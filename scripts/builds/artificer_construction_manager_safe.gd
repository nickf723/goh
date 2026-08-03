extends "res://scripts/builds/artificer_construction_manager.gd"
class_name ArtificerConstructionManagerSafe

const SafeContraptionScript = preload(
	"res://scripts/builds/artificer_contraption_instance_safe.gd"
)


func finalize_draft(
	ignore_cost: bool = false,
	manifest_immediately: bool = true
) -> Dictionary:
	# Keep Vector3 values while the draft is live, but rewrite the saved slot with
	# plain arrays after finalization so GameState can serialize it to JSON.
	var slot_id: String = BuildCatalog.get_selected_custom_slot()
	var encoded_parts: Array[Dictionary] = BuildCatalog.encode_part_layout(
		draft_parts
	)
	var result: Dictionary = super.finalize_draft(
		ignore_cost,
		manifest_immediately
	)
	if not bool(result.get("ok", false)):
		return result
	var blueprints: Dictionary = BuildCatalog.get_custom_blueprints()
	var stored: Dictionary = blueprints.get(slot_id, {}) as Dictionary
	if not stored.is_empty():
		stored["parts"] = encoded_parts
		blueprints[slot_id] = stored
		GameState.story_flags[BuildCatalog.CUSTOM_BLUEPRINTS_FLAG] = blueprints
		result["definition"] = BuildCatalog.get_definition(slot_id)
	return result


func _manifest_definition_at(
	definition: Dictionary,
	ground_position: Vector3,
	yaw_degrees: float
) -> ArtificerContraptionInstance:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return null
	var instance := SafeContraptionScript.new() as ArtificerContraptionInstanceSafe
	instance.configure(definition, actor, self)
	scene_root.add_child(instance)
	instance.global_position = ground_position + Vector3.UP * 0.025
	instance.global_rotation = Vector3(0.0, deg_to_rad(yaw_degrees), 0.0)
	active_contraptions.append(instance)
	instance.tree_exiting.connect(_on_contraption_exiting.bind(instance))
	contraption_deployed.emit(instance)
	active_contraptions_changed.emit(active_contraptions.size())
	_show_message(
		str(definition.get("display_name", "Contraption"))
		+ " deployed • "
		+ str(definition.get("mana_cost", 0))
		+ " mana"
	)
	return instance
