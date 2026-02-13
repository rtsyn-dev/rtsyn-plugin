use rtsyn_plugin::prelude::*;
use serde_json::Value;

#[derive(Debug)]
struct __RUST_STRUCT__ {
__STATE_FIELDS__
}

impl Default for __RUST_STRUCT__ {
    fn default() -> Self {
        Self {
__DEFAULT_FIELDS__
        }
    }
}

impl PluginDescriptor for __RUST_STRUCT__ {
    fn name() -> &'static str {
        "__PLUGIN_NAME__"
    }

    fn kind() -> &'static str {
        "__PLUGIN_KIND__"
    }

    fn plugin_type() -> PluginType {
        PluginType::__PLUGIN_TYPE_VARIANT__
    }

    fn inputs() -> &'static [&'static str] {
        &[__INPUT_ARRAY__]
    }

    fn outputs() -> &'static [&'static str] {
        &[__OUTPUT_ARRAY__]
    }

    fn internal_variables() -> &'static [&'static str] {
        &[__INTERNAL_ARRAY__]
    }

    fn default_vars() -> Vec<(&'static str, Value)> {
        vec![
__DEFAULT_VARS_VEC__
        ]
    }

    fn behavior() -> PluginBehavior {
        PluginBehavior {
            supports_start_stop: __SUPPORTS_START_STOP__,
            supports_restart: __SUPPORTS_RESTART__,
            supports_apply: __SUPPORTS_APPLY__,
            extendable_inputs: ExtendableInputs::None,
            loads_started: __LOADS_STARTED__,
            external_window: __EXTERNAL_WINDOW__,
            starts_expanded: __STARTS_EXPANDED__,
            start_requires_connected_inputs: serde_json::from_str(__REQ_INPUT_JSON__).unwrap_or_default(),
            start_requires_connected_outputs: serde_json::from_str(__REQ_OUTPUT_JSON__).unwrap_or_default(),
        }
    }
}

impl PluginRuntime for __RUST_STRUCT__ {
    fn set_config_value(&mut self, key: &str, value: &Value) {
        let Some(v) = value.as_f64() else { return; };
        match key {
__CONFIG_MATCH_ARMS__
            _ => {}
        }
    }

    fn set_input_value(&mut self, key: &str, value: f64) {
        match key {
__INPUT_MATCH_ARMS__
            _ => {}
        }
    }

    fn process_tick(&mut self, _tick: u64, period_seconds: f64) {
__PROCESS_BODY__
    }

    fn get_output_value(&self, key: &str) -> f64 {
        match key {
__OUTPUT_MATCH_ARMS__
            _ => 0.0,
        }
    }

    fn get_internal_value(&self, key: &str) -> Option<f64> {
        match key {
__INTERNAL_MATCH_ARMS__
            _ => None,
        }
    }
}

rtsyn_plugin::export_plugin!(__RUST_STRUCT__);
