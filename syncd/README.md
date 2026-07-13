# /syncd

Tier 2: `covelight-syncd`, the Rust daemon behind the sole untrusted-input
boundary in the project. USB CDC-ACM gadget; Ed25519 challenge-response;
nothing is parsed before authentication succeeds (CLAUDE.md #12). Runs as
the unprivileged `sync` user.

**Tier:** tier2

**Status:** not started — see `docs/plan/04-phase3-to-6-skeletons.md`
(Phase 4, protocol spec + implementation; `docs/design/protocol.md` is the
spec stub).
