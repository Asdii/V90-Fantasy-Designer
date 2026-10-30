#include <Arduino.h>
#include "Configuration.h"
#include "Encoder.h"
#include "MachineNetwork.h"

Configuration configuration;
bool ready = false;

void setup() {
    Serial.begin(115200); // Do not wait for USB: standalone operation is required.
    Encoder::begin();
    pinMode(9, INPUT_PULLUP); // XIAO BOOT; hold AFTER boot to reopen setup.
    ready = configuration.begin();
    if (ready) MachineNetwork::begin(configuration);
    else Serial.println("NVS initialization failed; restart device. No credentials were erased.");
}

void loop() {
    static uint32_t pressedAt = 0;
    static bool handled = false;
    if (!ready) { delay(100); return; }
    if (digitalRead(9) == LOW) {
        if (!pressedAt) pressedAt = millis();
        if (!handled && millis() - pressedAt >= 3000) {
            handled = true; MachineNetwork::reopenSetup();
        }
    } else { pressedAt = 0; handled = false; }
    MachineNetwork::tick();
    delay(1); // Wi-Fi/RTOS yield; encoder interrupts continue independently.
}
