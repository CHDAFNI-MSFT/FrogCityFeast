class_name DiscoveryCatalog
extends RefCounted

const ENTRIES := [
	{
		"id": "street_donut",
		"name": "Street Donut",
		"hint": "Look along the streets near Moonlight Market.",
	},
	{
		"id": "market_apple",
		"name": "Market Apple",
		"hint": "Search inside Moonlight Market.",
	},
	{
		"id": "running_hotdog",
		"name": "Runaway Hot Dog",
		"hint": "Watch for a snack that refuses to stay still.",
	},
	{
		"id": "shop_phone",
		"name": "Loose Phone",
		"hint": "Visit Leap Cafe after growing once.",
	},
	{
		"id": "cafe_stockroom_coffee_tin",
		"name": "Stockroom Coffee Tin",
		"hint": "Find the marked rear door inside Leap Cafe.",
	},
	{
		"id": "leap_cafe_menu_board",
		"name": "Sidewalk Menu Board",
		"hint": "Start outside Leap Cafe at its sidewalk menu.",
	},
	{
		"id": "leap_cafe_espresso_counter",
		"name": "Rear Espresso Counter",
		"hint": "Remove the menu board, grow once, and enter the cafe.",
	},
	{
		"id": "leap_cafe_awning",
		"name": "Front Awning",
		"hint": "Wrestle out the counter before stripping the awning.",
	},
	{
		"id": "leap_cafe_building",
		"name": "Leap Cafe",
		"hint": "Remove all three cafe parts and reach maximum size.",
	},
	{
		"id": "park_chair",
		"name": "Park Chair",
		"hint": "Explore River Park after growing once.",
	},
	{
		"id": "golden_cake",
		"name": "Flying Golden Cake",
		"hint": "Search the northern city for a rare moving treat.",
	},
	{
		"id": "delivery_van",
		"name": "Delivery Van",
		"hint": "Become enormous before challenging city traffic.",
	},
	{
		"id": "market_vendor",
		"name": "Market Vendor",
		"hint": "Moonlight Market has someone difficult to catch.",
	},
	{
		"id": "canal_lobby_lamp",
		"name": "Lobby Lamp",
		"hint": "Step inside Canal Apartments and search the back wall.",
	},
	{
		"id": "canal_tenant_cat",
		"name": "Tenant's Cat",
		"hint": "Grow once, then win a struggle in the apartment lobby.",
	},
	{
		"id": "canal_upper_hall_vacuum",
		"name": "Hallway Vacuum",
		"hint": "Take the marked stairs inside Canal Apartments.",
	},
	{
		"id": "canal_apartments_address_plaque",
		"name": "Address Plaque",
		"hint": "Start dismantling Canal Apartments from the canal-side street.",
	},
	{
		"id": "canal_apartments_lobby_bench",
		"name": "Lobby Bench",
		"hint": "Remove the plaque, grow once, and enter the apartment lobby.",
	},
	{
		"id": "canal_apartments_entry_canopy",
		"name": "Entry Canopy",
		"hint": "Wrestle out the lobby bench before stripping the canopy.",
	},
	{
		"id": "canal_apartments_building",
		"name": "Canal Apartments",
		"hint": "Remove all three apartment parts and reach maximum size.",
	},
	{
		"id": "moonlight_market_sign",
		"name": "Market Sign",
		"hint": "Start dismantling Moonlight Market from outside.",
	},
	{
		"id": "moonlight_market_door",
		"name": "Market Door",
		"hint": "Grow once, then pull open Moonlight Market.",
	},
	{
		"id": "moonlight_market_counter",
		"name": "Market Counter",
		"hint": "Enter the weakened market and eat its counter.",
	},
	{
		"id": "moonlight_market_building",
		"name": "Moonlight Market",
		"hint": "Remove all three market parts and reach maximum size.",
	},
	{
		"id": "oddities_shop_door",
		"name": "Shop Shutter",
		"hint": "The Oddities Shop shutter lifts off at any size.",
	},
	{
		"id": "oddities_shop_counter",
		"name": "Curio Shelf",
		"hint": "Enter the open shop and win a struggle with its shelf.",
	},
	{
		"id": "oddities_shop_sign",
		"name": "Shop Banner",
		"hint": "Grow once, then strip the banner from the Oddities Shop.",
	},
	{
		"id": "oddities_shop_building",
		"name": "Oddities Shop",
		"hint": "Remove all three shop parts and reach maximum size.",
	},
	{
		"id": "animal_control",
		"name": "Animal Control Officer",
		"hint": "At maximum size, let a resistant target escape, then eat what comes looking.",
	},
]


static func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in ENTRIES:
		result.append((entry as Dictionary).duplicate(true))
	return result


static func ids() -> PackedStringArray:
	var result := PackedStringArray()
	for entry in ENTRIES:
		result.append(str(entry["id"]))
	return result


static func count() -> int:
	return ENTRIES.size()


static func entry_for(target_id: String) -> Dictionary:
	for entry in ENTRIES:
		if str(entry["id"]) == target_id:
			return (entry as Dictionary).duplicate(true)
	return {}
