extends GutTest

## Proves animal_sounds satisfies the SDK contract and the review checklist:
## valid manifest, reports ready, every tap plays sound with no wrong
## answers, exploring all four animals ends the activity calmly, and zero
## text-capable nodes exist. Mirrors the template's test shape.

const ACTIVITY_SCENE := preload("res://activity.tscn")
const ANIMALS := ["Fox", "Frog", "Bird", "Cat"]

var activity: Control

func before_each() -> void:
	activity = ACTIVITY_SCENE.instantiate()

func after_each() -> void:
	if is_instance_valid(activity) and not activity.is_inside_tree():
		activity.free()

func _animal(name: String) -> TouchTarget:
	return activity.get_node("SafeArea/CenterContainer/Grid/%s" % name)

func test_manifest_is_valid() -> void:
	var manifest := ActivityManifest.load_from_file("res://manifest.cfg")
	assert_true(manifest.is_valid(), manifest.error)
	assert_eq(manifest.id, "animal_sounds")
	assert_false(manifest.declared_layouts.is_empty())

func test_reports_ready_on_load() -> void:
	watch_signals(activity)
	add_child_autofree(activity)
	assert_signal_emitted(activity, "activity_ready", "report_ready() fires from _ready()")

func test_no_text_capable_nodes() -> void:
	add_child_autofree(activity)
	assert_true(TextAudit.find_text_nodes(activity).is_empty(),
		"constraint #1: zero text-capable nodes")

func test_every_animal_plays_a_sound() -> void:
	add_child_autofree(activity)
	var audio: AudioStreamPlayer = activity.get_node("ActivityAudio")
	for name in ANIMALS:
		_animal(name).tapped.emit()
		assert_true(audio.playing, "%s makes a sound when tapped" % name)

func test_no_wrong_answer_no_early_finish() -> void:
	# Tapping the same animal repeatedly (or any single animal) is never
	# "wrong" and never ends the activity on its own before all are heard.
	watch_signals(activity)
	add_child_autofree(activity)
	for i in 5:
		_animal("Fox").tapped.emit()
	await get_tree().create_timer(0.2).timeout
	assert_signal_not_emitted(activity, "activity_finished",
		"hammering one animal never ends the activity or penalizes anything")

func test_exploring_all_animals_ends_calmly() -> void:
	watch_signals(activity)
	add_child_autofree(activity)
	for name in ANIMALS:
		_animal(name).tapped.emit()
	# The ending is deliberately delayed (a calm wind-down), not instant.
	assert_signal_not_emitted(activity, "activity_finished",
		"the last animal doesn't snap-cut to home")
	var finished: bool = await wait_for_signal(activity.activity_finished, 3.0)
	assert_true(finished, "hearing all four animals ends the activity calmly")

func test_touch_targets_meet_minimum_size() -> void:
	add_child_autofree(activity)
	await get_tree().process_frame
	for name in ANIMALS:
		var t := _animal(name)
		assert_true(t.size.x >= LayoutConstants.MIN_TOUCH_TARGET_SIZE, "%s width" % name)
		assert_true(t.size.y >= LayoutConstants.MIN_TOUCH_TARGET_SIZE, "%s height" % name)

func test_safe_area_respects_safe_margin() -> void:
	add_child_autofree(activity)
	var safe: Control = activity.get_node("SafeArea")
	assert_eq(safe.offset_left, LayoutConstants.SAFE_MARGIN)
	assert_eq(safe.offset_top, LayoutConstants.SAFE_MARGIN)
	assert_eq(safe.offset_right, -LayoutConstants.SAFE_MARGIN)
	assert_eq(safe.offset_bottom, -LayoutConstants.SAFE_MARGIN)
