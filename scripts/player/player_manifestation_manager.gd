extends Node
class_name PlayerManifestationManager

signal manifestation_started(actor: ManifestedAvatarActor, definition: PlayableAvatarDefinition)
signal manifestation_dismissed(avatar_id: String, reason: String)
signal manifestation_failed(avatar_id: String, failures: Array[String])
signal manifestation_recalled(actor: ManifestedAvatarActor, reason: String)

@export_group("Manifestation Catalog")
@export var prototype_avatar_definition: PlayableAvatarDefinition
@export var manifestation_scene: PackedScene

@export_group("Debug Access")
@export var debug_input_enabled: bool = true
@export var debug_toggle_key: Key = KEY_F10

@export_group("Placement")
@export_range(0.5, 6.0, 0.1) var summon_side_distance: float = 2.25
@export_range(0.0, 4.0, 0.1) var summon_back_distance: float = 1.15
@export_range(1.0, 10.0, 0.1) var floor_probe_height: float = 4.0
@export_range(1.0, 12.0, 0.1) var floor_probe_depth: float = 8.0
@export_range(0.5, 2.0, 0.01) var actor_center_height: float = 0.96

@export_group("Lifetime")
@export_range(0.0, 600.0, 0.5) var debug_manifestation_duration: float = 0.0

var owner_actor: CharacterBody3D
var avatar_manager: PlayerAvatarManager
var active_manifestation: ManifestedAvatarActor
var active_definition: PlayableAvatarDefinition
var lifetime_remaining: float = 0.0
var total_manifestations: int = 0
var total_dismissals: int = 0
var total_recalls: int = 0
var last_result: String = "ready"
var last_failure: String = ""
var last_dismiss_reason: String = "none"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	owner_actor = get_parent() as CharacterBody3D
	if owner_actor != null:
		avatar_manager = owner_actor.get_node_or_null(
			"AvatarManager"
		) as PlayerAvatarManager
	if avatar_manager != null and not avatar_manager.avatar_transition_started.is_connected(
		_on_avatar_transition_started
	):
		avatar_manager.avatar_transition_started.connect(
			_on_avatar_transition_started
		)
	add_to_group("player_manifestation_manager")
	add_to_group("warlock_manifestation_manager")
	add_to_group("debuggable")


func _exit_tree() -> void:
	if avatar_manager != null and avatar_manager.avatar_transition_started.is_connected(
		_on_avatar_transition_started
	):
		avatar_manager.avatar_transition_started.disconnect(
			_on_avatar_transition_started
		)
	if active_manifestation != null and is_instance_valid(active_manifestation):
		active_manifestation.prepare_for_dismissal("scene_exit")
		active_manifestation.queue_free()
	active_manifestation = null
	active_definition = null


func _process(delta: float) -> void:
	if active_manifestation != null and not is_instance_valid(active_manifestation):
		active_manifestation = null
		active_definition = null
		lifetime_remaining = 0.0
		last_result = "manifestation_lost"
		return
	if active_manifestation == null:
		return
	if lifetime_remaining > 0.0:
		lifetime_remaining = maxf(
			lifetime_remaining - maxf(delta, 0.0),
			0.0
		)
		if lifetime_remaining <= 0.0:
			dismiss_manifestation("duration_expired")


func _unhandled_input(event: InputEvent) -> void:
	if not debug_input_enabled or not OS.is_debug_build():
		return
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode != debug_toggle_key:
		return
	if has_active_manifestation():
		dismiss_manifestation("debug_toggle")
	else:
		manifest_prototype(true)
	get_viewport().set_input_as_handled()


func manifest_prototype(force_debug: bool = false) -> bool:
	return manifest_avatar(
		prototype_avatar_definition,
		force_debug,
		null
	)


func manifest_avatar(
	definition: PlayableAvatarDefinition,
	force_debug: bool = false,
	driver_override: AvatarControlDriver = null
) -> bool:
	if owner_actor == null or manifestation_scene == null or definition == null:
		return _fail(
			definition.avatar_id if definition != null else "none",
			["Manifestation owner, scene, or avatar definition is missing."]
		)
	if has_active_manifestation():
		if active_definition == definition:
			active_manifestation.recall_to_owner("manifestation_toggle")
			return true
		dismiss_manifestation("avatar_switch")
	if avatar_manager != null and avatar_manager.is_incarnated():
		return _fail(
			definition.avatar_id,
			["Dismiss Divine Incarnation before manifesting a companion."]
		)

	var failures: Array[String] = definition.validate_definition()
	if (
		not force_debug
		and definition.required_unlock_id != ""
		and not GameState.has_unlock(definition.required_unlock_id)
	):
		failures.append(
			definition.display_name + " is not unlocked for manifestation."
		)
	if not failures.is_empty():
		return _fail(definition.avatar_id, failures)

	var instance: Node = manifestation_scene.instantiate()
	if not instance is ManifestedAvatarActor:
		if instance != null:
			instance.queue_free()
		return _fail(
			definition.avatar_id,
			["Manifestation scene does not produce ManifestedAvatarActor."]
		)
	var actor: ManifestedAvatarActor = instance as ManifestedAvatarActor
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		actor.queue_free()
		return _fail(definition.avatar_id, ["No active scene can receive the manifestation."])

	scene_root.add_child(actor)
	actor.global_transform = get_safe_manifestation_transform(actor)
	var initialization_failures: Array[String] = actor.initialize_manifestation(
		definition,
		owner_actor,
		self,
		driver_override
	)
	if not initialization_failures.is_empty():
		actor.queue_free()
		return _fail(definition.avatar_id, initialization_failures)

	active_manifestation = actor
	active_definition = definition
	lifetime_remaining = (
		debug_manifestation_duration
		if debug_manifestation_duration > 0.0
		else maxf(definition.manifestation_duration, 0.0)
	)
	_connect_manifestation(actor)
	total_manifestations += 1
	last_result = "manifested"
	last_failure = ""
	manifestation_started.emit(actor, definition)
	_show_message(definition.display_name + " manifests beside Grace.")
	return true


func dismiss_manifestation(reason: String = "dismissed") -> bool:
	if not has_active_manifestation():
		active_manifestation = null
		active_definition = null
		lifetime_remaining = 0.0
		return false
	var actor: ManifestedAvatarActor = active_manifestation
	var previous_avatar_id: String = (
		active_definition.avatar_id
		if active_definition != null
		else "unknown"
	)
	active_manifestation = null
	active_definition = null
	lifetime_remaining = 0.0
	_disconnect_manifestation(actor)
	actor.prepare_for_dismissal(reason)
	actor.queue_free()
	total_dismissals += 1
	last_result = "dismissed"
	last_dismiss_reason = reason
	manifestation_dismissed.emit(previous_avatar_id, reason)
	_show_message(previous_avatar_id.capitalize() + " returns beyond the veil.")
	return true


func recall_manifestation(reason: String = "recalled") -> bool:
	if not has_active_manifestation():
		return false
	var recalled_ok: bool = active_manifestation.recall_to_owner(reason)
	if recalled_ok:
		total_recalls += 1
		last_result = "recalled"
		manifestation_recalled.emit(active_manifestation, reason)
	return recalled_ok


func has_active_manifestation() -> bool:
	return (
		active_manifestation != null
		and is_instance_valid(active_manifestation)
		and not active_manifestation.is_queued_for_deletion()
	)


func get_active_manifestation() -> ManifestedAvatarActor:
	return active_manifestation if has_active_manifestation() else null


func get_safe_manifestation_transform(
	requesting_actor: ManifestedAvatarActor = null
) -> Transform3D:
	if owner_actor == null:
		return Transform3D.IDENTITY
	var owner_basis: Basis = owner_actor.global_transform.basis.orthonormalized()
	var candidate_offsets: Array[Vector3] = [
		owner_basis.x * summon_side_distance + owner_basis.z * summon_back_distance,
		-owner_basis.x * summon_side_distance + owner_basis.z * summon_back_distance,
		owner_basis.z * (summon_back_distance + 1.1),
		-owner_basis.z * (summon_back_distance + 1.5),
		owner_basis.x * (summon_side_distance + 1.0),
		-owner_basis.x * (summon_side_distance + 1.0),
	]
	for offset: Vector3 in candidate_offsets:
		var candidate: Vector3 = owner_actor.global_position + offset
		var floor_position: Variant = _find_floor_position(candidate, requesting_actor)
		if not floor_position is Vector3:
			continue
		var actor_position: Vector3 = (
			floor_position as Vector3
			+ Vector3.UP * actor_center_height
		)
		if not _position_is_clear(actor_position, requesting_actor):
			continue
		var result: Transform3D = owner_actor.global_transform
		result.origin = actor_position
		return result

	var fallback: Transform3D = owner_actor.global_transform
	fallback.origin = (
		owner_actor.global_position
		+ owner_basis.x * summon_side_distance
		+ owner_basis.z * summon_back_distance
		+ Vector3.UP * actor_center_height
	)
	return fallback


func _find_floor_position(
	candidate: Vector3,
	requesting_actor: ManifestedAvatarActor
) -> Variant:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		candidate + Vector3.UP * floor_probe_height,
		candidate + Vector3.DOWN * floor_probe_depth,
		1
	)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var exclusions: Array[RID] = []
	if owner_actor != null:
		exclusions.append(owner_actor.get_rid())
	if requesting_actor != null:
		exclusions.append(requesting_actor.get_rid())
	query.exclude = exclusions
	var result: Dictionary = get_viewport().world_3d.direct_space_state.intersect_ray(
		query
	)
	if result.is_empty():
		return null
	var normal_value: Variant = result.get("normal", Vector3.ZERO)
	if not normal_value is Vector3:
		return null
	var normal: Vector3 = normal_value as Vector3
	if normal.dot(Vector3.UP) < 0.55:
		return null
	return result.get("position", candidate)


func _position_is_clear(
	actor_position: Vector3,
	requesting_actor: ManifestedAvatarActor
) -> bool:
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.41
	capsule.height = 1.84
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, actor_position + Vector3.UP * 0.04)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.margin = 0.01
	var exclusions: Array[RID] = []
	if owner_actor != null:
		exclusions.append(owner_actor.get_rid())
	if requesting_actor != null:
		exclusions.append(requesting_actor.get_rid())
	query.exclude = exclusions
	return get_viewport().world_3d.direct_space_state.intersect_shape(
		query,
		8
	).is_empty()


func _connect_manifestation(actor: ManifestedAvatarActor) -> void:
	if not actor.manifestation_defeated.is_connected(_on_manifestation_defeated):
		actor.manifestation_defeated.connect(_on_manifestation_defeated)
	if not actor.dismissal_requested.is_connected(_on_dismissal_requested):
		actor.dismissal_requested.connect(_on_dismissal_requested)
	if not actor.recalled.is_connected(_on_actor_recalled):
		actor.recalled.connect(_on_actor_recalled)


func _disconnect_manifestation(actor: ManifestedAvatarActor) -> void:
	if actor == null:
		return
	if actor.manifestation_defeated.is_connected(_on_manifestation_defeated):
		actor.manifestation_defeated.disconnect(_on_manifestation_defeated)
	if actor.dismissal_requested.is_connected(_on_dismissal_requested):
		actor.dismissal_requested.disconnect(_on_dismissal_requested)
	if actor.recalled.is_connected(_on_actor_recalled):
		actor.recalled.disconnect(_on_actor_recalled)


func _on_avatar_transition_started(
	_from_avatar_id: String,
	_to_avatar_id: String
) -> void:
	if has_active_manifestation():
		dismiss_manifestation("divine_incarnation_transfer")


func _on_manifestation_defeated(
	actor: ManifestedAvatarActor
) -> void:
	if actor == active_manifestation:
		dismiss_manifestation("defeated")


func _on_dismissal_requested(
	actor: ManifestedAvatarActor,
	reason: String
) -> void:
	if actor == active_manifestation:
		dismiss_manifestation(reason)


func _on_actor_recalled(
	actor: ManifestedAvatarActor,
	reason: String
) -> void:
	if actor != active_manifestation:
		return
	total_recalls += 1
	last_result = "recalled"
	manifestation_recalled.emit(actor, reason)


func _fail(avatar_id: String, failures: Array[String]) -> bool:
	last_result = "failed"
	last_failure = "; ".join(failures)
	manifestation_failed.emit(avatar_id, failures)
	if last_failure != "":
		_show_message(last_failure)
	return false


func _show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	var actor_data: Dictionary = (
		active_manifestation.get_debug_data()
		if has_active_manifestation()
		else {}
	)
	return {
		"active": has_active_manifestation(),
		"avatar_id": (
			active_definition.avatar_id
			if active_definition != null
			else "none"
		),
		"avatar_name": (
			active_definition.display_name
			if active_definition != null
			else "none"
		),
		"lifetime_remaining": snappedf(lifetime_remaining, 0.01),
		"driver_id": str(actor_data.get("driver_id", "none")),
		"target": str(actor_data.get("target", "none")),
		"last_action": str(actor_data.get("last_action_id", "none")),
		"owned_fields": int(actor_data.get("owned_fields", 0)),
		"stuck_timer": float(actor_data.get("stuck_timer", 0.0)),
		"recall_count": int(actor_data.get("recall_count", 0)),
		"total_manifestations": total_manifestations,
		"total_dismissals": total_dismissals,
		"total_recalls": total_recalls,
		"last_result": last_result,
		"last_failure": last_failure,
		"last_dismiss_reason": last_dismiss_reason,
		"actor": actor_data,
	}
