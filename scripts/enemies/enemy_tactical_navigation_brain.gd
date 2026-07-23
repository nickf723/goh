extends "res://scripts/enemies/enemy_perception_investigation_brain.gd"
class_name EnemyTacticalNavigationBrain

@export_group("Tactical Navigation")
@export var tactical_navigation_path: NodePath = NodePath("../TacticalNavigationAgent")
@export var use_tactical_navigation: bool = true

var tactical_navigation: TacticalNavigationAgent = null


func _ready() -> void:
	super._ready()
	resolve_tactical_navigation()
	configure_tactical_navigation()


func resolve_tactical_navigation() -> void:
	tactical_navigation = get_node_or_null(tactical_navigation_path) as TacticalNavigationAgent


func configure_tactical_navigation() -> void:
	if tactical_navigation == null:
		return
	tactical_navigation.personality_id = personality_id


func investigate_world_position(world_position: Vector3, evidence_name: String = "evidence") -> void:
	last_known_position = world_position
	last_heard_summary = evidence_name
	last_awareness_reason = "assigned " + evidence_name
	suspicion = max(suspicion, alert_threshold * 0.72)
	investigation_timer = investigation_timeout
	set_awareness_state(AwarenessState.INVESTIGATING, last_awareness_reason)
	change_state(EnemyState.IDLE)
	if tactical_navigation != null:
		tactical_navigation.force_replan()


func move_toward_player(delta: float) -> void:
	if player == null:
		clear_horizontal_velocity()
		return
	move_toward_world_position(player.global_position, delta, noncombat_stop_distance)


func move_toward_world_position(destination: Vector3, delta: float, arrival_distance: float) -> bool:
	if actor == null:
		return true
	var offset: Vector3 = destination - actor.global_position
	offset.y = 0.0
	if offset.length() <= arrival_distance:
		clear_horizontal_velocity()
		if tactical_navigation != null:
			tactical_navigation.clear_destination()
		return true

	if not use_tactical_navigation:
		return super.move_toward_world_position(destination, delta, arrival_distance)
	if tactical_navigation == null:
		resolve_tactical_navigation()
		configure_tactical_navigation()
	if tactical_navigation == null:
		return super.move_toward_world_position(destination, delta, arrival_distance)

	var direction: Vector3 = tactical_navigation.get_next_direction(destination, delta)
	if direction.length_squared() <= 0.0001:
		clear_horizontal_velocity()
		last_action_summary = "waiting for navigation path"
		return false

	var speed: float = get_definition().get_move_speed() * get_status_move_multiplier()
	speed *= get_personality_number("move_speed_multiplier", 1.0)
	speed *= get_perception_multiplier("investigation_speed", 1.0)
	actor.velocity.x = direction.x * speed
	actor.velocity.z = direction.z * speed
	face_direction(direction, delta)
	return false


func reset_perception() -> void:
	super.reset_perception()
	if tactical_navigation != null:
		tactical_navigation.clear_destination()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	if tactical_navigation != null:
		var navigation_data: Dictionary = tactical_navigation.get_debug_data()
		data["route"] = navigation_data.get("route", "none")
		data["route_score"] = navigation_data.get("score", "inf")
		data["route_distance"] = navigation_data.get("distance", 0.0)
		data["route_hazard"] = navigation_data.get("hazard_cost", 0.0)
		data["route_stuck"] = navigation_data.get("stuck", 0.0)
		data["route_replans"] = navigation_data.get("replans", 0)
		data["route_summary"] = navigation_data.get("summary", "unplanned")
	return data
