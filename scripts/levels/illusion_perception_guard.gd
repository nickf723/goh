extends CharacterBody3D
class_name IllusionPerceptionGuard

signal target_changed(target: Node3D, kind: String)
signal illusion_targeted(illusion: Node3D)
signal illusion_attacked(illusion: Node3D)
signal arrived_at_target(target: Node3D)

const PerceptionResolver = preload(
	"res://scripts/perception/perception_target_resolver.gd"
)

@export_range(1.0, 30.0, 0.5) var perception_range: float = 18.0
@export_range(0.5, 8.0, 0.1) var move_speed: float = 2.8
@export_range(1.0, 20.0, 0.5) var acceleration: float = 8.0
@export_range(0.5, 5.0, 0.05) var stopping_distance: float = 1.15
@export_range(0.05, 2.0, 0.05) var attack_interval: float = 0.65
@export_range(0.05, 1.0, 0.01) var perception_interval: float = 0.12
@export var gravity: float = 18.0
@export var training_enabled: bool = true

var canonical_target: Node3D = null
var current_target: Node3D = null
var perception: AnimalPerceptionMemory = null
var perception_snapshot: Dictionary = {}
var perception_remaining: float = 0.0
var attack_remaining: float = 0.0
var initial_transform: Transform3D
var target_change_count: int = 0
var illusion_target_count: int = 0
var illusion_attack_count: int = 0
var arrived_count: int = 0
var visual_root: Node3D = null
var eye_material: StandardMaterial3D = null


func _ready() -> void:
	initial_transform = global_transform
	add_to_group("illusion_training_guards")
	add_to_group("debuggable")
	add_to_group("lab_resettable")
	_build_collision()
	_build_visual()
	perception = AnimalPerceptionMemory.create_for_species(
		"wolf",
		{"curiosity": 0.7, "courage": 0.8, "patience": 0.65}
	)
	perception.sight_range = perception_range
	perception.field_of_view_degrees = 320.0
	set_physics_process(true)


func set_canonical_target(target: Node3D) -> void:
	canonical_target = target
	perception_remaining = 0.0


func set_training_enabled(value: bool) -> void:
	training_enabled = value
	perception_remaining = 0.0
	if not training_enabled:
		current_target = null
		velocity.x = 0.0
		velocity.z = 0.0


func _physics_process(delta: float) -> void:
	var step: float = maxf(delta, 0.0)
	if not training_enabled:
		if not is_on_floor():
			velocity.y -= gravity * step
		elif velocity.y < 0.0:
			velocity.y = -0.1
		move_and_slide()
		return
	if current_target != null and not is_instance_valid(current_target):
		current_target = null
	perception_remaining -= step
	attack_remaining = maxf(attack_remaining - step, 0.0)
	if perception_remaining <= 0.0:
		perception_remaining = maxf(perception_interval, 0.05)
		_refresh_target()
	_move_toward_perceived_target(step)
	if not is_on_floor():
		velocity.y -= gravity * step
	elif velocity.y < 0.0:
		velocity.y = -0.1
	move_and_slide()


func _refresh_target() -> void:
	if current_target != null and not is_instance_valid(current_target):
		current_target = null
	var next: Node3D = PerceptionResolver.resolve_target(
		get_tree(),
		self,
		canonical_target,
		perception_range
	)
	var target_speed: float = 0.0
	if next != null and is_instance_valid(next) and next is CharacterBody3D:
		var target_velocity: Vector3 = (next as CharacterBody3D).velocity
		target_speed = Vector2(target_velocity.x, target_velocity.z).length()
	if perception != null:
		perception_snapshot = perception.update(
			self,
			next,
			maxf(perception_interval, 0.05),
			Vector3.ZERO,
			0.0,
			target_speed
		)
	if next == current_target:
		return
	current_target = next
	target_change_count += 1
	var kind: String = _target_kind(current_target)
	target_changed.emit(current_target, kind)
	if kind == "illusion" and current_target != null and is_instance_valid(current_target):
		illusion_target_count += 1
		illusion_targeted.emit(current_target)


func _move_toward_perceived_target(delta: float) -> void:
	if current_target == null or not is_instance_valid(current_target):
		current_target = null
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		return
	var target_position: Vector3 = (
		perception.get_target_position(current_target.global_position)
		if perception != null
		else current_target.global_position
	)
	var offset: Vector3 = target_position - global_position
	offset.y = 0.0
	var distance: float = offset.length()
	if distance <= stopping_distance:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		if distance <= stopping_distance * 1.15:
			_arrive_and_attack()
		return
	var direction: Vector3 = offset.normalized()
	velocity.x = move_toward(
		velocity.x,
		direction.x * move_speed,
		acceleration * delta
	)
	velocity.z = move_toward(
		velocity.z,
		direction.z * move_speed,
		acceleration * delta
	)
	var target_yaw: float = atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 7.0, 0.0, 1.0))


func _arrive_and_attack() -> void:
	if current_target == null or not is_instance_valid(current_target):
		current_target = null
		return
	arrived_count += 1
	arrived_at_target.emit(current_target)
	if attack_remaining > 0.0:
		return
	attack_remaining = maxf(attack_interval, 0.05)
	if _target_kind(current_target) != "illusion":
		return
	var payload := DamagePayload.new()
	payload.amount = 4
	payload.stance_damage = 2
	payload.element = "neutral"
	payload.source_name = "Training Sentry"
	payload.hit_type = "melee"
	payload.tags = ["training", "perception_attack"]
	if current_target.has_method("receive_damage_payload"):
		current_target.call("receive_damage_payload", payload)
	illusion_attack_count += 1
	illusion_attacked.emit(current_target)
	_flash_eyes()


func _target_kind(target: Variant) -> String:
	# A queued-for-deletion illusion can survive in a typed member until the next
	# perception tick. Accept Variant here so debug/progression reads cannot throw
	# a typed-argument error while Godot is retiring that Object.
	if target == null or not is_instance_valid(target):
		return "none"
	if not target is Node:
		return "none"
	return str((target as Node).get_meta("perception_target_kind", "grace"))


func _safe_target_name() -> String:
	if current_target == null or not is_instance_valid(current_target):
		return "none"
	return str(current_target.name)


func reset_target() -> void:
	global_transform = initial_transform
	velocity = Vector3.ZERO
	current_target = null
	perception_remaining = 0.0
	attack_remaining = 0.0
	target_change_count = 0
	illusion_target_count = 0
	illusion_attack_count = 0
	arrived_count = 0
	if perception != null:
		perception.reset()
	perception_snapshot.clear()


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.position = Vector3(0.0, 0.85, 0.0)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.7
	collision.shape = capsule
	add_child(collision)


func _build_visual() -> void:
	visual_root = Node3D.new()
	visual_root.name = "SentryVisual"
	add_child(visual_root)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.position = Vector3(0.0, 0.92, 0.0)
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.42
	body_mesh.height = 1.55
	body.mesh = body_mesh
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(0.16, 0.19, 0.28)
	body_material.metallic = 0.62
	body_material.roughness = 0.34
	body.material_override = body_material
	visual_root.add_child(body)
	var visor := MeshInstance3D.new()
	visor.name = "Visor"
	visor.position = Vector3(0.0, 1.22, -0.38)
	var visor_mesh := BoxMesh.new()
	visor_mesh.size = Vector3(0.48, 0.12, 0.08)
	visor.mesh = visor_mesh
	eye_material = StandardMaterial3D.new()
	eye_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_material.emission_enabled = true
	eye_material.emission = Color(0.28, 0.74, 1.0)
	eye_material.emission_energy_multiplier = 2.2
	eye_material.albedo_color = Color(0.18, 0.56, 0.9)
	visor.material_override = eye_material
	visual_root.add_child(visor)


func _flash_eyes() -> void:
	if eye_material == null:
		return
	eye_material.emission = Color(0.8, 0.24, 1.0)
	var timer: SceneTreeTimer = get_tree().create_timer(0.14)
	timer.timeout.connect(func() -> void:
		if eye_material != null:
			eye_material.emission = Color(0.28, 0.74, 1.0)
	)


func get_debug_data() -> Dictionary:
	return {
		"illusion_perception_guard": true,
		"enabled": training_enabled,
		"target": _safe_target_name(),
		"target_kind": _target_kind(current_target),
		"target_changes": target_change_count,
		"illusion_targets": illusion_target_count,
		"illusion_attacks": illusion_attack_count,
		"arrivals": arrived_count,
		"perception": perception_snapshot.duplicate(true),
	}
