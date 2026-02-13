#include "__CORE_HEADER_FILE__"
#include <cmath>
#include <cstdlib>
#include <cstring>

struct __CORE_STATE_TAG__ {
__C_STATE_FIELDS__
};

static int key_eq(const char* key, size_t len, const char* lit) {
    size_t n = std::strlen(lit);
    return (len == n) && (std::strncmp(key, lit, n) == 0);
}

extern "C" __CORE_STATE_TYPE__* __CORE_PREFIX___new(void) {
    auto* s = static_cast<__CORE_STATE_TYPE__*>(std::calloc(1, sizeof(__CORE_STATE_TYPE__)));
    if (s == nullptr) return nullptr;
__C_DEFAULT_FIELDS__
    return s;
}

extern "C" void __CORE_PREFIX___free(__CORE_STATE_TYPE__* s) {
    std::free(s);
}

extern "C" void __CORE_PREFIX___set_config(__CORE_STATE_TYPE__* s, const char* key, size_t len, double value) {
    if (s == nullptr || key == nullptr || !std::isfinite(value)) return;
__C_CONFIG_ARMS__
}

extern "C" void __CORE_PREFIX___set_input(__CORE_STATE_TYPE__* s, const char* name, size_t len, double value) {
    if (s == nullptr || name == nullptr || !std::isfinite(value)) return;
__C_INPUT_ARMS__
}

extern "C" void __CORE_PREFIX___process(__CORE_STATE_TYPE__* s, double period_seconds) {
    (void)period_seconds;
    if (s == nullptr) return;
__C_PROCESS_BODY__
}

extern "C" double __CORE_PREFIX___get_output(const __CORE_STATE_TYPE__* s, const char* name, size_t len) {
    if (s == nullptr || name == nullptr) return 0.0;
__C_OUTPUT_ARMS__
    return 0.0;
}
