extends Control
class_name TouchTarget

## The base touch primitive -- docs/design/activity-sdk.md's input API.
## A tappable/holdable area sized for small hands by default. Handles both
## InputEventScreenTouch (device) and InputEventMouseButton (desktop dev,
## same dual-path pattern home.gd already uses) so an activity behaves
## identically on a real device and in a developer's desktop test window.
##
## Enforces LayoutConstants.MIN_TOUCH_TARGET_SIZE two ways: it raises its
## own custom_minimum_size to that floor (so a TouchTarget in a container
## that sizes children by their minimum gets the safe size for free), and
## it checks its *actual* on-screen size one frame after entering the tree
## and warns if it's still too small -- most shapes in this project are
## sized by anchors/offsets, not by custom_minimum_size, so custom_minimum_size
## alone can't catch "this shape is visibly 80x80" the way checking real
## size does. This is "enforced by the API where possible"
## (docs/plan/02-phase1-shell.md T1.3) -- it cannot stop a parent container
## or explicit offsets from making this smaller than the floor, which is
## why docs/guides/activity-review.md's checklist still asks a reviewer to
## check actual on-screen size, not just trust this warning fired or didn't.

signal tapped
signal held
signal released

const HOLD_SECONDS := 0.5

var _is_pressed := false
var _held_fired := false
var _hold_timer: Timer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var min_size := LayoutConstants.MIN_TOUCH_TARGET_SIZE
	if custom_minimum_size.x < min_size and custom_minimum_size.y < min_size:
		custom_minimum_size = Vector2(min_size, min_size)
	call_deferred("_check_actual_size")
	_hold_timer = Timer.new()
	_hold_timer.one_shot = true
	_hold_timer.wait_time = HOLD_SECONDS
	_hold_timer.timeout.connect(_on_hold_timeout)
	add_child(_hold_timer)

## Deferred so anchors/offsets have resolved into a real `size` by the time
## this runs -- `size` right at `_ready()` can still be stale for a Control
## laid out by anchors rather than a container.
func _check_actual_size() -> void:
	var min_size := LayoutConstants.MIN_TOUCH_TARGET_SIZE
	if size.x < min_size or size.y < min_size:
		push_warning("TouchTarget '%s' is only %s -- smaller than LayoutConstants.MIN_TOUCH_TARGET_SIZE (%s). Small hands need the full target size; note why in review if this is deliberate." % [name, size, min_size])

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			_on_press()
		else:
			_on_release()

func _on_press() -> void:
	_is_pressed = true
	_held_fired = false
	_hold_timer.start()

func _on_release() -> void:
	if not _is_pressed:
		return
	_is_pressed = false
	_hold_timer.stop()
	released.emit()
	if not _held_fired:
		tapped.emit()

func _on_hold_timeout() -> void:
	if _is_pressed:
		_held_fired = true
		held.emit()
