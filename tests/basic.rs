use rtsyn_plugin::prelude::*;

#[derive(Default)]
struct Dummy;

#[derive(Default)]
struct StandardDummy;

impl PluginDescriptor for Dummy {
    fn name() -> &'static str {
        "Dummy"
    }

    fn kind() -> &'static str {
        "dummy"
    }

    fn plugin_type() -> PluginType {
        PluginType::Computational
    }

    fn inputs() -> &'static [&'static str] {
        &["i_in"]
    }

    fn outputs() -> &'static [&'static str] {
        &["v_out"]
    }

    fn internal_variables() -> &'static [&'static str] {
        &["x"]
    }
}

impl PluginDescriptor for StandardDummy {
    fn name() -> &'static str {
        "Standard Dummy"
    }

    fn kind() -> &'static str {
        "standard_dummy"
    }

    fn inputs() -> &'static [&'static str] {
        &[]
    }

    fn outputs() -> &'static [&'static str] {
        &[]
    }
}

#[test]
fn descriptor_metadata() {
    assert_eq!(Dummy::name(), "Dummy");
    assert_eq!(Dummy::kind(), "dummy");
    assert_eq!(Dummy::plugin_type().as_str(), "computational");
    assert_eq!(Dummy::inputs(), &["i_in"]);
    assert_eq!(Dummy::outputs(), &["v_out"]);
    assert_eq!(
        Dummy::integration_method(),
        Some(IntegrationMethod::RungeKutta)
    );

    let schema = Dummy::display_schema();
    assert_eq!(schema.inputs, vec!["i_in"]);
    assert_eq!(schema.outputs, vec!["v_out"]);
    assert_eq!(schema.variables, vec!["x"]);
}

#[test]
fn plugin_type_strings() {
    assert_eq!(PluginType::Standard.as_str(), "standard");
    assert_eq!(PluginType::Device.as_str(), "device");
    assert_eq!(PluginType::Computational.as_str(), "computational");
}

#[test]
fn integration_method_strings() {
    assert_eq!(IntegrationMethod::RungeKutta.as_str(), "runge_kutta");
    assert_eq!(IntegrationMethod::Euler.as_str(), "euler");
    assert_eq!(IntegrationMethod::Custom.as_str(), "custom");
}

#[test]
fn integration_method_default_non_computational() {
    assert_eq!(StandardDummy::plugin_type(), PluginType::Standard);
    assert_eq!(StandardDummy::integration_method(), None);
}
