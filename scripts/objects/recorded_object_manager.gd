extends Node3D
class_name RecordedObjectManager

signal blueprint_recorded(blueprint_id: String, newly_recorded: bool)
signal blueprint_selected(blueprint_id: String)
signal placement_started(blueprint_id: String)
signal placement_updated(position: Vector3, valid: bool, reason: String)
signal placement_cancelled
signal object_placed(object: RecordedObjectInstance)
signal active_objects_changed(count: int)

const Catalog = preload("res://scripts/objects/recorded_object_catalog.gd")
const RecordedObjectScript = preload(
	"res://scripts/objects/recorded_object_instance_safe.gd"
)

@export var actor_path: NodePath
@export_range(1, 20, 1) var maximum_total_active: int = 7
@export_range(15.0, 180.0, 15.0) var rotation_step_degrees: float = 90.0
@export var keyboard_controls_enabled: bool = true
@export var controller_controls_enabled: bool = true
@export var print_debug: bool = false

var actor: Node3D
var active_objects: Array[RecordedObjectInstance] = []
var placement_active: bool = false
var placement_yaw_degrees: float = 0.0
var target_ground_position: Vector3 = Vector3.ZERO
var placement_valid: bool = false
var invalid_reason: String = ""
var support_rid: RID
var preview_root: Node3D
var preview_mesh: MeshInstance3D
var last_selected_id: String = ""


func _ready() -> void:
	actor = get_node_or_null(actor_path) as Node3D if actor_path != NodePath() else null
	if actor == null and get_parent() is Node3D:
		actor = get_parent() as Node3D
	add_to_group("recorded_object_manager")
	add_to_group("debuggable")
	last_selected_id = Catalog.get_selected_blueprint_id()


func bind_actor(new_actor: Node3D) -> void:
	actor = new_actor


func _process(_delta: float) -> void:
	_prune_active_objects()
	if placement_active:
		_update_target_from_camera()
		_update_preview()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if keyboard_controls_enabled and event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			match key_event.keycode:
				KEY_V:
					toggle_placement()
				KEY_Q:
					cycle_blueprint(-1)
				KEY_E:
					cycle_blueprint(1)
				KEY_R:
					rotate_preview(1)
				KEY_F1, KEY_F2, KEY_F3, KEY_F4:
					var index: int = int(key_event.keycode - KEY_F1)
					select_blueprint_by_index(index)
				KEY_F8:
					clear_spawned_objects()
				_:
					return
			get_viewport().set_input_as_handled()
			return
	if keyboard_controls_enabled and event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and placement_active:
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				confirm_placement()
				get_viewport().set_input_as_handled()
			elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
				cancel_placement()
				get_viewport().set_input_as_handled()
			return
	if controller_controls_enabled and event is InputEventJoypadButton:
		var button_event := event as InputEventJoypadButton
		if not button_event.pressed:
			return
		match button_event.button_index:
			JOY_BUTTON_Y:
				toggle_placement()
			JOY_BUTTON_LEFT_SHOULDER:
				cycle_blueprint(-1)
			JOY_BUTTON_RIGHT_SHOULDER:
				cycle_blueprint(1)
			JOY_BUTTON_A:
				if placement_active:
					confirm_placement()
				else:
					begin_placement()
			JOY_BUTTON_B:
				if placement_active:
					cancel_placement()
				else:
					return
			_:
				return
		get_viewport().set_input_as_handled()


func record_blueprint(blueprint_id: String) -> Dictionary:
	var result: Dictionary = Catalog.record_blueprint(blueprint_id)
	if bool(result.get("ok", false)):
		var newly_recorded: bool = bool(result.get("newly_recorded", false))
		blueprint_recorded.emit(blueprint_id, newly_recorded)
		select_blueprint(blueprint_id)
		_show_message(
			(
				"Blueprint recorded: "
				if newly_recorded
				else "Blueprint selected: "
			)
			+ str((result.get("definition", {}) as Dictionary).get("display_name", blueprint_id.capitalize()))
		)
	return result


func select_blueprint(blueprint_id: String) -> bool:
	if not Catalog.select_blueprint(blueprint_id):
		_show_message("That object has not been recorded yet.")
		return false
	last_selected_id = blueprint_id
	blueprint_selected.emit(blueprint_id)
	if placement_active:
		_rebuild_preview()
		_update_target_from_camera()
		_update_preview()
	return true


func select_blueprint_by_index(index: int) -> bool:
	if index < 0 or index >= Catalog.BLUEPRINT_ORDER.size():
		return false
	return select_blueprint(Catalog.BLUEPRINT_ORDER[index])


func cycle_blueprint(direction: int) -> bool:
	var recorded: Array[String] = Catalog.get_recorded_blueprint_ids()
	if recorded.is_empty():
		_show_message("Record an object before trying to reproduce it.")
		return false
	var selected: String = Catalog.get_selected_blueprint_id()
	var index: int = recorded.find(selected)
	if index < 0:
		index = 0
	else:
		index = posmod(index + signi(direction), recorded.size())
	var changed: bool = select_blueprint(recorded[index])
	if changed:
		_show_message("Recorded object: " + str(Catalog.get_definition(recorded[index]).get("display_name", recorded[index].capitalize())))
	return changed


func toggle_placement() -> void:
	if placement_active:
		cancel_placement()
	else:
		begin_placement()


func begin_placement() -> bool:
	var blueprint_id: String = Catalog.get_selected_blueprint_id()
	if blueprint_id == "" or not Catalog.is_recorded(blueprint_id):
		_show_message("No recorded object is selected.")
		return false
	placement_active = true
	placement_yaw_degrees = 0.0
	_rebuild_preview()
	_update_target_from_camera()
	_update_preview()
	placement_started.emit(blueprint_id)
	_show_message("Placing " + str(Catalog.get_definition(blueprint_id).get("display_name", blueprint_id.capitalize())) + ".")
	return true


func cancel_placement() -> void:
	placement_active = false
	placement_valid = false
	invalid_reason = ""
	_destroy_preview()
	placement_cancelled.emit()


func rotate_preview(direction: int = 1) -> void:
	if not placement_active:
		return
	placement_yaw_degrees = wrapf(
		placement_yaw_degrees + rotation_step_degrees * signi(direction),
		0.0,
		360.0
	)
	_update_preview()


func confirm_placement() -> RecordedObjectInstance:
	if not placement_active:
		return null
	if not placement_valid:
		_show_message(invalid_reason if invalid_reason != "" else "The object cannot fit there.")
		return null
	var instance: RecordedObjectInstance = place_selected_at(
		target_ground_position,
		placement_yaw_degrees,
		false,
		false,
		support_rid
	)
	if instance != null:
		cancel_placement()
	return instance


func place_selected_at(
	ground_position: Vector3,
	yaw_degrees: float = 0.0,
	ignore_cost: bool = false,
	ignore_validation: bool = false,
	excluded_support_rid: RID = RID()
) -> RecordedObjectInstance:
	var blueprint_id: String = Catalog.get_selected_blueprint_id()
	var definition: Dictionary = Catalog.get_definition(blueprint_id)
	if definition.is_empty() or not Catalog.is_recorded(blueprint_id):
		return null
	var validation: Dictionary = validate_placement(
		definition,
		ground_position,
		yaw_degrees,
		excluded_support_rid
	)
	if not ignore_validation and not bool(validation.get("valid", false)):
		invalid_reason = str(validation.get("reason", "The object cannot fit there."))
		return null
	var mana_cost: int = maxi(int(definition.get("mana_cost", 0)), 0)
	if not ignore_cost and mana_cost > 0 and not GameState.spend_mana(mana_cost):
		_show_message("Not enough mana to reproduce " + str(definition.get("display_name", "that object")) + ".")
		return null
	_enforce_active_limits(blueprint_id, int(definition.get("maximum_active", 1)))
	var instance := RecordedObjectScript.new() as RecordedObjectInstance
	instance.configure(definition, actor, self)
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		if not ignore_cost and mana_cost > 0:
			GameState.restore_mana(mana_cost)
		instance.queue_free()
		return null
	scene_root.add_child(instance)
	var size: Vector3 = definition.get("size", Vector3.ONE) as Vector3
	instance.global_position = ground_position + Vector3.UP * (size.y * 0.5 + 0.025)
	instance.global_rotation = Vector3(0.0, deg_to_rad(yaw_degrees), 0.0)
	active_objects.append(instance)
	instance.tree_exiting.connect(_on_object_exiting.bind(instance))
	object_placed.emit(instance)
	active_objects_changed.emit(active_objects.size())
	_show_message(
		str(definition.get("display_name", blueprint_id.capitalize()))
		+ " reproduced • "
		+ str(mana_cost)
		+ " mana"
	)
	if print_debug:
		print("Recorded object placed: ", blueprint_id, " at ", instance.global_position)
	return instance


func validate_placement(
	definition: Dictionary,
	ground_position: Vector3,
	yaw_degrees: float = 0.0,
	excluded_support_rid: RID = RID()
) -> Dictionary:
	if actor == null or get_world_3d() == null:
		return {"valid": false, "reason": "No placement world is available."}
	var size: Vector3 = definition.get("size", Vector3.ONE) as Vector3
	var range_limit: float = maxf(float(definition.get("placement_range", 10.0)), 1.0)
	var flat_offset: Vector3 = ground_position - actor.global_position
	flat_offset.y = 0.0
	if flat_offset.length() > range_limit + 0.1:
		return {"valid": false, "reason": "The target is outside reproduction range."}
	var overlapping_object: RecordedObjectInstance = _find_active_overlap(
		size,
		ground_position,
		yaw_degrees
	)
	if overlapping_object != null:
		return {
			"valid": false,
			"reason": "Another reproduced object occupies that space.",
			"active_overlap": overlapping_object.blueprint_id,
		}
	var shape := BoxShape3D.new()
	shape.size = Vector3(
		maxf(size.x * 0.88, 0.1),
		maxf(size.y * 0.86, 0.1),
		maxf(size.z * 0.88, 0.1)
	)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(
		Basis(Vector3.UP, deg_to_rad(yaw_degrees)),
		ground_position + Vector3.UP * (size.y * 0.5 + 0.08)
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = 0xFFFFFFFF
	var exclusions: Array[RID] = []
	if actor is CollisionObject3D:
		exclusions.append((actor as CollisionObject3D).get_rid())
	if excluded_support_rid.is_valid():
		exclusions.append(excluded_support_rid)
	query.exclude = exclusions
	var hits: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(query, 12)
	if not hits.is_empty():
		return {"valid": false, "reason": "Another body occupies that space.", "hits": hits.size()}
	return {"valid": true, "reason": "", "hits": 0}


func clear_spawned_objects() -> void:
	for object: RecordedObjectInstance in active_objects:
		if object != null and is_instance_valid(object):
			object.queue_free()
	active_objects.clear()
	active_objects_changed.emit(0)
	_show_message("All reproduced objects dismissed.")


func get_active_objects() -> Array[RecordedObjectInstance]:
	_prune_active_objects()
	return active_objects.duplicate()


func get_active_count(blueprint_id: String = "") -> int:
	_prune_active_objects()
	if blueprint_id == "":
		return active_objects.size()
	var count: int = 0
	for object: RecordedObjectInstance in active_objects:
		if object.blueprint_id == blueprint_id:
			count += 1
	return count


func get_debug_data() -> Dictionary:
	var selected: String = Catalog.get_selected_blueprint_id()
	return {
		"selected_blueprint": selected,
		"recorded_blueprints": Catalog.get_recorded_blueprint_ids(),
		"placement_active": placement_active,
		"placement_valid": placement_valid,
		"invalid_reason": invalid_reason,
		"target_ground_position": target_ground_position,
		"yaw_degrees": placement_yaw_degrees,
		"active_count": get_active_count(),
		"maximum_total_active": maximum_total_active,
		"preview_visible": preview_root != null and is_instance_valid(preview_root),
		"safe_recorded_object_actor": true,
	}


func _update_target_from_camera() -> void:
	if actor == null or get_world_3d() == null:
		placement_valid = false
		invalid_reason = "No placement world is available."
		return
	var definition: Dictionary = Catalog.get_definition(Catalog.get_selected_blueprint_id())
	var range_limit: float = maxf(float(definition.get("placement_range", 10.0)), 1.0)
	var camera: Camera3D = get_viewport().get_camera_3d()
	var ray_origin: Vector3
	var ray_end: Vector3
	if camera != null:
		var screen_center: Vector2 = get_viewport().get_visible_rect().size * 0.5
		ray_origin = camera.project_ray_origin(screen_center)
		ray_end = ray_origin + camera.project_ray_normal(screen_center) * (range_limit + 18.0)
	else:
		var forward: Vector3 = -actor.global_transform.basis.z
		forward.y = 0.0
		if forward.length_squared() <= 0.01:
			forward = Vector3.FORWARD
		ray_origin = actor.global_position + Vector3.UP * 1.0
		ray_end = actor.global_position + forward.normalized() * range_limit + Vector3.DOWN * 3.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	if actor is CollisionObject3D:
		query.exclude = [(actor as CollisionObject3D).get_rid()]
	query.collision_mask = 0xFFFFFFFF
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	support_rid = RID()
	if not hit.is_empty() and hit.has("position"):
		target_ground_position = hit["position"] as Vector3
		var collider: Object = hit.get("collider")
		if collider is CollisionObject3D:
			support_rid = (collider as CollisionObject3D).get_rid()
	else:
		var forward: Vector3 = -actor.global_transform.basis.z
		forward.y = 0.0
		if forward.length_squared() <= 0.01:
			forward = Vector3.FORWARD
		var raw: Vector3 = actor.global_position + forward.normalized() * minf(range_limit, 6.0)
		var ground_query := PhysicsRayQueryParameters3D.create(
			raw + Vector3.UP * 6.0,
			raw + Vector3.DOWN * 16.0
		)
		if actor is CollisionObject3D:
			ground_query.exclude = [(actor as CollisionObject3D).get_rid()]
		var ground_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ground_query)
		if ground_hit.is_empty():
			placement_valid = false
			invalid_reason = "No stable surface is under the target."
			placement_updated.emit(target_ground_position, false, invalid_reason)
			return
		target_ground_position = ground_hit["position"] as Vector3
		var ground_collider: Object = ground_hit.get("collider")
		if ground_collider is CollisionObject3D:
			support_rid = (ground_collider as CollisionObject3D).get_rid()
	var validation: Dictionary = validate_placement(
		definition,
		target_ground_position,
		placement_yaw_degrees,
		support_rid
	)
	placement_valid = bool(validation.get("valid", false))
	invalid_reason = str(validation.get("reason", ""))
	placement_updated.emit(target_ground_position, placement_valid, invalid_reason)


func _rebuild_preview() -> void:
	_destroy_preview()
	var definition: Dictionary = Catalog.get_definition(Catalog.get_selected_blueprint_id())
	if definition.is_empty() or get_tree().current_scene == null:
		return
	preview_root = Node3D.new()
	preview_root.name = "RecordedObjectPlacementPreview"
	get_tree().current_scene.add_child(preview_root)
	preview_mesh = MeshInstance3D.new()
	preview_mesh.name = "PreviewMesh"
	var size: Vector3 = definition.get("size", Vector3.ONE) as Vector3
	if str(definition.get("behavior", "")) == "blast_barrel":
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = size.x * 0.48
		cylinder.bottom_radius = size.x * 0.5
		cylinder.height = size.y
		cylinder.radial_segments = 18
		preview_mesh.mesh = cylinder
	else:
		var box := BoxMesh.new()
		box.size = size
		preview_mesh.mesh = box
	preview_root.add_child(preview_mesh)


func _update_preview() -> void:
	if preview_root == null or not is_instance_valid(preview_root):
		return
	var definition: Dictionary = Catalog.get_definition(Catalog.get_selected_blueprint_id())
	var size: Vector3 = definition.get("size", Vector3.ONE) as Vector3
	preview_root.global_position = target_ground_position + Vector3.UP * (size.y * 0.5 + 0.025)
	preview_root.global_rotation = Vector3(0.0, deg_to_rad(placement_yaw_degrees), 0.0)
	if preview_mesh != null:
		preview_mesh.material_override = _make_preview_material(
			Color(0.28, 1.0, 0.56, 0.48)
			if placement_valid
			else Color(1.0, 0.22, 0.16, 0.48)
		)


func _destroy_preview() -> void:
	if preview_root != null and is_instance_valid(preview_root):
		preview_root.queue_free()
	preview_root = null
	preview_mesh = null


func _find_active_overlap(
	candidate_size: Vector3,
	ground_position: Vector3,
	yaw_degrees: float
) -> RecordedObjectInstance:
	_prune_active_objects()
	var candidate_center: Vector3 = (
		ground_position + Vector3.UP * (candidate_size.y * 0.5 + 0.025)
	)
	var candidate_half: Vector3 = _rotated_half_extents(
		candidate_size,
		deg_to_rad(yaw_degrees)
	)
	for object: RecordedObjectInstance in active_objects:
		if object == null or not is_instance_valid(object):
			continue
		var object_half: Vector3 = _rotated_half_extents(
			object.body_size,
			object.global_rotation.y
		)
		var delta: Vector3 = object.global_position - candidate_center
		if (
			absf(delta.x) < (candidate_half.x + object_half.x) * 0.92
			and absf(delta.y) < (candidate_half.y + object_half.y) * 0.92
			and absf(delta.z) < (candidate_half.z + object_half.z) * 0.92
		):
			return object
	return null


func _rotated_half_extents(size: Vector3, yaw_radians: float) -> Vector3:
	var cosine: float = absf(cos(yaw_radians))
	var sine: float = absf(sin(yaw_radians))
	return Vector3(
		(size.x * cosine + size.z * sine) * 0.5,
		size.y * 0.5,
		(size.x * sine + size.z * cosine) * 0.5
	)


func _enforce_active_limits(blueprint_id: String, maximum_for_blueprint: int) -> void:
	_prune_active_objects()
	while get_active_count(blueprint_id) >= maxi(maximum_for_blueprint, 1):
		_dismiss_oldest(blueprint_id)
	while active_objects.size() >= maxi(maximum_total_active, 1):
		_dismiss_oldest("")


func _dismiss_oldest(blueprint_id: String) -> void:
	for object: RecordedObjectInstance in active_objects:
		if blueprint_id != "" and object.blueprint_id != blueprint_id:
			continue
		active_objects.erase(object)
		if object != null and is_instance_valid(object):
			object.queue_free()
		active_objects_changed.emit(active_objects.size())
		return


func _on_object_exiting(object: RecordedObjectInstance) -> void:
	active_objects.erase(object)
	active_objects_changed.emit(active_objects.size())


func _prune_active_objects() -> void:
	var survivors: Array[RecordedObjectInstance] = []
	for object: RecordedObjectInstance in active_objects:
		if object != null and is_instance_valid(object) and not object.is_queued_for_deletion():
			survivors.append(object)
	if survivors.size() != active_objects.size():
		active_objects = survivors
		active_objects_changed.emit(active_objects.size())


func _make_preview_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	return material


func _show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)
	elif print_debug:
		print(message)
