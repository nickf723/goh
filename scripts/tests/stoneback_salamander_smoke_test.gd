extends Node

const StonebackScene: PackedScene = preload("res://scenes/actors/enemies/stoneback_salamander_enemy.tscn")


func _ready() -> void:
	var actor := CharacterBody3D.new()
	actor.name = "Grace"
	actor.add_to_group("player")
	add_child(actor)

	var stoneback: StonebackSalamanderEnemy = StonebackScene.instantiate() as StonebackSalamanderEnemy
	stoneback.ai_enabled = false
	add_child(stoneback)

	await get_tree().process_frame
	await get_tree().process_frame

	assert(stoneback != null)
	assert(stoneback.is_in_group("biological"))
	assert(not stoneback.is_in_group("construct"))
	assert(stoneback.get_climb_anchors().size() == 6)
	assert(not stoneback.can_player_climb())

	var shell: LargeEnemyWeakPoint = stoneback.get_weak_point("shell_plate")
	var vent: LargeEnemyWeakPoint = stoneback.get_weak_point("heat_vent")
	var horn: LargeEnemyWeakPoint = stoneback.get_weak_point("horn")
	var foreleg: LargeEnemyWeakPoint = stoneback.get_weak_point("foreleg")
	assert(shell != null and vent != null and horn != null and foreleg != null)
	assert(not vent.is_targeting_enabled())

	var water := DamagePayload.new()
	water.amount = 1
	water.stance_damage = 0
	water.element = "water"
	water.source_name = "Smoke Test Water"
	stoneback.receive_damage_payload(water)
	assert(stoneback.wet_timer > 0.0)

	var stance_before: int = stoneback.current_stance
	var lightning := DamagePayload.new()
	lightning.amount = 2
	lightning.stance_damage = 4
	lightning.element = "lightning"
	lightning.source_name = "Smoke Test Lightning"
	stoneback.receive_damage_payload(lightning)
	assert(stoneback.current_stance <= stance_before - 8)

	var earth := DamagePayload.new()
	earth.amount = 30
	earth.stance_damage = 8
	earth.element = "earth"
	earth.source_name = "Smoke Test Earth"
	shell.receive_damage_payload(earth)
	assert(shell.broken)
	assert(vent.is_targeting_enabled())
	assert(stoneback.chest_open)

	var ice := DamagePayload.new()
	ice.amount = 34
	ice.stance_damage = 10
	ice.element = "ice"
	ice.source_name = "Smoke Test Ice"
	foreleg.receive_damage_payload(ice)
	assert(foreleg.broken)
	assert(stoneback.state == LargeConstructEnemy.State.KNEEL)
	assert(stoneback.can_player_climb())

	var debug: Dictionary = stoneback.get_debug_data()
	assert(bool(debug.get("creature", false)))
	assert(bool(debug.get("wet", false)))
	assert(bool(debug.get("shell_open", false)))

	print("StonebackSalamanderSmokeTest: PASS")
	get_tree().quit()
