#include "rtsyn_plugin_ui.h"
#include <stdlib.h>
#include <string.h>

// Example C plugin using the new UI API

typedef struct {
    uint64_t id;
    double amplitude;
    double frequency;
    char output_path[256];
} ExamplePlugin;

// Create plugin instance
void* create(uint64_t id) {
    ExamplePlugin* plugin = (ExamplePlugin*)malloc(sizeof(ExamplePlugin));
    if (!plugin) return NULL;
    
    plugin->id = id;
    plugin->amplitude = 1.0;
    plugin->frequency = 440.0;
    plugin->output_path[0] = '\0';
    
    return plugin;
}

// Destroy plugin instance
void destroy(void* instance) {
    if (instance) {
        free(instance);
    }
}

// Get plugin metadata
char* meta_json(void* instance) {
    const char* json = "{"
        "\"name\":\"Example C Plugin\","
        "\"fixed_vars\":[],"
        "\"default_vars\":["
            "{\"amplitude\":1.0},"
            "{\"frequency\":440.0}"
        "]"
    "}";
    return strdup(json);
}

// Get inputs
char* inputs_json(void* instance) {
    return strdup("[]");
}

// Get outputs
char* outputs_json(void* instance) {
    const char* json = "["
        "{\"id\":\"signal\"}"
    "]";
    return strdup(json);
}

// NEW: Get UI schema
char* ui_schema_json(void* instance) {
    // Create schema
    RTSynUISchema* schema = rtsyn_ui_schema_new();
    
    // Add amplitude field
    RTSynConfigField* amplitude_field = rtsyn_ui_field_float(
        "amplitude",
        "Amplitude",
        1.0,
        0.0,
        10.0
    );
    rtsyn_ui_schema_add_field(schema, amplitude_field);
    
    // Add frequency field
    RTSynConfigField* freq_field = rtsyn_ui_field_float(
        "frequency",
        "Frequency (Hz)",
        440.0,
        20.0,
        20000.0
    );
    rtsyn_ui_schema_add_field(schema, freq_field);
    
    // Add output path field
    RTSynConfigField* path_field = rtsyn_ui_field_filepath(
        "output_path",
        "Output File",
        NULL,
        RTSYN_FILE_MODE_SAVE
    );
    rtsyn_ui_schema_add_field(schema, path_field);
    
    // Convert to JSON
    char* json = rtsyn_ui_schema_to_json(schema);
    
    // Free schema (fields are consumed)
    rtsyn_ui_schema_free(schema);
    
    return json;
}

// NEW: Get behavior
char* behavior_json(void* instance) {
    return rtsyn_behavior_to_json(
        1,  // supports_start_stop
        1,  // supports_restart
        RTSYN_EXTENDABLE_NONE,  // extendable_inputs_type
        NULL,  // extendable_inputs_pattern
        1,  // loads_started
        0   // connection_dependent
    );
}

// Process function
int process(void* instance, uint64_t tick, double period_seconds) {
    // Processing logic here
    return 0;
}

// Set input value
void set_input(void* instance, const char* port, double value) {
    // No inputs for this example
}

// Get output value
double get_output(void* instance, const char* port) {
    ExamplePlugin* plugin = (ExamplePlugin*)instance;
    if (strcmp(port, "signal") == 0) {
        // Generate simple sine wave
        return plugin->amplitude;
    }
    return 0.0;
}

// Set config from JSON
int set_config_json(void* instance, const char* json) {
    // Parse JSON and update plugin config
    // For simplicity, this example doesn't parse JSON
    return 0;
}

// Export plugin API
#ifdef _WIN32
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default")))
#endif

typedef struct {
    void* (*create)(uint64_t);
    void (*destroy)(void*);
    char* (*meta_json)(void*);
    char* (*inputs_json)(void*);
    char* (*outputs_json)(void*);
    int (*process)(void*, uint64_t, double);
    void (*set_input)(void*, const char*, double);
    double (*get_output)(void*, const char*);
    int (*set_config_json)(void*, const char*);
    char* (*ui_schema_json)(void*);
    char* (*behavior_json)(void*);
} PluginApi;

EXPORT PluginApi rtsyn_plugin_api = {
    .create = create,
    .destroy = destroy,
    .meta_json = meta_json,
    .inputs_json = inputs_json,
    .outputs_json = outputs_json,
    .process = process,
    .set_input = set_input,
    .get_output = get_output,
    .set_config_json = set_config_json,
    .ui_schema_json = ui_schema_json,
    .behavior_json = behavior_json,
};
