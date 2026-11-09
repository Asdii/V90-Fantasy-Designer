#pragma once
#include "XReferenceProtocol.h"

// RAM state belongs to this power-on, not to the Wi-Fi/socket lifetime. A boot
// remains pending indefinitely until a phone confirms this exact boot ID.
namespace BootNotice {
class State {
public:
    void begin(const std::string& bootId) { bootId_ = bootId; pending_ = true; }
    bool pending() const { return pending_; }
    bool acknowledge(JsonVariantConst doc) {
        std::string boot;
        if (!doc.is<JsonObjectConst>() || doc.size() != 2 ||
            doc["type"] != "ack_boot" ||
            !XReferenceProtocol::readId(doc["boot_id"], boot) || boot != bootId_)
            return false;
        pending_ = false;
        return true;
    }
    void write(JsonDocument& doc) const { doc["boot_notice_pending"] = pending_; }
private:
    std::string bootId_;
    bool pending_ = true;
};
}
