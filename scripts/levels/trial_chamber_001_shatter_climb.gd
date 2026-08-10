extends Node3D
class_name TrialChamber001ShatterClimb

signal stage_completed(stage_id: String)
signal optional_reward_claimed(item_id: String, quantity: int)
signal trial_completed(solution_id: String)
signal trial_reset

enum TrialStage {
	FREEZE_CROSSING,
	SHATTER_SEAL,
	SYNTHESIS_ASCENT,
	COMPLETE,
}

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
const RewardChoiceChestScene: PackedScene = preload(
	"res://scenes/items/reward_choice_chest.tscn"
)

const COMPLETION_FLAG: String = "trial_chamber_001_shatter_climb_complete"
const CROSSING_FLAG: String = "trial_chamber_001_crossing_frozen"
const SHATTER_FLAG: String = "trial_chamber_001_main_seal_shattered"
const ASCENT_FLAG: String = "trial_chamber_001_ascent_frozen"
const CROWN_FLAG: String = "trial_chamber_001_crown_shattered"
const START_POSITION: Vector3 = Vector3(0.0, 1.0, 27.0)

var player: CharacterBody3D
var environment_root: Node3D
var crossing_bridge: StaticBody3D
var main_gate: StaticBody3D
var ascent_bridge: StaticBody3D
var crown_gate: StaticBody3D
var optional_chest: Node
var goal_area: Area3D
var goal_beacon: MeshInstance3D
var stage: TrialStage = TrialStage.FREEZE_CROSSING
var trial_complete: bool = false
var optional_reward_taken: bool = false
var crossing_frozen: bool = false
var main_gate_open: bool = false
var ascent_frozen: bool = false
var crown_gate_open: bool = false
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
	_set_stage(TrialStage.FREEZE_CROSSING, false)
	_show_message(
		"Trial 001 • Shatter & Climb\n"
		+ "Three problems stand between Grace and the upper seal. Optional caches are never required."
	)
	set_process(true)


func _process(_delta: float) -> void:
	if player == null or resetting:
		return
	if player.global_position.y < -5.0:
		_show_message("The chamber catches Grace and returns her to the entrance.")
		reset_trial()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_viewport().set_input_as_handled()
		reset_trial()


func _build_materials() -> void:
	floor_material = _make_material(Color(0.052, 0.062, 0.082), 0.16, 0.8)
	wall_material = _make_material(Color(0.072, 0.088, 0.118), 0.12, 0.86)
	platform_material = _make_material(Color(0.13, 0.155, 0.205), 0.18, 0.7)
	stone_material = _make_material(Color(0.29, 0.31, 0.35), 0.08, 0.8)
	water_material = _make_material(Color(0.07, 0.46, 0.7, 0.74), 0.02, 0.18, true)
	ice_material = _make_emissive(
		Color(0.34, 0.82, 0.96, 0.9),
		Color(0.2, 0.72, 1.0),
		1.7,
		true
	)
	gold_material = _make_emissive(
		Color(0.78, 0.58, 0.12, 1.0),
		Color(1.0, 0.72, 0.18),
		3.2
	)
	void_material = _make_material(Color(0.012, 0.016, 0.025), 0.0, 0.98)


func _build_chamber() -> void:
	environment_root = Node3D.new()
	environment_root.name = "TrialArchitecture"
	add_child(environment_root)

	# One continuous shell. No decorative maze, no staircase forest.
	_create_static_box("LeftWall", Vector3(-10.0, 6.5, -3.0), Vector3(1.0, 14.0, 68.0), wall_material)
	_create_static_box("RightWall", Vector3(10.0, 6.5, -3.0), Vector3(1.0, 14.0, 68.0), wall_material)
	_create_static_box("Ceiling", Vector3(0.0, 13.5, -3.0), Vector3(20.0, 1.0, 68.0), wall_material)
	_create_static_box("FrontWall", Vector3(0.0, 6.5, 31.0), Vector3(20.0, 14.0, 1.0), wall_material)
	_create_static_box("BackWall", Vector3(0.0, 6.5, -37.0), Vector3(20.0, 14.0, 1.0), wall_material)

	_build_freeze_crossing()
	_build_shatter_chamber()
	_build_optional_cache()
	_build_synthesis_ascent()
	_build_goal()
	_build_visual_language()


func _build_freeze_crossing() -> void:
	_create_static_box("EntranceFloor", Vector3(0.0, -0.5, 25.0), Vector3(18.0, 1.0, 12.0), floor_material)
	_create_static_box("CrossingFarFloor", Vector3(0.0, -0.5, 7.5), Vector3(18.0, 1.0, 5.0), floor_material)
	_create_visual_box("CrossingVoid", Vector3(0.0, -6.5, 14.5), Vector3(18.0, 1.0, 10.0), void_material)
	crossing_bridge = _create_water_ice_surface(
		"FrozenCrossing",
		"trial_001_crossing",
		CROSSING_FLAG,
		Vector3(0.0, 0.0, 14.5),
		Vector3(8.0, 0.5, 9.0),
		Vector3.ZERO,
		"The flooded span hardens into a walkable sheet of ice."
	)
	crossing_bridge.bridge_frozen.connect(_on_crossing_frozen)
	_create_checkpoint(
		"CrossingCheckpoint",
		Vector3(0.0, 1.0, 8.2),
		Vector3(14.0, 3.0, 1.8),
		_on_crossing_checkpoint_body_entered
	)


func _build_shatter_chamber() -> void:
	_create_static_box("ShatterRoomFloor", Vector3(0.0, -0.5, 0.5), Vector3(18.0, 1.0, 14.0), floor_material)
	_create_static_box("MainGateWingLeft", Vector3(-7.0, 4.0, -6.2), Vector3(4.0, 8.0, 1.0), wall_material)
	_create_static_box("MainGateWingRight", Vector3(7.0, 4.0, -6.2), Vector3(4.0, 8.0, 1.0), wall_material)
	main_gate = _create_shatter_gate(
		"BrittleMasonrySeal",
		"trial_001_main_masonry",
		SHATTER_FLAG,
		Vector3(0.0, 0.0, -6.2),
		Vector3(10.0, 8.0, 1.0),
		"Ice binds the fractured masonry into one brittle mass.",
		"The Heavy Hammer strike breaks the frozen seal apart."
	)
	main_gate.gate_opened.connect(_on_main_gate_opened)
	_create_static_box("PostGateFloor", Vector3(0.0, -0.5, -10.0), Vector3(18.0, 1.0, 7.0), floor_material)
	_create_checkpoint(
		"ShatterCheckpoint",
		Vector3(0.0, 1.0, -8.0),
		Vector3(14.0, 3.0, 1.8),
		_on_shatter_checkpoint_body_entered
	)


func _build_optional_cache() -> void:
	# The shelf is deliberately too high for an ordinary jump and does not own
	# main-route progression. Ice Lance footholds and Water Jet recoil are both
	# legitimate ways to reach it.
	_create_static_box(
		"OptionalCacheShelf",
		Vector3(6.2, 3.2, -10.5),
		Vector3(5.0, 0.5, 4.0),
		platform_material
	)
	_create_static_box(
		"OptionalCacheBackstop",
		Vector3(8.8, 5.0, -10.5),
		Vector3(0.4, 4.0, 4.0),
		stone_material
	)
	_create_visual_box(
		"OptionalCacheFloorMark",
		Vector3(6.2, 0.04, -9.2),
		Vector3(2.0, 0.08, 0.5),
		gold_material
	)
	optional_chest = RewardChoiceChestScene.instantiate()
	optional_chest.name = "OptionalRewardChest"
	optional_chest.set("starts_locked", false)
	optional_chest.set("resettable_in_lab", false)
	if optional_chest is Node3D:
		(optional_chest as Node3D).position = Vector3(6.2, 3.48, -10.5)
	if optional_chest.has_signal("reward_chosen"):
		optional_chest.connect("reward_chosen", _on_optional_reward_chosen)
	environment_root.add_child(optional_chest)


func _build_synthesis_ascent() -> void:
	_create_static_box("AscentLowerFloor", Vector3(0.0, -0.5, -13.0), Vector3(18.0, 1.0, 6.0), floor_material)
	_create_visual_box("AscentVoid", Vector3(0.0, -6.5, -19.0), Vector3(18.0, 1.0, 12.0), void_material)
	ascent_bridge = _create_water_ice_surface(
		"FrozenAscent",
		"trial_001_frozen_ascent",
		ASCENT_FLAG,
		Vector3(0.0, 3.0, -19.0),
		Vector3(8.0, 0.5, 12.0),
		Vector3(-30.0, 0.0, 0.0),
		"The flooded chute freezes into a steep crystalline ramp."
	)
	ascent_bridge.bridge_frozen.connect(_on_ascent_frozen)

	_create_static_box("UpperLanding", Vector3(0.0, 5.75, -25.5), Vector3(18.0, 1.0, 5.0), platform_material)
	_create_static_box("CrownWingLeft", Vector3(-7.0, 9.0, -28.0), Vector3(4.0, 7.0, 1.0), wall_material)
	_create_static_box("CrownWingRight", Vector3(7.0, 9.0, -28.0), Vector3(4.0, 7.0, 1.0), wall_material)
	crown_gate = _create_shatter_gate(
		"CrownMasonrySeal",
		"trial_001_crown_masonry",
		CROWN_FLAG,
		Vector3(0.0, 6.0, -28.0),
		Vector3(10.0, 7.0, 1.0),
		"Ice turns the crown seal brittle.",
		"The Heavy Hammer strike opens the final passage."
	)
	crown_gate.gate_opened.connect(_on_crown_gate_opened)
	_create_static_box("GoalFloor", Vector3(0.0, 5.75, -32.5), Vector3(18.0, 1.0, 8.0), platform_material)


func _build_goal() -> void:
	goal_area = Area3D.new()
	goal_area.name = "UpperSealGoal"
	goal_area.position = Vector3(0.0, 7.2, -33.2)
	goal_area.collision_layer = 0
	goal_area.collision_mask = 1
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(9.0, 3.0, 3.0)
	collision.shape = shape
	goal_area.add_child(collision)
	goal_area.body_entered.connect(_on_goal_body_entered)
	environment_root.add_child(goal_area)

	goal_beacon = MeshInstance3D.new()
	goal_beacon.name = "UpperSealBeacon"
	goal_beacon.position = Vector3(0.0, 9.2, -35.8)
	var beacon_mesh := CylinderMesh.new()
	beacon_mesh.top_radius = 1.25
	beacon_mesh.bottom_radius = 1.25
	beacon_mesh.height = 0.2
	goal_beacon.mesh = beacon_mesh
	goal_beacon.rotation_degrees.x = 90.0
	goal_beacon.material_override = gold_material
	environment_root.add_child(goal_beacon)


func _build_visual_language() -> void:
	_create_label("TRIAL 001", Vector3(0.0, 4.3, 30.35), Color(0.8, 0.86, 1.0), 24)
	_create_label("SHATTER & CLIMB", Vector3(0.0, 3.45, 30.35), Color(1.0, 0.72, 0.22), 34)
	_create_label("I", Vector3(-8.8, 4.0, 11.0), Color(0.32, 0.78, 1.0), 30)
	_create_label("II", Vector3(-8.8, 4.0, -3.5), Color(0.72, 0.84, 1.0), 30)
	_create_label("III", Vector3(-8.8, 4.0, -13.0), Color(1.0, 0.72, 0.22), 30)
	_create_label("CACHE", Vector3(6.2, 5.4, -12.3), Color(1.0, 0.72, 0.22), 20)


func _create_water_ice_surface(
	node_name: String,
	bridge_id: String,
	completion_flag: String,
	position_value: Vector3,
	size_value: Vector3,
	rotation_value: Vector3,
	freeze_message: String
) -> StaticBody3D:
	var bridge := StaticBody3D.new()
	bridge.name = node_name
	bridge.set_script(VillageIceBridgeScript)
	bridge.set("bridge_id", bridge_id)
	bridge.set("completion_flag", completion_flag)
	bridge.set("objective_after", "")
	bridge.set("freeze_message", freeze_message)
	bridge.position = position_value
	bridge.rotation_degrees = rotation_value

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

	var water_visual := _make_box_mesh(
		Vector3(size_value.x, 0.16, size_value.z),
		water_material
	)
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
	return bridge


func _create_shatter_gate(
	node_name: String,
	gate_id: String,
	completion_flag: String,
	position_value: Vector3,
	size_value: Vector3,
	freeze_message: String,
	shatter_message: String
) -> StaticBody3D:
	var gate := StaticBody3D.new()
	gate.name = node_name
	gate.set_script(VillageRouteGateScript)
	gate.set("gate_id", gate_id)
	gate.set("display_name", node_name.replace("Seal", " Seal").replace("Masonry", " Masonry"))
	gate.set("accepts_fire", false)
	gate.set("accepts_ice_force_combo", true)
	gate.set("require_heavy_for_shatter", true)
	gate.set("completion_flag", completion_flag)
	gate.set("objective_after", "")
	gate.set("freeze_message", freeze_message)
	gate.set("shatter_message", shatter_message)
	gate.set("locked_message", "The fractured stone flexes under ordinary force but does not fail.")
	gate.position = position_value

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	collision.position.y = size_value.y * 0.5
	gate.add_child(collision)

	var visual_root := Node3D.new()
	visual_root.name = "VisualRoot"
	gate.add_child(visual_root)
	var chunk_count: int = 12
	for index: int in range(chunk_count):
		var row: int = index / 4
		var column: int = index % 4
		var chunk := _make_box_mesh(
			Vector3(size_value.x / 4.5, size_value.y / 3.5, size_value.z * 0.8),
			stone_material
		)
		chunk.name = "Fracture%02d" % [index + 1]
		chunk.position = Vector3(
			-size_value.x * 0.34 + float(column) * size_value.x * 0.225,
			size_value.y * 0.17 + float(row) * size_value.y * 0.29,
			0.0
		)
		chunk.rotation_degrees.z = -8.0 + float((index * 7) % 17)
		visual_root.add_child(chunk)

	environment_root.add_child(gate)
	return gate


func _create_checkpoint(
	node_name: String,
	position_value: Vector3,
	size_value: Vector3,
	callback: Callable
) -> Area3D:
	var area := Area3D.new()
	area.name = node_name
	area.position = position_value
	area.collision_layer = 0
	area.collision_mask = 1
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	area.add_child(collision)
	area.body_entered.connect(callback)
	environment_root.add_child(area)
	return area


func _on_crossing_frozen(_bridge_id: String) -> void:
	crossing_frozen = true


func _on_main_gate_opened(_gate_id: String, _method: String) -> void:
	main_gate_open = true


func _on_ascent_frozen(_bridge_id: String) -> void:
	ascent_frozen = true


func _on_crown_gate_opened(_gate_id: String, _method: String) -> void:
	crown_gate_open = true


func _on_crossing_checkpoint_body_entered(body: Node3D) -> void:
	if not _is_player(body) or stage != TrialStage.FREEZE_CROSSING:
		return
	stage_completed.emit("freeze_crossing")
	_set_stage(TrialStage.SHATTER_SEAL)


func _on_shatter_checkpoint_body_entered(body: Node3D) -> void:
	if not _is_player(body) or stage != TrialStage.SHATTER_SEAL:
		return
	stage_completed.emit("shatter_seal")
	_set_stage(TrialStage.SYNTHESIS_ASCENT)


func _on_optional_reward_chosen(item_id: String, quantity: int) -> void:
	optional_reward_taken = true
	optional_reward_claimed.emit(item_id, quantity)
	_show_message("Optional cache claimed. The main trial remains unchanged.")


func _on_goal_body_entered(body: Node3D) -> void:
	if not _is_player(body):
		return
	if stage != TrialStage.SYNTHESIS_ASCENT:
		_show_message("The seal is ahead, but the earlier chamber is still unresolved.")
		return
	_complete_trial(_resolve_solution_id())


func _resolve_solution_id() -> String:
	if ascent_frozen and crown_gate_open:
		return "water_ice_then_ice_heavy"
	return "emergent_synthesis"


func _complete_trial(solution_id: String) -> void:
	if trial_complete:
		return
	trial_complete = true
	stage_completed.emit("synthesis_ascent")
	_set_stage(TrialStage.COMPLETE)
	GameState.set_flag(COMPLETION_FLAG, true)
	if goal_beacon != null:
		goal_beacon.scale = Vector3.ONE * 1.45
	_show_message("Shatter & Climb complete. Three problems solved; optional cache status did not matter.")
	trial_completed.emit(solution_id)


func _set_stage(next_stage: TrialStage, announce: bool = true) -> void:
	stage = next_stage
	match stage:
		TrialStage.FREEZE_CROSSING:
			_set_objective("Puzzle I: cross the flooded span.")
			if announce:
				_show_message("Puzzle I begins.")
		TrialStage.SHATTER_SEAL:
			_set_objective("Puzzle II: pass the fractured masonry seal.")
			if announce:
				_show_message("Puzzle I complete. Puzzle II is now the way forward.")
		TrialStage.SYNTHESIS_ASCENT:
			_set_objective("Puzzle III: reach the upper seal through the cascade chamber.")
			if announce:
				_show_message("Puzzle II complete. The final chamber recombines what you learned.")
		TrialStage.COMPLETE:
			_set_objective("Trial 001 complete. Reset to replay the chamber.")


func reset_trial() -> void:
	if resetting:
		return
	resetting = true
	trial_complete = false
	crossing_frozen = false
	main_gate_open = false
	ascent_frozen = false
	crown_gate_open = false
	_clear_runtime_flags()
	for mechanism: Node in [crossing_bridge, main_gate, ascent_bridge, crown_gate]:
		if mechanism == null or not is_instance_valid(mechanism):
			continue
		if mechanism.has_method("reset_bridge"):
			mechanism.call("reset_bridge")
		elif mechanism.has_method("reset_gate"):
			mechanism.call("reset_gate")
	if player != null:
		player.global_position = START_POSITION
		player.rotation_degrees = Vector3.ZERO
		player.velocity = Vector3.ZERO
	_configure_trial_loadout()
	_restore_resources()
	if goal_beacon != null:
		goal_beacon.scale = Vector3.ONE
	_set_stage(TrialStage.FREEZE_CROSSING, false)
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
	GameState.set_flag(CROSSING_FLAG, false)
	GameState.set_flag(SHATTER_FLAG, false)
	GameState.set_flag(ASCENT_FLAG, false)
	GameState.set_flag(CROWN_FLAG, false)


func _is_player(body: Node) -> bool:
	return body != null and body.is_in_group("player")


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


func _create_label(
	text_value: String,
	position_value: Vector3,
	color: Color,
	size_value: int
) -> void:
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
		"format": "three_consecutive_plus_optional",
		"stage": TrialStage.keys()[int(stage)],
		"complete": trial_complete,
		"crossing_frozen": crossing_frozen,
		"main_gate_open": main_gate_open,
		"ascent_frozen": ascent_frozen,
		"crown_gate_open": crown_gate_open,
		"optional_reward_taken": optional_reward_taken,
		"fixed_spells": ["water_jet", "ice_lance"],
		"fixed_weapon": "hammer",
		"flight_disabled": (
			not bool(player.get_node("AerialLocomotion").get("flight_unlocked"))
			if player != null and player.get_node_or_null("AerialLocomotion") != null
			else true
		),
	}
