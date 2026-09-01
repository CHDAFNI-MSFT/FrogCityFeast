class_name GameplayTuning
extends RefCounted

const LARGE_TIER := 2
const ENORMOUS_TIER := 3
const WHOLE_BUILDING_EDIBLE_TIER := LARGE_TIER
const PURSUER_EDIBLE_TIER := ENORMOUS_TIER

const GROWTH_THRESHOLDS := [100, 500, 1700]
const FROG_TIER_SCALES := [1.0, 1.25, 1.58, 2.35]
const FROG_TIER_RADII := [28.0, 35.0, 44.0, 66.0]
const FROG_TIER_SPEEDS := [330.0, 345.0, 355.0, 320.0]
const FROG_TIER_TONGUE_RANGES := [380.0, 500.0, 650.0, 900.0]
const CITY_CAMERA_ZOOMS := [0.9, 0.86, 0.78, 0.62]
const CITY_CAMERA_FORWARD_OFFSETS := [220.0, 230.0, 250.0, 320.0]

const TONGUE_RECOVERY := 0.38
const STRUGGLE_DURATION := 3.4
const MIN_STRUGGLE_TAPS := 4

const SCORE_SIZE_BONUS_PER_TIER := 0.35
const SCORE_ACCURACY_BONUS := 0.45
const SCORE_RARE_BONUS := 0.80
const SCORE_DANGER_BONUS := 0.30
const SCORE_PURSUIT_BONUS := 0.45

const GROWTH_SIZE_MULTIPLIERS := [1.0, 1.10, 1.25, 1.35]
const RARE_GROWTH_BONUS := 45

const VEHICLE_COLLISION_PENALTY := 10
const ANIMAL_CONTROL_CONTACT_PENALTY := 20
const ANIMAL_CONTROL_NET_PENALTY := 22
const ANIMAL_CONTROL_TRAP_PENALTY := 12
const SECURITY_CONTACT_PENALTY := 16
const SECURITY_FLASHLIGHT_PENALTY := 10
const WATCHDOG_CONTACT_PENALTY := 12
const WATCHDOG_LUNGE_PENALTY := 14


static func score_value(
	base_value: int,
	size_tier: int,
	accuracy: float,
	rare: bool,
	dangerous_location: bool,
	captured_while_chased: bool
) -> int:
	var multiplier := 1.0
	multiplier += float(maxi(0, size_tier)) * SCORE_SIZE_BONUS_PER_TIER
	multiplier += clampf(accuracy, 0.0, 1.0) * SCORE_ACCURACY_BONUS
	if rare:
		multiplier += SCORE_RARE_BONUS
	if dangerous_location:
		multiplier += SCORE_DANGER_BONUS
	if captured_while_chased:
		multiplier += SCORE_PURSUIT_BONUS
	return maxi(1, roundi(float(base_value) * multiplier))


static func growth_value(
	base_value: int,
	size_tier: int,
	rare: bool
) -> int:
	var multiplier_index := clampi(
		size_tier,
		0,
		GROWTH_SIZE_MULTIPLIERS.size() - 1
	)
	var value := roundi(
		float(base_value) * GROWTH_SIZE_MULTIPLIERS[multiplier_index]
	)
	if rare:
		value += RARE_GROWTH_BONUS
	return maxi(1, value)


static func struggle_taps_required(
	authored_taps: int,
	target_size_tier: int,
	frog_growth_tier: int
) -> int:
	var size_advantage := maxi(
		0,
		frog_growth_tier - target_size_tier
	)
	return maxi(MIN_STRUGGLE_TAPS, authored_taps - size_advantage)


static func city_camera_zoom(growth_tier: int) -> Vector2:
	var index := clampi(growth_tier, 0, CITY_CAMERA_ZOOMS.size() - 1)
	return Vector2.ONE * CITY_CAMERA_ZOOMS[index]


static func city_camera_forward_offset(growth_tier: int) -> float:
	var index := clampi(
		growth_tier,
		0,
		CITY_CAMERA_FORWARD_OFFSETS.size() - 1
	)
	return CITY_CAMERA_FORWARD_OFFSETS[index]
