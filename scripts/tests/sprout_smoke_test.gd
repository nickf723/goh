extends Node

const SproutAbility: AbilityDefinition = preload(
	"res://data/abilities/sprout_ability.tres"
)
const StartingLoadout: AbilityLoadout = preload(
	"res://data/loadouts/grace_starting_loadout.tres"
)
const SproutScene: PackedScene = preload(
	"res://scenes/actions/life_sprout_platform.tscn"
)
const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const GameUIScene: PackedScene = preload(
	"res://scenes/ui/game_ui.tscn"
)
const PlantCatalog = preload(
	"res://scripts/life/plant_summon_catalog.gd"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	validate_ability_contract()
	validate_plant_catalog_contract()
	await validate_platform_contract()
	await validate_growth_lift()
	await validate_ground_targeting_contract()
	_finish()


func validate_ability_contract() -> void:
	_expect(SproutAbility != null, "Sprout ability resource exists")
	if SproutAbility == null:
		return
	_expect(SproutAbility.element == "life", "Sprout belongs to Life")
	_expect(SproutAbility.get_spell_id() == "sprout", "Sprout spell id is stable")
	_expect(SproutAbility.mana_cost == 2, "Sprout stays a cheap utility spell")
	_expect(SproutAbility.targeting_style == "ground_placement", "Sprout advertises aimed ground placement")
	for role: String in ["growth", "platform", "traversal", "object_interaction", "plant_summon"]:
		_expect(SproutAbility.roles.has(role), "Sprout declares " + role)
	_expect(StartingLoadout.knows_ability(SproutAbility), "Grace learns Sprout in Focus")


func validate_plant_catalog_contract() -> void:
	var plant_id: String = PlantCatalog.get_plant_id_for_ability(SproutAbility)
	_expect(plant_id == "broadleaf_sprout", "Sprout resolves to the starter discovered plant")
	var definition: PlantSummonDefinition = PlantCatalog.get_definition(plant_id)
	_expect(definition != null, "Broadleaf Sprout has catalog data")
	if definition != null:
		_expect(definition.creates_platform, "Broadleaf Sprout is authored as a platform plant")
		_expect(definition.growth_archetype == "platform", "plant archetype is data-driven")
	var placement: Dictionary = PlantCatalog.get_ground_spell_definition_for_ability(SproutAbility)
	_expect(str(placement.get("effect_type", "")) == "spawn_field", "plant summons use shared ground placement")
	_expect(str(placement.get("post_spawn_method", "")) == "activate_from_ground_target", "placement activates the plant only after confirmation")
	_expect(PlantCatalog.get_default_discovered_plant_ids().has("broadleaf_sprout"), "starter plant is discoverable through the plant library")


func validate_platform_contract() -> void:
	var sprout: LifeSproutPlatform = SproutScene.instantiate() as LifeSproutPlatform
	add_child(sprout)
	await get_tree().process_frame
	_expect(
		sprout.activate_at(Vector3.ZERO, Vector3.UP),
		"Sprout activates on a stable surface"
	)
	_expect(sprout.active, "Sprout becomes active geometry")
	_expect(sprout.platform_body != null, "Sprout builds a StaticBody platform")
	_expect(sprout.visual_root != null, "Sprout builds visible living geometry")
	_expect(sprout.platform_height > 1.0, "Sprout creates a useful traversal step")
	_expect(sprout.lifetime >= 8.0, "Sprout persists long enough for utility")
	if sprout.has_method("get_plant_id"):
		_expect(str(sprout.call("get_plant_id")) == "broadleaf_sprout", "Sprout actor reads its species definition")

	sprout.call("_finish_growth")
	await get_tree().process_frame
	_expect(
		sprout.platform_collision != null and not sprout.platform_collision.disabled,
		"Sprout collision becomes walkable after growth"
	)

	sprout.begin_wither_and_remove()
	await get_tree().process_frame
	_expect(not sprout.active, "Sprout disables gameplay geometry when it starts wilting")
	if is_instance_valid(sprout):
		sprout.queue_free()


func validate_growth_lift() -> void:
	var character := CharacterBody3D.new()
	character.name = "SproutLiftCharacter"
	character.position = Vector3(0.0, 0.45, 0.0)
	var character_collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.2
	character_collision.shape = capsule
	character.add_child(character_collision)
	add_child(character)

	var rigid := RigidBody3D.new()
	rigid.name = "SproutLiftCrate"
	rigid.mass = 2.0
	rigid.position = Vector3(0.45, 0.35, 0.0)
	var rigid_collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.3
	rigid_collision.shape = sphere
	rigid.add_child(rigid_collision)
	add_child(rigid)

	await get_tree().physics_frame

	var sprout: LifeSproutPlatform = SproutScene.instantiate() as LifeSproutPlatform
	add_child(sprout)
	await get_tree().process_frame
	sprout.global_position = Vector3.ZERO
	var lifted: int = sprout.lift_occupants()
	await get_tree().physics_frame

	_expect(lifted >= 2, "Sprout growth detects both characters and physics objects")
	_expect(character.velocity.y > 0.1, "Sprout growth lifts CharacterBody targets")
	_expect(rigid.linear_velocity.y > 0.1, "Sprout growth lifts RigidBody objects")

	sprout.queue_free()
	rigid.queue_free()
	character.queue_free()


func validate_ground_targeting_contract() -> void:
	var game_ui: Node = GameUIScene.instantiate()
	add_child(game_ui)
	var floor: StaticBody3D = _make_floor()
	add_child(floor)
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "SproutGroundTargetPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	add_child(player)
	for _frame: int in range(12):
		await get_tree().process_frame
	await get_tree().physics_frame

	var caster: Node = player.get_node_or_null("AbilityCaster")
	_expect(caster != null, "Sprout test player exposes the plant-aware caster")
	if caster == null:
		player.queue_free()
		floor.queue_free()
		game_ui.queue_free()
		return
	var loadout_value: Variant = caster.get("loadout")
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout if loadout_value is AbilityLoadout else null
	var sprout_index: int = _find_spell_index(loadout, "sprout")
	_expect(sprout_index >= 0, "Sprout exists in the runtime ability array")
	if sprout_index >= 0:
		caster.call("select_ability", sprout_index, false)
		var started: bool = bool(caster.call("cast_from_player", player, 0.18, false))
		_expect(started, "casting Sprout enters placement instead of spawning immediately")
		_expect(bool(caster.call("is_ground_targeting")), "Sprout exposes the movable ground-target reticle")
		if bool(caster.call("is_ground_targeting")):
			var controller: RefCounted = caster.call("get_ground_targeting_controller") as RefCounted
			var spell_key: String = controller.get_spell_key()
			_expect(PlantCatalog.is_plant_ground_spell_key(spell_key), "Sprout targeting is owned by the plant summon catalog")
			caster.call("cancel_ground_targeting", false)

	player.queue_free()
	floor.queue_free()
	game_ui.queue_free()


func _find_spell_index(loadout: AbilityLoadout, spell_id: String) -> int:
	if loadout == null:
		return -1
	for index: int in range(loadout.get_equipped_ability_count()):
		var ability: AbilityDefinition = loadout.get_equipped_ability(index)
		if ability != null and ability.get_spell_id() == spell_id:
			return index
	return -1


func _make_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "SproutTargetFloor"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(24.0, 0.4, 24.0)
	collision.shape = shape
	floor.add_child(collision)
	floor.position = Vector3(0.0, -0.2, 0.0)
	return floor


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("SPROUT_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("SPROUT_SMOKE_TEST: " + failure)
	get_tree().quit(1)
