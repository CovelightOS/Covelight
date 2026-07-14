//! T1.4: verifies a `.pck`'s Ed25519 signature (`docs/design/signing.md`)
//! *before* the shell ever calls `ProjectSettings.load_resource_pack()`.
//! Consumes `covelight-crypto` (`/tools/covelight-crypto`) — the only
//! Ed25519 implementation in this project — never reimplements it.
//!
//! Split in two, deliberately:
//! - [`verify_pck`] is plain Rust, no Godot types, so it's testable with
//!   ordinary `cargo test` against real files on disk (see `tests/`)
//!   without needing a Godot runtime.
//! - [`PckVerifier`] is the thin GDExtension surface `shell.gd` calls —
//!   nothing but marshaling a `GString` in and a `bool` out, plus logging
//!   the *reason* for a rejection (parent-visible, per CLAUDE.md #3's
//!   logging requirement) somewhere the child never sees (constraint #1 —
//!   GDScript only ever receives `true`/`false`, never a reason string).
//!
//! No debug/test flag anywhere in this crate can make [`verify_pck`]
//! return `Ok` for an invalid signature — there is no branch that skips
//! verification, in any build configuration (CLAUDE.md #3).

use std::fmt;
use std::path::Path;

use covelight_crypto::{hash_file, sig_path_for, trusted_keys, verify, PublicKey, Sidecar};

use godot::classes::ProjectSettings;
use godot::prelude::*;

/// Why a `.pck` was rejected. Never shown to the child (constraint #1) —
/// this exists purely for the parent-visible log line `PckVerifier` emits.
#[derive(Debug)]
pub enum VerifyError {
    /// `<pck>.sig` doesn't exist or couldn't be read.
    MissingSidecar(std::io::Error),
    /// Sidecar existed but wasn't 76 well-formed bytes (bad length/magic).
    MalformedSidecar(covelight_crypto::Error),
    /// The `.pck` itself couldn't be read/hashed.
    UnreadablePck(std::io::Error),
    /// Sidecar parsed fine, but its `key_id` isn't trusted, or the
    /// signature didn't verify against the `.pck`'s bytes.
    Untrusted(covelight_crypto::Error),
}

impl fmt::Display for VerifyError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            VerifyError::MissingSidecar(e) => write!(f, "missing/unreadable .sig sidecar: {e}"),
            VerifyError::MalformedSidecar(e) => write!(f, "malformed .sig sidecar: {e}"),
            VerifyError::UnreadablePck(e) => write!(f, "could not read .pck: {e}"),
            VerifyError::Untrusted(e) => write!(f, "signature rejected: {e}"),
        }
    }
}

/// Implements `docs/design/signing.md`'s "Verification flow in the shell"
/// steps 1-5 exactly: locate the sidecar next to `pck_path`, reject if
/// missing; parse it, reject if malformed; hash `pck_path` (streaming,
/// constant memory, matching `covelight-crypto::hash_file`'s own
/// contract) and verify against `keys`. Step 6 (proceed to
/// `load_resource_pack`) is the caller's job, only on `Ok`.
pub fn verify_pck_against(pck_path: &Path, keys: &[PublicKey]) -> Result<(), VerifyError> {
    let sig_path = sig_path_for(pck_path);
    let sidecar_bytes = std::fs::read(&sig_path).map_err(VerifyError::MissingSidecar)?;
    let sidecar = Sidecar::from_bytes(&sidecar_bytes).map_err(VerifyError::MalformedSidecar)?;
    let hasher = hash_file(pck_path).map_err(VerifyError::UnreadablePck)?;
    verify(keys, hasher, &sidecar).map_err(VerifyError::Untrusted)
}

/// [`verify_pck_against`] using the embedded, compiled-in trusted-keys
/// table (`covelight_crypto::trusted_keys()`) — what every real caller
/// (`PckVerifier::verify_pck`, and therefore `shell.gd`) actually uses.
pub fn verify_pck(pck_path: &Path) -> Result<(), VerifyError> {
    verify_pck_against(pck_path, &trusted_keys())
}

/// The GDExtension class `shell.gd` calls. No instance state — every
/// method is a static-style call (`PckVerifier.verify_pck(path)` from
/// GDScript), so the shell never needs to manage this object's lifetime.
#[derive(GodotClass)]
#[class(base=Object, init)]
struct PckVerifier {
    base: Base<Object>,
}

#[godot_api]
impl PckVerifier {
    /// Returns `true` only if `pck_path` has a valid signature from a
    /// trusted key. On `false`, the reason is logged via `godot_error!`
    /// (visible in the shell's own log output — parent-visible per
    /// CLAUDE.md #3) and nothing else; the caller (`shell.gd`) must not
    /// call `load_resource_pack` and must not show the child anything
    /// (constraint #1 — a rejected pack is silent from the child's
    /// perspective, same shape as T1.2's crash containment).
    ///
    /// `pck_path` may be a Godot virtual path (`res://…`, `user://…`) as
    /// well as a real OS path — resolved via `ProjectSettings.globalize_path`
    /// before ever touching `std::fs`, which understands neither prefix.
    /// Found by testing directly against a real Godot process, not assumed:
    /// an earlier version of this function handed `user://…` straight to
    /// Rust's `std::fs::read` and it silently failed to find a file that
    /// genuinely existed.
    #[func]
    fn verify_pck(pck_path: GString) -> bool {
        let path_string = Self::globalize(&pck_path);
        match verify_pck(Path::new(&path_string)) {
            Ok(()) => true,
            Err(reason) => {
                godot_error!("covelight-pck-verify: rejected '{pck_path}': {reason}");
                false
            }
        }
    }

    /// Test/tooling entry point only — `shell/scripts/pck_loader.gd` (the
    /// only production caller in this project) never calls this, and
    /// nothing in this crate calls it internally either. It exists because
    /// `covelight_crypto::TRUSTED_KEY_BYTES` ships empty until a real
    /// project key exists (a governance decision, not a code one — see
    /// that constant's own doc comment), which means `verify_pck()` above
    /// can only ever return `false` in this repo today, for *any* input,
    /// including a genuinely well-signed one. That makes "a validly signed
    /// pck verifies" untestable through `verify_pck()` alone. This performs
    /// the exact same real Ed25519 verification (`verify_pck_against`,
    /// shared code, not a parallel implementation) against a caller-supplied
    /// key instead of the compiled-in table — not a weaker check, just a
    /// different, explicit, test-supplied trust root. Forging a pass still
    /// requires a real signature from the matching private key; nothing
    /// here can be tricked into accepting unsigned or tampered bytes.
    #[func]
    fn verify_pck_with_key(pck_path: GString, public_key_hex: GString) -> bool {
        let path_string = Self::globalize(&pck_path);
        let key = match hex::decode(public_key_hex.to_string())
            .ok()
            .and_then(|bytes| <[u8; covelight_crypto::PUBLIC_KEY_LEN]>::try_from(bytes).ok())
            .and_then(|bytes| PublicKey::from_bytes(&bytes).ok())
        {
            Some(key) => key,
            None => {
                godot_error!(
                    "covelight-pck-verify: '{public_key_hex}' is not a valid Ed25519 public key"
                );
                return false;
            }
        };
        match verify_pck_against(Path::new(&path_string), &[key]) {
            Ok(()) => true,
            Err(reason) => {
                godot_error!("covelight-pck-verify: rejected '{pck_path}': {reason}");
                false
            }
        }
    }

    fn globalize(path: &GString) -> String {
        ProjectSettings::singleton()
            .globalize_path(path)
            .to_string()
    }
}

struct CovelightPckVerifyExtension;

#[gdextension]
unsafe impl ExtensionLibrary for CovelightPckVerifyExtension {}

#[cfg(test)]
mod tests {
    use super::*;
    use covelight_crypto::{sign_file, KeyPair};
    use std::fs;
    use tempfile::tempdir;

    fn write_signed_pck(dir: &Path, keypair: &KeyPair, content: &[u8]) -> std::path::PathBuf {
        let pck_path = dir.join("activity.pck");
        fs::write(&pck_path, content).unwrap();
        let sidecar = sign_file(keypair, &pck_path).unwrap();
        fs::write(sig_path_for(&pck_path), sidecar.to_bytes()).unwrap();
        pck_path
    }

    #[test]
    fn valid_signature_from_a_trusted_key_verifies() {
        let dir = tempdir().unwrap();
        let keypair = KeyPair::generate();
        let pck_path = write_signed_pck(dir.path(), &keypair, b"pretend pck bytes");

        // covelight_crypto::trusted_keys() reads the compiled-in (empty)
        // table, which this specific test key is deliberately not part
        // of -- verify() is exercised directly against an explicit trust
        // set instead, exactly like covelight-crypto's own tests do. This
        // proves the *mechanism*; whether the shipped table is populated
        // is a separate, later, governance decision (see lib.rs's own
        // doc comment on TRUSTED_KEY_BYTES).
        let sidecar_bytes = fs::read(sig_path_for(&pck_path)).unwrap();
        let sidecar = Sidecar::from_bytes(&sidecar_bytes).unwrap();
        let hasher = hash_file(&pck_path).unwrap();
        let result = verify(&[keypair.public_key()], hasher, &sidecar);
        assert!(result.is_ok());
    }

    #[test]
    fn missing_sidecar_is_rejected() {
        let dir = tempdir().unwrap();
        let pck_path = dir.path().join("unsigned.pck");
        fs::write(&pck_path, b"no signature anywhere").unwrap();

        let result = verify_pck(&pck_path);
        assert!(matches!(result, Err(VerifyError::MissingSidecar(_))));
    }

    #[test]
    fn tampered_pck_bytes_are_rejected() {
        let dir = tempdir().unwrap();
        let keypair = KeyPair::generate();
        let pck_path = write_signed_pck(dir.path(), &keypair, b"original content");

        // Tamper with the .pck after signing -- the sidecar now covers
        // bytes that no longer exist on disk.
        fs::write(&pck_path, b"tampered content!").unwrap();

        let sidecar_bytes = fs::read(sig_path_for(&pck_path)).unwrap();
        let sidecar = Sidecar::from_bytes(&sidecar_bytes).unwrap();
        let hasher = hash_file(&pck_path).unwrap();
        let result = verify(&[keypair.public_key()], hasher, &sidecar);
        assert!(matches!(
            result,
            Err(covelight_crypto::Error::InvalidSignature)
        ));
    }

    #[test]
    fn untrusted_key_is_rejected_even_with_a_valid_signature() {
        let dir = tempdir().unwrap();
        let signer = KeyPair::generate();
        let someone_else = KeyPair::generate();
        let pck_path = write_signed_pck(dir.path(), &signer, b"legit content, wrong signer");

        let sidecar_bytes = fs::read(sig_path_for(&pck_path)).unwrap();
        let sidecar = Sidecar::from_bytes(&sidecar_bytes).unwrap();
        let hasher = hash_file(&pck_path).unwrap();
        // Only someone_else's key is trusted -- signer's key_id won't match.
        let result = verify(&[someone_else.public_key()], hasher, &sidecar);
        assert!(matches!(
            result,
            Err(covelight_crypto::Error::UnknownKey(_))
        ));
    }

    #[test]
    fn malformed_sidecar_is_rejected_not_panicked() {
        let dir = tempdir().unwrap();
        let pck_path = dir.path().join("weird.pck");
        fs::write(&pck_path, b"content").unwrap();
        fs::write(sig_path_for(&pck_path), b"not a real sidecar").unwrap();

        let result = verify_pck(&pck_path);
        assert!(matches!(result, Err(VerifyError::MalformedSidecar(_))));
    }
}
