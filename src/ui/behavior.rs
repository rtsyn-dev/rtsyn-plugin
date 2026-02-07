use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct PluginBehavior {
    pub supports_start_stop: bool,
    pub supports_restart: bool,
    pub extendable_inputs: ExtendableInputs,
    pub loads_started: bool,
}

impl Default for PluginBehavior {
    fn default() -> Self {
        Self {
            supports_start_stop: true,
            supports_restart: true,
            extendable_inputs: ExtendableInputs::None,
            loads_started: true,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "lowercase")]
pub enum ExtendableInputs {
    None,
    Manual,
    Auto { pattern: String },
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ConnectionBehavior {
    pub dependent: bool,
}

impl Default for ConnectionBehavior {
    fn default() -> Self {
        Self { dependent: false }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn behavior_default() {
        let behavior = PluginBehavior::default();
        assert!(behavior.supports_start_stop);
        assert!(behavior.supports_restart);
        assert_eq!(behavior.extendable_inputs, ExtendableInputs::None);
        assert!(behavior.loads_started);
    }

    #[test]
    fn extendable_inputs_serialization() {
        let none = ExtendableInputs::None;
        let json = serde_json::to_string(&none).unwrap();
        assert_eq!(json, r#"{"type":"none"}"#);

        let manual = ExtendableInputs::Manual;
        let json = serde_json::to_string(&manual).unwrap();
        assert_eq!(json, r#"{"type":"manual"}"#);

        let auto = ExtendableInputs::Auto {
            pattern: "in_{}".to_string(),
        };
        let json = serde_json::to_string(&auto).unwrap();
        assert_eq!(json, r#"{"type":"auto","pattern":"in_{}"}"#);
    }

    #[test]
    fn extendable_inputs_deserialization() {
        let json = r#"{"type":"none"}"#;
        let result: ExtendableInputs = serde_json::from_str(json).unwrap();
        assert_eq!(result, ExtendableInputs::None);

        let json = r#"{"type":"auto","pattern":"in_{}"}"#;
        let result: ExtendableInputs = serde_json::from_str(json).unwrap();
        assert_eq!(
            result,
            ExtendableInputs::Auto {
                pattern: "in_{}".to_string()
            }
        );
    }

    #[test]
    fn connection_behavior_default() {
        let behavior = ConnectionBehavior::default();
        assert!(!behavior.dependent);
    }

    #[test]
    fn behavior_serialization_roundtrip() {
        let behavior = PluginBehavior {
            supports_start_stop: false,
            supports_restart: true,
            extendable_inputs: ExtendableInputs::Auto {
                pattern: "input_{}".to_string(),
            },
            loads_started: false,
        };

        let json = serde_json::to_string(&behavior).unwrap();
        let deserialized: PluginBehavior = serde_json::from_str(&json).unwrap();
        assert_eq!(behavior, deserialized);
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DisplaySchema {
    #[serde(default)]
    pub outputs: Vec<String>,
    #[serde(default)]
    pub inputs: Vec<String>,
    #[serde(default)]
    pub variables: Vec<String>,
}
