extends Node3D
class_name TacticalNavigationHazard

@export var hazard_id: String = "navigation_hazard"
@export var lane_id: String = ""
@export var active: bool = true
@export var behavior: String = "danger"
@export_range(0.1, 12.0, 0.1) var radius: float = 2.0
@export_range(0.0, 50.0, 0.1) var cost_per_meter: float = 2.0
@export_range(0.1, 6.0, 0.05) var falloff_exponent: float = 1.4
@export var impassable: bool = false
@export_range(100.0, 100000.0, 100.0) var impassable_cost: float = 10000.0

const PERSONALITY_COST_MULTIPLIERS: Dictionary = {
	"balanced": 0.9,
	"cautious": 2.2,
	"bold": 0.25,
	"skittish": 3.0,
	"brute": 0.05,
	"opportunist": 0.75,
}

var revision: int = 0


func _ready() -> void:
	add_to_group("tactical_navigation_hazards")
	add_to_group("debuggable")
	if hazard_id.strip_edges() == "":
		hazard_id = name


func set_hazard_active(value: bool) -> void:
	if active == value:
		return
	active = value
	revision += 1


func toggle_hazard() -> bool:
	set_hazard_active(not active)
	return active


func matches_lane(requested_lane_id: String) -> bool:
	return lane_id == "" or requested_lane_id == "" or lane_id == requested_lane_id


func get_cost_at_position(world_position: Vector3, personality_id: String = "balanced") -> float:
	if not active:
		return 0.0
	var horizontal_offset: Vector3 = world_position - global_position
	horizontal_offset.y = 0.0
	var distance: float = horizontal_offset.length()
	var safe_radius: float = max(radius, 0.1)
	if distance >= safe_radius:
		return 0.0
	if impassable:
		return impassable_cost
	var normalized_weight: float = clampf(1.0 - distance / safe_radius, 0.0, 1.0)
	var weight: float = pow(normalized_weight, max(falloff_exponent, 0.1))
	return cost_per_meter * weight * get_personality_multiplier(personality_id)


func get_personality_multiplier(personality_id: String) -> float:
	var normalized: String = personality_id.to_lower().strip_edges()
	return float(PERSONALITY_COST_MULTIPLIERS.get(normalized, PERSONALITY_COST_MULTIPLIERS["balanced"]))


func get_debug_data() -> Dictionary:
	return {
		"tactical_navigation_hazard": hazard_id,
		"lane": lane_id,
		"active": active,
		"behavior": behavior,
		"radius": radius,
		"cost_per_meter": cost_per_meter,
		"impassable": impassable,
		"revision": revision,
	}
