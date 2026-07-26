extends Node
class_name AirbornePresentationController

@export var profile: AirbornePresentationProfile

var actor: CharacterBody3D
var airborne_controller: Node
var visual_root: Node3D
var base_position: Vector3 = Vector3.ZERO
var base_rotation: Vector3 = Vector3.ZERO
var base_scale: Vector3 = Vector3.ONE
var angular_offset: Vector3 = Vector3.ZERO
var presentation_state: String = "grounded"
var spin_direction: float = 1.0
var presentation_locked: bool = false
var presentation_tween: Tween


func _ready() -> void:
	add_to_group("debuggable")
	call_deferred("bind_presentation")


func bind_presentation() -> void:
	actor = get_parent() as CharacterBody3D
	if actor == null:
		return
	airborne_controller = actor.get_node_or_null("AirborneReactionController")
	visual_root = actor.get_node_or_null("VisualRoot") as Node3D
	if visual_root == null:
		return
	if profile == null:
		profile = AirbornePresentationProfile.new()
	base_position = visual_root.position
	base_rotation = visual_root.rotation
	base_scale = visual_root.scale
	spin_direction = -1.0 if actor.get_instance_id() % 2 == 0 else 1.0
	connect_airborne_signals()
	apply_reaction_rhythm()
	reset_presentation()


func connect_airborne_signals() -> void:
	if airborne_controller == null:
		return
	if airborne_controller.has_signal("air_state_changed"):
		var state_callable := Callable(self, "_on_air_state_changed")
		if not airborne_controller.is_connected("air_state_changed", state_callable):
			airborne_controller.connect("air_state_changed", state_callable)
	if airborne_controller.has_signal("landed"):
		var landed_callable := Callable(self, "_on_landed")
		if not airborne_controller.is_connected("landed", landed_callable):
			airborne_controller.connect("landed", landed_callable)
	if airborne_controller.has_signal("ground_bounced"):
		var bounce_callable := Callable(self, "_on_ground_bounced")
		if not airborne_controller.is_connected("ground_bounced", bounce_callable):
			airborne_controller.connect("ground_bounced", bounce_callable)
	if airborne_controller.has_signal("plunge_started"):
		var plunge_callable := Callable(self, "_on_plunge_started")
		if not airborne_controller.is_connected("plunge_started", plunge_callable):
			airborne_controller.connect("plunge_started", plunge_callable)


func apply_reaction_rhythm() -> void:
	if airborne_controller == null or profile == null:
		return
	var bounce_velocity: Variant = airborne_controller.get("ground_bounce_velocity")
	if bounce_velocity != null:
		airborne_controller.set(
			"ground_bounce_velocity",
			float(bounce_velocity) * maxf(profile.bounce_height_multiplier, 0.05)
		)
	var recovery: Variant = airborne_controller.get("landing_recovery_duration")
	if recovery != null:
		airborne_controller.set(
			"landing_recovery_duration",
			float(recovery) * maxf(profile.landing_recovery_multiplier, 0.05)
		)
	var resistance: Variant = airborne_controller.get("juggle_resistance_per_hit")
	if resistance != null:
		airborne_controller.set(
			"juggle_resistance_per_hit",
			float(resistance) * maxf(profile.juggle_resistance_multiplier, 0.05)
		)
	var hitstun: Variant = airborne_controller.get("base_air_hitstun")
	if hitstun != null:
		airborne_controller.set(
			"base_air_hitstun",
			float(hitstun) * maxf(profile.air_hitstun_multiplier, 0.05)
		)


func _process(delta: float) -> void:
	if visual_root == null or profile == null or presentation_locked:
		return
	if presentation_state not in ["launched", "airborne", "falling", "plunge"]:
		return
	angular_offset += profile.get_spin_radians_per_second() * delta * spin_direction
	var target_rotation: Vector3 = base_rotation + angular_offset
	match presentation_state:
		"launched":
			target_rotation += profile.get_rotation_radians(profile.launch_rotation_degrees)
		"falling":
			target_rotation += profile.get_rotation_radians(profile.falling_rotation_degrees)
		"plunge":
			target_rotation += profile.get_rotation_radians(profile.plunge_rotation_degrees)
	var weight: float = clampf(maxf(profile.pose_response, 0.1) * delta, 0.0, 1.0)
	visual_root.rotation = visual_root.rotation.lerp(target_rotation, weight)
	visual_root.scale = visual_root.scale.lerp(multiplied_scale(profile.airborne_scale), weight)
	visual_root.position = visual_root.position.lerp(base_position, weight)


func _on_air_state_changed(_previous_state: String, new_state: String) -> void:
	var normalized_state: String = new_state.to_lower()
	if normalized_state == "grounded":
		recover_to_base(profile.landing_recover_time)
		return
	if normalized_state == "landing":
		return
	presentation_locked = false
	presentation_state = normalized_state


func _on_plunge_started() -> void:
	kill_presentation_tween()
	presentation_locked = false
	presentation_state = "plunge"


func _on_ground_bounced(_bounce_count: int) -> void:
	if visual_root == null or profile == null:
		return
	kill_presentation_tween()
	presentation_locked = true
	presentation_state = "bounce"
	visual_root.scale = multiplied_scale(profile.bounce_scale)
	visual_root.position = base_position + Vector3(0.0, -profile.landing_drop * 0.55, 0.0)
	presentation_tween = create_tween()
	presentation_tween.set_parallel(true)
	presentation_tween.tween_property(
		visual_root,
		"scale",
		multiplied_scale(profile.airborne_scale),
		maxf(profile.bounce_pose_time, 0.05)
	)
	presentation_tween.tween_property(
		visual_root,
		"position",
		base_position,
		maxf(profile.bounce_pose_time, 0.05)
	)
	presentation_tween.finished.connect(Callable(self, "_finish_bounce_pose"))


func _on_landed(recovery_time: float) -> void:
	if visual_root == null or profile == null:
		return
	kill_presentation_tween()
	presentation_locked = true
	presentation_state = "landing"
	visual_root.rotation = base_rotation + profile.get_rotation_radians(profile.landing_rotation_degrees)
	visual_root.scale = multiplied_scale(profile.landing_scale)
	visual_root.position = base_position + Vector3(0.0, -profile.landing_drop, 0.0)
	presentation_tween = create_tween()
	presentation_tween.set_parallel(true)
	var duration: float = maxf(recovery_time, profile.landing_recover_time, 0.05)
	presentation_tween.tween_property(visual_root, "rotation", base_rotation, duration)
	presentation_tween.tween_property(visual_root, "scale", base_scale, duration)
	presentation_tween.tween_property(visual_root, "position", base_position, duration)
	presentation_tween.finished.connect(Callable(self, "_finish_landing_pose"))


func recover_to_base(duration: float) -> void:
	if visual_root == null:
		return
	kill_presentation_tween()
	presentation_locked = true
	presentation_state = "recover"
	presentation_tween = create_tween()
	presentation_tween.set_parallel(true)
	var safe_duration: float = maxf(duration, 0.05)
	presentation_tween.tween_property(visual_root, "rotation", base_rotation, safe_duration)
	presentation_tween.tween_property(visual_root, "scale", base_scale, safe_duration)
	presentation_tween.tween_property(visual_root, "position", base_position, safe_duration)
	presentation_tween.finished.connect(Callable(self, "_finish_recover"))


func _finish_bounce_pose() -> void:
	presentation_tween = null
	presentation_locked = false
	presentation_state = "launched"


func _finish_landing_pose() -> void:
	presentation_tween = null
	presentation_locked = false
	presentation_state = "grounded"
	angular_offset = Vector3.ZERO


func _finish_recover() -> void:
	presentation_tween = null
	presentation_locked = false
	presentation_state = "grounded"
	angular_offset = Vector3.ZERO


func reset_presentation() -> void:
	kill_presentation_tween()
	presentation_locked = false
	presentation_state = "grounded"
	angular_offset = Vector3.ZERO
	if visual_root != null:
		visual_root.position = base_position
		visual_root.rotation = base_rotation
		visual_root.scale = base_scale


func kill_presentation_tween() -> void:
	if presentation_tween != null and presentation_tween.is_valid():
		presentation_tween.kill()
	presentation_tween = null


func multiplied_scale(multiplier: Vector3) -> Vector3:
	return Vector3(
		base_scale.x * multiplier.x,
		base_scale.y * multiplier.y,
		base_scale.z * multiplier.z
	)


func get_debug_data() -> Dictionary:
	return {
		"profile": profile.display_name if profile != null else "none",
		"state": presentation_state,
		"spin": roundi(profile.spin_degrees_per_second.length()) if profile != null else 0,
		"locked": presentation_locked,
		"rotation": visual_root.rotation if visual_root != null else Vector3.ZERO,
		"scale": visual_root.scale if visual_root != null else Vector3.ONE,
	}
