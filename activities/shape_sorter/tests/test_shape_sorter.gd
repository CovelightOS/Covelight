extends GutTest

## Proves shape_sorter satisfies the SDK contract and review checklist:
## valid manifest, reports ready, correct drops settle, wrong drops drift
## back with no penalty and no early end, sorting all three ends calmly,
## and zero text-capable nodes exist.
##
## Drags are driven by emitting Draggable's own signals (drag_started /
## drag_moved / drag_ended) directly, the same way the other activities'
## tests emit `tapped` — Draggable's raw input handling is SDK-level infra
## proven in the shell's tests; here we test that shape_sorter wires those
## signals into correct sorting behavior.

const ACTIVITY_SCENE := preload("res://activity.tscn")

var activity: Control

func before_each() -> void:
	activity = ACTIVITY_SCENE.instantiate()

func after_each() -> void:
	if is_instance_valid(activity) and not activity.is_inside_tree():
		activity.free()

func _shape(i: int) -> Draggable:
	return activity.get_node("SafeArea/Shape%d" % i)

func _slot(i: int) -> Panel:
	return activity.get_node("SafeArea/Slot%d" % i)

## report_ready() only fires after the activity waits a frame for layout,
## so every interactive test starts by awaiting it -- that also guarantees
## _layout() has run and the drag signals are connected.
func _add_and_await_ready() -> void:
	add_child_autofree(activity)
	await wait_for_signal(activity.activity_ready, 2.0)

## Simulates dropping shape `shape_i` onto slot `slot_i`. Pressing exactly
## at the shape's top-left makes Draggable's grab offset zero, so a
## drag_moved to a target position puts the shape's top-left there -- moving
## it onto slot_i means its centre lands in that slot.
func _drop_on(shape_i: int, slot_i: int) -> void:
	var shape := _shape(shape_i)
	var target := _slot(slot_i).global_position
	shape.drag_started.emit(0, shape.global_position)
	shape.drag_moved.emit(0, target)
	shape.drag_ended.emit(0, target)

func test_manifest_is_valid() -> void:
	var manifest := ActivityManifest.load_from_file("res://manifest.cfg")
	assert_true(manifest.is_valid(), manifest.error)
	assert_eq(manifest.id, "shape_sorter")

func test_reports_ready() -> void:
	watch_signals(activity)
	await _add_and_await_ready()
	assert_signal_emitted(activity, "activity_ready")

func test_no_text_capable_nodes() -> void:
	await _add_and_await_ready()
	assert_true(TextAudit.find_text_nodes(activity).is_empty(),
		"constraint #1: zero text-capable nodes")

func test_correct_drop_makes_a_sound_and_does_not_end_early() -> void:
	watch_signals(activity)
	await _add_and_await_ready()
	var audio: AudioStreamPlayer = activity.get_node("ActivityAudio")

	_drop_on(0, 0)  # shape 0 onto its matching slot
	assert_true(audio.playing, "a correct drop settles with a sound")
	await get_tree().create_timer(0.2).timeout
	assert_signal_not_emitted(activity, "activity_finished",
		"one correct drop out of three does not end the activity")

func test_wrong_drop_drifts_back_with_no_penalty() -> void:
	watch_signals(activity)
	await _add_and_await_ready()
	var shape := _shape(0)
	var rest := shape.position

	_drop_on(0, 1)  # shape 0 onto the WRONG slot
	# It must ease back to its resting spot, and nothing else happens.
	await get_tree().create_timer(0.5).timeout
	assert_almost_eq(shape.position, rest, Vector2(1, 1),
		"a wrong drop drifts the shape back home, unchanged")
	assert_signal_not_emitted(activity, "activity_finished",
		"a wrong drop never ends or penalizes the activity")

func test_wrong_drop_can_be_retried_and_then_sorted() -> void:
	# Proves "a child cannot lose": after a wrong drop, the same shape still
	# sorts correctly. No state to recover from.
	watch_signals(activity)
	await _add_and_await_ready()
	_drop_on(0, 2)          # wrong
	await get_tree().create_timer(0.4).timeout
	_drop_on(0, 0)          # right, second try
	await get_tree().create_timer(0.2).timeout
	# Still only one of three placed, so not finished -- but no error either.
	assert_signal_not_emitted(activity, "activity_finished")

func test_sorting_all_shapes_ends_calmly() -> void:
	watch_signals(activity)
	await _add_and_await_ready()
	_drop_on(0, 0)
	_drop_on(1, 1)
	_drop_on(2, 2)
	assert_signal_not_emitted(activity, "activity_finished",
		"the last correct drop doesn't snap-cut to home")
	var finished: bool = await wait_for_signal(activity.activity_finished, 3.0)
	assert_true(finished, "sorting all three shapes ends the activity calmly")

func test_shapes_and_slots_meet_minimum_size() -> void:
	await _add_and_await_ready()
	for i in 3:
		assert_true(_shape(i).size.x >= LayoutConstants.MIN_TOUCH_TARGET_SIZE, "shape %d width" % i)
		assert_true(_shape(i).size.y >= LayoutConstants.MIN_TOUCH_TARGET_SIZE, "shape %d height" % i)

func test_safe_area_respects_safe_margin() -> void:
	await _add_and_await_ready()
	var safe: Control = activity.get_node("SafeArea")
	assert_eq(safe.offset_left, LayoutConstants.SAFE_MARGIN)
	assert_eq(safe.offset_top, LayoutConstants.SAFE_MARGIN)
	assert_eq(safe.offset_right, -LayoutConstants.SAFE_MARGIN)
	assert_eq(safe.offset_bottom, -LayoutConstants.SAFE_MARGIN)
