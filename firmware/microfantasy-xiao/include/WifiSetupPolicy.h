#pragma once
#include <stdint.h>

// No Arduino dependencies: timeouts, retries and the commit gate are testable
// without a radio. All durations use unsigned subtraction (millis rollover).
namespace WifiSetup {
enum class Phase { Idle, Acknowledging, Scanning, Waiting, Connecting, Ready, Failed };
enum class Action { None, Scan, Connect, Disconnect, Commit, Fail };

inline const char* connectionError(uint16_t reason, bool associated) {
    if (associated) return "address_timeout";
    switch (reason) {
        case 201: return "network_not_found";
        case 15: case 202: case 204: return "authentication_failed";
        case 203: return "association_failed";
        case 200: return "signal_lost";
        default: return "connection_timeout";
    }
}

class Policy {
public:
    static constexpr uint8_t MaxAttempts = 3;
    Phase phase = Phase::Idle;
    uint8_t attempt = 0;
    uint16_t reason = 0;
    const char* error = "";

    bool busy() const {
        return phase == Phase::Acknowledging || phase == Phase::Scanning ||
               phase == Phase::Waiting || phase == Phase::Connecting;
    }
    bool request(uint32_t now) {
        if (busy()) return false;
        attempt = 0; reason = 0; error = "";
        enter(Phase::Acknowledging, now);
        return true;
    }
    void scanned(uint32_t now) {
        if (phase == Phase::Scanning) enter(Phase::Waiting, now);
    }
    void storageFailed() { phase = Phase::Failed; error = "storage_error"; }

    Action tick(uint32_t now, bool hasIp = false, bool matchesSsid = false,
                bool associated = false, uint16_t disconnectReason = 0) {
        const uint32_t elapsed = now - since;
        switch (phase) {
            case Phase::Acknowledging:
                // Let the HTTP 202 leave the AP before changing radio channel.
                if (elapsed >= 750) { enter(Phase::Scanning, now); return Action::Scan; }
                break;
            case Phase::Scanning:
                // Hidden networks and failed scans still get a connection try.
                if (elapsed >= 10000) enter(Phase::Waiting, now);
                break;
            case Phase::Waiting:
                if (elapsed >= (attempt == 0 ? 250u : 2000u)) {
                    ++attempt; reason = 0;
                    enter(Phase::Connecting, now);
                    return Action::Connect;
                }
                break;
            case Phase::Connecting:
                if (disconnectReason) reason = disconnectReason;
                // Never persist credentials for an old connection or before DHCP.
                if (hasIp && matchesSsid) {
                    phase = Phase::Ready; error = "";
                    return Action::Commit;
                }
                if (elapsed >= 25000) {
                    if (attempt < MaxAttempts) {
                        enter(Phase::Waiting, now);
                        return Action::Disconnect;
                    }
                    phase = Phase::Failed;
                    error = connectionError(reason, associated);
                    return Action::Fail;
                }
                break;
            default: break;
        }
        return Action::None;
    }
private:
    uint32_t since = 0;
    void enter(Phase next, uint32_t now) { phase = next; since = now; }
};
}
