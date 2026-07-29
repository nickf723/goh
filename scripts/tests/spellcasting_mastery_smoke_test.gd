extends Node

const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")
const SpellcastingMasteryFixtureScript = preload(
	"res://scripts/tests/spellcasting_mastery_test_fixture.gd"
)


func _ready() -> void:
	var floor: StaticBody3D = _make_floor()
	add_child(floor)
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "SpellcastingMasteryPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	var manager: PlayerAvatarManager = (
		player.get_node_or_null("AvatarManager") as PlayerAvatarManager
	)
	var failures: Array[String] = []
	if manager == null or not manager.initialized:
		failures.append("PlayerAvatarManager did not initialize")
	else:
		failures.append_array(SpellcastingMasteryFixtureScript.run(manager))

	if failures.is_empty():
		print("SPELLCASTING_MASTERY_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("SPELLCASTING_MASTERY_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func _make_floor() -> StaticBody3D:
	var floor: StaticBody3D = StaticBody3D.new()
	floor.name = "SpellcastingMasteryFloor"
	floor.position = Vector3(0.0, -0.1, 0.0)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(18.0, 0.2, 18.0)
	collision.shape = shape
	floor.add_child(collision)
	return floor
