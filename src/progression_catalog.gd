class_name ProgressionCatalog
extends RefCounted

const SCOPE_SESSION := "session"
const SCOPE_PROFILE := "profile"
const SCOPE_DEVICE := "device"

const SECRET_FANTASY_DISTRICT := "secret_fantasy_district"
const DEVICE_SCORE_MILESTONE_THRESHOLD := 2500

const EVENT_PROFILE_ACHIEVEMENT_IDS := [
	"event_moonlight_bazaar",
	"event_kite_festival",
	"event_water_main",
	"event_wind_squall",
]

const GENERATED_ARCHETYPE_DISCOVERY_IDS := [
	"generated_downtown_lunch",
	"generated_residential_gnome",
	"generated_industrial_toolbox",
	"generated_waterfront_crate",
	"generated_shopping_bag",
	"generated_park_picnic",
]

const WHOLE_BUILDING_DISCOVERY_IDS := [
	"leap_cafe_building",
	"canal_apartments_building",
	"moonlight_market_building",
	"oddities_shop_building",
	"generated_building",
]

const FIRST_GROWTH_EVIDENCE_DISCOVERY_IDS := [
	"moonlight_market_door",
	"moonlight_market_counter",
	"oddities_shop_counter",
	"oddities_shop_sign",
	"leap_cafe_espresso_counter",
	"leap_cafe_awning",
	"canal_apartments_lobby_bench",
	"canal_apartments_entry_canopy",
	"generated_building_awning",
	"generated_building_fixture",
	"generated_building",
	"shop_phone",
	"park_chair",
	"golden_cake",
	"delivery_van",
	"market_vendor",
	"market_rooftop_beehive",
	"oddities_cellar_music_box",
	"canal_tenant_cat",
	"canal_upper_hall_vacuum",
	"canal_fire_escape_laundry",
	"river_subway_signal",
	"river_pond_lily_planter",
	"construction_crane_toolbox",
	"river_hidden_pump_handle",
	"animal_control",
	"security_guard",
	"watchdog",
]

const FIRST_GROWTH_EVIDENCE_ACHIEVEMENT_IDS := [
	"building_banquet",
	"power_sampler",
	"enormous_appetite",
]

const FIRST_GROWTH_EVIDENCE_CLUE_IDS := [
	"golden_crumb",
	"sewer_stamp",
	"oddities_label",
	"crane_map",
	"giant_shadow",
]

const STORY_CLUE_BY_DISCOVERY_ID := {
	"river_hidden_pump_handle": "sewer_stamp",
	"oddities_cellar_music_box": "oddities_label",
	"construction_crane_toolbox": "crane_map",
}

const STORY_CLUE_BY_POWER_ID := {
	"flight": "golden_crumb",
	"long_tongue": "oddities_label",
	"camouflage": "sewer_stamp",
}

const STORY_CLUE_BY_PROFILE_ACHIEVEMENT_ID := {
	"building_banquet": "giant_shadow",
	"event_moonlight_bazaar": "moonlit_receipt",
	"event_kite_festival": "kite_thread",
	"event_water_main": "repair_blueprint",
}

const SESSION_GOALS := [
	{
		"id": "sharp_aim",
		"name": "Sharp Aim",
		"description": "Make three swallows at 90% accuracy or better.",
	},
	{
		"id": "hold_on",
		"name": "Hold On",
		"description": "Win two target struggles.",
	},
	{
		"id": "city_tour",
		"name": "City Tour",
		"description": "Swallow four distinct target types.",
	},
]

const PROFILE_ACHIEVEMENTS := [
	{
		"id": "growth_spurt",
		"name": "Growth Spurt",
		"description": "Reach the first growth tier.",
		"category": "exploration",
	},
	{
		"id": "city_gourmet",
		"name": "City Gourmet",
		"description": "Record twelve distinct Field Guide discoveries.",
		"category": "exploration",
	},
	{
		"id": "building_banquet",
		"name": "Building Banquet",
		"description": "Swallow a whole weakened building.",
		"category": "exploration",
	},
	{
		"id": "power_sampler",
		"name": "Power Sampler",
		"description": "Discover every temporary power.",
		"category": "powers",
	},
	{
		"id": "clue_collector",
		"name": "Clue Collector",
		"description": "Find enough clues to reveal the secret path.",
		"category": "story",
	},
	{
		"id": "event_explorer",
		"name": "Event Explorer",
		"description": "Complete every one-time city event goal.",
		"category": "events",
	},
	{
		"id": "secret_finder",
		"name": "Secret Finder",
		"description": "Enter the secret fantasy district.",
		"category": "story",
	},
	{
		"id": "enormous_appetite",
		"name": "Enormous Appetite",
		"description": "Reach the enormous growth tier.",
		"category": "growth",
	},
	{
		"id": "event_moonlight_bazaar",
		"name": "Lantern Supper",
		"description": "Swallow a target during the Moonlight Market bazaar.",
		"category": "events",
	},
	{
		"id": "event_kite_festival",
		"name": "Kite Picnic",
		"description": "Swallow a target during the Canal Kite Festival.",
		"category": "events",
	},
	{
		"id": "event_water_main",
		"name": "Detour Dinner",
		"description": "Swallow a target while the water-main repair is active.",
		"category": "events",
	},
	{
		"id": "event_wind_squall",
		"name": "Snack in the Wind",
		"description": "Swallow a target during the wind squall.",
		"category": "events",
	},
]

const DEVICE_ACHIEVEMENTS := [
	{
		"id": "device_score_2500",
		"name": "iPad Feast",
		"description": "Reach a device best score of 2,500.",
	},
	{
		"id": "device_secret_found",
		"name": "Hidden City",
		"description": "Find the secret fantasy district on this device.",
	},
	{
		"id": "device_enormous_growth",
		"name": "Biggest Frog",
		"description": "Reach enormous growth on this device.",
	},
]

const STORY_CLUES := [
	{
		"id": "golden_crumb",
		"name": "Golden Crumb",
		"text": "A warm crumb points away from every ordinary street.",
	},
	{
		"id": "sewer_stamp",
		"name": "Sewer Stamp",
		"text": "A tiny crown is stamped beneath years of river dust.",
	},
	{
		"id": "moonlit_receipt",
		"name": "Moonlit Receipt",
		"text": "The receipt lists a shop that opens only between maps.",
	},
	{
		"id": "kite_thread",
		"name": "Silver Kite Thread",
		"text": "The thread tugs toward a district the wind cannot reach.",
	},
	{
		"id": "repair_blueprint",
		"name": "Folded Blueprint",
		"text": "A missing block is drawn beneath the water-main route.",
	},
	{
		"id": "oddities_label",
		"name": "Oddities Label",
		"text": "The faded label says the box was found beyond the last lamp.",
	},
	{
		"id": "crane_map",
		"name": "Crane Operator's Map",
		"text": "One penciled road continues past the edge of the paper.",
	},
	{
		"id": "district_glyph",
		"name": "District Glyph",
		"text": "Six neighborhood marks circle a seventh mark shaped like a star.",
	},
	{
		"id": "giant_shadow",
		"name": "Giant Shadow",
		"text": "The shadow is frog-shaped, but much larger than the nearby tower.",
	},
]

const POWERS := [
	{
		"id": "flight",
		"name": "Flight",
		"duration": 60.0,
		"target_id": "golden_cake",
	},
	{
		"id": "speed_burst",
		"name": "Speed Burst",
		"duration": 20.0,
		"target_id": "market_rooftop_beehive",
	},
	{
		"id": "long_tongue",
		"name": "Long Tongue",
		"duration": 30.0,
		"target_id": "oddities_cellar_music_box",
	},
	{
		"id": "camouflage",
		"name": "Camouflage",
		"duration": 20.0,
		"target_id": "river_hidden_pump_handle",
	},
	{
		"id": "bubble_shield",
		"name": "Bubble Shield",
		"duration": 30.0,
		"target_id": "river_pond_lily_planter",
	},
]

const SECRET_UNLOCKS := [
	{
		"id": SECRET_FANTASY_DISTRICT,
		"name": "Secret Fantasy District",
	},
]

const SECRET_CLUE_REQUIREMENT := 6


static func session_goal_entries() -> Array[Dictionary]:
	return _duplicate_entries(SESSION_GOALS)


static func profile_achievement_entries() -> Array[Dictionary]:
	return _duplicate_entries(PROFILE_ACHIEVEMENTS)


static func device_achievement_entries() -> Array[Dictionary]:
	return _duplicate_entries(DEVICE_ACHIEVEMENTS)


static func story_clue_entries() -> Array[Dictionary]:
	return _duplicate_entries(STORY_CLUES)


static func power_entries() -> Array[Dictionary]:
	return _duplicate_entries(POWERS)


static func session_goal_ids() -> PackedStringArray:
	return _entry_ids(SESSION_GOALS)


static func profile_achievement_ids() -> PackedStringArray:
	return _entry_ids(PROFILE_ACHIEVEMENTS)


static func device_achievement_ids() -> PackedStringArray:
	return _entry_ids(DEVICE_ACHIEVEMENTS)


static func story_clue_ids() -> PackedStringArray:
	return _entry_ids(STORY_CLUES)


static func power_ids() -> PackedStringArray:
	return _entry_ids(POWERS)


static func secret_unlock_ids() -> PackedStringArray:
	return _entry_ids(SECRET_UNLOCKS)


static func session_goal_entry(goal_id: String) -> Dictionary:
	return _entry_for(SESSION_GOALS, goal_id)


static func profile_achievement_entry(achievement_id: String) -> Dictionary:
	return _entry_for(PROFILE_ACHIEVEMENTS, achievement_id)


static func device_achievement_entry(achievement_id: String) -> Dictionary:
	return _entry_for(DEVICE_ACHIEVEMENTS, achievement_id)


static func story_clue_entry(clue_id: String) -> Dictionary:
	return _entry_for(STORY_CLUES, clue_id)


static func power_entry(power_id: String) -> Dictionary:
	return _entry_for(POWERS, power_id)


static func power_for_target(target_id: String) -> Dictionary:
	for entry in POWERS:
		if str(entry["target_id"]) == target_id:
			return (entry as Dictionary).duplicate(true)
	return {}


static func event_profile_achievement_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for achievement_id in EVENT_PROFILE_ACHIEVEMENT_IDS:
		result.append(str(achievement_id))
	return result


static func generated_archetype_discovery_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for discovery_id in GENERATED_ARCHETYPE_DISCOVERY_IDS:
		result.append(str(discovery_id))
	return result


static func whole_building_discovery_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for discovery_id in WHOLE_BUILDING_DISCOVERY_IDS:
		result.append(str(discovery_id))
	return result


static func first_growth_evidence_discovery_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for discovery_id in FIRST_GROWTH_EVIDENCE_DISCOVERY_IDS:
		result.append(str(discovery_id))
	return result


static func first_growth_evidence_achievement_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for achievement_id in FIRST_GROWTH_EVIDENCE_ACHIEVEMENT_IDS:
		result.append(str(achievement_id))
	return result


static func first_growth_evidence_clue_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for clue_id in FIRST_GROWTH_EVIDENCE_CLUE_IDS:
		result.append(str(clue_id))
	return result


static func story_clue_for_discovery(discovery_id: String) -> String:
	return str(STORY_CLUE_BY_DISCOVERY_ID.get(discovery_id, ""))


static func story_clue_for_power(power_id: String) -> String:
	return str(STORY_CLUE_BY_POWER_ID.get(power_id, ""))


static func story_clue_for_profile_achievement(
	achievement_id: String
) -> String:
	return str(
		STORY_CLUE_BY_PROFILE_ACHIEVEMENT_ID.get(achievement_id, "")
	)


static func _duplicate_entries(source: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in source:
		result.append((entry as Dictionary).duplicate(true))
	return result


static func _entry_ids(source: Array) -> PackedStringArray:
	var result := PackedStringArray()
	for entry in source:
		result.append(str(entry["id"]))
	return result


static func _entry_for(source: Array, entry_id: String) -> Dictionary:
	for entry in source:
		if str(entry["id"]) == entry_id:
			return (entry as Dictionary).duplicate(true)
	return {}
