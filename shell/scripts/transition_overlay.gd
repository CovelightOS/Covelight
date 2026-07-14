extends CanvasLayer
class_name TransitionOverlay

## Audio+animation for every shell transition (boot, entering and leaving
## an activity). A fade to/from black plus a cue looked up from
## CueLibrary (shell/audio/cue_library.gd) -- no text, ever (constraint #1).
## cover() and reveal() play distinct cues ("leaving" / "arriving") so the
## two directions of every transition are each their own audio event, not
## silence in one direction and a tone in the other (T1.7: "every shell
## interaction has an audio response"). The cover()/reveal() interface is
## what T1.7 kept unchanged from the pre-T1.7 placeholder-tone version --
## only what's inside changed.

const FADE_SECONDS := 0.25

@onready var _fade: ColorRect = $Fade
@onready var _player: AudioStreamPlayer = $AudioStreamPlayer

func _ready() -> void:
	_fade.color = Color.BLACK
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player.bus = AudioBus.CHROME_BUS

## Fades to opaque while playing the "leaving" cue, ducking Content so the
## chrome cue reads clearly. Callers swap whatever's underneath while fully
## covered, then call reveal(). Blocks input for the whole cover-through-
## reveal window so a curious tap during the transition can't land on a
## half-swapped scene.
func cover() -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_play_chrome_cue("transition_leave")
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 1.0, FADE_SECONDS)
	await tween.finished

func reveal() -> void:
	_play_chrome_cue("transition_arrive")
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 0.0, FADE_SECONDS)
	await tween.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _play_chrome_cue(cue_name: String) -> void:
	_player.stream = CueLibrary.get_cue(cue_name)
	_player.play()
	AudioBus.duck_content(FADE_SECONDS)
