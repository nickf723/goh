extends Node

const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")

const EXPECTED_STATES: Array[String] = [
	"idle", "locomotion", "jump", "fall", "landing", "swim_surface", "swim_underwater", "climb", "mantle",
	"attack", "guard", "dodge", "hit", "cast", "flight", "exhausted", "defeated",
]


func _ready() -> void:
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	add_child(player)
	await get_tree().process_frame

	var visual: StylizedActorVisual = player.get_node_or_null("GraceVisualV1") as StylizedActorVisual
	var wire: GraceWireSkeletonRenderer = (
		player.get_node_or_null("GraceVisualV1/WireSkeletonRenderer") as GraceWireSkeletonRenderer
	)
	var equipment_appearance: GraceWireEquipmentAppearance = (
		player.get_node_or_null("EquipmentAppearanceController") as GraceWireEquipmentAppearance
	)
	var feedback: PlayerMotionFeedback = (
		player.get_node_or_null("PlayerMotionFeedback") as PlayerMotionFeedback
	)
	var climbing: PlayerClimbingController = (
		player.get_node_or_null("ClimbingController") as PlayerClimbingController
	)
	var weapon_anchor: Node3D = player.get_node_or_null("WeaponController/HandAnchor") as Node3D

	assert(visual != null)
	assert(wire != null)
	assert(equipment_appearance != null)
	assert(feedback != null)
	assert(climbing != null)
	assert(weapon_anchor != null)
	assert(visual.is_in_group("grace_wire_motion_rig"))
	assert(wire.is_in_group("grace_wire_skeleton"))
	assert(visual.get_pose_nodes().size() >= 15)
	assert(visual.left_eye != null and visual.right_eye != null)
	assert(visual.left_brow != null and visual.right_brow != null)

	wire.sample_now()
	assert(wire.get_joint_count() == 19)
	assert(wire.get_segment_count() == 18)
	assert(wire.has_finite_pose())
	assert(wire.get_joint_position("left_hand").distance_to(wire.get_joint_position("right_hand")) > 0.3)
	assert(wire.get_joint_position("head").y > wire.get_joint_position("pelvis").y)
	assert(wire.get_joint_position("left_ankle").y < wire.get_joint_position("left_hip").y)

	for state_name: String in EXPECTED_STATES:
		visual.set_debug_forced_state(state_name)
		visual.sample_animation_pose(0.016)
		wire.sample_now()
		assert(visual.presentation_state == state_name)
		assert(wire.has_finite_pose())

	visual.clear_debug_forced_state()
	climbing.climbing = true
	visual.sample_animation_pose(0.016)
	wire.sample_now()
	assert(visual.presentation_state == "climb")
	climbing.climbing = false
	climbing.mantling = true
	climbing.mantle_remaining = climbing.mantle_duration * 0.5
	visual.sample_animation_pose(0.016)
	wire.sample_now()
	assert(visual.presentation_state == "mantle")
	assert(visual.get_mantle_progress() > 0.0)
	climbing.mantling = false

	equipment_appearance.apply_outfit("apprentice_robe")
	assert(str(wire.get_debug_data().get("outfit_id", "")) == "apprentice_robe")

	visual.sample_animation_pose(0.016)
	assert(absf(weapon_anchor.global_basis.determinant()) > 0.5)

	var debug_data: Dictionary = visual.get_animation_debug_data()
	assert(debug_data.has("acceleration"))
	assert(debug_data.has("turn_velocity"))
	assert(debug_data.has("state_elapsed"))
	assert(str(debug_data.get("rig_mode", "")) == "wire_skeleton")
	assert(int(debug_data.get("wire_joint_count", 0)) == 19)
	assert(int(debug_data.get("wire_segment_count", 0)) == 18)
	assert(bool(debug_data.get("wire_finite_pose", false)))
	assert(feedback.get_debug_data().has("live_effects"))

	print("GraceAnimationSmokeTest: PASS")
	get_tree().quit()
