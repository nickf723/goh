extends Node

const SwordMoveset: WeaponMovesetDefinition = preload("res://data/weapon_movesets/practice_sword_moveset.tres")
const DummyScene: PackedScene = preload("res://scenes/actors/enemies/combat_feel_dummy.tscn")


func _ready() -> void:
	assert(SwordMoveset != null)
	assert(SwordMoveset.validate_graph().is_empty())
	var opening: WeaponAttackDefinition = SwordMoveset.get_attack("sword_l1")
	var returning: WeaponAttackDefinition = SwordMoveset.get_attack("sword_l2")
	var heavy: WeaponAttackDefinition = SwordMoveset.get_attack("sword_h0")
	var reprise: WeaponAttackDefinition = SwordMoveset.get_attack("sword_reprise")
	assert(opening != null and returning != null and heavy != null and reprise != null)
	assert(SwordMoveset.get_follow_up(opening, "light") == returning)
	assert(SwordMoveset.get_follow_up(opening, "heavy") != null)
	assert(SwordMoveset.get_follow_up(heavy, "light") == reprise)
	assert(SwordMoveset.get_follow_up(reprise, "light") == returning)

	var floor := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(10, 1, 10)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.5
	floor.add_child(floor_collision)
	add_child(floor)

	var dummy: CombatFeelDummy = DummyScene.instantiate() as CombatFeelDummy
	add_child(dummy)
	await get_tree().process_frame

	var payload := DamagePayload.new()
	payload.amount = 4
	payload.stance_damage = 5
	payload.source_name = "Smoke Test Cut"
	payload.tags = ["weapon", "melee", "light"]
	var result: Dictionary = dummy.receive_damage_payload(payload)
	dummy.receive_weapon_impact(payload, Vector3.FORWARD, opening)
	assert(str(result.get("contact_type", "")) == "clean")
	assert(dummy.total_hits == 1)
	assert(dummy.last_damage == 4)
	assert(dummy.recoil_velocity.length() > 0.0)

	dummy.set_guarded(true)
	var guarded_result: Dictionary = dummy.receive_damage_payload(payload)
	dummy.receive_weapon_impact(payload, Vector3.FORWARD, heavy)
	assert(str(guarded_result.get("contact_type", "")) == "guarded")
	assert(dummy.last_damage == 0)

	print("CombatFeelSmokeTest: PASS")
	get_tree().quit()
