#include "Configuration.h"
#include <ArduinoJson.h>
#include <Preferences.h>
#include <esp_system.h>

namespace { Preferences storage; }

bool Configuration::begin() {
    if (!storage.begin("microfantasy", false)) return false;
    JsonDocument doc;
    if (!deserializeJson(doc, storage.getString("config", "{}"))) {
        ssid = doc["ssid"] | "";
        password = doc["password"] | "";
        inverted = doc["inverted"] | false;
    }
    setupPassword = storage.getString("setupKey", "");
    if (setupPassword.length() < 12) {
        char key[17];
        snprintf(key, sizeof(key), "%08lx%08lx", (unsigned long)esp_random(), (unsigned long)esp_random());
        setupPassword = key;
        if (!storage.putString("setupKey", setupPassword)) return false;
    }
    return true;
}

bool Configuration::save() const {
    JsonDocument doc;
    doc["ssid"] = ssid;
    doc["password"] = password;
    doc["inverted"] = inverted;
    String json;
    serializeJson(doc, json);
    return storage.putString("config", json) > 0;
}
