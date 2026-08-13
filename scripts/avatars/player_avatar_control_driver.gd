extends "res://scripts/avatars/avatar_control_driver.gd"
class_name PlayerAvatarControlDriver

@export var observe_each_frame: bool = true

var ability_caster: Node


func _ready() -> void:
	driver_id = "player_input"
	display_name = "Player Input"
	bind_actor(get_parent() as Node3D, get_parent() as Node3D)
	if controlled_actor != null:
		ability_caster = controlled_actor.get_node_or_null("AbilityCaster")
	add_to_group("avatar_control_driver")
	add_to_group("player_avatar_control_driver")
	add_to_group("debuggable")


func _process(delta: float) -> void:
	if observe_each_frame:
		sample_intent(delta)


func _build_intent(_delta: float, intent: AvatarActionIntent) -> void:
	if controlled_actor == null or not is_instance_valid(controlled_actor):
		controlled_actor = null
		ability_caster = null
		return
	var input_vector: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)
	if input_vector.length() > 0.01:
		var camera: Camera3D = get_viewport().get_camera_3d()
		var forward: Vector3 = -controlled_actor.global_transform.basis.z
		var right: Vector3 = controlled_actor.global_transform.basis.x
		if camera != null:
			forward = -camera.global_transform.basis.z
			right = camera.global_transform.basis.x
		forward.y = 0.0
		right.y = 0.0
		var world_direction: Vector3 = (
			right.normalized() * input_vector.x
			+ forward.normalized() * -input_vector.y
		)
		intent.set_movement(world_direction, input_vector.length())

	var valid_target: Node3D = _get_valid_lock_on_target()
	if valid_target != null:
		intent.target = valid_target
		intent.set_facing(intent.target.global_position - controlled_actor.global_position)
	elif intent.movement_direction.length_squared() > 0.001:
		intent.set_facing(intent.movement_direction)

	if InputMap.has_action("weapon_light_attack") and Input.is_action_just_pressed(
		"weapon_light_attack"
	):
		intent.attack_id = "input:light"
		intent.decision_tag = "player_light"
	elif InputMap.has_action("weapon_heavy_attack") and Input.is_action_just_pressed(
		"weapon_heavy_attack"
	):
		intent.attack_id = "input:heavy"
		intent.decision_tag = "player_heavy"

	if InputMap.has_action("cast_spell") and Input.is_action_just_pressed("cast_spell"):
		intent.spell_id = _get_selected_spell_id()
		intent.decision_tag = "player_cast"
	if InputMap.has_action("dodge") and Input.is_action_just_pressed("dodge"):
		intent.dodge_requested = true
		intent.dodge_direction = (
			intent.movement_direction
			if intent.movement_direction.length_squared() > 0.001
			else -controlled_actor.global_transform.basis.z
		)
		intent.decision_tag = "player_dodge"
	if InputMap.has_action("guard") and Input.is_action_pressed("guard"):
		intent.guard_requested = true
	if intent.decision_tag == "idle" and intent.movement_direction.length_squared() > 0.001:
		intent.decision_tag = "player_move"


func _get_valid_lock_on_target() -> Node3D:
	if controlled_actor == null or not is_instance_valid(controlled_actor):
		return null
	var target_value: Variant = controlled_actor.get("lock_on_target")
	if not is_instance_valid(target_value):
		return null
	return target_value as Node3D if target_value is Node3D else null


func _get_selected_spell_id() -> String:
	if (
		ability_caster == null
		or not is_instance_valid(ability_caster)
		or not ability_caster.has_method("get_current_ability")
	):
		ability_caster = null
		return "selected_spell"
	var ability_value: Variant = ability_caster.call("get_current_ability")
	if ability_value is AbilityDefinition:
		return (ability_value as AbilityDefinition).get_spell_id()
	return "selected_spell"


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["execution_mode"] = "observe_only"
	data["direct_player_controls_preserved"] = true
	return data
