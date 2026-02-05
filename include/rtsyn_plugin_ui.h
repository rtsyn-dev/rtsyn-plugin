#ifndef RTSYN_PLUGIN_UI_H
#define RTSYN_PLUGIN_UI_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque types
typedef struct RTSynUISchema RTSynUISchema;
typedef struct RTSynConfigField RTSynConfigField;

// File mode constants
#define RTSYN_FILE_MODE_OPEN 0
#define RTSYN_FILE_MODE_SAVE 1
#define RTSYN_FILE_MODE_FOLDER 2

// Extendable inputs type constants
#define RTSYN_EXTENDABLE_NONE 0
#define RTSYN_EXTENDABLE_MANUAL 1
#define RTSYN_EXTENDABLE_AUTO 2

// === UI Schema Functions ===

/**
 * Create a new UI schema.
 * Must be freed with rtsyn_ui_schema_free().
 */
RTSynUISchema* rtsyn_ui_schema_new(void);

/**
 * Free a UI schema.
 */
void rtsyn_ui_schema_free(RTSynUISchema* schema);

/**
 * Add a field to the schema.
 * The field is consumed and should not be freed separately.
 */
void rtsyn_ui_schema_add_field(RTSynUISchema* schema, RTSynConfigField* field);

/**
 * Convert schema to JSON string.
 * Must be freed with rtsyn_string_free().
 */
char* rtsyn_ui_schema_to_json(const RTSynUISchema* schema);

// === Config Field Functions ===

/**
 * Create a text field.
 * default_value can be NULL.
 */
RTSynConfigField* rtsyn_ui_field_text(
    const char* key,
    const char* label,
    const char* default_value
);

/**
 * Create an integer field with min/max bounds.
 */
RTSynConfigField* rtsyn_ui_field_integer(
    const char* key,
    const char* label,
    int64_t default_value,
    int64_t min,
    int64_t max
);

/**
 * Create a float field with min/max bounds.
 */
RTSynConfigField* rtsyn_ui_field_float(
    const char* key,
    const char* label,
    double default_value,
    double min,
    double max
);

/**
 * Create a boolean field.
 * default_value: 0 = false, non-zero = true
 */
RTSynConfigField* rtsyn_ui_field_boolean(
    const char* key,
    const char* label,
    int default_value
);

/**
 * Create a file path field.
 * mode: RTSYN_FILE_MODE_OPEN, RTSYN_FILE_MODE_SAVE, or RTSYN_FILE_MODE_FOLDER
 * default_path can be NULL.
 */
RTSynConfigField* rtsyn_ui_field_filepath(
    const char* key,
    const char* label,
    const char* default_path,
    int mode
);

/**
 * Free a config field (only if not added to schema).
 */
void rtsyn_ui_field_free(RTSynConfigField* field);

// === Behavior Functions ===

/**
 * Create behavior JSON from parameters.
 * extendable_inputs_type: RTSYN_EXTENDABLE_NONE, MANUAL, or AUTO
 * extendable_inputs_pattern: pattern for auto mode (e.g., "in_{}"), can be NULL
 * Returns JSON string that must be freed with rtsyn_string_free().
 */
char* rtsyn_behavior_to_json(
    int supports_start_stop,
    int supports_restart,
    int extendable_inputs_type,
    const char* extendable_inputs_pattern,
    int loads_started,
    int connection_dependent
);

// === String Management ===

/**
 * Free a string returned by rtsyn functions.
 */
void rtsyn_string_free(char* s);

#ifdef __cplusplus
}
#endif

#endif // RTSYN_PLUGIN_UI_H
