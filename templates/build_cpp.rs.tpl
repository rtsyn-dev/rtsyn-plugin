fn main() {
    println!("cargo:rerun-if-changed=src/__CORE_SOURCE_FILE__");
    println!("cargo:rerun-if-changed=src/__CORE_HEADER_FILE__");
    cc::Build::new()
        .cpp(true)
        .flag_if_supported("-std=c++17")
        .file("src/__CORE_SOURCE_FILE__")
        .compile("__CORE_BUILD_LIB__");
}
