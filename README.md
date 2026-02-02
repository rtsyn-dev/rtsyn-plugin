# RTSyn Plugin

A Rust crate for developing plugins for **RTSyn**. The plugins can be developed in _Rust_, _C_ and _C++_.

## Dependences

- Rust toolchain (stable) with Cargo

Install Rust via rustup:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

Then ensure your environment is loaded:

```bash
source "$HOME/.cargo/env"
```

## Usage

For creating a plugin, execute the following script to interactively create a template.

```bash
curl --proto '=https' --tlsv1.2 -sSf https://github.com/rtsyn-dev/rtsyn-plugin/scripts/plugin_template.sh | sh
```

Then after implementing the functions, import the root folder of the plugin from **RTSyn**.
