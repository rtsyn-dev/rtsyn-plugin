use rtsyn_plugin::prelude::*;
use serde_json::Value;

#[derive(Default)]
struct TestPlugin {
    input: f64,
    output: f64,
    gain: f64,
}

impl PluginDescriptor for TestPlugin {
    fn name() -> &'static str {
        "Test Plugin"
    }

    fn kind() -> &'static str {
        "test_plugin"
    }

    fn inputs() -> &'static [&'static str] {
        &["in_0"]
    }

    fn outputs() -> &'static [&'static str] {
        &["out_0"]
    }

    fn internal_variables() -> &'static [&'static str] {
        &["gain"]
    }

    fn default_vars() -> Vec<(&'static str, Value)> {
        vec![("gain", Value::from(2.0))]
    }

    fn behavior() -> PluginBehavior {
        PluginBehavior {
            supports_start_stop: true,
            supports_restart: true,
            supports_apply: false,
            extendable_inputs: ExtendableInputs::None,
            loads_started: false,
            external_window: false,
            starts_expanded: true,
            start_requires_connected_inputs: Vec::new(),
            start_requires_connected_outputs: Vec::new(),
        }
    }
}

impl PluginRuntime for TestPlugin {
    fn set_config_value(&mut self, key: &str, value: &Value) {
        if key == "gain" {
            if let Some(v) = value.as_f64() {
                self.gain = v;
            }
        }
    }

    fn set_input_value(&mut self, key: &str, value: f64) {
        if key == "in_0" {
            self.input = value;
        }
    }

    fn process_tick(&mut self, _tick: u64, _period_seconds: f64) {
        self.output = self.input * self.gain;
    }

    fn get_output_value(&self, key: &str) -> f64 {
        if key == "out_0" {
            self.output
        } else {
            0.0
        }
    }

    fn get_internal_value(&self, key: &str) -> Option<f64> {
        if key == "gain" {
            Some(self.gain)
        } else {
            None
        }
    }
}

#[test]
fn runtime_flow() {
    let mut p = TestPlugin::default();
    p.set_config_value("gain", &Value::from(3.0));
    p.set_input_value("in_0", 2.0);
    p.process_tick(1, 0.001);

    assert_eq!(p.get_output_value("out_0"), 6.0);
    assert_eq!(p.get_internal_value("gain"), Some(3.0));
}

#[test]
fn ui_and_behavior_are_serializable() {
    let behavior = TestPlugin::behavior();
    let behavior_json = serde_json::to_string(&behavior).expect("behavior serialize");
    let decoded: PluginBehavior = serde_json::from_str(&behavior_json).expect("behavior decode");
    assert_eq!(decoded, behavior);

    let schema = TestPlugin::display_schema();
    let schema_json = serde_json::to_string(&schema).expect("schema serialize");
    let decoded: DisplaySchema = serde_json::from_str(&schema_json).expect("schema decode");
    assert_eq!(decoded.inputs, vec!["in_0"]);
}
