extends GutTest

## Proves the template satisfies docs/design/activity-sdk.md's contract:
## the manifest parses and validates, the lifecycle fires correctly, the
## "no failure states" rule actually holds (a wrong tap doesn't end or
## penalize anything), no text-capable node exists anywhere in the scene,
## and both touch targets meet the minimum size and safe-margin rules.
## This is T1.3's acceptance evidence for "a template activity builds and
## runs in the shell" -- it proves the *contract*, not the real
## signed-PCK-loading path (T1.4, not yet built -- see docs/design/
## activity-sdk.md §10).

const ACTIVITY_SCENE := preload("res://activity.tscn")

var activity: Control

func before_each() -> void:
	activity = ACTIVITY_SCENE.instantiate()

## Tests that never add `activity` to the tree (e.g. test_manifest_is_valid,
## which doesn't need a live instance) would otherwise leak it as an
## orphan -- add_child_autofree() only manages freeing for instances it
## actually saw added.
func after_each() -> void:
	if is_instance_valid(activity) and not activity.is_inside_tree():
		activity.free()

func test_manifest_is_valid() -> void:
	var manifest := ActivityManifest.load_from_file("res://manifest.cfg")
	assert_true(manifest.is_valid(), manifest.error)
	assert_eq(manifest.id, "_template")
	assert_false(manifest.declared_layouts.is_empty(), "declared_layouts is mandatory and non-empty")

## Uses GUT's own signal watcher rather than a hand-rolled bool flag set
## from a lambda: GDScript lambdas capture outer local variables by value,
## not by reference, so `var x = false; s.connect(func(): x = true)` never
## actually updates the outer `x` -- a real gotcha this test suite hit
## first-hand before being rewritten this way.
func test_reports_ready_on_load() -> void:
	watch_signals(activity)
	add_child_autofree(activity)
	assert_signal_emitted(activity, "activity_ready", "report_ready() fires from _ready(), synchronously")

func test_target_tap_ends_activity_calmly() -> void:
	watch_signals(activity)
	add_child_autofree(activity)

	var target: TouchTarget = activity.get_node("TargetShape")
	target.tapped.emit()
	assert_signal_not_emitted(activity, "activity_finished", "doesn't end instantly -- a calm delay, not a snap cut")

	var fired: bool = await wait_for_signal(activity.activity_finished, 3.0)
	assert_true(fired, "activity_finished fired within the calm delay window")

func test_distractor_tap_has_no_failure_state() -> void:
	watch_signals(activity)
	add_child_autofree(activity)

	var distractor: TouchTarget = activity.get_node("DistractorShape")
	distractor.tapped.emit()
	await get_tree().create_timer(0.2).timeout
	assert_signal_not_emitted(activity, "activity_finished", "the 'wrong' shape never ends or penalizes the activity")

func test_no_text_capable_nodes() -> void:
	add_child_autofree(activity)
	assert_true(TextAudit.find_text_nodes(activity).is_empty(),
		"constraint #1: zero text-capable nodes anywhere in the activity")

func test_touch_targets_meet_minimum_size() -> void:
	add_child_autofree(activity)
	await get_tree().process_frame  # let anchors/offsets resolve into real size
	for node_name in ["TargetShape", "DistractorShape"]:
		var target: Control = activity.get_node(node_name)
		assert_true(target.size.x >= LayoutConstants.MIN_TOUCH_TARGET_SIZE,
			"%s width >= MIN_TOUCH_TARGET_SIZE" % node_name)
		assert_true(target.size.y >= LayoutConstants.MIN_TOUCH_TARGET_SIZE,
			"%s height >= MIN_TOUCH_TARGET_SIZE" % node_name)

## Checked via each Control's own offset_* properties, not measured screen
## distance -- those are meaningful regardless of a real window existing,
## unlike pixel-position checks (shell/README.md's own note: headless mode
## has no real window to measure against).
func test_touch_targets_respect_safe_margin() -> void:
	add_child_autofree(activity)
	var target: Control = activity.get_node("TargetShape")
	var distractor: Control = activity.get_node("DistractorShape")
	assert_true(absf(target.offset_right) >= LayoutConstants.SAFE_MARGIN, "TargetShape right inset")
	assert_true(absf(target.offset_bottom) >= LayoutConstants.SAFE_MARGIN, "TargetShape bottom inset")
	assert_true(absf(distractor.offset_left) >= LayoutConstants.SAFE_MARGIN, "DistractorShape left inset")
	assert_true(absf(distractor.offset_bottom) >= LayoutConstants.SAFE_MARGIN, "DistractorShape bottom inset")
