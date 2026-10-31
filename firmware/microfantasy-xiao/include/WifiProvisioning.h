#pragma once
#include "Configuration.h"
#include <ArduinoJson.h>

namespace WifiProvisioning {
void begin(Configuration& configuration);
void connectSaved();
void tick(uint32_t now);
bool busy();
bool configuring();
const char* error();
bool request(const String& ssid, const String& password, uint32_t now);
bool scan(uint32_t now);
void writeStatus(JsonDocument& doc);
void writeNetworks(JsonDocument& doc);
}
