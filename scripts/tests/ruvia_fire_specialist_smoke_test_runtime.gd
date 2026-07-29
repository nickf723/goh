extends "res://scripts/tests/ruvia_fire_specialist_smoke_test.gd"


func _validate_grace_baseline(
	authority: PlayerElementalAuthorityController,
	defense: PlayerDefenseController,
	action_state: PlayerActionState
) -> void:
	super._validate_grace_baseline(authority, defense, action_state)
	action_state.end_stagger()


func _validate_ruvia_authority(
	player: CharacterBody3D,
	manager: PlayerAvatarManager,
	authority: PlayerElementalAuthorityController,
	defense: PlayerDefenseController,
	status_receiver: PlayerStatusReceiver,
	action_state: PlayerActionState
) -> void:
	super._validate_ruvia_authority(
		player,
		manager,
		authority,
		defense,
		status_receiver,
		action_state
	)
	action_state.end_stagger()
