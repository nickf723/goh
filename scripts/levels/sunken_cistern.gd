extends Node3D
class_name SunkenCistern

## The Sunken Cistern - a standalone elemental dungeon beneath a city.
##
## Six connected spaces (one optional). Grace freezes a broken sluice to cross,
## energises a lightning ward over a gremlin fight, may detour to thaw a cache
## with fire, clears a construct-guarded reservoir with a paired ice + lightning
## ward, then finishes against a Stoneback Salamander in the drowned undercroft.
##
## Reuses, adds no new mechanics:
##   scripts/puzzles/prototype_element_lock_target.gd     (cast matching element -> active)
##   scripts/puzzles/prototype_element_lock_controller.gd (all active -> gate.unlock())
##   scripts/puzzles/village_ice_bridge.gd                (freeze water -> walkable path)
##   scenes/actors/interactables/readable_magic_gate.tscn (unlock())
##   existing enemy + interactable scenes
## Authoring pattern copied from scripts/levels/trial_chamber_001_shatter_climb.gd.
##
## Z axis runs north (entry, +Z) to south (undercroft, -Z). One long left wall,
## a split right wall with a branch gap at z in [2, 12].

signal stage_changed(stage_id: String)
signal dungeon_completed
signal dungeon_reset

enum Stage {
	SLUICE_ENTRY,
	PUMP_HALL,
	CRACKED_RESERVOIR,
	DROWNED_UNDERCROFT,
	COMPLETE,
}

const Loadout: AbilityLoadout = preload("res://data/loadouts/sunken_cistern_loadout.tres")
const GateScene: PackedScene = preload("res://scenes/actors/interactables/readable_magic_gate.tscn")
const SaveBedScene: PackedScene = preload("res://scenes/actors/interactables/save_bed.tscn")
const ManaShrineScene: PackedScene = preload("res://scenes/actors/interactables/mana_shrine.tscn")
const RewardAltarScene: PackedScene = preload("res://scenes/actors/interactables/church_trial_reward_altar.tscn")
const RewardChestScene: PackedScene = preload("res://scenes/items/reward_choice_chest.tscn")
const LevelExitScene: PackedScene = preload("res://scenes/actors/interactables/level_exit.tscn")
const StormGremlinScene: PackedScene = preload("res://scenes/actors/enemies/storm_drain_gremlin_actor.tscn")
const LargeConstructScene: PackedScene = preload("res://scenes/actors/enemies/large_construct_enemy.tscn")
const StonebackSalamanderScene: PackedScene = preload("res://scenes/actors/enemies/stoneback_salamander_enemy.tscn")

const LockTargetScript: Script = preload("res://scripts/puzzles/prototype_element_lock_target.gd")
const LockControllerScript: Script = preload("res://scripts/puzzles/prototype_element_lock_controller.gd")
const IceBridgeScript: Script = preload("res://scripts/puzzles/village_ice_bridge.gd")
const StatusReceiverScript: Script = preload("res://scripts/combat/status_receiver.gd")
const PayloadReceiverScript: Script = preload("res://scripts/combat/payload_receiver.gd")

const COMPLETION_FLAG: String = "sunken_cistern_complete"
const SLUICE_FLAG: String = "sunken_cistern_sluice_frozen"
const START_POSITION: Vector3 = Vector3(0.0, 1.5, 35.0)
const VOID_Y: float = -6.0

var player: CharacterBody3D
var architecture_root: Node3D
var stage: Stage = Stage.SLUICE_ENTRY
var complete: bool = false
var resetting: bool = false
var respawn_point: Vector3 = START_POSITION

var sluice_bridge: StaticBody3D
var gate_pump: Node
var gate_reservoir: Node
var gate_undercroft: Node
var cache_gate: Node
var undercroft_exit: Area3D

var floor_mat: StandardMaterial3D
var wall_mat: StandardMaterial3D
var trim_mat: StandardMaterial3D
var water_mat: StandardMaterial3D
var ice_mat: StandardMaterial3D
var void_mat: StandardMaterial3D
var ice_glow: StandardMaterial3D
var bolt_glow: StandardMaterial3D
var flame_glow: StandardMaterial3D


func _ready() -> void:
	add_to_group("elemental_dungeons")
	add_to_group("debuggable")
	player = get_node_or_null("Player") as CharacterBody3D
	_clear_flags()
	# Build one frame later so instanced props/enemies that touch the tree in
	# their own _ready() do not collide with this node still setting up.
	call_deferred("_build_dungeon")


func _build_dungeon() -> void:
	_build_materials()
	_build_shell()
	_build_sluice_entry()
	_build_pump_hall()
	_build_overflow_gallery()
	_build_cracked_reservoir()
	_build_drowned_undercroft()
	_configure_loadout()
	_restore_resources()
	_set_stage(Stage.SLUICE_ENTRY, false)
	_show_message(
		"The Sunken Cistern\n"
		+ "Old wards seal each chamber. Answer them with the element they were cut for."
	)
	set_process(true)


func _process(_delta: float) -> void:
	if player == null or resetting:
		return
	if player.global_position.y < VOID_Y:
		player.velocity = Vector3.ZERO
		player.global_position = respawn_point
		_show_message("The flooded dark spits Grace back onto solid stone.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_viewport().set_input_as_handled()
		reset_dungeon()


# --- materials --------------------------------------------------------------

func _build_materials() -> void:
	floor_mat = _make_material(Color(0.09, 0.11, 0.13), 0.05, 0.85)
	wall_mat = _make_material(Color(0.06, 0.08, 0.10), 0.04, 0.9)
	trim_mat = _make_material(Color(0.16, 0.19, 0.22), 0.2, 0.6)
	water_mat = _make_material(Color(0.06, 0.34, 0.46, 0.66), 0.0, 0.15, true)
	ice_mat = _make_emissive(Color(0.4, 0.82, 0.95, 0.9), Color(0.28, 0.72, 1.0), 1.6, true)
	void_mat = _make_material(Color(0.01, 0.015, 0.02), 0.0, 1.0)
	ice_glow = _make_emissive(Color(0.36, 0.8, 1.0), Color(0.3, 0.75, 1.0), 3.0)
	bolt_glow = _make_emissive(Color(0.95, 0.86, 0.35), Color(1.0, 0.82, 0.25), 3.2)
	flame_glow = _make_emissive(Color(1.0, 0.5, 0.2), Color(1.0, 0.42, 0.14), 3.2)


# --- shell -----------------------------------------------------------------

func _build_shell() -> void:
	architecture_root = Node3D.new()
	architecture_root.name = "CisternArchitecture"
	add_child(architecture_root)

	_static_box("LeftWall", Vector3(-9.5, 5.0, -2.5), Vector3(1.0, 12.0, 86.0), wall_mat)
	# Right wall split so z in [2, 12] is an open branch mouth.
	_static_box("RightWallNorth", Vector3(9.5, 5.0, 26.0), Vector3(1.0, 12.0, 28.0), wall_mat)
	_static_box("RightWallSouth", Vector3(9.5, 5.0, -21.5), Vector3(1.0, 12.0, 47.0), wall_mat)
	_static_box("BackWall", Vector3(0.0, 5.0, 39.5), Vector3(20.0, 12.0, 1.0), wall_mat)
	_static_box("SouthWall", Vector3(0.0, 5.0, -44.5), Vector3(20.0, 12.0, 1.0), wall_mat)
	_static_box("Ceiling", Vector3(0.0, 11.0, -2.5), Vector3(20.0, 1.0, 86.0), wall_mat)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.05, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.52, 0.62)
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color(0.16, 0.24, 0.30)
	env.fog_density = 0.012
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_bloom = 0.15
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.name = "CisternEnvironment"
	we.environment = env
	architecture_root.add_child(we)

	# Warm sconce fills down the spine of the cistern.
	for z_value: float in [34.0, 16.0, 5.0, -14.0, -24.0, -34.0]:
		_room_light("Sconce_%d" % int(z_value), Vector3(0.0, 7.0, z_value), 2.1, 26.0,
			Color(0.62, 0.74, 0.9))
	_room_light("GallerySconce", Vector3(18.0, 6.5, 7.0), 1.8, 20.0, Color(0.6, 0.72, 0.88))


# --- room 1: sluice entry (z 14 .. 40) -------------------------------

func _build_sluice_entry() -> void:
	_static_box("EntryFloor", Vector3(0.0, -0.5, 33.0), Vector3(18.0, 1.0, 14.0), floor_mat)
	_static_box("SluiceFarFloor", Vector3(0.0, -0.5, 16.5), Vector3(18.0, 1.0, 5.0), floor_mat)
	_visual_box("SluicePitVoid", Vector3(0.0, -7.0, 22.0), Vector3(18.0, 1.0, 8.0), void_mat)

	sluice_bridge = _make_ice_bridge(
		"FrozenSluice", "sunken_cistern_sluice", SLUICE_FLAG,
		Vector3(0.0, 0.0, 22.0), Vector3(8.5, 0.5, 8.0),
		"The running sluice locks into a sheet of walkable ice.")

	var bed := SaveBedScene.instantiate()
	bed.name = "EntrySaveBed"
	architecture_root.add_child(bed)
	(bed as Node3D).global_position = Vector3(-5.5, 0.1, 36.0)
	if "bed_id" in bed:
		bed.set("bed_id", "sunken_cistern_entry_bed")

	var shrine := ManaShrineScene.instantiate()
	shrine.name = "EntryManaShrine"
	architecture_root.add_child(shrine)
	(shrine as Node3D).global_position = Vector3(5.5, 0.1, 36.0)

	_make_lock("SluiceIceLock", "ice", "cistern_r1_locks", Vector3(0.0, 1.2, 15.4), ice_glow)
	_label("ICE", Vector3(0.0, 3.0, 15.0), Color(0.4, 0.82, 1.0), 26)

	gate_pump = _make_gate_in_wall(
		"PumpGate", Vector3(0.0, 0.0, 13.5),
		"The sluice ward answers. The pump hall opens.")
	_wire_controller("R1Controller", "cistern_r1_locks", gate_pump, _on_sluice_solved)

	_label("THE SUNKEN CISTERN", Vector3(0.0, 4.4, 38.9), Color(0.66, 0.82, 1.0), 30)


# --- room 2: pump hall (z -3 .. 13) + branch mouth ------------------

func _build_pump_hall() -> void:
	_static_box("PumpFloor", Vector3(0.0, -0.5, 5.0), Vector3(18.0, 1.0, 16.0), floor_mat)
	_water_sheet("PumpFloodwater", Vector3(0.0, 0.12, 6.0), Vector2(14.0, 12.0))
	_static_box("PumpDais", Vector3(0.0, 0.1, 0.0), Vector3(6.0, 0.6, 3.0), trim_mat)

	var bed := SaveBedScene.instantiate()
	bed.name = "PumpSaveBed"
	architecture_root.add_child(bed)
	(bed as Node3D).global_position = Vector3(-6.5, 0.1, 11.0)
	if "bed_id" in bed:
		bed.set("bed_id", "sunken_cistern_pump_bed")

	_spawn_enemy(StormGremlinScene, "PumpGremlinA", Vector3(-4.0, 1.0, 7.0))
	_spawn_enemy(StormGremlinScene, "PumpGremlinB", Vector3(4.5, 1.0, 4.0))

	_make_lock("PumpBoltLock", "lightning", "cistern_r2_locks", Vector3(0.0, 1.5, 0.0), bolt_glow)
	_label("LIGHTNING", Vector3(0.0, 3.4, -0.4), Color(1.0, 0.86, 0.3), 24)

	gate_reservoir = _make_gate_in_wall(
		"ReservoirGate", Vector3(0.0, 0.0, -3.5),
		"The pump ward answers. The reservoir opens.")
	_wire_controller("R2Controller", "cistern_r2_locks", gate_reservoir, _on_pump_solved)

	# Branch doorway: header over the z in [2, 12] gap, and a floor bridge.
	_static_box("BranchLintel", Vector3(9.5, 9.0, 7.0), Vector3(1.0, 4.0, 10.0), wall_mat)
	_static_box("BranchThreshold", Vector3(9.5, -0.5, 7.0), Vector3(3.0, 1.0, 10.0), floor_mat)


# --- room 3: overflow gallery (optional, x 10 .. 27) ---------------

func _build_overflow_gallery() -> void:
	var gx := 18.0
	_static_box("GalleryFloor", Vector3(gx, -0.5, 7.0), Vector3(16.0, 1.0, 14.0), floor_mat)
	_static_box("GalleryFarWall", Vector3(gx + 8.0, 5.0, 7.0), Vector3(1.0, 12.0, 16.0), wall_mat)
	_static_box("GalleryNorthWall", Vector3(gx, 5.0, 14.5), Vector3(17.0, 12.0, 1.0), wall_mat)
	_static_box("GallerySouthWall", Vector3(gx, 5.0, -0.5), Vector3(17.0, 12.0, 1.0), wall_mat)
	_static_box("GalleryCeiling", Vector3(gx, 11.0, 7.0), Vector3(17.0, 1.0, 16.0), wall_mat)
	_visual_box("GalleryFrostGrate", Vector3(gx + 3.0, 2.0, 7.0), Vector3(0.4, 4.0, 6.0), ice_mat)

	_make_lock("GalleryFlameLock", "fire", "cistern_cache_locks",
		Vector3(gx + 3.2, 1.6, 7.0), flame_glow)
	_label("FIRE", Vector3(gx + 3.2, 3.6, 7.0), Color(1.0, 0.55, 0.25), 24)

	cache_gate = _make_gate(
		"CacheGate", Vector3(gx + 4.6, 0.0, 7.0), 90.0,
		"The frost grate steams away. The cache is open.")
	_wire_controller("CacheController", "cistern_cache_locks", cache_gate, Callable())

	var chest := RewardChestScene.instantiate()
	chest.name = "GalleryCache"
	if "starts_locked" in chest:
		chest.set("starts_locked", false)
	if "resettable_in_lab" in chest:
		chest.set("resettable_in_lab", false)
	architecture_root.add_child(chest)
	(chest as Node3D).position = Vector3(gx + 6.4, 0.1, 7.0)

	_label("OVERFLOW GALLERY", Vector3(gx, 4.2, 0.2), Color(0.7, 0.8, 0.95), 18)


# --- room 4: cracked reservoir (z -25 .. -4) ---------------------

func _build_cracked_reservoir() -> void:
	_static_box("ResWalkNorth", Vector3(0.0, -0.5, -6.0), Vector3(18.0, 1.0, 4.0), floor_mat)
	_static_box("ResWalkSouth", Vector3(0.0, -0.5, -23.0), Vector3(18.0, 1.0, 4.0), floor_mat)
	_static_box("ResWalkWest", Vector3(-7.5, -0.5, -14.5), Vector3(3.0, 1.0, 17.0), floor_mat)
	_static_box("ResWalkEast", Vector3(7.5, -0.5, -14.5), Vector3(3.0, 1.0, 17.0), floor_mat)
	_visual_box("ResPoolBed", Vector3(0.0, -1.8, -14.5), Vector3(12.0, 1.0, 13.0), void_mat)
	_water_sheet("ResPoolWater", Vector3(0.0, -0.6, -14.5), Vector2(12.0, 13.0))
	_static_box("ResIslandA", Vector3(0.0, -0.5, -11.0), Vector3(3.4, 1.0, 3.4), trim_mat)
	_static_box("ResIslandB", Vector3(0.0, -0.5, -18.0), Vector3(3.4, 1.0, 3.4), trim_mat)

	_spawn_enemy(LargeConstructScene, "ReservoirConstruct", Vector3(0.0, 1.2, -22.0))

	_make_lock("ResIceLock", "ice", "cistern_r3_locks", Vector3(-4.5, 1.4, -24.0), ice_glow)
	_make_lock("ResBoltLock", "lightning", "cistern_r3_locks", Vector3(4.5, 1.4, -24.0), bolt_glow)
	_label("ICE", Vector3(-4.5, 3.1, -24.5), Color(0.4, 0.82, 1.0), 22)
	_label("LIGHTNING", Vector3(4.5, 3.1, -24.5), Color(1.0, 0.86, 0.3), 20)

	gate_undercroft = _make_gate_in_wall(
		"UndercroftGate", Vector3(0.0, 0.0, -25.5),
		"Both wards answer together. The undercroft opens.")
	_wire_controller("R3Controller", "cistern_r3_locks", gate_undercroft, _on_reservoir_solved)


# --- room 5: drowned undercroft, capstone (z -43 .. -26) --------

func _build_drowned_undercroft() -> void:
	_static_box("UndercroftFloor", Vector3(0.0, -0.5, -34.5), Vector3(18.0, 1.0, 17.0), floor_mat)
	_water_sheet("UndercroftShallows", Vector3(0.0, 0.1, -34.5), Vector2(16.0, 15.0))
	_static_box("UndercroftPlinth", Vector3(0.0, 0.05, -39.0), Vector3(4.0, 0.5, 4.0), trim_mat)

	_spawn_enemy(StonebackSalamanderScene, "UndercroftSalamander", Vector3(0.0, 1.3, -30.0))

	var altar := RewardAltarScene.instantiate()
	altar.name = "UndercroftRewardAltar"
	architecture_root.add_child(altar)
	(altar as Node3D).global_position = Vector3(0.0, 0.4, -39.0)
	if "reward_item_id" in altar:
		altar.set("reward_item_id", "sunken_cistern_seal")
	if "objective_after" in altar:
		altar.set("objective_after", "Leave the cistern.")

	undercroft_exit = LevelExitScene.instantiate() as Area3D
	undercroft_exit.name = "UndercroftExit"
	architecture_root.add_child(undercroft_exit)
	undercroft_exit.global_position = Vector3(0.0, 1.0, -42.0)
	if "prompt_text" in undercroft_exit:
		undercroft_exit.set("prompt_text", "Leave the Sunken Cistern")
	if "completion_message" in undercroft_exit:
		undercroft_exit.set("completion_message", "The Sunken Cistern is answered end to end.")
	if "objective_after" in undercroft_exit:
		undercroft_exit.set("objective_after", "The Sunken Cistern is complete. Reset to replay.")
	if undercroft_exit.has_signal("exit_triggered"):
		undercroft_exit.connect("exit_triggered", _on_exit_triggered)

	_label("DROWNED UNDERCROFT", Vector3(0.0, 4.2, -43.6), Color(0.66, 0.8, 0.95), 22)


# --- puzzle / prop builders -------------------------------------------

func _make_lock(node_name: String, element: String, group_name: String,
		position_value: Vector3, glow: StandardMaterial3D) -> StaticBody3D:
	var lock := StaticBody3D.new()
	lock.name = node_name
	lock.set_script(LockTargetScript)
	lock.set("display_name", node_name)
	lock.set("required_element", element)
	lock.set("activation_message", "%s ward answers." % element.capitalize())
	lock.set("wrong_element_message", "The %s ward rejects that element." % element.capitalize())
	lock.position = position_value
	lock.collision_layer = 1
	lock.collision_mask = 0
	lock.add_to_group(group_name)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.6, 2.4, 1.6)
	collision.shape = shape
	lock.add_child(collision)

	var body := _box_mesh(Vector3(1.4, 2.2, 1.4), trim_mat)
	body.name = "MeshInstance3D"
	lock.add_child(body)

	var marker := _box_mesh(Vector3(1.7, 0.4, 1.7), glow)
	marker.name = "ActivatedMarker"
	marker.position = Vector3(0.0, 1.4, 0.0)
	marker.visible = false
	lock.add_child(marker)

	architecture_root.add_child(lock)
	return lock


func _wire_controller(node_name: String, group_name: String, gate: Node,
		on_done: Callable) -> void:
	var controller := Node.new()
	controller.name = node_name
	controller.set_script(LockControllerScript)
	controller.set("target_group_name", group_name)
	controller.set("puzzle_complete_message", "")
	controller.set("objective_after", "")
	architecture_root.add_child(controller)
	controller.set("gate_path", controller.get_path_to(gate))
	if on_done.is_valid() and controller.has_signal("puzzle_completed"):
		controller.connect("puzzle_completed", on_done)


func _make_gate_in_wall(node_name: String, opening_center: Vector3,
		unlock_message: String) -> Node:
	var z := opening_center.z
	_static_box(node_name + "WingLeft", Vector3(-6.25, 4.0, z), Vector3(6.5, 8.0, 1.0), wall_mat)
	_static_box(node_name + "WingRight", Vector3(6.25, 4.0, z), Vector3(6.5, 8.0, 1.0), wall_mat)
	_static_box(node_name + "Lintel", Vector3(0.0, 6.5, z), Vector3(5.5, 3.0, 1.0), wall_mat)
	return _make_gate(node_name, opening_center, 0.0, unlock_message)


func _make_gate(node_name: String, position_value: Vector3, yaw_degrees: float,
		unlock_message: String) -> Node:
	var gate := GateScene.instantiate()
	gate.name = node_name
	if "gate_name" in gate:
		gate.set("gate_name", node_name)
	if "unlock_message" in gate:
		gate.set("unlock_message", unlock_message)
	architecture_root.add_child(gate)
	(gate as Node3D).position = position_value
	(gate as Node3D).rotation_degrees = Vector3(0.0, yaw_degrees, 0.0)
	return gate


func _make_ice_bridge(node_name: String, bridge_id: String, flag: String,
		position_value: Vector3, size_value: Vector3, freeze_message: String) -> StaticBody3D:
	var bridge := StaticBody3D.new()
	bridge.name = node_name
	bridge.set_script(IceBridgeScript)
	bridge.set("bridge_id", bridge_id)
	bridge.set("completion_flag", flag)
	bridge.set("objective_after", "")
	bridge.set("freeze_message", freeze_message)
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
	var walk_shape := BoxShape3D.new()
	walk_shape.size = size_value
	bridge_collision.shape = walk_shape
	bridge_collision.disabled = true
	bridge.add_child(bridge_collision)

	var water_visual := _box_mesh(Vector3(size_value.x, 0.16, size_value.z), water_mat)
	water_visual.name = "WaterVisual"
	bridge.add_child(water_visual)

	var ice_visual := _box_mesh(size_value, ice_mat)
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

	architecture_root.add_child(bridge)
	return bridge


func _room_light(node_name: String, position_value: Vector3, energy: float,
		range_value: float, color: Color) -> void:
	var lamp := OmniLight3D.new()
	lamp.name = node_name
	lamp.position = position_value
	lamp.light_energy = energy
	lamp.omni_range = range_value
	lamp.light_color = color
	lamp.shadow_enabled = false
	architecture_root.add_child(lamp)


func _water_sheet(node_name: String, position_value: Vector3, xz_size: Vector2) -> void:
	var sheet := _box_mesh(Vector3(xz_size.x, 0.12, xz_size.y), water_mat)
	sheet.name = node_name
	sheet.position = position_value
	architecture_root.add_child(sheet)


func _spawn_enemy(scene: PackedScene, node_name: String, position_value: Vector3) -> Node:
	var enemy := scene.instantiate()
	enemy.name = node_name
	architecture_root.add_child(enemy)
	if enemy is Node3D:
		(enemy as Node3D).global_position = position_value
	return enemy


# --- stage machine ---------------------------------------------------

func _on_sluice_solved() -> void:
	_set_stage(Stage.PUMP_HALL)


func _on_pump_solved() -> void:
	_set_stage(Stage.CRACKED_RESERVOIR)


func _on_reservoir_solved() -> void:
	_set_stage(Stage.DROWNED_UNDERCROFT)


func _on_exit_triggered(_result: Dictionary) -> void:
	if complete:
		return
	complete = true
	GameState.set_flag(COMPLETION_FLAG, true)
	_set_stage(Stage.COMPLETE)
	_show_message("The Sunken Cistern is answered end to end.")
	dungeon_completed.emit()


func _set_stage(next_stage: Stage, announce: bool = true) -> void:
	stage = next_stage
	match stage:
		Stage.SLUICE_ENTRY:
			_set_objective("Freeze the sluice, then answer the ICE ward.")
			respawn_point = START_POSITION
		Stage.PUMP_HALL:
			_set_objective("Clear the pump hall and answer the LIGHTNING ward.")
			respawn_point = Vector3(0.0, 1.5, 11.0)
			if announce:
				_show_message("The sluice ward yields. Ahead: the pump hall.")
		Stage.CRACKED_RESERVOIR:
			_set_objective("Cross the reservoir; answer the ICE and LIGHTNING wards together.")
			respawn_point = Vector3(0.0, 1.5, -5.0)
			if announce:
				_show_message("The pump hall is quiet. The cracked reservoir waits below.")
		Stage.DROWNED_UNDERCROFT:
			_set_objective("Face what guards the undercroft, claim the seal, then leave.")
			respawn_point = Vector3(0.0, 1.5, -27.0)
			if announce:
				_show_message("Both wards answered. The drowned undercroft opens.")
		Stage.COMPLETE:
			_set_objective("The Sunken Cistern is complete. Reset to replay.")
	stage_changed.emit(Stage.keys()[int(stage)])


func reset_dungeon() -> void:
	if resetting:
		return
	resetting = true
	complete = false
	_clear_flags()
	if sluice_bridge != null and is_instance_valid(sluice_bridge) and sluice_bridge.has_method("reset_bridge"):
		sluice_bridge.call("reset_bridge")
	if player != null:
		player.velocity = Vector3.ZERO
		player.global_position = START_POSITION
		player.rotation_degrees = Vector3.ZERO
	_configure_loadout()
	_restore_resources()
	_set_stage(Stage.SLUICE_ENTRY, false)
	_show_message("The wards reseal. Reload the scene for a full reset of opened gates.")
	dungeon_reset.emit()
	resetting = false


# --- player / state helpers ----------------------------------------

func _configure_loadout() -> void:
	if player == null:
		return
	var caster: Node = player.get_node_or_null("AbilityCaster")
	if caster != null:
		caster.set("loadout", Loadout.duplicate(true))
		caster.set("current_ability_index", 0)
		if caster.has_method("align_focus_menu_to_current_ability"):
			caster.call("align_focus_menu_to_current_ability")
		if caster.has_method("emit_current_ability"):
			caster.call("emit_current_ability")


func _restore_resources() -> void:
	GameState.set_stat("health", GameState.get_stat("max_health"))
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	GameState.set_stat("stance", GameState.get_stat("max_stance"))


func _clear_flags() -> void:
	GameState.set_flag(COMPLETION_FLAG, false)
	GameState.set_flag(SLUICE_FLAG, false)


func _is_player(body: Node) -> bool:
	return body != null and body.is_in_group("player")


# --- primitive builders (from trial_chamber_001_shatter_climb.gd) ----

func _static_box(node_name: String, position_value: Vector3, size_value: Vector3,
		material: Material) -> StaticBody3D:
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
	var mesh_instance := _box_mesh(size_value, material)
	mesh_instance.name = "Visual"
	body.add_child(mesh_instance)
	architecture_root.add_child(body)
	return body


func _visual_box(node_name: String, position_value: Vector3, size_value: Vector3,
		material: Material) -> MeshInstance3D:
	var mesh_instance := _box_mesh(size_value, material)
	mesh_instance.name = node_name
	mesh_instance.position = position_value
	architecture_root.add_child(mesh_instance)
	return mesh_instance


func _box_mesh(size_value: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	return mesh_instance


func _label(text_value: String, position_value: Vector3, color: Color, size_value: int) -> void:
	var label := Label3D.new()
	label.name = "Label_" + text_value.replace(" ", "")
	label.text = text_value
	label.position = position_value
	label.modulate = color
	label.font_size = size_value
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	architecture_root.add_child(label)


func _make_material(color: Color, metallic: float, roughness: float,
		transparent: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if transparent or color.a < 0.999:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _make_emissive(color: Color, emission: Color, energy: float,
		transparent: bool = false) -> StandardMaterial3D:
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


func _show_message(text_value: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text_value)
	else:
		print(text_value)


func get_debug_data() -> Dictionary:
	return {
		"sunken_cistern": true,
		"stage": Stage.keys()[int(stage)],
		"complete": complete,
		"rooms": 6,
		"locks": ["ice", "lightning", "fire(optional)", "ice+lightning"],
		"capstone": "stoneback_salamander",
	}
