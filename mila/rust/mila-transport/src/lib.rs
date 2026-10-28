//! Strict Porsche SSH host certificate validation.
use base64::{engine::general_purpose::STANDARD, Engine};
use ed25519_dalek::{Signature, Verifier, VerifyingKey};
use thiserror::Error;

const ALG: &[u8] = b"ssh-ed25519-cert-v01@openssh.com";
const MAX: usize = 16_384;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct HostCertificate {
    pub public_key: [u8; 32],
    pub ca: String,
    pub principals: Vec<String>,
    pub valid_after: u64,
    pub valid_before: u64,
    signed: Vec<u8>,
    signature: [u8; 64],
}
#[derive(Clone, Copy, Debug, Eq, PartialEq, Error)]
pub enum HostRefusal {
    #[error("malformed")]
    Malformed,
    #[error("wrong authority")]
    WrongAuthority,
    #[error("wrong principal")]
    WrongPrincipal,
    #[error("not yet valid")]
    NotYetValid,
    #[error("expired")]
    Expired,
    #[error("bad signature")]
    BadSignature,
}

struct Reader<'a> {
    b: &'a [u8],
    o: usize,
}
impl<'a> Reader<'a> {
    fn field(&mut self) -> Option<&'a [u8]> {
        let n = self.u32()? as usize;
        let e = self.o.checked_add(n)?;
        let v = self.b.get(self.o..e)?;
        self.o = e;
        Some(v)
    }
    fn u32(&mut self) -> Option<u32> {
        let x = self.b.get(self.o..self.o + 4)?;
        self.o += 4;
        Some(u32::from_be_bytes(x.try_into().ok()?))
    }
    fn u64(&mut self) -> Option<u64> {
        let x = self.b.get(self.o..self.o + 8)?;
        self.o += 8;
        Some(u64::from_be_bytes(x.try_into().ok()?))
    }
    fn done(&self) -> bool {
        self.o == self.b.len()
    }
}
fn host(s: &str) -> bool {
    !s.is_empty()
        && s.len() <= 253
        && s.bytes()
            .all(|c| c.is_ascii_alphanumeric() || c == b'.' || c == b'-')
        && !s.starts_with('.')
        && !s.ends_with('.')
}
fn key_line(raw: &[u8]) -> Option<String> {
    if raw.len() != 32 {
        return None;
    }
    let mut b = Vec::new();
    b.extend((11u32).to_be_bytes());
    b.extend(b"ssh-ed25519");
    b.extend((32u32).to_be_bytes());
    b.extend(raw);
    Some(format!("ssh-ed25519 {}", STANDARD.encode(b)))
}
pub fn parse_host_certificate_blob(blob: &[u8]) -> Option<HostCertificate> {
    if blob.len() > MAX {
        return None;
    }
    let mut r = Reader { b: blob, o: 0 };
    if r.field() != Some(ALG) {
        return None;
    };
    let nonce = r.field()?;
    if !(16..=64).contains(&nonce.len()) {
        return None;
    };
    let k = r.field()?;
    let public_key: [u8; 32] = k.try_into().ok()?;
    let _serial = r.u64()?;
    if r.u32() != Some(2) {
        return None;
    };
    let id = r.field()?;
    if id.is_empty() || id.len() > 128 || std::str::from_utf8(id).is_err() {
        return None;
    };
    let names = r.field()?;
    let mut nr = Reader { b: names, o: 0 };
    let mut principals = Vec::new();
    while !nr.done() {
        let n = std::str::from_utf8(nr.field()?).ok()?.to_owned();
        if !host(&n) || principals.contains(&n) || principals.len() >= 8 {
            return None;
        }
        principals.push(n)
    }
    let after = r.u64()?;
    let before = r.u64()?;
    if after >= before {
        return None;
    };
    for _ in 0..3 {
        if !r.field()?.is_empty() {
            return None;
        }
    }
    let ca_blob = r.field()?;
    let mut ca_reader = Reader { b: ca_blob, o: 0 };
    if ca_reader.field()? != b"ssh-ed25519" {
        return None;
    }
    let ca = key_line(ca_reader.field()?)?;
    if !ca_reader.done() {
        return None;
    }
    let signed_len = r.o;
    let sf = r.field()?;
    if !r.done() {
        return None;
    };
    let mut sr = Reader { b: sf, o: 0 };
    if sr.field() != Some(b"ssh-ed25519") {
        return None;
    };
    let sig: [u8; 64] = sr.field()?.try_into().ok()?;
    if !sr.done() {
        return None;
    };
    Some(HostCertificate {
        public_key,
        ca,
        principals,
        valid_after: after,
        valid_before: before,
        signed: blob[..signed_len].to_vec(),
        signature: sig,
    })
}
pub fn parse_host_certificate_line(line: &str) -> Option<HostCertificate> {
    if line.len() > MAX {
        return None;
    }
    let mut p = line.split_whitespace();
    if p.next()? != "ssh-ed25519-cert-v01@openssh.com" {
        return None;
    }
    let raw = p.next()?;
    if p.next().is_some() {
        return None;
    }
    let b = STANDARD.decode(raw).ok()?;
    parse_host_certificate_blob(&b)
}
pub fn verify_host_certificate(
    cert: &HostCertificate,
    ca: &str,
    principal: &str,
    now: u64,
) -> Result<(), HostRefusal> {
    let raw = ca
        .strip_prefix("ssh-ed25519 ")
        .and_then(|x| STANDARD.decode(x).ok())
        .and_then(|b| {
            let mut r = Reader { b: &b, o: 0 };
            if r.field()? != b"ssh-ed25519" {
                return None;
            };
            let k = r.field()?;
            if !r.done() {
                return None;
            };
            Some(k.to_vec())
        })
        .ok_or(HostRefusal::Malformed)?;
    if cert.ca != ca {
        return Err(HostRefusal::WrongAuthority);
    }
    if !cert.principals.iter().any(|p| p == principal) {
        return Err(HostRefusal::WrongPrincipal);
    }
    if now < cert.valid_after {
        return Err(HostRefusal::NotYetValid);
    }
    if now >= cert.valid_before {
        return Err(HostRefusal::Expired);
    }
    let key = VerifyingKey::from_bytes(
        raw.as_slice()
            .try_into()
            .map_err(|_| HostRefusal::Malformed)?,
    )
    .map_err(|_| HostRefusal::Malformed)?;
    key.verify(&cert.signed, &Signature::from_bytes(&cert.signature))
        .map_err(|_| HostRefusal::BadSignature)
}

/// A bounded request accepted by a Porsche session.
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum SessionRequest {
    Exec { command: String },
    Watch { machine_id: String },
}
/// Typed replies keep transport details out of native UI wrappers.
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum SessionReply {
    Output(Vec<u8>),
    State { machine_id: String, state: String },
    Closed,
}
#[derive(Clone, Copy, Debug, Eq, PartialEq, Error)]
pub enum TransportError {
    #[error("session is closed")]
    Closed,
    #[error("request exceeds bounds")]
    RequestTooLarge,
    #[error("transport unavailable")]
    Unavailable,
}
/// Platform implementations provide the I/O while the Rust core owns validation.
pub trait PorscheSession {
    fn send(&mut self, request: SessionRequest) -> Result<SessionReply, TransportError>;
}

/// A deployment's published SSH trust policy.
#[derive(Clone, Debug, Eq, PartialEq, serde::Serialize, serde::Deserialize)]
pub struct TrustDocument {
    pub version: u8,
    pub ca: String,
    pub management_host: String,
    pub zone: String,
    pub retirement: u64,
}
impl TrustDocument {
    pub fn same_authority(&self, other: &Self) -> bool {
        self.ca == other.ca
            && self.management_host == other.management_host
            && self.zone == other.zone
    }
}
#[derive(Clone, Copy, Debug, Eq, PartialEq, Error)]
pub enum TrustRefusal {
    #[error("malformed")]
    Malformed,
    #[error("wrong host")]
    WrongHost,
    #[error("retired")]
    Retired,
    #[error("conflicts")]
    Conflicts,
}
const MAX_TRUST_BYTES: usize = 8192;
fn valid_hostname(s: &str, max: usize) -> bool {
    if s.is_empty() || s.len() > max {
        return false;
    }
    s.split('.').all(|label| {
        !label.is_empty()
            && label.len() <= 63
            && !label.starts_with('-')
            && !label.ends_with('-')
            && label
                .bytes()
                .all(|c| c.is_ascii_alphanumeric() || c == b'-')
    })
}
fn canonical_ca(s: &str) -> bool {
    let Some(raw) = s.strip_prefix("ssh-ed25519 ") else {
        return false;
    };
    let Ok(b) = STANDARD.decode(raw) else {
        return false;
    };
    let mut r = Reader { b: &b, o: 0 };
    r.field() == Some(b"ssh-ed25519") && r.field().is_some_and(|k| k.len() == 32) && r.done()
}
pub fn decode_trust_document(
    bytes: &[u8],
    origin_host: &str,
    now: u64,
) -> Result<TrustDocument, TrustRefusal> {
    if bytes.len() > MAX_TRUST_BYTES {
        return Err(TrustRefusal::Malformed);
    }
    let value: serde_json::Value =
        serde_json::from_slice(bytes).map_err(|_| TrustRefusal::Malformed)?;
    let obj = value.as_object().ok_or(TrustRefusal::Malformed)?;
    const KEYS: [&str; 5] = ["version", "ca", "management_host", "zone", "retirement"];
    if obj.len() != KEYS.len() || KEYS.iter().any(|k| !obj.contains_key(*k)) {
        return Err(TrustRefusal::Malformed);
    }
    let version = obj["version"]
        .as_u64()
        .filter(|v| *v == 1)
        .ok_or(TrustRefusal::Malformed)? as u8;
    let ca = obj["ca"]
        .as_str()
        .filter(|v| canonical_ca(v))
        .ok_or(TrustRefusal::Malformed)?
        .to_owned();
    let host = obj["management_host"]
        .as_str()
        .filter(|v| valid_hostname(v, 180))
        .ok_or(TrustRefusal::Malformed)?
        .to_owned();
    let zone = obj["zone"]
        .as_str()
        .filter(|v| valid_hostname(v, 189))
        .ok_or(TrustRefusal::Malformed)?
        .to_owned();
    let retirement = obj["retirement"].as_u64().ok_or(TrustRefusal::Malformed)?;
    if host != origin_host {
        return Err(TrustRefusal::WrongHost);
    }
    if retirement <= now {
        return Err(TrustRefusal::Retired);
    }
    Ok(TrustDocument {
        version,
        ca,
        management_host: host,
        zone,
        retirement,
    })
}
pub fn reconcile_trust(
    pinned: Option<&TrustDocument>,
    fetched: TrustDocument,
) -> Result<TrustDocument, TrustRefusal> {
    let Some(old) = pinned else {
        return Ok(fetched);
    };
    if !old.same_authority(&fetched) {
        return Err(TrustRefusal::Conflicts);
    }
    Ok(if fetched.retirement >= old.retirement {
        fetched
    } else {
        old.clone()
    })
}

/// Terminal attachment request and bounded watch subscription.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TerminalAttachRequest {
    pub machine_id: uuid::Uuid,
    pub session_id: uuid::Uuid,
    pub from: u64,
    pub columns: u16,
    pub rows: u16,
    pub read_write: bool,
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct WatchRequest {
    pub machines: Vec<uuid::Uuid>,
    pub threads: Vec<uuid::Uuid>,
}
#[derive(Clone, Copy, Debug, Eq, PartialEq, Error)]
pub enum RequestRefusal {
    #[error("too many filters")]
    TooManyFilters,
    #[error("invalid dimensions")]
    InvalidDimensions,
}
impl WatchRequest {
    pub const MAX_FILTERS: usize = 64;
    pub fn new(
        mut machines: Vec<uuid::Uuid>,
        mut threads: Vec<uuid::Uuid>,
    ) -> Result<Self, RequestRefusal> {
        machines.sort();
        machines.dedup();
        threads.sort();
        threads.dedup();
        if machines.len() + threads.len() > Self::MAX_FILTERS {
            return Err(RequestRefusal::TooManyFilters);
        }
        Ok(Self { machines, threads })
    }
}
impl TerminalAttachRequest {
    pub fn validate(&self) -> Result<(), RequestRefusal> {
        if self.columns == 0 || self.columns > 4096 || self.rows == 0 || self.rows > 512 {
            Err(RequestRefusal::InvalidDimensions)
        } else {
            Ok(())
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum WatchEvent {
    Watching {
        session_id: uuid::Uuid,
        machines: Vec<uuid::Uuid>,
        threads: Vec<uuid::Uuid>,
    },
    Heartbeat,
    MachineChanged(uuid::Uuid),
    TerminalSessionsChanged(uuid::Uuid),
    ThreadChanged(uuid::Uuid),
    Resync,
    Session {
        id: uuid::Uuid,
        authenticated: bool,
    },
    Unknown,
}
#[derive(Clone, Copy, Debug, Eq, PartialEq, Error)]
#[error("invalid watch line: {0}")]
pub struct WatchFormat(pub &'static str);
pub const MAX_WATCH_LINE_BYTES: usize = 65_536;
pub fn decode_watch_line(line: &[u8]) -> Result<WatchEvent, WatchFormat> {
    if line.len() > MAX_WATCH_LINE_BYTES {
        return Err(WatchFormat("too long"));
    }
    let v: serde_json::Value = serde_json::from_slice(line).map_err(|_| WatchFormat("json"))?;
    let o = v.as_object().ok_or(WatchFormat("object"))?;
    if o.get("version").and_then(|v| v.as_u64()) != Some(1) {
        return Err(WatchFormat("version"));
    }
    let event = o
        .get("event")
        .and_then(|v| v.as_str())
        .ok_or(WatchFormat("event"))?;
    let id = |k: &str| {
        o.get(k)
            .and_then(|v| v.as_str())
            .and_then(|s| uuid::Uuid::parse_str(s).ok())
            .ok_or(WatchFormat("field"))
    };
    let ids = |k: &str| -> Result<Vec<uuid::Uuid>, WatchFormat> {
        let a = o
            .get(k)
            .and_then(|v| v.as_array())
            .ok_or(WatchFormat("field"))?;
        if a.len() > WatchRequest::MAX_FILTERS {
            return Err(WatchFormat("field"));
        }
        a.iter()
            .map(|v| {
                v.as_str()
                    .and_then(|s| uuid::Uuid::parse_str(s).ok())
                    .ok_or(WatchFormat("field"))
            })
            .collect()
    };
    Ok(match event {
        "watching" => WatchEvent::Watching {
            session_id: id("session_id")?,
            machines: ids("machines")?,
            threads: ids("threads")?,
        },
        "heartbeat" => WatchEvent::Heartbeat,
        "machine" => WatchEvent::MachineChanged(id("id")?),
        "terminal_session" => WatchEvent::TerminalSessionsChanged(id("machine_id")?),
        "thread" => WatchEvent::ThreadChanged(id("id")?),
        "resync" => WatchEvent::Resync,
        "session" => WatchEvent::Session {
            id: id("id")?,
            authenticated: o.get("status").and_then(|v| v.as_str()) == Some("authenticated"),
        },
        _ => WatchEvent::Unknown,
    })
}

pub mod ssh;

/// Bounded state and framing policy shared by native PTY adapters.
///
/// This type deliberately owns no SSH channel. Platform bindings must attach
/// it to an authenticated `russh` channel and perform I/O through that
/// channel; the policy prevents stale generations and unbounded payloads from
/// crossing the UI boundary.
pub mod pty {
    use thiserror::Error;

    pub const MAX_CHUNK: usize = 64 * 1024;
    pub const MAX_INPUT: usize = 64 * 1024;
    pub const MAX_COLUMNS: u16 = 500;
    pub const MAX_ROWS: u16 = 500;

    #[derive(Clone, Copy, Debug, Eq, PartialEq, Error)]
    pub enum Error {
        #[error("invalid terminal dimensions")]
        Dimensions,
        #[error("terminal payload exceeds bounds")]
        Bounds,
        #[error("terminal generation is stale")]
        StaleGeneration,
        #[error("terminal is closed")]
        Closed,
    }

    #[derive(Clone, Copy, Debug, Eq, PartialEq)]
    pub struct Dimensions {
        pub columns: u16,
        pub rows: u16,
    }
    impl Dimensions {
        pub fn new(columns: u16, rows: u16) -> Result<Self, Error> {
            if columns == 0 || rows == 0 || columns > MAX_COLUMNS || rows > MAX_ROWS {
                return Err(Error::Dimensions);
            }
            Ok(Self { columns, rows })
        }
    }

    #[derive(Clone, Copy, Debug, Eq, PartialEq)]
    pub enum State {
        Detached,
        Attached,
        Closed,
    }

    #[derive(Debug)]
    pub struct Session {
        generation: u64,
        dimensions: Dimensions,
        state: State,
    }
    impl Session {
        pub fn attach(generation: u64, dimensions: Dimensions) -> Self {
            Self {
                generation,
                dimensions,
                state: State::Attached,
            }
        }
        pub fn state(&self) -> State {
            self.state
        }
        pub fn dimensions(&self) -> Dimensions {
            self.dimensions
        }
        pub fn accept_output(&self, generation: u64, chunk: &[u8]) -> Result<(), Error> {
            self.check(generation)?;
            if chunk.len() > MAX_CHUNK {
                return Err(Error::Bounds);
            }
            Ok(())
        }
        pub fn input(&self, generation: u64, bytes: &[u8]) -> Result<(), Error> {
            self.check(generation)?;
            if bytes.len() > MAX_INPUT {
                return Err(Error::Bounds);
            }
            Ok(())
        }
        pub fn resize(&mut self, generation: u64, dimensions: Dimensions) -> Result<(), Error> {
            self.check(generation)?;
            self.dimensions = dimensions;
            Ok(())
        }
        pub fn close(&mut self, generation: u64) -> Result<(), Error> {
            self.check(generation)?;
            self.state = State::Closed;
            Ok(())
        }
        fn check(&self, generation: u64) -> Result<(), Error> {
            if generation != self.generation {
                return Err(Error::StaleGeneration);
            }
            if self.state == State::Closed {
                return Err(Error::Closed);
            }
            Ok(())
        }
    }

    #[cfg(test)]
    mod tests {
        use super::*;
        #[test]
        fn stale_and_closed_sessions_refuse_all_controls() {
            let d = Dimensions::new(80, 24).unwrap();
            let mut s = Session::attach(7, d);
            assert_eq!(s.accept_output(6, b"x"), Err(Error::StaleGeneration));
            assert!(s.input(7, b"x").is_ok());
            s.close(7).unwrap();
            assert_eq!(s.input(7, b"x"), Err(Error::Closed));
        }
        #[test]
        fn bounds_are_fail_closed() {
            assert_eq!(Dimensions::new(0, 24), Err(Error::Dimensions));
            let s = Session::attach(1, Dimensions::new(80, 24).unwrap());
            assert_eq!(
                s.accept_output(1, &vec![0; MAX_CHUNK + 1]),
                Err(Error::Bounds)
            );
            assert_eq!(s.input(1, &vec![0; MAX_INPUT + 1]), Err(Error::Bounds));
        }
    }
}
