extends "res://addons/covelight_sdk/activity_base.gd"

## Animal Sounds — the tap + audio reference activity (T1.6).
##
## Four animals (placeholder colored shapes; real animal art is a
## contributor lane, not built here). Tap any animal, hear its voice. This
## is pure exploration: there is NO wrong tap. Every tap always plays that
## animal's sound and gives a warm visual pulse — a child cannot lose,
## cannot be redirected, cannot be told "no" (docs/guides/activity-review.md,
## "No failure states").
##
## Ending: once the child has heard all four animals at least once, they've
## explored the whole set, so the activity ends calmly on its own — a soft
## closing tone, then a return home. No score, no "great job", no "play
## again?". This "explore-completion" ending is the honest stopping point
## for a free-play activity: the shell has no child-facing exit button (by
## design — shell/scripts/shell.gd), so the activity itself must decide
## when it's done, and "you've seen everything" is a natural, pressure-free
## trigger. It is neither a timer nor a streak (the review checklist's two
## concerns) — the pace is entirely the child's.
##
## SDK surface exercised: TouchTarget.tapped + ActivityAudio. Nothing in
## this file reaches past the SDK into shell internals.

## Each animal's TouchTarget node name -> the pitch of its voice, in Hz.
## Kept as plain data (not hard-coded into the handler) so adding a fifth
## animal is one entry here plus one scene node — no logic change. The
## four pitches are a pentatonic set (G4 A4 C5 D5): any combination a child
## mashes out is consonant, so random tapping always sounds pleasant.
const ANIMAL_VOICES := {
	"Fox": 392.0,
	"Frog": 440.0,
	"Bird": 523.0,
	"Cat": 587.0,
}

## Soft resolving note played once, at the calm ending.
const CLOSING_HZ := 659.0

@onready var _audio: ActivityAudio = $ActivityAudio
@onready var _grid: Control = $SafeArea/CenterContainer/Grid

## Names of animals heard so far. A Dictionary used as a set (values are
## always true) — GDScript has no built-in Set type, and a Dictionary
## lookup is the clear, boring way to answer "have they heard this one?".
var _heard: Dictionary = {}
var _ending := false

func _ready() -> void:
	for animal_name in ANIMAL_VOICES:
		var animal: TouchTarget = _grid.get_node(animal_name)
		# bind() passes the animal's name and node to the handler, so one
		# handler serves all four without needing a separate function each.
		animal.tapped.connect(_on_animal_tapped.bind(animal_name, animal))
	report_ready()

func _on_animal_tapped(animal_name: String, animal: Control) -> void:
	# Once the calm ending has begun, ignore further taps so the wind-down
	# isn't interrupted — not a failure state, just letting the ending land.
	if _ending:
		return
	_audio.play_placeholder_tone(ANIMAL_VOICES[animal_name], 0.35)
	_pulse(animal)
	_heard[animal_name] = true
	if _heard.size() == ANIMAL_VOICES.size():
		_finish_calmly()

## A brief brighten-and-settle — the warm acknowledgment that a tap landed.
## Uses `modulate` (a color multiplier) rather than `scale` so it needs no
## pivot setup and looks right regardless of the animal's size or position.
func _pulse(node: CanvasItem) -> void:
	var tween := create_tween()
	tween.tween_property(node, "modulate", Color(1.3, 1.3, 1.3), 0.10)
	tween.tween_property(node, "modulate", Color.WHITE, 0.20)

func _finish_calmly() -> void:
	_ending = true
	await get_tree().create_timer(0.6).timeout
	_audio.play_placeholder_tone(CLOSING_HZ, 0.5)
	await get_tree().create_timer(0.9).timeout
	report_finished()
