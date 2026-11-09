#include "BootNotice.h"
#include <cassert>
#include <cstdio>

static bool receive(BootNotice::State& state, const std::string& wire) {
    JsonDocument doc;
    if (XReferenceProtocol::parse(doc, wire.data(), wire.size())) return false;
    return state.acknowledge(doc.as<JsonVariantConst>());
}

int main() {
    BootNotice::State notice;
    notice.begin("boot-1");
    // Repeated telemetry / no phone never consumes the notification.
    for (int i = 0; i < 100; ++i) {
        JsonDocument status;
        notice.write(status);
        assert(status["boot_notice_pending"] == true && notice.pending());
    }
    for (const auto& wire : {
        "{}", "[]", "{\"type\":\"ack_boot\"}",
        "{\"type\":\"ack_boot\",\"boot_id\":\"old-boot\"}",
        "{\"type\":\"ack_boot\",\"boot_id\":42}",
        "{\"type\":\"ack_boot\",\"boot_id\":\"boot-1\",\"x_mm\":0}",
        "{\"type\":\"ack_boot\",\"boot_id\":\"boot-1\",\"boot_id\":\"boot-1\"}",
        "{\"type\":\"zero_x\",\"boot_id\":\"boot-1\"}"
    }) {
        assert(!receive(notice, wire)); assert(notice.pending());
    }
    const std::string ack = "{\"type\":\"ack_boot\",\"boot_id\":\"boot-1\"}";
    assert(receive(notice, ack) && !notice.pending());
    assert(receive(notice, ack) && !notice.pending()); // Idempotent receipt.
    JsonDocument status; notice.write(status);
    assert(status["boot_notice_pending"] == false);
    notice.begin("boot-2");
    assert(notice.pending());
    assert(!receive(notice, ack) && notice.pending());
    assert(receive(notice, "{\"type\":\"ack_boot\",\"boot_id\":\"boot-2\"}"));
    puts("Boot notice tests passed");
}
