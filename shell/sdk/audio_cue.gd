extends AudioStreamPlayer
class_name ActivityAudio

## The activity audio helper -- docs/design/activity-sdk.md's audio API.
## All guidance and feedback in an activity is audio (CLAUDE.md #1); this is
## the one Node type an activity should ever play a cue through, so T1.7's
## real central audio bus (ducking, cue library, master-volume persistence)
## can retrofit onto every existing activity by changing this file, not by
## touching activity code (same pattern as transition_overlay.gd's
## cover()/reveal() surviving its own future asset swap).
##
## There is deliberately no text/caption parameter anywhere on this API --
## not "discouraged," simply not a thing this class can do. An activity
## that wants to communicate something to the child has exactly one tool
## here: a sound.

## Placeholder output routing until T1.7 defines real buses (ducking,
## per-activity vs. shell-chrome separation). "Master" is Godot's always-
## present default bus, so this never fails for lack of a bus that doesn't
## exist yet.
const BUS_NAME := "Master"

func _ready() -> void:
	bus = BUS_NAME

## Plays a cue immediately, interrupting whatever this player was doing.
## The generic entry point -- most activity sound (a tap acknowledgment, an
## ambient loop cue, anything) goes through this.
func play_cue(stream: AudioStream) -> void:
	self.stream = stream
	play()

## Semantically the same as play_cue() -- exists so "what do I call when
## the child tapped the wrong thing" has an obvious, correctly-named answer
## in the API itself. docs/guides/activity-review.md's "no failure states"
## check is about which *sound* this plays (never a negative/buzzer cue),
## not about this function existing.
func play_gentle_redirect(stream: AudioStream) -> void:
	play_cue(stream)

## Generates and plays a short procedural sine-wave tone -- for prototyping
## an activity's audio *timing and structure* before real cue assets exist,
## exactly the role transition_overlay.gd's placeholder tone plays for
## shell chrome. Never ships as a "real" cue in a reviewed activity; it's
## intentionally simple, not intentionally reusable DSP, and stays a
## separate ~15 lines here rather than sharing code with
## transition_overlay.gd's copy -- one small duplication is clearer than a
## shared utility neither caller actually needs to vary together.
func play_placeholder_tone(hz: float = 440.0, seconds: float = 0.3) -> void:
	play_cue(_make_placeholder_tone(hz, seconds))

func _make_placeholder_tone(hz: float, seconds: float) -> AudioStreamWAV:
	const SAMPLE_RATE := 22050
	var sample_count := int(SAMPLE_RATE * seconds)
	var data := PackedByteArray()
	data.resize(sample_count * 2)  # 16-bit mono
	var attack := maxi(1, int(sample_count * 0.15))
	var release := maxi(1, int(sample_count * 0.3))
	for i in sample_count:
		var t := float(i) / SAMPLE_RATE
		var envelope := 1.0
		if i < attack:
			envelope = float(i) / attack
		elif i > sample_count - release:
			envelope = float(sample_count - i) / release
		var sample := sin(TAU * hz * t) * envelope * 0.4
		data.encode_s16(i * 2, int(clamp(sample, -1.0, 1.0) * 32767.0))
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = SAMPLE_RATE
	wave.stereo = false
	wave.data = data
	return wave
