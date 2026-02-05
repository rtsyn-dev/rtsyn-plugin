use rtsyn_plugin::prelude::*;
use serde_json::Value;

struct TestPlugin {
    id: PluginId,
    meta: PluginMeta,
    inputs: Vec<Port>,
    outputs: Vec<Port>,
}

impl TestPlugin {
    fn new(id: u64) -> Self {
        Self {
            id: PluginId(id),
            meta: PluginMeta {
                name: "Test Plugin".to_string(),
                fixed_vars: vec![],
                default_vars: vec![("test_var".to_string(), Value::from(42))],
            },
            inputs: vec![Port {
                id: PortId("in_0".to_string()),
            }],
            outputs: vec![Port {
                id: PortId("out_0".to_string()),
            }],
        }
    }
}

impl Plugin for TestPlugin {
    fn id(&self) -> PluginId {
        self.id
    }

    fn meta(&self) -> &PluginMeta {
        &self.meta
    }

    fn inputs(&self) -> &[Port] {
        &self.inputs
    }

    fn outputs(&self) -> &[Port] {
        &self.outputs
    }

    fn process(&mut self, _ctx: &mut PluginContext) -> Result<(), PluginError> {
        Ok(())
    }

    fn ui_schema(&self) -> Option<UISchema> {
        Some(
            UISchema::new()
                .field(
                    ConfigField::text("name", "Name")
                        .default_value(Value::String("default".to_string()))
                        .hint("Plugin name"),
                )
                .field(
                    ConfigField::integer("count", "Count")
                        .min(0)
                        .max(100)
                        .default_value(Value::from(10)),
                )
                .field(
                    ConfigField::filepath("output", "Output File")
                        .mode(FileMode::SaveFile)
                        .filter("CSV files", "*.csv"),
                )
                .field(
                    ConfigField::dynamic_list("items", "Items")
                        .add_label("Add item")
                        .item_type(FieldType::Text {
                            multiline: false,
                            max_length: Some(50),
                        }),
                ),
        )
    }

    fn behavior(&self) -> PluginBehavior {
        PluginBehavior {
            supports_start_stop: true,
            supports_restart: false,
            extendable_inputs: ExtendableInputs::Auto {
                pattern: "in_{}".to_string(),
            },
            loads_started: false,
        }
    }

    fn connection_behavior(&self) -> ConnectionBehavior {
        ConnectionBehavior { dependent: true }
    }

    fn on_input_added(&mut self, port: &str) -> Result<(), PluginError> {
        self.inputs.push(Port {
            id: PortId(port.to_string()),
        });
        Ok(())
    }

    fn on_input_removed(&mut self, port: &str) -> Result<(), PluginError> {
        self.inputs.retain(|p| p.id.0 != port);
        Ok(())
    }
}

#[test]
fn plugin_basic_functionality() {
    let mut plugin = TestPlugin::new(1);

    assert_eq!(plugin.id(), PluginId(1));
    assert_eq!(plugin.meta().name, "Test Plugin");
    assert_eq!(plugin.inputs().len(), 1);
    assert_eq!(plugin.outputs().len(), 1);

    let mut ctx = PluginContext::default();
    assert!(plugin.process(&mut ctx).is_ok());
}

#[test]
fn plugin_ui_schema() {
    let plugin = TestPlugin::new(1);
    let schema = plugin.ui_schema().expect("Should have UI schema");

    assert_eq!(schema.fields.len(), 4);

    // Check text field
    assert_eq!(schema.fields[0].key, "name");
    assert_eq!(schema.fields[0].label, "Name");
    assert_eq!(schema.fields[0].hint, Some("Plugin name".to_string()));

    // Check integer field
    assert_eq!(schema.fields[1].key, "count");
    if let FieldType::Integer { min, max, .. } = schema.fields[1].field_type {
        assert_eq!(min, Some(0));
        assert_eq!(max, Some(100));
    } else {
        panic!("Expected Integer field type");
    }

    // Check filepath field
    assert_eq!(schema.fields[2].key, "output");
    if let FieldType::FilePath { mode, filters } = &schema.fields[2].field_type {
        assert_eq!(*mode, FileMode::SaveFile);
        assert_eq!(filters.len(), 1);
        assert_eq!(filters[0].0, "CSV files");
    } else {
        panic!("Expected FilePath field type");
    }

    // Check dynamic list field
    assert_eq!(schema.fields[3].key, "items");
    if let FieldType::DynamicList { add_label, .. } = &schema.fields[3].field_type {
        assert_eq!(add_label, "Add item");
    } else {
        panic!("Expected DynamicList field type");
    }
}

#[test]
fn plugin_behavior() {
    let plugin = TestPlugin::new(1);
    let behavior = plugin.behavior();

    assert!(behavior.supports_start_stop);
    assert!(!behavior.supports_restart);
    assert_eq!(
        behavior.extendable_inputs,
        ExtendableInputs::Auto {
            pattern: "in_{}".to_string()
        }
    );
    assert!(!behavior.loads_started);
}

#[test]
fn plugin_connection_behavior() {
    let plugin = TestPlugin::new(1);
    let conn_behavior = plugin.connection_behavior();

    assert!(conn_behavior.dependent);
}

#[test]
fn plugin_dynamic_inputs() {
    let mut plugin = TestPlugin::new(1);

    assert_eq!(plugin.inputs().len(), 1);

    // Add input
    plugin.on_input_added("in_1").unwrap();
    assert_eq!(plugin.inputs().len(), 2);
    assert_eq!(plugin.inputs()[1].id.0, "in_1");

    // Add another
    plugin.on_input_added("in_2").unwrap();
    assert_eq!(plugin.inputs().len(), 3);

    // Remove input
    plugin.on_input_removed("in_1").unwrap();
    assert_eq!(plugin.inputs().len(), 2);
    assert_eq!(plugin.inputs()[0].id.0, "in_0");
    assert_eq!(plugin.inputs()[1].id.0, "in_2");
}

#[test]
fn ui_schema_json_serialization() {
    let plugin = TestPlugin::new(1);
    let schema = plugin.ui_schema().expect("Should have UI schema");

    // Serialize to JSON
    let json = serde_json::to_string(&schema).expect("Should serialize");

    // Deserialize back
    let deserialized: UISchema = serde_json::from_str(&json).expect("Should deserialize");

    assert_eq!(deserialized.fields.len(), schema.fields.len());
    assert_eq!(deserialized.fields[0].key, schema.fields[0].key);
}

#[test]
fn behavior_json_serialization() {
    let plugin = TestPlugin::new(1);
    let behavior = plugin.behavior();

    // Serialize to JSON
    let json = serde_json::to_string(&behavior).expect("Should serialize");

    // Deserialize back
    let deserialized: PluginBehavior = serde_json::from_str(&json).expect("Should deserialize");

    assert_eq!(deserialized, behavior);
}

#[test]
fn prelude_imports() {
    // Test that prelude brings everything into scope
    let _id = PluginId(1);
    let _port_id = PortId("test".to_string());
    let _port = Port {
        id: PortId("test".to_string()),
    };
    let _ctx = PluginContext::default();
    let _behavior = PluginBehavior::default();
    let _conn_behavior = ConnectionBehavior::default();
    let _schema = UISchema::new();
    let _field = ConfigField::text("key", "Label");
}

#[test]
fn default_plugin_behavior() {
    struct MinimalPlugin;

    impl Plugin for MinimalPlugin {
        fn id(&self) -> PluginId {
            PluginId(1)
        }
        fn meta(&self) -> &PluginMeta {
            static META: PluginMeta = PluginMeta {
                name: String::new(),
                fixed_vars: Vec::new(),
                default_vars: Vec::new(),
            };
            &META
        }
        fn inputs(&self) -> &[Port] {
            &[]
        }
        fn outputs(&self) -> &[Port] {
            &[]
        }
        fn process(&mut self, _ctx: &mut PluginContext) -> Result<(), PluginError> {
            Ok(())
        }
    }

    let plugin = MinimalPlugin;

    // Test default implementations
    assert!(plugin.ui_schema().is_none());

    let behavior = plugin.behavior();
    assert!(behavior.supports_start_stop);
    assert!(behavior.supports_restart);
    assert_eq!(behavior.extendable_inputs, ExtendableInputs::None);
    assert!(behavior.loads_started);

    let conn_behavior = plugin.connection_behavior();
    assert!(!conn_behavior.dependent);

    // Test default lifecycle hooks
    let mut plugin = MinimalPlugin;
    assert!(plugin.on_input_added("test").is_ok());
    assert!(plugin.on_input_removed("test").is_ok());
}
