extends Node
class_name PlayerRecoveryController

const SafeDestinationQueryScript = preload("res://scripts/quality/safe_destination_query.gd")

signal safe_transform_recorded(recovery_transform: Transform3D)
signal recovery_started(reason: String)
signal recovery_finished(reason: String, recovery_transform: Transform3D)

@export var fallback_minimum_y: float = -24.0
@export var safe_sample_interval: float = 0.28
@export var outside_bounds_grace_seconds: float = 0.18
@export var recovery_invulnerability_seconds: float = 0.8
@export var show_recovery_messages: bool = true

var actor: CharacterBody3D
var playable_space: Node
var initial_transform: Transform3D = Transform3D.IDENTITY
var last_safe_transform: Transform3D = Transform3D.IDENTITY
var manual_recovery_transform: Transform3D = Transform3D.IDENTITY
var pending_override_transform: Transform3D = Transform3D.IDENTITY
var has_last_safe_transform: bool = false
var has_manual_recovery_transform: bool = false
var has_pending_override: bool = false
var pending_reason: String = ""
var sample_timer: float = 0.0
var outside_bounds_timer: float = 0.0
var recovering: bool = false
var recovery_count: int = 0


func _ready() -> void:
	actor = get_parent() as CharacterBody3D
	if actor == null:
		set_physics_process(false)
		return
	initial_transform = actor.global_transform
	last_safe_transform = initial_transform
	has_last_safe_transform = true
	add_to_group("player_recovery_controller")
	call_deferred("_refresh_playable_space")


func _physics_process(delta: float) -> void:
	if actor == null or recovering:
		return
	if bool(actor.get("is_defeated")):
		return
	if playable_space == null or not is_instance_valid(playable_space):
		_refresh_playable_space()

	if pending_reason != "":
		recover_now(pending_reason)
		return

	var minimum_y: float = fallback_minimum_y
	if playable_space != null:
		minimum_y = float(playable_space.get("minimum_recovery_y"))
	if actor.global_position.y < minimum_y:
		recover_now("fell below the playable space")
		return

	if playable_space != null and playable_space.has_method("contains_position"):
		if not bool(playable_space.call("contains_position", actor.global_position)):
			outside_bounds_timer += maxf(delta, 0.0)
			if outside_bounds_timer >= outside_bounds_grace_seconds:
				recover_now("left the playable boundary")
				return
		else:
			outside_bounds_timer = 0.0

	sample_timer -= maxf(delta, 0.0)
	if sample_timer <= 0.0:
		sample_timer = maxf(safe_sample_interval, 0.05)
		if _can_record_safe_transform():
			record_safe_transform(actor.global_transform)


func request_recovery(
	reason: String = "unsafe position",
	override_transform: Transform3D = Transform3D.IDENTITY,
	use_override: bool = false
) -> void:
	pending_reason = reason
	has_pending_override = use_override
	if use_override:
		pending_override_transform = override_transform


func set_manual_recovery_transform(value: Transform3D) -> void:
	manual_recovery_transform = value
	has_manual_recovery_transform = true


func clear_manual_recovery_transform() -> void:
	has_manual_recovery_transform = false


func record_safe_transform(value: Transform3D) -> void:
	last_safe_transform = value
	has_last_safe_transform = true
	safe_transform_recorded.emit(last_safe_transform)


func recover_now(reason: String = "unsafe position") -> void:
	if actor == null or recovering:
		return
	recovering = true
	recovery_started.emit(reason)
	var target_transform: Transform3D = _resolve_recovery_transform()
	_cancel_unstable_states()

	var safe_result: Dictionary = SafeDestinationQueryScript.find_safe_destination(actor, target_transform.origin, {
		"playable_space": playable_space,
		"start_position": initial_transform.origin,
		"require_ground": true,
		"max_rise": 3.0,
		"max_drop": 8.0,
		"search_steps": 8,
	})
	if bool(safe_result.get("valid", false)):
		target_transform.origin = safe_result.get("position", target_transform.origin)

	actor.global_transform = target_transform
	actor.velocity = Vector3.ZERO
	GameState.begin_player_invulnerability(recovery_invulnerability_seconds)
	record_safe_transform(target_transform)
	recovery_count += 1
	pending_reason = ""
	has_pending_override = false
	outside_bounds_timer = 0.0
	_show_message("Grace returned to safe ground.")
	recovery_finished.emit(reason, target_transform)
	call_deferred("_finish_recovery")


func _finish_recovery() -> void:
	recovering = false


func _resolve_recovery_transform() -> Transform3D:
	if has_pending_override:
		return pending_override_transform
	if has_manual_recovery_transform:
		return manual_recovery_transform
	var fallback: Transform3D = last_safe_transform if has_last_safe_transform else initial_transform
	if playable_space != null and playable_space.has_method("get_recovery_transform"):
		return playable_space.call("get_recovery_transform", fallback) as Transform3D
	return fallback


func _can_record_safe_transform() -> bool:
	if actor == null or not actor.is_on_floor():
		return false
	if absf(actor.velocity.y) > 1.5:
		return false
	if playable_space != null and playable_space.has_method("is_position_allowed"):
		if not bool(playable_space.call("is_position_allowed", actor.global_position)):
			return false
	if _special_locomotion_active():
		return false
	return true


func _special_locomotion_active() -> bool:
	var swimming: Node = actor.get_node_or_null("SwimmingController")
	if swimming != null and swimming.has_method("should_handle_locomotion"):
		if bool(swimming.call("should_handle_locomotion")):
			return true
	var climbing: Node = actor.get_node_or_null("ClimbingController")
	if climbing != null and climbing.has_method("should_handle_locomotion"):
		if bool(climbing.call("should_handle_locomotion")):
			return true
	var riding: Node = actor.get_node_or_null("RidingController")
	if riding != null and riding.has_method("is_riding"):
		if bool(riding.call("is_riding")):
			return true
	var tether: Node = actor.get_node_or_null("MetalTetherController")
	if tether != null and tether.has_method("should_handle_locomotion"):
		if bool(tether.call("should_handle_locomotion")):
			return true
	var aerial: Node = actor.get_node_or_null("AerialLocomotion")
	if aerial != null and bool(aerial.get("flight_active")):
		return true
	return false


func _cancel_unstable_states() -> void:
	if actor.has_method("cancel_combat_motion"):
		actor.call("cancel_combat_motion")
	if actor.has_method("clear_lock_on"):
		actor.call("clear_lock_on")

	var riding: Node = actor.get_node_or_null("RidingController")
	if riding != null and riding.has_method("is_riding") and bool(riding.call("is_riding")):
		riding.call("dismount", true)
	var tether: Node = actor.get_node_or_null("MetalTetherController")
	if tether != null and tether.has_method("release_tether"):
		tether.call("release_tether", "recovery", false)
	var swimming: Node = actor.get_node_or_null("SwimmingController")
	if swimming != null and swimming.has_method("reset_swimming"):
		swimming.call("reset_swimming")
	var climbing: Node = actor.get_node_or_null("ClimbingController")
	if climbing != null and climbing.has_method("reset_climbing"):
		climbing.call("reset_climbing")
	var aerial: Node = actor.get_node_or_null("AerialLocomotion")
	if aerial != null and aerial.has_method("finish_flight"):
		aerial.call("finish_flight", false, false)
	var dodge: Node = actor.get_node_or_null("PlayerDodgeController")
	if dodge != null and dodge.has_method("cancel_into_weapon_technique"):
		dodge.call("cancel_into_weapon_technique")
	var action_state: Node = actor.get_node_or_null("PlayerActionState")
	if action_state != null and action_state.has_method("clear_action_locks"):
		action_state.call("clear_action_locks")
	for channel: Node in get_tree().get_nodes_in_group("player_ability_channels"):
		if actor.is_ancestor_of(channel) and channel.has_method("cancel_ability_channel"):
			channel.call("cancel_ability_channel")
	actor.velocity = Vector3.ZERO


func _refresh_playable_space() -> void:
	playable_space = null
	if actor == null or actor.get_tree() == null:
		return
	var current_scene: Node = actor.get_tree().current_scene
	for candidate: Node in actor.get_tree().get_nodes_in_group("playable_space"):
		if current_scene == null or candidate == current_scene or current_scene.is_ancestor_of(candidate):
			playable_space = candidate
			return


func _show_message(message: String) -> void:
	if not show_recovery_messages:
		return
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)


func get_debug_data() -> Dictionary:
	return {
		"has_space": playable_space != null,
		"last_safe": last_safe_transform.origin,
		"manual_anchor": has_manual_recovery_transform,
		"recovering": recovering,
		"recoveries": recovery_count,
		"minimum_y": float(playable_space.get("minimum_recovery_y")) if playable_space != null else fallback_minimum_y,
	}
