extends "res://scripts/objects/recorded_object_manager.gd"
class_name RecordedObjectManagerSpell

const SafeRecordedObjectScript = preload(
	"res://scripts/objects/recorded_object_instance_safe.gd"
)

@export_group("Manipulation Placement")
@export_range(0.25, 2.0, 0.05) var depth_step: float = 0.75
@export_range(0.0, 12.0, 0.25) var maximum_depth_offset: float = 6.0

var placement_depth_offset: float = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return

	if keyboard_controls_enabled and event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if placement_active:
				match key_event.keycode:
					KEY_V, KEY_ESCAPE:
						cancel_placement()
					KEY_Q:
						adjust_depth(-1)
					KEY_E:
						adjust_depth(1)
					KEY_R:
						rotate_preview(1)
					KEY_F8:
						clear_spawned_objects()
					_:
						return
			else:
				match key_event.keycode:
					KEY_V:
						begin_placement()
					KEY_F1, KEY_F2, KEY_F3, KEY_F4:
						select_blueprint_by_index(
							int(key_event.keycode - KEY_F1)
						)
					KEY_F8:
						clear_spawned_objects()
					_:
						return
			get_viewport().set_input_as_handled()
			return

	if keyboard_controls_enabled and event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed or not placement_active:
			return
		match mouse_event.button_index:
			MOUSE_BUTTON_LEFT:
				confirm_placement()
			MOUSE_BUTTON_RIGHT:
				cancel_placement()
			MOUSE_BUTTON_WHEEL_UP:
				adjust_depth(1)
			MOUSE_BUTTON_WHEEL_DOWN:
				adjust_depth(-1)
			_:
				return
		get_viewport().set_input_as_handled()
		return

	# Controller input belongs to placement only after a spell, menu, or station
	# has deliberately entered placement mode. Normal combat never wakes this
	# manager.
	if (
		controller_controls_enabled
		and placement_active
		and event is InputEventJoypadButton
	):
		var button_event := event as InputEventJoypadButton
		if not button_event.pressed:
			return
		match button_event.button_index:
			JOY_BUTTON_DPAD_UP:
				adjust_depth(1)
			JOY_BUTTON_DPAD_DOWN:
				adjust_depth(-1)
			JOY_BUTTON_LEFT_SHOULDER:
				rotate_preview(-1)
			JOY_BUTTON_RIGHT_SHOULDER:
				rotate_preview(1)
			JOY_BUTTON_A:
				confirm_placement()
			JOY_BUTTON_B:
				cancel_placement()
			_:
				return
		get_viewport().set_input_as_handled()


func begin_placement() -> bool:
	placement_depth_offset = 0.0
	return super.begin_placement()


func cancel_placement() -> void:
	placement_depth_offset = 0.0
	super.cancel_placement()


func adjust_depth(direction: int) -> void:
	if not placement_active or direction == 0:
		return
	placement_depth_offset = clampf(
		placement_depth_offset + depth_step * signi(direction),
		-maximum_depth_offset,
		maximum_depth_offset
	)
	_update_target_from_camera()
	_update_preview()


func _update_target_from_camera() -> void:
	super._update_target_from_camera()
	if (
		not placement_active
		or absf(placement_depth_offset) <= 0.001
		or actor == null
		or get_world_3d() == null
	):
		return

	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var forward: Vector3 = -camera.global_basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		return
	forward = forward.normalized()

	var shifted: Vector3 = (
		target_ground_position + forward * placement_depth_offset
	)
	var down_query := PhysicsRayQueryParameters3D.create(
		shifted + Vector3.UP * 8.0,
		shifted + Vector3.DOWN * 20.0
	)
	if actor is CollisionObject3D:
		down_query.exclude = [(actor as CollisionObject3D).get_rid()]
	down_query.collision_mask = 0xFFFFFFFF
	var ground_hit: Dictionary = (
		get_world_3d().direct_space_state.intersect_ray(down_query)
	)
	if ground_hit.is_empty():
		placement_valid = false
		invalid_reason = "No stable surface is under that depth."
		placement_updated.emit(
			target_ground_position,
			false,
			invalid_reason
		)
		return

	target_ground_position = ground_hit["position"] as Vector3
	support_rid = RID()
	var collider: Object = ground_hit.get("collider")
	if collider is CollisionObject3D:
		support_rid = (collider as CollisionObject3D).get_rid()
	var definition: Dictionary = Catalog.get_definition(
		Catalog.get_selected_blueprint_id()
	)
	var validation: Dictionary = validate_placement(
		definition,
		target_ground_position,
		placement_yaw_degrees,
		support_rid
	)
	placement_valid = bool(validation.get("valid", false))
	invalid_reason = str(validation.get("reason", ""))
	placement_updated.emit(
		target_ground_position,
		placement_valid,
		invalid_reason
	)


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
		invalid_reason = str(
			validation.get("reason", "The object cannot fit there.")
		)
		return null
	var mana_cost: int = maxi(int(definition.get("mana_cost", 0)), 0)
	if (
		not ignore_cost
		and mana_cost > 0
		and not GameState.spend_mana(mana_cost)
	):
		_show_message(
			"Not enough mana to reproduce "
			+ str(definition.get("display_name", "that object"))
			+ "."
		)
		return null

	_enforce_active_limits(
		blueprint_id,
		int(definition.get("maximum_active", 1))
	)
	var instance := (
		SafeRecordedObjectScript.new() as RecordedObjectInstanceSafe
	)
	instance.configure(definition, actor, self)
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		if not ignore_cost and mana_cost > 0:
			GameState.restore_mana(mana_cost)
		instance.queue_free()
		return null

	scene_root.add_child(instance)
	var size: Vector3 = definition.get("size", Vector3.ONE) as Vector3
	instance.global_position = (
		ground_position + Vector3.UP * (size.y * 0.5 + 0.025)
	)
	instance.global_rotation = Vector3(
		0.0,
		deg_to_rad(yaw_degrees),
		0.0
	)
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
	return instance


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["placement_depth_offset"] = placement_depth_offset
	data["spell_driven_controls"] = true
	data["safe_deferred_blasts"] = true
	return data
