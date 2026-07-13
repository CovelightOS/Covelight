extends Control

## Placeholder home screen. T1.5 replaces this with the real textless
## activity chooser (icon tiles, tap-hold audio preview). For now: tapping
## anywhere starts the stub test activity, so the state machine's
## transitions are actually reachable/observable before T1.5 exists.
## Zero rendered text (constraint #1) -- the corner/center shapes carry
## over T1.1's scaffolding proof, now inset by LayoutConstants.SAFE_MARGIN
## instead of sitting flush against the edges.

signal activity_requested(activity_scene: PackedScene)

const STUB_ACTIVITY := preload("res://scenes/activities/stub_activity.tscn")

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		activity_requested.emit(STUB_ACTIVITY)
	elif event is InputEventMouseButton and event.pressed:
		activity_requested.emit(STUB_ACTIVITY)
