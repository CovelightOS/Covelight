extends TouchTarget
class_name Draggable

## A draggable touch target -- docs/design/activity-sdk.md's input API,
## the drag/drop primitive T1.6's shape-sorter activity builds on.
## Extends TouchTarget (tap/hold + minimum-size enforcement still apply)
## and adds drag tracking, keyed per finger by InputEventScreenTouch/
## InputEventScreenDrag's own `index` -- so several Draggables can each be
## mid-drag under different fingers at once (multi-touch, T1.6's color-
## mixing activity) without any extra bookkeeping on the activity's part.
##
## Deliberately listens in `_input()`, not `_gui_input()`: Control's
## `_gui_input()` only receives events while the pointer is over that
## Control's own rect, so a drag that carries a finger outside where it
## started would silently stop being reported the moment it crosses the
## boundary -- exactly the case a real drag-and-drop needs to keep working.
## `_input()` fires tree-wide for every touch/mouse event regardless of
## position (it runs before Godot's own GUI hit-testing), so this tracks a
## drag correctly for its whole path once it has started inside this
## target's rect.
##
## Honest limitation: `_input()` isn't gated by overlap/z-order the way GUI
## hit-testing is, so two overlapping Draggables both starting a drag from
## the same initial touch point is unhandled here. Not a concern given
## LayoutConstants.SAFE_MARGIN-spaced layouts are the norm, but a real
## constraint if an activity ever wants tightly stacked draggables.

signal drag_started(index: int, position: Vector2)
signal drag_moved(index: int, position: Vector2)
signal drag_ended(index: int, position: Vector2)

## Sentinel index for the desktop-dev mouse pointer, which has no touch
## index of its own -- kept distinct from any real touch index (>= 0).
const MOUSE_INDEX := -1

var _active_drags: Dictionary = {}  # index(int) -> Vector2 last position

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_press_release(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_handle_move(event.index, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_press_release(MOUSE_INDEX, event.position, event.pressed)
	elif event is InputEventMouseMotion:
		_handle_move(MOUSE_INDEX, event.position)

func _handle_press_release(index: int, position: Vector2, pressed: bool) -> void:
	if pressed:
		if is_visible_in_tree() and get_global_rect().has_point(position):
			_active_drags[index] = position
			drag_started.emit(index, position)
	elif _active_drags.has(index):
		_active_drags.erase(index)
		drag_ended.emit(index, position)

func _handle_move(index: int, position: Vector2) -> void:
	if _active_drags.has(index):
		_active_drags[index] = position
		drag_moved.emit(index, position)
