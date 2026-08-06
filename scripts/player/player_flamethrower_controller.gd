extends Node3D
class_name PlayerFlamethrowerController

const GameplayEffectAccessScript = preload(
	"res://scripts/effects/gameplay_effect_access.gd"
)

signal channel_started
signal channel_ended(reason: String)
signal mana_drained(amount: int, current_mana: int)
signal target_heated(target: Node, energy_j: float)
signal combat_tick_resolved(target: Node, result: Dictionary)

@export_group("Spell Channel")
@export var handled_spell_id: String = "flamethrower"
@export var channel_action: StringName = &"cast_spell"
@export_range(0.0, 20.0, 0.1) var mana_per_second: float = 3.0

@export_group("Flame Geometry")
@export_range(0.5, 20.0, 0.1) var maximum_range: float = 6.5
@export_range(2, 12, 1) var cone_sample_count: int = 6
@export_range(0.05, 2.0, 0.05) var start_radius: float = 0.24
@export_range(0.1, 4.0, 0.05) var end_radius: float = 1.35
@export_flags_3d_physics var collision_mask: int = 1

@export_group("Continuous Heat")
@export_range(1.0, 5000.0, 10.0) var heat_energy_j_per_second: float = 900.0
@export_range(0.1, 1.0, 0.05) var distant_heat_multiplier: float = 0.62

@export_group("Combat Ticks")
@export_range(0.05, 2.0, 0.05) var combat_tick_seconds: float = 0.25
@export_range(0, 20, 1) var combat_damage: int = 1
@export_range(0, 20, 1) var combat_stance_damage: int = 1
@export_range(0.0, 10.0, 0.1) var burning_seconds: float = 0.8
@export_range(0.0, 5.0, 0.1) var burning_strength: float = 0.45

var player: CharacterBody3D
var action_state: PlayerActionState
var ability_caster: Node
var active_ability: AbilityDefinition
var channel_requested: bool = false
var mana_fractional_cost: float = 0.0
var combat_tick_timer: float = 0.0
var visual_age: float = 0.0
var current_stream_range: float = 0.0
var current_targets: Array[Node] = []
var last_end_reason: String = "never_started"
var total_channel_seconds: float = 0.0
var total_mana_spent: int = 0
var total_heat_energy_j: float = 0.0
var total_combat_ticks: int = 0

var stream_root: Node3D
var outer_flame: MeshInstance3D
var inner_flame: MeshInstance3D
var stream_light: OmniLight3D
var collision_exclusions: Array[RID] = []


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	if player != null:
		action_state = player.get_node_or_null(
			"PlayerActionState"
		) as PlayerActionState
		ability_caster = player.get_node_or_null("AbilityCaster")
		_collect_collision_rids(player, collision_exclusions)
	_create_stream_visuals()
	add_to_group("player_ability_channels")
	add_to_group("flamethrower_controllers")
	add_to_group("debuggable")
	add_to_group("lab_resettable")


func _process(delta: float) -> void:
	if not channel_requested:
		return
	advance_channel(
		delta,
		Input.is_action_pressed(channel_action)
	)


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
	if channel_requested:
		return true
	if GameState.get_stat("mana") <= 0:
		_show_message("Flamethrower needs Mana to begin.")
		return false
	if action_state != null and not action_state.begin_cast_channel():
		return false

	active_ability = ability
	channel_requested = true
	combat_tick_timer = 0.0
	last_end_reason = "active"
	current_stream_range = maximum_range
	_set_stream_visible(true)
	channel_started.emit()
	_show_message(
		"Flamethrower: hold Cast to sustain heat. Mana drains continuously."
	)
	return true


func advance_channel(delta: float, cast_held: bool = true) -> bool:
	if not channel_requested:
		return false
	if not cast_held:
		cancel_ability_channel("released")
		return false
	if _player_state_interrupts_channel():
		cancel_ability_channel("interrupted")
		return false
	if not is_flamethrower_equipped():
		cancel_ability_channel("spell_changed")
		return false
	if GameState.get_stat("mana") <= 0:
		cancel_ability_channel("mana_empty")
		return false

	var safe_delta: float = maxf(delta, 0.0)
	visual_age += safe_delta
	total_channel_seconds += safe_delta
	var origin: Vector3 = _get_cast_origin()
	var direction: Vector3 = _get_cast_direction(origin)
	current_stream_range = _resolve_stream_range(origin, direction)
	current_targets = _collect_stream_targets(
		origin,
		direction,
		current_stream_range
	)
	_update_stream_visual(origin, direction, current_stream_range)
	_apply_continuous_heat(origin, current_targets, safe_delta)

	combat_tick_timer -= safe_delta
	if combat_tick_timer <= 0.0:
		combat_tick_timer += maxf(combat_tick_seconds, 0.05)
		_apply_combat_tick(current_targets)

	if not _consume_channel_mana(safe_delta):
		cancel_ability_channel("mana_empty")
		return false
	return true


func cancel_ability_channel(reason: String = "cancelled") -> void:
	var was_active: bool = channel_requested
	channel_requested = false
	active_ability = null
	combat_tick_timer = 0.0
	current_targets.clear()
	current_stream_range = 0.0
	last_end_reason = reason
	_set_stream_visible(false)
	if (
		action_state != null
		and action_state.is_cast_channel_active()
	):
		action_state.end_cast()
	if was_active:
		channel_ended.emit(reason)
		if reason == "mana_empty":
			_show_message("Flamethrower sputters out: Mana depleted.")


func is_flamethrower_equipped() -> bool:
	if ability_caster == null or not is_instance_valid(ability_caster):
		return false
	if not ability_caster.has_method("get_current_ability"):
		return false
	var ability: AbilityDefinition = ability_caster.call(
		"get_current_ability"
	) as AbilityDefinition
	return can_handle_ability(ability)


func _player_state_interrupts_channel() -> bool:
	if player == null or not is_instance_valid(player):
		return true
	if (
		player.has_method("is_focus_spell_menu_open")
		and bool(player.call("is_focus_spell_menu_open"))
	):
		return true
	if action_state == null:
		return false
	return (
		action_state.is_defeated
		or action_state.is_staggered
		or action_state.is_dodging
		or action_state.is_interacting
		or action_state.is_manipulating
		or action_state.is_guarding
		or action_state.is_using_item
		or not action_state.is_cast_channel_active()
	)


func get_effective_mana_rate() -> float:
	return maxf(
		GameplayEffectAccessScript.modify_float(
			"mana_cost",
			mana_per_second
		),
		0.0
	)


func _consume_channel_mana(delta: float) -> bool:
	var rate: float = get_effective_mana_rate()
	if rate <= 0.0:
		return true
	mana_fractional_cost += rate * maxf(delta, 0.0)
	var whole_cost: int = floori(mana_fractional_cost)
	if whole_cost <= 0:
		return true

	var available: int = GameState.get_stat("mana")
	var spent: int = mini(whole_cost, available)
	if spent > 0:
		GameState.spend_mana(spent)
		total_mana_spent += spent
		mana_drained.emit(spent, GameState.get_stat("mana"))
	mana_fractional_cost = fmod(
		mana_fractional_cost - float(spent),
		1.0
	)
	if spent < whole_cost:
		return false
	return GameState.get_stat("mana") > 0


func _get_cast_origin() -> Vector3:
	if (
		ability_caster != null
		and ability_caster.has_method("get_player_cast_origin")
	):
		var origin_value: Variant = ability_caster.call(
			"get_player_cast_origin",
			player
		)
		if origin_value is Vector3:
			return origin_value as Vector3
	return player.global_position + Vector3.UP * 1.1


func _get_cast_direction(origin: Vector3) -> Vector3:
	if (
		ability_caster != null
		and ability_caster.has_method("get_cast_direction")
	):
		var direction_value: Variant = ability_caster.call(
			"get_cast_direction",
			player,
			origin
		)
		if direction_value is Vector3:
			var resolved: Vector3 = direction_value as Vector3
			if resolved.length_squared() > 0.0001:
				return resolved.normalized()
	var fallback: Vector3 = -player.global_transform.basis.z
	return (
		fallback.normalized()
		if fallback.length_squared() > 0.0001
		else Vector3.FORWARD
	)


func _resolve_stream_range(
	origin: Vector3,
	direction: Vector3
) -> float:
	var world: World3D = player.get_world_3d() if player != null else null
	if world == null:
		return maximum_range
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * maximum_range
	)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = collision_exclusions
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	var hit_position: Variant = hit.get("position")
	if hit_position is Vector3:
		return clampf(
			origin.distance_to(hit_position as Vector3) + 0.32,
			0.35,
			maximum_range
		)
	return maximum_range


func _collect_stream_targets(
	origin: Vector3,
	direction: Vector3,
	stream_range: float
) -> Array[Node]:
	var targets: Array[Node] = []
	var target_ids: Dictionary = {}
	var world: World3D = player.get_world_3d() if player != null else null
	if world == null:
		return targets
	var sample_total: int = maxi(cone_sample_count, 2)
	for sample_index: int in range(sample_total):
		var fraction: float = (
			float(sample_index + 1) / float(sample_total)
		)
		var distance: float = stream_range * fraction
		var radius: float = lerpf(start_radius, end_radius, fraction)
		var sphere := SphereShape3D.new()
		sphere.radius = radius
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = sphere
		query.transform = Transform3D(
			Basis.IDENTITY,
			origin + direction * distance
		)
		query.collision_mask = collision_mask
		query.collide_with_areas = true
		query.collide_with_bodies = true
		query.exclude = collision_exclusions
		for result: Dictionary in world.direct_space_state.intersect_shape(
			query,
			32
		):
			var collider_value: Variant = result.get("collider")
			if not collider_value is Node:
				continue
			var target: Node = _resolve_effect_target(
				collider_value as Node
			)
			if target == null or target == player:
				continue
			var target_id: int = target.get_instance_id()
			if target_ids.has(target_id):
				continue
			target_ids[target_id] = true
			targets.append(target)
	return targets


func _resolve_effect_target(start_node: Node) -> Node:
	var current: Node = start_node
	while current != null:
		if current == player:
			return null
		if _is_effect_target(current):
			return current
		if current == get_tree().current_scene:
			break
		current = current.get_parent()
	return null


func _is_effect_target(node: Node) -> bool:
	return (
		node.get_node_or_null("ThermalState") != null
		or node.get_node_or_null("CombustionState") != null
		or node.get_node_or_null("PayloadReceiver") != null
		or node.get_node_or_null("HitReceiver") != null
		or node.has_method("receive_damage_payload")
	)


func _apply_continuous_heat(
	origin: Vector3,
	targets: Array[Node],
	delta: float
) -> void:
	for target: Node in targets:
		var thermal_state: ThermalState = target.get_node_or_null(
			"ThermalState"
		) as ThermalState
		if thermal_state == null:
			continue
		var distance_ratio: float = clampf(
			origin.distance_to(_get_target_position(target))
			/ maxf(current_stream_range, 0.01),
			0.0,
			1.0
		)
		var intensity: float = lerpf(
			1.0,
			distant_heat_multiplier,
			distance_ratio
		)
		var energy_j: float = (
			heat_energy_j_per_second
			* intensity
			* delta
		)
		thermal_state.apply_energy_j(energy_j, "Flamethrower")
		total_heat_energy_j += energy_j
		target_heated.emit(target, energy_j)


func _apply_combat_tick(targets: Array[Node]) -> void:
	if targets.is_empty():
		return
	for target: Node in targets:
		var payload := DamagePayload.new()
		payload.amount = combat_damage
		payload.stance_damage = combat_stance_damage
		payload.element = "fire"
		payload.source_name = "Flamethrower"
		payload.hit_type = "channel"
		payload.status_effect = "burning"
		payload.status_duration = burning_seconds
		payload.status_strength = burning_strength
		payload.tags = [
			"fire",
			"magic",
			"channel",
			"continuous",
			"flamethrower",
			"heat",
		]
		var result: Dictionary = {}
		var payload_receiver: Node = target.get_node_or_null(
			"PayloadReceiver"
		)
		if (
			payload_receiver != null
			and payload_receiver.has_method("receive_payload")
		):
			var result_value: Variant = payload_receiver.call(
				"receive_payload",
				payload
			)
			if result_value is Dictionary:
				result = (result_value as Dictionary).duplicate(true)
		elif target.has_method("receive_damage_payload"):
			var direct_result: Variant = target.call(
				"receive_damage_payload",
				payload
			)
			if direct_result is Dictionary:
				result = (direct_result as Dictionary).duplicate(true)
		elif target.get_node_or_null("HitReceiver") != null:
			var hit_receiver: Node = target.get_node("HitReceiver")
			if hit_receiver.has_method("receive_payload"):
				var hit_result: Variant = hit_receiver.call(
					"receive_payload",
					payload
				)
				if hit_result is Dictionary:
					result = (hit_result as Dictionary).duplicate(true)
		total_combat_ticks += 1
		combat_tick_resolved.emit(target, result)


func _get_target_position(target: Node) -> Vector3:
	if target is Node3D:
		return (target as Node3D).global_position
	var parent: Node = target.get_parent()
	return (
		(parent as Node3D).global_position
		if parent is Node3D
		else player.global_position
	)


func _create_stream_visuals() -> void:
	stream_root = Node3D.new()
	stream_root.name = "FlamethrowerStreamVisual"
	stream_root.visible = false
	add_child(stream_root)

	outer_flame = _create_flame_mesh(
		"OuterFlame",
		maximum_range,
		start_radius,
		end_radius,
		Color(1.0, 0.15, 0.015, 0.34),
		2.8
	)
	stream_root.add_child(outer_flame)
	inner_flame = _create_flame_mesh(
		"InnerFlame",
		maximum_range * 0.78,
		start_radius * 0.55,
		end_radius * 0.48,
		Color(1.0, 0.76, 0.08, 0.58),
		4.2
	)
	stream_root.add_child(inner_flame)

	stream_light = OmniLight3D.new()
	stream_light.name = "FlameLight"
	stream_light.position = Vector3(0.0, 0.0, -1.8)
	stream_light.light_color = Color(1.0, 0.34, 0.06)
	stream_light.light_energy = 2.2
	stream_light.omni_range = 5.0
	stream_light.shadow_enabled = false
	stream_root.add_child(stream_light)


func _create_flame_mesh(
	node_name: String,
	length: float,
	near_radius: float,
	far_radius: float,
	color: Color,
	emission_energy: float
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	var cone := CylinderMesh.new()
	cone.top_radius = near_radius
	cone.bottom_radius = far_radius
	cone.height = length
	cone.radial_segments = 16
	cone.rings = 2
	mesh_instance.mesh = cone
	mesh_instance.position = Vector3(0.0, 0.0, -length * 0.5)
	mesh_instance.rotation.x = PI * 0.5
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = emission_energy
	mesh_instance.material_override = material
	return mesh_instance


func _update_stream_visual(
	origin: Vector3,
	direction: Vector3,
	stream_range: float
) -> void:
	if stream_root == null:
		return
	stream_root.global_position = origin
	stream_root.look_at(origin + direction, Vector3.UP)
	var range_ratio: float = clampf(
		stream_range / maxf(maximum_range, 0.01),
		0.04,
		1.0
	)
	var flicker: float = 1.0 + sin(visual_age * 22.0) * 0.055
	stream_root.scale = Vector3(flicker, flicker, range_ratio)
	if inner_flame != null:
		var inner_pulse: float = 1.0 + sin(visual_age * 31.0) * 0.08
		inner_flame.scale.x = inner_pulse
		inner_flame.scale.z = inner_pulse


func _set_stream_visible(visible: bool) -> void:
	if stream_root != null:
		stream_root.visible = visible


func _collect_collision_rids(
	node: Node,
	target: Array[RID]
) -> void:
	if node is CollisionObject3D:
		var rid: RID = (node as CollisionObject3D).get_rid()
		if rid.is_valid() and not target.has(rid):
			target.append(rid)
	for child: Node in node.get_children():
		_collect_collision_rids(child, target)


func _show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func reset_target() -> void:
	cancel_ability_channel("reset")
	mana_fractional_cost = 0.0
	combat_tick_timer = 0.0
	visual_age = 0.0
	current_stream_range = 0.0
	total_channel_seconds = 0.0
	total_mana_spent = 0
	total_heat_energy_j = 0.0
	total_combat_ticks = 0
	last_end_reason = "reset"


func get_debug_data() -> Dictionary:
	var target_names: Array[String] = []
	for target: Node in current_targets:
		if target != null and is_instance_valid(target):
			target_names.append(str(target.name))
	return {
		"flamethrower_controller": true,
		"spell_id": handled_spell_id,
		"equipped": is_flamethrower_equipped(),
		"channel_active": channel_requested,
		"mana_per_second": get_effective_mana_rate(),
		"mana_fractional_cost": snappedf(mana_fractional_cost, 0.001),
		"stream_range": snappedf(current_stream_range, 0.01),
		"target_count": current_targets.size(),
		"targets": target_names,
		"last_end_reason": last_end_reason,
		"total_channel_seconds": snappedf(total_channel_seconds, 0.01),
		"total_mana_spent": total_mana_spent,
		"total_heat_energy_j": snappedf(total_heat_energy_j, 0.1),
		"total_combat_ticks": total_combat_ticks,
	}
