//! End-to-end tests of the actual `sign` binary: keygen -> sign -> verify,
//! and the three required failure modes (tampered file, wrong key,
//! malformed sidecar). Fills T0.4's CI acceptance checklist.

use std::fs;
use std::path::PathBuf;
use std::process::Command;
use std::sync::atomic::{AtomicU32, Ordering};

fn sign_bin() -> &'static str {
    env!("CARGO_BIN_EXE_sign")
}

fn temp_dir(label: &str) -> PathBuf {
    static COUNTER: AtomicU32 = AtomicU32::new(0);
    let n = COUNTER.fetch_add(1, Ordering::SeqCst);
    let dir = std::env::temp_dir().join(format!(
        "covelight-sign-test-{}-{}-{}",
        std::process::id(),
        label,
        n
    ));
    fs::create_dir_all(&dir).unwrap();
    dir
}

fn run(dir: &PathBuf, args: &[&str]) -> (bool, String, String) {
    let output = Command::new(sign_bin())
        .args(args)
        .current_dir(dir)
        .output()
        .expect("failed to execute sign binary");
    (
        output.status.success(),
        String::from_utf8_lossy(&output.stdout).to_string(),
        String::from_utf8_lossy(&output.stderr).to_string(),
    )
}

#[test]
fn keygen_sign_verify_round_trip() {
    let dir = temp_dir("roundtrip");
    let content_path = dir.join("activity.pck");
    fs::write(&content_path, b"a whole activity's worth of bytes").unwrap();

    let (ok, out, err) = run(&dir, &["keygen", "--out", "project"]);
    assert!(ok, "keygen failed: {err}");
    assert!(out.contains("key_id"));
    assert!(dir.join("project.key").exists());
    assert!(dir.join("project.pub").exists());

    let (ok, _out, err) = run(&dir, &["sign", "activity.pck", "--key", "project.key"]);
    assert!(ok, "sign failed: {err}");
    assert!(dir.join("activity.pck.sig").exists());

    let (ok, out, err) = run(&dir, &["verify", "activity.pck", "--pubkey", "project.pub"]);
    assert!(ok, "verify of untampered file failed: {err}");
    assert!(out.contains("OK"));
}

#[test]
fn tampered_file_fails_verification() {
    let dir = temp_dir("tampered");
    fs::write(dir.join("activity.pck"), b"original bytes").unwrap();
    run(&dir, &["keygen", "--out", "project"]);
    run(&dir, &["sign", "activity.pck", "--key", "project.key"]);

    // Mutate the content after signing.
    fs::write(dir.join("activity.pck"), b"tampered bytes!!").unwrap();

    let (ok, _out, err) = run(&dir, &["verify", "activity.pck", "--pubkey", "project.pub"]);
    assert!(!ok, "verification should fail on tampered content");
    assert!(err.contains("error"));
}

#[test]
fn wrong_key_fails_verification() {
    let dir = temp_dir("wrongkey");
    fs::write(dir.join("activity.pck"), b"some content").unwrap();
    run(&dir, &["keygen", "--out", "signer"]);
    run(&dir, &["keygen", "--out", "attacker"]);
    run(&dir, &["sign", "activity.pck", "--key", "signer.key"]);

    let (ok, _out, err) = run(
        &dir,
        &["verify", "activity.pck", "--pubkey", "attacker.pub"],
    );
    assert!(!ok, "verification should fail against the wrong public key");
    assert!(err.contains("error"));
}

#[test]
fn malformed_signature_file_fails_cleanly() {
    let dir = temp_dir("malformed");
    fs::write(dir.join("activity.pck"), b"some content").unwrap();
    run(&dir, &["keygen", "--out", "project"]);

    // Not a signature at all: too short, wrong magic.
    fs::write(dir.join("activity.pck.sig"), b"not a real sidecar").unwrap();

    let output = Command::new(sign_bin())
        .args(["verify", "activity.pck", "--pubkey", "project.pub"])
        .current_dir(&dir)
        .output()
        .expect("failed to execute sign binary");

    assert!(
        !output.status.success(),
        "malformed sidecar must be rejected"
    );
    // A clean Result-based error exits with a normal failure code, never a
    // panic. On most platforms a Rust panic still exits non-zero too, so
    // the decisive check is the absence of panic-style output.
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(
        !stderr.contains("panicked"),
        "must fail via a clean error, not a panic: {stderr}"
    );
    assert!(stderr.contains("error"));
}

#[test]
fn malformed_signature_empty_file_fails_cleanly() {
    let dir = temp_dir("malformed-empty");
    fs::write(dir.join("activity.pck"), b"some content").unwrap();
    run(&dir, &["keygen", "--out", "project"]);
    fs::write(dir.join("activity.pck.sig"), b"").unwrap();

    let output = Command::new(sign_bin())
        .args(["verify", "activity.pck", "--pubkey", "project.pub"])
        .current_dir(&dir)
        .output()
        .expect("failed to execute sign binary");

    assert!(!output.status.success());
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(!stderr.contains("panicked"), "{stderr}");
}
