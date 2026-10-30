#include "Encoder.h"
#include "PositionMath.h"
#include "soc/gpio_reg.h"
#include "soc/soc.h"
#include "driver/gpio.h"
#include "esp_intr_alloc.h"

namespace {
constexpr uint8_t PIN_A = 3, PIN_B = 4, PIN_DO = 5, PIN_CLK = 6, PIN_CS = 7;
portMUX_TYPE mux = portMUX_INITIALIZER_UNLOCKED;
volatile int64_t count = 0;
volatile uint32_t invalid = 0;
volatile uint8_t previous = 0;

inline __attribute__((always_inline)) uint8_t ab() {
    const uint32_t pins = REG_READ(GPIO_IN_REG); // One simultaneous A/B snapshot.
    return (((pins >> PIN_A) & 1) << 1) | ((pins >> PIN_B) & 1);
}

void IRAM_ATTR onEdge(void*) {
    portENTER_CRITICAL_ISR(&mux);
    const uint8_t next = ab();
    if ((previous ^ next) == 3) ++invalid; // Lost/invalid state: never guess direction.
    count += quadratureDelta(previous, next);
    previous = next;
    portEXIT_CRITICAL_ISR(&mux);
}
}

void Encoder::begin() {
    pinMode(PIN_CS, OUTPUT);
    digitalWrite(PIN_CS, LOW); // Unlock incremental outputs and leave enabled.
    pinMode(PIN_CLK, OUTPUT);
    digitalWrite(PIN_CLK, LOW);
    pinMode(PIN_DO, INPUT); // SSI deliberately unused: no CS/CLK traffic during counting.
    pinMode(PIN_A, INPUT);
    pinMode(PIN_B, INPUT);
    delay(100); // Sensor startup only, never wait for USB or Wi-Fi.
    previous = ab();
    // IRAM ISR service keeps counting while NVS temporarily disables flash cache.
    ESP_ERROR_CHECK(gpio_install_isr_service(ESP_INTR_FLAG_IRAM));
    ESP_ERROR_CHECK(gpio_set_intr_type(static_cast<gpio_num_t>(PIN_A), GPIO_INTR_ANYEDGE));
    ESP_ERROR_CHECK(gpio_set_intr_type(static_cast<gpio_num_t>(PIN_B), GPIO_INTR_ANYEDGE));
    ESP_ERROR_CHECK(gpio_isr_handler_add(static_cast<gpio_num_t>(PIN_A), onEdge, nullptr));
    ESP_ERROR_CHECK(gpio_isr_handler_add(static_cast<gpio_num_t>(PIN_B), onEdge, nullptr));
}

EncoderSample Encoder::read() {
    portENTER_CRITICAL(&mux);
    EncoderSample result{count, invalid};
    portEXIT_CRITICAL(&mux);
    return result;
}
