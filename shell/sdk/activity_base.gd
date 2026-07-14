extends Control
class_name ActivityBase

## The T1.3 activity entry-point contract (docs/design/activity-sdk.md).
## Control-rooted, not Node -- activities are full-screen anchored layouts
## like everything else in this shell (home.tscn), so they share the same
## anchor/safe-margin conventions from the start.
##
## Lifecycle: start / pause / resume / end.
##
## start -- override `_ready()` (as any Control does), call `report_ready()`
## once initialized and able to take input. The shell is watching for it
## (with a timeout) as the sole signal that loading succeeded -- an activity
## that never calls it (because it crashed, hung waiting on something, or
## never got instantiated correctly) is indistinguishable to the shell from
## one that's still loading, until the watchdog times out and reclaims
## control. See Shell.load_timeout_seconds.
##
## pause / resume -- fire when the host OS takes focus away from the shell
## entirely (e.g. an interruption outside child-reachable UI, or a desktop
## dev window losing focus) and back. Not a shell state (the shell has no
## PAUSED state -- see shell.gd) -- purely a courtesy hook so an activity
## can stop animations/audio while not visible instead of running unheard
## and unseen. Override `_on_activity_paused()` / `_on_activity_resumed()`;
## both are no-ops by default, so ignoring them is safe and common.
##
## end -- call `report_finished()` when the activity is done and the child
## should return home -- calmly, per CLAUDE.md #4, never a score screen, and
## never as a response to a "wrong" action (redirect gently instead; see
## docs/guides/activity-review.md).

signal activity_ready
signal activity_finished

func report_ready() -> void:
	activity_ready.emit()

func report_finished() -> void:
	activity_finished.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_on_activity_paused()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_on_activity_resumed()

## Override to pause animations/audio when the host loses focus. No-op by
## default -- most activities can safely ignore this.
func _on_activity_paused() -> void:
	pass

## Override to resume after `_on_activity_paused()`. No-op by default.
func _on_activity_resumed() -> void:
	pass
