#include "WifiSetupPolicy.h"
#include <assert.h>
#include <string.h>
#include <stdio.h>
using namespace WifiSetup;

static uint32_t connect(Policy& policy, uint32_t start = 0) {
    assert(policy.request(start));
    assert(policy.tick(start + 749) == Action::None); // HTTP response grace
    assert(policy.tick(start + 750) == Action::Scan);
    policy.scanned(start + 1750);
    assert(policy.tick(start + 1999) == Action::None);
    assert(policy.tick(start + 2000) == Action::Connect);
    return start + 2000;
}

int main() {
    Policy success;
    const auto at = connect(success);
    assert(!success.request(at + 1)); // no concurrent configuration
    assert(success.tick(at + 1, true, false) == Action::None); // old network
    assert(success.tick(at + 2, false, true, true) == Action::None); // no DHCP
    assert(success.tick(at + 3, true, true, true) == Action::Commit);
    assert(success.tick(at + 4, true, true, true) == Action::None); // save once
    assert(!success.busy());
    success.storageFailed();
    assert(strcmp(success.error, "storage_error") == 0);

    Policy steering;
    uint32_t now = connect(steering);
    assert(steering.tick(now + 25000, false, false, false, 203) == Action::Disconnect);
    assert(steering.tick(now + 26999) == Action::None);
    assert(steering.tick(now + 27000) == Action::Connect);
    assert(steering.attempt == 2);
    // A router can accept a later attempt. No manual restart is required.
    assert(steering.tick(now + 28000, true, true, true) == Action::Commit);

    Policy failed;
    now = connect(failed);
    for (int attempt = 1; attempt <= 3; ++attempt) {
        assert(failed.attempt == attempt);
        const auto action = failed.tick(now + 25000, false, false, false, 202);
        if (attempt < 3) {
            assert(action == Action::Disconnect);
            now += 27000;
            assert(failed.tick(now) == Action::Connect);
        } else assert(action == Action::Fail);
    }
    assert(strcmp(failed.error, "authentication_failed") == 0);
    assert(failed.tick(now + 60000, true, false) == Action::None); // no late commit
    assert(failed.request(now + 60001)); // retry after error is possible
    assert(strcmp(failed.error, "") == 0);

    Policy scanTimeout;
    assert(scanTimeout.request(0));
    assert(scanTimeout.tick(750) == Action::Scan);
    scanTimeout.tick(10750);
    assert(scanTimeout.tick(11000) == Action::Connect); // hidden / unavailable scan

    Policy rollover;
    connect(rollover, UINT32_MAX - 1000);
    assert(rollover.attempt == 1);
    assert(strcmp(connectionError(201, false), "network_not_found") == 0);
    assert(strcmp(connectionError(0, true), "address_timeout") == 0);
    assert(strcmp(connectionError(204, false), "authentication_failed") == 0);
    assert(strcmp(connectionError(200, false), "signal_lost") == 0);
    assert(strcmp(connectionError(0, false), "connection_timeout") == 0);
    puts("Wi-Fi setup: PASS (response grace, DHCP gate, retries, rollback gate, scan timeout, rollover)");
}
