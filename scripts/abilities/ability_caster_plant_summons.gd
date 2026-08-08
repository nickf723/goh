extends "res://scripts/abilities/ability_caster_focus_grid.gd"
class_name AbilityCasterPlantSummons

const PlantSummons = preload(
	"res://scripts/life/plant_summon_catalog.gd"
)
const GroundSpellRegistryScript = preload(
	"res://scripts/abilities/ground_spell_registry.gd"
)


func cast_from_player(
	player: Node3D,
	cast_lock_duration: float = 0.18,
	allow_charge: bool = true
) -> bool:
	if is_ground_targeting():
		return confirm_ground_targeting()

	var ability: AbilityDefinition = get_current_ability()
	var plant_ground_spell: Dictionary = (
		PlantSummons.get_ground_spell_definition_for_ability(ability)
	)
	if not plant_ground_spell.is_empty():
		return begin_ground_targeting(
			player,
			ability,
			plant_ground_spell
		)
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
	var plant_ground_spell: Dictionary = (
		PlantSummons.get_ground_spell_definition_for_key(spell_key)
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

	var payload: DamagePayload = (
		GroundSpellRegistryScript.make_payload_for_ability(
			ability,
			plant_ground_spell
		)
	)
	spawn_ground_field(
		target_position,
		ability,
		player,
		payload,
		plant_ground_spell
	)
	cancel_ground_targeting(false)
	show_feedback(
		str(
			plant_ground_spell.get(
				"confirm_message",
				"The plant takes root."
			)
		)
	)
	return true


func cancel_ground_targeting(
	should_show_feedback: bool = true
) -> void:
	if not is_ground_targeting():
		return
	var controller: RefCounted = get_ground_targeting_controller()
	var spell_key: String = controller.get_spell_key()
	if not PlantSummons.is_plant_ground_spell_key(spell_key):
		super.cancel_ground_targeting(should_show_feedback)
		return

	var plant_ground_spell: Dictionary = (
		PlantSummons.get_ground_spell_definition_for_key(spell_key)
	)
	controller.cancel()
	focus_spell_menu_open = false

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


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["plant_summon_catalog"] = true
	data["plant_summon_ids"] = PlantSummons.get_all_plant_ids()
	data["plant_ground_targeting"] = true
	return data
