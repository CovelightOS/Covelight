//! Ed25519 content-signing primitives, implementing `docs/design/signing.md`
//! exactly: Ed25519ph (RFC 8032 prehashed) signatures over SHA-512(content),
//! and the fixed 76-byte detached sidecar format.
//!
//! This is the only Ed25519 implementation in the project. `/tools/sign`
//! (T0.4), the shell's GDExtension (T1.4), and later syncd-adjacent import
//! checks (T2.6) all consume this crate rather than each rolling their own.
//!
//! Two API layers, for two different callers:
//!
//! - [`Sha512`] is re-exported so callers who stream bytes from their own I/O
//!   (the shell's GDExtension may read via Godot's `FileAccess`, not
//!   `std::fs`) can feed a hasher incrementally and hand it to
//!   [`KeyPair::sign_prehashed`] / [`PublicKey::verify_prehashed`] without
//!   buffering the whole file.
//! - [`sign_file`] / [`verify`] are `std::fs`-based convenience wrappers for
//!   callers happy to hand over a path (`/tools/sign`, tests).
//!
//! No panics on malformed input anywhere in this crate: every parsing
//! function returns [`Error`].

use std::fs::File;
use std::io::{self, Read};
use std::path::Path;

pub use sha2::{Digest, Sha512};

use ed25519_dalek::{Signature as DalekSignature, SigningKey, VerifyingKey};
use rand::rand_core::UnwrapErr;
use rand::rngs::SysRng;
use sha2::Sha256;

pub const PUBLIC_KEY_LEN: usize = 32;
pub const PRIVATE_KEY_LEN: usize = 32;
pub const SIGNATURE_LEN: usize = 64;
pub const KEY_ID_LEN: usize = 8;

/// `"CVS1"` — Covelight Signature v1. A future format change gets a new
/// magic, not a version field to branch on (docs/design/signing.md).
pub const SIDECAR_MAGIC: [u8; 4] = *b"CVS1";

/// magic(4) + key_id(8) + signature(64), fixed, no variable-length fields.
pub const SIDECAR_LEN: usize = 4 + KEY_ID_LEN + SIGNATURE_LEN;

/// First 8 bytes of SHA-256(public key bytes). Identification only, not a
/// trust boundary by itself — see docs/design/signing.md.
pub type KeyId = [u8; KEY_ID_LEN];

#[derive(Debug)]
pub enum Error {
    /// Sidecar bytes were not exactly `SIDECAR_LEN` long.
    BadSidecarLength {
        expected: usize,
        actual: usize,
    },
    /// Sidecar's first 4 bytes weren't `SIDECAR_MAGIC`.
    BadMagic,
    /// Public/private key bytes were not a valid Ed25519 point/scalar.
    InvalidKeyBytes,
    /// `key_id` in the sidecar matched none of the supplied trusted keys.
    UnknownKey(KeyId),
    /// Signature did not verify against the digest and key.
    InvalidSignature,
    Io(io::Error),
}

impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Error::BadSidecarLength { expected, actual } => write!(
                f,
                "signature sidecar is {actual} bytes, expected exactly {expected}"
            ),
            Error::BadMagic => write!(f, "signature sidecar has an unrecognized magic"),
            Error::InvalidKeyBytes => write!(f, "key bytes are not a valid Ed25519 key"),
            Error::UnknownKey(id) => write!(f, "key_id {} is not trusted", hex_encode(id)),
            Error::InvalidSignature => write!(f, "signature verification failed"),
            Error::Io(e) => write!(f, "I/O error: {e}"),
        }
    }
}

impl std::error::Error for Error {}

impl From<io::Error> for Error {
    fn from(e: io::Error) -> Self {
        Error::Io(e)
    }
}

fn hex_encode(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

/// An Ed25519 keypair. `to_bytes`/`from_bytes` round-trip the 32-byte seed —
/// storage/encryption of that seed is an operational concern
/// (docs/design/signing.md, "Project key storage & access control"), not
/// this crate's.
pub struct KeyPair(SigningKey);

impl KeyPair {
    /// Generates a new keypair from the OS CSPRNG.
    pub fn generate() -> Self {
        let mut csprng = UnwrapErr(SysRng);
        KeyPair(SigningKey::generate(&mut csprng))
    }

    pub fn from_bytes(bytes: &[u8; PRIVATE_KEY_LEN]) -> Self {
        KeyPair(SigningKey::from_bytes(bytes))
    }

    pub fn to_bytes(&self) -> [u8; PRIVATE_KEY_LEN] {
        self.0.to_bytes()
    }

    pub fn public_key(&self) -> PublicKey {
        PublicKey(self.0.verifying_key())
    }

    /// Signs an in-progress SHA-512 hash (Ed25519ph, RFC 8032). The caller
    /// owns hashing, so a large file never needs to be buffered whole.
    pub fn sign_prehashed(&self, hasher: Sha512) -> Signature {
        Signature(
            self.0
                .sign_prehashed(hasher, None)
                .expect("Ed25519ph signing over a valid SHA-512 state cannot fail"),
        )
    }

    /// Convenience for small in-memory messages (tests, short content).
    pub fn sign_bytes(&self, message: &[u8]) -> Signature {
        let mut hasher = Sha512::new();
        hasher.update(message);
        self.sign_prehashed(hasher)
    }
}

/// An Ed25519 public key.
#[derive(Clone, Copy, PartialEq, Eq)]
pub struct PublicKey(VerifyingKey);

impl PublicKey {
    pub fn from_bytes(bytes: &[u8; PUBLIC_KEY_LEN]) -> Result<Self, Error> {
        VerifyingKey::from_bytes(bytes)
            .map(PublicKey)
            .map_err(|_| Error::InvalidKeyBytes)
    }

    pub fn to_bytes(&self) -> [u8; PUBLIC_KEY_LEN] {
        self.0.to_bytes()
    }

    /// First 8 bytes of SHA-256(public key bytes).
    pub fn key_id(&self) -> KeyId {
        let digest = Sha256::digest(self.to_bytes());
        let mut id = [0u8; KEY_ID_LEN];
        id.copy_from_slice(&digest[..KEY_ID_LEN]);
        id
    }

    /// Verifies a signature over an in-progress SHA-512 hash (Ed25519ph).
    pub fn verify_prehashed(&self, hasher: Sha512, signature: &Signature) -> Result<(), Error> {
        self.0
            .verify_prehashed(hasher, None, &signature.0)
            .map_err(|_| Error::InvalidSignature)
    }

    /// Convenience for small in-memory messages (tests, short content).
    pub fn verify_bytes(&self, message: &[u8], signature: &Signature) -> Result<(), Error> {
        let mut hasher = Sha512::new();
        hasher.update(message);
        self.verify_prehashed(hasher, signature)
    }
}

/// A raw Ed25519 signature (64 bytes).
#[derive(Clone, Copy)]
pub struct Signature(DalekSignature);

impl Signature {
    pub fn to_bytes(&self) -> [u8; SIGNATURE_LEN] {
        self.0.to_bytes()
    }

    pub fn from_bytes(bytes: [u8; SIGNATURE_LEN]) -> Self {
        Signature(DalekSignature::from_bytes(&bytes))
    }
}

/// The `<id>.pck.sig` sidecar: `docs/design/signing.md`'s fixed 76-byte
/// format. `from_bytes` never panics on malformed input — every failure
/// mode is a rejected [`Error`], matching the shell's fail-closed
/// verification flow.
pub struct Sidecar {
    pub key_id: KeyId,
    pub signature: Signature,
}

impl Sidecar {
    pub fn new(key_id: KeyId, signature: Signature) -> Self {
        Sidecar { key_id, signature }
    }

    pub fn to_bytes(&self) -> [u8; SIDECAR_LEN] {
        let mut out = [0u8; SIDECAR_LEN];
        out[0..4].copy_from_slice(&SIDECAR_MAGIC);
        out[4..4 + KEY_ID_LEN].copy_from_slice(&self.key_id);
        out[4 + KEY_ID_LEN..].copy_from_slice(&self.signature.to_bytes());
        out
    }

    pub fn from_bytes(bytes: &[u8]) -> Result<Self, Error> {
        if bytes.len() != SIDECAR_LEN {
            return Err(Error::BadSidecarLength {
                expected: SIDECAR_LEN,
                actual: bytes.len(),
            });
        }
        if bytes[0..4] != SIDECAR_MAGIC {
            return Err(Error::BadMagic);
        }
        let mut key_id: KeyId = [0u8; KEY_ID_LEN];
        key_id.copy_from_slice(&bytes[4..4 + KEY_ID_LEN]);
        let mut sig_bytes = [0u8; SIGNATURE_LEN];
        sig_bytes.copy_from_slice(&bytes[4 + KEY_ID_LEN..]);
        Ok(Sidecar {
            key_id,
            signature: Signature::from_bytes(sig_bytes),
        })
    }
}

/// Streams a file through SHA-512 in constant memory.
pub fn hash_file(path: &Path) -> io::Result<Sha512> {
    let mut file = File::open(path)?;
    let mut hasher = Sha512::new();
    let mut buf = [0u8; 64 * 1024];
    loop {
        let n = file.read(&mut buf)?;
        if n == 0 {
            break;
        }
        hasher.update(&buf[..n]);
    }
    Ok(hasher)
}

/// Signs `path` and returns the sidecar to write alongside it as
/// `<path>.sig`.
pub fn sign_file(keypair: &KeyPair, path: &Path) -> io::Result<Sidecar> {
    let hasher = hash_file(path)?;
    let signature = keypair.sign_prehashed(hasher);
    Ok(Sidecar::new(keypair.public_key().key_id(), signature))
}

/// The shell's verification algorithm (docs/design/signing.md,
/// "Verification flow in the shell", steps 4-5): look up `sidecar.key_id`
/// among `trusted_keys`, reject if absent, else verify the signature.
pub fn verify(trusted_keys: &[PublicKey], hasher: Sha512, sidecar: &Sidecar) -> Result<(), Error> {
    let key = trusted_keys
        .iter()
        .find(|k| k.key_id() == sidecar.key_id)
        .ok_or(Error::UnknownKey(sidecar.key_id))?;
    key.verify_prehashed(hasher, &sidecar.signature)
}

/// Convenience: hashes `path` from disk and verifies it against `sidecar`.
pub fn verify_file(
    trusted_keys: &[PublicKey],
    path: &Path,
    sidecar: &Sidecar,
) -> Result<(), Error> {
    let hasher = hash_file(path)?;
    verify(trusted_keys, hasher, sidecar)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trip() {
        let keypair = KeyPair::generate();
        let sig = keypair.sign_bytes(b"hello covelight");
        assert!(keypair
            .public_key()
            .verify_bytes(b"hello covelight", &sig)
            .is_ok());
    }

    #[test]
    fn tampered_message_fails() {
        let keypair = KeyPair::generate();
        let sig = keypair.sign_bytes(b"original content");
        let result = keypair.public_key().verify_bytes(b"tampered content", &sig);
        assert!(matches!(result, Err(Error::InvalidSignature)));
    }

    #[test]
    fn wrong_key_fails() {
        let keypair = KeyPair::generate();
        let other = KeyPair::generate();
        let sig = keypair.sign_bytes(b"hello covelight");
        let result = other.public_key().verify_bytes(b"hello covelight", &sig);
        assert!(matches!(result, Err(Error::InvalidSignature)));
    }

    #[test]
    fn unknown_key_id_rejected_before_verify() {
        let signer = KeyPair::generate();
        let unrelated = KeyPair::generate();
        let sig = signer.sign_bytes(b"content");
        let sidecar = Sidecar::new(signer.public_key().key_id(), sig);

        let mut hasher = Sha512::new();
        hasher.update(b"content");
        // Only `unrelated`'s key is trusted — signer's key_id won't match.
        let result = verify(&[unrelated.public_key()], hasher, &sidecar);
        assert!(matches!(result, Err(Error::UnknownKey(_))));
    }

    #[test]
    fn sidecar_round_trip_bytes() {
        let keypair = KeyPair::generate();
        let sig = keypair.sign_bytes(b"content");
        let sidecar = Sidecar::new(keypair.public_key().key_id(), sig);
        let bytes = sidecar.to_bytes();
        assert_eq!(bytes.len(), SIDECAR_LEN);

        let parsed = Sidecar::from_bytes(&bytes).unwrap();
        assert_eq!(parsed.key_id, sidecar.key_id);
        assert_eq!(parsed.signature.to_bytes(), sidecar.signature.to_bytes());
    }

    #[test]
    fn malformed_sidecar_wrong_length_no_panic() {
        let result = Sidecar::from_bytes(&[0u8; 10]);
        assert!(matches!(
            result,
            Err(Error::BadSidecarLength {
                expected: SIDECAR_LEN,
                actual: 10
            })
        ));
    }

    #[test]
    fn malformed_sidecar_bad_magic_no_panic() {
        let mut bytes = [0u8; SIDECAR_LEN];
        bytes[0..4].copy_from_slice(b"XXXX");
        let result = Sidecar::from_bytes(&bytes);
        assert!(matches!(result, Err(Error::BadMagic)));
    }

    #[test]
    fn malformed_sidecar_empty_no_panic() {
        let result = Sidecar::from_bytes(&[]);
        assert!(matches!(result, Err(Error::BadSidecarLength { .. })));
    }

    #[test]
    fn invalid_public_key_bytes_rejected() {
        // High byte 0xFF puts y out of range for a valid compressed Edwards
        // point (verified empirically against ed25519-dalek, not derived).
        let mut bytes = [0u8; PUBLIC_KEY_LEN];
        bytes[31] = 0xFF;
        let result = PublicKey::from_bytes(&bytes);
        assert!(matches!(result, Err(Error::InvalidKeyBytes)));
    }

    #[test]
    fn key_id_is_stable_and_key_specific() {
        let a = KeyPair::generate();
        let b = KeyPair::generate();
        assert_eq!(a.public_key().key_id(), a.public_key().key_id());
        assert_ne!(a.public_key().key_id(), b.public_key().key_id());
    }
}
