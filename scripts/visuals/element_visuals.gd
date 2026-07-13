extends Node
class_name ElementVisuals

const ELEMENT_COLORS: Dictionary = {
	"fire": Color(1.0, 0.24, 0.045, 1.0),
	"water": Color(0.08, 0.58, 1.0, 1.0),
	"ice": Color(0.56, 0.94, 1.0, 1.0),
	"lightning": Color(0.72, 0.72, 1.0, 1.0),
	"sound": Color(1.0, 0.43, 0.74, 1.0),
	"oil": Color(0.09, 0.055, 0.12, 1.0),
	"steam": Color(0.84, 0.9, 0.96, 1.0),
	"neutral": Color(0.9, 0.9, 0.95, 1.0),
}


static func get_element_color(element: String) -> Color:
	return ELEMENT_COLORS.get(element.to_lower(), ELEMENT_COLORS["neutral"]) as Color


static func make_material(
	color: Color,
	emission_energy: float = 1.0,
	alpha: float = 1.0,
	unshaded: bool = true
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.emission_enabled = emission_energy > 0.0
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = emission_energy
	material.roughness = 0.32

	if alpha < 0.999:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	return material


static func clear_children(root: Node) -> void:
	if root == null:
		return

	for child: Node in root.get_children():
		root.remove_child(child)
		child.queue_free()


static func configure_projectile_visual(root: Node3D, element: String) -> void:
	if root == null:
		return

	clear_children(root)
	root.scale = Vector3.ONE
	root.rotation = Vector3.ZERO
	var color: Color = get_element_color(element)

	match element.to_lower():
		"fire":
			add_sphere(root, "EmberCore", 0.19, color, Vector3.ZERO, Vector3(1.0, 1.0, 1.25), 2.8)
			add_sphere(root, "HotCenter", 0.09, Color(1.0, 0.88, 0.28, 1.0), Vector3(0.0, 0.0, -0.05), Vector3.ONE, 4.0)
			add_sphere(root, "FlameTailA", 0.12, Color(1.0, 0.5, 0.06, 1.0), Vector3(0.0, 0.0, 0.25), Vector3(0.65, 0.65, 1.5), 2.1, 0.78)
			add_sphere(root, "FlameTailB", 0.08, Color(0.9, 0.12, 0.025, 1.0), Vector3(0.0, 0.0, 0.46), Vector3(0.5, 0.5, 1.7), 1.6, 0.52)
			add_light(root, color, 1.75, 3.0)
		"water":
			add_capsule(root, "WaterBody", 0.14, 0.62, color, Vector3.ZERO, Vector3(1.0, 1.0, 1.0), Vector3(90.0, 0.0, 0.0), 2.0, 0.82)
			add_torus(root, "FlowRingA", 0.12, 0.18, Color(0.45, 0.92, 1.0, 1.0), Vector3(0.0, 0.0, -0.13), Vector3(90.0, 0.0, 0.0), 2.2, 0.72)
			add_torus(root, "FlowRingB", 0.09, 0.15, Color(0.2, 0.72, 1.0, 1.0), Vector3(0.0, 0.0, 0.18), Vector3(90.0, 0.0, 0.0), 1.6, 0.58)
			add_sphere(root, "DropletA", 0.055, Color(0.7, 0.96, 1.0, 1.0), Vector3(0.18, 0.08, 0.16), Vector3.ONE, 1.8, 0.8)
			add_sphere(root, "DropletB", 0.04, Color(0.7, 0.96, 1.0, 1.0), Vector3(-0.16, -0.08, 0.27), Vector3.ONE, 1.8, 0.7)
			add_light(root, color, 1.05, 2.2)
		"ice":
			add_box(root, "LanceCore", Vector3(0.22, 0.22, 0.78), color, Vector3(0.0, 0.0, -0.08), Vector3(0.0, 0.0, 45.0), 2.4, 0.92)
			add_box(root, "ShardLeft", Vector3(0.08, 0.12, 0.38), Color(0.82, 0.98, 1.0, 1.0), Vector3(-0.15, 0.03, 0.14), Vector3(0.0, 18.0, -28.0), 1.8, 0.72)
			add_box(root, "ShardRight", Vector3(0.08, 0.12, 0.36), Color(0.72, 0.9, 1.0, 1.0), Vector3(0.15, -0.02, 0.18), Vector3(0.0, -18.0, 28.0), 1.7, 0.68)
			add_torus(root, "FrostHalo", 0.12, 0.2, color, Vector3(0.0, 0.0, 0.22), Vector3(90.0, 0.0, 0.0), 1.4, 0.5)
			add_light(root, color, 1.25, 2.5)
		"lightning":
			add_sphere(root, "SparkCore", 0.12, Color(0.95, 0.95, 1.0, 1.0), Vector3.ZERO, Vector3.ONE, 4.5)
			add_box(root, "ArcA", Vector3(0.055, 0.055, 0.38), color, Vector3(0.09, 0.07, 0.08), Vector3(0.0, 22.0, 24.0), 3.2)
			add_box(root, "ArcB", Vector3(0.05, 0.05, 0.34), Color(0.38, 0.55, 1.0, 1.0), Vector3(-0.08, -0.06, 0.24), Vector3(0.0, -26.0, -30.0), 3.0)
			add_box(root, "ArcC", Vector3(0.045, 0.045, 0.28), Color(1.0, 0.84, 0.28, 1.0), Vector3(0.05, -0.04, -0.18), Vector3(0.0, -15.0, 42.0), 3.5)
			add_torus(root, "ChargeRing", 0.13, 0.21, color, Vector3.ZERO, Vector3(90.0, 0.0, 0.0), 3.0, 0.72)
			add_light(root, color, 2.2, 3.4)
		_:
			add_sphere(root, "ProjectileCore", 0.18, color, Vector3.ZERO, Vector3.ONE, 1.5)
			add_light(root, color, 0.8, 2.0)


static func animate_projectile_visual(root: Node3D, element: String, elapsed: float) -> void:
	if root == null:
		return

	match element.to_lower():
		"fire":
			root.rotation.z = sin(elapsed * 13.0) * 0.18
			root.scale = Vector3.ONE * (1.0 + sin(elapsed * 18.0) * 0.06)
		"water":
			root.rotation.z = elapsed * 2.8
			root.scale = Vector3.ONE * (1.0 + sin(elapsed * 9.0) * 0.035)
		"ice":
			root.rotation.z = elapsed * 1.7
		"lightning":
			root.rotation.z = sin(elapsed * 32.0) * 0.42
			root.scale = Vector3.ONE * (0.9 + abs(sin(elapsed * 29.0)) * 0.2)
		_:
			root.rotation.z = elapsed * 1.1


static func spawn_trail_sample(tree: SceneTree, position: Vector3, element: String, direction: Vector3) -> void:
	if tree == null or tree.current_scene == null:
		return

	var sample := MeshInstance3D.new()
	sample.name = "ElementTrail_" + element
	sample.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var color: Color = get_element_color(element)

	if element == "ice" or element == "lightning":
		var box := BoxMesh.new()
		box.size = Vector3(0.07, 0.07, 0.22)
		sample.mesh = box
	else:
		var sphere := SphereMesh.new()
		sphere.radius = 0.07
		sphere.height = 0.14
		sphere.radial_segments = 8
		sphere.rings = 4
		sample.mesh = sphere

	sample.material_override = make_material(color, 1.5, 0.42)
	tree.current_scene.add_child(sample)
	sample.global_position = position

	if direction.length() > 0.01:
		sample.look_at(position + direction, Vector3.UP)

	sample.scale = Vector3.ONE
	var tween := sample.create_tween()
	tween.tween_property(sample, "scale", Vector3.ZERO, 0.24)
	tween.tween_callback(Callable(sample, "queue_free"))


static func spawn_impact(tree: SceneTree, position: Vector3, element: String, radius: float = 1.0) -> void:
	if tree == null or tree.current_scene == null:
		return

	var burst := Node3D.new()
	burst.name = "ElementImpact_" + element
	tree.current_scene.add_child(burst)
	burst.global_position = position
	var color: Color = get_element_color(element)
	add_sphere(burst, "ImpactCore", 0.18, color, Vector3.ZERO, Vector3.ONE, 2.8, 0.55)
	add_torus(burst, "ImpactRing", 0.16, 0.24, color, Vector3.ZERO, Vector3(90.0, 0.0, 0.0), 2.2, 0.75)

	for index: int in range(5):
		var angle: float = TAU * float(index) / 5.0
		var shard_position := Vector3(cos(angle), 0.15 + float(index % 2) * 0.08, sin(angle)) * 0.28
		add_box(
			burst,
			"ImpactShard" + str(index),
			Vector3(0.045, 0.045, 0.24),
			color,
			shard_position,
			Vector3(0.0, rad_to_deg(angle), 35.0),
			1.9,
			0.72
		)

	burst.scale = Vector3.ONE * 0.22
	var tween := burst.create_tween()
	tween.set_parallel(true)
	tween.tween_property(burst, "scale", Vector3.ONE * radius, 0.26)
	tween.tween_property(burst, "rotation:y", 0.75, 0.26)
	tween.set_parallel(false)
	tween.tween_callback(Callable(burst, "queue_free"))


static func spawn_reaction_burst(
	tree: SceneTree,
	position: Vector3,
	style: String,
	color: Color,
	radius: float = 1.25,
	duration: float = 0.42
) -> void:
	if tree == null or tree.current_scene == null:
		return

	var burst := Node3D.new()
	burst.name = "ReactionBurst_" + style
	tree.current_scene.add_child(burst)
	burst.global_position = position
	add_torus(burst, "GroundRing", 0.28, 0.36, color, Vector3(0.0, -0.25, 0.0), Vector3.ZERO, 3.0, 0.8)
	add_torus(burst, "VerticalRingA", 0.22, 0.3, color, Vector3.ZERO, Vector3(90.0, 0.0, 0.0), 2.4, 0.64)
	add_torus(burst, "VerticalRingB", 0.18, 0.26, color, Vector3.ZERO, Vector3(0.0, 0.0, 90.0), 2.0, 0.54)
	add_sphere(burst, "ReactionCore", 0.16, color, Vector3.ZERO, Vector3.ONE, 3.5, 0.42)

	if style == "steam":
		for index: int in range(5):
			var cloud_position := Vector3(
				(float(index % 3) - 1.0) * 0.22,
				float(index) * 0.1,
				(float(index % 2) - 0.5) * 0.28
			)
			add_sphere(burst, "SteamCloud" + str(index), 0.22, ELEMENT_COLORS["steam"], cloud_position, Vector3(1.3, 0.8, 1.0), 0.7, 0.32)
	elif style == "shatter":
		for index: int in range(8):
			var angle: float = TAU * float(index) / 8.0
			add_box(
				burst,
				"ShatterShard" + str(index),
				Vector3(0.06, 0.12, 0.38),
				get_element_color("ice"),
				Vector3(cos(angle), 0.1 + float(index % 3) * 0.12, sin(angle)) * 0.34,
				Vector3(25.0, rad_to_deg(angle), 35.0),
				2.3,
				0.8
			)

	burst.scale = Vector3.ONE * 0.18
	var tween := burst.create_tween()
	tween.set_parallel(true)
	tween.tween_property(burst, "scale", Vector3.ONE * radius, duration)
	tween.tween_property(burst, "rotation:y", 1.25, duration)
	tween.set_parallel(false)
	tween.tween_callback(Callable(burst, "queue_free"))


static func spawn_sound_pulse(tree: SceneTree, position: Vector3, radius: float, lifetime: float) -> void:
	if tree == null or tree.current_scene == null:
		return

	var pulse := Node3D.new()
	pulse.name = "SoundPulseVisual"
	tree.current_scene.add_child(pulse)
	pulse.global_position = position
	var sound_color: Color = get_element_color("sound")

	for index: int in range(3):
		var ring := add_torus(
			pulse,
			"SoundRing" + str(index),
			0.2,
			0.235,
			sound_color.lightened(float(index) * 0.12),
			Vector3(0.0, 0.08 + float(index) * 0.08, 0.0),
			Vector3.ZERO,
			2.0,
			0.62 - float(index) * 0.1
		)
		ring.scale = Vector3.ONE * (0.18 + float(index) * 0.08)
		var ring_tween := ring.create_tween()
		ring_tween.set_delay(float(index) * 0.055)
		ring_tween.tween_property(ring, "scale", Vector3.ONE * radius, lifetime)

	var vertical_a := add_torus(pulse, "ResonanceA", 0.16, 0.2, sound_color, Vector3(0.0, 0.35, 0.0), Vector3(90.0, 0.0, 0.0), 2.4, 0.54)
	var vertical_b := add_torus(pulse, "ResonanceB", 0.16, 0.2, sound_color, Vector3(0.0, 0.35, 0.0), Vector3(0.0, 0.0, 90.0), 2.4, 0.54)
	vertical_a.scale = Vector3.ONE * 0.2
	vertical_b.scale = Vector3.ONE * 0.2
	vertical_a.create_tween().tween_property(vertical_a, "scale", Vector3.ONE * radius * 0.72, lifetime)
	vertical_b.create_tween().tween_property(vertical_b, "scale", Vector3.ONE * radius * 0.72, lifetime)

	var cleanup := pulse.create_tween()
	cleanup.tween_interval(lifetime + 0.08)
	cleanup.tween_callback(Callable(pulse, "queue_free"))


static func configure_surface_visual(surface: Node3D, profile: String, state: String) -> void:
	if surface == null:
		return

	var root: Node3D = surface.get_node_or_null("ReactionVisualRoot") as Node3D

	if root == null:
		root = Node3D.new()
		root.name = "ReactionVisualRoot"
		surface.add_child(root)

	clear_children(root)
	var mesh_instance: MeshInstance3D = surface.get_node_or_null("MeshInstance3D") as MeshInstance3D
	var color: Color = get_element_color(profile)
	var alpha: float = 0.72
	var emission: float = 0.75

	match state:
		"burning":
			color = get_element_color("fire")
			emission = 2.4
			alpha = 0.82
			for index: int in range(6):
				var angle: float = TAU * float(index) / 6.0
				add_sphere(root, "OilFlame" + str(index), 0.13, color, Vector3(cos(angle) * 1.25, 0.18 + float(index % 2) * 0.08, sin(angle) * 1.25), Vector3(0.72, 1.45, 0.72), 2.7, 0.72)
		"electrified":
			color = get_element_color("lightning")
			emission = 2.8
			for index: int in range(5):
				var angle: float = TAU * float(index) / 5.0
				add_box(root, "WaterArc" + str(index), Vector3(0.045, 0.045, 0.72), color, Vector3(cos(angle) * 1.2, 0.16, sin(angle) * 1.2), Vector3(0.0, rad_to_deg(angle), 32.0 if index % 2 == 0 else -32.0), 3.0, 0.76)
		"frozen":
			color = get_element_color("ice")
			emission = 1.8
			alpha = 0.86
			for index: int in range(8):
				var angle: float = TAU * float(index) / 8.0
				add_box(root, "SurfaceIce" + str(index), Vector3(0.12, 0.34, 0.54), color, Vector3(cos(angle) * 1.45, 0.15, sin(angle) * 1.45), Vector3(22.0, rad_to_deg(angle), 28.0), 1.6, 0.78)
		"steaming":
			color = get_element_color("steam")
			emission = 0.55
			alpha = 0.36
			for index: int in range(7):
				add_sphere(root, "SurfaceSteam" + str(index), 0.28, color, Vector3((float(index % 4) - 1.5) * 0.58, 0.28 + float(index % 3) * 0.2, (float(index % 3) - 1.0) * 0.62), Vector3(1.35, 0.82, 1.0), 0.55, 0.28)
		"shattered":
			color = get_element_color("ice")
			emission = 1.5
			alpha = 0.24
		_:
			if profile == "oil":
				color = get_element_color("oil")
				emission = 0.35
				alpha = 0.84
				add_torus(root, "OilSheenA", 0.55, 0.62, Color(0.5, 0.16, 0.72, 1.0), Vector3(-0.55, 0.08, 0.35), Vector3.ZERO, 0.8, 0.34)
				add_torus(root, "OilSheenB", 0.38, 0.44, Color(0.88, 0.34, 0.18, 1.0), Vector3(0.68, 0.09, -0.42), Vector3.ZERO, 0.65, 0.26)
			elif profile == "water":
				color = get_element_color("water")
				emission = 0.85
				alpha = 0.62
				add_torus(root, "WaterRippleA", 0.42, 0.48, Color(0.54, 0.92, 1.0, 1.0), Vector3(-0.55, 0.07, 0.35), Vector3.ZERO, 1.1, 0.42)
				add_torus(root, "WaterRippleB", 0.68, 0.74, Color(0.2, 0.68, 1.0, 1.0), Vector3(0.5, 0.075, -0.4), Vector3.ZERO, 0.9, 0.32)

	if mesh_instance != null:
		mesh_instance.material_override = make_material(color, emission, alpha, false)

	add_torus(root, "StateBoundary", 1.72, 1.78, color, Vector3(0.0, 0.07, 0.0), Vector3.ZERO, max(emission, 0.8), min(alpha + 0.08, 0.82))


static func animate_surface_visual(surface: Node3D, profile: String, state: String, elapsed: float) -> void:
	if surface == null:
		return

	var root: Node3D = surface.get_node_or_null("ReactionVisualRoot") as Node3D

	if root == null:
		return

	var speed: float = 0.45
	if state == "electrified":
		speed = 4.8
	elif state == "burning":
		speed = 1.8
	elif state == "steaming":
		speed = 0.75
	elif profile == "water":
		speed = 0.7

	root.rotation.y = elapsed * speed
	root.position.y = sin(elapsed * (3.0 if state == "burning" else 1.4)) * 0.025


static func build_status_marker(root: Node3D, status_name: String, height: float, index: int = 0) -> void:
	if root == null:
		return

	var y: float = max(height * 0.58, 0.55) + float(index) * 0.08
	match status_name:
		"wet":
			for item: int in range(3):
				var angle: float = TAU * float(item) / 3.0
				add_sphere(root, "WetDrop" + str(item), 0.07, get_element_color("water"), Vector3(cos(angle) * 0.42, y + float(item) * 0.13, sin(angle) * 0.42), Vector3(0.72, 1.35, 0.72), 1.2, 0.72)
		"oily":
			add_torus(root, "OilStatusRing", 0.38, 0.44, Color(0.46, 0.12, 0.58, 1.0), Vector3(0.0, max(height * 0.48, 0.45), 0.0), Vector3.ZERO, 0.75, 0.46)
		"burning":
			for item: int in range(4):
				var angle: float = TAU * float(item) / 4.0
				add_sphere(root, "BurnStatus" + str(item), 0.11, get_element_color("fire"), Vector3(cos(angle) * 0.38, y + float(item % 2) * 0.22, sin(angle) * 0.38), Vector3(0.68, 1.5, 0.68), 2.3, 0.7)
		"frozen":
			add_sphere(root, "FrozenShell", max(height * 0.34, 0.38), get_element_color("ice"), Vector3(0.0, max(height * 0.48, 0.48), 0.0), Vector3(0.78, 1.25, 0.78), 1.25, 0.18)
			for item: int in range(4):
				var angle: float = TAU * float(item) / 4.0
				add_box(root, "FrozenShard" + str(item), Vector3(0.07, 0.26, 0.42), get_element_color("ice"), Vector3(cos(angle) * 0.46, y, sin(angle) * 0.46), Vector3(20.0, rad_to_deg(angle), 35.0), 1.8, 0.68)
		"stunned":
			for item: int in range(3):
				var angle: float = TAU * float(item) / 3.0
				add_box(root, "StunArc" + str(item), Vector3(0.045, 0.045, 0.38), get_element_color("lightning"), Vector3(cos(angle) * 0.45, y + 0.15, sin(angle) * 0.45), Vector3(0.0, rad_to_deg(angle), 38.0 if item % 2 == 0 else -38.0), 3.2, 0.82)
		"steamed":
			for item: int in range(4):
				add_sphere(root, "SteamStatus" + str(item), 0.18, get_element_color("steam"), Vector3((float(item % 2) - 0.5) * 0.35, y + float(item) * 0.13, (float(item % 3) - 1.0) * 0.22), Vector3(1.2, 0.82, 1.0), 0.45, 0.28)
		"revealed":
			add_torus(root, "RevealRingA", 0.42, 0.48, get_element_color("sound"), Vector3(0.0, y, 0.0), Vector3(90.0, 0.0, 0.0), 2.2, 0.64)
			add_torus(root, "RevealRingB", 0.32, 0.38, get_element_color("sound"), Vector3(0.0, y, 0.0), Vector3(0.0, 0.0, 90.0), 1.8, 0.52)
		_:
			pass


static func estimate_target_height(target: Node) -> float:
	if target == null:
		return 1.4

	var height: float = 0.0
	for child: Node in target.get_children():
		if child is CollisionShape3D:
			var shape: Shape3D = (child as CollisionShape3D).shape
			if shape is CapsuleShape3D:
				height = max(height, (shape as CapsuleShape3D).height)
			elif shape is BoxShape3D:
				height = max(height, (shape as BoxShape3D).size.y)
			elif shape is SphereShape3D:
				height = max(height, (shape as SphereShape3D).radius * 2.0)
			elif shape is CylinderShape3D:
				height = max(height, (shape as CylinderShape3D).height)

	return max(height, 1.0)


static func add_sphere(
	root: Node3D,
	name_value: String,
	radius: float,
	color: Color,
	position_value: Vector3 = Vector3.ZERO,
	scale_value: Vector3 = Vector3.ONE,
	emission: float = 1.0,
	alpha: float = 1.0
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_value
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	node.mesh = mesh
	node.position = position_value
	node.scale = scale_value
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.material_override = make_material(color, emission, alpha)
	root.add_child(node)
	return node


static func add_box(
	root: Node3D,
	name_value: String,
	size: Vector3,
	color: Color,
	position_value: Vector3 = Vector3.ZERO,
	rotation_degrees_value: Vector3 = Vector3.ZERO,
	emission: float = 1.0,
	alpha: float = 1.0
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_value
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = position_value
	node.rotation_degrees = rotation_degrees_value
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.material_override = make_material(color, emission, alpha)
	root.add_child(node)
	return node


static func add_capsule(
	root: Node3D,
	name_value: String,
	radius: float,
	height: float,
	color: Color,
	position_value: Vector3 = Vector3.ZERO,
	scale_value: Vector3 = Vector3.ONE,
	rotation_degrees_value: Vector3 = Vector3.ZERO,
	emission: float = 1.0,
	alpha: float = 1.0
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_value
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 4
	node.mesh = mesh
	node.position = position_value
	node.scale = scale_value
	node.rotation_degrees = rotation_degrees_value
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.material_override = make_material(color, emission, alpha)
	root.add_child(node)
	return node


static func add_torus(
	root: Node3D,
	name_value: String,
	inner_radius: float,
	outer_radius: float,
	color: Color,
	position_value: Vector3 = Vector3.ZERO,
	rotation_degrees_value: Vector3 = Vector3.ZERO,
	emission: float = 1.0,
	alpha: float = 1.0
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_value
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 16
	mesh.ring_segments = 8
	node.mesh = mesh
	node.position = position_value
	node.rotation_degrees = rotation_degrees_value
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.material_override = make_material(color, emission, alpha)
	root.add_child(node)
	return node


static func add_light(root: Node3D, color: Color, energy: float, range_value: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = "ElementLight"
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	light.shadow_enabled = false
	root.add_child(light)
	return light
