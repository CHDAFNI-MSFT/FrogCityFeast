class_name DistrictGenerator
extends RefCounted

const DEFINITION_SCRIPT := preload("res://src/district_definition.gd")

const CORE_COORDINATE := Vector2i.ZERO
const CORE_BOUNDS := Rect2(-1760, -1360, 3520, 2720)
const DISTRICT_SIZE := Vector2(3520, 2720)
const MAIN_ROAD_WIDTH := 360.0
const BUILDINGS_PER_DISTRICT := 1
const LOOSE_TARGETS_PER_DISTRICT := 4
const STREAM_MARGIN := 800.0
const MAX_LOADED_GENERATED_DISTRICTS := 9
const SECRET_MIN_DISTANCE := 4
const SECRET_MAX_DISTANCE := 6
const SECRET_ENTRY_OFFSET := Vector2.ZERO
const SECRET_PORTAL_MARKER_OFFSET := Vector2(0, -280)
const SECRET_PORTAL_APPROACH_OFFSET := Vector2(0, -170)
const GENERATED_BUILDING_DISCOVERY_IDS := [
	"generated_building_sign",
	"generated_building_awning",
	"generated_building_fixture",
	"generated_building",
]

const ARCHETYPES := [
	{
		"id": "downtown",
		"name": "Downtown",
		"ground": Color("777c80"),
		"lot": Color("96999b"),
		"road": Color("343d45"),
		"accent": Color("6fc3d1"),
		"building": Color("8ba4b4"),
		"building_names": ["Skyline Arcade", "Clocktower Offices"],
		"target_id": "generated_downtown_lunch",
		"target_names": [
			"Tower Lunch",
			"Commuter Pretzel",
			"Lobby Umbrella",
			"Rooftop Parcel",
		],
		"target_color": Color("edb45f"),
		"layout": "diagonal",
	},
	{
		"id": "residential",
		"name": "Apartment Neighborhood",
		"ground": Color("78946f"),
		"lot": Color("9db58e"),
		"road": Color("465058"),
		"accent": Color("f1d18a"),
		"building": Color("b98d78"),
		"building_names": ["Garden Flats", "Maple Court"],
		"target_id": "generated_residential_gnome",
		"target_names": [
			"Garden Gnome",
			"Porch Parcel",
			"Picnic Thermos",
			"Laundry Basket",
		],
		"target_color": Color("d96f61"),
		"layout": "opposite",
	},
	{
		"id": "industrial",
		"name": "Industrial Works",
		"ground": Color("77705f"),
		"lot": Color("928a75"),
		"road": Color("363b3f"),
		"accent": Color("e1b64a"),
		"building": Color("8b765d"),
		"building_names": ["Rivet Works", "Freight Depot"],
		"target_id": "generated_industrial_toolbox",
		"target_names": [
			"Toolbox",
			"Safety Cone",
			"Coil of Cable",
			"Packing Crate",
		],
		"target_color": Color("e18c3e"),
		"layout": "wide",
	},
	{
		"id": "waterfront",
		"name": "Waterfront",
		"ground": Color("7f9d88"),
		"lot": Color("9cb9a2"),
		"road": Color("3d4851"),
		"accent": Color("64b3d4"),
		"building": Color("7ba1ad"),
		"building_names": ["Canal Boathouse", "Harbor Cafe"],
		"target_id": "generated_waterfront_crate",
		"target_names": [
			"Fish Crate",
			"Dock Rope",
			"Captain's Lunch",
			"Canal Lantern",
		],
		"target_color": Color("73b9c9"),
		"layout": "west",
	},
	{
		"id": "shopping",
		"name": "Shopping District",
		"ground": Color("927f8e"),
		"lot": Color("b19baa"),
		"road": Color("40424c"),
		"accent": Color("f19bc4"),
		"building": Color("c18ca8"),
		"building_names": ["Ribbon Mall", "Button Boutique"],
		"target_id": "generated_shopping_bag",
		"target_names": [
			"Shopping Bag",
			"Window Display Hat",
			"Food Court Tray",
			"Lost Plush Frog",
		],
		"target_color": Color("ef86b5"),
		"layout": "north_south",
	},
	{
		"id": "parks",
		"name": "Parks and Gardens",
		"ground": Color("6f9c68"),
		"lot": Color("8fba7d"),
		"road": Color("46524c"),
		"accent": Color("d8e56d"),
		"building": Color("8da76f"),
		"building_names": ["Glasshouse", "Park Pavilion"],
		"target_id": "generated_park_picnic",
		"target_names": [
			"Picnic Basket",
			"Garden Trowel",
			"Kite Spool",
			"Flower Cart",
		],
		"target_color": Color("d5cf68"),
		"layout": "open",
	},
]

const SECRET_ARCHETYPE := {
	"id": "secret_fantasy",
	"name": "Starfall Quarter",
	"ground": Color("51496f"),
	"lot": Color("76658f"),
	"road": Color("2d3048"),
	"accent": Color("f0d472"),
	"building": Color("8f72aa"),
	"building_names": ["Starlight Conservatory"],
	"target_id": "generated_park_picnic",
	"target_names": [
		"Starfruit Picnic",
		"Moonflower Basket",
		"Comet Kite Spool",
		"Glowcap Cart",
	],
	"target_color": Color("e8cc72"),
	"layout": "secret",
}


static func bounds_for_coordinate(coordinate: Vector2i) -> Rect2:
	return Rect2(
		CORE_BOUNDS.position
		+ Vector2(coordinate.x, coordinate.y) * DISTRICT_SIZE,
		DISTRICT_SIZE
	)


static func coordinate_for_position(position: Vector2) -> Vector2i:
	var relative := position - CORE_BOUNDS.position
	return Vector2i(
		floori(relative.x / DISTRICT_SIZE.x),
		floori(relative.y / DISTRICT_SIZE.y)
	)


static func seed_for_coordinate(
	session_seed: int,
	coordinate: Vector2i
) -> int:
	var value := int(session_seed) & 0x7fffffff
	value = (
		value
		+ coordinate.x * 73856093
		+ coordinate.y * 19349663
	) & 0x7fffffff
	value = (value * 1103515245 + 12345) & 0x7fffffff
	return maxi(1, value)


static func secret_coordinate(session_seed: int) -> Vector2i:
	var value := maxi(1, absi(session_seed))
	var side := posmod(value, 4)
	var distance := (
		SECRET_MIN_DISTANCE
		+ posmod(value / 4, SECRET_MAX_DISTANCE - SECRET_MIN_DISTANCE + 1)
	)
	var along := posmod(value / 12, 5) - 2
	match side:
		0:
			return Vector2i(distance, along)
		1:
			return Vector2i(along, distance)
		2:
			return Vector2i(-distance, along)
	return Vector2i(along, -distance)


static func secret_entry_position(coordinate: Vector2i) -> Vector2:
	return bounds_for_coordinate(coordinate).get_center() + SECRET_ENTRY_OFFSET


static func secret_portal_marker_position(coordinate: Vector2i) -> Vector2:
	return (
		bounds_for_coordinate(coordinate).get_center()
		+ SECRET_PORTAL_MARKER_OFFSET
	)


static func secret_portal_approach_position(coordinate: Vector2i) -> Vector2:
	return (
		bounds_for_coordinate(coordinate).get_center()
		+ SECRET_PORTAL_APPROACH_OFFSET
	)


static func generate(
	session_seed: int,
	coordinate: Vector2i
) -> DistrictDefinition:
	var district_seed := seed_for_coordinate(session_seed, coordinate)
	var archetype := (
		ARCHETYPES[posmod(district_seed, ARCHETYPES.size())] as Dictionary
	)
	return _generate_definition(
		coordinate,
		district_seed,
		archetype,
		"district",
		false
	)


static func generate_reserved(
	session_seed: int,
	coordinate: Vector2i
) -> DistrictDefinition:
	var district_seed := seed_for_coordinate(session_seed, coordinate)
	var archetype := (
		ARCHETYPES[posmod(district_seed, ARCHETYPES.size())] as Dictionary
	)
	return _generate_definition(
		coordinate,
		district_seed,
		archetype,
		"secret_district",
		false
	)


static func generate_secret(
	session_seed: int,
	coordinate: Vector2i
) -> DistrictDefinition:
	var district_seed := seed_for_coordinate(
		session_seed ^ 0x5EC7E7,
		coordinate
	)
	return _generate_definition(
		coordinate,
		district_seed,
		SECRET_ARCHETYPE,
		"secret_district",
		true
	)


static func _generate_definition(
	coordinate: Vector2i,
	district_seed: int,
	archetype: Dictionary,
	district_id_prefix: String,
	is_secret: bool
) -> DistrictDefinition:
	var definition := DEFINITION_SCRIPT.new() as DistrictDefinition
	var rng := RandomNumberGenerator.new()
	rng.seed = district_seed
	var bounds := bounds_for_coordinate(coordinate)
	var center := bounds.get_center()

	definition.coordinate = coordinate
	definition.district_id = "%s_%d_%d" % [
		district_id_prefix,
		coordinate.x,
		coordinate.y,
	]
	definition.archetype_id = str(archetype["id"])
	definition.display_name = (
		str(archetype["name"])
		if is_secret
		else "%s %d,%d" % [
			archetype["name"],
			coordinate.x,
			coordinate.y,
		]
	)
	definition.bounds = bounds
	definition.ground_color = archetype["ground"] as Color
	definition.lot_color = archetype["lot"] as Color
	definition.road_color = archetype["road"] as Color
	definition.accent_color = archetype["accent"] as Color
	definition.roads = _build_roads(bounds)
	definition.obstacles = _build_obstacles(
		str(archetype["id"]),
		bounds
	)
	definition.buildings = _build_buildings(
		archetype,
		bounds,
		rng
	)
	definition.targets = _build_targets(
		archetype,
		definition,
		rng,
		district_seed
	)
	definition.restock_positions = _build_restock_positions(definition)
	definition.roadblock_anchors = [
		{
			"position": center + Vector2(-720, 0),
			"size": Vector2(320, 52),
			"layout": PrototypeRoadblock.LAYOUT_STRAIGHT,
		},
		{
			"position": center + Vector2(720, 0),
			"size": Vector2(320, 52),
			"layout": PrototypeRoadblock.LAYOUT_STAGGERED,
		},
		{
			"position": center + Vector2(0, -620),
			"size": Vector2(52, 300),
			"layout": PrototypeRoadblock.LAYOUT_STRAIGHT,
		},
		{
			"position": center + Vector2(0, 620),
			"size": Vector2(52, 300),
			"layout": PrototypeRoadblock.LAYOUT_STAGGERED,
		},
	]
	definition.pursuit_trap_anchors = [
		center + Vector2(-560, -250),
		center + Vector2(560, -250),
		center + Vector2(-560, 250),
		center + Vector2(560, 250),
	]
	return definition


static func discovery_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for archetype_value in ARCHETYPES:
		var archetype := archetype_value as Dictionary
		var target_id := str(archetype["target_id"])
		if not result.has(target_id):
			result.append(target_id)
	for target_id in GENERATED_BUILDING_DISCOVERY_IDS:
		result.append(str(target_id))
	return result


static func validation_errors(
	definition: DistrictDefinition
) -> PackedStringArray:
	var errors := PackedStringArray()
	if definition.roads.size() < 2:
		errors.append("District requires horizontal and vertical through streets.")
		return errors
	var horizontal := definition.roads[0]
	var vertical := definition.roads[1]
	if (
		not is_equal_approx(horizontal.position.x, definition.bounds.position.x)
		or not is_equal_approx(horizontal.end.x, definition.bounds.end.x)
	):
		errors.append("Horizontal street does not connect both district edges.")
	if (
		not is_equal_approx(vertical.position.y, definition.bounds.position.y)
		or not is_equal_approx(vertical.end.y, definition.bounds.end.y)
	):
		errors.append("Vertical street does not connect both district edges.")

	var footprints: Array[Rect2] = []
	for building_value in definition.buildings:
		var building := building_value as Dictionary
		var footprint := Rect2(
			building["position"] as Vector2
			- (building["size"] as Vector2) / 2.0,
			building["size"] as Vector2
		)
		if not definition.bounds.encloses(footprint.grow(48.0)):
			errors.append("Building footprint leaves district bounds.")
		for road in definition.roads:
			if footprint.grow(48.0).intersects(road):
				errors.append("Building blocks a through street.")
		for other in footprints:
			if footprint.grow(64.0).intersects(other):
				errors.append("Generated building footprints overlap.")
		for obstacle in definition.obstacles:
			if footprint.grow(36.0).intersects(obstacle):
				errors.append("Generated building overlaps an obstacle.")
		footprints.append(footprint)

	var target_areas: Array[Rect2] = []
	for target_value in definition.targets:
		var target := target_value as Dictionary
		var radius := float(target["radius"])
		var target_area := Rect2(
			target["position"] as Vector2 - Vector2.ONE * radius,
			Vector2.ONE * radius * 2.0
		)
		if not definition.bounds.grow(-radius).encloses(target_area):
			errors.append("Generated target leaves district bounds.")
		for footprint in footprints:
			if footprint.grow(radius + 20.0).intersects(target_area):
				errors.append("Generated target overlaps a building.")
		for obstacle in definition.obstacles:
			if obstacle.grow(radius + 20.0).intersects(target_area):
				errors.append("Generated target overlaps an obstacle.")
		for other in target_areas:
			if other.grow(24.0).intersects(target_area):
				errors.append("Generated targets overlap.")
		target_areas.append(target_area)
	var roadblock_layouts := {}
	for anchor_value in definition.roadblock_anchors:
		var anchor := anchor_value as Dictionary
		var layout_id := str(anchor.get("layout", ""))
		var size := anchor.get("size", Vector2.ZERO) as Vector2
		var position := anchor.get("position", Vector2.INF) as Vector2
		if (
			size.x <= 0.0
			or size.y <= 0.0
			or position == Vector2.INF
		):
			errors.append("Generated roadblock anchor is incomplete.")
			continue
		if layout_id not in [
			PrototypeRoadblock.LAYOUT_STRAIGHT,
			PrototypeRoadblock.LAYOUT_STAGGERED,
		]:
			errors.append("Generated roadblock anchor has an unknown layout.")
			continue
		roadblock_layouts[layout_id] = true
		var rects := PrototypeRoadblock.local_rects_for_layout(
			layout_id,
			size
		)
		if rects.is_empty() or rects.size() > PrototypeRoadblock.MAX_SEGMENTS:
			errors.append("Generated roadblock layout exceeds its segment cap.")
		for rect in rects:
			var world_rect := Rect2(
				position + rect.position,
				rect.size
			)
			if not definition.bounds.encloses(
				world_rect.grow(
					PrototypeRoadblock.SAFE_EDGE_CLEARANCE
				)
			):
				errors.append(
					"Generated roadblock layout leaves safe district bounds."
				)
		if (
			layout_id == PrototypeRoadblock.LAYOUT_STAGGERED
			and PrototypeRoadblock.central_opening_width(
				layout_id,
				size
			) < PrototypeRoadblock.MIN_STAGGERED_OPENING
		):
			errors.append(
				"Generated staggered roadblock lacks a maximum-growth lane."
			)
	if roadblock_layouts.size() < 2:
		errors.append("Generated district requires both roadblock layouts.")
	return errors


static func _build_roads(bounds: Rect2) -> Array[Rect2]:
	var center := bounds.get_center()
	return [
		Rect2(
			Vector2(bounds.position.x, center.y - MAIN_ROAD_WIDTH / 2.0),
			Vector2(bounds.size.x, MAIN_ROAD_WIDTH)
		),
		Rect2(
			Vector2(center.x - MAIN_ROAD_WIDTH / 2.0, bounds.position.y),
			Vector2(MAIN_ROAD_WIDTH, bounds.size.y)
		),
	]


static func _build_obstacles(
	archetype_id: String,
	bounds: Rect2
) -> Array[Rect2]:
	var center := bounds.get_center()
	match archetype_id:
		"waterfront":
			return [
				Rect2(
					Vector2(center.x + 1120, bounds.position.y),
					Vector2(500, bounds.size.y / 2.0 - 250.0)
				),
				Rect2(
					Vector2(center.x + 1120, center.y + 250),
					Vector2(500, bounds.size.y / 2.0 - 250.0)
				),
			]
		"industrial":
			return [
				Rect2(center + Vector2(900, -990), Vector2(420, 190)),
			]
		"parks":
			return [
				Rect2(center + Vector2(760, -930), Vector2(380, 230)),
			]
		"secret_fantasy":
			return [
				Rect2(center + Vector2(-1260, -980), Vector2(360, 220)),
				Rect2(center + Vector2(900, 760), Vector2(340, 240)),
			]
	return []


static func _build_buildings(
	archetype: Dictionary,
	bounds: Rect2,
	rng: RandomNumberGenerator
) -> Array[Dictionary]:
	var center := bounds.get_center()
	var layout := str(archetype["layout"])
	var placements := [
		{"offset": Vector2(-760, -610), "door": "south"},
		{"offset": Vector2(760, 610), "door": "north"},
	]
	match layout:
		"opposite":
			placements = [
				{"offset": Vector2(760, -610), "door": "south"},
				{"offset": Vector2(-760, 610), "door": "north"},
			]
		"wide":
			placements = [
				{"offset": Vector2(-890, -650), "door": "east"},
				{"offset": Vector2(890, 650), "door": "west"},
			]
		"west":
			placements = [
				{"offset": Vector2(-850, -610), "door": "south"},
				{"offset": Vector2(-850, 610), "door": "north"},
			]
		"north_south":
			placements = [
				{"offset": Vector2(-700, -640), "door": "south"},
				{"offset": Vector2(700, 640), "door": "north"},
			]
		"open":
			placements = [
				{"offset": Vector2(-970, -690), "door": "east"},
				{"offset": Vector2(970, 690), "door": "west"},
			]
		"secret":
			placements = [
				{"offset": Vector2(880, -650), "door": "west"},
			]

	var result: Array[Dictionary] = []
	var names := archetype["building_names"] as Array
	for index in BUILDINGS_PER_DISTRICT:
		var placement := placements[index] as Dictionary
		var size := Vector2(
			rng.randf_range(430.0, 520.0),
			rng.randf_range(320.0, 390.0)
		)
		var door_side := str(placement["door"])
		var counter_position := Vector2.ZERO
		var counter_size := Vector2(150, 52)
		match door_side:
			"north":
				counter_position = Vector2(0, size.y * 0.28)
			"south":
				counter_position = Vector2(0, -size.y * 0.28)
			"east":
				counter_position = Vector2(-size.x * 0.28, 0)
				counter_size = Vector2(52, 150)
			"west":
				counter_position = Vector2(size.x * 0.28, 0)
				counter_size = Vector2(52, 150)
		result.append({
			"position": center + placement["offset"] as Vector2,
			"size": size,
			"name": str(names[index]),
			"door_side": door_side,
			"color": (archetype["building"] as Color).lightened(
				float(index) * 0.08
			),
			"counter_position": counter_position,
			"counter_size": counter_size,
		})
	return result


static func _build_targets(
	archetype: Dictionary,
	definition: DistrictDefinition,
	rng: RandomNumberGenerator,
	district_seed: int
) -> Array[Dictionary]:
	var center := definition.bounds.get_center()
	var candidates := [
		center + Vector2(-1210, -270),
		center + Vector2(1210, 270),
		center + Vector2(-420, -980),
		center + Vector2(420, 980),
		center + Vector2(-1180, 330),
		center + Vector2(1180, -330),
		center + Vector2(-650, 0),
		center + Vector2(650, 0),
		center + Vector2(0, -620),
		center + Vector2(0, 620),
		center + Vector2(-1320, 760),
		center + Vector2(1320, -760),
	]
	var names := archetype["target_names"] as Array
	var result: Array[Dictionary] = []
	var candidate_index := 0
	while result.size() < LOOSE_TARGETS_PER_DISTRICT:
		var position: Vector2 = candidates[candidate_index] as Vector2
		candidate_index += 1
		if _position_blocked(position, 34.0, definition):
			continue
		var index := result.size()
		result.append({
			"instance_id": "%s_target_%d" % [
				definition.district_id,
				index,
			],
			"id": str(archetype["target_id"]),
			"name": str(names[index]),
			"position": position,
			"value": 24 + index * 11,
			"tier": 1 if index >= 2 else 0,
			"kind": "object" if index % 2 == 1 else "food",
			"radius": 27.0 + float(index % 2) * 4.0,
			"resistant": index == 3,
			"taps": 6 if index == 3 else 0,
			"color": (archetype["target_color"] as Color).lightened(
				float(index) * 0.06
			),
			"motion_seed": seed_for_coordinate(
				district_seed + index + 1,
				definition.coordinate
			),
			"restockable": false,
		})
	return result


static func _build_restock_positions(
	definition: DistrictDefinition
) -> Array[Vector2]:
	var center := definition.bounds.get_center()
	var candidates := [
		center + Vector2(-1180, -300),
		center + Vector2(1180, 300),
		center + Vector2(-480, -980),
		center + Vector2(480, 980),
		center + Vector2(-650, 300),
		center + Vector2(650, -300),
	]
	var result: Array[Vector2] = []
	for candidate in candidates:
		if not _position_blocked(candidate, 44.0, definition):
			result.append(candidate)
	return result


static func _position_blocked(
	position: Vector2,
	radius: float,
	definition: DistrictDefinition
) -> bool:
	var area := Rect2(
		position - Vector2.ONE * radius,
		Vector2.ONE * radius * 2.0
	)
	for building_value in definition.buildings:
		var building := building_value as Dictionary
		var footprint := Rect2(
			building["position"] as Vector2
			- (building["size"] as Vector2) / 2.0,
			building["size"] as Vector2
		)
		if footprint.grow(radius + 20.0).intersects(area):
			return true
	for obstacle in definition.obstacles:
		if obstacle.grow(radius + 20.0).intersects(area):
			return true
	return false
