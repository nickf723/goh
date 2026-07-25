extends StaticBody3D

var lab: Node
var health: int = 16


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	if payload == null:
		return {}
	if lab != null and lab.has_method("receive_target_hit"):
		return lab.call("receive_target_hit", maxi(payload.amount, 1))
	health = maxi(health - maxi(payload.amount, 1), 0)
	return {"message": "Target health " + str(health), "objective": ""}


func is_target_defeated() -> bool:
	return health <= 0


func get_targeting_aim_point() -> Vector3:
	return global_position + Vector3.UP * 1.2
