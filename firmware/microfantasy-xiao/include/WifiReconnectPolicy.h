#pragma once
#include <stdint.h>

// Retry after a reported disconnect, while allowing association/DHCP to finish.
// All time comparisons also work across millis() rollover.
class WifiReconnectPolicy {
public:
    void started(uint32_t now) { since = now; connecting = true; }
    void connected(uint32_t now) { since = now; connecting = false; failures = 0; }
    void disconnected(uint32_t now) { since = now; connecting = false; }
    bool retry(uint32_t now, bool associated) {
        const uint32_t backoff = 1000u << (failures < 3 ? failures : 3);
        const uint32_t wait = connecting ? (associated ? 25000u : 15000u) : backoff;
        if (now - since < wait) return false;
        if (failures < 3) ++failures;
        started(now);
        return true;
    }
private:
    uint32_t since = 0;
    uint8_t failures = 0;
    bool connecting = false;
};
