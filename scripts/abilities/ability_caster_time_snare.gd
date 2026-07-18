extends "res://scripts/abilities/ability_caster_menu_select.gd"

const TIME_SNARE_SPELL_ID: String = "time_snare"
const GROUND_SPELL_TIME_SNARE: String = "time_snare"

@export_group("Time Snare Targeting")
@export var time_snare_target_radius: float = 3.2
@export var time_snare_target_range: float = 12.0
@export var time_snare_initial_distance: float = 6.0
@export var time_snare_marker_speed: float = 8.0
@export var time_snare_marker_deadzone: float = 0.18
@export var time_snare_ground_y_offset: float = 0.06
@export var time_snare_cast_lock_duration: float = 0.22


func cast_from_player(player: Node3D, cast_lock_duration: float = 0.18, allow_charge: bool = true) -> bool:
	if is_ground_targeting():
		if get_ground_targeting_controller().get_spell_key() == GROUND_SPELL_TIME_SNARE:
			return confirm_ground_targeting()
		return super.cast_from_player(player, cast_lock_duration, allow_charge)

	var ability: AbilityDefinition = get_current_ability()
	if should_use_time_snare_targeting(ability):
		return begin_ground_targeting(
			player,
			ability,
			get_time_snare_target_config(),
			"Place Time Snare. Right stick moves target. Cast confirms. Cancel backs out."
		)

	return super.cast_from_player(player, cast_lock_duration, allow_charge)


func should_use_time_snare_targeting(ability: AbilityDefinition) -> bool:
	if ability == null:
		return false

	if ability.element.to_lower() != "time":
		return false

	var spell_id: String = get_ability_spell_id(ability)
	if spell_id != "":
		return spell_id == TIME_SNARE_SPELL_ID

	return ability.display_name.to_lower() == "time snare"


func confirm_ground_targeting() -> bool:
	if not is_ground_targeting():
		return false

	var controller: RefCounted = get_ground_targeting_controller()
	if controller.get_spell_key() != GROUND_SPELL_TIME_SNARE:
		return super.confirm_ground_targeting()

	var ability_resource: Resource = controller.get_ability()
	var ability: AbilityDefinition = ability_resource as AbilityDefinition
	var player: Node3D = controller.get_source_player()
	var target_position: Vector3 = controller.get_target_position()

	if ability == null or player == null:
		cancel_ground_targeting(false)
		return false

	if action_state != null and not action_state.can_cast():
		return true

	if not pay_ability_cost(ability):
		show_feedback("Not enough resources for Time Snare.")
		return true

	if action_state != null:
		action_state.begin_cast(controller.get_cast_lock_duration(time_snare_cast_lock_duration))

	spawn_time_snare_field(target_position, ability, player)
	cancel_ground_targeting(false)
	show_feedback("Time Snare bends the field.")
	return true


func cancel_ground_targeting(should_show_feedback: bool = true) -> void:
	if not is_ground_targeting():
		return

	var spell_key: String = get_ground_targeting_controller().get_spell_key()
	if spell_key != GROUND_SPELL_TIME_SNARE:
		super.cancel_ground_targeting(should_show_feedback)
		return

	get_ground_targeting_controller().cancel()
	focus_spell_menu_open = false

	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("hide_spell_focus_menu"):
		ui.hide_spell_focus_menu()

	if should_show_feedback:
		show_feedback("Time Snare canceled.")


func get_time_snare_target_config() -> Dictionary:
	return {
		"spell_key": GROUND_SPELL_TIME_SNARE,
		"marker_name": "TimeSnareTargetMarker",
		"disc_name": "TimeSnareDisc",
		"center_name": "TimeSnareCenter",
		"radius": time_snare_target_radius,
		"range": time_snare_target_range,
		"initial_distance": time_snare_initial_distance,
		"speed": time_snare_marker_speed,
		"deadzone": time_snare_marker_deadzone,
		"ground_y_offset": time_snare_ground_y_offset,
		"cast_lock_duration": time_snare_cast_lock_duration,
		"disc_color": Color(0.95, 0.78, 0.18, 0.34),
		"center_color": Color(0.95, 0.78, 0.18, 0.82),
		"disc_alpha": 0.34,
		"center_alpha": 0.82,
		"pulse_speed": 5.8,
		"pulse_size": 0.055,
		"emission_energy": 0.9,
	}


func make_time_snare_payload(ability: AbilityDefinition) -> DamagePayload:
	var base_payload: Resource = get_ability_payload(ability)
	var payload: DamagePayload = DamagePayload.new()

	if base_payload is DamagePayload:
		var duplicate_payload: Resource = base_payload.duplicate(true)
		if duplicate_payload is DamagePayload:
			payload = duplicate_payload as DamagePayload

	payload.source_name = "Time Snare"
	payload.hit_type = "ground_field"
	if payload.status_effect == "":
		payload.status_effect = "chill"
	if payload.status_duration <= 0.0:
		payload.status_duration = 0.75
	if payload.status_strength <= 0.0:
		payload.status_strength = 0.45
	append_payload_tags(payload, ["time_snare", "ground_targeted", "field", "slow", "control"])
	return payload


func spawn_time_snare_field(target_position: Vector3, ability: AbilityDefinition, source_actor: Node3D) -> void:
	if ability == null or ability.ability_scene == null:
		return

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return

	var ability_instance: Node = ability.ability_scene.instantiate()
	var snare_payload: DamagePayload = make_time_snare_payload(ability)

	if ability_instance.has_method("set_payload"):
		ability_instance.set_payload(snare_payload)

	if ability_instance.has_method("set_source_actor"):
		ability_instance.set_source_actor(source_actor)

	scene_root.add_child(ability_instance)

	if ability_instance is Node3D:
		var node_3d: Node3D = ability_instance as Node3D
		node_3d.global_position = target_position

	if ability_instance.has_method("configure_area"):
		ability_instance.call("configure_area")
	if ability_instance.has_method("configure_visual"):
		ability_instance.call("configure_visual")
	if ability_instance.has_method("apply_snare_tick"):
		ability_instance.call_deferred("apply_snare_tick")
