use serde::{Deserialize, Serialize};
use serde_json::Value;

pub mod prelude;
pub mod ui;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct PluginId(pub u64);

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct PortId(pub String);

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Port {
    pub id: PortId,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PluginMeta {
    pub name: String,
    pub fixed_vars: Vec<(String, Value)>,
    pub default_vars: Vec<(String, Value)>,
}

#[derive(Debug, Default)]
pub struct PluginContext {
    pub tick: u64,
    pub period_seconds: f64,
}

#[derive(thiserror::Error, Debug)]
pub enum PluginError {
    #[error("processing failed")]
    ProcessingFailed,
}

pub trait Plugin: Send {
    fn id(&self) -> PluginId;
    fn meta(&self) -> &PluginMeta;
    fn inputs(&self) -> &[Port];
    fn outputs(&self) -> &[Port];
    fn process(&mut self, ctx: &mut PluginContext) -> Result<(), PluginError>;

    // NEW: UI schema for configuration
    fn ui_schema(&self) -> Option<ui::UISchema> {
        None
    }

    // NEW: Plugin behavior flags
    fn behavior(&self) -> ui::PluginBehavior {
        ui::PluginBehavior::default()
    }

    // NEW: Connection behavior
    fn connection_behavior(&self) -> ui::ConnectionBehavior {
        ui::ConnectionBehavior::default()
    }

    // NEW: Dynamic input management
    fn on_input_added(&mut self, _port: &str) -> Result<(), PluginError> {
        Ok(())
    }

    fn on_input_removed(&mut self, _port: &str) -> Result<(), PluginError> {
        Ok(())
    }
}

pub trait DeviceDriver: Plugin {
    fn open(&mut self) -> Result<(), PluginError>;
    fn close(&mut self) -> Result<(), PluginError>;
}

pub trait ProcessingUnit: Plugin {}

pub trait EventLogger: Plugin {
    fn flush(&mut self) -> Result<(), PluginError>;
}

#[repr(C)]
pub struct PluginString {
    pub ptr: *mut u8,
    pub len: usize,
    pub cap: usize,
}

impl PluginString {
    pub fn from_string(value: String) -> Self {
        let mut bytes = value.into_bytes();
        let out = PluginString {
            ptr: bytes.as_mut_ptr(),
            len: bytes.len(),
            cap: bytes.capacity(),
        };
        std::mem::forget(bytes);
        out
    }

    pub unsafe fn into_string(self) -> String {
        let bytes = Vec::from_raw_parts(self.ptr, self.len, self.cap);
        String::from_utf8_lossy(&bytes).into_owned()
    }
}

#[no_mangle]
pub extern "C" fn rtsyn_plugin_string_free(value: PluginString) {
    if value.ptr.is_null() {
        return;
    }
    unsafe {
        let _ = Vec::from_raw_parts(value.ptr, value.len, value.cap);
    }
}

#[repr(C)]
pub struct PluginApi {
    pub create: extern "C" fn(id: u64) -> *mut std::ffi::c_void,
    pub destroy: extern "C" fn(handle: *mut std::ffi::c_void),
    pub meta_json: extern "C" fn(handle: *mut std::ffi::c_void) -> PluginString,
    pub inputs_json: extern "C" fn(handle: *mut std::ffi::c_void) -> PluginString,
    pub outputs_json: extern "C" fn(handle: *mut std::ffi::c_void) -> PluginString,
    pub behavior_json: Option<extern "C" fn(handle: *mut std::ffi::c_void) -> PluginString>,
    pub ui_schema_json: Option<extern "C" fn(handle: *mut std::ffi::c_void) -> PluginString>,
    pub set_config_json: extern "C" fn(handle: *mut std::ffi::c_void, data: *const u8, len: usize),
    pub set_input:
        extern "C" fn(handle: *mut std::ffi::c_void, name: *const u8, len: usize, value: f64),
    pub process: extern "C" fn(handle: *mut std::ffi::c_void, tick: u64, period_seconds: f64),
    pub get_output:
        extern "C" fn(handle: *mut std::ffi::c_void, name: *const u8, len: usize) -> f64,
}

pub const RTSYN_PLUGIN_API_SYMBOL: &str = "rtsyn_plugin_api";
