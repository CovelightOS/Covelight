extends GutTest

## T1.7 acceptance (docs/plan/02-phase1-shell.md): the central audio bus
## (Chrome/Content routing, ducking, master-volume persistence), and "every
## shell interaction produces audio feedback" for the two shell-level
## surfaces that aren't an activity's own responsibility -- HomeTile taps
## and TransitionOverlay's cover()/reveal(). AudioBus is a real autoload
## (project.godot's [autoload]), so it's already booted and its buses
## already exist by the time any test runs, same as it would be for the
## shell in production -- nothing here mocks it.

const HOME_TILE_SCENE := preload("res://scenes/home_tile.tscn")
const TRANSITION_SCENE := preload("res://scenes/transition_overlay.tscn")

var _original_volume: float

func before_each() -> void:
	_original_volume = AudioBus.get_master_volume()

## Every test that touches master volume restores it -- AudioBus is a
## singleton shared across the whole test run (and persists to real disk),
## so leaving it changed would leak into whichever test runs next, or into
## a developer's next real run of the shell.
func after_each() -> void:
	AudioBus.set_master_volume(_original_volume)

func test_chrome_and_content_buses_exist() -> void:
	assert_ne(AudioServer.get_bus_index(AudioBus.CHROME_BUS), -1, "Chrome bus created at boot")
	assert_ne(AudioServer.get_bus_index(AudioBus.CONTENT_BUS), -1, "Content bus created at boot")

func test_chrome_and_content_route_to_master() -> void:
	var chrome_idx := AudioServer.get_bus_index(AudioBus.CHROME_BUS)
	var content_idx := AudioServer.get_bus_index(AudioBus.CONTENT_BUS)
	assert_eq(AudioServer.get_bus_send(chrome_idx), "Master")
	assert_eq(AudioServer.get_bus_send(content_idx), "Master")

func test_set_master_volume_applies_to_master_bus_and_clamps() -> void:
	AudioBus.set_master_volume(0.4)
	var idx := AudioServer.get_bus_index("Master")
	assert_almost_eq(AudioServer.get_bus_volume_linear(idx), 0.4, 0.001)
	assert_almost_eq(AudioBus.get_master_volume(), 0.4, 0.001)

	AudioBus.set_master_volume(5.0)
	assert_almost_eq(AudioBus.get_master_volume(), 1.0, 0.001, "clamped to 1.0, never louder than unity")

	AudioBus.set_master_volume(-3.0)
	assert_almost_eq(AudioBus.get_master_volume(), 0.0, 0.001, "clamped to 0.0, never negative")

## Master volume "must survive app restarts" (T1.7 design notes). This
## can't restart the whole engine mid-test, so it checks the actual
## mechanism a restart depends on instead: the value AudioBus just set is
## really on disk at the path a fresh AudioBus._load_master_volume() reads
## from, not just held in memory.
func test_master_volume_persists_to_disk() -> void:
	AudioBus.set_master_volume(0.65)
	var config := ConfigFile.new()
	var err := config.load("user://settings/audio.cfg")
	assert_eq(err, OK, "settings file was written to user://")
	assert_almost_eq(config.get_value("audio", "master_volume", -1.0), 0.65, 0.001)

func test_duck_content_lowers_then_restores_volume() -> void:
	var idx := AudioServer.get_bus_index(AudioBus.CONTENT_BUS)
	var normal_db := AudioServer.get_bus_volume_db(idx)

	AudioBus.duck_content(0.2)
	await get_tree().create_timer(0.1).timeout
	assert_lt(AudioServer.get_bus_volume_db(idx), normal_db, "content bus is quieter mid-duck")

	await get_tree().create_timer(0.2).timeout
	assert_almost_eq(AudioServer.get_bus_volume_db(idx), normal_db, 0.5,
		"content bus returns to its normal level once the duck window ends")

func test_cue_library_never_returns_null_even_for_unknown_names() -> void:
	assert_not_null(CueLibrary.get_cue("ui_tap"), "a known cue resolves")
	assert_not_null(CueLibrary.get_cue("totally_unknown_cue_name"),
		"an unknown/misspelled cue name still returns something playable -- never a reason for a silent interaction")

## T1.7: no silent taps anywhere. Before this task, a tap only became
## audible once the resulting screen transition played its tone -- so a
## tap that ends in Shell.start_activity_from_pck() silently rejecting an
## unsigned/tampered PCK (constraint #1: no error shown) produced no sound
## at all. HomeTile now plays its own tap cue immediately, independent of
## whatever the tap goes on to trigger.
func test_home_tile_tap_plays_audio_immediately() -> void:
	var tile: HomeTile = HOME_TILE_SCENE.instantiate()
	add_child_autofree(tile)
	var audio: AudioStreamPlayer = tile.get_node("ActivityAudio")

	tile.tapped.emit()
	assert_true(audio.playing, "tapping a tile produces audio feedback before anything else happens")

func test_transition_cover_and_reveal_each_play_audio() -> void:
	var overlay: TransitionOverlay = TRANSITION_SCENE.instantiate()
	add_child_autofree(overlay)
	var player: AudioStreamPlayer = overlay.get_node("AudioStreamPlayer")

	await overlay.cover()
	assert_true(player.playing, "cover() plays a 'leaving' cue -- still audible once its own fade finishes")

	player.stop()
	await overlay.reveal()
	assert_true(player.playing, "reveal() plays an 'arriving' cue, distinct from cover() -- not silence in one direction")
