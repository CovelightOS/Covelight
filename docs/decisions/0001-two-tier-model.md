# ADR 0001 — Two-Tier Model (App + OS)

**Status:** Accepted · July 2026
**Supersedes:** the project's original OS-only architecture.

## Context

Covelight began as a Linux-only design: replace Android entirely (postmarketOS base) to achieve a *structural* air gap — radio drivers compiled out of the kernel, read-only verified root, content arriving solely over an authenticated USB-C protocol. That design remains sound and is retained (see Tier 2 below).

The problem was reach. Replacing an OS requires an unlockable bootloader, and investigation of the 2025–2026 landscape showed that door closing industry-wide: Samsung ended bootloader unlocking with One UI 8 (and re-locks previously unlocked devices on update); Xiaomi decommissioned its legacy unlock servers in August 2025, permanently sealing many older devices, and rations remaining unlocks (account binding, waiting periods, ~3 devices/year); Huawei/Honor, Oppo, Realme and Vivo are closed; carrier variants are widely locked; and most cheap devices — the phones families most commonly own — run MediaTek SoCs with no viable mainline path regardless. There were also claims that the EU Radio Equipment Directive mandates this trend; that regulatory reading is disputed, but the vendor behavior is fact either way.

The project's ranked requirements were then made explicit: (1) reach — work on most modern phones, ideally the one already in the family's drawer; (2) fully free; (3) open to contribution. Requirement 1 and the structural air gap are incompatible *on the same device*: locked devices can only be reached by software running on Android; the air gap can only exist by replacing Android.

A single-tier resolution in either direction was rejected. OS-only fails requirement 1 outright. App-only (Android kiosk alone) surrenders the structural claim, the project's strongest differentiator and proof of seriousness, and puts Covelight in undifferentiated competition with commercial parental-control products.

## Decision

Ship one shared child-facing platform (Godot 4 shell + Ed25519-signed PCK activities) at two explicitly labeled protection tiers:

- **Tier 1 — Covelight (app):** Android Device-Owner kiosk. Policy-based protection (lock-task, radios disabled, launcher replaced, installs blocked). Runs on nearly any Android 8+ phone or tablet, including locked-bootloader devices. Distributed as direct APK + F-Droid — no Play Store dependence.
- **Tier 2 — Covelight OS (flagship):** the original Linux design, unchanged: structural air gap, dm-verity read-only root, Rust sync daemon over USB CDC-ACM, three-user privilege separation, curated device list (reference: OnePlus 6/6T).

Bound by a hard rule: **honest tier labeling everywhere, always.** The app tier is never described with "air gap," "structural," or "cannot network." Air-gap language belongs to Covelight OS exclusively. This rule is CLAUDE.md constraint #7 and carries its own PR review label.

## Consequences

**Positive.** Reach: the drawer phone and the locked new Samsung are both viable Tier 1 targets. Time-to-first-child shrinks dramatically (Godot shell + kiosk wrapper ships in months; the OS was always a year+). The contributor pool widens (Godot + Android skills vastly outnumber kernel-bring-up skills). The shared content platform means every activity serves both tiers forever. Tier 2 becomes the honest upgrade path ("same Covelight — now with the radios physically absent") rather than the sole gate.

**Negative / accepted costs.** Tier 1 sits on a vendor OS we don't control: Play Services and vendor telemetry beneath the kiosk, per-skin quirks (MIUI foreground-killing, OEM update drift) as a permanent maintenance workstream, and protection that is policy — an implementation with a bug surface — rather than structure. Two provisioning flows to maintain. And a permanent communication burden: the tier distinction must be re-explained forever, because blurring it once, in one place, hands a security researcher a legitimate "Covelight overclaims" story.

**Reversal criteria.** If Tier 1's policy enforcement proves unreliable on major vendor skins despite the test matrix, or if honest labeling proves impossible to sustain in practice, the app tier is cut before the claim is softened. The claim is load-bearing; the tier is not.
