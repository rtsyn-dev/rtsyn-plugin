#!/usr/bin/env sh
set -e

########################################
# Config
########################################

RESERVED_NAMES="time tick id process input inputs output outputs"

########################################
# Helpers (bash 3.2 safe)
########################################

trim() {
    echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
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

prompt_raw_name() {
    local prompt="$1"
    local raw
    while true; do
        read -rp "$prompt" raw
        raw="$(trim "$raw")"
        is_valid_name "$raw" || {
            echo "✖ invalid name"
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
            echo "✖ '$norm' is reserved"
            continue
        }
        case " $used " in *" $norm "*)
            echo "✖ duplicate name"
            continue
            ;;
        esac
        echo "$norm"
        return
    done
}

prompt_bool() {
    while true; do
        read -rp "(y/n): " v
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

########################################
# Start
########################################

echo "=== RTSyn Plugin Generator ==="

read -rp "Plugin base directory (default ./): " BASE_DIR
BASE_DIR="$(trim "$BASE_DIR")"
[ -z "$BASE_DIR" ] && BASE_DIR="."
mkdir -p "$BASE_DIR"

PLUGIN_NAME="$(prompt_raw_name "Plugin name (human readable): ")"
PLUGIN_KIND="$(to_snake_case "$PLUGIN_NAME")"
echo "→ plugin kind: $PLUGIN_KIND"

read -rp "Description: " DESCRIPTION

echo "Plugin model?"
echo "1) Native Rust (Plugin trait)"
echo "2) FFI (shared library)"
read -rp "#? " MODEL

LANG="rust"
if [ "$MODEL" = "2" ]; then
    echo "FFI language?"
    echo "1) Rust"
    echo "2) C"
    echo "3) C++"
    read -rp "#? " LANG_SEL
    case "$LANG_SEL" in
    1) LANG="rust" ;;
    2) LANG="c" ;;
    3) LANG="cpp" ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
    esac
fi

########################################
# IO
########################################

read -rp "Number of inputs: " N_INPUTS
read -rp "Number of outputs: " N_OUTPUTS

INPUTS=""
OUTPUTS=""

for i in $(seq 1 "$N_INPUTS"); do
    n="$(prompt_identifier "Input #$i name: " "$INPUTS")"
    INPUTS="$INPUTS $n"
done

for i in $(seq 1 "$N_OUTPUTS"); do
    n="$(prompt_identifier "Output #$i name: " "$OUTPUTS")"
    OUTPUTS="$OUTPUTS $n"
done

########################################
# Variables
########################################

read -rp "Number of plugin.toml variables: " N_VARS

VAR_NAMES=""
VAR_VALUES=""

for i in $(seq 1 "$N_VARS"); do
    v="$(prompt_identifier "Variable #$i name: " "$VAR_NAMES")"
    while true; do
        read -rp "Variable #$i default value (TOML literal): " d
        d="$(trim "$d")"
        [ -z "$d" ] && {
            echo "✖ default value cannot be empty"
            continue
        }
        break
    done
    VAR_NAMES="$VAR_NAMES $v"
    VAR_VALUES="$VAR_VALUES $d"
done

########################################
# FFI flags
########################################

if [ "$MODEL" = "2" ]; then
    echo "Extendable inputs?"
    EXTENDABLE_INPUTS="$(prompt_bool)"
    echo "Auto extend inputs?"
    AUTO_EXTEND_INPUTS="$(prompt_bool)"
    echo "Connection dependent?"
    CONNECTION_DEPENDENT="$(prompt_bool)"
    echo "Loads started?"
    LOADS_STARTED="$(prompt_bool)"
fi

########################################
# Directories
########################################

PLUGIN_DIR="$BASE_DIR/$PLUGIN_KIND"
SRC_DIR="$PLUGIN_DIR/src"
mkdir -p "$SRC_DIR"

########################################
# plugin.toml  ✅ RESTORED
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
library = "lib$PLUGIN_KIND.so"
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
name = "$PLUGIN_KIND"
version = "0.1.0"
edition = "2021"

[dependencies]
rtsyn_plugin = { workspace = true }
serde_json = { workspace = true }

[lib]
crate-type = ["cdylib"]
EOF

########################################
# Rust dyn (PluginApi)
########################################

if [ "$MODEL" = "2" ] && [ "$LANG" = "rust" ]; then
    LIB="$SRC_DIR/lib.rs"

    cat >"$LIB" <<EOF
use rtsyn_plugin::{PluginApi, PluginString};
use serde_json::Value;
use std::ffi::c_void;

const INPUTS: &[&str] = &[
EOF

    for i in $INPUTS; do
        echo "    \"$i\"," >>"$LIB"
    done

    cat >>"$LIB" <<EOF
];

const OUTPUTS: &[&str] = &[
EOF

    for o in $OUTPUTS; do
        echo "    \"$o\"," >>"$LIB"
    done

    cat >>"$LIB" <<EOF
];

struct PluginState;

extern "C" fn create(_: u64) -> *mut c_void {
    Box::into_raw(Box::new(PluginState)) as *mut c_void
}

extern "C" fn destroy(handle: *mut c_void) {
    if !handle.is_null() {
        unsafe { drop(Box::from_raw(handle as *mut PluginState)) }
    }
}

extern "C" fn meta_json(_: *mut c_void) -> PluginString {
    PluginString::from_string(serde_json::json!({
        "name": "$PLUGIN_NAME",
        "kind": "$PLUGIN_KIND"
    }).to_string())
}

extern "C" fn inputs_json(_: *mut c_void) -> PluginString {
    PluginString::from_string(serde_json::to_string(INPUTS).unwrap())
}

extern "C" fn outputs_json(_: *mut c_void) -> PluginString {
    PluginString::from_string(serde_json::to_string(OUTPUTS).unwrap())
}

extern "C" fn set_config_json(_: *mut c_void, _: *const u8, _: usize) {}
extern "C" fn set_input(_: *mut c_void, _: *const u8, _: usize, _: f64) {}
extern "C" fn process(_: *mut c_void, _: u64) {}
extern "C" fn get_output(_: *mut c_void, _: *const u8, _: usize) -> f64 { 0.0 }

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
# Done
########################################

echo
echo "✔ Plugin created at: $PLUGIN_DIR"
echo "✔ Kind: $PLUGIN_KIND"
