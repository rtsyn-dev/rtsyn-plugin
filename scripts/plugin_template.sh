#!/usr/bin/env bash
set -Eeuo pipefail

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
        break
    done
    VAR_NAMES="$VAR_NAMES $v"
    VAR_VALUES="$VAR_VALUES $d"
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

# 1) Native Rust plugin
if [ "$MODEL" = "1" ]; then
    cat >"$SRC_DIR/lib.rs" <<EOF
use rtsyn_plugin::{Plugin, PluginContext, PluginError};

pub struct PluginState;

impl Plugin for PluginState {
    fn process(&mut self, _ctx: &mut PluginContext) -> Result<(), PluginError> {
        Ok(())
    }
}
EOF
fi

# 2) FFI Rust dyn (PluginApi)
if [ "$MODEL" = "2" ] && [ "$LANG" = "rust" ]; then
    LIB="$SRC_DIR/lib.rs"

    cat >"$LIB" <<EOF
use rtsyn_plugin::{PluginApi, PluginString};
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

# 3) FFI C - generate src/plugin.c
if [ "$MODEL" = "2" ] && [ "$LANG" = "c" ]; then
    cat >"$SRC_DIR/plugin.c" <<'EOF'
/* C FFI plugin stub.
   Implement the RTSyn C FFI surface expected by your loader, or provide a shim as needed.
*/
#include <stdint.h>

void* create(uint64_t id) { (void)id; return 0; }
void destroy(void* handle) { (void)handle; }

const char* meta_json(void* handle) { (void)handle; return "{}"; }
const char* inputs_json(void* handle) { (void)handle; return "[]"; }
const char* outputs_json(void* handle) { (void)handle; return "[]"; }

void set_config_json(void* handle, const uint8_t* buf, uintptr_t len) { (void)handle; (void)buf; (void)len; }
void set_input(void* handle, const uint8_t* name, uintptr_t name_len, double v) { (void)handle; (void)name; (void)name_len; (void)v; }
void process(void* handle, uint64_t tick) { (void)handle; (void)tick; }
double get_output(void* handle, const uint8_t* name, uintptr_t name_len) { (void)handle; (void)name; (void)name_len; return 0.0; }
EOF
fi

# 4) FFI C++ - generate src/plugin.cpp
if [ "$MODEL" = "2" ] && [ "$LANG" = "cpp" ]; then
    cat >"$SRC_DIR/plugin.cpp" <<'EOF'
/* C++ FFI plugin stub.
   Implement the RTSyn C/C++ FFI surface expected by your loader, or provide a shim as needed.
*/
#include <cstdint>

extern "C" {
void* create(std::uint64_t id) { (void)id; return nullptr; }
void destroy(void* handle) { (void)handle; }

const char* meta_json(void* handle) { (void)handle; return "{}"; }
const char* inputs_json(void* handle) { (void)handle; return "[]"; }
const char* outputs_json(void* handle) { (void)handle; return "[]"; }

void set_config_json(void* handle, const std::uint8_t* buf, std::uintptr_t len) { (void)handle; (void)buf; (void)len; }
void set_input(void* handle, const std::uint8_t* name, std::uintptr_t name_len, double v) { (void)handle; (void)name; (void)name_len; (void)v; }
void process(void* handle, std::uint64_t tick) { (void)handle; (void)tick; }
double get_output(void* handle, const std::uint8_t* name, std::uintptr_t name_len) { (void)handle; (void)name; (void)name_len; return 0.0; }
}
EOF
fi

########################################
# Done
########################################

echo >&2
echo "Plugin created at: $PLUGIN_DIR" >&2
echo "Kind: $PLUGIN_KIND" >&2
