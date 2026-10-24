use hegel::{generators as gs, TestCase};
use mila_runtime::{
    AppLock, LockAvailability, LockDelay, LockEvent, LockPhase, MachineSnapshot, SnapshotMachine,
    MAX_SNAPSHOT_BYTES,
};
use mila_runtime::{AttachOutcome, AttachPhase, TerminalAttach};
use mila_runtime::{PokeEnvelope, RuntimeError, SnapshotStore};
use mila_runtime::{MutationPhase, MutationTracker, NextAction};
use mila_model::RequestId;
use mila_runtime::{PushEnvironment, PushProvider, PushRegistrationRequest};

#[hegel::test(test_cases = 64)]
fn terminal_output_never_advances_before_connection(tc: TestCase) {
    let generation = tc.draw(gs::default::<u64>());
    let bytes = tc.draw(gs::default::<u8>());
    let mut state = TerminalAttach::initial();
    assert!(!state.output(generation, bytes as usize));
    assert_eq!(state.phase(), AttachPhase::Idle);
    assert!(state.request());
    assert!(state.connected(state.generation(), 0));
    assert_eq!(state.output(state.generation(), bytes as usize), bytes > 0);
    assert!(state.ended(state.generation(), AttachOutcome::Closed));
}

#[hegel::test(test_cases = 128)]
fn mutation_uncertainty_never_allocates_a_second_request(tc: TestCase) {
    let suffix = tc.draw(gs::default::<u64>());
    let id = RequestId::parse(&format!("porsche-{suffix:032x}")).expect("request id");
    let mut tracker = MutationTracker::submitted(id.clone());
    tracker.uncertain();
    let polls = tc.draw(gs::default::<u8>()) as usize;
    for _ in 0..polls {
        tracker.polled().expect("poll");
    }
    assert_eq!(tracker.request_id, id);
    assert_eq!(tracker.phase, MutationPhase::Uncertain);
    assert_eq!(tracker.next_action(), NextAction::Poll);
}

#[hegel::test(test_cases = 128)]
fn terminal_reconnect_rejects_stale_generation_output(tc: TestCase) {
    let bytes = tc.draw(gs::default::<u8>()).max(1) as usize;
    let mut state = TerminalAttach::initial();
    assert!(state.request());
    let first = state.generation();
    assert!(state.connected(first, 0));
    assert!(state.output(first, bytes));
    let cursor_before_reconnect = state.cursor();
    assert!(state.ended(first, AttachOutcome::Transport));
    assert!(state.request());
    let second = state.generation();
    assert_ne!(first, second);
    assert!(state.connected(second, cursor_before_reconnect));
    let cursor_before_stale = state.cursor();
    assert!(!state.output(first, bytes));
    assert_eq!(state.cursor(), cursor_before_stale);
    assert!(state.output(second, bytes));
}

#[derive(Default)]
struct MemoryStore {
    bytes: std::cell::RefCell<Option<Vec<u8>>>,
}

impl SnapshotStore for MemoryStore {
    fn read(&self, _deployment: &str) -> Result<Option<Vec<u8>>, RuntimeError> {
        Ok(self.bytes.borrow().clone())
    }

    fn write(&self, _deployment: &str, bytes: &[u8]) -> Result<(), RuntimeError> {
        *self.bytes.borrow_mut() = Some(bytes.to_vec());
        Ok(())
    }
}

#[hegel::test(test_cases = 64)]
fn arbitrary_bytes_never_panic(tc: TestCase) {
    let bytes = tc.draw(gs::vecs(gs::default::<u8>()).max_size(2_000));
    let _ = MachineSnapshot::decode(&bytes, "control.example.test", None);
}

#[hegel::test(test_cases = 64)]
fn encoded_snapshots_round_trip(tc: TestCase) {
    let name_bytes = tc.draw(gs::vecs(gs::default::<u8>()).max_size(32));
    let id_bytes = tc.draw(gs::vecs(gs::default::<u8>()).max_size(32));
    let name = String::from_utf8_lossy(&name_bytes).into_owned();
    let id = String::from_utf8_lossy(&id_bytes).into_owned();
    let machine = SnapshotMachine {
        id,
        name,
        desired_state: "running".into(),
        observed_state: None,
        pinned: false,
        owner: None,
        read: true,
        write: false,
        manage: false,
    };
    let snapshot = MachineSnapshot::new("control.example.test".into(), None, 10, vec![machine])
        .expect("valid");
    let encoded = snapshot.encode().expect("encode");
    assert!(encoded.len() <= MAX_SNAPSHOT_BYTES);
    assert_eq!(
        MachineSnapshot::decode(&encoded, "control.example.test", None).expect("decode"),
        snapshot
    );
}

#[hegel::test(test_cases = 64)]
fn arbitrary_registration_inputs_never_panic(tc: TestCase) {
    let token =
        String::from_utf8_lossy(&tc.draw(gs::vecs(gs::default::<u8>()).max_size(800))).into_owned();
    let app =
        String::from_utf8_lossy(&tc.draw(gs::vecs(gs::default::<u8>()).max_size(300))).into_owned();
    let host =
        String::from_utf8_lossy(&tc.draw(gs::vecs(gs::default::<u8>()).max_size(300))).into_owned();
    let _ = PushRegistrationRequest::new(
        PushProvider::Fcm,
        token,
        app,
        PushEnvironment::Production,
        host,
        None,
    );
}

#[hegel::test(test_cases = 128)]
fn push_replies_never_accept_expired_or_unbounded_values(tc: TestCase) {
    let raw_key = tc.draw(gs::vecs(gs::default::<u8>()).max_size(900));
    let push_key = "A".repeat(16 + raw_key.len().min(684));
    let key_id = String::from_utf8_lossy(
        &tc.draw(gs::vecs(gs::default::<u8>()).max_size(180)),
    )
    .into_owned();
    let now = tc.draw(gs::default::<u64>());
    let expires = tc.draw(gs::default::<u64>());
    if let Ok(reply) = mila_runtime::PushRegistrationReply::new(
        push_key,
        key_id,
        expires,
        now,
    ) {
        assert!(reply.expires_at > now);
        assert!((16..=700).contains(&reply.push_key.len()));
        assert!(!reply.key_id.is_empty());
        assert!(reply.key_id.len() <= 128);
    }
}

#[hegel::test(test_cases = 64)]
fn arbitrary_poke_metadata_never_panics(tc: TestCase) {
    let bytes = tc.draw(gs::vecs(gs::default::<u8>()).max_size(5_000));
    let text = String::from_utf8_lossy(&bytes);
    let envelope = PokeEnvelope {
        deployment: text.to_string(),
        push_key: text.to_string(),
        delivery_id: text.to_string(),
        collapse_id: text.to_string(),
        kind: text.to_string(),
        issued_at: tc.draw(gs::default::<u64>()),
        nonce: text.to_string(),
        ciphertext: text.to_string(),
    };
    let _ = envelope.validate(1_000);
}

#[test]
fn registration_restricts_origins_and_secrets() {
    let token = "a".repeat(32);
    let req = PushRegistrationRequest::new(
        PushProvider::Apns,
        token,
        "com.example.mila".into(),
        PushEnvironment::Production,
        "mila.example.test".into(),
        None,
    )
    .expect("valid");
    assert_eq!(PushProvider::Apns.origin(), "https://api.push.apple.com");
    assert!(!format!("{req:?}").contains("aaaa"));
    assert!(PushRegistrationRequest::new(
        PushProvider::Fcm,
        "a".repeat(32),
        "app".into(),
        PushEnvironment::Development,
        "mila.example.test".into(),
        None
    )
    .is_err());
    assert!(PushRegistrationRequest::new(
        PushProvider::Wns,
        "https://evil.example/channel".into(),
        "app".into(),
        PushEnvironment::Production,
        "mila.example.test".into(),
        Some("https://evil.example/channel".into())
    )
    .is_err());
}

#[hegel::test(test_cases = 64)]
fn lock_never_unlocks_from_stale_or_failed_results(tc: TestCase) {
    let generated = tc.draw(gs::default::<u32>());
    let lock = AppLock::start(true, LockDelay::Immediate)
        .apply(LockEvent::Availability(LockAvailability::Available))
        .apply(LockEvent::UnlockRequested);
    assert_eq!(lock.phase, LockPhase::Authenticating);
    let stale_attempt = if generated == lock.attempt {
        generated.wrapping_add(1)
    } else {
        generated
    };
    let stale = lock.apply(LockEvent::UnlockFinished {
        attempt: stale_attempt,
        success: true,
    });
    assert_eq!(stale.phase, LockPhase::Authenticating);
    let failed = stale.apply(LockEvent::UnlockFinished {
        attempt: stale.attempt,
        success: false,
    });
    assert_eq!(failed.phase, LockPhase::Locked);
    assert!(failed.obscured());
}

#[test]
fn lock_relocks_after_elapsed_background_delay() {
    let lock = AppLock::start(false, LockDelay::OneMinute)
        .apply(LockEvent::Availability(LockAvailability::Available))
        .apply(LockEvent::Enable)
        .apply(LockEvent::Backgrounded(10))
        .apply(LockEvent::Foregrounded(60_010));
    assert_eq!(lock.phase, LockPhase::Locked);
}

#[hegel::test(test_cases = 64)]
fn snapshot_persistence_never_replaces_newer_data(tc: TestCase) {
    let old = tc.draw(gs::default::<u64>());
    let delta = tc.draw(gs::default::<u16>()) as u64;
    let newer = old.saturating_add(delta);
    let store = MemoryStore::default();
    let cached =
        MachineSnapshot::new("control.example.test".into(), None, old, vec![]).expect("valid");
    let _ = mila_runtime::save_snapshot_if_newer(&store, None, cached.clone()).expect("save");
    let incoming =
        MachineSnapshot::new("control.example.test".into(), None, newer, vec![]).expect("valid");
    let selected = mila_runtime::save_snapshot_if_newer(&store, None, incoming).expect("save");
    assert_eq!(selected.saved_at, newer.max(old));
    let loaded = mila_runtime::load_snapshot(&store, "control.example.test", None)
        .expect("load")
        .expect("snapshot");
    assert_eq!(loaded.saved_at, newer.max(old));
}

#[test]
fn snapshot_store_rejects_cross_deployment_bytes() {
    let store = MemoryStore::default();
    let snapshot =
        MachineSnapshot::new("control.example.test".into(), None, 1, vec![]).expect("valid");
    let bytes = snapshot.encode().expect("encode");
    *store.bytes.borrow_mut() = Some(bytes);
    assert_eq!(
        mila_runtime::load_snapshot(&store, "other.example.test", None),
        Err(RuntimeError::InvalidSnapshot)
    );
}
