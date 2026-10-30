#pragma once
#include <Arduino.h>

struct EncoderSample { int64_t count; uint32_t invalidTransitions; };
namespace Encoder {
void begin();
EncoderSample read();
}
