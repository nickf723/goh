extends Node

const TargetingAssistScript = preload("res://scripts/player/combat_targeting_assist.gd")


func _ready() -> void:
	var world := Node3D.new()
	world.name = "CombatTargetingSmokeWorld"
	add_child(world)

	var actor := CharacterBody3D.new()
	actor.name = "Grace"
	world.add_child(actor)

	var pivot := Node3D.new()
	pivot.name = "CameraPivot"
	pivot.position = Vector3(0, 1.0, 0)
	actor.add_child(pivot)

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	camera.position = Vector3(0, 1.8, 6.0)
	pivot.add_child(camera)

	var assist := Node.new()
	assist.name = "CombatTargetingAssist"
	assist.set_script(TargetingAssistScript)
	actor.add_child(assist)

	var center_target := Node3D.new()
	center_target.name = "CenterGoblin"
	center_target.position = Vector3(0, 0, -7)
	world.add_child(center_target)
	center_target.add_to_group("enemy")

	var right_target := Node3D.new()
	right_target.name = "RightGoblin"
	right_target.position = Vector3(4, 0, -8)
	world.add_child(right_target)
	right_target.add_to_group("enemy")

	await get_tree().process_frame
	await get_tree().process_frame

	var best: Node3D = assist.call("find_best_hard_target")
	assert(best == center_target)
	assist.call("set_hard_target", center_target)
	assert(assist.get("hard_target") == center_target)

	var switched: Node3D = assist.call("find_directional_target", center_target, 1)
	assert(switched == right_target)

	assist.call("clear_hard_target")
	assist.call("_refresh_soft_target")
	assert(assist.get("soft_target") == center_target)
	var direction: Vector3 = assist.call("get_soft_aim_direction", actor.global_position + Vector3.UP)
	assert(direction.length() > 0.99)
	assert(direction.z < -0.7)

	var debug: Dictionary = assist.call("get_debug_data")
	assert(int(debug.get("hard_candidates", 0)) == 2)

	print("CombatTargetingSmokeTest: PASS")
	get_tree().quit()
