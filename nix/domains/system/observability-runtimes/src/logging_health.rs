use std::env;
use std::process::{Command, ExitCode};

fn main() -> ExitCode {
    delegate("OVERALLS_LOGGING_HEALTH_SCRIPT")
}

fn delegate(variable: &str) -> ExitCode {
    let script = match env::var(variable) {
        Ok(value) => value,
        Err(_) => {
            eprintln!("observability runtime is not configured");
            return ExitCode::from(78);
        }
    };
    let status = Command::new("/usr/bin/env")
        .arg("python3")
        .arg(script)
        .args(env::args().skip(1))
        .status();
    match status {
        Ok(status) => ExitCode::from(status.code().unwrap_or(1) as u8),
        Err(_) => ExitCode::from(127),
    }
}
