extends GutTest

## T1.5 acceptance (docs/plan/02-phase1-shell.md): zero rendered text,
## every interactive element >= the SDK's minimum touch-target size, safe
## margin respected. Also covers the tap/hold wiring itself: tap launches,
## hold previews without launching, release-after-hold doesn't launch
## either. TouchTarget's own tap/hold/release discrimination (SDK-level
## infra, shell/sdk/touch_target.gd) is treated as already correct here --
## these tests emit its public signals directly rather than simulating raw
## input events, so they're testing "does the home screen wire those
## signals up correctly," which is this task's actual job.
##
## Layout is checked via offset_*/custom_minimum_size, not measured pixel
## position -- headless mode has no real window (shell/README.md's own
## documented limitation), so those are the only layout facts meaningful
## without one. Visual reflow across the three T1.1 ratios still needs a
## real window; see the PR for that check.

const HOME_SCENE := preload("res://scenes/home.tscn")

var home: Control

func before_each() -> void:
	home = HOME_SCENE.instantiate()

func after_each() -> void:
	if is_instance_valid(home) and not home.is_inside_tree():
		home.free()

func _first_tile() -> HomeTile:
	var grid: GridContainer = home.get_node("SafeArea/CenterContainer/TileGrid")
	assert_true(grid.get_child_count() > 0, "at least one activity tile must exist")
	return grid.get_child(0)

func test_no_text_capable_nodes() -> void:
	add_child_autofree(home)
	assert_true(TextAudit.find_text_nodes(home).is_empty(),
		"constraint #1: zero text-capable nodes on the home screen")

func test_safe_area_respects_safe_margin() -> void:
	add_child_autofree(home)
	var safe_area: Control = home.get_node("SafeArea")
	assert_eq(safe_area.offset_left, LayoutConstants.SAFE_MARGIN)
	assert_eq(safe_area.offset_top, LayoutConstants.SAFE_MARGIN)
	assert_eq(safe_area.offset_right, -LayoutConstants.SAFE_MARGIN)
	assert_eq(safe_area.offset_bottom, -LayoutConstants.SAFE_MARGIN)

func test_tiles_meet_minimum_touch_target_size() -> void:
	add_child_autofree(home)
	await get_tree().process_frame
	var grid: GridContainer = home.get_node("SafeArea/CenterContainer/TileGrid")
	for tile in grid.get_children():
		assert_true(tile.size.x >= LayoutConstants.MIN_TOUCH_TARGET_SIZE, "%s width" % tile.name)
		assert_true(tile.size.y >= LayoutConstants.MIN_TOUCH_TARGET_SIZE, "%s height" % tile.name)

func test_tap_launches() -> void:
	add_child_autofree(home)
	watch_signals(home)
	var tile := _first_tile()
	tile.tapped.emit()
	assert_signal_emitted(home, "activity_requested", "a quick tap must launch the activity")

func test_hold_previews_without_launching() -> void:
	add_child_autofree(home)
	watch_signals(home)
	var tile := _first_tile()
	var audio: AudioStreamPlayer = tile.get_node("ActivityAudio")

	tile.held.emit()
	assert_true(audio.playing, "holding a tile plays a preview cue")
	assert_signal_not_emitted(home, "activity_requested", "holding must not launch by itself")

func test_release_after_hold_does_not_launch() -> void:
	add_child_autofree(home)
	watch_signals(home)
	var tile := _first_tile()
	var audio: AudioStreamPlayer = tile.get_node("ActivityAudio")

	tile.held.emit()
	tile.released.emit()
	assert_false(audio.playing, "releasing stops the preview cue")
	assert_signal_not_emitted(home, "activity_requested",
		"TouchTarget suppresses tapped after held fires -- releasing from a hold must not launch")
