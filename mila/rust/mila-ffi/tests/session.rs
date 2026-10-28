use base64::{engine::general_purpose::STANDARD, Engine};
use mila_ffi::session::*;
use mila_transport::{
    ssh::{DeviceSigner, SshError},
    TrustDocument,
};
use russh::{
    keys::{
        ssh_key::certificate::{Builder, CertType},
        Algorithm, Certificate, PrivateKey,
    },
    server, Channel, ChannelId,
};
use serde_json::{json, Value};
use std::collections::VecDeque;
use std::sync::Mutex;
use std::{
    sync::{
        atomic::{AtomicUsize, Ordering},
        Arc,
    },
    time::{Duration, SystemTime, UNIX_EPOCH},
};

struct HardwareStandIn {
    key: p256::ecdsa::SigningKey,
    calls: Arc<AtomicUsize>,
}

const FIRST: &str = "00000000-0000-0000-0000-000000000001";

fn machine(id: &str, name: &str) -> Value {
    json!({"id": id, "name": name, "desired_state": "running", "observed_state": "running",
        "owner": true, "pinned": false, "permissions": {"read": true, "write": true, "manage": true}})
}
fn page(items: Vec<Value>, cursor: Option<&str>) -> Vec<u8> {
    serde_json::to_vec(&json!({"version": 1, "status": "succeeded", "result": {"items": items, "next_cursor": cursor}})).unwrap()
}
fn reply(command: &str, bytes: Vec<u8>) -> Response {
    Response {
        command: command.into(),
        bytes,
        exit: Some(0),
    }
}

impl DeviceSigner for HardwareStandIn {
    async fn sign(&mut self, message: &[u8]) -> Result<[u8; 64], SshError> {
        use p256::ecdsa::signature::Signer;
        self.calls.fetch_add(1, Ordering::SeqCst);
        let signature: p256::ecdsa::Signature = self.key.sign(message);
        Ok(signature.to_bytes().into())
    }
}
fn identity(calls: Arc<AtomicUsize>) -> (String, HardwareStandIn) {
    let key = p256::ecdsa::SigningKey::from_slice(&[7; 32]).unwrap();
    let mut blob = Vec::new();
    for bytes in [
        b"ecdsa-sha2-nistp256".as_slice(),
        b"nistp256",
        key.verifying_key().to_encoded_point(false).as_bytes(),
    ] {
        blob.extend_from_slice(&(bytes.len() as u32).to_be_bytes());
        blob.extend_from_slice(bytes);
    }
    (
        format!("ecdsa-sha2-nistp256 {}", STANDARD.encode(blob)),
        HardwareStandIn { key, calls },
    )
}
struct Response {
    command: String,
    bytes: Vec<u8>,
    exit: Option<u32>,
}
struct Handler {
    responses: Arc<Mutex<VecDeque<Response>>>,
    pending: Option<Response>,
    authentications: Arc<AtomicUsize>,
}
impl server::Handler for Handler {
    type Error = russh::Error;
    async fn auth_publickey(
        &mut self,
        _: &str,
        _: &russh::keys::PublicKey,
    ) -> Result<server::Auth, Self::Error> {
        self.authentications.fetch_add(1, Ordering::SeqCst);
        Ok(server::Auth::Accept)
    }
    async fn channel_open_session(
        &mut self,
        _: Channel<server::Msg>,
        reply: server::ChannelOpenHandle,
        _: &mut server::Session,
    ) -> Result<(), Self::Error> {
        reply.accept().await;
        Ok(())
    }
    async fn exec_request(
        &mut self,
        channel: ChannelId,
        data: &[u8],
        session: &mut server::Session,
    ) -> Result<(), Self::Error> {
        let response = self
            .responses
            .lock()
            .unwrap()
            .pop_front()
            .expect("unexpected command");
        assert_eq!(data, response.command.as_bytes());
        self.pending = Some(response);
        session.channel_success(channel)?;
        Ok(())
    }
    async fn channel_eof(
        &mut self,
        channel: ChannelId,
        session: &mut server::Session,
    ) -> Result<(), Self::Error> {
        session.extended_data(channel, 1, b"discard progress".to_vec())?;
        let response = self.pending.take().unwrap();
        session.data(channel, response.bytes)?;
        if let Some(exit) = response.exit {
            session.exit_status_request(channel, exit)?;
        }
        session.eof(channel)?;
        session.close(channel)?;
        Ok(())
    }
}
async fn endpoint(
    responses: Arc<Mutex<VecDeque<Response>>>,
) -> (
    TrustDocument,
    u16,
    Arc<AtomicUsize>,
    tokio::task::JoinHandle<()>,
) {
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs();
    let ca = PrivateKey::random(&mut rand::rng(), Algorithm::Ed25519).unwrap();
    let host = PrivateKey::random(&mut rand::rng(), Algorithm::Ed25519).unwrap();
    let mut builder = Builder::new(
        vec![1; 32],
        host.public_key().key_data().clone(),
        now - 60,
        now + 60,
    )
    .unwrap();
    builder
        .cert_type(CertType::Host)
        .unwrap()
        .key_id("test")
        .unwrap()
        .valid_principal("localhost")
        .unwrap();
    let certificate: Certificate = builder.sign(&ca).unwrap();
    let trust = TrustDocument {
        version: 1,
        ca: ca.public_key().to_openssh().unwrap(),
        management_host: "localhost".into(),
        zone: "example".into(),
        retirement: now + 60,
    };
    let mut config = server::Config {
        keys: vec![host],
        ..Default::default()
    };
    config.certificates = vec![certificate];
    config.auth_rejection_time = Duration::ZERO;
    let listener = tokio::net::TcpListener::bind(("127.0.0.1", 0))
        .await
        .unwrap();
    let port = listener.local_addr().unwrap().port();
    let authentications = Arc::new(AtomicUsize::new(0));
    let count = authentications.clone();
    let task = tokio::spawn(async move {
        let (socket, _) = listener.accept().await.unwrap();
        if let Ok(connection) = server::run_stream(
            Arc::new(config),
            socket,
            Handler {
                authentications: count,
                responses,
                pending: None,
            },
        )
        .await
        {
            let _ = connection.await;
        }
    });
    (trust, port, authentications, task)
}

unsafe extern "C" fn sign(context: usize, message: *const u8, len: usize, output: *mut u8) -> i32 {
    use p256::ecdsa::signature::Signer;
    let signer = &*(context as *const HardwareStandIn);
    signer.calls.fetch_add(1, Ordering::SeqCst);
    let signature: p256::ecdsa::Signature =
        signer.key.sign(std::slice::from_raw_parts(message, len));
    std::ptr::copy_nonoverlapping(signature.to_bytes().as_ptr(), output, 64);
    0
}
#[test]
fn ffi_real_ssh_read_snapshot_and_close() {
    let runtime = tokio::runtime::Builder::new_multi_thread()
        .worker_threads(2)
        .enable_all()
        .build()
        .unwrap();
    let responses = Arc::new(Mutex::new(VecDeque::from([
        reply("ls --json", page(vec![machine(FIRST, "live")], None)),
        reply("ls --json", b"malformed".to_vec()),
    ])));
    let (trust, port, auth, task) = runtime.block_on(endpoint(responses.clone()));
    let (public, signer) = identity(Arc::new(AtomicUsize::new(0)));
    let trust = serde_json::to_vec(&trust).unwrap();
    let mut handle = 0;
    unsafe {
        assert_eq!(
            mila_session_connect(
                trust.as_ptr(),
                trust.len(),
                b"localhost".as_ptr(),
                9,
                public.as_ptr(),
                public.len(),
                port,
                5000,
                Some(sign),
                &signer as *const _ as usize,
                &mut handle
            ),
            SessionStatus::Ok
        );
        assert_ne!(handle, 0);
        assert_eq!(mila_session_read_machines(handle, 0), SessionStatus::Ok);
        let mut required = 0;
        assert_eq!(
            mila_session_listing(handle, std::ptr::null_mut(), 0, &mut required),
            SessionStatus::SmallBuffer
        );
        let mut data = vec![0; required];
        assert_eq!(
            mila_session_listing(handle, data.as_mut_ptr(), data.len(), &mut required),
            SessionStatus::Ok
        );
        let value: Value = serde_json::from_slice(&data).unwrap();
        assert_eq!(value["machines"][0]["name"], "live");
        assert_eq!(
            mila_session_read_machines(handle, 0),
            SessionStatus::Transport
        );
        assert_eq!(
            mila_session_snapshot(handle, 42, std::ptr::null_mut(), 0, &mut required),
            SessionStatus::SmallBuffer
        );
        let mut snapshot = vec![0; required];
        assert_eq!(
            mila_session_snapshot(
                handle,
                42,
                snapshot.as_mut_ptr(),
                snapshot.len(),
                &mut required
            ),
            SessionStatus::Ok
        );
        let decoded =
            mila_runtime::MachineSnapshot::decode(&snapshot, "localhost", Some(port)).unwrap();
        assert_eq!(decoded.machines[0].name, "live");
        assert_eq!(decoded.saved_at, 42);
        assert_eq!(mila_session_close(handle), SessionStatus::Ok);
        assert_eq!(mila_session_close(handle), SessionStatus::InvalidHandle);
        assert_eq!(
            mila_session_listing(handle, data.as_mut_ptr(), data.len(), &mut required),
            SessionStatus::InvalidHandle
        );
    }
    assert_eq!(signer.calls.load(Ordering::SeqCst), 1);
    assert_eq!(auth.load(Ordering::SeqCst), 1);
    assert!(responses.lock().unwrap().is_empty());
    task.abort();
}
#[hegel::test(test_cases = 128)]
fn arbitrary_stale_handles_refuse_without_writing(tc: hegel::TestCase) {
    let handle = tc.draw(hegel::generators::default::<u64>()) | (1u64 << 63);
    let mut output = [0xA5; 32];
    let mut written = 123;
    unsafe {
        assert_eq!(
            mila_session_listing(handle, output.as_mut_ptr(), output.len(), &mut written),
            SessionStatus::InvalidHandle
        );
    }
    assert_eq!(output, [0xA5; 32]);
    assert_eq!(written, 123);
    assert_eq!(mila_session_close(handle), SessionStatus::InvalidHandle);
}

#[test]
fn machine_actions_reject_invalid_inputs_before_lookup() {
    let machine = b"not-an-id";
    let action = b"start";
    let request = b"porsche-00000000000000000000000000000000";
    let status = unsafe {
        mila_session_machine_action(
            u64::MAX,
            machine.as_ptr(),
            machine.len(),
            action.as_ptr(),
            action.len(),
            request.as_ptr(),
            request.len(),
        )
    };
    assert_eq!(status, SessionStatus::InvalidHandle);
}

/// PTY handles are opaque capabilities. Every generated stale handle must be
/// rejected without modifying caller-owned output or length storage.
#[hegel::test(test_cases = 128)]
fn arbitrary_stale_terminal_handles_refuse_without_writing(tc: hegel::TestCase) {
    let handle = tc.draw(hegel::generators::default::<u64>()) | (1_u64 << 63);
    let mut output = [0xA5; 64];
    let mut written = 17_usize;
    unsafe {
        assert_eq!(
            mila_session_terminal_poll(handle, output.as_mut_ptr(), output.len(), &mut written),
            SessionStatus::InvalidHandle
        );
        assert_eq!(
            mila_session_terminal_input(handle, b"x".as_ptr(), 1),
            SessionStatus::InvalidHandle
        );
    }
    assert_eq!(
        mila_session_terminal_resize(handle, 80, 24),
        SessionStatus::InvalidHandle
    );
    assert_eq!(
        mila_session_terminal_kill(handle),
        SessionStatus::InvalidHandle
    );
    assert_eq!(output, [0xA5; 64]);
    assert_eq!(written, 17);
}

/// Dimension validation is stable across the full generated input space and
/// does not perform a session lookup for malformed dimensions.
#[hegel::test(test_cases = 128)]
fn arbitrary_terminal_dimensions_are_bounded_before_lookup(tc: hegel::TestCase) {
    let columns = tc.draw(hegel::generators::default::<u32>());
    let rows = tc.draw(hegel::generators::default::<u32>());
    let valid = (1..=4096).contains(&columns) && (1..=512).contains(&rows);
    let mut terminal = 0_u64;
    let status = mila_session_terminal_attach(u64::MAX, columns, rows, &mut terminal);
    if valid {
        assert_eq!(status, SessionStatus::InvalidHandle);
    } else {
        assert_eq!(status, SessionStatus::Invalid);
    }
    assert_eq!(terminal, 0);
}
