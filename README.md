# RTSyn Plugin

Rust crate for developing RTSyn plugins with the descriptor/runtime API.

## Dependencies

- Stable Rust + Cargo

## Template Generator

Use the interactive template-based generator to create plugin scaffolds:
- Rust (`PluginDescriptor` + `PluginRuntime` + `export_plugin!`)
- C core + Rust wrapper (opaque state pattern)
- C++ core + Rust wrapper (opaque state pattern)

```bash
./scripts/plugin_template.sh
```

The generated scaffold includes:
- `plugin.toml` with `kind` and library name
- `Cargo.toml` (`cdylib`)
- `src/lib.rs` with minimal plugin logic and behavior flags (`loads_started`, `supports_start_stop`, `supports_restart`)
- for C/C++: `src/plugin.h` + `src/plugin.c|cpp` and `build.rs`

For computational Rust plugins, `rtsyn_plugin::numerics::rk4_step` is available so users only implement the derivative function.
