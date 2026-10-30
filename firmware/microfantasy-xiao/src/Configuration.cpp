#include "Configuration.h"
#include <ArduinoJson.h>
#include <Preferences.h>

namespace { Preferences storage; }

bool Configuration::begin() {
    if (!storage.begin("microfantasy", false)) return false;
    JsonDocument doc;
    if (storage.isKey("config") && !deserializeJson(doc, storage.getString("config"))) {
        ssid = doc["ssid"] | "";
        password = doc["password"] | "";
        inverted = doc["inverted"] | false;
    }
    // A deliberately simple setup key, also replacing earlier random keys.
    setupPassword = "fantasy123";
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
