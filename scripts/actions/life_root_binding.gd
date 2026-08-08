extends Node3D
class_name LifeRootBinding

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")

@export_range(0.25, 20.0, 0.05) var default_duration: float = 3.25

var target: Node3D = null
var source_actor: Node = null
var remaining: float = 0.0
var status_receiver: Node = null
var rigid_body: RigidBody3D = null
var original_freeze: bool = false
var original_freeze_mode: RigidBody3D.FreezeMode = RigidBody3D.FREEZE_MODE_STATIC
var released: bool = false
var visual_root: Node3D = null
var elapsed: float = 0.0


func _ready() -> void:
	add_to_group("life_root_bindings")
	add_to_group("debuggable")


func bind_to_target(
	new_target: Node3D,
	duration: float = 3.25,
	new_source_actor: Node = null
) -> bool:
	if new_target == null or not is_instance_valid(new_target):
		return false
	target = new_target
	source_actor = new_source_actor
	remaining = maxf(duration, 0.25)
	position = Vector3.ZERO

	status_receiver = target.get_node_or_null("StatusReceiver")
	if status_receiver != null and status_receiver.has_method("apply_status"):
		status_receiver.call(
			"apply_status",
			"rooted",
			remaining,
			1.0,
			"Root Bind"
		)

	if target is RigidBody3D:
		rigid_body = target as RigidBody3D
		original_freeze = rigid_body.freeze
		original_freeze_mode = rigid_body.freeze_mode
		_pin_rigid_body()
	elif target.has_method("apply_root_trap"):
		target.call("apply_root_trap", remaining, source_actor)

	_build_root_visual()
	return true


func refresh_binding(duration: float, new_source_actor: Node = null) -> void:
	remaining = maxf(remaining, maxf(duration, 0.25))
	if new_source_actor != null:
		source_actor = new_source_actor
	if status_receiver != null and is_instance_valid(status_receiver):
		if status_receiver.has_method("apply_status"):
			status_receiver.call(
				"apply_status",
				"rooted",
				remaining,
				1.0,
				"Root Bind"
			)
	if rigid_body != null and is_instance_valid(rigid_body):
		_pin_rigid_body()
	if target != null and is_instance_valid(target) and target.has_method("apply_root_trap"):
		target.call("apply_root_trap", remaining, source_actor)
	_pulse_visual()


func _process(delta: float) -> void:
	if released:
		return
	if target == null or not is_instance_valid(target):
		released = true
		queue_free()
		return

	var step: float = maxf(delta, 0.0)
	elapsed += step
	remaining -= step
	if rigid_body != null and is_instance_valid(rigid_body):
		_pin_rigid_body()
	if visual_root != null:
		visual_root.rotation.y = sin(elapsed * 1.8) * 0.035

	if remaining <= 0.0:
		release_binding()


func release_binding() -> void:
	if released:
		return
	released = true

	if status_receiver != null and is_instance_valid(status_receiver):
		if status_receiver.has_method("remove_status"):
			status_receiver.call("remove_status", "rooted")

	if rigid_body != null and is_instance_valid(rigid_body):
		rigid_body.freeze_mode = original_freeze_mode
		rigid_body.freeze = original_freeze
		rigid_body.linear_velocity = Vector3.ZERO
		rigid_body.angular_velocity = Vector3.ZERO

	if target != null and is_instance_valid(target) and target.has_method("release_root_trap"):
		target.call("release_root_trap", source_actor)

	if visual_root != null and is_instance_valid(visual_root):
		var tween := create_tween()
		tween.tween_property(visual_root, "scale", Vector3(1.12, 0.05, 1.12), 0.18)
		tween.tween_callback(queue_free)
	else:
		queue_free()


func _pin_rigid_body() -> void:
	if rigid_body == null or not is_instance_valid(rigid_body):
		return
	rigid_body.linear_velocity = Vector3.ZERO
	rigid_body.angular_velocity = Vector3.ZERO
	rigid_body.freeze = true


func _build_root_visual() -> void:
	if visual_root != null:
		return
	visual_root = Node3D.new()
	visual_root.name = "RootVisual"
	add_child(visual_root)

	var target_height: float = clampf(
		ElementVisuals.estimate_target_height(target),
		0.7,
		2.6
	)
	var root_radius: float = clampf(target_height * 0.34, 0.42, 0.9)

	var bark_material := StandardMaterial3D.new()
	bark_material.albedo_color = Color(0.25, 0.12, 0.035, 1.0)
	bark_material.roughness = 0.9
	var life_material := StandardMaterial3D.new()
	life_material.albedo_color = Color(0.18, 0.66, 0.12, 1.0)
	life_material.emission_enabled = true
	life_material.emission = Color(0.1, 0.48, 0.07, 1.0)
	life_material.emission_energy_multiplier = 0.65
	life_material.roughness = 0.78

	var ring := MeshInstance3D.new()
	ring.name = "RootCrown"
	var torus := TorusMesh.new()
	torus.inner_radius = root_radius * 0.72
	torus.outer_radius = root_radius
	torus.rings = 24
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = bark_material
	ring.position.y = 0.08
	visual_root.add_child(ring)

	for index: int in range(8):
		var angle: float = TAU * float(index) / 8.0
		var root := MeshInstance3D.new()
		root.name = "BindingRoot" + str(index + 1)
		var mesh := BoxMesh.new()
		var height: float = target_height * (0.36 + float(index % 3) * 0.045)
		mesh.size = Vector3(0.075, height, 0.1)
		root.mesh = mesh
		root.material_override = bark_material if index % 2 == 0 else life_material
		root.position = Vector3(
			cos(angle) * root_radius * 0.76,
			height * 0.42,
			sin(angle) * root_radius * 0.76
		)
		root.rotation = Vector3(
			sin(angle) * 0.42,
			-angle,
			cos(angle) * -0.42
		)
		visual_root.add_child(root)

	visual_root.scale = Vector3(1.0, 0.04, 1.0)
	var grow := create_tween()
	grow.set_trans(Tween.TRANS_BACK)
	grow.set_ease(Tween.EASE_OUT)
	grow.tween_property(visual_root, "scale", Vector3.ONE, 0.18)


func _pulse_visual() -> void:
	if visual_root == null:
		return
	visual_root.scale = Vector3.ONE
	var tween := create_tween()
	tween.tween_property(visual_root, "scale", Vector3(1.08, 1.05, 1.08), 0.08)
	tween.tween_property(visual_root, "scale", Vector3.ONE, 0.12)


func get_debug_data() -> Dictionary:
	return {
		"rooted_target": target.name if target != null and is_instance_valid(target) else "none",
		"remaining": snappedf(maxf(remaining, 0.0), 0.01),
		"pins_rigid_body": rigid_body != null and is_instance_valid(rigid_body),
		"preserves_actions": true,
		"released": released,
	}
