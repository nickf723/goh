extends Node3D
class_name PrototypeLightningFlashSpellTrial

signal first_contact_completed
signal chasm_line_completed
signal trial_completed
signal trial_reset

const GateScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_sliding_gate.tscn"
)

enum TrialStage {
	FIRST_CONTACT,
	CHASM_LINE,
	MASTERY,
	COMPLETE,
}

@export var completion_flag: String = "thunderline_flash_spell_trial_complete"
@export_range(3.0, 30.0, 0.5) var first_contact_minimum_distance: float = 8.0
@export_range(8.0, 40.0, 0.5) var chasm_minimum_distance: float = 16.0
@export_range(-20.0, 0.0, 0.5) var fall_reset_height: float = -8.0
@export var mana_regeneration_note: String = (
	"This development trial regenerates Mana between Flash attempts."
)

var environment_root: Node3D
var actors_root: Node3D
var player: CharacterBody3D
var initial_player_transform: Transform3D
var current_checkpoint: Transform3D
var first_gate: MechanismSlidingGate
var chasm_gate: MechanismSlidingGate
var mastery_area: Area3D

var stage: TrialStage = TrialStage.FIRST_CONTACT
var trial_complete: bool = false
var last_flash_serial: int = 0
var first_contact_count: int = 0
var chasm_completion_count: int = 0
var upward_mistake_count: int = 0
var fall_recovery_count: int = 0
var last_flash_distance: float = 0.0
var last_flash_contacted: bool = false
var last_flash_direction: Vector3 = Vector3.ZERO
var last_flash_destination: Vector3 = Vector3.ZERO
var last_flash_contact_name: String = "none"

var floor_material: StandardMaterial3D
var wall_material: StandardMaterial3D
var lightning_material: StandardMaterial3D
var warning_material: StandardMaterial3D
var gold_material: StandardMaterial3D
var void_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("thunderline_flash_spell_trial")
	add_to_group("spell_trials")
	add_to_group("lab_resource_regeneration")
	add_to_group("debuggable")
	player = get_node_or_null("Player") as CharacterBody3D
	if player != null:
		initial_player_transform = player.transform
		current_checkpoint = initial_player_transform
		last_flash_serial = int(player.get_meta("lightning_flash_serial", 0))
	_build_roots()
	_build_materials()
	_build_environment()
	_build_first_contact_stage()
	_build_chasm_stage()
	_build_mastery_landing()
	_restore_player_resources()
	_set_stage(TrialStage.FIRST_CONTACT)
	_show_message(
		"The Thunderline: become the bolt and stop at first contact. "
		+ mana_regeneration_note
	)
	call_deferred("_equip_flash")
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.global_position.y <= fall_reset_height:
		_recover_from_fall()
		return
	var serial: int = int(player.get_meta("lightning_flash_serial", 0))
	if serial == last_flash_serial:
		return
	last_flash_serial = serial
	_consume_flash_result()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_viewport().set_input_as_handled()
		reset_trial()


func _build_roots() -> void:
	environment_root = Node3D.new()
	environment_root.name = "ThunderlineEnvironment"
	add_child(environment_root)
	actors_root = Node3D.new()
	actors_root.name = "ThunderlineActors"
	add_child(actors_root)


func _build_materials() -> void:
	floor_material = _make_material(Color(0.045, 0.06, 0.09), 0.32, 0.66)
	wall_material = _make_material(Color(0.018, 0.03, 0.055), 0.58, 0.42)
	lightning_material = _make_emissive_material(
		Color(0.08, 0.24, 0.64, 0.92),
		Color(0.16, 0.46, 1.0),
		3.5
	)
	warning_material = _make_emissive_material(
		Color(0.58, 0.12, 0.04, 0.94),
		Color(1.0, 0.22, 0.04),
		3.8
	)
	gold_material = _make_emissive_material(
		Color(0.68, 0.45, 0.06, 0.94),
		Color(1.0, 0.72, 0.08),
		3.7
	)
	void_material = _make_emissive_material(
		Color(0.015, 0.02, 0.045, 1.0),
		Color(0.05, 0.08, 0.2),
		0.8
	)


func _build_environment() -> void:
	_create_static_box(
		"FirstContactFloor",
		Vector3(0.0, -0.5, 4.0),
		Vector3(12.0, 1.0, 26.0),
		floor_material
	)
	_create_static_box(
		"FarLandingFloor",
		Vector3(0.0, -0.5, 38.0),
		Vector3(12.0, 1.0, 14.0),
		floor_material
	)
	_create_static_box(
		"LeftThunderlineWall",
		Vector3(-6.5, 3.0, 18.0),
		Vector3(1.0, 7.0, 58.0),
		wall_material
	)
	_create_static_box(
		"RightThunderlineWall",
		Vector3(6.5, 3.0, 18.0),
		Vector3(1.0, 7.0, 58.0),
		wall_material
	)
	_create_static_box(
		"ThunderlineBackWall",
		Vector3(0.0, 3.0, -9.0),
		Vector3(12.0, 7.0, 1.0),
		wall_material
	)
	_create_static_box(
		"ThunderlineFrontWall",
		Vector3(0.0, 3.0, 46.0),
		Vector3(12.0, 7.0, 1.0),
		wall_material
	)

	_create_floor_visual(
		"ThunderlineStartChannel",
		Vector3(0.0, 0.035, 2.5),
		Vector3(4.0, 0.06, 16.0),
		lightning_material
	)
	_create_floor_visual(
		"ThunderlineFarChannel",
		Vector3(0.0, 0.035, 38.0),
		Vector3(4.0, 0.06, 10.0),
		lightning_material
	)
	_create_floor_visual(
		"ChasmVoid",
		Vector3(0.0, -5.5, 25.0),
		Vector3(11.0, 0.2, 14.0),
		void_material
	)

	_create_label(
		"THE THUNDERLINE",
		Vector3(0.0, 5.0, -5.6),
		Color(0.56, 0.78, 1.0),
		34
	)
	_create_label(
		"Direction becomes distance. Contact becomes arrival.",
		Vector3(0.0, 4.0, -2.8),
		Color(0.68, 0.82, 0.98),
		20
	)
	_create_label(
		"I • FIRST CONTACT",
		Vector3(0.0, 4.1, 1.0),
		Color(0.42, 0.7, 1.0),
		27
	)
	_create_label(
		"II • THE OPEN CIRCUIT",
		Vector3(0.0, 4.1, 15.0),
		Color(0.42, 0.7, 1.0),
		27
	)


func _build_first_contact_stage() -> void:
	_create_floor_visual(
		"FirstContactLine",
		Vector3(0.0, 0.075, 9.0),
		Vector3(8.0, 0.08, 0.32),
		gold_material
	)
	_create_label(
		"AIM THROUGH THE GATE • FLASH STOPS AT SOLID CONTACT",
		Vector3(0.0, 3.1, 8.2),
		Color(0.72, 0.88, 1.0),
		17
	)
	first_gate = _spawn_gate(
		"FirstContactGate",
		"First Contact Gate",
		Vector3(0.0, 0.0, 10.0)
	)


func _build_chasm_stage() -> void:
	_create_label(
		"NO GROUND CHECK • NO SAFE LANDING",
		Vector3(0.0, 3.3, 15.8),
		Color(1.0, 0.42, 0.18),
		19
	)
	_create_label(
		"DO NOT AIM UP.",
		Vector3(0.0, 5.1, 19.0),
		Color(1.0, 0.26, 0.1),
		30
	)
	for marker_z: float in [19.0, 22.0, 25.0, 28.0, 31.0]:
		_create_floor_visual(
			"ChasmBoltMarker" + str(roundi(marker_z)),
			Vector3(0.0, -5.35, marker_z),
			Vector3(2.6, 0.08, 0.22),
			warning_material
		)
	chasm_gate = _spawn_gate(
		"ChasmContactGate",
		"Open Circuit Gate",
		Vector3(0.0, 0.0, 36.5)
	)
	_create_floor_visual(
		"ChasmArrivalLine",
		Vector3(0.0, 0.075, 35.5),
		Vector3(8.0, 0.08, 0.32),
		gold_material
	)


func _build_mastery_landing() -> void:
	mastery_area = _create_trigger_area(
		"FlashMasteryArea",
		Vector3(0.0, 1.0, 42.0),
		Vector3(7.0, 2.4, 4.0)
	)
	mastery_area.body_entered.connect(_on_mastery_area_body_entered)
	_create_floor_visual(
		"FlashMasterySeal",
		Vector3(0.0, 0.08, 42.0),
		Vector3(5.0, 0.12, 3.2),
		gold_material
	)
	_create_label(
		"AIM • BECOME • CONTACT",
		Vector3(0.0, 3.9, 43.4),
		Color(1.0, 0.82, 0.28),
		26
	)


func _consume_flash_result() -> void:
	last_flash_distance = float(
		player.get_meta("lightning_flash_distance", 0.0)
	)
	last_flash_contacted = bool(
		player.get_meta("lightning_flash_contacted", false)
	)
	last_flash_direction = player.get_meta(
		"lightning_flash_direction",
		Vector3.ZERO
	) as Vector3
	last_flash_destination = player.get_meta(
		"lightning_flash_destination",
		player.global_position
	) as Vector3
	last_flash_contact_name = str(
		player.get_meta("lightning_flash_contact_name", "none")
	)

	if last_flash_direction.y >= 0.38:
		upward_mistake_count += 1

	match stage:
		TrialStage.FIRST_CONTACT:
			_try_complete_first_contact()
		TrialStage.CHASM_LINE:
			_try_complete_chasm_line()
		_:
			pass


func _try_complete_first_contact() -> void:
	if (
		not last_flash_contacted
		or last_flash_distance < first_contact_minimum_distance
		or last_flash_destination.z < 8.0
		or absf(last_flash_destination.x) > 3.5
	):
		_show_message(
			"Flash must carry Grace down the line until the closed gate stops her."
		)
		return
	first_contact_count += 1
	first_gate.set_gate_open(
		true,
		false,
		{"reason": "first_flash_contact"}
	)
	current_checkpoint = Transform3D(
		player.global_transform.basis,
		Vector3(0.0, 1.0, 14.0)
	)
	_set_stage(TrialStage.CHASM_LINE)
	first_contact_completed.emit()
	_show_message(
		"First contact confirmed. Cross the chasm and let the far conductor stop the bolt."
	)


func _try_complete_chasm_line() -> void:
	if last_flash_direction.y >= 0.38:
		_show_message(
			"The bolt climbed instead of crossing. The chasm is still waiting below."
		)
		return
	if (
		not last_flash_contacted
		or last_flash_distance < chasm_minimum_distance
		or last_flash_destination.z < 34.0
		or absf(last_flash_destination.x) > 4.5
	):
		_show_message(
			"Aim across the open circuit until the far gate becomes the first contact."
		)
		return
	chasm_completion_count += 1
	chasm_gate.set_gate_open(
		true,
		false,
		{"reason": "chasm_flash_contact"}
	)
	current_checkpoint = Transform3D(
		player.global_transform.basis,
		Vector3(0.0, 1.0, 38.5)
	)
	_set_stage(TrialStage.MASTERY)
	chasm_line_completed.emit()
	_show_message(
		"Open circuit crossed. The gold seal lies beyond the conductor."
	)


func _on_mastery_area_body_entered(body: Node) -> void:
	if body != player or stage != TrialStage.MASTERY:
		return
	trial_complete = true
	GameState.set_flag(completion_flag, true)
	_set_stage(TrialStage.COMPLETE)
	trial_completed.emit()
	_show_message("Flash mastered: AIM • BECOME • CONTACT.")


func _recover_from_fall() -> void:
	fall_recovery_count += 1
	_cancel_transient_player_states()
	player.global_transform = current_checkpoint
	player.velocity = Vector3.ZERO
	if player.has_method("reset_physics_interpolation"):
		player.call("reset_physics_interpolation")
	_restore_player_resources()
	_show_message("The Thunderline returns Grace to the last conductor.")


func _cancel_transient_player_states() -> void:
	var surf: Node = player.get_node_or_null("SurfController")
	if surf != null and surf.has_method("cancel_surf"):
		surf.call("cancel_surf", "thunderline_recovery")
	var dodge: Node = player.get_node_or_null("PlayerDodgeController")
	if dodge != null and dodge.has_method("cancel_dodge"):
		dodge.call("cancel_dodge", "thunderline_recovery")


func _set_stage(next_stage: TrialStage) -> void:
	stage = next_stage
	match stage:
		TrialStage.FIRST_CONTACT:
			_set_objective(
				"Flash: aim down the first line and let the closed gate stop the bolt."
			)
		TrialStage.CHASM_LINE:
			_set_objective(
				"Flash: cross the open chasm and contact the far gate. Do not aim up."
			)
		TrialStage.MASTERY:
			_set_objective(
				"Flash: enter the gold mastery seal beyond the conductor."
			)
		TrialStage.COMPLETE:
			_set_objective(
				"Thunderline complete: AIM • BECOME • CONTACT."
			)


func _equip_flash() -> void:
	if player == null:
		return
	var caster: Node = player.get_node_or_null("AbilityCaster")
	if caster == null or not caster.has_method("select_ability"):
		return
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout
	for ability_index: int in range(loadout.get_equipped_ability_count()):
		var ability: AbilityDefinition = loadout.get_equipped_ability(ability_index)
		if ability != null and ability.get_spell_id() == "flash":
			caster.call("select_ability", ability_index, false)
			return


func reset_trial() -> void:
	trial_complete = false
	first_contact_count = 0
	chasm_completion_count = 0
	upward_mistake_count = 0
	fall_recovery_count = 0
	last_flash_distance = 0.0
	last_flash_contacted = false
	last_flash_direction = Vector3.ZERO
	last_flash_destination = Vector3.ZERO
	last_flash_contact_name = "none"
	GameState.set_flag(completion_flag, false)
	for effect: Node in get_tree().get_nodes_in_group("lightning_flash_effects"):
		if effect.has_method("finish_flash"):
			effect.call("finish_flash", "trial_reset")
	_cancel_transient_player_states()
	if player != null:
		player.transform = initial_player_transform
		player.velocity = Vector3.ZERO
		player.visible = true
		player.remove_meta("lightning_flash_visual_token")
		last_flash_serial = int(player.get_meta("lightning_flash_serial", 0))
	current_checkpoint = initial_player_transform
	if first_gate != null:
		first_gate.set_gate_open(false, true, {"reason": "trial_reset"})
	if chasm_gate != null:
		chasm_gate.set_gate_open(false, true, {"reason": "trial_reset"})
	_restore_player_resources()
	_set_stage(TrialStage.FIRST_CONTACT)
	call_deferred("_equip_flash")
	trial_reset.emit()


func _restore_player_resources() -> void:
	GameState.set_stat("health", GameState.get_stat("max_health"))
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	GameState.set_stat("stance", GameState.get_stat("max_stance"))


func _spawn_gate(
	node_name: String,
	display_name_value: String,
	position_value: Vector3
) -> MechanismSlidingGate:
	var gate: MechanismSlidingGate = GateScene.instantiate() as MechanismSlidingGate
	gate.name = node_name
	gate.display_name = display_name_value
	gate.position = position_value
	gate.scale = Vector3(1.35, 1.0, 1.0)
	gate.open_offset = Vector3(0.0, 4.5, 0.0)
	gate.transition_seconds = 0.42
	actors_root.add_child(gate)
	var state_label: Label3D = gate.get_node_or_null("StateLabel") as Label3D
	if state_label != null:
		state_label.visible = false
	return gate


func _create_trigger_area(
	node_name: String,
	position_value: Vector3,
	size_value: Vector3
) -> Area3D:
	var area := Area3D.new()
	area.name = node_name
	area.position = position_value
	area.collision_layer = 0
	area.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	area.add_child(collision)
	actors_root.add_child(area)
	return area


func _create_static_box(
	node_name: String,
	position_value: Vector3,
	size_value: Vector3,
	material: Material
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	visual.mesh = mesh
	visual.material_override = material
	body.add_child(visual)
	environment_root.add_child(body)
	return body


func _create_floor_visual(
	node_name: String,
	position_value: Vector3,
	size_value: Vector3,
	material: Material
) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := BoxMesh.new()
	mesh.size = size_value
	visual.mesh = mesh
	visual.material_override = material
	environment_root.add_child(visual)
	return visual


func _create_label(
	text_value: String,
	position_value: Vector3,
	color: Color,
	font_size_value: int
) -> Label3D:
	var label := Label3D.new()
	label.text = text_value
	label.position = position_value
	label.font_size = font_size_value
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 7
	label.modulate = color
	label.visibility_range_end = 50.0
	label.visibility_range_end_margin = 5.0
	environment_root.add_child(label)
	return label


func _make_material(
	color: Color,
	metallic: float,
	roughness: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _make_emissive_material(
	albedo: Color,
	emission_color: Color,
	energy: float
) -> StandardMaterial3D:
	var material: StandardMaterial3D = _make_material(albedo, 0.32, 0.4)
	material.emission_enabled = true
	material.emission = emission_color
	material.emission_energy_multiplier = energy
	return material


func _show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func _set_objective(text: String) -> void:
	GameState.set_objective(text)
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("set_objective"):
		ui.call("set_objective", text)


func get_debug_data() -> Dictionary:
	return {
		"flash_spell_trial": true,
		"stage": TrialStage.keys()[stage].to_lower(),
		"complete": trial_complete,
		"completion_flag": GameState.get_flag(completion_flag),
		"first_contact_count": first_contact_count,
		"chasm_completion_count": chasm_completion_count,
		"upward_mistakes": upward_mistake_count,
		"fall_recoveries": fall_recovery_count,
		"last_flash_distance": snappedf(last_flash_distance, 0.01),
		"last_flash_contacted": last_flash_contacted,
		"last_flash_direction": last_flash_direction,
		"last_flash_destination": last_flash_destination,
		"last_flash_contact_name": last_flash_contact_name,
		"mana_regeneration": 2.0,
	}
