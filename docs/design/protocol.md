# Sync Protocol Specification (Tier 2)

> **Status: PLANNED — Phase 4** (`docs/plan/04-phase3-to-6-skeletons.md`). Spec precedes code; once implemented, the Rust `covelight-syncd` implementation is the source of truth for the wire format and this doc must track it.

## Will cover
- Transport: USB CDC-ACM framing
- Handshake: Ed25519 challenge-response; fixed-size pre-auth frames; NOTHING parsed before auth succeeds (CLAUDE.md #12)
- Session messages: content transfer, removal, progress export, log export
- Error handling & versioning
- Fuzzing strategy per parser
