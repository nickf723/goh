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


func _ready() -> void:
	GameState.reset_run()
	trial = TrialScene.instantiate()
	add_child(trial)
	for _index: int in range(10):
		await get_tree().process_frame
	await get_tree().physics_frame

	_validate_structure()
	_validate_fixed_loadout()
	await _validate_left_route()
	await _validate_right_route_and_completion()
	await _validate_emergent_goal_policy()

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
		"StartPlatform",
		"GoalPlatform",
		"CenterSpine",
		"FrozenCrossing",
		"BrittleMasonrySeal",
		"UpperSealGoal",
		"UpperSealBeacon",
	]:
		_expect(architecture.get_node_or_null(path) != null, "trial architecture contains " + path)
	_expect(trial.get_node_or_null("Player") != null, "trial contains canonical Player")
	_expect(trial.get_node_or_null("GameUI") != null, "trial contains canonical GameUI")


func _validate_fixed_loadout() -> void:
	var player: Node = trial.get_node_or_null("Player")
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


func _validate_left_route() -> void:
	var bridge: Node = trial.get_node_or_null("TrialArchitecture/FrozenCrossing")
	_expect(bridge != null, "left Water/Ice route exists")
	if bridge == null:
		return
	var payload_receiver: Node = bridge.get_node_or_null("PayloadTarget/PayloadReceiver")
	_expect(payload_receiver != null, "left route exposes the shared PayloadReceiver target")
	if payload_receiver == null:
		return

	payload_receiver.call("receive_payload", WaterJetPayload.duplicate(true))
	await get_tree().process_frame
	_expect(not bool(bridge.get("is_frozen_bridge")), "Water alone does not create the ice crossing")
	payload_receiver.call("receive_payload", IceLancePayload.duplicate(true))
	await get_tree().process_frame
	await get_tree().physics_frame
	_expect(bool(bridge.get("is_frozen_bridge")), "actual Water Jet then Ice Lance payloads freeze the crossing")
	_expect(bool(trial.get("left_route_ready")), "trial recognizes the Water/Ice route")
	var bridge_collision: CollisionShape3D = bridge.get_node_or_null("BridgeCollision") as CollisionShape3D
	_expect(bridge_collision != null and not bridge_collision.disabled, "frozen route enables traversal collision")

	trial.call("reset_trial")
	await get_tree().process_frame
	await get_tree().physics_frame
	_expect(not bool(trial.get("left_route_ready")), "reset clears Water/Ice route state")
	_expect(not bool(bridge.get("is_frozen_bridge")), "reset melts the trial bridge")


func _validate_right_route_and_completion() -> void:
	var gate: Node = trial.get_node_or_null("TrialArchitecture/BrittleMasonrySeal")
	_expect(gate != null, "right Ice/Heavy route exists")
	if gate == null:
		return

	gate.call("receive_damage_payload", IceLancePayload.duplicate(true))
	_expect(bool(gate.get("is_frozen")), "Ice Lance primes the brittle masonry")
	_expect(not bool(gate.get("is_open")), "Ice alone does not solve the masonry route")

	var heavy_payload := DamagePayload.new()
	heavy_payload.element = "neutral"
	heavy_payload.source_name = "Trial Smoke Hammer"
	heavy_payload.tags = ["weapon", "heavy", "force", "blunt"]
	heavy_payload.knockback_strength = 5.0
	gate.call("receive_damage_payload", heavy_payload)
	await get_tree().process_frame
	_expect(bool(gate.get("is_open")), "Heavy force shatters the frozen masonry")
	_expect(bool(trial.get("right_route_ready")), "trial recognizes the Ice/Heavy route")

	var player: Node3D = trial.get_node_or_null("Player") as Node3D
	_expect(player != null, "completion test resolves player")
	if player != null:
		trial.call("_on_goal_body_entered", player)
	await get_tree().process_frame
	_expect(bool(trial.get("trial_complete")), "upper seal completes after a supported route")
	_expect(GameState.get_flag("trial_chamber_001_shatter_climb_complete"), "trial completion flag is written")

	trial.call("reset_trial")
	await get_tree().process_frame
	_expect(not bool(trial.get("trial_complete")), "reset clears completion state")
	_expect(not bool(trial.get("right_route_ready")), "reset restores the masonry route")
	_expect(not GameState.get_flag("trial_chamber_001_shatter_climb_complete"), "reset clears the runtime completion flag")
	if player != null:
		_expect(player.global_position.distance_to(Vector3(0.0, 1.0, 16.0)) < 0.2, "reset returns Grace to the chamber entrance")


func _validate_emergent_goal_policy() -> void:
	var player: Node3D = trial.get_node_or_null("Player") as Node3D
	if player == null:
		return
	_expect(not bool(trial.get("left_route_ready")) and not bool(trial.get("right_route_ready")), "emergent-policy check begins with both authored routes unsolved")
	trial.call("_on_goal_body_entered", player)
	await get_tree().process_frame
	_expect(bool(trial.get("trial_complete")), "reaching the seal through an emergent solution is accepted")
	trial.call("reset_trial")
	await get_tree().process_frame


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
