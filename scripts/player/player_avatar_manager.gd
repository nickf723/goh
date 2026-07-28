extends Node
class_name PlayerAvatarManager

signal avatar_transition_started(from_avatar_id: String, to_avatar_id: String)
signal avatar_changed(definition: PlayableAvatarDefinition)
signal avatar_dismissed(previous_avatar_id: String, reason: String)
signal avatar_transition_failed(avatar_id: String, failures: Array[String])
signal emergency_restore_completed(reason: String)

@export_group("Avatar Catalog")
@export var default_avatar_definition: PlayableAvatarDefinition
@export var prototype_avatar_definition: PlayableAvatarDefinition
@export var additional_avatar_definitions: Array[PlayableAvatarDefinition] = []

@export_group("Debug Access")
@export var debug_input_enabled: bool = true
@export var debug_toggle_key: Key = KEY_F9

@export_group("Safety")
@export_range(0.05, 2.0, 0.05) var watchdog_interval: float = 0.35
@export var auto_restore_on_contract_failure: bool = true

var actor: CharacterBody3D
var action_state: PlayerActionState
var weapon_controller: WeaponController
var ability_caster: Node
var ground_motion_motor: PlayerGroundMotionMotor
var vertical_motion_controller: PlayerVerticalMotionController
var dodge_motion_controller: PlayerDodgeController
var combat_footwork_controller: PlayerCombatFootworkController
var wire_renderer: AvatarWireSkeletonRenderer
var camera: Camera3D

var initialized: bool = false
var baseline_snapshot: Dictionary = {}
var active_definition: PlayableAvatarDefinition
var manifestation_remaining: float = 0.0
var watchdog_remaining: float = 0.0
var transition_in_progress: bool = false
var transition_count: int = 0
var rollback_count: int = 0
var last_transition_result: String = "not_initialized"
var last_error: String = ""
var last_dismiss_reason: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	actor = get_parent() as CharacterBody3D
	_resolve_bindings()
	add_to_group("player_avatar_manager")
	add_to_group("divine_incarnation_manager")
	add_to_group("debuggable")
	if actor != null:
		actor.add_to_group("active_player_avatar")
		actor.add_to_group("player_avatar_anchor")
	call_deferred("_initialize_manager")


func _process(delta: float) -> void:
	if not initialized or transition_in_progress or active_definition == null:
		return
	if manifestation_remaining > 0.0:
		manifestation_remaining = maxf(manifestation_remaining - maxf(delta, 0.0), 0.0)
		if manifestation_remaining <= 0.0:
			dismiss_avatar("manifestation_expired")
			return

	watchdog_remaining = maxf(watchdog_remaining - maxf(delta, 0.0), 0.0)
	if watchdog_remaining > 0.0:
		return
	watchdog_remaining = maxf(watchdog_interval, 0.05)
	var failures: Array[String] = _validate_live_contract(active_definition)
	if not failures.is_empty() and auto_restore_on_contract_failure:
		emergency_restore("watchdog: " + "; ".join(failures))


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
	if active_definition != null:
		dismiss_avatar("debug_toggle")
	elif prototype_avatar_definition != null:
		incarnate(prototype_avatar_definition, true)
	get_viewport().set_input_as_handled()


func _initialize_manager() -> void:
	_resolve_bindings()
	var binding_failures: Array[String] = _validate_bindings()
	if not binding_failures.is_empty():
		last_transition_result = "initialization_failed"
		last_error = "; ".join(binding_failures)
		push_error("PlayerAvatarManager: " + last_error)
		return

	baseline_snapshot = _capture_configuration()
	active_definition = null
	manifestation_remaining = 0.0
	watchdog_remaining = maxf(watchdog_interval, 0.05)
	initialized = true
	last_transition_result = "ready"
	_apply_anchor_metadata(default_avatar_definition)


func incarnate_by_id(avatar_id: String, force_debug: bool = false) -> bool:
	var definition: PlayableAvatarDefinition = get_avatar_definition(avatar_id)
	if definition == null:
		last_transition_result = "definition_not_found"
		last_error = "No playable avatar definition named " + avatar_id + "."
		avatar_transition_failed.emit(avatar_id, [last_error])
		return false
	return incarnate(definition, force_debug)


func incarnate(
	definition: PlayableAvatarDefinition,
	force_debug: bool = false
) -> bool:
	if not initialized:
		_initialize_manager()
	if not initialized or definition == null or transition_in_progress:
		return false
	if active_definition == definition:
		return true
	if active_definition != null and not dismiss_avatar("avatar_switch"):
		return false

	var failures: Array[String] = definition.validate_definition()
	if not force_debug and not is_avatar_unlocked(definition):
		failures.append(definition.display_name + " is not unlocked for incarnation.")
	if not failures.is_empty():
		last_transition_result = "validation_failed"
		last_error = "; ".join(failures)
		avatar_transition_failed.emit(definition.avatar_id, failures)
		return false

	transition_in_progress = true
	var safety_snapshot: Dictionary = _capture_configuration()
	var runtime_anchor: Dictionary = _capture_runtime_anchor()
	var from_avatar_id: String = get_active_avatar_id()
	avatar_transition_started.emit(from_avatar_id, definition.avatar_id)
	_quiesce_actions("avatar_incarnation")

	var apply_failures: Array[String] = _apply_definition(definition)
	_restore_runtime_anchor(runtime_anchor, definition)
	apply_failures.append_array(_validate_live_contract(definition))
	if not apply_failures.is_empty():
		_restore_configuration(safety_snapshot)
		_restore_runtime_anchor(runtime_anchor, null)
		transition_in_progress = false
		rollback_count += 1
		last_transition_result = "rolled_back"
		last_error = "; ".join(apply_failures)
		avatar_transition_failed.emit(definition.avatar_id, apply_failures)
		return false

	active_definition = definition
	manifestation_remaining = maxf(definition.manifestation_duration, 0.0)
	watchdog_remaining = maxf(watchdog_interval, 0.05)
	transition_count += 1
	last_transition_result = "incarnated"
	last_error = ""
	transition_in_progress = false
	_apply_anchor_metadata(definition)
	avatar_changed.emit(definition)
	_show_message("Divine Incarnation: " + definition.display_name)
	return true


func dismiss_avatar(reason: String = "dismissed") -> bool:
	if not initialized:
		return false
	if active_definition == null:
		return true
	if transition_in_progress:
		return false

	transition_in_progress = true
	var previous_id: String = active_definition.avatar_id
	var runtime_anchor: Dictionary = _capture_runtime_anchor()
	_quiesce_actions("avatar_dismissal")
	var restored: bool = _restore_configuration(baseline_snapshot)
	_restore_runtime_anchor(runtime_anchor, default_avatar_definition)
	active_definition = null
	manifestation_remaining = 0.0
	watchdog_remaining = maxf(watchdog_interval, 0.05)
	last_dismiss_reason = reason
	transition_in_progress = false
	_apply_anchor_metadata(default_avatar_definition)

	if not restored:
		rollback_count += 1
		last_transition_result = "dismiss_restore_failed"
		last_error = "The baseline avatar configuration could not be restored."
		avatar_transition_failed.emit(previous_id, [last_error])
		return false

	transition_count += 1
	last_transition_result = "dismissed"
	last_error = ""
	avatar_dismissed.emit(previous_id, reason)
	_show_message("Grace returns. ")
	return true


func emergency_restore(reason: String = "contract_failure") -> bool:
	if transition_in_progress:
		return false
	transition_in_progress = true
	var runtime_anchor: Dictionary = _capture_runtime_anchor()
	_quiesce_actions("emergency_restore")
	var restored: bool = _restore_configuration(baseline_snapshot)
	_restore_runtime_anchor(runtime_anchor, default_avatar_definition)
	active_definition = null
	manifestation_remaining = 0.0
	watchdog_remaining = maxf(watchdog_interval, 0.05)
	rollback_count += 1
	last_dismiss_reason = reason
	last_transition_result = "emergency_restored" if restored else "emergency_restore_failed"
	last_error = "" if restored else reason
	transition_in_progress = false
	_apply_anchor_metadata(default_avatar_definition)
	if restored:
		emergency_restore_completed.emit(reason)
		_show_message("Incarnation destabilized. Grace restored safely.")
	return restored


func is_avatar_unlocked(definition: PlayableAvatarDefinition) -> bool:
	if definition == null:
		return false
	if definition.required_unlock_id == "":
		return true
	if GameState.has_method("has_unlock") and GameState.has_unlock(definition.required_unlock_id):
		return true
	return OS.is_debug_build() and definition.debug_available


func get_avatar_definition(avatar_id: String) -> PlayableAvatarDefinition:
	for definition: PlayableAvatarDefinition in get_avatar_definitions():
		if definition != null and definition.avatar_id == avatar_id:
			return definition
	return null


func get_avatar_definitions() -> Array[PlayableAvatarDefinition]:
	var definitions: Array[PlayableAvatarDefinition] = []
	for definition: PlayableAvatarDefinition in [
		default_avatar_definition,
		prototype_avatar_definition,
	]:
		if definition != null and not definitions.has(definition):
			definitions.append(definition)
	for definition: PlayableAvatarDefinition in additional_avatar_definitions:
		if definition != null and not definitions.has(definition):
			definitions.append(definition)
	return definitions


func get_active_avatar_id() -> String:
	if active_definition != null:
		return active_definition.avatar_id
	if default_avatar_definition != null:
		return default_avatar_definition.avatar_id
	return "grace"


func get_active_avatar_display_name() -> String:
	if active_definition != null:
		return active_definition.display_name
	if default_avatar_definition != null:
		return default_avatar_definition.display_name
	return "Grace"


func is_incarnated() -> bool:
	return active_definition != null


func get_manifestation_ratio() -> float:
	if active_definition == null or active_definition.manifestation_duration <= 0.0:
		return 1.0 if active_definition != null else 0.0
	return clampf(
		manifestation_remaining / maxf(active_definition.manifestation_duration, 0.001),
		0.0,
		1.0
	)


func get_debug_data() -> Dictionary:
	var current_camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var active_summary: Dictionary = (
		active_definition.get_debug_summary()
		if active_definition != null
		else (
			default_avatar_definition.get_debug_summary()
			if default_avatar_definition != null
			else {}
		)
	)
	return {
		"initialized": initialized,
		"active_avatar_id": get_active_avatar_id(),
		"active_avatar_name": get_active_avatar_display_name(),
		"incarnated": is_incarnated(),
		"manifestation_remaining": snappedf(manifestation_remaining, 0.01),
		"manifestation_ratio": snappedf(get_manifestation_ratio(), 0.01),
		"stable_actor_instance_id": actor.get_instance_id() if actor != null else -1,
		"stable_actor_path": str(actor.get_path()) if actor != null and actor.is_inside_tree() else "",
		"camera_preserved": camera != null and current_camera == camera,
		"health_anchor": GameState.get_stat("health"),
		"weapon": weapon_controller.equipped_weapon.display_name if weapon_controller != null and weapon_controller.equipped_weapon != null else "none",
		"weapon_class": weapon_controller.equipped_weapon.weapon_class if weapon_controller != null and weapon_controller.equipped_weapon != null else "none",
		"spell_count": _get_active_spell_count(),
		"ground_profile": _resource_path(ground_motion_motor.profile if ground_motion_motor != null else null),
		"dodge_profile": _resource_path(dodge_motion_controller.profile if dodge_motion_controller != null else null),
		"footwork_profile": _resource_path(combat_footwork_controller.profile if combat_footwork_controller != null else null),
		"vertical_profile": _resource_path(vertical_motion_controller.profile if vertical_motion_controller != null else null),
		"transition_count": transition_count,
		"rollback_count": rollback_count,
		"transition_in_progress": transition_in_progress,
		"last_result": last_transition_result,
		"last_error": last_error,
		"last_dismiss_reason": last_dismiss_reason,
		"definition": active_summary,
	}


func _resolve_bindings() -> void:
	if actor == null:
		actor = get_parent() as CharacterBody3D
	if actor == null:
		return
	action_state = actor.get_node_or_null("PlayerActionState") as PlayerActionState
	weapon_controller = actor.get_node_or_null("WeaponController") as WeaponController
	ability_caster = actor.get_node_or_null("AbilityCaster")
	ground_motion_motor = actor.get_node_or_null("GroundMotionMotor") as PlayerGroundMotionMotor
	vertical_motion_controller = actor.get_node_or_null("VerticalMotionController") as PlayerVerticalMotionController
	dodge_motion_controller = actor.get_node_or_null("PlayerDodgeController") as PlayerDodgeController
	combat_footwork_controller = actor.get_node_or_null("CombatFootworkController") as PlayerCombatFootworkController
	wire_renderer = (
		actor.get_node_or_null("GraceVisualV1/WireSkeletonRenderer") as AvatarWireSkeletonRenderer
	)
	camera = actor.get_node_or_null("CameraPivot/SpringArm3D/Camera3D") as Camera3D


func _validate_bindings() -> Array[String]:
	var failures: Array[String] = []
	if actor == null:
		failures.append("stable CharacterBody3D anchor is missing")
	if action_state == null:
		failures.append("PlayerActionState is missing")
	if weapon_controller == null:
		failures.append("WeaponController is missing")
	if ability_caster == null:
		failures.append("AbilityCaster is missing")
	if ground_motion_motor == null:
		failures.append("GroundMotionMotor is missing")
	if vertical_motion_controller == null:
		failures.append("VerticalMotionController is missing")
	if dodge_motion_controller == null:
		failures.append("PlayerDodgeController is missing")
	if combat_footwork_controller == null:
		failures.append("CombatFootworkController is missing")
	if wire_renderer == null:
		failures.append("AvatarWireSkeletonRenderer is missing")
	if camera == null:
		failures.append("player camera is missing")
	return failures


func _capture_configuration() -> Dictionary:
	return {
		"weapon": weapon_controller.equipped_weapon if weapon_controller != null else null,
		"loadout": ability_caster.get("loadout") if ability_caster != null else null,
		"ability_index": int(ability_caster.get("current_ability_index")) if ability_caster != null else 0,
		"focus_element_index": int(ability_caster.get("focus_element_index")) if ability_caster != null else 0,
		"focus_spell_index": int(ability_caster.get("focus_spell_index")) if ability_caster != null else 0,
		"ground_profile": ground_motion_motor.profile if ground_motion_motor != null else null,
		"vertical_profile": vertical_motion_controller.profile if vertical_motion_controller != null else null,
		"dodge_profile": dodge_motion_controller.profile if dodge_motion_controller != null else null,
		"footwork_profile": combat_footwork_controller.profile if combat_footwork_controller != null else null,
		"wire_presentation": wire_renderer.capture_avatar_presentation() if wire_renderer != null else {},
	}


func _capture_runtime_anchor() -> Dictionary:
	var target: Variant = actor.get("lock_on_target") if actor != null else null
	return {
		"transform": actor.global_transform if actor != null else Transform3D.IDENTITY,
		"velocity": actor.velocity if actor != null else Vector3.ZERO,
		"lock_on_target": target,
		"camera": get_viewport().get_camera_3d() if is_inside_tree() else camera,
		"health": GameState.get_stat("health"),
		"objective": GameState.current_objective,
		"actor_instance_id": actor.get_instance_id() if actor != null else -1,
	}


func _apply_definition(definition: PlayableAvatarDefinition) -> Array[String]:
	var failures: Array[String] = []
	ground_motion_motor.profile = definition.ground_motion_profile
	vertical_motion_controller.profile = definition.vertical_motion_profile
	dodge_motion_controller.profile = definition.dodge_motion_profile
	combat_footwork_controller.profile = definition.combat_footwork_profile

	weapon_controller.equip_weapon(definition.weapon_definition)
	ability_caster.set("loadout", definition.ability_loadout)
	ability_caster.set("current_ability_index", definition.starting_ability_index)
	ability_caster.set("focus_element_index", 0)
	ability_caster.set("focus_spell_index", 0)
	if ability_caster.has_method("align_focus_menu_to_current_ability"):
		ability_caster.call("align_focus_menu_to_current_ability")
	if ability_caster.has_method("emit_current_ability"):
		ability_caster.call("emit_current_ability")
	if not wire_renderer.set_avatar_presentation(definition):
		failures.append("wire avatar presentation rejected the definition")
	return failures


func _restore_configuration(snapshot: Dictionary) -> bool:
	if snapshot.is_empty():
		return false
	var ground_value: Variant = snapshot.get("ground_profile", null)
	var vertical_value: Variant = snapshot.get("vertical_profile", null)
	var dodge_value: Variant = snapshot.get("dodge_profile", null)
	var footwork_value: Variant = snapshot.get("footwork_profile", null)
	var weapon_value: Variant = snapshot.get("weapon", null)
	var loadout_value: Variant = snapshot.get("loadout", null)
	if not ground_value is GroundMotionProfile:
		return false
	if not vertical_value is VerticalMotionProfile:
		return false
	if not dodge_value is DodgeMotionProfile:
		return false
	if not footwork_value is CombatFootworkProfile:
		return false
	if not weapon_value is WeaponDefinition:
		return false
	if not loadout_value is AbilityLoadout:
		return false

	ground_motion_motor.profile = ground_value as GroundMotionProfile
	vertical_motion_controller.profile = vertical_value as VerticalMotionProfile
	dodge_motion_controller.profile = dodge_value as DodgeMotionProfile
	combat_footwork_controller.profile = footwork_value as CombatFootworkProfile
	weapon_controller.equip_weapon(weapon_value as WeaponDefinition)
	ability_caster.set("loadout", loadout_value as AbilityLoadout)
	var ability_count: int = (loadout_value as AbilityLoadout).get_equipped_ability_count()
	var restored_index: int = clampi(int(snapshot.get("ability_index", 0)), 0, maxi(ability_count - 1, 0))
	ability_caster.set("current_ability_index", restored_index)
	ability_caster.set("focus_element_index", int(snapshot.get("focus_element_index", 0)))
	ability_caster.set("focus_spell_index", int(snapshot.get("focus_spell_index", 0)))
	if ability_caster.has_method("align_focus_menu_to_current_ability"):
		ability_caster.call("align_focus_menu_to_current_ability")
	if ability_caster.has_method("emit_current_ability"):
		ability_caster.call("emit_current_ability")
	var wire_snapshot: Variant = snapshot.get("wire_presentation", {})
	if wire_snapshot is Dictionary:
		wire_renderer.restore_avatar_presentation(wire_snapshot as Dictionary)
	else:
		wire_renderer.clear_avatar_presentation()
	return true


func _restore_runtime_anchor(
	runtime_anchor: Dictionary,
	definition: PlayableAvatarDefinition
) -> void:
	if actor == null or runtime_anchor.is_empty():
		return
	var should_preserve_transform: bool = definition == null or definition.preserve_world_transform
	var should_preserve_velocity: bool = definition == null or definition.preserve_velocity
	var should_preserve_target: bool = definition == null or definition.preserve_lock_on_target
	if should_preserve_transform:
		actor.global_transform = runtime_anchor.get("transform", actor.global_transform) as Transform3D
	if should_preserve_velocity:
		actor.velocity = runtime_anchor.get("velocity", actor.velocity) as Vector3
	if should_preserve_target:
		var target: Variant = runtime_anchor.get("lock_on_target", null)
		actor.set("lock_on_target", target if target == null or is_instance_valid(target) else null)
	var health_before: int = int(runtime_anchor.get("health", GameState.get_stat("health")))
	if GameState.get_stat("health") != health_before:
		GameState.set_stat("health", health_before)
	var objective_before: String = str(runtime_anchor.get("objective", GameState.current_objective))
	if GameState.current_objective != objective_before:
		GameState.set_objective(objective_before)
	var previous_camera: Variant = runtime_anchor.get("camera", null)
	if previous_camera is Camera3D and is_instance_valid(previous_camera):
		(previous_camera as Camera3D).current = true


func _validate_live_contract(definition: PlayableAvatarDefinition) -> Array[String]:
	var failures: Array[String] = _validate_bindings()
	if definition == null:
		return failures
	if ground_motion_motor != null and ground_motion_motor.profile != definition.ground_motion_profile:
		failures.append("ground-motion profile does not match " + definition.avatar_id)
	if vertical_motion_controller != null and vertical_motion_controller.profile != definition.vertical_motion_profile:
		failures.append("vertical-motion profile does not match " + definition.avatar_id)
	if dodge_motion_controller != null and dodge_motion_controller.profile != definition.dodge_motion_profile:
		failures.append("dodge profile does not match " + definition.avatar_id)
	if combat_footwork_controller != null and combat_footwork_controller.profile != definition.combat_footwork_profile:
		failures.append("combat-footwork profile does not match " + definition.avatar_id)
	if weapon_controller != null and weapon_controller.equipped_weapon != definition.weapon_definition:
		failures.append("weapon does not match " + definition.avatar_id)
	if ability_caster != null and ability_caster.get("loadout") != definition.ability_loadout:
		failures.append("ability loadout does not match " + definition.avatar_id)
	if wire_renderer != null and wire_renderer.active_avatar_id != definition.avatar_id:
		failures.append("wire presentation does not match " + definition.avatar_id)
	if actor != null and actor.get_instance_id() != int(_capture_runtime_anchor().get("actor_instance_id", actor.get_instance_id())):
		failures.append("stable actor anchor changed")
	if camera != null and get_viewport().get_camera_3d() != camera:
		failures.append("player camera ownership changed")
	return failures


func _quiesce_actions(reason: String) -> void:
	if ability_caster != null:
		if ability_caster.has_method("cancel_ground_targeting"):
			ability_caster.call("cancel_ground_targeting", false)
		if ability_caster.has_method("cancel_charged_firebolt"):
			ability_caster.call("cancel_charged_firebolt", false)
		if ability_caster.has_method("close_focus_spell_menu"):
			ability_caster.call("close_focus_spell_menu")
	if weapon_controller != null and weapon_controller.current_attack != null:
		weapon_controller.cancel_current_attack(reason)
	if dodge_motion_controller != null and dodge_motion_controller.is_dodge_active():
		dodge_motion_controller.cancel_dodge(reason)
	if combat_footwork_controller != null:
		combat_footwork_controller.cancel_footwork(reason)
	if action_state != null:
		action_state.clear_action_locks()


func _apply_anchor_metadata(definition: PlayableAvatarDefinition) -> void:
	if actor == null:
		return
	var avatar_id: String = definition.avatar_id if definition != null else "grace"
	var display_name: String = definition.display_name if definition != null else "Grace"
	var element: String = definition.element if definition != null else ""
	actor.set_meta("active_avatar_id", avatar_id)
	actor.set_meta("active_avatar_display_name", display_name)
	actor.set_meta("active_avatar_element", element)
	actor.set_meta("avatar_anchor_mode", "stable_player_proxy")


func _get_active_spell_count() -> int:
	if ability_caster == null:
		return 0
	var loadout_value: Variant = ability_caster.get("loadout")
	if loadout_value is AbilityLoadout:
		return (loadout_value as AbilityLoadout).get_equipped_ability_count()
	return 0


func _resource_path(resource: Resource) -> String:
	if resource == null:
		return "none"
	return resource.resource_path if resource.resource_path != "" else resource.get_class()


func _show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
