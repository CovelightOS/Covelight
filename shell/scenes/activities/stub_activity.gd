extends ActivityBase

## Stub "activity" for T1.2 -- proves the shell can start, run, and end an
## activity before T1.4's real signed-PCK loading exists. Reports ready
## immediately, shows a single pulsing shape (textless) for a couple
## seconds, then reports finished so the shell returns home on its own,
## same as a real activity ending calmly.

const RUN_SECONDS := 1.5

@onready var _shape: ColorRect = $Shape

func _ready() -> void:
	report_ready()
	var tween := create_tween()
	tween.tween_property(_shape, "scale", Vector2(1.15, 1.15), 0.4)
	tween.tween_property(_shape, "scale", Vector2(1.0, 1.0), 0.4)
	await get_tree().create_timer(RUN_SECONDS).timeout
	report_finished()
