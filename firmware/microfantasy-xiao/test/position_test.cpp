#include "PositionMath.h"
#include <assert.h>
#include <stdio.h>

int main() {
    const uint8_t forward[] = {0, 1, 3, 2, 0};
    int64_t count = 0;
    for (int cycle = 0; cycle < 256; ++cycle)
        for (int i = 1; i < 5; ++i) count += quadratureDelta(forward[i-1], forward[i]);
    assert(count == 1024);
    assert(positionMm(count, 0, false) == 2.0);
    assert(positionMm(count, 0, true) == -2.0);
    assert(positionMm(count, count, false) == 0.0);
    assert(positionMm(count - 512, count, false) == -1.0);
    for (int cycle = 0; cycle < 512; ++cycle)
        for (int i = 4; i > 0; --i) count += quadratureDelta(forward[i], forward[i-1]);
    assert(count == -1024);
    assert(positionMm(count, 0, false) == -2.0);
    for (uint8_t before = 0; before < 4; ++before) {
        assert(quadratureDelta(before, before) == 0); // Stationary is not a fault.
        assert(quadratureDelta(before, before ^ 3) == 0); // Never invent lost counts.
        for (uint8_t after = 0; after < 4; ++after)
            assert(quadratureDelta(before, after) == -quadratureDelta(after, before));
    }
    assert(quadratureDelta(0, 1) + quadratureDelta(1, 0) == 0); // Reversal/bounce.
    const int64_t far = 5000000000LL;
    assert(positionMm(far + 512, far, false) == 1.0); // Beyond int32.
    puts("PASS: quadrature, direction, 512 counts/mm, zero, reversal, invalid states, int64");
}
