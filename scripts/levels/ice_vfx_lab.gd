extends "res://scripts/levels/single_element_vfx_lab.gd"
class_name IceVfxLab

const FreezeStateScript = preload("res://scripts/physics/freeze_state.gd")
const IceRendererScript = preload("res://scripts/presentation/procedural_ice_renderer.gd")
const IceEventScript = preload("res://scripts/presentation/ice_vfx_event.gd")
const IceProfileScript = preload("res://scripts/presentation/ice_presentation_profile.gd")
const GenericProjectileScene: PackedScene = preload("res://scenes/actions/generic_projectile.tscn")
const IceLancePayload: Resource = preload("res://data/damage_payloads/ice_lance_payload.tres")

var renderer: Node3D
var lake_thermal: ThermalState
var lake_freeze: Node
var lake_overlay: MeshInstance3D
var lake_overlay_material: StandardMaterial3D
var lake_phase: String = "freeze"
var lake_hold_timer: float = 0.0
var last_lake_visual_progress: float = -1.0
var lake_origin_index: int = 0

var fracture_thermal: ThermalState
var fracture_state: Node
var fracture_slab: MeshInstance3D
var thaw_thermal: ThermalState
var thaw_state: Node
var thaw_monolith: MeshInstance3D
var thaw_material: StandardMaterial3D

var seed_counter: int = 4100
var replay_timer: float = 0.0
var readout_timer: float = 0.0
var manual_trigger_count: int = 0
var launched_projectiles: Array[Node] = []

const LAKE_CENTER := Vector3(0.0, 0.38, 8.2)
const CRYSTAL_CENTER := Vector3(-9.0, 0.42, 3.0)
const FROST_CENTER := Vector3(9.8, 3.2, 4.2)
const FRACTURE_CENTER := Vector3(-8.7, 1.35, -6.0)
const THAW_CENTER := Vector3(8.2, 1.45, -5.8)
const PROJECTILE_ORIGIN := Vector3(5.8, 1.65, -9.2)


func _ready() -> void:
	setup_lab(
		"Cryogenic Observatory",
		"FREEZE FRONTS • CRYSTAL GROWTH • FROST • FRACTURE • THAW",
		Color(0.38, 0.82, 1.0, 1.0)
	)
	remove_from_group("single_element_vfx_lab")
	add_to_group("ice_vfx_lab")
	add_to_group("single_element_vfx_lab")
	renderer = IceRendererScript.new()
	renderer.name = "ProceduralIceRenderer"
	add_child(renderer)
	build_lake_station()
	build_crystal_station()
	build_frost_station()
	build_fracture_station()
	build_thaw_station()
	build_projectile_range()
	set_status("ICE SYSTEMS ONLINE")
	update_ice_readout()


func _process(delta: float) -> void:
	var safe_delta: float = max(delta, 0.0)
	if auto_replay_enabled:
		update_lake_cycle(safe_delta)
		replay_timer -= safe_delta
		if replay_timer <= 0.0:
			replay_timer = 4.2
			trigger_crystal_growth(0.75)
			trigger_frost(0.68)
	readout_timer -= safe_delta
	if readout_timer <= 0.0:
		readout_timer = 0.12
		update_ice_readout()
	prune_projectiles()


func build_lake_station() -> void:
	add_cylinder_visual("LakeBasin", Vector3(0.0, 0.05, 8.2), 5.35, 0.55, Color(0.04, 0.16, 0.24, 1.0))
	add_cylinder_visual("LakeWater", LAKE_CENTER, 4.75, 0.12, Color(0.08, 0.38, 0.62, 0.72), true, 0.8)
	lake_overlay_material = make_ice_material(Color(0.58, 0.9, 1.0, 0.0), 0.0, 1.4)
	lake_overlay = MeshInstance3D.new()
	lake_overlay.name = "LakeFreezeOverlay"
	var overlay_mesh := CylinderMesh.new()
	overlay_mesh.top_radius = 4.7
	overlay_mesh.bottom_radius = 4.7
	overlay_mesh.height = 0.045
	overlay_mesh.radial_segments = 72
	lake_overlay.mesh = overlay_mesh
	lake_overlay.material_override = lake_overlay_material
	lake_overlay.position = LAKE_CENTER + Vector3.UP * 0.08
	lake_overlay.scale = Vector3(0.01, 1.0, 0.01)
	add_child(lake_overlay)
	LabGeometry.add_label(self, "LakeTitle", "FREEZE LAKE", Vector3(0.0, 1.35, 13.9), 22, accent_color)
	LabGeometry.add_label(self, "LakeSubtitle", "temperature-driven phase front", Vector3(0.0, 0.92, 13.85), 13, Color(0.72, 0.9, 1.0, 1.0))
	add_global_console("freeze_lake", "FREEZE", Vector3(-2.0, 0.75, 14.8), accent_color)
	add_global_console("thaw_lake", "THAW", Vector3(0.0, 0.75, 14.8), Color(0.24, 0.62, 0.9, 1.0))
	add_global_console("move_origin", "ORIGIN", Vector3(2.0, 0.75, 14.8), Color(0.52, 0.86, 1.0, 1.0))
	var state_root := Node3D.new()
	state_root.name = "LakeFreezeState"
	add_child(state_root)
	lake_thermal = ThermalState.new()
	lake_thermal.name = "ThermalState"
	lake_thermal.starting_temperature_c = 12.0
	lake_thermal.ambient_temperature_c = 12.0
	lake_thermal.passive_ambient_exchange = false
	lake_thermal.heat_capacity_override_j_per_c = 10.0
	state_root.add_child(lake_thermal)
	lake_freeze = FreezeStateScript.new()
	lake_freeze.name = "FreezeState"
	lake_freeze.auto_process = true
	lake_freeze.freeze_rate_per_second = 0.11
	lake_freeze.thaw_rate_per_second = 0.09
	lake_freeze.configure(lake_thermal, false)
	state_root.add_child(lake_freeze)
	lake_freeze.freeze_progress_changed.connect(_on_lake_freeze_progress_changed)
	lake_freeze.thawed.connect(_on_lake_thawed)


func build_crystal_station() -> void:
	LabGeometry.add_static_box(self, "CrystalGardenPlatform", Vector3(-9.0, 0.15, 3.0), Vector3(6.6, 0.3, 6.6), Color(0.035, 0.13, 0.19, 1.0))
	LabGeometry.add_label(self, "CrystalTitle", "CRYSTAL GARDEN", Vector3(-9.0, 4.1, 5.9), 21, accent_color)
	LabGeometry.add_label(self, "CrystalSubtitle", "seeded symmetry and branching", Vector3(-9.0, 3.62, 5.86), 13, Color(0.72, 0.9, 1.0, 1.0))
	add_global_console("crystal", "GROW", Vector3(-9.0, 0.75, 6.9), Color(0.34, 0.76, 1.0, 1.0))


func build_frost_station() -> void:
	LabGeometry.add_static_box(self, "FrostWall", Vector3(10.0, 3.2, 4.2), Vector3(0.45, 6.0, 7.2), Color(0.12, 0.2, 0.25, 1.0))
	LabGeometry.add_label(self, "FrostTitle", "FROST WALL", Vector3(8.9, 6.9, 4.2), 21, accent_color)
	LabGeometry.add_label(self, "FrostSubtitle", "surface-plane fern growth", Vector3(8.85, 6.42, 4.2), 13, Color(0.72, 0.9, 1.0, 1.0))
	add_global_console("frost", "FROST", Vector3(7.2, 0.75, 7.0), Color(0.62, 0.9, 1.0, 1.0))


func build_fracture_station() -> void:
	LabGeometry.add_static_box(self, "FracturePlatform", Vector3(-8.7, 0.15, -6.0), Vector3(6.6, 0.3, 6.4), Color(0.035, 0.13, 0.19, 1.0))
	fracture_slab = MeshInstance3D.new()
	fracture_slab.name = "FractureIceSlab"
	var slab_mesh := BoxMesh.new()
	slab_mesh.size = Vector3(4.2, 0.55, 3.5)
	fracture_slab.mesh = slab_mesh
	fracture_slab.material_override = make_ice_material(Color(0.44, 0.8, 1.0, 0.78), 0.78, 1.2)
	fracture_slab.position = FRACTURE_CENTER
	add_child(fracture_slab)
	LabGeometry.add_label(self, "FractureTitle", "FRACTURE CHAMBER", Vector3(-8.7, 4.2, -2.8), 21, accent_color)
	LabGeometry.add_label(self, "FractureSubtitle", "stress → crack → shatter", Vector3(-8.7, 3.72, -2.85), 13, Color(0.72, 0.9, 1.0, 1.0))
	add_global_console("impact", "IMPACT", Vector3(-10.1, 0.75, -9.8), Color(0.3, 0.64, 0.9, 1.0))
	add_global_console("shatter", "SHATTER", Vector3(-7.3, 0.75, -9.8), Color(0.18, 0.5, 0.78, 1.0))
	var state_root := Node3D.new()
	state_root.name = "FractureStateRoot"
	add_child(state_root)
	fracture_thermal = ThermalState.new()
	fracture_thermal.name = "ThermalState"
	fracture_thermal.starting_temperature_c = -22.0
	fracture_thermal.passive_ambient_exchange = false
	state_root.add_child(fracture_thermal)
	fracture_state = FreezeStateScript.new()
	fracture_state.name = "FreezeState"
	fracture_state.auto_process = false
	fracture_state.starts_frozen = true
	fracture_state.configure(fracture_thermal, true)
	state_root.add_child(fracture_state)
	fracture_state.cracked.connect(_on_fracture_cracked)
	fracture_state.shattered.connect(_on_fracture_shattered)


func build_thaw_station() -> void:
	LabGeometry.add_static_box(self, "ThawPlatform", Vector3(8.2, 0.15, -5.8), Vector3(6.6, 0.3, 6.4), Color(0.035, 0.13, 0.19, 1.0))
	thaw_material = make_ice_material(Color(0.5, 0.86, 1.0, 0.82), 0.82, 1.35)
	thaw_monolith = MeshInstance3D.new()
	thaw_monolith.name = "ThawMonolith"
	var mesh := PrismMesh.new()
	mesh.size = Vector3(2.1, 3.4, 1.7)
	thaw_monolith.mesh = mesh
	thaw_monolith.material_override = thaw_material
	thaw_monolith.position = THAW_CENTER
	add_child(thaw_monolith)
	LabGeometry.add_label(self, "ThawTitle", "THAW THEATER", Vector3(8.2, 4.7, -2.8), 21, accent_color)
	LabGeometry.add_label(self, "ThawSubtitle", "heat recedes frost into droplets", Vector3(8.2, 4.22, -2.85), 13, Color(0.72, 0.9, 1.0, 1.0))
	add_global_console("thaw_specimen", "APPLY HEAT", Vector3(8.2, 0.75, -9.7), Color(0.22, 0.58, 0.88, 1.0))
	var state_root := Node3D.new()
	state_root.name = "ThawStateRoot"
	add_child(state_root)
	thaw_thermal = ThermalState.new()
	thaw_thermal.name = "ThermalState"
	thaw_thermal.starting_temperature_c = -16.0
	thaw_thermal.passive_ambient_exchange = false
	state_root.add_child(thaw_thermal)
	thaw_state = FreezeStateScript.new()
	thaw_state.name = "FreezeState"
	thaw_state.auto_process = true
	thaw_state.starts_frozen = true
	thaw_state.thaw_rate_per_second = 0.13
	thaw_state.configure(thaw_thermal, true)
	state_root.add_child(thaw_state)
	thaw_state.freeze_progress_changed.connect(_on_thaw_progress_changed)
	thaw_state.thawed.connect(_on_thaw_complete)


func build_projectile_range() -> void:
	LabGeometry.add_static_box(self, "ProjectileRange", Vector3(0.0, 0.08, -7.2), Vector3(5.2, 0.16, 8.0), Color(0.03, 0.11, 0.17, 1.0))
	LabGeometry.add_label(self, "ProjectileTitle", "ICE LANCE RANGE", Vector3(0.0, 3.5, -4.2), 20, accent_color)
	add_global_console("launch_ice", "LAUNCH", Vector3(0.0, 0.75, -10.9), Color(0.42, 0.82, 1.0, 1.0))
	for index: int in range(3):
		var x_value: float = -1.2 + float(index) * 1.2
		add_cylinder_visual("RangeCrystal" + str(index + 1), Vector3(x_value, 0.95, -2.8), 0.22, 1.9, Color(0.22, 0.52, 0.72, 1.0), true, 1.2)


func update_lake_cycle(delta: float) -> void:
	if lake_freeze == null or lake_thermal == null:
		return
	match lake_phase:
		"freeze":
			lake_thermal.set_temperature(-20.0, "Cryogenic cycle")
			if float(lake_freeze.freeze_progress) >= 0.985:
				lake_phase = "hold_frozen"
				lake_hold_timer = 2.1
		"hold_frozen":
			lake_hold_timer -= delta
			if lake_hold_timer <= 0.0:
				lake_phase = "thaw"
		"thaw":
			lake_thermal.set_temperature(18.0, "Observatory thaw")
			if float(lake_freeze.freeze_progress) <= 0.015:
				lake_phase = "hold_liquid"
				lake_hold_timer = 1.8
		"hold_liquid":
			lake_hold_timer -= delta
			if lake_hold_timer <= 0.0:
				lake_phase = "freeze"
		_:
			lake_phase = "freeze"


func handle_element_action(action_id: String) -> Dictionary:
	manual_trigger_count += 1
	match action_id:
		"freeze_lake":
			lake_freeze.set_freeze_progress(0.0)
			lake_thermal.set_temperature(-26.0, "Manual freeze")
			lake_phase = "freeze"
			return make_action_result("Lake cooling accelerated. Watch the front grow from the selected origin.")
		"thaw_lake":
			lake_thermal.set_temperature(24.0, "Manual thaw")
			lake_phase = "thaw"
			return make_action_result("Lake thaw initiated through real thermal state.")
		"move_origin":
			lake_origin_index = (lake_origin_index + 1) % 4
			last_lake_visual_progress = -1.0
			return make_action_result("Freeze origin moved to quadrant " + str(lake_origin_index + 1) + ".")
		"crystal":
			trigger_crystal_growth(1.0)
			return make_action_result("A new seeded crystal family is growing.")
		"frost":
			trigger_frost(1.0)
			return make_action_result("Procedural frost is crawling across the wall plane.")
		"impact":
			trigger_impact(false)
			return make_action_result("Stress added to the frozen slab.")
		"shatter":
			trigger_impact(true)
			return make_action_result("A heavy impulse challenges the fractured slab.")
		"thaw_specimen":
			trigger_thaw_specimen()
			return make_action_result("Heat applied. The monolith should recede into melt droplets.")
		"launch_ice":
			launch_ice_lance()
			return make_action_result("Procedural Ice Lance launched downrange.")
		_:
			return super.handle_element_action(action_id)


func trigger_crystal_growth(intensity_scale: float) -> void:
	seed_counter += 31
	var event: Resource = IceEventScript.make(
		IceEventScript.KIND_CRYSTAL_GROWTH,
		CRYSTAL_CENTER,
		Vector3.UP,
		get_intensity() * intensity_scale,
		1.25,
		seed_counter,
		"ice_crystal_garden",
		["gallery", "crystal"]
	)
	event.shard_count = 20
	event.duration_seconds = 3.2
	renderer.call("render_event", event, IceProfileScript.make_crystal_garden())


func trigger_frost(intensity_scale: float) -> void:
	seed_counter += 47
	var event: Resource = IceEventScript.make(
		IceEventScript.KIND_FROST,
		FROST_CENTER,
		Vector3.LEFT,
		get_intensity() * intensity_scale,
		2.55,
		seed_counter,
		"ice_frost_wall",
		["gallery", "frost"]
	)
	event.progress = 1.0
	event.duration_seconds = 3.0
	renderer.call("render_event", event, IceProfileScript.make_frost_wall())


func trigger_impact(force_shatter: bool) -> void:
	if fracture_state == null:
		return
	if bool(fracture_state.is_shattered):
		fracture_state.reset_target()
		fracture_slab.visible = true
	seed_counter += 59
	var strength: float = (1.15 if force_shatter else 0.24) * get_intensity()
	var result: Dictionary = fracture_state.apply_impact(strength, "Ice lab impact")
	if bool(result.get("accepted", false)) and not bool(result.get("shattered", false)):
		var event: Resource = IceEventScript.make(
			IceEventScript.KIND_CRACK,
			FRACTURE_CENTER + Vector3.UP * 0.31,
			Vector3.UP,
			get_intensity(),
			1.7,
			seed_counter,
			"ice_fracture_slab",
			["crack", "impact"]
		)
		event.progress = clampf(float(result.get("stress", 0.0)), 0.1, 1.0)
		renderer.call("render_event", event, IceProfileScript.make_crack())


func trigger_thaw_specimen() -> void:
	if thaw_state == null or thaw_thermal == null:
		return
	if float(thaw_state.freeze_progress) <= 0.01:
		thaw_thermal.set_temperature(-18.0, "Specimen refreeze")
		thaw_state.is_shattered = false
		thaw_state.set_freeze_progress(1.0)
	thaw_thermal.set_temperature(30.0, "Applied gallery heat")


func launch_ice_lance() -> void:
	var projectile := GenericProjectileScene.instantiate() as Node3D
	if projectile == null:
		return
	add_child(projectile)
	projectile.global_position = PROJECTILE_ORIGIN
	if projectile.has_method("set_payload"):
		projectile.call("set_payload", IceLancePayload.duplicate(true))
	if projectile.has_method("launch"):
		projectile.call("launch", Vector3.FORWARD)
	launched_projectiles.append(projectile)


func _on_lake_freeze_progress_changed(progress: float, _delta_progress: float) -> void:
	var visible_progress: float = clampf(progress, 0.0, 1.0)
	lake_overlay.visible = visible_progress > 0.005
	lake_overlay.scale = Vector3(max(visible_progress, 0.01), 1.0, max(visible_progress, 0.01))
	lake_overlay_material.albedo_color.a = 0.12 + visible_progress * 0.66
	lake_overlay_material.emission_energy_multiplier = 0.45 + visible_progress * 1.3
	if absf(visible_progress - last_lake_visual_progress) >= 0.075:
		last_lake_visual_progress = visible_progress
		seed_counter += 17
		var origin_offset: Vector3 = [
			Vector3(-1.4, 0.0, -1.0),
			Vector3(1.3, 0.0, -1.1),
			Vector3(1.2, 0.0, 1.15),
			Vector3(-1.25, 0.0, 1.05),
		][lake_origin_index]
		var event: Resource = IceEventScript.make(
			IceEventScript.KIND_FREEZE_FRONT,
			LAKE_CENTER + origin_offset + Vector3.UP * 0.13,
			Vector3.UP,
			get_intensity(),
			4.45,
			seed_counter,
			"ice_freeze_lake",
			["water", "freeze_front"]
		)
		event.progress = visible_progress
		event.duration_seconds = 1.1
		renderer.call("render_event", event, IceProfileScript.make_freeze_front())


func _on_lake_thawed(_source_name: String) -> void:
	seed_counter += 23
	var event: Resource = IceEventScript.make(IceEventScript.KIND_THAW, LAKE_CENTER, Vector3.UP, get_intensity(), 4.0, seed_counter, "lake_thaw")
	event.duration_seconds = 1.7
	renderer.call("render_event", event, IceProfileScript.new())


func _on_fracture_cracked(_source_name: String) -> void:
	set_status("FRACTURE THRESHOLD CROSSED")


func _on_fracture_shattered(_source_name: String) -> void:
	fracture_slab.visible = false
	seed_counter += 61
	var event: Resource = IceEventScript.make(IceEventScript.KIND_SHATTER, FRACTURE_CENTER, Vector3.UP, get_intensity(), 2.2, seed_counter, "fracture_shatter")
	event.shard_count = 42
	event.duration_seconds = 1.8
	renderer.call("render_event", event, IceProfileScript.make_crack())
	set_status("ICE SLAB SHATTERED")


func _on_thaw_progress_changed(progress: float, delta_progress: float) -> void:
	var safe_progress: float = clampf(progress, 0.0, 1.0)
	thaw_monolith.scale = Vector3(0.72 + safe_progress * 0.28, max(safe_progress, 0.05), 0.72 + safe_progress * 0.28)
	thaw_material.albedo_color.a = 0.18 + safe_progress * 0.66
	if delta_progress < -0.045:
		seed_counter += 7
		var event: Resource = IceEventScript.make(IceEventScript.KIND_THAW, THAW_CENTER + Vector3.UP * 0.7, Vector3.UP, get_intensity() * 0.55, 1.2, seed_counter, "monolith_melt")
		event.duration_seconds = 0.9
		renderer.call("render_event", event, IceProfileScript.new())


func _on_thaw_complete(_source_name: String) -> void:
	seed_counter += 13
	var event: Resource = IceEventScript.make(IceEventScript.KIND_THAW, THAW_CENTER, Vector3.UP, get_intensity(), 1.8, seed_counter, "monolith_thaw_complete")
	event.duration_seconds = 1.8
	renderer.call("render_event", event, IceProfileScript.new())
	set_status("THAW COMPLETE • MELTWATER RELEASED")


func update_ice_readout() -> void:
	if status_label == null:
		return
	var lake_progress: float = float(lake_freeze.freeze_progress) if lake_freeze != null else 0.0
	var stress: float = float(fracture_state.fracture_stress) if fracture_state != null else 0.0
	var effect_count: int = int(renderer.active_effects.size()) if renderer != null else 0
	status_label.text = (
		"ICE ENGINE"
		+ "\nLAKE " + lake_phase.to_upper() + "  " + str(snapped(lake_progress * 100.0, 1.0)) + "%"
		+ "  TEMP " + str(snapped(lake_thermal.temperature_c if lake_thermal != null else 0.0, 0.1)) + " °C"
		+ "\nFRACTURE " + str(snapped(stress, 0.01))
		+ "  CRACKED " + ("YES" if fracture_state != null and bool(fracture_state.is_cracked) else "NO")
		+ "  FX " + str(effect_count)
	)


func add_cylinder_visual(
	node_name: String,
	position_value: Vector3,
	radius: float,
	height: float,
	color: Color,
	emissive: bool = false,
	energy: float = 1.0
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 48
	node.mesh = mesh
	node.material_override = LabGeometry.make_material(color, emissive, energy)
	node.position = position_value
	add_child(node)
	return node


func make_ice_material(color: Color, alpha: float, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.roughness = 0.13
	material.metallic = 0.06
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = energy
	return material


func prune_projectiles() -> void:
	var valid: Array[Node] = []
	for projectile: Node in launched_projectiles:
		if projectile != null and is_instance_valid(projectile) and not projectile.is_queued_for_deletion():
			valid.append(projectile)
	launched_projectiles = valid


func reset_target() -> void:
	super.reset_target()
	manual_trigger_count = 0
	seed_counter = 4100
	replay_timer = 0.0
	lake_phase = "freeze"
	lake_hold_timer = 0.0
	lake_origin_index = 0
	last_lake_visual_progress = -1.0
	if renderer != null and renderer.has_method("reset_target"):
		renderer.call("reset_target")
	for projectile: Node in launched_projectiles:
		if projectile != null and is_instance_valid(projectile):
			projectile.queue_free()
	launched_projectiles.clear()
	if lake_thermal != null:
		lake_thermal.set_temperature(12.0, "Reset")
	if lake_freeze != null:
		lake_freeze.set_freeze_progress(0.0)
		lake_freeze.clear_fracture("Reset")
	if fracture_thermal != null:
		fracture_thermal.set_temperature(-22.0, "Reset")
	if fracture_state != null:
		fracture_state.reset_target()
	if fracture_slab != null:
		fracture_slab.visible = true
	if thaw_thermal != null:
		thaw_thermal.set_temperature(-16.0, "Reset")
	if thaw_state != null:
		thaw_state.reset_target()
		thaw_state.set_freeze_progress(1.0)
	if thaw_monolith != null:
		thaw_monolith.visible = true
		thaw_monolith.scale = Vector3.ONE
	set_status("ICE SYSTEMS RESET")
	update_ice_readout()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["ice_vfx_lab"] = true
	data["lake_phase"] = lake_phase
	data["lake_progress"] = float(lake_freeze.freeze_progress) if lake_freeze != null else 0.0
	data["fracture_stress"] = float(fracture_state.fracture_stress) if fracture_state != null else 0.0
	data["manual_triggers"] = manual_trigger_count
	data["projectiles"] = launched_projectiles.size()
	data["renderer"] = renderer.call("get_debug_data") if renderer != null and renderer.has_method("get_debug_data") else {}
	return data
