extends "res://scripts/abilities/ability_caster_focus_grid.gd"
class_name AbilityCasterPlantSummons

const PlantSummons = preload(
	"res://scripts/life/plant_summon_catalog.gd"
)
const PreparedPlantLoadoutScript = preload(
	"res://scripts/life/prepared_plant_loadout.gd"
)
const GroundSpellRegistryScript = preload(
	"res://scripts/abilities/ground_spell_registry.gd"
)

var active_plant_preparation_snapshot: Dictionary = {}


func cast_from_player(
	player: Node3D,
	cast_lock_duration: float = 0.18,
	allow_charge: bool = true
) -> bool:
	if is_ground_targeting():
		return confirm_ground_targeting()

	var ability: AbilityDefinition = get_current_ability()
	if PlantSummons.is_plant_summon_ability(ability):
		var store: PreparedPlantLoadout = _get_prepared_plant_loadout()
		if store == null:
			show_feedback("No prepared plant blueprint is available.")
			return false
		var snapshot: Dictionary = store.get_prepared_snapshot()
		var plant_id: String = str(snapshot.get("plant_id", ""))
		var parameters_value: Variant = snapshot.get("parameters", {})
		var parameters: Dictionary = (
			(parameters_value as Dictionary).duplicate(true)
			if parameters_value is Dictionary
			else {}
		)
		var plant_ground_spell: Dictionary = (
			PlantSummons.get_ground_spell_definition_for_prepared(
				ability,
				plant_id,
				parameters
			)
		)
		if plant_ground_spell.is_empty():
			show_feedback("The prepared plant blueprint is unavailable.")
			return false
		active_plant_preparation_snapshot = snapshot.duplicate(true)
		var started: bool = begin_ground_targeting(
			player,
			ability,
			plant_ground_spell
		)
		if not started:
			active_plant_preparation_snapshot.clear()
		return started

	return super.cast_from_player(
		player,
		cast_lock_duration,
		allow_charge
	)


func confirm_ground_targeting() -> bool:
	if not is_ground_targeting():
		return false

	var controller: RefCounted = get_ground_targeting_controller()
	var spell_key: String = controller.get_spell_key()
	if not PlantSummons.is_plant_ground_spell_key(spell_key):
		return super.confirm_ground_targeting()

	if (
		controller.has_method("is_target_valid")
		and not bool(controller.call("is_target_valid"))
	):
		var reason: String = "That plant cannot grow there."
		if controller.has_method("get_invalid_reason"):
			var reported: String = str(
				controller.call("get_invalid_reason")
			)
			if reported != "":
				reason = reported
		show_feedback(reason)
		return true

	var ability_resource: Resource = controller.get_ability()
	var ability: AbilityDefinition = ability_resource as AbilityDefinition
	var player: Node3D = controller.get_source_player()
	var target_position: Vector3 = controller.get_target_position()
	var snapshot: Dictionary = active_plant_preparation_snapshot.duplicate(true)
	if snapshot.is_empty():
		var store: PreparedPlantLoadout = _get_prepared_plant_loadout()
		if store != null:
			snapshot = store.get_prepared_snapshot()
	var plant_id: String = str(snapshot.get("plant_id", ""))
	var parameters_value: Variant = snapshot.get("parameters", {})
	var parameters: Dictionary = (
		(parameters_value as Dictionary).duplicate(true)
		if parameters_value is Dictionary
		else {}
	)
	var plant_ground_spell: Dictionary = (
		PlantSummons.get_ground_spell_definition_for_prepared(
			ability,
			plant_id,
			parameters
		)
	)
	if ability == null or player == null or plant_ground_spell.is_empty():
		cancel_ground_targeting(false)
		return false

	if action_state != null and not action_state.can_cast():
		return true
	if not pay_ability_cost(ability):
		show_feedback(
			"Not enough resources for " + ability.display_name + "."
		)
		return true

	if action_state != null:
		action_state.begin_cast(
			controller.get_cast_lock_duration(0.2)
		)

	var did_spawn: bool = _spawn_prepared_plant(
		target_position,
		player,
		snapshot
	)
	if not did_spawn:
		show_feedback("The prepared plant could not take root.")
		return true

	var confirm_message: String = str(
		plant_ground_spell.get(
			"confirm_message",
			"The plant takes root."
		)
	)
	cancel_ground_targeting(false)
	show_feedback(confirm_message)
	return true


func cancel_ground_targeting(
	should_show_feedback: bool = true
) -> void:
	if not is_ground_targeting():
		active_plant_preparation_snapshot.clear()
		return
	var controller: RefCounted = get_ground_targeting_controller()
	var spell_key: String = controller.get_spell_key()
	if not PlantSummons.is_plant_ground_spell_key(spell_key):
		super.cancel_ground_targeting(should_show_feedback)
		return

	var plant_ground_spell: Dictionary = {}
	if not active_plant_preparation_snapshot.is_empty():
		var plant_id: String = str(
			active_plant_preparation_snapshot.get("plant_id", "")
		)
		var parameters_value: Variant = active_plant_preparation_snapshot.get(
			"parameters",
			{}
		)
		var parameters: Dictionary = (
			(parameters_value as Dictionary).duplicate(true)
			if parameters_value is Dictionary
			else {}
		)
		plant_ground_spell = PlantSummons.get_ground_spell_definition(
			plant_id,
			"",
			parameters
		)
	if plant_ground_spell.is_empty():
		plant_ground_spell = PlantSummons.get_ground_spell_definition_for_key(
			spell_key
		)

	controller.cancel()
	focus_spell_menu_open = false
	active_plant_preparation_snapshot.clear()

	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("hide_spell_focus_menu"):
		ui.call("hide_spell_focus_menu")
	elif ui != null and ui.has_method("hide_spell_menu"):
		ui.call("hide_spell_menu")

	if should_show_feedback:
		show_feedback(
			str(
				plant_ground_spell.get(
					"cancel_message",
					"Plant growth canceled."
				)
			)
		)


func _spawn_prepared_plant(
	target_position: Vector3,
	player: Node3D,
	snapshot: Dictionary
) -> bool:
	var plant_id: String = str(snapshot.get("plant_id", ""))
	var definition: PlantSummonDefinition = PlantSummons.get_definition(plant_id)
	if definition == null or definition.summon_scene_path == "":
		return false
	var scene_resource: Resource = load(definition.summon_scene_path)
	if not scene_resource is PackedScene:
		return false
	var instance: Node = (scene_resource as PackedScene).instantiate()
	if instance == null:
		return false
	var parameters_value: Variant = snapshot.get("parameters", {})
	var parameters: Dictionary = (
		(parameters_value as Dictionary).duplicate(true)
		if parameters_value is Dictionary
		else {}
	)
	if instance.has_method("set_plant_definition"):
		instance.call("set_plant_definition", definition)
	if instance.has_method("set_prepared_parameters"):
		instance.call("set_prepared_parameters", parameters)
	if instance.has_method("set_source_actor"):
		instance.call("set_source_actor", player)

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		instance.queue_free()
		return false
	scene_root.add_child(instance)
	if instance is Node3D:
		(instance as Node3D).global_position = target_position
	if instance.has_method("activate_from_ground_target"):
		instance.call("activate_from_ground_target")
	elif instance.has_method("activate_at"):
		instance.call("activate_at", target_position, Vector3.UP, player)
	else:
		instance.queue_free()
		return false
	return true


func _get_prepared_plant_loadout() -> PreparedPlantLoadout:
	return PreparedPlantLoadoutScript.get_or_create(get_tree()) as PreparedPlantLoadout


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	var store: PreparedPlantLoadout = _get_prepared_plant_loadout()
	data["plant_summon_catalog"] = true
	data["plant_summon_ids"] = PlantSummons.get_all_plant_ids()
	data["plant_ground_targeting"] = true
	data["plant_preparation_external"] = true
	data["combat_configuration_required"] = false
	data["prepared_plant"] = (
		store.get_prepared_snapshot() if store != null else {}
	)
	data["active_cast_snapshot"] = active_plant_preparation_snapshot.duplicate(true)
	return data
