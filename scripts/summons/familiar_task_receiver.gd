extends Area3D
class_name FamiliarTaskReceiver

signal task_started(task_id: String, familiar: Node3D)
signal task_state_changed(task_id: String, state: String)
signal task_completed(task_id: String, familiar: Node3D, result: Dictionary)

const TaskStateStoreScript: Script = preload(
	"res://scripts/summons/familiar_task_state_store.gd"
)

@export_group("Task Identity")
@export var task_id: String = "hold"
@export var task_key: String = ""
@export var display_name: String = "Familiar Task"
@export var action_label: String = "Use Familiar"
@export_multiline var description: String = "Send the familiar to interact with this object."
@export var capability_tag: String = ""
@export var required_species_ids: Array[String] = []
@export var one_shot: bool = false
@export var persist_completion: bool = true

@export_group("Targeting")
@export var anchor_offset: Vector3 = Vector3.ZERO
@export_range(0.4, 4.0, 0.1) var interaction_radius: float = 1.25
@export_range(0.2, 4.0, 0.1) var target_radius: float = 0.9

@export_group("World Result")
@export var affected_node_path: NodePath
@export var revealed_node_path: NodePath
@export var reward_item_id: String = ""
@export_range(0, 99, 1) var reward_amount: int = 0
@export var completion_flag: String = ""

@export_group("Presentation")
@export var show_world_label: bool = true
@export var accent_color: Color = Color(0.38, 0.92, 0.72)
@export var completed_color: Color = Color(0.95, 0.76, 0.28)

var task_store: FamiliarTaskStateStore
var completed: bool = false
var active: bool = false
var active_familiar: Node3D
var completion_count: int = 0
var last_result: Dictionary = {}
var marker_root: Node3D
var marker_mesh: MeshInstance3D
var world_label: Label3D


func _ready() -> void:
	monitoring = true
	monitorable = true
	collision_layer = 1 << 19
	collision_mask = 0
	add_to_group("familiar_task_receivers")
	add_to_group("debuggable")
	_ensure_target_shape()
	_build_presentation()
	task_store = TaskStateStoreScript.get_or_create(get_tree()) as FamiliarTaskStateStore
	_restore_persistent_state()
	_refresh_presentation()


func _process(_delta: float) -> void:
	if not active or task_id != "hold":
		return
	if active_familiar == null or not is_instance_valid(active_familiar):
		_release_hold("familiar unavailable")
		return
	if active_familiar.global_position.distance_to(get_task_anchor(active_familiar)) > interaction_radius * 1.55:
		_release_hold("familiar left position")


func get_task_anchor(_familiar: Node3D = null) -> Vector3:
	return global_position + global_basis * anchor_offset


func get_familiar_task_preview(familiar: Node3D) -> Dictionary:
	var availability: Dictionary = _get_availability(familiar)
	var resolved_label: String = action_label
	if completed and one_shot:
		resolved_label = display_name + " Complete"
	return {
		"valid": bool(availability.get("ok", false)),
		"task_id": _normalized_task_id(),
		"task_key": _resolved_task_key(),
		"label": resolved_label,
		"description": str(availability.get("error", description)),
		"position": get_task_anchor(familiar),
		"receiver": self,
		"completed": completed,
		"active": active,
		"capability": _resolved_capability(),
	}


func begin_familiar_task(familiar: Node3D) -> Dictionary:
	var availability: Dictionary = _get_availability(familiar)
	if not bool(availability.get("ok", false)):
		return availability
	active_familiar = familiar
	active = true
	task_started.emit(_normalized_task_id(), familiar)
	task_state_changed.emit(_normalized_task_id(), "active")
	match _normalized_task_id():
		"hold":
			last_result = {
				"ok": true,
				"task_id": "hold",
				"task_key": _resolved_task_key(),
				"ongoing": true,
				"message": _familiar_name(familiar) + " is holding " + display_name + ".",
			}
			_refresh_presentation()
			return last_result.duplicate(true)
		"ram":
			return _complete_ram(familiar)
		"forage":
			return _complete_forage(familiar)
		_:
			return _complete_generic(familiar)


func end_familiar_task(familiar: Node3D = null) -> bool:
	if not active:
		return false
	if familiar != null and active_familiar != familiar:
		return false
	_release_hold("released")
	return true


func is_task_active_for(familiar: Node3D) -> bool:
	return active and active_familiar == familiar


func reset_task(save_now: bool = true) -> void:
	active = false
	active_familiar = null
	completed = false
	completion_count = 0
	last_result.clear()
	_set_affected_enabled(true)
	_set_revealed_enabled(false)
	if task_store != null and _resolved_task_key() != "":
		task_store.remove_task_state(_resolved_task_key(), save_now)
	_refresh_presentation()
	task_state_changed.emit(_normalized_task_id(), "reset")


func get_task_debug_data() -> Dictionary:
	return {
		"task_id": _normalized_task_id(),
		"task_key": _resolved_task_key(),
		"display_name": display_name,
		"capability": _resolved_capability(),
		"completed": completed,
		"active": active,
		"active_familiar": _familiar_name(active_familiar) if active_familiar != null and is_instance_valid(active_familiar) else "none",
		"completion_count": completion_count,
		"last_result": last_result.duplicate(true),
	}


func get_debug_data() -> Dictionary:
	return {"familiar_task_receiver": get_task_debug_data()}


func _get_availability(familiar: Node3D) -> Dictionary:
	if familiar == null or not is_instance_valid(familiar):
		return {"ok": false, "error": "No familiar is available."}
	if completed and one_shot:
		return {"ok": false, "error": display_name + " is already complete."}
	var species_value: Variant = familiar.get("species_id")
	var species_id: String = str(species_value).to_lower().strip_edges() if species_value != null else ""
	if not required_species_ids.is_empty():
		var normalized_species: Array[String] = []
		for raw_species: String in required_species_ids:
			normalized_species.append(raw_species.to_lower().strip_edges())
		if not normalized_species.has(species_id):
			return {"ok": false, "error": display_name + " requires a different familiar species."}
	var capability: String = _resolved_capability()
	if familiar.has_method("has_familiar_task_capability"):
		if not bool(familiar.call("has_familiar_task_capability", capability)):
			return {
				"ok": false,
				"error": _familiar_name(familiar) + " cannot " + capability.replace("_", " ") + ".",
			}
	elif capability != "hold":
		return {"ok": false, "error": _familiar_name(familiar) + " lacks this task capability."}
	return {"ok": true}


func _complete_ram(familiar: Node3D) -> Dictionary:
	_set_affected_enabled(false)
	var result: Dictionary = _finish_one_shot(
		familiar,
		_familiar_name(familiar) + " smashes through " + display_name + "."
	)
	result["reaction"] = "break"
	return result


func _complete_forage(familiar: Node3D) -> Dictionary:
	var gained: int = 0
	if reward_item_id != "" and reward_amount > 0:
		gained = GameState.add_inventory_item(reward_item_id, reward_amount)
	_set_revealed_enabled(true)
	var message: String = _familiar_name(familiar) + " searches " + display_name + "."
	if reward_item_id != "" and gained > 0:
		message += " Found " + str(gained) + " " + reward_item_id.replace("_", " ").capitalize() + "."
	var result: Dictionary = _finish_one_shot(familiar, message)
	result["reward_item_id"] = reward_item_id
	result["reward_amount"] = gained
	result["reaction"] = "reveal"
	return result


func _complete_generic(familiar: Node3D) -> Dictionary:
	return _finish_one_shot(
		familiar,
		_familiar_name(familiar) + " completes " + display_name + "."
	)


func _finish_one_shot(familiar: Node3D, message: String) -> Dictionary:
	active = false
	completed = true
	completion_count += 1
	last_result = {
		"ok": true,
		"task_id": _normalized_task_id(),
		"task_key": _resolved_task_key(),
		"completed": true,
		"message": message,
	}
	if completion_flag != "" and GameState.has_method("set_flag"):
		GameState.call("set_flag", completion_flag, true)
	if persist_completion and task_store != null:
		task_store.mark_completed(
			_resolved_task_key(),
			_normalized_task_id(),
			_familiar_identity(familiar),
			{
				"display_name": display_name,
				"completion_count": completion_count,
				"result": last_result.duplicate(true),
			},
			true
		)
	_refresh_presentation()
	task_state_changed.emit(_normalized_task_id(), "completed")
	task_completed.emit(_normalized_task_id(), familiar, last_result.duplicate(true))
	active_familiar = null
	return last_result.duplicate(true)


func _release_hold(reason: String) -> void:
	active = false
	active_familiar = null
	last_result = {
		"ok": true,
		"task_id": "hold",
		"task_key": _resolved_task_key(),
		"released": true,
		"reason": reason,
	}
	_refresh_presentation()
	task_state_changed.emit("hold", "inactive")


func _restore_persistent_state() -> void:
	if not persist_completion or task_store == null:
		return
	var state: Dictionary = task_store.get_task_state(_resolved_task_key())
	if state.is_empty() or not bool(state.get("completed", false)):
		return
	completed = true
	completion_count = maxi(int(state.get("completion_count", 1)), 1)
	last_result = state.get("result", {}) as Dictionary
	if _normalized_task_id() == "ram":
		_set_affected_enabled(false)
	elif _normalized_task_id() == "forage":
		_set_revealed_enabled(true)


func _ensure_target_shape() -> void:
	for child: Node in get_children():
		if child is CollisionShape3D:
			return
	var collision := CollisionShape3D.new()
	collision.name = "FamiliarTaskTargetShape"
	var shape := SphereShape3D.new()
	shape.radius = target_radius
	collision.shape = shape
	add_child(collision)


func _build_presentation() -> void:
	marker_root = Node3D.new()
	marker_root.name = "FamiliarTaskMarker"
	add_child(marker_root)
	marker_mesh = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.72
	mesh.bottom_radius = 0.72
	mesh.height = 0.045
	marker_mesh.mesh = mesh
	marker_mesh.position.y = 0.04
	marker_root.add_child(marker_mesh)
	if show_world_label:
		world_label = Label3D.new()
		world_label.name = "FamiliarTaskLabel"
		world_label.position = Vector3(0.0, 1.45, 0.0)
		world_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		world_label.font_size = 22
		world_label.pixel_size = 0.006
		world_label.outline_size = 7
		marker_root.add_child(world_label)


func _refresh_presentation() -> void:
	var color: Color = completed_color if completed else accent_color
	if active:
		color = Color(1.0, 0.9, 0.32)
	if marker_mesh != null:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(color.r, color.g, color.b, 0.58)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.8
		marker_mesh.material_override = material
	if world_label != null:
		world_label.text = (
			display_name.to_upper() + "\nCOMPLETE"
			if completed and one_shot
			else action_label.to_upper()
		)
		world_label.modulate = color


func _set_affected_enabled(enabled: bool) -> void:
	var node: Node = get_node_or_null(affected_node_path) if affected_node_path != NodePath() else null
	_set_world_node_enabled(node, enabled)


func _set_revealed_enabled(enabled: bool) -> void:
	var node: Node = get_node_or_null(revealed_node_path) if revealed_node_path != NodePath() else null
	_set_world_node_enabled(node, enabled)


func _set_world_node_enabled(node: Node, enabled: bool) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node is Node3D:
		(node as Node3D).visible = enabled
	node.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	_set_collision_enabled_recursive(node, enabled)


func _set_collision_enabled_recursive(node: Node, enabled: bool) -> void:
	if node is CollisionObject3D:
		var collision_object := node as CollisionObject3D
		if not collision_object.has_meta("familiar_task_original_layer"):
			collision_object.set_meta("familiar_task_original_layer", collision_object.collision_layer)
			collision_object.set_meta("familiar_task_original_mask", collision_object.collision_mask)
		collision_object.collision_layer = int(collision_object.get_meta("familiar_task_original_layer", 1)) if enabled else 0
		collision_object.collision_mask = int(collision_object.get_meta("familiar_task_original_mask", 1)) if enabled else 0
	for child: Node in node.get_children():
		_set_collision_enabled_recursive(child, enabled)


func _normalized_task_id() -> String:
	return task_id.to_lower().strip_edges().replace(" ", "_")


func _resolved_capability() -> String:
	var normalized: String = capability_tag.to_lower().strip_edges().replace(" ", "_")
	return normalized if normalized != "" else _normalized_task_id()


func _resolved_task_key() -> String:
	var normalized: String = task_key.to_lower().strip_edges().replace(" ", "_")
	if normalized != "":
		return normalized
	var scene_path: String = get_tree().current_scene.scene_file_path if get_tree() != null and get_tree().current_scene != null else "runtime"
	return (scene_path + ":" + str(get_path())).to_lower().replace(" ", "_")


func _familiar_name(familiar: Node3D) -> String:
	if familiar == null or not is_instance_valid(familiar):
		return "Familiar"
	var display_value: Variant = familiar.get("display_name")
	if display_value != null and str(display_value) != "":
		return str(display_value)
	var name_value: Variant = familiar.get("animal_name")
	return str(name_value) if name_value != null and str(name_value) != "" else familiar.name


func _familiar_identity(familiar: Node3D) -> String:
	if familiar == null or not is_instance_valid(familiar):
		return ""
	for property_name: String in ["roster_animal_id", "persistent_animal_id", "species_id"]:
		var value: Variant = familiar.get(property_name)
		if value != null and str(value) != "":
			return str(value).to_lower().strip_edges()
	return familiar.name.to_lower()
