extends "res://scripts/enemies/enemy_threat_aware_action_brain.gd"
class_name EnemyPerceptionInvestigationBrain

enum AwarenessState {
	UNAWARE,
	SUSPICIOUS,
	INVESTIGATING,
	ALERTED,
	SEARCHING,
	RETURNING,
}

const PERCEPTION_PERSONALITIES: Dictionary = {
	"balanced": {
		"vision": 1.0,
		"hearing": 1.0,
		"suspicion": 1.0,
		"investigation_speed": 1.0,
		"search_time": 1.0,
		"memory": 1.0,
	},
	"cautious": {
		"vision": 1.08,
		"hearing": 1.15,
		"suspicion": 0.88,
		"investigation_speed": 0.78,
		"search_time": 1.25,
		"memory": 1.22,
	},
	"bold": {
		"vision": 1.0,
		"hearing": 0.88,
		"suspicion": 1.2,
		"investigation_speed": 1.22,
		"search_time": 0.82,
		"memory": 0.95,
	},
	"skittish": {
		"vision": 1.12,
		"hearing": 1.48,
		"suspicion": 1.38,
		"investigation_speed": 1.12,
		"search_time": 1.42,
		"memory": 1.1,
	},
	"brute": {
		"vision": 0.78,
		"hearing": 0.68,
		"suspicion": 0.62,
		"investigation_speed": 0.72,
		"search_time": 0.62,
		"memory": 0.75,
	},
}

@export_group("Perception")
@export var perception_sensor_path: NodePath = NodePath("../EnemyPerceptionSensor")
@export_range(0.05, 4.0, 0.05) var visual_suspicion_gain_per_second: float = 1.05
@export_range(0.0, 4.0, 0.05) var suspicion_decay_per_second: float = 0.22
@export_range(0.1, 2.0, 0.05) var alert_threshold: float = 1.0
@export_range(0.1, 20.0, 0.1) var instant_alert_distance: float = 2.3
@export_range(0.1, 10.0, 0.1) var heard_suspicion_gain: float = 0.72
@export_range(0.1, 10.0, 0.1) var strong_sound_intensity: float = 0.62

@export_group("Memory and Investigation")
@export_range(0.2, 20.0, 0.1) var target_memory_seconds: float = 3.6
@export_range(0.2, 20.0, 0.1) var investigation_timeout: float = 6.0
@export_range(0.2, 20.0, 0.1) var search_duration: float = 4.0
@export_range(0.2, 5.0, 0.1) var investigation_arrival_distance: float = 0.9
@export_range(0.2, 8.0, 0.1) var search_radius: float = 1.8
@export_range(0.1, 8.0, 0.1) var search_turn_speed: float = 1.65
@export_range(0.1, 5.0, 0.1) var return_arrival_distance: float = 0.75

@export_group("Engagement")
@export var allow_combat: bool = true
@export_range(0.5, 10.0, 0.1) var noncombat_stop_distance: float = 2.8
@export var return_home_after_search: bool = true

var awareness_state: AwarenessState = AwarenessState.UNAWARE
var perception_sensor: EnemyPerceptionSensor = null
var suspicion: float = 0.0
var last_known_position: Vector3 = Vector3.ZERO
var home_position: Vector3 = Vector3.ZERO
var memory_timer: float = 0.0
var investigation_timer: float = 0.0
var search_timer: float = 0.0
var search_phase: float = 0.0
var last_processed_stimulus_id: int = 0
var last_heard_summary: String = "none"
var last_awareness_reason: String = "none"
var observation: Dictionary = {}


func _ready() -> void:
	super._ready()
	resolve_perception_sensor()
	if actor != null:
		home_position = actor.global_position
		last_known_position = home_position
	configure_sensor_personality()


func _physics_process(delta: float) -> void:
	if perception_sensor == null:
		resolve_perception_sensor()
	if perception_sensor != null:
		perception_sensor.set_target(player)
		configure_sensor_personality()
		observation = perception_sensor.sample_now(delta)
	update_awareness(delta)
	super._physics_process(delta)


func resolve_perception_sensor() -> void:
	perception_sensor = get_node_or_null(perception_sensor_path) as EnemyPerceptionSensor


func configure_sensor_personality() -> void:
	if perception_sensor == null:
		return
	perception_sensor.vision_multiplier = get_perception_multiplier("vision", 1.0)
	perception_sensor.hearing_multiplier = get_perception_multiplier("hearing", 1.0)


func update_awareness(delta: float) -> void:
	var target_visible: bool = bool(observation.get("target_visible", false))
	var visibility: float = float(observation.get("visibility_strength", 0.0))
	var distance: float = float(observation.get("target_distance", INF))
	var heard: Dictionary = observation.get("heard", {}) as Dictionary

	if target_visible and player != null:
		last_known_position = player.global_position
		memory_timer = target_memory_seconds * get_perception_multiplier("memory", 1.0)
		var gain: float = visual_suspicion_gain_per_second * visibility
		gain *= get_perception_multiplier("suspicion", 1.0)
		suspicion = clampf(suspicion + gain * delta, 0.0, alert_threshold)
		if distance <= instant_alert_distance or suspicion >= alert_threshold:
			enter_alerted("saw Grace")
		elif awareness_state != AwarenessState.ALERTED:
			set_awareness_state(AwarenessState.SUSPICIOUS, "partial visual")
	else:
		process_heard_stimulus(heard)
		if awareness_state == AwarenessState.ALERTED:
			memory_timer = max(memory_timer - delta, 0.0)
			if memory_timer <= 0.0:
				begin_search("visual memory expired")
		elif awareness_state == AwarenessState.SUSPICIOUS and heard.is_empty():
			suspicion = max(suspicion - suspicion_decay_per_second * delta, 0.0)
			if suspicion <= 0.01:
				set_awareness_state(AwarenessState.UNAWARE, "suspicion cleared")

	if awareness_state == AwarenessState.INVESTIGATING:
		investigation_timer = max(investigation_timer - delta, 0.0)
		if investigation_timer <= 0.0:
			begin_search("investigation timed out")
	elif awareness_state == AwarenessState.SEARCHING:
		search_timer = max(search_timer - delta, 0.0)
		if search_timer <= 0.0:
			if return_home_after_search:
				set_awareness_state(AwarenessState.RETURNING, "search exhausted")
			else:
				set_awareness_state(AwarenessState.UNAWARE, "search exhausted")


func process_heard_stimulus(heard: Dictionary) -> void:
	if heard.is_empty():
		return
	var stimulus_id: int = int(heard.get("id", 0))
	if stimulus_id <= 0 or stimulus_id == last_processed_stimulus_id:
		return
	last_processed_stimulus_id = stimulus_id
	var intensity: float = float(heard.get("intensity", 0.0))
	var position_value: Vector3 = heard.get("position", actor.global_position if actor != null else Vector3.ZERO) as Vector3
	last_known_position = position_value
	last_heard_summary = str(heard.get("display_name", heard.get("category", "sound")))
	var gain: float = intensity * heard_suspicion_gain * get_perception_multiplier("suspicion", 1.0)
	suspicion = clampf(suspicion + gain, 0.0, alert_threshold * 0.92)
	investigation_timer = investigation_timeout
	if awareness_state == AwarenessState.ALERTED:
		memory_timer = max(memory_timer, target_memory_seconds * 0.5)
		last_awareness_reason = "heard " + last_heard_summary
		return
	set_awareness_state(AwarenessState.INVESTIGATING, "heard " + last_heard_summary)
	if intensity >= strong_sound_intensity:
		suspicion = max(suspicion, alert_threshold * 0.72)


func enter_alerted(reason: String) -> void:
	suspicion = alert_threshold
	set_awareness_state(AwarenessState.ALERTED, reason)
	change_state(EnemyState.CHASE)


func begin_search(reason: String) -> void:
	search_timer = search_duration * get_perception_multiplier("search_time", 1.0)
	search_phase = 0.0
	set_awareness_state(AwarenessState.SEARCHING, reason)
	change_state(EnemyState.IDLE)


func set_awareness_state(new_state: AwarenessState, reason: String) -> void:
	if awareness_state == new_state:
		last_awareness_reason = reason
		return
	awareness_state = new_state
	last_awareness_reason = reason
	if new_state != AwarenessState.ALERTED and state == EnemyState.CHASE:
		change_state(EnemyState.IDLE)


func process_idle(delta: float) -> void:
	reset_attack_commit()
	match awareness_state:
		AwarenessState.UNAWARE:
			clear_horizontal_velocity()
			last_action_summary = "unaware"
		AwarenessState.SUSPICIOUS:
			clear_horizontal_velocity()
			face_world_position(last_known_position, delta)
			last_action_summary = "suspicious: watching " + format_position(last_known_position)
		AwarenessState.INVESTIGATING:
			if move_toward_world_position(last_known_position, delta, investigation_arrival_distance):
				begin_search("reached sound source")
			else:
				last_action_summary = "investigating " + last_heard_summary
		AwarenessState.ALERTED:
			change_state(EnemyState.CHASE)
		AwarenessState.SEARCHING:
			process_search(delta)
		AwarenessState.RETURNING:
			if move_toward_world_position(home_position, delta, return_arrival_distance):
				suspicion = 0.0
				set_awareness_state(AwarenessState.UNAWARE, "returned home")
			else:
				last_action_summary = "returning to post"


func process_chase(delta: float) -> void:
	var target_visible: bool = bool(observation.get("target_visible", false))
	if not target_visible:
		if memory_timer > 0.0:
			move_toward_world_position(last_known_position, delta, investigation_arrival_distance)
			last_action_summary = "pursuing last known position"
			return
		begin_search("lost Grace")
		return

	if allow_combat:
		super.process_chase(delta)
		return
	var distance: float = get_distance_to_player()
	if distance > noncombat_stop_distance:
		move_toward_player(delta)
		last_action_summary = "alerted pursuit without attacks"
	else:
		clear_horizontal_velocity()
		face_player(delta)
		last_action_summary = "alerted observation"


func process_search(delta: float) -> void:
	clear_horizontal_velocity()
	search_phase += delta * search_turn_speed
	var offset := Vector3(cos(search_phase), 0.0, sin(search_phase)) * search_radius
	face_world_position(last_known_position + offset, delta)
	last_action_summary = "searching around last known position"


func move_toward_world_position(destination: Vector3, delta: float, arrival_distance: float) -> bool:
	if actor == null:
		return true
	var direction: Vector3 = destination - actor.global_position
	direction.y = 0.0
	var distance: float = direction.length()
	if distance <= arrival_distance:
		clear_horizontal_velocity()
		return true
	direction = get_zone_adjusted_direction(direction.normalized())
	var speed: float = get_definition().get_move_speed() * get_status_move_multiplier()
	speed *= get_personality_number("move_speed_multiplier", 1.0)
	speed *= get_perception_multiplier("investigation_speed", 1.0)
	actor.velocity.x = direction.x * speed
	actor.velocity.z = direction.z * speed
	face_direction(direction, delta)
	return false


func face_world_position(destination: Vector3, delta: float) -> void:
	if actor == null:
		return
	var direction: Vector3 = destination - actor.global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		return
	face_direction(direction.normalized(), delta)


func get_perception_multiplier(key: String, fallback: float) -> float:
	var profile_id: String = personality_id.to_lower().strip_edges()
	var profile: Dictionary = PERCEPTION_PERSONALITIES.get(profile_id, PERCEPTION_PERSONALITIES["balanced"]) as Dictionary
	return float(profile.get(key, fallback))


func format_position(position_value: Vector3) -> String:
	return "(" + str(snapped(position_value.x, 0.1)) + ", " + str(snapped(position_value.z, 0.1)) + ")"


func get_awareness_state_name() -> String:
	return AwarenessState.keys()[awareness_state]


func reset_perception() -> void:
	awareness_state = AwarenessState.UNAWARE
	suspicion = 0.0
	last_known_position = home_position
	memory_timer = 0.0
	investigation_timer = 0.0
	search_timer = 0.0
	search_phase = 0.0
	last_processed_stimulus_id = 0
	last_heard_summary = "none"
	last_awareness_reason = "reset"
	change_state(EnemyState.IDLE)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["awareness"] = get_awareness_state_name()
	data["suspicion"] = snapped(suspicion, 0.01)
	data["visible"] = bool(observation.get("target_visible", false))
	data["visibility"] = snapped(float(observation.get("visibility_strength", 0.0)), 0.01)
	data["smoke"] = snapped(float(observation.get("smoke_density", 0.0)), 0.01)
	data["heard"] = last_heard_summary
	data["last_known"] = last_known_position
	data["memory"] = snapped(memory_timer, 0.1)
	data["reason"] = last_awareness_reason
	return data
