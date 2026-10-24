//! Linux notification capability reporting.
//!
//! Mila's platform profile does not currently provide a Linux push provider.
//! Keep that absence explicit at the native boundary so the UI cannot claim
//! registration succeeded or retain a misleading enabled state.

/// Why notification delivery is unavailable on this platform.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum NotificationUnavailable {
    NoPushProvider,
}

/// Capability exposed by the platform profile.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum NotificationCapability {
    Unsupported(NotificationUnavailable),
    /// Desktop notifications are available through the freedesktop portal,
    /// even though Linux has no Susan push registration provider.
    LocalDesktop,
}

/// Native notification state owned by the Linux presentation host.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct NotificationState {
    capability: NotificationCapability,
    enabled: bool,
}

impl NotificationState {
    /// Constructs the Linux capability from the platform profile.
    pub const fn linux() -> Self {
        Self {
            capability: NotificationCapability::Unsupported(
                NotificationUnavailable::NoPushProvider,
            ),
            enabled: false,
        }
    }

    pub const fn desktop() -> Self {
        Self {
            capability: NotificationCapability::LocalDesktop,
            enabled: false,
        }
    }

    pub const fn capability(&self) -> NotificationCapability {
        self.capability
    }

    pub const fn enabled(&self) -> bool {
        self.enabled
    }

    /// Attempts to register this host with the platform push provider.
    ///
    /// Linux has no provider in the shared Susan protocol. Keeping a distinct
    /// registration operation prevents the GTK host from treating a local
    /// toggle as a completed server registration.
    /// @cc [owner:ghuntley,label:security;desktop] linux-notifications-registration
    /// Registration MUST fail closed when the platform has no push provider,
    /// and a failed attempt MUST leave the state disabled.
    pub fn register(&mut self) -> Result<(), NotificationUnavailable> {
        self.enabled = false;
        Err(NotificationUnavailable::NoPushProvider)
    }

    /// @cc [owner:ghuntley,label:security;desktop] linux-notifications-no-provider
    /// Linux MUST refuse notification enablement while no push provider exists;
    /// the native state MUST remain disabled after every refusal.
    pub fn enable(&mut self) -> Result<(), NotificationUnavailable> {
        match self.capability {
            NotificationCapability::Unsupported(reason) => {
                self.enabled = false;
                Err(reason)
            }
            NotificationCapability::LocalDesktop => {
                self.enabled = true;
                Ok(())
            }
        }
    }

    /// Disables local notification presentation without changing capability.
    pub const fn disable(&mut self) {
        self.enabled = false;
    }

    /// Returns whether this host can display a local desktop notification.
    pub const fn can_display_locally(&self) -> bool {
        matches!(self.capability, NotificationCapability::LocalDesktop)
    }
}

#[cfg(test)]
mod tests {
    use super::{NotificationCapability, NotificationState, NotificationUnavailable};

    #[test]
    fn linux_reports_unsupported_without_enabling() {
        let mut state = NotificationState::linux();
        assert_eq!(
            state.capability(),
            NotificationCapability::Unsupported(NotificationUnavailable::NoPushProvider)
        );
        assert!(!state.enabled());
        assert_eq!(state.enable(), Err(NotificationUnavailable::NoPushProvider));
        assert!(!state.enabled());
        assert_eq!(
            state.register(),
            Err(NotificationUnavailable::NoPushProvider)
        );
        assert!(!state.enabled());
    }

    #[test]
    fn desktop_capability_can_be_enabled_without_push_registration() {
        let mut state = NotificationState::desktop();
        assert!(state.can_display_locally());
        assert_eq!(state.enable(), Ok(()));
        assert!(state.enabled());
        state.disable();
        assert!(!state.enabled());
        assert_eq!(
            state.register(),
            Err(NotificationUnavailable::NoPushProvider)
        );
        assert!(!state.enabled());
    }
}
