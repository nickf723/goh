extends Area3D
class_name WaterStateConsole

var water_volume: ConductiveWaterVolume


func _ready() -> void:
	add_to_group("debuggable")
	add_to_group("lab_resettable")


func configure_water(volume: ConductiveWaterVolume) -> void:
	water_volume = volume
	if water_volume != null:
		var callback := Callable(self, "_on_fill_state_changed")
		if not water_volume.fill_state_changed.is_connected(callback):
			water_volume.fill_state_changed.connect(callback)
	update_label()


func _on_fill_state_changed(_is_filled: bool) -> void:
	update_label()


func interact() -> Dictionary:
	if water_volume == null:
		return {"message": "The water controls are disconnected.", "objective": ""}
	water_volume.toggle_filled()
	update_label()
	return {
		"message": "Water basin " + ("filled." if water_volume.filled else "drained."),
		"objective": "Compare the circuit with and without a conductive water path.",
	}


func update_label() -> void:
	var label: Label3D = get_node_or_null("StateLabel") as Label3D
	if label != null:
		label.text = "WATER CONTROL\n" + ("DRAIN" if water_volume != null and water_volume.filled else "FILL")


func reset_target() -> void:
	update_label()


func get_debug_data() -> Dictionary:
	return {
		"water_console": true,
		"water_filled": water_volume.filled if water_volume != null else false,
	}
