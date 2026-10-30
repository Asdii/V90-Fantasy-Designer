#pragma once
#include <Arduino.h>

struct Configuration {
    String ssid;
    String password;
    bool inverted = false;
    String setupPassword;
    bool begin();
    bool save() const;
};
