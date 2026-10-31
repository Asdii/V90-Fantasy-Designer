#include "WifiProvisioning.h"
#include "WifiSetupPolicy.h"
#include <WiFi.h>
#include <esp_wifi.h>
#include <algorithm>
#include <vector>

namespace {
Configuration* config;
WifiSetup::Policy policy;
String candidateSsid, candidatePassword;
struct Network {
    String ssid;
    uint8_t bssid[6];
    int32_t rssi, channel;
    wifi_auth_mode_t auth;
};
std::vector<Network> networks;
bool scanPending = false, scanning = false;
uint32_t scanAt = 0;
const char* scanError = "";

// Wi-Fi callbacks run on another task. Only this small snapshot is shared;
// all strings, HTTP, NVS and connection changes remain on the Arduino loop.
portMUX_TYPE eventMux = portMUX_INITIALIZER_UNLOCKED;
bool associated = false;
uint16_t lastReason = 0, loggedReason = 0;

bool compatible(wifi_auth_mode_t auth) {
    return auth == WIFI_AUTH_OPEN || auth == WIFI_AUTH_WPA2_PSK ||
           auth == WIFI_AUTH_WPA_WPA2_PSK || auth == WIFI_AUTH_WPA3_PSK ||
           auth == WIFI_AUTH_WPA2_WPA3_PSK;
}

bool matches(const uint8_t* buffer, size_t capacity, const String& expected) {
    return expected.length() <= capacity &&
           memcmp(buffer, expected.c_str(), expected.length()) == 0 &&
           (expected.length() == capacity || buffer[expected.length()] == 0);
}

void connectStation(const String& ssid, const String& password,
                    int32_t channel = 0, const uint8_t* bssid = nullptr) {
    // Configure DHCP and credentials through Arduino without connecting yet.
    // Its 2.0.17 wrapper leaves SAE PWE unspecified; IDF 4.4 supports BOTH
    // hunting-and-pecking and H2E, as used by Espressif's station example.
    WiFi.begin(ssid.c_str(), password.c_str(), channel, bssid, false);
    wifi_config_t station = {};
    esp_err_t result = esp_wifi_get_config(WIFI_IF_STA, &station);
    if (result == ESP_OK &&
        (!matches(station.sta.ssid, sizeof(station.sta.ssid), ssid) ||
         !matches(station.sta.password, sizeof(station.sta.password), password))) {
        result = ESP_ERR_INVALID_STATE;
    }
    if (result == ESP_OK) {
        station.sta.sae_pwe_h2e = WPA3_SAE_PWE_BOTH;
        result = esp_wifi_set_config(WIFI_IF_STA, &station);
    }
    if (result == ESP_OK) result = esp_wifi_connect();
    if (result != ESP_OK) Serial.printf("Wi-Fi connection API error: %s\n", esp_err_to_name(result));
}

void startScan(uint32_t now) {
    WiFi.disconnect(false, false);
    scanPending = true; scanning = false; scanAt = now;
    scanError = ""; networks.clear();
}

void finishScan(uint32_t now, int16_t count) {
    if (count >= 0) {
        // The ESP32-C3 radio scans only 2.4 GHz. A unified SSID therefore
        // selects its compatible radio without requiring a router setting.
        for (int16_t i = 0; i < count && i < 256; ++i) {
            const String ssid = WiFi.SSID(i);
            if (ssid.isEmpty() || !compatible(WiFi.encryptionType(i))) continue;
            Network entry;
            entry.ssid = ssid; entry.rssi = WiFi.RSSI(i);
            entry.channel = WiFi.channel(i); entry.auth = WiFi.encryptionType(i);
            memcpy(entry.bssid, WiFi.BSSID(i), 6);
            networks.push_back(entry);
        }
        std::sort(networks.begin(), networks.end(), [](const Network& a, const Network& b) {
            return a.rssi > b.rssi;
        });
        if (networks.size() > 64) networks.resize(64);
    } else scanError = "scan_failed";
    WiFi.scanDelete(); scanning = scanPending = false;
    policy.scanned(now);
}

void scanTick(uint32_t now) {
    if (scanPending && now - scanAt >= 250) {
        scanPending = false; scanning = true;
        const int16_t result = WiFi.scanNetworks(true, false, false, 120);
        if (result != WIFI_SCAN_RUNNING) finishScan(now, result);
    }
    if (!scanning) return;
    const int16_t result = WiFi.scanComplete();
    if (result >= 0 || result == WIFI_SCAN_FAILED) finishScan(now, result);
    else if (now - scanAt >= 9000) {
        esp_wifi_scan_stop();
        finishScan(now, WIFI_SCAN_FAILED);
    }
}

void connectCandidate() {
    // Try the strongest matching 2.4 GHz AP, then another matching AP if
    // present. The final attempt is unpinned, using the SDK all-channel scan.
    const Network* target = nullptr;
    if (policy.attempt < WifiSetup::Policy::MaxAttempts) {
        uint8_t match = 0;
        for (const auto& network : networks) {
            if (network.ssid != candidateSsid) continue;
            if (!target) target = &network;
            if (++match == policy.attempt) { target = &network; break; }
        }
    }
    portENTER_CRITICAL(&eventMux);
    associated = false; lastReason = 0;
    portEXIT_CRITICAL(&eventMux);
    loggedReason = 0;
    Serial.printf("Wi-Fi setup attempt %u/%u | channel: %ld\n", policy.attempt,
                  WifiSetup::Policy::MaxAttempts, target ? (long)target->channel : 0L);
    connectStation(candidateSsid, candidatePassword,
                   target ? target->channel : 0, target ? target->bssid : nullptr);
}
}

void WifiProvisioning::begin(Configuration& configuration) {
    config = &configuration;
    // One owner controls retries; background reconnect must not interrupt a
    // scan or restore old credentials in the middle of provisioning.
    WiFi.setAutoReconnect(false);
    WiFi.setScanMethod(WIFI_ALL_CHANNEL_SCAN);
    WiFi.setSortMethod(WIFI_CONNECT_AP_BY_SIGNAL);
    WiFi.onEvent([](WiFiEvent_t event, WiFiEventInfo_t info) {
        portENTER_CRITICAL(&eventMux);
        if (event == ARDUINO_EVENT_WIFI_STA_CONNECTED) associated = true;
        if (event == ARDUINO_EVENT_WIFI_STA_DISCONNECTED) {
            associated = false;
            // ASSOC_LEAVE is produced by our deliberate disconnects.
            if (info.wifi_sta_disconnected.reason != WIFI_REASON_ASSOC_LEAVE)
                lastReason = info.wifi_sta_disconnected.reason;
        }
        portEXIT_CRITICAL(&eventMux);
    });
}

bool WifiProvisioning::busy() { return policy.busy() || scanning || scanPending; }
bool WifiProvisioning::configuring() { return policy.busy(); }
const char* WifiProvisioning::error() { return policy.error; }

void WifiProvisioning::connectSaved() {
    if (!config->ssid.isEmpty()) connectStation(config->ssid, config->password);
}

bool WifiProvisioning::request(const String& ssid, const String& password, uint32_t now) {
    if (busy() || !policy.request(now)) return false;
    candidateSsid = ssid; candidatePassword = password;
    return true;
}

bool WifiProvisioning::scan(uint32_t now) {
    if (busy()) return false;
    startScan(now);
    return true;
}

void WifiProvisioning::tick(uint32_t now) {
    scanTick(now);
    bool linkAssociated;
    uint16_t reason;
    portENTER_CRITICAL(&eventMux);
    linkAssociated = associated; reason = lastReason;
    portEXIT_CRITICAL(&eventMux);
    if (reason && reason != loggedReason) {
        loggedReason = reason;
        Serial.printf("Wi-Fi disconnect: %u (%s)\n", reason,
                      WiFi.disconnectReasonName(static_cast<wifi_err_reason_t>(reason)));
    }
    const bool hasIp = WiFi.status() == WL_CONNECTED && WiFi.localIP() != IPAddress(0, 0, 0, 0);
    switch (policy.tick(now, hasIp, WiFi.SSID() == candidateSsid, linkAssociated, reason)) {
        case WifiSetup::Action::Scan: startScan(now); break;
        case WifiSetup::Action::Connect: connectCandidate(); break;
        case WifiSetup::Action::Disconnect: WiFi.disconnect(false, false); break;
        case WifiSetup::Action::Commit: {
            Configuration next = *config;
            next.ssid = candidateSsid; next.password = candidatePassword;
            if (next.save()) { *config = next; Serial.println("Wi-Fi setup saved"); }
            else policy.storageFailed();
            candidatePassword = "";
            break;
        }
        case WifiSetup::Action::Fail:
            Serial.printf("Wi-Fi setup failed: %s | reason: %u\n", policy.error, policy.reason);
            candidatePassword = "";
            WiFi.disconnect(false, false);
            // Failed credentials never replace the previously saved network.
            connectSaved();
            break;
        default: break;
    }
}

void WifiProvisioning::writeStatus(JsonDocument& doc) {
    bool linkAssociated;
    portENTER_CRITICAL(&eventMux);
    linkAssociated = associated;
    portEXIT_CRITICAL(&eventMux);
    doc["scan_supported"] = true;
    doc["attempt"] = policy.attempt;
    doc["max_attempts"] = WifiSetup::Policy::MaxAttempts;
    doc["reason_code"] = policy.reason;
    const char* phase = "idle";
    switch (policy.phase) {
        case WifiSetup::Phase::Acknowledging: phase = "preparing"; break;
        case WifiSetup::Phase::Scanning: phase = "scanning"; break;
        case WifiSetup::Phase::Waiting: phase = "retrying"; break;
        case WifiSetup::Phase::Connecting: phase = linkAssociated ? "getting_address" : "connecting"; break;
        case WifiSetup::Phase::Ready: phase = "connected"; break;
        case WifiSetup::Phase::Failed: phase = "failed"; break;
        default: break;
    }
    doc["phase"] = phase;
}

void WifiProvisioning::writeNetworks(JsonDocument& doc) {
    doc["device"] = "MicroFantasy"; doc["schemaVersion"] = 1;
    doc["scanning"] = scanning || scanPending;
    doc["error"] = scanError;
    JsonArray list = doc["networks"].to<JsonArray>();
    std::vector<String> seen;
    for (const auto& network : networks) {
        if (std::find(seen.begin(), seen.end(), network.ssid) != seen.end()) continue;
        seen.push_back(network.ssid);
        JsonObject item = list.add<JsonObject>();
        item["ssid"] = network.ssid; item["rssi"] = network.rssi;
        item["secured"] = network.auth != WIFI_AUTH_OPEN;
        if (seen.size() >= 24) break;
    }
}
