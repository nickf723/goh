extends "res://scripts/tests/avatar_control_driver_manifestation_smoke_test.gd"


func _validate_manifested_contract(
	player: CharacterBody3D,
	actor: ManifestedAvatarActor,
	manager: PlayerManifestationManager,
	camera_before: Camera3D
) -> void:
	super._validate_manifested_contract(
		player,
		actor,
		manager,
		camera_before
	)
	_expect(
		not actor.is_in_group("combat_targetable"),
		"Grace's targeting assist excludes manifested Ruvia"
	)
	_expect(
		actor.is_in_group("friendly_manifestation"),
		"Manifested Ruvia exposes explicit friendly identity"
	)
	_expect(
		actor.visual is ManifestedAvatarMotionVisual,
		"Manifestation uses a resource-isolated motion visual"
	)
	var stamina_before: int = GameState.get_stat("stamina")
	GameState.set_stat("stamina", 0)
	_expect(
		actor.visual.resolve_presentation_state() != "exhausted",
		"Grace's empty stamina does not exhaust autonomous Ruvia"
	)
	GameState.set_stat("stamina", stamina_before)


func _validate_resource_isolation(
	player: CharacterBody3D,
	actor: ManifestedAvatarActor
) -> void:
	GameState.set_stat("mana", 9)
	GameState.set_stat("stamina", 11)
	actor.action_state.clear_action_locks()
	var mana_before: int = GameState.get_stat("mana")
	_expect(
		actor.authority_controller.begin_ability_channel(
			actor,
			FireboltAbility
		),
		"Manifested Ruvia casts Firebolt"
	)
	_expect(
		GameState.get_stat("mana") == mana_before,
		"Manifested spells do not spend Grace's mana"
	)
	var projectile: Node = actor.authority_controller.last_cast_instance
	_expect(
		projectile is ManifestedGenericProjectile,
		"Manifestation uses an ally-safe projectile"
	)
	if projectile is ManifestedGenericProjectile:
		_expect(
			(projectile as ManifestedGenericProjectile).should_ignore_target(player),
			"Ruvia's manifested Firebolt ignores Grace"
		)

	actor.action_state.clear_action_locks()
	var stamina_before: int = GameState.get_stat("stamina")
	var moveset: WeaponMovesetDefinition = actor.weapon_controller.get_moveset()
	var light_attack: WeaponAttackDefinition = (
		moveset.get_attack("ruvia_halberd_l1")
		if moveset != null
		else null
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
		actor.authority_controller.begin_ability_channel(
			actor,
			FireFieldAbility
		),
		"Manifested Ruvia creates an owned Fire Field"
	)
	var field: Node3D = actor.authority_controller.last_owned_field
	_expect(
		field is ManifestedFireField,
		"Manifestation uses ally-safe Fire Field"
	)
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
	var driver: RuviaManifestationControlDriver = (
		actor.companion_driver as RuviaManifestationControlDriver
	)
	_expect(driver != null, "Manifestation exposes Ruvia tactical driver")
	if driver == null:
		return

	_clear_manifestation_fields(actor)
	var target_a: Node3D = _spawn_driver_target(
		"ManifestationTacticalTargetA",
		actor.global_position + Vector3(0.0, 0.0, -8.0)
	)
	var target_b: Node3D = _spawn_driver_target(
		"ManifestationTacticalTargetB",
		actor.global_position + Vector3(4.8, 0.0, -3.0)
	)
	_expect(target_a != null and target_b != null, "Tactical test targets instantiate")
	if target_a == null or target_b == null:
		if target_a != null:
			target_a.queue_free()
		if target_b != null:
			target_b.queue_free()
		return

	driver.bind_actor(actor, player)
	driver.set_driver_enabled(true)
	driver.current_target = target_a
	driver.decision_remaining = 0.0
	driver.spell_cooldown_remaining = 0.0
	var opening_intent: AvatarActionIntent = driver.sample_intent(1.0 / 60.0)
	_expect(opening_intent.target == target_a, "Tactical driver retains a valid hostile target")
	_expect(
		opening_intent.spell_id == "firebolt"
		or opening_intent.movement_direction.length() > 0.1,
		"Ruvia pressures a distant target instead of idling"
	)

	target_a.global_position = actor.global_position + Vector3(0.0, 0.0, -3.2)
	target_b.global_position = actor.global_position + Vector3(4.6, 0.0, -2.8)
	driver.current_target = target_a
	driver.last_target_instance_id = target_a.get_instance_id()
	driver.decision_remaining = 0.0
	driver.spell_cooldown_remaining = 99.0
	driver.post_action_reassessment_remaining = 0.0
	driver.reposition_remaining = 0.0
	driver.reposition_requested = false
	driver.attacks_since_reposition = 0
	driver.attacks_since_spell = 0
	driver.actions_on_current_target = 0
	driver.target_switch_pending = false
	driver.planned_attack_queue.clear()
	driver.recent_actions.clear()

	var moveset: WeaponMovesetDefinition = actor.weapon_controller.get_moveset()
	var first_attack: WeaponAttackDefinition = (
		moveset.get_attack("ruvia_halberd_l1")
		if moveset != null
		else null
	)
	_expect(first_attack != null, "Tactical cadence finds Cinder Sweep")
	if first_attack != null:
		_expect(
			actor.weapon_controller.start_attack(first_attack),
			"Tactical cadence starts its first committed form"
		)
		driver.notify_action_result("attack", first_attack.attack_id, true)
		var busy_intent: AvatarActionIntent = driver.sample_intent(1.0 / 60.0)
		_expect(
			not busy_intent.has_action_request(),
			"Ruvia does not request a second action while the first is active"
		)
		actor.weapon_controller.cancel_current_attack("tactical cadence test")
		driver.decision_remaining = 0.0
		var reassess_intent: AvatarActionIntent = driver.sample_intent(1.0 / 60.0)
		_expect(
			not reassess_intent.has_action_request(),
			"Ruvia pauses to reassess after a completed form"
		)
		_expect(
			reassess_intent.movement_direction.length() > 0.1,
			"Post-action reassessment creates visible footwork"
		)
		_expect(
			driver.tactical_mode == "reassess",
			"Driver reports the reassessment state"
		)

	driver.post_action_reassessment_remaining = 0.0
	driver.decision_remaining = 0.0
	var second_attack: WeaponAttackDefinition = (
		moveset.get_attack("ruvia_halberd_l2")
		if moveset != null
		else null
	)
	_expect(second_attack != null, "Tactical cadence finds Backdraft Return")
	if second_attack != null:
		_expect(
			actor.weapon_controller.start_attack(second_attack),
			"Tactical cadence starts a second distinct form"
		)
		driver.notify_action_result("attack", second_attack.attack_id, true)
		driver.sample_intent(1.0 / 60.0)
		actor.weapon_controller.cancel_current_attack("tactical reposition test")
		driver.decision_remaining = 0.0
		var reposition_intent: AvatarActionIntent = driver.sample_intent(1.0 / 60.0)
		_expect(
			driver.reposition_remaining > 0.0,
			"Two committed attacks trigger a reposition phase"
		)
		_expect(
			not reposition_intent.has_action_request()
			and reposition_intent.movement_direction.length() > 0.1,
			"Repositioning moves without immediately bonking again"
		)
		_expect(
			driver.total_repositions >= 1,
			"Tactical driver records deliberate repositioning"
		)

	_clear_manifestation_fields(actor)
	driver.current_target = target_a
	driver.last_target_instance_id = target_a.get_instance_id()
	driver.post_action_reassessment_remaining = 0.0
	driver.reposition_remaining = 0.0
	driver.reposition_requested = false
	driver.decision_remaining = 0.0
	driver.spell_cooldown_remaining = 0.0
	driver.attacks_since_spell = driver.attacks_before_field_setup
	driver.target_switch_pending = false
	var field_setup_intent: AvatarActionIntent = driver.sample_intent(1.0 / 60.0)
	_expect(
		field_setup_intent.spell_id == "fire_field",
		"Ruvia deliberately establishes Fire terrain after a melee sequence"
	)

	driver.spell_cooldown_remaining = 99.0
	driver.post_action_reassessment_remaining = 0.0
	driver.reposition_remaining = 0.0
	driver.reposition_requested = false
	driver.decision_remaining = 0.0
	driver.current_target = target_a
	driver.last_target_instance_id = target_a.get_instance_id()
	driver.actions_on_current_target = driver.actions_before_target_switch
	driver.target_switch_pending = true
	driver.target_switch_remaining = 0.0
	var switch_intent: AvatarActionIntent = driver.sample_intent(1.0 / 60.0)
	_expect(
		driver.current_target == target_b,
		"Ruvia changes targets instead of tunneling one dummy forever"
	)
	_expect(
		switch_intent.movement_direction.length() > 0.1,
		"Target switching produces reposition movement"
	)
	_expect(
		driver.total_target_switches >= 1,
		"Tactical driver records target changes"
	)
	var tactical_debug: Dictionary = driver.get_debug_data()
	_expect(
		tactical_debug.has("tactical_mode")
		and tactical_debug.has("recent_actions")
		and tactical_debug.has("total_repositions"),
		"Tactical diagnostics expose cadence and memory"
	)

	driver.set_driver_enabled(false)
	target_a.queue_free()
	target_b.queue_free()


func _spawn_driver_target(target_name: String, world_position: Vector3) -> Node3D:
	var target: Node = CombatFeelDummyScene.instantiate()
	if not (target is Node3D):
		if target != null:
			target.queue_free()
		return null
	var target_3d: Node3D = target as Node3D
	target_3d.name = target_name
	add_child(target_3d)
	target_3d.global_position = world_position
	return target_3d


func _clear_manifestation_fields(actor: ManifestedAvatarActor) -> void:
	if actor == null or actor.authority_controller == null:
		return
	for field: Node in actor.authority_controller.get_owned_fields():
		if field != null and is_instance_valid(field):
			field.queue_free()
	actor.authority_controller.owned_fields.clear()
	actor.authority_controller.last_owned_field = null
