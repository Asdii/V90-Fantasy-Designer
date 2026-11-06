#include "MachineNetwork.h"
#include "Encoder.h"
#include "PositionMath.h"
#include "WifiProvisioning.h"
#include "WifiReconnectPolicy.h"
#include <WiFi.h>
#include <WiFiUdp.h>
#include <WebServer.h>
#include <WebSocketsServer.h>
#include <ESPmDNS.h>
#include <ArduinoJson.h>

namespace {
WebServer http(80);
WebSocketsServer ws(81);
WiFiUDP discovery;
constexpr uint16_t DISCOVERY_PORT = 42190;
WifiReconnectPolicy reconnect;
Configuration* config;
String deviceId;
IPAddress announcedIp;
int64_t zero = 0;
bool ap = false, connectedBefore = false, mdns = false;
uint32_t lostAt = 0, closeApAt = 0, lastFrame = 0, lastStatus = 0;
uint32_t seenDisconnect = 0, lastDiscoveryReply = 0, lastMdnsAttempt = 0;

void identity(JsonDocument& doc) {
    doc["service"] = "microfantasy-machine";
    doc["api_version"] = 1;
    doc["device_id"] = deviceId;
    doc["hostname"] = "fantasy-machine.local";
    doc["ip"] = WiFi.localIP().toString();
    doc["ws_port"] = 81;
    doc["ws_path"] = "/ws";
}

void discoveryTick(uint32_t now) {
    const int length = discovery.parsePacket();
    if (!length) return;
    if (length > 256 || now - lastDiscoveryReply < 100) { discovery.flush(); return; }
    char packet[257];
    const int read = discovery.read(packet, sizeof(packet) - 1);
    if (read <= 0) return;
    JsonDocument request;
    if (deserializeJson(request, packet, read) ||
        request["type"].as<String>() != "discover" || request["api_version"].as<int>() != 1 ||
        !request["nonce"].is<String>()) return;
    const String nonce = request["nonce"].as<String>();
    if (nonce.isEmpty() || nonce.length() > 64) return;
    JsonDocument response;
    identity(response);
    response["type"] = "discovery";
    response["nonce"] = nonce;
    String body; serializeJson(response, body);
    discovery.beginPacket(discovery.remoteIP(), discovery.remotePort());
    discovery.write(reinterpret_cast<const uint8_t*>(body.c_str()), body.length());
    discovery.endPacket();
    lastDiscoveryReply = now;
}

void position(uint8_t client, uint32_t now) {
    char body[128];
    snprintf(body, sizeof(body), "{\"type\":\"position\",\"x_mm\":%.6f,\"timestamp\":%lu}",
             positionMm(Encoder::read().count, zero, config->inverted), (unsigned long)now);
    if (client == 255) ws.broadcastTXT(body); else ws.sendTXT(client, body);
}

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
    identity(doc);
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
    position(255, millis());
}

void connectionTick(uint32_t now) {
    WifiProvisioning::tick(now);
    const uint32_t disconnected = WifiProvisioning::disconnectSequence();
    if (disconnected != seenDisconnect) {
        seenDisconnect = disconnected;
        reconnect.disconnected(now);
    }
    if (WifiProvisioning::busy()) { reconnect.started(now); closeApAt = 0; }
    const IPAddress ip = WiFi.localIP();
    const bool connected = WiFi.status() == WL_CONNECTED && ip != IPAddress(0, 0, 0, 0);
    if (connected && (!connectedBefore || ip != announcedIp)) {
        if (connectedBefore) ws.disconnect();
        if (mdns) MDNS.end();
        mdns = false;
        announcedIp = ip;
        discovery.stop(); discovery.begin(DISCOVERY_PORT);
        reconnect.connected(now);
        lastMdnsAttempt = now - 5000;
        Serial.printf("Wi-Fi connected: %s | device: %s | ws://fantasy-machine.local:81/ws\n",
                      ip.toString().c_str(), deviceId.c_str());
        if (ap && !WifiProvisioning::busy() && !*WifiProvisioning::error()) closeApAt = now;
    }
    if (connected && !mdns && now - lastMdnsAttempt >= 5000) {
        lastMdnsAttempt = now;
        mdns = MDNS.begin("fantasy-machine");
        if (mdns) {
            MDNS.setInstanceName(deviceId.c_str());
            MDNS.addService("fantasy-machine", "tcp", 81);
            MDNS.addServiceTxt("fantasy-machine", "tcp", "path", "/ws");
            MDNS.addServiceTxt("fantasy-machine", "tcp", "id", deviceId);
            MDNS.addServiceTxt("fantasy-machine", "tcp", "api_version", "1");
        }
    }
    if (!connected && connectedBefore) {
        lostAt = now;
        closeApAt = 0;
        reconnect.disconnected(now);
        ws.disconnect();
        if (mdns) { MDNS.end(); mdns = false; }
        discovery.stop(); discovery.begin(DISCOVERY_PORT);
    }
    connectedBefore = connected;
    if (!connected && !WifiProvisioning::busy()) {
        if (now - lostAt >= 60000) startAp();
        if (!config->ssid.isEmpty() && reconnect.retry(now, WifiProvisioning::stationAssociated())) {
            WiFi.disconnect(false, false);
            WifiProvisioning::connectSaved();
        }
    }
    if (ap && connected && !WifiProvisioning::busy() && closeApAt && now - closeApAt >= 60000) {
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
    WiFi.setHostname("fantasy-machine");
    WiFi.mode(WIFI_STA);
    deviceId = "microfantasy-" + WiFi.macAddress();
    deviceId.replace(":", ""); deviceId.toLowerCase();
    WifiProvisioning::begin(configuration);
    WiFi.setSleep(false);
    if (config->ssid.isEmpty()) startAp();
    else WifiProvisioning::connectSaved();
    lostAt = millis();
    reconnect.started(lostAt);
    // OS captive-network probes are expected when joining a Wi-Fi without Internet.
    auto setupPage = [] {
        http.send(200, "text/html; charset=utf-8", "<h2>MicroFantasy</h2><p>Conectado a la maquina. Abre MicroFantasy y elige Configurar Wi-Fi de la maquina. Esta red no tiene Internet.</p>");
    };
    http.on("/", HTTP_GET, setupPage);
    http.on("/generate_204", HTTP_GET, setupPage);
    http.on("/gen_204", HTTP_GET, setupPage);
    http.on("/hotspot-detect.html", HTTP_GET, setupPage);
    http.on("/connecttest.txt", HTTP_GET, setupPage);
    http.on("/favicon.ico", HTTP_GET, [] { http.send(204); });
    http.on("/api/v1/info", HTTP_GET, [] {
        JsonDocument doc; identity(doc); reply(200, doc);
    });
    // Browser discovery bridge. Only active sensor clients become candidates;
    // V90 verifies each candidate's /api/v1/status before offering it to the user.
    http.on("/api/v1/apps", HTTP_OPTIONS, [] {
        http.sendHeader("Access-Control-Allow-Origin", "*");
        http.sendHeader("Access-Control-Allow-Methods", "GET, OPTIONS");
        http.sendHeader("Access-Control-Allow-Private-Network", "true");
        http.send(204);
    });
    http.on("/api/v1/apps", HTTP_GET, [] {
        http.sendHeader("Access-Control-Allow-Origin", "*");
        JsonDocument doc;
        doc["service"] = "microfantasy-machine";
        doc["api_version"] = 1;
        JsonArray apps = doc["apps"].to<JsonArray>();
        for (uint8_t client = 0; client < WEBSOCKETS_SERVER_CLIENT_MAX; ++client) {
            if (ws.clientIsConnected(client)) {
                apps.add("http://" + ws.remoteIP(client).toString() + ":8787");
            }
        }
        reply(200, doc);
    });
    http.on("/api/v1/setup", HTTP_GET, [] {
        if (!setupRequest()) { http.send(403); return; }
        JsonDocument doc;
        doc["device"] = "MicroFantasy"; doc["schemaVersion"] = 1;
        doc["connected"] = WiFi.status() == WL_CONNECTED && !WifiProvisioning::configuring() && !*WifiProvisioning::error();
        doc["connecting"] = WifiProvisioning::configuring();
        doc["error"] = WifiProvisioning::error();
        doc["ip"] = WiFi.localIP().toString();
        doc["hostname"] = "fantasy-machine.local";
        doc["device_id"] = deviceId;
        WifiProvisioning::writeStatus(doc);
        reply(200, doc);
    });
    http.on("/api/v1/setup", HTTP_POST, [] {
        if (!setupRequest()) { http.send(403); return; }
        if (WifiProvisioning::busy()) { http.send(409); return; }
        JsonDocument doc;
        const String body = http.arg("plain");
        if (body.length() > 512 || deserializeJson(doc, body) ||
            !doc["ssid"].is<String>() || !doc["password"].is<String>()) { http.send(400); return; }
        const String ssid = doc["ssid"].as<String>(), password = doc["password"].as<String>();
        if (ssid.length() < 1 || ssid.length() > 32 ||
            doc["ssid"].as<JsonString>().size() != strlen(ssid.c_str()) ||
            doc["password"].as<JsonString>().size() != strlen(password.c_str()) ||
            (password.length() != 0 && (password.length() < 8 || password.length() > 63))) { http.send(400); return; }
        WifiProvisioning::request(ssid, password, millis());
        closeApAt = 0;
        JsonDocument result; result["accepted"] = true; reply(202, result);
    });
    http.on("/api/v1/setup/networks", HTTP_POST, [] {
        if (!setupRequest()) { http.send(403); return; }
        if (!WifiProvisioning::scan(millis())) { http.send(409); return; }
        closeApAt = 0;
        JsonDocument doc; doc["accepted"] = true; reply(202, doc);
    });
    http.on("/api/v1/setup/networks", HTTP_GET, [] {
        if (!setupRequest()) { http.send(403); return; }
        JsonDocument doc; WifiProvisioning::writeNetworks(doc); reply(200, doc);
    });
    http.onNotFound([] { http.send(404, "text/plain", "Use MicroFantasy > Configurar Wi-Fi de la maquina"); });
    http.begin();
    discovery.begin(DISCOVERY_PORT);
    ws.begin();
    ws.onEvent([](uint8_t client, WStype_t type, uint8_t* data, size_t length) {
        if (type == WStype_CONNECTED) {
            if (String(reinterpret_cast<char*>(data)) != "/ws") { ws.disconnect(client); return; }
            status(client);
            position(client, millis());
        } else if (type == WStype_TEXT) command(client, data, length);
    });
    ws.enableHeartbeat(3000, 1500, 2);
}

void MachineNetwork::reopenSetup() {
    startAp(); closeApAt = 0;
    if (ap) Serial.printf("Setup password: %s | http://192.168.4.1\n", config->setupPassword.c_str());
    Serial.println("Setup reopened; existing Wi-Fi credentials retained until a new connection succeeds.");
}

void MachineNetwork::tick() {
    const uint32_t now = millis();
    connectionTick(now);
    ws.loop();
    if (now - lastFrame >= 34) { // About 29 Hz, including when stationary.
        lastFrame = now;
        if (ws.connectedClients()) position(255, now);
    }
    discoveryTick(now);
    http.handleClient();
    if (now - lastStatus >= 1000) {
        lastStatus = now;
        const auto sample = Encoder::read();
        Serial.printf("X: %.3f mm | count: %lld | invalid: %lu\n",
            positionMm(sample.count, zero, config->inverted), (long long)sample.count,
            (unsigned long)sample.invalidTransitions);
        status(255);
    }
}
