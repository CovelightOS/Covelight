extends Control
class_name Shell

## Root scene: boot -> home -> activity-running -> return-to-home.
## docs/plan/02-phase1-shell.md T1.2.
##
## No quit path is implemented anywhere here, on purpose -- there is no
## exit, no back-to-OS, no menu in child-reachable UI (the parent exit
## gesture is Tier 1's T2.3, a separate, deliberately-hidden surface, not
## this scene). A desktop dev build's OS window close button is a
## development convenience outside this scope, not a child-reachable path.

enum State { BOOT, HOME, ACTIVITY_RUNNING, RETURN_TO_HOME }

signal state_changed(new_state: State)

## Seconds an activity has to call report_ready() before it's treated as
## failed-to-load and the shell recovers to home. A var, not a const, so
## tests can shrink it; production default is generous since real signed
## PCK loading (T1.4) may need real I/O and signature verification time.
var load_timeout_seconds: float = 5.0

var state: State = State.BOOT:
	set(value):
		state = value
		state_changed.emit(value)

const HOME_SCENE := preload("res://scenes/home.tscn")

var _current_activity: Node = null
var _watchdog: Timer

@onready var _home_container: Control = $HomeContainer
@onready var _activity_container: Control = $ActivityContainer
@onready var _transition: TransitionOverlay = $TransitionOverlay

func _ready() -> void:
	_watchdog = Timer.new()
	_watchdog.one_shot = true
	_watchdog.timeout.connect(_on_watchdog_timeout)
	add_child(_watchdog)
	_enter_boot()

func _enter_boot() -> void:
	state = State.BOOT
	await _transition.cover()
	await _transition.reveal()
	_enter_home()

func _enter_home() -> void:
	state = State.HOME
	var home := HOME_SCENE.instantiate()
	home.activity_requested.connect(_on_activity_requested)
	_home_container.add_child(home)

func _on_activity_requested(activity_scene: PackedScene) -> void:
	start_activity(activity_scene)

## Public entry point T1.5's real home screen (and tests) call. T1.4's
## real signed-PCK loading plugs in here too -- this signature doesn't
## care whether activity_scene came from a stub resource or a verified PCK.
func start_activity(activity_scene: PackedScene) -> void:
	for child in _home_container.get_children():
		child.queue_free()
	state = State.ACTIVITY_RUNNING
	await _transition.cover()
	_current_activity = activity_scene.instantiate()
	_current_activity.activity_ready.connect(_on_activity_ready)
	_current_activity.activity_finished.connect(_on_activity_finished)
	_activity_container.add_child(_current_activity)
	_watchdog.start(load_timeout_seconds)
	await _transition.reveal()

func _on_activity_ready() -> void:
	_watchdog.stop()

func _on_activity_finished() -> void:
	_watchdog.stop()
	_return_to_home()

## Crash containment. Fires when an activity throws during load (never
## reaches report_ready()), hangs waiting on something that never resolves,
## or otherwise fails to load -- the shell can't tell those apart, and
## doesn't need to: all of them mean "no ready signal arrived in time,"
## and all of them get the same calm recovery, no error text, no dialog.
##
## Honest limitation: this cannot recover from a true busy-loop hang inside
## a single frame (extremely unlikely for any real activity, but possible
## in principle) -- that blocks the single script thread this Timer's own
## callback runs on too. Recovering from that needs OS-level process
## supervision, which is out of scope here (Tier 1/2 concerns, not the
## shell's).
func _on_watchdog_timeout() -> void:
	_return_to_home()

func _return_to_home() -> void:
	if state == State.RETURN_TO_HOME:
		return
	state = State.RETURN_TO_HOME
	await _transition.cover()
	if is_instance_valid(_current_activity):
		_current_activity.queue_free()
	_current_activity = null
	_enter_home()
	await _transition.reveal()
