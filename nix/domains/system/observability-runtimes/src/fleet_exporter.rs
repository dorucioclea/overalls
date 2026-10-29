use std::env;
use std::process::{Command, ExitCode};

fn main() -> ExitCode {
    let script = match env::var("OVERALLS_FLEET_EXPORTER_SCRIPT") {
        Ok(value) => value,
        Err(_) => {
            eprintln!("observability runtime is not configured");
            return ExitCode::from(78);
        }
    };
    let python = env::var("OVERALLS_FLEET_EXPORTER_PYTHON").unwrap_or_else(|_| "python3".to_owned());
    match Command::new(python)
        .arg(script)
        .args(env::args().skip(1))
        .status()
    {
        Ok(status) => ExitCode::from(status.code().unwrap_or(1) as u8),
        Err(_) => ExitCode::from(127),
    }
}
