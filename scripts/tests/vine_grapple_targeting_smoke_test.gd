extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const GameUIScene: PackedScene = preload(
	"res://scenes/ui/game_ui.tscn"
)
const VineTargeting = preload(
	"res://scripts/player/vine_grapple_targeting.gd"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var floor: StaticBody3D = _make_floor()
	add_child(floor)
	var game_ui: Node = GameUIScene.instantiate()
	add_child(game_ui)
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "VineTargetingTestPlayer"
	player.position = Vector3(0.0, 0.96, 4.0)
	player.add_to_group("player")
	add_child(player)

	var target_a: CharacterBody3D = _make_enemy("NearGoblin", Vector3(-1.3, 0.8, -5.0))
	var target_b: CharacterBody3D = _make_enemy("LockedGoblin", Vector3(1.3, 0.8, -5.0))
	add_child(target_a)
	add_child(target_b)

	for _frame: int in range(10):
		await get_tree().process_frame
	await get_tree().physics_frame

	var caster: Node = player.get_node_or_null("AbilityCaster")
	_expect(caster != null, "player exposes AbilityCaster")
	if caster == null:
		_finish([target_b, target_a, player, game_ui, floor])
		return
	var loadout_value: Variant = caster.get("loadout")
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout if loadout_value is AbilityLoadout else null
	_expect(loadout != null, "player resolves the spell loadout")
	if loadout == null:
		_finish([target_b, target_a, player, game_ui, floor])
		return
	var vine_index: int = _find_spell_index(loadout, "vine_grapple")
	_expect(vine_index >= 0, "Vine Grapple is available")
	if vine_index < 0:
		_finish([target_b, target_a, player, game_ui, floor])
		return
	caster.call("select_ability", vine_index, false)

	player.set("lock_on_target", target_b)
	var assist: Node = player.get_node_or_null("CombatTargetingAssist")
	if assist != null and assist.has_method("set_hard_target"):
		assist.call("set_hard_target", target_b)
	var locked_result: Dictionary = VineTargeting.resolve_target(
		player,
		22.0,
		180.0,
		20.0,
		false
	)
	_expect(
		locked_result.get("target") == target_b,
		"explicit lock-on wins when several grapple targets are nearby"
	)
	_expect(
		str(locked_result.get("source", "")) == VineTargeting.SOURCE_HARD_LOCK,
		"resolver reports hard-lock targeting authority"
	)

	var heavy := RigidBody3D.new()
	heavy.name = "TooHeavy"
	heavy.mass = 220.0
	heavy.position = Vector3(0.0, 1.0, -3.0)
	add_child(heavy)
	var heavy_result: Dictionary = VineTargeting.evaluate_target(
		player,
		heavy,
		heavy.global_position,
		22.0,
		180.0,
		false,
		VineTargeting.SOURCE_DIRECT
	)
	_expect(not bool(heavy_result.get("valid", true)), "overweight objects become invalid targets")
	_expect(str(heavy_result.get("reason", "")) == "too_heavy", "overweight target exposes a clear reason")

	for _frame: int in range(6):
		await get_tree().process_frame
	var preview: Node = get_tree().get_first_node_in_group("vine_grapple_target_previews")
	_expect(preview != null, "gameplay UI installs the Vine target preview")
	if preview != null and preview.has_method("get_debug_data"):
		var preview_data: Dictionary = preview.call("get_debug_data") as Dictionary
		_expect(bool(preview_data.get("active", false)), "Vine target preview becomes visible while the spell is active")
		_expect(str(preview_data.get("target", "")) == "Locked Goblin", "preview names the same hard-locked target")
		_expect(str(preview_data.get("source", "")) == VineTargeting.SOURCE_HARD_LOCK, "preview and cast share targeting authority")

	heavy.queue_free()
	_finish([target_b, target_a, player, game_ui, floor])


func _make_enemy(node_name: String, position_value: Vector3) -> CharacterBody3D:
	var target := CharacterBody3D.new()
	target.name = node_name
	target.position = position_value
	target.add_to_group("enemy")
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.45
	shape.height = 1.6
	collision.shape = shape
	target.add_child(collision)
	var receiver := ForceReceiver.new()
	receiver.name = "ForceReceiver"
	target.add_child(receiver)
	return target


func _make_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "VineTargetingFloor"
	floor.position = Vector3(0.0, -0.1, 0.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(30.0, 0.2, 30.0)
	collision.shape = shape
	floor.add_child(collision)
	return floor


func _find_spell_index(loadout: AbilityLoadout, spell_id: String) -> int:
	for index: int in range(loadout.get_equipped_ability_count()):
		var ability: AbilityDefinition = loadout.get_equipped_ability(index)
		if ability != null and ability.get_spell_id() == spell_id:
			return index
	return -1


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish(nodes: Array) -> void:
	for node_value: Variant in nodes:
		if node_value is Node and is_instance_valid(node_value as Node):
			(node_value as Node).queue_free()
	if failures.is_empty():
		print("VINE_GRAPPLE_TARGETING_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("VINE_GRAPPLE_TARGETING_SMOKE_TEST: " + failure)
	get_tree().quit(1)
