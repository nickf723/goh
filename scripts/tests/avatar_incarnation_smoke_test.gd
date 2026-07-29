extends Node

const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")
const GraceAvatar: PlayableAvatarDefinition = preload(
	"res://data/avatars/grace_avatar_definition.tres"
)
const RuviaAvatar: PlayableAvatarDefinition = preload(
	"res://data/avatars/ruvia_incarnation_prototype.tres"
)


func _ready() -> void:
	for definition: PlayableAvatarDefinition in [GraceAvatar, RuviaAvatar]:
		for definition_error: String in definition.validate_definition():
			assert(false, definition_error)
	assert(RuviaAvatar.avatar_kind == "divine_incarnation")
	assert(RuviaAvatar.element == "fire")
	assert(RuviaAvatar.has_only_matching_element_spells())
	assert(RuviaAvatar.ability_loadout.get_equipped_ability_count() == 2)

	GameState.set_stat("max_health", 80)
	GameState.set_stat("health", 57)
	GameState.set_objective("Preserve the incarnation test objective.")
	var floor: StaticBody3D = _make_floor()
	add_child(floor)
	var target: Node3D = Node3D.new()
	target.name = "PersistentLockTarget"
	target.position = Vector3(0.0, 0.0, -5.0)
	add_child(target)

	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "AvatarProxyPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	var manager: PlayerAvatarManager = (
		player.get_node_or_null("AvatarManager") as PlayerAvatarManager
	)
	var ground: PlayerGroundMotionMotor = (
		player.get_node_or_null("GroundMotionMotor") as PlayerGroundMotionMotor
	)
	var vertical: PlayerVerticalMotionController = (
		player.get_node_or_null("VerticalMotionController") as PlayerVerticalMotionController
	)
	var dodge: PlayerDodgeController = (
		player.get_node_or_null("PlayerDodgeController") as PlayerDodgeController
	)
	var footwork: PlayerCombatFootworkController = (
		player.get_node_or_null("CombatFootworkController") as PlayerCombatFootworkController
	)
	var weapon: WeaponController = player.get_node_or_null("WeaponController") as WeaponController
	var ability_caster: Node = player.get_node_or_null("AbilityCaster")
	var action_state: PlayerActionState = (
		player.get_node_or_null("PlayerActionState") as PlayerActionState
	)
	var visual: GraceIncarnationMotionVisual = (
		player.get_node_or_null("GraceVisualV1") as GraceIncarnationMotionVisual
	)
	var wire: AvatarWireSkeletonRenderer = (
		player.get_node_or_null("GraceVisualV1/WireSkeletonRenderer") as AvatarWireSkeletonRenderer
	)
	var camera: Camera3D = (
		player.get_node_or_null("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	)

	assert(player.is_on_floor())
	assert(manager != null and manager.initialized)
	assert(manager.default_avatar_definition == GraceAvatar)
	assert(manager.prototype_avatar_definition == RuviaAvatar)
	assert(manager.is_in_group("divine_incarnation_manager"))
	assert(player.is_in_group("active_player_avatar"))
	assert(player.is_in_group("player_avatar_anchor"))
	assert(str(player.get_meta("avatar_anchor_mode", "")) == "stable_player_proxy")
	assert(ground != null)
	assert(vertical != null)
	assert(dodge != null)
	assert(footwork != null)
	assert(weapon != null)
	assert(ability_caster != null)
	assert(action_state != null)
	assert(visual != null)
	assert(wire != null)
	assert(camera != null and camera.current)

	player.set_physics_process(false)
	manager.set_process(false)
	visual.set_process(false)
	wire.set_process(false)

	var stable_instance_id: int = player.get_instance_id()
	var baseline_ground: GroundMotionProfile = ground.profile
	var baseline_vertical: VerticalMotionProfile = vertical.profile
	var baseline_dodge: DodgeMotionProfile = dodge.profile
	var baseline_footwork: CombatFootworkProfile = footwork.profile
	var baseline_weapon: WeaponDefinition = weapon.equipped_weapon
	var baseline_loadout: AbilityLoadout = ability_caster.get("loadout") as AbilityLoadout
	var baseline_palette: Color = wire.center_material.albedo_color
	var baseline_camera: Camera3D = get_viewport().get_camera_3d()

	var invalid_definition: PlayableAvatarDefinition = PlayableAvatarDefinition.new()
	invalid_definition.avatar_id = "broken_incarnation"
	invalid_definition.display_name = "Broken Incarnation"
	invalid_definition.avatar_kind = "divine_incarnation"
	invalid_definition.element = "fire"
	assert(not manager.incarnate(invalid_definition, true))
	assert(not manager.is_incarnated())
	assert(ground.profile == baseline_ground)
	assert(weapon.equipped_weapon == baseline_weapon)
	assert(manager.last_transition_result == "validation_failed")

	var incarnation_transform := Transform3D(
		Basis.from_euler(Vector3(0.0, 0.42, 0.0)),
		Vector3(1.25, 1.4, -0.8)
	)
	var incarnation_velocity := Vector3(2.1, 1.3, -0.75)
	player.global_transform = incarnation_transform
	player.velocity = incarnation_velocity
	player.set("lock_on_target", target)
	action_state.begin_cast(0.5)
	assert(action_state.is_casting)

	assert(manager.incarnate(RuviaAvatar, true))
	assert(manager.is_incarnated())
	assert(manager.get_active_avatar_id() == "ruvia")
	assert(player.get_instance_id() == stable_instance_id)
	assert(player.global_transform.is_equal_approx(incarnation_transform))
	assert(player.velocity.is_equal_approx(incarnation_velocity))
	assert(player.get("lock_on_target") == target)
	assert(get_viewport().get_camera_3d() == baseline_camera)
	assert(camera.current)
	assert(GameState.get_stat("health") == 57)
	assert(GameState.current_objective == "Preserve the incarnation test objective.")
	assert(not action_state.is_casting)

	assert(ground.profile == RuviaAvatar.ground_motion_profile)
	assert(vertical.profile == RuviaAvatar.vertical_motion_profile)
	assert(dodge.profile == RuviaAvatar.dodge_motion_profile)
	assert(footwork.profile == RuviaAvatar.combat_footwork_profile)
	assert(weapon.equipped_weapon == RuviaAvatar.weapon_definition)
	assert(weapon.equipped_weapon.weapon_class == "halberd")
	assert(weapon.runtime_weapon_rig != null)
	assert(ability_caster.get("loadout") == RuviaAvatar.ability_loadout)
	for spell_index: int in range(
		RuviaAvatar.ability_loadout.get_equipped_ability_count()
	):
		var spell: AbilityDefinition = (
			RuviaAvatar.ability_loadout.get_equipped_ability(spell_index)
		)
		assert(spell != null and spell.element == "fire")

	assert(wire.active_avatar_id == "ruvia")
	assert(wire.active_avatar_element == "fire")
	assert(wire.avatar_palette_override_active)
	assert(wire.center_material.albedo_color.is_equal_approx(RuviaAvatar.wire_center_color))
	assert(wire.left_material.albedo_color.is_equal_approx(RuviaAvatar.wire_left_color))
	assert(wire.right_material.albedo_color.is_equal_approx(RuviaAvatar.wire_right_color))
	visual.sample_animation_pose(1.0 / 60.0)
	wire.sample_now(1.0)
	assert(wire.center_material.emission_energy_multiplier >= RuviaAvatar.wire_emission_multiplier - 0.01)
	assert(wire.has_finite_pose())
	var incarnation_visual_debug: Dictionary = visual.get_animation_debug_data()
	assert(str(incarnation_visual_debug.get("active_avatar_id", "")) == "ruvia")
	assert(str(incarnation_visual_debug.get("active_avatar_element", "")) == "fire")

	var manager_debug: Dictionary = manager.get_debug_data()
	assert(bool(manager_debug.get("initialized", false)))
	assert(bool(manager_debug.get("incarnated", false)))
	assert(bool(manager_debug.get("camera_preserved", false)))
	assert(int(manager_debug.get("stable_actor_instance_id", -1)) == stable_instance_id)
	assert(int(manager_debug.get("current_actor_instance_id", -2)) == stable_instance_id)
	assert(str(manager_debug.get("weapon_class", "")) == "halberd")
	assert(int(manager_debug.get("spell_count", 0)) == 2)

	var return_transform := Transform3D(
		Basis.from_euler(Vector3(0.0, -0.6, 0.0)),
		Vector3(-2.0, 2.1, 1.7)
	)
	var return_velocity := Vector3(-1.4, -2.0, 0.8)
	player.global_transform = return_transform
	player.velocity = return_velocity
	GameState.set_stat("health", 43)
	GameState.set_objective("The god travelled while Grace remained the anchor.")
	assert(manager.dismiss_avatar("smoke_test"))
	assert(not manager.is_incarnated())
	assert(manager.get_active_avatar_id() == "grace")
	assert(player.get_instance_id() == stable_instance_id)
	assert(player.global_transform.is_equal_approx(return_transform))
	assert(player.velocity.is_equal_approx(return_velocity))
	assert(player.get("lock_on_target") == target)
	assert(GameState.get_stat("health") == 43)
	assert(GameState.current_objective == "The god travelled while Grace remained the anchor.")
	assert(get_viewport().get_camera_3d() == baseline_camera)
	assert(ground.profile == baseline_ground)
	assert(vertical.profile == baseline_vertical)
	assert(dodge.profile == baseline_dodge)
	assert(footwork.profile == baseline_footwork)
	assert(weapon.equipped_weapon == baseline_weapon)
	assert(ability_caster.get("loadout") == baseline_loadout)
	assert(not wire.avatar_palette_override_active)
	assert(wire.active_avatar_id == "grace")
	assert(wire.center_material.albedo_color.is_equal_approx(baseline_palette))

	# A live contract mutation cannot strand Grace in a broken incarnation. The
	# watchdog restores the baseline kit while keeping the current world anchor.
	assert(manager.incarnate(RuviaAvatar, true))
	var watchdog_transform: Transform3D = player.global_transform
	weapon.equip_weapon(baseline_weapon)
	manager._process(manager.watchdog_interval + 0.01)
	assert(not manager.is_incarnated())
	assert(manager.last_transition_result == "emergency_restored")
	assert(manager.rollback_count >= 1)
	assert(player.global_transform.is_equal_approx(watchdog_transform))
	assert(weapon.equipped_weapon == baseline_weapon)
	assert(ground.profile == baseline_ground)
	assert(wire.active_avatar_id == "grace")

	# Timed manifestations use the same safe dismissal path.
	var timed_ruvia: PlayableAvatarDefinition = RuviaAvatar.duplicate(true) as PlayableAvatarDefinition
	timed_ruvia.avatar_id = "ruvia_timed_test"
	timed_ruvia.display_name = "Ruvia Timed Test"
	timed_ruvia.manifestation_duration = 0.05
	assert(manager.incarnate(timed_ruvia, true))
	assert(manager.is_incarnated())
	manager._process(0.06)
	assert(not manager.is_incarnated())
	assert(manager.last_dismiss_reason == "manifestation_expired")
	assert(weapon.equipped_weapon == baseline_weapon)
	assert(ability_caster.get("loadout") == baseline_loadout)

	print("AVATAR_INCARNATION_SMOKE_TEST: PASS")
	get_tree().quit(0)


func _make_floor() -> StaticBody3D:
	var floor: StaticBody3D = StaticBody3D.new()
	floor.name = "AvatarIncarnationFloor"
	floor.position = Vector3(0.0, -0.1, 0.0)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(18.0, 0.2, 18.0)
	collision.shape = shape
	floor.add_child(collision)
	return floor
