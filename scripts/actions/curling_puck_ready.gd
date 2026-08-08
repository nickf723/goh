extends "res://scripts/actions/curling_puck.gd"
class_name CurlingPuckReady

const ReadyTrailScript = preload(
	"res://scripts/actions/curling_ice_trail_ready.gd"
)

# Neutral input sends the puck straight. Holding left or right while casting
# selects the curl direction, letting one spell author straight bridges, curved
# puzzle routes, and momentum runways without a second aiming mode.


func execute(player: Node3D, requested_direction: Vector3) -> void:
	super.execute(player, requested_direction)
	if not active or trail == null or not is_instance_valid(trail):
		return
	_install_ready_trail()
	trail.set_meta("curling_puck_curl_sign", curl_sign)
	trail.set_meta("curling_puck_route_kind", _get_route_kind())


func _install_ready_trail() -> void:
	if trail is CurlingIceTrailReady:
		return
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var old_trail: CurlingIceTrail = trail
	var old_parent: Node = old_trail.get_parent()
	old_trail.force_dissipate("replace_with_ready_trail")
	if old_parent != null and old_trail.get_parent() == old_parent:
		old_parent.remove_child(old_trail)

	var ready_trail: CurlingIceTrailReady = (
		ReadyTrailScript.new() as CurlingIceTrailReady
	)
	ready_trail.trail_width = trail_width
	ready_trail.segment_spacing = trail_segment_spacing
	ready_trail.maximum_segments = trail_maximum_segments
	ready_trail.linger_seconds = trail_linger_seconds
	scene_root.add_child(ready_trail)
	ready_trail.configure(source_actor, cast_serial, self)
	ready_trail.add_sample(global_position, cast_direction)
	trail = ready_trail
	var trail_body: StaticBody3D = ready_trail.get_static_body()
	if trail_body != null:
		_collect_collision_rids(trail_body, collision_exclusions)


func _resolve_curl_sign() -> float:
	if source_actor != null and source_actor.has_meta("clone_cast_curl_sign"):
		return clampf(
			float(source_actor.get_meta("clone_cast_curl_sign", 0.0)),
			-1.0,
			1.0
		)
	var left_strength: float = Input.get_action_strength("move_left")
	var right_strength: float = Input.get_action_strength("move_right")
	if left_strength > right_strength + 0.12:
		return -1.0
	if right_strength > left_strength + 0.12:
		return 1.0
	return 0.0


func _get_route_kind() -> String:
	if curl_sign < -0.5:
		return "left_curl"
	if curl_sign > 0.5:
		return "right_curl"
	return "straight"


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["player_selected_curl"] = true
	data["neutral_cast_is_straight"] = true
	data["clone_preserves_curl_intent"] = true
	data["route_kind"] = _get_route_kind()
	data["trail_records_curl"] = (
		trail != null
		and is_instance_valid(trail)
		and trail.has_meta("curling_puck_curl_sign")
	)
	data["ready_trail_interactions"] = trail is CurlingIceTrailReady
	data["transient_duplicate_trail"] = false
	return data
