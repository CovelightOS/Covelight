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

	assert_false(_tree_has_any_text_node(shell), "no Label/RichTextLabel/Button anywhere -- constraint #1, even mid-recovery")

	# The crash itself is expected and deliberate -- this is the proof that
	# it actually happened, and marks it handled so GUT's error tracker
	# doesn't ALSO fail this test for an error the test intentionally caused.
	assert_engine_error("this_method_does_not_exist",
		"the deliberate crash actually fired, proving containment isn't a no-op")

## Recursively checks for any node type that could render text to the
## child. Constraint #1 is "no text, ever" -- this makes that a checkable
## fact about the live tree, not just an assumption about the code.
func _tree_has_any_text_node(node: Node) -> bool:
	if node is Label or node is RichTextLabel or node is Button \
		or node is LineEdit or node is TextEdit or node is OptionButton \
		or node is AcceptDialog:
		return true
	for child in node.get_children():
		if _tree_has_any_text_node(child):
			return true
	return false
