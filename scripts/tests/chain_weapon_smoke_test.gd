extends Node

const Chain: WeaponDefinition = preload("res://data/weapons/training_chain.tres")
const RigScene: PackedScene = preload("res://scenes/weapons/chain_weapon_rig.tscn")
const LabScene: PackedScene = preload("res://scenes/levels/prototypes/prototype_chain_weapon_lab_v1.tscn")
const SoulGripAbility: AbilityDefinition = preload("res://data/abilities/soul_grip_ability.tres")
const StartingLoadout: AbilityLoadout = preload("res://data/loadouts/grace_starting_loadout.tres")
const SoulGripSpellControllerScript: Script = preload("res://scripts/player/soul_grip_spell_controller.gd")
const PlayerChannelCasterScript: Script = preload("res://scripts/abilities/ability_caster_player_channels.gd")

var failures: Array[String] = []


func _ready() -> void:
	run_tests()
	if failures.is_empty():
		print("CHAIN_WEAPON_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("CHAIN_WEAPON_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func run_tests() -> void:
	if Chain == null:
		failures.append("Training Chain resource is missing")
		return
	if Chain.weapon_class != "chains":
		failures.append("Training Chain must use the chains weapon class")
	if Chain.runtime_rig_scene == null:
		failures.append("Training Chain has no runtime rig scene")
	if Chain.moveset == null:
		failures.append("Training Chain has no moveset")
		return

	for graph_error: String in Chain.moveset.validate_graph():
		failures.append("moveset graph: " + graph_error)
	if Chain.moveset.attacks.size() != 7:
		failures.append("expected 7 chain attacks")

	assert_attack("chain_l1", "chain_l2", "chain_h1")
	assert_attack("chain_l2", "chain_l3", "chain_h2")
	assert_attack("chain_l3", "", "chain_h3")
	assert_attack("chain_h0", "", "")

	var light: WeaponAttackDefinition = Chain.moveset.get_entry_attack("light")
	var heavy: WeaponAttackDefinition = Chain.moveset.get_entry_attack("heavy")
	if light == null or heavy == null:
		failures.append("chain entry attacks are missing")
	else:
		var light_payload: DamagePayload = light.build_payload(Chain)
		var heavy_payload: DamagePayload = heavy.build_payload(Chain)
		for required_tag: String in ["chain", "weighted_tip", "force", "blunt"]:
			if not light_payload.tags.has(required_tag):
				failures.append("light payload missing " + required_tag)
		if not heavy.extra_tags.has("slam"):
			failures.append("neutral heavy must use the slam trajectory")
		if heavy.stance_multiplier <= light.stance_multiplier:
			failures.append("neutral heavy must exceed light stance pressure")

	var rig: Node = RigScene.instantiate()
	add_child(rig)
	if not rig is ChainWeaponRig3D:
		failures.append("runtime rig is not a ChainWeaponRig3D")
	elif rig.get_node_or_null("FlexibleChain") == null:
		failures.append("runtime rig did not construct its FlexibleChain")
	rig.queue_free()

	var lab: Node = LabScene.instantiate()
	if lab == null:
		failures.append("chain weapon laboratory failed to instantiate")
	else:
		if float(lab.get("stamina_regeneration_per_second")) <= 0.0:
			failures.append("chain laboratory must regenerate practice stamina")
		lab.queue_free()

	var input_bootstrap: WeaponInputBootstrap = WeaponInputBootstrap.new()
	add_child(input_bootstrap)
	assert_attack_binding("weapon_light_attack", KEY_J, MOUSE_BUTTON_LEFT, JOY_BUTTON_LEFT_SHOULDER)
	assert_attack_binding("weapon_heavy_attack", KEY_K, MOUSE_BUTTON_XBUTTON1, JOY_BUTTON_RIGHT_SHOULDER)
	if action_has_joypad("weapon_light_attack", JOY_BUTTON_X):
		failures.append("light attack must use L, not the left face button")
	if action_has_mouse("weapon_heavy_attack", MOUSE_BUTTON_RIGHT):
		failures.append("heavy attack must not steal right mouse from Focus")
	input_bootstrap.queue_free()

	if SoulGripAbility == null or SoulGripAbility.get_spell_id() != "soul_grip":
		failures.append("Soul Grip ability definition is missing")
	elif not StartingLoadout.learned_abilities.has(SoulGripAbility):
		failures.append("Grace must learn Soul Grip through the normal ability loadout")

	var dummy_player: CharacterBody3D = CharacterBody3D.new()
	var ability_caster: Node3D = PlayerChannelCasterScript.new() as Node3D
	ability_caster.name = "AbilityCaster"
	ability_caster.set("loadout", StartingLoadout)
	ability_caster.set("current_ability_index", StartingLoadout.equipped_abilities.find(SoulGripAbility))
	var soul_grip_controller: Node3D = SoulGripSpellControllerScript.new() as Node3D
	dummy_player.add_child(ability_caster)
	dummy_player.add_child(soul_grip_controller)
	add_child(dummy_player)
	if not bool(soul_grip_controller.call("can_handle_ability", SoulGripAbility)):
		failures.append("Soul Grip spell controller must claim the Soul Grip ability")
	if not bool(ability_caster.call("cast_from_player", dummy_player)):
		failures.append("Cast must delegate equipped Soul Grip to its player channel")
	elif not bool(soul_grip_controller.get("channel_requested")):
		failures.append("Soul Grip channel did not begin through the Cast action")
	if action_has_joypad("soul_grip", JOY_BUTTON_LEFT_SHOULDER):
		failures.append("Soul Grip must not own the Light shoulder")
	if not action_has_joypad("weapon_light_attack", JOY_BUTTON_LEFT_SHOULDER):
		failures.append("Soul Grip setup removed the Light shoulder attack")
	dummy_player.queue_free()


func assert_attack(
	attack_id: String,
	expected_light: String,
	expected_heavy: String
) -> void:
	var attack: WeaponAttackDefinition = Chain.moveset.get_attack(attack_id)
	if attack == null:
		failures.append("missing attack " + attack_id)
		return
	if attack.next_light_attack_id != expected_light:
		failures.append(attack_id + " light link mismatch")
	if attack.next_heavy_attack_id != expected_heavy:
		failures.append(attack_id + " heavy link mismatch")


func assert_attack_binding(
	action_name: String,
	expected_key: Key,
	expected_mouse: MouseButton,
	expected_joypad: JoyButton
) -> void:
	var has_key: bool = false
	var has_mouse: bool = false
	var has_joypad: bool = false
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == expected_key:
			has_key = true
		elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == expected_mouse:
			has_mouse = true
		elif event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == expected_joypad:
			has_joypad = true
	if not has_key or not has_mouse or not has_joypad:
		failures.append(action_name + " must provide matching keyboard, mouse, and controller bindings")


func action_has_mouse(action_name: String, expected_mouse: MouseButton) -> bool:
	if not InputMap.has_action(action_name):
		return false
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventMouseButton:
			if (event as InputEventMouseButton).button_index == expected_mouse:
				return true
	return false


func action_has_joypad(action_name: String, expected_joypad: JoyButton) -> bool:
	if not InputMap.has_action(action_name):
		return false
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton:
			if (event as InputEventJoypadButton).button_index == expected_joypad:
				return true
	return false
