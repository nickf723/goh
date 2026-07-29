extends "res://scripts/tests/avatar_control_driver_manifestation_smoke_test.gd"


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
