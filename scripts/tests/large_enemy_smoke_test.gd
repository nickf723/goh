extends Node

const ConstructScene: PackedScene = preload("res://scenes/actors/enemies/large_construct_enemy.tscn")
const TargetingAssistScript = preload("res://scripts/player/combat_targeting_assist.gd")
const TraversalControllerScript = preload("res://scripts/player/large_enemy_traversal_controller.gd")


func _ready() -> void:
	var world := Node3D.new()
	world.name = "LargeEnemySmokeWorld"
	add_child(world)

	var actor := CharacterBody3D.new()
	actor.name = "Grace"
	actor.position = Vector3(0, 0, 10)
	actor.add_to_group("player")
	world.add_child(actor)
	var pivot := Node3D.new()
	pivot.name = "CameraPivot"
	pivot.position = Vector3(0, 1, 0)
	actor.add_child(pivot)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	camera.position = Vector3(0, 2, 6)
	pivot.add_child(camera)
	var assist := Node.new()
	assist.name = "CombatTargetingAssist"
	assist.set_script(TargetingAssistScript)
	actor.add_child(assist)

	var construct: LargeConstructEnemy = ConstructScene.instantiate() as LargeConstructEnemy
	construct.name = "SmokeTestColossus"
	construct.ai_enabled = false
	world.add_child(construct)

	await get_tree().process_frame
	await get_tree().process_frame

	assert(construct.get_lock_on_weak_points().size() == 4)
	var core: LargeEnemyWeakPoint = construct.get_weak_point("core")
	var chest: LargeEnemyWeakPoint = construct.get_weak_point("chest_plate")
	var arm: LargeEnemyWeakPoint = construct.get_weak_point("weapon_arm")
	var leg: LargeEnemyWeakPoint = construct.get_weak_point("left_leg")
	assert(core != null and not core.is_targeting_enabled())
	assert(chest != null and arm != null and leg != null)
	var best_body: Node3D = assist.call("find_best_hard_target")
	assert(best_body == construct)
	assist.call("set_hard_target", construct)
	var part_target: Node3D = assist.call("find_directional_target", construct, 1)
	assert(part_target != null)
	assert(part_target.is_in_group("lock_on_weak_point"))
	assert(part_target.call("get_targeting_owner") == construct)

	var heavy := DamagePayload.new()
	heavy.amount = 40
	heavy.stance_damage = 20
	heavy.element = "earth"
	heavy.source_name = "Smoke Test Hammer"
	heavy.hit_type = "weapon"
	heavy.tags = ["weapon", "heavy"]
	chest.receive_damage_payload(heavy)
	assert(chest.broken)
	assert(core.is_targeting_enabled())
	assert(construct.chest_open)

	var shock := DamagePayload.new()
	shock.amount = 40
	shock.stance_damage = 18
	shock.element = "lightning"
	shock.source_name = "Smoke Test Lightning"
	shock.hit_type = "magic"
	shock.tags = ["lightning", "electrical"]
	arm.receive_damage_payload(shock)
	assert(arm.broken)
	assert(not construct.weapon_arm_enabled)

	var ice := DamagePayload.new()
	ice.amount = 38
	ice.stance_damage = 24
	ice.element = "ice"
	ice.source_name = "Smoke Test Ice"
	ice.hit_type = "magic"
	ice.tags = ["ice", "freeze"]
	leg.receive_damage_payload(ice)
	assert(leg.broken)
	assert(construct.broken_legs == 1)
	assert(construct.state == LargeConstructEnemy.State.KNEEL)
	assert(construct.can_player_climb())
	var anchors: Array[Node3D] = construct.get_climb_anchors()
	assert(anchors.size() >= 5)
	actor.global_position = anchors[0].global_position
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	var traversal := TraversalControllerScript.new() as LargeEnemyTraversalController
	actor.add_child(traversal)
	traversal.setup(actor, construct)
	assert(traversal.try_attach())
	assert(traversal.is_attached)
	traversal.on_large_enemy_shake(1.0)
	assert(not traversal.is_attached)

	var debug: Dictionary = construct.get_debug_data()
	assert(bool(debug.get("large_enemy", false)))
	assert(bool(debug.get("chest_open", false)))
	assert(not bool(debug.get("weapon_arm", true)))

	print("LargeEnemySmokeTest: PASS")
	get_tree().quit()
