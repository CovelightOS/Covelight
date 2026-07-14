extends GutTest

## Covers T1.2's acceptance: every state transition, plus the
## deliberately-crashing activity proving crash containment (shell
## survives, returns home, no text shown).

const SHELL_SCENE := preload("res://scenes/shell.tscn")
const STUB_ACTIVITY := preload("res://scenes/activities/stub_activity.tscn")
const CRASHING_ACTIVITY := preload("res://scenes/activities/crashing_activity.tscn")

const TEST_LOAD_TIMEOUT := 0.2  # real default is 5.0; tests don't wait that long
const SETTLE_TIMEOUT := 3.0     # generous ceiling for any single awaited transition

var shell: Shell

func before_each() -> void:
	shell = SHELL_SCENE.instantiate()
	shell.load_timeout_seconds = TEST_LOAD_TIMEOUT
	add_child_autofree(shell)

func test_boots_to_home() -> void:
	assert_eq(shell.state, Shell.State.BOOT, "starts in BOOT")
	var reached_home: bool = await wait_for_signal(shell.state_changed, SETTLE_TIMEOUT)
	assert_true(reached_home, "state_changed fired during boot")
	assert_eq(shell.state, Shell.State.HOME, "boot settles into HOME")

func test_home_to_activity_running() -> void:
	await wait_for_signal(shell.state_changed, SETTLE_TIMEOUT)  # settle into HOME
	assert_eq(shell.state, Shell.State.HOME)

	shell.start_activity(STUB_ACTIVITY)
	assert_eq(shell.state, Shell.State.ACTIVITY_RUNNING,
		"state flips synchronously, before the cover-transition await")

func test_activity_finishing_returns_to_home() -> void:
	await wait_for_signal(shell.state_changed, SETTLE_TIMEOUT)  # HOME

	shell.start_activity(STUB_ACTIVITY)
	assert_eq(shell.state, Shell.State.ACTIVITY_RUNNING)

	# stub_activity finishes itself after ~1.5s of real time.
	var finished: bool = await wait_for_signal(shell.state_changed, SETTLE_TIMEOUT)
	assert_true(finished, "state_changed fired for return-to-home")
	assert_eq(shell.state, Shell.State.RETURN_TO_HOME)

	var back_home: bool = await wait_for_signal(shell.state_changed, SETTLE_TIMEOUT)
	assert_true(back_home, "state_changed fired settling back into HOME")
	assert_eq(shell.state, Shell.State.HOME, "back home after the activity finished itself")

## Regression test for a latent bug shipped in T1.2's shell.tscn and only
## surfaced by real-device tapping during T1.5: ActivityContainer, an empty
## full-screen Control layered on top of HomeContainer, had mouse_filter =
## PASS. PASS still makes a control the picked target -- it only propagates
## unhandled input to its own PARENT, never falls through to a sibling
## beneath it -- so it silently ate every click meant for the home tiles,
## and nothing launched. Every other test drives the shell by calling
## start_activity()/emitting signals directly, so none of them ever routed
## a real InputEvent through the viewport's GUI picking, which is the only
## thing that exercises mouse_filter. This one does: a genuine synthetic
## click at the tile's location must reach the tile and launch. Both
## overlay containers are now mouse_filter = IGNORE (transparent to
## picking; their live child still receives input normally).
func test_real_click_on_home_tile_launches_activity() -> void:
	await wait_for_signal(shell.state_changed, SETTLE_TIMEOUT)  # settle into HOME
	assert_eq(shell.state, Shell.State.HOME)

	var tile: Control = shell.find_child("HomeTile", true, false)
	assert_not_null(tile, "home screen has a tile to tap")

	# Canvas-space coords + in_local_coords=true: the position is already in
	# the viewport's own space, so no window/stretch transform is applied
	# (the shell has no real window under a headless test). This is the
	# real GUI-picking path -- if any overlay intercepts the pick, tapped
	# never fires and state never leaves HOME.
	# start_activity() flips state to ACTIVITY_RUNNING synchronously, inside
	# the tapped-signal chain, before its own first await -- so the release
	# event that completes the tap leaves the shell already out of HOME by
	# the time push_input returns. Assert "no longer HOME" rather than a
	# specific target state: with the tiny 0.2s test watchdog the activity
	# may already be racing on to RETURN_TO_HOME, which is irrelevant here.
	# The only thing this test proves -- and the thing the bug broke -- is
	# that the pick reached the tile at all.
	var center: Vector2 = tile.get_global_rect().get_center()
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = center
		get_viewport().push_input(ev, true)
		await get_tree().process_frame

	assert_ne(shell.state, Shell.State.HOME,
		"a real click on the tile left HOME -- the GUI pick reached the tile and launched")

func test_crashing_activity_is_contained() -> void:
	await wait_for_signal(shell.state_changed, SETTLE_TIMEOUT)  # HOME
	assert_eq(shell.state, Shell.State.HOME)

	shell.start_activity(CRASHING_ACTIVITY)
	assert_eq(shell.state, Shell.State.ACTIVITY_RUNNING)

	# The crashing activity throws in _ready() and never reports ready --
	# only the watchdog timeout recovers it. This is the whole point of
	# the test: prove the shell survives and comes back on its own.
	var recovered: bool = await wait_for_signal(shell.state_changed, SETTLE_TIMEOUT)
	assert_true(recovered, "watchdog fired and state_changed to RETURN_TO_HOME")
	assert_eq(shell.state, Shell.State.RETURN_TO_HOME)

	var back_home: bool = await wait_for_signal(shell.state_changed, SETTLE_TIMEOUT)
	assert_true(back_home, "state_changed fired settling back into HOME")
	assert_eq(shell.state, Shell.State.HOME,
		"shell recovered to HOME after the crash, unassisted")

	assert_true(TextAudit.find_text_nodes(shell).is_empty(), "no text-capable node anywhere -- constraint #1, even mid-recovery")

	# The crash itself is expected and deliberate -- this is the proof that
	# it actually happened, and marks it handled so GUT's error tracker
	# doesn't ALSO fail this test for an error the test intentionally caused.
	assert_engine_error("this_method_does_not_exist",
		"the deliberate crash actually fired, proving containment isn't a no-op")
