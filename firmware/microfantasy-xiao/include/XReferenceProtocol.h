#pragma once

#include "XReference.h"
#include <ArduinoJson.h>
#include <cstdio>
#include <cstring>

// Uses the same ArduinoJson version in firmware and native wire-contract tests.
namespace XReferenceProtocol {
constexpr size_t MaxCommandBytes = 2048; // Includes three fully escaped 80-byte IDs.

inline bool readId(JsonVariantConst value, std::string& id) {
    if (!value.is<JsonString>()) return false;
    const JsonString text = value.as<JsonString>();
    if (!text.size() || text.size() > XReference::MaxIdBytes) return false;
    id.assign(text.c_str(), text.size());
    return XReference::validId(id);
}

// Commands are flat JSON objects with scalar values. ArduinoJson also accepts
// non-JSON syntax (single quotes, unquoted keys, some numbers) and trailing data.
// Check the small wire grammar first; ArduinoJson still owns decoding/Unicode.
class CommandShape {
public:
    CommandShape(const char* data, size_t length) : data_(data), length_(length) {}
    bool valid(size_t& fields) {
        fields = 0;
        whitespace();
        if (!take('{')) return false;
        whitespace();
        if (!take('}')) {
            do {
                whitespace();
                if (!string()) return false;
                whitespace();
                if (!take(':')) return false;
                whitespace();
                if (!value()) return false;
                ++fields;
                whitespace();
            } while (take(','));
            if (!take('}')) return false;
        }
        whitespace();
        return at_ == length_;
    }
private:
    const char* data_;
    size_t length_, at_ = 0;
    char peek() const { return at_ < length_ ? data_[at_] : '\0'; }
    bool take(char c) {
        if (at_ == length_ || data_[at_] != c) return false;
        ++at_;
        return true;
    }
    void whitespace() {
        while (peek() == ' ' || peek() == '\t' || peek() == '\n' || peek() == '\r') ++at_;
    }
    bool digit() const { return peek() >= '0' && peek() <= '9'; }
    bool string() {
        if (!take('"')) return false;
        while (at_ < length_) {
            const unsigned char c = static_cast<unsigned char>(data_[at_++]);
            if (c == '"') return true;
            if (c < 0x20) return false;
            if (c != '\\') continue;
            if (at_ == length_) return false;
            const char escaped = data_[at_++];
            if (escaped == 'u') {
                for (int i = 0; i < 4; ++i) {
                    const char hex = peek();
                    if (!digit() && !(hex >= 'a' && hex <= 'f') && !(hex >= 'A' && hex <= 'F')) return false;
                    ++at_;
                }
            } else if (!escaped || !std::strchr("\"\\/bfnrt", escaped)) return false;
        }
        return false;
    }
    bool literal(const char* text) {
        while (*text) if (!take(*text++)) return false;
        return true;
    }
    bool value() {
        if (peek() == '"') return string();
        if (peek() == 't') return literal("true");
        if (peek() == 'f') return literal("false");
        if (peek() == 'n') return literal("null");
        take('-');
        if (!take('0')) {
            if (!digit()) return false;
            while (digit()) ++at_;
        }
        if (take('.')) {
            if (!digit()) return false;
            while (digit()) ++at_;
        }
        if (take('e') || take('E')) {
            if (!take('+')) take('-');
            if (!digit()) return false;
            while (digit()) ++at_;
        }
        return true;
    }
};

inline const char* parse(JsonDocument& doc, const char* data, size_t length) {
    if (length > MaxCommandBytes) return "payload_too_large";
    size_t fields = 0;
    if (!CommandShape(data, length).valid(fields) ||
        deserializeJson(doc, data, length, DeserializationOption::NestingLimit(1)) ||
        !doc.is<JsonObject>() || doc.size() != fields) return "invalid_json";
    // A duplicate (even an escaped equivalent key) reduces the decoded size.
    return nullptr;
}

inline XReference::Ack anchor(XReference::State& state, JsonVariantConst doc,
                              int64_t rawCount) {
    XReference::Request request;
    if (!readId(doc["request_id"], request.requestId))
        return state.reject("", "invalid_request_id", rawCount);
    if (!doc.is<JsonObjectConst>() || doc.size() != 5 ||
        !doc["type"].is<JsonString>() || doc["type"] != "set_x_reference")
        return state.reject(request.requestId, "invalid_command", rawCount);
    if (!readId(doc["boot_id"], request.bootId))
        return state.reject(request.requestId, "invalid_boot_id", rawCount);
    if (!readId(doc["reference_id"], request.referenceId))
        return state.reject(request.requestId, "invalid_reference_id", rawCount);
    // is<double>() accepts JSON integers/floats, never bool/string/null.
    if (!doc["x_mm"].is<double>())
        return state.reject(request.requestId, "invalid_x_mm", rawCount);
    request.xMm = doc["x_mm"].as<double>();
    return state.anchor(request, rawCount);
}

inline void writeState(JsonDocument& doc, const XReference::Snapshot& state) {
    doc["boot_id"] = state.bootId;
    if (state.referenceId.empty()) doc["reference_id"] = nullptr;
    else doc["reference_id"] = state.referenceId;
    doc["reference_revision"] = state.revision;
}

inline void writeCapabilities(JsonDocument& doc) {
    doc["capabilities"].to<JsonArray>().add("set_x_reference");
}

inline void writeCoordinate(JsonDocument& doc, double xMm) {
    // ArduinoJson stores exactly-representable doubles as floats, then prints
    // fewer digits. Keep encoder resolution and round-trip the accepted double.
    char number[32];
    std::snprintf(number, sizeof(number), "%.17g", xMm);
    doc["x_mm"] = serialized(std::string(number));
}

inline void writePosition(JsonDocument& doc, const XReference::Snapshot& state,
                          uint32_t timestamp) {
    doc["type"] = "position";
    writeState(doc, state);
    writeCoordinate(doc, state.xMm);
    doc["timestamp"] = timestamp;
}

inline void writeAck(JsonDocument& doc, const XReference::Ack& ack) {
    doc["type"] = "reference_ack";
    doc["request_id"] = ack.requestId;
    doc["accepted"] = ack.accepted;
    writeState(doc, ack.state);
    writeCoordinate(doc, ack.state.xMm);
    if (ack.error) doc["error"] = ack.error;
}
}
