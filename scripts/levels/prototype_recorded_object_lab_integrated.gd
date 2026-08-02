extends "res://scripts/levels/prototype_recorded_object_lab.gd"
class_name PrototypeRecordedObjectLabIntegrated


func _build_manager() -> void:
	manager = player.get_node_or_null(
		"RecordedObjectManager"
	) as RecordedObjectManager
	if manager == null:
		super._build_manager()
		return
	manager.maximum_total_active = 7
	manager.print_debug = OS.has_feature("editor")
	manager.bind_actor(player)
	_connect_manager_signal("blueprint_recorded", _on_blueprint_state_changed)
	_connect_manager_signal("blueprint_selected", _on_blueprint_selected)
	_connect_manager_signal("object_placed", _on_object_placed)
	_connect_manager_signal("active_objects_changed", _on_active_objects_changed)


func _connect_manager_signal(signal_name: StringName, callback: Callable) -> void:
	if manager.has_signal(signal_name) and not manager.is_connected(signal_name, callback):
		manager.connect(signal_name, callback)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["uses_production_manager"] = (
		manager != null
		and manager.get_parent() == player
		and manager.name == "RecordedObjectManager"
	)
	return data
