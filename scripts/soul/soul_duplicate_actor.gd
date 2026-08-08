extends CharacterBody3D
class_name SoulDuplicateActor

signal duplicate_attack_started(attack_id: String)
signal duplicate_attack_resolved(attack_id: String, target_count: int)
signal duplicate_spell_mirrored(spell_id: String)
signal duplicate_form_changed(form_id: String)

const GraceVisualScene: PackedScene = preload(
	"res://scenes/actors/player/grace_wire_visual_v1.tscn"
)
const FlamethrowerControllerScript = preload(
	"res://scripts/player/player_flamethrower_controller.gd"
)
const PlayerActionStateScript = preload(
	"res://scripts/player/player_action_state.gd"
)

@export_group("Live Mirror Movement")
@export_range(1.0, 12.0, 0.1) var move_speed: float = 5.0
@export_range(1.0, 80.0, 0.5) var acceleration: float = 30.0
@export_range(1.0, 80.0, 0.5) var air_acceleration: float = 12.0
@export_range(1.0, 40.0, 0.5) var gravity: float = 18.0
@export_range(1.0, 20.0, 0.1) var jump_velocity: float = 6.0
@export_range(0.5, 20.0, 0.1) var dodge_speed: float = 10.0
@export_range(0.05, 1.0, 0.01) var dodge_seconds: float = 0.22
@export_range(0.0, 2.0, 0.01) var dodge_cooldown: float = 0.32

@export_group("Spawn")
@export_range(0.5, 5.0, 0.1) var default_side_offset: float = 1.7

var source_actor: CharacterBody3D = null
var duplicate_index: int = 0
var dodge_remaining: float = 0.0
var dodge_cooldown_remaining: float = 0.0
var current_form: String = "normal"
var form_scale: float = 1.0
var flight_active: bool = false
var soul_integrity: float = 100.0
var visual_root: Node3D = null
var collision_shape: CollisionShape3D = null
var action_state: PlayerActionState = null
var flamethrower_controller: PlayerFlamethrowerController = null
var attack_serial: int = 0
var mirrored_spell_count: int = 0


func _ready() -> void:
	add_to_group("soul_duplicates")
	add_to_group("duplicate_sources")
	add_to_group("spell_effects")
	add_to_group("persistent_spell_effects")
	add_to_group("debuggable")
	collision_layer = 1
	collision_mask = 1
	floor_snap_length = 0.42
	floor_constant_speed = true
	_build_body()
	_build_support_controllers()


func configure(source: CharacterBody3D, index: int = 0) -> void:
	source_actor = source
	duplicate_index = index
	if source_actor == null:
		return
	var side: Vector3 = source_actor.global_transform.basis.x
	side.y = 0.0
	if side.length_squared() <= 0.001:
		side = Vector3.RIGHT
	global_transform = source_actor.global_transform
	global_position += side.normalized() * default_side_offset * float(index + 1)
	velocity = source_actor.velocity


func _physics_process(delta: float) -> void:
	if source_actor == null or not is_instance_valid(source_actor):
		queue_free()
		return
	var step: float = maxf(delta, 0.0)
	dodge_cooldown_remaining = maxf(dodge_cooldown_remaining - step, 0.0)
	if dodge_remaining > 0.0:
		dodge_remaining = maxf(dodge_remaining - step, 0.0)
		_apply_gravity(step)
		move_and_slide()
		return

	var input_vector: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)
	var requested_direction: Vector3 = _camera_relative_direction(input_vector)
	var speed_multiplier: float = 1.0
	match current_form:
		"grown":
			speed_multiplier = 0.78
		"shrunk":
			speed_multiplier = 1.35
	var target_speed: float = move_speed * speed_multiplier
	var target_velocity: Vector3 = requested_direction * target_speed
	var planar_accel: float = acceleration if is_on_floor() else air_acceleration
	velocity.x = move_toward(velocity.x, target_velocity.x, planar_accel * step)
	velocity.z = move_toward(velocity.z, target_velocity.z, planar_accel * step)

	if flight_active:
		var vertical_input: float = 0.0
		if Input.is_action_pressed("jump"):
			vertical_input += 1.0
		if InputMap.has_action("flight_descend") and Input.is_action_pressed("flight_descend"):
			vertical_input -= 1.0
		velocity.y = move_toward(velocity.y, vertical_input * 5.2, 15.0 * step)
	elif Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	else:
		_apply_gravity(step)

	if Input.is_action_just_pressed("dodge") and dodge_cooldown_remaining <= 0.0:
		var dodge_direction: Vector3 = requested_direction
		if dodge_direction.length_squared() <= 0.001:
			dodge_direction = -source_actor.global_transform.basis.z
			dodge_direction.y = 0.0
		if dodge_direction.length_squared() > 0.001:
			dodge_direction = dodge_direction.normalized()
			velocity.x = dodge_direction.x * dodge_speed * speed_multiplier
			velocity.z = dodge_direction.z * dodge_speed * speed_multiplier
			dodge_remaining = dodge_seconds
			dodge_cooldown_remaining = dodge_cooldown

	move_and_slide()


func mirror_weapon_attack(
	attack: WeaponAttackDefinition,
	weapon: WeaponDefinition
) -> void:
	if attack == null:
		return
	attack_serial += 1
	var serial: int = attack_serial
	duplicate_attack_started.emit(attack.attack_id)
	var startup: float = maxf(attack.get_startup_duration(), 0.0)
	var timer: SceneTreeTimer = get_tree().create_timer(startup)
	timer.timeout.connect(
		func() -> void:
			if not is_inside_tree() or serial > attack_serial:
				return
			_resolve_weapon_attack(attack, weapon)
	)


func _resolve_weapon_attack(
	attack: WeaponAttackDefinition,
	weapon: WeaponDefinition
) -> void:
	var payload: DamagePayload = attack.build_payload(weapon)
	if payload == null:
		return
	for tag: String in ["soul", "duplicate", "live_clone"]:
		if not payload.tags.has(tag):
			payload.tags.append(tag)
	var damage_multiplier: float = 1.0
	var range_multiplier: float = 1.0
	match current_form:
		"grown":
			damage_multiplier = 1.5
			range_multiplier = 1.2
		"shrunk":
			damage_multiplier = 0.72
			range_multiplier = 0.82
	payload.amount = maxi(roundi(float(payload.amount) * damage_multiplier), 0)
	payload.stance_damage = maxi(roundi(float(payload.stance_damage) * damage_multiplier), 0)
	var attack_range: float = maxf(attack.attack_range * range_multiplier, 0.2)
	var center: Vector3 = global_position + Vector3.UP * maxf(0.7 * form_scale, 0.25)
	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	center += forward * attack.attack_center_forward_offset * range_multiplier
	var shape := SphereShape3D.new()
	shape.radius = attack_range
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.exclude = [get_rid()]
	var minimum_dot: float = cos(deg_to_rad(attack.cone_angle_degrees * 0.5))
	var seen: Dictionary = {}
	var target_count: int = 0
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 64):
		var raw: Variant = hit.get("collider")
		if not raw is Node:
			continue
		var target: Node = _find_payload_target(raw as Node)
		if target == null or target == source_actor or target == self:
			continue
		if target.is_in_group("soul_duplicates") or target.is_in_group("repeat_echoes"):
			continue
		var id: int = target.get_instance_id()
		if seen.has(id):
			continue
		var target_position: Vector3 = _target_position(target)
		var offset: Vector3 = target_position - center
		offset.y = 0.0
		if offset.length_squared() > 0.001 and forward.dot(offset.normalized()) < minimum_dot:
			continue
		seen[id] = true
		_send_payload(target, payload)
		target_count += 1
		if target_count >= attack.max_targets:
			break
	duplicate_attack_resolved.emit(attack.attack_id, target_count)


func apply_source_state_spell(spell_id: String, cast_direction: Vector3) -> void:
	match spell_id:
		"grow":
			_apply_form("grown")
		"shrink":
			_apply_form("shrunk")
		"flight_concentration":
			flight_active = not flight_active
		"flash":
			_apply_flash(cast_direction)
		_:
			pass
	mirrored_spell_count += 1
	duplicate_spell_mirrored.emit(spell_id)


func _apply_form(form_id: String) -> void:
	if current_form == form_id:
		current_form = "normal"
		form_scale = 1.0
	elif form_id == "grown":
		current_form = "grown"
		form_scale = 1.55
	else:
		current_form = "shrunk"
		form_scale = 0.58
	if visual_root != null:
		visual_root.scale = Vector3.ONE * form_scale
		visual_root.position.y = -0.92 * form_scale
	if collision_shape != null and collision_shape.shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = collision_shape.shape.duplicate(true) as CapsuleShape3D
		capsule.radius = 0.46 * form_scale
		capsule.height = maxf(1.92 * form_scale, capsule.radius * 2.0)
		collision_shape.shape = capsule
	duplicate_form_changed.emit(current_form)


func _apply_flash(direction_value: Vector3) -> void:
	var direction: Vector3 = direction_value
	if direction.length_squared() <= 0.001:
		direction = -global_transform.basis.z
	direction = direction.normalized()
	var from: Vector3 = global_position + Vector3.UP * 0.9 * form_scale
	var to: Vector3 = from + direction * 24.0
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	query.collide_with_areas = false
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var endpoint: Vector3 = result.get("position", to) as Vector3
	global_position += endpoint - from - direction * 0.35


func _build_body() -> void:
	collision_shape = CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.46
	capsule.height = 1.92
	collision_shape.shape = capsule
	add_child(collision_shape)
	visual_root = GraceVisualScene.instantiate() as Node3D
	visual_root.name = "GraceVisualV1"
	visual_root.position = Vector3(0.0, -0.92, 0.0)
	add_child(visual_root)
	_tint_visual_recursive(visual_root)


func _build_support_controllers() -> void:
	action_state = PlayerActionStateScript.new() as PlayerActionState
	action_state.name = "PlayerActionState"
	add_child(action_state)
	flamethrower_controller = FlamethrowerControllerScript.new() as PlayerFlamethrowerController
	flamethrower_controller.name = "FlamethrowerController"
	add_child(flamethrower_controller)


func _tint_visual_recursive(node: Node) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.set_instance_shader_parameter("soul_duplicate_tint", Color(0.32, 0.88, 1.0, 0.78))
		if node is MeshInstance3D:
			var mesh_instance := node as MeshInstance3D
			var material: Material = mesh_instance.material_override
			if material is StandardMaterial3D:
				var duplicate_material := (material as StandardMaterial3D).duplicate(true) as StandardMaterial3D
				duplicate_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				duplicate_material.albedo_color.a = minf(duplicate_material.albedo_color.a, 0.72)
				duplicate_material.emission_enabled = true
				duplicate_material.emission = Color(0.12, 0.72, 1.0)
				duplicate_material.emission_energy_multiplier = 0.75
				mesh_instance.material_override = duplicate_material
	for child: Node in node.get_children():
		_tint_visual_recursive(child)


func _camera_relative_direction(input_vector: Vector2) -> Vector3:
	if input_vector.length() <= 0.01:
		return Vector3.ZERO
	var forward: Vector3 = -source_actor.global_transform.basis.z
	var right: Vector3 = source_actor.global_transform.basis.x
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		forward = -camera.global_transform.basis.z
		right = camera.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	if forward.length_squared() > 0.001:
		forward = forward.normalized()
	if right.length_squared() > 0.001:
		right = right.normalized()
	var direction: Vector3 = right * input_vector.x + forward * -input_vector.y
	return direction.normalized() if direction.length_squared() > 0.001 else Vector3.ZERO


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1


func _find_payload_target(start_node: Node) -> Node:
	var current: Node = start_node
	while current != null:
		if current.has_method("receive_damage_payload") or current.get_node_or_null("PayloadReceiver") != null or current.get_node_or_null("HitReceiver") != null:
			return current
		current = current.get_parent()
	return null


func _send_payload(target: Node, payload: DamagePayload) -> void:
	var resolved: DamagePayload = payload.duplicate(true) as DamagePayload
	var receiver: Node = target.get_node_or_null("PayloadReceiver")
	if receiver != null and receiver.has_method("receive_payload"):
		receiver.call("receive_payload", resolved)
		return
	if target.has_method("receive_damage_payload"):
		target.call("receive_damage_payload", resolved)
		return
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if hit_receiver != null and hit_receiver.has_method("receive_payload"):
		hit_receiver.call("receive_payload", resolved)


func _target_position(target: Node) -> Vector3:
	if target is Node3D:
		return (target as Node3D).global_position
	var parent: Node = target.get_parent()
	return (parent as Node3D).global_position if parent is Node3D else global_position


func get_debug_data() -> Dictionary:
	return {
		"soul_duplicate": true,
		"duplicate_index": duplicate_index,
		"form": current_form,
		"form_scale": form_scale,
		"flight_active": flight_active,
		"soul_integrity": soul_integrity,
		"velocity": velocity,
		"attack_serial": attack_serial,
		"mirrored_spells": mirrored_spell_count,
		"independent_collision": true,
		"shared_input": true,
		"live_simulation": true,
	}
