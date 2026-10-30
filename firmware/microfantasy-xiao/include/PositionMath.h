#pragma once
#include <stdint.h>

// AS5311 rev. 1.13: 256 cycles/channel = 1024 quadrature edges / 2 mm.
constexpr double COUNTS_PER_MM = 512.0;

// Pure, inlined integer logic also used by the ISR. No flash lookup table.
#ifdef _MSC_VER
__forceinline
#else
inline __attribute__((always_inline))
#endif
int8_t quadratureDelta(uint8_t before, uint8_t after) {
    const uint8_t changed = before ^ after;
    if (changed == 0 || changed == 3) return 0;
    return ((before & 1) ^ (after >> 1)) ? -1 : 1;
}

inline double positionMm(int64_t count, int64_t zero, bool inverted) {
    return static_cast<double>(count - zero) / COUNTS_PER_MM * (inverted ? -1.0 : 1.0);
}
