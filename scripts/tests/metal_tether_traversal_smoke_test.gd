extends Node

const MetalTetherAbility: AbilityDefinition = preload(
	"res://data/abilities/metal_tether_ability.tres"
)
const MetalTetherMaterial: FlexibleMaterialProfile = preload(
	"res://data/flexible_materials/metal_spell_tether.tres"
)
const StartingLoadout: AbilityLoadout = preload(
	"res://data/loadouts/grace_starting_loadout.tres"
)
const LabLoadout: AbilityLoadout = preload(
	"res://data/loadouts/grace_metal_tether_lab_loadout.tres"
)
const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")
const AnchorScene: PackedScene = preload("res://scenes/traversal/metal_tether_anchor.tscn")
const LabScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_metal_tether_traversal_lab_v1.tscn"
)

var failures: Array[String] = []


func _ready() -> void:
	run_tests()
	if failures.is_empty():
		print("METAL_TETHER_TRAVERSAL_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("METAL_TETHER_TRAVERSAL_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func run_tests() -> void:
	validate_ability_contract()
	validate_anchor_contract()
	validate_player_integration()
	validate_laboratory_contract()


func validate_ability_contract() -> void:
	if MetalTetherAbility == null:
		failures.append("Metal Tether ability resource is missing")
		return
	if MetalTetherAbility.get_spell_id() != "metal_tether":
		failures.append("Metal Tether spell id mismatch")
	if MetalTetherAbility.element != "metal":
		failures.append("Metal Tether must be a Metal spell")
	for required_role: String in ["traversal", "movement", "force", "grapple"]:
		if not MetalTetherAbility.roles.has(required_role):
			failures.append("Metal Tether missing role " + required_role)
	if not StartingLoadout.knows_ability(MetalTetherAbility):
		failures.append("Grace must learn Metal Tether in the normal starting loadout")
	if not LabLoadout.knows_ability(MetalTetherAbility):
		failures.append("Metal Tether laboratory loadout is missing the spell")

	if MetalTetherMaterial == null:
		failures.append("conjured metal filament material is missing")
	else:
		if not MetalTetherMaterial.conductive:
			failures.append("Metal Tether material must conduct")
		if MetalTetherMaterial.burnable:
			failures.append("Metal Tether material must not burn")
		if MetalTetherMaterial.visual_style != FlexibleMaterialProfile.VisualStyle.FILAMENT:
			failures.append("Metal Tether must use the filament presentation")


func validate_anchor_contract() -> void:
	var anchor_body: Node3D = AnchorScene.instantiate() as Node3D
	add_child(anchor_body)
	var anchor: MetalTetherAnchor3D = anchor_body.get_node_or_null(
		"MetalTetherAnchor"
	) as MetalTetherAnchor3D
	if anchor == null:
		failures.append("anchor scene is missing its MetalTetherAnchor component")
		anchor_body.queue_free()
		return
	if not anchor.can_accept_tether():
		failures.append("fresh anchor must accept a tether")
	anchor.breakable = true
	anchor.break_strength = 100.0
	if bool(anchor.receive_tether_tension(101.0, Vector3(0.0, -4.0, 0.0))):
		failures.append("overloaded breakaway anchor incorrectly held")
	if not anchor.broken:
		failures.append("overloaded breakaway anchor did not materially break")
	anchor.reset_anchor()
	if anchor.broken or not anchor.can_accept_tether():
		failures.append("anchor reset did not restore availability")
	anchor_body.queue_free()


func validate_player_integration() -> void:
	var anchor_body: Node3D = AnchorScene.instantiate() as Node3D
	anchor_body.position = Vector3(0.0, 6.0, -5.0)
	add_child(anchor_body)
	var anchor: MetalTetherAnchor3D = anchor_body.get_node(
		"MetalTetherAnchor"
	) as MetalTetherAnchor3D

	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	add_child(player)
	var controller: MetalTetherSpellController = player.get_node_or_null(
		"MetalTetherController"
	) as MetalTetherSpellController
	if controller == null:
		failures.append("player scene is missing MetalTetherController")
	else:
		if not controller.can_handle_ability(MetalTetherAbility):
			failures.append("player channel does not claim Metal Tether")
		if not controller.attach_to_anchor(anchor, MetalTetherAbility):
			failures.append("controller could not attach to a valid nearby anchor")
		else:
			if not controller.tether_active:
				failures.append("controller did not enter tether locomotion")
			if controller.tether_length <= 0.0:
				failures.append("controller did not establish a physical tether length")
			if get_node_or_null("MetalTetherRuntimeVisual") == null:
				failures.append("controller did not build the shared flexible tether visual")
			var preserved_velocity: Vector3 = Vector3(3.0, 2.0, -4.0)
			player.velocity = preserved_velocity
			controller.release_tether("smoke test", false)
			if not player.velocity.is_equal_approx(preserved_velocity):
				failures.append("releasing Metal Tether must preserve launch momentum")

	assert_binding("tether_reel_in", KEY_R, MOUSE_BUTTON_WHEEL_UP, JOY_BUTTON_DPAD_UP)
	assert_binding("tether_reel_out", KEY_F, MOUSE_BUTTON_WHEEL_DOWN, JOY_BUTTON_DPAD_DOWN)
	if not InputMap.has_action("cast_spell"):
		failures.append("Metal Tether must use the normal Cast action")

	player.queue_free()
	anchor_body.queue_free()


func validate_laboratory_contract() -> void:
	var lab: Node = LabScene.instantiate()
	if lab == null:
		failures.append("Metal Tether laboratory failed to instantiate")
		return
	if lab.get_node_or_null("Player/MetalTetherController") == null:
		failures.append("laboratory player is missing Metal Tether")
	if lab.get_node_or_null("FoundryCrosswind") == null:
		failures.append("laboratory is missing the airflow integration station")
	if lab.get_node_or_null("TetherHUD/Panel/Margin/Readout") == null:
		failures.append("laboratory is missing the live tension readout")
	lab.queue_free()


func assert_binding(
	action_name: String,
	expected_key: Key,
	expected_mouse: MouseButton,
	expected_joypad: JoyButton
) -> void:
	if not InputMap.has_action(action_name):
		failures.append(action_name + " action is missing")
		return
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
		failures.append(action_name + " lacks matching keyboard, mouse, or controller input")
