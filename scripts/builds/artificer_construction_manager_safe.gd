extends "res://scripts/builds/artificer_construction_manager.gd"
class_name ArtificerConstructionManagerSafe

const SafeContraptionScript = preload(
	"res://scripts/builds/artificer_contraption_instance_safe.gd"
)


func cancel_mode() -> void:
	var previous_mode: String = mode
	super.cancel_mode()
	if previous_mode == MODE_DEPLOY:
		selected_deploy_build_id = ""


func deploy_selected_at(
	ground_position: Vector3,
	yaw_degrees: float = 0.0,
	ignore_cost: bool = false,
	ignore_validation: bool = false,
	excluded_support_rid: RID = RID()
) -> ArtificerContraptionInstance:
	# During a live deployment preview, keep the blueprint frozen to the one that
	# opened the mode. Outside that mode, direct deployment should honor whatever
	# the player most recently prepared in the spell menu or Items.
	if mode != MODE_DEPLOY:
		selected_deploy_build_id = BuildCatalog.get_selected_build_id()
	var resolved_support_rid: RID = excluded_support_rid
	if not resolved_support_rid.is_valid():
		resolved_support_rid = _find_support_rid(ground_position)
	return super.deploy_selected_at(
		ground_position,
		yaw_degrees,
		ignore_cost,
		ignore_validation,
		resolved_support_rid
	)


func finalize_draft(
	ignore_cost: bool = false,
	manifest_immediately: bool = true
) -> Dictionary:
	if draft_parts.size() < 2:
		_show_message("Attach at least two engineering parts before saving a contraption.")
		return {"ok": false, "error": "not enough parts"}
	if draft_parts.size() > maximum_draft_parts:
		_show_message("This draft exceeds the twelve-part prototype limit.")
		return {"ok": false, "error": "too many parts"}

	var slot_id: String = BuildCatalog.get_selected_custom_slot()
	var encoded_parts: Array[Dictionary] = BuildCatalog.encode_part_layout(
		draft_parts
	)
	if encoded_parts.size() != draft_parts.size():
		_show_message("One or more engineering parts could not be encoded.")
		return {"ok": false, "error": "part encoding failed"}

	var newly_saved: bool = not BuildCatalog.is_custom_build(slot_id)
	var stored: Dictionary = {
		"slot_id": slot_id,
		"display_name": BuildCatalog.get_custom_slot_display_name(slot_id),
		"parts": encoded_parts,
		"saved_at_msec": Time.get_ticks_msec(),
	}
	if not BuildCatalog.store_custom_blueprint_record(slot_id, stored):
		_show_message("The contraption slot could not be written.")
		return {"ok": false, "error": "blueprint write failed"}
	BuildCatalog.select_custom_slot(slot_id)
	BuildCatalog.select_build(slot_id)

	var raw_slot_value: Variant = GameState.story_flags.get(
		BuildCatalog.get_custom_slot_flag(slot_id),
		null
	)
	if not raw_slot_value is Dictionary:
		_show_message("The contraption slot disappeared after writing.")
		return {"ok": false, "error": "blueprint verification failed"}
	var raw_slot: Dictionary = raw_slot_value as Dictionary
	var raw_parts: Array = raw_slot.get("parts", []) as Array
	if raw_parts.size() != encoded_parts.size():
		_show_message("The contraption slot did not preserve every part.")
		return {
			"ok": false,
			"error": "blueprint part count mismatch",
			"expected_parts": encoded_parts.size(),
			"stored_parts": raw_parts.size(),
		}

	var definition: Dictionary = BuildCatalog.get_definition(slot_id)
	if (
		definition.is_empty()
		or (definition.get("parts", []) as Array).size()
		!= encoded_parts.size()
	):
		_show_message("The saved contraption recipe could not be reconstructed.")
		return {
			"ok": false,
			"error": "blueprint reconstruction failed",
			"expected_parts": encoded_parts.size(),
			"definition_parts": (definition.get("parts", []) as Array).size(),
		}

	var manifestation: ArtificerContraptionInstance
	if manifest_immediately:
		var cost: int = maxi(int(definition.get("mana_cost", 0)), 0)
		if ignore_cost or cost <= 0 or GameState.spend_mana(cost):
			var origin: Vector3 = (
				draft_root.global_position
				if draft_root != null and is_instance_valid(draft_root)
				else actor.global_position
			)
			manifestation = _manifest_definition_at(definition, origin, 0.0)
		else:
			_show_message("Blueprint saved, but Grace lacks the mana to manifest it now.")

	blueprint_finalized.emit(slot_id, definition)
	_record_artificer_discovery(slot_id, definition)
	clear_draft()
	cancel_mode()
	_show_message(
		str(definition.get("display_name", slot_id.capitalize()))
		+ " saved as an Artificer blueprint."
	)
	return {
		"ok": true,
		"newly_saved": newly_saved,
		"build_id": slot_id,
		"definition": definition,
		"manifestation": manifestation,
		"stored_part_count": raw_parts.size(),
	}


func _record_artificer_discovery(
	build_id: String,
	definition: Dictionary
) -> void:
	var tracker: Node = get_tree().root.get_node_or_null(
		"FullMenuDirector/ProgressionTracker"
	)
	if tracker == null or not tracker.has_method("record_discovery"):
		return
	tracker.call(
		"record_discovery",
		"blueprint",
		build_id,
		{
			"source": "artificer_construction",
			"display_name": str(definition.get("display_name", build_id.capitalize())),
			"components": BuildCatalog.get_component_summary(build_id),
		}
	)


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


func _find_support_rid(ground_position: Vector3) -> RID:
	var world: World3D = get_world_3d()
	if world == null:
		return RID()
	var query := PhysicsRayQueryParameters3D.create(
		ground_position + Vector3.UP * 2.0,
		ground_position + Vector3.DOWN * 3.0
	)
	query.collision_mask = 0xFFFFFFFF
	if actor is CollisionObject3D:
		query.exclude = [(actor as CollisionObject3D).get_rid()]
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	var collider: Object = hit.get("collider")
	if collider is CollisionObject3D:
		return (collider as CollisionObject3D).get_rid()
	return RID()
