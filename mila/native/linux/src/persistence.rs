//! Typed, durable deployment selection for the Linux client.
//!
//! Only the validated deployment authority is persisted.  Credentials and session
//! material are deliberately outside this file and are owned by the runtime.

use mila_native_linux::route::ActivationRoute;
use serde::{Deserialize, Serialize};
use std::{fs, io, path::PathBuf};

const FILE_NAME: &str = "deployment.json";
const SETTINGS_FILE_NAME: &str = "settings.json";
const MAX_PERSISTED_BYTES: usize = 64 * 1024;

fn restrict_permissions(path: &std::path::Path) -> io::Result<()> {
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        fs::set_permissions(path, fs::Permissions::from_mode(0o600))?;
    }
    Ok(())
}

fn require_owner_only(path: &std::path::Path) -> Result<(), PersistenceError> {
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let metadata = fs::metadata(path)?;
        if metadata.permissions().mode() & 0o077 != 0 {
            return Err(PersistenceError::InvalidData);
        }
    }
    Ok(())
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub(crate) struct DeploymentSelection {
    pub(crate) host: String,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub(crate) enum Appearance {
    System,
    Light,
    Dark,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub(crate) struct Settings {
    pub(crate) appearance: Appearance,
    pub(crate) locale: String,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            appearance: Appearance::System,
            locale: "en".to_owned(),
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(crate) enum LocaleDirection {
    Ltr,
    Rtl,
}

impl Settings {
    pub(crate) fn direction(&self) -> LocaleDirection {
        let language = self.locale.split('-').next().unwrap_or_default();
        match language {
            "ar" | "fa" | "he" | "ur" => LocaleDirection::Rtl,
            _ => LocaleDirection::Ltr,
        }
    }

    pub(crate) fn validate(appearance: Appearance, locale: &str) -> Result<Self, PersistenceError> {
        let raw = locale.trim().replace('_', "-");
        let mut parts = raw.split('-');
        let Some(language) = parts.next() else {
            return Err(PersistenceError::InvalidLocale);
        };
        let mut canonical = language.to_ascii_lowercase();
        for part in parts {
            if part.len() == 4 && part.bytes().all(|b| b.is_ascii_alphabetic()) {
                let mut chars = part.chars();
                if let Some(first) = chars.next() {
                    canonical.push('-');
                    canonical.push(first.to_ascii_uppercase());
                    canonical.extend(chars.map(|c| c.to_ascii_lowercase()));
                }
            } else {
                canonical.push('-');
                canonical.push_str(&part.to_ascii_uppercase());
            }
        }
        let locale = canonical;
        let valid = locale.len() >= 2
            && locale.len() <= 35
            && locale.split('-').all(|part| {
                !part.is_empty()
                    && part.len() <= 8
                    && part.bytes().all(|b| b.is_ascii_alphanumeric())
            })
            && locale
                .chars()
                .next()
                .is_some_and(|c| c.is_ascii_alphabetic());
        if !valid {
            return Err(PersistenceError::InvalidLocale);
        }
        Ok(Self { appearance, locale })
    }
}

impl DeploymentSelection {
    pub(crate) fn validate(host: &str) -> Result<Self, PersistenceError> {
        let host = host.trim().to_ascii_lowercase();
        if host.is_empty() || host.len() > 512 || host.contains(['/', '?', '#']) {
            return Err(PersistenceError::InvalidHost);
        }
        let route = format!("overalls://{host}/machines");
        let parsed = ActivationRoute::parse(&route).map_err(|_| PersistenceError::InvalidHost)?;
        let canonical = parsed.canonical();
        let authority = canonical
            .strip_prefix("overalls://")
            .and_then(|value| value.strip_suffix("/machines"))
            .ok_or(PersistenceError::InvalidHost)?;
        Ok(Self {
            host: authority.to_owned(),
        })
    }

    pub(crate) fn route(&self) -> String {
        format!("overalls://{}/machines", self.host)
    }
}

#[derive(Debug)]
pub(crate) enum PersistenceError {
    InvalidHost,
    Io(io::Error),
    InvalidData,
    InvalidLocale,
}

impl From<io::Error> for PersistenceError {
    fn from(error: io::Error) -> Self {
        Self::Io(error)
    }
}

fn path() -> Option<PathBuf> {
    if let Some(path) = std::env::var_os("MILA_DEPLOYMENT_PATH") {
        return Some(PathBuf::from(path));
    }
    let root = std::env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|home| PathBuf::from(home).join(".config")))?;
    Some(root.join("mila").join(FILE_NAME))
}

fn settings_path() -> Option<PathBuf> {
    if let Some(path) = std::env::var_os("MILA_SETTINGS_PATH") {
        return Some(PathBuf::from(path));
    }
    let root = std::env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|home| PathBuf::from(home).join(".config")))?;
    Some(root.join("mila").join(SETTINGS_FILE_NAME))
}

pub(crate) fn load() -> Result<Option<DeploymentSelection>, PersistenceError> {
    let Some(path) = path() else { return Ok(None) };
    let bytes = match fs::read(&path) {
        Ok(bytes) => bytes,
        Err(error) if error.kind() == io::ErrorKind::NotFound => return Ok(None),
        Err(error) => return Err(error.into()),
    };
    require_owner_only(&path)?;
    if bytes.len() > MAX_PERSISTED_BYTES {
        return Err(PersistenceError::InvalidData);
    }
    let selection: DeploymentSelection =
        serde_json::from_slice(&bytes).map_err(|_| PersistenceError::InvalidData)?;
    DeploymentSelection::validate(&selection.host).map(Some)
}

pub(crate) fn save(selection: &DeploymentSelection) -> Result<(), PersistenceError> {
    let selection = DeploymentSelection::validate(&selection.host)?;
    let Some(path) = path() else {
        return Err(PersistenceError::Io(io::Error::new(
            io::ErrorKind::NotFound,
            "configuration directory unavailable",
        )));
    };
    let parent = path
        .parent()
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "invalid configuration path"))?;
    fs::create_dir_all(parent)?;
    let temporary = path.with_extension("json.tmp");
    let bytes = serde_json::to_vec(&selection).map_err(|_| PersistenceError::InvalidData)?;
    fs::write(&temporary, bytes)?;
    restrict_permissions(&temporary)?;
    fs::rename(temporary, path)?;
    Ok(())
}

/// Forget the selected deployment without touching trust or device material.
pub(crate) fn forget() -> Result<(), PersistenceError> {
    let Some(path) = path() else {
        return Ok(());
    };
    match fs::remove_file(path) {
        Ok(()) => Ok(()),
        Err(error) if error.kind() == io::ErrorKind::NotFound => Ok(()),
        Err(error) => Err(error.into()),
    }
}

pub(crate) fn load_settings() -> Result<Settings, PersistenceError> {
    let Some(path) = settings_path() else {
        return Ok(Settings::default());
    };
    let bytes = match fs::read(&path) {
        Ok(bytes) => bytes,
        Err(error) if error.kind() == io::ErrorKind::NotFound => return Ok(Settings::default()),
        Err(error) => return Err(error.into()),
    };
    require_owner_only(&path)?;
    if bytes.len() > MAX_PERSISTED_BYTES {
        return Err(PersistenceError::InvalidData);
    }
    let settings: Settings =
        serde_json::from_slice(&bytes).map_err(|_| PersistenceError::InvalidData)?;
    Settings::validate(settings.appearance, &settings.locale)
}

pub(crate) fn save_settings(settings: &Settings) -> Result<(), PersistenceError> {
    let settings = Settings::validate(settings.appearance, &settings.locale)?;
    let Some(path) = settings_path() else {
        return Err(PersistenceError::Io(io::Error::new(
            io::ErrorKind::NotFound,
            "configuration directory unavailable",
        )));
    };
    let parent = path
        .parent()
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "invalid configuration path"))?;
    fs::create_dir_all(parent)?;
    let temporary = path.with_extension("json.tmp");
    fs::write(
        &temporary,
        serde_json::to_vec(&settings).map_err(|_| PersistenceError::InvalidData)?,
    )?;
    restrict_permissions(&temporary)?;
    fs::rename(temporary, path)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn validates_and_canonicalizes_host() {
        assert_eq!(
            DeploymentSelection::validate("Example.COM:443")
                .unwrap()
                .host,
            "example.com:443"
        );
        assert!(DeploymentSelection::validate("https://example.com").is_err());
        assert!(DeploymentSelection::validate("example.com/").is_err());
        assert!(DeploymentSelection::validate("example.com:0").is_err());
    }

    #[test]
    fn route_is_navigation_only() {
        let selection = DeploymentSelection::validate("example.com:443").unwrap();
        assert_eq!(selection.route(), "overalls://example.com:443/machines");
    }

    #[test]
    fn forget_is_idempotent() {
        let path =
            std::env::temp_dir().join(format!("mila-deployment-{}.json", std::process::id()));
        std::env::set_var("MILA_DEPLOYMENT_PATH", &path);
        let selection = DeploymentSelection::validate("example.com:443").unwrap();
        save(&selection).unwrap();
        assert!(path.exists());
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            assert_eq!(
                fs::metadata(&path).unwrap().permissions().mode() & 0o777,
                0o600
            );
        }
        assert_eq!(load().unwrap(), Some(selection.clone()));
        forget().unwrap();
        forget().unwrap();
        assert!(!path.exists());
        std::env::remove_var("MILA_DEPLOYMENT_PATH");
    }

    #[test]
    fn settings_validate_and_normalize_locale() {
        let settings = Settings::validate(Appearance::Dark, "fr_FR").unwrap();
        assert_eq!(settings.locale, "fr-FR");
        assert_eq!(
            Settings::validate(Appearance::System, "ZH_hant_tw")
                .unwrap()
                .locale,
            "zh-Hant-TW"
        );
        assert_eq!(settings.appearance, Appearance::Dark);
        assert!(Settings::validate(Appearance::System, "not a locale").is_err());
        assert!(Settings::validate(Appearance::System, "").is_err());
        assert_eq!(settings.direction(), LocaleDirection::Ltr);
        assert_eq!(
            Settings::validate(Appearance::System, "ar_SA")
                .unwrap()
                .direction(),
            LocaleDirection::Rtl
        );
    }

    #[cfg(unix)]
    #[test]
    fn settings_load_rejects_group_accessible_file() {
        use std::os::unix::fs::PermissionsExt;
        let path = std::env::temp_dir().join(format!("mila-settings-{}.json", std::process::id()));
        std::env::set_var("MILA_SETTINGS_PATH", &path);
        fs::write(&path, br#"{"appearance":"System","locale":"en"}"#).unwrap();
        fs::set_permissions(&path, fs::Permissions::from_mode(0o640)).unwrap();
        assert!(matches!(
            load_settings(),
            Err(PersistenceError::InvalidData)
        ));
        let _ = fs::remove_file(&path);
        std::env::remove_var("MILA_SETTINGS_PATH");
    }
}
