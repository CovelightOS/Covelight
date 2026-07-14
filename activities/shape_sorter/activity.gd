extends "res://addons/covelight_sdk/activity_base.gd"

## Shape Sorter — the drag-and-drop reference activity (T1.6).
##
## Three colored shapes rest in a row along the bottom; three matching
## colored slots wait in a row along the top. Drag a shape onto its
## matching slot and it settles in with a warm sound. Drag it anywhere
## else — a wrong slot, empty space — and it drifts gently back to where it
## started with a soft, unbothered sound. There is no buzz, no "no", no
## penalty (docs/guides/activity-review.md, "No failure states"): a wrong
## drop simply doesn't stick, and the child can try again immediately.
## When all three shapes are home, the activity ends calmly.
##
## SDK surface exercised: Draggable (drag_started / drag_moved / drag_ended,
## which multi-touch color_mixing also builds on). Colors are the only
## matching cue — shape i belongs in slot i, both the same color — so it's
## fully textless.
##
## Positions are computed in code (see _layout) rather than set with scene
## anchors. Dragging has to move a node freely and spring it back, which
## fights anchor-driven layout; pinning every shape and slot to explicit
## top-left `position` values keeps that logic simple and predictable — a
## contributor reads `shape.position = ...` and knows exactly what moves.
## The shell is portrait-locked and an activity never resizes mid-run, so
## computing positions once from the real SafeArea size is enough.

## One entry per shape/slot pair. The color is the whole game: shape i and
## slot i share PAIRS[i], and that match is the only thing the child reads.
const PAIRS: Array[Color] = [
	Color(0.906, 0.451, 0.271),  # warm orange
	Color(0.361, 0.573, 0.741),  # calm blue
	Color(0.945, 0.769, 0.353),  # soft yellow
]

const SHAPE_SIZE := Vector2(240, 240)
const HALF := Vector2(120, 120)

@onready var _audio: ActivityAudio = $ActivityAudio
@onready var _safe: Control = $SafeArea

var _shapes: Array[Draggable] = []
var _slots: Array[Panel] = []
var _rest: Dictionary = {}          # Draggable -> its resting position
var _placed: Dictionary = {}        # Draggable -> true once settled in its slot
var _grab_offset: Dictionary = {}   # Draggable -> finger-to-shape offset during a drag

func _ready() -> void:
	for i in PAIRS.size():
		_shapes.append(_safe.get_node("Shape%d" % i))
		_slots.append(_safe.get_node("Slot%d" % i))
		_paint(i)
	# SafeArea's size isn't resolved until the first layout pass, so wait
	# one frame before computing positions from it.
	await get_tree().process_frame
	_layout()
	for i in _shapes.size():
		var shape := _shapes[i]
		shape.drag_started.connect(_on_drag_started.bind(shape))
		shape.drag_moved.connect(_on_drag_moved.bind(shape))
		shape.drag_ended.connect(_on_drag_ended.bind(shape))
	report_ready()

## Tints shape i and slot i with their shared color. The shape is a solid
## fill; the slot is a faint, outlined version of the same color — clearly
## "the home for this shape" without any text.
func _paint(i: int) -> void:
	var color := PAIRS[i]
	(_shapes[i].get_node("Shape") as ColorRect).color = color
	var style: StyleBoxFlat = _slots[i].get_theme_stylebox("panel").duplicate()
	style.bg_color = Color(color, 0.2)
	style.border_color = color
	_slots[i].add_theme_stylebox_override("panel", style)

func _layout() -> void:
	var w := _safe.size.x
	var h := _safe.size.y
	# Three columns centred across the width; slots high, shapes resting low.
	var col_fraction: Array[float] = [0.2, 0.5, 0.8]
	for i in _shapes.size():
		var cx := w * col_fraction[i]
		_slots[i].size = SHAPE_SIZE
		_slots[i].position = Vector2(cx, h * 0.16) - HALF
		_shapes[i].size = SHAPE_SIZE
		_shapes[i].position = Vector2(cx, h * 0.78) - HALF
		_rest[_shapes[i]] = _shapes[i].position

func _shape_center(shape: Draggable) -> Vector2:
	return shape.global_position + HALF

func _on_drag_started(_index: int, _pos: Vector2, shape: Draggable) -> void:
	if _placed.has(shape):
		return
	shape.move_to_front()  # a picked-up shape draws over the others
	_grab_offset[shape] = shape.global_position - _pos

func _on_drag_moved(_index: int, pos: Vector2, shape: Draggable) -> void:
	if _placed.has(shape):
		return
	shape.global_position = pos + _grab_offset.get(shape, Vector2.ZERO)

func _on_drag_ended(_index: int, _pos: Vector2, shape: Draggable) -> void:
	if _placed.has(shape):
		return
	var i := _shapes.find(shape)
	var slot := _slots[i]
	if slot.get_global_rect().has_point(_shape_center(shape)):
		_settle_into_slot(shape, slot)
	else:
		_drift_home(shape)

func _settle_into_slot(shape: Draggable, slot: Panel) -> void:
	_placed[shape] = true
	var tween := create_tween()
	tween.tween_property(shape, "global_position", slot.global_position, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_audio.play_placeholder_tone(523.0, 0.3)  # warm settling note
	if _placed.size() == _shapes.size():
		_finish_calmly()

## A wrong (or incomplete) drop: the shape simply eases back to its resting
## spot with a soft, low, unremarkable tone — reads as "not quite, that's
## okay", never a rejection buzzer. This uses play_placeholder_tone (the
## SDK's placeholder path, same as the template's distractor) rather than
## play_gentle_redirect: the latter takes a real recorded AudioStream,
## which this activity doesn't have yet. The "gentle redirect" intent lives
## in the tone choice (low, brief, warm), not the function name.
func _drift_home(shape: Draggable) -> void:
	var tween := create_tween()
	tween.tween_property(shape, "position", _rest[shape], 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_audio.play_placeholder_tone(294.0, 0.22)

func _finish_calmly() -> void:
	await get_tree().create_timer(0.7).timeout
	_audio.play_placeholder_tone(659.0, 0.5)
	await get_tree().create_timer(0.9).timeout
	report_finished()
