extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const SurfAbility: AbilityDefinition = preload(
	"res://data/abilities/surf_ability.tres"
)
const SurfaceHazardScript = preload(
	"res://scripts/hazards/surface_hazard_area.gd"
)

var failures: Array[String] = []
var original_stats: Dictionary = {}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	_prepare_stats()
	_test_ability_contract()

	var floor: StaticBody3D = _make_floor()
	add_child(floor)
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "SurfSpellTestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	player.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	add_child(player)
	for _frame: int in range(12):
		await get_tree().process_frame
	await get_tree().physics_frame

	var caster: Node = player.get_node_or_null("AbilityCaster")
	_expect(caster != null, "Surf test resolves AbilityCaster")
	if caster == null:
		_finish([player, floor])
		return
	var surf_index: int = _find_surf_index(caster)
	_expect(surf_index >= 0, "Grace's runtime loadout contains Surf")
	if surf_index < 0:
		_finish([player, floor])
		return

	var spell_effects_before: int = get_tree().get_node_count_in_group("spell_effects")
	var persistent_before: int = get_tree().get_node_count_in_group(
		"persistent_spell_effects"
	)
	var starting_mana: int = GameState.get_stat("mana")
	caster.call("select_ability", surf_index, false)
	var cast_result: bool = bool(
		caster.call("cast_from_player", player, 0.0, false)
	)
	_expect(cast_result, "Surf casts through the ordinary AbilityCaster path")
	_expect(
		GameState.get_stat("mana") == starting_mana - SurfAbility.mana_cost,
		"Surf spends its authored upfront Mana cost"
	)

	var controller: PlayerSurfController = player.get_node_or_null(
		"SurfController"
	) as PlayerSurfController
	_expect(controller != null, "Surf installs one reusable player controller")
	if controller == null:
		_finish([player, floor])
		return
	controller.set_test_input_override(Vector2(0.0, -1.0), true)
	var start_position: Vector3 = player.global_position
	for _frame: int in range(24):
		await get_tree().physics_frame
	var moved_distance: float = start_position.distance_to(player.global_position)
	var active_debug: Dictionary = controller.get_debug_data()
	_expect(controller.is_surf_active(), "Surf remains active while movement input is held")
	_expect(moved_distance > 2.5, "Surf carries Grace forward across the floor")
	_expect(
		float(active_debug.get("speed", 0.0)) > 8.5,
		"Surf accelerates beyond Grace's ordinary running speed"
	)
	_expect(
		not player.is_physics_processing(),
		"Surf temporarily owns root locomotion instead of double-moving Grace"
	)
	_expect(
		get_tree().get_node_count_in_group("spell_effects")
		== spell_effects_before + 1,
		"active Surf registers one spell effect"
	)
	_expect(
		get_tree().get_node_count_in_group("persistent_spell_effects")
		== persistent_before + 1,
		"active Surf registers one persistent effect"
	)
	_expect(
		int(active_debug.get("foam_multimeshes", 0)) == 1
		and int(active_debug.get("foam_segment_nodes", -1)) == 0,
		"Surf foam uses one MultiMesh with no per-segment nodes"
	)

	var direction_before: Vector3 = active_debug.get(
		"direction",
		Vector3.FORWARD
	) as Vector3
	controller.set_test_input_override(Vector2(1.0, 0.0), true)
	for _frame: int in range(6):
		await get_tree().physics_frame
	var direction_after: Vector3 = controller.get_debug_data().get(
		"direction",
		Vector3.FORWARD
	) as Vector3
	var turn_degrees: float = rad_to_deg(direction_before.angle_to(direction_after))
	_expect(turn_degrees > 1.0, "Surf responds to steering input")
	_expect(
		turn_degrees < 20.0,
		"Surf cannot snap through a ninety-degree turn in one tenth of a second"
	)

	var hazard: SurfaceHazardArea = SurfaceHazardScript.new() as SurfaceHazardArea
	hazard.name = "SurfSmokeLava"
	hazard.display_name = "Test Lava"
	hazard.hazard_type = "lava"
	hazard.element = "fire"
	hazard.health_damage = 8
	hazard.stance_damage = 4
	add_child(hazard)
	await get_tree().process_frame
	var health_before_hazard: int = GameState.get_stat("health")
	var protected_result: Dictionary = hazard.apply_hazard_to_body(player)
	_expect(
		bool(protected_result.get("surf", false)),
		"tagged surface hazard resolves through Surf protection"
	)
	_expect(
		GameState.get_stat("health") == health_before_hazard,
		"Surf negates all surface-hazard health damage"
	)
	_expect(
		controller.get_hazard_negation_count() == 1,
		"Surf records the skimmed hazard"
	)

	controller.set_test_input_override(Vector2.ZERO, true)
	for _frame: int in range(30):
		await get_tree().physics_frame
	var inactive_debug: Dictionary = controller.get_debug_data()
	_expect(not controller.is_surf_active(), "idling collapses Surf")
	_expect(
		str(inactive_debug.get("last_end_reason", "")) == "idle",
		"idle cancellation reports its authored reason"
	)
	_expect(player.is_physics_processing(), "ordinary player locomotion resumes after Surf")
	_expect(
		get_tree().get_node_count_in_group("spell_effects") == spell_effects_before,
		"Surf removes its spell-effect group after cancellation"
	)
	_expect(
		get_tree().get_node_count_in_group("persistent_spell_effects")
		== persistent_before,
		"Surf leaves no persistent-effect leak after cancellation"
	)

	var health_before_unprotected: int = GameState.get_stat("health")
	var unprotected_result: Dictionary = hazard.apply_hazard_to_body(player)
	_expect(
		not bool(unprotected_result.get("surf", false)),
		"surface hazards stop being negated after the wave collapses"
	)
	_expect(
		GameState.get_stat("health") < health_before_unprotected,
		"the same surface hazard damages Grace without Surf"
	)

	_finish([player, floor, hazard])


func _test_ability_contract() -> void:
	_expect(SurfAbility.get_spell_id() == "surf", "Surf has a stable spell ID")
	_expect(SurfAbility.element == "water", "Surf belongs to Water")
	_expect(SurfAbility.mana_cost == 3, "Surf costs three Mana")
	_expect(
		SurfAbility.ability_scene != null
		and SurfAbility.ability_scene.resource_path
		== "res://scenes/actions/surf_cast.tscn",
		"Surf uses its dedicated locomotion action"
	)
	_expect(
		SurfAbility.get_delivery_type() == "movement_state",
		"Surf advertises movement-state delivery"
	)
	_expect(
		SurfAbility.get_roles().has("hazard_crossing"),
		"Surf exposes its surface-hazard traversal role"
	)


func _find_surf_index(caster: Node) -> int:
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return -1
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout
	for ability_index: int in range(loadout.get_equipped_ability_count()):
		var ability: AbilityDefinition = loadout.get_equipped_ability(ability_index)
		if ability != null and ability.get_spell_id() == "surf":
			return ability_index
	return -1


func _make_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "SurfSmokeFloor"
	floor.position = Vector3(0.0, -0.1, 8.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(40.0, 0.2, 60.0)
	collision.shape = shape
	floor.add_child(collision)
	return floor


func _prepare_stats() -> void:
	GameState.set_stat("max_health", 100)
	GameState.set_stat("health", 100)
	GameState.set_stat("max_mana", 60)
	GameState.set_stat("mana", 60)
	GameState.set_stat("max_stamina", 40)
	GameState.set_stat("stamina", 40)
	GameState.set_stat("max_stance", 35)
	GameState.set_stat("stance", 35)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("SURF_SPELL_SMOKE_TEST: " + label)


func _restore_state() -> void:
	GameState.stats = original_stats.duplicate(true)
	for stat_value: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_value)
		GameState.stat_changed.emit(stat_id, int(GameState.stats[stat_value]))


func _finish(nodes: Array) -> void:
	Engine.time_scale = 1.0
	_restore_state()
	for node_value: Variant in nodes:
		if node_value is Node and is_instance_valid(node_value as Node):
			(node_value as Node).queue_free()
	if failures.is_empty():
		print("SURF_SPELL_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("SURF_SPELL_SMOKE_TEST: " + failure)
	get_tree().quit(1)
