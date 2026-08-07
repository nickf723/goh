extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const PuckScene: PackedScene = preload(
	"res://scenes/actions/curling_puck.tscn"
)
const BoulderScene: PackedScene = preload(
	"res://scenes/actions/earth_boulder.tscn"
)
const PuckAbility: AbilityDefinition = preload(
	"res://data/abilities/curling_puck_ability.tres"
)
const TrailScript = preload(
	"res://scripts/actions/curling_ice_trail.gd"
)
const WaterVolumeScript = preload(
	"res://scripts/water/swimming_water_volume.gd"
)

var failures: Array[String] = []
var original_stats: Dictionary = {}
var original_quick_spell_loadouts: Dictionary = {}
var original_quick_spell_selected_slots: Dictionary = {}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	original_quick_spell_loadouts = GameState.quick_spell_loadouts.duplicate(true)
	original_quick_spell_selected_slots = (
		GameState.quick_spell_selected_slots.duplicate(true)
	)
	_prepare_stats()
	_test_ability_contract()

	var ground_floor: StaticBody3D = _make_floor(
		"CurlingPuckGroundFloor",
		Vector3(0.0, -0.5, -10.0),
		Vector3(50.0, 1.0, 50.0)
	)
	add_child(ground_floor)
	var pool_bottom: StaticBody3D = _make_floor(
		"CurlingPuckPoolBottom",
		Vector3(0.0, -3.5, 24.0),
		Vector3(20.0, 1.0, 16.0)
	)
	add_child(pool_bottom)
	var water_volume: SwimmingWaterVolume = _make_water_volume()
	add_child(water_volume)

	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "CurlingPuckTestPlayer"
	player.position = Vector3(0.0, 1.0, 0.0)
	player.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	player.add_to_group("player")
	add_child(player)
	await _wait_frames(20)
	await get_tree().physics_frame

	var caster: Node = player.get_node_or_null("AbilityCaster")
	var puck_index: int = _find_ability_index(caster, "curling_puck")
	_expect(caster != null, "Curling Puck test resolves AbilityCaster")
	_expect(puck_index >= 0, "Grace's complete library contains Curling Puck")
	if caster == null or puck_index < 0:
		_finish([player, water_volume, pool_bottom, ground_floor])
		return

	var spell_effects_before: int = get_tree().get_node_count_in_group(
		"spell_effects"
	)
	var persistent_before: int = get_tree().get_node_count_in_group(
		"persistent_spell_effects"
	)
	var starting_mana: int = GameState.get_stat("mana")
	caster.call("select_ability", puck_index, false)
	_expect(
		bool(caster.call("cast_from_player", player, 0.0, false)),
		"Curling Puck casts through the ordinary AbilityCaster path"
	)
	_expect(
		GameState.get_stat("mana") == starting_mana - 2,
		"Curling Puck spends its two-Mana formation cost"
	)
	await _wait_physics_frames(18)
	var ordinary_puck: CurlingPuck = _find_puck_for_source(player)
	_expect(ordinary_puck != null, "ordinary casting creates one ground puck")
	if ordinary_puck != null:
		var puck_debug: Dictionary = ordinary_puck.get_debug_data()
		var trail_debug: Dictionary = puck_debug.get("trail", {}) as Dictionary
		_expect(
			is_zero_approx(float(puck_debug.get("curl_sign", 99.0))),
			"neutral casting sends a straight puck"
		)
		_expect(
			float(puck_debug.get("distance_travelled", 0.0)) > 1.4,
			"the puck travels along the ground over time"
		)
		_expect(
			int(trail_debug.get("segments", 0)) >= 3,
			"the moving puck leaves several connected ice segments"
		)
		_expect(
			int(trail_debug.get("multimeshes", 0)) == 1
			and int(trail_debug.get("per_segment_process_nodes", -1)) == 0,
			"the complete visual trail uses one MultiMesh and no segment scripts"
		)
		_expect(
			not bool(puck_debug.get("persistent", true)),
			"the moving puck is temporary while its terrain trail is persistent"
		)
		ordinary_puck.force_dissipate("ordinary_cast_complete")
	await _wait_frames(3)

	var curling_puck: CurlingPuck = PuckScene.instantiate() as CurlingPuck
	curling_puck.name = "RightCurlFixture"
	curling_puck.set_payload(PuckAbility.get_action_payload())
	curling_puck.set_source_actor(player)
	add_child(curling_puck)
	Input.action_press("move_right", 1.0)
	curling_puck.execute(player, Vector3.FORWARD)
	Input.action_release("move_right")
	curling_puck.set_physics_process(false)
	var curl_start: Vector3 = curling_puck.global_position
	for _step: int in range(80):
		if not is_instance_valid(curling_puck) or not curling_puck.active:
			break
		curling_puck.advance_puck(0.02)
		await get_tree().physics_frame
	_expect(
		is_instance_valid(curling_puck)
		and is_equal_approx(curling_puck.curl_sign, 1.0),
		"holding right during the cast selects a right-hand curl"
	)
	if is_instance_valid(curling_puck):
		_expect(
			absf(curling_puck.global_position.x - curl_start.x) > 0.18,
			"the selected curl bends the puck away from a straight route"
		)
		curling_puck.force_dissipate("curl_fixture_complete")
	await _wait_frames(3)

	var ground_trail: CurlingIceTrail = TrailScript.new() as CurlingIceTrail
	ground_trail.name = "GroundTractionTrail"
	ground_trail.linger_seconds = 2.0
	add_child(ground_trail)
	ground_trail.configure(player, 901)
	ground_trail.add_path_between(
		Vector3(-4.0, 0.0, -4.0),
		Vector3(4.0, 0.0, -4.0),
		Vector3.RIGHT
	)
	var ground_debug: Dictionary = ground_trail.get_debug_data()
	_expect(
		int(ground_debug.get("ground_segments", 0)) >= 8,
		"ground travel produces a broad slippery runway"
	)

	var motor: PlayerGroundMotionMotor = player.get_node_or_null(
		"GroundMotionMotor"
	) as PlayerGroundMotionMotor
	_expect(motor != null, "Grace exposes the shared ground motion motor")
	if motor != null:
		var dry_velocity: Vector3 = motor.resolve_planar_velocity(
			Vector3(5.0, 0.0, 0.0),
			Vector3.ZERO,
			true,
			0.1
		)
		ground_trail.get_slippery_area().register_body(player)
		var ice_velocity: Vector3 = motor.resolve_planar_velocity(
			Vector3(5.0, 0.0, 0.0),
			Vector3.ZERO,
			true,
			0.1
		)
		_expect(
			ice_velocity.length() > dry_velocity.length() + 0.5,
			"Grace keeps substantially more momentum on the ice trail"
		)
		var motor_debug: Dictionary = motor.get_debug_data()
		_expect(
			bool(motor_debug.get("slippery_active", false))
			and float(motor_debug.get("slippery_braking_multiplier", 1.0)) < 0.2,
			"the locomotion motor reports reduced ice traction"
		)
		ground_trail.get_slippery_area().unregister_body(player)

	var rigid_body := RigidBody3D.new()
	rigid_body.name = "SlipperyRigidFixture"
	rigid_body.linear_damp = 1.1
	rigid_body.angular_damp = 0.9
	add_child(rigid_body)
	ground_trail.get_slippery_area().register_body(rigid_body)
	_expect(
		rigid_body.linear_damp <= 0.05
		and rigid_body.angular_damp <= 0.05,
		"ordinary rigid bodies inherit low damping from the ice trail"
	)
	ground_trail.get_slippery_area().unregister_body(rigid_body)
	_expect(
		is_equal_approx(rigid_body.linear_damp, 1.1)
		and is_equal_approx(rigid_body.angular_damp, 0.9),
		"rigid-body damping is restored after leaving the trail"
	)
	rigid_body.queue_free()

	var boulder: RigidBody3D = BoulderScene.instantiate() as RigidBody3D
	boulder.name = "CurlingPuckBoulderFixture"
	add_child(boulder)
	await get_tree().process_frame
	boulder.freeze = true
	ground_trail.get_slippery_area().register_body(boulder)
	_expect(
		int(boulder.get_meta("ice_curl_last_trail_serial_contact", 0)) == 901,
		"Boulder records which Curling Puck trail changed its traction"
	)
	_expect(
		boulder.linear_damp <= 0.05 and boulder.angular_damp <= 0.05,
		"the ice runway preserves Boulder's translation and roll"
	)
	ground_trail.get_slippery_area().unregister_body(boulder)
	boulder.queue_free()
	ground_trail.force_dissipate("ground_contract_complete")
	await _wait_frames(3)

	var water_trail: CurlingIceTrail = TrailScript.new() as CurlingIceTrail
	water_trail.name = "FrozenWaterTrail"
	water_trail.linger_seconds = 2.0
	add_child(water_trail)
	water_trail.configure(player, 902)
	water_trail.add_path_between(
		Vector3(0.0, 0.0, 17.0),
		Vector3(0.0, 0.0, 31.0),
		Vector3.BACK
	)
	var water_debug: Dictionary = water_trail.get_debug_data()
	_expect(
		int(water_debug.get("water_segments", 0)) >= 20,
		"the trail recognizes and freezes a long route across water"
	)
	_expect(
		int(water_debug.get("bridge_collision_shapes", 0))
		== int(water_debug.get("water_segments", -1)),
		"every water segment receives physical bridge support"
	)
	var swimming: PlayerSwimmingController = player.get_node_or_null(
		"SwimmingController"
	) as PlayerSwimmingController
	_expect(swimming != null, "Grace exposes swimming locomotion")
	if swimming != null:
		swimming.enter_water(water_volume)
		_expect(swimming.should_handle_locomotion(), "water ordinarily activates swimming")
		water_trail.get_frozen_bridge_area().register_body(player)
		_expect(
			not swimming.should_handle_locomotion()
			and swimming.is_supported_by_frozen_surface(),
			"frozen water support hands locomotion back to ground movement"
		)
		water_trail.get_frozen_bridge_area().unregister_body(player)
		_expect(
			swimming.should_handle_locomotion(),
			"swimming resumes when the temporary bridge disappears"
		)
		swimming.exit_water(water_volume)
	water_trail.force_dissipate("water_contract_complete")
	await _wait_frames(3)

	var lifetime_trail: CurlingIceTrail = TrailScript.new() as CurlingIceTrail
	lifetime_trail.name = "CurlingTrailLifetimeFixture"
	lifetime_trail.linger_seconds = 0.08
	lifetime_trail.fade_seconds = 0.04
	add_child(lifetime_trail)
	lifetime_trail.configure(player, 903)
	lifetime_trail.add_path_between(
		Vector3(-1.0, 0.0, -2.0),
		Vector3(1.0, 0.0, -2.0),
		Vector3.RIGHT
	)
	lifetime_trail.finish_drawing("lifetime_test")
	await _wait_frames(24)
	_expect(
		not is_instance_valid(lifetime_trail),
		"the temporary terrain fades and removes every shared collision surface"
	)

	_clear_curling_effects()
	await _wait_frames(4)
	_expect(
		get_tree().get_node_count_in_group("spell_effects") == spell_effects_before
		and get_tree().get_node_count_in_group("persistent_spell_effects")
		== persistent_before,
		"Curling Puck and every ice trail return performance counters to baseline"
	)

	_finish([player, water_volume, pool_bottom, ground_floor])


func _test_ability_contract() -> void:
	_expect(
		PuckAbility.get_spell_id() == "curling_puck",
		"Curling Puck keeps a stable spell ID"
	)
	_expect(PuckAbility.element == "ice", "Curling Puck belongs to Ice")
	_expect(PuckAbility.mana_cost == 2, "Curling Puck costs two Mana")
	_expect(PuckAbility.get_ui_label() == "◍>", "Curling Puck has a distinct Focus badge")
	_expect(
		PuckAbility.category == AbilityDefinition.AbilityCategory.PROJECTILE,
		"Curling Puck remains a projectile spell"
	)
	_expect(
		PuckAbility.get_delivery_type() == "ground_curling_projectile",
		"Curling Puck advertises ground-curling delivery"
	)
	_expect(
		PuckAbility.get_roles().has("water_freeze")
		and PuckAbility.get_roles().has("momentum_setup"),
		"Curling Puck declares bridge and physics-setup roles"
	)
	_expect(
		PuckAbility.ability_scene != null
		and PuckAbility.ability_scene.resource_path
		== "res://scenes/actions/curling_puck.tscn",
		"Curling Puck uses its dedicated action scene"
	)
	var payload: DamagePayload = PuckAbility.get_action_payload() as DamagePayload
	_expect(
		payload != null
		and payload.amount == 1
		and payload.stance_damage == 2
		and payload.status_effect == "chill",
		"the puck itself carries a light chilling impact"
	)


func _find_ability_index(caster: Node, spell_id: String) -> int:
	if caster == null:
		return -1
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return -1
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout
	for ability_index: int in range(loadout.get_equipped_ability_count()):
		var ability: AbilityDefinition = loadout.get_equipped_ability(ability_index)
		if ability != null and ability.get_spell_id() == spell_id:
			return ability_index
	return -1


func _find_puck_for_source(player: Node) -> CurlingPuck:
	for candidate: Node in get_tree().get_nodes_in_group("curling_puck_effects"):
		if (
			candidate is CurlingPuck
			and candidate.has_method("belongs_to_source")
			and bool(candidate.call("belongs_to_source", player))
		):
			return candidate as CurlingPuck
	return null


func _make_floor(
	node_name: String,
	position_value: Vector3,
	size_value: Vector3
) -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = node_name
	floor.position = position_value
	floor.collision_layer = 1
	floor.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	floor.add_child(collision)
	return floor


func _make_water_volume() -> SwimmingWaterVolume:
	var volume: SwimmingWaterVolume = (
		WaterVolumeScript.new() as SwimmingWaterVolume
	)
	volume.name = "CurlingPuckFreezableWater"
	volume.position = Vector3(0.0, -1.5, 24.0)
	volume.surface_height_offset = 1.5
	volume.water_label = "Curling Puck Test Pool"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(18.0, 3.0, 16.0)
	collision.shape = shape
	volume.add_child(collision)
	return volume


func _clear_curling_effects() -> void:
	for puck: Node in get_tree().get_nodes_in_group("curling_puck_effects"):
		if puck != null and is_instance_valid(puck):
			if puck.has_method("force_dissipate"):
				puck.call("force_dissipate", "smoke_test_cleanup")
			else:
				puck.queue_free()
	for trail: Node in get_tree().get_nodes_in_group("curling_ice_trails"):
		if trail != null and is_instance_valid(trail):
			if trail.has_method("force_dissipate"):
				trail.call("force_dissipate", "smoke_test_cleanup")
			else:
				trail.queue_free()


func _prepare_stats() -> void:
	GameState.set_stat("max_health", 100)
	GameState.set_stat("health", 100)
	GameState.set_stat("max_mana", 100)
	GameState.set_stat("mana", 100)
	GameState.set_stat("max_stamina", 40)
	GameState.set_stat("stamina", 40)
	GameState.set_stat("max_stance", 35)
	GameState.set_stat("stance", 35)


func _wait_frames(frame_count: int) -> void:
	for _frame: int in range(maxi(frame_count, 0)):
		await get_tree().process_frame


func _wait_physics_frames(frame_count: int) -> void:
	for _frame: int in range(maxi(frame_count, 0)):
		await get_tree().physics_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("CURLING_PUCK_SPELL_SMOKE_TEST: " + label)


func _restore_state() -> void:
	GameState.stats = original_stats.duplicate(true)
	for stat_value: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_value)
		GameState.stat_changed.emit(stat_id, int(GameState.stats[stat_value]))
	GameState.quick_spell_loadouts = original_quick_spell_loadouts.duplicate(true)
	GameState.quick_spell_selected_slots = (
		original_quick_spell_selected_slots.duplicate(true)
	)


func _finish(nodes: Array) -> void:
	Engine.time_scale = 1.0
	Input.action_release("move_left")
	Input.action_release("move_right")
	_clear_curling_effects()
	_restore_state()
	for node_value: Variant in nodes:
		if node_value is Node and is_instance_valid(node_value as Node):
			(node_value as Node).queue_free()
	if failures.is_empty():
		print("CURLING_PUCK_SPELL_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("CURLING_PUCK_SPELL_SMOKE_TEST: " + failure)
	get_tree().quit(1)
