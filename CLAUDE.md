# CLAUDE.md — Covelight

Instructions for Claude (Claude Code and other AI-assisted sessions) working in this repository. Read before making any change.

## What this project is

Covelight is a free, open-source, textless learning environment for pre-literate children (ages ~2–6), shipped at **two protection tiers on one shared Godot platform**:

- **Tier 1 — Covelight (app):** an Android Device-Owner kiosk. Runs on nearly any Android phone. Protection is **policy-based** (radios disabled, lock-task mode, launcher replaced).
- **Tier 2 — Covelight OS:** a Linux OS (postmarketOS base) replacing Android on supported devices. Protection is **structural** (radio drivers compiled out of the kernel, dm-verity read-only root, USB-only authenticated sync).

The child-facing layer (Godot shell + signed PCK activities) is identical on both tiers. Strictly non-profit. Read `ARCHITECTURE.md` for the full design; §6 records why the project moved from OS-only to two tiers.

## Inviolable constraints — never violate, never "helpfully" work around

### Everywhere (both tiers)

1. **No text in the kid-facing UI.** No strings, labels, tooltips, or error text rendered to the child. Icons, color, animation, audio only. (Code comments, logs, parent/companion UI text are fine.)
2. **One runtime for child-facing content: Godot 4, as signed PCK bundles.** No web views, alternative engines, interpreters, or content plugin systems — on either tier.
3. **Unsigned content never loads.** Ed25519 signature verification before any bundle loads, app and OS alike. Never add a debug bypass that could ship.
4. **No attention-engineering patterns in content.** No streaks, variable rewards, autoplay chains, or timers pressuring continued use. Activities end calmly.
5. **No telemetry, analytics, crash reporting, or tracking of any kind, on any tier, in any component.** Not opt-in, not anonymized, not "just crash counts."
6. **Non-profit is permanent.** No payment, subscription, sponsorship, or project-donation code or copy. Donation references point to children's charities only.
7. **Honest tier labeling is a hard rule in all copy and docs.** The app tier is described as policy-based protection; only Covelight OS may be described with "air gap," "structural," "cannot network," or equivalents. If you write user-facing text, check every safety claim against the tier it describes.

### Tier 1 (Android app) specific

8. **The kiosk never weakens itself.** Device-Owner policies (lock-task, radios off, status bar suppressed, installs blocked, safe-mode blocked) are set at provisioning and never relaxed at runtime. No "temporary exit," no gesture backdoors, no network re-enable path in child-reachable code.
9. **No Play Services dependencies.** The app must build and run without Google libraries (distributed via direct APK + F-Droid; F-Droid inclusion criteria are the compliance bar). No Firebase, no Play billing, no Google analytics — see also constraint 5.
10. **Content enters only via app releases or signed PCK import from the Companion.** Never add over-the-air content download to the child app, even though Android makes it easy — the child device's networking stays policy-dead.

### Tier 2 (Covelight OS) specific

11. **No networking code, ever, in on-device components.** No sockets-to-network, HTTP clients, update checks, or "optional online features." Kernel configs keep all radio drivers and firmware excluded. If a task seems to require networking, stop and flag it.
12. **Nothing is parsed before authentication.** In `covelight-syncd`, Ed25519 challenge-response completes before any variable-length or structured input is processed; pre-auth frames stay fixed-size. Never reorder this.
13. **Private keys never touch the child device.** Only parent public keys are enrolled. Parent-side keys live in platform keystores — never in JS-accessible memory, app storage, or logs. In the mobile Companion, USB-serial and signing code stays in native modules, not JavaScript.
14. **Read-only root & privilege separation are load-bearing.** Persistence goes to the data partition under the correct user (`kid`/`sync`). No writable-root assumptions, no dm-verity weakening, no sudo paths, no setuid binaries, no cross-user shortcuts. No interactive root exists on-device.

## Repository layout

```
/shell        — Godot 4 shell + activity SDK (shared, both tiers)
/activities   — first-party learning activities (Godot → signed PCKs)
/app          — Tier 1: Android kiosk wrapper (Device Owner, lock-task)
/companion    — parent side: Tauri desktop (provisioning + OS sync) and RN mobile (OS sync)
/os           — Tier 2: pmbootstrap configs, kernel configs, packaging, image build
/syncd        — Tier 2: covelight-syncd (Rust)
/devices      — device database: data/, tools/score.py, probe (see docs/device-database.md)
/docs         — ARCHITECTURE.md, protocol spec, provisioning guide, porting guides
/tools        — content signing, CI helpers
```

(Keep this section current if the skeleton evolves.)

## Conventions

- **Godot:** GDScript, Godot 4.x; activities build against the SDK in `/shell` — no engine-internal reach-ins from activity code. New activities require a content review against constraint 4.
- **Android:** Kotlin; no Google library dependencies (constraint 9); vendor-skin workarounds get documented per-device in the test matrix, never silently hacked in.
- **Rust:** stable toolchain, `cargo fmt` + `clippy -D warnings`; no `unsafe` in protocol/parsing code without a justifying review comment; parser changes ship with fuzz targets. No new `syncd` dependencies without justification — the input boundary stays small.
- **TypeScript:** strict mode. Protocol framing is mirrored from Rust — **the Rust implementation is the source of truth for the wire format.**
- **Commits/PRs:** small, single-purpose. Anything touching kiosk policies, `syncd` auth, kernel config, signing, or user separation gets a `security` label and requires review. Anything touching user-facing safety claims gets an `honest-labeling` review (constraint 7).

## Current phase & priorities

- **Phase 0 (now):** repo skeleton, namespaces (`covelight.org`, `covelight.dev`, GitHub org).
- **Phase 1 (next):** Godot shell + activity SDK + first activities — desktop-runnable, no phone needed. This is the critical path; both tiers ride on it.
- **Phase 2:** Android kiosk wrapper + Companion setup helper → first family-usable release.
- **Phase 3:** device-test matrix, vendor-skin hardening (MIUI foreground-kill issues are known hostile terrain), F-Droid submission.
- **Phase 4–5 (OS track):** Rust sync protocol → pmOS/QEMU image → Pi Zero 2 W USB-gadget tests → OnePlus 6 bring-up.
- **Phase 6:** device database/compatibility checker, Halium expansion ports.
- **Open decisions:** license (do not add license headers until resolved); "Covelight" trademark check pending.

## Hardware & platform context

- Tier 1 targets Android 8+ broadly; Device Owner requires factory-reset provisioning (the setup flow must say so upfront).
- Tier 2 reference device: OnePlus 6/6T (mainline, locally unlockable — no vendor server involved). Do not write copy implying the OS runs on arbitrary phones; modern Samsung/Huawei/Oppo-family and Xiaomi-legacy devices are bootloader-blocked, and the trend is one-way. The app tier exists precisely for those devices.
- Dev: shared platform work needs only a desktop; OS track uses macOS + UTM/QEMU aarch64 and a Pi Zero 2 W gadget test stand.

## Tone for user-facing text (companion, website, docs)

Calm, honest, precise. Claims match tiers exactly (constraint 7). Never "unhackable," never "100% safe." Lead with what is structurally or verifiably true. The lighthouse/harbor identity extends to the writing: reassuring, not alarmist.
