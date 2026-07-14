extends Control

## T1.5: the real textless activity chooser, replacing T1.2's placeholder
## (tap-anywhere-to-start-the-stub). One HomeTile per available activity,
## laid out in a grid inset by LayoutConstants.SAFE_MARGIN on every side.
## Zero rendered text anywhere (constraint #1) -- every tile communicates
## through shape, color, and sound alone.

signal activity_requested(activity_scene: PackedScene)

## The activity list is data, not a filesystem scan: there is no real
## installed-content directory or discovery mechanism yet (that arrives
## with T1.6's first real signed activities, and whatever later task
## teaches the shell to enumerate installed .pck/manifest pairs via
## PckLoader). Today the only real activity-shaped scene in the project is
## the T1.2 stub, so that's the only tile. Adding a second real activity
## later means adding a second entry here, nothing structural changes.
##
## Sorted by "id" at display time (below), not left in declaration order
## and never by recency/last-played/popularity -- CLAUDE.md #4: nothing
## about *how tiles are ordered* should manufacture a pull toward one
## activity over another.
const ACTIVITIES: Array[Dictionary] = [
	{
		"id": "stub",
		"scene": preload("res://scenes/activities/stub_activity.tscn"),
		"beacon_color": Color(0.945, 0.706, 0.353),  # warm amber
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
		var activity_scene: PackedScene = entry["scene"]
		tile.launch_requested.connect(func(): activity_requested.emit(activity_scene))
		_tile_grid.add_child(tile)
