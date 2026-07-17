extends "res://scripts/abilities/ability_caster_menu_select.gd"

# Prototype wrapper for ground-targeted field spells.
# Earth Spike still lives in the parent wrapper. This layer adds Poison Bloom
# without touching the older projectile, charge, pierce, or chain behavior.

const POISON_BLOOM_SPELL_IDS: Array[String] = ["poison_cloud", "poison_bloom"]

@export_group("Poison Bloom Targeting")
@export var poison_bloom_target_radius: float = 3.0
@export var poison_bloom_target_range: float = 12.0
@export var poison_bloom_initial_distance: float = 6.0
@export var poison_bloom_marker_speed: float = 8.0
@export var poison_bloom_marker_deadzone: float = 0.18
@export var poison_bloom_ground_y_offset: float = 0.06
@export var poison_bloom_cast_lock_duration: float = 0.22

var poison_bloom_targeting_active: bool = false
var poison_bloom_targeting_player: Node3D = null
var poison_bloom_targeting_ability: AbilityDefinition = null
var poison_bloom_target_position: Vector3 = Vector3.ZERO
var poison_bloom_target_marker: Node3D = null


func _process(delta: float) -> void:
	super._process(delta)
	update_poison_bloom_targeting(delta)


func cast_from_player(player: Node3D, cast_lock_duration: float = 0.18, allow_charge: bool = true) -> bool:
	var ability: AbilityDefinition = get_current_ability()

	if poison_bloom_targeting_active:
		return confirm_poison_bloom_targeting()

	if should_use_poison_bloom_targeting(ability):
		return begin_poison_bloom_targeting(player, ability)

	return super.cast_from_player(player, cast_lock_duration, allow_charge)


func handle_focus_menu_input(event: InputEvent) -> bool:
	if poison_bloom_targeting_active:
		return handle_poison_bloom_targeting_input(event)

	return super.handle_focus_menu_input(event)


func is_ground_targeting() -> bool:
	return poison_bloom_targeting_active or super.is_ground_targeting()


func should_use_poison_bloom_targeting(ability: AbilityDefinition) -> bool:
	if ability == null:
		return false

	if ability.element.to_lower() != "poison":
		return false

	var spell_id: String = get_ability_spell_id(ability)
	if spell_id != "":
		return POISON_BLOOM_SPELL_IDS.has(spell_id)

	var display_name: String = ability.display_name.to_lower()
	return display_name == "poison cloud" or display_name == "poison bloom"


func get_ability_spell_id(ability: AbilityDefinition) -> String:
	if ability == null:
		return ""

	if ability.has_method("get_spell_id"):
		return str(ability.get_spell_id())

	var spell_id_value: Variant = ability.get("spell_id")
	if spell_id_value != null:
		return str(spell_id_value)

	return ""


func begin_poison_bloom_targeting(player: Node3D, ability: AbilityDefinition) -> bool:
	if player == null or ability == null:
		return false

	if action_state != null and not action_state.can_cast():
		return false

	cancel_charged_firebolt(false)
	poison_bloom_targeting_active = true
	poison_bloom_targeting_player = player
	poison_bloom_targeting_ability = ability
	poison_bloom_target_position = get_initial_poison_bloom_target_position(player)
	focus_spell_menu_open = true
	ensure_poison_bloom_marker()
	update_poison_bloom_marker_visual()
	show_feedback("Place Poison Bloom. Right stick moves target. Cast confirms. Cancel backs out.")
	return true


func update_poison_bloom_targeting(delta: float) -> void:
	if not poison_bloom_targeting_active:
		return

	if poison_bloom_targeting_player == null or not is_instance_valid(poison_bloom_targeting_player):
		cancel_poison_bloom_targeting(false)
		return

	var target_input: Vector2 = Input.get_vector(
		"camera_left",
		"camera_right",
		"camera_up",
		"camera_down"
	)

	if target_input.length() >= poison_bloom_marker_deadzone:
		var move_direction: Vector3 = get_poison_bloom_target_move_direction(target_input)
		if move_direction.length() > 0.01:
			poison_bloom_target_position += move_direction * poison_bloom_marker_speed * delta
			poison_bloom_target_position = clamp_poison_bloom_target_position(poison_bloom_target_position)
			poison_bloom_target_position = resolve_poison_bloom_ground_position(poison_bloom_target_position)

	update_poison_bloom_marker_visual()


func get_poison_bloom_target_move_direction(target_input: Vector2) -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var right_axis: Vector3 = Vector3.RIGHT
	var forward_axis: Vector3 = Vector3.FORWARD

	if camera != null:
		right_axis = camera.global_transform.basis.x
		forward_axis = -camera.global_transform.basis.z
	elif poison_bloom_targeting_player != null:
		right_axis = poison_bloom_targeting_player.global_transform.basis.x
		forward_axis = -poison_bloom_targeting_player.global_transform.basis.z

	right_axis.y = 0.0
	forward_axis.y = 0.0

	if right_axis.length() <= 0.01:
		right_axis = Vector3.RIGHT
	if forward_axis.length() <= 0.01:
		forward_axis = Vector3.FORWARD

	right_axis = right_axis.normalized()
	forward_axis = forward_axis.normalized()

	var move_direction: Vector3 = right_axis * target_input.x + forward_axis * -target_input.y
	if move_direction.length() <= 0.01:
		return Vector3.ZERO

	return move_direction.normalized()


func handle_poison_bloom_targeting_input(event: InputEvent) -> bool:
	if event.is_action_pressed("cast_spell") or event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		confirm_poison_bloom_targeting()
		return true

	if event.is_action_pressed("ui_cancel"):
		cancel_poison_bloom_targeting(true)
		return true

	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			match key_event.keycode:
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					confirm_poison_bloom_targeting()
					return true
				KEY_ESCAPE:
					cancel_poison_bloom_targeting(true)
					return true

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed:
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				confirm_poison_bloom_targeting()
				return true
			if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
				cancel_poison_bloom_targeting(true)
				return true

	return true


func confirm_poison_bloom_targeting() -> bool:
	if not poison_bloom_targeting_active:
		return false

	var player: Node3D = poison_bloom_targeting_player
	var ability: AbilityDefinition = poison_bloom_targeting_ability

	if player == null or ability == null:
		cancel_poison_bloom_targeting(false)
		return false

	if action_state != null and not action_state.can_cast():
		return true

	if not pay_ability_cost(ability):
		show_feedback("Not enough resources for Poison Bloom.")
		return true

	if action_state != null:
		action_state.begin_cast(poison_bloom_cast_lock_duration)

	var target_position: Vector3 = poison_bloom_target_position
	spawn_poison_bloom(target_position, ability, player)
	cancel_poison_bloom_targeting(false)
	show_feedback("Poison Bloom unfurls.")
	return true


func cancel_poison_bloom_targeting(should_show_feedback: bool = true) -> void:
	if poison_bloom_target_marker != null:
		poison_bloom_target_marker.queue_free()

	poison_bloom_target_marker = null
	poison_bloom_targeting_active = false
	poison_bloom_targeting_player = null
	poison_bloom_targeting_ability = null
	focus_spell_menu_open = false

	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("hide_spell_focus_menu"):
		ui.hide_spell_focus_menu()

	if should_show_feedback:
		show_feedback("Poison Bloom canceled.")


func get_initial_poison_bloom_target_position(player: Node3D) -> Vector3:
	var forward_axis: Vector3 = -player.global_transform.basis.z
	forward_axis.y = 0.0

	if forward_axis.length() <= 0.01:
		forward_axis = Vector3.FORWARD

	var initial_position: Vector3 = player.global_position + forward_axis.normalized() * poison_bloom_initial_distance
	return resolve_poison_bloom_ground_position(clamp_poison_bloom_target_position(initial_position))


func clamp_poison_bloom_target_position(raw_position: Vector3) -> Vector3:
	if poison_bloom_targeting_player == null:
		return raw_position

	var origin: Vector3 = poison_bloom_targeting_player.global_position
	var offset: Vector3 = raw_position - origin
	offset.y = 0.0

	if offset.length() > poison_bloom_target_range:
		offset = offset.normalized() * poison_bloom_target_range

	return origin + offset


func resolve_poison_bloom_ground_position(raw_position: Vector3) -> Vector3:
	var resolved_position: Vector3 = raw_position
	var world_3d: World3D = get_world_3d()

	if world_3d != null:
		var ray_from: Vector3 = raw_position + Vector3.UP * 8.0
		var ray_to: Vector3 = raw_position + Vector3.DOWN * 18.0
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_from, ray_to)
		var result: Dictionary = world_3d.direct_space_state.intersect_ray(query)

		if result.has("position"):
			resolved_position = result["position"]

	resolved_position.y += poison_bloom_ground_y_offset
	return resolved_position


func ensure_poison_bloom_marker() -> void:
	if poison_bloom_target_marker != null and is_instance_valid(poison_bloom_target_marker):
		return

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return

	poison_bloom_target_marker = Node3D.new()
	poison_bloom_target_marker.name = "PoisonBloomTargetMarker"

	var disc: MeshInstance3D = MeshInstance3D.new()
	disc.name = "PoisonBloomDisc"
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var disc_mesh: CylinderMesh = CylinderMesh.new()
	disc_mesh.top_radius = 1.0
	disc_mesh.bottom_radius = 1.0
	disc_mesh.height = 0.035
	disc.mesh = disc_mesh
	disc.scale = Vector3(poison_bloom_target_radius, 1.0, poison_bloom_target_radius)
	disc.material_override = make_poison_bloom_marker_material()
	poison_bloom_target_marker.add_child(disc)

	var center: MeshInstance3D = MeshInstance3D.new()
	center.name = "PoisonBloomCenter"
	center.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var center_mesh: SphereMesh = SphereMesh.new()
	center_mesh.radius = 0.13
	center_mesh.height = 0.26
	center.mesh = center_mesh
	center.material_override = make_poison_bloom_marker_material(0.78)
	poison_bloom_target_marker.add_child(center)

	scene_root.add_child(poison_bloom_target_marker)


func make_poison_bloom_marker_material(alpha: float = 0.34) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.85, 0.22, alpha)
	material.emission_enabled = true
	material.emission = Color(0.12, 0.62, 0.12, 1.0)
	material.emission_energy_multiplier = 0.72
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func update_poison_bloom_marker_visual() -> void:
	if poison_bloom_target_marker == null:
		return

	poison_bloom_target_marker.global_position = poison_bloom_target_position

	var pulse_age: float = float(Time.get_ticks_msec()) * 0.001
	var pulse: float = 1.0 + sin(pulse_age * 4.4) * 0.055
	poison_bloom_target_marker.scale = Vector3.ONE * pulse


func spawn_poison_bloom(target_position: Vector3, ability: AbilityDefinition, source_actor: Node3D) -> void:
	if ability == null or ability.ability_scene == null:
		return

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return

	var ability_instance: Node = ability.ability_scene.instantiate()
	var poison_payload: DamagePayload = make_poison_bloom_payload(ability)

	if ability_instance.has_method("set_payload"):
		ability_instance.set_payload(poison_payload)

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
	if ability_instance.has_method("apply_cloud_tick"):
		ability_instance.call_deferred("apply_cloud_tick")


func make_poison_bloom_payload(ability: AbilityDefinition) -> DamagePayload:
	var base_payload: Resource = get_ability_payload(ability)
	var payload: DamagePayload = DamagePayload.new()

	if base_payload is DamagePayload:
		var duplicate_payload: Resource = base_payload.duplicate(true)
		if duplicate_payload is DamagePayload:
			payload = duplicate_payload as DamagePayload

	payload.source_name = "Poison Bloom"
	payload.hit_type = "ground_field"
	if payload.status_effect == "":
		payload.status_effect = "poisoned"
	if payload.status_duration <= 0.0:
		payload.status_duration = 1.6
	if payload.status_strength <= 0.0:
		payload.status_strength = 1.0
	append_payload_tags(payload, ["poison_bloom", "ground_targeted", "field", "aoe"])
	return payload
