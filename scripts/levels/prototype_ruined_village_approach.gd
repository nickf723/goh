extends Node3D
class_name PrototypeRuinedVillageApproach

const VillageClueScript = preload("res://scripts/interaction/village_clue.gd")
const VillageMemoryRelicScript = preload("res://scripts/interaction/village_memory_relic.gd")
const VillageRouteGateScript = preload("res://scripts/puzzles/village_route_gate.gd")
const VillageIceBridgeScript = preload("res://scripts/puzzles/village_ice_bridge.gd")
const EncounterControllerScript = preload("res://scripts/encounters/encounter_controller.gd")
const PayloadReceiverScript = preload("res://scripts/combat/payload_receiver.gd")
const StatusReceiverScript = preload("res://scripts/combat/status_receiver.gd")
const RevealableReceiverScript = preload("res://scripts/detection/revealable_receiver.gd")

const VillageEncounter: EncounterDefinition = preload("res://data/encounters/village_square_ambush.tres")
const SaveBedScene: PackedScene = preload("res://scenes/actors/interactables/save_bed.tscn")
const LevelExitScene: PackedScene = preload("res://scenes/actors/interactables/level_exit.tscn")
const WeaponRackScene: PackedScene = preload("res://scenes/actors/interactables/weapon_rack.tscn")
const PracticeSword: WeaponDefinition = preload("res://data/weapons/practice_sword.tres")
const TrainingHammer: WeaponDefinition = preload("res://data/weapons/training_hammer.tres")
const TrainingSpear: WeaponDefinition = preload("res://data/weapons/training_spear.tres")
const VillageShowcaseLoadout: AbilityLoadout = preload("res://data/loadouts/grace_ruined_village_showcase_loadout.tres")

const CHURCH_TRIAL_SCENE: String = "res://scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn"
const ARRIVAL_OBJECTIVE: String = "Survey the impossible village and reach the church above the ruins."

const TEST_FLAGS: Array[String] = [
	"inspected_arrival_crater",
	"inspected_lifted_foundation",
	"inspected_empty_hearth",
	"found_village_memory",
	"cleared_village_square_ambush",
	"opened_square_barrier",
	"opened_ravine_debris",
	"froze_village_bridge",
]

var palette: Dictionary = {}
var geometry_root: Node3D
var detail_root: Node3D
var interaction_root: Node3D
var puzzle_root: Node3D
var encounter_root: Node3D
var reset_in_progress: bool = false


func _ready() -> void:
	Engine.time_scale = 1.0
	add_to_group("ruined_village_approach")
	add_to_group("debuggable")

	create_roots()
	create_palette()
	build_environment()
	build_arrival_hollow()
	build_outer_ruins()
	build_village_square()
	build_ravine_routes()
	build_church_approach()
	build_interactions()
	build_encounter()
	build_checkpoint_and_exit()
	build_optional_weapon_cache()

	await get_tree().process_frame
	await get_tree().process_frame

	var restored: bool = false
	if GameState.has_method("apply_save_for_current_scene"):
		restored = GameState.apply_save_for_current_scene()

	if not restored:
		GameState.set_objective(ARRIVAL_OBJECTIVE)
		show_message(
			"Grace lands in a hollow where an entire village appears to have been cut away from the earth. "
			+ "The church remains on the ridge beyond it."
		)


	configure_player_showcase()


func configure_player_showcase() -> void:
	var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
	if player == null:
		return

	var ability_caster: Node = player.get_node_or_null("AbilityCaster")
	if ability_caster != null:
		var runtime_loadout: AbilityLoadout = VillageShowcaseLoadout.duplicate(true) as AbilityLoadout
		ability_caster.set("loadout", runtime_loadout)

		var flight_index: int = 0
		for index: int in range(runtime_loadout.equipped_abilities.size()):
			var ability: AbilityDefinition = runtime_loadout.equipped_abilities[index]
			if ability != null and ability.get_spell_id() == "flight_concentration":
				flight_index = index
				break

		ability_caster.set("current_ability_index", flight_index)
		if ability_caster.has_method("align_focus_menu_to_current_ability"):
			ability_caster.call("align_focus_menu_to_current_ability")
		if ability_caster.has_method("emit_current_ability"):
			ability_caster.call("emit_current_ability")

	var aerial_locomotion: PlayerAerialLocomotion = player.get_node_or_null("AerialLocomotion") as PlayerAerialLocomotion
	if aerial_locomotion != null:
		aerial_locomotion.double_jump_unlocked = true
		aerial_locomotion.hover_unlocked = true
		aerial_locomotion.flight_unlocked = true
		aerial_locomotion.maximum_air_jumps = 1

	var maximum_mana: int = max(GameState.get_stat("max_mana"), 12)
	GameState.set_stat("max_mana", maximum_mana)
	GameState.set_stat("mana", maximum_mana)
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	GameState.set_stat("focus", max(GameState.get_stat("focus"), 5))

	show_message(
		"Spell showcase ready: all 24 developed spells are learned and equipped, including Rain and Snowfall. "
		+ "Flight is selected — cast with RT / Q, Jump ascends, and Dodge descends."
	)


func _unhandled_input(event: InputEvent) -> void:
	if reset_in_progress:
		return

	if event.is_action_pressed("restart_scene") and OS.has_feature("editor"):
		reset_village_for_test()
		get_viewport().set_input_as_handled()


func create_roots() -> void:
	geometry_root = Node3D.new()
	geometry_root.name = "GeneratedGeometry"
	add_child(geometry_root)

	detail_root = Node3D.new()
	detail_root.name = "GeneratedDetails"
	add_child(detail_root)

	interaction_root = Node3D.new()
	interaction_root.name = "VillageInteractions"
	add_child(interaction_root)

	puzzle_root = Node3D.new()
	puzzle_root.name = "VillagePuzzles"
	add_child(puzzle_root)

	encounter_root = Node3D.new()
	encounter_root.name = "VillageEncounters"
	add_child(encounter_root)


func create_palette() -> void:
	palette = {
		"earth": make_material(Color(0.22, 0.18, 0.13, 1.0), 0.0, 0.92),
		"grass": make_material(Color(0.18, 0.28, 0.14, 1.0), 0.0, 0.9),
		"moss": make_material(Color(0.28, 0.39, 0.17, 1.0), 0.0, 0.88),
		"stone": make_material(Color(0.42, 0.39, 0.34, 1.0), 0.05, 0.78),
		"stone_dark": make_material(Color(0.22, 0.23, 0.24, 1.0), 0.08, 0.82),
		"stone_warm": make_material(Color(0.57, 0.46, 0.34, 1.0), 0.04, 0.72),
		"plaster": make_material(Color(0.72, 0.66, 0.53, 1.0), 0.0, 0.88),
		"wood": make_material(Color(0.32, 0.18, 0.09, 1.0), 0.0, 0.82),
		"wood_light": make_material(Color(0.56, 0.34, 0.16, 1.0), 0.0, 0.74),
		"leaf": make_material(Color(0.16, 0.34, 0.16, 1.0), 0.0, 0.9),
		"leaf_light": make_material(Color(0.28, 0.48, 0.2, 1.0), 0.0, 0.88),
		"water": make_material(Color(0.12, 0.46, 0.72, 0.68), 0.05, 0.2, true),
		"ice": make_emissive_material(Color(0.56, 0.9, 1.0, 0.88), 0.55, true),
		"void": make_material(Color(0.035, 0.045, 0.06, 1.0), 0.0, 0.98),
		"gold": make_emissive_material(Color(0.95, 0.67, 0.18, 1.0), 0.72),
		"memory": make_emissive_material(Color(0.94, 0.72, 0.25, 1.0), 1.15),
		"boundary": make_material(Color(0.12, 0.15, 0.12, 1.0), 0.0, 0.98),
	}


func build_environment() -> void:
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.name = "VillageEnvironment"
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.38, 0.48, 0.56, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.68, 0.72, 0.74, 1.0)
	environment.ambient_light_energy = 0.72
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.55, 0.62, 0.64, 1.0)
	environment.fog_density = 0.006
	environment.fog_height = 3.0
	environment.fog_height_density = 0.08
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "LateAfternoonSun"
	sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sun.light_color = Color(1.0, 0.82, 0.62, 1.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.rotation_degrees = Vector3(-68.0, 142.0, 0.0)
	fill.light_color = Color(0.42, 0.57, 0.78, 1.0)
	fill.light_energy = 0.28
	fill.shadow_enabled = false
	add_child(fill)

	create_region_label("THE VANISHED VILLAGE", Vector3(0, 8.5, 66), 72, Color(0.94, 0.84, 0.64, 1.0))
	create_region_label("CHURCH OF ANGELS", Vector3(0, 18.0, -78), 54, Color(1.0, 0.78, 0.28, 1.0))


func build_arrival_hollow() -> void:
	create_static_box("ArrivalGround", Vector3(0, -0.5, 56), Vector3(34, 1, 32), palette["grass"])
	create_static_box("ArrivalEarth", Vector3(0, -2.0, 56), Vector3(38, 3, 36), palette["earth"])
	create_static_box("ArrivalBackCliff", Vector3(0, 4.0, 73), Vector3(42, 10, 3), palette["stone_dark"])
	create_static_box("ArrivalLeftCliff", Vector3(-19, 3.0, 55), Vector3(4, 8, 38), palette["stone_dark"])
	create_static_box("ArrivalRightCliff", Vector3(19, 3.0, 55), Vector3(4, 8, 38), palette["stone_dark"])

	create_crater(Vector3(0, 0.04, 59), 6.2)
	create_stair_run(Vector3(0, 0.0, 38), Vector3(10, 0.45, 2.2), 8, Vector3(0, 0.28, -2.2), palette["stone_warm"])

	for tree_data: Dictionary in [
		{"p": Vector3(-13, 0, 63), "s": 1.1},
		{"p": Vector3(13, 0, 64), "s": 0.95},
		{"p": Vector3(-15, 0, 47), "s": 0.85},
		{"p": Vector3(15, 0, 45), "s": 1.15},
	]:
		create_tree(tree_data["p"], float(tree_data["s"]))

	create_broken_cart(Vector3(-7, 0.6, 48), -18.0)
	create_ruin_foundation(Vector3(8, 0.2, 47), Vector3(9, 0.35, 7), 10.0)


func build_outer_ruins() -> void:
	create_static_box("OuterVillageGround", Vector3(0, 2.5, 22), Vector3(46, 1, 38), palette["grass"])
	create_static_box("OuterVillageEarth", Vector3(0, 0.0, 22), Vector3(50, 5, 42), palette["earth"])

	create_ruin_house(Vector3(-12, 3.05, 28), Vector3(9, 0.4, 11), 18.0, true)
	create_ruin_house(Vector3(12, 3.05, 26), Vector3(10, 0.4, 9), -12.0, false)
	create_ruin_house(Vector3(-15, 3.05, 10), Vector3(8, 0.4, 8), -8.0, false)
	create_ruin_house(Vector3(15, 3.05, 11), Vector3(9, 0.4, 10), 7.0, true)

	create_displaced_foundation(Vector3(-6, 4.3, 17), 14.0)
	create_empty_hearth(Vector3(8, 3.25, 14))
	create_dry_well(Vector3(0, 3.1, 28))

	for position: Vector3 in [
		Vector3(-21, 3.0, 34), Vector3(21, 3.0, 33),
		Vector3(-22, 3.0, 17), Vector3(22, 3.0, 16),
		Vector3(-20, 3.0, 5), Vector3(20, 3.0, 3),
	]:
		create_tree(position, 0.72 + abs(position.z) * 0.006)

	create_road_segment(Vector3(0, 3.04, 20), Vector3(6.5, 0.12, 32), 0.0)


func build_village_square() -> void:
	create_static_box("VillageSquare", Vector3(0, 2.55, -1), Vector3(44, 1.1, 26), palette["stone_warm"])
	create_static_box("VillageSquareEarth", Vector3(0, 0.2, -1), Vector3(48, 5, 30), palette["earth"])
	create_road_segment(Vector3(0, 3.15, -1), Vector3(18, 0.14, 18), 0.0)

	create_dry_well(Vector3(0, 3.25, 2), 1.35)
	create_market_stall(Vector3(-9, 3.1, -2), 12.0)
	create_market_stall(Vector3(9, 3.1, 0), -10.0)
	create_broken_cart(Vector3(6, 3.65, -7), 34.0)
	create_fallen_statue(Vector3(-4, 3.5, -7), -22.0)

	for rubble_position: Vector3 in [
		Vector3(-15, 3.4, 5), Vector3(14, 3.35, 5),
		Vector3(-13, 3.3, -8), Vector3(13, 3.35, -8),
		Vector3(-6, 3.3, 7), Vector3(7, 3.3, 8),
	]:
		create_rubble_cluster(rubble_position, 0.8)


func build_ravine_routes() -> void:
	create_static_box("RavineVoid", Vector3(0, -7.0, -25), Vector3(52, 1, 30), palette["void"], false)
	create_static_box("NearRavineLip", Vector3(0, 2.2, -12), Vector3(46, 2.5, 4), palette["stone_dark"])
	create_static_box("FarRavineLip", Vector3(0, 5.1, -38), Vector3(46, 4.5, 5), palette["stone_dark"])
	create_static_box("FarRouteLanding", Vector3(0, 5.5, -43), Vector3(44, 1, 12), palette["grass"])
	create_static_box("FarRouteEarth", Vector3(0, 2.0, -43), Vector3(48, 7, 16), palette["earth"])

	# Right lane exists physically but is blocked by a two-solution debris gate.
	create_static_box("RightRavineBridge", Vector3(10, 2.65, -25), Vector3(6, 0.65, 26), palette["stone"])
	create_static_box("RightBridgeRailLeft", Vector3(7.3, 3.5, -25), Vector3(0.35, 1.7, 26), palette["stone_dark"])
	create_static_box("RightBridgeRailRight", Vector3(12.7, 3.5, -25), Vector3(0.35, 1.7, 26), palette["stone_dark"])

	# Left lane is created by Water followed by Ice.
	create_static_box("LeftNearPlatform", Vector3(-10, 2.6, -14), Vector3(8, 0.8, 6), palette["stone"])
	create_static_box("LeftFarPlatform", Vector3(-10, 5.25, -37), Vector3(8, 1.2, 7), palette["stone"])

	create_stair_run(Vector3(10, 3.0, -40), Vector3(6, 0.45, 2.0), 7, Vector3(0, 0.42, -1.55), palette["stone_warm"])
	create_stair_run(Vector3(-10, 3.05, -39), Vector3(6, 0.45, 1.8), 7, Vector3(0, 0.4, -1.5), palette["stone_warm"])

	create_encounter_barrier(Vector3(0, 3.1, -11.0))
	create_elemental_debris_gate(Vector3(10, 3.35, -24.5))
	create_ice_bridge(Vector3(-10, 3.05, -25.5))

	for side: float in [-1.0, 1.0]:
		create_cliff_teeth(Vector3(side * 22.5, 0.5, -25), side)


func build_church_approach() -> void:
	create_static_box("ChurchGround", Vector3(0, 7.5, -60), Vector3(46, 1, 34), palette["grass"])
	create_static_box("ChurchHill", Vector3(0, 3.0, -60), Vector3(52, 9, 40), palette["earth"])
	create_stair_run(Vector3(0, 6.0, -48), Vector3(12, 0.5, 2.0), 8, Vector3(0, 0.26, -1.7), palette["stone_warm"])
	create_road_segment(Vector3(0, 8.05, -57), Vector3(11, 0.15, 20), 0.0)

	create_church_facade(Vector3(0, 8.0, -71))
	create_church_tower(Vector3(-10, 8.0, -72), 17.0)
	create_church_tower(Vector3(10, 8.0, -72), 17.0)

	for position: Vector3 in [
		Vector3(-18, 8.0, -50), Vector3(18, 8.0, -50),
		Vector3(-19, 8.0, -61), Vector3(19, 8.0, -61),
	]:
		create_cypress(position, 1.05)

	create_grave_marker(Vector3(-14, 8.1, -58), -8.0)
	create_grave_marker(Vector3(14, 8.1, -57), 12.0)
	create_grave_marker(Vector3(-16, 8.1, -64), 4.0)
	create_grave_marker(Vector3(16, 8.1, -64), -6.0)


func build_interactions() -> void:
	create_clue(
		"ArrivalCraterClue",
		Vector3(2.8, 0.5, 58.0),
		"arrival_crater",
		"The soil is fused into a perfect ring around Grace, but the grass outside it bends toward the crater instead of away from it.",
		"Follow the road into the vanished village.",
		"inspected_arrival_crater",
		Color(0.88, 0.46, 0.22, 1.0)
	)
	create_clue(
		"LiftedFoundationClue",
		Vector3(-6.0, 4.0, 17.0),
		"lifted_foundation",
		"The house foundation ends in a clean vertical wall of soil. No collapse made this edge. The missing half was lifted away intact.",
		"Search the village square for another sign of what happened.",
		"inspected_lifted_foundation",
		Color(0.68, 0.82, 0.42, 1.0)
	)
	create_clue(
		"EmptyHearthClue",
		Vector3(8.0, 3.8, 14.0),
		"empty_hearth",
		"Ash still lies inside the hearth, yet the room around it is gone. A spoon rests at the edge as though dinner simply stopped.",
		"Reach the village square beneath the church.",
		"inspected_empty_hearth",
		Color(0.94, 0.66, 0.3, 1.0)
	)
	create_memory_relic(Vector3(-10.5, 3.7, 4.8))


func build_encounter() -> void:
	var controller: Node3D = Node3D.new()
	controller.name = "VillageSquareEncounter"
	controller.set_script(EncounterControllerScript)
	controller.set("definition", VillageEncounter)
	controller.set("activate_on_ready", false)
	controller.set("reward_group_name", "encounter_reward")
	controller.position = Vector3(0, 3.1, -1.0)
	encounter_root.add_child(controller)

	create_region_label("VILLAGE SQUARE", Vector3(0, 8.0, 6), 38, Color(0.9, 0.76, 0.52, 1.0))


func build_checkpoint_and_exit() -> void:
	var save_bed: Node = SaveBedScene.instantiate()
	save_bed.name = "ChurchGroundsCheckpoint"
	save_bed.set("bed_id", "ruined_village_church_checkpoint")
	save_bed.set("bed_display_name", "Church Grounds Camp")
	save_bed.set("sleep_objective_after", "Enter the Church of Angels and face its trial.")
	if save_bed is Node3D:
		(save_bed as Node3D).position = Vector3(-6.0, 8.55, -54.0)
	interaction_root.add_child(save_bed)

	var level_exit: Node = LevelExitScene.instantiate()
	level_exit.name = "ChurchTrialEntrance"
	level_exit.set("prompt_text", "Enter the Church Trial")
	level_exit.set("completion_message", "Grace crosses the threshold into the Church of Angels.")
	level_exit.set("objective_after", "Complete the Church Trial.")
	level_exit.set("next_scene_path", CHURCH_TRIAL_SCENE)
	level_exit.set("triggers_on_touch", false)
	if level_exit is Node3D:
		(level_exit as Node3D).position = Vector3(0, 9.0, -66.5)
	interaction_root.add_child(level_exit)


func build_optional_weapon_cache() -> void:
	create_weapon_rack(Vector3(-5.0, 0.8, 49.0), PracticeSword, "Abandoned Sword")
	create_weapon_rack(Vector3(0.0, 0.8, 48.0), TrainingHammer, "Mason's Hammer")
	create_weapon_rack(Vector3(5.0, 0.8, 49.0), TrainingSpear, "Militia Spear")
	create_region_label("ABANDONED ARMORY", Vector3(0, 3.3, 50.5), 28, Color(0.82, 0.66, 0.4, 1.0))


func create_weapon_rack(position_value: Vector3, weapon: WeaponDefinition, label_text: String) -> void:
	var rack: Node = WeaponRackScene.instantiate()
	rack.name = label_text.replace(" ", "") + "Rack"
	rack.set("weapon", weapon)
	rack.set("prompt_text", "Equip " + label_text)
	if rack is Node3D:
		(rack as Node3D).position = position_value
	interaction_root.add_child(rack)


func create_clue(
	node_name: String,
	position_value: Vector3,
	clue_id: String,
	message: String,
	objective: String,
	flag_name: String,
	accent: Color
) -> void:
	var clue: Area3D = Area3D.new()
	clue.name = node_name
	clue.set_script(VillageClueScript)
	clue.set("clue_id", clue_id)
	clue.set("clue_message", message)
	clue.set("objective_after", objective)
	clue.set("story_flag", flag_name)
	clue.set("prompt_text", "Inspect")
	clue.position = position_value

	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var sphere_shape: SphereShape3D = SphereShape3D.new()
	sphere_shape.radius = 1.4
	collision.shape = sphere_shape
	clue.add_child(collision)

	var marker: MeshInstance3D = MeshInstance3D.new()
	marker.name = "ClueMarker"
	var marker_mesh: CylinderMesh = CylinderMesh.new()
	marker_mesh.top_radius = 0.32
	marker_mesh.bottom_radius = 0.52
	marker_mesh.height = 0.18
	marker.mesh = marker_mesh
	marker.position.y = 0.08
	marker.material_override = make_emissive_material(accent, 0.8)
	clue.add_child(marker)

	var label: Label3D = make_label("INSPECT", Vector3(0, 1.25, 0), 26, accent)
	clue.add_child(label)
	interaction_root.add_child(clue)


func create_memory_relic(position_value: Vector3) -> void:
	var relic: Area3D = Area3D.new()
	relic.name = "HiddenWoodenBirdMemory"
	relic.set_script(VillageMemoryRelicScript)
	relic.position = position_value

	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var sphere_shape: SphereShape3D = SphereShape3D.new()
	sphere_shape.radius = 1.5
	collision.shape = sphere_shape
	relic.add_child(collision)

	var bird_root: Node3D = Node3D.new()
	bird_root.name = "MemoryVisual"
	relic.add_child(bird_root)
	add_box_mesh(bird_root, "Body", Vector3(0.6, 0.25, 0.22), Vector3.ZERO, palette["memory"])
	add_box_mesh(bird_root, "LeftWing", Vector3(0.45, 0.08, 0.28), Vector3(-0.38, 0.08, 0), palette["wood_light"], Vector3(0, 0, 18))
	add_box_mesh(bird_root, "RightWing", Vector3(0.45, 0.08, 0.28), Vector3(0.38, 0.08, 0), palette["wood_light"], Vector3(0, 0, -18))
	add_sphere_mesh(bird_root, "Head", 0.18, Vector3(0, 0.18, -0.2), palette["memory"])

	var status_receiver: Node = Node.new()
	status_receiver.name = "StatusReceiver"
	status_receiver.set_script(StatusReceiverScript)
	relic.add_child(status_receiver)

	var revealable: Node = Node.new()
	revealable.name = "RevealableReceiver"
	revealable.set_script(RevealableReceiverScript)
	revealable.set("starts_hidden", true)
	revealable.set("reveal_duration_override", 0.0)
	revealable.set("reveal_message", "Sound outlines a tiny wooden bird buried in the square.")
	relic.add_child(revealable)

	var label: Label3D = make_label("SOUND MEMORY", Vector3(0, 1.35, 0), 24, Color(0.96, 0.76, 0.28, 1.0))
	bird_root.add_child(label)
	interaction_root.add_child(relic)


func create_encounter_barrier(position_value: Vector3) -> void:
	var gate: StaticBody3D = create_route_gate_base("SquareEncounterBarrier", position_value, Vector3(31, 3.2, 2.2))
	gate.set("gate_id", "square_encounter_barrier")
	gate.set("display_name", "Scavenger Barricade")
	gate.set("accepts_fire", false)
	gate.set("accepts_ice_force_combo", false)
	gate.set("completion_flag", "opened_square_barrier")
	gate.set("objective_after", "Find a route across the collapsed ravine.")
	gate.set("locked_message", "The barricade is reinforced from the far side. Deal with the scavengers first.")
	gate.add_to_group("encounter_reward")


func create_elemental_debris_gate(position_value: Vector3) -> void:
	var gate: StaticBody3D = create_route_gate_base("RavineDebrisGate", position_value, Vector3(5.4, 3.0, 2.4))
	gate.set("gate_id", "ravine_debris_gate")
	gate.set("display_name", "Root-Choked Debris")
	gate.set("accepts_fire", true)
	gate.set("accepts_ice_force_combo", true)
	gate.set("completion_flag", "opened_ravine_debris")
	gate.set("objective_after", "Cross the stone bridge and climb toward the church.")
	gate.set("fire_message", "Fire races through the dry roots and clears the stone bridge.")
	gate.set("freeze_message", "Ice binds the loose rubble together. A Heavy or forceful hit could shatter it.")
	gate.set("shatter_message", "The frozen debris fractures and tumbles into the ravine.")
	var label: Label3D = make_label("FIRE  OR  ICE + HEAVY", Vector3(0, 2.35, 0), 24, Color(1.0, 0.72, 0.32, 1.0))
	gate.add_child(label)


func create_route_gate_base(node_name: String, position_value: Vector3, size: Vector3) -> StaticBody3D:
	var gate: StaticBody3D = StaticBody3D.new()
	gate.name = node_name
	gate.set_script(VillageRouteGateScript)
	gate.position = position_value

	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position.y = size.y * 0.5
	gate.add_child(collision)

	var visual_root: Node3D = Node3D.new()
	visual_root.name = "VisualRoot"
	gate.add_child(visual_root)

	for index: int in range(8):
		var x: float = lerpf(-size.x * 0.42, size.x * 0.42, float(index) / 7.0)
		var height: float = 1.2 + float((index * 7) % 4) * 0.42
		add_box_mesh(
			visual_root,
			"Debris" + str(index),
			Vector3(max(size.x / 9.0, 0.7), height, size.z * 0.8),
			Vector3(x, height * 0.5, 0),
			palette["wood" if index % 3 == 0 else "stone"],
			Vector3(0, float(index * 13) - 35.0, float(index % 2) * 9.0)
		)

	puzzle_root.add_child(gate)
	return gate


func create_ice_bridge(position_value: Vector3) -> void:
	var bridge: StaticBody3D = StaticBody3D.new()
	bridge.name = "WaterIceRavineBridge"
	bridge.set_script(VillageIceBridgeScript)
	bridge.set("bridge_id", "village_ravine_ice_bridge")
	bridge.set("completion_flag", "froze_village_bridge")
	bridge.set("objective_after", "Cross the frozen path and climb toward the church.")
	bridge.position = position_value

	var target_collision: CollisionShape3D = CollisionShape3D.new()
	target_collision.name = "TargetCollision"
	var target_shape: BoxShape3D = BoxShape3D.new()
	target_shape.size = Vector3(6.5, 1.1, 24.0)
	target_collision.shape = target_shape
	target_collision.position.y = -0.15
	bridge.add_child(target_collision)

	var bridge_collision: CollisionShape3D = CollisionShape3D.new()
	bridge_collision.name = "BridgeCollision"
	var crossing_shape: BoxShape3D = BoxShape3D.new()
	crossing_shape.size = Vector3(6.0, 0.55, 24.0)
	bridge_collision.shape = crossing_shape
	bridge_collision.position.y = 0.0
	bridge_collision.disabled = true
	bridge.add_child(bridge_collision)

	var water_visual: MeshInstance3D = create_box_mesh_instance(Vector3(6.0, 0.14, 24.0), palette["water"])
	water_visual.name = "WaterVisual"
	water_visual.position.y = 0.0
	bridge.add_child(water_visual)

	var ice_visual: MeshInstance3D = create_box_mesh_instance(Vector3(6.0, 0.48, 24.0), palette["ice"])
	ice_visual.name = "IceVisual"
	ice_visual.position.y = 0.08
	ice_visual.visible = false
	bridge.add_child(ice_visual)

	for index: int in range(9):
		var shard: MeshInstance3D = create_box_mesh_instance(Vector3(0.12, 0.16, 2.0), palette["ice"])
		shard.name = "IceVein" + str(index)
		shard.position = Vector3(-2.4 + float(index % 3) * 2.4, 0.34, -9.0 + float(index / 3) * 8.5)
		shard.rotation_degrees.y = float(index * 21)
		ice_visual.add_child(shard)

	var status_receiver: Node = Node.new()
	status_receiver.name = "StatusReceiver"
	status_receiver.set_script(StatusReceiverScript)
	bridge.add_child(status_receiver)

	var payload_receiver: Node = Node.new()
	payload_receiver.name = "PayloadReceiver"
	payload_receiver.set_script(PayloadReceiverScript)
	bridge.add_child(payload_receiver)

	var label: Label3D = make_label("WATER  →  ICE", Vector3(0, 1.7, 9.2), 26, Color(0.56, 0.9, 1.0, 1.0))
	bridge.add_child(label)
	puzzle_root.add_child(bridge)


func reset_village_for_test() -> void:
	reset_in_progress = true
	Engine.time_scale = 1.0
	for flag_name: String in TEST_FLAGS:
		GameState.set_flag(flag_name, false)
	GameState.restore_rest_resources()
	GameState.set_objective(ARRIVAL_OBJECTIVE)
	get_tree().reload_current_scene()


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func create_static_box(
	node_name: String,
	position_value: Vector3,
	size: Vector3,
	material: Material,
	with_collision: bool = true,
	rotation_value: Vector3 = Vector3.ZERO
) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.rotation_degrees = rotation_value

	if with_collision:
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)

	var mesh_instance: MeshInstance3D = create_box_mesh_instance(size, material)
	mesh_instance.name = node_name + "Mesh"
	body.add_child(mesh_instance)
	geometry_root.add_child(body)
	return body


func create_box_mesh_instance(size: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	return mesh_instance


func add_box_mesh(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	position_value: Vector3,
	material: Material,
	rotation_value: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = create_box_mesh_instance(size, material)
	mesh_instance.name = node_name
	mesh_instance.position = position_value
	mesh_instance.rotation_degrees = rotation_value
	parent.add_child(mesh_instance)
	return mesh_instance


func add_sphere_mesh(parent: Node3D, node_name: String, radius: float, position_value: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 8
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = position_value
	parent.add_child(mesh_instance)
	return mesh_instance


func add_cylinder_mesh(
	parent: Node3D,
	node_name: String,
	radius: float,
	height: float,
	position_value: Vector3,
	material: Material,
	top_radius: float = -1.0
) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = position_value
	parent.add_child(mesh_instance)
	return mesh_instance


func create_stair_run(
	start_position: Vector3,
	step_size: Vector3,
	count: int,
	step_offset: Vector3,
	material: Material
) -> void:
	for index: int in range(count):
		var position_value: Vector3 = start_position + step_offset * float(index)
		create_static_box(
			"Stair" + str(start_position.z) + "_" + str(index),
			position_value,
			step_size,
			material
		)


func create_road_segment(position_value: Vector3, size: Vector3, rotation_y: float) -> void:
	create_static_box(
		"RoadSegment" + str(detail_root.get_child_count()),
		position_value,
		size,
		palette["stone"],
		false,
		Vector3(0, rotation_y, 0)
	)


func create_crater(position_value: Vector3, radius: float) -> void:
	for index: int in range(18):
		var angle: float = TAU * float(index) / 18.0
		var rock_position: Vector3 = position_value + Vector3(cos(angle) * radius, 0.18, sin(angle) * radius)
		var rock_size: Vector3 = Vector3(1.2, 0.5 + float(index % 3) * 0.18, 0.8)
		create_static_box("CraterRock" + str(index), rock_position, rock_size, palette["stone_dark"], true, Vector3(0, rad_to_deg(-angle), float(index % 2) * 8.0))
	create_static_box("CraterCenter", position_value + Vector3(0, -0.18, 0), Vector3(radius * 1.35, 0.25, radius * 1.35), palette["earth"], false)


func create_ruin_foundation(position_value: Vector3, size: Vector3, rotation_y: float) -> void:
	create_static_box("Foundation" + str(detail_root.get_child_count()), position_value, size, palette["stone_warm"], true, Vector3(0, rotation_y, 0))


func create_ruin_house(position_value: Vector3, foundation_size: Vector3, rotation_y: float, tall_wall: bool) -> void:
	var root: Node3D = Node3D.new()
	root.name = "RuinedHouse" + str(detail_root.get_child_count())
	root.position = position_value
	root.rotation_degrees.y = rotation_y
	detail_root.add_child(root)

	add_box_mesh(root, "Foundation", foundation_size, Vector3.ZERO, palette["stone_warm"])
	add_box_mesh(root, "BackWall", Vector3(foundation_size.x, 2.8 if tall_wall else 1.8, 0.35), Vector3(0, 1.4 if tall_wall else 0.9, -foundation_size.z * 0.45), palette["plaster"])
	add_box_mesh(root, "SideWall", Vector3(0.35, 1.8, foundation_size.z * 0.8), Vector3(-foundation_size.x * 0.44, 0.9, 0), palette["stone"])
	add_box_mesh(root, "Beam", Vector3(foundation_size.x * 0.8, 0.18, 0.18), Vector3(0.4, 2.2, -foundation_size.z * 0.35), palette["wood"], Vector3(0, 0, 11))

	create_static_box(root.name + "CollisionFoundation", position_value, foundation_size, palette["stone_warm"], true, Vector3(0, rotation_y, 0))


func create_displaced_foundation(position_value: Vector3, rotation_y: float) -> void:
	var root: Node3D = Node3D.new()
	root.name = "DisplacedFoundation"
	root.position = position_value
	root.rotation_degrees.y = rotation_y
	detail_root.add_child(root)
	add_box_mesh(root, "FloorHalf", Vector3(7, 0.35, 5), Vector3(-1.5, 0, 0), palette["stone_warm"])
	add_box_mesh(root, "CutSoil", Vector3(0.4, 2.8, 5), Vector3(2.05, -1.25, 0), palette["earth"])
	add_box_mesh(root, "WallStub", Vector3(5.5, 1.7, 0.32), Vector3(-1.2, 0.95, -2.25), palette["plaster"])


func create_empty_hearth(position_value: Vector3) -> void:
	var root: Node3D = Node3D.new()
	root.name = "EmptyHearth"
	root.position = position_value
	detail_root.add_child(root)
	add_box_mesh(root, "Base", Vector3(2.0, 0.4, 1.5), Vector3(0, 0.2, 0), palette["stone_dark"])
	add_box_mesh(root, "Back", Vector3(2.0, 1.8, 0.35), Vector3(0, 1.0, -0.58), palette["stone"])
	add_box_mesh(root, "Left", Vector3(0.35, 1.2, 1.2), Vector3(-0.82, 0.7, 0), palette["stone"])
	add_box_mesh(root, "Right", Vector3(0.35, 1.2, 1.2), Vector3(0.82, 0.7, 0), palette["stone"])
	add_box_mesh(root, "Spoon", Vector3(0.08, 0.05, 0.8), Vector3(0.45, 0.48, 0.15), palette["gold"], Vector3(0, 28, 0))


func create_dry_well(position_value: Vector3, scale_value: float = 1.0) -> void:
	var root: Node3D = Node3D.new()
	root.name = "DryWell" + str(detail_root.get_child_count())
	root.position = position_value
	root.scale = Vector3.ONE * scale_value
	detail_root.add_child(root)

	for index: int in range(12):
		var angle: float = TAU * float(index) / 12.0
		add_box_mesh(
			root,
			"WellStone" + str(index),
			Vector3(0.72, 0.55, 0.45),
			Vector3(cos(angle) * 1.2, 0.28, sin(angle) * 1.2),
			palette["stone"],
			Vector3(0, -rad_to_deg(angle), 0)
		)
	add_box_mesh(root, "CrossBeam", Vector3(3.3, 0.18, 0.18), Vector3(0, 2.5, 0), palette["wood"])
	add_box_mesh(root, "LeftPost", Vector3(0.18, 2.8, 0.18), Vector3(-1.45, 1.4, 0), palette["wood"])
	add_box_mesh(root, "RightPost", Vector3(0.18, 2.8, 0.18), Vector3(1.45, 1.4, 0), palette["wood"])


func create_market_stall(position_value: Vector3, rotation_y: float) -> void:
	var root: Node3D = Node3D.new()
	root.name = "CollapsedMarketStall" + str(detail_root.get_child_count())
	root.position = position_value
	root.rotation_degrees.y = rotation_y
	detail_root.add_child(root)
	add_box_mesh(root, "Table", Vector3(3.2, 0.18, 1.5), Vector3(0, 1.0, 0), palette["wood_light"], Vector3(0, 0, 4))
	add_box_mesh(root, "PostA", Vector3(0.16, 2.5, 0.16), Vector3(-1.35, 1.2, -0.55), palette["wood"], Vector3(0, 0, -12))
	add_box_mesh(root, "PostB", Vector3(0.16, 2.0, 0.16), Vector3(1.35, 0.95, 0.55), palette["wood"], Vector3(0, 0, 24))
	add_box_mesh(root, "Canopy", Vector3(3.6, 0.12, 2.2), Vector3(0.2, 2.15, 0), palette["plaster"], Vector3(8, 0, 16))


func create_broken_cart(position_value: Vector3, rotation_y: float) -> void:
	var root: Node3D = Node3D.new()
	root.name = "BrokenCart" + str(detail_root.get_child_count())
	root.position = position_value
	root.rotation_degrees.y = rotation_y
	detail_root.add_child(root)
	add_box_mesh(root, "CartBed", Vector3(2.8, 0.28, 1.6), Vector3(0, 0.8, 0), palette["wood_light"], Vector3(0, 0, 8))
	add_box_mesh(root, "Axle", Vector3(3.1, 0.16, 0.16), Vector3(0, 0.55, 0), palette["wood"])
	for x_value: float in [-1.35, 1.35]:
		var wheel: MeshInstance3D = add_cylinder_mesh(root, "Wheel", 0.65, 0.16, Vector3(x_value, 0.55, 0), palette["wood"])
		wheel.rotation_degrees.z = 90.0
	add_box_mesh(root, "Shaft", Vector3(0.16, 0.16, 3.5), Vector3(0.4, 0.65, -2.0), palette["wood"], Vector3(0, 10, 0))


func create_fallen_statue(position_value: Vector3, rotation_y: float) -> void:
	var root: Node3D = Node3D.new()
	root.name = "FallenAngelStatue"
	root.position = position_value
	root.rotation_degrees = Vector3(72, rotation_y, 18)
	detail_root.add_child(root)
	add_cylinder_mesh(root, "Body", 0.42, 2.8, Vector3(0, 1.4, 0), palette["stone"], 0.3)
	add_sphere_mesh(root, "Head", 0.42, Vector3(0, 3.0, 0), palette["stone"])
	add_box_mesh(root, "WingLeft", Vector3(1.7, 0.16, 0.7), Vector3(-0.95, 2.0, 0), palette["stone"], Vector3(0, 0, -28))
	add_box_mesh(root, "WingRight", Vector3(1.7, 0.16, 0.7), Vector3(0.95, 2.0, 0), palette["stone"], Vector3(0, 0, 28))


func create_rubble_cluster(position_value: Vector3, scale_value: float) -> void:
	var root: Node3D = Node3D.new()
	root.name = "RubbleCluster" + str(detail_root.get_child_count())
	root.position = position_value
	detail_root.add_child(root)
	for index: int in range(6):
		var offset: Vector3 = Vector3(float((index * 7) % 5) - 2.0, float(index % 2) * 0.25, float((index * 3) % 5) - 2.0) * 0.42 * scale_value
		add_box_mesh(root, "Stone" + str(index), Vector3(0.6, 0.4, 0.8) * scale_value, offset, palette["stone"], Vector3(index * 11, index * 19, index * 7))


func create_tree(position_value: Vector3, scale_value: float) -> void:
	var root: Node3D = Node3D.new()
	root.name = "OliveTree" + str(detail_root.get_child_count())
	root.position = position_value
	root.scale = Vector3.ONE * scale_value
	detail_root.add_child(root)
	add_cylinder_mesh(root, "Trunk", 0.34, 4.2, Vector3(0, 2.1, 0), palette["wood"], 0.24)
	add_sphere_mesh(root, "CrownA", 1.55, Vector3(-0.7, 4.2, 0), palette["leaf"])
	add_sphere_mesh(root, "CrownB", 1.35, Vector3(0.8, 4.5, 0.25), palette["leaf_light"])
	add_sphere_mesh(root, "CrownC", 1.25, Vector3(0, 5.2, -0.35), palette["leaf"])


func create_cypress(position_value: Vector3, scale_value: float) -> void:
	var root: Node3D = Node3D.new()
	root.name = "Cypress" + str(detail_root.get_child_count())
	root.position = position_value
	root.scale = Vector3.ONE * scale_value
	detail_root.add_child(root)
	add_cylinder_mesh(root, "Trunk", 0.24, 4.8, Vector3(0, 2.4, 0), palette["wood"], 0.18)
	add_cylinder_mesh(root, "Crown", 1.0, 7.5, Vector3(0, 5.4, 0), palette["leaf"], 0.08)


func create_cliff_teeth(position_value: Vector3, side: float) -> void:
	for index: int in range(7):
		var y_offset: float = float(index % 3) * 0.7
		create_static_box(
			"RavineCliff" + str(side) + "_" + str(index),
			position_value + Vector3(side * float(index) * 1.1, y_offset, float(index - 3) * 4.0),
			Vector3(3.5, 8.0 + y_offset, 5.0),
			palette["stone_dark"]
		)


func create_church_facade(position_value: Vector3) -> void:
	var root: Node3D = Node3D.new()
	root.name = "ChurchFacade"
	root.position = position_value
	detail_root.add_child(root)
	add_box_mesh(root, "Nave", Vector3(19, 12, 8), Vector3(0, 6, 0), palette["plaster"])
	add_box_mesh(root, "StoneBase", Vector3(21, 2.2, 9), Vector3(0, 1.1, 0), palette["stone_warm"])
	add_box_mesh(root, "Door", Vector3(4.2, 7.5, 0.5), Vector3(0, 3.75, 4.15), palette["wood"])
	add_box_mesh(root, "DoorGlow", Vector3(3.6, 6.8, 0.12), Vector3(0, 3.7, 4.48), palette["gold"])
	add_box_mesh(root, "Lintel", Vector3(7.0, 0.7, 0.8), Vector3(0, 7.7, 4.0), palette["stone"])
	add_sphere_mesh(root, "RoseWindow", 1.65, Vector3(0, 9.3, 4.18), palette["gold"])


func create_church_tower(position_value: Vector3, height: float) -> void:
	var root: Node3D = Node3D.new()
	root.name = "ChurchTower" + str(detail_root.get_child_count())
	root.position = position_value
	detail_root.add_child(root)
	add_box_mesh(root, "Tower", Vector3(7.0, height, 7.0), Vector3(0, height * 0.5, 0), palette["stone_warm"])
	add_cylinder_mesh(root, "Roof", 5.0, 6.0, Vector3(0, height + 3.0, 0), palette["stone_dark"], 0.0)
	add_box_mesh(root, "BellOpening", Vector3(2.0, 3.0, 0.2), Vector3(0, height - 3.0, 3.6), palette["void"])


func create_grave_marker(position_value: Vector3, rotation_y: float) -> void:
	var root: Node3D = Node3D.new()
	root.name = "GraveMarker" + str(detail_root.get_child_count())
	root.position = position_value
	root.rotation_degrees.y = rotation_y
	detail_root.add_child(root)
	add_box_mesh(root, "Stone", Vector3(0.8, 1.5, 0.25), Vector3(0, 0.75, 0), palette["stone"])
	add_box_mesh(root, "Crossbar", Vector3(1.2, 0.25, 0.28), Vector3(0, 1.05, 0), palette["stone"])


func create_region_label(text: String, position_value: Vector3, font_size: int, color: Color) -> void:
	var label: Label3D = make_label(text, position_value, font_size, color)
	label.name = text.replace(" ", "") + "Label"
	add_child(label)


func make_label(text: String, position_value: Vector3, font_size: int, color: Color) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = text
	label.position = position_value
	label.font_size = font_size
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 7
	label.modulate = color
	return label


func make_material(color: Color, metallic: float, roughness: float, transparent: bool = false) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if transparent or color.a < 0.999:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func make_emissive_material(color: Color, energy: float, transparent: bool = false) -> StandardMaterial3D:
	var material: StandardMaterial3D = make_material(color, 0.18, 0.32, transparent)
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = energy
	return material


func get_debug_data() -> Dictionary:
	return {
		"level": "ruined_village_approach",
		"geometry": geometry_root.get_child_count() if geometry_root != null else 0,
		"details": detail_root.get_child_count() if detail_root != null else 0,
		"clues": get_tree().get_nodes_in_group("village_clue").size(),
		"encounters": get_tree().get_nodes_in_group("encounter_controller").size(),
		"objective": GameState.current_objective,
	}
