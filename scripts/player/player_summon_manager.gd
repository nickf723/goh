extends Node
class_name PlayerSummonManager

signal summon_created(summon: Node3D)
signal summon_dismissed
signal summon_command_changed(command: String)
signal summon_cooldown_changed(remaining: float)

const FamiliarCatalog = preload(
	"res://scripts/summons/familiar_definition_catalog.gd"
)
const FamiliarCommandInterfaceScript = preload(
	"res://scripts/ui/familiar_command_interface.gd"
)

@export var handled_spell_id: String = "spectral_familiar"
@export var summon_definition: SummonDefinition
@export var install_command_interface: bool = true

var actor: Node3D
var action_state: PlayerActionState
var active_summon: Node3D
var active_definition: SummonDefinition
var command_interface: Node
var cooldown_remaining: float = 0.0
var total_summons: int = 0
var total_recalls: int = 0
var total_commands: int = 0
var last_command_id: String = "none"


func _ready() -> void:
	actor = get_parent() as Node3D
	if actor != null:
		action_state = actor.get_node_or_null("PlayerActionState") as PlayerActionState
	add_to_group("player_ability_channels")
	add_to_group("summon_managers")
	add_to_group("debuggable")
	if install_command_interface:
		call_deferred("_install_command_interface")


func _process(delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)
		summon_cooldown_changed.emit(cooldown_remaining)
	if active_summon != null and not is_instance_valid(active_summon):
		active_summon = null
		active_definition = null
		summon_dismissed.emit()


func can_handle_ability(ability: AbilityDefinition) -> bool:
	return ability != null and ability.get_spell_id() == handled_spell_id


func begin_ability_channel(source_player: Node3D, ability: AbilityDefinition) -> bool:
	if source_player != actor or not can_handle_ability(ability):
		return false
	if active_summon != null and is_instance_valid(active_summon):
		var dismissed_name: String = get_active_familiar_display_name()
		if not dismiss_summon(false):
			return false
		total_recalls += 1
		_show_message(dismissed_name + " dismissed. Cast again to summon the prepared familiar.")
		_begin_cast_feedback()
		return true
	if cooldown_remaining > 0.0:
		_show_message("Familiar recovering: " + str(snappedf(cooldown_remaining, 0.1)) + "s")
		return false
	var definition: SummonDefinition = get_resolved_summon_definition()
	if definition == null or definition.summon_scene == null:
		_show_message("No familiar blueprint is equipped.")
		return false
	if not _definition_is_unlocked(definition):
		_show_message(definition.display_name + " has not been understood well enough to summon.")
		return false
	var cost: int = maxi(ability.mana_cost, definition.mana_cost)
	if not GameState.spend_mana(cost):
		_show_message("Not enough mana to summon.")
		return false
	return summon_familiar(definition)


func summon_familiar(definition_override: SummonDefinition = null) -> bool:
	if actor == null:
		return false
	var definition: SummonDefinition = (
		definition_override if definition_override != null else get_resolved_summon_definition()
	)
	if definition == null or definition.summon_scene == null:
		return false
	var instance: Node = definition.summon_scene.instantiate()
	if not (instance is Node3D):
		if instance != null:
			instance.queue_free()
		_show_message("The prepared familiar scene is not a 3D actor.")
		return false
	var familiar: Node3D = instance as Node3D
	if not familiar.has_method("initialize"):
		familiar.queue_free()
		_show_message("The prepared familiar does not implement the summon contract.")
		return false
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		familiar.queue_free()
		return false
	scene_root.add_child(familiar)
	familiar.global_position = actor.global_position + actor.global_basis * definition.summon_offset
	familiar.call("initialize", actor, self)
	if familiar.has_method("configure_familiar"):
		familiar.call("configure_familiar", _get_loadout_for_definition(definition), definition)
	if familiar.has_signal("familiar_defeated"):
		var callback := Callable(self, "_on_familiar_defeated")
		if not familiar.is_connected("familiar_defeated", callback):
			familiar.connect("familiar_defeated", callback)
	active_summon = familiar
	active_definition = definition
	total_summons += 1
	summon_created.emit(active_summon)
	_begin_cast_feedback()
	_show_message(definition.display_name + " answered Grace. Familiar commands are now available.")
	return true


func dismiss_summon(start_cooldown: bool = false) -> bool:
	if active_summon == null or not is_instance_valid(active_summon):
		active_summon = null
		active_definition = null
		return false
	var old_summon: Node3D = active_summon
	var old_definition: SummonDefinition = active_definition
	active_summon = null
	active_definition = null
	var callback := Callable(self, "_on_familiar_defeated")
	if old_summon.has_signal("familiar_defeated") and old_summon.is_connected("familiar_defeated", callback):
		old_summon.disconnect("familiar_defeated", callback)
	if old_summon.has_method("dismiss_familiar"):
		old_summon.call("dismiss_familiar")
	else:
		old_summon.queue_free()
	if start_cooldown:
		cooldown_remaining = old_definition.defeat_cooldown if old_definition != null else 8.0
	summon_dismissed.emit()
	return true


func get_active_summon() -> Node3D:
	return active_summon if active_summon != null and is_instance_valid(active_summon) else null


func get_active_familiar_display_name() -> String:
	var familiar: Node3D = get_active_summon()
	if familiar == null:
		return "Familiar"
	var display_value: Variant = familiar.get("display_name")
	if display_value != null and str(display_value) != "":
		return str(display_value)
	var animal_name_value: Variant = familiar.get("animal_name")
	if animal_name_value != null and str(animal_name_value) != "":
		return str(animal_name_value)
	if active_definition != null and active_definition.display_name != "":
		return active_definition.display_name
	return str(familiar.name)


func get_available_familiar_commands() -> Array[String]:
	var familiar: Node3D = get_active_summon()
	var commands: Array[String] = []
	if familiar == null:
		return commands
	if familiar.has_method("get_available_familiar_commands"):
		var value: Variant = familiar.call("get_available_familiar_commands")
		if value is Array:
			for raw: Variant in value as Array:
				_append_command(commands, str(raw))
		return commands
	if familiar.has_method("issue_follow_command") or familiar.has_method("set_command"):
		_append_command(commands, "follow")
	if familiar.has_method("issue_stay_command") or familiar.has_method("set_command"):
		_append_command(commands, "stay")
	if familiar.has_method("issue_come_here_command") or familiar.has_method("recall_to_summoner"):
		_append_command(commands, "come_here")
	if familiar.has_method("issue_move_to_command"):
		_append_command(commands, "move_to")
	if familiar.has_method("set_command"):
		_append_command(commands, "assist")
	return commands


func issue_familiar_command(
	command_id: String,
	destination: Vector3 = Vector3.INF
) -> Dictionary:
	var familiar: Node3D = get_active_summon()
	if familiar == null:
		return {"ok": false, "error": "No familiar is summoned."}
	var normalized: String = _normalize_command(command_id)
	if not get_available_familiar_commands().has(normalized):
		return {
			"ok": false,
			"error": get_active_familiar_display_name() + " does not support " + normalized.replace("_", " ") + ".",
		}
	var result: Dictionary = {"ok": false, "command_id": normalized}
	match normalized:
		"follow":
			result = _call_command_method(familiar, "issue_follow_command", [], "FOLLOW")
		"stay":
			result = _call_command_method(
				familiar,
				"issue_stay_command",
				[familiar.global_position],
				"STAY"
			)
		"come_here":
			if familiar.has_method("issue_come_here_command"):
				result = _result_dictionary(familiar.call("issue_come_here_command"))
			elif familiar.has_method("recall_to_summoner"):
				familiar.call("recall_to_summoner")
				result = {"ok": true, "command_id": normalized}
		"move_to":
			if destination == Vector3.INF:
				result = {"ok": false, "error": "Go There requires a world destination."}
			elif familiar.has_method("issue_move_to_command"):
				result = _result_dictionary(familiar.call("issue_move_to_command", destination))
		"assist":
			result = _set_legacy_command(familiar, "ASSIST")
		"focus":
			result = _set_legacy_command(familiar, "FOCUS")
		_:
			result = {"ok": false, "error": "Unknown familiar command."}
	if bool(result.get("ok", false)):
		result["command_id"] = normalized
		last_command_id = normalized
		total_commands += 1
		summon_command_changed.emit(normalized)
	return result


func get_familiar_command_state() -> Dictionary:
	var familiar: Node3D = get_active_summon()
	if familiar == null:
		return {"active": false, "command_id": "none"}
	var data: Dictionary = {}
	if familiar.has_method("get_familiar_command_data"):
		data = _result_dictionary(familiar.call("get_familiar_command_data"))
	elif familiar.has_method("get_companion_command_data"):
		data = _result_dictionary(familiar.call("get_companion_command_data"))
	else:
		var command_value: Variant = familiar.get("command")
		data["command"] = str(command_value) if command_value != null else "FOLLOW"
	data["active"] = true
	data["display_name"] = get_active_familiar_display_name()
	if not data.has("command_id"):
		data["command_id"] = _normalize_command(str(data.get("command", "follow")))
	return data


func command_follow() -> Dictionary:
	return issue_familiar_command("follow")


func command_stay() -> Dictionary:
	return issue_familiar_command("stay")


func command_assist() -> Dictionary:
	return issue_familiar_command("assist")


func command_focus() -> Dictionary:
	return issue_familiar_command("focus")


func command_come_here() -> Dictionary:
	return issue_familiar_command("come_here")


func command_move_to(destination: Vector3) -> Dictionary:
	return issue_familiar_command("move_to", destination)


func command_rally() -> Dictionary:
	return command_follow()


func command_hold() -> Dictionary:
	return command_stay()


func get_resolved_summon_definition() -> SummonDefinition:
	var species_knowledge: Node = get_node_or_null("/root/SpeciesKnowledge")
	if species_knowledge != null and species_knowledge.has_method("get_equipped_familiar_species_id"):
		var species_id: String = str(species_knowledge.call("get_equipped_familiar_species_id"))
		if species_id != "":
			var definition_value: Variant = FamiliarCatalog.get_definition(species_id)
			if definition_value is SummonDefinition:
				return definition_value as SummonDefinition
	return summon_definition


func reset_summons() -> void:
	dismiss_summon(false)
	cooldown_remaining = 0.0
	total_summons = 0
	total_recalls = 0
	total_commands = 0
	last_command_id = "none"


func get_debug_data() -> Dictionary:
	var definition: SummonDefinition = get_resolved_summon_definition()
	return {
		"spell_id": handled_spell_id,
		"active": get_active_summon() != null,
		"summon": get_active_familiar_display_name() if get_active_summon() != null else "none",
		"command": get_familiar_command_state().get("command_id", "none"),
		"available_commands": get_available_familiar_commands(),
		"resolved_definition": definition.summon_id if definition != null else "none",
		"resolved_species": definition.species_id if definition != null else "",
		"cooldown": snappedf(cooldown_remaining, 0.1),
		"total_summons": total_summons,
		"total_recalls": total_recalls,
		"total_commands": total_commands,
		"last_command": last_command_id,
		"command_interface_installed": command_interface != null and is_instance_valid(command_interface),
	}


func _install_command_interface() -> void:
	if actor == null:
		return
	var existing: Node = actor.get_node_or_null("FamiliarCommandInterface")
	if existing != null:
		command_interface = existing
	else:
		command_interface = FamiliarCommandInterfaceScript.new()
		command_interface.name = "FamiliarCommandInterface"
		actor.add_child(command_interface)
	if command_interface.has_method("bind"):
		command_interface.call("bind", self, actor)


func _call_command_method(
	familiar: Node3D,
	method_name: String,
	arguments: Array,
	fallback_command: String
) -> Dictionary:
	if familiar.has_method(method_name):
		return _result_dictionary(familiar.callv(method_name, arguments))
	return _set_legacy_command(familiar, fallback_command)


func _set_legacy_command(familiar: Node3D, command_value: String) -> Dictionary:
	if familiar == null or not familiar.has_method("set_command"):
		return {"ok": false, "error": "Familiar command method is unavailable."}
	familiar.call("set_command", command_value)
	var actual: Variant = familiar.get("command")
	var succeeded: bool = actual != null and str(actual).to_upper() == command_value.to_upper()
	return {
		"ok": succeeded,
		"command": str(actual) if actual != null else command_value,
	}


func _result_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {"ok": bool(value)}


func _append_command(commands: Array[String], command_id: String) -> void:
	var normalized: String = _normalize_command(command_id)
	if normalized != "" and not commands.has(normalized):
		commands.append(normalized)


func _normalize_command(value: String) -> String:
	var normalized: String = value.to_lower().strip_edges().replace(" ", "_")
	match normalized:
		"rally": return "follow"
		"hold": return "stay"
		"go_there": return "move_to"
		_: return normalized


func _definition_is_unlocked(definition: SummonDefinition) -> bool:
	if definition == null or definition.unlock_id == "" or definition.species_id == "":
		return true
	var species_knowledge: Node = get_node_or_null("/root/SpeciesKnowledge")
	return (
		species_knowledge != null
		and species_knowledge.has_method("has_unlock")
		and bool(species_knowledge.call("has_unlock", definition.species_id, definition.unlock_id))
	)


func _get_loadout_for_definition(definition: SummonDefinition) -> Dictionary:
	if definition == null or definition.species_id == "":
		return {}
	var species_knowledge: Node = get_node_or_null("/root/SpeciesKnowledge")
	if species_knowledge != null and species_knowledge.has_method("get_familiar_loadout"):
		var value: Variant = species_knowledge.call("get_familiar_loadout", definition.species_id)
		return value as Dictionary if value is Dictionary else {}
	return {}


func _on_familiar_defeated(_familiar: Node = null) -> void:
	var defeated_definition: SummonDefinition = active_definition
	active_summon = null
	active_definition = null
	cooldown_remaining = defeated_definition.defeat_cooldown if defeated_definition != null else 8.0
	summon_dismissed.emit()
	_show_message("The familiar was dispersed. Its spirit must recover.")


func _begin_cast_feedback() -> void:
	if action_state != null:
		action_state.begin_cast(0.32)


func _show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)
	else:
		print(message)
