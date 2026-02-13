use rtsyn_plugin::prelude::*;
use serde_json::Value;
use std::ffi::c_void;

#[repr(C)]
struct __FFI_CORE_STRUCT__(c_void);

extern "C" {
    fn __CORE_PREFIX___new() -> *mut __FFI_CORE_STRUCT__;
    fn __CORE_PREFIX___free(state: *mut __FFI_CORE_STRUCT__);
    fn __CORE_PREFIX___set_config(
        state: *mut __FFI_CORE_STRUCT__,
        key: *const u8,
        len: usize,
        value: f64,
    );
    fn __CORE_PREFIX___set_input(
        state: *mut __FFI_CORE_STRUCT__,
        name: *const u8,
        len: usize,
        value: f64,
    );
    fn __CORE_PREFIX___process(state: *mut __FFI_CORE_STRUCT__, period_seconds: f64);
    fn __CORE_PREFIX___get_output(
        state: *const __FFI_CORE_STRUCT__,
        name: *const u8,
        len: usize,
    ) -> f64;
}

struct __RUST_STRUCT__ {
    state: *mut __FFI_CORE_STRUCT__,
}

impl Default for __RUST_STRUCT__ {
    fn default() -> Self {
        Self {
            state: unsafe { __CORE_PREFIX___new() },
        }
    }
}

impl Drop for __RUST_STRUCT__ {
    fn drop(&mut self) {
        if !self.state.is_null() {
            unsafe { __CORE_PREFIX___free(self.state) };
            self.state = std::ptr::null_mut();
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
        if self.state.is_null() {
            return;
        }
        if let Some(v) = value.as_f64() {
            unsafe { __CORE_PREFIX___set_config(self.state, key.as_ptr(), key.len(), v) };
        }
    }

    fn set_input_value(&mut self, key: &str, value: f64) {
        if self.state.is_null() {
            return;
        }
        let safe = if value.is_finite() { value } else { 0.0 };
        unsafe { __CORE_PREFIX___set_input(self.state, key.as_ptr(), key.len(), safe) };
    }

    fn process_tick(&mut self, _tick: u64, period_seconds: f64) {
        if self.state.is_null() {
            return;
        }
        unsafe { __CORE_PREFIX___process(self.state, period_seconds) };
    }

    fn get_output_value(&self, key: &str) -> f64 {
        if self.state.is_null() {
            return 0.0;
        }
        unsafe { __CORE_PREFIX___get_output(self.state, key.as_ptr(), key.len()) }
    }

    fn get_internal_value(&self, key: &str) -> Option<f64> {
        if self.state.is_null() {
            return None;
        }
        if <Self as PluginDescriptor>::internal_variables()
            .iter()
            .any(|k| *k == key)
        {
            Some(unsafe { __CORE_PREFIX___get_output(self.state, key.as_ptr(), key.len()) })
        } else {
            None
        }
    }
}

rtsyn_plugin::export_plugin!(__RUST_STRUCT__);
