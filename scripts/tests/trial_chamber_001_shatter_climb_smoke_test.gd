extends Node

const TrialScene: PackedScene = preload(
	"res://scenes/levels/prototypes/trial_chamber_001_shatter_climb_v1.tscn"
)
const WaterJetPayload: DamagePayload = preload(
	"res://data/damage_payloads/water_jet_payload.tres"
)
const IceLancePayload: DamagePayload = preload(
	"res://data/damage_payloads/ice_lance_payload.tres"
)

var failures: Array[String] = []
var trial: Node
var player: Node3D


func _ready() -> void:
	GameState.reset_run()
	trial = TrialScene.instantiate()
	add_child(trial)
	for _index: int in range(12):
		await get_tree().process_frame
	await get_tree().physics_frame
	player = trial.get_node_or_null("Player") as Node3D

	_validate_structure()
	_validate_fixed_loadout()
	_validate_optional_cache()
	await _validate_puzzle_one()
	await _validate_puzzle_two()
	await _validate_puzzle_three_and_completion()
	await _validate_reset()

	if trial != null and is_instance_valid(trial):
		trial.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_structure() -> void:
	_expect(trial != null, "trial scene instantiates")
	if trial == null:
		return
	_expect(trial.is_in_group("trial_chambers"), "trial joins shared trial_chambers group")
	var architecture: Node = trial.get_node_or_null("TrialArchitecture")
	_expect(architecture != null, "trial owns one compact architecture root")
	if architecture == null:
		return
	for path: String in [
		"EntranceFloor",
		"FrozenCrossing",
		"CrossingCheckpoint",
		"ShatterRoomFloor",
		"BrittleMasonrySeal",
		"ShatterCheckpoint",
		"OptionalCacheShelf",
		"OptionalRewardChest",
		"FrozenAscent",
		"CrownMasonrySeal",
		"UpperSealGoal",
		"UpperSealBeacon",
		"Ceiling",
	]:
		_expect(architecture.get_node_or_null(path) != null, "trial architecture contains " + path)
	_expect(architecture.find_children("*Step*", "", true, false).is_empty(), "v2 uses no authored stair runs")
	_expect(player != null, "trial contains canonical Player")
	_expect(trial.get_node_or_null("GameUI") != null, "trial contains canonical GameUI")
	_expect(int(trial.get("stage")) == 0, "trial begins on Puzzle I")


func _validate_fixed_loadout() -> void:
	if player == null:
		return
	var caster: Node = player.get_node_or_null("AbilityCaster")
	_expect(caster != null, "trial resolves AbilityCaster")
	if caster != null:
		var loadout_value: Variant = caster.get("loadout")
		_expect(loadout_value is AbilityLoadout, "trial assigns an AbilityLoadout")
		if loadout_value is AbilityLoadout:
			var loadout := loadout_value as AbilityLoadout
			_expect(loadout.get_learned_abilities().size() == 2, "trial teaches exactly two spells")
			_expect(loadout.get_equipped_ability_count() == 2, "trial equips exactly two spells")
			var ids: Array[String] = []
			for ability: AbilityDefinition in loadout.get_learned_abilities():
				if ability != null:
					ids.append(ability.get_spell_id())
			ids.sort()
			_expect(ids == ["ice_lance", "water_jet"], "trial loadout is exactly Water Jet + Ice Lance")

	var weapon_controller: Node = player.get_node_or_null("WeaponController")
	_expect(weapon_controller != null, "trial resolves WeaponController")
	if weapon_controller != null:
		var weapon_value: Variant = weapon_controller.get("equipped_weapon")
		_expect(weapon_value is WeaponDefinition, "trial equips a WeaponDefinition")
		if weapon_value is WeaponDefinition:
			_expect((weapon_value as WeaponDefinition).weapon_class == "hammer", "trial fixes the Training Hammer")

	var aerial: Node = player.get_node_or_null("AerialLocomotion")
	_expect(aerial != null, "trial resolves AerialLocomotion")
	if aerial != null:
		_expect(not bool(aerial.get("double_jump_unlocked")), "trial disables double jump bypass")
		_expect(not bool(aerial.get("hover_unlocked")), "trial disables hover bypass")
		_expect(not bool(aerial.get("flight_unlocked")), "trial disables flight bypass")


func _validate_optional_cache() -> void:
	var chest: Node = trial.get_node_or_null("TrialArchitecture/OptionalRewardChest")
	_expect(chest != null, "optional cache exists")
	if chest == null:
		return
	_expect(not bool(chest.get("locked")), "optional reward starts available")
	_expect(not bool(chest.get("claimed")), "optional reward starts unclaimed")
	var stage_before: int = int(trial.get("stage"))
	var result: Variant = chest.call("interact")
	_expect(result is Dictionary, "optional cache can be opened")
	_expect(bool(chest.get("opened")), "optional cache reveals its choices")
	_expect(int(trial.get("stage")) == stage_before, "opening optional cache does not advance main progression")


func _validate_puzzle_one() -> void:
	var bridge: Node = trial.get_node_or_null("TrialArchitecture/FrozenCrossing")
	_expect(bridge != null, "Puzzle I Water/Ice crossing exists")
	if bridge == null:
		return
	var payload_receiver: Node = bridge.get_node_or_null("PayloadTarget/PayloadReceiver")
	_expect(payload_receiver != null, "Puzzle I exposes shared PayloadReceiver")
	if payload_receiver == null:
		return

	payload_receiver.call("receive_payload", WaterJetPayload.duplicate(true))
	await get_tree().process_frame
	_expect(not bool(bridge.get("is_frozen_bridge")), "Water alone does not solve Puzzle I")
	payload_receiver.call("receive_payload", IceLancePayload.duplicate(true))
	await get_tree().process_frame
	await get_tree().physics_frame
	_expect(bool(bridge.get("is_frozen_bridge")), "Water Jet then Ice Lance freezes Puzzle I")
	_expect(bool(trial.get("crossing_frozen")), "trial observes the frozen crossing")
	_expect(int(trial.get("stage")) == 0, "mechanism state alone does not skip the traversal outcome")

	trial.call("_on_crossing_checkpoint_body_entered", player)
	await get_tree().process_frame
	_expect(int(trial.get("stage")) == 1, "reaching the far side advances to Puzzle II")


func _validate_puzzle_two() -> void:
	var gate: Node = trial.get_node_or_null("TrialArchitecture/BrittleMasonrySeal")
	_expect(gate != null, "Puzzle II brittle masonry exists")
	if gate == null:
		return
	_expect(bool(gate.get("require_heavy_for_shatter")), "Puzzle II explicitly requires a Heavy shatter hit")

	gate.call("receive_damage_payload", IceLancePayload.duplicate(true))
	_expect(bool(gate.get("is_frozen")), "Ice Lance primes Puzzle II")
	_expect(not bool(gate.get("is_open")), "Ice alone does not solve Puzzle II")

	var light_payload := DamagePayload.new()
	light_payload.element = "neutral"
	light_payload.source_name = "Trial Smoke Light Hammer"
	light_payload.tags = ["weapon", "light", "force", "blunt"]
	light_payload.knockback_strength = 8.0
	gate.call("receive_damage_payload", light_payload)
	_expect(not bool(gate.get("is_open")), "a Light force hit cannot satisfy the Heavy-only shatter gate")

	var heavy_payload := _make_heavy_hammer_payload()
	gate.call("receive_damage_payload", heavy_payload)
	await get_tree().process_frame
	_expect(bool(gate.get("is_open")), "Heavy Hammer shatters the frozen Puzzle II seal")
	_expect(bool(trial.get("main_gate_open")), "trial observes Puzzle II opening")
	_expect(int(trial.get("stage")) == 1, "opening the seal alone does not skip traversal outcome")

	trial.call("_on_shatter_checkpoint_body_entered", player)
	await get_tree().process_frame
	_expect(int(trial.get("stage")) == 2, "passing Puzzle II advances to the synthesis chamber")


func _validate_puzzle_three_and_completion() -> void:
	var ascent: Node = trial.get_node_or_null("TrialArchitecture/FrozenAscent")
	var crown: Node = trial.get_node_or_null("TrialArchitecture/CrownMasonrySeal")
	_expect(ascent != null, "Puzzle III contains the flooded ascent")
	_expect(crown != null, "Puzzle III contains the crown masonry seal")
	if ascent == null or crown == null:
		return

	var payload_receiver: Node = ascent.get_node_or_null("PayloadTarget/PayloadReceiver")
	_expect(payload_receiver != null, "Puzzle III ascent exposes shared PayloadReceiver")
	if payload_receiver != null:
		payload_receiver.call("receive_payload", WaterJetPayload.duplicate(true))
		payload_receiver.call("receive_payload", IceLancePayload.duplicate(true))
	await get_tree().process_frame
	await get_tree().physics_frame
	_expect(bool(ascent.get("is_frozen_bridge")), "Puzzle III freezes the cascade into a ramp")
	_expect(bool(trial.get("ascent_frozen")), "trial observes the frozen ascent")

	crown.call("receive_damage_payload", IceLancePayload.duplicate(true))
	_expect(bool(crown.get("is_frozen")), "Puzzle III crown can be made brittle")
	crown.call("receive_damage_payload", _make_heavy_hammer_payload())
	await get_tree().process_frame
	_expect(bool(crown.get("is_open")), "Puzzle III Heavy Hammer opens the frozen crown")
	_expect(bool(trial.get("crown_gate_open")), "trial observes the crown opening")

	trial.call("_on_goal_body_entered", player)
	await get_tree().process_frame
	_expect(bool(trial.get("trial_complete")), "reaching the seal after all three puzzles completes the trial")
	_expect(int(trial.get("stage")) == 3, "trial enters COMPLETE stage")
	_expect(GameState.get_flag("trial_chamber_001_shatter_climb_complete"), "trial completion flag is written")


func _validate_reset() -> void:
	var crossing: Node = trial.get_node_or_null("TrialArchitecture/FrozenCrossing")
	var main_seal: Node = trial.get_node_or_null("TrialArchitecture/BrittleMasonrySeal")
	var ascent: Node = trial.get_node_or_null("TrialArchitecture/FrozenAscent")
	var crown: Node = trial.get_node_or_null("TrialArchitecture/CrownMasonrySeal")
	var chest: Node = trial.get_node_or_null("TrialArchitecture/OptionalRewardChest")
	trial.call("reset_trial")
	await get_tree().process_frame
	await get_tree().physics_frame

	_expect(int(trial.get("stage")) == 0, "reset returns to Puzzle I")
	_expect(not bool(trial.get("trial_complete")), "reset clears completion state")
	_expect(crossing != null and not bool(crossing.get("is_frozen_bridge")), "reset melts Puzzle I crossing")
	_expect(main_seal != null and not bool(main_seal.get("is_open")), "reset restores Puzzle II seal")
	_expect(ascent != null and not bool(ascent.get("is_frozen_bridge")), "reset melts Puzzle III ascent")
	_expect(crown != null and not bool(crown.get("is_open")), "reset restores Puzzle III crown")
	_expect(not GameState.get_flag("trial_chamber_001_shatter_climb_complete"), "reset clears runtime completion flag")
	if player != null:
		_expect(player.global_position.distance_to(Vector3(0.0, 1.0, 27.0)) < 0.2, "reset returns Grace to the entrance")
	if chest != null:
		_expect(bool(chest.get("opened")), "main-trial reset does not respawn or reseal the optional reward cache")


func _make_heavy_hammer_payload() -> DamagePayload:
	var payload := DamagePayload.new()
	payload.element = "neutral"
	payload.source_name = "Trial Smoke Heavy Hammer"
	payload.tags = ["weapon", "heavy", "force", "blunt"]
	payload.knockback_strength = 8.0
	return payload


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("TRIAL_CHAMBER_001_SHATTER_CLIMB_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("TRIAL_CHAMBER_001_SHATTER_CLIMB_SMOKE_TEST: " + failure)
	get_tree().quit(1)
