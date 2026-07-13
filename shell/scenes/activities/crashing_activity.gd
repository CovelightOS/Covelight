extends ActivityBase

## Deliberately-crashing test activity, proving T1.2's crash containment
## (docs/plan/02-phase1-shell.md T1.2, acceptance: "Deliberately-crashing
## test activity -> shell survives, returns home, no text shown").
##
## Crashes synchronously in _ready(), before ever calling report_ready() --
## this is deliberate: it's the realistic shape of "fails to load," which
## is the case that actually needs shell-side handling. A GDScript runtime
## error does not raise a catchable exception and does not crash the
## engine (verified empirically against the real engine before writing
## this); it prints to the log and aborts only this function. The shell
## never sees the crash directly -- it only sees an activity that never
## reported ready, and its watchdog timeout is what recovers.

func _ready() -> void:
	print("crashing_activity: about to crash on purpose")
	var deliberately_null: Node = null
	deliberately_null.this_method_does_not_exist()
	report_ready()  # unreachable
