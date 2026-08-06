extends DamagePayload
class_name NonDamagingWaterWavePayload


func _init() -> void:
	amount = 0
	stance_damage = 0
	element = "water"
	source_name = "Water Wave"
	hit_type = "wave"
	status_effect = "wet"
	status_duration = 4.0
	status_strength = 1.0
	knockback_strength = 0.0
	knockback_up_strength = 0.0
	suppress_reactions = true
