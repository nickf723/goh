extends Resource
class_name ElementalAuthorityProfile

@export_group("Identity")
@export var authority_id: String = "elemental_authority"
@export var display_name: String = "Elemental Authority"
@export var element: String = "neutral"
@export_multiline var description: String = ""

@export_group("Matching-Element Defense")
@export_range(0.0, 2.0, 0.05) var incoming_damage_multiplier: float = 1.0
@export_range(0.0, 2.0, 0.05) var incoming_stance_multiplier: float = 1.0
@export var blocked_statuses: Array[String] = []
@export var matching_hazards_are_traversable: bool = false

@export_group("Matching-Element Spell Authority")
@export_range(0.0, 2.0, 0.05) var mana_cost_multiplier: float = 1.0
@export_range(0, 8, 1) var mana_cost_flat_reduction: int = 0
@export_range(0, 8, 1) var minimum_mana_cost: int = 0
@export_range(0.0, 4.0, 0.05) var spell_damage_multiplier: float = 1.0
@export_range(0.0, 4.0, 0.05) var spell_stance_multiplier: float = 1.0
@export_range(0.0, 4.0, 0.05) var status_duration_multiplier: float = 1.0
@export_range(0.0, 4.0, 0.05) var status_strength_multiplier: float = 1.0
@export_range(0.1, 3.0, 0.05) var projectile_speed_multiplier: float = 1.0
@export_range(0.0, 4.0, 0.05) var field_radius_bonus: float = 0.0
@export_range(0.0, 10.0, 0.1) var field_lifetime_bonus: float = 0.0

@export_group("Weapon-Spell Weaving")
@export_range(0.02, 1.0, 0.01) var standard_cast_lock_duration: float = 0.16
@export_range(0.02, 1.0, 0.01) var quick_weave_lock_duration: float = 0.09
@export_range(0.05, 2.0, 0.01) var weave_window_seconds: float = 0.5
@export_range(0.0, 4.0, 0.05) var owned_field_flare_radius_bonus: float = 0.75
@export_range(0.0, 5.0, 0.05) var owned_field_flare_lifetime_bonus: float = 0.8
@export_range(0.0, 3.0, 0.05) var owned_field_flare_strength_bonus: float = 0.45
@export_range(0.3, 3.0, 0.05) var thrust_wake_radius: float = 1.05
@export_range(0.2, 5.0, 0.05) var thrust_wake_lifetime: float = 1.35
@export_range(0.2, 2.0, 0.05) var thrust_wake_spacing: float = 0.72
@export_range(0, 8, 1) var thrust_wake_max_segments: int = 4


func matches_element(candidate_element: String) -> bool:
	return (
		element.strip_edges() != ""
		and candidate_element.strip_edges().to_lower() == element.strip_edges().to_lower()
	)


func blocks_status(status_name: String) -> bool:
	var normalized_status: String = status_name.strip_edges().to_lower()
	for blocked_status: String in blocked_statuses:
		if blocked_status.strip_edges().to_lower() == normalized_status:
			return true
	return false


func get_modified_mana_cost(base_cost: int) -> int:
	var scaled_cost: int = ceili(float(maxi(base_cost, 0)) * maxf(mana_cost_multiplier, 0.0))
	return maxi(scaled_cost - maxi(mana_cost_flat_reduction, 0), maxi(minimum_mana_cost, 0))


func validate_profile() -> Array[String]:
	var failures: Array[String] = []
	if authority_id.strip_edges() == "":
		failures.append("elemental authority id must not be empty")
	if display_name.strip_edges() == "":
		failures.append(authority_id + ": display name must not be empty")
	if element.strip_edges() == "":
		failures.append(authority_id + ": element must not be empty")
	if incoming_damage_multiplier < 0.0:
		failures.append(authority_id + ": incoming damage multiplier must not be negative")
	if incoming_stance_multiplier < 0.0:
		failures.append(authority_id + ": incoming stance multiplier must not be negative")
	if spell_damage_multiplier < 0.0 or spell_stance_multiplier < 0.0:
		failures.append(authority_id + ": outgoing spell multipliers must not be negative")
	if projectile_speed_multiplier <= 0.0:
		failures.append(authority_id + ": projectile speed multiplier must be positive")
	if standard_cast_lock_duration <= 0.0 or quick_weave_lock_duration <= 0.0:
		failures.append(authority_id + ": cast lock durations must be positive")
	if thrust_wake_spacing <= 0.0:
		failures.append(authority_id + ": thrust wake spacing must be positive")
	return failures


func get_debug_summary() -> Dictionary:
	return {
		"authority_id": authority_id,
		"display_name": display_name,
		"element": element,
		"incoming_damage_multiplier": incoming_damage_multiplier,
		"incoming_stance_multiplier": incoming_stance_multiplier,
		"blocked_statuses": blocked_statuses.duplicate(),
		"hazard_traversal": matching_hazards_are_traversable,
		"mana_cost_multiplier": mana_cost_multiplier,
		"spell_damage_multiplier": spell_damage_multiplier,
		"spell_stance_multiplier": spell_stance_multiplier,
		"status_duration_multiplier": status_duration_multiplier,
		"status_strength_multiplier": status_strength_multiplier,
		"projectile_speed_multiplier": projectile_speed_multiplier,
		"field_radius_bonus": field_radius_bonus,
		"field_lifetime_bonus": field_lifetime_bonus,
	}
