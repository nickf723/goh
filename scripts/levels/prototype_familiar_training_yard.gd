extends Node3D
class_name PrototypeFamiliarTrainingYard

const WildGremlinScene: PackedScene = preload(
	"res://scenes/actors/enemies/storm_drain_gremlin_actor.tscn"
)
const TargetAllocator = preload(
	"res://scripts/ai/target_allocation_blackboard.gd"
)
const BiteOption: Resource = preload(
	"res://data/enemy_action_options/gremlin_bite_option.tres"
)
const PounceOption: Resource = preload(
	"res://data/enemy_action_options/gremlin_pounce_option.tres"
)
const BackstepOption: Resource = preload(
	"res://data/enemy_action_options/gremlin_backstep_option.tres"
)
const MireSpitOption: Resource = preload(
	"res://data/enemy_action_options/storm_drain_mire_spit_option.tres"
)

@export var opening_objective: String = (
	"Study Gremlin behavior, configure a Familiar Blueprint in the Magic menu, then cast Spectral Familiar."
)
@export var enable_editor_f8_reset: bool = true

@onready var player: Node3D = %Player
@onready var enemy_root: Node3D = %EnemyRoot
@onready var status_label: Label = %FamiliarStatusLabel

var status_refresh_remaining: float = 0.0
var reset_count: int = 0
var wild_defeats: int = 0


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("debuggable")
	if player != null and not player.is_in_group("player"):
		player.add_to_group("player")
	_prepare_training_dummies()
	_bind_summon_manager()
	spawn_wild_gremlins()
	refill_player_resources()
	set_objective(opening_objective)
	show_message("Familiar Training Yard ready. Two observations unlock the first Gremlin blueprint.")
	update_status_panel()


func _process(delta: float) -> void:
	status_refresh_remaining = maxf(status_refresh_remaining - maxf(delta, 0.0), 0.0)
	if status_refresh_remaining <= 0.0:
		status_refresh_remaining = 0.2
		update_status_panel()


func _unhandled_input(event: InputEvent) -> void:
	if not enable_editor_f8_reset or not OS.has_feature("editor"):
		return
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_F8:
		reset_lab()
		get_viewport().set_input_as_handled()


func spawn_wild_gremlins() -> void:
	clear_wild_gremlins()
	_spawn_wild_gremlin(
		"WildPouncer",
		Vector3(-5.5, 0.8, -4.0),
		"skirmisher",
		_typed_options([PounceOption, BiteOption, BackstepOption])
	)
	_spawn_wild_gremlin(
		"WildMire",
		Vector3(5.5, 0.8, -5.0),
		"primer",
		_typed_options([MireSpitOption, BiteOption, BackstepOption])
	)


func _spawn_wild_gremlin(
	member_name: String,
	spawn_position: Vector3,
	role_id: String,
	options: Array[EnemyActionOption]
) -> void:
	var member_value: Variant = WildGremlinScene.instantiate()
	if not member_value is Node3D:
		return
	var member: Node3D = member_value as Node3D
	member.name = member_name
	member.position = spawn_position
	member.set_meta("tactical_squad_id", "familiar_training_wild")
	var brain: Node = member.get_node_or_null("EnemyBrain")
	if brain != null:
		brain.set("tactical_squad_id", "familiar_training_wild")
		brain.set("tactical_squad_role_id", role_id)
		brain.set("auto_assign_squad_role", false)
		brain.set("personality_id", "bold" if role_id == "skirmisher" else "cautious")
		brain.set("action_options", options)
	var role_label: Label3D = member.get_node_or_null("RoleLabel") as Label3D
	if role_label != null:
		role_label.text = "WILD " + role_id.replace("_", " ").to_upper()
	var hit_receiver: Node = member.get_node_or_null("HitReceiver")
	if hit_receiver != null and hit_receiver.has_signal("health_depleted"):
		hit_receiver.connect(
			"health_depleted",
			Callable(self, "_on_wild_gremlin_defeated").bind(member_name)
		)
	enemy_root.add_child(member)


func _typed_options(values: Array) -> Array[EnemyActionOption]:
	var result: Array[EnemyActionOption] = []
	for value: Variant in values:
		if value is EnemyActionOption:
			result.append(value as EnemyActionOption)
	return result


func clear_wild_gremlins() -> void:
	for child: Node in enemy_root.get_children():
		child.queue_free()


func reset_lab() -> void:
	reset_count += 1
	TargetAllocator.clear_all()
	var summon_manager: Node = _get_summon_manager()
	if summon_manager != null and summon_manager.has_method("reset_summons"):
		summon_manager.call("reset_summons")
	_reset_training_dummies()
	spawn_wild_gremlins()
	refill_player_resources()
	if player != null:
		player.global_position = Vector3(0.0, 0.96, 9.5)
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
	set_objective(opening_objective)
	show_message("Familiar Training Yard reset #" + str(reset_count) + ". Creature knowledge was preserved.")


func reset_creature_mastery_for_debug() -> void:
	var service: Node = get_node_or_null("/root/SpeciesKnowledge")
	if service != null and service.has_method("reset_species"):
		service.call("reset_species", "gremlin")
	update_status_panel()
	show_message("Gremlin mastery reset for testing.")


func master_gremlin_for_debug() -> void:
	var service: Node = get_node_or_null("/root/SpeciesKnowledge")
	if service == null or not service.has_method("add_discovery"):
		return
	var discoveries_to_add: Array[Dictionary] = [
		{"id": "first_encounter", "label": "First encounter", "points": 1},
		{"id": "survived_pounce", "label": "Survived Pounce", "points": 1},
		{"id": "witnessed_backstep", "label": "Witnessed Backstep", "points": 1},
		{"id": "pack_coordination", "label": "Observed pack coordination", "points": 2},
		{"id": "conduct_susceptibility", "label": "Discovered Conduct susceptibility", "points": 4},
		{"id": "habitat_scavenging", "label": "Studied scavenging habitat", "points": 1},
		{"id": "stable_familiar_bond", "label": "Formed a stable familiar bond", "points": 4},
	]
	for discovery: Dictionary in discoveries_to_add:
		service.call(
			"add_discovery",
			"gremlin",
			str(discovery.get("id", "")),
			str(discovery.get("label", "")),
			int(discovery.get("points", 0))
		)
	service.call("set_equipped_familiar_species", "gremlin")
	update_status_panel()
	show_message("Gremlin mastery completed and familiar equipped for testing.")


func _prepare_training_dummies() -> void:
	for node_value: Variant in get_tree().get_nodes_in_group("familiar_training_dummy"):
		if not node_value is Node:
			continue
		var dummy: Node = node_value as Node
		dummy.add_to_group("enemy")
		var receiver: Node = dummy.get_node_or_null("HitReceiver")
		if receiver != null:
			receiver.set("max_health", 30)
			receiver.set("current_health", 30)
			receiver.set("max_stance", 18)
			receiver.set("current_stance", 18)
			receiver.set("disappears_when_defeated", false)


func _reset_training_dummies() -> void:
	for node_value: Variant in get_tree().get_nodes_in_group("familiar_training_dummy"):
		if not node_value is Node:
			continue
		var dummy: Node = node_value as Node
		var receiver: Node = dummy.get_node_or_null("HitReceiver")
		if receiver != null:
			receiver.set("current_health", int(receiver.get("max_health")))
			receiver.set("current_stance", int(receiver.get("max_stance")))
		var status_receiver: Node = dummy.get_node_or_null("StatusReceiver")
		if status_receiver != null and status_receiver.has_method("clear_all_statuses"):
			status_receiver.call("clear_all_statuses")


func _bind_summon_manager() -> void:
	var summon_manager: Node = _get_summon_manager()
	if summon_manager == null:
		return
	if summon_manager.has_signal("summon_created") and not summon_manager.is_connected(
		"summon_created",
		Callable(self, "_on_familiar_summoned")
	):
		summon_manager.connect("summon_created", Callable(self, "_on_familiar_summoned"))


func _get_summon_manager() -> Node:
	return player.get_node_or_null("SummonManager") if player != null else null


func _on_familiar_summoned(_familiar: Node) -> void:
	var service: Node = get_node_or_null("/root/SpeciesKnowledge")
	if service != null and service.has_method("add_discovery"):
		var result_value: Variant = service.call(
			"add_discovery",
			"gremlin",
			"stable_familiar_bond",
			"Formed a stable familiar bond",
			4
		)
		if result_value is Dictionary and bool((result_value as Dictionary).get("new_discovery", false)):
			show_message("Stable familiar bond recorded. Transformation insight is now within reach.")


func _on_wild_gremlin_defeated(_member_name: String) -> void:
	wild_defeats += 1
	var service: Node = get_node_or_null("/root/SpeciesKnowledge")
	if service != null and service.has_method("add_discovery"):
		service.call(
			"add_discovery",
			"gremlin",
			"defeated_wild_pack",
			"Defeated a wild Gremlin pack",
			1
		)
	show_message("Wild Gremlin defeated. Battle behavior added to the field record.")


func update_status_panel() -> void:
	if status_label == null:
		return
	var service: Node = get_node_or_null("/root/SpeciesKnowledge")
	var species_data: Dictionary = {}
	var loadout: Dictionary = {}
	var equipped_species: String = ""
	if service != null:
		if service.has_method("get_species_data"):
			var species_value: Variant = service.call("get_species_data", "gremlin")
			if species_value is Dictionary:
				species_data = species_value as Dictionary
		if service.has_method("get_familiar_loadout"):
			var loadout_value: Variant = service.call("get_familiar_loadout", "gremlin")
			if loadout_value is Dictionary:
				loadout = loadout_value as Dictionary
		if service.has_method("get_equipped_familiar_species_id"):
			equipped_species = str(service.call("get_equipped_familiar_species_id"))
	var summon_manager: Node = _get_summon_manager()
	var active_name: String = "none"
	if summon_manager != null and summon_manager.has_method("get_debug_data"):
		var debug_value: Variant = summon_manager.call("get_debug_data")
		if debug_value is Dictionary:
			active_name = str((debug_value as Dictionary).get("summon", "none"))
	var techniques: Array[String] = _string_array(loadout.get("technique_ids", []))
	status_label.text = (
		"CREATURE MASTERY • GREMLIN\n"
		+ "Knowledge " + str(species_data.get("points", 0))
		+ " • Rank " + str(species_data.get("rank", 0))
		+ " • " + ("EQUIPPED" if equipped_species == "gremlin" else "NOT EQUIPPED")
		+ "\nRole " + str(loadout.get("role", "locked")).to_upper()
		+ " • Command " + str(loadout.get("command", "locked")).to_upper()
		+ " • Techniques " + (", ".join(techniques) if not techniques.is_empty() else "none")
		+ "\nActive familiar: " + active_name
		+ " • Wild defeats " + str(wild_defeats)
		+ "\nTAB/M full menu • summon spell to cast • F8 reset combat"
	)


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
	var service: Node = get_node_or_null("/root/SpeciesKnowledge")
	return {
		"training_yard": true,
		"wild_count": enemy_root.get_child_count() if enemy_root != null else 0,
		"wild_defeats": wild_defeats,
		"reset_count": reset_count,
		"gremlin": (
			service.call("get_species_data", "gremlin")
			if service != null and service.has_method("get_species_data")
			else {}
		),
		"loadout": (
			service.call("get_familiar_loadout", "gremlin")
			if service != null and service.has_method("get_familiar_loadout")
			else {}
		),
	}


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			result.append(str(raw))
	return result
