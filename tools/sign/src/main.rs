//! Thin CLI over `covelight-crypto`: `keygen` / `sign` / `verify`.
//! Implements `docs/design/signing.md`. See that doc for the format and the
//! reasoning; this file is plumbing only, no cryptographic logic of its own.

use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::ExitCode;

use covelight_crypto::{sig_path_for, sign_file, verify_file, Error, KeyPair, PublicKey, Sidecar};

fn usage() -> String {
    "usage:\n  \
     sign keygen [--out NAME]\n  \
     sign sign <file> --key KEYFILE\n  \
     sign verify <file> --pubkey PUBFILE [--sig SIGFILE]"
        .to_string()
}

fn main() -> ExitCode {
    let args: Vec<String> = env::args().collect();
    match run(&args[1..]) {
        Ok(()) => ExitCode::SUCCESS,
        Err(msg) => {
            eprintln!("error: {msg}");
            ExitCode::FAILURE
        }
    }
}

fn run(args: &[String]) -> Result<(), String> {
    match args.first().map(String::as_str) {
        Some("keygen") => cmd_keygen(&args[1..]),
        Some("sign") => cmd_sign(&args[1..]),
        Some("verify") => cmd_verify(&args[1..]),
        _ => Err(usage()),
    }
}

/// Pulls `--flag value` pairs out of `args`, returning the remaining
/// positional arguments. Never panics on a missing value or unknown flag —
/// callers decide what's required.
fn take_flag(args: &[String], flag: &str) -> (Option<String>, Vec<String>) {
    let mut value = None;
    let mut rest = Vec::new();
    let mut i = 0;
    while i < args.len() {
        if args[i] == flag {
            value = args.get(i + 1).cloned();
            i += 2;
        } else {
            rest.push(args[i].clone());
            i += 1;
        }
    }
    (value, rest)
}

fn cmd_keygen(args: &[String]) -> Result<(), String> {
    let (out, _rest) = take_flag(args, "--out");
    let out = out.unwrap_or_else(|| "covelight".to_string());

    let keypair = KeyPair::generate();
    let key_path = format!("{out}.key");
    let pub_path = format!("{out}.pub");

    fs::write(&key_path, hex::encode(keypair.to_bytes()))
        .map_err(|e| format!("writing {key_path}: {e}"))?;
    fs::write(&pub_path, hex::encode(keypair.public_key().to_bytes()))
        .map_err(|e| format!("writing {pub_path}: {e}"))?;

    println!("wrote {key_path} (private — keep this offline and encrypted)");
    println!("wrote {pub_path}");
    println!("key_id: {}", hex::encode(keypair.public_key().key_id()));
    Ok(())
}

fn read_hex_key_file<const N: usize>(path: &str) -> Result<[u8; N], String> {
    let text = fs::read_to_string(path).map_err(|e| format!("reading {path}: {e}"))?;
    let bytes = hex::decode(text.trim()).map_err(|e| format!("{path} is not valid hex: {e}"))?;
    bytes
        .try_into()
        .map_err(|v: Vec<u8>| format!("{path} is {} bytes, expected {N}", v.len()))
}

fn cmd_sign(args: &[String]) -> Result<(), String> {
    let (key, rest) = take_flag(args, "--key");
    let key_path = key.ok_or_else(usage)?;
    let file = rest.first().ok_or_else(usage)?;

    let key_bytes: [u8; covelight_crypto::PRIVATE_KEY_LEN] = read_hex_key_file(&key_path)?;
    let keypair = KeyPair::from_bytes(&key_bytes);

    let path = Path::new(file);
    let sidecar = sign_file(&keypair, path).map_err(|e| format!("signing {file}: {e}"))?;

    let sig_path = sig_path_for(path);
    fs::write(&sig_path, sidecar.to_bytes())
        .map_err(|e| format!("writing {}: {e}", sig_path.display()))?;

    println!("wrote {}", sig_path.display());
    Ok(())
}

fn cmd_verify(args: &[String]) -> Result<(), String> {
    let (pubkey, rest) = take_flag(args, "--pubkey");
    let (sig, rest) = take_flag(&rest, "--sig");
    let pubkey_path = pubkey.ok_or_else(usage)?;
    let file = rest.first().ok_or_else(usage)?;

    let pub_bytes: [u8; covelight_crypto::PUBLIC_KEY_LEN] = read_hex_key_file(&pubkey_path)?;
    let public_key = PublicKey::from_bytes(&pub_bytes).map_err(|e| e.to_string())?;

    let path = Path::new(file);
    let sig_path = sig.map(PathBuf::from).unwrap_or_else(|| sig_path_for(path));

    let sidecar_bytes =
        fs::read(&sig_path).map_err(|e| format!("reading {}: {e}", sig_path.display()))?;
    let sidecar = Sidecar::from_bytes(&sidecar_bytes).map_err(|e: Error| e.to_string())?;

    verify_file(&[public_key], path, &sidecar).map_err(|e| e.to_string())?;
    println!("OK: {file} verifies against {pubkey_path}");
    Ok(())
}
