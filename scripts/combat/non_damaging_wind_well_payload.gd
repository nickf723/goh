extends DamagePayload
class_name NonDamagingWindWellPayload


func _init() -> void:
	amount = 0
	stance_damage = 0
	element = "air"
	source_name = "Wind Well"
	hit_type = "updraft_field"
	status_effect = ""
	status_duration = 0.0
	status_strength = 0.0
	knockback_strength = 0.0
	knockback_up_strength = 0.0
	suppress_reactions = true
