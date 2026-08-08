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

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	validate_ability_contract()
	await validate_platform_contract()
	await validate_growth_lift()
	_finish()


func validate_ability_contract() -> void:
	_expect(SproutAbility != null, "Sprout ability resource exists")
	if SproutAbility == null:
		return
	_expect(SproutAbility.element == "life", "Sprout belongs to Life")
	_expect(SproutAbility.get_spell_id() == "sprout", "Sprout spell id is stable")
	_expect(SproutAbility.mana_cost == 2, "Sprout stays a cheap utility spell")
	for role: String in ["growth", "platform", "traversal", "object_interaction"]:
		_expect(SproutAbility.roles.has(role), "Sprout declares " + role)
	_expect(StartingLoadout.knows_ability(SproutAbility), "Grace learns Sprout in Focus")


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
