extends GutTest

## Proves color_mixing satisfies the SDK contract and review checklist:
## valid manifest, reports ready, a single drop colors the bowl, two drops
## blend to something new (with a sound), a drop dragged off the bowl stops
## contributing, discovering all three blends ends calmly, and zero
## text-capable nodes exist. Drags are driven by emitting Draggable's
## signals directly (see shape_sorter's test for the same rationale).

const ACTIVITY_SCENE := preload("res://activity.tscn")
const DROP_HALF := Vector2(110, 110)

var activity: Control

func before_each() -> void:
	activity = ACTIVITY_SCENE.instantiate()

func after_each() -> void:
	if is_instance_valid(activity) and not activity.is_inside_tree():
		activity.free()

func _drop(i: int) -> Draggable:
	return activity.get_node("SafeArea/Drop%d" % i)

func _bowl() -> Panel:
	return activity.get_node("SafeArea/Bowl")

func _add_and_await_ready() -> void:
	add_child_autofree(activity)
	await wait_for_signal(activity.activity_ready, 2.0)

## Drags drop i so its centre sits on the bowl centre (pressing at the
## drop's top-left makes Draggable's grab offset zero, so the moved-to
## position becomes the drop's new top-left).
func _put_on_bowl(i: int) -> void:
	var drop := _drop(i)
	var target := _bowl().get_global_rect().get_center() - DROP_HALF
	drop.drag_started.emit(0, drop.global_position)
	drop.drag_moved.emit(0, target)
	drop.drag_ended.emit(0, target)

## Drags drop i far away from the bowl (its resting area, low and to the side).
func _put_aside(i: int) -> void:
	var drop := _drop(i)
	var target := Vector2(0, 0)
	drop.drag_started.emit(0, drop.global_position)
	drop.drag_moved.emit(0, target)
	drop.drag_ended.emit(0, target)

func test_manifest_is_valid() -> void:
	var manifest := ActivityManifest.load_from_file("res://manifest.cfg")
	assert_true(manifest.is_valid(), manifest.error)
	assert_eq(manifest.id, "color_mixing")

func test_reports_ready() -> void:
	watch_signals(activity)
	await _add_and_await_ready()
	assert_signal_emitted(activity, "activity_ready")

func test_no_text_capable_nodes() -> void:
	await _add_and_await_ready()
	assert_true(TextAudit.find_text_nodes(activity).is_empty(),
		"constraint #1: zero text-capable nodes")

func test_single_drop_colors_the_bowl() -> void:
	await _add_and_await_ready()
	_put_on_bowl(0)
	assert_eq(_bowl().self_modulate, activity.PRIMARIES[0],
		"one drop on the bowl paints the bowl that drop's color")

func test_two_drops_blend_and_do_not_end_early() -> void:
	watch_signals(activity)
	await _add_and_await_ready()
	var audio: AudioStreamPlayer = activity.get_node("ActivityAudio")
	_put_on_bowl(0)
	_put_on_bowl(1)
	var blended: Color = _bowl().self_modulate
	assert_ne(blended, activity.PRIMARIES[0], "the blend is not just red")
	assert_ne(blended, activity.PRIMARIES[1], "the blend is not just blue")
	assert_true(audio.playing, "discovering a new blend plays a soft sound")
	await get_tree().create_timer(0.2).timeout
	assert_signal_not_emitted(activity, "activity_finished",
		"one blend of three does not end the activity")

func test_dragging_a_drop_off_the_bowl_stops_its_contribution() -> void:
	await _add_and_await_ready()
	_put_on_bowl(0)
	assert_eq(_bowl().self_modulate, activity.PRIMARIES[0])
	_put_aside(0)
	assert_eq(_bowl().self_modulate, activity.EMPTY_BOWL,
		"a drop pulled off the bowl no longer colors it -- nothing is 'wrong', it just stops")

func test_discovering_all_blends_ends_calmly() -> void:
	watch_signals(activity)
	await _add_and_await_ready()
	# Putting all three drops on the bowl forms all three pairs at once.
	_put_on_bowl(0)
	_put_on_bowl(1)
	_put_on_bowl(2)
	assert_signal_not_emitted(activity, "activity_finished",
		"the final discovery doesn't snap-cut to home")
	var finished: bool = await wait_for_signal(activity.activity_finished, 3.0)
	assert_true(finished, "discovering all three blends ends the activity calmly")

func test_drops_meet_minimum_size() -> void:
	await _add_and_await_ready()
	for i in 3:
		assert_true(_drop(i).size.x >= LayoutConstants.MIN_TOUCH_TARGET_SIZE, "drop %d width" % i)
		assert_true(_drop(i).size.y >= LayoutConstants.MIN_TOUCH_TARGET_SIZE, "drop %d height" % i)

func test_safe_area_respects_safe_margin() -> void:
	await _add_and_await_ready()
	var safe: Control = activity.get_node("SafeArea")
	assert_eq(safe.offset_left, LayoutConstants.SAFE_MARGIN)
	assert_eq(safe.offset_right, -LayoutConstants.SAFE_MARGIN)
