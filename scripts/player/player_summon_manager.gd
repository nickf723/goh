extends Node
class_name PlayerSummonManager

signal summon_created(summon: SpectralFamiliar)
signal summon_dismissed
signal summon_command_changed(command: String)
signal summon_cooldown_changed(remaining: float)

@export var handled_spell_id: String = "spectral_familiar"
@export var summon_definition: SummonDefinition
@export var command_action: String = "summon_command_next"

var actor: Node3D
var action_state: PlayerActionState
var active_summon: SpectralFamiliar
var cooldown_remaining: float = 0.0
var total_summons: int = 0
var total_recalls: int = 0


func _ready() -> void:
	actor = get_parent() as Node3D
	if actor != null:
		action_state = actor.get_node_or_null("PlayerActionState") as PlayerActionState
	add_to_group("player_ability_channels")
	add_to_group("summon_managers")
	add_to_group("debuggable")


func _process(delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)
		summon_cooldown_changed.emit(cooldown_remaining)
	if active_summon != null and not is_instance_valid(active_summon):
		active_summon = null


func can_handle_ability(ability: AbilityDefinition) -> bool:
	return ability != null and ability.get_spell_id() == handled_spell_id


func begin_ability_channel(source_player: Node3D, ability: AbilityDefinition) -> bool:
	if source_player != actor or not can_handle_ability(ability):
		return false
	if active_summon != null and is_instance_valid(active_summon):
		active_summon.set_command(SpectralFamiliar.COMMAND_FOLLOW)
		active_summon.recall_to_summoner()
		total_recalls += 1
		_show_message(active_summon.display_name + " recalled.")
		_begin_cast_feedback()
		return true
	if cooldown_remaining > 0.0:
		_show_message("Familiar recovering: " + str(snappedf(cooldown_remaining, 0.1)) + "s")
		return false
	if summon_definition == null or summon_definition.summon_scene == null:
		_show_message("No familiar definition is equipped.")
		return false
	var cost: int = maxi(ability.mana_cost, summon_definition.mana_cost)
	if not GameState.spend_mana(cost):
		_show_message("Not enough mana to summon.")
		return false
	return summon_familiar()


func summon_familiar() -> bool:
	if actor == null or summon_definition == null or summon_definition.summon_scene == null:
		return false
	var instance: Node = summon_definition.summon_scene.instantiate()
	var familiar := instance as SpectralFamiliar
	if familiar == null:
		instance.queue_free()
		return false
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return false
	scene_root.add_child(familiar)
	familiar.global_position = actor.global_position + actor.global_basis * summon_definition.summon_offset
	familiar.initialize(actor, self)
	familiar.familiar_defeated.connect(_on_familiar_defeated)
	active_summon = familiar
	total_summons += 1
	summon_created.emit(active_summon)
	_begin_cast_feedback()
	_show_message(summon_definition.display_name + " answered Grace.")
	return true


func dismiss_summon(start_cooldown: bool = false) -> bool:
	if active_summon == null or not is_instance_valid(active_summon):
		active_summon = null
		return false
	var old_summon: SpectralFamiliar = active_summon
	active_summon = null
	if old_summon.familiar_defeated.is_connected(_on_familiar_defeated):
		old_summon.familiar_defeated.disconnect(_on_familiar_defeated)
	old_summon.queue_free()
	if start_cooldown:
		cooldown_remaining = summon_definition.defeat_cooldown if summon_definition != null else 8.0
	summon_dismissed.emit()
	return true


func command_follow() -> void:
	if active_summon != null:
		active_summon.set_command(SpectralFamiliar.COMMAND_FOLLOW)


func command_stay() -> void:
	if active_summon != null:
		active_summon.set_command(SpectralFamiliar.COMMAND_STAY)


func command_assist() -> void:
	if active_summon != null:
		active_summon.set_command(SpectralFamiliar.COMMAND_ASSIST)


func get_active_summon() -> SpectralFamiliar:
	return active_summon


func reset_summons() -> void:
	dismiss_summon(false)
	cooldown_remaining = 0.0
	total_summons = 0
	total_recalls = 0


func get_debug_data() -> Dictionary:
	return {
		"spell_id": handled_spell_id,
		"active": active_summon != null and is_instance_valid(active_summon),
		"summon": active_summon.display_name if active_summon != null else "none",
		"command": active_summon.command if active_summon != null else "NONE",
		"cooldown": snappedf(cooldown_remaining, 0.1),
		"total_summons": total_summons,
		"total_recalls": total_recalls,
	}


func _on_familiar_defeated(_familiar: SpectralFamiliar) -> void:
	active_summon = null
	cooldown_remaining = summon_definition.defeat_cooldown if summon_definition != null else 8.0
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
