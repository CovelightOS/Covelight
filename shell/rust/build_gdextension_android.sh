#!/usr/bin/env bash
# Cross-compiles the T1.4 GDExtension (shell/rust/pck_verify) for Android
# and copies both ABI binaries into
# shell/addons/covelight_pck_verify/bin/android/<abi>/, where
# covelight_pck_verify.gdextension's android.*.arm64/arm32 entries expect
# to find them.
#
# T2.1: the Android-embedded shell loads activities through the exact same
# verify-then-load path as desktop (PckLoader -> PckVerifier, T1.4) -- this
# script exists so that path has a real binary to load on-device instead of
# silently having no GDExtension available. A missing binary here means the
# same parse-time failure shell/README.md documents for desktop: the whole
# project fails to boot, not a silent signature-check bypass.
#
# Targets arm64-v8a and armeabi-v7a only -- the two ABIs real phones from
# roughly the last decade actually ship (ARCHITECTURE.md's "phone already
# in the drawer" target). x86/x86_64 Android hardware doesn't exist in the
# wild for this project's audience; skipped.
#
# Requires: rustup targets aarch64-linux-android + armv7-linux-androideabi,
# and an installed Android NDK (ANDROID_NDK_HOME, or found under the
# default SDK location).
#
# usage: shell/rust/build_gdextension_android.sh [--release|--debug]  (default: debug)

set -euo pipefail

PROFILE="debug"
CARGO_FLAG=""
if [ "${1:-}" = "--release" ]; then
	PROFILE="release"
	CARGO_FLAG="--release"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRATE_DIR="$SCRIPT_DIR/pck_verify"
BIN_ROOT="$SCRIPT_DIR/../addons/covelight_pck_verify/bin/android"

# Android API level floor -- must match CLAUDE.md's Tier 1 target (T2.1,
# docs/plan/03-phase2-kiosk.md) and the min_sdk set in shell/export_presets.cfg's
# Android preset and app/build.gradle.kts. One number, three places that
# must agree; this is the source-of-truth comment for all three.
MIN_SDK=26

if [ -z "${ANDROID_NDK_HOME:-}" ]; then
	DEFAULT_SDK="$HOME/Library/Android/sdk"
	NEWEST_NDK="$(ls -1 "$DEFAULT_SDK/ndk" 2>/dev/null | sort -V | tail -1)"
	if [ -z "$NEWEST_NDK" ]; then
		echo "error: ANDROID_NDK_HOME not set and no NDK found under $DEFAULT_SDK/ndk" >&2
		exit 1
	fi
	ANDROID_NDK_HOME="$DEFAULT_SDK/ndk/$NEWEST_NDK"
fi

HOST_TAG=""
case "$(uname -s)" in
Darwin) HOST_TAG="darwin-x86_64" ;;
Linux) HOST_TAG="linux-x86_64" ;;
*)
	echo "error: unsupported host OS $(uname -s) for Android cross-compile" >&2
	exit 1
	;;
esac

NDK_BIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$HOST_TAG/bin"
if [ ! -d "$NDK_BIN" ]; then
	echo "error: NDK toolchain bin dir not found: $NDK_BIN" >&2
	exit 1
fi

# rust target triple : android ABI dir name : NDK clang triple prefix
TARGETS=(
	"aarch64-linux-android:arm64-v8a:aarch64-linux-android"
	"armv7-linux-androideabi:armeabi-v7a:armv7a-linux-androideabi"
)

for entry in "${TARGETS[@]}"; do
	RUST_TARGET="${entry%%:*}"
	rest="${entry#*:}"
	ABI="${rest%%:*}"
	NDK_TRIPLE="${rest#*:}"

	CLANG="$NDK_BIN/${NDK_TRIPLE}${MIN_SDK}-clang"
	if [ ! -x "$CLANG" ]; then
		echo "error: expected NDK clang not found: $CLANG" >&2
		exit 1
	fi

	echo "building covelight-pck-verify for $RUST_TARGET ($PROFILE)..."
	ENV_LINKER_VAR="CARGO_TARGET_$(echo "$RUST_TARGET" | tr '[:lower:]-' '[:upper:]_')_LINKER"
	ENV_CC_VAR="CC_$(echo "$RUST_TARGET" | tr '-' '_')"
	ENV_AR_VAR="AR_$(echo "$RUST_TARGET" | tr '-' '_')"

	(
		cd "$CRATE_DIR"
		export "$ENV_LINKER_VAR=$CLANG"
		export "$ENV_CC_VAR=$CLANG"
		export "$ENV_AR_VAR=$NDK_BIN/llvm-ar"
		cargo build $CARGO_FLAG --target "$RUST_TARGET"
	)

	OUT_DIR="$BIN_ROOT/$ABI"
	mkdir -p "$OUT_DIR"
	cp "$CRATE_DIR/target/$RUST_TARGET/$PROFILE/libcovelight_pck_verify.so" "$OUT_DIR/libcovelight_pck_verify.so"
	echo "copied libcovelight_pck_verify.so -> $OUT_DIR"
done
