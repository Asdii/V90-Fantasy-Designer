#pragma once
#include "Configuration.h"

namespace MachineNetwork {
void begin(Configuration& configuration);
void tick();
void reopenSetup();
const char* wifiStatus();
}
