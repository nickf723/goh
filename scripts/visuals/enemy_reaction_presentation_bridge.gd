extends Node
class_name EnemyReactionPresentationBridge

# Presentation adapter for EnemyActor. HitReceiver remains authoritative for
# health/stance and AirbornePresentationController remains authoritative in air.
# This bridge only turns one gameplay impact into one grounded visual beat.

@export_range(0.0, 20.0, 0.5) var directional_hit_degrees: float = 6.0
@export_range(0.0, 30.0, 0.5) var directional_stagger_degrees: float = 10.0
@export_range(0.01, 0.2, 0.005) var recoil_in_time: float = 0.055
@export_range(0.02, 0.4, 0.01) var recoil_out_time: float = 0.14

var actor: CharacterBody3D
var hit_receiver: Node
var force_receiver: ForceReceiver
var visual: Node
var visual_root: Node3D
var airborne_presentation: Node

var previous_health: int = -1
var previous_stance: int = -1
var pending_health_severity: float = 0.0
var pending_stance_severity: float = 0.0
var pending_stance_break: bool = false
var pending_sources: Array[String] = []
var flush_queued: bool = false

var base_visual_rotation: Vector3 = Vector3.ZERO
var directional_tween: Tween
var reaction_count: int = 0
var last_reaction_kind: String = "none"
var last_reaction_severity: float = 0.0
var last_direction_local: Vector3 = Vector3.ZERO
var last_coalesced_sources: Array[String] = []
var last_airborne_suppressed: bool = false
var bound: bool = false


func _ready() -> void:
	add_to_group("enemy_reaction_presentation_bridge")
	add_to_group("debuggable")
	call_deferred("bind_presentation")


func bind_presentation() -> void:
	actor = get_parent() as CharacterBody3D
	if actor == null:
		return
	hit_receiver = actor.get_node_or_null("HitReceiver")
	force_receiver = actor.get_node_or_null("ForceReceiver") as ForceReceiver
	visual = actor.get_node_or_null("VisualRoot")
	visual_root = visual as Node3D
	airborne_presentation = actor.get_node_or_null("AirbornePresentationController")
	if hit_receiver == null or visual == null:
		return

	previous_health = int(hit_receiver.get("current_health"))
	previous_stance = int(hit_receiver.get("current_stance"))
	if visual_root != null:
		base_visual_rotation = visual_root.rotation

	_take_signal("health_changed", "_on_health_changed")
	_take_signal("stance_changed", "_on_stance_changed")
	_take_signal("stance_broken", "_on_stance_broken")
	bound = true


func _take_signal(signal_name: StringName, callback_name: StringName) -> void:
	if hit_receiver == null or not hit_receiver.has_signal(signal_name):
		return
	var legacy_callback := Callable(visual, callback_name)
	if hit_receiver.is_connected(signal_name, legacy_callback):
		hit_receiver.disconnect(signal_name, legacy_callback)
	var bridge_callback := Callable(self, callback_name)
	if not hit_receiver.is_connected(signal_name, bridge_callback):
		hit_receiver.connect(signal_name, bridge_callback)


func _on_health_changed(current_health: int, maximum_health: int) -> void:
	if previous_health < 0:
		previous_health = maximum_health
	var damage: int = maxi(previous_health - current_health, 0)
	previous_health = current_health
	if damage <= 0 or current_health <= 0:
		return
	pending_health_severity = maxf(
		pending_health_severity,
		clampf(float(damage) / maxf(float(maximum_health) * 0.35, 1.0), 0.6, 1.3)
	)
	_append_source("health")
	_queue_flush()


func _on_stance_changed(current_stance: int, maximum_stance: int) -> void:
	if previous_stance < 0:
		previous_stance = maximum_stance
	var damage: int = maxi(previous_stance - current_stance, 0)
	previous_stance = current_stance
	if damage <= 0 or current_stance <= 0:
		return
	pending_stance_severity = maxf(
		pending_stance_severity,
		clampf(float(damage) / maxf(float(maximum_stance) * 0.45, 1.0), 0.55, 1.0)
	)
	_append_source("stance")
	_queue_flush()


func _on_stance_broken() -> void:
	pending_stance_break = true
	_append_source("stance_break")
	_queue_flush()


func _append_source(source: String) -> void:
	if not pending_sources.has(source):
		pending_sources.append(source)


func _queue_flush() -> void:
	if flush_queued:
		return
	flush_queued = true
	call_deferred("_flush_pending_reaction")


func _flush_pending_reaction() -> void:
	flush_queued = false
	if visual == null or not is_instance_valid(visual):
		_clear_pending()
		return
	if str(visual.get("presentation_state")) == "defeated":
		_clear_pending()
		return

	last_coalesced_sources = pending_sources.duplicate()
	last_airborne_suppressed = _airborne_owns_visual_root()
	if last_airborne_suppressed:
		last_reaction_kind = "airborne_owned"
		last_reaction_severity = maxf(pending_health_severity, pending_stance_severity)
		_clear_pending()
		return

	last_direction_local = _resolve_local_reaction_direction()
	if pending_stance_break:
		last_reaction_kind = "stagger"
		last_reaction_severity = 1.0
		if visual.has_method("start_stagger"):
			visual.call("start_stagger")
		_apply_directional_recoil(last_direction_local, true)
		reaction_count += 1
		_clear_pending()
		return

	var severity: float = maxf(pending_health_severity, pending_stance_severity)
	if severity > 0.0:
		last_reaction_kind = "hit"
		last_reaction_severity = severity
		if visual.has_method("start_hit_reaction"):
			visual.call("start_hit_reaction", severity)
		_apply_directional_recoil(last_direction_local, false)
		reaction_count += 1
	_clear_pending()


func _airborne_owns_visual_root() -> bool:
	if airborne_presentation == null or not is_instance_valid(airborne_presentation):
		return false
	var state: String = str(airborne_presentation.get("presentation_state")).to_lower()
	return state in ["launched", "airborne", "falling", "plunge", "bounce", "landing"]


func _resolve_local_reaction_direction() -> Vector3:
	if actor == null:
		return Vector3.BACK
	var world_direction: Vector3 = Vector3.ZERO
	if force_receiver != null:
		world_direction = force_receiver.external_velocity
		world_direction.y = 0.0
	if world_direction.length_squared() <= 0.0025:
		var player: Node3D = actor.get_tree().get_first_node_in_group("player") as Node3D
		if player != null:
			world_direction = actor.global_position - player.global_position
			world_direction.y = 0.0
	if world_direction.length_squared() <= 0.0025:
		world_direction = actor.global_transform.basis.z
	var local_direction: Vector3 = actor.global_transform.basis.inverse() * world_direction.normalized()
	local_direction.y = 0.0
	return local_direction.normalized() if local_direction.length_squared() > 0.001 else Vector3.BACK


func _apply_directional_recoil(local_direction: Vector3, stagger: bool) -> void:
	if visual_root == null:
		return
	if directional_tween != null and directional_tween.is_valid():
		directional_tween.kill()
	var strength: float = directional_stagger_degrees if stagger else directional_hit_degrees
	var side: float = clampf(local_direction.x, -1.0, 1.0)
	var back: float = clampf(local_direction.z, -1.0, 1.0)
	var target_rotation: Vector3 = base_visual_rotation + Vector3(
		deg_to_rad(back * strength * 0.42),
		deg_to_rad(side * strength * 0.18),
		deg_to_rad(-side * strength)
	)
	directional_tween = create_tween()
	directional_tween.tween_property(
		visual_root,
		"rotation",
		target_rotation,
		recoil_in_time
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	directional_tween.tween_property(
		visual_root,
		"rotation",
		base_visual_rotation,
		recoil_out_time * (1.35 if stagger else 1.0)
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func cancel_presentation() -> void:
	if directional_tween != null and directional_tween.is_valid():
		directional_tween.kill()
	directional_tween = null
	_clear_pending()
	flush_queued = false
	if visual_root != null and is_instance_valid(visual_root):
		visual_root.rotation = base_visual_rotation
	last_reaction_kind = "cancelled"


func _clear_pending() -> void:
	pending_health_severity = 0.0
	pending_stance_severity = 0.0
	pending_stance_break = false
	pending_sources.clear()


func get_debug_data() -> Dictionary:
	return {
		"enemy_reaction_presentation_bridge": true,
		"bound": bound,
		"reaction_count": reaction_count,
		"last_reaction": last_reaction_kind,
		"last_severity": snappedf(last_reaction_severity, 0.01),
		"last_direction_local": last_direction_local,
		"last_sources": last_coalesced_sources.duplicate(),
		"airborne_suppressed": last_airborne_suppressed,
		"coalesces_health_and_stance": true,
		"airborne_authority_preserved": true,
		"defeat_cancellable": true,
		"gameplay_authority": false,
	}
