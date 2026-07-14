extends RefCounted
class_name ActivityProgress

## Local-only progress storage -- docs/design/activity-sdk.md's progress
## API. CLAUDE.md #5/#10: no telemetry, no network APIs reachable from
## activity code at all -- not "activities are asked not to," there is
## simply no HTTPRequest, no socket, no remote-anything imported or
## reachable anywhere in this file or the rest of `/shell/sdk`. Everything
## here reads and writes `user://`, Godot's own per-install local data
## directory, nothing else.
##
## Storage is one opaque Dictionary blob per activity id -- not a shared
## cross-activity schema. This is a deliberate, provisional choice
## (docs/plan/02-phase1-shell.md's open question: "start opaque, revisit at
## Phase 4"), not an oversight: a shared schema is easy to add later by
## having a future version read/migrate these blobs, but hard to undo once
## activities depend on shared fields. An activity decides its own
## Dictionary shape and is the only code that ever reads it back.

static func _path_for(activity_id: String) -> String:
	return "user://progress/%s.cfg" % activity_id

## Returns {} if nothing has been saved yet for this activity -- never an
## error, since "no progress yet" is the normal first-run state, not a
## failure.
static func load_progress(activity_id: String) -> Dictionary:
	var config := ConfigFile.new()
	var open_err := config.load(_path_for(activity_id))
	if open_err != OK:
		return {}
	return config.get_value("progress", "data", {})

static func save_progress(activity_id: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute("user://progress")
	var config := ConfigFile.new()
	config.set_value("progress", "data", data)
	config.save(_path_for(activity_id))
