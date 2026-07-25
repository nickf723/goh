extends Node
class_name PlayerClimbingController

signal climb_started(surface: String)
signal climb_ended(reason: String)
signal mantle_started
signal mantle_finished

@export var wall_probe_distance: float = 1.05
@export var chest_height: float = 1.05
@export var head_height: float = 1.95
@export var climb_speed: float = 3.1
@export var lateral_speed: float = 2.7
@export var wall_hold_speed: float = 1.6
@export var jump_away_speed: float = 5.0
@export var jump_up_speed: float = 5.4
@export var mantle_duration: float = 0.3
@export var base_stamina_per_second: float = 2.2
@export var resting_stamina_per_second: float = 1.25

var climbing: bool = false
var mantling: bool = false
var wall_normal: Vector3 = Vector3.ZERO
var surface_name: String = "none"
var surface_drain_multiplier: float = 1.0
var surface_slide_speed: float = 0.0
var stamina_drain_progress: float = 0.0
var stamina_rest_progress: float = 0.0
var mantle_remaining: float = 0.0
var mantle_target: Vector3 = Vector3.ZERO
var last_outcome: String = "READY"

@onready var actor: CharacterBody3D = get_parent() as CharacterBody3D
@onready var action_state: PlayerActionState = get_parent().get_node_or_null("PlayerActionState") as PlayerActionState


func _ready() -> void:
	add_to_group("debuggable")


func update_climb_detection() -> void:
	if actor == null or climbing or mantling:
		return
	if action_state != null and not action_state.can_manipulate():
		return
	var wants_wall: bool = Input.get_action_strength("move_forward") > 0.2
	var wants_grab: bool = not actor.is_on_floor() or Input.is_action_pressed("jump")
	if not wants_wall or not wants_grab:
		return
	var forward: Vector3 = -actor.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		return
	var hit: Dictionary = _raycast(
		actor.global_position + Vector3.UP * chest_height,
		actor.global_position + Vector3.UP * chest_height + forward.normalized() * wall_probe_distance
	)
	if hit.is_empty():
		return
	var collider: Node = hit.get("collider") as Node
	if collider == null or not collider.is_in_group("climbable"):
		return
	var profile: Dictionary = _get_surface_profile(collider)
	if not bool(profile.get("climbable", true)):
		last_outcome = str(profile.get("label", "Surface")).to_upper() + " REJECTED"
		_show_message(str(profile.get("label", "Surface")) + " cannot be climbed.")
		return
	if action_state != null and not action_state.begin_manipulation():
		return
	climbing = true
	wall_normal = (hit.get("normal", Vector3.BACK) as Vector3).normalized()
	surface_name = str(profile.get("label", "stone"))
	surface_drain_multiplier = float(profile.get("drain", 1.0))
	surface_slide_speed = float(profile.get("slide", 0.0))
	last_outcome = "GRABBED " + surface_name.to_upper()
	_face_wall()
	climb_started.emit(surface_name)
	_show_message("Climbing " + surface_name + ".")


func should_handle_locomotion() -> bool:
	return climbing or mantling


func process_locomotion(delta: float) -> bool:
	if actor == null:
		return false
	if mantling:
		_process_mantle(delta)
		return true
	if not climbing:
		return false
	if Input.is_action_just_pressed("dodge"):
		_detach("DROPPED")
		actor.velocity = Vector3.ZERO
		actor.move_and_slide()
		return true
	if Input.is_action_just_pressed("jump"):
		var launch: Vector3 = wall_normal * jump_away_speed + Vector3.UP * jump_up_speed
		_detach("CLIMB JUMP")
		actor.velocity = launch
		actor.move_and_slide()
		return true
	var contact: Dictionary = _raycast(
		actor.global_position + Vector3.UP * chest_height,
		actor.global_position + Vector3.UP * chest_height - wall_normal * wall_probe_distance
	)
	if contact.is_empty():
		if _try_begin_mantle():
			_process_mantle(delta)
			return true
		_detach("LOST GRIP")
		return false
	wall_normal = (contact.get("normal", wall_normal) as Vector3).normalized()
	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var vertical_input: float = -input_vector.y
	var horizontal_input: float = input_vector.x
	var wall_right: Vector3 = Vector3.UP.cross(wall_normal).normalized()
	var movement: Vector3 = Vector3.UP * vertical_input * climb_speed
	movement += wall_right * horizontal_input * lateral_speed
	movement -= wall_normal * wall_hold_speed
	movement.y -= surface_slide_speed
	actor.velocity = movement
	actor.move_and_slide()
	_update_stamina(delta, Vector2(horizontal_input, vertical_input).length())
	if vertical_input > 0.15:
		_try_begin_mantle()
	return true


func _try_begin_mantle() -> bool:
	if not climbing or actor == null:
		return false
	var head_origin: Vector3 = actor.global_position + Vector3.UP * head_height
	var head_hit: Dictionary = _raycast(head_origin, head_origin - wall_normal * wall_probe_distance)
	if not head_hit.is_empty():
		return false
	var ledge_probe_origin: Vector3 = actor.global_position + Vector3.UP * 2.8 - wall_normal * 0.85
	var ledge_hit: Dictionary = _raycast(ledge_probe_origin, ledge_probe_origin + Vector3.DOWN * 3.0)
	if ledge_hit.is_empty():
		return false
	var ledge_normal: Vector3 = ledge_hit.get("normal", Vector3.UP) as Vector3
	if ledge_normal.dot(Vector3.UP) < 0.65:
		return false
	mantling = true
	climbing = false
	mantle_remaining = mantle_duration
	mantle_target = (ledge_hit.get("position", actor.global_position) as Vector3) + Vector3.UP * 0.08
	last_outcome = "MANTLING"
	mantle_started.emit()
	return true


func _process_mantle(delta: float) -> void:
	mantle_remaining = maxf(mantle_remaining - delta, 0.0)
	var remaining: float = maxf(mantle_remaining, 0.04)
	actor.velocity = (mantle_target - actor.global_position) / remaining
	actor.velocity = actor.velocity.limit_length(8.5)
	actor.move_and_slide()
	if mantle_remaining <= 0.0 or actor.global_position.distance_to(mantle_target) < 0.12:
		actor.global_position = mantle_target
		actor.velocity = Vector3.ZERO
		mantling = false
		last_outcome = "MANTLED"
		if action_state != null:
			action_state.end_manipulation()
		mantle_finished.emit()


func _update_stamina(delta: float, effort: float) -> void:
	if effort > 0.12 or surface_slide_speed > 0.0:
		stamina_rest_progress = 0.0
		var directional_cost: float = 1.0 + maxf(-Input.get_axis("move_forward", "move_back"), 0.0) * 0.35
		stamina_drain_progress += base_stamina_per_second * surface_drain_multiplier * directional_cost * delta
		while stamina_drain_progress >= 1.0:
			stamina_drain_progress -= 1.0
			if not GameState.spend_stamina(1):
				_detach("EXHAUSTED")
				_show_message("Grace lost her grip.")
				return
	else:
		stamina_drain_progress = maxf(stamina_drain_progress - delta, 0.0)
		stamina_rest_progress += resting_stamina_per_second * delta
		if stamina_rest_progress >= 1.0:
			stamina_rest_progress -= 1.0
			var maximum: int = GameState.get_stat("max_stamina")
			GameState.set_stat("stamina", mini(GameState.get_stat("stamina") + 1, maximum))


func _detach(reason: String) -> void:
	climbing = false
	mantling = false
	wall_normal = Vector3.ZERO
	surface_name = "none"
	last_outcome = reason
	if action_state != null:
		action_state.end_manipulation()
	climb_ended.emit(reason)


func _face_wall() -> void:
	var into_wall: Vector3 = -wall_normal
	into_wall.y = 0.0
	if into_wall.length_squared() <= 0.001:
		return
	actor.rotation.y = atan2(-into_wall.x, -into_wall.z)


func _get_surface_profile(collider: Node) -> Dictionary:
	var kind: String = str(collider.get_meta("climb_surface", "stone"))
	match kind:
		"wood":
			return {"label": "wood", "climbable": true, "drain": 0.75, "slide": 0.0}
		"metal":
			return {"label": "metal", "climbable": true, "drain": 1.55, "slide": 0.0}
		"wet":
			return {"label": "wet stone", "climbable": true, "drain": 1.8, "slide": 0.55}
		"ice":
			return {"label": "ice", "climbable": false, "drain": 3.0, "slide": 2.0}
		_:
			return {"label": "stone", "climbable": true, "drain": 1.0, "slide": 0.0}


func _raycast(from: Vector3, to: Vector3) -> Dictionary:
	if actor == null or actor.get_world_3d() == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [actor.get_rid()]
	return actor.get_world_3d().direct_space_state.intersect_ray(query)


func reset_climbing() -> void:
	_detach("READY")
	stamina_drain_progress = 0.0
	stamina_rest_progress = 0.0


func get_debug_data() -> Dictionary:
	return {
		"climbing": climbing,
		"mantling": mantling,
		"surface": surface_name,
		"drain_multiplier": snappedf(surface_drain_multiplier, 0.05),
		"slide": snappedf(surface_slide_speed, 0.05),
		"outcome": last_outcome,
		"stamina_progress": snappedf(stamina_drain_progress, 0.05),
	}


func _show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)
