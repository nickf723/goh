extends "res://scripts/levels/prototype_engineering_build_yard.gd"

const SpellManagerScript = preload(
	"res://scripts/objects/recorded_object_manager_spell.gd"
)


func _build_manager() -> void:
	var existing: Node = player.get_node_or_null("RecordedObjectManager")
	if existing is RecordedObjectManagerSpell:
		manager = existing as RecordedObjectManagerSpell
	else:
		if existing is RecordedObjectManager:
			var legacy := existing as RecordedObjectManager
			legacy.cancel_placement()
			legacy.controller_controls_enabled = false
			legacy.keyboard_controls_enabled = false
			legacy.remove_from_group("recorded_object_manager")
			legacy.name = "RecordedObjectManagerLegacy"
			legacy.queue_free()
		manager = SpellManagerScript.new() as RecordedObjectManagerSpell
		manager.name = "RecordedObjectManager"
		player.add_child(manager)
	manager.maximum_total_active = 7
	manager.print_debug = OS.has_feature("editor")
	manager.bind_actor(player)
	_connect_manager_signal_safe("blueprint_recorded", _on_blueprint_state_changed)
	_connect_manager_signal_safe("blueprint_selected", _on_blueprint_selected)
	_connect_manager_signal_safe("object_placed", _on_object_placed)
	_connect_manager_signal_safe("active_objects_changed", _on_active_objects_changed)


func _connect_manager_signal_safe(
	signal_name: StringName,
	callback: Callable
) -> void:
	if manager.has_signal(signal_name) and not manager.is_connected(signal_name, callback):
		manager.connect(signal_name, callback)
