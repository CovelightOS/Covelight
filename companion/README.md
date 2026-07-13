# /companion

Parent-side software, two clients:

- **Desktop (Tauri, macOS/Windows/Linux):** Tier 1 Device-Owner provisioning
  wizard, and Tier 2 USB sync client (content push, progress export).
- **Mobile (React Native, Android):** Tier 2 sync only, for parents without a
  computer. USB-serial and signing logic live in native modules, not
  JavaScript (CLAUDE.md #13). Not yet built — desktop ships first.

**Tier:** cross-tier — desktop handles both tiers' parent-facing work; mobile
covers Tier 2 only.

**Status:** not started — see `docs/plan/03-phase2-kiosk.md` (Phase 2,
desktop provisioning) and `docs/plan/04-phase3-to-6-skeletons.md` (Phase 4,
desktop + mobile sync client).
