extends "res://addons/covelight_sdk/activity_base.gd"

## Minimal working demo of the full activity contract -- copy this whole
## directory to start a new activity (docs/design/activity-sdk.md §2). This
## file exists to prove the mechanical contract works end-to-end (manifest,
## lifecycle, audio, input, safe margins), not to be a polished gameplay
## example -- T1.6's first three real activities are the actual reference
## examples for activity *design*. Two shapes, both `TouchTarget`s, anchored
## outside LayoutConstants.SAFE_MARGIN of every edge:
##
## - TargetShape (green, bottom-right): the "right" answer. Tap it, hear a
##   cue, the activity ends calmly a moment later.
## - DistractorShape (yellow, bottom-left): the "wrong" answer. Tap it,
##   hear a different, gentler cue, and nothing else happens -- no penalty,
##   no state change. The child can still tap TargetShape whenever ready.
##   This is docs/design/activity-sdk.md §8's "no failure states" rule,
##   demonstrated rather than just described.
##
## Both cues here are ActivityAudio.play_placeholder_tone() -- procedural,
## no shipped audio asset, because this template never itself goes through
## activity review as a real activity. A real activity calls
## `_audio.play_cue(preload("res://sounds/your_cue.ogg"))` and
## `_audio.play_gentle_redirect(preload("res://sounds/your_redirect.ogg"))`
## with real recorded/licensed sound instead.

@onready var _audio: ActivityAudio = $ActivityAudio
@onready var _target: TouchTarget = $TargetShape
@onready var _distractor: TouchTarget = $DistractorShape

const END_DELAY_SECONDS := 1.0

func _ready() -> void:
	_target.tapped.connect(_on_target_tapped)
	_distractor.tapped.connect(_on_distractor_tapped)
	report_ready()

func _on_target_tapped() -> void:
	_audio.play_placeholder_tone(660.0, 0.3)
	await get_tree().create_timer(END_DELAY_SECONDS).timeout
	report_finished()

func _on_distractor_tapped() -> void:
	_audio.play_placeholder_tone(220.0, 0.25)
