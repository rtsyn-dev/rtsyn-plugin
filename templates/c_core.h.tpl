#pragma once
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct __CORE_STATE_TAG__ __CORE_STATE_TYPE__;

__CORE_STATE_TYPE__* __CORE_PREFIX___new(void);
void __CORE_PREFIX___free(__CORE_STATE_TYPE__* state);
void __CORE_PREFIX___set_config(__CORE_STATE_TYPE__* state, const char* key, size_t len, double value);
void __CORE_PREFIX___set_input(__CORE_STATE_TYPE__* state, const char* name, size_t len, double value);
void __CORE_PREFIX___process(__CORE_STATE_TYPE__* state, double period_seconds);
double __CORE_PREFIX___get_output(const __CORE_STATE_TYPE__* state, const char* name, size_t len);

#ifdef __cplusplus
}
#endif
