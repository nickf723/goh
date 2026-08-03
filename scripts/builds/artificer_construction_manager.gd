extends Node3D
class_name ArtificerConstructionManager

signal mode_started(mode_id: String)
signal mode_cancelled(mode_id: String)
signal placement_updated(position: Vector3, valid: bool, reason: String)
signal part_placed(part_id: String, part_count: int)
signal part_removed(part_id: String, part_count: int)
signal blueprint_finalized(build_id: String, definition: Dictionary)
signal contraption_deployed(contraption: ArtificerContraptionInstance)
signal active_contraptions_changed(count: int)

const PartCatalog = preload(
	"res://scripts/builds/engineering_part_catalog.gd"
)
const BuildCatalog = preload(
	"res://scripts/builds/engineering_build_catalog.gd"
)
const ContraptionScript = preload(
	"res://scripts/builds/artificer_contraption_instance.gd"
)

const MODE_NONE: String = ""
const MODE_ASSEMBLY: String = "assembly"
const MODE_DEPLOY: String = "deploy"

@export_range(2, 20, 1) var maximum_draft_parts: int = 12
@export_range(1, 8, 1) var maximum_active_contraptions: int = 3
@export_range(4.0, 24.0, 0.5) var construction_range: float = 14.0
@export_range(0.25, 2.0, 0.05) var depth_step: float = 0.75
@export_range(0.0, 12.0, 0.25) var maximum_depth_offset: float = 6.0
@export_range(15.0, 90.0, 7.5) var rotation_step_degrees: float = 22.5
@export_range(0.25, 1.0, 0.25) var snap_increment: float = 0.5
@export_range(1.0, 6.0, 0.25) var connection_distance: float = 3.75
@export var keyboard_controls_enabled: bool = true
@export var print_debug: bool = false

var actor: Node3D
var mode: String = MODE_NONE
var placement_yaw_degrees: float = 0.0
var placement_depth_offset: float = 0.0
var target_world_position: Vector3 = Vector3.ZERO
var target_ground_position: Vector3 = Vector3.ZERO
var placement_valid: bool = false
var invalid_reason: String = ""
var support_rid: RID

var preview_root: Node3D
var preview_mesh: MeshInstance3D
var draft_root: Node3D
var draft_parts: Array[Dictionary] = []
var draft_part_nodes: Array[Node3D] = []
var active_contraptions: Array[ArtificerContraptionInstance] = []
var selected_deploy_build_id: String = ""


func _ready() -> void:
	actor = get_parent() as Node3D
	PartCatalog.ensure_prototype_baseline()
	add_to_group("artificer_construction_manager")
	add_to_group("debuggable")


func bind_actor(new_actor: Node3D) -> void:
	actor = new_actor


func _process(_delta: float) -> void:
	_prune_active_contraptions()
	if mode != MODE_NONE:
		_update_target_from_camera()
		_update_preview()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or mode == MODE_NONE:
		return
	if keyboard_controls_enabled and event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		match key_event.keycode:
			KEY_Q:
				adjust_depth(-1)
			KEY_E:
				adjust_depth(1)
			KEY_R:
				rotate_preview(1)
			KEY_Z:
				cycle_part(-1)
			KEY_X:
				cycle_part(1)
			KEY_BACKSPACE:
				undo_last_part()
			KEY_ENTER:
				finalize_draft()
			KEY_ESCAPE:
				cancel_mode()
			_:
				return
		get_viewport().set_input_as_handled()
		return
	if keyboard_controls_enabled and event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed:
			return
		match mouse_event.button_index:
			MOUSE_BUTTON_LEFT:
				confirm_placement()
			MOUSE_BUTTON_RIGHT:
				cancel_mode()
			MOUSE_BUTTON_WHEEL_UP:
				adjust_depth(1)
			MOUSE_BUTTON_WHEEL_DOWN:
				adjust_depth(-1)
			_:
				return
		get_viewport().set_input_as_handled()


func begin_assembly() -> bool:
	PartCatalog.ensure_prototype_baseline()
	if PartCatalog.get_selected_part_id() == "":
		_show_message("No engineering part is prepared.")
		return false
	_set_mode(MODE_ASSEMBLY)
	_show_message(
		"Artificer Assembly: "
		+ str(PartCatalog.get_definition(
			PartCatalog.get_selected_part_id()
		).get("display_name", "Part"))
	)
	return true


func begin_deploy(build_id: String = "") -> bool:
	var resolved_id: String = build_id
	if resolved_id == "":
		resolved_id = BuildCatalog.get_selected_build_id()
	if resolved_id == "" or not BuildCatalog.is_saved(resolved_id):
		_show_message("No saved contraption is prepared.")
		return false
	if not BuildCatalog.select_build(resolved_id):
		return false
	selected_deploy_build_id = resolved_id
	_set_mode(MODE_DEPLOY)
	_show_message(
		"Deploying "
		+ str(BuildCatalog.get_definition(resolved_id).get(
			"display_name",
			resolved_id.capitalize()
		))
	)
	return true


func _set_mode(next_mode: String) -> void:
	var previous: String = mode
	mode = next_mode
	placement_yaw_degrees = 0.0
	placement_depth_offset = 0.0
	placement_valid = false
	invalid_reason = ""
	_rebuild_preview()
	_update_target_from_camera()
	_update_preview()
	if previous != MODE_NONE and previous != next_mode:
		mode_cancelled.emit(previous)
	mode_started.emit(mode)


func cancel_mode() -> void:
	if mode == MODE_NONE:
		return
	var previous: String = mode
	mode = MODE_NONE
	placement_valid = false
	invalid_reason = ""
	placement_depth_offset = 0.0
	_destroy_preview()
	mode_cancelled.emit(previous)


func clear_draft() -> void:
	for node: Node3D in draft_part_nodes:
		if node != null and is_instance_valid(node):
			node.queue_free()
	draft_part_nodes.clear()
	draft_parts.clear()
	if draft_root != null and is_instance_valid(draft_root):
		draft_root.queue_free()
	draft_root = null
	if mode == MODE_ASSEMBLY:
		_rebuild_preview()


func adjust_depth(direction: int) -> void:
	if mode == MODE_NONE or direction == 0:
		return
	placement_depth_offset = clampf(
		placement_depth_offset + depth_step * signi(direction),
		-maximum_depth_offset,
		maximum_depth_offset
	)
	_update_target_from_camera()
	_update_preview()


func rotate_preview(direction: int) -> void:
	if mode == MODE_NONE or direction == 0:
		return
	placement_yaw_degrees = wrapf(
		placement_yaw_degrees + rotation_step_degrees * signi(direction),
		0.0,
		360.0
	)
	_update_preview()


func cycle_part(direction: int) -> String:
	if mode != MODE_ASSEMBLY:
		return PartCatalog.get_selected_part_id()
	var selected: String = PartCatalog.cycle_selected_part(direction)
	_rebuild_preview()
	_update_target_from_camera()
	_update_preview()
	return selected


func confirm_placement() -> Node:
	if mode == MODE_ASSEMBLY:
		return place_prepared_part_at(
			target_world_position,
			placement_yaw_degrees,
			false
		)
	if mode == MODE_DEPLOY:
		var instance: ArtificerContraptionInstance = deploy_selected_at(
			target_ground_position,
			placement_yaw_degrees,
			false,
			false,
			support_rid
		)
		if instance != null:
			cancel_mode()
		return instance
	return null


func place_prepared_part_at(
	world_center: Vector3,
	yaw_degrees: float = 0.0,
	ignore_validation: bool = false
) -> Node3D:
	var part_id: String = PartCatalog.get_selected_part_id()
	var definition: Dictionary = PartCatalog.get_definition(part_id)
	if definition.is_empty() or not PartCatalog.is_unlocked(part_id):
		_show_message("That engineering part has not been learned.")
		return null
	if draft_parts.size() >= maximum_draft_parts:
		_show_message("This draft already uses the twelve-part prototype limit.")
		return null

	var size: Vector3 = definition.get("size", Vector3.ONE) as Vector3
	if draft_root == null or not is_instance_valid(draft_root):
		_create_draft_root(world_center - Vector3.UP * size.y * 0.5)
	var local_center: Vector3 = draft_root.to_local(world_center)
	local_center = Vector3(
		snappedf(local_center.x, snap_increment),
		snappedf(maxf(local_center.y, size.y * 0.5), snap_increment),
		snappedf(local_center.z, snap_increment)
	)
	var validation: Dictionary = validate_draft_part(
		part_id,
		local_center,
		yaw_degrees
	)
	if not ignore_validation and not bool(validation.get("valid", false)):
		invalid_reason = str(validation.get("reason", "That part cannot attach there."))
		_show_message(invalid_reason)
		return null

	var part: Dictionary = {
		"part_id": part_id,
		"position": local_center,
		"yaw_degrees": snappedf(yaw_degrees, rotation_step_degrees),
	}
	draft_parts.append(part)
	var node: Node3D = _create_draft_part_node(part, draft_parts.size())
	draft_part_nodes.append(node)
	part_placed.emit(part_id, draft_parts.size())
	placement_depth_offset = 0.0
	_update_target_from_camera()
	_update_preview()
	return node


func undo_last_part() -> bool:
	if draft_parts.is_empty():
		_show_message("The artificer draft is already empty.")
		return false
	var removed: Dictionary = draft_parts.pop_back()
	var node: Node3D = draft_part_nodes.pop_back()
	if node != null and is_instance_valid(node):
		node.queue_free()
	part_removed.emit(str(removed.get("part_id", "")), draft_parts.size())
	if draft_parts.is_empty():
		if draft_root != null and is_instance_valid(draft_root):
			draft_root.queue_free()
		draft_root = null
	_update_target_from_camera()
	_update_preview()
	return true


func finalize_draft(
	ignore_cost: bool = false,
	manifest_immediately: bool = true
) -> Dictionary:
	if draft_parts.size() < 2:
		_show_message("Attach at least two engineering parts before saving a contraption.")
		return {"ok": false, "error": "not enough parts"}
	var slot_id: String = BuildCatalog.get_selected_custom_slot()
	var result: Dictionary = BuildCatalog.save_custom_blueprint(
		slot_id,
		draft_parts
	)
	if not bool(result.get("ok", false)):
		_show_message(str(result.get("error", "The contraption could not be saved.")))
		return result
	var definition: Dictionary = result.get("definition", {}) as Dictionary
	var manifestation: ArtificerContraptionInstance
	if manifest_immediately:
		var cost: int = maxi(int(definition.get("mana_cost", 0)), 0)
		if ignore_cost or cost <= 0 or GameState.spend_mana(cost):
			var origin: Vector3 = (
				draft_root.global_position
				if draft_root != null and is_instance_valid(draft_root)
				else actor.global_position
			)
			manifestation = _manifest_definition_at(
				definition,
				origin,
				0.0
			)
		else:
			_show_message("Blueprint saved, but Grace lacks the mana to manifest it now.")
	blueprint_finalized.emit(slot_id, definition)
	clear_draft()
	cancel_mode()
	_show_message(
		str(definition.get("display_name", slot_id.capitalize()))
		+ " saved as an Artificer blueprint."
	)
	result["manifestation"] = manifestation
	return result


func deploy_selected_at(
	ground_position: Vector3,
	yaw_degrees: float = 0.0,
	ignore_cost: bool = false,
	ignore_validation: bool = false,
	excluded_support_rid: RID = RID()
) -> ArtificerContraptionInstance:
	var build_id: String = selected_deploy_build_id
	if build_id == "":
		build_id = BuildCatalog.get_selected_build_id()
	var definition: Dictionary = BuildCatalog.get_definition(build_id)
	if definition.is_empty() or not BuildCatalog.is_saved(build_id):
		return null
	var validation: Dictionary = validate_deploy(
		definition,
		ground_position,
		yaw_degrees,
		excluded_support_rid
	)
	if not ignore_validation and not bool(validation.get("valid", false)):
		invalid_reason = str(validation.get("reason", "The contraption cannot fit there."))
		_show_message(invalid_reason)
		return null
	var cost: int = maxi(int(definition.get("mana_cost", 0)), 0)
	if not ignore_cost and cost > 0 and not GameState.spend_mana(cost):
		_show_message(
			"Not enough mana to deploy "
			+ str(definition.get("display_name", "that contraption"))
			+ "."
		)
		return null
	_enforce_active_limit()
	return _manifest_definition_at(definition, ground_position, yaw_degrees)


func _manifest_definition_at(
	definition: Dictionary,
	ground_position: Vector3,
	yaw_degrees: float
) -> ArtificerContraptionInstance:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return null
	var instance := ContraptionScript.new() as ArtificerContraptionInstance
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


func validate_draft_part(
	part_id: String,
	local_center: Vector3,
	yaw_degrees: float
) -> Dictionary:
	if not PartCatalog.has_part(part_id):
		return {"valid": false, "reason": "Unknown engineering part."}
	if draft_parts.is_empty():
		return {"valid": true, "reason": ""}
	var candidate_size: Vector3 = PartCatalog.get_part_size(part_id)
	var candidate_half: Vector3 = _rotated_half_extents(
		candidate_size,
		deg_to_rad(yaw_degrees)
	)
	var connected: bool = false
	for part: Dictionary in draft_parts:
		var existing_id: String = str(part.get("part_id", ""))
		var existing_position: Vector3 = part.get("position", Vector3.ZERO) as Vector3
		var existing_half: Vector3 = _rotated_half_extents(
			PartCatalog.get_part_size(existing_id),
			deg_to_rad(float(part.get("yaw_degrees", 0.0)))
		)
		var delta: Vector3 = existing_position - local_center
		if (
			absf(delta.x) < (candidate_half.x + existing_half.x) * 0.82
			and absf(delta.y) < (candidate_half.y + existing_half.y) * 0.82
			and absf(delta.z) < (candidate_half.z + existing_half.z) * 0.82
		):
			return {"valid": false, "reason": "That engineering part overlaps the draft."}
		if delta.length() <= connection_distance + candidate_half.length() * 0.35:
			connected = true
	if not connected:
		return {"valid": false, "reason": "Move the part close enough to attach to the draft."}
	return {"valid": true, "reason": ""}


func validate_deploy(
	definition: Dictionary,
	ground_position: Vector3,
	yaw_degrees: float = 0.0,
	excluded_support_rid: RID = RID()
) -> Dictionary:
	if actor == null or get_world_3d() == null:
		return {"valid": false, "reason": "No construction world is available."}
	var size: Vector3 = definition.get("size", Vector3.ONE) as Vector3
	var flat_offset: Vector3 = ground_position - actor.global_position
	flat_offset.y = 0.0
	if flat_offset.length() > float(definition.get("placement_range", construction_range)) + 0.1:
		return {"valid": false, "reason": "The target is outside Artificer deployment range."}
	for active: ArtificerContraptionInstance in active_contraptions:
		if active == null or not is_instance_valid(active):
			continue
		var half_a: Vector3 = _rotated_half_extents(size, deg_to_rad(yaw_degrees))
		var half_b: Vector3 = _rotated_half_extents(
			active.body_size,
			active.global_rotation.y
		)
		var center_a: Vector3 = ground_position + Vector3.UP * size.y * 0.5
		var center_b: Vector3 = active.global_position + Vector3.UP * active.body_size.y * 0.5
		var delta: Vector3 = center_b - center_a
		if (
			absf(delta.x) < (half_a.x + half_b.x) * 0.9
			and absf(delta.y) < (half_a.y + half_b.y) * 0.9
			and absf(delta.z) < (half_a.z + half_b.z) * 0.9
		):
			return {"valid": false, "reason": "Another contraption occupies that space."}
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
	var hits: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(query, 20)
	if not hits.is_empty():
		return {"valid": false, "reason": "Another body occupies that deployment space."}
	return {"valid": true, "reason": ""}


func clear_active_contraptions() -> void:
	for instance: ArtificerContraptionInstance in active_contraptions:
		if instance != null and is_instance_valid(instance):
			instance.queue_free()
	active_contraptions.clear()
	active_contraptions_changed.emit(0)


func get_active_count() -> int:
	_prune_active_contraptions()
	return active_contraptions.size()


func _update_target_from_camera() -> void:
	if actor == null or get_world_3d() == null or mode == MODE_NONE:
		placement_valid = false
		invalid_reason = "No construction world is available."
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var screen_center: Vector2 = get_viewport().get_visible_rect().size * 0.5
	var ray_origin: Vector3 = camera.project_ray_origin(screen_center)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_center).normalized()
	var ray_end: Vector3 = ray_origin + ray_direction * (construction_range + 20.0)
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	if actor is CollisionObject3D:
		query.exclude = [(actor as CollisionObject3D).get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var base_distance: float = 6.0
	if not hit.is_empty():
		base_distance = ray_origin.distance_to(hit.get("position", ray_origin + ray_direction * 6.0) as Vector3)
	var distance: float = clampf(
		base_distance + placement_depth_offset,
		2.0,
		construction_range
	)
	var free_target: Vector3 = ray_origin + ray_direction * distance

	if mode == MODE_ASSEMBLY:
		var part_id: String = PartCatalog.get_selected_part_id()
		var size: Vector3 = PartCatalog.get_part_size(part_id)
		if draft_root == null or not is_instance_valid(draft_root):
			var ground_query := PhysicsRayQueryParameters3D.create(
				free_target + Vector3.UP * 8.0,
				free_target + Vector3.DOWN * 22.0
			)
			if actor is CollisionObject3D:
				ground_query.exclude = [(actor as CollisionObject3D).get_rid()]
			var ground_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ground_query)
			if ground_hit.is_empty():
				placement_valid = false
				invalid_reason = "No stable surface is beneath the first engineering part."
				return
			target_world_position = (
				ground_hit.get("position", free_target) as Vector3
			) + Vector3.UP * size.y * 0.5
			placement_valid = true
			invalid_reason = ""
		else:
			var local_center: Vector3 = draft_root.to_local(free_target)
			local_center = Vector3(
				snappedf(local_center.x, snap_increment),
				snappedf(maxf(local_center.y, size.y * 0.5), snap_increment),
				snappedf(local_center.z, snap_increment)
			)
			target_world_position = draft_root.to_global(local_center)
			var validation: Dictionary = validate_draft_part(
				part_id,
				local_center,
				placement_yaw_degrees
			)
			placement_valid = bool(validation.get("valid", false))
			invalid_reason = str(validation.get("reason", ""))
		placement_updated.emit(target_world_position, placement_valid, invalid_reason)
		return

	var raw_ground: Vector3 = free_target
	var down_query := PhysicsRayQueryParameters3D.create(
		raw_ground + Vector3.UP * 10.0,
		raw_ground + Vector3.DOWN * 24.0
	)
	if actor is CollisionObject3D:
		down_query.exclude = [(actor as CollisionObject3D).get_rid()]
	var ground_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(down_query)
	if ground_hit.is_empty():
		placement_valid = false
		invalid_reason = "No stable surface is beneath that deployment."
		return
	target_ground_position = ground_hit.get("position", raw_ground) as Vector3
	support_rid = RID()
	var collider: Object = ground_hit.get("collider")
	if collider is CollisionObject3D:
		support_rid = (collider as CollisionObject3D).get_rid()
	var definition: Dictionary = BuildCatalog.get_definition(selected_deploy_build_id)
	var validation: Dictionary = validate_deploy(
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
	if mode == MODE_NONE or get_tree().current_scene == null:
		return
	preview_root = Node3D.new()
	preview_root.name = "ArtificerPlacementPreview"
	get_tree().current_scene.add_child(preview_root)
	preview_mesh = MeshInstance3D.new()
	preview_mesh.name = "PreviewMesh"
	var size: Vector3 = Vector3.ONE
	var shape_id: String = "box"
	if mode == MODE_ASSEMBLY:
		var part_definition: Dictionary = PartCatalog.get_definition(
			PartCatalog.get_selected_part_id()
		)
		size = part_definition.get("size", Vector3.ONE) as Vector3
		shape_id = str(part_definition.get("shape", "box"))
	else:
		size = BuildCatalog.get_definition(selected_deploy_build_id).get(
			"size",
			Vector3.ONE
		) as Vector3
	if shape_id == "cylinder":
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = size.x * 0.5
		cylinder.bottom_radius = size.z * 0.5
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
	if mode == MODE_ASSEMBLY:
		preview_root.global_position = target_world_position
	else:
		var size: Vector3 = BuildCatalog.get_definition(selected_deploy_build_id).get(
			"size",
			Vector3.ONE
		) as Vector3
		preview_root.global_position = target_ground_position + Vector3.UP * size.y * 0.5
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


func _create_draft_root(ground_position: Vector3) -> void:
	draft_root = Node3D.new()
	draft_root.name = "ArtificerDraft"
	get_tree().current_scene.add_child(draft_root)
	draft_root.global_position = ground_position
	draft_root.add_to_group("artificer_draft")


func _create_draft_part_node(part: Dictionary, index: int) -> Node3D:
	var part_id: String = str(part.get("part_id", ""))
	var definition: Dictionary = PartCatalog.get_definition(part_id)
	var root := Node3D.new()
	root.name = "Draft" + part_id.to_pascal_case() + str(index)
	root.position = part.get("position", Vector3.ZERO) as Vector3
	root.rotation_degrees.y = float(part.get("yaw_degrees", 0.0))
	draft_root.add_child(root)
	var mesh := MeshInstance3D.new()
	mesh.name = "DraftPartVisual"
	var size: Vector3 = definition.get("size", Vector3.ONE) as Vector3
	if str(definition.get("shape", "box")) == "cylinder":
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = size.x * 0.5
		cylinder.bottom_radius = size.z * 0.5
		cylinder.height = size.y
		cylinder.radial_segments = 18
		mesh.mesh = cylinder
		if part_id == "wheel":
			mesh.rotation_degrees.z = 90.0
	else:
		var box := BoxMesh.new()
		box.size = size
		mesh.mesh = box
	var color: Color = definition.get("color", Color(0.5, 0.7, 0.9, 1.0)) as Color
	mesh.material_override = _make_draft_material(Color(color.r, color.g, color.b, 0.72))
	root.add_child(mesh)
	var area := Area3D.new()
	area.name = "DraftPartSurface"
	area.collision_layer = 1
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(
		maxf(size.x * 0.96, 0.05),
		maxf(size.y * 0.96, 0.05),
		maxf(size.z * 0.96, 0.05)
	)
	collision.shape = shape
	area.add_child(collision)
	root.add_child(area)
	return root


func _enforce_active_limit() -> void:
	_prune_active_contraptions()
	while active_contraptions.size() >= maximum_active_contraptions:
		var oldest: ArtificerContraptionInstance = active_contraptions.pop_front()
		if oldest != null and is_instance_valid(oldest):
			oldest.queue_free()


func _on_contraption_exiting(instance: ArtificerContraptionInstance) -> void:
	active_contraptions.erase(instance)
	active_contraptions_changed.emit(active_contraptions.size())


func _prune_active_contraptions() -> void:
	var survivors: Array[ArtificerContraptionInstance] = []
	for instance: ArtificerContraptionInstance in active_contraptions:
		if (
			instance != null
			and is_instance_valid(instance)
			and not instance.is_queued_for_deletion()
		):
			survivors.append(instance)
	if survivors.size() != active_contraptions.size():
		active_contraptions = survivors
		active_contraptions_changed.emit(active_contraptions.size())


func _rotated_half_extents(size: Vector3, yaw_radians: float) -> Vector3:
	var cosine: float = absf(cos(yaw_radians))
	var sine: float = absf(sin(yaw_radians))
	return Vector3(
		(size.x * cosine + size.z * sine) * 0.5,
		size.y * 0.5,
		(size.x * sine + size.z * cosine) * 0.5
	)


func _make_preview_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	return material


func _make_draft_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = 0.35
	material.roughness = 0.48
	return material


func _show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)
	elif print_debug:
		print(message)


func get_debug_data() -> Dictionary:
	return {
		"mode": mode,
		"selected_part": PartCatalog.get_selected_part_id(),
		"selected_build": selected_deploy_build_id,
		"selected_custom_slot": BuildCatalog.get_selected_custom_slot(),
		"draft_part_count": draft_parts.size(),
		"draft_parts": draft_parts.duplicate(true),
		"placement_active": mode != MODE_NONE,
		"placement_valid": placement_valid,
		"invalid_reason": invalid_reason,
		"depth_offset": placement_depth_offset,
		"yaw_degrees": placement_yaw_degrees,
		"active_count": get_active_count(),
		"maximum_active": maximum_active_contraptions,
	}
