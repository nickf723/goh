extends "res://scripts/enemies/enemy_squad_tactical_action_brain.gd"
class_name EnemyThreatAwareActionBrain

@export_group("Threat Awareness")
@export var threat_sensor_path: NodePath = NodePath("../EnemyThreatSensor")
@export var threat_score_severity_scale: float = 0.12

var threat_sensor: EnemyThreatSensor
var current_threat: CombatThreat
var last_threat_summary: String = "none"
var last_threat_response: String = "none"


func _ready() -> void:
	super._ready()
	resolve_threat_sensor()


func resolve_threat_sensor() -> void:
	threat_sensor = get_node_or_null(threat_sensor_path) as EnemyThreatSensor


func process_chase(delta: float) -> void:
	if actor != null and player != null and try_threat_response(delta):
		return
	super.process_chase(delta)


func try_threat_response(delta: float) -> bool:
	if threat_sensor == null:
		resolve_threat_sensor()
	if threat_sensor == null or actor == null:
		return false
	threat_sensor.reaction_delay_multiplier = get_personality_number(
		"threat_reaction_delay_multiplier",
		1.0
	)
	var threat: CombatThreat = threat_sensor.get_best_actionable_threat(
		actor.global_position
	)
	if threat == null:
		current_threat = null
		last_threat_summary = "none"
		return false
	last_threat_summary = threat.get_debug_summary()
	var response: EnemyActionOption = select_threat_response(
		get_distance_to_player(),
		threat
	)
	if response == null:
		last_threat_response = "no compatible response"
		return false
	current_threat = threat
	selected_option = response
	last_selection_summary = "react: " + response.get_display_name()
	last_threat_response = response.get_display_name()
	commit_threat_response(delta, response, threat)
	return true


func select_threat_response(
	distance: float,
	threat: CombatThreat
) -> EnemyActionOption:
	_begin_tactical_evaluation()
	var best_option: EnemyActionOption
	var best_score: float = -INF
	for option: EnemyActionOption in action_options:
		if option == null or not option.is_valid_at_distance(distance):
			continue
		if not is_option_available(option):
			continue
		if not option.can_respond_to_threat(threat):
			continue
		var score: float = score_action_option(option, distance)
		score += option.get_threat_score_bonus()
		score += threat.severity * maxf(threat_score_severity_scale, 0.0)
		if score <= best_score:
			continue
		best_option = option
		best_score = score
	last_selection_score = 0.0 if best_option == null else best_score
	_finalize_tactical_decision(best_option)
	return best_option


func commit_threat_response(
	delta: float,
	option: EnemyActionOption,
	threat: CombatThreat
) -> void:
	if option == null or option.get_action() == null:
		reset_attack_commit()
		return
	clear_horizontal_velocity()
	face_player(delta)
	attack_commit_timer += delta
	last_action_summary = (
		"reacting to "
		+ threat.display_name
		+ " with "
		+ option.get_display_name()
	)
	var default_commit_time: float = maxf(
		get_definition().get_attack_commit_time(),
		0.0
	)
	default_commit_time *= get_personality_number(
		"attack_commit_time_multiplier",
		1.0
	)
	var commit_time: float = option.get_threat_commit_time(default_commit_time)
	if attack_commit_timer < commit_time:
		return
	start_selected_action()
	if action_runner != null and action_runner.is_running():
		threat_sensor.acknowledge_threat(threat)
		current_threat = null


func interrupt_current_action(reason: String) -> bool:
	var interrupted: bool = super.interrupt_current_action(reason)
	if interrupted:
		current_threat = null
	return interrupted


func cancel_current_action(reason: String) -> void:
	super.cancel_current_action(reason)
	current_threat = null


func finish_action_state() -> void:
	super.finish_action_state()
	current_threat = null


func get_debug_data() -> Dictionary:
	var debug_data: Dictionary = super.get_debug_data()
	debug_data["threat"] = last_threat_summary
	debug_data["threat_response"] = last_threat_response
	debug_data["threat_time"] = (
		snappedf(current_threat.get_time_until_impact(), 0.01)
		if current_threat != null
		else 0.0
	)
	return debug_data
