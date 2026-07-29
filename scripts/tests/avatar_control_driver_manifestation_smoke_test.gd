extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const RuviaAvatar: PlayableAvatarDefinition = preload(
	"res://data/avatars/ruvia_incarnation_prototype.tres"
)
const FireboltAbility: AbilityDefinition = preload(
	"res://data/abilities/firebolt_ability.tres"
)
const FireFieldAbility: AbilityDefinition = preload(
	"res://data/abilities/fire_field_ability.tres"
)
const CombatFeelDummyScene: PackedScene = preload(
	"res://scenes/actors/enemies/combat_feel_dummy.tscn"
)
const ScriptedDriverScript = preload(
	"res://scripts/avatars/scripted_avatar_control_driver.gd"
)

var failures: Array[String] = []
var original_stats: Dictionary = {}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	_prepare_resources()
	var floor: StaticBody3D = _make_floor()
	add_child(floor)
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "ManifestationTestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	add_child(player)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	var player_driver: PlayerAvatarControlDriver = (
		player.get_node_or_null(
			"PlayerControlDriver"
		) as PlayerAvatarControlDriver
	)
	var manager: PlayerManifestationManager = (
		player.get_node_or_null(
			"ManifestationManager"
		) as PlayerManifestationManager
	)
	var avatar_manager: PlayerAvatarManager = (
		player.get_node_or_null("AvatarManager") as PlayerAvatarManager
	)
	var player_camera: Camera3D = (
		player.get_node_or_null(
			"CameraPivot/SpringArm3D/Camera3D"
		) as Camera3D
	)
	_expect(player_driver != null, "Shared player exposes PlayerControlDriver")
	_expect(manager != null, "Shared player exposes ManifestationManager")
	_expect(avatar_manager != null, "Shared player retains Divine Incarnation manager")
	_expect(player_camera != null, "Shared player retains camera")
	if (
		player_driver == null
		or manager == null
		or avatar_manager == null
		or player_camera == null
	):
		_finish(player, floor)
		return

	var player_driver_debug: Dictionary = player_driver.get_debug_data()
	_expect(
		str(player_driver_debug.get("driver_id", "")) == "player_input",
		"Player control driver identifies player input"
	)
	_expect(
		bool(player_driver_debug.get("direct_player_controls_preserved", false)),
		"Player driver preserves existing polished controls"
	)

	var camera_before: Camera3D = get_viewport().get_camera_3d()
	_expect(manager.manifest_prototype(true), "Ruvia manifestation begins")
	var actor: ManifestedAvatarActor = manager.get_active_manifestation()
	_expect(actor != null, "Manifestation manager exposes autonomous Ruvia")
	if actor == null:
		_finish(player, floor)
		return
	actor.set_physics_process(false)
	actor.active_control_driver.set_driver_enabled(false)
	await get_tree().process_frame

	_validate_manifested_contract(
		player,
		actor,
		manager,
		camera_before
	)
	_validate_resource_isolation(player, actor)
	_validate_companion_driver(player, actor)
	_validate_scripted_driver(player, actor)
	_validate_recall(player, actor, manager)

	actor.active_control_driver.set_driver_enabled(false)
	_expect(
		avatar_manager.incarnate(RuviaAvatar, true),
		"Divine Incarnation still activates while manifestation framework is installed"
	)
	_expect(
		not manager.has_active_manifestation(),
		"Incarnation transfer dismisses autonomous Ruvia first"
	)
	_expect(
		avatar_manager.is_incarnated(),
		"Player receives Ruvia after companion dismissal"
	)
	_expect(
		avatar_manager.dismiss_avatar("manifestation smoke cleanup"),
		"Grace restores after the incarnation handoff"
	)

	await get_tree().process_frame
	_finish(player, floor)


func _validate_manifested_contract(
	player: CharacterBody3D,
	actor: ManifestedAvatarActor,
	manager: PlayerManifestationManager,
	camera_before: Camera3D
) -> void:
	_expect(actor != player, "Manifestation uses a separate autonomous body")
	_expect(actor.avatar_definition == RuviaAvatar, "Manifestation uses Ruvia definition")
	_expect(actor.owner_actor == player, "Grace remains manifestation owner")
	_expect(actor.is_in_group("friendly_actor"), "Manifestation is allied")
	_expect(actor.collision_layer == 0, "Manifestation does not become a friendly hit target")
	_expect(
		get_viewport().get_camera_3d() == camera_before,
		"Manifestation preserves Grace's camera ownership"
	)
	_expect(
		actor.ground_motion_motor.profile == RuviaAvatar.ground_motion_profile,
		"Manifestation installs Ruvia ground motion"
	)
	_expect(
		actor.vertical_motion_controller.profile == RuviaAvatar.vertical_motion_profile,
		"Manifestation installs Ruvia vertical motion"
	)
	_expect(
		actor.dodge_controller.profile == RuviaAvatar.dodge_motion_profile,
		"Manifestation installs Ruvia dodge motion"
	)
	_expect(
		actor.combat_footwork_controller.profile
		== RuviaAvatar.combat_footwork_profile,
		"Manifestation installs Ruvia combat footwork"
	)
	_expect(
		actor.weapon_controller.equipped_weapon == RuviaAvatar.weapon_definition,
		"Manifestation equips Ember Halberd"
	)
	_expect(
		actor.authority_controller.get_authority_profile()
		== RuviaAvatar.elemental_authority_profile,
		"Manifestation installs Fire Authority"
	)
	_expect(
		actor.wire_renderer.active_avatar_id == "ruvia",
		"Manifestation wire presentation identifies Ruvia"
	)
	actor.wire_renderer.sample_now(1.0)
	_expect(actor.wire_renderer.has_finite_pose(), "Manifested wire body is finite")
	var manager_debug: Dictionary = manager.get_debug_data()
	_expect(str(manager_debug.get("driver_id", "")) == "companion_ai", "Manager reports companion driver")


func _validate_resource_isolation(
	player: CharacterBody3D,
	actor: ManifestedAvatarActor
) -> void:
	GameState.set_stat("mana", 9)
	GameState.set_stat("stamina", 11)
	actor.action_state.clear_action_locks()
	var mana_before: int = GameState.get_stat("mana")
	_expect(
		actor.authority_controller.begin_ability_channel(actor, FireboltAbility),
		"Manifested Ruvia casts Firebolt"
	)
	_expect(
		GameState.get_stat("mana") == mana_before,
		"Manifested spells do not spend Grace's mana"
	)
	actor.action_state.clear_action_locks()
	var stamina_before: int = GameState.get_stat("stamina")
	var light_attack: WeaponAttackDefinition = (
		actor.weapon_controller.get_moveset().get_attack("ruvia_halberd_l1")
	)
	_expect(
		actor.weapon_controller.start_attack(light_attack),
		"Manifested Ruvia starts an Ember Halberd form"
	)
	_expect(
		GameState.get_stat("stamina") == stamina_before,
		"Manifested attacks do not spend Grace's stamina"
	)
	actor.weapon_controller.cancel_current_attack("resource isolation")
	actor.action_state.clear_action_locks()

	_expect(
		actor.authority_controller.begin_ability_channel(actor, FireFieldAbility),
		"Manifested Ruvia creates an owned Fire Field"
	)
	var field: Node3D = actor.authority_controller.last_owned_field
	_expect(field is ManifestedFireField, "Manifestation uses ally-safe Fire Field")
	if field is ManifestedFireField:
		var player_status: PlayerStatusReceiver = (
			player.get_node_or_null("StatusReceiver") as PlayerStatusReceiver
		)
		player_status.remove_status("burning")
		(field as ManifestedFireField).apply_burning_to_target(player)
		_expect(
			not player_status.has_status("burning"),
			"Ruvia's manifested Fire cannot Burn Grace"
		)
	actor.action_state.clear_action_locks()


func _validate_companion_driver(
	player: CharacterBody3D,
	actor: ManifestedAvatarActor
) -> void:
	var driver: CompanionAvatarControlDriver = actor.companion_driver
	_expect(driver != null, "Manifestation exposes companion driver")
	if driver == null:
		return
	var target: Node = CombatFeelDummyScene.instantiate()
	_expect(target is Node3D, "Companion test target instantiates")
	if not (target is Node3D):
		if target != null:
			target.queue_free()
		return
	var target_3d: Node3D = target as Node3D
	target_3d.name = "ManifestationDriverTarget"
	add_child(target_3d)
	target_3d.global_position = actor.global_position + Vector3(0.0, 0.0, -8.0)
	driver.bind_actor(actor, player)
	driver.set_driver_enabled(true)
	driver.decision_remaining = 0.0
	driver.spell_cooldown_remaining = 0.0
	var intent: AvatarActionIntent = driver.sample_intent(1.0 / 60.0)
	_expect(intent.target == target_3d, "Companion driver selects hostile target")
	_expect(
		intent.spell_id == "firebolt" or intent.movement_direction.length() > 0.1,
		"Companion driver pressures a distant target"
	)
	_expect(
		str(driver.get_debug_data().get("driver_id", "")) == "companion_ai",
		"Companion driver diagnostics identify AI control"
	)
	driver.set_driver_enabled(false)
	target_3d.queue_free()


func _validate_scripted_driver(
	player: CharacterBody3D,
	actor: ManifestedAvatarActor
) -> void:
	var scripted: ScriptedAvatarControlDriver = (
		ScriptedDriverScript.new() as ScriptedAvatarControlDriver
	)
	actor.add_child(scripted)
	scripted.bind_actor(actor, player)
	var steps: Array[Dictionary] = [
		{
			"duration": 0.2,
			"movement_direction": Vector3.FORWARD,
			"movement_strength": 0.5,
			"attack_id": "ruvia_halberd_l1",
			"decision_tag": "test_form",
		},
	]
	scripted.set_sequence(steps, false)
	var intent: AvatarActionIntent = scripted.sample_intent(0.05)
	_expect(intent.attack_id == "ruvia_halberd_l1", "Scripted driver emits authored attack")
	_expect(is_equal_approx(intent.movement_strength, 0.5), "Scripted driver emits authored movement")
	_expect(str(intent.decision_tag) == "test_form", "Scripted driver preserves sequence tag")
	scripted.queue_free()


func _validate_recall(
	player: CharacterBody3D,
	actor: ManifestedAvatarActor,
	manager: PlayerManifestationManager
) -> void:
	actor.global_position = player.global_position + Vector3(30.0, 0.0, 0.0)
	_expect(manager.recall_manifestation("smoke_test"), "Manager recalls separated manifestation")
	_expect(
		actor.global_position.distance_to(player.global_position) < 8.0,
		"Recall returns Ruvia beside Grace"
	)
	_expect(
		int(manager.get_debug_data().get("total_recalls", 0)) >= 1,
		"Recall is reported in manifestation diagnostics"
	)


func _prepare_resources() -> void:
	GameState.set_stat("max_health", 100)
	GameState.set_stat("health", 100)
	GameState.set_stat("max_mana", 20)
	GameState.set_stat("mana", 20)
	GameState.set_stat("max_stamina", 20)
	GameState.set_stat("stamina", 20)
	GameState.set_stat("max_stance", 20)
	GameState.set_stat("stance", 20)


func _make_floor() -> StaticBody3D:
	var floor: StaticBody3D = StaticBody3D.new()
	floor.name = "ManifestationTestFloor"
	floor.position = Vector3(0.0, -0.1, 0.0)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(80.0, 0.2, 80.0)
	collision.shape = shape
	floor.add_child(collision)
	return floor


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _restore_stats() -> void:
	GameState.stats = original_stats.duplicate(true)
	for stat_value: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_value)
		GameState.stat_changed.emit(
			stat_id,
			int(GameState.stats[stat_value])
		)


func _finish(player: Node, floor: Node) -> void:
	if player != null:
		player.queue_free()
	if floor != null:
		floor.queue_free()
	_restore_stats()
	if failures.is_empty():
		print("AVATAR_CONTROL_DRIVER_MANIFESTATION_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error(
			"AVATAR_CONTROL_DRIVER_MANIFESTATION_SMOKE_TEST: "
			+ failure
		)
	get_tree().quit(1)
