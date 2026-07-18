extends Resource
class_name EnemyActionOption

# New actions should use `action`. `attack` remains as a compatibility bridge for
# existing option resources created before defensive actions existed.
@export var action: EnemyCombatActionDefinition
@export var attack: EnemyAttackDefinition
@export var presentation: EnemyActionPresentation

@export_group("Selection")
@export var selection_role: String = "melee"
@export var minimum_start_distance: float = 0.0
@export var maximum_start_distance: float = 1.5
@export var selection_weight: float = 1.0
@export var can_interrupt_post_miss_retreat: bool = false

@export_group("Threat Response")
@export var responds_to_threats: bool = false
@export var threat_required_tags: Array[String] = []
@export var threat_any_tags: Array[String] = []
@export var minimum_threat_time_to_impact: float = 0.0
@export var maximum_threat_time_to_impact: float = 999.0
@export var threat_score_bonus: float = 0.0
@export var threat_commit_time_override: float = -1.0

@export_group("Contact")
@export var contact_range_override: float = -1.0
@export var stop_movement_on_hit: bool = false

@export_group("Cooldown")
@export var reuse_cooldown_override: float = -1.0

@export_group("Debug")
@export var debug_label: String = ""


func get_action() -> EnemyCombatActionDefinition:
	if action != null:
		return action

	return attack


func is_valid_at_distance(distance: float) -> bool:
	if get_action() == null:
		return false

	return distance >= get_minimum_start_distance() and distance <= get_maximum_start_distance()


func can_respond_to_threat(threat: CombatThreat) -> bool:
	if not responds_to_threats or threat == null or threat.is_expired():
		return false
	if not threat.matches_all_tags(threat_required_tags):
		return false
	if not threat.matches_any_tag(threat_any_tags):
		return false

	var time_until_impact: float = threat.get_time_until_impact()
	return (
		time_until_impact >= max(minimum_threat_time_to_impact, 0.0)
		and time_until_impact <= max(maximum_threat_time_to_impact, minimum_threat_time_to_impact)
	)


func get_minimum_start_distance() -> float:
	return max(minimum_start_distance, 0.0)


func get_maximum_start_distance() -> float:
	var minimum: float = get_minimum_start_distance()
	return max(maximum_start_distance, minimum)


func get_contact_range() -> float:
	if contact_range_override > 0.0:
		return contact_range_override

	var attack_action: EnemyAttackDefinition = get_action() as EnemyAttackDefinition
	return attack_action.get_range() if attack_action != null else 0.0


func get_selection_weight() -> float:
	return max(selection_weight, 0.0)


func get_threat_score_bonus() -> float:
	return threat_score_bonus


func get_threat_commit_time(default_commit_time: float) -> float:
	if threat_commit_time_override >= 0.0:
		return threat_commit_time_override
	return max(default_commit_time, 0.0)


func get_reuse_cooldown() -> float:
	if reuse_cooldown_override >= 0.0:
		return reuse_cooldown_override

	var combat_action: EnemyCombatActionDefinition = get_action()
	return combat_action.get_cooldown() if combat_action != null else 0.0


func get_display_name() -> String:
	if debug_label != "":
		return debug_label

	var combat_action: EnemyCombatActionDefinition = get_action()
	return combat_action.get_display_name() if combat_action != null else "No Action"


func get_action_kind() -> String:
	var combat_action: EnemyCombatActionDefinition = get_action()
	return combat_action.get_action_kind() if combat_action != null else "none"


func is_attack_option() -> bool:
	return get_action() is EnemyAttackDefinition


func is_defensive_option() -> bool:
	return get_action() is EnemyDefenseDefinition


func get_role_tags() -> Array[String]:
	var combat_action: EnemyCombatActionDefinition = get_action()
	if combat_action == null:
		var empty_tags: Array[String] = []
		return empty_tags

	return combat_action.get_role_tags()


func apply_presentation(telegraph: Node) -> void:
	if presentation != null:
		presentation.apply_to(telegraph)
