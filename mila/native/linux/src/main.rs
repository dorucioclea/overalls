use adw::prelude::*;
use adw::{Application, ApplicationWindow};
use gtk::{gio, glib, Align, Box, Button, Entry, Label, Orientation, TextDirection};
use mila_native_linux::adapter::{
    decode_listing, decode_notification_devices, decode_web_endpoint, format_machine_action,
    format_ssh_key_revoke, format_thread_response, format_web_command, TerminalStream,
};
use mila_native_linux::machine_view::{project_detail, project_listing};
use mila_native_linux::notifications::NotificationState;
use mila_native_linux::route::{ActivationBatch, ActivationRoute, NavigationDecision};
use mila_native_linux::session::{
    ApprovalInfo, SessionBinding, SignInEvent, SignInFlow, SignInPhase, WhoamiOutcome,
};
use std::{cell::RefCell, rc::Rc};
mod persistence;
mod strings;
const APPLICATION_ID: &str = "dev.overalls.Mila.Linux";
#[derive(Clone)]
struct NativeState {
    status: Rc<RefCell<Option<Label>>>,
    sign_in: Rc<RefCell<SignInFlow>>,
    session: Rc<RefCell<SessionBinding>>,
    machine_listing: Rc<RefCell<Option<mila_session::MachineListing>>>,
}
impl NativeState {
    fn new() -> Self {
        Self {
            status: Rc::new(RefCell::new(None)),
            sign_in: Rc::new(RefCell::new(SignInFlow::default())),
            session: Rc::new(RefCell::new(SessionBinding::default())),
            machine_listing: Rc::new(RefCell::new(None)),
        }
    }
    fn ensure_window(&self, app: &adw::Application) -> ApplicationWindow {
        if let Some(window) = app.active_window() {
            if let Ok(window) = window.downcast::<ApplicationWindow>() {
                return window;
            }
        }
        let root = Box::new(Orientation::Vertical, 12);
        root.set_margin_top(24);
        root.set_margin_bottom(24);
        root.set_margin_start(24);
        root.set_margin_end(24);
        let title_text = strings::text(strings::Message::AppName);
        let title = Label::new(Some(&title_text));
        title.set_halign(Align::Start);
        title.add_css_class("title-1");
        root.append(&title);
        let nav = Box::new(Orientation::Horizontal, 8);
        let ready_text = strings::text(strings::Message::Ready);
        let content = Label::new(Some(&ready_text));
        content.set_wrap(true);
        content.set_halign(Align::Start);
        *self.status.borrow_mut() = Some(content.clone());
        for (name, text) in [
            ("Machines", "Machines\nSelect a machine to view its status."),
            ("Threads", "Threads\nRecent conversations appear here."),
            (
                "Settings",
                "Settings\nRuntime settings are managed by the core library.",
            ),
        ] {
            let button = Button::with_label(name);
            let label = content.clone();
            let text = text.to_string();
            button.connect_clicked(move |_| label.set_label(&text));
            nav.append(&button);
        }
        root.append(&nav);

        let settings = persistence::load_settings().unwrap_or_default();
        root.set_direction(match settings.direction() {
            persistence::LocaleDirection::Rtl => TextDirection::Rtl,
            persistence::LocaleDirection::Ltr => TextDirection::Ltr,
        });
        let appearance_label = Label::new(Some(&strings::text(strings::Message::Appearance)));
        appearance_label.set_halign(Align::Start);
        root.append(&appearance_label);
        let settings_actions = Box::new(Orientation::Horizontal, 8);
        for (label, appearance) in [
            (
                strings::text(strings::Message::AppearanceSystem),
                persistence::Appearance::System,
            ),
            (
                strings::text(strings::Message::AppearanceLight),
                persistence::Appearance::Light,
            ),
            (
                strings::text(strings::Message::AppearanceDark),
                persistence::Appearance::Dark,
            ),
        ] {
            let button = Button::with_label(&label);
            let status = content.clone();
            let locale = settings.locale.clone();
            button.connect_clicked(move |_| {
                let value = persistence::Settings {
                    appearance,
                    locale: locale.clone(),
                };
                match persistence::save_settings(&value) {
                    Ok(()) => status.set_label(&format!(
                        "{}: {:?}",
                        strings::text(strings::Message::Appearance),
                        appearance
                    )),
                    Err(_) => status.set_label("Settings could not be saved."),
                }
            });
            settings_actions.append(&button);
        }
        root.append(&settings_actions);
        let locale = Entry::builder()
            .placeholder_text(&strings::text(strings::Message::Locale))
            .text(&settings.locale)
            .hexpand(true)
            .build();
        let save_settings = Button::with_label(&strings::text(strings::Message::SaveSettings));
        let locale_input = locale.clone();
        let settings_status = content.clone();
        let saved_appearance = settings.appearance;
        save_settings.connect_clicked(move |_| {
            match persistence::Settings::validate(saved_appearance, locale_input.text().as_str())
                .and_then(|value| persistence::save_settings(&value).map(|_| value))
            {
                Ok(value) => {
                    settings_status.set_label(&format!("Settings saved: {}", value.locale))
                }
                Err(_) => settings_status.set_label("Settings locale rejected by Rust policy."),
            }
        });
        root.append(&locale);
        root.append(&save_settings);

        let deployment = Entry::builder()
            .placeholder_text(&strings::text(strings::Message::DeploymentSelect))
            .hexpand(true)
            .build();
        if let Ok(Some(selection)) = persistence::load() {
            deployment.set_text(&selection.host);
        }
        let select = Button::with_label(&strings::text(strings::Message::SelectDeployment));
        let deployment_status = content.clone();
        let deployment_input = deployment.clone();
        let deployment_session = self.session.clone();
        let deployment_sign_in = self.sign_in.clone();
        select.connect_clicked(move |_| {
            let host = deployment_input.text().trim().to_owned();
            match persistence::DeploymentSelection::validate(&host) {
                Ok(selection) => {
                    let route = selection.route();
                    let _ = persistence::save(&selection);
                    // A deployment switch invalidates every authenticated handle and
                    // approval generation. Keep the GTK shell from accidentally
                    // presenting authority from the previous host.
                    deployment_session.borrow_mut().clear();
                    let mut flow = deployment_sign_in.borrow_mut();
                    *flow = flow.clone().apply(SignInEvent::SignOut);
                    let parsed = ActivationRoute::parse(&route).expect("validated route");
                    deployment_status.set_label(&format!(
                        "Deployment selected\n{}\nSign in required.",
                        parsed.canonical()
                    ))
                }
                Err(_) => deployment_status.set_label("Deployment host rejected by Rust policy."),
            }
        });
        root.append(&deployment);
        root.append(&select);
        let reload = Button::with_label(&strings::text(strings::Message::ReloadDeployment));
        let reload_status = content.clone();
        let reload_input = deployment.clone();
        reload.connect_clicked(move |_| match persistence::load() {
            Ok(Some(selection)) => {
                reload_input.set_text(&selection.host);
                reload_status.set_label(&format!("Deployment loaded\n{}", selection.host));
            }
            Ok(None) => {
                reload_input.set_text("");
                reload_status.set_label("No deployment is selected.");
            }
            Err(_) => reload_status.set_label("Deployment could not be loaded."),
        });
        root.append(&reload);
        let forget = Button::with_label(&strings::text(strings::Message::ForgetDeployment));
        let forget_status = content.clone();
        let forget_input = deployment.clone();
        let forget_session = self.session.clone();
        let forget_sign_in = self.sign_in.clone();
        forget.connect_clicked(move |_| match persistence::forget() {
            Ok(()) => {
                forget_input.set_text("");
                forget_session.borrow_mut().clear();
                let mut flow = forget_sign_in.borrow_mut();
                *flow = flow.clone().apply(SignInEvent::SignOut);
                forget_status.set_label(&strings::text(strings::Message::DeploymentForgotten));
            }
            Err(_) => {
                forget_status.set_label(&strings::text(strings::Message::DeploymentForgetFailed));
            }
        });
        root.append(&forget);

        let machine_detail_id = Entry::builder()
            .placeholder_text("Machine UUID for detail")
            .hexpand(true)
            .build();
        let machine_status = content.clone();
        let machine_session = self.session.clone();
        let machine_listing = self.machine_listing.clone();
        let refresh_machines = Button::with_label("Refresh machines");
        refresh_machines.connect_clicked(move |_| {
            let binding = machine_session.borrow();
            let Some(live) = binding.session() else {
                machine_status.set_label("Machine list unavailable until sign-in.");
                return;
            };
            match live
                .listing()
                .and_then(|bytes| {
                    decode_listing(&bytes)
                        .map_err(|_| mila_native_linux::session::SessionError::InvalidInput)
                })
                .and_then(|listing| {
                    let rows = project_listing(&listing)
                        .map_err(|_| mila_native_linux::session::SessionError::InvalidInput)?;
                    *machine_listing.borrow_mut() = Some(listing);
                    let summary = rows
                        .iter()
                        .map(|row| {
                            format!(
                                "{}{} — {}",
                                if row.pinned { "★ " } else { "" },
                                row.name,
                                row.observed_state.as_deref().unwrap_or("unavailable")
                            )
                        })
                        .collect::<Vec<_>>();
                    Ok(summary.join("\n"))
                }) {
                Ok(summary) if summary.is_empty() => {
                    machine_status.set_label("No machines returned.")
                }
                Ok(summary) => machine_status.set_label(&format!("Machines\n{summary}")),
                Err(_) => machine_status.set_label("Machine list rejected by Rust policy."),
            }
        });
        let detail_status = content.clone();
        let detail_listing = self.machine_listing.clone();
        let detail_id = machine_detail_id.clone();
        let show_machine = Button::with_label("Show machine detail");
        show_machine.connect_clicked(move |_| {
            let id = detail_id.text().trim().to_owned();
            let Some(listing) = detail_listing.borrow().as_ref().cloned() else {
                detail_status.set_label("Refresh machines before opening detail.");
                return;
            };
            match project_detail(&listing, &id) {
                Ok(row) => detail_status.set_label(&format!(
                    "Machine {}\nDesired: {}\nObserved: {}\nRead: {}  Write: {}  Manage: {}",
                    row.name,
                    row.desired_state,
                    row.observed_state.as_deref().unwrap_or("unavailable"),
                    row.can_read,
                    row.can_write,
                    row.can_manage
                )),
                Err(_) => detail_status.set_label("Machine detail unavailable."),
            }
        });
        root.append(&machine_detail_id);
        root.append(&refresh_machines);
        root.append(&show_machine);

        // The lifecycle controls are deliberately state-only until the host
        // supplies its owner-only Linux device signer and HTTPS trust fetcher.
        // They still exercise the same generation/approval/reconnect reducer as
        // the connected path and never claim authenticated authority locally.
        let sign_in_controls = Box::new(Orientation::Horizontal, 8);
        let sign_in = self.sign_in.clone();
        let sign_in_status = content.clone();
        let deployment_input = deployment.clone();
        let sign_in_button = Button::with_label(&strings::text(strings::Message::SignInStart));
        sign_in_button.connect_clicked(move |_| {
            let host = deployment_input.text().trim().to_owned();
            let Ok(selection) = persistence::DeploymentSelection::validate(&host) else {
                sign_in_status
                    .set_label(&strings::text(strings::Message::SignInDeploymentRequired));
                return;
            };
            let _ = persistence::save(&selection);
            let mut flow = sign_in.borrow_mut();
            *flow = flow.clone().apply(SignInEvent::Start);
            sign_in_status.set_label(&strings::text(strings::Message::SignInConnecting));
        });
        sign_in_controls.append(&sign_in_button);

        let approval_url = Entry::builder()
            .placeholder_text("Browser approval URL (HTTPS)")
            .hexpand(true)
            .build();
        let approval_fingerprint = Entry::builder()
            .placeholder_text("Approval fingerprint")
            .hexpand(true)
            .build();
        let sign_in = self.sign_in.clone();
        let sign_in_status = content.clone();
        let url = approval_url.clone();
        let fingerprint = approval_fingerprint.clone();
        let approval_button = Button::with_label(&strings::text(strings::Message::SignInApprove));
        approval_button.connect_clicked(move |_| {
            let mut flow = sign_in.borrow_mut();
            let generation = flow.generation;
            let outcome = WhoamiOutcome::Approval {
                url: url.text().trim().to_owned(),
                fingerprint: fingerprint.text().trim().to_owned(),
            };
            *flow = flow.clone().apply(SignInEvent::Whoami {
                generation,
                outcome,
                at: 0,
            });
            sign_in_status.set_label(if flow.phase == SignInPhase::AwaitingApproval {
                "Approval pending; open the HTTPS link in your browser."
            } else {
                "Approval URL rejected by Rust policy."
            });
        });
        sign_in_controls.append(&approval_button);

        let sign_in = self.sign_in.clone();
        let session = self.session.clone();
        let sign_in_status = content.clone();
        let check_approval = Button::with_label("Check approval");
        check_approval.connect_clicked(move |_| {
            let generation = sign_in.borrow().generation;
            let outcome = match session.borrow().session() {
                Some(live) => live.whoami(),
                None => Err(mila_native_linux::session::SessionError::StaleHandle),
            };
            let mut flow = sign_in.borrow_mut();
            match outcome {
                Ok(outcome) => {
                    *flow = flow.clone().apply(SignInEvent::Whoami {
                        generation,
                        outcome,
                        at: 0,
                    });
                    sign_in_status.set_label(match flow.phase {
                        SignInPhase::SignedIn => "Deployment approved and signed in.",
                        SignInPhase::AwaitingApproval => "Approval is still pending.",
                        _ => "Deployment identity check refused.",
                    });
                }
                Err(_) => sign_in_status.set_label("No authenticated deployment session."),
            }
        });
        sign_in_controls.append(&check_approval);

        let sign_in = self.sign_in.clone();
        let sign_in_status = content.clone();
        let open_approval = Button::with_label(&strings::text(strings::Message::SignInOpenBrowser));
        open_approval.connect_clicked(move |_| {
            let flow = sign_in.borrow();
            let Some(approval) = flow.approval.as_ref() else {
                sign_in_status.set_label("No live approval link is available.");
                return;
            };
            if ApprovalInfo::validate(&approval.url, &approval.fingerprint, approval.issued_at)
                .is_err()
            {
                sign_in_status.set_label("Approval URL rejected by Rust policy.");
                return;
            }
            match gio::AppInfo::launch_default_for_uri(
                &approval.url,
                None::<&gio::AppLaunchContext>,
            ) {
                Ok(()) => sign_in_status.set_label("Approval opened in the browser."),
                Err(_) => sign_in_status.set_label("The browser could not open approval."),
            }
        });
        sign_in_controls.append(&open_approval);

        let sign_in = self.sign_in.clone();
        let sign_in_status = content.clone();
        let session = self.session.clone();
        let machine_listing_on_sign_out = self.machine_listing.clone();
        let sign_out_button = Button::with_label(&strings::text(strings::Message::SignInSignOut));
        sign_out_button.connect_clicked(move |_| {
            session.borrow_mut().clear();
            // Never retain authenticated machine projections after sign-out.
            // A subsequent session must refresh from the server before detail/actions.
            *machine_listing_on_sign_out.borrow_mut() = None;
            let mut flow = sign_in.borrow_mut();
            *flow = flow.clone().apply(SignInEvent::SignOut);
            sign_in_status.set_label("Signed out; deployment trust and approval remain pinned.");
        });
        sign_in_controls.append(&sign_out_button);
        root.append(&sign_in_controls);
        root.append(&approval_url);
        root.append(&approval_fingerprint);

        let sign_in = self.sign_in.clone();
        let sign_in_status = content.clone();
        let reconnect = Button::with_label(&strings::text(strings::Message::SignInReconnect));
        reconnect.connect_clicked(move |_| {
            let mut flow = sign_in.borrow_mut();
            let previous = flow.phase;
            *flow = flow.clone().apply(SignInEvent::Start);
            sign_in_status.set_label(if previous == SignInPhase::Disconnected {
                "Reconnect started; a fresh generation must reauthenticate."
            } else {
                "Reconnect requires a disconnected authenticated session."
            });
        });
        root.append(&reconnect);

        // Linux intentionally reports lock capability explicitly. The shared Flutter
        // policy marks Linux as unavailable; keeping this state visible prevents
        // presenting a control that cannot be honored by the native platform.
        let lock_title = strings::text(strings::Message::LockTitle);
        let lock_button = Button::with_label(&lock_title);
        // The capability is explicitly unavailable on Linux; keep the control
        // visible for discoverability but prevent it from implying an action.
        lock_button.set_sensitive(false);
        let lock_status = content.clone();
        lock_button.connect_clicked(move |_| {
            let explanation = strings::text(strings::Message::LockExplain);
            let unavailable = strings::text(strings::Message::LockUnavailable);
            lock_status.set_label(&format!("{unavailable}\n{explanation}"));
        });
        root.append(&lock_button);
        // Linux can show local desktop notifications through the desktop
        // environment, while Susan push registration remains unavailable.
        let notification_state = Rc::new(RefCell::new(NotificationState::desktop()));
        let notification_button =
            Button::with_label(&strings::text(strings::Message::NotificationsTitle));
        let notification_status = content.clone();
        let notification_state_for_action = notification_state.clone();
        notification_button.connect_clicked(move |_| {
            let mut state = notification_state_for_action.borrow_mut();
            match state.enable() {
                Ok(()) => notification_status.set_label("Notifications enabled."),
                Err(_) => notification_status
                    .set_label(&strings::text(strings::Message::NotificationsExplain)),
            }
        });
        root.append(&notification_button);
        let notification_id = Entry::builder()
            .placeholder_text(&strings::text(strings::Message::NotificationDeviceId))
            .hexpand(true)
            .build();
        let notification_actions = Box::new(Orientation::Horizontal, 8);
        for (message, operation) in [
            (strings::Message::NotificationRefresh, "list"),
            (strings::Message::NotificationRemove, "remove"),
            (strings::Message::NotificationEnable, "enable"),
            (strings::Message::NotificationDisable, "disable"),
        ] {
            let button = Button::with_label(&strings::text(message));
            let status = content.clone();
            let session = self.session.clone();
            let device_id = notification_id.clone();
            button.connect_clicked(move |_| {
                let mut binding = session.borrow_mut();
                let Some(live) = binding.session_mut() else {
                    status.set_label(&strings::text(strings::Message::NotificationRequireSignIn));
                    return;
                };
                let result = match operation {
                    "list" => live.device_list().and_then(|bytes| {
                        decode_notification_devices(&bytes)
                            .map(|items| format!("{} notification devices", items.len()))
                            .map_err(|_| mila_native_linux::session::SessionError::InvalidInput)
                    }),
                    "remove" => live
                        .device_remove(device_id.text().trim())
                        .map(|()| String::new()),
                    "enable" => live
                        .device_preference(device_id.text().trim(), true)
                        .map(|()| String::new()),
                    "disable" => live
                        .device_preference(device_id.text().trim(), false)
                        .map(|()| String::new()),
                    _ => Err(mila_native_linux::session::SessionError::InvalidInput),
                };
                let message = if result.is_ok() {
                    strings::text(strings::Message::NotificationAccepted)
                } else {
                    strings::text(strings::Message::NotificationRejected)
                };
                status.set_label(&message);
            });
            notification_actions.append(&button);
        }
        root.append(&notification_id);
        root.append(&notification_actions);
        let machine_id = Entry::builder()
            .placeholder_text(&strings::text(strings::Message::MachineUuid))
            .hexpand(true)
            .build();
        let request_id = Entry::builder()
            .placeholder_text("Request UUID (for mutations)")
            .hexpand(true)
            .build();
        let actions = Box::new(Orientation::Horizontal, 8);
        // `rm` is Porsche's closed-command spelling for deleting a machine.
        // Keep it in the native action set so GTK exposes the complete lifecycle
        // supported by the authenticated Rust session.
        for action in ["show", "start", "stop", "pause", "resume", "rm"] {
            let button = Button::with_label(action);
            let machine = machine_id.clone();
            let request = request_id.clone();
            let label = content.clone();
            let session = self.session.clone();
            let action = action.to_owned();
            button.connect_clicked(move |_| {
                if action == "show" {
                    let request = (!request.text().is_empty()).then(|| request.text().to_string());
                    match format_machine_action(
                        &action,
                        machine.text().as_str(),
                        request.as_deref(),
                    ) {
                        Ok(command) => label.set_label(&format!("Machine command\n{command}")),
                        Err(_) => label.set_label("Machine command rejected by Rust policy."),
                    }
                    return;
                }
                let mut binding = session.borrow_mut();
                let Some(live) = binding.session_mut() else {
                    label.set_label("Machine mutations require sign-in.");
                    return;
                };
                match live.machine_action(machine.text().trim(), &action, request.text().trim()) {
                    Ok(()) => label.set_label("Machine mutation accepted."),
                    Err(_) => label.set_label("Machine mutation rejected by Rust policy."),
                }
            });
            actions.append(&button);
        }
        root.append(&machine_id);
        root.append(&request_id);
        root.append(&actions);
        let create_name = Entry::builder()
            .placeholder_text("New machine name")
            .hexpand(true)
            .build();
        let create_button = Button::with_label("Create machine");
        let create_status = content.clone();
        let create_session = self.session.clone();
        let create_request = request_id.clone();
        let create_name_input = create_name.clone();
        create_button.connect_clicked(move |_| {
            let mut binding = create_session.borrow_mut();
            let Some(live) = binding.session_mut() else {
                create_status.set_label("Machine creation requires sign-in.");
                return;
            };
            match live.machine_create(
                create_name_input.text().trim(),
                1,
                1024,
                10_240,
                create_request.text().trim(),
            ) {
                Ok(()) => create_status.set_label("Machine creation accepted."),
                Err(_) => create_status.set_label("Machine creation rejected by Rust policy."),
            }
        });
        root.append(&create_name);
        root.append(&create_button);
        let resize_button = Button::with_label("Resize machine");
        let resize_status = content.clone();
        let resize_session = self.session.clone();
        let resize_machine = machine_id.clone();
        let resize_request = request_id.clone();
        resize_button.connect_clicked(move |_| {
            let mut binding = resize_session.borrow_mut();
            let Some(live) = binding.session_mut() else {
                resize_status.set_label("Machine resize requires sign-in.");
                return;
            };
            match live.machine_resize(
                resize_machine.text().trim(),
                1,
                1024,
                10_240,
                resize_request.text().trim(),
            ) {
                Ok(()) => resize_status.set_label("Machine resize accepted."),
                Err(_) => resize_status.set_label("Machine resize rejected by Rust policy."),
            }
        });
        root.append(&resize_button);
        let share_email = Entry::builder()
            .placeholder_text(&strings::text(strings::Message::ShareEmail))
            .hexpand(true)
            .build();
        let share_role = Entry::builder()
            .placeholder_text(&strings::text(strings::Message::ShareRole))
            .hexpand(true)
            .build();
        let share_actions = Box::new(Orientation::Horizontal, 8);
        for (label_text, operation) in [
            (strings::text(strings::Message::ShareAdd), "add"),
            (strings::text(strings::Message::ShareRemove), "remove"),
        ] {
            let button = Button::with_label(&label_text);
            let machine = machine_id.clone();
            let email = share_email.clone();
            let role = share_role.clone();
            let status = content.clone();
            let session = self.session.clone();
            let request_id = request_id.clone();
            button.connect_clicked(move |_| {
                let request = request_id.text().trim().to_owned();
                let selected_role =
                    (!role.text().trim().is_empty()).then(|| role.text().trim().to_owned());
                let add = operation == "add";
                let mut binding = session.borrow_mut();
                let Some(live) = binding.session_mut() else {
                    status.set_label("Sharing mutations require sign-in.");
                    return;
                };
                match live.share_mutation(
                    machine.text().trim(),
                    email.text().trim(),
                    selected_role.as_deref(),
                    add,
                    &request,
                ) {
                    Ok(()) => status.set_label("Sharing mutation accepted."),
                    Err(_) => status.set_label("Sharing request rejected by Rust policy."),
                }
            });
            share_actions.append(&button);
        }
        root.append(&share_email);
        root.append(&share_role);
        root.append(&share_actions);
        let share_response = Entry::builder()
            .placeholder_text("share show JSON (paste response)")
            .hexpand(true)
            .build();
        let share_load = Button::with_label(&strings::text(strings::Message::ShareLoad));
        let share_status = content.clone();
        let response_input = share_response.clone();
        share_load.connect_clicked(
            move |_| match mila_native_linux::adapter::decode_share_listing(
                response_input.text().as_bytes(),
            ) {
                Ok((owner, grants)) => share_status
                    .set_label(&format!("Owner: {owner}\n{} share grants", grants.len())),
                Err(_) => share_status.set_label("Sharing listing rejected by Rust policy."),
            },
        );
        root.append(&share_response);
        root.append(&share_load);
        // Terminal controls keep only typed lifecycle state. PTY bytes remain in
        // the transport and never enter GTK labels or application state.
        let terminal = Entry::builder()
            .placeholder_text("Terminal session ID")
            .hexpand(true)
            .build();
        let terminal_input = Entry::builder()
            .placeholder_text("Input length (bytes)")
            .hexpand(true)
            .build();
        let terminal_columns = Entry::builder()
            .placeholder_text("Columns")
            .text("80")
            .hexpand(true)
            .build();
        let terminal_rows = Entry::builder()
            .placeholder_text("Rows")
            .text("24")
            .hexpand(true)
            .build();
        let terminal_actions = Box::new(Orientation::Horizontal, 8);
        let terminal_stream = Rc::new(RefCell::new(TerminalStream::new()));
        let terminal_status = content.clone();
        let stream = terminal_stream.clone();
        let session_input = terminal.clone();
        let session_binding = self.session.clone();
        let attach = Button::with_label(&strings::text(strings::Message::AttachTerminal));
        attach.connect_clicked(move |_| {
            if session_binding.borrow().session().is_none() {
                terminal_status.set_label("Terminal controls require sign-in.");
                return;
            }
            let session = session_input.text().trim().to_owned();
            if session.is_empty() || session.len() > 128 {
                terminal_status.set_label("Terminal session rejected by Rust policy.");
                return;
            }
            let mut stream = stream.borrow_mut();
            match stream.attach() {
                Ok(generation) => terminal_status.set_label(&format!(
                    "Terminal attaching\nSession {session}\nGeneration {generation}"
                )),
                Err(_) => terminal_status.set_label("Terminal attach unavailable."),
            }
        });
        terminal_actions.append(&attach);

        let terminal_status = content.clone();
        let stream = terminal_stream.clone();
        let session_binding = self.session.clone();
        let connect = Button::with_label("Connect");
        connect.connect_clicked(move |_| {
            if session_binding.borrow().session().is_none() {
                terminal_status.set_label("Terminal controls require sign-in.");
                return;
            }
            let mut stream = stream.borrow_mut();
            let generation = stream.state().generation();
            let cursor = stream.state().resume_cursor().unwrap_or(0);
            match stream.connected(generation, cursor, true) {
                Ok(()) => terminal_status.set_label(&format!(
                    "Terminal attached\nGeneration {generation}\nRead-write"
                )),
                Err(_) => terminal_status.set_label("Terminal connection rejected."),
            }
        });
        terminal_actions.append(&connect);

        let terminal_status = content.clone();
        let stream = terminal_stream.clone();
        let session_binding = self.session.clone();
        let reconnect = Button::with_label("Reconnect");
        reconnect.connect_clicked(move |_| {
            if session_binding.borrow().session().is_none() {
                terminal_status.set_label("Terminal controls require sign-in.");
                return;
            }
            let mut stream = stream.borrow_mut();
            match stream.reconnect() {
                Ok(generation) => terminal_status
                    .set_label(&format!("Terminal reconnecting\nGeneration {generation}")),
                Err(_) => terminal_status.set_label("Terminal reconnect unavailable."),
            }
        });
        terminal_actions.append(&reconnect);

        let terminal_status = content.clone();
        let stream = terminal_stream.clone();
        let input = terminal_input.clone();
        let session_binding = self.session.clone();
        let input_button = Button::with_label("Send input");
        input_button.connect_clicked(move |_| {
            if session_binding.borrow().session().is_none() {
                terminal_status.set_label("Terminal controls require sign-in.");
                return;
            }
            let length = input.text().trim().parse::<usize>().ok();
            let Some(length) = length else {
                terminal_status.set_label("Terminal input length rejected.");
                return;
            };
            match stream.borrow().validate_input(length) {
                Ok(()) => {
                    terminal_status.set_label(&format!("Terminal input accepted ({length} bytes)"))
                }
                Err(_) => terminal_status.set_label("Terminal input rejected by Rust policy."),
            }
        });
        terminal_actions.append(&input_button);

        let terminal_status = content.clone();
        let stream = terminal_stream.clone();
        let columns = terminal_columns.clone();
        let rows = terminal_rows.clone();
        let session_binding = self.session.clone();
        let resize = Button::with_label("Resize");
        resize.connect_clicked(move |_| {
            if session_binding.borrow().session().is_none() {
                terminal_status.set_label("Terminal controls require sign-in.");
                return;
            }
            let parsed = columns
                .text()
                .trim()
                .parse::<u16>()
                .ok()
                .zip(rows.text().trim().parse::<u16>().ok());
            let Some((columns, rows)) = parsed else {
                terminal_status.set_label("Terminal size rejected.");
                return;
            };
            match stream.borrow().validate_resize(columns, rows) {
                Ok(()) => terminal_status
                    .set_label(&format!("Terminal resize accepted ({columns}x{rows})")),
                Err(_) => terminal_status.set_label("Terminal resize rejected by Rust policy."),
            }
        });
        terminal_actions.append(&resize);

        let terminal_status = content.clone();
        let stream = terminal_stream.clone();
        let session_binding = self.session.clone();
        let kill = Button::with_label("Kill");
        kill.connect_clicked(move |_| {
            if session_binding.borrow().session().is_none() {
                terminal_status.set_label("Terminal controls require sign-in.");
                return;
            }
            let generation = stream.borrow().state().generation();
            match stream.borrow_mut().kill(generation) {
                Ok(()) => {
                    terminal_status.set_label(&format!("Terminal ended\nGeneration {generation}"))
                }
                Err(_) => terminal_status.set_label("Terminal kill rejected."),
            }
        });
        terminal_actions.append(&kill);
        root.append(&terminal);
        root.append(&terminal_input);
        root.append(&terminal_columns);
        root.append(&terminal_rows);
        root.append(&terminal_actions);
        let thread_id = Entry::builder()
            .placeholder_text(&strings::text(strings::Message::ThreadId))
            .max_length(128)
            .hexpand(true)
            .build();
        let thread_actions = Box::new(Orientation::Horizontal, 8);
        for operation in ["ls", "show"] {
            let label = if operation == "ls" {
                strings::text(strings::Message::ThreadList)
            } else {
                strings::text(strings::Message::ThreadShow)
            };
            let button = Button::with_label(&label);
            let input = thread_id.clone();
            let status = content.clone();
            let session = self.session.clone();
            let operation = operation.to_owned();
            button.connect_clicked(move |_| {
                let id = (!input.text().is_empty()).then(|| input.text().to_string());
                let mut binding = session.borrow_mut();
                let Some(live) = binding.session_mut() else {
                    status.set_label("Thread controls require sign-in.");
                    return;
                };
                let command = if operation == "ls" {
                    "thread ls"
                } else {
                    "thread show"
                };
                match live.thread_action(id.as_deref(), command, None, None, None) {
                    Ok(bytes) => match format_thread_response(&bytes) {
                        Ok(response) => status.set_label(&response),
                        Err(_) => status.set_label("Thread response rejected by Rust policy."),
                    },
                    Err(_) => status.set_label("Thread command rejected by Rust policy."),
                }
            });
            thread_actions.append(&button);
        }
        let turns = Button::with_label("Thread turns");
        let turns_input = thread_id.clone();
        let turns_status = content.clone();
        let turns_session = self.session.clone();
        turns.connect_clicked(move |_| {
            let mut binding = turns_session.borrow_mut();
            let Some(live) = binding.session_mut() else {
                turns_status.set_label("Thread controls require sign-in.");
                return;
            };
            match live.thread_action(
                Some(turns_input.text().trim()),
                "thread turns",
                None,
                None,
                None,
            ) {
                Ok(bytes) => match format_thread_response(&bytes) {
                    Ok(response) => turns_status.set_label(&response),
                    Err(_) => turns_status.set_label("Thread response rejected by Rust policy."),
                },
                Err(_) => turns_status.set_label("Thread turns rejected by Rust policy."),
            }
        });
        thread_actions.append(&turns);
        let thread_secondary = Entry::builder()
            .placeholder_text("Turn or question ID")
            .max_length(128)
            .hexpand(true)
            .build();
        let thread_input = Entry::builder()
            .placeholder_text("Thread input (stdin)")
            .max_length(64 * 1024)
            .hexpand(true)
            .build();
        for (message, command, needs_secondary) in [
            (strings::Message::ThreadPrompt, "thread prompt", false),
            (strings::Message::ThreadAnswer, "thread answer", true),
        ] {
            let button = Button::with_label(&strings::text(message));
            let thread = thread_id.clone();
            let secondary = thread_secondary.clone();
            let input = thread_input.clone();
            let request = request_id.clone();
            let session = self.session.clone();
            let status = content.clone();
            button.connect_clicked(move |_| {
                let mut binding = session.borrow_mut();
                let Some(live) = binding.session_mut() else {
                    status.set_label("Thread controls require sign-in.");
                    return;
                };
                let secondary_value = needs_secondary.then(|| secondary.text().trim().to_owned());
                let request_value =
                    (!request.text().trim().is_empty()).then(|| request.text().trim().to_owned());
                match live.thread_action(
                    Some(thread.text().trim()),
                    command,
                    secondary_value.as_deref(),
                    Some(input.text().as_str()),
                    request_value.as_deref(),
                ) {
                    Ok(bytes) => match format_thread_response(&bytes) {
                        Ok(response) => status.set_label(&response),
                        Err(_) => status.set_label("Thread response rejected by Rust policy."),
                    },
                    Err(_) => status.set_label("Thread mutation rejected by Rust policy."),
                }
            });
            thread_actions.append(&button);
        }
        for (message, command, needs_input) in [
            (
                strings::Message::ThreadPlanApprove,
                "thread plan approve",
                false,
            ),
            (
                strings::Message::ThreadPlanRevise,
                "thread plan revise",
                true,
            ),
        ] {
            let button = Button::with_label(&strings::text(message));
            let thread = thread_id.clone();
            let secondary = thread_secondary.clone();
            let input = thread_input.clone();
            let request = request_id.clone();
            let session = self.session.clone();
            let status = content.clone();
            button.connect_clicked(move |_| {
                let mut binding = session.borrow_mut();
                let Some(live) = binding.session_mut() else {
                    status.set_label("Thread controls require sign-in.");
                    return;
                };
                let request_value =
                    (!request.text().trim().is_empty()).then(|| request.text().trim().to_owned());
                let input_value = needs_input.then(|| input.text().to_owned());
                match live.thread_action(
                    Some(thread.text().trim()),
                    command,
                    Some(secondary.text().trim()),
                    input_value.as_deref(),
                    request_value.as_deref(),
                ) {
                    Ok(bytes) => match format_thread_response(&bytes) {
                        Ok(response) => status.set_label(&response),
                        Err(_) => status.set_label("Thread response rejected by Rust policy."),
                    },
                    Err(_) => status.set_label("Thread mutation rejected by Rust policy."),
                }
            });
            thread_actions.append(&button);
        }
        root.append(&thread_id);
        root.append(&thread_secondary);
        root.append(&thread_input);
        root.append(&thread_actions);
        let web_port = Entry::builder()
            .placeholder_text("Web port (1-65535)")
            .hexpand(true)
            .build();
        let web_request = Entry::builder()
            .placeholder_text("Request UUID (for web changes)")
            .hexpand(true)
            .build();
        let web_revision = Entry::builder()
            .placeholder_text("Policy revision")
            .hexpand(true)
            .build();
        let web_actions = Box::new(Orientation::Horizontal, 8);
        // Keep the last authenticated endpoint in memory only.  The URL is
        // accepted from the Rust decoder after machine/route and HTTPS
        // validation; GTK never constructs or persists browser destinations.
        let web_endpoint: Rc<RefCell<Option<mila_native_linux::adapter::WebEndpoint>>> =
            Rc::new(RefCell::new(None));
        for (label_text, operation, public) in [
            (strings::text(strings::Message::WebShow), "show", false),
            (strings::text(strings::Message::WebPublic), "set", true),
            (strings::text(strings::Message::WebPrivate), "set", false),
        ] {
            let button = Button::with_label(&label_text);
            let machine = machine_id.clone();
            let port = web_port.clone();
            let request = web_request.clone();
            let revision = web_revision.clone();
            let session = self.session.clone();
            let status = content.clone();
            let endpoint_state = web_endpoint.clone();
            button.connect_clicked(move |_| {
                let machine_id = machine.text().trim().to_owned();
                let parsed_port = (!port.text().is_empty())
                    .then(|| port.text().parse::<u16>().ok())
                    .flatten();
                let request_id = (!request.text().is_empty()).then(|| request.text().to_string());
                let parsed_revision = (!revision.text().is_empty())
                    .then(|| revision.text().parse::<u64>().ok())
                    .flatten();
                let mut binding = session.borrow_mut();
                let Some(live) = binding.session_mut() else {
                    status.set_label("Web endpoint unavailable until sign-in.");
                    return;
                };
                if operation == "show" {
                    let result = live.web_show(&machine_id).and_then(|bytes| {
                        decode_web_endpoint(&bytes)
                            .map_err(|_| mila_native_linux::session::SessionError::InvalidInput)
                    });
                    match result.as_ref() {
                        Ok(endpoint) => status.set_label(&format!(
                            "Web endpoint\n{}:{} ({}, revision {})",
                            endpoint.label,
                            endpoint.port,
                            endpoint.visibility,
                            endpoint.policy_revision
                        )),
                        Err(_) => status.set_label("Web endpoint read rejected."),
                    }
                    if let Ok(endpoint) = result {
                        *endpoint_state.borrow_mut() = Some(endpoint);
                    }
                } else {
                    let Some(port) = parsed_port else {
                        status.set_label("Web port rejected.");
                        return;
                    };
                    let Some(revision) = parsed_revision else {
                        status.set_label("Web policy revision rejected.");
                        return;
                    };
                    let Some(request_id) = request_id.as_deref() else {
                        status.set_label("Web request id rejected.");
                        return;
                    };
                    if format_web_command(
                        operation,
                        &machine_id,
                        Some(port),
                        public,
                        Some(request_id),
                    )
                    .is_err()
                    {
                        status.set_label("Web request rejected by Rust policy.");
                        return;
                    }
                    match live.web_set(&machine_id, port, public, revision, request_id) {
                        Ok(()) => status.set_label("Web endpoint change submitted."),
                        Err(_) => status.set_label("Web endpoint change rejected."),
                    }
                }
            });
            web_actions.append(&button);
        }
        root.append(&web_port);
        root.append(&web_request);
        root.append(&web_revision);
        root.append(&web_actions);
        let open_web = Button::with_label("Open web endpoint");
        let open_web_status = content.clone();
        let endpoint_state = web_endpoint.clone();
        let open_web_session = self.session.clone();
        open_web.connect_clicked(move |_| {
            if open_web_session.borrow().session().is_none() {
                endpoint_state.borrow_mut().take();
                open_web_status.set_label("Web controls require sign-in.");
                return;
            }
            let Some(endpoint) = endpoint_state.borrow().as_ref().cloned() else {
                open_web_status.set_label("Load a web endpoint before opening it.");
                return;
            };
            let Some(url) = endpoint.url else {
                open_web_status.set_label("This machine has no public web endpoint.");
                return;
            };
            // decode_web_endpoint already enforces HTTPS and the canonical
            // machine route. Re-check the scheme at the launch boundary so a
            // future state refactor cannot turn this into an open redirect.
            if !url.starts_with("https://") {
                open_web_status.set_label("Browser destination rejected by Rust policy.");
                return;
            }
            match gio::AppInfo::launch_default_for_uri(&url, None::<&gio::AppLaunchContext>) {
                Ok(()) => open_web_status.set_label("Web endpoint opened in the browser."),
                Err(_) => open_web_status.set_label("The browser could not open the endpoint."),
            }
        });
        root.append(&open_web);
        let key_id = Entry::builder()
            .placeholder_text("SSH key ID")
            .hexpand(true)
            .build();
        let key_request = Entry::builder()
            .placeholder_text("Request UUID (porsche-…)")
            .hexpand(true)
            .build();
        let revoke = Button::with_label(&strings::text(strings::Message::RevokeKey));
        let key_id_for_action = key_id.clone();
        let key_request_for_action = key_request.clone();
        let label_for_action = content.clone();
        let revoke_session = self.session.clone();
        revoke.connect_clicked(move |_| {
            if revoke_session.borrow().session().is_none() {
                label_for_action.set_label("SSH key controls require sign-in.");
                return;
            }
            match format_ssh_key_revoke(
                key_id_for_action.text().as_str(),
                key_request_for_action.text().as_str(),
            ) {
                Ok(command) => label_for_action.set_label(&format!("SSH key command\n{command}")),
                Err(_) => label_for_action.set_label("SSH key request rejected by Rust policy."),
            }
        });
        root.append(&key_id);
        root.append(&key_request);
        root.append(&revoke);
        root.append(&content);
        ApplicationWindow::builder()
            .application(app)
            .title("Mila")
            .default_width(720)
            .default_height(420)
            .content(&root)
            .build()
    }
    fn activate(&self, app: &adw::Application) {
        self.ensure_window(app).present();
    }
    fn open(&self, app: &adw::Application, files: &[gio::File]) {
        let window = self.ensure_window(app);
        let uris = files.iter().map(|file| file.uri()).collect::<Vec<_>>();
        let batch = ActivationBatch::parse(uris.iter().map(|uri| uri.as_str()));
        let selected_authority = persistence::load()
            .ok()
            .flatten()
            .map(|selection| selection.host);
        let authenticated = self.sign_in.borrow().phase == SignInPhase::SignedIn
            && self.session.borrow().is_authenticated();
        let decisions = batch.decisions(selected_authority.as_deref(), authenticated);
        let rejected = batch.rejected();
        if decisions.is_empty() {
            self.set_status("Mila\nNo supported link could be opened.");
        } else {
            let routes = decisions
                .iter()
                .map(|decision| match decision {
                    NavigationDecision::UnknownDeployment { .. } => {
                        format!("Add deployment before opening {}", decision.canonical())
                    }
                    NavigationDecision::SignInRequired { .. } => {
                        format!("Sign in before opening {}", decision.canonical())
                    }
                    NavigationDecision::Open { .. } => {
                        format!("Open {}", decision.canonical())
                    }
                })
                .collect::<Vec<_>>();
            self.set_status(&format!(
                "Mila\nRoutes:\n{}\nRejected links: {rejected}",
                routes.join("\n")
            ));
        }
        window.present();
    }
    fn set_status(&self, value: &str) {
        if let Some(label) = self.status.borrow().as_ref() {
            label.set_label(value);
        }
    }
}
fn main() -> glib::ExitCode {
    adw::init().expect("GTK/libadwaita initialization failed");
    let css = gtk::CssProvider::new();
    css.load_from_data("* { font-family: JetBrains Mono, monospace; font-size: 14px; } window, box { background: #fff; color: #000; } button, entry { border: 2px solid #000; border-radius: 0; background: #eee; color: #000; } button:hover { background: #000; color: #fff; } @media (prefers-color-scheme: dark) { window, box { background: #000; color: #fff; } button, entry { border-color: #fff; background: #111; color: #fff; } button:hover { background: #fff; color: #000; } } ");
    gtk::style_context_add_provider_for_display(
        &gtk::gdk::Display::default().expect("display"),
        &css,
        gtk::STYLE_PROVIDER_PRIORITY_APPLICATION,
    );
    let application = Application::builder()
        .application_id(APPLICATION_ID)
        .flags(gio::ApplicationFlags::HANDLES_OPEN)
        .build();
    let state = NativeState::new();
    let a = state.clone();
    application.connect_activate(move |app| a.activate(app));
    let o = state.clone();
    application.connect_open(move |app, files, _| o.open(app, files));
    application.run()
}
