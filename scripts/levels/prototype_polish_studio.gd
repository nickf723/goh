extends Node3D
class_name PrototypePolishStudio

const PresentationServiceScript = preload(
	"res://scripts/presentation/presentation_service.gd"
)

const MATERIALS: Array[String] = ["flesh", "wood", "stone", "metal", "glass"]
const REACTIONS: Array[String] = ["RESIST", "FLINCH", "STAGGER", "LAUNCH", "GUARD BREAK"]
const ELEMENTS: Array[String] = ["neutral", "life", "death", "fire", "lightning"]

var player: CharacterBody3D = null
var director: GamePresentationDirector = null
var status_label: Label = null
var last_event: Dictionary = {}
var preview_index: int = 0
var breakables: Array[Node] = []


func _ready() -> void:
	player = get_node_or_null("Player") as CharacterBody3D
	director = PresentationServiceScript.get_or_create(get_tree())
	if director != null and not director.event_presented.is_connected(_on_presentation_event):
		director.event_presented.connect(_on_presentation_event)
	_build_environment()
	_configure_floor_materials()
	_configure_player()
	_connect_breakables()
	_build_labels()
	_build_hud()
	GameState.set_objective(
		"Polish Studio: compare material contact, reactions, movement audio, camera impulse, VFX, and haptics."
	)


func _exit_tree() -> void:
	if director != null and is_instance_valid(director):
		if director.event_presented.is_connected(_on_presentation_event):
			director.event_presented.disconnect(_on_presentation_event)


func _process(_delta: float) -> void:
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.physical_keycode == KEY_F5:
			_preview_next_profile()
			get_viewport().set_input_as_handled()
			return
		if key_event.physical_keycode == KEY_F8:
			_reset_studio()
			get_viewport().set_input_as_handled()
			return


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "PolishStudioEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.008, 0.012, 0.022)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.32, 0.4, 0.56)
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.42
	world_environment.environment = environment
	add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.name = "StudioKey"
	key.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	key.light_color = Color(0.72, 0.84, 1.0)
	key.light_energy = 1.3
	key.shadow_enabled = true
	add_child(key)

	var warm := OmniLight3D.new()
	warm.name = "StudioWarmFill"
	warm.position = Vector3(-7.0, 5.0, -4.0)
	warm.light_color = Color(1.0, 0.42, 0.16)
	warm.light_energy = 3.4
	warm.omni_range = 13.0
	add_child(warm)

	var cool := OmniLight3D.new()
	cool.name = "StudioCoolFill"
	cool.position = Vector3(7.0, 4.0, -5.0)
	cool.light_color = Color(0.22, 0.55, 1.0)
	cool.light_energy = 3.0
	cool.omni_range = 13.0
	add_child(cool)


func _configure_floor_materials() -> void:
	var strip_width: float = 4.6
	var strip_depth: float = 22.0
	var floor_materials: Array[String] = ["wood", "stone", "metal", "glass"]
	var floor_colors: Array[Color] = [
		Color(0.25, 0.12, 0.045),
		Color(0.13, 0.15, 0.18),
		Color(0.12, 0.18, 0.23),
		Color(0.08, 0.18, 0.23, 0.82),
	]
	for index: int in range(floor_materials.size()):
		var material_id: String = floor_materials[index]
		var x: float = (float(index) - 1.5) * strip_width
		var body := StaticBody3D.new()
		body.name = material_id.capitalize() + "Floor"
		body.position = Vector3(x, -0.5, 0.0)
		body.set_meta("presentation_material", material_id)
		body.add_to_group("presentation_material_" + material_id)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(strip_width - 0.08, 1.0, strip_depth)
		collision.shape = shape
		body.add_child(collision)
		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = shape.size
		mesh_instance.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = floor_colors[index]
		material.roughness = 0.88 if material_id in ["wood", "stone"] else 0.42
		material.metallic = 0.72 if material_id == "metal" else 0.0
		if material_id == "glass":
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color.a = 0.78
		mesh_instance.material_override = material
		body.add_child(mesh_instance)
		add_child(body)

		var label := Label3D.new()
		label.name = material_id.capitalize() + "FloorLabel"
		label.text = material_id.to_upper() + " FOOTSTEPS"
		label.position = Vector3(x, 0.12, 8.6)
		label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		label.font_size = 22
		label.pixel_size = 0.007
		label.modulate = Color(0.72, 0.82, 0.96)
		add_child(label)


func _configure_player() -> void:
	if player == null:
		return
	var weapon_controller: WeaponController = player.get_node_or_null("WeaponController") as WeaponController
	if weapon_controller != null:
		weapon_controller.input_buffer_seconds = 0.38
		weapon_controller.facing_assist_range = 4.8
	GameState.set_stat("max_health", 100)
	GameState.set_stat("health", 100)
	GameState.set_stat("max_stamina", 100)
	GameState.set_stat("stamina", 100)
	GameState.set_stat("max_mana", 100)
	GameState.set_stat("mana", 100)
	GameState.set_stat("max_stance", 50)
	GameState.set_stat("stance", 50)


func _connect_breakables() -> void:
	breakables.clear()
	for raw: Node in get_tree().get_nodes_in_group("breakable"):
		if not is_ancestor_of(raw):
			continue
		breakables.append(raw)
		if raw.has_signal("broken"):
			var callback: Callable = _on_breakable_broken.bind(raw)
			if not raw.is_connected("broken", callback):
				raw.connect("broken", callback)


func _build_labels() -> void:
	var title := Label3D.new()
	title.text = "PRESENTATION POLISH STUDIO"
	title.position = Vector3(0.0, 6.2, -9.5)
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.font_size = 42
	title.pixel_size = 0.008
	title.outline_size = 8
	title.modulate = Color(0.7, 0.88, 1.0)
	add_child(title)

	var subtitle := Label3D.new()
	subtitle.text = "MATERIAL CONTACT  •  REACTION WEIGHT  •  ELEMENT ACCENTS  •  MOVEMENT  •  HAPTICS"
	subtitle.position = Vector3(0.0, 5.35, -9.4)
	subtitle.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	subtitle.font_size = 18
	subtitle.pixel_size = 0.008
	subtitle.outline_size = 6
	subtitle.modulate = Color(0.84, 0.9, 1.0)
	add_child(subtitle)

	var reaction_header := Label3D.new()
	reaction_header.text = "REACTION WEIGHT"
	reaction_header.position = Vector3(0.0, 4.9, -2.5)
	reaction_header.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	reaction_header.font_size = 22
	reaction_header.pixel_size = 0.007
	reaction_header.modulate = Color(1.0, 0.7, 0.3)
	add_child(reaction_header)

	var material_header := Label3D.new()
	material_header.text = "DESTRUCTION MATERIALS"
	material_header.position = Vector3(0.0, 3.2, -7.0)
	material_header.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	material_header.font_size = 22
	material_header.pixel_size = 0.007
	material_header.modulate = Color(0.54, 0.9, 1.0)
	add_child(material_header)

	for child_name: String in [
		"WoodCrate", "StoneUrn", "MetalBox", "GlassJar",
	]:
		var target: Node3D = get_node_or_null(child_name) as Node3D
		if target == null:
			continue
		var label := Label3D.new()
		label.text = child_name.replace("WoodCrate", "WOOD").replace("StoneUrn", "STONE").replace("MetalBox", "METAL").replace("GlassJar", "GLASS")
		label.position = target.position + Vector3.UP * 2.2
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 19
		label.pixel_size = 0.007
		label.outline_size = 5
		label.modulate = Color(0.82, 0.9, 1.0)
		add_child(label)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 15
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	panel.custom_minimum_size = Vector2(570, 150)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.018, 0.032, 0.91)
	style.border_color = Color(0.26, 0.66, 1.0, 0.88)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0))
	panel.add_child(status_label)
	_update_hud()


func _update_hud() -> void:
	if status_label == null:
		return
	var lines: Array[String] = [
		"PRESENTATION DIRECTOR  •  F5 preview next profile  •  F8 reset studio",
		"Walk across floor strips; hit reaction targets; break the four material props; cast spells freely.",
	]
	if last_event.is_empty():
		lines.append("Last event: waiting for input…")
	else:
		var event_type: String = str(last_event.get("event_type", "event")).to_upper()
		var parts: Array[String] = ["#" + str(last_event.get("event_id", 0)), event_type]
		for key: String in ["tier", "material", "element", "reaction", "haptic"]:
			var value: String = str(last_event.get(key, ""))
			if value != "":
				parts.append(key.to_upper() + " " + value.to_upper())
		lines.append("  •  ".join(parts))
		var audio_value: Variant = last_event.get("audio", {})
		lines.append("Audio: " + _audio_summary(audio_value))
	status_label.text = "\n".join(lines)


func _audio_summary(value: Variant) -> String:
	var cues: Array[String] = []
	if value is Dictionary:
		var cue: String = str((value as Dictionary).get("cue", ""))
		if cue != "":
			cues.append(cue)
	elif value is Array:
		for row_value: Variant in value as Array:
			if row_value is Dictionary:
				var cue: String = str((row_value as Dictionary).get("cue", ""))
				if cue != "":
					cues.append(cue)
	return "none" if cues.is_empty() else ", ".join(cues)


func _on_presentation_event(_event_type: String, data: Dictionary) -> void:
	last_event = data.duplicate(true)


func _on_breakable_broken(target: Node) -> void:
	if director == null or not is_instance_valid(director):
		return
	director.present_break({"target": target})


func _preview_next_profile() -> void:
	if director == null or not is_instance_valid(director):
		return
	var index: int = preview_index
	var material_id: String = MATERIALS[index % MATERIALS.size()]
	var reaction: String = REACTIONS[index % REACTIONS.size()]
	var element: String = ELEMENTS[index % ELEMENTS.size()]
	preview_index += 1
	director.preview_impact(
		material_id,
		reaction,
		element,
		Vector3(0.0, 1.2, -5.0)
	)
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call(
			"show_message",
			"Preview • " + material_id.capitalize() + " • " + reaction + " • " + element.capitalize()
		)


func _reset_studio() -> void:
	for raw: Node in get_tree().get_nodes_in_group("lab_resettable"):
		if is_ancestor_of(raw) and raw.has_method("reset_target"):
			raw.call("reset_target")
	for target: Node in breakables:
		if target != null and is_instance_valid(target) and target.has_method("reset_prop"):
			target.call("reset_prop")
	if player != null:
		player.global_position = Vector3(0.0, 1.1, 7.2)
		player.velocity = Vector3.ZERO
	_configure_player()
	if director != null:
		director.clear_history()
	last_event.clear()
	preview_index = 0


func get_debug_data() -> Dictionary:
	return {
		"polish_studio": true,
		"director_present": director != null and is_instance_valid(director),
		"breakables": breakables.size(),
		"preview_index": preview_index,
		"last_event": last_event.duplicate(true),
	}
