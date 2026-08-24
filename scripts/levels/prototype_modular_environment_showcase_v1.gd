extends Node3D
class_name PrototypeModularEnvironmentShowcaseV1

const Catalog = preload("res://scripts/environment/modular_environment_catalog.gd")
const StylizedMaterialLibrary = preload("res://scripts/environment/stylized_pbr_material_library.gd")
const StoryInteractableScript = preload("res://scripts/interaction/story_interactable.gd")
const PlayableSpaceScript = preload("res://scripts/quality/playable_space_3d.gd")
const RecoveryVolumeScript = preload("res://scripts/quality/playable_recovery_volume_3d.gd")
const STONE_MATERIAL: Material = preload("res://art/materials/environment/modular/weathered_stone.tres")
const TRIM_STONE_MATERIAL: Material = preload("res://art/materials/environment/modular/trim_stone.tres")
const WET_STONE_MATERIAL: Material = preload("res://art/materials/environment/modular/wet_stone.tres")
const METAL_MATERIAL: Material = preload("res://art/materials/environment/modular/aged_metal.tres")
const WARM_GLOW_MATERIAL: Material = preload("res://art/materials/environment/modular/warm_glow.tres")
const STYLIZED_STONE_STUDY_MATERIAL: Material = preload("res://art/materials/environment/modular/stylized_pbr_stone_study.tres")

var world: Node3D
var set_root: Node3D
var gate: Node3D
var gate_lever: Area3D
var style_lighting_console: Area3D
var style_environment: Environment
var style_sky_material: ProceduralSkyMaterial
var key_light: DirectionalLight3D
var lighting_dialect_id: String = "warm_key_cool_sky_v1"
var stylized_comparison_stats: Dictionary = {}
var status_label: Label
var placed_piece_ids: Array[String] = []
var placed_categories: Dictionary = {}


func _ready() -> void:
	add_to_group("modular_environment_showcase")
	world = $World
	_configure_environment()
	_build_playable_space()
	_build_foundation()
	_build_weathered_cloister()
	_build_stylized_surface_study()
	_build_gate_lever()
	_build_style_lighting_console()
	_build_signage()
	_build_hud()
	call_deferred("_apply_stylized_material_comparison")
	_show_status("Compare legacy materials on the left with stylized PBR on the right.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()


func _configure_environment() -> void:
	var environment_node: WorldEnvironment = $WorldEnvironment
	style_environment = Environment.new()
	style_sky_material = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = style_sky_material

	style_environment.background_mode = Environment.BG_SKY
	style_environment.sky = sky
	style_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	style_environment.ambient_light_sky_contribution = 1.0
	style_environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	style_environment.adjustment_enabled = true
	style_environment.ssao_enabled = true
	style_environment.ssao_radius = 1.5
	style_environment.ssao_intensity = 1.45
	style_environment.ssao_power = 1.2
	environment_node.environment = style_environment
	key_light = $DirectionalLight3D as DirectionalLight3D
	_apply_lighting_dialect("warm_key_cool_sky_v1")


func _apply_lighting_dialect(dialect_id: String) -> void:
	if style_environment == null or style_sky_material == null:
		return
	lighting_dialect_id = dialect_id
	match dialect_id:
		"violet_twilight_v1":
			style_sky_material.sky_top_color = Color(0.018, 0.014, 0.085)
			style_sky_material.sky_horizon_color = Color(0.22, 0.17, 0.38)
			style_sky_material.ground_horizon_color = Color(0.12, 0.09, 0.18)
			style_sky_material.ground_bottom_color = Color(0.01, 0.008, 0.025)
			style_sky_material.sky_curve = 0.28
			style_sky_material.ground_curve = 0.18
			style_sky_material.sky_energy_multiplier = 0.66
			style_sky_material.ground_energy_multiplier = 0.42
			style_environment.background_energy_multiplier = 0.62
			style_environment.ambient_light_energy = 0.72
			style_environment.tonemap_exposure = 1.08
			style_environment.adjustment_brightness = 1.02
			style_environment.adjustment_contrast = 1.07
			style_environment.adjustment_saturation = 1.13
			if key_light != null:
				key_light.light_color = Color(0.69, 0.74, 1.0)
				key_light.light_energy = 0.9
		_:
			lighting_dialect_id = "warm_key_cool_sky_v1"
			style_sky_material.sky_top_color = Color(0.045, 0.09, 0.2)
			style_sky_material.sky_horizon_color = Color(0.35, 0.47, 0.63)
			style_sky_material.ground_horizon_color = Color(0.24, 0.27, 0.34)
			style_sky_material.ground_bottom_color = Color(0.025, 0.028, 0.04)
			style_sky_material.sky_curve = 0.22
			style_sky_material.ground_curve = 0.16
			style_sky_material.sky_energy_multiplier = 0.82
			style_sky_material.ground_energy_multiplier = 0.6
			style_environment.background_energy_multiplier = 0.82
			style_environment.ambient_light_energy = 0.84
			style_environment.tonemap_exposure = 1.04
			style_environment.adjustment_brightness = 1.03
			style_environment.adjustment_contrast = 1.06
			style_environment.adjustment_saturation = 1.16
			if key_light != null:
				key_light.light_color = Color(1.0, 0.79, 0.62)
				key_light.light_energy = 1.28
	_update_style_lighting_prompt()


func _build_playable_space() -> void:
	var playable_space := Node3D.new()
	playable_space.name = "PlayableSpace"
	playable_space.set_script(PlayableSpaceScript)
	playable_space.set("use_bounds", true)
	playable_space.set("bounds_center", Vector3(0.0, 3.0, 0.0))
	playable_space.set("bounds_size", Vector3(28.0, 18.0, 42.0))
	playable_space.set("minimum_recovery_y", -4.5)
	playable_space.set("generate_boundary_collision", true)
	playable_space.set("boundary_thickness", 1.0)
	playable_space.set("boundary_height", 14.0)
	var default_anchor := Marker3D.new()
	default_anchor.name = "DefaultRecoveryAnchor"
	default_anchor.position = Vector3(0.0, 1.0, -15.0)
	playable_space.add_child(default_anchor)
	playable_space.set("default_recovery_path", NodePath("DefaultRecoveryAnchor"))
	add_child(playable_space)
	var recovery_volume := Area3D.new()
	recovery_volume.name = "ShowcaseRecoveryVolume"
	recovery_volume.position = Vector3(0.0, -6.2, 0.0)
	recovery_volume.set_script(RecoveryVolumeScript)
	recovery_volume.set("recovery_reason", "fell beneath the modular environment showcase")
	var recovery_shape := CollisionShape3D.new()
	var recovery_box := BoxShape3D.new()
	recovery_box.size = Vector3(34.0, 4.0, 50.0)
	recovery_shape.shape = recovery_box
	recovery_volume.add_child(recovery_shape)
	playable_space.add_child(recovery_volume)
	_add_static_box(world, "DeepSafetyCatch", Vector3(32.0, 0.5, 48.0), Vector3(0.0, -8.5, 0.0), WET_STONE_MATERIAL, false)


func _build_foundation() -> void:
	set_root = Node3D.new()
	set_root.name = "WeatheredCloisterSet"
	set_root.add_to_group("modular_environment_set")
	set_root.set_meta("set_id", "weathered_cloister_v1")
	world.add_child(set_root)
	_add_static_box(set_root, "EntryFoundation", Vector3(7.0, 0.45, 11.0), Vector3(0.0, -0.46, -10.5), STONE_MATERIAL, false)
	_add_static_box(set_root, "LeftFoundation", Vector3(5.0, 0.45, 14.0), Vector3(-3.1, -0.46, 0.0), STONE_MATERIAL, false)
	_add_static_box(set_root, "RightFoundation", Vector3(5.0, 0.45, 14.0), Vector3(3.1, -0.46, 0.0), STONE_MATERIAL, false)
	_add_static_box(set_root, "ChannelCatch", Vector3(2.3, 0.4, 14.0), Vector3(0.0, -0.82, 0.0), WET_STONE_MATERIAL, false)
	_add_static_box(set_root, "BridgeFoundation", Vector3(7.0, 0.45, 4.2), Vector3(0.0, -0.46, 7.9), STONE_MATERIAL, false)
	_add_static_box(set_root, "RaisedFoundation", Vector3(10.0, 0.55, 7.0), Vector3(0.0, 1.22, 14.5), TRIM_STONE_MATERIAL, true)


func _build_weathered_cloister() -> void:
	_place_piece("weathered_stone_floor_4m", "EntryFloorSouth", Vector3(0.0, 0.0, -13.0))
	_place_piece("weathered_stone_floor_4m", "EntryFloorNorth", Vector3(0.0, 0.0, -9.0))
	_place_piece("weathered_stone_arch_4m", "EntranceArch", Vector3(0.0, 0.0, -8.2))
	for z_value: float in [-4.0, 0.0, 4.0]:
		_place_piece("weathered_stone_floor_4m", "FloorLeft_%s" % str(z_value).replace(".", "_"), Vector3(-3.1, 0.0, z_value))
		_place_piece("weathered_stone_floor_4m", "FloorRight_%s" % str(z_value).replace(".", "_"), Vector3(3.1, 0.0, z_value))
		_place_piece("weathered_water_channel_4m", "WaterChannel_%s" % str(z_value).replace(".", "_"), Vector3(0.0, 0.0, z_value))
		_place_piece("weathered_stone_wall_4m", "WallLeft_%s" % str(z_value).replace(".", "_"), Vector3(-5.45, 0.0, z_value), Vector3(0.0, PI * 0.5, 0.0))
		_place_piece("weathered_stone_wall_4m", "WallRight_%s" % str(z_value).replace(".", "_"), Vector3(5.45, 0.0, z_value), Vector3(0.0, PI * 0.5, 0.0))
		_place_piece("weathered_stone_pillar_3m", "PillarLeft_%s" % str(z_value).replace(".", "_"), Vector3(-1.55, 0.0, z_value))
		_place_piece("weathered_stone_pillar_3m", "PillarRight_%s" % str(z_value).replace(".", "_"), Vector3(1.55, 0.0, z_value))
		var frame: Node3D = _place_piece("weathered_timber_frame_4m", "TimberFrame_%s" % str(z_value).replace(".", "_"), Vector3(0.0, 0.0, z_value))
		if frame != null:
			frame.scale.x = 2.55
		_place_piece("weathered_wall_sconce", "SconceLeft_%s" % str(z_value).replace(".", "_"), Vector3(-5.05, 1.45, z_value), Vector3(0.0, -PI * 0.5, 0.0))
		_place_piece("weathered_wall_sconce", "SconceRight_%s" % str(z_value).replace(".", "_"), Vector3(5.05, 1.45, z_value), Vector3(0.0, PI * 0.5, 0.0))
	_place_piece("weathered_stone_floor_4m", "CanalBridge", Vector3(0.0, 0.0, 7.0), Vector3.ZERO, Vector3(1.45, 1.0, 0.7))
	_place_piece("weathered_stone_stairs_4m", "RaisedGalleryStairs", Vector3(0.0, 0.0, 9.25))
	gate = _place_piece("weathered_iron_gate_3m", "ShowcaseGate", Vector3(0.0, 1.5, 12.0))
	_place_piece("weathered_stone_floor_4m", "RaisedFloorLeft", Vector3(-2.0, 1.5, 14.7))
	_place_piece("weathered_stone_floor_4m", "RaisedFloorRight", Vector3(2.0, 1.5, 14.7))
	_place_piece("weathered_stone_pedestal", "HeroPedestal", Vector3(0.0, 1.5, 15.0))
	_place_piece("weathered_crate", "SupplyCrate", Vector3(-2.7, 1.5, 14.6), Vector3(0.0, 0.18, 0.0))
	_place_piece("weathered_barrel", "StorageBarrel", Vector3(2.7, 1.5, 14.6), Vector3(0.0, -0.24, 0.0))
	_place_piece("weathered_stone_wall_4m", "GalleryBackWallLeft", Vector3(-2.05, 1.5, 17.55))
	_place_piece("weathered_stone_wall_4m", "GalleryBackWallRight", Vector3(2.05, 1.5, 17.55))


func _build_stylized_surface_study() -> void:
	var study := Node3D.new()
	study.name = "StylizedSurfaceStudy"
	study.position = Vector3(0.0, 3.54, 15.0)
	study.set_meta("study_id", "stylized_pbr_stone_v1")
	study.set_meta("rollout_scope", "showcase_material_family")
	set_root.add_child(study)
	_add_stylized_rock_lobe(
		study,
		"Core",
		0.72,
		Vector3(0.0, 0.52, 0.0),
		Vector3(1.05, 0.78, 0.92),
		Vector3(0.08, -0.16, 0.04)
	)
	_add_stylized_rock_lobe(
		study,
		"LeftLobe",
		0.52,
		Vector3(-0.5, 0.38, 0.08),
		Vector3(0.92, 0.72, 0.86),
		Vector3(-0.08, 0.28, -0.12)
	)
	_add_stylized_rock_lobe(
		study,
		"RightLobe",
		0.45,
		Vector3(0.48, 0.34, -0.04),
		Vector3(0.88, 0.7, 0.8),
		Vector3(0.12, -0.32, 0.08)
	)


func _build_gate_lever() -> void:
	gate_lever = Area3D.new()
	gate_lever.name = "GateLever"
	gate_lever.position = Vector3(-2.55, 1.5, 10.6)
	gate_lever.set_script(StoryInteractableScript)
	gate_lever.set("prompt_text", "Open the weathered iron gate")
	gate_lever.set("one_shot", false)
	gate_lever.connect("activated", _on_gate_lever_activated)
	set_root.add_child(gate_lever)
	_add_visual_box(gate_lever, "LeverBase", Vector3(0.7, 0.85, 0.55), Vector3(0.0, 0.42, 0.0), TRIM_STONE_MATERIAL)
	_add_visual_box(gate_lever, "LeverPlate", Vector3(0.48, 0.52, 0.08), Vector3(0.0, 0.54, -0.32), METAL_MATERIAL)
	_add_visual_box(gate_lever, "LeverHandle", Vector3(0.12, 0.72, 0.12), Vector3(0.0, 0.9, -0.38), METAL_MATERIAL, Vector3(0.0, 0.0, -0.48))
	_add_visual_sphere(gate_lever, "LeverGrip", 0.13, Vector3(-0.16, 1.2, -0.38), WARM_GLOW_MATERIAL)


func _build_style_lighting_console() -> void:
	style_lighting_console = Area3D.new()
	style_lighting_console.name = "StyleLightingConsole"
	style_lighting_console.position = Vector3(2.55, 1.5, 10.6)
	style_lighting_console.set_script(StoryInteractableScript)
	style_lighting_console.set("prompt_text", "Switch to violet twilight")
	style_lighting_console.set("one_shot", false)
	style_lighting_console.connect(
		"activated",
		_on_style_lighting_console_activated
	)
	set_root.add_child(style_lighting_console)
	var collision := CollisionShape3D.new()
	collision.name = "InteractionShape"
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.9, 1.4, 0.8)
	collision.position = Vector3(0.0, 0.7, 0.0)
	collision.shape = shape
	style_lighting_console.add_child(collision)
	_add_visual_box(
		style_lighting_console,
		"ConsoleBase",
		Vector3(0.7, 0.85, 0.55),
		Vector3(0.0, 0.42, 0.0),
		STYLIZED_STONE_STUDY_MATERIAL
	)
	_add_visual_box(
		style_lighting_console,
		"ConsolePlate",
		Vector3(0.48, 0.52, 0.08),
		Vector3(0.0, 0.54, -0.32),
		StylizedMaterialLibrary.get_material("aged_metal")
	)
	_add_visual_sphere(
		style_lighting_console,
		"DialectLight",
		0.13,
		Vector3(0.0, 0.96, -0.38),
		WARM_GLOW_MATERIAL
	)
	_update_style_lighting_prompt()


func _on_style_lighting_console_activated(
	_interactable: Node
) -> void:
	var next_dialect := (
		"violet_twilight_v1"
		if lighting_dialect_id == "warm_key_cool_sky_v1"
		else "warm_key_cool_sky_v1"
	)
	_apply_lighting_dialect(next_dialect)
	var label := (
		"VIOLET TWILIGHT"
		if lighting_dialect_id == "violet_twilight_v1"
		else "WARM DAYLIGHT"
	)
	_show_status(
		label
		+ "  •  Compare the legacy left side with stylized PBR on the right."
	)


func _update_style_lighting_prompt() -> void:
	if style_lighting_console == null:
		return
	style_lighting_console.set(
		"prompt_text",
		(
			"Switch to warm daylight"
			if lighting_dialect_id == "violet_twilight_v1"
			else "Switch to violet twilight"
		)
	)


func _apply_stylized_material_comparison() -> void:
	var family_counts: Dictionary = {}
	for family_id: String in StylizedMaterialLibrary.get_family_ids():
		family_counts[family_id] = 0
	stylized_comparison_stats = {
		"total": 0,
		"families": family_counts,
		"roots": [],
	}
	for candidate: Node in set_root.get_children():
		var candidate_name: String = str(candidate.name)
		var is_right_comparison := (
			candidate_name.begins_with("FloorRight_")
			or candidate_name.begins_with("WallRight_")
			or candidate_name.begins_with("PillarRight_")
			or candidate_name.begins_with("SconceRight_")
			or candidate_name == "RaisedFloorRight"
			or candidate_name == "GalleryBackWallRight"
			or candidate_name == "StorageBarrel"
		)
		if not is_right_comparison:
			continue
		var result: Dictionary = (
			StylizedMaterialLibrary.apply_to_subtree(candidate)
		)
		var replacement_count: int = int(result.get("total", 0))
		if replacement_count <= 0:
			continue
		stylized_comparison_stats["total"] = int(
			stylized_comparison_stats.get("total", 0)
		) + replacement_count
		var roots: Array = stylized_comparison_stats.get("roots", [])
		roots.append(candidate_name)
		stylized_comparison_stats["roots"] = roots
		var result_families: Dictionary = result.get("families", {})
		for family_id: String in StylizedMaterialLibrary.get_family_ids():
			family_counts[family_id] = int(
				family_counts.get(family_id, 0)
			) + int(result_families.get(family_id, 0))
	stylized_comparison_stats["families"] = family_counts
	set_root.set_meta(
		"stylized_comparison_stats",
		stylized_comparison_stats.duplicate(true)
	)


func _build_signage() -> void:
	_add_label(set_root, "TitlePlaque", "WEATHERED CLOISTER", Vector3(0.0, 4.25, -8.05), Color(0.72, 0.88, 0.96), 25)
	_add_label(set_root, "ArchitecturePlaque", "LEGACY MATERIALS", Vector3(-4.7, 2.7, -5.8), Color(0.66, 0.75, 0.78), 17)
	_add_label(set_root, "StylizedWingPlaque", "STYLIZED PBR", Vector3(4.7, 2.7, -5.8), Color(0.58, 0.78, 1.0), 17)
	_add_label(set_root, "WaterPlaque", "WATER + TRANSITIONS", Vector3(0.0, 1.2, 5.8), Color(0.42, 0.82, 0.96), 17)
	_add_label(set_root, "PropPlaque", "MATERIAL FAMILY + LIGHTING", Vector3(0.0, 5.25, 16.85), Color(0.58, 0.78, 1.0), 17)
	_add_label(set_root, "LightingPlaque", "LIGHTING DIALECT", Vector3(3.3, 3.1, 10.7), Color(0.82, 0.68, 1.0), 15)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ModularShowcaseHUD"
	layer.layer = 20
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18.0, 18.0)
	panel.custom_minimum_size = Vector2(520.0, 82.0)
	layer.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	var title := Label.new()
	title.text = "WEATHERED CLOISTER  •  STYLE CALIBRATION v1.2"
	title.add_theme_font_size_override("font_size", 17)
	box.add_child(title)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color(0.72, 0.84, 0.9))
	box.add_child(status_label)


func _on_gate_lever_activated(_interactable: Node) -> void:
	if gate == null or not gate.has_method("toggle_gate"):
		return
	gate.call("toggle_gate")
	var opening: bool = bool(gate.get("target_open"))
	gate_lever.set("prompt_text", "Close the weathered iron gate" if opening else "Open the weathered iron gate")
	_show_status("IRON GATE  •  " + ("Opening" if opening else "Closing") + ". Inspect the moving bars and collision.")


func _place_piece(
	piece_id: String,
	node_name: String,
	position_value: Vector3,
	rotation_value: Vector3 = Vector3.ZERO,
	scale_value: Vector3 = Vector3.ONE
) -> Node3D:
	var piece: Node3D = Catalog.instantiate_piece(piece_id)
	if piece == null:
		push_warning("Unknown modular environment piece: " + piece_id)
		return null
	piece.name = node_name
	piece.position = position_value
	piece.rotation = rotation_value
	piece.scale = scale_value
	set_root.add_child(piece)
	placed_piece_ids.append(piece_id)
	var definition: Dictionary = Catalog.get_definition(piece_id)
	placed_categories[str(definition.get("category", "unknown"))] = true
	return piece


func _add_static_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	position_value: Vector3,
	material_value: Material,
	visible_mesh: bool = true
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	if visible_mesh:
		_add_visual_box(body, "Visual", size, Vector3.ZERO, material_value)
	return body


func _add_visual_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	position_value: Vector3,
	material_value: Material,
	rotation_value: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	visual.rotation = rotation_value
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material_value
	parent.add_child(visual)
	return visual


func _add_visual_sphere(
	parent: Node3D,
	node_name: String,
	radius: float,
	position_value: Vector3,
	material_value: Material
) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 8
	visual.mesh = mesh
	visual.material_override = material_value
	parent.add_child(visual)
	return visual


func _add_stylized_rock_lobe(
	parent: Node3D,
	node_name: String,
	radius: float,
	position_value: Vector3,
	scale_value: Vector3,
	rotation_value: Vector3
) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	visual.scale = scale_value
	visual.rotation = rotation_value
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	visual.mesh = mesh
	visual.material_override = STYLIZED_STONE_STUDY_MATERIAL
	parent.add_child(visual)
	return visual


func _add_label(
	parent: Node3D,
	node_name: String,
	text_value: String,
	position_value: Vector3,
	color_value: Color,
	font_size: int
) -> Label3D:
	var label := Label3D.new()
	label.name = node_name
	label.text = text_value
	label.position = position_value
	label.modulate = color_value
	label.font_size = font_size
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 4
	parent.add_child(label)
	return label


func _show_status(message: String) -> void:
	if status_label != null:
		status_label.text = message


func get_showcase_stats() -> Dictionary:
	return {
		"set_id": "weathered_cloister_v1",
		"placed_count": placed_piece_ids.size(),
		"unique_piece_ids": placed_piece_ids.duplicate().reduce(func(accumulator: Dictionary, id: String) -> Dictionary: accumulator[id] = true; return accumulator, {}).size(),
		"categories": placed_categories.keys(),
		"gate": gate != null,
		"lever": gate_lever != null,
		"stylized_surface_study": set_root.get_node_or_null("StylizedSurfaceStudy") != null,
		"style_lighting_console": style_lighting_console != null,
		"environment_profile": lighting_dialect_id,
		"stylized_comparison": stylized_comparison_stats.duplicate(true),
	}


func get_stylized_comparison_stats() -> Dictionary:
	return stylized_comparison_stats.duplicate(true)


func get_placed_piece_ids() -> Array[String]:
	return placed_piece_ids.duplicate()
