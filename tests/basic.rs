use rtsyn_plugin::{Plugin, PluginContext, PluginError, PluginId, PluginMeta, Port, PortId};
use serde_json::json;

struct DummyPlugin {
    id: PluginId,
    meta: PluginMeta,
    inputs: Vec<Port>,
    outputs: Vec<Port>,
    calls: usize,
}

impl DummyPlugin {
    fn new(id: u64) -> Self {
        Self {
            id: PluginId(id),
            meta: PluginMeta {
                name: "dummy".to_string(),
                fixed_vars: vec![("fixed".to_string(), json!(1))],
                default_vars: vec![("default".to_string(), json!(2))],
            },
            inputs: vec![Port {
                id: PortId("in".to_string()),
            }],
            outputs: vec![Port {
                id: PortId("out".to_string()),
            }],
            calls: 0,
        }
    }
}

impl Plugin for DummyPlugin {
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
        self.calls += 1;
        Ok(())
    }
}

#[test]
fn plugin_meta_and_ports() {
    let plugin = DummyPlugin::new(1);
    assert_eq!(plugin.id().0, 1);
    assert_eq!(plugin.meta().name, "dummy");
    assert_eq!(plugin.inputs()[0].id.0, "in");
    assert_eq!(plugin.outputs()[0].id.0, "out");
}

#[test]
fn plugin_process_is_called() {
    let mut plugin = DummyPlugin::new(2);
    let mut ctx = PluginContext::default();
    plugin.process(&mut ctx).unwrap();
    plugin.process(&mut ctx).unwrap();
    assert_eq!(plugin.calls, 2);
}
