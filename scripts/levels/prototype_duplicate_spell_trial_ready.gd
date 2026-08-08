extends "res://scripts/levels/prototype_duplicate_spell_trial.gd"
class_name PrototypeDuplicateSpellTrialReady


func _plate(
	node_name: String,
	position_value: Vector3,
	display: String
) -> PressurePlateSwitch:
	var plate: PressurePlateSwitch = super._plate(
		node_name,
		position_value,
		display
	)
	if plate != null:
		# The stock plate is 1.75 m wide. Paired lanes are 1.7 m apart, so two
		# unscaled detection boxes overlap. Narrow only this lab's plates enough
		# that each physical body must genuinely occupy its own lane.
		plate.scale = Vector3(0.72, 1.0, 1.0)
	return plate


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["independent_plate_lanes"] = true
	data["paired_plate_scale_x"] = 0.72
	return data
