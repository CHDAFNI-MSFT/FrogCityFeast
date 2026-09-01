class_name ProductionArt
extends RefCounted

const INK := Color("25313b")
const CREAM := Color("fff4dc")
const PAPER := Color("f4d8aa")
const FROG_GREEN := Color("68c95f")
const FROG_DARK := Color("2f7a49")
const CANAL_TEAL := Color("4e9ca6")
const PARK_TEAL := Color("4d8d72")
const CITY_CORAL := Color("dc7a67")
const CITY_GOLD := Color("e7b85d")
const NIGHT_VIOLET := Color("4b456f")
const NIGHT_NAVY := Color("233044")
const MAGIC_AMBER := Color("ffd166")
const DANGER_CORAL := Color("f0645a")
const FOCUS_MINT := Color("8ee39a")

const FROG_TEXTURE: Texture2D = preload(
	"res://assets/art/characters/frog.svg"
)
const WING_TEXTURE: Texture2D = preload(
	"res://assets/art/characters/frog_wing.svg"
)
const FOOD_TEXTURE: Texture2D = preload(
	"res://assets/art/targets/food.svg"
)
const LIVING_TEXTURE: Texture2D = preload(
	"res://assets/art/targets/living.svg"
)
const OBJECT_TEXTURE: Texture2D = preload(
	"res://assets/art/targets/object.svg"
)
const VEHICLE_TEXTURE: Texture2D = preload(
	"res://assets/art/targets/vehicle.svg"
)
const BUILDING_PART_TEXTURE: Texture2D = preload(
	"res://assets/art/targets/building_part.svg"
)


static func target_texture(kind: String) -> Texture2D:
	match kind:
		"vehicle":
			return VEHICLE_TEXTURE
		"living":
			return LIVING_TEXTURE
		"object", "building":
			return OBJECT_TEXTURE
		"building_part":
			return BUILDING_PART_TEXTURE
		_:
			return FOOD_TEXTURE


static func target_visual_size(kind: String, pick_radius: float) -> Vector2:
	match kind:
		"vehicle":
			return Vector2(pick_radius * 2.75, pick_radius * 1.72)
		"building_part":
			return Vector2(pick_radius * 2.5, pick_radius * 1.55)
		"object", "building":
			return Vector2.ONE * pick_radius * 2.05
		_:
			return Vector2.ONE * pick_radius * 1.95
