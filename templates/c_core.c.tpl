#include "__CORE_HEADER_FILE__"
#include <math.h>
#include <stdlib.h>
#include <string.h>

struct __CORE_STATE_TAG__ {
__C_STATE_FIELDS__
};

static int key_eq(const char* key, size_t len, const char* lit) {
    size_t n = strlen(lit);
    return (len == n) && (strncmp(key, lit, n) == 0);
}

__CORE_STATE_TYPE__* __CORE_PREFIX___new(void) {
    __CORE_STATE_TYPE__* s = (__CORE_STATE_TYPE__*)calloc(1, sizeof(*s));
    if (s == NULL) return NULL;
__C_DEFAULT_FIELDS__
    return s;
}

void __CORE_PREFIX___free(__CORE_STATE_TYPE__* s) {
    free(s);
}

void __CORE_PREFIX___set_config(__CORE_STATE_TYPE__* s, const char* key, size_t len, double value) {
    if (s == NULL || key == NULL || !isfinite(value)) return;
__C_CONFIG_ARMS__
}

void __CORE_PREFIX___set_input(__CORE_STATE_TYPE__* s, const char* name, size_t len, double value) {
    if (s == NULL || name == NULL || !isfinite(value)) return;
__C_INPUT_ARMS__
}

void __CORE_PREFIX___process(__CORE_STATE_TYPE__* s, double period_seconds) {
    (void)period_seconds;
    if (s == NULL) return;
__C_PROCESS_BODY__
}

double __CORE_PREFIX___get_output(const __CORE_STATE_TYPE__* s, const char* name, size_t len) {
    if (s == NULL || name == NULL) return 0.0;
__C_OUTPUT_ARMS__
    return 0.0;
}
