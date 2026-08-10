extends Node3D
class_name TrialChamber001ShatterClimb

signal route_opened(route_id: String)
signal trial_completed(route_id: String)
signal trial_reset

const TrialLoadout: AbilityLoadout = preload(
	"res://data/loadouts/trial_shatter_climb_loadout.tres"
)
const TrainingHammer: WeaponDefinition = preload(
	"res://data/weapons/training_hammer.tres"
)
const VillageRouteGateScript: Script = preload(
	"res://scripts/puzzles/village_route_gate.gd"
)
const VillageIceBridgeScript: Script = preload(
	"res://scripts/puzzles/village_ice_bridge.gd"
)
const StatusReceiverScript: Script = preload(
	"res://scripts/combat/status_receiver.gd"
)
const PayloadReceiverScript: Script = preload(
	"res://scripts/combat/payload_receiver.gd"
)

const COMPLETION_FLAG: String = "trial_chamber_001_shatter_climb_complete"
const LEFT_ROUTE_FLAG: String = "trial_chamber_001_frozen_crossing"
const RIGHT_ROUTE_FLAG: String = "trial_chamber_001_shattered_wall"
const START_TRANSFORM := Transform3D(
	Basis.IDENTITY,
	Vector3(0.0, 1.0, 16.0)
)

var player: CharacterBody3D
var environment_root: Node3D
var left_bridge: StaticBody3D
var right_gate: StaticBody3D
var goal_area: Area3D
var goal_beacon: MeshInstance3D
var left_route_ready: bool = false
var right_route_ready: bool = false
var trial_complete: bool = false
var resetting: bool = false

var floor_material: StandardMaterial3D
var wall_material: StandardMaterial3D
var platform_material: StandardMaterial3D
var stone_material: StandardMaterial3D
var water_material: StandardMaterial3D
var ice_material: StandardMaterial3D
var gold_material: StandardMaterial3D
var void_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("trial_chambers")
	add_to_group("spell_trials")
	add_to_group("debuggable")
	player = get_node_or_null("Player") as CharacterBody3D
	_clear_runtime_flags()
	_build_materials()
	_build_chamber()
	_configure_trial_loadout()
	_restore_resources()
	_set_objective("Reach the upper seal using only Water, Ice, and the Training Hammer.")
	_show_message(
		"Trial 001 • Shatter & Climb\n"
		+ "Two routes reach the same upper seal. The chamber only gives you what you need."
	)
	set_process(true)


func _process(_delta: float) -> void:
	if player == null or resetting:
		return
	if player.global_position.y < -5.0:
		_show_message("The chamber catches Grace and returns her to the start.")
		reset_trial()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_viewport().set_input_as_handled()
		reset_trial()


func _build_materials() -> void:
	floor_material = _make_material(Color(0.055, 0.065, 0.085), 0.18, 0.78)
	wall_material = _make_material(Color(0.075, 0.09, 0.12), 0.12, 0.84)
	platform_material = _make_material(Color(0.13, 0.16, 0.21), 0.2, 0.68)
	stone_material = _make_material(Color(0.28, 0.3, 0.34), 0.08, 0.78)
	water_material = _make_material(Color(0.08, 0.48, 0.68, 0.72), 0.02, 0.18, true)
	ice_material = _make_emissive(Color(0.34, 0.82, 0.96, 0.88), Color(0.2, 0.72, 1.0), 1.7, true)
	gold_material = _make_emissive(Color(0.78, 0.58, 0.12, 1.0), Color(1.0, 0.72, 0.18), 3.2)
	void_material = _make_material(Color(0.012, 0.016, 0.025), 0.0, 0.98)


func _build_chamber() -> void:
	environment_root = Node3D.new()
	environment_root.name = "TrialArchitecture"
	add_child(environment_root)

	# One quiet room shell. The puzzle, not the scenery, carries the complexity.
	_create_static_box("StartPlatform", Vector3(0, -0.5, 15.5), Vector3(24, 1, 11), floor_material)
	_create_static_box("GoalPlatform", Vector3(0, 7.0, -16.0), Vector3(24, 1, 9), platform_material)
	_create_visual_box("LowerVoid", Vector3(0, -6.5, -1.0), Vector3(24, 1, 24), void_material)
	_create_static_box("LeftWall", Vector3(-13.0, 5.5, 0.0), Vector3(1.0, 12.0, 40.0), wall_material)
	_create_static_box("RightWall", Vector3(13.0, 5.5, 0.0), Vector3(1.0, 12.0, 40.0), wall_material)
	_create_static_box("BackWall", Vector3(0.0, 5.5, -21.0), Vector3(26.0, 12.0, 1.0), wall_material)
	_create_static_box("FrontWallLeft", Vector3(-9.0, 5.5, 21.0), Vector3(8.0, 12.0, 1.0), wall_material)
	_create_static_box("FrontWallRight", Vector3(9.0, 5.5, 21.0), Vector3(8.0, 12.0, 1.0), wall_material)
	_create_static_box("CenterSpine", Vector3(0.0, 3.0, 0.0), Vector3(2.0, 7.0, 25.0), wall_material)

	_build_left_route()
	_build_right_route()
	_build_goal()
	_build_visual_language()


func _build_left_route() -> void:
	_create_static_box("LeftNearLanding", Vector3(-7.0, -0.25, 8.0), Vector3(6.0, 0.5, 5.0), platform_material)
	_create_static_box("LeftFarLanding", Vector3(-7.0, 0.1, -5.0), Vector3(6.0, 0.8, 5.0), platform_material)
	left_bridge = _create_water_ice_bridge(Vector3(-7.0, 0.0, 1.5), Vector3(5.2, 0.5, 8.5))
	_create_stair_run(
		"LeftUpperStep",
		Vector3(-7.0, 0.35, -7.1),
		10,
		Vector3(5.6, 0.55, 1.35),
		Vector3(0.0, 0.68, -0.82),
		platform_material
	)


func _build_right_route() -> void:
	_create_static_box("RightNearLanding", Vector3(7.0, -0.25, 8.0), Vector3(6.0, 0.5, 5.0), platform_material)
	_create_stair_run(
		"RightLowerStep",
		Vector3(7.0, -0.05, 6.2),
		6,
		Vector3(5.6, 0.5, 1.45),
		Vector3(0.0, 0.55, -1.15),
		platform_material
	)
	_create_static_box("RightGateLanding", Vector3(7.0, 2.95, -1.25), Vector3(6.0, 0.55, 3.6), platform_material)
	right_gate = _create_shatter_gate(Vector3(7.0, 3.0, -3.0))
	_create_stair_run(
		"RightUpperStep",
		Vector3(7.0, 3.05, -4.8),
		7,
		Vector3(5.6, 0.55, 1.35),
		Vector3(0.0, 0.68, -1.05),
		platform_material
	)


func _build_goal() -> void:
	goal_area = Area3D.new()
	goal_area.name = "UpperSealGoal"
	goal_area.position = Vector3(0.0, 8.0, -17.0)
	goal_area.collision_layer = 0
	goal_area.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(9.0, 3.0, 3.0)
	collision.shape = shape
	goal_area.add_child(collision)
	goal_area.body_entered.connect(_on_goal_body_entered)
	environment_root.add_child(goal_area)

	goal_beacon = MeshInstance3D.new()
	goal_beacon.name = "UpperSealBeacon"
	goal_beacon.position = Vector3(0.0, 9.2, -19.2)
	var beacon_mesh := CylinderMesh.new()
	beacon_mesh.top_radius = 1.2
	beacon_mesh.bottom_radius = 1.2
	beacon_mesh.height = 0.18
	goal_beacon.mesh = beacon_mesh
	goal_beacon.rotation_degrees.x = 90.0
	goal_beacon.material_override = gold_material
	environment_root.add_child(goal_beacon)


func _build_visual_language() -> void:
	# Sparse color landmarks distinguish the two systemic ideas without giant
	# solution text: cyan water on the left, fractured stone on the right, gold goal.
	_create_visual_box("LeftLaneInset", Vector3(-7.0, 0.03, 10.8), Vector3(5.0, 0.08, 1.2), water_material)
	_create_visual_box("RightLaneInset", Vector3(7.0, 0.03, 10.8), Vector3(5.0, 0.08, 1.2), stone_material)
	_create_visual_box("GoalLintel", Vector3(0.0, 10.0, -19.5), Vector3(9.0, 0.45, 0.45), gold_material)
	_create_label("TRIAL 001", Vector3(0.0, 4.2, 19.4), Color(0.8, 0.86, 1.0), 24)
	_create_label("SHATTER & CLIMB", Vector3(0.0, 3.35, 19.4), Color(1.0, 0.72, 0.22), 34)


func _create_water_ice_bridge(position_value: Vector3, size_value: Vector3) -> StaticBody3D:
	var bridge := StaticBody3D.new()
	bridge.name = "FrozenCrossing"
	bridge.set_script(VillageIceBridgeScript)
	bridge.set("bridge_id", "trial_001_frozen_crossing")
	bridge.set("completion_flag", LEFT_ROUTE_FLAG)
	bridge.set("objective_after", "")
	bridge.set("freeze_message", "The flooded lane locks into a walkable sheet of ice.")
	bridge.position = position_value

	var target_collision := CollisionShape3D.new()
	target_collision.name = "TargetCollision"
	var target_shape := BoxShape3D.new()
	target_shape.size = Vector3(size_value.x + 0.4, 1.0, size_value.z)
	target_collision.shape = target_shape
	target_collision.position.y = -0.2
	bridge.add_child(target_collision)

	var bridge_collision := CollisionShape3D.new()
	bridge_collision.name = "BridgeCollision"
	var crossing_shape := BoxShape3D.new()
	crossing_shape.size = size_value
	bridge_collision.shape = crossing_shape
	bridge_collision.disabled = true
	bridge.add_child(bridge_collision)

	var water_visual := _make_box_mesh(Vector3(size_value.x, 0.16, size_value.z), water_material)
	water_visual.name = "WaterVisual"
	bridge.add_child(water_visual)
	var ice_visual := _make_box_mesh(size_value, ice_material)
	ice_visual.name = "IceVisual"
	ice_visual.position.y = 0.08
	ice_visual.visible = false
	bridge.add_child(ice_visual)

	var status_receiver := Node.new()
	status_receiver.name = "StatusReceiver"
	status_receiver.set_script(StatusReceiverScript)
	bridge.add_child(status_receiver)
	var payload_receiver := Node.new()
	payload_receiver.name = "PayloadReceiver"
	payload_receiver.set_script(PayloadReceiverScript)
	bridge.add_child(payload_receiver)

	environment_root.add_child(bridge)
	bridge.connect("bridge_frozen", _on_left_route_opened)
	return bridge


func _create_shatter_gate(position_value: Vector3) -> StaticBody3D:
	var gate := StaticBody3D.new()
	gate.name = "BrittleMasonrySeal"
	gate.set_script(VillageRouteGateScript)
	gate.set("gate_id", "trial_001_brittle_masonry")
	gate.set("display_name", "Brittle Masonry")
	gate.set("accepts_fire", false)
	gate.set("accepts_ice_force_combo", true)
	gate.set("completion_flag", RIGHT_ROUTE_FLAG)
	gate.set("objective_after", "")
	gate.set("freeze_message", "Ice locks the fractured masonry into one brittle mass.")
	gate.set("shatter_message", "The Hammer breaks the frozen seal apart.")
	gate.set("locked_message", "The fractured wall absorbs the impact instead of breaking cleanly.")
	gate.position = position_value

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.4, 4.2, 1.0)
	collision.shape = shape
	collision.position.y = 2.1
	gate.add_child(collision)

	var visual_root := Node3D.new()
	visual_root.name = "VisualRoot"
	gate.add_child(visual_root)
	for index: int in range(7):
		var chunk := _make_box_mesh(
			Vector3(1.0 + float(index % 2) * 0.35, 1.25, 0.8),
			stone_material
		)
		chunk.name = "Fracture%02d" % [index + 1]
		chunk.position = Vector3(
			-2.0 + float(index % 4) * 1.35,
			0.7 + float(index / 4) * 1.35,
			0.0
		)
		chunk.rotation_degrees.z = -7.0 + float(index * 5)
		visual_root.add_child(chunk)

	environment_root.add_child(gate)
	gate.connect("gate_opened", _on_right_route_opened)
	return gate


func _on_left_route_opened(_bridge_id: String, _method: String) -> void:
	if left_route_ready:
		return
	left_route_ready = true
	route_opened.emit("water_ice")
	_set_objective("A route is open. Reach the upper seal.")


func _on_right_route_opened(_gate_id: String, _method: String) -> void:
	if right_route_ready:
		return
	right_route_ready = true
	route_opened.emit("ice_heavy")
	_set_objective("A route is open. Reach the upper seal.")


func _on_goal_body_entered(body: Node3D) -> void:
	if body == null or not body.is_in_group("player"):
		return
	if not left_route_ready and not right_route_ready:
		_show_message("The upper seal stays dormant. Open one of the chamber's routes first.")
		return
	_complete_trial("water_ice" if left_route_ready else "ice_heavy")


func _complete_trial(route_id: String) -> void:
	if trial_complete:
		return
	trial_complete = true
	GameState.set_flag(COMPLETION_FLAG, true)
	_set_objective("Trial 001 complete. Reset to try the other route.")
	_show_message("Shatter & Climb complete. The chamber accepted your solution.")
	if goal_beacon != null:
		goal_beacon.scale = Vector3.ONE * 1.45
	trial_completed.emit(route_id)


func reset_trial() -> void:
	if resetting:
		return
	resetting = true
	trial_complete = false
	left_route_ready = false
	right_route_ready = false
	_clear_runtime_flags()
	if left_bridge != null and left_bridge.has_method("reset_bridge"):
		left_bridge.call("reset_bridge")
	if right_gate != null and right_gate.has_method("reset_gate"):
		right_gate.call("reset_gate")
	if player != null:
		player.global_transform = START_TRANSFORM
		player.velocity = Vector3.ZERO
	_configure_trial_loadout()
	_restore_resources()
	if goal_beacon != null:
		goal_beacon.scale = Vector3.ONE
	_set_objective("Reach the upper seal using only Water, Ice, and the Training Hammer.")
	trial_reset.emit()
	resetting = false


func _configure_trial_loadout() -> void:
	if player == null:
		return
	var caster: Node = player.get_node_or_null("AbilityCaster")
	if caster != null:
		caster.set("loadout", TrialLoadout.duplicate(true))
		caster.set("current_ability_index", 0)
		if caster.has_method("align_focus_menu_to_current_ability"):
			caster.call("align_focus_menu_to_current_ability")
		if caster.has_method("emit_current_ability"):
			caster.call("emit_current_ability")
	var weapon_controller: Node = player.get_node_or_null("WeaponController")
	if weapon_controller != null:
		if weapon_controller.has_method("equip_weapon"):
			weapon_controller.call("equip_weapon", TrainingHammer)
		else:
			weapon_controller.set("equipped_weapon", TrainingHammer)
	var aerial: Node = player.get_node_or_null("AerialLocomotion")
	if aerial != null:
		if "double_jump_unlocked" in aerial:
			aerial.set("double_jump_unlocked", false)
		if "hover_unlocked" in aerial:
			aerial.set("hover_unlocked", false)
		if "flight_unlocked" in aerial:
			aerial.set("flight_unlocked", false)


func _restore_resources() -> void:
	GameState.set_stat("health", GameState.get_stat("max_health"))
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	GameState.set_stat("stance", GameState.get_stat("max_stance"))


func _clear_runtime_flags() -> void:
	GameState.set_flag(COMPLETION_FLAG, false)
	GameState.set_flag(LEFT_ROUTE_FLAG, false)
	GameState.set_flag(RIGHT_ROUTE_FLAG, false)


func _create_stair_run(
	name_prefix: String,
	start_position: Vector3,
	count: int,
	step_size: Vector3,
	step_offset: Vector3,
	material: Material
) -> void:
	for index: int in range(count):
		_create_static_box(
			name_prefix + "%02d" % [index + 1],
			start_position + step_offset * float(index),
			step_size,
			material
		)


func _create_static_box(
	node_name: String,
	position_value: Vector3,
	size_value: Vector3,
	material: Material
) -> StaticBody3D:
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
	var mesh_instance := _make_box_mesh(size_value, material)
	mesh_instance.name = "Visual"
	body.add_child(mesh_instance)
	environment_root.add_child(body)
	return body


func _create_visual_box(
	node_name: String,
	position_value: Vector3,
	size_value: Vector3,
	material: Material
) -> MeshInstance3D:
	var mesh_instance := _make_box_mesh(size_value, material)
	mesh_instance.name = node_name
	mesh_instance.position = position_value
	environment_root.add_child(mesh_instance)
	return mesh_instance


func _make_box_mesh(size_value: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	return mesh_instance


func _create_label(text_value: String, position_value: Vector3, color: Color, size_value: int) -> void:
	var label := Label3D.new()
	label.name = text_value.replace(" ", "")
	label.text = text_value
	label.position = position_value
	label.modulate = color
	label.font_size = size_value
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	environment_root.add_child(label)


func _make_material(
	color: Color,
	metallic: float,
	roughness: float,
	transparent: bool = false
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if transparent or color.a < 0.999:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _make_emissive(
	color: Color,
	emission: Color,
	energy: float,
	transparent: bool = false
) -> StandardMaterial3D:
	var material := _make_material(color, 0.12, 0.38, transparent)
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material


func _set_objective(text_value: String) -> void:
	GameState.set_objective(text_value)
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
		"trial_chamber_001": true,
		"trial_id": "shatter_climb",
		"complete": trial_complete,
		"left_route_ready": left_route_ready,
		"right_route_ready": right_route_ready,
		"fixed_spells": ["water_jet", "ice_lance"],
		"fixed_weapon": "hammer",
		"flight_disabled": (
			not bool(player.get_node("AerialLocomotion").get("flight_unlocked"))
			if player != null and player.get_node_or_null("AerialLocomotion") != null
			else true
		),
	}
