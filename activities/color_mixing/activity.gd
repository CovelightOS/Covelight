extends "res://addons/covelight_sdk/activity_base.gd"

## Color Mixing — the multi-touch + visual-feedback reference activity (T1.6).
##
## Three color drops rest below a large central bowl. Drag a drop onto the
## bowl and the bowl takes on that color. Drag a second drop onto it and the
## bowl blends the two — red and blue make a purple, and so on — updating
## live as the child moves the drops. Because a drop only colors the bowl
## while it overlaps it, the child can either drop colors in one at a time
## OR hold two at once with two fingers: the bowl reflects whatever is on it
## right now. That simultaneous two-finger case is the multi-touch surface —
## Draggable tracks each finger independently by its own index, so two drops
## can be mid-drag at the same time with no extra work here.
##
## There are no wrong moves: any color on the bowl is a valid, pretty
## result, and a drop dragged off the bowl just stops contributing. Once the
## child has discovered all three two-color blends, they've explored the
## palette, and the activity ends calmly (same "explore-completion" ending
## as animal_sounds — a natural stopping point, not a score or a timer).
##
## SDK surface exercised: Draggable used multi-touch (several drops draggable
## at once), plus live visual feedback (the bowl re-colors every frame a
## drop moves). Nothing here reaches past the SDK.

## The three primary drops. Index i is both the drop's node suffix and its
## color. The blends of any two of these are the three "discoveries" that
## complete the activity.
const PRIMARIES: Array[Color] = [
	Color(0.878, 0.325, 0.310),  # red
	Color(0.310, 0.510, 0.780),  # blue
	Color(0.945, 0.808, 0.353),  # yellow
]

## Bowl color when nothing is on it — a calm empty stone.
const EMPTY_BOWL := Color(0.82, 0.80, 0.75)

const DROP_SIZE := Vector2(220, 220)
const DROP_HALF := Vector2(110, 110)

@onready var _audio: ActivityAudio = $ActivityAudio
@onready var _safe: Control = $SafeArea
@onready var _bowl: Panel = $SafeArea/Bowl

var _drops: Array[Draggable] = []
var _rest: Dictionary = {}          # Draggable -> resting position
var _grab_offset: Dictionary = {}   # Draggable -> finger-to-drop offset
## Each two-color blend discovered, keyed "i-j" (i < j). Once all three
## pairs are here, the palette is fully explored.
var _discovered: Dictionary = {}
var _ending := false

func _ready() -> void:
	for i in PRIMARIES.size():
		var drop: Draggable = _safe.get_node("Drop%d" % i)
		_drops.append(drop)
		(drop.get_node("Fill") as ColorRect).color = PRIMARIES[i]
	await get_tree().process_frame  # let SafeArea size resolve before layout
	_layout()
	for drop in _drops:
		drop.drag_started.connect(_on_drag_started.bind(drop))
		drop.drag_moved.connect(_on_drag_moved.bind(drop))
		drop.drag_ended.connect(_on_drag_ended.bind(drop))
	_refresh_bowl()
	report_ready()

func _layout() -> void:
	var w := _safe.size.x
	var h := _safe.size.y
	# Bowl centred in the upper-middle; drops resting in a row along the low.
	var bowl_size := Vector2(minf(w, h) * 0.5, minf(w, h) * 0.5)
	_bowl.size = bowl_size
	_bowl.position = Vector2(w * 0.5, h * 0.38) - bowl_size * 0.5
	var col_fraction: Array[float] = [0.22, 0.5, 0.78]
	for i in _drops.size():
		_drops[i].size = DROP_SIZE
		_drops[i].position = Vector2(w * col_fraction[i], h * 0.82) - DROP_HALF
		_rest[_drops[i]] = _drops[i].position

func _drop_center(drop: Draggable) -> Vector2:
	return drop.global_position + DROP_HALF

func _on_drag_started(_index: int, _pos: Vector2, drop: Draggable) -> void:
	drop.move_to_front()
	_grab_offset[drop] = drop.global_position - _pos

func _on_drag_moved(_index: int, pos: Vector2, drop: Draggable) -> void:
	drop.global_position = pos + _grab_offset.get(drop, Vector2.ZERO)
	_refresh_bowl()

func _on_drag_ended(_index: int, _pos: Vector2, drop: Draggable) -> void:
	# A drop simply stays where it's let go. If that's off the bowl, it
	# stops contributing; if it's on the bowl, it keeps coloring it. Either
	# way there's nothing to "get wrong".
	_refresh_bowl()

## Recomputes the bowl color from whichever drops currently overlap it, and
## notices any newly-formed two-color blend.
func _refresh_bowl() -> void:
	if _ending:
		return
	var on: Array[int] = []
	for i in _drops.size():
		if _bowl.get_global_rect().has_point(_drop_center(_drops[i])):
			on.append(i)
	_bowl.self_modulate = _blend(on)
	_note_discoveries(on)

## Averages the primaries currently on the bowl. Averaging (not additive or
## subtractive light math) is the boring, predictable choice: two colors
## always give the same middle color, so a child sees a consistent result —
## clarity over color-theory cleverness.
func _blend(on: Array[int]) -> Color:
	if on.is_empty():
		return EMPTY_BOWL
	var r := 0.0
	var g := 0.0
	var b := 0.0
	for i in on:
		r += PRIMARIES[i].r
		g += PRIMARIES[i].g
		b += PRIMARIES[i].b
	var n := float(on.size())
	return Color(r / n, g / n, b / n)

## Credits every two-color pair present on the bowl right now. Dropping all
## three at once credits all three pairs — a child who dumps everything in
## discovers the whole palette, which is fine. Each newly-seen pair gets a
## soft pleasant tone; discovering all three ends the activity.
func _note_discoveries(on: Array[int]) -> void:
	if on.size() < 2:
		return
	var found_new := false
	for a in on.size():
		for b in range(a + 1, on.size()):
			var key := "%d-%d" % [on[a], on[b]]
			if not _discovered.has(key):
				_discovered[key] = true
				found_new = true
	if found_new:
		_audio.play_placeholder_tone(523.0, 0.3)
		if _discovered.size() == 3:  # all three pairs of three primaries
			_finish_calmly()

func _finish_calmly() -> void:
	_ending = true
	await get_tree().create_timer(0.8).timeout
	_audio.play_placeholder_tone(659.0, 0.5)
	await get_tree().create_timer(0.9).timeout
	report_finished()
