extends RefCounted
class_name ActivityManifest

## Parses and validates `manifest.cfg` -- docs/design/activity-sdk.md's
## activity manifest. A plain Godot ConfigFile, not a custom class_name
## Resource: a PCK loaded at runtime via `load_resource_pack` was never
## scanned into the host shell's global class cache (see
## docs/research/godot-pck.md finding 3, and shell/README.md's own note on
## when that cache gets built), so a custom Resource subclass defined
## *inside* an activity's PCK would not reliably resolve there. ConfigFile
## is a built-in engine type, always available, in both directions.

const ALLOWED_LAYOUTS := ["phone_portrait", "tablet_portrait"]

var id: String = ""
var version: String = ""
var min_shell_version: String = ""
var declared_layouts: Array = []
var entry_scene: String = "res://activity.tscn"

## Non-empty only when parsing/validation failed -- human-readable, never
## shown to the child (this runs in tooling/shell-loading code, not
## child-reachable UI).
var error: String = ""

static func load_from_file(path: String) -> ActivityManifest:
	var manifest := ActivityManifest.new()
	var config := ConfigFile.new()
	var open_err := config.load(path)
	if open_err != OK:
		manifest.error = "could not read %s (%s)" % [path, error_string(open_err)]
		return manifest

	manifest.id = config.get_value("activity", "id", "")
	manifest.version = config.get_value("activity", "version", "")
	manifest.min_shell_version = config.get_value("activity", "min_shell_version", "")
	manifest.declared_layouts = config.get_value("activity", "declared_layouts", [])
	manifest.entry_scene = config.get_value("activity", "entry_scene", "res://activity.tscn")

	manifest.error = manifest._validate()
	return manifest

func is_valid() -> bool:
	return error == ""

func _validate() -> String:
	if id.is_empty():
		return "manifest missing required field: id"
	if version.is_empty():
		return "manifest missing required field: version"
	if min_shell_version.is_empty():
		return "manifest missing required field: min_shell_version"
	if declared_layouts.is_empty():
		return "manifest must declare at least one layout in %s -- responsive layout declaration is mandatory (docs/plan/02-phase1-shell.md T1.3)" % [ALLOWED_LAYOUTS]
	for layout in declared_layouts:
		if not ALLOWED_LAYOUTS.has(layout):
			return "unknown declared_layout %s -- must be one of %s" % [layout, ALLOWED_LAYOUTS]
	return ""

## True if `shell_version` (e.g. ProjectSettings "application/config/version")
## satisfies this manifest's min_shell_version, compared as dotted-integer
## semver ("major.minor.patch", missing components treated as 0). Not a
## security boundary -- just avoids handing an old shell build an activity
## that assumes a newer SDK surface exists.
func is_compatible_with_shell(shell_version: String) -> bool:
	return _compare_versions(shell_version, min_shell_version) >= 0

static func _compare_versions(a: String, b: String) -> int:
	var a_parts := _parse_version(a)
	var b_parts := _parse_version(b)
	for i in maxi(a_parts.size(), b_parts.size()):
		var a_part: int = a_parts[i] if i < a_parts.size() else 0
		var b_part: int = b_parts[i] if i < b_parts.size() else 0
		if a_part != b_part:
			return a_part - b_part
	return 0

static func _parse_version(v: String) -> Array:
	var parts: Array = []
	for token in v.split("."):
		parts.append(int(token) if token.is_valid_int() else 0)
	return parts
