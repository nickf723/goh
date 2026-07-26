extends Node3D
class_name PrototypeAirbornePresentationLab

const CombatArenaLoadoutScript = preload("res://scripts/systems/combat_arena_loadout.gd")
const PracticeSword: WeaponDefinition = preload("res://data/weapons/practice_sword.tres")

@export var hud_refresh_interval: float = 0.08

@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
@onready var weapon_controller: Node = get_node_or_null("Player/WeaponController")
@onready var target_container: Node = get_node_or_null("Targets")
@onready var status_label: Label = get_node_or_null("LabHUD/Panel/Margin/VBox/StatusLabel") as Label

var entry_progression_snapshot: Dictionary = {}
var snapshot_restored: bool = false
var initial_player_transform: Transform3D
var hud_timer: float = 0.0
var last_action: String = "READY"


func _ready() -> void:
	add_to_group("combat_arena_director")
	add_to_group("debuggable")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	entry_progression_snapshot = CombatArenaLoadoutScript.capture_state()
	CombatArenaLoadoutScript.apply_everything_unlocked()
	if player != null:
		initial_player_transform = player.global_transform
	set_objective("Compare Featherweight, Standard, and Juggernaut airborne reactions.")
	show_message("Airborne Presentation Lab online. F5 launches, F6 juggles, F7 plunges, and F8 resets all targets.")
	call_deferred("reset_arena")


func _exit_tree() -> void:
	restore_entry_progression()


func _process(delta: float) -> void:
	CombatArenaLoadoutScript.refill_combat_resources()
	hud_timer -= delta
	if hud_timer > 0.0:
		return
	hud_timer = maxf(hud_refresh_interval, 0.03)
	refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.physical_keycode:
		KEY_F5:
			launch_all()
		KEY_F6:
			juggle_all()
		KEY_F7:
			plunge_all()
		KEY_F8:
			reset_arena()
		_:
			return
	get_viewport().set_input_as_handled()


func launch_all() -> void:
	apply_payload_to_targets(make_launch_payload())
	last_action = "F5 LAUNCH"
	show_message("All profiles launched. Compare spin speed, silhouette, and rise response.")


func juggle_all() -> void:
	apply_payload_to_targets(make_juggle_payload())
	last_action = "F6 JUGGLE"
	show_message("Aerial follow-up applied. Repeated presses reveal profile-specific juggle resistance.")


func plunge_all() -> void:
	apply_payload_to_targets(make_plunge_payload())
	last_action = "F7 PLUNGE"
	show_message("Plunge applied. Watch the squash, bounce height, and landing recovery.")


func reset_arena() -> void:
	CombatArenaLoadoutScript.apply_everything_unlocked()
	reset_player()
	for target: Node in get_targets():
		if target.has_method("reset_target"):
			target.call("reset_target")
	CombatArenaLoadoutScript.refill_combat_resources()
	last_action = "F8 RESET"
	refresh_hud()


func reset_player() -> void:
	if player == null:
		return
	var preserved_weapon: WeaponDefinition
	if weapon_controller != null:
		var weapon_value: Variant = weapon_controller.get("equipped_weapon")
		if weapon_value is WeaponDefinition:
			preserved_weapon = weapon_value as WeaponDefinition
	player.global_transform = initial_player_transform
	player.velocity = Vector3.ZERO
	if player.has_method("cancel_combat_motion"):
		player.call("cancel_combat_motion")
	if player.has_method("clear_lock_on"):
		player.call("clear_lock_on")
	if weapon_controller != null:
		if weapon_controller.has_method("equip_weapon"):
			weapon_controller.call("equip_weapon", preserved_weapon if preserved_weapon != null else PracticeSword)
		if weapon_controller.has_method("reset_combo_chain"):
			weapon_controller.call("reset_combo_chain")


func apply_payload_to_targets(payload: DamagePayload) -> void:
	for target: Node in get_targets():
		if target.has_method("receive_damage_payload"):
			target.call("receive_damage_payload", payload.duplicate(true))


func make_launch_payload() -> DamagePayload:
	var payload := DamagePayload.new()
	payload.amount = 0
	payload.stance_damage = 0
	payload.source_name = "Presentation Lab Launcher"
	payload.hit_type = "melee"
	payload.tags = ["weapon", "melee", "heavy", "force", "launcher", "presentation_lab"]
	payload.knockback_strength = 0.8
	payload.knockback_up_strength = 7.0
	return payload


func make_juggle_payload() -> DamagePayload:
	var payload := DamagePayload.new()
	payload.amount = 0
	payload.stance_damage = 0
	payload.source_name = "Presentation Lab Aerial Follow-up"
	payload.hit_type = "melee"
	payload.tags = ["weapon", "melee", "context_aerial", "technique_aerial_forward", "presentation_lab"]
	payload.knockback_strength = 0.35
	payload.knockback_up_strength = 2.1
	return payload


func make_plunge_payload() -> DamagePayload:
	var payload := DamagePayload.new()
	payload.amount = 0
	payload.stance_damage = 0
	payload.source_name = "Presentation Lab Plunge"
	payload.hit_type = "melee"
	payload.tags = ["weapon", "melee", "context_aerial", "technique_aerial_down", "plunging", "ground_bounce", "presentation_lab"]
	return payload


func get_targets() -> Array[Node]:
	var targets: Array[Node] = []
	if target_container == null:
		return targets
	for child: Node in target_container.get_children():
		targets.append(child)
	return targets


func refresh_hud() -> void:
	if status_label == null:
		return
	var lines: Array[String] = [
		"AIR PRESENTATION  |  " + last_action,
		"F5 Launch  •  F6 Juggle  •  F7 Plunge  •  F8 Reset",
	]
	for target: Node in get_targets():
		var target_name: String = str(target.get("target_label"))
		var air_controller: Node = target.get_node_or_null("AirborneReactionController")
		var presentation_controller: Node = target.get_node_or_null("AirbornePresentationController")
		var air_data: Dictionary = air_controller.call("get_debug_data") if air_controller != null and air_controller.has_method("get_debug_data") else {}
		var presentation_data: Dictionary = presentation_controller.call("get_debug_data") if presentation_controller != null and presentation_controller.has_method("get_debug_data") else {}
		lines.append(
			target_name
			+ "  "
			+ str(air_data.get("air", "GROUND"))
			+ "  |  pose "
			+ str(presentation_data.get("state", "grounded")).to_upper()
			+ "  |  spin "
			+ str(presentation_data.get("spin", 0))
			+ "  |  juggle "
			+ str(air_data.get("juggle", 0.0))
			+ "  |  bounce "
			+ str(air_data.get("bounce", "0/1"))
		)
	status_label.text = "\n".join(lines)


func restore_entry_progression() -> void:
	if snapshot_restored or entry_progression_snapshot.is_empty():
		return
	snapshot_restored = true
	CombatArenaLoadoutScript.restore_state(entry_progression_snapshot)


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func set_objective(text: String) -> void:
	GameState.set_objective(text)
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("set_objective"):
		ui.call("set_objective", text)


func get_debug_data() -> Dictionary:
	return {
		"lab": "airborne_presentation_v1",
		"last_action": last_action,
		"targets": get_targets().size(),
		"snapshot_captured": not entry_progression_snapshot.is_empty(),
	}
