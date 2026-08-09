extends Node
class_name PlayerMotionFeedback

signal footstep_emitted(side: String)
signal jump_emitted(kind: String)
signal landing_emitted(strength: float)
signal motion_state_changed(previous_state: String, next_state: String)

const PresentationServiceScript = preload(
	"res://scripts/presentation/presentation_service.gd"
)

@export var footstep_phase_interval: float = PI
@export var climbing_grip_interval: float = 0.28
@export var maximum_live_effects: int = 16

@export_group("Player Preferences")
@export_range(0.0, 1.0, 0.05) var visual_effect_scale: float = 1.0
@export_range(0.0, 1.0, 0.05) var camera_impulse_scale: float = 1.0

var previous_state: String = "idle"
var previous_stride_bucket: int = 0
var grip_timer: float = 0.0
var footstep_side: bool = false
var live_effects: Array[Node3D] = []
var last_jump_kind: String = "none"
var last_landing_kind: String = "none"
var last_landing_speed: float = 0.0
var last_landing_strength: float = 0.0
var last_presentation_camera_strength: float = 0.0

@onready var actor: CharacterBody3D = get_parent() as CharacterBody3D
@onready var visual: StylizedActorVisual = get_parent().get_node_or_null("GraceVisualV1") as StylizedActorVisual
@onready var vertical_motion: PlayerVerticalMotionController = (
	get_parent().get_node_or_null("VerticalMotionController") as PlayerVerticalMotionController
)


func _ready() -> void:
	add_to_group("debuggable")
	if visual != null:
		previous_state = visual.presentation_state
		previous_stride_bucket = floori(visual.stride_phase / maxf(footstep_phase_interval, 0.01))
	if vertical_motion != null:
		if not vertical_motion.jump_started.is_connected(_on_jump_started):
			vertical_motion.jump_started.connect(_on_jump_started)
		if not vertical_motion.landed.is_connected(_on_vertical_landed):
			vertical_motion.landed.connect(_on_vertical_landed)
	# Installing the service here makes the director available in every scene that
	# contains Grace, while still keeping it persistent across scene transitions.
	PresentationServiceScript.get_or_create(get_tree())


func _exit_tree() -> void:
	if vertical_motion == null:
		return
	if vertical_motion.jump_started.is_connected(_on_jump_started):
		vertical_motion.jump_started.disconnect(_on_jump_started)
	if vertical_motion.landed.is_connected(_on_vertical_landed):
		vertical_motion.landed.disconnect(_on_vertical_landed)


func _process(delta: float) -> void:
	_cleanup_effects()
	if visual == null or actor == null:
		return
	var state: String = visual.presentation_state
	if state != previous_state:
		_on_motion_state_changed(previous_state, state)
		previous_state = state
	if state == "locomotion" and actor.is_on_floor() and visual.movement_weight > 0.18:
		_update_footsteps()
	if state == "climb":
		grip_timer -= delta
		if grip_timer <= 0.0:
			grip_timer = climbing_grip_interval
			_spawn_grip_mote()
	else:
		grip_timer = 0.0


func _update_footsteps() -> void:
	var bucket: int = floori(visual.stride_phase / maxf(footstep_phase_interval, 0.01))
	if bucket == previous_stride_bucket:
		return
	previous_stride_bucket = bucket
	footstep_side = not footstep_side
	_spawn_footstep_pulse()
	var side: String = "right" if footstep_side else "left"
	footstep_emitted.emit(side)
	_present_movement("footstep", {
		"position": _get_feet_position(),
		"side": side,
		"strength": clampf(visual.movement_weight * 0.34, 0.12, 0.34),
	})


func _on_motion_state_changed(previous: String, next: String) -> void:
	motion_state_changed.emit(previous, next)
	# The vertical-motion controller owns exact landing impact and timing. Retain the
	# older visual-state fallback for actors that do not install that controller.
	if next == "landing" and vertical_motion == null:
		_spawn_landing_pulse(visual.landing_strength)
		landing_emitted.emit(visual.landing_strength)
		_apply_landing_camera_impulse(visual.landing_strength)
		_present_movement("landing", {
			"position": _get_feet_position(),
			"strength": visual.landing_strength,
			"kind": "visual_fallback",
		})


func _on_jump_started(kind: String, launch_velocity: float) -> void:
	last_jump_kind = kind
	var strength: float = clampf(launch_velocity / 6.5, 0.35, 1.0)
	_spawn_takeoff_pulse(strength)
	jump_emitted.emit(kind)
	_present_movement("jump", {
		"position": _get_feet_position(),
		"strength": strength,
		"kind": kind,
	})


func _on_vertical_landed(kind: String, impact_speed: float, strength: float) -> void:
	last_landing_kind = kind
	last_landing_speed = impact_speed
	last_landing_strength = strength
	if strength <= 0.0:
		return
	_spawn_landing_pulse(strength)
	landing_emitted.emit(strength)
	_apply_landing_camera_impulse(strength)
	_present_movement("landing", {
		"position": _get_feet_position(),
		"strength": strength,
		"impact_speed": impact_speed,
		"kind": kind,
	})


func _present_movement(kind: String, context: Dictionary) -> void:
	var director: GamePresentationDirector = PresentationServiceScript.get_or_create(
		get_tree()
	)
	if director == null:
		return
	var payload: Dictionary = context.duplicate(true)
	payload["actor"] = actor
	director.present_movement(kind, payload)


func _spawn_footstep_pulse() -> void:
	var origin: Vector3 = _get_feet_position()
	origin.x += 0.16 if footstep_side else -0.16
	_spawn_ground_ring(origin, 0.22, Color(0.56, 0.72, 0.9, 0.34), 0.24)


func _spawn_takeoff_pulse(strength: float) -> void:
	_spawn_ground_ring(
		_get_feet_position(),
		lerpf(0.28, 0.52, strength),
		Color(0.48, 0.82, 1.0, 0.42),
		0.26
	)


func _spawn_landing_pulse(strength: float) -> void:
	_spawn_ground_ring(
		_get_feet_position(),
		lerpf(0.55, 1.2, strength),
		Color(0.72, 0.84, 1.0, 0.52),
		0.38
	)


func _spawn_ground_ring(origin: Vector3, radius: float, color: Color, duration: float) -> void:
	var preference_scale: float = clampf(visual_effect_scale, 0.0, 1.0)
	if preference_scale <= 0.001 or get_tree().current_scene == null:
		return
	var ring := MeshInstance3D.new()
	ring.name = "MotionPulse"
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.12
	mesh.height = 0.025
	mesh.radial_segments = 28
	ring.mesh = mesh
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var scaled_color: Color = color
	scaled_color.a *= preference_scale
	material.albedo_color = scaled_color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = lerpf(0.45, 1.1, preference_scale)
	ring.material_override = material
	get_tree().current_scene.add_child(ring)
	ring.global_position = origin + Vector3.UP * 0.025
	_track_effect(ring)
	var tween := ring.create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	var expansion: float = lerpf(1.35, 1.8, preference_scale)
	tween.parallel().tween_property(
		ring,
		"scale",
		Vector3(expansion, 0.15, expansion),
		duration
	)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, duration)
	tween.finished.connect(ring.queue_free)


func _spawn_grip_mote() -> void:
	var preference_scale: float = clampf(visual_effect_scale, 0.0, 1.0)
	if preference_scale <= 0.001 or get_tree().current_scene == null:
		return
	var use_left: bool = int(Time.get_ticks_msec() / 280) % 2 == 0
	var anchor_path: String = "GraceVisualV1/LeftHandAnchor" if use_left else "GraceVisualV1/RightHandAnchor"
	var anchor := actor.get_node_or_null(anchor_path) as Node3D
	if anchor == null:
		return
	var mote := MeshInstance3D.new()
	mote.name = "GripMote"
	mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := SphereMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.07
	mote.mesh = mesh
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.65, 0.82, 1.0, 0.7 * preference_scale)
	material.emission_enabled = true
	material.emission = Color(0.42, 0.7, 1.0)
	material.emission_energy_multiplier = lerpf(0.7, 1.8, preference_scale)
	mote.material_override = material
	get_tree().current_scene.add_child(mote)
	mote.global_position = anchor.global_position
	mote.scale = Vector3.ONE * lerpf(0.72, 1.0, preference_scale)
	_track_effect(mote)
	var tween := mote.create_tween()
	tween.parallel().tween_property(mote, "global_position:y", mote.global_position.y - 0.22, 0.34)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.34)
	tween.finished.connect(mote.queue_free)


func _apply_landing_camera_impulse(strength: float) -> void:
	var scaled_strength: float = strength * clampf(camera_impulse_scale, 0.0, 1.0)
	if scaled_strength <= 0.001:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var original_offset: float = camera.v_offset
	camera.v_offset = original_offset - 0.045 * scaled_strength
	var tween := camera.create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "v_offset", original_offset, 0.16)


func apply_presentation_camera_impulse(
	world_direction: Vector3,
	strength: float
) -> void:
	var scaled_strength: float = clampf(strength, 0.0, 1.0) * clampf(
		camera_impulse_scale,
		0.0,
		1.0
	)
	last_presentation_camera_strength = scaled_strength
	if scaled_strength <= 0.001:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var direction: Vector3 = world_direction
	if direction.length_squared() > 0.0001:
		direction = direction.normalized()
	var horizontal_sign: float = 0.0
	if direction.length_squared() > 0.0001:
		horizontal_sign = clampf(direction.dot(camera.global_basis.x), -1.0, 1.0)
	var original_h: float = camera.h_offset
	var original_v: float = camera.v_offset
	camera.h_offset = original_h + horizontal_sign * 0.034 * scaled_strength
	camera.v_offset = original_v - 0.028 * scaled_strength
	var tween := camera.create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(camera, "h_offset", original_h, 0.14)
	tween.parallel().tween_property(camera, "v_offset", original_v, 0.14)


func _get_feet_position() -> Vector3:
	var anchor := actor.get_node_or_null("GraceVisualV1/FeetVFXAnchor") as Node3D
	if anchor != null:
		return anchor.global_position
	return actor.global_position - Vector3.UP


func _track_effect(effect: Node3D) -> void:
	live_effects.append(effect)
	while live_effects.size() > maximum_live_effects:
		var oldest: Node3D = live_effects.pop_front()
		if oldest != null and is_instance_valid(oldest):
			oldest.queue_free()


func _cleanup_effects() -> void:
	var valid_effects: Array[Node3D] = []
	for effect: Node3D in live_effects:
		if effect != null and is_instance_valid(effect) and not effect.is_queued_for_deletion():
			valid_effects.append(effect)
	live_effects = valid_effects


func get_debug_data() -> Dictionary:
	return {
		"state": previous_state,
		"stride_bucket": previous_stride_bucket,
		"footstep_side": "right" if footstep_side else "left",
		"grip_timer": snappedf(grip_timer, 0.01),
		"last_jump_kind": last_jump_kind,
		"last_landing_kind": last_landing_kind,
		"last_landing_speed": snappedf(last_landing_speed, 0.01),
		"last_landing_strength": snappedf(last_landing_strength, 0.01),
		"last_presentation_camera_strength": snappedf(last_presentation_camera_strength, 0.01),
		"visual_effect_scale": snappedf(visual_effect_scale, 0.05),
		"camera_impulse_scale": snappedf(camera_impulse_scale, 0.05),
		"live_effects": live_effects.size(),
		"presentation_directed": true,
	}
