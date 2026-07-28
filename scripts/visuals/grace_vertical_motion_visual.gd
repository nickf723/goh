extends "res://scripts/visuals/grace_wire_motion_visual.gd"
class_name GraceVerticalMotionVisual

const VERTICAL_STATE_BLOCKERS: Array[String] = [
	"riding",
	"swim_surface",
	"swim_underwater",
	"climb",
	"mantle",
	"defeated",
	"hit",
	"dodge",
	"attack",
	"guard",
	"cast",
	"item",
	"interact",
	"flight",
]

@onready var vertical_motion_controller: PlayerVerticalMotionController = (
	get_parent().get_node_or_null("VerticalMotionController") as PlayerVerticalMotionController
)

var vertical_root_position: Vector3 = Vector3.ZERO
var vertical_root_rotation: Vector3 = Vector3.ZERO
var vertical_body_position: Vector3 = Vector3.ZERO
var vertical_body_rotation: Vector3 = Vector3.ZERO
var vertical_left_leg_position: Vector3 = Vector3.ZERO
var vertical_left_leg_rotation: Vector3 = Vector3.ZERO
var vertical_right_leg_position: Vector3 = Vector3.ZERO
var vertical_right_leg_rotation: Vector3 = Vector3.ZERO


func _ready() -> void:
	super._ready()
	add_to_group("grace_vertical_motion_visual")


func sample_animation_pose(delta: float) -> void:
	_remove_vertical_accent()
	super.sample_animation_pose(delta)
	_apply_vertical_accent()
	sync_animation_anchors()


func resolve_presentation_state() -> String:
	var inherited_state: String = super.resolve_presentation_state()
	if vertical_motion_controller == null:
		return inherited_state
	if VERTICAL_STATE_BLOCKERS.has(inherited_state):
		return inherited_state
	match vertical_motion_controller.vertical_state:
		"launch", "rising", "apex":
			return "jump"
		"falling":
			return "fall"
		"landing":
			return "landing"
	return inherited_state


func get_animation_debug_data() -> Dictionary:
	var debug_data: Dictionary = super.get_animation_debug_data()
	if vertical_motion_controller != null:
		var vertical: Dictionary = vertical_motion_controller.get_debug_data()
		debug_data["vertical_motion_state"] = str(vertical.get("state", "grounded"))
		debug_data["vertical_phase_progress"] = float(vertical.get("phase_progress", 0.0))
		debug_data["vertical_velocity"] = float(vertical.get("vertical_velocity", 0.0))
		debug_data["vertical_coyote"] = float(vertical.get("coyote", 0.0))
		debug_data["vertical_jump_buffer"] = float(vertical.get("jump_buffer", 0.0))
		debug_data["vertical_gravity_scale"] = float(vertical.get("gravity_scale", 1.0))
		debug_data["vertical_landing_kind"] = str(vertical.get("landing_kind", "none"))
		debug_data["vertical_landing_speed"] = float(vertical.get("landing_speed", 0.0))
		debug_data["vertical_landing_strength"] = float(vertical.get("landing_strength", 0.0))
		debug_data["vertical_peak_downward_speed"] = float(
			vertical.get("peak_downward_speed", 0.0)
		)
		debug_data["vertical_visual_override"] = (
			vertical_motion_controller.vertical_state
			in ["launch", "rising", "apex", "falling", "landing"]
			and not VERTICAL_STATE_BLOCKERS.has(presentation_state)
		)
	return debug_data


func _apply_vertical_accent() -> void:
	if vertical_motion_controller == null:
		return
	if dodge_motion_controller != null and dodge_motion_controller.is_dodge_active():
		return
	if (
		combat_footwork_controller != null
		and combat_footwork_controller.is_visual_footwork_active()
	):
		return
	if not control_pose_sample.is_empty():
		return

	var state: String = vertical_motion_controller.vertical_state
	if state not in ["launch", "rising", "apex", "falling", "landing"]:
		return
	if presentation_state not in ["jump", "fall", "landing"]:
		return

	var vertical_profile: VerticalMotionProfile = vertical_motion_controller.profile
	var progress: float = vertical_motion_controller.get_phase_progress()
	var horizontal_speed: float = 0.0
	var local_velocity: Vector3 = Vector3.ZERO
	if actor != null:
		var horizontal_velocity := Vector3(actor.velocity.x, 0.0, actor.velocity.z)
		horizontal_speed = horizontal_velocity.length()
		local_velocity = actor.global_transform.basis.orthonormalized().inverse() * horizontal_velocity
	var speed_weight: float = clampf(horizontal_speed / maxf(locomotion_speed_reference, 0.1), 0.0, 1.0)

	var launch_compression: float = (
		vertical_profile.launch_compression if vertical_profile != null else 0.065
	)
	var rising_extension: float = (
		vertical_profile.rising_extension if vertical_profile != null else 0.035
	)
	var apex_float: float = vertical_profile.apex_float if vertical_profile != null else 0.025
	var falling_brace: float = (
		vertical_profile.falling_brace_radians if vertical_profile != null else 0.14
	)
	var landing_compression: float = (
		vertical_profile.landing_compression if vertical_profile != null else 0.12
	)

	match state:
		"launch":
			var launch_weight: float = 1.0 - smoothstep(0.0, 1.0, progress)
			vertical_root_position.y -= launch_compression * launch_weight
			vertical_body_position.y -= launch_compression * 0.35 * launch_weight
			vertical_body_rotation.x += 0.11 * launch_weight
			vertical_left_leg_position += Vector3(-0.012, -0.025, 0.018) * launch_weight
			vertical_right_leg_position += Vector3(0.012, -0.025, -0.018) * launch_weight
			vertical_left_leg_rotation.x -= 0.12 * launch_weight
			vertical_right_leg_rotation.x += 0.1 * launch_weight
		"rising":
			var rise_weight: float = 1.0 - smoothstep(0.0, 1.0, progress)
			vertical_root_position.y += rising_extension * rise_weight
			vertical_body_rotation.x -= (0.04 + speed_weight * 0.035) * rise_weight
			vertical_root_rotation.z -= clampf(local_velocity.x * 0.012, -0.06, 0.06)
			vertical_left_leg_rotation.x += 0.08 * rise_weight
			vertical_right_leg_rotation.x -= 0.06 * rise_weight
		"apex":
			var apex_weight: float = smoothstep(0.0, 1.0, progress)
			vertical_root_position.y += apex_float * apex_weight
			vertical_body_position.y += apex_float * 0.28 * apex_weight
			vertical_body_rotation.x -= 0.02 * apex_weight
			vertical_left_leg_rotation.x += 0.1 * apex_weight
			vertical_right_leg_rotation.x += 0.08 * apex_weight
			vertical_left_leg_position.z += 0.018 * apex_weight
			vertical_right_leg_position.z -= 0.012 * apex_weight
		"falling":
			var fall_weight: float = smoothstep(0.0, 1.0, progress)
			vertical_root_position.y -= 0.018 * fall_weight
			vertical_body_rotation.x += falling_brace * fall_weight
			vertical_root_rotation.z -= clampf(local_velocity.x * 0.014, -0.08, 0.08)
			vertical_left_leg_rotation.x -= 0.12 * fall_weight
			vertical_right_leg_rotation.x += 0.14 * fall_weight
			vertical_left_leg_position.z -= 0.02 * fall_weight
			vertical_right_leg_position.z += 0.022 * fall_weight
		"landing":
			var landing_wave: float = vertical_motion_controller.get_landing_wave()
			var strength: float = vertical_motion_controller.last_landing_strength
			var compression: float = landing_compression * strength * landing_wave
			vertical_root_position.y -= compression
			vertical_body_position.y -= compression * 0.32
			vertical_body_rotation.x += 0.12 * strength * landing_wave
			vertical_left_leg_position += Vector3(-0.018, -0.02, 0.012) * strength * landing_wave
			vertical_right_leg_position += Vector3(0.018, -0.02, -0.012) * strength * landing_wave
			vertical_left_leg_rotation.x -= 0.16 * strength * landing_wave
			vertical_right_leg_rotation.x += 0.16 * strength * landing_wave

	_apply_vertical_offsets()


func _apply_vertical_offsets() -> void:
	if visual_root != null:
		visual_root.position += vertical_root_position
		visual_root.rotation += vertical_root_rotation
	if body_root != null:
		body_root.position += vertical_body_position
		body_root.rotation += vertical_body_rotation
	if left_leg != null:
		left_leg.position += vertical_left_leg_position
		left_leg.rotation += vertical_left_leg_rotation
	if right_leg != null:
		right_leg.position += vertical_right_leg_position
		right_leg.rotation += vertical_right_leg_rotation


func _remove_vertical_accent() -> void:
	if visual_root != null:
		visual_root.position -= vertical_root_position
		visual_root.rotation -= vertical_root_rotation
	if body_root != null:
		body_root.position -= vertical_body_position
		body_root.rotation -= vertical_body_rotation
	if left_leg != null:
		left_leg.position -= vertical_left_leg_position
		left_leg.rotation -= vertical_left_leg_rotation
	if right_leg != null:
		right_leg.position -= vertical_right_leg_position
		right_leg.rotation -= vertical_right_leg_rotation
	vertical_root_position = Vector3.ZERO
	vertical_root_rotation = Vector3.ZERO
	vertical_body_position = Vector3.ZERO
	vertical_body_rotation = Vector3.ZERO
	vertical_left_leg_position = Vector3.ZERO
	vertical_left_leg_rotation = Vector3.ZERO
	vertical_right_leg_position = Vector3.ZERO
	vertical_right_leg_rotation = Vector3.ZERO
