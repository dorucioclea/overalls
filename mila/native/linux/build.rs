use std::{env, path::PathBuf, process::Command};

fn main() {
    let root = PathBuf::from(env::var_os("CARGO_MANIFEST_DIR").expect("manifest directory"));
    let script = root.join("../../localization/generate_catalogs.py");
    let source = root.join("../../localization/catalogs");
    let output = PathBuf::from(env::var_os("OUT_DIR").expect("OUT_DIR")).join("mila-locales");
    let status = Command::new("python3")
        .arg(script)
        .arg("--source")
        .arg(source)
        .arg("--output")
        .arg(&output)
        .status()
        .expect("run Mila localization generator");
    assert!(status.success(), "Mila localization generation failed");
    println!("cargo:rustc-env=MILA_BUILT_LOCALE_DIR={}", output.display());
    println!("cargo:rerun-if-changed=../../localization/generate_catalogs.py");
    println!("cargo:rerun-if-changed=../../localization/catalogs");
}
