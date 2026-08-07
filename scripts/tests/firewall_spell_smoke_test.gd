extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const FirewallAbility: AbilityDefinition = preload(
	"res://data/abilities/firewall_ability.tres"
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
	player.name = "FirewallSpellTestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	add_child(player)
	for _frame: int in range(18):
		await get_tree().process_frame
	await get_tree().physics_frame

	var caster: Node = player.get_node_or_null("AbilityCaster")
	_expect(caster != null, "Firewall test resolves AbilityCaster")
	if caster == null:
		_finish([player, floor])
		return
	var firewall_index: int = _find_firewall_index(caster)
	_expect(firewall_index >= 0, "Grace's runtime loadout contains Firewall")
	if firewall_index < 0:
		_finish([player, floor])
		return

	var spell_effects_before: int = get_tree().get_node_count_in_group(
		"spell_effects"
	)
	var persistent_before: int = get_tree().get_node_count_in_group(
		"persistent_spell_effects"
	)
	var starting_mana: int = GameState.get_stat("mana")
	caster.call("select_ability", firewall_index, false)
	var cast_result: bool = bool(
		caster.call("cast_from_player", player, 0.18, false)
	)
	_expect(cast_result, "Firewall casts through the ordinary AbilityCaster path")
	_expect(
		GameState.get_stat("mana") == starting_mana - FirewallAbility.mana_cost,
		"Firewall spends its authored upfront Mana cost"
	)
	var ordinary_cast: FirewallCast = _find_firewall_for_player(player)
	_expect(ordinary_cast != null, "ordinary casting creates one Firewall action")
	if ordinary_cast != null:
		ordinary_cast.set_test_cast_held_override(true, true)
		var ordinary_debug: Dictionary = ordinary_cast.get_debug_data()
		_expect(bool(ordinary_debug.get("drawing", false)), "Firewall begins in drawing phase")
		_expect(
			bool(ordinary_debug.get("owns_cast_channel", false)),
			"Firewall converts the base cast lock into an owned channel"
		)
		_expect(
			bool(ordinary_debug.get("camera_brush_aim", false)),
			"ordinary Firewall drawing enters camera-brush aim"
		)
		ordinary_cast.cancel_drawing("test_cleanup")
		await get_tree().process_frame

	var serial_before: int = int(player.get_meta("firewall_serial", 0))
	var corner_firewall: FirewallCast = _spawn_direct_firewall(player)
	_expect(corner_firewall != null, "test can spawn Firewall's production action scene")
	if corner_firewall == null:
		_finish([player, floor])
		return

	corner_firewall.append_surface_sample_for_test(
		Vector3(0.0, 0.0, -2.0),
		Vector3.UP,
		"Floor"
	)
	corner_firewall.append_surface_sample_for_test(
		Vector3(0.0, 0.0, -0.35),
		Vector3.UP,
		"Floor"
	)
	corner_firewall.append_surface_sample_for_test(
		Vector3(0.0, 1.2, 0.0),
		Vector3.BACK,
		"Wall"
	)
	corner_firewall.append_surface_sample_for_test(
		Vector3(0.0, 3.0, 0.0),
		Vector3.BACK,
		"Wall"
	)
	corner_firewall.append_surface_sample_for_test(
		Vector3(0.0, 3.4, -1.2),
		Vector3.DOWN,
		"Ceiling"
	)
	corner_firewall.finish_drawing_for_test("test_release")
	var corner_debug: Dictionary = corner_firewall.get_debug_data()
	var surface_sequence: Array = corner_debug.get("surface_sequence", []) as Array
	_expect(bool(corner_debug.get("wall_active", false)), "release erupts the drawn path")
	_expect(
		int(corner_debug.get("surface_transitions", 0)) >= 2,
		"floor-to-wall-to-ceiling drawing records both surface transitions"
	)
	_expect(
		surface_sequence.has("floor")
		and surface_sequence.has("wall")
		and surface_sequence.has("ceiling"),
		"Firewall preserves floor, wall, and ceiling surface identities"
	)
	_expect(
		int(corner_debug.get("visual_segment_count", 0)) >= 5,
		"corner smoothing produces a continuous multi-segment wall"
	)
	_expect(
		int(corner_debug.get("contact_segment_count", 0))
		<= int(corner_debug.get("visual_segment_count", 0)),
		"Firewall compresses collinear visual pieces into fewer contact queries"
	)
	_expect(
		int(corner_debug.get("visual_multimeshes", 0)) == 4
		and int(corner_debug.get("per_segment_nodes", -1)) == 0,
		"Firewall renders the complete line through four MultiMeshes and no segment nodes"
	)
	_expect(
		get_tree().get_node_count_in_group("persistent_spell_effects")
		== persistent_before + 1,
		"an ignited Firewall registers exactly one persistent effect"
	)
	_expect(
		int(player.get_meta("firewall_serial", 0)) == serial_before + 1,
		"ignition publishes one Firewall path result"
	)
	var metadata_sequence: Array = player.get_meta(
		"firewall_surface_sequence",
		[]
	) as Array
	_expect(
		metadata_sequence.has("floor")
		and metadata_sequence.has("wall")
		and metadata_sequence.has("ceiling"),
		"published path metadata retains the three-surface sequence"
	)

	for _frame: int in range(8):
		await get_tree().process_frame
	_expect(
		float(corner_firewall.get_debug_data().get("height_ratio", 0.0)) > 0.0,
		"the Firewall rises from the traced surfaces after ignition"
	)
	corner_firewall.finish_firewall("test_cleanup")
	await get_tree().process_frame
	_expect(
		get_tree().get_node_count_in_group("persistent_spell_effects")
		== persistent_before,
		"Firewall cleanup returns persistent effects to baseline"
	)

	var timed_firewall: FirewallCast = _spawn_direct_firewall(player)
	_expect(timed_firewall != null, "time-limit fixture creates another Firewall")
	if timed_firewall != null:
		timed_firewall.append_surface_sample_for_test(
			Vector3(0.0, 0.0, 1.0),
			Vector3.UP,
			"Floor"
		)
		timed_firewall.append_surface_sample_for_test(
			Vector3(2.0, 0.0, 1.0),
			Vector3.UP,
			"Floor"
		)
		timed_firewall.advance_drawing(
			timed_firewall.maximum_draw_seconds + 0.1,
			true
		)
		var timed_debug: Dictionary = timed_firewall.get_debug_data()
		_expect(
			bool(timed_debug.get("wall_active", false)),
			"reaching the draw-time limit automatically ignites the line"
		)
		_expect(
			str(timed_debug.get("last_end_reason", "")) == "time_limit",
			"automatic ignition records the time-limit reason"
		)
		timed_firewall.finish_firewall("test_cleanup")
		await get_tree().process_frame

	var brush_firewall: FirewallCast = _spawn_direct_firewall(player)
	_expect(brush_firewall != null, "adaptive brush fixture creates another Firewall")
	if brush_firewall != null:
		brush_firewall.targeting_range = 30.0
		var brush_origin := Vector3(0.0, 8.0, 5.0)
		var first_floor_target := Vector3(-4.0, 0.0, -4.0)
		var second_floor_target := Vector3(4.0, 0.0, -14.0)
		brush_firewall.call(
			"set_test_brush_ray_override",
			brush_origin,
			(first_floor_target - brush_origin).normalized(),
			true
		)
		_expect(
			bool(brush_firewall.call("sample_brush_ray_for_test")),
			"adaptive brush records its first floor contact"
		)
		brush_firewall.call(
			"set_test_brush_ray_override",
			brush_origin,
			(second_floor_target - brush_origin).normalized(),
			true
		)
		_expect(
			bool(brush_firewall.call("sample_brush_ray_for_test")),
			"adaptive brush fills a fast camera sweep instead of dropping the stroke"
		)
		var brush_debug: Dictionary = brush_firewall.get_debug_data()
		_expect(
			int(brush_debug.get("brush_subdivision_passes", 0)) >= 1,
			"large ray motion invokes bounded adaptive subdivision"
		)
		_expect(
			int(brush_debug.get("brush_subsample_queries", 0)) > 2
			and int(brush_debug.get("brush_recovered_samples", 0)) > 0,
			"intermediate rays recover surface samples between fast look positions"
		)
		_expect(
			int(brush_debug.get("point_count", 0)) >= 10
			and float(brush_debug.get("path_length", 0.0)) >= 8.0,
			"recovered brush stroke remains a dense continuous floor path"
		)
		_expect(
			int(brush_debug.get("rejected_surface_jumps", 0)) == 0,
			"adaptive floor sweep avoids a false maximum-gap rejection"
		)
		brush_firewall.finish_firewall("test_cleanup")
		await get_tree().process_frame

	_expect(
		get_tree().get_node_count_in_group("spell_effects") == spell_effects_before,
		"all Firewall actions cleanly leave the temporary spell-effect group"
	)
	_expect(
		get_tree().get_node_count_in_group("persistent_spell_effects")
		== persistent_before,
		"all Firewall actions cleanly leave the persistent-effect group"
	)
	_finish([player, floor])


func _spawn_direct_firewall(player: CharacterBody3D) -> FirewallCast:
	var firewall: FirewallCast = FirewallAbility.ability_scene.instantiate() as FirewallCast
	if firewall == null:
		return null
	firewall.targeting_range = 0.1
	firewall.set_payload(FirewallAbility.get_action_payload())
	firewall.set_source_actor(player)
	add_child(firewall)
	firewall.execute(player, Vector3.FORWARD)
	firewall.set_test_cast_held_override(true, true)
	return firewall


func _find_firewall_for_player(player: Node) -> FirewallCast:
	for effect: Node in get_tree().get_nodes_in_group("firewall_effects"):
		if (
			effect is FirewallCast
			and effect.has_method("belongs_to_source")
			and bool(effect.call("belongs_to_source", player))
		):
			return effect as FirewallCast
	return null


func _test_ability_contract() -> void:
	_expect(FirewallAbility.get_spell_id() == "firewall", "Firewall has a stable spell ID")
	_expect(FirewallAbility.element == "fire", "Firewall belongs to Fire")
	_expect(FirewallAbility.mana_cost == 4, "Firewall costs four Mana")
	_expect(
		FirewallAbility.ability_scene != null
		and FirewallAbility.ability_scene.resource_path
		== "res://scenes/actions/firewall_cast.tscn",
		"Firewall uses its dedicated draw-and-erupt action"
	)
	_expect(
		FirewallAbility.get_targeting_style() == "aimed_surface_channel",
		"Firewall advertises aimed surface drawing"
	)
	_expect(
		FirewallAbility.get_delivery_type() == "channel_then_field",
		"Firewall advertises its channel-then-field lifecycle"
	)
	_expect(
		FirewallAbility.get_roles().has("surface_drawing")
		and FirewallAbility.get_roles().has("area_control"),
		"Firewall exposes its path-authoring and area-control roles"
	)


func _find_firewall_index(caster: Node) -> int:
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return -1
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout
	for ability_index: int in range(loadout.get_equipped_ability_count()):
		var ability: AbilityDefinition = loadout.get_equipped_ability(ability_index)
		if ability != null and ability.get_spell_id() == "firewall":
			return ability_index
	return -1


func _make_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "FirewallSmokeFloor"
	floor.position = Vector3(0.0, -0.1, 0.0)
	floor.add_to_group("firewall_drawable_surface")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(80.0, 0.2, 80.0)
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
	push_error("FIREWALL_SPELL_SMOKE_TEST: " + label)


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
		print("FIREWALL_SPELL_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("FIREWALL_SPELL_SMOKE_TEST: " + failure)
	get_tree().quit(1)
