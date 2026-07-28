extends Node

const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")
const WeaponCharacterPoseCatalogScript = preload(
	"res://scripts/weapons/weapon_character_pose_catalog.gd"
)

const EXPECTED_STATES: Array[String] = [
	"idle", "locomotion", "jump", "fall", "landing", "swim_surface", "swim_underwater", "climb", "mantle",
	"attack", "guard", "dodge", "hit", "cast", "flight", "exhausted", "defeated",
]


func _ready() -> void:
	var floor: StaticBody3D = _make_grounding_floor()
	add_child(floor)
	var step: StaticBody3D = _make_step_fixture()
	add_child(step)

	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.position = Vector3(0.0, 0.96, 2.0)
	add_child(player)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	var visual: GraceWireMotionVisual = player.get_node_or_null("GraceVisualV1") as GraceWireMotionVisual
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
	var step_up: PlayerStepUpController = (
		player.get_node_or_null("StepUpController") as PlayerStepUpController
	)
	var weapon: WeaponController = player.get_node_or_null("WeaponController") as WeaponController
	var weapon_control: PlayerWeaponControlAnimator = (
		player.get_node_or_null("PlayerWeaponControlAnimator") as PlayerWeaponControlAnimator
	)
	var weapon_anchor: Node3D = player.get_node_or_null("WeaponController/HandAnchor") as Node3D

	assert(visual != null)
	assert(wire != null)
	assert(equipment_appearance != null)
	assert(feedback != null)
	assert(climbing != null)
	assert(step_up != null)
	assert(weapon != null)
	assert(weapon_control != null)
	assert(weapon_anchor != null)
	assert(visual.is_in_group("grace_wire_motion_rig"))
	assert(wire.is_in_group("grace_wire_skeleton"))
	assert(step_up.is_in_group("player_step_up_controller"))
	assert(weapon_control.is_in_group("player_weapon_control_animator"))
	assert(visual.get_pose_nodes().size() >= 17)
	assert(visual.left_eye != null and visual.right_eye != null)
	assert(visual.left_brow != null and visual.right_brow != null)

	for profile_error: String in WeaponCharacterPoseCatalogScript.validate_profiles():
		assert(false, profile_error)

	visual.set_debug_forced_state("idle")
	visual.sample_animation_pose(0.016)
	wire.sample_now(1.0)
	assert(wire.get_joint_count() == 19)
	assert(wire.get_segment_count() == 18)
	assert(wire.has_finite_pose())
	assert(wire.get_joint_position("left_hand").distance_to(wire.get_joint_position("right_hand")) > 0.3)
	assert(wire.get_joint_position("head").y > wire.get_joint_position("pelvis").y)
	assert(wire.get_joint_position("left_ankle").y < wire.get_joint_position("left_hip").y)
	validate_grounded_feet(wire)

	for state_name: String in EXPECTED_STATES:
		visual.set_debug_forced_state(state_name)
		visual.sample_animation_pose(0.016)
		wire.sample_now(1.0)
		assert(visual.presentation_state == state_name)
		assert(wire.has_finite_pose())
		if state_name in ["idle", "locomotion", "landing", "attack", "guard", "dodge", "cast"]:
			validate_grounded_feet(wire)

	visual.clear_debug_forced_state()
	climbing.climbing = true
	visual.sample_animation_pose(0.016)
	wire.sample_now(1.0)
	assert(visual.presentation_state == "climb")
	assert(not bool(wire.get_grounding_debug_data().get("active", true)))
	climbing.climbing = false
	climbing.mantling = true
	climbing.mantle_remaining = climbing.mantle_duration * 0.5
	visual.sample_animation_pose(0.016)
	wire.sample_now(1.0)
	assert(visual.presentation_state == "mantle")
	assert(visual.get_mantle_progress() > 0.0)
	assert(not bool(wire.get_grounding_debug_data().get("active", true)))
	climbing.mantling = false

	equipment_appearance.apply_outfit("apprentice_robe")
	assert(str(wire.get_debug_data().get("outfit_id", "")) == "apprentice_robe")

	await validate_step_navigation(player, step_up)
	validate_sword_control(visual, wire, weapon, weapon_control)

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
	assert(debug_data.has("wire_grounding_active"))
	assert(debug_data.has("wire_left_toe_offset"))
	assert(debug_data.has("wire_right_toe_offset"))
	assert(debug_data.has("control_pose_id"))
	assert(debug_data.has("right_hand_drive"))
	assert(feedback.get_debug_data().has("live_effects"))

	print("GraceAnimationSmokeTest: PASS")
	get_tree().quit()


func validate_grounded_feet(wire: GraceWireSkeletonRenderer) -> void:
	var grounding: Dictionary = wire.get_grounding_debug_data()
	assert(bool(grounding.get("active", false)))
	assert(bool(grounding.get("left_hit", false)))
	assert(bool(grounding.get("right_hit", false)))

	var left_toe_bottom: float = wire.get_joint_world_position("left_toe").y - wire.joint_radius
	var right_toe_bottom: float = wire.get_joint_world_position("right_toe").y - wire.joint_radius
	assert(left_toe_bottom >= -0.01)
	assert(right_toe_bottom >= -0.01)
	assert(left_toe_bottom <= 0.04)
	assert(right_toe_bottom <= 0.04)
	assert(wire.get_joint_world_position("left_ankle").y > wire.get_joint_world_position("left_toe").y)
	assert(wire.get_joint_world_position("right_ankle").y > wire.get_joint_world_position("right_toe").y)


func validate_step_navigation(
	player: CharacterBody3D,
	step_up: PlayerStepUpController
) -> void:
	player.global_position = Vector3(0.0, 0.96, 0.0)
	player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(player.is_on_floor())

	var before_height: float = player.global_position.y
	var stepped: bool = step_up.try_step_up(Vector3(0.0, 0.0, -5.0), 1.0 / 60.0)
	assert(stepped)
	assert(step_up.stepped_this_frame)
	assert(step_up.last_step_height >= 0.24)
	assert(step_up.last_step_height <= step_up.maximum_step_height)
	assert(player.global_position.y > before_height + 0.2)
	step_up.finish_step()

	var step_debug: Dictionary = step_up.get_debug_data()
	assert(bool(step_debug.get("stepped", false)))
	assert(str(step_debug.get("reason", "")) == "stepped")

	player.global_position = Vector3(0.0, 0.96, 2.0)
	player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame


func validate_sword_control(
	visual: GraceWireMotionVisual,
	wire: GraceWireSkeletonRenderer,
	weapon: WeaponController,
	weapon_control: PlayerWeaponControlAnimator
) -> void:
	var moveset: WeaponMovesetDefinition = weapon.get_moveset()
	assert(moveset != null)
	for attack: WeaponAttackDefinition in moveset.attacks:
		assert(attack != null)
		assert(attack.character_pose_id != "")
		assert(WeaponCharacterPoseCatalogScript.has_profile(attack.character_pose_id))

	GameState.set_stat("max_stamina", maxi(GameState.get_stat("max_stamina"), 40))
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	var attack: WeaponAttackDefinition = moveset.get_entry_attack("light")
	assert(attack != null)
	assert(weapon.start_attack(attack))

	var attack_speed: float = weapon.get_attack_speed()
	var startup: float = attack.get_startup_duration(attack_speed)
	var active: float = attack.get_active_duration(attack_speed)

	weapon.current_attack_elapsed = startup * 0.88
	visual.sample_animation_pose(0.016)
	weapon_control.sample_now()
	wire.sample_now(1.0)
	var windup_hand: Vector3 = visual.right_hand.position
	var windup_body: Vector3 = visual.body_root.rotation
	var windup_weapon_rotation: Vector3 = weapon.weapon_visual_pivot.rotation_degrees
	assert(weapon_control.is_controlling_attack())
	assert(str(weapon_control.get_debug_data().get("phase", "")) == "startup")

	weapon.current_attack_elapsed = startup + active * 0.82
	visual.sample_animation_pose(0.016)
	weapon_control.sample_now()
	wire.sample_now(1.0)
	var strike_hand: Vector3 = visual.right_hand.position
	var strike_body: Vector3 = visual.body_root.rotation
	var strike_weapon_rotation: Vector3 = weapon.weapon_visual_pivot.rotation_degrees
	var control_debug: Dictionary = weapon_control.get_debug_data()

	assert(str(control_debug.get("phase", "")) == "active")
	assert(float(control_debug.get("weapon_rotation_share", 1.0)) < 0.6)
	assert(bool(control_debug.get("trail_started", false)))
	assert(strike_hand.distance_to(windup_hand) > 0.025)
	assert(strike_body.distance_to(windup_body) > 0.08)
	assert(strike_weapon_rotation.distance_to(windup_weapon_rotation) > 4.0)
	assert(strike_weapon_rotation.length() < attack.strike_rotation_degrees.length() * 0.65)
	assert(wire.has_finite_pose())

	weapon.cancel_current_attack("animation smoke test complete")
	visual.sample_animation_pose(0.016)
	weapon_control.sample_now()
	assert(not weapon_control.is_controlling_attack())


func _make_grounding_floor() -> StaticBody3D:
	var floor: StaticBody3D = StaticBody3D.new()
	floor.name = "GroundingFloor"
	floor.position = Vector3(0.0, -0.1, 0.0)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(8.0, 0.2, 8.0)
	collision.shape = shape
	floor.add_child(collision)
	return floor


func _make_step_fixture() -> StaticBody3D:
	var step: StaticBody3D = StaticBody3D.new()
	step.name = "StepFixture"
	step.position = Vector3(0.0, 0.14, -1.5)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(3.0, 0.28, 2.0)
	collision.shape = shape
	step.add_child(collision)
	return step
