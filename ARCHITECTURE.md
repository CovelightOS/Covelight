# Covelight — Architecture

System design, security model, and the reasoning behind the major decisions — including alternatives considered and rejected, and one major decision that was *reversed* (§6). Audience: engineers evaluating, reviewing, or contributing.

## 1. Requirements and the shape they force

The project's ranked requirements:

1. **Reach:** work on most modern phones — ideally the phone already in the family's drawer.
2. **Fully free:** no cost, no monetization, no data extraction, ever.
3. **Open contribution:** a volunteer community must be able to build this.

Requirement 1 has exactly one technical answer for locked-bootloader devices (which now includes all modern Samsung, Huawei/Honor, Oppo/Realme/Vivo, and a growing share of others): software that runs *on* Android. Requirement-complete protection (a structural air gap) has exactly one answer too: *replacing* Android, which only unlockable devices permit. These answers are incompatible on a single device — so Covelight ships **two tiers on one shared platform**, honestly labeled.

## 2. The shared platform (where children actually live)

Everything a child sees and touches is identical on both tiers:

- **Covelight Shell** — a Godot 4 application: fullscreen, textless, sound-driven. No text is ever rendered to the child; communication is icons, color, animation, audio.
- **Learning activities** — Godot PCK bundles, dynamically loaded by the shell.
- **Content signing** — every bundle is Ed25519-signed; the shell verifies signatures before loading, on both tiers. Unsigned content does not load anywhere.
- **The content rule** — no attention engineering: no streaks, variable rewards, autoplay chains, or pressure timers. Activities end calmly. This is enforced in activity review, not just stated.
- **One runtime, by design** — all on-device content is Godot. No web views, no alternative engines, no plugin interpreters. One runtime means one sandbox, one signing pipeline, one attack surface, and one skill set for content contributors.

**Why a game engine for a non-game:** a textless UI is pure animation, touch, and audio — the native workload of a game engine and a constant fight in conventional UI toolkits. (The project's original Qt/QML design was superseded on exactly this point.) Contributors don't need engine expertise: the **activity SDK** (scene template, audio helpers, input API) makes a first activity a weekend-sized task.

## 3. Tier 1 — Covelight, the Android kiosk

### 3.1 Mechanism

- The Covelight app is provisioned as **Android Device Owner** on a factory-reset device (`dpm set-device-owner` over ADB — no accounts may exist on the device, hence the reset).
- Device Owner policies then: set Covelight as the persistent launcher in **lock-task (kiosk) mode**, disable Wi-Fi/Bluetooth/mobile data, suppress the status bar and system UI surfaces, block app installation and safe-mode entry, and disable factory reset from settings.
- The **desktop setup helper** (part of the Covelight Companion, Tauri) walks the parent through reset → developer options → cable → one click. The parent never sees a terminal. This helper is a first-class product surface — if setup is hard, nothing else matters.
- Distribution: direct APK + F-Droid. **No Play Store dependence** — the project must not be removable by a platform gatekeeper.

### 3.2 Content delivery on Tier 1

The child device's networking is policy-disabled, so content never arrives over the air on the child device. Activities ship (a) bundled with the app release, and (b) as signed PCK files imported via USB file transfer from the Companion, verified on-device before loading. The same signature scheme as Tier 2 — only the transport differs.

### 3.3 Honest limitations (these go in public copy, not just here)

- Protection is **policy, not structure**: the radios, Android, vendor firmware, and (on most devices) Play Services remain present and functional beneath the kiosk. A policy has an implementation; implementations have bugs. We claim "the device does only Covelight," never "the device cannot network."
- The vendor OS underneath may itself carry telemetry and ads (e.g., HyperOS-era Xiaomi skins). Covelight adds zero tracking of its own — published, auditable — but cannot amputate the host OS.
- Vendor skins are hostile terrain: aggressive background-process killing (notably MIUI), OEM update drift, per-vendor kiosk quirks. Mitigation: a community **device-test matrix**, treated as a permanent workstream, not a launch task.
- Device Owner requires factory reset; the setup flow says so before step one.

## 4. Tier 2 — Covelight OS, the flagship

The complete design as originally specified, unchanged in substance:

```text
┌─────────────────────────────────────────────┐
│  Learning activities (signed .pck bundles)  │   ← identical to Tier 1
├─────────────────────────────────────────────┤
│  Covelight Shell — Godot 4, fullscreen      │   ← identical to Tier 1   (user: kid)
├─────────────────────────────────────────────┤
│  cage (Wayland kiosk compositor)            │   (user: kid)
├──────────────────────┬──────────────────────┤
│  OpenRC services     │  covelight-syncd     │   (user: sync)
│                      │  Rust, USB CDC-ACM   │
├──────────────────────┴──────────────────────┤
│  Alpine userspace (postmarketOS)            │
├─────────────────────────────────────────────┤
│  Kernel — radio drivers & firmware ABSENT   │
├─────────────────────────────────────────────┤
│  dm-verity read-only root                   │
└─────────────────────────────────────────────┘
           ▲ USB-C — the only I/O channel
```

- **Structural air gap:** Wi-Fi/Bluetooth are not disabled — their drivers and firmware are excluded from the kernel build. No runtime path can re-enable what isn't there.
- **`covelight-syncd` (Rust):** the sole untrusted-input boundary. USB CDC-ACM gadget; Ed25519 challenge-response; **nothing is parsed before authentication succeeds** (pre-auth frames are fixed-size); parent private keys live only in platform keystores and never exist on the child device. Rust for memory safety exactly here; fuzz targets accompany parser code.
- **Privilege separation:** `kid` (shell; can read content, write progress) / `sync` (daemon; can write content store, nothing else) / `root` (init only; no interactive login exists).
- **Threat model honesty:** the child is not an adversary; anyone with fastboot access can reflash the device (fine — we are child-safe software, not anti-theft). We defend against network paths existing, untrusted USB input, and drift between published and running code (reproducible builds are a stated long-term goal).
- **Devices:** reference is OnePlus 6/6T (mainline postmarketOS, mature freedreno GPU, working USB gadget, locally unlockable *forever* — fastboot unlock with no vendor server involved). Expansion: other well-mainlined Qualcomm devices, then Halium ports (vendor GPL kernels rebuilt with radios stripped — air gap preserved, auditability reduced, labeled accordingly). The device database (`docs/devices/device-database.md`) drives this with a six-requirement scoring model (display, touch, GPU, audio out, charging, USB gadget) and a hard rule: **`unknown` never gets promoted to `works` by inference.**

## 5. The Companion (parent side)

One desktop application (Tauri; macOS/Windows/Linux) with two jobs:

1. **Tier 1 provisioning:** the guided Device-Owner setup described in §3.1 (bundled ADB, no terminal).
2. **Tier 2 sync client:** USB serial connection to `covelight-syncd`, Ed25519 signing with keys in the OS keychain, content library management.

A mobile companion (React Native, Android) covers Tier 2 sync for parents without a computer; its USB-serial and signing paths live in native modules, not JavaScript. **iOS phones cannot host the companion** — iOS provides no general-purpose USB serial API (External Accessory requires MFi hardware; DriverKit doesn't extend to iPhone). iPhone households use the desktop Companion.

## 6. Decision log

| Decision | Alternatives rejected | Reasoning |
|---|---|---|
| **Two tiers on one shared Godot platform** | (a) OS-only — *the project's original position, reversed*; (b) app-only | OS-only fails requirement 1: the flashable-device pool is finite and shrinking (Samsung ended bootloader unlocking with One UI 8 and re-locks on update; Xiaomi decommissioned legacy unlock servers in 2025 and rations the rest; Huawei/Oppo/Realme/Vivo closed; carrier variants locked). App-only surrenders the structural claim and the project's proof of seriousness. Two tiers keep the reach *and* the flagship — at the price of permanent, explicit tier labeling. |
| Godot 4 as the only content runtime | Qt/QML; per-contributor frameworks | Textless animated/audio UI is engine-native work; single runtime = single sandbox/signing/attack surface; maximizes the contributor pool for content. |
| Device Owner kiosk for Tier 1 | Plain launcher app; accessibility-service lockdown | Only Device Owner can persistently pin the app, disable radios by policy, and block escapes without root. Launcher-only approaches are trivially exited. |
| Direct APK + F-Droid distribution | Play Store primary | A gatekeeper-escape project must not be removable by a gatekeeper. (Play listing may exist as a mirror later; never as the canonical channel.) |
| Rust for `covelight-syncd` | C/C++ | Memory safety at the one boundary parsing attacker-controllable bytes. |
| Mainline-first for the OS, Halium as expansion | Halium-first | One auditable kernel tree anchors the headline claim; Halium widens hardware later without surrendering the air gap. |
| USB-C as Tier 2's only channel | Local Wi-Fi Direct/BT sync | Any radio transport requires shipping radio drivers, destroying the air gap. The cable *is* the trust model. |
| Honest tier labeling as a hard rule | Marketing both tiers under one safety claim | The first security researcher to find the gap between claim and reality would — rightly — burn the project's credibility. The app tier never claims an air gap, anywhere, ever. |

## 7. Development environments

- **Shared platform (Phase 1):** Godot 4 on any desktop — the shell and activities run and are reviewed entirely on desktop; no phone needed.
- **Tier 1 (Phase 2–3):** any Android device + ADB; community device-test matrix for vendor skins.
- **Tier 2 (Phase 4+):** protocol development on desktop (pty/loopback); QEMU aarch64 via UTM; Pi Zero 2 W as USB-gadget test stand; OnePlus 6 bring-up.
- CI: Godot export + content-signature checks; Android build; Rust test/lint/fuzz; pmOS image builds.

## 8. Known limitations, stated openly

- Tier 1 sits on an OS we don't control; its protection is as strong as Android's Device Owner enforcement on that vendor's skin — strong, but policy.
- Tier 2's Supported (Halium) devices run frozen vendor kernels with proprietary GPU/firmware blobs; tier labeling keeps this honest.
- No telemetry means no remote crash reporting on either tier; debugging relies on parent-initiated log export.
- A parent (or anyone with the device and a computer) can undo either tier. Out of scope by design.
