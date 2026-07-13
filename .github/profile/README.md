# Covelight

**No phone on Earth was built for a child.**

So we're building one — and until every family can have it, we're rescuing the phones they already own.

Covelight is a free, open-source learning environment for pre-literate children, roughly ages 2–6. No ads, no feeds, no accounts, no data collection. The interface is entirely textless — symbols, color, animation, and sound, nothing to read.

## Two tiers, one child-facing experience

Covelight ships at two protection tiers. A child moving between them notices nothing.

**Covelight (the app)** — a kiosk mode for Android phones you already own. Protection is **policy-based**: the device is provisioned so Covelight is the only thing it does. Launcher replaced, Wi-Fi and Bluetooth disabled, no other apps, no store. Runs on nearly any Android phone from the last several years.

**Covelight OS (the flagship)** — a Linux-based mobile OS that replaces Android on select devices. Protection is **structural**: Wi-Fi and Bluetooth drivers are compiled out of the kernel. Not switched off — absent. The system is read-only and cryptographically verified. This is the only tier we describe as an air gap.

We hold that line on purpose. If you see "air gap," "structural," or "cannot network" applied to the app tier, that's a bug in our writing — tell us.

Both tiers run identical learning content: activities are cryptographically signed and verified on the device before they ever load.

## Non-profit, permanently

Covelight accepts no personal payment, ever. No subscriptions, no premium tiers, no ads. Donations, if any, go to children's charities — never to the project or its contributors. This is infrastructure, not a startup.

## Where things stand

Early days. Building in public, in the open, from phase 0.

Nothing here is ready for a child yet. There are no screenshots to show, because there is nothing on a screen worth screenshotting. When that changes, this page changes with it — not before.

## Help build it

You don't need to be a game developer or a kernel hacker.

- **Learning activities** (Godot 4 / GDScript) — the highest-impact lane. The activity SDK is designed to make your first one a weekend project.
- **Android** — kiosk wrapper, Device Owner provisioning, vendor-skin quirk hunting. Xiaomi/MIUI, Samsung, and Oppo testers especially welcome.
- **Design & audio** — textless UI is its own craft: iconography, sound design, interaction for pre-literate users.
- **Rust / Linux / embedded** — sync daemon, protocol fuzzing, kernel config, device ports.
- **Desktop / TypeScript** — the companion and setup helper.
- **Security review** — threat modeling, protocol review, honest-labeling review of public copy.

Start with [CONTRIBUTING.md](https://github.com/CovelightOS/Covelight/blob/main/CONTRIBUTING.md).

## Read more

- [Repository](https://github.com/CovelightOS/Covelight)
- [Documentation](https://github.com/CovelightOS/Covelight/tree/main/docs)
- [Roadmap / plan](https://github.com/CovelightOS/Covelight/tree/main/docs/plan)

---

*A calm harbor in a connected world.*
