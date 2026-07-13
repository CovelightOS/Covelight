extends CanvasLayer
class_name TransitionOverlay

## Placeholder audio+animation for every shell transition (boot, entering
## and leaving an activity). A fade to/from black plus a soft, procedurally
## generated tone -- no external audio asset, no text, ever (constraint #1).
## Explicitly a placeholder: T1.7 builds the real cue library and audio bus;
## the cover()/reveal() interface is what should survive that swap
## unchanged, not this tone-generation code.

const FADE_SECONDS := 0.25
const TONE_HZ := 330.0          # a soft E4, not a harsh chirp
const TONE_SECONDS := 0.35
const TONE_SAMPLE_RATE := 22050

@onready var _fade: ColorRect = $Fade
@onready var _player: AudioStreamPlayer = $AudioStreamPlayer

func _ready() -> void:
	_fade.color = Color.BLACK
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player.stream = _make_placeholder_tone()

## Fades to opaque while playing the placeholder tone. Callers swap
## whatever's underneath while fully covered, then call reveal(). Blocks
## input for the whole cover-through-reveal window so a curious tap during
## the transition can't land on a half-swapped scene.
func cover() -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_player.play()
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 1.0, FADE_SECONDS)
	await tween.finished

func reveal() -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 0.0, FADE_SECONDS)
	await tween.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _make_placeholder_tone() -> AudioStreamWAV:
	var sample_count := int(TONE_SAMPLE_RATE * TONE_SECONDS)
	var data := PackedByteArray()
	data.resize(sample_count * 2)  # 16-bit mono
	var attack := maxi(1, int(sample_count * 0.15))
	var release := maxi(1, int(sample_count * 0.3))
	for i in sample_count:
		var t := float(i) / TONE_SAMPLE_RATE
		var envelope := 1.0
		if i < attack:
			envelope = float(i) / attack
		elif i > sample_count - release:
			envelope = float(sample_count - i) / release
		var sample := sin(TAU * TONE_HZ * t) * envelope * 0.4
		data.encode_s16(i * 2, int(clamp(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = TONE_SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
