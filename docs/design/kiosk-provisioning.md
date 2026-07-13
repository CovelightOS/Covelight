# Kiosk Provisioning Design (Tier 1)

> **Status: PLANNED — written alongside tasks T2.2 and T2.4** (`docs/plan/03-phase2-kiosk.md`).

## Will cover
- Device Owner provisioning flow (factory-reset requirement, adb dpm path, account-free precondition)
- Full policy set applied at provisioning (lock-task, radios, status bar, installs, safe mode, keyguard) — and the rule that policies are never relaxed at runtime (CLAUDE.md #8)
- Parent exit path: gesture → PIN → parent menu; rate limiting; Companion-based recovery (no on-device backdoor)
- Unprovisioning / clean removal
- Known residual surfaces (power menu, recovery-mode combos, vendor dialogs) and their honest assessment (ARCHITECTURE §3.3)
