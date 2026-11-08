#include "XReference.h"
#include "WifiReconnectPolicy.h"
#include <cassert>
#include <cstdio>
#include <limits>

using namespace XReference;

static void near(double actual, double expected) {
    assert(std::abs(actual - expected) < 1e-9);
}

static void same(const Snapshot& a, const Snapshot& b) {
    assert(a.bootId == b.bootId && a.referenceId == b.referenceId);
    assert(a.revision == b.revision && a.inverted == b.inverted);
    near(a.xMm, b.xMm);
}

static void anchoring() {
    for (bool inverted : {false, true}) {
        State state;
        state.beginBoot("boot-a", inverted);
        const int direction = inverted ? -1 : 1;
        const int64_t raw = 50000000000000000LL; // Beyond exact double integers.
        const auto startup = state.snapshot(raw);
        assert(startup.bootId == "boot-a");
        assert(startup.referenceId.empty() && startup.revision == 0);

        const auto negative = state.anchor({"neg", "boot-a", "frame", -37.25}, raw);
        assert(negative.accepted && !negative.error);
        assert(negative.state.referenceId == "frame" && negative.state.revision == 1);
        near(negative.state.xMm, -37.25);
        near(state.snapshot(raw).xMm, -37.25);
        near(state.snapshot(raw + direction).xMm, -37.25 + 1.0 / 512);
        const int64_t center = raw + direction * 19072; // 37.25 mm.
        near(state.snapshot(center).xMm, 0);
        const int64_t positive = center + direction * 42496; // +83 mm, asymmetric.
        near(state.snapshot(positive).xMm, 83);

        const auto pos = state.anchor({"pos", "boot-a", "frame", 83}, positive);
        assert(pos.accepted && pos.state.revision == 2);
        near(state.snapshot(center).xMm, 0);
        near(state.snapshot(raw).xMm, -37.25);
        const auto zero = state.anchor({"center", "boot-a", "frame", 0}, center);
        assert(zero.accepted && zero.state.revision == 3);
        near(state.snapshot(center + direction * 512).xMm, 1);

        const auto fractional = state.anchor({"fraction", "boot-a", "frame", 0.123456789}, raw);
        near(fractional.state.xMm, 0.123456789); // Never round to an encoder edge.
        near(state.snapshot(raw - direction * 512).xMm, -0.876543211);
        assert(raw == 50000000000000000LL); // All commands take the count by value.
    }
    near(positionMm(INT64_MAX, INT64_MAX - 1, false), 1.0 / 512);
    assert(positionMm(INT64_MAX, INT64_MIN, false) > 0);
    assert(positionMm(INT64_MIN, INT64_MAX, false) < 0);
}

static void validationAndRetry() {
    State state;
    state.beginBoot("boot-a", false);
    const Request request{"id", "boot-a", "calibration", -19.5};
    const auto original = state.anchor(request, 8000);
    assert(original.accepted);
    const auto afterMove = state.snapshot(8000 + 1024);
    near(afterMove.xMm, -17.5);
    const auto retry = state.anchor(request, 8000 + 1024);
    assert(retry.accepted && retry.requestId == original.requestId);
    same(retry.state, original.state);
    same(state.snapshot(9024), afterMove); // Retry did not anchor the new count.

    const auto reject = [&](const Request& bad, const char* error) {
        const auto before = state.snapshot(9024);
        const auto ack = state.anchor(bad, 9024);
        assert(!ack.accepted && std::string(ack.error) == error);
        same(ack.state, before);
        same(state.snapshot(9024), before);
    };
    reject({"id", "old-boot", "calibration", -19.5}, "wrong_boot");
    reject({"id", "boot-a", "another-frame", -19.5}, "request_id_conflict");
    reject({"id", "boot-a", "calibration", 19.5}, "request_id_conflict");
    reject({"", "boot-a", "calibration", 0}, "invalid_request_id");
    reject({std::string(81, 'a'), "boot-a", "calibration", 0}, "invalid_request_id");
    reject({std::string("id\0suffix", 9), "boot-a", "calibration", 0}, "invalid_request_id");
    reject({"new", "", "calibration", 0}, "invalid_boot_id");
    reject({"new", std::string(81, 'b'), "calibration", 0}, "invalid_boot_id");
    reject({"new", "b\xc3\xb6ot", "calibration", 0}, "invalid_boot_id");
    reject({"new", "boot-a", "", 0}, "invalid_reference_id");
    reject({"new", "boot-a", std::string(81, 'c'), 0}, "invalid_reference_id");
    reject({"new", "boot-a", std::string("ref\0suffix", 10), 0}, "invalid_reference_id");
    for (double x : {10000.0001, -10000.0001, std::numeric_limits<double>::infinity(),
                     -std::numeric_limits<double>::infinity(), std::numeric_limits<double>::quiet_NaN()})
        reject({"new", "boot-a", "calibration", x}, "unsupported_x");

    // Rejections do not consume IDs. Both boundary coordinates are supported.
    assert(state.anchor({"new", "boot-a", "calibration", 10000}, 9024).accepted);
    assert(state.anchor({"limit", "boot-a", std::string(80, 'c'), -10000}, 9024).accepted);
    assert(state.anchor({std::string(80, 'a'), "boot-a", "frame", 0}, 9024).accepted);
    same(state.anchor(request, 12000).state, original.state); // Later anchors don't erase receipts.
}

static void legacyAndContinuity() {
    State state;
    state.beginBoot("boot-a", false);
    const Request request{"id", "boot-a", "calibration", -37.25};
    const auto original = state.anchor(request, 1024);
    state.setDirection(false); // No-op direction doesn't invalidate or persist.
    same(state.snapshot(1024), original.state);
    state.setDirection(true);
    const auto reversed = state.snapshot(1536);
    near(reversed.xMm, 36.25);
    assert(reversed.referenceId.empty() && reversed.revision == 2);
    same(state.anchor(request, 1536).state, original.state);
    same(state.snapshot(1536), reversed);
    state.zero(1536);
    const auto zeroed = state.snapshot(1536);
    assert(zeroed.referenceId.empty() && zeroed.revision == 3);
    near(zeroed.xMm, 0);
    near(state.snapshot(2048).xMm, -1);
    same(state.anchor(request, 2048).state, original.state);
    near(state.snapshot(2048).xMm, -1);

    const Request next{"next", "boot-a", "calibration", 83};
    assert(state.anchor(next, 2048).accepted);
    const auto anchored = state.snapshot(2048);
    WifiReconnectPolicy wifi;
    wifi.connected(0);
    wifi.disconnected(100);
    assert(wifi.retry(1100, false));
    // The encoder continues while disconnected; neither retry nor reconnect
    // enters beginBoot(). The post-reconnect count carries that movement.
    wifi.connected(2000);
    auto continued = state.snapshot(2560);
    assert(continued.bootId == anchored.bootId && continued.referenceId == anchored.referenceId);
    assert(continued.revision == anchored.revision);
    near(continued.xMm, 82);
    same(state.anchor(next, 2560).state, anchored);
    near(state.snapshot(2560).xMm, 82);

    state.beginBoot("boot-b", true); // Actual reset, restored direction only.
    const auto rebooted = state.snapshot(0);
    assert(rebooted.bootId == "boot-b" && rebooted.referenceId.empty());
    assert(rebooted.revision == 0 && rebooted.inverted);
    near(rebooted.xMm, 0);
    assert(!state.anchor(next, 0).accepted); // Delayed packet from prior boot.
    assert(state.anchor({"next", "boot-b", "calibration", 83}, 0).accepted);
    assert(state.snapshot(0).revision == 1); // Old receipts were cleared.
}

static void boundedCache() {
    State state;
    state.beginBoot("boot", false);
    for (size_t i = 0; i < RecentRequests; ++i)
        assert(state.anchor({std::to_string(i), "boot", "frame", double(i)}, int64_t(i)).accepted);
    const auto before = state.snapshot(200);
    for (size_t i = 0; i < RecentRequests; ++i) {
        const auto ack = state.anchor({std::to_string(i), "boot", "frame", double(i)}, 200);
        assert(ack.accepted && ack.state.revision == i + 1);
    }
    same(state.snapshot(200), before);
    assert(state.anchor({"extra", "boot", "frame", -10}, 200).accepted);
    assert(state.anchor({"1", "boot", "frame", 1}, 300).state.revision == 2);
    // Bounded FIFO: only the oldest receipt was evicted, as documented.
    assert(state.anchor({"0", "boot", "frame", 0}, 300).state.revision == RecentRequests + 2);
}

int main() {
    anchoring();
    validationAndRetry();
    legacyAndContinuity();
    boundedCache();
    puts("X reference: PASS (signed/asymmetric anchors, inversion, validation, receipts, reboot/Wi-Fi continuity)");
}
