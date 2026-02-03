#!/usr/bin/env bash
set -Eeuo pipefail

########################################
# Config
########################################

RESERVED_NAMES="time tick id process input inputs output outputs period_seconds"

########################################
# Helpers (bash 3.2 safe)
########################################

trim() {
    echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

to_kebab_case() {
    echo "$1" |
        sed -E 's/[^a-zA-Z0-9]+/-/g' |
        sed -E 's/([a-z0-9])([A-Z])/\1-\2/g' |
        tr '[:upper:]' '[:lower:]' |
        sed -E 's/^-+|-+$//g'
}

to_snake_case() {
    echo "$1" |
        sed -E 's/[^a-zA-Z0-9]+/_/g' |
        sed -E 's/([a-z0-9])([A-Z])/\1_\2/g' |
        tr '[:upper:]' '[:lower:]' |
        sed -E 's/^_+|_+$//g'
}

is_valid_name() {
    local s="$1"
    [ -z "$s" ] && return 1
    echo "$s" | grep -q '[A-Za-z]' || return 1
    echo "$s" | grep -q '^[0-9]' && return 1
    echo "$s" | grep -Eq '^[A-Za-z0-9_ -]+$' || return 1
    return 0
}

is_reserved() {
    for r in $RESERVED_NAMES; do
        [ "$1" = "$r" ] && return 0
    done
    return 1
}

# Read from /dev/tty so curl|bash stays interactive
read_tty() {
    printf "%s" "$1" >&2
    IFS= read -r REPLY </dev/tty
}

prompt_raw_name() {
    local prompt="$1"
    local raw
    while true; do
        read_tty "$prompt"
        raw="$(trim "$REPLY")"
        is_valid_name "$raw" || {
            echo "invalid name" >&2
            continue
        }
        echo "$raw"
        return
    done
}

prompt_identifier() {
    local prompt="$1"
    local used="$2"
    local raw norm
    while true; do
        raw="$(prompt_raw_name "$prompt")"
        norm="$(to_snake_case "$raw")"
        is_reserved "$norm" && {
            echo "'$norm' is reserved" >&2
            continue
        }
        case " $used " in *" $norm "*)
            echo "duplicate name" >&2
            continue
            ;;
        esac
        echo "$norm"
        return
    done
}

prompt_bool() {
    local v
    while true; do
        read_tty "(y/n): "
        v="$(trim "$REPLY")"
        case "$v" in
        y | Y)
            echo "true"
            return
            ;;
        n | N)
            echo "false"
            return
            ;;
        esac
    done
}

prompt_int() {
    local v
    while true; do
        read_tty "$1"
        v="$(trim "$REPLY")"
        echo "$v" | grep -Eq '^[0-9]+$' && {
            echo "$v"
            return
        }
        echo "expected integer" >&2
    done
}

########################################
# Start
########################################

echo "=== RTSyn Plugin Generator ===" >&2

read_tty "Plugin base directory (default ./): "
BASE_DIR="$(trim "$REPLY")"
[ -z "$BASE_DIR" ] && BASE_DIR="."
mkdir -p "$BASE_DIR"

PLUGIN_NAME="$(prompt_raw_name "Plugin name (human readable): ")"

# snake_case kind (semantic identifier)
PLUGIN_KIND="$(to_snake_case "$PLUGIN_NAME")"
# kebab-case slug (folder / crate / library filename)
PLUGIN_SLUG="$(to_kebab_case "$PLUGIN_NAME")"

echo "→ plugin kind (snake_case): $PLUGIN_KIND" >&2
echo "→ plugin slug (kebab-case): $PLUGIN_SLUG" >&2

read_tty "Description: "
DESCRIPTION="$REPLY"

echo "Plugin model?" >&2
echo "1) Native Rust (Plugin trait)" >&2
echo "2) FFI (shared library)" >&2
read_tty "#? "
MODEL="$(trim "$REPLY")"

LANG="rust"
if [ "$MODEL" = "2" ]; then
    echo "FFI language?" >&2
    echo "1) Rust" >&2
    echo "2) C" >&2
    echo "3) C++" >&2
    read_tty "#? "
    LANG_SEL="$(trim "$REPLY")"
    case "$LANG_SEL" in
    1) LANG="rust" ;;
    2) LANG="c" ;;
    3) LANG="cpp" ;;
    *)
        echo "Invalid choice" >&2
        exit 1
        ;;
    esac
fi

########################################
# IO
########################################

N_INPUTS="$(prompt_int "Number of inputs: ")"
N_OUTPUTS="$(prompt_int "Number of outputs: ")"

INPUTS=""
OUTPUTS=""

i=1
while [ "$i" -le "$N_INPUTS" ]; do
    n="$(prompt_identifier "Input #$i name: " "$INPUTS")"
    INPUTS="$INPUTS $n"
    i=$((i + 1))
done

i=1
while [ "$i" -le "$N_OUTPUTS" ]; do
    n="$(prompt_identifier "Output #$i name: " "$OUTPUTS")"
    OUTPUTS="$OUTPUTS $n"
    i=$((i + 1))
done

########################################
# Variables
########################################

N_VARS="$(prompt_int "Number of plugin.toml variables: ")"

VAR_NAMES=""
VAR_VALUES=""
VAR_TYPES=""

i=1
while [ "$i" -le "$N_VARS" ]; do
    v="$(prompt_identifier "Variable #$i name: " "$VAR_NAMES")"
    while true; do
        read_tty "Variable #$i default value (TOML literal): "
        d="$(trim "$REPLY")"
        [ -z "$d" ] && {
            echo "default value cannot be empty" >&2
            continue
        }
        read_tty "Field #$i C type (double / size_t / int64_t): "
        ctype="$(trim "$REPLY")"

        case "$ctype" in
        double) rtype="f64" ;;
        size_t) rtype="usize" ;;
        int64_t) rtype="i64" ;;
        *)
            echo "Unsupported type"
            continue
            ;;
        esac

        break
    done
    VAR_NAMES="$VAR_NAMES $v"
    VAR_VALUES="$VAR_VALUES $d"
    VAR_TYPES="$VAR_TYPES $ctype"
    i=$((i + 1))
done

########################################
# FFI flags
########################################

EXTENDABLE_INPUTS="false"
AUTO_EXTEND_INPUTS="false"
CONNECTION_DEPENDENT="false"
LOADS_STARTED="false"

if [ "$MODEL" = "2" ]; then
    echo "Extendable inputs?" >&2
    EXTENDABLE_INPUTS="$(prompt_bool)"
    echo "Auto extend inputs?" >&2
    AUTO_EXTEND_INPUTS="$(prompt_bool)"
    echo "Connection dependent?" >&2
    CONNECTION_DEPENDENT="$(prompt_bool)"
    echo "Loads started?" >&2
    LOADS_STARTED="$(prompt_bool)"
fi

########################################
# Directories (NO implicit plugins/)
########################################

PLUGIN_DIR="$BASE_DIR/$PLUGIN_SLUG"
SRC_DIR="$PLUGIN_DIR/src"
mkdir -p "$SRC_DIR"

########################################
# plugin.toml
########################################

cat >"$PLUGIN_DIR/plugin.toml" <<EOF
name = "$PLUGIN_NAME"
kind = "$PLUGIN_KIND"
version = "0.1.0"
description = "$DESCRIPTION"
supports_start_stop = true
supports_restart = true
EOF

if [ "$MODEL" = "2" ]; then
    cat >>"$PLUGIN_DIR/plugin.toml" <<EOF
library = "lib$PLUGIN_SLUG.so"
extendable_inputs = $EXTENDABLE_INPUTS
auto_extend_inputs = $AUTO_EXTEND_INPUTS
connection_dependent = $CONNECTION_DEPENDENT
loads_started = $LOADS_STARTED
EOF
fi

for x in $INPUTS; do
    cat >>"$PLUGIN_DIR/plugin.toml" <<EOF

[[inputs]]
name = "$x"
EOF
done

for x in $OUTPUTS; do
    cat >>"$PLUGIN_DIR/plugin.toml" <<EOF

[[outputs]]
name = "$x"
EOF
done

set -- $VAR_VALUES
for v in $VAR_NAMES; do
    d="$1"
    shift
    cat >>"$PLUGIN_DIR/plugin.toml" <<EOF

[[variables]]
name = "$v"
default = $d
EOF
done

########################################
# Cargo.toml
########################################

cat >"$PLUGIN_DIR/Cargo.toml" <<EOF
[package]
name = "$PLUGIN_SLUG"
version = "0.1.0"
edition = "2021"

[dependencies]
rtsyn_plugin = { git = "https://github.com/rtsyn-dev/rtsyn-plugin" }
serde_json = "1"

[lib]
crate-type = ["cdylib"]
EOF

########################################
# Sources
########################################

########################################
# Sources
########################################

# 1) Native Rust plugin
if [ "$MODEL" = "1" ]; then
    cat >"$SRC_DIR/lib.rs" <<EOF
use rtsyn_plugin::{
    Plugin, PluginContext, PluginError, PluginId, PluginMeta, Port, PortId,
};
use serde_json::Value;

pub struct PluginState {
    id: PluginId,
    meta: PluginMeta,
    inputs: Vec<Port>,
    outputs: Vec<Port>,
$(
        i=0
        for v in $VAR_NAMES; do
            ctype=$(echo "$VAR_TYPES" | awk "{ print \$$((i + 1)) }")
            case "$ctype" in
            double) rtype="f64" ;;
            size_t) rtype="usize" ;;
            int64_t) rtype="i64" ;;
            esac
            echo "    $v: $rtype,"
            i=$((i + 1))
        done
    )
}

impl PluginState {
    pub fn new(id: u64) -> Self {
        Self {
            id: PluginId(id),
            meta: PluginMeta {
                name: "$PLUGIN_NAME".to_string(),
                fixed_vars: Vec::new(),
                default_vars: vec![
$(
        i=0
        for v in $VAR_NAMES; do
            val=$(echo "$VAR_VALUES" | awk "{ print \$$((i + 1)) }")
            echo "                    (\"$v\".to_string(), Value::from($val)),"
            i=$((i + 1))
        done
    )
                ],
            },
            inputs: vec![
$(
        for x in $INPUTS; do
            echo "                Port { id: PortId(\"$x\".to_string()) },"
        done
    )
            ],
            outputs: vec![
$(
        for x in $OUTPUTS; do
            echo "                Port { id: PortId(\"$x\".to_string()) },"
        done
    )
            ],
$(
        i=0
        for v in $VAR_NAMES; do
            val=$(echo "$VAR_VALUES" | awk "{ print \$$((i + 1)) }")
            echo "            $v: $val,"
            i=$((i + 1))
        done
    )
        }
    }
}

impl Plugin for PluginState {
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
        // TODO: Implement your plugin logic here
        // 
        // REAL-TIME CONSIDERATIONS:
        // - Keep computational complexity bounded and predictable
        // - Avoid unbounded loops or recursive algorithms
        // - For integration loops, limit steps (e.g., max 10-50 per tick)
        // - Use ctx.period_seconds for time-dependent calculations
        // - Consider using adaptive time steps instead of increasing iteration count
        
        Ok(())
    }
}
EOF
fi

########################################
# 2) FFI Rust dyn (PluginApi)
########################################

if [ "$MODEL" = "2" ] && [ "$LANG" = "rust" ]; then
    cat >"$SRC_DIR/lib.rs" <<EOF
use rtsyn_plugin::{
    PluginApi, PluginString,
    Plugin, PluginContext, PluginError,
    PluginId, PluginMeta, Port, PortId,
};
use serde_json::Value;
use std::ffi::c_void;
use std::slice;
use std::str;

// ============================
// Static port declarations
// ============================

const INPUTS: &[&str] = &[
$(for x in $INPUTS; do echo "    \"$x\","; done)
];

const OUTPUTS: &[&str] = &[
$(for x in $OUTPUTS; do echo "    \"$x\","; done)
];

// ============================
// Core plugin implementation
// ============================

pub struct PluginImpl {
    id: PluginId,
    meta: PluginMeta,
    inputs: Vec<Port>,
    outputs: Vec<Port>,
$(
        i=0
        for v in $VAR_NAMES; do
            ctype=$(echo "$VAR_TYPES" | awk "{print \$$((i + 1))}")
            case "$ctype" in
            double) rtype="f64" ;;
            size_t) rtype="usize" ;;
            int64_t) rtype="i64" ;;
            esac
            echo "    pub $v: $rtype,"
            i=$((i + 1))
        done
    )
$(for x in $INPUTS; do echo "    pub $x: f64,"; done)
$(for x in $OUTPUTS; do echo "    pub $x: f64,"; done)
}

impl PluginImpl {
    pub fn new(id: u64) -> Self {
        Self {
            id: PluginId(id),
            meta: PluginMeta {
                name: "$PLUGIN_NAME".to_string(),
                fixed_vars: Vec::new(),
                default_vars: vec![
$(
        i=0
        for v in $VAR_NAMES; do
            val=$(echo "$VAR_VALUES" | awk "{print \$$((i + 1))}")
            echo "                    (\"$v\".to_string(), Value::from($val)),"
            i=$((i + 1))
        done
    )
                ],
            },
            inputs: vec![
$(for x in $INPUTS; do echo "                Port { id: PortId(\"$x\".to_string()) },"; done)
            ],
            outputs: vec![
$(for x in $OUTPUTS; do echo "                Port { id: PortId(\"$x\".to_string()) },"; done)
            ],
$(
        i=0
        for v in $VAR_NAMES; do
            val=$(echo "$VAR_VALUES" | awk "{print \$$((i + 1))}")
            echo "            $v: $val,"
            i=$((i + 1))
        done
    )
$(for x in $INPUTS; do echo "            $x: 0.0,"; done)
$(for x in $OUTPUTS; do echo "            $x: 0.0,"; done)
        }
    }
}

impl Plugin for PluginImpl {
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
        // TODO: Implement your plugin logic here
        // 
        // REAL-TIME CONSIDERATIONS:
        // - Keep computational complexity bounded and predictable
        // - Avoid unbounded loops or recursive algorithms
        // - For integration loops, limit steps (e.g., max 10-50 per tick)
        // - Use ctx.period_seconds for time-dependent calculations
        // - Consider using adaptive time steps instead of increasing iteration count
        
        Ok(())
    }
}

// ============================
// FFI state wrapper
// ============================

struct PluginState {
    plugin: PluginImpl,
    ctx: PluginContext,
}

// ============================
// ABI functions
// ============================

extern "C" fn create(id: u64) -> *mut c_void {
    let state = PluginState {
        plugin: PluginImpl::new(id),
        ctx: PluginContext::default(),
    };
    Box::into_raw(Box::new(state)) as *mut c_void
}

extern "C" fn destroy(handle: *mut c_void) {
    if !handle.is_null() {
        unsafe { drop(Box::from_raw(handle as *mut PluginState)) }
    }
}

extern "C" fn meta_json(_: *mut c_void) -> PluginString {
    PluginString::from_string(
        serde_json::json!({
            "name": "$PLUGIN_NAME",
            "kind": "$PLUGIN_KIND"
        })
        .to_string(),
    )
}

extern "C" fn inputs_json(_: *mut c_void) -> PluginString {
    PluginString::from_string(serde_json::to_string(INPUTS).unwrap())
}

extern "C" fn outputs_json(_: *mut c_void) -> PluginString {
    PluginString::from_string(serde_json::to_string(OUTPUTS).unwrap())
}

extern "C" fn set_config_json(handle: *mut c_void, data: *const u8, len: usize) {
    if handle.is_null() || data.is_null() {
        return;
    }

    let state = unsafe { &mut *(handle as *mut PluginState) };
    let bytes = unsafe { slice::from_raw_parts(data, len) };

    if let Ok(json) = serde_json::from_slice::<Value>(bytes) {
$(
        i=0
        for v in $VAR_NAMES; do
            ctype=$(echo "$VAR_TYPES" | awk "{print \$$((i + 1))}")
            case "$ctype" in
            double)
                echo "        if let Some(val) = json.get(\"$v\").and_then(|v| v.as_f64()) { state.plugin.$v = val; }"
                ;;
            size_t)
                echo "        if let Some(val) = json.get(\"$v\").and_then(|v| v.as_u64()) { state.plugin.$v = val as usize; }"
                ;;
            int64_t)
                echo "        if let Some(val) = json.get(\"$v\").and_then(|v| v.as_i64()) { state.plugin.$v = val; }"
                ;;
            esac
            i=$((i + 1))
        done
    )
    }
}

extern "C" fn set_input(handle: *mut c_void, port: *const u8, len: usize, value: f64) {
    if handle.is_null() || port.is_null() {
        return;
    }

    let state = unsafe { &mut *(handle as *mut PluginState) };
    let name = unsafe { slice::from_raw_parts(port, len) };

    match str::from_utf8(name) {
$(for x in $INPUTS; do
        echo "        Ok(\"$x\") => state.plugin.$x = value,"
    done)
        _ => {}
    }
}

extern "C" fn process(handle: *mut c_void, tick: u64, period_seconds: f64) {
    if handle.is_null() {
        return;
    }

    let state = unsafe { &mut *(handle as *mut PluginState) };
    state.ctx.tick = tick;
    state.ctx.period_seconds = period_seconds;
    let _ = state.plugin.process(&mut state.ctx);
}

extern "C" fn get_output(handle: *mut c_void, port: *const u8, len: usize) -> f64 {
    if handle.is_null() || port.is_null() {
        return 0.0;
    }

    let state = unsafe { &*(handle as *mut PluginState) };
    let name = unsafe { slice::from_raw_parts(port, len) };

    match str::from_utf8(name) {
$(for x in $OUTPUTS; do
        echo "        Ok(\"$x\") => state.plugin.$x,"
    done)
        _ => 0.0,
    }
}

// ============================
// Plugin API export
// ============================

#[no_mangle]
pub extern "C" fn rtsyn_plugin_api() -> *const PluginApi {
    static API: PluginApi = PluginApi {
        create,
        destroy,
        meta_json,
        inputs_json,
        outputs_json,
        set_config_json,
        set_input,
        process,
        get_output,
    };
    &API
}
EOF
fi

########################################
# 3) FFI C core (numerical model)
########################################

if [ "$MODEL" = "2" ] && [ "$LANG" = "c" ]; then
    C_BASENAME="$(to_snake_case "$PLUGIN_SLUG")"

    ########################################
    # Header
    ########################################

    cat >"$SRC_DIR/$C_BASENAME.h" <<EOF
#pragma once
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ${C_BASENAME}_state {
$(
        i=0
        for v in $VAR_NAMES; do
            ctype=$(echo "$VAR_TYPES" | awk "{print \$$((i + 1))}")
            echo "    $ctype $v;"
            i=$((i + 1))
        done
    )
$(for x in $INPUTS; do echo "    double $x;"; done)
$(for x in $OUTPUTS; do echo "    double $x;"; done)
} ${C_BASENAME}_state_t;

void ${C_BASENAME}_init(${C_BASENAME}_state_t *state);
void ${C_BASENAME}_set_config(${C_BASENAME}_state_t *state, const char *key, size_t len, double value);
void ${C_BASENAME}_set_input(${C_BASENAME}_state_t *state, const char *name, size_t len, double value);
void ${C_BASENAME}_process(${C_BASENAME}_state_t *state, double period_seconds);

#ifdef __cplusplus
}
#endif
EOF

    ########################################
    # Source
    ########################################

    cat >"$SRC_DIR/$C_BASENAME.c" <<EOF
#include "$C_BASENAME.h"
#include <string.h>

void ${C_BASENAME}_init(${C_BASENAME}_state_t *state) {
$(
        i=0
        for v in $VAR_NAMES; do
            val=$(echo "$VAR_VALUES" | awk "{print \$$((i + 1))}")
            ctype=$(echo "$VAR_TYPES" | awk "{print \$$((i + 1))}")
            case "$ctype" in
            double) echo "    state->$v = $val;" ;;
            size_t) echo "    state->$v = $val;" ;;
            int64_t) echo "    state->$v = $val;" ;;
            esac
            i=$((i + 1))
        done
    )
$(for x in $INPUTS; do echo "    state->$x = 0.0;"; done)
$(for x in $OUTPUTS; do echo "    state->$x = 0.0;"; done)
}

void ${C_BASENAME}_set_config(
    ${C_BASENAME}_state_t *state,
    const char *key,
    size_t len,
    double value
) {
$(for v in $VAR_NAMES; do
        echo "    if (len == ${#v} && strncmp(key, \"$v\", len) == 0) { state->$v = value; return; }"
    done)
}

void ${C_BASENAME}_set_input(
    ${C_BASENAME}_state_t *state,
    const char *name,
    size_t len,
    double value
) {
$(for x in $INPUTS; do
        echo "    if (len == ${#x} && strncmp(name, \"$x\", len) == 0) { state->$x = value; return; }"
    done)
}

void ${C_BASENAME}_process(${C_BASENAME}_state_t *state, double period_seconds) {
    /* TODO: Implement your plugin logic here
     * 
     * REAL-TIME CONSIDERATIONS:
     * - Keep computational complexity bounded and predictable
     * - Avoid unbounded loops or recursive algorithms
     * - For integration loops, limit steps (e.g., max 10-50 per tick)
     * - Consider using adaptive time steps instead of increasing iteration count
     * - Use period_seconds for time-dependent calculations
     */
    (void)state;
    (void)period_seconds;
}
EOF
fi

########################################
# 4) FFI C++ core (numerical model)
########################################

if [ "$MODEL" = "2" ] && [ "$LANG" = "cpp" ]; then
    CPP_BASENAME="$(to_snake_case "$PLUGIN_SLUG")"

    ########################################
    # Header
    ########################################

    cat >"$SRC_DIR/$CPP_BASENAME.h" <<EOF
#pragma once
#include <cstddef>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ${CPP_BASENAME}_state_cpp {
$(
        i=0
        for v in $VAR_NAMES; do
            ctype=$(echo "$VAR_TYPES" | awk "{print \$$((i + 1))}")
            echo "    $ctype $v;"
            i=$((i + 1))
        done
    )
$(for x in $INPUTS; do echo "    double $x;"; done)
$(for x in $OUTPUTS; do echo "    double $x;"; done)
} ${CPP_BASENAME}_state_cpp_t;

void ${CPP_BASENAME}_init(${CPP_BASENAME}_state_cpp_t *state);
void ${CPP_BASENAME}_set_config(${CPP_BASENAME}_state_cpp_t *state, const char *key, size_t len, double value);
void ${CPP_BASENAME}_set_input(${CPP_BASENAME}_state_cpp_t *state, const char *name, size_t len, double value);
void ${CPP_BASENAME}_process(${CPP_BASENAME}_state_cpp_t *state, double period_seconds);

#ifdef __cplusplus
}
#endif
EOF

    ########################################
    # Source
    ########################################

    cat >"$SRC_DIR/$CPP_BASENAME.cpp" <<EOF
#include "$CPP_BASENAME.h"
#include <cstring>
#include <cmath>

extern "C" void ${CPP_BASENAME}_init(${CPP_BASENAME}_state_cpp_t *state) {
$(
        i=0
        for v in $VAR_NAMES; do
            val=$(echo "$VAR_VALUES" | awk "{print \$$((i + 1))}")
            ctype=$(echo "$VAR_TYPES" | awk "{print \$$((i + 1))}")
            case "$ctype" in
            double) echo "    state->$v = $val;" ;;
            size_t) echo "    state->$v = $val;" ;;
            int64_t) echo "    state->$v = $val;" ;;
            esac
            i=$((i + 1))
        done
    )
$(for x in $INPUTS; do echo "    state->$x = 0.0;"; done)
$(for x in $OUTPUTS; do echo "    state->$x = 0.0;"; done)
}

extern "C" void ${CPP_BASENAME}_set_config(
    ${CPP_BASENAME}_state_cpp_t *state,
    const char *key,
    size_t len,
    double value
) {
$(for v in $VAR_NAMES; do
        echo "    if (len == ${#v} && std::strncmp(key, \"$v\", len) == 0) { state->$v = value; return; }"
    done)
}

extern "C" void ${CPP_BASENAME}_set_input(
    ${CPP_BASENAME}_state_cpp_t *state,
    const char *name,
    size_t len,
    double value
) {
$(for x in $INPUTS; do
        echo "    if (len == ${#x} && std::strncmp(name, \"$x\", len) == 0) { state->$x = value; return; }"
    done)
}

extern "C" void ${CPP_BASENAME}_process(${CPP_BASENAME}_state_cpp_t *state, double period_seconds) {
    /* TODO: Implement your plugin logic here
     * 
     * REAL-TIME CONSIDERATIONS:
     * - Keep computational complexity bounded and predictable
     * - Avoid unbounded loops or recursive algorithms
     * - For integration loops, limit steps (e.g., max 10-50 per tick)
     * - Consider using adaptive time steps instead of increasing iteration count
     * - Use period_seconds for time-dependent calculations
     */
    (void)state;
    (void)period_seconds;
}
EOF
fi

########################################
# lib.rs (FFI wrapper for C / C++)
########################################

if [ "$MODEL" = "2" ] && { [ "$LANG" = "c" ] || [ "$LANG" = "cpp" ]; }; then
    CORE="$(to_snake_case "$PLUGIN_SLUG")"

    cat >"$SRC_DIR/lib.rs" <<EOF
use rtsyn_plugin::{PluginApi, PluginString};
use serde_json::Value;
use std::ffi::c_void;
use std::slice;
use std::str;

#[repr(C)]
struct CoreState {
$(
        i=0
        for v in $VAR_NAMES; do
            ctype=$(echo "$VAR_TYPES" | awk "{print \$$((i + 1))}")
            case "$ctype" in
            double) rtype="f64" ;;
            size_t) rtype="usize" ;;
            int64_t) rtype="i64" ;;
            esac
            echo "    $v: $rtype,"
            i=$((i + 1))
        done
    )
$(for x in $INPUTS; do echo "    $x: f64,"; done)
$(for x in $OUTPUTS; do echo "    $x: f64,"; done)
}

extern "C" {
    fn ${CORE}_init(state: *mut CoreState);
    fn ${CORE}_set_config(state: *mut CoreState, key: *const u8, len: usize, value: f64);
    fn ${CORE}_set_input(state: *mut CoreState, name: *const u8, len: usize, value: f64);
    fn ${CORE}_process(state: *mut CoreState, period_seconds: f64);
}

const INPUTS: &[&str] = &[
$(for x in $INPUTS; do echo "    \"$x\","; done)
];

const OUTPUTS: &[&str] = &[
$(for x in $OUTPUTS; do echo "    \"$x\","; done)
];

extern "C" fn create(_id: u64) -> *mut c_void {
    let mut state = Box::new(CoreState {
$(
        i=0
        for v in $VAR_NAMES; do
            ctype=$(echo "$VAR_TYPES" | awk "{print \$$((i + 1))}")
            case "$ctype" in
            double) echo "        $v: 0.0," ;;
            size_t) echo "        $v: 0," ;;
            int64_t) echo "        $v: 0," ;;
            esac
            i=$((i + 1))
        done
    )
$(for x in $INPUTS; do echo "        $x: 0.0,"; done)
$(for x in $OUTPUTS; do echo "        $x: 0.0,"; done)
    });
    unsafe {
        ${CORE}_init(&mut *state);
    }
    Box::into_raw(state) as *mut c_void
}

extern "C" fn destroy(handle: *mut c_void) {
    if handle.is_null() {
        return;
    }
    unsafe {
        drop(Box::from_raw(handle as *mut CoreState));
    }
}

extern "C" fn meta_json(_: *mut c_void) -> PluginString {
    PluginString::from_string(
        serde_json::json!({
            "name": "$PLUGIN_NAME",
            "kind": "$PLUGIN_KIND"
        })
        .to_string(),
    )
}

extern "C" fn inputs_json(_: *mut c_void) -> PluginString {
    PluginString::from_string(serde_json::to_string(INPUTS).unwrap())
}

extern "C" fn outputs_json(_: *mut c_void) -> PluginString {
    PluginString::from_string(serde_json::to_string(OUTPUTS).unwrap())
}

extern "C" fn set_config_json(handle: *mut c_void, data: *const u8, len: usize) {
    if handle.is_null() || data.is_null() || len == 0 {
        return;
    }

    let state = handle as *mut CoreState;
    let bytes = unsafe { slice::from_raw_parts(data, len) };

    if let Ok(json) = serde_json::from_slice::<Value>(bytes) {
        if let Some(map) = json.as_object() {
            for (key, value) in map {
                if let Some(v) = value.as_f64() {
                    unsafe {
                        ${CORE}_set_config(
                            state,
                            key.as_bytes().as_ptr(),
                            key.len(),
                            v,
                        );
                    }
                }
            }
        }
    }
}

extern "C" fn set_input(handle: *mut c_void, name: *const u8, len: usize, value: f64) {
    if handle.is_null() || name.is_null() || len == 0 {
        return;
    }

    unsafe {
        ${CORE}_set_input(
            handle as *mut CoreState,
            name,
            len,
            value,
        );
    }
}

extern "C" fn process(handle: *mut c_void, _tick: u64, period_seconds: f64) {
    if handle.is_null() {
        return;
    }
    unsafe {
        ${CORE}_process(handle as *mut CoreState, period_seconds);
    }
}

extern "C" fn get_output(handle: *mut c_void, name: *const u8, len: usize) -> f64 {
    if handle.is_null() || name.is_null() || len == 0 {
        return 0.0;
    }

    let state = unsafe { &*(handle as *mut CoreState) };
    let bytes = unsafe { slice::from_raw_parts(name, len) };

    match str::from_utf8(bytes) {
$(for x in $OUTPUTS; do
        echo "        Ok(\"$x\") => state.$x,"
    done)
        _ => 0.0,
    }
}

#[no_mangle]
pub extern "C" fn rtsyn_plugin_api() -> *const PluginApi {
    static API: PluginApi = PluginApi {
        create,
        destroy,
        meta_json,
        inputs_json,
        outputs_json,
        set_config_json,
        set_input,
        process,
        get_output,
    };
    &API
}
EOF
fi

########################################
# build.rs (FFI C / C++)
########################################

if [ "$MODEL" = "2" ] && { [ "$LANG" = "c" ] || [ "$LANG" = "cpp" ]; }; then
    CORE="$(to_snake_case "$PLUGIN_SLUG")"

    cat >"$PLUGIN_DIR/build.rs" <<EOF
fn main() {
    let mut build = cc::Build::new();
EOF

    if [ "$LANG" = "cpp" ]; then
        cat >>"$PLUGIN_DIR/build.rs" <<EOF
    build
        .cpp(true)
        .flag_if_supported("-std=c++17")
        .file("src/$CORE.cpp");
EOF
    else
        cat >>"$PLUGIN_DIR/build.rs" <<EOF
    build
        .file("src/$CORE.c");
EOF
    fi

    cat >>"$PLUGIN_DIR/build.rs" <<EOF
    build.compile("$PLUGIN_SLUG");
}
EOF
fi

if [ "$MODEL" = "2" ] && { [ "$LANG" = "c" ] || [ "$LANG" = "cpp" ]; }; then
    cat >>"$PLUGIN_DIR/Cargo.toml" <<EOF

[build-dependencies]
cc = "1"
EOF
fi

########################################
# Done
########################################

echo >&2
echo "Plugin created at: $PLUGIN_DIR" >&2
echo "Kind: $PLUGIN_KIND" >&2
