# Content Signing Design

**Status:** Accepted · written for T0.3 (`docs/plan/01-phase0-foundation.md`).
Gates T0.4 (signing tool) and T1.4 (shell verification) — nothing depends on
signing behavior until this doc is approved. Implemented by the shared
`covelight-crypto` crate, consumed by `/tools/sign` (T0.4), the shell's
GDExtension (T1.4), and by Companion/`syncd` import paths (T2.6, Phase 4)
that move signed content onto a device.

## Scope

This document specifies **PCK content signing only**: the scheme that lets
the Covelight Shell verify that a `.pck` activity bundle was produced by a
trusted project key before loading it, on both tiers (ARCHITECTURE §2).

Two other signing concerns exist in this project and are **not** this
document's scope:

- **Android APK signing** (Tier 1 app packaging) — standard Android
  tooling, a distribution concern for `/app`, unrelated to activity content.
- **Tier 2 OS image / dm-verity signing** — a separate OS-build concern
  (`/os`, Phase 4+).

Also out of scope, referenced but not redesigned: **per-parent pairing
keys** (ARCHITECTURE §4, CLAUDE.md #13). Those authenticate a parent's
Companion to that parent's own device over USB for `covelight-syncd`
sync sessions — a different problem (session/device-pairing authentication)
solved by a different, independent set of keypairs (one per parent-device
pairing, private keys in the parent's OS keystore, never on the child
device). Nothing below touches that design.

## Threat model

**The adversary:** anyone who can get bytes onto the path the shell reads
activities from and have them mistaken for legitimate, reviewed content —
a corrupted or truncated file transfer, a tampered download or USB import,
a malicious or compromised third party attempting to substitute unreviewed
content for an official activity, or a compromised build/release pipeline
producing content that was never actually reviewed. Signing defends exactly
one boundary: **the shell must never load a `.pck` that wasn't produced by
a holder of a currently-trusted project key.**

**Not the adversary:** the child (ARCHITECTURE §4 — a small child mashing
the screen is not a threat model). Not a parent with physical access to
their own device — a parent can already undo either tier by design
(ARCHITECTURE §8); signing doesn't add parent-facing restrictions. Not
someone with fastboot/root access reflashing the device wholesale — that is
explicitly out of scope everywhere in this project ("we are child-safe
software, not anti-theft," ARCHITECTURE §4). Signing does not, and is not
meant to, defend against a fully compromised device replacing the shell
binary itself or its embedded trust store — that is a device-integrity
problem (Tier 2's read-only dm-verity root is the relevant structural
defense there; Tier 1 has no equivalent for the shell binary beyond
Android's own APK signing, which is a separate scheme).

Signing also does not attest that content passed the activity-review
checklist (`docs/guides/activity-review.md`) — it attests provenance
(produced by a trusted key), not review compliance. In practice these
coincide today because the only key holders are project maintainers who
sign only reviewed content, but that is a process discipline, not something
the cryptography itself enforces.

## Key hierarchy

Deliberately flat — no CA chain, no X.509, no intermediate keys. One
logical role:

**Project content signing key(s):** one or more Ed25519 keypairs, each
identified by a `key_id`, all listed in a small, source-checked-in
**trusted-keys table** compiled into the shell / `covelight-crypto` (and
therefore shipped with every shell, app, and OS release — no live
key-server, consistent with CLAUDE.md #5/#11's no-network, no-telemetry
constraints). Multiple keys may be trusted simultaneously — this is what
makes rotation possible (see below) — but there is no hierarchy between
them; any trusted key can sign any content.

This is separate from, and does not reference internally, the per-parent
pairing keys described above. A reader should never need to cross-reference
those two systems to reason about either one.

## Signature format

### Detached vs. embedded — decision

**Decision: detached.** Every signed activity is a pair of files:
`<id>.pck` (unmodified Godot export) and `<id>.pck.sig` (the signature
sidecar, format below), always stored, transferred, and imported together.

Reasoning:

- **Format independence.** Godot's `.pck` layout is not ours to own; it
  changes across Godot versions. A detached signature never touches or
  assumes anything about PCK internals — the signer/verifier treat the
  `.pck` as an opaque byte string. An embedded scheme (Godot 4's resource
  pack loader accepts a byte offset into a file — `load_resource_pack`
  takes an `offset` parameter in Godot 4.x, which T1.4 must confirm against
  the exact engine version in use — would let us prefix a header+signature
  ahead of raw, untouched `.pck` bytes without truly "embedding" into the
  format either). Both approaches can avoid parsing Godot's format; the
  detached approach avoids it more simply, with no dependency on a loader
  API detail that could change.
- **Generality.** `covelight-crypto` is meant to be one Ed25519
  implementation reused across the shell, `/tools/sign`, and eventually
  `syncd`-adjacent content transfer. A signature format that just pairs
  "some bytes" with "a signature over those bytes" needs no Godot-specific
  knowledge at all, and works unchanged if the project ever signs something
  that isn't a PCK (a probe report, a device-database export).
- **Simplicity of the security-critical parser.** The sidecar is fixed-size
  and trivial to parse (below) — no variable-length fields, nothing to
  get wrong, in the same spirit as `covelight-syncd`'s fixed-size pre-auth
  frames (CLAUDE.md #12).

**Honest cost, accepted:** two files must travel together. If a copy step
drops the sidecar, the activity fails closed (rejected as unsigned, not
silently loaded) — a functional bug, never a security hole. Every path
that moves a `.pck` (app bundling T1.6, Companion USB import T2.6) must
treat the pair as one logical unit at the transport/storage layer (e.g.
write-then-atomic-rename both, or reject a partial pair outright); that is
an implementation discipline for those tasks, not a cryptographic concern.

**If this is reversed later:** the signature bytes and the algorithm below
don't change — only where they live. Switching to embedded means defining
a container (`[header][sig bytes][raw .pck bytes]`) and using Godot's
byte-offset load path instead of a sidecar file lookup; `covelight-crypto`'s
`sign`/`verify` functions over a byte buffer stay identical either way.

### Sidecar format (`<id>.pck.sig`)

Fixed 76 bytes, no variable-length fields:

```text
offset  size  field
0       4     magic    "CVS1" (ASCII) — format+version identifier.
                        Unrecognized magic → reject. A future format
                        change gets a new magic, not a version field to
                        branch on.
4       8     key_id   first 8 bytes of SHA-256(public_key_bytes).
                        Identification only, not itself a trust boundary —
                        used solely to look up which trusted public key to
                        verify against.
12      64    sig      Ed25519ph signature (RFC 8032 prehashed variant)
                        over SHA-512(pck_file_bytes).
```

**Why Ed25519ph (prehashed), not plain Ed25519 over the raw file:** pure
Ed25519 needs the entire message available to compute the signature (the
algorithm hashes the message as part of nonce and challenge derivation).
Activity `.pck` files can be several MB of audio/art; requiring that much
be buffered whole, on a years-old Android phone or a Pi Zero 2 W-class
device, is an avoidable cost. Ed25519ph signs a fixed 64-byte SHA-512
digest instead, so both signer and verifier compute that digest with a
constant-memory streaming hash and only the 64-byte result touches the
actual signature math. `covelight-crypto` must implement this per RFC 8032
exactly (not a custom prehash), so signer and verifier agree bit-for-bit
regardless of which of the three consumers (`/tools/sign`, shell
GDExtension, later import-path checks) computed which side.

**No time-based key validity.** Trust is purely "is this `key_id` currently
present in the shipped trusted-keys table" — no expiry timestamps, no
valid-from/valid-until windows. Device clocks, especially on air-gapped
Tier 2 devices with no time sync, are not a trustworthy input; a
correctness-critical check must not depend on one.

## Verification flow in the shell

For every `.pck` the shell is about to load — whether bundled with the app
(T1.6) or imported via Companion/USB (T2.6) — before any call into Godot's
own resource-pack loader:

1. Locate `<id>.pck.sig` next to `<id>.pck`. Missing → reject, log for
   parent visibility (per CLAUDE.md #3), do not proceed. No child-visible
   error text.
2. Read the sidecar. Anything other than exactly 76 bytes → reject as
   corrupt/tampered. Do not attempt a partial parse.
3. Parse `magic` (must equal `CVS1`), `key_id`, `sig`. Bad magic → reject.
4. Look up `key_id` in the shell's embedded trusted-keys table. No match →
   reject.
5. Stream `pck_file_bytes` through SHA-512 (constant memory); verify `sig`
   against that digest using the matched public key (Ed25519ph verify).
   Failure → reject.
6. Only on success: proceed to load `<id>.pck` through the normal Godot
   resource-pack path.

Every rejection path is identical in shape: fail closed, no partial load,
no child-visible text, a log entry for the parent. **No build configuration
may skip or short-circuit this flow** — CLAUDE.md #3's "no debug bypass
that could ship" applies to every step above, including test/debug builds.

This ordering is also a defense-in-depth property worth stating plainly:
an attacker who cannot produce a valid signature never gets their bytes as
far as Godot's own PCK parser at all — signing gates access to that parser,
not just the activity's behavior once loaded.

## Project key storage & access control

- Keys are generated offline (`tools/sign keygen`, T0.4) — never inside
  hosted CI, never typed into a CI secret store as plaintext long-term.
- The private key is held encrypted at rest (e.g. an age- or
  GPG-encrypted file) in a maintainer's password manager or equivalent.
  A hardware-backed key (YubiKey or similar with Ed25519 support) is the
  target once the volunteer team can support the workflow; a
  passphrase-encrypted file is the accepted v1 minimum given this is an
  unfunded, volunteer project.
- **Signing runs locally**, on a maintainer's machine, not in CI. This is
  a deliberate departure from common signing-pipeline practice (CI-held
  signing secrets): Covelight has no budget for the operational rigor
  (secret rotation, audit logging, provider trust) that a CI-held private
  key would need to deserve the same confidence as offline custody.
- CI (`build.yml`, T0.4's tests) only ever runs **verification**, using
  public keys — safe to embed in the repo and in CI. CI never sees, needs,
  or handles the private key.
- Public keys are embedded in `covelight-crypto` source (checked into the
  repo, part of the trusted-keys table) and therefore ship with every
  shell/app/OS build — no live fetch, ever.
- Exactly who currently holds signing capability is a short, auditable,
  human-maintained roster (a governance/process detail, not specified
  here) — the requirement this doc places on that roster is: the private
  key must never be committed to the repo, never live unencrypted in a CI
  secret, and never appear in logs.

## Rotation and compromise procedure

**Rotation (planned):**

1. Generate a new keypair offline (`tools/sign keygen`).
2. Add the new public key + `key_id` to the trusted-keys table; ship it in
   the next shell/app/OS release. Old and new keys are now both trusted.
3. Sign all newly published content with the new key.
4. Once enough time has passed for active devices to have picked up the
   release that trusts the new key (bounded by each tier's own update
   cadence — Tier 1 via app/F-Droid update, Tier 2 via a Companion-mediated
   USB update — there is no push mechanism), optionally re-sign the
   existing catalog with the new key.
5. Remove the old public key from the trusted-keys table in a later
   release. Content still signed only with the retired key stops loading
   from that release onward — call this out explicitly in release notes
   so it isn't a surprise.

**Compromise (private key stolen or leaked):**

1. Stop signing anything new with the compromised key immediately.
2. Generate a new keypair; ship its public key in an emergency release as
   fast as each tier's own update channel allows.
3. Remove the compromised `key_id` from the trusted-keys table in that
   same release — this invalidates every `.pck` signed with that key,
   legitimate or forged, the moment a device updates.
4. Re-sign the legitimate catalog with the new key and publish it alongside
   the emergency release, so legitimate content keeps working once the
   compromised key is distrusted.
5. **Honest limitation, stated openly (matches ARCHITECTURE §8's tone):**
   revocation only reaches a device on that device's own next update.
   There is no remote kill-switch — cannot be one, given CLAUDE.md #5/#11.
   A device whose parent never updates it never distrusts the compromised
   key. This is an accepted consequence of the no-telemetry, no-network
   design, not a gap being papered over.

## Non-goals — explicit

- **This is not encryption.** `.pck` files are plaintext on disk, on every
  tier, always. Anyone with access to the file or device can read or copy
  activity content. Signing proves integrity and provenance; it says
  nothing about confidentiality.
- **This is not DRM and makes no licensing claim.** There is no access
  control here — nothing about who may load, copy, or redistribute an
  activity. This is intentional and consistent with the project's
  non-profit, non-monetized ethos (CLAUDE.md #6): DRM-style enforcement
  machinery would contradict the reason this scheme exists.
- **This is not a defense against a compromised device or shell binary.**
  Someone with root, fastboot, or physical access can in principle patch
  the shell to skip verification entirely, replace the embedded
  trusted-keys table, or reflash the OS outright. That is out of scope
  here — Tier 2's read-only, dm-verity-verified root is the relevant
  structural defense for the shell binary's own integrity; Tier 1 has
  Android's ordinary APK signing (a separate scheme) and no stronger
  guarantee, consistent with Tier 1 being policy-based protection, not
  structural (CLAUDE.md #7).
- **This is not a remote revocation system.** No CRL, no OCSP-equivalent,
  no live check of any kind — see the compromise procedure's honest
  limitation above.
- **This does not close the gap between verifying a file and Godot loading
  it.** Godot's `ProjectSettings.load_resource_pack()` takes only a file
  path — there is no in-memory or pre-mount-hook variant, confirmed against
  an open Godot engine proposal requesting exactly that capability
  (`docs/research/godot-pck-gdextension.md`). Verification (T1.4's
  GDExtension) and the engine's own load are therefore two separate file
  opens, not one atomic operation, leaving a Time-of-Check-to-Time-of-Use
  window in principle. Standard file locks are advisory on Linux/Android,
  so this can't be closed by locking either. It doesn't expand this
  document's threat model, though: exploiting it needs write access to the
  exact on-device path between verify and load, which on both tiers
  already requires something outside "not the adversary" above (another
  process in the app's own private storage, or a compromised
  `covelight-syncd`) — not a new class of attacker, just an honestly-named
  edge of an existing one. T1.4 minimizes the window (verify immediately
  followed by load, nothing else scheduled between them) without claiming
  to eliminate it.
