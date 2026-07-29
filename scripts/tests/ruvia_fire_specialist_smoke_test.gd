extends Node

const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")
const RuviaAvatar: PlayableAvatarDefinition = preload(
	"res://data/avatars/ruvia_incarnation_prototype.tres"
)
const FireboltAbility: AbilityDefinition = preload(
	"res://data/abilities/firebolt_ability.tres"
)
const FireFieldAbility: AbilityDefinition = preload(
	"res://data/abilities/fire_field_ability.tres"
)
const EnemyStatusReceiverScript = preload(
	"res://scripts/combat/status_receiver.gd"
)

var failures: Array[String] = []
var original_stats: Dictionary = {}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	_capture_stats()
	_prepare_stats()
	var floor: StaticBody3D = _make_floor()
	add_child(floor)
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "RuviaFireSpecialistTestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	var manager: PlayerAvatarManager = (
		player.get_node_or_null("AvatarManager") as PlayerAvatarManager
	)
	var authority: PlayerElementalAuthorityController = (
		player.get_node_or_null(
			"ElementalAuthorityController"
		) as PlayerElementalAuthorityController
	)
	var defense: PlayerDefenseController = (
		player.get_node_or_null(
			"PlayerDefenseController"
		) as PlayerDefenseController
	)
	var status_receiver: PlayerStatusReceiver = (
		player.get_node_or_null("StatusReceiver") as PlayerStatusReceiver
	)
	var weapon: WeaponController = (
		player.get_node_or_null("WeaponController") as WeaponController
	)
	var animator: PlayerWeaponControlAnimator = (
		player.get_node_or_null(
			"PlayerWeaponControlAnimator"
		) as PlayerWeaponControlAnimator
	)
	var visual: GraceElementalAuthorityMotionVisual = (
		player.get_node_or_null(
			"GraceVisualV1"
		) as GraceElementalAuthorityMotionVisual
	)
	var wire: AvatarWireSkeletonRenderer = (
		player.get_node_or_null(
			"GraceVisualV1/WireSkeletonRenderer"
		) as AvatarWireSkeletonRenderer
	)
	var action_state: PlayerActionState = (
		player.get_node_or_null("PlayerActionState") as PlayerActionState
	)

	_expect(manager != null, "Shared player exposes avatar manager")
	_expect(authority != null, "Shared player exposes elemental authority")
	_expect(defense != null, "Shared player exposes authority-aware defense")
	_expect(status_receiver != null, "Shared player exposes a status receiver")
	_expect(weapon != null, "Shared player exposes weapon controller")
	_expect(animator != null, "Shared player exposes weapon animator")
	_expect(visual != null, "Shared player exposes authority motion visual")
	_expect(wire != null, "Shared player exposes avatar wire renderer")
	_expect(action_state != null, "Shared player exposes action state")
	if (
		manager == null
		or authority == null
		or defense == null
		or status_receiver == null
		or weapon == null
		or animator == null
		or visual == null
		or wire == null
		or action_state == null
	):
		_restore_stats()
		_finish()
		return

	player.set_physics_process(false)
	manager.set_process(false)
	authority.set_process(false)
	weapon.set_process(false)
	animator.set_process(false)
	visual.set_process(false)
	wire.set_process(false)
	action_state.set_process(false)

	_validate_grace_baseline(authority, defense, action_state)
	_validate_ruvia_authority(
		player,
		manager,
		authority,
		defense,
		status_receiver,
		action_state
	)
	_validate_authority_spells(
		player,
		authority,
		weapon,
		animator,
		visual,
		wire,
		action_state
	)
	_validate_weapon_spell_weaves(
		player,
		authority,
		weapon,
		action_state
	)
	_validate_solar_spread(player, weapon)
	_validate_dismissal(manager, authority, defense, action_state)

	_restore_stats()
	player.queue_free()
	floor.queue_free()
	_finish()


func _validate_grace_baseline(
	authority: PlayerElementalAuthorityController,
	defense: PlayerDefenseController,
	action_state: PlayerActionState
) -> void:
	_expect(not authority.is_authority_active(), "Grace begins without divine elemental authority")
	GameState.set_stat("health", 100)
	GameState.set_stat("stance", GameState.get_stat("max_stance"))
	var fire_payload: DamagePayload = _make_payload("fire", 7, 3, "Baseline Fire")
	var result: Dictionary = defense.resolve_incoming_attack(fire_payload)
	_expect(str(result.get("outcome", "")) == "hit", "Ordinary Fire can hit Grace")
	_expect(GameState.get_stat("health") == 93, "Grace takes baseline Fire damage")
	defense.reset_defense()
	action_state.clear_action_locks()


func _validate_ruvia_authority(
	player: CharacterBody3D,
	manager: PlayerAvatarManager,
	authority: PlayerElementalAuthorityController,
	defense: PlayerDefenseController,
	status_receiver: PlayerStatusReceiver,
	action_state: PlayerActionState
) -> void:
	GameState.set_stat("health", 100)
	GameState.set_stat("stance", GameState.get_stat("max_stance"))
	_expect(manager.incarnate(RuviaAvatar, true), "Ruvia incarnation activates")
	_expect(authority.is_authority_active(), "Ruvia installs elemental authority")
	_expect(
		authority.get_authority_profile() == RuviaAvatar.elemental_authority_profile,
		"Live authority matches Ruvia's definition"
	)
	_expect(authority.has_authority_for_element("fire"), "Ruvia owns Fire")
	_expect(authority.is_immune_to_element("fire"), "Ruvia is immune to matching Fire")
	_expect(authority.can_traverse_hazard("fire"), "Ruvia can traverse Fire hazards")

	var fire_payload: DamagePayload = _make_payload("fire", 9, 4, "Authority Fire")
	var fire_result: Dictionary = defense.resolve_incoming_attack(fire_payload)
	_expect(
		str(fire_result.get("outcome", "")) == "elemental_authority",
		"Matching Fire resolves through elemental authority"
	)
	_expect(GameState.get_stat("health") == 100, "Matching Fire cannot damage Ruvia")
	_expect(GameState.get_stat("stance") == GameState.get_stat("max_stance"), "Matching Fire cannot damage Ruvia's stance")

	status_receiver.apply_status("burning", 4.0, 2.0, "Authority Fire")
	_expect(not status_receiver.has_status("burning"), "Ruvia cannot receive Burning")
	status_receiver.apply_status("poisoned", 2.0, 1.0, "Control Poison")
	_expect(status_receiver.has_status("poisoned"), "Unmatched statuses still affect Ruvia")
	status_receiver.remove_status("poisoned")

	var ice_payload: DamagePayload = _make_payload("ice", 5, 1, "Control Ice")
	var ice_result: Dictionary = defense.resolve_incoming_attack(ice_payload)
	_expect(str(ice_result.get("outcome", "")) == "hit", "Unmatched Ice still damages Ruvia")
	_expect(GameState.get_stat("health") == 95, "Ruvia authority does not become universal immunity")
	defense.reset_defense()
	action_state.clear_action_locks()
	GameState.set_stat("health", 100)
	player.set_meta("active_avatar_id", "ruvia")
	player.set_meta("active_avatar_display_name", "Ruvia")


func _validate_authority_spells(
	player: CharacterBody3D,
	authority: PlayerElementalAuthorityController,
	weapon: WeaponController,
	animator: PlayerWeaponControlAnimator,
	visual: GraceElementalAuthorityMotionVisual,
	wire: AvatarWireSkeletonRenderer,
	action_state: PlayerActionState
) -> void:
	var base_payload: DamagePayload = FireboltAbility.get_action_payload() as DamagePayload
	var empowered_payload: DamagePayload = authority.modify_spell_payload(
		FireboltAbility,
		base_payload
	)
	_expect(empowered_payload != null, "Ruvia can build an authority Firebolt payload")
	if empowered_payload != null and base_payload != null:
		_expect(empowered_payload.amount > base_payload.amount, "Authority increases Firebolt damage")
		_expect(empowered_payload.stance_damage >= base_payload.stance_damage, "Authority preserves or increases Firebolt stance pressure")
		_expect(empowered_payload.status_duration > base_payload.status_duration, "Authority lengthens Burning")
		_expect(empowered_payload.tags.has("elemental_authority"), "Authority payload is tagged")

	var rig: Node3D = weapon.runtime_weapon_rig
	_expect(rig != null and rig.has_method("get_spell_cast_origin"), "Ember Halberd exposes a spell conduit point")
	GameState.set_stat("mana", 20)
	action_state.clear_action_locks()
	var expected_origin: Vector3 = (
		rig.call("get_spell_cast_origin", "firebolt") as Vector3
		if rig != null and rig.has_method("get_spell_cast_origin")
		else player.global_position
	)
	_expect(
		authority.begin_ability_channel(player, FireboltAbility),
		"Ruvia casts Firebolt through elemental authority"
	)
	_expect(
		authority.last_cast_instance is GenericProjectile,
		"Authority Firebolt creates the projectile action"
	)
	_expect(
		authority.last_cast_origin.distance_to(expected_origin) < 0.08,
		"Firebolt originates at the halberd blade"
	)
	if authority.last_cast_instance is GenericProjectile:
		var projectile: GenericProjectile = authority.last_cast_instance as GenericProjectile
		_expect(projectile.speed > 18.0, "Authority increases Firebolt projectile speed")
		_expect(projectile.get_payload().tags.has("ruvia_fire_authority"), "Projectile carries Ruvia's authority tag")

	visual.sample_animation_pose(1.0 / 60.0)
	animator.sample_now()
	var pose_sample: Dictionary = authority.get_cast_pose_sample()
	_expect(bool(pose_sample.get("two_handed", false)), "Authority cast pose keeps both hands on the halberd")
	var animator_debug: Dictionary = animator.get_debug_data()
	_expect(bool(animator_debug.get("authority_cast_active", false)), "Weapon animator owns the authority cast")
	_expect(bool(animator_debug.get("support_hand_locked", false)), "Guide hand locks to the shaft while casting")
	_expect(wire.has_finite_pose(), "Authority casting keeps the wire body finite")
	authority._process(0.3)
	action_state.clear_action_locks()

	GameState.set_stat("mana", 20)
	_expect(
		authority.begin_ability_channel(player, FireFieldAbility),
		"Ruvia creates an owned Fire Field"
	)
	_expect(authority.last_owned_field is FireField, "Authority records the owned Fire Field")
	if authority.last_owned_field is FireField:
		var field: FireField = authority.last_owned_field as FireField
		var field_debug: Dictionary = field.get_debug_data()
		_expect(bool(field_debug.get("authority_owned", false)), "Fire Field records authority ownership")
		_expect(str(field_debug.get("owner_avatar", "")) == "ruvia", "Fire Field records Ruvia as owner")
		_expect(field.radius > 3.0, "Authority expands Fire Field radius")
		_expect(field.lifetime > 5.0, "Authority extends Fire Field lifetime")
	authority._process(0.3)
	action_state.clear_action_locks()


func _validate_weapon_spell_weaves(
	player: CharacterBody3D,
	authority: PlayerElementalAuthorityController,
	weapon: WeaponController,
	action_state: PlayerActionState
) -> void:
	var moveset: WeaponMovesetDefinition = weapon.get_moveset()
	_expect(moveset != null, "Ruvia's halberd moveset is available for weaving")
	if moveset == null:
		return

	var cinder: WeaponAttackDefinition = moveset.get_attack("ruvia_halberd_l1")
	GameState.set_stat("mana", 20)
	action_state.clear_action_locks()
	_expect(weapon.start_attack(cinder), "Cinder Sweep begins for blade-tip weave")
	if weapon.current_attack != null:
		weapon.current_attack_elapsed = (
			weapon.current_attack.get_cancel_window_start(weapon.get_attack_speed())
			+ 0.01
		)
		weapon.update_cancel_permissions()
	_expect(
		authority.begin_ability_channel(player, FireboltAbility),
		"Firebolt cancels from Cinder Sweep's late recovery"
	)
	_expect(authority.last_weave_id == "blade_tip_firebolt", "Cinder Sweep resolves blade-tip Firebolt")
	authority._process(0.3)
	action_state.clear_action_locks()

	var haft: WeaponAttackDefinition = moveset.get_attack("ruvia_halberd_l3")
	GameState.set_stat("mana", 20)
	_expect(weapon.start_attack(haft), "Haft Check begins for field plant")
	if weapon.current_attack != null:
		weapon.current_attack_elapsed = (
			weapon.current_attack.get_cancel_window_start(weapon.get_attack_speed())
			+ 0.01
		)
		weapon.update_cancel_permissions()
	_expect(
		authority.begin_ability_channel(player, FireFieldAbility),
		"Fire Field cancels from Haft Check"
	)
	_expect(authority.last_weave_id == "haft_field_plant", "Haft Check resolves close field plant")
	if authority.last_owned_field != null:
		var planted_offset: Vector3 = authority.last_owned_field.global_position - player.global_position
		planted_offset.y = 0.0
		_expect(planted_offset.length() < 1.5, "Haft Check plants Fire Field at close control range")
	authority._process(0.3)
	action_state.clear_action_locks()

	var owned_fields: Array[Node] = authority.get_owned_fields()
	_expect(not owned_fields.is_empty(), "Weapon weave test retains an owned field")
	var flare_field: FireField = null
	if not owned_fields.is_empty() and owned_fields[0] is FireField:
		flare_field = owned_fields[0] as FireField
	var flare_radius_before: float = flare_field.radius if flare_field != null else 0.0
	var ember_wheel: WeaponAttackDefinition = moveset.get_attack("ruvia_halberd_l5")
	_expect(weapon.start_attack(ember_wheel), "Ember Wheel begins")
	weapon.current_phase = "active"
	authority._process(0.016)
	if flare_field != null:
		_expect(flare_field.radius > flare_radius_before, "Ember Wheel flares owned Fire Fields")
	weapon.cancel_current_attack("fire_specialist_test")
	action_state.clear_action_locks()

	var thrust_field: Node = authority.last_owned_field
	if thrust_field is FireField:
		player.global_position = (thrust_field as FireField).global_position
	var scorching_thrust: WeaponAttackDefinition = moveset.get_attack(
		"ruvia_halberd_h1"
	)
	_expect(weapon.start_attack(scorching_thrust), "Scorching Thrust begins inside an owned field")
	weapon.current_phase = "active"
	for step_index: int in range(3):
		player.global_position += Vector3(0.0, 0.0, -0.9)
		authority._process(0.016)
	var authority_debug: Dictionary = authority.get_debug_data()
	_expect(int(authority_debug.get("total_wake_segments", 0)) > 0, "Scorching Thrust leaves a burning wake")
	weapon.cancel_current_attack("fire_specialist_test")
	action_state.clear_action_locks()


func _validate_solar_spread(
	player: CharacterBody3D,
	weapon: WeaponController
) -> void:
	if not weapon.runtime_weapon_rig is RuviaEmberHalberdAuthorityRig:
		_expect(false, "Ruvia uses the Fire-conduit Ember Halberd rig")
		return
	var rig: RuviaEmberHalberdAuthorityRig = (
		weapon.runtime_weapon_rig as RuviaEmberHalberdAuthorityRig
	)
	var primary: Node3D = _make_enemy("PrimarySolarTarget", player.global_position + Vector3(0.0, 0.0, -2.0))
	var secondary: Node3D = _make_enemy("SecondarySolarTarget", player.global_position + Vector3(1.7, 0.0, -1.7))
	var solar: WeaponAttackDefinition = weapon.get_moveset().get_attack("ruvia_halberd_h4")
	var targets: Array[Node] = [primary]
	rig.on_weapon_targets_hit(targets, solar)
	var secondary_receiver: Node = secondary.get_node_or_null("StatusReceiver")
	_expect(
		secondary_receiver != null
		and secondary_receiver.has_method("has_status")
		and bool(secondary_receiver.call("has_status", "burning")),
		"Solar Descent spreads weaker Burning to nearby enemies"
	)
	_expect(int(rig.get_debug_data().get("solar_spread_count", 0)) >= 1, "Halberd rig reports Solar Descent spread")
	primary.queue_free()
	secondary.queue_free()


func _validate_dismissal(
	manager: PlayerAvatarManager,
	authority: PlayerElementalAuthorityController,
	defense: PlayerDefenseController,
	action_state: PlayerActionState
) -> void:
	action_state.clear_action_locks()
	_expect(manager.dismiss_avatar("fire_specialist_test"), "Ruvia dismisses safely")
	_expect(not authority.is_authority_active(), "Grace returns without Ruvia's Fire authority")
	GameState.set_stat("health", 100)
	GameState.set_stat("stance", GameState.get_stat("max_stance"))
	var fire_payload: DamagePayload = _make_payload("fire", 6, 2, "Return Fire")
	var result: Dictionary = defense.resolve_incoming_attack(fire_payload)
	_expect(str(result.get("outcome", "")) == "hit", "Fire damages Grace again after dismissal")
	_expect(GameState.get_stat("health") == 94, "Dismissal restores ordinary elemental vulnerability")


func _make_payload(
	element: String,
	amount: int,
	stance_damage: int,
	source_name: String
) -> DamagePayload:
	var payload: DamagePayload = DamagePayload.new()
	payload.element = element
	payload.amount = amount
	payload.stance_damage = stance_damage
	payload.source_name = source_name
	payload.hit_type = "test"
	payload.tags = [element, "smoke_test"]
	return payload


func _make_enemy(enemy_name: String, world_position: Vector3) -> Node3D:
	var enemy: Node3D = Node3D.new()
	enemy.name = enemy_name
	enemy.global_position = world_position
	enemy.add_to_group("enemy")
	var receiver: Node = EnemyStatusReceiverScript.new()
	receiver.name = "StatusReceiver"
	enemy.add_child(receiver)
	add_child(enemy)
	return enemy


func _make_floor() -> StaticBody3D:
	var floor: StaticBody3D = StaticBody3D.new()
	floor.name = "RuviaFireSpecialistFloor"
	floor.position = Vector3(0.0, -0.1, 0.0)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(30.0, 0.2, 30.0)
	collision.shape = shape
	floor.add_child(collision)
	return floor


func _capture_stats() -> void:
	for stat_id: String in [
		"health",
		"max_health",
		"stamina",
		"max_stamina",
		"mana",
		"max_mana",
		"stance",
		"max_stance",
		"focus",
		"max_focus",
	]:
		original_stats[stat_id] = GameState.get_stat(stat_id)


func _prepare_stats() -> void:
	GameState.set_stat("max_health", 100)
	GameState.set_stat("health", 100)
	GameState.set_stat("max_stamina", 100)
	GameState.set_stat("stamina", 100)
	GameState.set_stat("max_mana", 100)
	GameState.set_stat("mana", 100)
	GameState.set_stat("max_stance", 40)
	GameState.set_stat("stance", 40)
	GameState.set_stat("max_focus", 100)
	GameState.set_stat("focus", 100)


func _restore_stats() -> void:
	for stat_id_variant: Variant in original_stats.keys():
		var stat_id: String = str(stat_id_variant)
		GameState.set_stat(stat_id, int(original_stats[stat_id_variant]))


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func _finish() -> void:
	if failures.is_empty():
		print("RUVIA_FIRE_SPECIALIST_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	push_error(
		"RUVIA_FIRE_SPECIALIST_SMOKE_TEST: FAILED: "
		+ ", ".join(failures)
	)
	get_tree().quit(1)
