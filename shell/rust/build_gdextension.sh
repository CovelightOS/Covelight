#!/usr/bin/env bash
# Builds the T1.4 GDExtension (shell/rust/pck_verify -> covelight-crypto)
# and copies the platform binary into shell/addons/covelight_pck_verify/bin/,
# where covelight_pck_verify.gdextension expects to find it.
#
# This is now a hard prerequisite for running ANY part of /shell headless
# or in the editor, not an optional dev nicety: shell/scripts/pck_loader.gd
# references the PckVerifier class it defines by name at parse time, so a
# missing binary breaks the whole project's script compilation, not just
# PCK-loading (verified directly against the real engine, not assumed —
# see docs/research/godot-pck-gdextension.md and this task's PR). That's
# intentional, not an oversight: making verification quietly optional
# whenever the binary happens to be missing would itself be exactly the
# kind of dev-convenience bypass CLAUDE.md #3 forbids. One script, run
# once, is the actual cost.
#
# Same script for local dev and CI (single source of truth) -- see
# shell/README.md and .github/workflows/build.yml.
#
# usage: shell/rust/build_gdextension.sh [--release|--debug]  (default: debug)

set -euo pipefail

PROFILE="debug"
CARGO_FLAG=""
if [ "${1:-}" = "--release" ]; then
	PROFILE="release"
	CARGO_FLAG="--release"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRATE_DIR="$SCRIPT_DIR/pck_verify"
BIN_DIR="$SCRIPT_DIR/../addons/covelight_pck_verify/bin"

mkdir -p "$BIN_DIR"

echo "building covelight-pck-verify ($PROFILE)..."
(cd "$CRATE_DIR" && cargo build $CARGO_FLAG)

TARGET_DIR="$CRATE_DIR/target/$PROFILE"

case "$(uname -s)" in
	Darwin)
		cp "$TARGET_DIR/libcovelight_pck_verify.dylib" "$BIN_DIR/libcovelight_pck_verify.dylib"
		echo "copied libcovelight_pck_verify.dylib -> $BIN_DIR"
		;;
	Linux)
		cp "$TARGET_DIR/libcovelight_pck_verify.so" "$BIN_DIR/libcovelight_pck_verify.so"
		echo "copied libcovelight_pck_verify.so -> $BIN_DIR"
		;;
	*)
		echo "error: unsupported host OS $(uname -s) -- add a case here" >&2
		exit 1
		;;
esac
