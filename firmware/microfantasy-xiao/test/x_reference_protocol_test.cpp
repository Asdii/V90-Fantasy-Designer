#include "XReferenceProtocol.h"
#include <cassert>
#include <cstdio>
#include <limits>

using namespace XReference;
namespace Wire = XReferenceProtocol;

static std::string json(const JsonDocument& doc) {
    std::string result;
    serializeJson(doc, result);
    return result;
}

static void request(JsonDocument& doc) {
    doc.clear();
    doc["type"] = "set_x_reference";
    doc["request_id"] = "request";
    doc["boot_id"] = "boot";
    doc["reference_id"] = "calibration";
    doc["x_mm"] = -37.25;
}

static Ack send(State& state, const std::string& payload, int64_t count) {
    JsonDocument doc;
    const char* error = Wire::parse(doc, payload.data(), payload.size());
    if (error) return state.reject("", error, count);
    return Wire::anchor(state, doc.as<JsonVariantConst>(), count);
}

static std::string receipt(const Ack& ack) {
    JsonDocument doc;
    Wire::writeAck(doc, ack);
    return json(doc);
}

static void rejectedWithoutMutation(State& state, const std::string& payload) {
    const auto before = state.snapshot(5000);
    const auto ack = send(state, payload, 5000);
    assert(!ack.accepted && ack.error);
    const auto after = state.snapshot(5000);
    assert(after.referenceId == before.referenceId && after.bootId == before.bootId);
    assert(after.xMm == before.xMm && after.revision == before.revision);
    assert(after.inverted == before.inverted);
    JsonDocument wire;
    assert(!deserializeJson(wire, receipt(ack)));
    assert(wire["type"] == "reference_ack" && wire["accepted"] == false);
    assert(wire["boot_id"] == before.bootId);
    assert(wire["reference_revision"].as<uint64_t>() == before.revision);
    assert(wire["x_mm"].as<double>() == before.xMm);
}

static void strictWireValidation() {
    State state;
    state.beginBoot("boot", false);
    JsonDocument doc;
    request(doc);
    assert(send(state, json(doc), 512).accepted);

    for (const char* field : {"request_id", "boot_id", "reference_id", "x_mm", "type"}) {
        request(doc); doc.remove(field);
        rejectedWithoutMutation(state, json(doc));
        request(doc); doc[field] = nullptr;
        rejectedWithoutMutation(state, json(doc));
        request(doc); doc[field] = true;
        rejectedWithoutMutation(state, json(doc));
        request(doc); doc[field].to<JsonArray>().add(1);
        rejectedWithoutMutation(state, json(doc));
    }
    for (const char* field : {"request_id", "boot_id", "reference_id"}) {
        request(doc); doc[field] = 7;
        rejectedWithoutMutation(state, json(doc));
        request(doc); doc[field] = "";
        rejectedWithoutMutation(state, json(doc));
        request(doc); doc[field] = std::string(81, 'a');
        rejectedWithoutMutation(state, json(doc));
        request(doc); doc[field] = std::string("a\0b", 3);
        rejectedWithoutMutation(state, json(doc));
        for (const char* id : {"with space", "slash/", "quote\"", "backslash\\", "line\n", "marco-\xc3\xb1"}) {
            request(doc); doc[field] = id;
            rejectedWithoutMutation(state, json(doc));
        }
    }
    request(doc); doc["boot_id"] = "old-boot";
    rejectedWithoutMutation(state, json(doc));
    request(doc); doc["type"] = std::string("set_x_reference\0suffix", 22);
    rejectedWithoutMutation(state, json(doc));
    request(doc); doc["x_mm"] = "0";
    rejectedWithoutMutation(state, json(doc));
    for (double x : {10000.001, -10000.001, std::numeric_limits<double>::infinity(),
                     std::numeric_limits<double>::quiet_NaN()}) {
        request(doc); doc["x_mm"] = x;
        rejectedWithoutMutation(state, json(doc));
    }
    request(doc); doc["extra"] = 1;
    rejectedWithoutMutation(state, json(doc));
    for (const char* payload : {
            "", "null", "[]", "{}", "{", "{\"type\":", "{\"type\":\"set_x_reference\"}",
            "{'type':'set_x_reference'}", "{type:\"set_x_reference\"}",
            "{\"x_mm\":+1}", "{\"x_mm\":01}", "{\"x_mm\":1.}", "{\"x_mm\":.1}",
            "{\"x_mm\":1e}", "{\"x_mm\":NaN}", "{\"x_mm\":Infinity}",
            "{\"type\":\"bad\\q\"}", "{\"type\":\"bad\\u12X4\"}",
            "{\"type\":\"line\nbreak\"}", "{\"type\":\"zero_x\",}"})
        rejectedWithoutMutation(state, payload);

    request(doc);
    const auto valid = json(doc);
    for (const std::string& suffix : {std::string("{}"), std::string("garbage"), std::string(1, '\0')})
        rejectedWithoutMutation(state, valid + suffix);
    rejectedWithoutMutation(state, valid.substr(0, valid.size() - 1) + ",\"x_mm\":0}");
    rejectedWithoutMutation(state, valid.substr(0, valid.size() - 1) + ",\"x_\\u006dm\":0}");
    rejectedWithoutMutation(state, std::string(Wire::MaxCommandBytes + 1, ' '));
    // Valid JSON but unsupported non-finite numeric result.
    rejectedWithoutMutation(state,
        "{\"type\":\"set_x_reference\",\"request_id\":\"new\",\"boot_id\":\"boot\",\"reference_id\":\"frame\",\"x_mm\":1e999}");
    assert(send(state, " \r\n\t" + valid + " \t\n", 1000).accepted);
}

static void snapshotsAndReceipts() {
    State state;
    state.beginBoot("boot", false);
    JsonDocument status, position;
    auto snap = state.snapshot(0);
    Wire::writeState(status, snap);
    Wire::writeCapabilities(status);
    Wire::writePosition(position, snap, 0);
    assert(status["reference_id"].isNull() && status["reference_revision"] == 0);
    assert(status["capabilities"].size() == 1 && status["capabilities"][0] == "set_x_reference");
    assert(position["reference_id"].isNull());
    assert(json(position).find("\"reference_id\":null") != std::string::npos);

    JsonDocument doc;
    request(doc);
    const auto payload = json(doc);
    const auto accepted = send(state, payload, 512);
    const auto originalAck = receipt(accepted);
    assert(accepted.accepted);
    assert(originalAck.find("\"error\"") == std::string::npos);
    assert(receipt(send(state, payload, 1024)) == originalAck); // Byte-identical ack.
    assert(state.snapshot(1024).xMm == -36.25);
    request(doc); doc["reference_id"] = "other";
    rejectedWithoutMutation(state, json(doc));
    request(doc); doc["x_mm"] = 0;
    rejectedWithoutMutation(state, json(doc));

    snap = state.snapshot(1024); // One capture, used by both outgoing messages.
    state.zero(1024); // Writers must not accidentally read newer live state.
    status.clear(); position.clear();
    Wire::writeState(status, snap);
    Wire::writeCapabilities(status);
    Wire::writePosition(position, snap, 1234);
    const auto positionBody = json(position);
    assert(!deserializeJson(position, positionBody));
    assert(status["boot_id"] == position["boot_id"]);
    assert(status["reference_id"] == position["reference_id"]);
    assert(status["reference_revision"] == position["reference_revision"]);
    assert(position["x_mm"] == -36.25 && position["timestamp"] == 1234);
    assert(receipt(send(state, payload, 2048)) == originalAck);
    assert(state.snapshot(2048).referenceId.empty() && state.snapshot(2048).revision == 2);

    JsonDocument current;
    Wire::writePosition(current, state.snapshot(2048), UINT32_MAX);
    const auto currentBody = json(current);
    assert(!deserializeJson(current, currentBody));
    assert(current["reference_id"].isNull() && current["reference_revision"] == 2);
    assert(current["x_mm"] == 2);
    assert(current["timestamp"].as<uint32_t>() == UINT32_MAX);
}

static void maximumAndEscapedIds() {
    State state;
    const std::string boot(80, 'b');
    state.beginBoot(boot, true);
    // All three IDs can be 80 bytes, including JSON escape expansion. The old
    // 256-byte command limit and 128-byte position buffer cannot carry this.
    std::string escaped;
    for (int i = 0; i < 80; ++i) escaped += "\\u0062";
    const auto payload = "{\"type\":\"set_x_reference\",\"request_id\":\"" + escaped +
        "\",\"boot_id\":\"" + escaped + "\",\"reference_id\":\"" + escaped + "\",\"x_mm\":-10000}";
    assert(payload.size() > 256 && payload.size() <= Wire::MaxCommandBytes);
    const auto ack = send(state, payload, 5000);
    assert(ack.accepted && ack.requestId == boot && ack.state.referenceId == boot);
    assert(ack.state.xMm == -10000);
    JsonDocument position;
    Wire::writePosition(position, state.snapshot(5001), 10);
    JsonDocument roundtrip;
    assert(!deserializeJson(roundtrip, json(position)));
    assert(roundtrip["boot_id"] == boot && roundtrip["reference_id"] == boot);

    state.beginBoot("boot", false);
    const auto special = send(state,
        "{\"type\":\"set_x_reference\",\"request_id\":\"Request_1.:\\u002d\",\"boot_id\":\"boot\","
        "\"reference_id\":\"Frame-2._:3\",\"x_mm\":1.25e+2}", 0);
    assert(special.accepted && special.state.xMm == 125);
    JsonDocument wire;
    assert(!deserializeJson(wire, receipt(special)));
    assert(wire["request_id"] == "Request_1.:-");
    assert(wire["reference_id"] == "Frame-2._:3");

    for (double x : {-9999.765625, 0.12345678912345, 9999.765625}) {
        const auto precise = state.anchor({std::to_string(x), "boot", "frame", x}, 0);
        assert(precise.accepted);
        assert(!deserializeJson(wire, receipt(precise)));
        assert(wire["x_mm"].as<double>() == x);
        Wire::writePosition(position, state.snapshot(1), 42);
        assert(!deserializeJson(wire, json(position)));
        // Allow decoder rounding by one ULP, far below the app's 1e-6 tolerance.
        assert(std::abs(wire["x_mm"].as<double>() - (x + 1.0 / 512)) < 1e-10);
    }
}

int main() {
    strictWireValidation();
    snapshotsAndReceipts();
    maximumAndEscapedIds();
    puts("X reference wire contract: PASS (strict JSON, bounds, snapshots, nulls, capabilities, cached acks)");
}
