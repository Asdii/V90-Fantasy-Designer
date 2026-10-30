#include "MachineNetwork.h"
#include "Encoder.h"
#include "PositionMath.h"
#include <WiFi.h>
#include <WebServer.h>
#include <WebSocketsServer.h>
#include <ESPmDNS.h>
#include <ArduinoJson.h>

namespace {
WebServer http(80);
WebSocketsServer ws(81);
Configuration* config;
int64_t zero = 0;
bool ap = false, pending = false, trial = false, connectedBefore = false, mdns = false;
uint32_t attemptAt = 0, lostAt = 0, closeApAt = 0, lastFrame = 0, lastStatus = 0;
String candidateSsid, candidatePassword, setupError;

void reply(int code, const JsonDocument& doc) {
    String body;
    serializeJson(doc, body);
    http.sendHeader("Cache-Control", "no-store");
    http.send(code, "application/json", body);
}

void startAp() {
    if (ap) return;
    WiFi.mode(WIFI_AP_STA);
    String suffix = WiFi.macAddress(); suffix.replace(":", "");
    const String name = "MicroFantasy-" + suffix.substring(6);
    ap = WiFi.softAP(name.c_str(), config->setupPassword.c_str());
    closeApAt = 0;
    if (ap) {
        Serial.printf("Setup Wi-Fi: %s | Password: %s | http://192.168.4.1\n",
                      name.c_str(), config->setupPassword.c_str());
    } else Serial.println("Could not start setup Wi-Fi");
}

bool setupRequest() {
    // Provisioning is available ONLY over the temporary password-protected AP.
    return ap && http.client().localIP() == WiFi.softAPIP();
}

void status(uint8_t client) {
    JsonDocument doc;
    doc["type"] = "status";
    doc["connected"] = true; // Transport ready, not a claim of magnetic field health.
    doc["status"] = "incremental_ready";
    doc["sensor"] = Encoder::read().invalidTransitions ? "transition_warning" : "unverified";
    doc["wifi"] = MachineNetwork::wifiStatus();
    doc["inverted"] = config->inverted;
    doc["counts_per_mm"] = COUNTS_PER_MM;
    String body; serializeJson(doc, body);
    if (client == 255) ws.broadcastTXT(body); else ws.sendTXT(client, body);
}

void command(uint8_t client, uint8_t* payload, size_t length) {
    JsonDocument doc;
    if (length > 256 || deserializeJson(doc, payload, length) || !doc.is<JsonObject>()) return;
    const String type = doc["type"] | "";
    if (type == "zero_x") zero = Encoder::read().count;
    else if (type == "set_direction" && doc["inverted"].is<bool>()) {
        const bool old = config->inverted;
        config->inverted = doc["inverted"].as<bool>();
        if (old != config->inverted && !config->save()) {
            config->inverted = old;
            String failure = "{\"type\":\"status\",\"status\":\"storage_error\"}";
            ws.sendTXT(client, failure);
            return;
        }
    } else {
        String failure = "{\"type\":\"status\",\"status\":\"invalid_command\"}";
        ws.sendTXT(client, failure);
        return;
    }
    status(255);
}

void connectionTick(uint32_t now) {
    if (pending) {
        pending = false; trial = true; attemptAt = now; closeApAt = 0;
        WiFi.disconnect(false, false);
        WiFi.begin(candidateSsid.c_str(), candidatePassword.c_str());
        connectedBefore = false;
    }
    const bool connected = WiFi.status() == WL_CONNECTED;
    if (connected && !connectedBefore) {
        if (trial) {
            Configuration next = *config;
            next.ssid = candidateSsid; next.password = candidatePassword;
            if (next.save()) { *config = next; setupError = ""; }
            else setupError = "storage_error";
            trial = false;
            candidatePassword = "";
        }
        if (mdns) MDNS.end();
        mdns = MDNS.begin("fantasy-machine");
        if (mdns) {
            MDNS.addService("fantasy-machine", "tcp", 81);
            MDNS.addServiceTxt("fantasy-machine", "tcp", "path", "/ws");
        }
        Serial.printf("Wi-Fi connected: %s | ws://fantasy-machine.local:81/ws\n", WiFi.localIP().toString().c_str());
        if (ap && setupError.isEmpty()) closeApAt = now;
    }
    if (!connected && connectedBefore) {
        lostAt = now;
        closeApAt = 0;
        if (mdns) { MDNS.end(); mdns = false; }
    }
    connectedBefore = connected;
    if (trial && !connected && now - attemptAt >= 20000) {
        trial = false; setupError = "connection_failed"; candidatePassword = "";
        WiFi.disconnect(false, false);
        if (!config->ssid.isEmpty()) WiFi.begin(config->ssid.c_str(), config->password.c_str());
        attemptAt = now;
    }
    if (!connected && !trial && !pending) {
        if (now - lostAt >= 60000) startAp();
        if (!config->ssid.isEmpty() && now - attemptAt >= 15000) {
            WiFi.reconnect(); attemptAt = now;
        }
    }
    if (ap && connected && closeApAt && now - closeApAt >= 15000) {
        WiFi.softAPdisconnect(true); WiFi.mode(WIFI_STA); ap = false; closeApAt = 0;
    }
}
}

const char* MachineNetwork::wifiStatus() {
    return WiFi.status() == WL_CONNECTED ? "ok" : (ap ? "setup" : "reconnecting");
}

void MachineNetwork::begin(Configuration& configuration) {
    config = &configuration;
    WiFi.persistent(false); // Own NVS record; do not write credentials on retries.
    WiFi.mode(WIFI_STA);
    WiFi.setHostname("fantasy-machine");
    WiFi.setAutoReconnect(true);
    WiFi.setSleep(false);
    if (config->ssid.isEmpty()) startAp();
    else WiFi.begin(config->ssid.c_str(), config->password.c_str());
    lostAt = attemptAt = millis();
    http.on("/api/v1/setup", HTTP_GET, [] {
        if (!setupRequest()) { http.send(403); return; }
        JsonDocument doc;
        doc["device"] = "MicroFantasy"; doc["schemaVersion"] = 1;
        doc["connected"] = WiFi.status() == WL_CONNECTED && !pending && !trial && setupError.isEmpty();
        doc["connecting"] = pending || trial;
        doc["error"] = setupError;
        doc["ip"] = WiFi.localIP().toString();
        doc["hostname"] = "fantasy-machine.local";
        reply(200, doc);
    });
    http.on("/api/v1/setup", HTTP_POST, [] {
        if (!setupRequest()) { http.send(403); return; }
        if (pending || trial) { http.send(409); return; }
        JsonDocument doc;
        const String body = http.arg("plain");
        if (body.length() > 512 || deserializeJson(doc, body) ||
            !doc["ssid"].is<String>() || !doc["password"].is<String>()) { http.send(400); return; }
        const String ssid = doc["ssid"].as<String>(), password = doc["password"].as<String>();
        if (ssid.length() < 1 || ssid.length() > 32 ||
            doc["ssid"].as<JsonString>().size() != strlen(ssid.c_str()) ||
            doc["password"].as<JsonString>().size() != strlen(password.c_str()) ||
            (password.length() != 0 && (password.length() < 8 || password.length() > 63))) { http.send(400); return; }
        candidateSsid = ssid; candidatePassword = password; setupError = "";
        pending = true;
        JsonDocument result; result["accepted"] = true; reply(202, result);
    });
    http.onNotFound([] { http.send(404, "text/plain", "Use MicroFantasy > Configurar Wi-Fi de la maquina"); });
    http.begin();
    ws.begin();
    ws.onEvent([](uint8_t client, WStype_t type, uint8_t* data, size_t length) {
        if (type == WStype_CONNECTED) {
            if (String(reinterpret_cast<char*>(data)) != "/ws") { ws.disconnect(client); return; }
            status(client);
        } else if (type == WStype_TEXT) command(client, data, length);
    });
    ws.enableHeartbeat(5000, 3000, 2);
}

void MachineNetwork::reopenSetup() {
    startAp(); closeApAt = 0;
    if (ap) Serial.printf("Setup password: %s | http://192.168.4.1\n", config->setupPassword.c_str());
    Serial.println("Setup reopened; existing Wi-Fi credentials retained until a new connection succeeds.");
}

void MachineNetwork::tick() {
    const uint32_t now = millis();
    connectionTick(now);
    http.handleClient();
    ws.loop();
    if (now - lastFrame >= 40) { // 25 Hz, including when stationary.
        lastFrame = now;
        JsonDocument doc;
        doc["type"] = "position";
        doc["x_mm"] = positionMm(Encoder::read().count, zero, config->inverted);
        doc["timestamp"] = now;
        String body; serializeJson(doc, body); ws.broadcastTXT(body);
    }
    if (now - lastStatus >= 1000) {
        lastStatus = now;
        const auto sample = Encoder::read();
        Serial.printf("X: %.3f mm | count: %lld | invalid: %lu\n",
            positionMm(sample.count, zero, config->inverted), (long long)sample.count,
            (unsigned long)sample.invalidTransitions);
        status(255);
    }
}
