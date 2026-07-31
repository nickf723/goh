extends Node3D
class_name PrototypeStormDrainPackEncounter


const PackMemberScene: PackedScene = preload(
	"res://scenes/actors/enemies/storm_drain_gremlin_actor.tscn"
)
const BiteOption: EnemyActionOption = preload(
	"res://data/enemy_action_options/gremlin_bite_option.tres"
)
const PounceOption: EnemyActionOption = preload(
	"res://data/enemy_action_options/gremlin_pounce_option.tres"
)
const BackstepOption: EnemyActionOption = preload(
	"res://data/enemy_action_options/gremlin_backstep_option.tres"
)
const MireSpitOption: EnemyActionOption = preload(
	"res://data/enemy_action_options/storm_drain_mire_spit_option.tres"
)
const SparkPounceOption: EnemyActionOption = preload(
	"res://data/enemy_action_options/storm_drain_spark_pounce_option.tres"
)
const GuardScreechOption: EnemyActionOption = preload(
	"res://data/enemy_action_options/storm_drain_guard_screech_option.tres"
)
const HookstepOption: EnemyActionOption = preload(
	"res://data/enemy_action_options/storm_drain_hookstep_option.tres"
)

@export var opening_objective: String = (
	"Break the Storm Drain Pack's Wet → Lightning plan. Tab cycles tactical telemetry."
)
@export var enable_editor_f8_reset: bool = true

@onready var enemy_root: Node3D = %EnemyRoot
@onready var pack_status_label: Label = %PackStatusLabel
@onready var overlay: CanvasLayer = %TacticalDecisionOverlay
@onready var player: Node3D = %Player

var pack_members: Array[Node3D] = []
var observed_member_index: int = 0
var reset_count: int = 0
var encounter_complete: bool = false


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("debuggable")
	spawn_pack()
	refill_player_resources()
	clear_player_statuses()
	set_objective(opening_objective)
	show_message(
		"Storm Drain Pack deployed. Mire prepares Wet, Spark cashes it in, "
		+ "Shield repairs stance, and Runner opens lanes."
	)
	call_deferred("bind_observed_member")


func _process(_delta: float) -> void:
	prune_pack_members()
	update_pack_status()
	if not encounter_complete and get_alive_pack_count() <= 0:
		encounter_complete = true
		set_objective("Storm Drain Pack defeated. Use the reset console or F8 to rerun.")
		show_message("The pack formation collapses. Encounter clear.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_focus_next"):
		cycle_observed_member(1)
		get_viewport().set_input_as_handled()
		return
	if not enable_editor_f8_reset or not OS.has_feature("editor"):
		return
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode == KEY_F8:
		reset_lab()
		get_viewport().set_input_as_handled()


func spawn_pack() -> void:
	clear_pack_members()
	encounter_complete = false
	var configs: Array[Dictionary] = [
		{
			"name": "MireGremlin",
			"label": "MIRE • PRIMER",
			"role": "primer",
			"personality": "cautious",
			"position": Vector3(-6.0, 0.8, -4.5),
			"color": Color(0.18, 0.82, 0.68, 1.0),
			"options": _typed_options([MireSpitOption, BiteOption, BackstepOption]),
		},
		{
			"name": "SparkGremlin",
			"label": "SPARK • PAYOFF",
			"role": "payoff_specialist",
			"personality": "bold",
			"position": Vector3(4.8, 0.8, -5.5),
			"color": Color(0.35, 0.48, 1.0, 1.0),
			"options": _typed_options([SparkPounceOption, BiteOption, BackstepOption]),
		},
		{
			"name": "ShieldGremlin",
			"label": "SHIELD • PROTECTOR",
			"role": "protector",
			"personality": "brute",
			"position": Vector3(-3.4, 0.8, 4.6),
			"color": Color(0.92, 0.76, 0.2, 1.0),
			"options": _typed_options([GuardScreechOption, BiteOption, BackstepOption]),
		},
		{
			"name": "RunnerGremlin",
			"label": "RUNNER • SKIRMISHER",
			"role": "skirmisher",
			"personality": "skittish",
			"position": Vector3(6.2, 0.8, 4.2),
			"color": Color(1.0, 0.42, 0.72, 1.0),
			"options": _typed_options([HookstepOption, PounceOption, BiteOption]),
		},
	]
	for config: Dictionary in configs:
		spawn_pack_member(config)
	observed_member_index = 0
	call_deferred("bind_observed_member")
	update_pack_status()


func spawn_pack_member(config: Dictionary) -> void:
	var member_value: Variant = PackMemberScene.instantiate()
	if not member_value is Node3D:
		return
	var member: Node3D = member_value as Node3D
	member.name = str(config.get("name", "StormDrainGremlin"))
	var position_value: Variant = config.get("position", Vector3.ZERO)
	var spawn_position: Vector3 = Vector3.ZERO
	if position_value is Vector3:
		spawn_position = position_value
	member.position = spawn_position
	member.set_meta("tactical_squad_id", "storm_drain_pack")
	enemy_root.add_child(member)
	var brain: Node = member.get_node_or_null("EnemyBrain")
	if brain != null:
		brain.set("tactical_squad_id", "storm_drain_pack")
		brain.set("tactical_squad_role_id", str(config.get("role", "generalist")))
		brain.set("auto_assign_squad_role", false)
		brain.set("personality_id", str(config.get("personality", "skittish")))
		var options_value: Variant = config.get("options", [])
		if options_value is Array:
			brain.set("action_options", options_value)
		if brain.has_method("refresh_tactical_squad_role"):
			brain.call_deferred("refresh_tactical_squad_role")
	var role_color: Color = Color.WHITE
	var color_value: Variant = config.get("color", Color.WHITE)
	if color_value is Color:
		role_color = color_value
	var role_label: Label3D = member.get_node_or_null("RoleLabel") as Label3D
	if role_label != null:
		role_label.text = str(config.get("label", "PACK MEMBER"))
		role_label.modulate = role_color
	var beacon: OmniLight3D = member.get_node_or_null("RoleBeacon") as OmniLight3D
	if beacon != null:
		beacon.light_color = role_color
	var hit_receiver: Node = member.get_node_or_null("HitReceiver")
	if hit_receiver != null:
		hit_receiver.set("target_name", str(config.get("label", member.name)))
		if hit_receiver.has_signal("health_depleted"):
			hit_receiver.connect(
				"health_depleted",
				Callable(self, "_on_pack_member_defeated").bind(str(member.name))
			)
	var tags: Node = member.get_node_or_null("TagComponent")
	if tags != null and tags.has_method("add_tag"):
		tags.call("add_tag", str(config.get("role", "generalist")))
	pack_members.append(member)


func _typed_options(values: Array) -> Array[EnemyActionOption]:
	var result: Array[EnemyActionOption] = []
	for value: Variant in values:
		if value is EnemyActionOption:
			result.append(value as EnemyActionOption)
	return result


func cycle_observed_member(direction: int) -> void:
	prune_pack_members()
	if pack_members.is_empty():
		return
	observed_member_index = wrapi(
		observed_member_index + direction,
		0,
		pack_members.size()
	)
	bind_observed_member()


func bind_observed_member() -> void:
	prune_pack_members()
	if overlay == null or pack_members.is_empty():
		return
	observed_member_index = clampi(
		observed_member_index,
		0,
		pack_members.size() - 1
	)
	var member: Node3D = pack_members[observed_member_index]
	var brain: Node = member.get_node_or_null("EnemyBrain")
	if brain == null or not brain.has_method("get_tactical_decision_recorder"):
		return
	var recorder: Variant = brain.call("get_tactical_decision_recorder")
	if recorder != null and overlay.has_method("bind_recorder"):
		overlay.call("bind_recorder", recorder)
	show_message("Telemetry observing: " + _member_label(member))


func _member_label(member: Node3D) -> String:
	if member == null:
		return "none"
	var label: Label3D = member.get_node_or_null("RoleLabel") as Label3D
	return label.text if label != null else member.name


func _on_pack_member_defeated(member_name: String) -> void:
	show_message(member_name + " defeated. The surviving roles must adapt.")
	call_deferred("bind_observed_member")


func prune_pack_members() -> void:
	var alive: Array[Node3D] = []
	for member: Node3D in pack_members:
		if member != null and is_instance_valid(member) and not member.is_queued_for_deletion():
			alive.append(member)
	pack_members = alive
	if pack_members.is_empty():
		observed_member_index = 0
	else:
		observed_member_index = mini(observed_member_index, pack_members.size() - 1)


func get_alive_pack_count() -> int:
	prune_pack_members()
	return pack_members.size()


func update_pack_status() -> void:
	if pack_status_label == null:
		return
	var observed: String = "none"
	if not pack_members.is_empty():
		observed = _member_label(pack_members[observed_member_index])
	pack_status_label.text = (
		"STORM DRAIN PACK\n"
		+ "Alive: " + str(get_alive_pack_count()) + "/4"
		+ "\nObserved: " + observed
		+ "\nF2 telemetry • Tab next actor • F8 reset"
	)


func clear_pack_members() -> void:
	for child: Node in enemy_root.get_children():
		child.queue_free()
	pack_members.clear()


func reset_lab() -> void:
	reset_count += 1
	clear_pack_members()
	clear_player_statuses()
	refill_player_resources()
	if player != null:
		player.global_position = Vector3(0.0, 0.96, 10.5)
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
	call_deferred("spawn_pack")
	set_objective(opening_objective)
	show_message("Storm Drain Pack reset #" + str(reset_count) + ".")


func clear_player_statuses() -> void:
	if player == null:
		return
	var status_receiver: Node = player.get_node_or_null("StatusReceiver")
	if status_receiver != null and status_receiver.has_method("clear_all_statuses"):
		status_receiver.call("clear_all_statuses")


func refill_player_resources() -> void:
	GameState.set_stat("health", GameState.get_stat("max_health"))
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	GameState.set_stat("focus", GameState.get_stat("max_focus"))


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
		"encounter": "storm_drain_pack",
		"alive": get_alive_pack_count(),
		"observed_index": observed_member_index,
		"reset_count": reset_count,
		"complete": encounter_complete,
	}
