extends Control
class_name ActivityBase

## Control-rooted, not Node -- activities are full-screen anchored layouts
## like everything else in this shell (home.tscn), so they share the same
## anchor/safe-margin conventions from the start.

## Provisional activity contract for T1.2's state machine. T1.3 formalizes
## the full activity manifest and lifecycle (start/pause/end); this is
## deliberately just the minimal signal pair the shell depends on today, so
## T1.4's real signed-PCK loading can instantiate a real activity scene in
## place of the stub/test scenes here without the shell changing at all.
##
## Contract: call `report_ready()` once initialized and able to take
## input. The shell is watching for it (with a timeout) as the sole signal
## that loading succeeded — an activity that never calls it (because it
## crashed, hung waiting on something, or never got instantiated  correctly)
## is indistinguishable to the shell from one that's still loading, until
## the watchdog times out and reclaims control. See docs on
## Shell.LOAD_TIMEOUT_SECONDS.
##
## Call `report_finished()` when the activity is done and the child should
## return home — calmly, per CLAUDE.md #4, never a score screen.

signal activity_ready
signal activity_finished

func report_ready() -> void:
	activity_ready.emit()

func report_finished() -> void:
	activity_finished.emit()
