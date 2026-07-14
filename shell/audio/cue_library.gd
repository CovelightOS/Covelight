extends RefCounted
class_name CueLibrary

## T1.7's central cue library. The shell's own chrome (TransitionOverlay,
## HomeTile) looks up sounds by *name* here instead of each owning its own
## ad-hoc tone generator -- this is what makes "placeholder cue set,
## documented as replaceable" (docs/plan/02-phase1-shell.md T1.7) a real,
## single-file swap: drop a real asset at CUE_DIR + "<name>.<ext>" and
## get_cue() picks it up automatically, no calling code changes anywhere.
##
## This is deliberately separate from ActivityAudio.play_placeholder_tone()
## (shell/sdk/audio_cue.gd), which stays as-is: that's an *activity author's*
## ad-hoc prototyping tool for arbitrary hz/duration before real assets
## exist, not a named, swappable cue. Different concern, kept separate on
## purpose (see that file's own doc comment).

## Where a real asset replaces a placeholder tone. Any format Godot's
## importer accepts (.ogg, .wav) works -- get_cue() doesn't care, it just
## asks ResourceLoader whether something is there.
const CUE_DIR := "res://audio/cues/"

## name -> [hz, seconds] fallback placeholder tone, used only until a real
## asset lands at CUE_DIR + name + extension. Every entry here is a distinct
## shell-chrome or home-screen moment that needs *some* sound today --
## calm, short, no two identical, so a contributor's ear can tell them apart
## while replacing them one at a time.
##
## Frequencies chosen a fifth or so apart and kept in a comfortable mid
## register (330-880 Hz) -- audibly distinct without any of them reading as
## an alert or a buzzer (CLAUDE.md #4, "no attention-engineering... audio
## can manipulate as easily as visuals").
const _PLACEHOLDER_TONES := {
	"ui_tap": [660.0, 0.12],             # HomeTile tap acknowledgment
	"ui_hold_preview": [440.0, 0.4],      # HomeTile hold-to-preview (existing T1.5 tone)
	"transition_leave": [330.0, 0.35],    # TransitionOverlay.cover() -- soft E4, "going somewhere"
	"transition_arrive": [440.0, 0.3],    # TransitionOverlay.reveal() -- a step up from leave, "here now"
	"gentle_redirect": [392.0, 0.25],     # generic soft redirect, for shell-level (non-activity) use
}

const _SAMPLE_RATE := 22050

## Returns the named cue's AudioStream -- a real asset if one exists at
## CUE_DIR + name (any importable extension), otherwise a procedurally
## generated placeholder tone. Unknown names fall back to a neutral default
## tone rather than erroring, since a missing/misspelled cue name should
## never be the reason a shell interaction goes silent (T1.7's whole point).
static func get_cue(cue_name: String) -> AudioStream:
	var real := _find_real_asset(cue_name)
	if real != null:
		return real
	var params: Array = _PLACEHOLDER_TONES.get(cue_name, [440.0, 0.3])
	return _make_placeholder_tone(params[0], params[1])

static func _find_real_asset(cue_name: String) -> AudioStream:
	for ext in ["ogg", "wav"]:
		var path := "%s%s.%s" % [CUE_DIR, cue_name, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return null

static func _make_placeholder_tone(hz: float, seconds: float) -> AudioStreamWAV:
	var sample_count := int(_SAMPLE_RATE * seconds)
	var data := PackedByteArray()
	data.resize(sample_count * 2)  # 16-bit mono
	var attack := maxi(1, int(sample_count * 0.15))
	var release := maxi(1, int(sample_count * 0.3))
	for i in sample_count:
		var t := float(i) / _SAMPLE_RATE
		var envelope := 1.0
		if i < attack:
			envelope = float(i) / attack
		elif i > sample_count - release:
			envelope = float(sample_count - i) / release
		var sample := sin(TAU * hz * t) * envelope * 0.4
		data.encode_s16(i * 2, int(clamp(sample, -1.0, 1.0) * 32767.0))
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = _SAMPLE_RATE
	wave.stereo = false
	wave.data = data
	return wave
