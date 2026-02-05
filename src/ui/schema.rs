use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UISchema {
    pub fields: Vec<ConfigField>,
}

impl UISchema {
    pub fn new() -> Self {
        Self { fields: Vec::new() }
    }

    pub fn field(mut self, field: ConfigField) -> Self {
        self.fields.push(field);
        self
    }
}

impl Default for UISchema {
    fn default() -> Self {
        Self::new()
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConfigField {
    pub key: String,
    pub label: String,
    #[serde(rename = "type")]
    pub field_type: FieldType,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub default: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub hint: Option<String>,
}

impl ConfigField {
    pub fn new(key: impl Into<String>, label: impl Into<String>, field_type: FieldType) -> Self {
        Self {
            key: key.into(),
            label: label.into(),
            field_type,
            default: None,
            hint: None,
        }
    }

    pub fn text(key: impl Into<String>, label: impl Into<String>) -> Self {
        Self::new(
            key,
            label,
            FieldType::Text {
                multiline: false,
                max_length: None,
            },
        )
    }

    pub fn integer(key: impl Into<String>, label: impl Into<String>) -> Self {
        Self::new(
            key,
            label,
            FieldType::Integer {
                min: None,
                max: None,
                step: 1,
            },
        )
    }

    pub fn float(key: impl Into<String>, label: impl Into<String>) -> Self {
        Self::new(
            key,
            label,
            FieldType::Float {
                min: None,
                max: None,
                step: 0.1,
            },
        )
    }

    pub fn boolean(key: impl Into<String>, label: impl Into<String>) -> Self {
        Self::new(key, label, FieldType::Boolean)
    }

    pub fn filepath(key: impl Into<String>, label: impl Into<String>) -> Self {
        Self::new(
            key,
            label,
            FieldType::FilePath {
                mode: FileMode::OpenFile,
                filters: Vec::new(),
            },
        )
    }

    pub fn dynamic_list(key: impl Into<String>, label: impl Into<String>) -> Self {
        Self::new(
            key,
            label,
            FieldType::DynamicList {
                item_type: Box::new(FieldType::Text {
                    multiline: false,
                    max_length: None,
                }),
                add_label: "Add".to_string(),
            },
        )
    }

    pub fn default_value(mut self, value: Value) -> Self {
        self.default = Some(value);
        self
    }

    pub fn hint(mut self, hint: impl Into<String>) -> Self {
        self.hint = Some(hint.into());
        self
    }

    pub fn max_length(mut self, max: usize) -> Self {
        if let FieldType::Text { ref mut max_length, .. } = self.field_type {
            *max_length = Some(max);
        }
        self
    }

    pub fn multiline(mut self) -> Self {
        if let FieldType::Text { ref mut multiline, .. } = self.field_type {
            *multiline = true;
        }
        self
    }

    pub fn min(mut self, min: i64) -> Self {
        if let FieldType::Integer { min: ref mut m, .. } = self.field_type {
            *m = Some(min);
        }
        self
    }

    pub fn max(mut self, max: i64) -> Self {
        if let FieldType::Integer { max: ref mut m, .. } = self.field_type {
            *m = Some(max);
        }
        self
    }

    pub fn step(mut self, step: i64) -> Self {
        if let FieldType::Integer { step: ref mut s, .. } = self.field_type {
            *s = step;
        }
        self
    }

    pub fn min_f(mut self, min: f64) -> Self {
        if let FieldType::Float { min: ref mut m, .. } = self.field_type {
            *m = Some(min);
        }
        self
    }

    pub fn max_f(mut self, max: f64) -> Self {
        if let FieldType::Float { max: ref mut m, .. } = self.field_type {
            *m = Some(max);
        }
        self
    }

    pub fn step_f(mut self, step: f64) -> Self {
        if let FieldType::Float { step: ref mut s, .. } = self.field_type {
            *s = step;
        }
        self
    }

    pub fn mode(mut self, mode: FileMode) -> Self {
        if let FieldType::FilePath { mode: ref mut m, .. } = self.field_type {
            *m = mode;
        }
        self
    }

    pub fn filter(mut self, name: impl Into<String>, pattern: impl Into<String>) -> Self {
        if let FieldType::FilePath { ref mut filters, .. } = self.field_type {
            filters.push((name.into(), pattern.into()));
        }
        self
    }

    pub fn item_type(mut self, item_type: FieldType) -> Self {
        if let FieldType::DynamicList { item_type: ref mut it, .. } = self.field_type {
            *it = Box::new(item_type);
        }
        self
    }

    pub fn add_label(mut self, label: impl Into<String>) -> Self {
        if let FieldType::DynamicList { add_label: ref mut al, .. } = self.field_type {
            *al = label.into();
        }
        self
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "lowercase")]
pub enum FieldType {
    Integer {
        #[serde(skip_serializing_if = "Option::is_none")]
        min: Option<i64>,
        #[serde(skip_serializing_if = "Option::is_none")]
        max: Option<i64>,
        step: i64,
    },
    Float {
        #[serde(skip_serializing_if = "Option::is_none")]
        min: Option<f64>,
        #[serde(skip_serializing_if = "Option::is_none")]
        max: Option<f64>,
        step: f64,
    },
    Text {
        multiline: bool,
        #[serde(skip_serializing_if = "Option::is_none")]
        max_length: Option<usize>,
    },
    Boolean,
    FilePath {
        mode: FileMode,
        filters: Vec<(String, String)>,
    },
    DynamicList {
        item_type: Box<FieldType>,
        add_label: String,
    },
    Choice {
        options: Vec<String>,
    },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum FileMode {
    OpenFile,
    SaveFile,
    SelectFolder,
}

#[derive(Debug, Clone)]
pub struct Validator {
    pub validate_fn: fn(&Value) -> Result<(), String>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ui_schema_builder() {
        let schema = UISchema::new()
            .field(ConfigField::text("name", "Name"))
            .field(ConfigField::integer("count", "Count"));

        assert_eq!(schema.fields.len(), 2);
        assert_eq!(schema.fields[0].key, "name");
        assert_eq!(schema.fields[1].key, "count");
    }

    #[test]
    fn config_field_text() {
        let field = ConfigField::text("separator", "Separator")
            .default_value(Value::String(",".to_string()))
            .max_length(5)
            .hint("CSV separator");

        assert_eq!(field.key, "separator");
        assert_eq!(field.label, "Separator");
        assert_eq!(field.default, Some(Value::String(",".to_string())));
        assert_eq!(field.hint, Some("CSV separator".to_string()));

        if let FieldType::Text { max_length, .. } = field.field_type {
            assert_eq!(max_length, Some(5));
        } else {
            panic!("Expected Text field type");
        }
    }

    #[test]
    fn config_field_integer() {
        let field = ConfigField::integer("priority", "Priority")
            .min(0)
            .max(99)
            .step(1)
            .default_value(Value::from(10));

        if let FieldType::Integer { min, max, step } = field.field_type {
            assert_eq!(min, Some(0));
            assert_eq!(max, Some(99));
            assert_eq!(step, 1);
        } else {
            panic!("Expected Integer field type");
        }
    }

    #[test]
    fn config_field_float() {
        let field = ConfigField::float("amplitude", "Amplitude")
            .min_f(0.0)
            .max_f(10.0)
            .step_f(0.1);

        if let FieldType::Float { min, max, step } = field.field_type {
            assert_eq!(min, Some(0.0));
            assert_eq!(max, Some(10.0));
            assert_eq!(step, 0.1);
        } else {
            panic!("Expected Float field type");
        }
    }

    #[test]
    fn config_field_filepath() {
        let field = ConfigField::filepath("path", "Output File")
            .mode(FileMode::SaveFile)
            .filter("CSV files", "*.csv")
            .filter("All files", "*");

        if let FieldType::FilePath { mode, filters } = field.field_type {
            assert_eq!(mode, FileMode::SaveFile);
            assert_eq!(filters.len(), 2);
            assert_eq!(filters[0].0, "CSV files");
            assert_eq!(filters[0].1, "*.csv");
        } else {
            panic!("Expected FilePath field type");
        }
    }

    #[test]
    fn config_field_dynamic_list() {
        let field = ConfigField::dynamic_list("columns", "Columns")
            .item_type(FieldType::Text {
                multiline: false,
                max_length: Some(50),
            })
            .add_label("Add column");

        if let FieldType::DynamicList { item_type, add_label } = field.field_type {
            assert_eq!(add_label, "Add column");
            if let FieldType::Text { max_length, .. } = *item_type {
                assert_eq!(max_length, Some(50));
            } else {
                panic!("Expected Text item type");
            }
        } else {
            panic!("Expected DynamicList field type");
        }
    }

    #[test]
    fn ui_schema_serialization() {
        let schema = UISchema::new()
            .field(
                ConfigField::text("name", "Name")
                    .default_value(Value::String("test".to_string())),
            )
            .field(ConfigField::boolean("enabled", "Enabled"));

        let json = serde_json::to_string(&schema).unwrap();
        let deserialized: UISchema = serde_json::from_str(&json).unwrap();

        assert_eq!(deserialized.fields.len(), 2);
        assert_eq!(deserialized.fields[0].key, "name");
        assert_eq!(deserialized.fields[1].key, "enabled");
    }

    #[test]
    fn field_type_serialization() {
        let field_type = FieldType::Integer {
            min: Some(0),
            max: Some(100),
            step: 5,
        };

        let json = serde_json::to_string(&field_type).unwrap();
        assert!(json.contains(r#""kind":"integer"#));
        assert!(json.contains(r#""min":0"#));
        assert!(json.contains(r#""max":100"#));
        assert!(json.contains(r#""step":5"#));

        let deserialized: FieldType = serde_json::from_str(&json).unwrap();
        if let FieldType::Integer { min, max, step } = deserialized {
            assert_eq!(min, Some(0));
            assert_eq!(max, Some(100));
            assert_eq!(step, 5);
        } else {
            panic!("Expected Integer field type");
        }
    }

    #[test]
    fn file_mode_serialization() {
        let mode = FileMode::SaveFile;
        let json = serde_json::to_string(&mode).unwrap();
        assert_eq!(json, r#""savefile""#);

        let deserialized: FileMode = serde_json::from_str(&json).unwrap();
        assert_eq!(deserialized, FileMode::SaveFile);
    }
}
