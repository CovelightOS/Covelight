# Covelight Device Database — Design

## Purpose

Answer three questions from one dataset:

1. **Parent-facing:** "I have an old <phone> in a drawer. Will Covelight run on it?"
2. **Contributor-facing:** "Which device should I port next, and what work already exists for it?"
3. **Project-facing:** "What is our real supported-device list?"

## Core insight: our bar is much lower than a phone OS's bar

A general-purpose mobile Linux distro considers a device "done" when it works as a *phone*. That means modem, calls, SMS, camera, Bluetooth, GPS, NFC, sensors, video codecs. Most ports stall on exactly those.

Covelight needs **six** things, and actively wants four of the hard ones **absent**:

| Requirement | Needed? | Notes |
|---|---|---|
| Display | ✅ Required | |
| Touchscreen | ✅ Required | |
| GPU / 3D acceleration | ✅ Required | Godot is unusable on software rendering |
| Audio output | ✅ Required | Textless UI is sound-driven — non-negotiable |
| Battery / charging | ✅ Required | Must charge safely and report level |
| USB gadget (CDC-ACM) | ✅ Required | The entire sync architecture depends on it |
| Modem / cellular | ❌ Must be absent | Compiled out |
| Wi-Fi | ❌ Must be absent | Compiled out — this is the air gap |
| Bluetooth | ❌ Must be absent | Compiled out |
| Camera, GPS, NFC, sensors, codecs | 🚫 Don't care | Not used by any Covelight component |

**Consequence:** many devices marked "partially working" upstream are, for us, **fully working**. The database's job is to re-score existing upstream data against this shorter checklist. That is data work, not kernel work — and it means our real supported list is probably larger than the published tables suggest.

## Architecture

```text
data/soc.yml           ── mainline support level per SoC (hand-curated, ~40 rows)
data/oem-policy.yml    ── bootloader unlock policy per OEM (hand-curated, ~20 rows)
data/devices/*.yml     ── one file per device, keyed by codename
        │
        ▼
tools/ingest/*         ── adapters that pull upstream data into device files
tools/score.py         ── applies the 6-requirement model → tier
        │
        ▼
build/devices.json     ── static blob consumed by the web checker (no backend)
build/roadmap.md       ── contributor-facing "port these next", demand-ranked
```

No server. No database engine. No telemetry. Files in git, reviewed by PR, compiled to a static JSON.

## The join key: codename, not marketing name

Marketing names are a swamp — regional variants, carrier variants, renames (Poco F1 / Pocophone F1 / Xiaomi Mi 8 SE...). Every upstream project (postmarketOS, LineageOS, TWRP, Halium) keys on **codename** (`enchilada`, `fajita`, `beryllium`). So:

- Primary key: `<vendor>-<codename>` (e.g. `oneplus-enchilada`)
- `aliases:` holds every marketing/regional/carrier name a parent might type
- The parent-facing checker searches aliases; everything internal uses codenames

Fuzzy search over aliases is what makes "Which phone do you have?" actually usable.

## Device record schema

See `data/devices/enchilada.yml` for a worked example. Fields:

```yaml
codename:            # canonical, lowercase
vendor:              # oneplus, xiaomi, samsung, ...
aliases:             # every name a human might type
soc:                 # key into soc.yml
year:                # release year
arch:                # aarch64

bootloader:
  unlockable:        # yes | no | conditional
  notes:             # e.g. Xiaomi account wait period; Samsung Knox efuse

support:             # per-requirement status, per track
  track: mainline    # mainline | halium
  display:      works | partial | broken | unknown
  touch:        ...
  gpu:          ...
  audio_out:    ...
  charging:     ...
  usb_gadget:   ...

sources:             # provenance for every claim above — required
  - name: postmarketos-wiki
    url: ...
    fetched: YYYY-MM-DD
  - name: covelight-probe
    report_id: ...

artifacts:           # prior work a porter can reuse
  kernel_source:     # OEM GPL release
  lineage_tree:      # device tree
  twrp_tree:
  pmaports:

demand:              # populated from checker lookups (aggregate counts only)
  lookups: 0

tier:                # DERIVED — never hand-edited
verified_by:         # who confirmed, and how
```

**`sources` is mandatory on every status claim.** A device list that a parent trusts with their child's device cannot contain guesses. `unknown` is a perfectly good value; a wrong `works` is not.

## Tier model (derived, not hand-assigned)

| Tier | Meaning |
|---|---|
| `verified` | Mainline kernel; all six requirements confirmed working, at least one confirmed by a Covelight probe run (not just upstream claims). Full structural air-gap claim holds and is maximally auditable. |
| `supported` | All six work, but via Halium (vendor kernel rebuilt with radios stripped), **or** mainline with only upstream-reported (not Covelight-verified) status. |
| `candidate` | SoC is mainlined and bootloader is unlockable, but one or more of the six is `unknown` or `partial`. **This is the porting backlog.** |
| `blocked` | Bootloader not unlockable. No amount of engineering fixes this. Terminal state. |
| `unviable` | SoC has no mainline path (most MediaTek) and no Halium port. Effectively terminal. |

Scoring rules:
- `bootloader.unlockable == no` → **`blocked`**, regardless of everything else. Check this first; it short-circuits.
- any of the six `broken` → `unviable` (unless a Halium track fixes it)
- any of the six `unknown`/`partial` → `candidate`
- all six `works`, mainline, Covelight-probe confirmed → `verified`
- all six `works`, otherwise → `supported`

## The `unknown` problem — and `covelight-probe`

Here is the honest gap: **almost nobody upstream tests USB gadget mode**, because a general-purpose phone OS doesn't care about it. So `usb_gadget: unknown` will be the single most common blocker in the database, and it's the one requirement we cannot compromise on.

Solution: **`covelight-probe`** — a small bootable image that runs the six checks and prints a result the user can submit as a PR or paste into an issue:

- panel lights up, correct resolution
- touch events register (tap targets)
- GPU: renders a test scene at an acceptable frame rate
- audio: plays a tone, user confirms they heard it
- charging: reports battery level, current draw sane
- USB gadget: enumerates CDC-ACM, echoes bytes to a host

This turns a hard research task into a five-minute crowdsourced action that any parent or hobbyist with the phone in hand can perform — **without committing to installing Covelight**. It is the cheapest possible way to grow the database, and it scales with the community rather than with the core team.

It also means the two programs feed each other: a drawer-phone donation drive supplies both families *and* the hardware contributors need to run probes and do ports.

## Ingest sources

| Source | Gives us | Format | Confidence |
|---|---|---|---|
| postmarketOS device wiki / `pmaports` | per-component status, codenames, SoC, `deviceinfo` | wiki tables + repo files | High — closest match to our requirement columns |
| LineageOS wiki device data | codename ↔ marketing name, SoC, year, vendor | structured YAML per device | High — best source for **aliases** |
| Halium / Droidian / UBports device lists | Halium-track availability | pages/lists | Medium |
| TWRP device list | existence of a device tree (porting artifact) | pages | Medium |
| OEM GPL kernel release portals | kernel source availability | per-vendor sites | Manual |
| OEM bootloader policy | `unlockable` | **hand-curated** | Must be manual — no reliable machine source, and it changes |

**Verify every adapter against the live format before writing it.** These are community-maintained sources; layouts change. Each adapter must record `fetched:` dates so staleness is visible, and ingest must never overwrite a `covelight-probe`-sourced status with a scraped one — probe data is higher authority.

**`bootloader.unlockable` is the highest-stakes field in the whole dataset** and must be human-reviewed. It's also the fastest short-circuit: if it's `no`, nothing else matters. Curate it first.

## Demand ranking

The checker logs **only** an aggregate counter per codename (no identifiers, no IPs, nothing per-person — a Covelight service that tracks people would be self-defeating). That counter turns the porting backlog into a demand-ranked queue:

```text
priority = demand.lookups
         × bootloader_unlockable
         × soc_mainline_score
         × (1 + existing_artifacts)
```

"400 parents have a Redmi Note 8 in a drawer, its SoC is mainlined, LineageOS trees exist" is a *far* more motivating contributor task than a generic backlog entry — and it's computed, not guessed.

## Build order

1. `soc.yml` + `oem-policy.yml` — small, hand-curated, and they alone let you answer "blocked / not blocked" for most phones people own. **This is 80% of the parent-facing value for ~5% of the work.**
2. LineageOS ingest → aliases + codename ↔ marketing-name mapping (makes lookup usable)
3. postmarketOS ingest → the six requirement columns
4. `score.py` → tiers → `devices.json`
5. Static checker page consuming `devices.json`
6. `covelight-probe` → close the `usb_gadget: unknown` gap, crowdsourced
