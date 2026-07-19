extends Node3D
class_name LightningGalleryWing

@export var readout_interval: float = 0.08

var gallery: ElementVfxGallery
var water_pool: FluidForceVolume
var renderer: LightningArcRenderer
var exhibit: VfxGalleryExhibit
var readout: Label3D
var source_orb: MeshInstance3D
var direct_target: Node3D
var storm_target: Node3D
var circuit_left: Node3D
var circuit_right: Node3D
var chain_targets: Array[Node3D] = []
var initialized: bool = false
var local_auto_enabled: bool = true
var readout_timer: float = 0.0
var seed_counter: int = 7001
var manual_trigger_count: int = 0


func _ready() -> void:
	add_to_group("lightning_gallery_wing")
	add_to_group("debuggable")
	add_to_group("lab_resettable")
	call_deferred("initialize_wing")


func initialize_wing() -> void:
	gallery = get_parent() as ElementVfxGallery
	if gallery == null:
		push_warning("Lightning Gallery Wing requires ElementVfxGallery as its parent.")
		return
	water_pool = gallery.theater_pool
	build_stage()
	build_exhibit()
	activate_lightning_bay()
	initialized = true
	set_auto_play(true)
	update_readout()


func _process(delta: float) -> void:
	if not initialized:
		return
	if gallery != null and exhibit != null:
		var desired_auto: bool = gallery.auto_replay_enabled and local_auto_enabled
		if exhibit.auto_play != desired_auto:
			exhibit.set_auto_play(desired_auto)
	readout_timer -= max(delta, 0.0)
	if readout_timer <= 0.0:
		readout_timer = max(readout_interval, 0.03)
		update_readout()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		reset_target()


func build_stage() -> void:
	renderer = LightningArcRenderer.new()
	renderer.name = "LightningArcRenderer"
	add_child(renderer)

	ThermalLabGeometry.add_static_box(
		self,
		"LightningStageFloor",
		Vector3(11.1, 0.05, 10.2),
		Vector3(9.6, 0.7, 12.5),
		Color(0.035, 0.025, 0.11, 1.0)
	)
	ThermalLabGeometry.add_label(
		self,
		"LightningWingTitle",
		"PROCEDURAL LIGHTNING",
		Vector3(11.1, 7.8, 5.1),
		32,
		Color(0.66, 0.58, 1.0, 1.0)
	)
	ThermalLabGeometry.add_label(
		self,
		"LightningWingSubtitle",
		"FRACTAL TRUNK • BRANCHES • CHAIN • CIRCUIT • WATER",
		Vector3(11.1, 7.15, 5.2),
		15,
		Color(0.78, 0.82, 1.0, 1.0)
	)

	source_orb = add_orb("LightningSource", Vector3(11.1, 6.4, 8.2), 0.38, Color(0.72, 0.68, 1.0, 1.0), 6.5)
	direct_target = add_target_pylon("DirectTarget", Vector3(11.1, 1.25, 8.2), Color(0.32, 0.2, 0.92, 1.0))
	storm_target = add_target_pylon("StormTarget", Vector3(14.2, 1.25, 13.5), Color(0.5, 0.16, 1.0, 1.0))
	circuit_left = add_target_pylon("CircuitTerminalA", Vector3(9.55, 1.0, 5.8), Color(0.18, 0.45, 1.0, 1.0), Vector3(0.52, 1.6, 0.52))
	circuit_right = add_target_pylon("CircuitTerminalB", Vector3(12.65, 1.0, 5.8), Color(0.72, 0.36, 1.0, 1.0), Vector3(0.52, 1.6, 0.52))

	var chain_positions: Array[Vector3] = [
		Vector3(8.5, 1.15, 12.6),
		Vector3(10.2, 1.75, 14.2),
		Vector3(12.1, 1.1, 13.0),
		Vector3(14.0, 1.85, 14.7),
	]
	for index: int in range(chain_positions.size()):
		chain_targets.append(add_target_pylon(
			"ChainTarget" + str(index + 1),
			chain_positions[index],
			Color(0.32 + float(index) * 0.11, 0.2, 1.0, 1.0),
			Vector3(0.58, 1.7 + float(index % 2) * 0.45, 0.58)
		))

	readout = ThermalLabGeometry.add_label(
		self,
		"LightningReadout",
		"LIGHTNING ENGINE",
		Vector3(11.1, 4.15, 5.35),
		18,
		Color(0.78, 0.84, 1.0, 1.0)
	)
	add_console("TriggerConsole", "trigger", "TRIGGER", Vector3(9.2, 0.85, 3.8), Color(0.3, 0.18, 0.86, 1.0))
	add_console("CycleConsole", "cycle", "NEXT TYPE", Vector3(11.1, 0.85, 3.8), Color(0.48, 0.2, 0.98, 1.0))
	add_console("AutoConsole", "toggle_auto", "AUTO", Vector3(13.0, 0.85, 3.8), Color(0.68, 0.25, 1.0, 1.0))
	add_console("ClearConsole", "clear", "CLEAR", Vector3(14.9, 0.85, 3.8), Color(0.26, 0.24, 0.6, 1.0))


func build_exhibit() -> void:
	exhibit = VfxGalleryExhibit.new()
	exhibit.name = "LightningExhibit"
	exhibit.auto_interval_seconds = 1.75
	exhibit.configure(
		"lightning_engine",
		"lightning",
		"Procedural Lightning",
		"Seeded fractal paths rendered as generated emissive ribbon geometry.",
		["direct", "storm", "chain", "circuit", "water"],
		Color(0.5, 0.28, 1.0, 1.0),
		Callable(self, "trigger_lightning_exhibit")
	)
	add_child(exhibit)


func trigger_lightning_exhibit(
	_exhibit: VfxGalleryExhibit,
	effect_kind: String,
	requested_intensity: float
) -> bool:
	var intensity: float = requested_intensity * get_gallery_intensity()
	seed_counter += 37
	var accepted: bool = false
	match effect_kind:
		"direct":
			accepted = render_direct(intensity)
		"storm":
			accepted = render_storm(intensity)
		"chain":
			accepted = render_chain(intensity)
		"circuit":
			accepted = render_circuit(intensity)
		"water":
			accepted = render_water_strike(intensity)
		_:
			return false
	if accepted and exhibit != null and exhibit.auto_play:
		exhibit.cycle_kind()
	return accepted


func render_direct(intensity: float) -> bool:
	if source_orb == null or direct_target == null:
		return false
	var event := LightningArcEvent.make(
		LightningArcEvent.KIND_DIRECT,
		source_orb.global_position,
		direct_target.global_position + Vector3.UP * 1.0,
		intensity,
		seed_counter,
		"gallery_direct",
		["gallery", "lightning", "direct"]
	)
	renderer.render_arc(event, make_profile("direct"))
	return true


func render_storm(intensity: float) -> bool:
	if storm_target == null:
		return false
	var start := storm_target.global_position + Vector3(-1.4, 8.4, -0.8)
	var event := LightningArcEvent.make(
		LightningArcEvent.KIND_STORM,
		start,
		storm_target.global_position + Vector3.UP * 1.15,
		intensity,
		seed_counter,
		"gallery_storm",
		["gallery", "lightning", "storm", "branching"]
	)
	renderer.render_arc(event, make_profile("storm"))
	return true


func render_chain(intensity: float) -> bool:
	if chain_targets.size() < 2:
		return false
	var previous: Vector3 = source_orb.global_position
	for index: int in range(chain_targets.size()):
		var target: Node3D = chain_targets[index]
		var event := LightningArcEvent.make(
			LightningArcEvent.KIND_CHAIN,
			previous,
			target.global_position + Vector3.UP * 0.9,
			intensity * (1.0 - float(index) * 0.08),
			seed_counter + index * 101,
			"gallery_chain_" + str(index),
			["gallery", "lightning", "chain"]
		)
		event.metadata["chain_index"] = index
		renderer.render_arc(event, make_profile("chain"))
		previous = target.global_position + Vector3.UP * 0.9
	return true


func render_circuit(intensity: float) -> bool:
	if circuit_left == null or circuit_right == null:
		return false
	var event := LightningArcEvent.make(
		LightningArcEvent.KIND_CIRCUIT,
		circuit_left.global_position + Vector3.UP * 0.8,
		circuit_right.global_position + Vector3.UP * 0.8,
		intensity,
		seed_counter,
		"gallery_circuit",
		["gallery", "lightning", "circuit", "precision"]
	)
	renderer.render_arc(event, make_profile("circuit"))
	return true


func render_water_strike(intensity: float) -> bool:
	if water_pool == null:
		return false
	var center := Vector3(
		water_pool.global_position.x + 2.0,
		water_pool.get_surface_y(),
		water_pool.global_position.z + 0.2
	)
	var strike := LightningArcEvent.make(
		LightningArcEvent.KIND_STORM,
		center + Vector3(-0.6, 8.6, 0.3),
		center,
		intensity,
		seed_counter,
		"gallery_water_strike",
		["gallery", "lightning", "water", "conductive"]
	)
	renderer.render_arc(strike, make_profile("storm"))

	var surface_profile: LightningProfile = make_profile("water")
	for index: int in range(7):
		var angle: float = TAU * float(index) / 7.0 + float(seed_counter % 19) * 0.03
		var radius: float = 1.5 + float(index % 3) * 0.55 * intensity
		var endpoint := center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var surface_event := LightningArcEvent.make(
			LightningArcEvent.KIND_WATER_SURFACE,
			center,
			endpoint,
			intensity * 0.72,
			seed_counter + 211 + index * 43,
			"gallery_water_arc_" + str(index),
			["gallery", "lightning", "water_surface"]
		)
		surface_event.flatten_to_surface = true
		surface_event.surface_y = water_pool.get_surface_y() + 0.035
		renderer.render_arc(surface_event, surface_profile)

	water_pool.set_visual_state(24.0, 1.0, 0.78)
	water_pool.emit_disturbance(
		FluidDisturbanceEvent.KIND_ELECTRICAL,
		center,
		water_pool.flow_velocity_m_s,
		Vector3.ZERO,
		1.7 * intensity,
		1.1 * intensity,
		"procedural_lightning_water",
		["gallery", "water", "lightning", "electrical"]
	)
	return true


func make_profile(kind: String) -> LightningProfile:
	var profile := LightningProfile.new()
	match kind:
		"direct":
			profile.thickness = 0.045
			profile.duration_seconds = 0.17
			profile.subdivision_count = 5
			profile.jitter_amplitude = 0.34
			profile.branch_chance = 0.13
			profile.branch_depth = 1
			profile.maximum_branches = 4
		"storm":
			profile.thickness = 0.07
			profile.duration_seconds = 0.27
			profile.subdivision_count = 6
			profile.jitter_amplitude = 0.82
			profile.branch_chance = 0.68
			profile.branch_depth = 2
			profile.branch_length_ratio = 0.28
			profile.maximum_branches = 20
			profile.light_energy = 9.0
			profile.light_range = 12.0
		"chain":
			profile.thickness = 0.036
			profile.duration_seconds = 0.15
			profile.subdivision_count = 4
			profile.jitter_amplitude = 0.26
			profile.branch_chance = 0.12
			profile.maximum_branches = 3
			profile.light_energy = 4.2
		"circuit":
			profile.thickness = 0.025
			profile.duration_seconds = 0.12
			profile.subdivision_count = 3
			profile.jitter_amplitude = 0.09
			profile.branch_chance = 0.0
			profile.maximum_branches = 0
			profile.light_energy = 3.2
			profile.light_range = 4.0
		"water":
			profile.thickness = 0.028
			profile.duration_seconds = 0.23
			profile.subdivision_count = 4
			profile.jitter_amplitude = 0.32
			profile.branch_chance = 0.34
			profile.branch_depth = 1
			profile.branch_length_ratio = 0.22
			profile.maximum_branches = 5
			profile.light_energy = 2.4
			profile.light_range = 4.5
	return profile


func handle_lightning_action(action_id: String) -> Dictionary:
	var message: String = ""
	match action_id:
		"trigger":
			if exhibit != null and exhibit.trigger_preview(get_gallery_intensity()):
				manual_trigger_count += 1
				message = "Lightning preview: " + exhibit.last_effect_kind.to_upper()
			else:
				message = "The Lightning exhibit did not respond."
		"cycle":
			message = "Lightning type selected: " + exhibit.cycle_kind().to_upper()
		"toggle_auto":
			local_auto_enabled = not local_auto_enabled
			set_auto_play(local_auto_enabled)
			message = "Lightning auto replay " + ("enabled." if local_auto_enabled else "paused.")
		"clear":
			if renderer != null:
				renderer.reset_target()
			message = "Active lightning arcs cleared."
		_:
			message = "Unknown Lightning control: " + action_id
	update_readout()
	return {
		"message": message,
		"objective": "Compare fractal Lightning paths, branches, chains, circuits, and water conduction.",
	}


func set_auto_play(enabled: bool) -> void:
	local_auto_enabled = enabled
	if exhibit != null:
		exhibit.set_auto_play(enabled and (gallery == null or gallery.auto_replay_enabled))


func reset_target() -> void:
	if renderer != null:
		renderer.reset_target()
	if exhibit != null:
		exhibit.reset_target()
	manual_trigger_count = 0
	seed_counter = 7001
	local_auto_enabled = true
	if initialized:
		set_auto_play(true)
	update_readout()


func update_readout() -> void:
	if readout == null or exhibit == null or renderer == null:
		return
	readout.text = (
		"LIGHTNING ENGINE"
		+ "\nSELECTED: " + exhibit.get_current_kind().to_upper()
		+ "  AUTO: " + ("ON" if exhibit.auto_play else "OFF")
		+ "\nARCS: " + str(renderer.rendered_count)
		+ "  BRANCHES: " + str(renderer.total_generated_branches)
		+ "  POINTS: " + str(renderer.total_generated_points)
	)


func get_gallery_intensity() -> float:
	if gallery != null:
		return gallery.get_intensity()
	return 1.0


func activate_lightning_bay() -> void:
	for raw_bay: Node in get_tree().get_nodes_in_group("vfx_gallery_element_bays"):
		var bay := raw_bay as Node3D
		if bay == null or str(bay.get_meta("element_id", "")) != "lightning":
			continue
		bay.set_meta("active", true)
		var pylon := bay.get_node_or_null("Pylon") as MeshInstance3D
		if pylon != null:
			pylon.material_override = ThermalLabGeometry.make_material(Color(0.34, 0.1, 1.0, 1.0), true, 3.8)
		var label := bay.get_node_or_null("Label") as Label3D
		if label != null:
			label.modulate = Color(0.62, 0.48, 1.0, 1.0)


func add_orb(
	node_name: String,
	position_value: Vector3,
	radius: float,
	color: Color,
	energy: float
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.position = position_value
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	node.mesh = mesh
	node.material_override = ThermalLabGeometry.make_material(color, true, energy)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func add_target_pylon(
	node_name: String,
	position_value: Vector3,
	color: Color,
	size: Vector3 = Vector3(0.75, 2.2, 0.75)
) -> Node3D:
	var target := Node3D.new()
	target.name = node_name
	target.position = position_value
	ThermalLabGeometry.add_box_visual(target, "Pylon", size, color, true, 2.7)
	add_orb_to_parent(target, "Collector", Vector3(0.0, size.y * 0.58, 0.0), 0.19, color.lightened(0.3), 4.0)
	add_child(target)
	return target


func add_orb_to_parent(
	parent: Node3D,
	node_name: String,
	position_value: Vector3,
	radius: float,
	color: Color,
	energy: float
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.position = position_value
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	node.mesh = mesh
	node.material_override = ThermalLabGeometry.make_material(color, true, energy)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


func add_console(
	node_name: String,
	action_id: String,
	label_text: String,
	position_value: Vector3,
	color: Color
) -> LightningGalleryConsole:
	var console := LightningGalleryConsole.new()
	console.name = node_name
	console.action_id = action_id
	console.prompt_text = label_text
	console.position = position_value
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.65, 0.8, 1.0)
	collision.shape = shape
	console.add_child(collision)
	ThermalLabGeometry.add_box_visual(console, "ConsoleVisual", Vector3(1.65, 0.8, 1.0), color, true, 1.8)
	ThermalLabGeometry.add_label(console, "ConsoleLabel", label_text, Vector3(0.0, 0.75, 0.0), 14, Color.WHITE)
	add_child(console)
	return console


func get_debug_data() -> Dictionary:
	return {
		"lightning_gallery_wing": true,
		"initialized": initialized,
		"auto_enabled": local_auto_enabled,
		"manual_triggers": manual_trigger_count,
		"chain_targets": chain_targets.size(),
		"water_pool_connected": water_pool != null,
		"exhibit": exhibit.get_debug_data() if exhibit != null else {},
		"renderer": renderer.get_debug_data() if renderer != null else {},
	}
