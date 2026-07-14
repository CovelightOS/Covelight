extends RefCounted
class_name PckLoader

## T1.4: verifies a `.pck`'s Ed25519 signature (`shell/rust/pck_verify`,
## `docs/design/signing.md`) BEFORE ever calling
## `ProjectSettings.load_resource_pack()` — CLAUDE.md #3, "unsigned content
## never loads," made structural: `load_and_verify()` is the only path
## `shell.gd` uses to load a `.pck`, and there is no branch inside it that
## reaches `load_resource_pack` without `_verify` having returned `true`
## first.
##
## `_verify` is an injectable `Callable`, defaulting to the real
## `PckVerifier.verify_pck` (the GDExtension wrapping `covelight-crypto`).
## This is dependency injection for testing, not a bypass: normal
## construction (`PckLoader.new()`, what `shell.gd` actually does) always
## uses the real cryptographic check. The override parameter exists only
## so a test can ask "does the loader correctly gate load_resource_pack on
## a verification result" without needing a real project signing key
## embedded in the build to produce a genuine `true` — `covelight-crypto`'s
## own trusted-keys table ships empty until a real key exists (a
## governance decision, out of scope here — see
## `covelight_crypto::TRUSTED_KEY_BYTES`'s doc comment). No test, override,
## or build configuration changes what `PckVerifier.verify_pck` itself
## accepts; only which function a *test's own* `PckLoader` instance calls.
var _verify: Callable = PckVerifier.verify_pck

func _init(verify_override: Callable = Callable()) -> void:
	if verify_override.is_valid():
		_verify = verify_override

## Verifies `pck_path`, and only on success, loads it and returns the
## manifest-declared entry scene, ready to instantiate. Returns `null` on
## any failure — missing/tampered signature, load failure, or an invalid
## manifest all look identical to the caller, which is correct: the child
## must never see a difference between "that failed" and anything else
## (constraint #1). The *reason* is logged (parent-visible), never
## surfaced past this function's boolean-shaped return.
func load_and_verify(pck_path: String) -> PackedScene:
	if not _verify.call(pck_path):
		return null
	if not ProjectSettings.load_resource_pack(pck_path):
		push_error("PckLoader: load_resource_pack failed for a *verified* pck at %s" % pck_path)
		return null

	var manifest := ActivityManifest.load_from_file("res://manifest.cfg")
	if not manifest.is_valid():
		push_error("PckLoader: verified pck at %s has an invalid manifest: %s" % [pck_path, manifest.error])
		return null

	var entry: Resource = load(manifest.entry_scene)
	if not (entry is PackedScene):
		push_error("PckLoader: entry_scene %s (declared by %s) is not a PackedScene" % [manifest.entry_scene, pck_path])
		return null
	return entry
