extends GutTest

## T1.4 acceptance (docs/plan/02-phase1-shell.md): valid signed PCK loads;
## unsigned PCK does not; tampered PCK does not. Real Ed25519 signing via
## /tools/sign (T0.4) invoked as a subprocess -- the shell/GDExtension only
## ever verifies (docs/design/signing.md), so a genuine .sig sidecar for
## these tests has to come from the one place this project actually signs
## anything, not a hand-built fixture that merely resembles the format.

var _sign_bin: String
var _work_dir: String

func before_all() -> void:
	_sign_bin = _find_or_build_sign_binary()

func before_each() -> void:
	_work_dir = "user://pck_loader_test_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(_work_dir)

func after_each() -> void:
	var dir := DirAccess.open(_work_dir)
	if dir:
		for file_name in dir.get_files():
			dir.remove(file_name)
	DirAccess.remove_absolute(_work_dir)

func _repo_root() -> String:
	return ProjectSettings.globalize_path("res://").path_join("..").simplify_path()

func _find_or_build_sign_binary() -> String:
	var root := _repo_root()
	var release := root.path_join("tools/target/release/sign")
	var debug := root.path_join("tools/target/debug/sign")
	if FileAccess.file_exists(release):
		return release
	if FileAccess.file_exists(debug):
		return debug
	var output := []
	OS.execute("cargo", ["build", "--manifest-path", root.path_join("tools/Cargo.toml"), "-p", "sign"], output, true)
	gut.p("built sign binary locally: %s" % [output])
	assert_true(FileAccess.file_exists(debug), "sign binary should exist after building it")
	return debug

func _run_sign(args: PackedStringArray) -> Array:
	var output := []
	var exit_code := OS.execute(_sign_bin, args, output, true)
	return [exit_code, output]

## Signs `pck_path` (a real OS path) with a freshly generated keypair and
## returns that keypair's public key as a hex string -- the caller passes
## it to PckVerifier.verify_pck_with_key() as the explicit trust root,
## since covelight-crypto's *compiled-in* trusted-keys table ships empty
## until a real project key exists (see shell/rust/pck_verify/src/lib.rs's
## own doc comment on why that method exists at all).
func _sign_with_fresh_key(pck_path: String) -> String:
	var key_prefix := pck_path + ".signer"
	var keygen := _run_sign(["keygen", "--out", key_prefix])
	assert_eq(keygen[0], 0, "sign keygen should succeed: %s" % [keygen[1]])

	var sign_result := _run_sign(["sign", pck_path, "--key", key_prefix + ".key"])
	assert_eq(sign_result[0], 0, "sign sign should succeed: %s" % [sign_result[1]])

	var pub_text := FileAccess.get_file_as_string(key_prefix + ".pub")
	return pub_text.strip_edges()

func test_valid_signed_pck_is_accepted_and_loader_proceeds_to_load() -> void:
	var pck_path := ProjectSettings.globalize_path(_work_dir.path_join("valid.pck"))
	var f := FileAccess.open(pck_path, FileAccess.WRITE)
	f.store_string("pretend pck bytes for the valid-signature test")
	f.close()

	var public_key_hex := _sign_with_fresh_key(pck_path)

	# Real Ed25519 verification against the real signature this test just
	# produced -- proves the crypto genuinely accepts a validly signed
	# file, not just that a test double says so.
	assert_true(PckVerifier.verify_pck_with_key(pck_path, public_key_hex),
		"a validly signed pck must verify against its own signer's key")

	# PckLoader's wiring: on a true verification result, it must actually
	# proceed to load_resource_pack, not short-circuit. Injected here
	# because load_resource_pack needs real PCK-format bytes to succeed
	# (this fixture is plain text, not a real pack) -- this half of the
	# test is about the *gating logic*, not the crypto (which the assert
	# above and the "rejected" tests below already cover for real). See
	# pck_loader.gd's own doc comment for why this isn't a verification
	# bypass: production PckLoader.new() never takes this path.
	#
	# Observed via push_error: load_and_verify's own "load_resource_pack
	# failed for a *verified* pck" message only fires on the path that
	# actually attempted the load, which our non-pack fixture bytes make
	# fail -- distinguishing "gate opened, then a real load attempt failed"
	# from "gate stayed shut" without needing real pack bytes.
	var always_true := func(_path: String) -> bool: return true
	var loader := PckLoader.new(always_true)
	var result := loader.load_and_verify(pck_path)
	assert_null(result, "load_resource_pack legitimately fails on non-pack fixture bytes")
	assert_push_error("load_resource_pack failed",
		"PckLoader must have actually attempted the load when verify() returned true")

func test_unsigned_pck_is_rejected() -> void:
	var pck_path := ProjectSettings.globalize_path(_work_dir.path_join("unsigned.pck"))
	var f := FileAccess.open(pck_path, FileAccess.WRITE)
	f.store_string("no signature anywhere near this file")
	f.close()

	assert_false(PckVerifier.verify_pck(pck_path), "an unsigned pck must be rejected")
	assert_engine_error("missing/unreadable .sig sidecar",
		"PckVerifier logs the reason (parent-visible) for the direct call above")

	var loader := PckLoader.new()
	var result := loader.load_and_verify(pck_path)
	assert_null(result, "PckLoader must not return a scene for an unsigned pck")
	assert_engine_error("missing/unreadable .sig sidecar",
		"PckVerifier logs the reason (parent-visible) for the loader's own call too")

func test_tampered_pck_is_rejected() -> void:
	var pck_path := ProjectSettings.globalize_path(_work_dir.path_join("tampered.pck"))
	var f := FileAccess.open(pck_path, FileAccess.WRITE)
	f.store_string("original content that gets signed")
	f.close()

	var public_key_hex := _sign_with_fresh_key(pck_path)

	# Confirm it verifies BEFORE tampering, so the rejection below is
	# actually caused by the tamper, not by some other mistake in the
	# fixture (e.g. a bad key) that would make this test pass for the
	# wrong reason.
	assert_true(PckVerifier.verify_pck_with_key(pck_path, public_key_hex),
		"sanity check: the fixture verifies before tampering")

	var tampered := FileAccess.open(pck_path, FileAccess.WRITE)
	tampered.store_string("tampered content, different from what was signed")
	tampered.close()

	assert_false(PckVerifier.verify_pck_with_key(pck_path, public_key_hex),
		"tampering with the pck after signing must invalidate the signature")
	assert_engine_error("signature verification failed",
		"PckVerifier logs the tamper-detection reason")

	# The default PckLoader (real PckVerifier.verify_pck) rejects this for
	# a *different* reason -- the compiled-in trusted-keys table is empty,
	# so it never even reaches signature math, matching the earlier
	# missing-sidecar test's fail-closed-by-default point.
	var loader := PckLoader.new()
	var result := loader.load_and_verify(pck_path)
	assert_null(result, "PckLoader must not return a scene for a tampered pck")
	assert_engine_error("is not trusted",
		"the default (empty) trusted-keys table rejects even a well-formed signature")

func test_missing_sidecar_is_rejected_by_the_real_default_verifier() -> void:
	# No override -- exercises the actual production PckVerifier.verify_pck,
	# whose compiled-in trusted-keys table is empty by design, so this also
	# happens to prove the fail-closed default: nothing verifies against it
	# yet, for anyone, which is the deliberately safe starting state.
	var pck_path := ProjectSettings.globalize_path(_work_dir.path_join("no_sidecar.pck"))
	var f := FileAccess.open(pck_path, FileAccess.WRITE)
	f.store_string("bytes with no .sig file next to them")
	f.close()

	var loader := PckLoader.new()
	var result := loader.load_and_verify(pck_path)
	assert_null(result, "PckLoader must not return a scene when no sidecar exists at all")
	assert_engine_error("missing/unreadable .sig sidecar",
		"PckVerifier logs the reason (parent-visible), never shown to the child")
