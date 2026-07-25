extends Node
class_name PlayerRidingController

signal mounted(mount: RideableMount)
signal dismounted(mount: RideableMount, forced: bool)
signal mount_called(mount: RideableMount)

@export var mount_range: float = 3.2
@export var mounted_camera_length: float = 8.0
@export var camera_response: float = 5.0
@export var severe_collision_dismount: bool = true

var actor: CharacterBody3D
var action_state: PlayerActionState
var current_mount: RideableMount
var spring_arm: SpringArm3D
var actor_collision: CollisionShape3D
var base_camera_length: float = 6.0
var prefer_right_dismount: bool = true


func _ready() -> void:
	actor = get_parent() as CharacterBody3D
	if actor == null:
		return
	action_state = actor.get_node_or_null("PlayerActionState") as PlayerActionState
	spring_arm = actor.get_node_or_null("CameraPivot/SpringArm3D") as SpringArm3D
	actor_collision = actor.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if spring_arm != null:
		base_camera_length = spring_arm.spring_length
	add_to_group("riding_controller")


func _process(delta: float) -> void:
	if spring_arm == null:
		return
	var target_length: float = mounted_camera_length if is_riding() else base_camera_length
	spring_arm.spring_length = lerpf(spring_arm.spring_length, target_length, clampf(delta * camera_response, 0.0, 1.0))


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if is_riding():
		dismount()
		get_viewport().set_input_as_handled()
		return
	var mount: RideableMount = find_nearest_mount()
	if mount != null and mount_mount(mount):
		get_viewport().set_input_as_handled()


func should_handle_locomotion() -> bool:
	return is_riding()


func process_locomotion(delta: float) -> bool:
	if not is_riding() or actor == null:
		return false
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var gallop_requested: bool = Input.is_action_pressed("guard")
	var jump_requested: bool = Input.is_action_just_pressed("jump")
	current_mount.process_ridden_locomotion(delta, input_vector, gallop_requested, jump_requested)
	_attach_actor_to_seat()
	return true


func mount_mount(mount: RideableMount) -> bool:
	if actor == null or mount == null or current_mount != null:
		return false
	if actor.global_position.distance_to(mount.global_position) > mount_range:
		return false
	if action_state != null:
		action_state.clear_action_locks()
		if not action_state.begin_manipulation():
			return false
	_reset_incompatible_locomotion()
	if not mount.assign_rider(actor):
		if action_state != null:
			action_state.end_manipulation()
		return false
	current_mount = mount
	if actor_collision != null:
		actor_collision.disabled = true
	actor.velocity = Vector3.ZERO
	if not current_mount.severe_collision.is_connected(_on_severe_collision):
		current_mount.severe_collision.connect(_on_severe_collision)
	_attach_actor_to_seat()
	mounted.emit(current_mount)
	_show_message("Mounted " + current_mount.display_name + ".")
	return true


func dismount(forced: bool = false) -> bool:
	if not is_riding() or actor == null:
		return false
	var old_mount: RideableMount = current_mount
	var dismount_position: Vector3 = old_mount.get_dismount_position(prefer_right_dismount)
	prefer_right_dismount = not prefer_right_dismount
	if old_mount.severe_collision.is_connected(_on_severe_collision):
		old_mount.severe_collision.disconnect(_on_severe_collision)
	old_mount.clear_rider()
	current_mount = null
	actor.global_position = dismount_position
	actor.rotation.y = old_mount.rotation.y
	actor.velocity = Vector3.ZERO
	if actor_collision != null:
		actor_collision.set_deferred("disabled", false)
	if action_state != null:
		action_state.end_manipulation()
	dismounted.emit(old_mount, forced)
	_show_message("Thrown from the saddle!" if forced else "Dismounted.")
	return true


func call_mount(mount: RideableMount = null) -> bool:
	if is_riding() or actor == null:
		return false
	var selected: RideableMount = mount
	if selected == null:
		selected = find_nearest_mount(true)
	if selected == null:
		return false
	var target: Vector3 = actor.global_position - actor.global_basis.z * 2.2 + actor.global_basis.x * 1.7
	if not selected.summon_to(target):
		return false
	mount_called.emit(selected)
	_show_message(selected.display_name + " is answering the call.")
	return true


func dismiss_mount(mount: RideableMount = null) -> bool:
	if is_riding():
		return false
	var selected: RideableMount = mount
	if selected == null:
		selected = find_nearest_mount(true)
	return selected != null and selected.dismiss()


func find_nearest_mount(ignore_range: bool = false) -> RideableMount:
	if actor == null or get_tree() == null:
		return null
	var best: RideableMount
	var best_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group("rideable_mount"):
		var mount := node as RideableMount
		if mount == null or mount.rider != null:
			continue
		var distance: float = actor.global_position.distance_to(mount.global_position)
		if not ignore_range and distance > mount_range:
			continue
		if distance < best_distance:
			best = mount
			best_distance = distance
	return best


func is_riding() -> bool:
	return current_mount != null and is_instance_valid(current_mount) and current_mount.rider == actor


func get_current_mount() -> RideableMount:
	return current_mount


func get_debug_data() -> Dictionary:
	return {
		"riding": is_riding(),
		"mount": current_mount.display_name if is_riding() else "none",
		"gait": current_mount.current_gait if is_riding() else "ON FOOT",
		"mount_speed": absf(current_mount.current_speed) if is_riding() else 0.0,
		"mount_stamina": current_mount.mount_stamina if is_riding() else 0.0,
	}


func _attach_actor_to_seat() -> void:
	if not is_riding():
		return
	var seat_transform: Transform3D = current_mount.get_seat_transform()
	actor.global_position = seat_transform.origin
	actor.rotation = Vector3(0.0, current_mount.rotation.y, 0.0)
	actor.velocity = Vector3.ZERO


func _reset_incompatible_locomotion() -> void:
	var climbing: Node = actor.get_node_or_null("ClimbingController")
	if climbing != null and climbing.has_method("reset_climbing"):
		climbing.call("reset_climbing")
	var swimming: Node = actor.get_node_or_null("SwimmingController")
	if swimming != null and swimming.has_method("reset_swimming"):
		swimming.call("reset_swimming")
	var aerial: Node = actor.get_node_or_null("AerialLocomotion")
	if aerial != null and aerial.has_method("end_flight"):
		aerial.call("end_flight")


func _on_severe_collision(_impact_speed: float) -> void:
	if severe_collision_dismount:
		dismount(true)


func _show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)
