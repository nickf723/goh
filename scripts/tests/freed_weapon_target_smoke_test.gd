extends Node

const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")


func _ready() -> void:
	var player := PlayerScene.instantiate() as CharacterBody3D
	assert(player != null)
	add_child(player)
	await get_tree().process_frame

	var controller: Node = player.get_node("WeaponController")
	assert(controller != null)
	assert(controller is SafeWeaponController)

	var stale_target := Node3D.new()
	stale_target.add_to_group("lock_on_weak_point")
	add_child(stale_target)
	player.set("lock_on_target", stale_target)
	stale_target.free()

	var attack: WeaponAttackDefinition = WeaponAttackDefinition.new()
	attack.attack_range = 3.0
	attack.cone_angle_degrees = 120.0

	var resolved: Node = controller.call("_get_locked_weak_point", player, attack)
	assert(resolved == null)
	assert(player.get("lock_on_target") == null)

	var second_target := Node3D.new()
	add_child(second_target)
	second_target.free()
	var position: Vector3 = controller.call("get_target_position", second_target)
	assert(position == Vector3.ZERO)

	player.queue_free()
	await get_tree().process_frame
	print("FREED_WEAPON_TARGET_SMOKE_TEST: PASS")
	get_tree().quit(0)
