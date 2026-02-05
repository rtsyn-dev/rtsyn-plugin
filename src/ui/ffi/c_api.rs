use crate::ui::{ConfigField, ExtendableInputs, FileMode, PluginBehavior, UISchema};
use serde_json::Value;
use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int};
use std::ptr;

// Opaque types for C
#[repr(C)]
pub struct RTSynUISchema {
    _private: [u8; 0],
}

#[repr(C)]
pub struct RTSynConfigField {
    _private: [u8; 0],
}

// File mode enum for C
pub const RTSYN_FILE_MODE_OPEN: c_int = 0;
pub const RTSYN_FILE_MODE_SAVE: c_int = 1;
pub const RTSYN_FILE_MODE_FOLDER: c_int = 2;

// Field type enum for C
pub const RTSYN_FIELD_INTEGER: c_int = 0;
pub const RTSYN_FIELD_FLOAT: c_int = 1;
pub const RTSYN_FIELD_TEXT: c_int = 2;
pub const RTSYN_FIELD_BOOLEAN: c_int = 3;
pub const RTSYN_FIELD_FILEPATH: c_int = 4;
pub const RTSYN_FIELD_DYNAMIC_LIST: c_int = 5;

// === UI Schema Functions ===

#[no_mangle]
pub extern "C" fn rtsyn_ui_schema_new() -> *mut RTSynUISchema {
    let schema = Box::new(UISchema::new());
    Box::into_raw(schema) as *mut RTSynUISchema
}

#[no_mangle]
pub extern "C" fn rtsyn_ui_schema_free(schema: *mut RTSynUISchema) {
    if !schema.is_null() {
        unsafe {
            let _ = Box::from_raw(schema as *mut UISchema);
        }
    }
}

#[no_mangle]
pub extern "C" fn rtsyn_ui_schema_add_field(
    schema: *mut RTSynUISchema,
    field: *mut RTSynConfigField,
) {
    if schema.is_null() || field.is_null() {
        return;
    }
    unsafe {
        let schema = &mut *(schema as *mut UISchema);
        let field = Box::from_raw(field as *mut ConfigField);
        schema.fields.push(*field);
    }
}

#[no_mangle]
pub extern "C" fn rtsyn_ui_schema_to_json(schema: *const RTSynUISchema) -> *mut c_char {
    if schema.is_null() {
        return ptr::null_mut();
    }
    unsafe {
        let schema = &*(schema as *const UISchema);
        match serde_json::to_string(schema) {
            Ok(json) => match CString::new(json) {
                Ok(cstr) => cstr.into_raw(),
                Err(_) => ptr::null_mut(),
            },
            Err(_) => ptr::null_mut(),
        }
    }
}

// === Config Field Functions ===

#[no_mangle]
pub extern "C" fn rtsyn_ui_field_text(
    key: *const c_char,
    label: *const c_char,
    default_value: *const c_char,
) -> *mut RTSynConfigField {
    if key.is_null() || label.is_null() {
        return ptr::null_mut();
    }
    unsafe {
        let key = match CStr::from_ptr(key).to_str() {
            Ok(s) => s,
            Err(_) => return ptr::null_mut(),
        };
        let label = match CStr::from_ptr(label).to_str() {
            Ok(s) => s,
            Err(_) => return ptr::null_mut(),
        };
        
        let mut field = ConfigField::text(key, label);
        
        if !default_value.is_null() {
            if let Ok(s) = CStr::from_ptr(default_value).to_str() {
                field = field.default_value(Value::String(s.to_string()));
            }
        }
        
        Box::into_raw(Box::new(field)) as *mut RTSynConfigField
    }
}

#[no_mangle]
pub extern "C" fn rtsyn_ui_field_integer(
    key: *const c_char,
    label: *const c_char,
    default_value: i64,
    min: i64,
    max: i64,
) -> *mut RTSynConfigField {
    if key.is_null() || label.is_null() {
        return ptr::null_mut();
    }
    unsafe {
        let key = match CStr::from_ptr(key).to_str() {
            Ok(s) => s,
            Err(_) => return ptr::null_mut(),
        };
        let label = match CStr::from_ptr(label).to_str() {
            Ok(s) => s,
            Err(_) => return ptr::null_mut(),
        };
        
        let field = ConfigField::integer(key, label)
            .min(min)
            .max(max)
            .default_value(Value::from(default_value));
        
        Box::into_raw(Box::new(field)) as *mut RTSynConfigField
    }
}

#[no_mangle]
pub extern "C" fn rtsyn_ui_field_float(
    key: *const c_char,
    label: *const c_char,
    default_value: f64,
    min: f64,
    max: f64,
) -> *mut RTSynConfigField {
    if key.is_null() || label.is_null() {
        return ptr::null_mut();
    }
    unsafe {
        let key = match CStr::from_ptr(key).to_str() {
            Ok(s) => s,
            Err(_) => return ptr::null_mut(),
        };
        let label = match CStr::from_ptr(label).to_str() {
            Ok(s) => s,
            Err(_) => return ptr::null_mut(),
        };
        
        let field = ConfigField::float(key, label)
            .min_f(min)
            .max_f(max)
            .default_value(Value::from(default_value));
        
        Box::into_raw(Box::new(field)) as *mut RTSynConfigField
    }
}

#[no_mangle]
pub extern "C" fn rtsyn_ui_field_boolean(
    key: *const c_char,
    label: *const c_char,
    default_value: c_int,
) -> *mut RTSynConfigField {
    if key.is_null() || label.is_null() {
        return ptr::null_mut();
    }
    unsafe {
        let key = match CStr::from_ptr(key).to_str() {
            Ok(s) => s,
            Err(_) => return ptr::null_mut(),
        };
        let label = match CStr::from_ptr(label).to_str() {
            Ok(s) => s,
            Err(_) => return ptr::null_mut(),
        };
        
        let field = ConfigField::boolean(key, label)
            .default_value(Value::Bool(default_value != 0));
        
        Box::into_raw(Box::new(field)) as *mut RTSynConfigField
    }
}

#[no_mangle]
pub extern "C" fn rtsyn_ui_field_filepath(
    key: *const c_char,
    label: *const c_char,
    default_path: *const c_char,
    mode: c_int,
) -> *mut RTSynConfigField {
    if key.is_null() || label.is_null() {
        return ptr::null_mut();
    }
    unsafe {
        let key = match CStr::from_ptr(key).to_str() {
            Ok(s) => s,
            Err(_) => return ptr::null_mut(),
        };
        let label = match CStr::from_ptr(label).to_str() {
            Ok(s) => s,
            Err(_) => return ptr::null_mut(),
        };
        
        let file_mode = match mode {
            RTSYN_FILE_MODE_OPEN => FileMode::OpenFile,
            RTSYN_FILE_MODE_SAVE => FileMode::SaveFile,
            RTSYN_FILE_MODE_FOLDER => FileMode::SelectFolder,
            _ => FileMode::OpenFile,
        };
        
        let mut field = ConfigField::filepath(key, label).mode(file_mode);
        
        if !default_path.is_null() {
            if let Ok(s) = CStr::from_ptr(default_path).to_str() {
                field = field.default_value(Value::String(s.to_string()));
            }
        }
        
        Box::into_raw(Box::new(field)) as *mut RTSynConfigField
    }
}

#[no_mangle]
pub extern "C" fn rtsyn_ui_field_free(field: *mut RTSynConfigField) {
    if !field.is_null() {
        unsafe {
            let _ = Box::from_raw(field as *mut ConfigField);
        }
    }
}

// === Behavior Functions ===

#[no_mangle]
pub extern "C" fn rtsyn_behavior_to_json(
    supports_start_stop: c_int,
    supports_restart: c_int,
    extendable_inputs_type: c_int,
    extendable_inputs_pattern: *const c_char,
    loads_started: c_int,
    connection_dependent: c_int,
) -> *mut c_char {
    let extendable_inputs = match extendable_inputs_type {
        0 => ExtendableInputs::None,
        1 => ExtendableInputs::Manual,
        2 => {
            if extendable_inputs_pattern.is_null() {
                ExtendableInputs::Auto {
                    pattern: "in_{}".to_string(),
                }
            } else {
                unsafe {
                    let pattern = match CStr::from_ptr(extendable_inputs_pattern).to_str() {
                        Ok(s) => s.to_string(),
                        Err(_) => "in_{}".to_string(),
                    };
                    ExtendableInputs::Auto { pattern }
                }
            }
        }
        _ => ExtendableInputs::None,
    };

    let behavior = PluginBehavior {
        supports_start_stop: supports_start_stop != 0,
        supports_restart: supports_restart != 0,
        extendable_inputs,
        loads_started: loads_started != 0,
    };

    let combined = serde_json::json!({
        "behavior": behavior,
        "connection_dependent": connection_dependent != 0,
    });

    match serde_json::to_string(&combined) {
        Ok(json) => match CString::new(json) {
            Ok(cstr) => cstr.into_raw(),
            Err(_) => ptr::null_mut(),
        },
        Err(_) => ptr::null_mut(),
    }
}

// === String Management ===

#[no_mangle]
pub extern "C" fn rtsyn_string_free(s: *mut c_char) {
    if !s.is_null() {
        unsafe {
            let _ = CString::from_raw(s);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_ui_schema_lifecycle() {
        let schema = rtsyn_ui_schema_new();
        assert!(!schema.is_null());
        rtsyn_ui_schema_free(schema);
    }

    #[test]
    fn test_field_text() {
        let key = CString::new("name").unwrap();
        let label = CString::new("Name").unwrap();
        let default_val = CString::new("test").unwrap();

        let field = rtsyn_ui_field_text(key.as_ptr(), label.as_ptr(), default_val.as_ptr());
        assert!(!field.is_null());
        rtsyn_ui_field_free(field);
    }

    #[test]
    fn test_field_integer() {
        let key = CString::new("count").unwrap();
        let label = CString::new("Count").unwrap();

        let field = rtsyn_ui_field_integer(key.as_ptr(), label.as_ptr(), 10, 0, 100);
        assert!(!field.is_null());
        rtsyn_ui_field_free(field);
    }

    #[test]
    fn test_schema_to_json() {
        let schema = rtsyn_ui_schema_new();
        
        let key = CString::new("name").unwrap();
        let label = CString::new("Name").unwrap();
        let field = rtsyn_ui_field_text(key.as_ptr(), label.as_ptr(), ptr::null());
        
        rtsyn_ui_schema_add_field(schema, field);
        
        let json = rtsyn_ui_schema_to_json(schema);
        assert!(!json.is_null());
        
        unsafe {
            let json_str = CStr::from_ptr(json).to_str().unwrap();
            assert!(json_str.contains("name"));
            assert!(json_str.contains("Name"));
        }
        
        rtsyn_string_free(json);
        rtsyn_ui_schema_free(schema);
    }

    #[test]
    fn test_behavior_to_json() {
        let pattern = CString::new("in_{}").unwrap();
        let json = rtsyn_behavior_to_json(1, 0, 2, pattern.as_ptr(), 0, 1);
        assert!(!json.is_null());
        
        unsafe {
            let json_str = CStr::from_ptr(json).to_str().unwrap();
            assert!(json_str.contains("behavior"));
            assert!(json_str.contains("connection_dependent"));
        }
        
        rtsyn_string_free(json);
    }
}
