class_name DistrictDefinition
extends RefCounted

var coordinate := Vector2i.ZERO
var district_id := ""
var archetype_id := ""
var display_name := ""
var bounds := Rect2()
var ground_color := Color.WHITE
var lot_color := Color.WHITE
var road_color := Color.WHITE
var accent_color := Color.WHITE
var roads: Array[Rect2] = []
var obstacles: Array[Rect2] = []
var buildings: Array[Dictionary] = []
var targets: Array[Dictionary] = []
var restock_positions: Array[Vector2] = []
var roadblock_anchors: Array[Dictionary] = []
var pursuit_trap_anchors: Array[Vector2] = []


func snapshot() -> Dictionary:
	return {
		"coordinate": coordinate,
		"district_id": district_id,
		"archetype_id": archetype_id,
		"display_name": display_name,
		"bounds": bounds,
		"ground_color": ground_color,
		"lot_color": lot_color,
		"road_color": road_color,
		"accent_color": accent_color,
		"roads": roads.duplicate(),
		"obstacles": obstacles.duplicate(),
		"buildings": buildings.duplicate(true),
		"targets": targets.duplicate(true),
		"restock_positions": restock_positions.duplicate(),
		"roadblock_anchors": roadblock_anchors.duplicate(true),
		"pursuit_trap_anchors": pursuit_trap_anchors.duplicate(),
	}
