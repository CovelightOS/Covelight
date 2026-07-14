extends Control

## T1.5 home screen, wired in T1.6 to launch real signed activities. One
## HomeTile per available activity, laid out in a grid inset by
## LayoutConstants.SAFE_MARGIN on every side. Zero rendered text anywhere
## (constraint #1) -- every tile communicates through shape, color, and
## sound alone.

## Emitted with the .pck path of the tapped activity. The shell verifies
## its signature and loads it (Shell.start_activity_from_pck) -- the home
## screen never loads or trusts content itself, it only points at it.
signal activity_requested(pck_path: String)

## The activity list is still data, not a filesystem scan: there's no
## installed-content discovery mechanism yet (a later task teaches the
## shell to enumerate whatever .pck/.sig pairs are actually present).
## T1.6's three activities are hard-listed here by path; each ships as a
## signed .pck under res://content/ (built + signed from /activities/* --
## see docs/plan/02-phase1-shell.md T1.6). Adding an activity later is one
## entry here plus its signed pck.
##
## Sorted by "id" at display time (below), never by recency/last-played/
## popularity -- CLAUDE.md #4: nothing about tile order should manufacture
## a pull toward one activity over another.
const ACTIVITIES: Array[Dictionary] = [
	{
		"id": "animal_sounds",
		"pck_path": "res://content/animal_sounds.pck",
		"beacon_color": Color(0.906, 0.451, 0.271),  # warm orange
	},
	{
		"id": "color_mixing",
		"pck_path": "res://content/color_mixing.pck",
		"beacon_color": Color(0.694, 0.475, 0.741),  # soft violet
	},
	{
		"id": "shape_sorter",
		"pck_path": "res://content/shape_sorter.pck",
		"beacon_color": Color(0.361, 0.573, 0.741),  # calm blue
	},
]

const HOME_TILE := preload("res://scenes/home_tile.tscn")

@onready var _tile_grid: GridContainer = $SafeArea/CenterContainer/TileGrid

func _ready() -> void:
	var sorted := ACTIVITIES.duplicate()
	sorted.sort_custom(func(a, b): return a["id"] < b["id"])
	for entry in sorted:
		var tile: HomeTile = HOME_TILE.instantiate()
		tile.beacon_color = entry["beacon_color"]
		var pck_path: String = entry["pck_path"]
		tile.launch_requested.connect(func(): activity_requested.emit(pck_path))
		_tile_grid.add_child(tile)
