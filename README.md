# Covelight

**No phone on Earth was built for a child. So we're building one — and until every family can have it, we're rescuing the phones they already own.**

Covelight is a free, open-source learning environment for pre-literate toddlers and young children (roughly ages 2–6). No ads, no feeds, no app store, no accounts, no data collection, no attention-engineered design — and no reading required: the interface is entirely textless, built from symbols, color, animation, and sound.

Covelight ships at **two protection tiers** that share the same learning environment. A child moving between them notices nothing.

## The two tiers

| | **Covelight** (the app) | **Covelight OS** (the flagship) |
|---|---|---|
| What it is | A full-device kiosk for Android | A complete Linux-based mobile OS that replaces Android |
| Runs on | Nearly any Android phone from the last ~8 years — including the old phone already in your drawer | A curated list of supported devices (starting with the OnePlus 6/6T) |
| How it protects | **Policy-based:** the device is provisioned so Covelight is the only thing it does — launcher replaced, Wi-Fi/Bluetooth disabled, status bar removed, no other apps, no store | **Structural:** Wi-Fi and Bluetooth drivers are compiled out of the kernel. Wireless isn't turned off — it doesn't exist. The system is read-only and cryptographically verified |
| Setup | Factory reset, then a guided setup helper on your computer does the rest | Flash the OS with our guided installer |
| Availability | First release target | In development; the app is your on-ramp |

**We label these tiers honestly, always.** The app provides strong protection by policy on top of the phone's original Android. The OS provides complete protection by structure. We will never blur that line — if you see us claim an "air gap" it refers to Covelight OS only.

Both tiers run the identical learning content: activities are signed bundles, verified on the device before loading, on the app and the OS alike.

## Non-profit, permanently

Covelight is free and open source. The project accepts no personal payment of any kind; any donations go to children's charities. There are no subscriptions, no premium tiers, no ads, and no data to sell — structurally, in the case of the OS, and by published, auditable code in the case of the app. This is not a startup. It is infrastructure we believe should simply exist.

## Why this exists

Every phone a child touches today was designed for an adult, then patched with "kids mode" — while the machinery underneath (feeds, notifications, recommendation engines, ads) was engineered to capture attention, including theirs. Parental-control products negotiate with that machinery. Covelight removes the child from it:

- The **app tier** takes over the entire device: nothing else runs, nothing interrupts, nothing advertises, nothing tracks the child on Covelight's side.
- The **OS tier** goes further and removes the machinery itself: no Android underneath, no Play Services, no radios in the kernel, content arriving only over a cryptographically authenticated USB-C cable from a parent's device.

And the content itself follows one rule everywhere: **no attention engineering.** No streaks, no variable rewards, no autoplay chains, no timers pressuring continued use. Activities end calmly.

## The phone is already in your drawer

You don't need to buy your child a device. Almost every household has a retired smartphone in a drawer. For the app tier, nearly any of them works. For the OS tier, phones from the 2018–2021 era (OnePlus 6/6T and similar) are ideal — a compatibility checker is in development so you can look up exactly what the phone in your drawer supports. One practical tip in the meantime: **don't let old drawer phones install pending system updates** — recent manufacturer updates have been removing the unlocking capability the OS tier depends on.

## Project status & roadmap

Building in public. Current phase: **0**.

| Phase | Scope | Tier |
|---|---|---|
| 0 | Repo skeleton, namespaces | — |
| 1 | Godot shell, activity SDK, first learning activities | Shared |
| 2 | Android kiosk wrapper + desktop setup helper → **first family-usable release** | App |
| 3 | Device-test matrix, vendor-skin hardening, F-Droid distribution | App |
| 4 | Rust sync daemon & USB protocol; postmarketOS image (QEMU) | OS |
| 5 | USB gadget hardware testing; OnePlus 6 bring-up → **Covelight OS beta** | OS |
| 6 | Device database & compatibility checker; additional device ports (Halium) | OS |

## Technology

- **Learning environment (shared):** Godot 4 — the shell and all activities; content ships as Ed25519-signed PCK bundles, verified before loading
- **App tier:** Android Device Owner / lock-task kiosk; distributed as a direct APK and via F-Droid — no Play Store dependence; provisioned by a desktop helper (Tauri) so parents never touch a terminal
- **OS tier:** postmarketOS (Alpine Linux), cage Wayland kiosk, dm-verity read-only root, radios compiled out; Rust sync daemon (`covelight-syncd`) over USB CDC-ACM with Ed25519 challenge-response; three-user privilege separation
- **Companion (parent side):** one desktop app handles both app-tier provisioning and OS-tier content sync. A mobile Companion (React Native, Android) is planned for OS-tier sync without a computer — not yet built.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full design and the reasoning behind it.

## Contributing

The two-tier model means most contributions help *every* child on *both* tiers:

- **Learning activities** (Godot 4 / GDScript) — the highest-impact lane; the activity SDK makes your first one a weekend project. No game-dev background needed.
- **Android** — kiosk wrapper, Device Owner provisioning, vendor-skin quirk hunting (we especially need people with Xiaomi/MIUI, Samsung, and Oppo devices to test)
- **Design & audio** — textless UI is its own craft: iconography, sound design, interaction for pre-literate users
- **Rust / Linux / embedded** — sync daemon, protocol fuzzing, kernel config, device ports (OS tier)
- **Desktop / TypeScript** — the companion & setup helper
- **Security review** — threat modeling, protocol review, honest-labeling review of all public copy

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to pick a task and PR
conventions. Open an issue or start a discussion to get involved.

## License

License selection is being finalized and will be committed before the first tagged release. The project will remain free and open source in perpetuity.

---

*Covelight — a calm harbor in a connected world.*
