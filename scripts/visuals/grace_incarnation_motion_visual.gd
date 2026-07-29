extends "res://scripts/visuals/grace_vertical_motion_visual.gd"
class_name GraceIncarnationMotionVisual

const WeaponPoseCatalogRouterScript = preload(
	"res://scripts/weapons/weapon_pose_catalog_router.gd"
)

@onready var incarnation_weapon_controller: WeaponController = (
	get_parent().get_node_or_null("WeaponController") as WeaponController
)


func _ready() -> void:
	super._ready()
	add_to_group("grace_incarnation_motion_visual")


func _resolve_control_pose_sample() -> Dictionary:
	if incarnation_weapon_controller == null:
		return super._resolve_control_pose_sample()
	var attack: WeaponAttackDefinition = incarnation_weapon_controller.current_attack
	if attack == null:
		return {}
	if not WeaponPoseCatalogRouterScript.has_profile(attack.character_pose_id):
		return super._resolve_control_pose_sample()
	return WeaponPoseCatalogRouterScript.sample_attack(
		attack,
		incarnation_weapon_controller.current_attack_elapsed,
		incarnation_weapon_controller.get_attack_speed()
	)


func get_animation_debug_data() -> Dictionary:
	var debug_data: Dictionary = super.get_animation_debug_data()
	var avatar_wire: AvatarWireSkeletonRenderer = (
		wire_skeleton_renderer as AvatarWireSkeletonRenderer
	)
	if avatar_wire != null:
		debug_data["active_avatar_id"] = avatar_wire.active_avatar_id
		debug_data["active_avatar_name"] = avatar_wire.active_avatar_display_name
		debug_data["active_avatar_element"] = avatar_wire.active_avatar_element
		debug_data["avatar_palette_override"] = avatar_wire.avatar_palette_override_active
		debug_data["avatar_base_emission"] = avatar_wire.avatar_emission_multiplier
	return debug_data


func _apply_dodge_iframe_highlight() -> void:
	if wire_skeleton_renderer == null:
		return
	var base_energy: float = 1.35
	var avatar_wire: AvatarWireSkeletonRenderer = (
		wire_skeleton_renderer as AvatarWireSkeletonRenderer
	)
	if avatar_wire != null:
		base_energy = avatar_wire.avatar_emission_multiplier
	var weight: float = 0.0
	var peak_energy: float = maxf(base_energy * 1.32, 2.15)
	if dodge_motion_controller != null:
		weight = dodge_motion_controller.get_iframe_visual_weight()
		if dodge_motion_controller.profile != null:
			peak_energy = maxf(
				dodge_motion_controller.profile.iframe_emission_multiplier,
				base_energy * 1.18
			)
	var energy: float = lerpf(base_energy, peak_energy, weight)
	for material: StandardMaterial3D in [
		wire_skeleton_renderer.center_material,
		wire_skeleton_renderer.left_material,
		wire_skeleton_renderer.right_material,
		wire_skeleton_renderer.joint_material,
	]:
		if material != null:
			material.emission_energy_multiplier = energy
