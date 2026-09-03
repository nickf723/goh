extends Node3D
class_name PrototypeOrganicSurfaceLabV1

const RECIPE: OrganicSurfaceRecipe = preload(
	"res://data/environment_surfaces/meadow_ground_seed_recipe_v1.tres"
)
const PREVIEW_COUNT: int = 8
const TWIN_COUNT: int = 2
const COLUMN_COUNT: int = 4
const PREVIEW_SIZE: float = 10.5
const PREVIEW_GAP: float = 2.1
const BANK_STEP: int = 1000003
const SLOT_STEPS: Array[int] = [
	0,
	0,
	7919,
	15427,
	23801,
	32719,
	41959,
	52391,
]
const CAMERA_TARGET := Vector3(0.0, 0.2, 0.0)
const CAMERA_MIN_DISTANCE: float = 29.0
const CAMERA_MAX_DISTANCE: float = 58.0

var preview_roots: Array[Node3D] = []
var preview_surfaces: Array[MeshInstance3D] = []
var preview_labels: Array[Label3D] = []
var selection_frames: Array[Node3D] = []
var active_seeds: Array[int] = []
var selected_index: int = 0
var bank_index: int = 0
var rebuild_count: int = 0
var last_rebuild_matched: bool = true
var last_copy_succeeded: bool = false
var camera_yaw: float = 0.0
var camera_distance: float = 45.0
var camera_height_ratio: float = 0.54
var style_environment: Environment
var style_sky_material: ProceduralSkyMaterial

@onready var previews_root: Node3D = $SurfacePreviews
@onready var camera: Camera3D = $InspectionCamera
@onready var status_label: Label = %StatusLabel
@onready var verification_label: Label = %VerificationLabel


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	add_to_group("organic_surface_lab")
	add_to_group("authored_environment_composition")
	add_to_group("debuggable")
	set_meta("lab_id", "seeded_organic_surface_lab_v1")
	set_meta("generator_id", OrganicSurfaceRecipe.GENERATOR_ID)
	set_meta("generator_version", RECIPE.generator_version)
	_configure_environment()
	_build_backdrop()
	_build_previews()
	_reset_seed_bank()
	_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		match key_event.keycode:
			KEY_LEFT:
				select_relative(-1)
			KEY_RIGHT:
				select_relative(1)
			KEY_N:
				next_seed_bank()
			KEY_SPACE:
				rebuild_selected_preview()
			KEY_C:
				copy_selected_signature()
			KEY_R:
				reset_seed_bank()
			KEY_Q:
				orbit_camera(-1)
			KEY_E:
				orbit_camera(1)
			KEY_W:
				zoom_camera(-1)
			KEY_S:
				zoom_camera(1)
			_:
				return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = (
			event as InputEventMouseButton
		)
		if not mouse_event.pressed:
			return
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_camera(-1)
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_camera(1)
			get_viewport().set_input_as_handled()


func select_relative(direction: int) -> void:
	selected_index = wrapi(
		selected_index + direction,
		0,
		PREVIEW_COUNT
	)
	_update_selection()


func next_seed_bank() -> void:
	bank_index += 1
	_apply_seed_bank()


func reset_seed_bank() -> void:
	_reset_seed_bank()


func rebuild_selected_preview() -> bool:
	if selected_index < 0 or selected_index >= preview_surfaces.size():
		last_rebuild_matched = false
		return false
	var before_signature: String = get_preview_local_signature(
		selected_index
	)
	_apply_material_to_preview(selected_index)
	var after_signature: String = get_preview_local_signature(
		selected_index
	)
	rebuild_count += 1
	last_rebuild_matched = (
		not before_signature.is_empty()
		and before_signature == after_signature
	)
	_update_readout(
		"REBUILD PASS — exact recipe restored"
		if last_rebuild_matched
		else "REBUILD FAILED — recipe drift detected"
	)
	return last_rebuild_matched


func copy_selected_signature() -> void:
	var signature: String = get_selected_signature()
	last_copy_succeeded = not signature.is_empty()
	if last_copy_succeeded:
		DisplayServer.clipboard_set(signature)
	_update_readout(
		"COPIED — " + signature
		if last_copy_succeeded
		else "COPY FAILED — no selected recipe"
	)


func orbit_camera(direction: int) -> void:
	camera_yaw += float(direction) * 0.18
	_update_camera()


func zoom_camera(direction: int) -> void:
	camera_distance = clampf(
		camera_distance + float(direction) * 3.0,
		CAMERA_MIN_DISTANCE,
		CAMERA_MAX_DISTANCE
	)
	_update_camera()


func get_selected_signature() -> String:
	if selected_index < 0 or selected_index >= active_seeds.size():
		return ""
	return RECIPE.get_signature(active_seeds[selected_index])


func get_preview_local_signature(preview_index: int) -> String:
	if preview_index < 0 or preview_index >= preview_surfaces.size():
		return ""
	var surface: MeshInstance3D = preview_surfaces[preview_index]
	var material: ShaderMaterial = (
		surface.material_override as ShaderMaterial
	)
	if material == null:
		return ""
	var anchor: Vector3 = preview_roots[preview_index].global_position
	var material_offset_value: Variant = material.get_shader_parameter(
		&"location_offset"
	)
	if not material_offset_value is Vector2:
		return ""
	var material_offset: Vector2 = material_offset_value as Vector2
	var local_offset: Vector2 = (
		material_offset + Vector2(anchor.x, anchor.z)
	)
	var payload := PackedStringArray([
		str(material.get_meta("organic_surface_recipe_id", "")),
		str(material.get_meta("organic_surface_generator", "")),
		str(material.get_meta(
			"organic_surface_generator_version",
			0
		)),
		str(material.get_meta("organic_surface_seed", 0)),
		"location_offset=%.6f,%.6f" % [
			local_offset.x,
			local_offset.y,
		],
	])
	for parameter_name: StringName in OrganicSurfaceRecipe.SIGNATURE_PARAMETERS:
		payload.append(
			"%s=%.6f" % [
				str(parameter_name),
				float(material.get_shader_parameter(parameter_name)),
			]
		)
	return "|".join(payload).sha256_text().substr(0, 16)


func get_debug_data() -> Dictionary:
	var signatures: Array[String] = []
	for preview_index: int in range(preview_surfaces.size()):
		signatures.append(get_preview_local_signature(preview_index))
	var unique_seeds: Dictionary = {}
	for surface_seed: int in active_seeds:
		unique_seeds[surface_seed] = true
	return {
		"lab_id": str(get_meta("lab_id", "")),
		"recipe": RECIPE.get_debug_data(
			active_seeds[selected_index]
			if not active_seeds.is_empty()
			else RECIPE.seed
		),
		"preview_count": preview_surfaces.size(),
		"active_seeds": active_seeds.duplicate(),
		"unique_seed_count": unique_seeds.size(),
		"local_signatures": signatures,
		"twin_seed_match": (
			active_seeds.size() >= TWIN_COUNT
			and active_seeds[0] == active_seeds[1]
		),
		"twin_visual_match": (
			signatures.size() >= TWIN_COUNT
			and signatures[0] == signatures[1]
		),
		"selected_index": selected_index,
		"bank_index": bank_index,
		"rebuild_count": rebuild_count,
		"last_rebuild_matched": last_rebuild_matched,
		"generator_id": OrganicSurfaceRecipe.GENERATOR_ID,
		"generator_version": RECIPE.generator_version,
		"shader_path": (
			RECIPE.material_template.shader.resource_path
			if (
				RECIPE.material_template != null
				and RECIPE.material_template.shader != null
			)
			else ""
		),
		"environment": {
			"procedural_sky": style_sky_material != null,
			"aces": (
				style_environment != null
				and style_environment.tonemap_mode
				== Environment.TONE_MAPPER_ACES
			),
			"ssao": (
				style_environment != null
				and style_environment.ssao_enabled
			),
			"warm_key_cool_fill": (
				$WarmKey.light_energy > 0.0
				and $CoolFill.light_energy > 0.0
			),
		},
	}


func _configure_environment() -> void:
	style_sky_material = ProceduralSkyMaterial.new()
	style_sky_material.sky_top_color = Color(0.055, 0.095, 0.16, 1.0)
	style_sky_material.sky_horizon_color = Color(0.30, 0.34, 0.36, 1.0)
	style_sky_material.ground_horizon_color = Color(0.16, 0.18, 0.17, 1.0)
	style_sky_material.ground_bottom_color = Color(0.025, 0.032, 0.035, 1.0)
	style_sky_material.sky_curve = 0.20
	style_sky_material.ground_curve = 0.18
	style_sky_material.sky_energy_multiplier = 0.72
	style_sky_material.ground_energy_multiplier = 0.52

	var sky := Sky.new()
	sky.sky_material = style_sky_material
	style_environment = Environment.new()
	style_environment.background_mode = Environment.BG_SKY
	style_environment.sky = sky
	style_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	style_environment.ambient_light_sky_contribution = 1.0
	style_environment.ambient_light_energy = 0.70
	style_environment.reflected_light_source = (
		Environment.REFLECTION_SOURCE_SKY
	)
	style_environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	style_environment.tonemap_exposure = 1.04
	style_environment.adjustment_enabled = true
	style_environment.adjustment_brightness = 1.02
	style_environment.adjustment_contrast = 1.08
	style_environment.adjustment_saturation = 1.10
	style_environment.ssao_enabled = true
	style_environment.ssao_radius = 1.4
	style_environment.ssao_intensity = 1.15
	style_environment.ssao_power = 1.12
	$WorldEnvironment.environment = style_environment

	$WarmKey.light_color = Color(1.0, 0.80, 0.58, 1.0)
	$WarmKey.light_energy = 1.32
	$WarmKey.shadow_enabled = true
	$CoolFill.light_color = Color(0.36, 0.52, 0.76, 1.0)
	$CoolFill.light_energy = 0.30
	$CoolFill.shadow_enabled = false


func _build_backdrop() -> void:
	var backdrop := MeshInstance3D.new()
	backdrop.name = "LaboratoryBackdrop"
	var backdrop_mesh := BoxMesh.new()
	backdrop_mesh.size = Vector3(57.0, 0.6, 28.0)
	backdrop.mesh = backdrop_mesh
	backdrop.position.y = -0.55
	backdrop.material_override = _make_standard_material(
		Color(0.028, 0.034, 0.039, 1.0),
		0.82,
		0.0
	)
	add_child(backdrop)


func _build_previews() -> void:
	var plinth_material: StandardMaterial3D = _make_standard_material(
		Color(0.075, 0.085, 0.09, 1.0),
		0.72,
		0.02
	)
	var frame_material: StandardMaterial3D = _make_standard_material(
		Color(0.94, 0.58, 0.18, 1.0),
		0.34,
		0.12
	)
	frame_material.emission_enabled = true
	frame_material.emission = Color(0.72, 0.27, 0.045, 1.0)
	frame_material.emission_energy_multiplier = 1.3

	for preview_index: int in range(PREVIEW_COUNT):
		var root := Node3D.new()
		root.name = "Preview%02d" % (preview_index + 1)
		root.position = _preview_position(preview_index)
		root.add_to_group("organic_surface_preview")
		previews_root.add_child(root)
		preview_roots.append(root)

		var plinth := MeshInstance3D.new()
		plinth.name = "Plinth"
		var plinth_mesh := BoxMesh.new()
		plinth_mesh.size = Vector3(
			PREVIEW_SIZE + 0.5,
			0.34,
			PREVIEW_SIZE + 0.5
		)
		plinth.mesh = plinth_mesh
		plinth.position.y = -0.18
		plinth.material_override = plinth_material
		root.add_child(plinth)

		var surface := MeshInstance3D.new()
		surface.name = "OrganicSurface"
		var surface_mesh := PlaneMesh.new()
		surface_mesh.size = Vector2(PREVIEW_SIZE, PREVIEW_SIZE)
		surface_mesh.subdivide_width = 48
		surface_mesh.subdivide_depth = 48
		surface.mesh = surface_mesh
		surface.position.y = 0.015
		surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(surface)
		preview_surfaces.append(surface)

		var label := Label3D.new()
		label.name = "SeedLabel"
		label.position = Vector3(0.0, 0.52, PREVIEW_SIZE * 0.5 - 0.52)
		label.font_size = 34
		label.outline_size = 8
		label.modulate = Color(0.94, 0.93, 0.86, 1.0)
		label.outline_modulate = Color(0.015, 0.02, 0.024, 0.96)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		root.add_child(label)
		preview_labels.append(label)

		var selection_frame: Node3D = _build_selection_frame(
			frame_material
		)
		root.add_child(selection_frame)
		selection_frames.append(selection_frame)


func _build_selection_frame(material: StandardMaterial3D) -> Node3D:
	var frame := Node3D.new()
	frame.name = "SelectionFrame"
	var half_extent: float = PREVIEW_SIZE * 0.5 + 0.16
	for frame_index: int in range(4):
		var edge := MeshInstance3D.new()
		var edge_mesh := BoxMesh.new()
		if frame_index < 2:
			edge_mesh.size = Vector3(PREVIEW_SIZE + 0.52, 0.12, 0.14)
			edge.position = Vector3(
				0.0,
				0.10,
				-half_extent if frame_index == 0 else half_extent
			)
		else:
			edge_mesh.size = Vector3(0.14, 0.12, PREVIEW_SIZE + 0.52)
			edge.position = Vector3(
				-half_extent if frame_index == 2 else half_extent,
				0.10,
				0.0
			)
		edge.mesh = edge_mesh
		edge.material_override = material
		frame.add_child(edge)
	return frame


func _reset_seed_bank() -> void:
	bank_index = 0
	selected_index = 0
	rebuild_count = 0
	last_rebuild_matched = true
	last_copy_succeeded = false
	_apply_seed_bank()


func _apply_seed_bank() -> void:
	active_seeds.clear()
	var bank_seed: int = RECIPE.seed + bank_index * BANK_STEP
	for slot_index: int in range(PREVIEW_COUNT):
		active_seeds.append(bank_seed + SLOT_STEPS[slot_index])
		_apply_material_to_preview(slot_index)
	_update_labels()
	_update_selection()
	_update_readout(
		"CANONICAL BANK RESTORED"
		if bank_index == 0
		else "SEED BANK %d — deterministic variation" % bank_index
	)


func _apply_material_to_preview(preview_index: int) -> void:
	if (
		preview_index < 0
		or preview_index >= preview_surfaces.size()
		or preview_index >= active_seeds.size()
	):
		return
	var material: ShaderMaterial = RECIPE.build_material(
		preview_roots[preview_index].global_position,
		active_seeds[preview_index]
	)
	preview_surfaces[preview_index].material_override = material


func _update_labels() -> void:
	for preview_index: int in range(preview_labels.size()):
		var role_name: String = (
			"TWIN A"
			if preview_index == 0
			else (
				"TWIN B"
				if preview_index == 1
				else "VARIATION %d" % (preview_index - 1)
			)
		)
		preview_labels[preview_index].text = "%s  •  %d" % [
			role_name,
			active_seeds[preview_index],
		]


func _update_selection() -> void:
	for preview_index: int in range(selection_frames.size()):
		selection_frames[preview_index].visible = (
			preview_index == selected_index
		)
	_update_readout()


func _update_readout(message: String = "") -> void:
	if status_label == null or verification_label == null:
		return
	if active_seeds.is_empty():
		status_label.text = "No surface recipe loaded"
		verification_label.text = message
		return
	var surface_seed: int = active_seeds[selected_index]
	var parameter_data: Dictionary = RECIPE.get_seed_parameters(surface_seed)
	status_label.text = (
		"%s  •  SEED %d  •  SLOT %d/%d\n"
		+ "soil %.2f  threshold %.2f  dryness %.2f  pebbles %.2f\n"
		+ "%s"
	) % [
		RECIPE.display_name,
		surface_seed,
		selected_index + 1,
		PREVIEW_COUNT,
		float(parameter_data.get(&"soil_amount", 0.0)),
		float(parameter_data.get(&"soil_threshold", 0.0)),
		float(parameter_data.get(&"dryness", 0.0)),
		float(parameter_data.get(&"pebble_amount", 0.0)),
		RECIPE.get_signature(surface_seed),
	]
	verification_label.text = (
		message
		if not message.is_empty()
		else (
			"TWIN VERIFICATION PASS — local patterns match"
			if (
				preview_surfaces.size() >= TWIN_COUNT
				and get_preview_local_signature(0)
				== get_preview_local_signature(1)
			)
			else "TWIN VERIFICATION FAILED"
		)
	)
	verification_label.modulate = (
		Color(0.50, 0.92, 0.63, 1.0)
		if not verification_label.text.contains("FAILED")
		else Color(1.0, 0.42, 0.35, 1.0)
	)


func _preview_position(preview_index: int) -> Vector3:
	var column: int = preview_index % COLUMN_COUNT
	var row: int = floori(
		float(preview_index) / float(COLUMN_COUNT)
	)
	var full_step: float = PREVIEW_SIZE + PREVIEW_GAP
	return Vector3(
		(float(column) - 1.5) * full_step,
		0.0,
		(float(row) - 0.5) * full_step
	)


func _update_camera() -> void:
	if camera == null:
		return
	var horizontal_distance: float = camera_distance
	camera.global_position = CAMERA_TARGET + Vector3(
		sin(camera_yaw) * horizontal_distance,
		horizontal_distance * camera_height_ratio,
		cos(camera_yaw) * horizontal_distance
	)
	camera.look_at(CAMERA_TARGET, Vector3.UP)


func _make_standard_material(
	albedo: Color,
	roughness: float,
	metallic: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = roughness
	material.metallic = metallic
	return material
