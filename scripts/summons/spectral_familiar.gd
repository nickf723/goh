extends CharacterBody3D
class_name SpectralFamiliar

signal command_changed(command: String)
signal health_changed(current: int, maximum: int)
signal familiar_defeated(familiar: SpectralFamiliar)
signal attack_performed(target: Node3D, result: Dictionary)

const COMMAND_FOLLOW := "FOLLOW"
const COMMAND_STAY := "STAY"
const COMMAND_ASSIST := "ASSIST"

@export var display_name: String = "Lumen"
@export var move_speed: float = 5.8
@export var acceleration: float = 18.0
@export var follow_distance: float = 2.4
@export var teleport_distance: float = 18.0
@export var target_search_range: float = 13.0
@export var attack_range: float = 2.1
@export var attack_damage: int = 2
@export var attack_stance_damage: int = 3
@export var attack_interval: float = 0.9
@export var maximum_health: int = 18
@export var gravity: float = 18.0

var summoner: Node3D
var summon_manager: Node
var command: String = COMMAND_FOLLOW
var current_health: int = 18
var current_target: Node3D
var stay_position: Vector3
var attack_timer: float = 0.0
var spawn_position: Vector3
var last_attack_result: String = "NONE"
var visual_root: Node3D
var aura_material: StandardMaterial3D
var elapsed: float = 0.0


func _ready() -> void:
	current_health = maximum_health
	spawn_position = global_position
	stay_position = global_position
	add_to_group("player_summon")
	add_to_group("friendly_actor")
	add_to_group("debuggable")
	_build_body()


func initialize(owner: Node3D, manager: Node) -> void:
	summoner = owner
	summon_manager = manager
	if is_inside_tree():
		recall_to_summoner()


func _physics_process(delta: float) -> void:
	elapsed += delta
	attack_timer = maxf(attack_timer - delta, 0.0)
	if summoner == null or not is_instance_valid(summoner):
		velocity = Vector3.ZERO
		return

	_refresh_target()
	var destination: Vector3 = _resolve_destination()
	var offset: Vector3 = destination - global_position
	offset.y = 0.0

	if global_position.distance_to(summoner.global_position) > teleport_distance:
		recall_to_summoner()
		offset = Vector3.ZERO

	if current_target != null and is_instance_valid(current_target):
		var target_distance: float = global_position.distance_to(current_target.global_position)
		if target_distance <= attack_range:
			velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
			velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
			_face_position(current_target.global_position, delta)
			if attack_timer <= 0.0:
				_attack_target()
		else:
			_move_toward(offset, delta)
	elif command == COMMAND_STAY:
		if offset.length() > 0.25:
			_move_toward(offset, delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
			velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
	else:
		_move_toward(offset, delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1
	move_and_slide()
	_update_visual()


func set_command(next_command: String) -> void:
	if next_command not in [COMMAND_FOLLOW, COMMAND_STAY, COMMAND_ASSIST]:
		return
	command = next_command
	if command == COMMAND_STAY:
		stay_position = global_position
		current_target = null
	command_changed.emit(command)


func cycle_command() -> String:
	match command:
		COMMAND_FOLLOW:
			set_command(COMMAND_STAY)
		COMMAND_STAY:
			set_command(COMMAND_ASSIST)
		_:
			set_command(COMMAND_FOLLOW)
	return command


func recall_to_summoner() -> void:
	if summoner == null or not is_instance_valid(summoner):
		return
	var offset: Vector3 = summoner.global_basis.x * 1.8 - summoner.global_basis.z * 1.2
	global_position = summoner.global_position + offset + Vector3.UP * 0.15
	velocity = Vector3.ZERO
	stay_position = global_position
	_spawn_recall_flash()


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	if payload == null:
		return {}
	current_health = maxi(current_health - maxi(payload.amount, 1), 0)
	health_changed.emit(current_health, maximum_health)
	if current_health <= 0:
		_defeat()
	return {
		"message": display_name + " takes " + str(maxi(payload.amount, 1)) + " damage.",
		"objective": "",
		"damage_dealt": maxi(payload.amount, 1),
	}


func heal_full() -> void:
	current_health = maximum_health
	health_changed.emit(current_health, maximum_health)


func is_target_defeated() -> bool:
	return current_health <= 0


func get_targeting_aim_point() -> Vector3:
	return global_position + Vector3.UP * 0.7


func get_debug_data() -> Dictionary:
	return {
		"name": display_name,
		"command": command,
		"health": current_health,
		"maximum_health": maximum_health,
		"target": current_target.name if current_target != null and is_instance_valid(current_target) else "none",
		"attack_timer": snappedf(attack_timer, 0.01),
		"last_attack": last_attack_result,
		"distance_to_summoner": snappedf(global_position.distance_to(summoner.global_position), 0.1) if summoner != null else -1.0,
	}


func _resolve_destination() -> Vector3:
	if current_target != null and is_instance_valid(current_target):
		return current_target.global_position
	if command == COMMAND_STAY:
		return stay_position
	var side: float = -1.0 if int(Time.get_ticks_msec() / 2200) % 2 == 0 else 1.0
	return summoner.global_position + summoner.global_basis.x * side * follow_distance + summoner.global_basis.z * 0.8


func _refresh_target() -> void:
	if command == COMMAND_STAY:
		current_target = null
		return
	var locked: Node3D = _get_summoner_locked_target()
	if locked != null and _valid_enemy(locked):
		current_target = locked
		return
	if command != COMMAND_ASSIST:
		current_target = null
		return
	if current_target != null and _valid_enemy(current_target):
		if global_position.distance_to(current_target.global_position) <= target_search_range * 1.35:
			return
	current_target = _find_nearest_enemy()


func _get_summoner_locked_target() -> Node3D:
	if summoner == null or not summoner.has_method("has_lock_on_target"):
		return null
	if not bool(summoner.call("has_lock_on_target")):
		return null
	var value: Variant = summoner.get("lock_on_target")
	return value as Node3D if value is Node3D else null


func _find_nearest_enemy() -> Node3D:
	var best: Node3D
	var best_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		var candidate := node as Node3D
		if not _valid_enemy(candidate):
			continue
		var distance: float = global_position.distance_to(candidate.global_position)
		if distance <= target_search_range and distance < best_distance:
			best = candidate
			best_distance = distance
	return best


func _valid_enemy(candidate: Node3D) -> bool:
	if candidate == null or not is_instance_valid(candidate) or candidate == self:
		return false
	if candidate.has_method("is_target_defeated") and bool(candidate.call("is_target_defeated")):
		return false
	return true


func _move_toward(offset: Vector3, delta: float) -> void:
	if offset.length() <= follow_distance * 0.45:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		return
	var direction: Vector3 = offset.normalized()
	velocity.x = move_toward(velocity.x, direction.x * move_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * move_speed, acceleration * delta)
	_face_position(global_position + direction, delta)


func _face_position(position: Vector3, delta: float) -> void:
	var direction: Vector3 = position - global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return
	var target_yaw: float = atan2(-direction.normalized().x, -direction.normalized().z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 10.0, 0.0, 1.0))


func _attack_target() -> void:
	if current_target == null or not is_instance_valid(current_target):
		return
	attack_timer = attack_interval
	var payload := DamagePayload.new()
	payload.amount = attack_damage
	payload.stance_damage = attack_stance_damage
	payload.element = "soul"
	payload.source_name = display_name + " Familiar Strike"
	payload.hit_type = "summon_attack"
	payload.tags = ["summon", "friendly", "soul"]
	var result: Dictionary = {}
	if current_target.has_method("receive_damage_payload"):
		result = current_target.call("receive_damage_payload", payload)
	else:
		var receiver: Node = current_target.get_node_or_null("HitReceiver")
		if receiver != null and receiver.has_method("receive_payload"):
			result = receiver.call("receive_payload", payload)
	last_attack_result = str(result.get("message", "STRUCK"))
	attack_performed.emit(current_target, result)
	_spawn_attack_flash(current_target.global_position)


func _defeat() -> void:
	familiar_defeated.emit(self)
	set_physics_process(false)
	visible = false
	queue_free()


func _build_body() -> void:
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 1.15
	collision.shape = shape
	collision.position.y = 0.58
	add_child(collision)
	visual_root = Node3D.new()
	visual_root.name = "SpectralVisual"
	add_child(visual_root)
	aura_material = StandardMaterial3D.new()
	aura_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_material.albedo_color = Color(0.26, 0.82, 1.0, 0.72)
	aura_material.emission_enabled = true
	aura_material.emission = Color(0.18, 0.68, 1.0)
	aura_material.emission_energy_multiplier = 2.5
	aura_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.36
	body_mesh.height = 1.05
	body.mesh = body_mesh
	body.position.y = 0.62
	body.material_override = aura_material
	visual_root.add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.32
	head_mesh.height = 0.64
	head.mesh = head_mesh
	head.position = Vector3(0, 1.12, -0.08)
	head.material_override = aura_material
	visual_root.add_child(head)
	for side: float in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		var ear_mesh := PrismMesh.new()
		ear_mesh.size = Vector3(0.22, 0.48, 0.16)
		ear.mesh = ear_mesh
		ear.position = Vector3(side * 0.26, 1.43, -0.04)
		ear.rotation_degrees.z = side * -18.0
		ear.material_override = aura_material
		visual_root.add_child(ear)
	var eye_material := StandardMaterial3D.new()
	eye_material.albedo_color = Color.WHITE
	eye_material.emission_enabled = true
	eye_material.emission = Color(0.86, 1.0, 1.0)
	eye_material.emission_energy_multiplier = 4.0
	for side: float in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.055
		eye_mesh.height = 0.11
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.12, 1.17, -0.36)
		eye.material_override = eye_material
		visual_root.add_child(eye)
	var label := Label3D.new()
	label.name = "CommandLabel"
	label.text = display_name + "\n" + command
	label.position = Vector3(0, 1.85, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 22
	label.pixel_size = 0.006
	label.outline_size = 7
	label.modulate = Color(0.62, 0.92, 1.0)
	visual_root.add_child(label)


func _update_visual() -> void:
	if visual_root == null:
		return
	visual_root.position.y = sin(elapsed * 4.2) * 0.08
	visual_root.rotation.z = sin(elapsed * 3.1) * 0.035
	var label := visual_root.get_node_or_null("CommandLabel") as Label3D
	if label != null:
		label.text = display_name + "\n" + command + "  " + str(current_health) + "/" + str(maximum_health)


func _spawn_recall_flash() -> void:
	_spawn_flash(global_position, Color(0.34, 0.84, 1.0), 1.2)


func _spawn_attack_flash(position: Vector3) -> void:
	_spawn_flash(position + Vector3.UP * 0.7, Color(0.66, 0.42, 1.0), 0.65)


func _spawn_flash(position: Vector3, color: Color, start_scale: float) -> void:
	if get_tree().current_scene == null:
		return
	var flash := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.25
	mesh.height = 0.5
	flash.mesh = mesh
	flash.global_position = position
	flash.scale = Vector3.ONE * start_scale
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color, 0.75)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.0
	flash.material_override = material
	get_tree().current_scene.add_child(flash)
	var tween := flash.create_tween()
	tween.parallel().tween_property(flash, "scale", Vector3.ONE * start_scale * 2.4, 0.35)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.35)
	tween.finished.connect(flash.queue_free)
