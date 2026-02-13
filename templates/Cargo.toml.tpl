[package]
name = "__PACKAGE_NAME__"
version = "0.1.0"
edition = "2021"

[dependencies]
rtsyn_plugin = { path = "../../rtsyn-plugin" }
serde_json = "1"

[lib]
crate-type = ["cdylib"]

__BUILD_DEPS__
