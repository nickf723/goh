extends RefCounted
class_name ElementVfxGalleryBuilder

const WaterfallShader: Shader = preload("res://shaders/waterfall_curtain_v1.gdshader")


static func build(host: Node3D) -> Dictionary:
	build_room_shell(host)
	build_lighting(host)
	build_header(host)

	var impact_profile := make_profile(
		Color(0.08, 0.58, 0.88, 0.72),
		Color(0.012, 0.11, 0.31, 0.88),
		0.1,
		1.05,
		0.12
	)
	var motion_profile := make_profile(
		Color(0.06, 0.7, 0.94, 0.74),
		Color(0.008, 0.14, 0.34, 0.9),
		0.13,
		1.35,
		0.24
	)
	var theater_profile := make_profile(
		Color(0.07, 0.6, 0.9, 0.74),
		Color(0.006, 0.08, 0.25, 0.92),
		0.17,
		1.55,
		0.2
	)
	theater_profile.maximum_active_effects = 180
	theater_profile.ripple_duration = 1.2
	theater_profile.wake_duration = 1.4

	var impact_pool := add_pool(
		host,
		"ImpactPool",
		Vector3(-9.0, -0.85, -1.0),
		Vector3(6.0, 2.4, 6.0),
		Vector3.ZERO,
		impact_profile
	)
	var motion_pool := add_pool(
		host,
		"MotionPool",
		Vector3(9.0, -0.85, -1.0),
		Vector3(6.0, 2.4, 6.0),
		Vector3(0.0, 0.0, -1.8),
		motion_profile
	)
	var theater_pool := add_pool(
		host,
		"WaterMotionTheater",
		Vector3(0.0, -1.05, 7.2),
		Vector3(16.0, 3.0, 10.0),
		Vector3(2.4, 0.0, -0.35),
		theater_profile
	)

	add_pool_borders(host, impact_pool, Color(0.06, 0.1, 0.16, 1.0))
	add_pool_borders(host, motion_pool, Color(0.05, 0.11, 0.17, 1.0))
	add_pool_borders(host, theater_pool, Color(0.035, 0.075, 0.12, 1.0))

	var waterfall := add_waterfall(host, theater_pool)
	var consoles := add_control_deck(host)
	var bays: Array[Node3D] = add_element_bays(host)

	var impact_readout := ThermalLabGeometry.add_label(
		host,
		"ImpactReadout",
		"IMPACT STAGE",
		Vector3(-9.0, 3.25, -3.9),
		20,
		Color(0.62, 0.9, 1.0, 1.0)
	)
	var motion_readout := ThermalLabGeometry.add_label(
		host,
		"MotionReadout",
		"MOTION STAGE",
		Vector3(9.0, 3.25, -3.9),
		20,
		Color(0.55, 0.94, 1.0, 1.0)
	)
	var theater_readout := ThermalLabGeometry.add_label(
		host,
		"TheaterReadout",
		"WATER MOTION THEATER",
		Vector3(0.0, 6.8, 11.3),
		22,
		Color(0.55, 0.9, 1.0, 1.0)
	)
	var control_readout := ThermalLabGeometry.add_label(
		host,
		"ControlReadout",
		"GALLERY CONTROLS",
		Vector3(0.0, 3.2, -8.0),
		20,
		Color(0.82, 0.9, 1.0, 1.0)
	)

	return {
		"impact_pool": impact_pool,
		"motion_pool": motion_pool,
		"theater_pool": theater_pool,
		"waterfall": waterfall,
		"consoles": consoles,
		"element_bays": bays,
		"impact_readout": impact_readout,
		"motion_readout": motion_readout,
		"theater_readout": theater_readout,
		"control_readout": control_readout,
	}


static func build_room_shell(host: Node3D) -> void:
	var floor_color := Color(0.025, 0.035, 0.055, 1.0)
	var wall_color := Color(0.045, 0.06, 0.095, 1.0)
	ThermalLabGeometry.add_static_box(
		host, "GalleryFloor", Vector3(0.0, -0.55, 3.0), Vector3(34.0, 1.0, 30.0), floor_color
	)
	ThermalLabGeometry.add_static_box(
		host, "BackWall", Vector3(0.0, 4.0, 17.5), Vector3(34.0, 9.0, 0.7), wall_color
	)
	ThermalLabGeometry.add_static_box(
		host, "LeftWall", Vector3(-17.0, 4.0, 3.0), Vector3(0.7, 9.0, 30.0), wall_color
	)
	ThermalLabGeometry.add_static_box(
		host, "RightWall", Vector3(17.0, 4.0, 3.0), Vector3(0.7, 9.0, 30.0), wall_color
	)
	ThermalLabGeometry.add_static_box(
		host, "FrontRail", Vector3(0.0, 0.1, -11.9), Vector3(28.0, 0.8, 0.35), Color(0.08, 0.13, 0.2, 1.0)
	)


static func build_lighting(host: Node3D) -> void:
	var directional := DirectionalLight3D.new()
	directional.name = "GalleryDirectionalLight"
	directional.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	directional.light_energy = 1.15
	directional.shadow_enabled = true
	host.add_child(directional)

	var water_light := OmniLight3D.new()
	water_light.name = "WaterTheaterLight"
	water_light.position = Vector3(0.0, 6.0, 6.0)
	water_light.light_color = Color(0.25, 0.62, 1.0, 1.0)
	water_light.light_energy = 5.2
	water_light.omni_range = 24.0
	host.add_child(water_light)

	for side: float in [-1.0, 1.0]:
		var aisle_light := OmniLight3D.new()
		aisle_light.name = "AisleLight" + str(int(side))
		aisle_light.position = Vector3(11.5 * side, 3.8, 0.5)
		aisle_light.light_color = Color(0.3, 0.52, 0.9, 1.0)
		aisle_light.light_energy = 2.8
		aisle_light.omni_range = 13.0
		host.add_child(aisle_light)


static func build_header(host: Node3D) -> void:
	ThermalLabGeometry.add_label(
		host,
		"Title",
		"ELEMENT VFX GALLERY",
		Vector3(0.0, 6.4, -10.8),
		46,
		Color(0.55, 0.88, 1.0, 1.0)
	)
	ThermalLabGeometry.add_label(
		host,
		"Instructions",
		"TRIGGER • CYCLE • AUTO REPLAY • INTENSITY • FLOW • STATE • SLOW MOTION • F8 RESET",
		Vector3(0.0, 5.55, -10.5),
		19,
		Color(0.78, 0.88, 1.0, 1.0)
	)


static func make_profile(
	shallow: Color,
	deep: Color,
	amplitude: float,
	speed: float,
	flow_strength: float
) -> FluidPresentationProfile:
	var profile := FluidPresentationProfile.new()
	profile.shallow_color = shallow
	profile.deep_color = deep
	profile.foam_color = Color(0.72, 0.97, 1.0, 0.94)
	profile.wave_amplitude = amplitude
	profile.wave_speed = speed
	profile.flow_band_strength = flow_strength
	profile.surface_emission = 0.16
	profile.maximum_active_effects = 110
	return profile


static func add_pool(
	parent: Node3D,
	node_name: String,
	position_value: Vector3,
	size: Vector3,
	flow: Vector3,
	profile: FluidPresentationProfile
) -> FluidForceVolume:
	var pool := FluidForceVolume.new()
	pool.name = node_name
	pool.position = position_value
	pool.volume_size = size
	pool.fluid_density_kg_m3 = 1000.0
	pool.flow_velocity_m_s = flow
	pool.presentation_profile = profile
	pool.presentation_enabled = true
	pool.create_default_visuals = true
	parent.add_child(pool)
	return pool


static func add_pool_borders(parent: Node3D, pool: FluidForceVolume, color: Color) -> void:
	var size: Vector3 = pool.volume_size
	var center: Vector3 = pool.position
	var bottom_y: float = center.y - size.y * 0.5 - 0.18
	ThermalLabGeometry.add_static_box(
		parent, pool.name + "Bottom", Vector3(center.x, bottom_y, center.z),
		Vector3(size.x + 0.5, 0.36, size.z + 0.5), color
	)
	ThermalLabGeometry.add_static_box(
		parent, pool.name + "Left", Vector3(center.x - size.x * 0.5 - 0.18, center.y, center.z),
		Vector3(0.36, size.y + 0.55, size.z + 0.55), color
	)
	ThermalLabGeometry.add_static_box(
		parent, pool.name + "Right", Vector3(center.x + size.x * 0.5 + 0.18, center.y, center.z),
		Vector3(0.36, size.y + 0.55, size.z + 0.55), color
	)
	ThermalLabGeometry.add_static_box(
		parent, pool.name + "Front", Vector3(center.x, center.y, center.z - size.z * 0.5 - 0.18),
		Vector3(size.x + 0.55, size.y + 0.55, 0.36), color
	)
	ThermalLabGeometry.add_static_box(
		parent, pool.name + "Back", Vector3(center.x, center.y, center.z + size.z * 0.5 + 0.18),
		Vector3(size.x + 0.55, size.y + 0.55, 0.36), color
	)


static func add_waterfall(parent: Node3D, pool: FluidForceVolume) -> MeshInstance3D:
	var wall := ThermalLabGeometry.add_static_box(
		parent,
		"WaterfallRockWall",
		Vector3(0.0, 3.3, 12.0),
		Vector3(8.0, 7.2, 0.8),
		Color(0.04, 0.07, 0.11, 1.0)
	)
	wall.add_to_group("vfx_gallery_waterfall_support")

	var curtain := MeshInstance3D.new()
	curtain.name = "ProceduralWaterfallCurtain"
	var plane := PlaneMesh.new()
	plane.size = Vector2(6.2, 6.5)
	plane.subdivide_width = 24
	plane.subdivide_depth = 36
	curtain.mesh = plane
	curtain.position = Vector3(0.0, 3.6, 11.5)
	curtain.rotation_degrees.x = 90.0
	curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = WaterfallShader
	material.set_shader_parameter("flow_speed", 1.25)
	material.set_shader_parameter("turbulence", 0.42)
	curtain.material_override = material
	parent.add_child(curtain)

	var impact_marker := MeshInstance3D.new()
	impact_marker.name = "WaterfallImpactMist"
	var mist_mesh := TorusMesh.new()
	mist_mesh.inner_radius = 1.1
	mist_mesh.outer_radius = 1.35
	mist_mesh.rings = 36
	mist_mesh.ring_segments = 10
	impact_marker.mesh = mist_mesh
	impact_marker.position = Vector3(0.0, pool.get_surface_y() + 0.04, 10.4)
	impact_marker.scale = Vector3(1.8, 0.08, 0.9)
	impact_marker.material_override = ThermalLabGeometry.make_material(Color(0.7, 0.96, 1.0, 0.36), true, 0.8)
	parent.add_child(impact_marker)
	return curtain


static func add_control_deck(host: Node3D) -> Dictionary:
	var consoles: Dictionary = {}
	consoles["impact_trigger"] = add_console(host, "ImpactTrigger", "impact_trigger", "Trigger impact stage", Vector3(-11.0, 0.4, -6.7), Color(0.1, 0.58, 0.95, 1.0))
	consoles["impact_cycle"] = add_console(host, "ImpactCycle", "impact_cycle", "Cycle impact effect", Vector3(-7.0, 0.4, -6.7), Color(0.18, 0.72, 1.0, 1.0))
	consoles["motion_trigger"] = add_console(host, "MotionTrigger", "motion_trigger", "Trigger motion stage", Vector3(7.0, 0.4, -6.7), Color(0.08, 0.76, 0.92, 1.0))
	consoles["motion_cycle"] = add_console(host, "MotionCycle", "motion_cycle", "Cycle motion effect", Vector3(11.0, 0.4, -6.7), Color(0.24, 0.88, 1.0, 1.0))
	consoles["toggle_auto"] = add_console(host, "AutoReplay", "toggle_auto", "Toggle automatic replay", Vector3(-7.5, 0.4, -9.0), Color(0.45, 0.34, 1.0, 1.0))
	consoles["cycle_intensity"] = add_console(host, "Intensity", "cycle_intensity", "Cycle preview intensity", Vector3(-3.8, 0.4, -9.0), Color(0.86, 0.36, 1.0, 1.0))
	consoles["reverse_flow"] = add_console(host, "ReverseFlow", "reverse_flow", "Reverse theater current", Vector3(0.0, 0.4, -9.0), Color(0.12, 0.72, 1.0, 1.0))
	consoles["cycle_state"] = add_console(host, "WaterState", "cycle_state", "Cycle water visual state", Vector3(3.8, 0.4, -9.0), Color(0.24, 0.9, 0.78, 1.0))
	consoles["toggle_waterfall"] = add_console(host, "Waterfall", "toggle_waterfall", "Toggle waterfall", Vector3(7.5, 0.4, -9.0), Color(0.38, 0.72, 1.0, 1.0))
	consoles["toggle_slow_motion"] = add_console(host, "SlowMotion", "toggle_slow_motion", "Toggle slow motion", Vector3(11.2, 0.4, -9.0), Color(1.0, 0.62, 0.18, 1.0))
	consoles["clear_effects"] = add_console(host, "ClearEffects", "clear_effects", "Clear active effects", Vector3(-11.2, 0.4, -9.0), Color(0.92, 0.22, 0.3, 1.0))
	return consoles


static func add_console(
	parent: Node3D,
	node_name: String,
	action_id: String,
	prompt: String,
	position_value: Vector3,
	color: Color
) -> VfxGalleryConsole:
	var console := VfxGalleryConsole.new()
	console.name = node_name
	console.position = position_value
	console.configure(parent, action_id, prompt)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.5, 1.0, 1.2)
	collision.shape = shape
	console.add_child(collision)
	ThermalLabGeometry.add_box_visual(console, "ConsoleVisual", Vector3(2.5, 1.0, 1.2), color, true, 1.5)
	ThermalLabGeometry.add_label(console, "ConsoleLabel", action_id.replace("_", " ").to_upper(), Vector3(0.0, 0.9, 0.0), 15, Color.WHITE)
	parent.add_child(console)
	return console


static func add_element_bays(parent: Node3D) -> Array[Node3D]:
	var elements: Array[Dictionary] = [
		{"id": "death", "name": "DEATH", "color": Color(0.82, 0.06, 0.08, 1.0)},
		{"id": "fire", "name": "FIRE", "color": Color(1.0, 0.18, 0.08, 1.0)},
		{"id": "sound", "name": "SOUND", "color": Color(1.0, 0.43, 0.05, 1.0)},
		{"id": "time", "name": "TIME", "color": Color(1.0, 0.66, 0.08, 1.0)},
		{"id": "metal", "name": "METAL", "color": Color(1.0, 0.9, 0.08, 1.0)},
		{"id": "poison", "name": "POISON", "color": Color(0.65, 0.92, 0.08, 1.0)},
		{"id": "earth", "name": "EARTH", "color": Color(0.14, 0.72, 0.18, 1.0)},
		{"id": "life", "name": "LIFE", "color": Color(0.05, 0.58, 0.36, 1.0)},
		{"id": "ice", "name": "ICE", "color": Color(0.1, 0.86, 0.8, 1.0)},
		{"id": "soul", "name": "SOUL", "color": Color(0.08, 0.86, 1.0, 1.0)},
		{"id": "water", "name": "WATER", "color": Color(0.05, 0.46, 1.0, 1.0)},
		{"id": "dreams", "name": "DREAMS", "color": Color(0.08, 0.22, 0.95, 1.0)},
		{"id": "lightning", "name": "LIGHTNING", "color": Color(0.27, 0.08, 0.96, 1.0)},
		{"id": "space", "name": "SPACE", "color": Color(0.56, 0.08, 0.92, 1.0)},
		{"id": "air", "name": "AIR", "color": Color(1.0, 0.22, 0.68, 1.0)},
		{"id": "body", "name": "BODY", "color": Color(0.92, 0.08, 0.48, 1.0)},
	]
	var bays: Array[Node3D] = []
	for index: int in range(elements.size()):
		var data: Dictionary = elements[index]
		var side: float = -1.0 if index < 8 else 1.0
		var local_index: int = index if index < 8 else index - 8
		var z_position: float = -7.0 + float(local_index) * 3.0
		var bay := Node3D.new()
		bay.name = "ElementBay_" + str(data.get("id", "unknown"))
		bay.position = Vector3(15.2 * side, 1.0, z_position)
		bay.add_to_group("vfx_gallery_element_bays")
		var element_id: String = str(data.get("id", "unknown"))
		var active: bool = element_id == "water"
		bay.set_meta("element_id", element_id)
		bay.set_meta("active", active)
		var color: Color = data.get("color", Color.WHITE) as Color
		var display_color: Color = color if active else color.darkened(0.65)
		ThermalLabGeometry.add_box_visual(bay, "Pylon", Vector3(0.85, 2.2, 0.85), display_color, true, 2.6 if active else 0.18)
		ThermalLabGeometry.add_label(bay, "Label", str(data.get("name", "UNKNOWN")), Vector3(0.0, 1.55, 0.0), 14, color if active else Color(0.46, 0.5, 0.58, 1.0))
		parent.add_child(bay)
		bays.append(bay)
	return bays
