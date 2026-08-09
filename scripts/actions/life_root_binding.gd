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
var original_freeze_mode: int = RigidBody3D.FREEZE_MODE_STATIC
var released: bool = false
var visual_root: Node3D = null
var elapsed: float = 0.0
var visual_root_radius: float = 0.0
var visual_target_height: float = 0.0
var visual_base_y: float = 0.0


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
		original_freeze_mode = int(rigid_body.freeze_mode)
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
		visual_root.rotation.y = sin(elapsed * 1.8) * 0.028

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
		tween.tween_property(
			visual_root,
			"scale",
			Vector3(1.1, 0.04, 1.1),
			0.2
		)
		tween.tween_callback(Callable(self, "queue_free"))
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

	var bounds: Dictionary = _estimate_target_bounds()
	visual_target_height = clampf(float(bounds.get("height", 1.0)), 0.6, 4.2)
	visual_base_y = float(bounds.get("min_y", 0.0)) - 0.025
	var measured_radius: float = float(bounds.get("radius", 0.45))
	var outside_margin: float = clampf(measured_radius * 0.18, 0.18, 0.42)
	visual_root_radius = clampf(measured_radius + outside_margin, 0.5, 2.8)

	var bark_material := StandardMaterial3D.new()
	bark_material.albedo_color = Color(0.27, 0.125, 0.035, 1.0)
	bark_material.roughness = 0.94
	var life_material := StandardMaterial3D.new()
	life_material.albedo_color = Color(0.18, 0.7, 0.11, 1.0)
	life_material.emission_enabled = true
	life_material.emission = Color(0.08, 0.5, 0.055, 1.0)
	life_material.emission_energy_multiplier = 0.72
	life_material.roughness = 0.8

	_add_binding_ring(
		"RootCrown",
		visual_root_radius,
		visual_base_y + 0.06,
		0.0,
		bark_material
	)

	var climb_height: float = clampf(visual_target_height * 0.74, 0.72, 3.0)
	var root_thickness: float = clampf(visual_root_radius * 0.12, 0.085, 0.19)
	for index: int in range(12):
		var angle: float = TAU * float(index) / 12.0
		var root := MeshInstance3D.new()
		root.name = "BindingRoot" + str(index + 1)
		var mesh := CylinderMesh.new()
		mesh.top_radius = root_thickness * (0.48 + float(index % 3) * 0.08)
		mesh.bottom_radius = root_thickness * (0.9 + float(index % 2) * 0.12)
		var height: float = climb_height * (0.82 + float(index % 4) * 0.055)
		mesh.height = height
		mesh.radial_segments = 7
		root.mesh = mesh
		root.material_override = bark_material if index % 3 != 1 else life_material
		var radial_distance: float = visual_root_radius * (0.9 + float(index % 2) * 0.035)
		root.position = Vector3(
			cos(angle) * radial_distance,
			visual_base_y + height * 0.5,
			sin(angle) * radial_distance
		)
		var inward_lean: float = 0.28 + float(index % 3) * 0.035
		root.rotation = Vector3(
			sin(angle) * inward_lean,
			-angle,
			cos(angle) * -inward_lean
		)
		visual_root.add_child(root)

	# Two broad bands wrap outside the target itself. They make Root Bind legible
	# on crates and other solid props whose mesh can hide roots near the origin.
	var lower_band_y: float = visual_base_y + visual_target_height * 0.32
	var upper_band_y: float = visual_base_y + visual_target_height * 0.61
	_add_binding_ring(
		"LowerBindingBand",
		visual_root_radius * 0.97,
		lower_band_y,
		5.0,
		life_material
	)
	_add_binding_ring(
		"UpperBindingBand",
		visual_root_radius * 0.94,
		upper_band_y,
		-6.0,
		bark_material
	)

	# Small leaf buds around the crown add a clear Life read without hiding the
	# target beneath a giant opaque effect.
	for index: int in range(6):
		var angle: float = TAU * (float(index) + 0.5) / 6.0
		var bud := MeshInstance3D.new()
		bud.name = "RootBud" + str(index + 1)
		var bud_mesh := SphereMesh.new()
		bud_mesh.radius = root_thickness * 0.72
		bud_mesh.height = root_thickness * 1.1
		bud_mesh.radial_segments = 7
		bud_mesh.rings = 4
		bud.mesh = bud_mesh
		bud.material_override = life_material
		bud.position = Vector3(
			cos(angle) * visual_root_radius,
			visual_base_y + 0.14,
			sin(angle) * visual_root_radius
		)
		visual_root.add_child(bud)

	visual_root.scale = Vector3(1.0, 0.035, 1.0)
	var grow := create_tween()
	grow.set_trans(Tween.TRANS_BACK)
	grow.set_ease(Tween.EASE_OUT)
	grow.tween_property(visual_root, "scale", Vector3.ONE, 0.2)


func _add_binding_ring(
	node_name: String,
	radius: float,
	y_position: float,
	tilt_degrees: float,
	material: Material
) -> void:
	if visual_root == null:
		return
	var ring := MeshInstance3D.new()
	ring.name = node_name
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(radius * 0.79, 0.08)
	torus.outer_radius = maxf(radius, 0.12)
	torus.rings = 28
	torus.ring_segments = 9
	ring.mesh = torus
	ring.material_override = material
	ring.position.y = y_position
	ring.rotation_degrees = Vector3(tilt_degrees, 0.0, tilt_degrees * 0.55)
	visual_root.add_child(ring)


func _estimate_target_bounds() -> Dictionary:
	if target == null or not is_instance_valid(target):
		return {"min_y": 0.0, "max_y": 1.0, "height": 1.0, "radius": 0.45}

	var state: Dictionary = {
		"found": false,
		"min_y": INF,
		"max_y": -INF,
		"radius": 0.0,
	}
	_accumulate_collision_bounds(target, target, state)
	if not bool(state.get("found", false)):
		_accumulate_mesh_bounds(target, target, state)

	if not bool(state.get("found", false)):
		var fallback_height: float = clampf(
			ElementVisuals.estimate_target_height(target),
			0.7,
			2.8
		)
		return {
			"min_y": 0.0,
			"max_y": fallback_height,
			"height": fallback_height,
			"radius": maxf(fallback_height * 0.34, 0.42),
		}

	var min_y: float = float(state.get("min_y", 0.0))
	var max_y: float = float(state.get("max_y", min_y + 1.0))
	return {
		"min_y": min_y,
		"max_y": max_y,
		"height": maxf(max_y - min_y, 0.5),
		"radius": maxf(float(state.get("radius", 0.42)), 0.32),
	}


func _accumulate_collision_bounds(root: Node3D, node: Node, state: Dictionary) -> void:
	if node is CollisionShape3D:
		var collision := node as CollisionShape3D
		if collision.shape != null and not collision.disabled:
			var relative: Transform3D = (
				root.global_transform.affine_inverse() * collision.global_transform
			)
			var scale: Vector3 = relative.basis.get_scale().abs()
			var shape_bounds: Dictionary = _get_shape_bounds(collision.shape, scale)
			if not shape_bounds.is_empty():
				_update_bounds_state(
					state,
					relative.origin.y,
					float(shape_bounds.get("half_y", 0.5)),
					float(shape_bounds.get("radius", 0.4))
				)
	for child: Node in node.get_children():
		_accumulate_collision_bounds(root, child, state)


func _get_shape_bounds(shape: Shape3D, scale: Vector3) -> Dictionary:
	if shape is BoxShape3D:
		var box := shape as BoxShape3D
		var half: Vector3 = box.size * scale * 0.5
		return {
			"half_y": half.y,
			"radius": Vector2(half.x, half.z).length(),
		}
	if shape is SphereShape3D:
		var sphere := shape as SphereShape3D
		return {
			"half_y": sphere.radius * scale.y,
			"radius": sphere.radius * maxf(scale.x, scale.z),
		}
	if shape is CapsuleShape3D:
		var capsule := shape as CapsuleShape3D
		return {
			"half_y": capsule.height * scale.y * 0.5,
			"radius": capsule.radius * maxf(scale.x, scale.z),
		}
	if shape is CylinderShape3D:
		var cylinder := shape as CylinderShape3D
		return {
			"half_y": cylinder.height * scale.y * 0.5,
			"radius": cylinder.radius * maxf(scale.x, scale.z),
		}
	return {}


func _accumulate_mesh_bounds(root: Node3D, node: Node, state: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			var relative: Transform3D = (
				root.global_transform.affine_inverse() * mesh_instance.global_transform
			)
			var scale: Vector3 = relative.basis.get_scale().abs()
			var aabb: AABB = mesh_instance.mesh.get_aabb()
			var half: Vector3 = aabb.size * scale * 0.5
			var center_y: float = (
				relative.origin.y + aabb.get_center().y * scale.y
			)
			_update_bounds_state(
				state,
				center_y,
				half.y,
				Vector2(half.x, half.z).length()
			)
	for child: Node in node.get_children():
		_accumulate_mesh_bounds(root, child, state)


func _update_bounds_state(
	state: Dictionary,
	center_y: float,
	half_y: float,
	radius: float
) -> void:
	state["found"] = true
	state["min_y"] = minf(float(state.get("min_y", INF)), center_y - half_y)
	state["max_y"] = maxf(float(state.get("max_y", -INF)), center_y + half_y)
	state["radius"] = maxf(float(state.get("radius", 0.0)), radius)


func _pulse_visual() -> void:
	if visual_root == null:
		return
	visual_root.scale = Vector3.ONE
	var tween := create_tween()
	tween.tween_property(visual_root, "scale", Vector3(1.08, 1.045, 1.08), 0.08)
	tween.tween_property(visual_root, "scale", Vector3.ONE, 0.12)


func get_debug_data() -> Dictionary:
	return {
		"rooted_target": target.name if target != null and is_instance_valid(target) else "none",
		"remaining": snappedf(maxf(remaining, 0.0), 0.01),
		"pins_rigid_body": rigid_body != null and is_instance_valid(rigid_body),
		"preserves_actions": true,
		"visual_radius": snappedf(visual_root_radius, 0.01),
		"visual_height": snappedf(visual_target_height, 0.01),
		"visual_base_y": snappedf(visual_base_y, 0.01),
		"bounds_driven_visual": true,
		"released": released,
	}
