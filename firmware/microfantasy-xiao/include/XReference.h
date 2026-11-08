#pragma once

#include "PositionMath.h"
#include <array>
#include <cmath>
#include <string>

// RAM-only coordinate state. The Arduino loop is its sole owner; neither the
// encoder ISR nor Wi-Fi events may mutate it. No hardware/storage dependencies.
namespace XReference {
constexpr size_t MaxIdBytes = 80;
constexpr size_t RecentRequests = 16;
constexpr double MaxAnchorMm = 10000.0;

inline bool validId(const std::string& id) {
    if (id.empty() || id.size() > MaxIdBytes) return false;
    // Shared with Flutter: ^[A-Za-z0-9_.:-]{1,80}$ (no user-entered IDs).
    for (unsigned char c : id) {
        if (!((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
              (c >= '0' && c <= '9') || c == '_' || c == '.' || c == ':' || c == '-'))
            return false;
    }
    return true;
}

inline bool validBootId(const std::string& id) {
    return validId(id);
}

struct Request {
    std::string requestId;
    std::string bootId;
    std::string referenceId;
    double xMm;
};

struct Snapshot {
    std::string bootId;
    std::string referenceId; // Empty is serialized as JSON null, never "".
    uint64_t revision;
    double xMm;
    bool inverted;
};

struct Ack {
    std::string requestId;
    bool accepted;
    Snapshot state;
    const char* error; // nullptr on success; static error codes otherwise.
};

class State {
public:
    // Called once per firmware boot, never on transport connect/disconnect.
    void beginBoot(const std::string& bootId, bool inverted) {
        bootId_ = bootId;
        referenceId_.clear();
        revision_ = 0;
        originCount_ = 0;
        offsetMm_ = 0;
        inverted_ = inverted;
        for (auto& entry : recent_) entry.used = false;
        next_ = 0;
    }

    Snapshot snapshot(int64_t rawCount) const {
        return {bootId_, referenceId_, revision_,
                positionMm(rawCount, originCount_, inverted_) +
                    (inverted_ ? -offsetMm_ : offsetMm_), inverted_};
    }

    Ack reject(const std::string& requestId, const char* error,
               int64_t rawCount) const {
        return {validId(requestId) ? requestId : "", false,
                snapshot(rawCount), error};
    }

    Ack anchor(const Request& request, int64_t rawCount) {
        if (!validId(request.requestId))
            return reject("", "invalid_request_id", rawCount);
        if (!validBootId(request.bootId))
            return reject(request.requestId, "invalid_boot_id", rawCount);
        if (!validId(request.referenceId))
            return reject(request.requestId, "invalid_reference_id", rawCount);
        if (!std::isfinite(request.xMm) || std::abs(request.xMm) > MaxAnchorMm)
            return reject(request.requestId, "unsupported_x", rawCount);
        if (request.bootId != bootId_)
            return reject(request.requestId, "wrong_boot", rawCount);

        for (const auto& entry : recent_) {
            if (!entry.used || entry.request.requestId != request.requestId) continue;
            if (entry.request.bootId != request.bootId ||
                entry.request.referenceId != request.referenceId ||
                entry.request.xMm != request.xMm)
                return reject(request.requestId, "request_id_conflict", rawCount);
            // Return the ORIGINAL ack even after movement/zero/direction/another
            // anchor. This is a receipt, not the current telemetry snapshot.
            return entry.ack;
        }

        // Preserve the physical count and fractional coordinates. Keeping an
        // integer pivot also preserves one-count resolution after long travel.
        originCount_ = rawCount;
        offsetMm_ = inverted_ ? -request.xMm : request.xMm;
        referenceId_ = request.referenceId;
        ++revision_;
        Ack ack{request.requestId, true, snapshot(rawCount), nullptr};
        auto& entry = recent_[next_];
        entry.used = true;
        entry.request = request;
        entry.ack = ack;
        next_ = (next_ + 1) % RecentRequests;
        return ack;
    }

    void zero(int64_t rawCount) {
        originCount_ = rawCount;
        offsetMm_ = 0;
        invalidate();
    }

    // Call only after persisting a changed direction successfully. As before,
    // reversing direction negates the entire coordinate, including its offset.
    void setDirection(bool inverted) {
        if (inverted == inverted_) return;
        inverted_ = inverted;
        invalidate();
    }

private:
    struct Cached {
        bool used = false;
        Request request;
        Ack ack;
    };
    std::string bootId_, referenceId_;
    uint64_t revision_ = 0;
    int64_t originCount_ = 0;
    double offsetMm_ = 0; // In the physical (uninverted) coordinate system.
    bool inverted_ = false;
    std::array<Cached, RecentRequests> recent_;
    size_t next_ = 0;

    void invalidate() {
        referenceId_.clear();
        ++revision_;
        // Keep receipts: a retry must never undo a subsequent command.
    }
};
}
