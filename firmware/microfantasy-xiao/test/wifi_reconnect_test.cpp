#include "WifiReconnectPolicy.h"
#include <assert.h>
#include <stdio.h>

int main() {
    WifiReconnectPolicy policy;
    policy.started(0);
    assert(!policy.retry(1000, false)); // A connection in progress keeps its time.
    assert(!policy.retry(14999, false));
    assert(policy.retry(15000, false));

    policy.connected(16000);
    policy.disconnected(20000);
    assert(!policy.retry(20999, false));
    assert(policy.retry(21000, false)); // First retry after one second.
    policy.disconnected(22000);
    assert(!policy.retry(23999, false));
    assert(policy.retry(24000, false));
    policy.disconnected(25000);
    assert(!policy.retry(28999, false));
    assert(policy.retry(29000, false));
    policy.disconnected(30000);
    assert(!policy.retry(37999, false));
    assert(policy.retry(38000, false));

    policy.connected(40000); // A working connection restores fast recovery.
    policy.disconnected(41000);
    assert(policy.retry(42000, false));
    policy.started(50000);
    assert(!policy.retry(65000, true)); // Allow DHCP on an associated network.
    assert(policy.retry(75000, true));

    policy.connected(0xfffffff0u);
    policy.disconnected(0xfffffff0u);
    assert(!policy.retry(983u, false));
    assert(policy.retry(984u, false));
    puts("Wi-Fi reconnect policy passed");
}
