use crate::ui::{DisplaySchema, PluginBehavior, UISchema};
use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum PluginType {
    Standard,
    Device,
    Computational,
}

impl Default for PluginType {
    fn default() -> Self {
        Self::Standard
    }
}

impl PluginType {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Standard => "standard",
            Self::Device => "device",
            Self::Computational => "computational",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum IntegrationMethod {
    RungeKutta,
    Euler,
    Custom,
}

impl IntegrationMethod {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::RungeKutta => "runge_kutta",
            Self::Euler => "euler",
            Self::Custom => "custom",
        }
    }
}

pub trait PluginDescriptor {
    fn name() -> &'static str;
    fn kind() -> &'static str;

    fn plugin_type() -> PluginType {
        PluginType::Standard
    }

    fn inputs() -> &'static [&'static str];
    fn outputs() -> &'static [&'static str];

    fn internal_variables() -> &'static [&'static str] {
        &[]
    }

    fn fixed_vars() -> Vec<(&'static str, Value)> {
        Vec::new()
    }

    fn default_vars() -> Vec<(&'static str, Value)> {
        Vec::new()
    }

    fn behavior() -> PluginBehavior {
        PluginBehavior::default()
    }

    fn integration_method() -> Option<IntegrationMethod> {
        match Self::plugin_type() {
            PluginType::Computational => Some(IntegrationMethod::RungeKutta),
            _ => None,
        }
    }

    fn display_schema() -> DisplaySchema {
        DisplaySchema {
            outputs: Self::outputs().iter().map(|s| (*s).to_string()).collect(),
            inputs: Self::inputs().iter().map(|s| (*s).to_string()).collect(),
            variables: Self::internal_variables()
                .iter()
                .map(|s| (*s).to_string())
                .collect(),
        }
    }
}

pub trait PluginRuntime {
    fn set_config_value(&mut self, _key: &str, _value: &Value) {}

    fn set_input_value(&mut self, _key: &str, _value: f64) {}

    fn ui_schema(&self) -> Option<UISchema> {
        None
    }

    fn process_tick(&mut self, tick: u64, period_seconds: f64);

    fn get_output_value(&self, key: &str) -> f64;

    fn get_internal_value(&self, _key: &str) -> Option<f64> {
        None
    }
}

#[macro_export]
macro_rules! export_plugin {
    ($plugin_ty:ty) => {
        extern "C" fn create(_id: u64) -> *mut std::ffi::c_void {
            let instance: $plugin_ty = Default::default();
            Box::into_raw(Box::new(instance)) as *mut std::ffi::c_void
        }

        extern "C" fn destroy(handle: *mut std::ffi::c_void) {
            if handle.is_null() {
                return;
            }
            unsafe {
                drop(Box::from_raw(handle as *mut $plugin_ty));
            }
        }

        extern "C" fn meta_json(_handle: *mut std::ffi::c_void) -> $crate::PluginString {
            static META_JSON: std::sync::OnceLock<String> = std::sync::OnceLock::new();
            let json = META_JSON.get_or_init(|| {
                let default_vars = <$plugin_ty as $crate::api::PluginDescriptor>::default_vars();
                let fixed_vars = <$plugin_ty as $crate::api::PluginDescriptor>::fixed_vars();
                serde_json::json!({
                    "name": <$plugin_ty as $crate::api::PluginDescriptor>::name(),
                    "kind": <$plugin_ty as $crate::api::PluginDescriptor>::kind(),
                    "plugin_type": <$plugin_ty as $crate::api::PluginDescriptor>::plugin_type().as_str(),
                    "integration_method": <$plugin_ty as $crate::api::PluginDescriptor>::integration_method()
                        .map(|m| m.as_str()),
                    "fixed_vars": fixed_vars,
                    "default_vars": default_vars
                })
                .to_string()
            });
            $crate::PluginString::from_string(json.clone())
        }

        extern "C" fn inputs_json(_handle: *mut std::ffi::c_void) -> $crate::PluginString {
            static INPUTS_JSON: std::sync::OnceLock<String> = std::sync::OnceLock::new();
            let json = INPUTS_JSON.get_or_init(|| {
                serde_json::to_string(&<$plugin_ty as $crate::api::PluginDescriptor>::inputs())
                    .unwrap_or_default()
            });
            $crate::PluginString::from_string(json.clone())
        }

        extern "C" fn outputs_json(_handle: *mut std::ffi::c_void) -> $crate::PluginString {
            static OUTPUTS_JSON: std::sync::OnceLock<String> = std::sync::OnceLock::new();
            let json = OUTPUTS_JSON.get_or_init(|| {
                serde_json::to_string(&<$plugin_ty as $crate::api::PluginDescriptor>::outputs())
                    .unwrap_or_default()
            });
            $crate::PluginString::from_string(json.clone())
        }

        extern "C" fn behavior_json(_handle: *mut std::ffi::c_void) -> $crate::PluginString {
            static BEHAVIOR_JSON: std::sync::OnceLock<String> = std::sync::OnceLock::new();
            let json = BEHAVIOR_JSON.get_or_init(|| {
                let behavior = <$plugin_ty as $crate::api::PluginDescriptor>::behavior();
                serde_json::to_string(&behavior).unwrap_or_default()
            });
            $crate::PluginString::from_string(json.clone())
        }

        extern "C" fn display_schema_json(_handle: *mut std::ffi::c_void) -> $crate::PluginString {
            static DISPLAY_SCHEMA_JSON: std::sync::OnceLock<String> = std::sync::OnceLock::new();
            let json = DISPLAY_SCHEMA_JSON.get_or_init(|| {
                let schema = <$plugin_ty as $crate::api::PluginDescriptor>::display_schema();
                serde_json::to_string(&schema).unwrap_or_default()
            });
            $crate::PluginString::from_string(json.clone())
        }

        extern "C" fn ui_schema_json(handle: *mut std::ffi::c_void) -> $crate::PluginString {
            if handle.is_null() {
                return $crate::PluginString::from_string(String::new());
            }
            let instance = unsafe { &mut *(handle as *mut $plugin_ty) };
            let schema = <$plugin_ty as $crate::api::PluginRuntime>::ui_schema(instance);
            let json = match schema {
                Some(schema) => serde_json::to_string(&schema).unwrap_or_default(),
                None => String::new(),
            };
            $crate::PluginString::from_string(json)
        }

        extern "C" fn set_config_json(handle: *mut std::ffi::c_void, data: *const u8, len: usize) {
            if handle.is_null() || data.is_null() || len == 0 {
                return;
            }
            let instance = unsafe { &mut *(handle as *mut $plugin_ty) };
            let slice = unsafe { std::slice::from_raw_parts(data, len) };
            if let Ok(map) =
                serde_json::from_slice::<serde_json::Map<String, serde_json::Value>>(slice)
            {
                for (k, v) in map {
                    <$plugin_ty as $crate::api::PluginRuntime>::set_config_value(instance, &k, &v);
                }
            }
        }

        extern "C" fn set_input(
            handle: *mut std::ffi::c_void,
            name: *const u8,
            len: usize,
            value: f64,
        ) {
            if handle.is_null() || name.is_null() || len == 0 {
                return;
            }
            let instance = unsafe { &mut *(handle as *mut $plugin_ty) };
            let slice = unsafe { std::slice::from_raw_parts(name, len) };
            if let Ok(key) = std::str::from_utf8(slice) {
                let v = if value.is_finite() { value } else { 0.0 };
                <$plugin_ty as $crate::api::PluginRuntime>::set_input_value(instance, key, v);
            }
        }

        extern "C" fn resolve_input_index(
            _handle: *mut std::ffi::c_void,
            name: *const u8,
            len: usize,
        ) -> i32 {
            if name.is_null() || len == 0 {
                return -1;
            }
            let slice = unsafe { std::slice::from_raw_parts(name, len) };
            let Ok(key) = std::str::from_utf8(slice) else {
                return -1;
            };
            static INPUT_INDEX: std::sync::OnceLock<
                std::collections::HashMap<&'static str, i32>,
            > = std::sync::OnceLock::new();
            let index = INPUT_INDEX.get_or_init(|| {
                <$plugin_ty as $crate::api::PluginDescriptor>::inputs()
                    .iter()
                    .enumerate()
                    .map(|(idx, key)| (*key, idx as i32))
                    .collect()
            });
            index.get(key).copied().unwrap_or(-1)
        }

        extern "C" fn set_input_by_index(handle: *mut std::ffi::c_void, index: usize, value: f64) {
            if handle.is_null() {
                return;
            }
            let Some(name) = <$plugin_ty as $crate::api::PluginDescriptor>::inputs().get(index) else {
                return;
            };
            let instance = unsafe { &mut *(handle as *mut $plugin_ty) };
            let v = if value.is_finite() { value } else { 0.0 };
            <$plugin_ty as $crate::api::PluginRuntime>::set_input_value(instance, name, v);
        }

        extern "C" fn process(handle: *mut std::ffi::c_void, tick: u64, period_seconds: f64) {
            if handle.is_null() {
                return;
            }
            let instance = unsafe { &mut *(handle as *mut $plugin_ty) };
            <$plugin_ty as $crate::api::PluginRuntime>::process_tick(instance, tick, period_seconds);
        }

        extern "C" fn get_output(
            handle: *mut std::ffi::c_void,
            name: *const u8,
            len: usize,
        ) -> f64 {
            if handle.is_null() || name.is_null() || len == 0 {
                return 0.0;
            }
            let instance = unsafe { &mut *(handle as *mut $plugin_ty) };
            let slice = unsafe { std::slice::from_raw_parts(name, len) };
            if let Ok(key) = std::str::from_utf8(slice) {
                static OUTPUT_KEYS: std::sync::OnceLock<
                    std::collections::HashSet<&'static str>,
                > = std::sync::OnceLock::new();
                let output_keys = OUTPUT_KEYS.get_or_init(|| {
                    <$plugin_ty as $crate::api::PluginDescriptor>::outputs()
                        .iter()
                        .copied()
                        .collect()
                });
                let out = <$plugin_ty as $crate::api::PluginRuntime>::get_output_value(instance, key);
                if output_keys.contains(key) {
                    return out;
                }
                if let Some(v) =
                    <$plugin_ty as $crate::api::PluginRuntime>::get_internal_value(instance, key)
                {
                    return v;
                }
            }
            0.0
        }

        extern "C" fn resolve_output_index(
            _handle: *mut std::ffi::c_void,
            name: *const u8,
            len: usize,
        ) -> i32 {
            if name.is_null() || len == 0 {
                return -1;
            }
            let slice = unsafe { std::slice::from_raw_parts(name, len) };
            let Ok(key) = std::str::from_utf8(slice) else {
                return -1;
            };
            static OUTPUT_INDEX: std::sync::OnceLock<
                std::collections::HashMap<&'static str, i32>,
            > = std::sync::OnceLock::new();
            let index = OUTPUT_INDEX.get_or_init(|| {
                <$plugin_ty as $crate::api::PluginDescriptor>::outputs()
                    .iter()
                    .enumerate()
                    .map(|(idx, key)| (*key, idx as i32))
                    .collect()
            });
            index.get(key).copied().unwrap_or(-1)
        }

        extern "C" fn get_output_by_index(handle: *mut std::ffi::c_void, index: usize) -> f64 {
            if handle.is_null() {
                return 0.0;
            }
            let Some(name) = <$plugin_ty as $crate::api::PluginDescriptor>::outputs().get(index) else {
                return 0.0;
            };
            let instance = unsafe { &mut *(handle as *mut $plugin_ty) };
            <$plugin_ty as $crate::api::PluginRuntime>::get_output_value(instance, name)
        }

        #[no_mangle]
        pub extern "C" fn rtsyn_plugin_abi_version() -> u32 {
            $crate::RTSYN_PLUGIN_ABI_VERSION
        }

        #[no_mangle]
        pub extern "C" fn rtsyn_plugin_api() -> *const $crate::PluginApi {
            static API: $crate::PluginApi = $crate::PluginApi {
                create,
                destroy,
                meta_json,
                inputs_json,
                outputs_json,
                behavior_json: Some(behavior_json),
                display_schema_json: Some(display_schema_json),
                ui_schema_json: Some(ui_schema_json),
                set_config_json,
                set_input,
                resolve_input_index: Some(resolve_input_index),
                set_input_by_index: Some(set_input_by_index),
                process,
                get_output,
                resolve_output_index: Some(resolve_output_index),
                get_output_by_index: Some(get_output_by_index),
            };
            &API as *const $crate::PluginApi
        }
    };
}
