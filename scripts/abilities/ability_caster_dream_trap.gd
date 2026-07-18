extends "res://scripts/abilities/ability_caster_time_snare.gd"

const DREAM_TRAP_SPELL_IDS: Array[String] = ["dream_snare", "dream_trap"]
const GROUND_SPELL_DREAM_TRAP: String = "dream_trap"

@export_group("Dream Trap Targeting")
@export var dream_trap_target_radius: float = 2.75
@export var dream_trap_target_range: float = 12.0
@export var dream_trap_initial_distance: float = 6.0
@export var dream_trap_marker_speed: float = 8.0
@export var dream_trap_marker_deadzone: float = 0.18
@export var dream_trap_ground_y_offset: float = 0.06
@export var dream_trap_cast_lock_duration: float = 0.22


func cast_from_player(player: Node3D, cast_lock_duration: float = 0.18, allow_charge: bool = true) -> bool:
	if is_ground_targeting():
		if get_ground_targeting_controller().get_spell_key() == GROUND_SPELL_DREAM_TRAP:
			return confirm_ground_targeting()
		return super.cast_from_player(player, cast_lock_duration, allow_charge)

	var ability: AbilityDefinition = get_current_ability()
	if should_use_dream_trap_targeting(ability):
		return begin_ground_targeting(
			player,
			ability,
			get_dream_trap_target_config(),
			"Place Dream Trap. Right stick moves target. Cast confirms. Cancel backs out."
		)

	return super.cast_from_player(player, cast_lock_duration, allow_charge)


func should_use_dream_trap_targeting(ability: AbilityDefinition) -> bool:
	if ability == null:
		return false

	if ability.element.to_lower() != "dreams":
		return false

	var spell_id: String = get_ability_spell_id(ability)
	if spell_id != "":
		return DREAM_TRAP_SPELL_IDS.has(spell_id)

	var display_name: String = ability.display_name.to_lower()
	return display_name == "dream snare" or display_name == "dream trap"


func confirm_ground_targeting() -> bool:
	if not is_ground_targeting():
		return false

	var controller: RefCounted = get_ground_targeting_controller()
	if controller.get_spell_key() != GROUND_SPELL_DREAM_TRAP:
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
		show_feedback("Not enough resources for Dream Trap.")
		return true

	if action_state != null:
		action_state.begin_cast(controller.get_cast_lock_duration(dream_trap_cast_lock_duration))

	spawn_dream_trap(target_position, ability, player)
	cancel_ground_targeting(false)
	show_feedback("Dream Trap waits.")
	return true


func cancel_ground_targeting(should_show_feedback: bool = true) -> void:
	if not is_ground_targeting():
		return

	var spell_key: String = get_ground_targeting_controller().get_spell_key()
	if spell_key != GROUND_SPELL_DREAM_TRAP:
		super.cancel_ground_targeting(should_show_feedback)
		return

	get_ground_targeting_controller().cancel()
	focus_spell_menu_open = false

	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("hide_spell_focus_menu"):
		ui.hide_spell_focus_menu()

	if should_show_feedback:
		show_feedback("Dream Trap canceled.")


func get_dream_trap_target_config() -> Dictionary:
	return {
		"spell_key": GROUND_SPELL_DREAM_TRAP,
		"marker_name": "DreamTrapTargetMarker",
		"disc_name": "DreamTrapDisc",
		"center_name": "DreamTrapCenter",
		"radius": dream_trap_target_radius,
		"range": dream_trap_target_range,
		"initial_distance": dream_trap_initial_distance,
		"speed": dream_trap_marker_speed,
		"deadzone": dream_trap_marker_deadzone,
		"ground_y_offset": dream_trap_ground_y_offset,
		"cast_lock_duration": dream_trap_cast_lock_duration,
		"disc_color": Color(0.62, 0.24, 0.95, 0.34),
		"center_color": Color(0.72, 0.28, 1.0, 0.82),
		"disc_alpha": 0.34,
		"center_alpha": 0.82,
		"pulse_speed": 4.1,
		"pulse_size": 0.06,
		"emission_energy": 0.92,
	}


func make_dream_trap_payload(ability: AbilityDefinition) -> DamagePayload:
	var base_payload: Resource = get_ability_payload(ability)
	var payload: DamagePayload = DamagePayload.new()

	if base_payload is DamagePayload:
		var duplicate_payload: Resource = base_payload.duplicate(true)
		if duplicate_payload is DamagePayload:
			payload = duplicate_payload as DamagePayload

	payload.source_name = "Dream Trap"
	payload.hit_type = "trap"
	if payload.status_effect == "":
		payload.status_effect = "staggered"
	if payload.status_duration <= 0.0:
		payload.status_duration = 1.2
	if payload.status_strength <= 0.0:
		payload.status_strength = 1.0
	append_payload_tags(payload, ["dream_trap", "ground_targeted", "trap", "illusion", "control"])
	return payload


func spawn_dream_trap(target_position: Vector3, ability: AbilityDefinition, source_actor: Node3D) -> void:
	if ability == null or ability.ability_scene == null:
		return

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return

	var ability_instance: Node = ability.ability_scene.instantiate()
	var dream_payload: DamagePayload = make_dream_trap_payload(ability)

	if ability_instance.has_method("set_payload"):
		ability_instance.set_payload(dream_payload)

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
