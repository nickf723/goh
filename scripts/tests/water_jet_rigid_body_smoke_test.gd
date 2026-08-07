extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)

var failures: Array[String] = []
var original_stats: Dictionary = {}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	_prepare_stats()

	var floor: StaticBody3D = _make_floor()
	add_child(floor)
	var wall: StaticBody3D = _make_wall()
	add_child(wall)
	var crate: RigidBody3D = _make_crate()
	add_child(crate)
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "WaterJetRigidBodyTestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	add_child(player)
	for _frame: int in range(18):
		await get_tree().process_frame
	await get_tree().physics_frame

	var caster: Node = player.get_node_or_null("AbilityCaster")
	var water_jet_index: int = _find_water_jet_index(caster)
	_expect(caster != null, "rigid-body test resolves AbilityCaster")
	_expect(water_jet_index >= 0, "rigid-body test finds Water Jet")
	if caster == null or water_jet_index < 0:
		_finish([player, crate, wall, floor])
		return

	caster.call("select_ability", water_jet_index, false)
	_expect(
		bool(caster.call("cast_from_player", player, 0.0, false)),
		"rigid-body test starts Water Jet"
	)
	await get_tree().process_frame
	var jet: WaterJetCast = _find_water_jet_for_player(player)
	_expect(jet != null, "rigid-body test resolves the active Water Jet")
	if jet == null:
		_finish([player, crate, wall, floor])
		return

	jet.set_physics_process(false)
	jet.set_test_cast_held_override(true, true)
	jet.set_test_direction_override(Vector3(0.0, 0.0, -1.0), true)
	var starting_position: Vector3 = crate.global_position
	for _tick: int in range(24):
		jet.advance_channel(0.05, true)
		await get_tree().physics_frame

	var debug: Dictionary = jet.get_debug_data()
	var moved_distance: float = starting_position.distance_to(
		crate.global_position
	)
	var target_names: Array = debug.get("targets", []) as Array
	_expect(
		str(debug.get("last_hit", "")) == "WaterJetRigidCrate",
		"the center obstruction ray identifies the contacted crate"
	)
	_expect(
		target_names.has("WaterJetRigidCrate"),
		"the contacted crate is guaranteed into the pressure target set"
	)
	_expect(
		bool(debug.get("endpoint_contact_guarantee", false)),
		"production Water Jet reports endpoint-contact authority"
	)
	_expect(
		int(debug.get("rigid_body_pressure_events", 0)) >= 10,
		"the sustained stream repeatedly pressures the rigid body"
	)
	_expect(
		float(debug.get("rigid_body_force_per_second", 0.0)) >= 150.0,
		"the production pressure tune can overcome ordinary rigid-body friction"
	)
	_expect(
		crate.linear_velocity.z < -0.4,
		"Water Jet gives the crate visible forward velocity"
	)
	_expect(
		moved_distance > 0.35,
		"a twelve-kilogram crate physically moves under sustained Water Jet"
	)
	_expect(not crate.sleeping, "Water Jet wakes a sleeping rigid body before pressure")

	jet.finish_channel("rigid_body_test_complete")
	await get_tree().process_frame
	_finish([player, crate, wall, floor])


func _find_water_jet_for_player(player: Node) -> WaterJetCast:
	for effect: Node in get_tree().get_nodes_in_group("water_jet_effects"):
		if (
			effect is WaterJetCast
			and effect.has_method("belongs_to_source")
			and bool(effect.call("belongs_to_source", player))
		):
			return effect as WaterJetCast
	return null


func _find_water_jet_index(caster: Node) -> int:
	if caster == null:
		return -1
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return -1
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout
	for ability_index: int in range(loadout.get_equipped_ability_count()):
		var ability: AbilityDefinition = loadout.get_equipped_ability(ability_index)
		if ability != null and ability.get_spell_id() == "water_jet":
			return ability_index
	return -1


func _make_crate() -> RigidBody3D:
	var crate := RigidBody3D.new()
	crate.name = "WaterJetRigidCrate"
	crate.position = Vector3(0.0, 0.7, -4.0)
	crate.mass = 12.0
	crate.linear_damp = 0.8
	crate.angular_damp = 5.0
	crate.axis_lock_angular_x = true
	crate.axis_lock_angular_y = true
	crate.axis_lock_angular_z = true
	crate.continuous_cd = true
	crate.sleeping = true
	var material := PhysicsMaterial.new()
	material.friction = 0.9
	material.bounce = 0.0
	crate.physics_material_override = material
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.4, 1.4, 1.4)
	collision.shape = shape
	crate.add_child(collision)
	return crate


func _make_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "WaterJetRigidBodyFloor"
	floor.position = Vector3(0.0, -0.1, -4.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20.0, 0.2, 20.0)
	collision.shape = shape
	floor.add_child(collision)
	return floor


func _make_wall() -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.name = "WaterJetRigidBodyWall"
	wall.position = Vector3(0.0, 2.0, -9.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(8.0, 4.0, 0.5)
	collision.shape = shape
	wall.add_child(collision)
	return wall


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
	push_error("WATER_JET_RIGID_BODY_SMOKE_TEST: " + label)


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
		print("WATER_JET_RIGID_BODY_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("WATER_JET_RIGID_BODY_SMOKE_TEST: " + failure)
	get_tree().quit(1)
