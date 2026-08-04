extends "res://scripts/ui/gameplay_context_hud.gd"
class_name RecordedObjectStatusHUD

# Compatibility entry point retained for FullMenuDirector. The former
# Recorded-Object-only panel now installs the shared gameplay context surface,
# which owns object reproduction, Soul Grasp, and transient familiar feedback.


func _ready() -> void:
	super._ready()
	call_deferred("_bind_recorded_object_discovery")


func _process(delta: float) -> void:
	if (
		player != null
		and is_instance_valid(player)
		and bool(player.get_meta("shared_placement_active", false))
	):
		if panel != null:
			panel.visible = false
		return
	super._process(delta)


func _bind_recorded_object_discovery() -> void:
	var manager: Node = get_tree().get_first_node_in_group(
		"recorded_object_manager"
	)
	if manager == null or not manager.has_signal("blueprint_recorded"):
		return
	var callback := Callable(self, "_on_blueprint_recorded")
	if not manager.is_connected("blueprint_recorded", callback):
		manager.connect("blueprint_recorded", callback)


func _on_blueprint_recorded(
	blueprint_id: String,
	newly_recorded: bool
) -> void:
	var definition: Dictionary = RecordedObjectCatalogScript.get_definition(
		blueprint_id
	)
	publish_context(
		"recorded_blueprint",
		{
			"eyebrow": (
				"BLUEPRINT RECORDED"
				if newly_recorded
				else "BLUEPRINT PREPARED"
			),
			"title": (
				str(definition.get("icon", "▣"))
				+ "  "
				+ str(definition.get(
					"display_name",
					blueprint_id.capitalize()
				))
			),
			"state": "Available to the Reproduce Object spell",
			"controls": "Prepare it in Magic, Items, or the Journal Blueprint record.",
			"valid": true,
		},
		3.0
	)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["manager_ready"] = (
		get_tree().get_first_node_in_group("recorded_object_manager")
		!= null
	)
	data["shared_placement_suppressed"] = (
		player != null
		and is_instance_valid(player)
		and bool(player.get_meta("shared_placement_active", false))
	)
	return data
