extends Resource
class_name EnemyDefinition

@export var enemy_class: EnemyClassDefinition

# When true, this definition inherits that trait group from enemy_class.
# Turn a toggle off when a specific enemy species needs one-off overrides.
@export var use_class_identity: bool = false
@export var use_class_vitals: bool = true
@export var use_class_defenses: bool = true
@export var use_class_movement: bool = true
@export var use_class_pressure: bool = true
@export var use_class_force: bool = true

@export var display_name: String = "Enemy"
@export var species_id: String = "enemy"
@export var faction_id: String = "monsters"
@export var spacing_buffer: float = 0.25
@export var circle_when_waiting_to_attack: bool = true
@export var strafe_speed_multiplier: float = 0.65
@export var strafe_switch_interval: float = 1.2

@export_enum(
	"animal",
	"fantasy_creature",
	"human",
	"undead",
	"spirit",
	"machine",
	"other"
)
var creature_type: String = "fantasy_creature"

@export var tags: Array[String] = ["enemy"]

@export var move_speed: float = 2.2
@export var turn_speed: float = 9.0
@export var gravity: float = 18.0

@export var detection_radius: float = 9.0
@export var lose_interest_radius: float = 14.0
@export var preferred_distance: float = 1.4

# HitReceiver.HitMode numeric values:
# 0 = INVULNERABLE, 1 = STANCE_ONLY, 2 = HEALTH_ONLY, 3 = STANCE_THEN_HEALTH.
@export var hit_mode: int = 2
@export var max_health: int = 4
@export var max_stance: int = 2
@export var resets_stance_after_break: bool = false
@export var disappears_when_defeated: bool = true
@export var restores_mana_when_defeated: int = 0

@export var weak_elements: Array[String] = []
@export var resistant_elements: Array[String] = []
@export var immune_elements: Array[String] = []
@export var weakness_multiplier: float = 2.0
@export var resistance_multiplier: float = 0.5

@export var attack_commit_time: float = 0.12
@export var attack_pressure_range_padding: float = 0.18

@export var force_drag: float = 10.0
@export var max_force_speed: float = 8.0

@export var debug_notes: String = ""


func get_display_name() -> String:
	if use_class_identity and enemy_class != null and display_name == "Enemy":
		return enemy_class.display_name

	return display_name


func get_creature_type() -> String:
	if use_class_identity and enemy_class != null:
		return enemy_class.creature_type

	return creature_type


func get_tags() -> Array[String]:
	var merged_tags: Array[String] = []

	if enemy_class != null:
		append_unique_strings(merged_tags, enemy_class.default_tags)
		append_unique_strings(merged_tags, enemy_class.role_tags)

	append_unique_strings(merged_tags, tags)

	if not merged_tags.has(species_id):
		merged_tags.append(species_id)

	if not merged_tags.has(get_creature_type()):
		merged_tags.append(get_creature_type())

	return merged_tags


func get_hit_mode() -> int:
	if use_class_vitals and enemy_class != null:
		return enemy_class.hit_mode

	return hit_mode


func get_max_health() -> int:
	if use_class_vitals and enemy_class != null:
		return enemy_class.max_health

	return max_health


func get_max_stance() -> int:
	if use_class_vitals and enemy_class != null:
		return enemy_class.max_stance

	return max_stance


func get_resets_stance_after_break() -> bool:
	if use_class_vitals and enemy_class != null:
		return enemy_class.resets_stance_after_break

	return resets_stance_after_break


func get_disappears_when_defeated() -> bool:
	if use_class_vitals and enemy_class != null:
		return enemy_class.disappears_when_defeated

	return disappears_when_defeated


func get_restores_mana_when_defeated() -> int:
	if use_class_vitals and enemy_class != null:
		return enemy_class.restores_mana_when_defeated

	return restores_mana_when_defeated


func get_weak_elements() -> Array[String]:
	if use_class_defenses and enemy_class != null:
		return enemy_class.weak_elements

	return weak_elements


func get_resistant_elements() -> Array[String]:
	if use_class_defenses and enemy_class != null:
		return enemy_class.resistant_elements

	return resistant_elements


func get_immune_elements() -> Array[String]:
	if use_class_defenses and enemy_class != null:
		return enemy_class.immune_elements

	return immune_elements


func get_weakness_multiplier() -> float:
	if use_class_defenses and enemy_class != null:
		return enemy_class.weakness_multiplier

	return weakness_multiplier


func get_resistance_multiplier() -> float:
	if use_class_defenses and enemy_class != null:
		return enemy_class.resistance_multiplier

	return resistance_multiplier


func get_move_speed() -> float:
	if use_class_movement and enemy_class != null:
		return enemy_class.move_speed

	return move_speed


func get_turn_speed() -> float:
	if use_class_movement and enemy_class != null:
		return enemy_class.turn_speed

	return turn_speed


func get_gravity() -> float:
	if use_class_movement and enemy_class != null:
		return enemy_class.gravity

	return gravity


func get_detection_radius() -> float:
	if use_class_movement and enemy_class != null:
		return enemy_class.detection_radius

	return detection_radius


func get_lose_interest_radius() -> float:
	if use_class_movement and enemy_class != null:
		return enemy_class.lose_interest_radius

	return lose_interest_radius


func get_preferred_distance() -> float:
	if use_class_movement and enemy_class != null:
		return enemy_class.preferred_distance

	return preferred_distance


func get_spacing_buffer() -> float:
	if use_class_movement and enemy_class != null:
		return enemy_class.spacing_buffer

	return spacing_buffer


func get_circle_when_waiting_to_attack() -> bool:
	if use_class_movement and enemy_class != null:
		return enemy_class.circle_when_waiting_to_attack

	return circle_when_waiting_to_attack


func get_strafe_speed_multiplier() -> float:
	if use_class_movement and enemy_class != null:
		return enemy_class.strafe_speed_multiplier

	return strafe_speed_multiplier


func get_strafe_switch_interval() -> float:
	if use_class_movement and enemy_class != null:
		return enemy_class.strafe_switch_interval

	return strafe_switch_interval


func get_attack_commit_time() -> float:
	if use_class_pressure and enemy_class != null:
		return enemy_class.attack_commit_time

	return attack_commit_time


func get_attack_pressure_range_padding() -> float:
	if use_class_pressure and enemy_class != null:
		return enemy_class.attack_pressure_range_padding

	return attack_pressure_range_padding


func get_force_drag() -> float:
	if use_class_force and enemy_class != null:
		return enemy_class.force_drag

	return force_drag


func get_max_force_speed() -> float:
	if use_class_force and enemy_class != null:
		return enemy_class.max_force_speed

	return max_force_speed


func get_class_summary() -> String:
	if enemy_class == null:
		return "no class"

	return enemy_class.class_id


func get_pressure_summary() -> String:
	return str(snapped(get_attack_commit_time(), 0.01)) + "s / +" + str(snapped(get_attack_pressure_range_padding(), 0.01))


func get_debug_notes() -> String:
	var notes: Array[String] = []

	if enemy_class != null and enemy_class.debug_notes != "":
		notes.append(enemy_class.debug_notes)

	if debug_notes != "":
		notes.append(debug_notes)

	return " | ".join(notes)


func append_unique_strings(target: Array[String], source: Array[String]) -> void:
	for value: String in source:
		if value == "":
			continue

		if target.has(value):
			continue

		target.append(value)
