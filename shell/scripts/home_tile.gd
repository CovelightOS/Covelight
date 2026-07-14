extends TouchTarget
class_name HomeTile

## T1.5: one activity tile on the home screen. Reuses the SDK's own
## TouchTarget (shell/sdk/touch_target.gd) rather than a bespoke input
## handler -- tap/hold/release semantics, minimum-size enforcement, and
## the dual touch/mouse input path are already correct there; the home
## screen is just another consumer of the SDK's conventions, same as any
## activity (docs/design/activity-sdk.md's own framing).
##
## Interaction, built entirely from TouchTarget's existing signals:
## - tapped   -> launch (emits launch_requested)
## - held     -> audio preview starts, beacon pulses gently
## - released -> preview stops; if it followed a hold, nothing else
##   happens (TouchTarget already suppresses `tapped` after `held` fires,
##   so holding-then-releasing previews without launching, and a separate
##   quick tap is what actually launches).
##
## Every tile is visually identical in size and base shape -- only the
## beacon's accent color varies -- so no tile carries more visual weight
## than another (CLAUDE.md #4: nothing here should manufacture a pull
## toward one activity over another).

signal launch_requested

## Deliberately generous, well above LayoutConstants.MIN_TOUCH_TARGET_SIZE
## -- "large icon tiles" per T1.5's own requirement, not just compliant.
const TILE_SIZE := Vector2(320.0, 320.0)

@export var beacon_color: Color = Color(0.945, 0.706, 0.353)  # warm amber, muted not neon

@onready var _beacon: Panel = $Base/Beacon
@onready var _audio: ActivityAudio = $ActivityAudio

var _pulse_tween: Tween

func _ready() -> void:
	super._ready()
	custom_minimum_size = TILE_SIZE
	var style: StyleBoxFlat = _beacon.get_theme_stylebox("panel").duplicate()
	style.bg_color = beacon_color
	_beacon.add_theme_stylebox_override("panel", style)

	tapped.connect(_on_tapped)
	held.connect(_on_held)
	released.connect(_on_released)

func _on_tapped() -> void:
	launch_requested.emit()

## Placeholder preview cue (ActivityAudio.play_placeholder_tone) -- there is
## no real per-activity preview audio yet, because there is no real
## installed-activity content yet (T1.6). A future SDK addition (a
## preview-cue manifest field, or similar) is what lets a real activity
## supply its own short preview sound without the home screen loading the
## whole PCK just to hold-and-listen; noted here as an open seam, not
## solved by this task.
func _on_held() -> void:
	_audio.play_placeholder_tone(440.0, 0.4)
	_start_pulse()

func _on_released() -> void:
	_audio.stop()
	_stop_pulse()

func _start_pulse() -> void:
	_stop_pulse()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_beacon, "scale", Vector2(1.12, 1.12), 0.5).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(_beacon, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE)

func _stop_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	_beacon.scale = Vector2(1.0, 1.0)
