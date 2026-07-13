# Porting Covelight OS to a New Device

> **Status: PLANNED — Phase 6** (`docs/plan/04-phase3-to-6-skeletons.md`).

## Will cover
- The six requirements (display, touch, GPU, audio out, charging, USB gadget) — and everything you may ignore (modem, camera, BT, GPS: not needed, radios actively stripped)
- Mainline track (postmarketOS) vs Supported track (Halium, vendor kernel rebuilt with radios removed)
- Using the device database and covelight-probe
- Submitting results; tier criteria ('verified' requires a probe run — see docs/devices/device-database.md)
