extends Node3D
class_name EngineeringBuildManager

signal build_saved(build_id: String, newly_saved: bool)
signal build_selected(build_id: String)
signal placement_started(build_id: String)
signal placement_updated(position: Vector3, valid: bool, reason: String)
signal placement_cancelled
signal build_placed(build: EngineeringBuildInstance)
signal active_builds_changed(count: int)

const Catalog = preload("res://scripts/builds/engineering_build_catalog.gd")
const BuildInstanceScript = preload(
	"res://scripts/builds/engineering_build_instance.gd"
)

@export var actor_path: NodePath
@export_range(1, 8, 1) var maximum_total_active: int = 4
@export_range(15.0, 180.0, 15.0) var rotation_step_degrees: float = 90.0
@export var keyboard_controls_enabled: bool = true
@export var controller_controls_enabled: bool = true
@export var print_debug: bool = false

var actor: Node3D
var active_builds: Array[EngineeringBuildInstance] = []
var placement_active: bool = false
var placement_yaw_degrees: float = 0.0
var target_ground_position: Vector3 = Vector3.ZERO
var placement_valid: bool = false
var invalid_reason: String = ""
var support_rid: RID
var preview_root: Node3D
var preview_mesh: MeshInstance3D


func _ready() -> void:
	actor = get_node_or_null(actor_path) as Node3D if actor_path != NodePath() else null
	if actor == null and get_parent() is Node3D:
		actor = get_parent() as Node3D
	add_to_group("engineering_build_manager")
	add_to_group("debuggable")


func bind_actor(new_actor: Node3D) -> void:
	actor = new_actor


func _process(_delta: float) -> void:
	_prune_active_builds()
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
					cycle_build(-1)
				KEY_E:
					cycle_build(1)
				KEY_R:
					rotate_preview(1)
				KEY_F1, KEY_F2, KEY_F3, KEY_F4:
					select_build_by_index(int(key_event.keycode - KEY_F1))
				KEY_F8:
					clear_spawned_builds()
				_:
					return
			get_viewport().set_input_as_handled()
			return
	if keyboard_controls_enabled and event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and placement_active:
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				confirm_placement()
			elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
				cancel_placement()
			else:
				return
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
				cycle_build(-1)
			JOY_BUTTON_RIGHT_SHOULDER:
				cycle_build(1)
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


func save_build(build_id: String) -> Dictionary:
	var result: Dictionary = Catalog.save_build(build_id)
	if bool(result.get("ok", false)):
		var newly_saved: bool = bool(result.get("newly_saved", false))
		build_saved.emit(build_id, newly_saved)
		select_build(build_id)
		_show_message(
			("Construction saved: " if newly_saved else "Construction selected: ")
			+ str((result.get("definition", {}) as Dictionary).get(
				"display_name",
				build_id.capitalize()
			))
		)
	else:
		var missing: Array = result.get("missing", []) as Array
		_show_message(
			"Missing recorded components: "
			+ (", ".join(missing) if not missing.is_empty() else "unknown")
		)
	return result


func select_build(build_id: String) -> bool:
	if not Catalog.select_build(build_id):
		_show_message("That construction has not been saved yet.")
		return false
	build_selected.emit(build_id)
	if placement_active:
		_rebuild_preview()
		_update_target_from_camera()
		_update_preview()
	return true


func select_build_by_index(index: int) -> bool:
	if index < 0 or index >= Catalog.BUILD_ORDER.size():
		return false
	return select_build(Catalog.BUILD_ORDER[index])


func cycle_build(direction: int) -> bool:
	var saved: Array[String] = Catalog.get_saved_build_ids()
	if saved.is_empty():
		_show_message("Save a construction before attempting reproduction.")
		return false
	var selected: String = Catalog.get_selected_build_id()
	var index: int = saved.find(selected)
	if index < 0:
		index = 0
	else:
		index = posmod(index + signi(direction), saved.size())
	var changed: bool = select_build(saved[index])
	if changed:
		_show_message(
			"Engineering build: "
			+ str(Catalog.get_definition(saved[index]).get(
				"display_name",
				saved[index].capitalize()
			))
		)
	return changed


func toggle_placement() -> void:
	if placement_active:
		cancel_placement()
	else:
		begin_placement()


func begin_placement() -> bool:
	var build_id: String = Catalog.get_selected_build_id()
	if build_id == "" or not Catalog.is_saved(build_id):
		_show_message("No saved engineering build is selected.")
		return false
	placement_active = true
	placement_yaw_degrees = 0.0
	_rebuild_preview()
	_update_target_from_camera()
	_update_preview()
	placement_started.emit(build_id)
	_show_message(
		"Placing "
		+ str(Catalog.get_definition(build_id).get("display_name", build_id.capitalize()))
		+ "."
	)
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


func confirm_placement() -> EngineeringBuildInstance:
	if not placement_active:
		return null
	if not placement_valid:
		_show_message(invalid_reason if invalid_reason != "" else "The build cannot fit there.")
		return null
	var instance: EngineeringBuildInstance = place_selected_at(
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
) -> EngineeringBuildInstance:
	var build_id: String = Catalog.get_selected_build_id()
	var definition: Dictionary = Catalog.get_definition(build_id)
	if definition.is_empty() or not Catalog.is_saved(build_id):
		return null
	var validation: Dictionary = validate_placement(
		definition,
		ground_position,
		yaw_degrees,
		excluded_support_rid
	)
	if not ignore_validation and not bool(validation.get("valid", false)):
		invalid_reason = str(validation.get("reason", "The build cannot fit there."))
		return null
	var mana_cost: int = maxi(int(definition.get("mana_cost", 0)), 0)
	if not ignore_cost and mana_cost > 0 and not GameState.spend_mana(mana_cost):
		_show_message(
			"Not enough mana to reproduce "
			+ str(definition.get("display_name", "that construction"))
			+ "."
		)
		return null
	_enforce_active_limits(build_id, int(definition.get("maximum_active", 1)))
	var instance := BuildInstanceScript.new() as EngineeringBuildInstance
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
	active_builds.append(instance)
	instance.tree_exiting.connect(_on_build_exiting.bind(instance))
	build_placed.emit(instance)
	active_builds_changed.emit(active_builds.size())
	_show_message(
		str(definition.get("display_name", build_id.capitalize()))
		+ " constructed • "
		+ str(mana_cost)
		+ " mana"
	)
	if print_debug:
		print("Engineering build placed: ", build_id, " at ", instance.global_position)
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
	var range_limit: float = maxf(float(definition.get("placement_range", 12.0)), 1.0)
	var flat_offset: Vector3 = ground_position - actor.global_position
	flat_offset.y = 0.0
	if flat_offset.length() > range_limit + 0.1:
		return {"valid": false, "reason": "The target is outside construction range."}
	var overlap: EngineeringBuildInstance = _find_active_overlap(
		size,
		ground_position,
		yaw_degrees
	)
	if overlap != null:
		return {
			"valid": false,
			"reason": "Another engineering build occupies that space.",
			"active_overlap": overlap.build_id,
		}
	var shape := BoxShape3D.new()
	shape.size = Vector3(
		maxf(size.x * 0.9, 0.1),
		maxf(size.y * 0.88, 0.1),
		maxf(size.z * 0.9, 0.1)
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
	var hits: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(query, 16)
	if not hits.is_empty():
		return {
			"valid": false,
			"reason": "Another body occupies that construction space.",
			"hits": hits.size(),
		}
	return {"valid": true, "reason": "", "hits": 0}


func clear_spawned_builds() -> void:
	for build: EngineeringBuildInstance in active_builds:
		if build != null and is_instance_valid(build):
			build.queue_free()
	active_builds.clear()
	active_builds_changed.emit(0)
	_show_message("All reproduced engineering builds dismissed.")


func get_active_builds() -> Array[EngineeringBuildInstance]:
	_prune_active_builds()
	return active_builds.duplicate()


func get_active_count(build_id: String = "") -> int:
	_prune_active_builds()
	if build_id == "":
		return active_builds.size()
	var count: int = 0
	for build: EngineeringBuildInstance in active_builds:
		if build.build_id == build_id:
			count += 1
	return count


func get_debug_data() -> Dictionary:
	return {
		"selected_build": Catalog.get_selected_build_id(),
		"saved_builds": Catalog.get_saved_build_ids(),
		"placement_active": placement_active,
		"placement_valid": placement_valid,
		"invalid_reason": invalid_reason,
		"target_ground_position": target_ground_position,
		"yaw_degrees": placement_yaw_degrees,
		"active_count": get_active_count(),
		"maximum_total_active": maximum_total_active,
		"preview_visible": preview_root != null and is_instance_valid(preview_root),
	}


func _update_target_from_camera() -> void:
	if actor == null or get_world_3d() == null:
		placement_valid = false
		invalid_reason = "No placement world is available."
		return
	var definition: Dictionary = Catalog.get_definition(Catalog.get_selected_build_id())
	var range_limit: float = maxf(float(definition.get("placement_range", 12.0)), 1.0)
	var camera: Camera3D = get_viewport().get_camera_3d()
	var ray_origin: Vector3
	var ray_end: Vector3
	if camera != null:
		var screen_center: Vector2 = get_viewport().get_visible_rect().size * 0.5
		ray_origin = camera.project_ray_origin(screen_center)
		ray_end = ray_origin + camera.project_ray_normal(screen_center) * (range_limit + 20.0)
	else:
		var forward: Vector3 = -actor.global_transform.basis.z
		forward.y = 0.0
		if forward.length_squared() <= 0.01:
			forward = Vector3.FORWARD
		ray_origin = actor.global_position + Vector3.UP * 1.0
		ray_end = actor.global_position + forward.normalized() * range_limit + Vector3.DOWN * 4.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	if actor is CollisionObject3D:
		query.exclude = [(actor as CollisionObject3D).get_rid()]
	query.collision_mask = 0xFFFFFFFF
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	support_rid = RID()
	if not hit.is_empty():
		target_ground_position = hit.get("position", actor.global_position) as Vector3
		var collider: Object = hit.get("collider")
		if collider is CollisionObject3D:
			support_rid = (collider as CollisionObject3D).get_rid()
	else:
		var flat_forward: Vector3 = ray_end - ray_origin
		flat_forward.y = 0.0
		if flat_forward.length_squared() <= 0.01:
			flat_forward = -actor.global_transform.basis.z
		target_ground_position = (
			actor.global_position
			+ flat_forward.normalized() * minf(range_limit, 7.0)
		)
		target_ground_position.y = actor.global_position.y - 1.0
	var result: Dictionary = validate_placement(
		definition,
		target_ground_position,
		placement_yaw_degrees,
		support_rid
	)
	placement_valid = bool(result.get("valid", false))
	invalid_reason = str(result.get("reason", ""))
	placement_updated.emit(target_ground_position, placement_valid, invalid_reason)


func _rebuild_preview() -> void:
	_destroy_preview()
	var definition: Dictionary = Catalog.get_definition(Catalog.get_selected_build_id())
	if definition.is_empty():
		return
	preview_root = Node3D.new()
	preview_root.name = "EngineeringBuildPreview"
	add_child(preview_root)
	preview_mesh = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = definition.get("size", Vector3.ONE) as Vector3
	preview_mesh.mesh = mesh
	preview_mesh.material_override = _make_preview_material(
		definition.get("color", Color(0.4, 0.8, 1.0, 1.0)) as Color
	)
	preview_root.add_child(preview_mesh)


func _update_preview() -> void:
	if preview_root == null or not is_instance_valid(preview_root):
		return
	var definition: Dictionary = Catalog.get_definition(Catalog.get_selected_build_id())
	var size: Vector3 = definition.get("size", Vector3.ONE) as Vector3
	preview_root.global_position = target_ground_position + Vector3.UP * (size.y * 0.5 + 0.025)
	preview_root.global_rotation = Vector3(0.0, deg_to_rad(placement_yaw_degrees), 0.0)
	var material := preview_mesh.material_override as StandardMaterial3D
	if material != null:
		material.albedo_color = (
			Color(0.24, 0.96, 0.5, 0.42)
			if placement_valid
			else Color(1.0, 0.2, 0.18, 0.42)
		)


func _destroy_preview() -> void:
	if preview_root != null and is_instance_valid(preview_root):
		preview_root.queue_free()
	preview_root = null
	preview_mesh = null


func _find_active_overlap(
	size: Vector3,
	ground_position: Vector3,
	yaw_degrees: float
) -> EngineeringBuildInstance:
	var candidate_center: Vector3 = ground_position + Vector3.UP * (size.y * 0.5)
	var candidate_basis := Basis(Vector3.UP, deg_to_rad(yaw_degrees))
	var candidate_half: Vector3 = size * 0.46
	for build: EngineeringBuildInstance in active_builds:
		if build == null or not is_instance_valid(build):
			continue
		var other_size: Vector3 = build.body_size
		var offset: Vector3 = build.global_position - candidate_center
		var local_offset: Vector3 = candidate_basis.inverse() * offset
		var other_radius_x: float = maxf(other_size.x, other_size.z) * 0.5
		var other_radius_z: float = other_radius_x
		if (
			absf(local_offset.x) < candidate_half.x + other_radius_x * 0.9
			and absf(local_offset.y) < candidate_half.y + other_size.y * 0.45
			and absf(local_offset.z) < candidate_half.z + other_radius_z * 0.9
		):
			return build
	return null


func _enforce_active_limits(build_id: String, maximum_active: int) -> void:
	_prune_active_builds()
	while get_active_count(build_id) >= maxi(maximum_active, 1):
		var oldest: EngineeringBuildInstance
		for build: EngineeringBuildInstance in active_builds:
			if build.build_id != build_id:
				continue
			if oldest == null or build.spawned_at_msec < oldest.spawned_at_msec:
				oldest = build
		if oldest == null:
			break
		active_builds.erase(oldest)
		oldest.queue_free()
	while active_builds.size() >= maximum_total_active:
		var oldest_global: EngineeringBuildInstance = active_builds[0]
		for build: EngineeringBuildInstance in active_builds:
			if build.spawned_at_msec < oldest_global.spawned_at_msec:
				oldest_global = build
		active_builds.erase(oldest_global)
		oldest_global.queue_free()


func _prune_active_builds() -> void:
	for index: int in range(active_builds.size() - 1, -1, -1):
		var build: EngineeringBuildInstance = active_builds[index]
		if build == null or not is_instance_valid(build) or build.is_queued_for_deletion():
			active_builds.remove_at(index)


func _on_build_exiting(build: EngineeringBuildInstance) -> void:
	active_builds.erase(build)
	active_builds_changed.emit(active_builds.size())


func _show_message(message: String) -> void:
	if message == "":
		return
	var game_ui: Node = get_tree().get_first_node_in_group("game_ui")
	if game_ui != null and game_ui.has_method("show_system_message"):
		game_ui.call("show_system_message", message)
	elif print_debug:
		print(message)


func _make_preview_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, 0.42)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
