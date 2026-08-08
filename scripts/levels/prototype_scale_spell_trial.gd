extends Node3D
class_name PrototypeScaleSpellTrial

signal trial_completed
signal trial_reset

@export var completion_flag: String = "resonant_stair_scale_trial_complete"
@export_range(0.02, 0.5, 0.01) var evaluation_interval: float = 0.08

var player: CharacterBody3D = null
var initial_player_transform: Transform3D
var environment_root: Node3D = null
var evaluation_remaining: float = 0.0
var trial_complete: bool = false
var balcony_collision: CollisionShape3D = null
var balcony_collision_enabled: bool = false
var floor_material: StandardMaterial3D
var platform_material: StandardMaterial3D
var note_material: StandardMaterial3D
var gold_material: StandardMaterial3D

const STEP_HEIGHT: float = 0.62
const STEP_FORWARD: float = 1.18
const STEP_COUNT: int = 8
const PLAYER_FOOT_OFFSET: float = 0.96
const START_POSITION: Vector3 = Vector3(0.0, 1.0, -5.0)


func _ready() -> void:
	add_to_group("scale_spell_trial")
	add_to_group("spell_trials")
	add_to_group("debuggable")
	player = get_node_or_null("Player") as CharacterBody3D
	if player != null:
		initial_player_transform = player.transform
	_build_materials()
	_build_environment()
	_restore_resources()
	call_deferred("_equip_spell", "scale")
	_set_objective("Cast Scale from the launch mark. Commit to the straight eight-note ascent and land on the Resonant Balcony.")
	_show_message("Resonant Stair: eight steps, one octave, one direction. Cast Scale while facing the balcony.")
	set_process(true)


func _process(delta: float) -> void:
	if trial_complete or player == null:
		return
	evaluation_remaining -= maxf(delta, 0.0)
	if evaluation_remaining > 0.0:
		return
	evaluation_remaining = evaluation_interval
	var final_root_y: float = START_POSITION.y + STEP_HEIGHT * float(STEP_COUNT)
	if not balcony_collision_enabled and player.global_position.y >= final_root_y - 0.18:
		_set_balcony_collision(true)
	if player.global_position.z >= 3.0 and player.global_position.y >= final_root_y - 0.35:
		_complete_trial()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_viewport().set_input_as_handled()
		reset_trial()


func _build_materials() -> void:
	floor_material = _make_material(Color(0.035, 0.04, 0.055), 0.35, 0.62)
	platform_material = _make_material(Color(0.08, 0.1, 0.16), 0.62, 0.3)
	note_material = _make_emissive(Color(0.72, 0.24, 0.08, 0.76), Color(1.0, 0.42, 0.08), 3.5)
	gold_material = _make_emissive(Color(0.72, 0.56, 0.08, 0.9), Color(1.0, 0.82, 0.18), 4.0)


func _build_environment() -> void:
	environment_root = Node3D.new()
	environment_root.name = "ResonantStairEnvironment"
	add_child(environment_root)
	_create_static_box("StartRunway", Vector3(0.0, -0.5, -5.0), Vector3(8.0, 1.0, 10.0), floor_material)
	var balcony_top_y: float = (
		START_POSITION.y
		+ STEP_HEIGHT * float(STEP_COUNT)
		- PLAYER_FOOT_OFFSET
	)
	var balcony: StaticBody3D = _create_static_box(
		"ResonantBalcony",
		Vector3(0.0, balcony_top_y - 0.5, 5.6),
		Vector3(8.0, 1.0, 7.0),
		platform_material
	)
	balcony_collision = balcony.get_node_or_null("CollisionShape3D") as CollisionShape3D
	_set_balcony_collision(false)
	_create_label("RESONANT STAIR", Vector3(0.0, 4.0, -7.8), Color(1.0, 0.62, 0.18), 32)
	_create_label("COMMIT • ASCEND • RESOLVE", Vector3(0.0, balcony_top_y + 2.5, 6.5), Color(1.0, 0.84, 0.3), 22)
	_create_marker(Vector3(0.0, 0.04, -3.8), Vector3(2.2, 0.08, 1.4), note_material)
	for index: int in range(STEP_COUNT):
		var step_number: int = index + 1
		var position_value := Vector3(
			0.0,
			START_POSITION.y + STEP_HEIGHT * float(step_number) - 0.92,
			-3.8 + STEP_FORWARD * float(index)
		)
		_create_note_ring(position_value, index)
	_create_marker(
		Vector3(0.0, balcony_top_y + 0.04, 5.2),
		Vector3(2.4, 0.08, 2.4),
		gold_material
	)


func _set_balcony_collision(value: bool) -> void:
	balcony_collision_enabled = value
	if balcony_collision != null:
		balcony_collision.set_deferred("disabled", not value)


func _create_static_box(node_name: String, position_value: Vector3, size_value: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.collision_layer = 1
	body.collision_mask = 1
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	environment_root.add_child(body)
	return body


func _create_marker(position_value: Vector3, size_value: Vector3, material: Material) -> void:
	var marker := MeshInstance3D.new()
	marker.position = position_value
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := BoxMesh.new()
	mesh.size = size_value
	marker.mesh = mesh
	marker.material_override = material
	environment_root.add_child(marker)


func _create_note_ring(position_value: Vector3, index: int) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "GuideNote%02d" % [index + 1]
	ring.position = position_value
	ring.rotation_degrees.x = 90.0
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.52
	torus.rings = 18
	torus.ring_segments = 7
	ring.mesh = torus
	ring.material_override = note_material
	environment_root.add_child(ring)


func _create_label(text_value: String, position_value: Vector3, color: Color, size_value: int) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.position = position_value
	label.modulate = color
	label.font_size = size_value
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	environment_root.add_child(label)


func _make_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _make_emissive(color: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = _make_material(color, 0.2, 0.42)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material


func _complete_trial() -> void:
	if trial_complete:
		return
	trial_complete = true
	_set_balcony_collision(true)
	GameState.set_flag(completion_flag, true)
	_set_objective("Scale mastered: eight notes convert commitment into vertical distance.")
	_show_message("Scale mastered • COMMIT • ASCEND • RESOLVE")
	trial_completed.emit()


func reset_trial() -> void:
	trial_complete = false
	GameState.set_flag(completion_flag, false)
	for controller: Node in get_tree().get_nodes_in_group("scale_controllers"):
		if controller.has_method("reset_target"):
			controller.call("reset_target")
	if player != null:
		player.transform = initial_player_transform
		player.velocity = Vector3.ZERO
	_set_balcony_collision(false)
	_restore_resources()
	call_deferred("_equip_spell", "scale")
	_set_objective("Cast Scale from the launch mark. Commit to the straight eight-note ascent and land on the Resonant Balcony.")
	trial_reset.emit()


func _equip_spell(spell_id: String) -> void:
	if player == null:
		return
	var caster: Node = player.get_node_or_null("AbilityCaster")
	if caster == null:
		return
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return
	var loadout := loadout_value as AbilityLoadout
	for index: int in range(loadout.get_equipped_ability_count()):
		var ability: AbilityDefinition = loadout.get_equipped_ability(index)
		if ability != null and ability.get_spell_id() == spell_id:
			caster.call("select_ability", index, false)
			return


func _restore_resources() -> void:
	GameState.set_stat("health", GameState.get_stat("max_health"))
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	GameState.set_stat("stance", GameState.get_stat("max_stance"))


func _set_objective(text_value: String) -> void:
	if GameState.has_method("set_objective"):
		GameState.call("set_objective", text_value)
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("set_objective"):
		ui.call("set_objective", text_value)
	elif ui != null and ui.has_method("set_objective_text"):
		ui.call("set_objective_text", text_value)


func _show_message(text_value: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text_value)
	else:
		print(text_value)


func get_debug_data() -> Dictionary:
	return {
		"scale_trial": true,
		"complete": trial_complete,
		"player_position": player.global_position if player != null else Vector3.ZERO,
		"balcony_collision_enabled": balcony_collision_enabled,
		"completion_flag": GameState.get_flag(completion_flag),
	}
