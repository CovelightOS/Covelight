extends Node

## T1.7's central audio bus manager, autoloaded as "AudioBus"
## (project.godot's [autoload] section) so bus creation happens once, at
## engine boot, before any scene's own _ready() tries to route an
## AudioStreamPlayer into a bus by name (docs/research/godot-audio.md
## finding 1: a bus should exist before something sends into it).
##
## Two buses, both routed to the engine's own default "Master":
## - CHROME_BUS  -- shell-level UI/transition cues (TransitionOverlay)
## - CONTENT_BUS -- activity + home-tile audio (every ActivityAudio node)
##
## Ducking rule: while a chrome cue plays, Content briefly quiets so the
## chrome cue reads clearly over whatever the child was just listening to,
## then Content fades back to its normal level -- a fixed, gentle
## fade-hold-fade, never a hard cut (docs/research/godot-audio.md finding 4
## explains why this is a plain bus-volume tween and not
## AudioEffectCompressor sidechaining).
##
## Master-volume persistence: set_master_volume()/get_master_volume() are
## the only two entry points a future parent-menu control (T2.3) needs.
## Nothing in /shell's child-reachable scenes calls them -- there is no
## volume slider anywhere a child can reach, by design (CLAUDE.md #1 in
## spirit: a volume control is not itself text, but it's an adult-facing
## setting, not part of the textless child experience).

const CHROME_BUS := "Chrome"
const CONTENT_BUS := "Content"

const DUCK_AMOUNT_DB := -10.0
const DUCK_FADE_SECONDS := 0.15

const _SETTINGS_PATH := "user://settings/audio.cfg"
const _SETTINGS_DIR := "user://settings"
const _DEFAULT_MASTER_VOLUME := 1.0

var _master_volume: float = _DEFAULT_MASTER_VOLUME
var _duck_tween: Tween

func _ready() -> void:
	_ensure_bus(CHROME_BUS)
	_ensure_bus(CONTENT_BUS)
	_load_master_volume()

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")

## Ducks CONTENT_BUS for `seconds` total (fade down, hold, fade back up),
## called by TransitionOverlay around a chrome cue. Safe to call again
## before a previous duck finishes -- it kills and restarts the tween from
## the bus's *current* volume rather than stacking fades.
func duck_content(seconds: float) -> void:
	var idx := AudioServer.get_bus_index(CONTENT_BUS)
	if idx == -1:
		return
	if _duck_tween:
		_duck_tween.kill()
	var normal_db := AudioServer.get_bus_volume_db(idx)
	var ducked_db := normal_db + DUCK_AMOUNT_DB
	var hold_seconds := maxf(0.0, seconds - 2.0 * DUCK_FADE_SECONDS)
	_duck_tween = create_tween()
	_duck_tween.tween_method(_set_content_volume_db, normal_db, ducked_db, DUCK_FADE_SECONDS)
	if hold_seconds > 0.0:
		_duck_tween.tween_interval(hold_seconds)
	_duck_tween.tween_method(_set_content_volume_db, ducked_db, normal_db, DUCK_FADE_SECONDS)

func _set_content_volume_db(db: float) -> void:
	var idx := AudioServer.get_bus_index(CONTENT_BUS)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, db)

## Parent-menu-only API (T2.3) -- see the file-level doc comment. Clamped
## to [0, 1] and persisted immediately so it survives an app restart, not
## just the current session.
func set_master_volume(linear: float) -> void:
	_master_volume = clampf(linear, 0.0, 1.0)
	_apply_master_volume()
	_save_master_volume()

func get_master_volume() -> float:
	return _master_volume

func _apply_master_volume() -> void:
	var idx := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_linear(idx, _master_volume)

func _load_master_volume() -> void:
	var config := ConfigFile.new()
	var err := config.load(_SETTINGS_PATH)
	if err == OK:
		_master_volume = config.get_value("audio", "master_volume", _DEFAULT_MASTER_VOLUME)
	_apply_master_volume()

func _save_master_volume() -> void:
	DirAccess.make_dir_recursive_absolute(_SETTINGS_DIR)
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", _master_volume)
	config.save(_SETTINGS_PATH)
