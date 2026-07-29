extends Node
class_name PlayerElementalAuthorityController

signal authority_changed(profile: ElementalAuthorityProfile)
signal matching_element_negated(element: String, source_name: String)
signal authority_cast_started(ability_id: String, weave_id: String)
signal authority_cast_finished(ability_id: String)
signal owned_field_registered(field: Node3D, field_kind: String)
signal owned_fields_flared(count: int)
signal thrust_wake_spawned(segment_count: int)

const GameplayEffectAccessScript = preload("res://scripts/effects/gameplay_effect_access.gd")
const FireFieldScene: PackedScene = preload("res://scenes/actions/fire_field.tscn")
const FireFieldPayload: DamagePayload = preload("res://data/damage_payloads/fire_field_payload.tres")

const FIREBOLT_ID: String = "firebolt"
const FIRE_FIELD_ID: String = "fire_field"
const RUVIA_LIGHT_1: String = "ruvia_halberd_l1"
const RUVIA_LIGHT_2: String = "ruvia_halberd_l2"
const RUVIA_HAFT_CHECK: String = "ruvia_halberd_l3"
const RUVIA_EMBER_WHEEL: String = "ruvia_halberd_l5"
const RUVIA_SCORCHING_THRUST: String = "ruvia_halberd_h1"

@export var profile: ElementalAuthorityProfile
@export var show_debug_prints: bool = false

var actor: CharacterBody3D
var avatar_manager: PlayerAvatarManager
var weapon_controller: WeaponController
var ability_caster: Node
var action_state: PlayerActionState
var status_receiver: Node

var owned_fields: Array[Node] = []
var last_cast_instance: Node
var last_owned_field: Node3D
var last_cast_ability_id: String = "none"
var last_weave_id: String = "none"
var last_cast_origin: Vector3 = Vector3.ZERO
var last_cast_direction: Vector3 = Vector3.FORWARD
var last_modified_mana_cost: int = 0
var negated_hit_count: int = 0

var current_cast_ability_id: String = ""
var current_cast_kind: String = ""
var current_cast_duration: float = 0.0
var current_cast_remaining: float = 0.0

var weave_window_remaining: float = 0.0
var weave_window_attack_id: String = ""
var observed_attack_id: String = ""
var attack_active_triggered: bool = false
var thrust_wake_armed: bool = false
var thrust_wake_last_position: Vector3 = Vector3.ZERO
var thrust_wake_segments: int = 0
var total_wake_segments: int = 0
var total_field_flares: int = 0


func _ready() -> void:
	process_priority = 24
	actor = get_parent() as CharacterBody3D
	_resolve_bindings()
	_connect_weapon_signals()
	add_to_group("player_elemental_authority")
	add_to_group("debuggable")
	if profile != null:
		set_authority_profile(profile)


func _exit_tree() -> void:
	_disconnect_weapon_signals()


func _process(delta: float) -> void:
	var safe_delta: float = maxf(delta, 0.0)
	weave_window_remaining = maxf(weave_window_remaining - safe_delta, 0.0)
	_update_authority_cast(safe_delta)
	_cleanup_owned_fields()
	_process_weapon_field_weaves()


func _resolve_bindings() -> void:
	if actor == null:
		actor = get_parent() as CharacterBody3D
	if actor == null:
		return
	avatar_manager = actor.get_node_or_null("AvatarManager") as PlayerAvatarManager
	weapon_controller = actor.get_node_or_null("WeaponController") as WeaponController
	ability_caster = actor.get_node_or_null("AbilityCaster")
	action_state = actor.get_node_or_null("PlayerActionState") as PlayerActionState
	status_receiver = actor.get_node_or_null("StatusReceiver")


func _connect_weapon_signals() -> void:
	if weapon_controller == null:
		return
	if not weapon_controller.attack_started.is_connected(_on_attack_started):
		weapon_controller.attack_started.connect(_on_attack_started)
	if not weapon_controller.attack_finished.is_connected(_on_attack_finished):
		weapon_controller.attack_finished.connect(_on_attack_finished)


func _disconnect_weapon_signals() -> void:
	if weapon_controller == null:
		return
	if weapon_controller.attack_started.is_connected(_on_attack_started):
		weapon_controller.attack_started.disconnect(_on_attack_started)
	if weapon_controller.attack_finished.is_connected(_on_attack_finished):
		weapon_controller.attack_finished.disconnect(_on_attack_finished)


func set_authority_profile(new_profile: ElementalAuthorityProfile) -> void:
	profile = new_profile
	_cancel_authority_cast()
	thrust_wake_armed = false
	attack_active_triggered = false
	if status_receiver != null and status_receiver.has_method("prune_blocked_statuses"):
		status_receiver.call("prune_blocked_statuses")
	authority_changed.emit(profile)


func get_authority_profile() -> ElementalAuthorityProfile:
	return profile


func is_authority_active() -> bool:
	return profile != null and profile.validate_profile().is_empty()


func has_authority_for_element(candidate_element: String) -> bool:
	return is_authority_active() and profile.matches_element(candidate_element)


func is_immune_to_element(candidate_element: String) -> bool:
	return (
		has_authority_for_element(candidate_element)
		and profile.incoming_damage_multiplier <= 0.001
	)


func can_traverse_hazard(candidate_element: String) -> bool:
	return (
		has_authority_for_element(candidate_element)
		and profile.matching_hazards_are_traversable
	)


func can_receive_status(status_name: String, source_element: String = "") -> bool:
	if not is_authority_active():
		return true
	if profile.blocks_status(status_name):
		return false
	if source_element != "" and profile.matches_element(source_element):
		return not profile.matching_hazards_are_traversable
	return true


func resolve_incoming_payload(payload: DamagePayload) -> Dictionary:
	if payload == null:
		return {
			"immune": false,
			"payload": null,
			"reason": "empty_payload",
		}
	if not has_authority_for_element(payload.element):
		return {
			"immune": false,
			"payload": payload,
			"reason": "unmatched_element",
		}

	var resolved: DamagePayload = payload.duplicate(true) as DamagePayload
	if resolved == null:
		resolved = payload
	resolved.amount = maxi(
		roundi(float(payload.amount) * maxf(profile.incoming_damage_multiplier, 0.0)),
		0
	)
	resolved.stance_damage = maxi(
		roundi(float(payload.stance_damage) * maxf(profile.incoming_stance_multiplier, 0.0)),
		0
	)
	var immune: bool = resolved.amount <= 0 and resolved.stance_damage <= 0
	if immune:
		negated_hit_count += 1
		matching_element_negated.emit(payload.element, payload.source_name)
	return {
		"immune": immune,
		"payload": resolved,
		"reason": "matching_element_authority",
		"authority_id": profile.authority_id,
		"damage_multiplier": profile.incoming_damage_multiplier,
		"stance_multiplier": profile.incoming_stance_multiplier,
	}


func modify_spell_payload(
	ability: AbilityDefinition,
	base_payload: DamagePayload
) -> DamagePayload:
	if base_payload == null:
		return null
	var resolved: DamagePayload = base_payload.duplicate(true) as DamagePayload
	if resolved == null:
		return base_payload
	if ability == null or not has_authority_for_element(ability.element):
		return resolved
	resolved.amount = maxi(
		roundi(float(resolved.amount) * profile.spell_damage_multiplier),
		0
	)
	resolved.stance_damage = maxi(
		roundi(float(resolved.stance_damage) * profile.spell_stance_multiplier),
		0
	)
	resolved.status_duration *= profile.status_duration_multiplier
	resolved.status_strength *= profile.status_strength_multiplier
	_append_payload_tag(resolved, "elemental_authority")
	_append_payload_tag(resolved, profile.authority_id)
	_append_payload_tag(resolved, "authority_owner:" + _get_active_avatar_id())
	return resolved


func get_modified_mana_cost(ability: AbilityDefinition) -> int:
	if ability == null:
		return 0
	var base_cost: int = GameplayEffectAccessScript.modify_int(
		"mana_cost",
		ability.mana_cost,
		"ceil"
	)
	if not has_authority_for_element(ability.element):
		return base_cost
	return profile.get_modified_mana_cost(base_cost)


func can_handle_ability(ability: AbilityDefinition) -> bool:
	if ability == null or not has_authority_for_element(ability.element):
		return false
	return ability.get_spell_id() in [FIREBOLT_ID, FIRE_FIELD_ID]


func begin_ability_channel(player: Node3D, ability: AbilityDefinition) -> bool:
	if player == null or ability == null or not can_handle_ability(ability):
		return false
	if actor == null or player != actor:
		return false
	if action_state != null and not action_state.can_cast():
		return false

	var weave_id: String = _resolve_weave_id(ability)
	var mana_cost: int = get_modified_mana_cost(ability)
	if not _pay_authority_cost(ability, mana_cost):
		_show_message("Not enough resources for " + ability.display_name + ".")
		return false

	var cast_origin: Vector3 = get_authority_cast_origin(ability)
	var cast_direction: Vector3 = get_authority_cast_direction(cast_origin)
	var cast_lock: float = profile.standard_cast_lock_duration
	if weave_id != "none":
		cast_lock = profile.quick_weave_lock_duration

	if weapon_controller != null and weapon_controller.current_attack != null:
		weapon_controller.cancel_current_attack("elemental_authority_weave")
	if action_state != null:
		action_state.begin_cast(cast_lock)

	var did_cast: bool = false
	if ability.get_spell_id() == FIRE_FIELD_ID:
		did_cast = _cast_fire_field(ability, cast_direction, weave_id)
	else:
		did_cast = _cast_authority_projectile(ability, cast_origin, cast_direction)

	if not did_cast:
		_refund_authority_cost(mana_cost)
		if action_state != null:
			action_state.is_casting = false
			action_state.cast_lock_timer = 0.0
		return false

	last_cast_ability_id = ability.get_spell_id()
	last_weave_id = weave_id
	last_cast_origin = cast_origin
	last_cast_direction = cast_direction
	last_modified_mana_cost = mana_cost
	_begin_authority_cast_presentation(ability.get_spell_id(), cast_lock, weave_id)
	authority_cast_started.emit(ability.get_spell_id(), weave_id)
	if show_debug_prints:
		print(
			"Elemental Authority cast: ",
			ability.display_name,
			" weave=",
			weave_id,
			" mana=",
			mana_cost
		)
	return true


func get_authority_cast_origin(ability: AbilityDefinition) -> Vector3:
	var rig: Node3D = _get_runtime_weapon_rig()
	if rig != null and rig.has_method("get_spell_cast_origin"):
		var origin_value: Variant = rig.call(
			"get_spell_cast_origin",
			ability.get_spell_id() if ability != null else ""
		)
		if origin_value is Vector3:
			return origin_value as Vector3
	if actor != null:
		var weapon_anchor: Node3D = actor.get_node_or_null(
			"WeaponController/HandAnchor/WeaponVisualPivot/WeaponModelRoot"
		) as Node3D
		if weapon_anchor != null:
			return weapon_anchor.global_position
		return actor.global_position + Vector3.UP * 1.05
	return Vector3.ZERO


func get_authority_cast_direction(cast_origin: Vector3) -> Vector3:
	if weapon_controller != null and weapon_controller.current_attack != null:
		var attack_direction: Vector3 = weapon_controller.get_attack_forward()
		if attack_direction.length_squared() > 0.001:
			return attack_direction.normalized()
	if actor != null and actor.has_method("get_lock_on_cast_direction"):
		var lock_direction: Vector3 = actor.call(
			"get_lock_on_cast_direction",
			cast_origin
		) as Vector3
		if lock_direction.length_squared() > 0.001:
			return lock_direction.normalized()
	if actor != null:
		var actor_forward: Vector3 = -actor.global_transform.basis.z
		if actor_forward.length_squared() > 0.001:
			return actor_forward.normalized()
	return Vector3.FORWARD


func get_cast_pose_sample() -> Dictionary:
	if current_cast_remaining <= 0.0 or current_cast_ability_id == "":
		return {}
	var progress: float = get_cast_progress()
	var phase: String = "startup"
	var phase_weight: float = smoothstep(0.0, 1.0, clampf(progress / 0.42, 0.0, 1.0))
	if progress >= 0.42 and progress < 0.68:
		phase = "active"
		phase_weight = smoothstep(0.0, 1.0, (progress - 0.42) / 0.26)
	elif progress >= 0.68:
		phase = "recovery"
		phase_weight = smoothstep(0.0, 1.0, (progress - 0.68) / 0.32)

	var field_cast: bool = current_cast_ability_id == FIRE_FIELD_ID
	var windup_body: Vector3 = Vector3(7.0, -12.0, 2.0) if field_cast else Vector3(-3.0, -18.0, 2.0)
	var strike_body: Vector3 = Vector3(-13.0, 8.0, -2.0) if field_cast else Vector3(-12.0, 12.0, -2.0)
	var windup_head: Vector3 = Vector3(5.0, 4.0, 0.0) if field_cast else Vector3(0.0, 6.0, 0.0)
	var strike_head: Vector3 = Vector3(-6.0, -3.0, 0.0) if field_cast else Vector3(-4.0, -4.0, 0.0)
	var windup_left_arm: Vector3 = Vector3(-24.0, 8.0, -92.0) if field_cast else Vector3(-44.0, 10.0, -48.0)
	var strike_left_arm: Vector3 = Vector3(-62.0, -6.0, 18.0) if field_cast else Vector3(-58.0, -8.0, -26.0)
	var windup_right_arm: Vector3 = Vector3(12.0, -10.0, 132.0) if field_cast else Vector3(-34.0, -8.0, 32.0)
	var strike_right_arm: Vector3 = Vector3(-78.0, 8.0, 12.0) if field_cast else Vector3(-108.0, 2.0, -12.0)
	var windup_hand_position: Vector3 = Vector3(-0.02, 0.12, 0.03) if field_cast else Vector3(0.0, 0.02, 0.08)
	var strike_hand_position: Vector3 = Vector3(0.0, -0.06, -0.16) if field_cast else Vector3(0.0, 0.02, -0.2)
	var windup_weapon_rotation: Vector3 = Vector3(-78.0, -8.0, 0.0) if field_cast else Vector3(0.0, -18.0, 82.0)
	var strike_weapon_rotation: Vector3 = Vector3(72.0, 8.0, 0.0) if field_cast else Vector3(0.0, 2.0, 90.0)
	var windup_weapon_offset: Vector3 = Vector3(0.0, 0.06, 0.08) if field_cast else Vector3(0.0, 0.0, 0.2)
	var strike_weapon_offset: Vector3 = Vector3(0.0, -0.08, -0.14) if field_cast else Vector3(0.0, 0.0, -0.38)
	var windup_grip: Vector3 = Vector3(0.12, 0.0, -0.94) if field_cast else Vector3(0.12, 0.0, -0.82)
	var strike_grip: Vector3 = Vector3(0.12, 0.0, -0.76) if field_cast else Vector3(0.12, 0.0, -0.92)

	return {
		"profile_id": "authority_cast_" + current_cast_ability_id,
		"authority_cast_id": current_cast_ability_id,
		"phase": phase,
		"phase_weight": phase_weight,
		"body": _sample_cast_rotation(windup_body, strike_body, phase, phase_weight),
		"head": _sample_cast_rotation(windup_head, strike_head, phase, phase_weight),
		"left_arm": _sample_cast_rotation(windup_left_arm, strike_left_arm, phase, phase_weight),
		"right_arm": _sample_cast_rotation(windup_right_arm, strike_right_arm, phase, phase_weight),
		"right_hand_position": _sample_cast_vector(
			Vector3.ZERO,
			windup_hand_position,
			strike_hand_position,
			Vector3.ZERO,
			phase,
			phase_weight
		),
		"right_hand_rotation": _sample_cast_rotation(
			Vector3(8.0, -4.0, -12.0),
			Vector3(-10.0, 6.0, 14.0),
			phase,
			phase_weight
		),
		"weapon_rotation_degrees": _sample_cast_vector(
			Vector3.ZERO,
			windup_weapon_rotation,
			strike_weapon_rotation,
			Vector3.ZERO,
			phase,
			phase_weight
		),
		"weapon_offset": _sample_cast_vector(
			Vector3.ZERO,
			windup_weapon_offset,
			strike_weapon_offset,
			Vector3.ZERO,
			phase,
			phase_weight
		),
		"weapon_rotation_share": 1.0,
		"weapon_offset_share": 1.0,
		"two_handed": true,
		"support_grip_position": _sample_cast_vector(
			Vector3(0.12, 0.0, -0.66),
			windup_grip,
			strike_grip,
			Vector3(0.12, 0.0, -0.66),
			phase,
			phase_weight
		),
		"support_grip_rotation": Vector3.ZERO,
		"support_hand_weight": 1.0 if phase != "recovery" else lerpf(1.0, 0.68, phase_weight),
	}


func get_cast_progress() -> float:
	if current_cast_duration <= 0.0:
		return 1.0
	return clampf(
		1.0 - current_cast_remaining / maxf(current_cast_duration, 0.001),
		0.0,
		1.0
	)


func register_owned_field(field: Node3D, field_kind: String = "field") -> void:
	if field == null or owned_fields.has(field):
		return
	owned_fields.append(field)
	last_owned_field = field
	owned_field_registered.emit(field, field_kind)


func get_owned_fields() -> Array[Node]:
	_cleanup_owned_fields()
	return owned_fields.duplicate()


func flare_owned_fields_near(center: Vector3, maximum_distance: float = 5.5) -> int:
	if not is_authority_active():
		return 0
	var flared: int = 0
	for field: Node in get_owned_fields():
		if not field is Node3D:
			continue
		var field_node: Node3D = field as Node3D
		if field_node.global_position.distance_to(center) > maximum_distance:
			continue
		if field.has_method("authority_flare"):
			field.call(
				"authority_flare",
				profile.owned_field_flare_radius_bonus,
				profile.owned_field_flare_lifetime_bonus,
				profile.owned_field_flare_strength_bonus
			)
			flared += 1
	if flared > 0:
		total_field_flares += flared
		owned_fields_flared.emit(flared)
	return flared


func is_inside_owned_field(world_position: Vector3, margin: float = 0.0) -> bool:
	for field: Node in get_owned_fields():
		if field.has_method("contains_world_position"):
			if bool(field.call("contains_world_position", world_position, margin)):
				return true
	return false


func _cast_authority_projectile(
	ability: AbilityDefinition,
	cast_origin: Vector3,
	cast_direction: Vector3
) -> bool:
	if ability == null or ability.ability_scene == null:
		return false
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return false
	var ability_instance: Node = ability.ability_scene.instantiate()
	var base_payload: Resource = ability.get_action_payload()
	if base_payload is DamagePayload:
		var authority_payload: DamagePayload = modify_spell_payload(
			ability,
			base_payload as DamagePayload
		)
		if ability_instance.has_method("set_payload"):
			ability_instance.call("set_payload", authority_payload)
	if ability_instance.has_method("set_source_actor"):
		ability_instance.call("set_source_actor", actor)
	scene_root.add_child(ability_instance)
	if ability_instance is Node3D:
		(ability_instance as Node3D).global_position = cast_origin
	if "speed" in ability_instance:
		ability_instance.set(
			"speed",
			float(ability_instance.get("speed")) * profile.projectile_speed_multiplier
		)
	if ability_instance.has_method("launch"):
		ability_instance.call("launch", cast_direction)
	last_cast_instance = ability_instance
	return true


func _cast_fire_field(
	ability: AbilityDefinition,
	cast_direction: Vector3,
	weave_id: String
) -> bool:
	var placement_distance: float = 2.65
	var field_kind: String = "authority_field"
	if weave_id == "haft_field_plant":
		placement_distance = 0.85
		field_kind = "haft_field"
	var flat_direction: Vector3 = cast_direction
	flat_direction.y = 0.0
	if flat_direction.length_squared() <= 0.001:
		flat_direction = -actor.global_transform.basis.z
	flat_direction = flat_direction.normalized()
	var target_position: Vector3 = (
		actor.global_position
		+ flat_direction * placement_distance
		+ Vector3.UP * 0.06
	)
	var base_payload: Resource = ability.get_action_payload()
	var authority_payload: DamagePayload = null
	if base_payload is DamagePayload:
		authority_payload = modify_spell_payload(ability, base_payload as DamagePayload)
	var field: Node3D = _spawn_fire_field_at(
		target_position,
		authority_payload,
		field_kind,
		true,
		0.0,
		0.0
	)
	last_cast_instance = field
	return field != null


func _spawn_fire_field_at(
	world_position: Vector3,
	field_payload: DamagePayload,
	field_kind: String,
	apply_authority_bonuses: bool,
	radius_override: float,
	lifetime_override: float
) -> Node3D:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return null
	var field_instance: Node = FireFieldScene.instantiate()
	if not field_instance is Node3D:
		field_instance.queue_free()
		return null
	if radius_override > 0.0:
		field_instance.set("radius", radius_override)
	if lifetime_override > 0.0:
		field_instance.set("lifetime", lifetime_override)
	if field_payload != null and field_instance.has_method("set_payload"):
		field_instance.call("set_payload", field_payload)
	if field_instance.has_method("set_source_actor"):
		field_instance.call("set_source_actor", actor)
	scene_root.add_child(field_instance)
	var field_node: Node3D = field_instance as Node3D
	field_node.global_position = world_position
	if field_instance.has_method("set_authority_context"):
		field_instance.call(
			"set_authority_context",
			actor,
			profile,
			apply_authority_bonuses,
			field_kind
		)
	if field_instance.has_method("ignite_at"):
		field_instance.call("ignite_at", world_position)
	else:
		if field_instance.has_method("configure_area"):
			field_instance.call("configure_area")
		if field_instance.has_method("configure_visual"):
			field_instance.call("configure_visual")
	register_owned_field(field_node, field_kind)
	return field_node


func _spawn_thrust_wake_field(world_position: Vector3) -> Node3D:
	if not is_authority_active():
		return null
	var wake_payload: DamagePayload = modify_spell_payload(
		_preload_fire_field_ability(),
		FireFieldPayload
	)
	if wake_payload != null:
		wake_payload.amount = maxi(1, roundi(float(wake_payload.amount) * 0.65))
		wake_payload.status_duration = maxf(wake_payload.status_duration, 0.9)
		wake_payload.status_strength *= 0.75
		_append_payload_tag(wake_payload, "scorching_thrust_wake")
	return _spawn_fire_field_at(
		world_position + Vector3.UP * 0.05,
		wake_payload,
		"scorching_thrust_wake",
		false,
		profile.thrust_wake_radius,
		profile.thrust_wake_lifetime
	)


func _preload_fire_field_ability() -> AbilityDefinition:
	return load("res://data/abilities/fire_field_ability.tres") as AbilityDefinition


func _pay_authority_cost(ability: AbilityDefinition, required_mana: int) -> bool:
	var required_stamina: int = GameplayEffectAccessScript.modify_int(
		"stamina_cost",
		ability.stamina_cost,
		"ceil"
	)
	var required_focus: int = GameplayEffectAccessScript.modify_int(
		"focus_cost",
		ability.focus_cost,
		"ceil"
	)
	if GameState.get_stat("mana") < required_mana:
		return false
	if GameState.get_stat("stamina") < required_stamina:
		return false
	if GameState.get_stat("focus") < required_focus:
		return false
	if required_mana > 0:
		GameState.spend_mana(required_mana)
	if required_stamina > 0:
		GameState.spend_stamina(required_stamina)
	if required_focus > 0:
		GameState.set_stat("focus", GameState.get_stat("focus") - required_focus)
	return true


func _refund_authority_cost(mana_cost: int) -> void:
	if mana_cost <= 0:
		return
	GameState.set_stat(
		"mana",
		mini(
			GameState.get_stat("mana") + mana_cost,
			GameState.get_stat("max_mana")
		)
	)


func _resolve_weave_id(ability: AbilityDefinition) -> String:
	var attack_id: String = ""
	if weapon_controller != null and weapon_controller.current_attack != null:
		attack_id = weapon_controller.current_attack.attack_id
	elif weave_window_remaining > 0.0:
		attack_id = weave_window_attack_id
	if ability.get_spell_id() == FIREBOLT_ID and attack_id in [RUVIA_LIGHT_1, RUVIA_LIGHT_2]:
		return "blade_tip_firebolt"
	if ability.get_spell_id() == FIRE_FIELD_ID and attack_id == RUVIA_HAFT_CHECK:
		return "haft_field_plant"
	return "none"


func _on_attack_started(attack: WeaponAttackDefinition) -> void:
	if attack == null:
		return
	observed_attack_id = attack.attack_id
	attack_active_triggered = false
	thrust_wake_armed = false
	thrust_wake_segments = 0
	if (
		is_authority_active()
		and attack.attack_id == RUVIA_SCORCHING_THRUST
		and actor != null
		and is_inside_owned_field(actor.global_position, 0.45)
	):
		thrust_wake_armed = true
		thrust_wake_last_position = actor.global_position


func _on_attack_finished(attack_id: String) -> void:
	if is_authority_active():
		weave_window_attack_id = attack_id
		weave_window_remaining = profile.weave_window_seconds
	observed_attack_id = ""
	attack_active_triggered = false
	thrust_wake_armed = false
	thrust_wake_segments = 0


func _process_weapon_field_weaves() -> void:
	if not is_authority_active() or weapon_controller == null:
		return
	var attack: WeaponAttackDefinition = weapon_controller.current_attack
	if attack == null:
		return
	if observed_attack_id != attack.attack_id:
		_on_attack_started(attack)

	if weapon_controller.current_phase == "active" and not attack_active_triggered:
		attack_active_triggered = true
		if attack.attack_id == RUVIA_EMBER_WHEEL and actor != null:
			flare_owned_fields_near(actor.global_position, 5.75)

	if (
		thrust_wake_armed
		and attack.attack_id == RUVIA_SCORCHING_THRUST
		and weapon_controller.current_phase in ["active", "recovery"]
		and actor != null
	):
		_update_thrust_wake(actor.global_position)


func _update_thrust_wake(current_position: Vector3) -> void:
	if profile == null or thrust_wake_segments >= profile.thrust_wake_max_segments:
		return
	var flat_offset: Vector3 = current_position - thrust_wake_last_position
	flat_offset.y = 0.0
	var distance: float = flat_offset.length()
	if distance < profile.thrust_wake_spacing:
		return
	var direction: Vector3 = flat_offset.normalized()
	while (
		distance >= profile.thrust_wake_spacing
		and thrust_wake_segments < profile.thrust_wake_max_segments
	):
		thrust_wake_last_position += direction * profile.thrust_wake_spacing
		_spawn_thrust_wake_field(thrust_wake_last_position)
		thrust_wake_segments += 1
		total_wake_segments += 1
		distance -= profile.thrust_wake_spacing
	thrust_wake_spawned.emit(thrust_wake_segments)


func _begin_authority_cast_presentation(
	ability_id: String,
	duration: float,
	_weave_id: String
) -> void:
	current_cast_ability_id = ability_id
	current_cast_kind = "field" if ability_id == FIRE_FIELD_ID else "projectile"
	current_cast_duration = maxf(duration, 0.02)
	current_cast_remaining = current_cast_duration
	var rig: Node3D = _get_runtime_weapon_rig()
	if rig != null and rig.has_method("begin_authority_cast"):
		rig.call("begin_authority_cast", ability_id, current_cast_duration)


func _update_authority_cast(delta: float) -> void:
	if current_cast_remaining <= 0.0:
		return
	current_cast_remaining = maxf(current_cast_remaining - delta, 0.0)
	var rig: Node3D = _get_runtime_weapon_rig()
	if rig != null and rig.has_method("update_authority_cast"):
		rig.call(
			"update_authority_cast",
			current_cast_ability_id,
			get_cast_progress()
		)
	if current_cast_remaining <= 0.0:
		var finished_id: String = current_cast_ability_id
		_cancel_authority_cast()
		authority_cast_finished.emit(finished_id)


func _cancel_authority_cast() -> void:
	var rig: Node3D = _get_runtime_weapon_rig()
	if rig != null and rig.has_method("end_authority_cast"):
		rig.call("end_authority_cast")
	current_cast_ability_id = ""
	current_cast_kind = ""
	current_cast_duration = 0.0
	current_cast_remaining = 0.0


func _get_runtime_weapon_rig() -> Node3D:
	if weapon_controller == null:
		return null
	return weapon_controller.runtime_weapon_rig


func _cleanup_owned_fields() -> void:
	var valid_fields: Array[Node] = []
	for field: Node in owned_fields:
		if field != null and is_instance_valid(field) and not field.is_queued_for_deletion():
			valid_fields.append(field)
	owned_fields = valid_fields
	if last_owned_field != null and not is_instance_valid(last_owned_field):
		last_owned_field = null


func _append_payload_tag(payload: DamagePayload, tag: String) -> void:
	if payload == null or tag == "" or payload.tags.has(tag):
		return
	payload.tags.append(tag)


func _get_active_avatar_id() -> String:
	if avatar_manager != null:
		return avatar_manager.get_active_avatar_id()
	if actor != null:
		return str(actor.get_meta("active_avatar_id", "grace"))
	return "grace"


func _sample_cast_rotation(
	windup_degrees: Vector3,
	strike_degrees: Vector3,
	phase: String,
	weight: float
) -> Vector3:
	return _degrees_to_radians(
		_sample_cast_vector(
			Vector3.ZERO,
			windup_degrees,
			strike_degrees,
			Vector3.ZERO,
			phase,
			weight
		)
	)


func _sample_cast_vector(
	neutral: Vector3,
	windup: Vector3,
	strike: Vector3,
	recovery: Vector3,
	phase: String,
	weight: float
) -> Vector3:
	var clamped_weight: float = clampf(weight, 0.0, 1.0)
	match phase:
		"startup":
			return neutral.lerp(windup, clamped_weight)
		"active":
			return windup.lerp(strike, clamped_weight)
		"recovery":
			return strike.lerp(recovery, clamped_weight)
		_:
			return neutral


func _degrees_to_radians(degrees: Vector3) -> Vector3:
	return Vector3(
		deg_to_rad(degrees.x),
		deg_to_rad(degrees.y),
		deg_to_rad(degrees.z)
	)


func _show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	elif show_debug_prints:
		print(text)


func get_debug_data() -> Dictionary:
	return {
		"active": is_authority_active(),
		"authority_id": profile.authority_id if profile != null else "none",
		"display_name": profile.display_name if profile != null else "None",
		"element": profile.element if profile != null else "none",
		"hazard_traversal": profile.matching_hazards_are_traversable if profile != null else false,
		"incoming_damage_multiplier": profile.incoming_damage_multiplier if profile != null else 1.0,
		"spell_damage_multiplier": profile.spell_damage_multiplier if profile != null else 1.0,
		"spell_stance_multiplier": profile.spell_stance_multiplier if profile != null else 1.0,
		"status_duration_multiplier": profile.status_duration_multiplier if profile != null else 1.0,
		"status_strength_multiplier": profile.status_strength_multiplier if profile != null else 1.0,
		"owned_fields": get_owned_fields().size(),
		"last_cast_ability": last_cast_ability_id,
		"last_weave": last_weave_id,
		"last_cast_origin": last_cast_origin,
		"last_cast_direction": last_cast_direction,
		"last_mana_cost": last_modified_mana_cost,
		"cast_active": current_cast_remaining > 0.0,
		"cast_progress": snappedf(get_cast_progress(), 0.01) if current_cast_remaining > 0.0 else 0.0,
		"cast_kind": current_cast_kind if current_cast_kind != "" else "none",
		"weave_window": snappedf(weave_window_remaining, 0.01),
		"weave_attack": weave_window_attack_id if weave_window_remaining > 0.0 else "none",
		"thrust_wake_armed": thrust_wake_armed,
		"thrust_wake_segments": thrust_wake_segments,
		"total_wake_segments": total_wake_segments,
		"total_field_flares": total_field_flares,
		"negated_hits": negated_hit_count,
	}
