# Phase 3 — Tier 1 Hardening (skeleton)

**Full task breakdown happens when Phase 2 ships.** Scope committed now:

- **Device-test matrix** (`docs/device-matrix.md`): community-run checklist per vendor skin — provisioning success, kiosk persistence, foreground-kill behavior (MIUI is known hostile terrain), boot persistence, radio-policy verification. [CC] builds the checklist + reporting template; [human/community] runs devices. Priority vendors: Samsung, Xiaomi/MIUI-HyperOS, Oppo family, Lenovo/Moto tablets. **Amazon Fire OS gets a row before any support claim is made — verify, don't assume.**
- **Vendor-quirk fixes**: one task per confirmed quirk, documented per-device, never silently hacked in.
- **F-Droid submission**: verify current F-Droid inclusion criteria at the time (reproducible build requirements evolve), fix what fails, submit. [CC+human]
- **Update channel**: how families update the app without OTA-to-child (Companion-mediated app update is the leading design).
- Parking lot: accessibility features (motor-impairment input options), multi-child profiles.

---

# Phase 4 — Tier 2 OS Track (skeleton)

**Full task breakdown happens when Phase 3 is underway.** Scope committed now:

- **Protocol spec** (`docs/protocol.md`): frame format, Ed25519 challenge-response handshake, fixed-size pre-auth frames, content-transfer and progress-export messages, error handling. The spec precedes code; the Rust implementation is the wire-format source of truth.
- **`covelight-syncd`** in `/syncd`: pty/loopback transport first (no hardware), `covelight-crypto` reuse, fuzz targets on every parser (CLAUDE.md #12–14 in force).
- **Companion sync client**: desktop first; RN mobile after (native modules for serial + signing).
- **pmOS image**: pmbootstrap config, cage + shell autostart, three-user separation, radios-out kernel config — QEMU aarch64 target only in this phase.
- Reuse note: the shell, activities, and signing pipeline arrive here **unchanged** from Phase 1 — this phase is transport + OS packaging only.

---

# Phase 5 — Tier 2 Hardware (skeleton)

**Full breakdown when Phase 4's QEMU image boots.** Scope committed now:

- **Pi Zero 2 W gadget stand** [CC+human]: USB CDC-ACM gadget via configfs, real enumeration against the Companion, protocol soak testing on real cables/ports.
- **OnePlus 6 bring-up** [human-heavy]: flash pmOS, validate the six requirements (display, touch, GPU, audio out, charging, USB gadget), then the Covelight image. First `verified`-tier entry in the device database.
- **dm-verity + read-only root** on real hardware; measured boot documentation.
- **Covelight OS beta release.**

---

# Phase 6 — Device Ecosystem (skeleton)

**Full breakdown when Covelight OS beta exists.** Scope committed now; foundations already in `/devices` (see `docs/device-database.md`):

- **Fill `oem-policy.yml` and `soc.yml` with verified, dated, sourced data** [human research + CC tooling]. Add the `unlock_mechanism: local | server | toggle` field — local-unlock devices are permanently safe to recommend; server-mediated ones can be revoked retroactively (Xiaomi 2025 precedent).
- **Ingest adapters** for postmarketOS wiki + LineageOS device data (verify live formats before writing adapters; probe data always outranks scraped data).
- **Compatibility checker**: static site consuming `build/devices.json` — "which old phone is in your drawer?" [CC]
- **`covelight-probe`**: bootable six-check image producing submittable reports — the crowdsourced answer to `usb_gadget: unknown`. [CC+human]
- **Halium expansion ports**, demand-ranked by checker lookups × feasibility. Vendor kernels rebuilt with radios stripped; `supported`-tier labeling.
- **Drawer-phone donation program** [human]: donated devices supply families *and* give porters hardware. Pairs with the checker launch.
