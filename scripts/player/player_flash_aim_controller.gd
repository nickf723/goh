extends Node
class_name PlayerFlashAimController

signal flash_aim_started
signal flash_aim_cancelled(reason: String)
signal flash_committed(direction: Vector3)

const GameplayEffectAccessScript = preload(
	"res://scripts/effects/gameplay_effect_access.gd"
)

@export var handled_spell_id: String = "flash"
@export var channel_action: StringName = &"cast_spell"
@export_range(0.0, 0.5, 0.01) var minimum_aim_seconds: float = 0.04
@export_range(0.01, 0.5, 0.01) var post_cast_lock_seconds: float = 0.08
@export_range(0.0, 1.0, 0.05) var upward_warning_component: float = 0.38
@export_range(0.0, 4.0, 0.05) var vertical_overflow_screens: float = 1.8
@export_range(0.0, 2.0, 0.05) var horizontal_overflow_screens: float = 0.7
@export_range(4.0, 60.0, 1.0) var pointer_status_updates_per_second: float = 24.0

var player: CharacterBody3D
var action_state: PlayerActionState
var ability_caster: Node
var aim_pointer: PlayerSpellAimPointer
var active_ability: AbilityDefinition
var aiming: bool = false
var aim_elapsed: float = 0.0
var status_accumulator: float = 0.0
var last_end_reason: String = "never_started"
var aim_start_count: int = 0
var commit_count: int = 0
var cancel_count: int = 0
var last_committed_direction: Vector3 = Vector3.ZERO
var last_pointer_direction: Vector3 = Vector3.FORWARD
var test_cast_held_override_enabled: bool = false
var test_cast_held: bool = true


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	if player != null:
		action_state = player.get_node_or_null(
			"PlayerActionState"
		) as PlayerActionState
		ability_caster = player.get_node_or_null("AbilityCaster")
		aim_pointer = player.get_node_or_null(
			"SpellAimPointer"
		) as PlayerSpellAimPointer
	add_to_group("player_ability_channels")
	add_to_group("flash_aim_controllers")
	add_to_group("lab_resettable")
	add_to_group("debuggable")
	set_process(false)


func _exit_tree() -> void:
	cancel_ability_channel("scene_exit")


func can_handle_ability(ability: AbilityDefinition) -> bool:
	return (
		ability != null
		and ability.get_spell_id() == handled_spell_id
	)


func begin_ability_channel(
	source_player: Node3D,
	ability: AbilityDefinition
) -> bool:
	if source_player != player or not can_handle_ability(ability):
		return false
	if aiming:
		return true
	if ability.ability_scene == null:
		_show_message("Flash has no travel action.")
		return false
	if GameState.get_stat("mana") < _get_required_mana(ability):
		_show_message("Not enough Mana to prepare Flash.")
		return false
	if action_state != null and not action_state.begin_cast_channel():
		return false
	if aim_pointer == null or not is_instance_valid(aim_pointer):
		aim_pointer = player.get_node_or_null(
			"SpellAimPointer"
		) as PlayerSpellAimPointer
	if aim_pointer == null:
		if action_state != null:
			action_state.end_cast()
		_show_message("Flash cannot find its aiming pointer.")
		return false

	active_ability = ability
	aiming = true
	aim_elapsed = 0.0
	status_accumulator = 0.0
	last_end_reason = "aiming"
	aim_start_count += 1
	aim_pointer.begin_aim(self, {
		"mode_id": "flash_direction",
		"capture_look": true,
		"initial_normalized_position": Vector2(0.5, 0.5),
		"horizontal_overflow_screens": horizontal_overflow_screens,
		"vertical_overflow_screens": vertical_overflow_screens,
		"color": Color(0.28, 0.52, 1.0, 1.0),
		"status_text": "FLASH • HOLD TO AIM • RELEASE TO TRAVEL",
		"target_valid": true,
	})
	_update_pointer_status()
	set_process(true)
	flash_aim_started.emit()
	_show_message(
		"Flash: hold Cast to aim the pointer. Release to become the bolt."
	)
	return true


func _process(delta: float) -> void:
	if not aiming:
		return
	if _aim_was_interrupted():
		cancel_ability_channel("interrupted")
		return
	if not _flash_is_still_equipped():
		cancel_ability_channel("spell_changed")
		return

	var step: float = maxf(delta, 0.0)
	aim_elapsed += step
	status_accumulator += step
	var status_interval: float = 1.0 / maxf(
		pointer_status_updates_per_second,
		1.0
	)
	if status_accumulator >= status_interval:
		status_accumulator = fmod(status_accumulator, status_interval)
		_update_pointer_status()

	if aim_elapsed >= minimum_aim_seconds and not _is_cast_held():
		commit_flash()


func commit_flash(direction_override: Vector3 = Vector3.ZERO) -> bool:
	if not aiming or active_ability == null:
		return false
	var direction: Vector3 = direction_override
	if direction.length_squared() <= 0.0001 and aim_pointer != null:
		direction = aim_pointer.get_ray_direction()
	if direction.length_squared() <= 0.0001:
		direction = -player.global_transform.basis.z
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	direction = direction.normalized()

	var ability: AbilityDefinition = active_ability
	_release_pointer("committed")
	aiming = false
	active_ability = null
	set_process(false)
	if action_state != null:
		action_state.end_cast()

	if ability_caster == null or not is_instance_valid(ability_caster):
		last_end_reason = "missing_caster"
		return false
	if not ability_caster.has_method("pay_ability_cost"):
		last_end_reason = "missing_cost_contract"
		return false
	if not bool(ability_caster.call("pay_ability_cost", ability, 0)):
		last_end_reason = "insufficient_resources"
		_show_message("Not enough resources for Flash.")
		return false

	var scene_root: Node = get_tree().current_scene
	if scene_root == null or not scene_root.is_inside_tree():
		last_end_reason = "missing_scene"
		return false
	var flash_instance: Node = ability.ability_scene.instantiate()
	if flash_instance == null:
		last_end_reason = "instantiate_failed"
		return false
	var action_payload: Resource = ability.get_action_payload()
	if action_payload != null and flash_instance.has_method("set_payload"):
		flash_instance.call("set_payload", action_payload)
	if flash_instance.has_method("set_source_actor"):
		flash_instance.call("set_source_actor", player)
	scene_root.add_child(flash_instance)
	if not flash_instance.has_method("execute"):
		flash_instance.queue_free()
		last_end_reason = "missing_execute"
		return false
	if action_state != null:
		action_state.begin_cast(post_cast_lock_seconds)
	flash_instance.call("execute", player, direction)
	last_committed_direction = direction
	last_end_reason = "committed"
	commit_count += 1
	flash_committed.emit(direction)
	return true


func commit_flash_for_test(direction: Vector3) -> bool:
	return commit_flash(direction)


func cancel_ability_channel(reason: String = "cancelled") -> void:
	if not aiming:
		return
	aiming = false
	active_ability = null
	last_end_reason = reason
	cancel_count += 1
	set_process(false)
	_release_pointer(reason)
	if (
		action_state != null
		and action_state.is_cast_channel_active()
	):
		action_state.end_cast()
	flash_aim_cancelled.emit(reason)


func reset_target() -> void:
	cancel_ability_channel("reset")
	aim_elapsed = 0.0
	status_accumulator = 0.0
	last_committed_direction = Vector3.ZERO
	last_pointer_direction = Vector3.FORWARD
	test_cast_held_override_enabled = false
	test_cast_held = true
	last_end_reason = "reset"


func set_test_cast_held_override(
	held: bool,
	enabled: bool = true
) -> void:
	test_cast_held = held
	test_cast_held_override_enabled = enabled


func is_flash_aiming() -> bool:
	return aiming


func _is_cast_held() -> bool:
	if test_cast_held_override_enabled:
		return test_cast_held
	return Input.is_action_pressed(channel_action)


func _get_required_mana(ability: AbilityDefinition) -> int:
	return GameplayEffectAccessScript.modify_int(
		"mana_cost",
		ability.mana_cost,
		"ceil"
	)


func _flash_is_still_equipped() -> bool:
	if ability_caster == null or not ability_caster.has_method(
		"get_current_ability"
	):
		return false
	var current_value: Variant = ability_caster.call("get_current_ability")
	return (
		current_value is AbilityDefinition
		and can_handle_ability(current_value as AbilityDefinition)
	)


func _aim_was_interrupted() -> bool:
	if player == null or not is_instance_valid(player):
		return true
	if bool(player.get("is_defeated")):
		return true
	if action_state == null:
		return false
	return (
		action_state.is_defeated
		or action_state.is_focus_menu_open
		or action_state.is_staggered
		or action_state.is_dodging
		or action_state.is_interacting
		or action_state.is_manipulating
		or action_state.is_guarding
		or action_state.is_using_item
		or not action_state.is_cast_channel_active()
	)


func _update_pointer_status() -> void:
	if aim_pointer == null or not aim_pointer.is_owned_by(self):
		return
	last_pointer_direction = aim_pointer.get_ray_direction()
	var status: String = "FLASH • RELEASE TO TRAVEL"
	if last_pointer_direction.y >= upward_warning_component:
		status = "FLASH • UPWARD LINE • NO SAFE LANDING"
	elif last_pointer_direction.y <= -upward_warning_component:
		status = "FLASH • DOWNWARD LINE • FIRST CONTACT"
	aim_pointer.set_target_state(true, status)


func _release_pointer(reason: String) -> void:
	if aim_pointer != null and aim_pointer.is_owned_by(self):
		aim_pointer.end_aim(self, reason)


func _show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	return {
		"flash_aim_controller": true,
		"spell_id": handled_spell_id,
		"aiming": aiming,
		"aim_elapsed": snappedf(aim_elapsed, 0.01),
		"pointer_ready": aim_pointer != null,
		"pointer_owned": (
			aim_pointer != null and aim_pointer.is_owned_by(self)
		),
		"pointer_direction": last_pointer_direction,
		"last_committed_direction": last_committed_direction,
		"aim_starts": aim_start_count,
		"commits": commit_count,
		"cancels": cancel_count,
		"last_end_reason": last_end_reason,
		"processing": is_processing(),
	}
