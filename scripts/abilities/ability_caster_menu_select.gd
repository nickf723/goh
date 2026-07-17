extends "res://scripts/abilities/ability_caster.gd"

# Prototype wrapper for the focus spell menu.
# The base AbilityCaster still owns casting, loadout, charge logic, and menu data.
# This wrapper changes the focus menu contract, delegates simple spell upgrade
# payload hooks to SpellModifierRegistry, and routes ground-targeted spells through
# GroundTargetingController.

const SpellModifiers = preload("res://scripts/abilities/spell_modifier_registry.gd")
const GroundTargeting = preload("res://scripts/abilities/ground_targeting_controller.gd")

const EARTH_SPIKE_SPELL_ID: String = "earth_spike"
const POISON_BLOOM_SPELL_IDS: Array[String] = ["poison_cloud", "poison_bloom"]
const GROUND_SPELL_EARTH_SPIKE: String = "earth_spike"
const GROUND_SPELL_POISON_BLOOM: String = "poison_bloom"

@export_group("Earth Spike Targeting")
@export var earth_spike_target_radius: float = 2.15
@export var earth_spike_target_range: float = 12.0
@export var earth_spike_initial_distance: float = 6.0
@export var earth_spike_marker_speed: float = 8.5
@export var earth_spike_marker_deadzone: float = 0.18
@export var earth_spike_ground_y_offset: float = 0.05
@export var earth_spike_cast_lock_duration: float = 0.24

@export_group("Poison Bloom Targeting")
@export var poison_bloom_target_radius: float = 3.0
@export var poison_bloom_target_range: float = 12.0
@export var poison_bloom_initial_distance: float = 6.0
@export var poison_bloom_marker_speed: float = 8.0
@export var poison_bloom_marker_deadzone: float = 0.18
@export var poison_bloom_ground_y_offset: float = 0.06
@export var poison_bloom_cast_lock_duration: float = 0.22

var ground_targeting_controller: RefCounted = null


func _process(delta: float) -> void:
	super._process(delta)

	if is_ground_targeting():
		get_ground_targeting_controller().update(delta)


func cast_from_player(player: Node3D, cast_lock_duration: float = 0.18, allow_charge: bool = true) -> bool:
	var ability: AbilityDefinition = get_current_ability()

	if is_ground_targeting():
		return confirm_ground_targeting()

	if should_use_poison_bloom_targeting(ability):
		return begin_ground_targeting(player, ability, get_poison_bloom_target_config(), "Place Poison Bloom. Right stick moves target. Cast confirms. Cancel backs out.")

	if should_use_earth_spike_targeting(ability):
		return begin_ground_targeting(player, ability, get_earth_spike_target_config(), "Place Earth Spike. Right stick moves target. Cast confirms. Cancel backs out.")

	if SpellModifiers.has_active_payload_modifier_for_ability(ability):
		return cast_with_spell_modifier(player, ability, cast_lock_duration)

	return super.cast_from_player(player, cast_lock_duration, allow_charge)


func cast_with_spell_modifier(player: Node3D, ability: AbilityDefinition, cast_lock_duration: float) -> bool:
	if ability == null:
		return false

	var payload_override: Resource = SpellModifiers.build_modified_payload_for_ability(ability)
	var modifier_lock_duration: float = SpellModifiers.get_cast_lock_duration_for_ability(ability, cast_lock_duration)
	var modifier_extra_mana_cost: int = SpellModifiers.get_cast_extra_mana_cost_for_ability(ability)

	var did_cast: bool = execute_ability_from_player(
		player,
		ability,
		modifier_lock_duration,
		payload_override,
		0.0,
		modifier_extra_mana_cost
	)

	if did_cast:
		var cast_message: String = SpellModifiers.get_cast_message_for_ability(ability)
		if cast_message != "":
			show_feedback(cast_message)

	return did_cast


func should_use_earth_spike_targeting(ability: AbilityDefinition) -> bool:
	if ability == null:
		return false

	if ability.element.to_lower() != "earth":
		return false

	var spell_id: String = get_ability_spell_id(ability)
	if spell_id != "":
		return spell_id == EARTH_SPIKE_SPELL_ID

	return ability.display_name.to_lower() == "earth spike"


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


func get_ground_targeting_controller() -> RefCounted:
	if ground_targeting_controller == null:
		ground_targeting_controller = GroundTargeting.new()

	return ground_targeting_controller


func begin_ground_targeting(player: Node3D, ability: AbilityDefinition, target_config: Dictionary, message: String) -> bool:
	if player == null or ability == null:
		return false

	if action_state != null and not action_state.can_cast():
		return false

	cancel_charged_firebolt(false)

	var controller: RefCounted = get_ground_targeting_controller()
	if not controller.start(self, player, ability, target_config):
		return false

	focus_spell_menu_open = true
	show_feedback(message)
	return true


func is_ground_targeting() -> bool:
	return ground_targeting_controller != null and ground_targeting_controller.is_active()


func handle_focus_menu_input(event: InputEvent) -> bool:
	if is_ground_targeting():
		return handle_ground_targeting_input(event)

	if not focus_spell_menu_open:
		return false

	if event.is_action_pressed("focus_element_left"):
		cycle_focus_element(-1)
		return true

	if event.is_action_pressed("focus_element_right"):
		cycle_focus_element(1)
		return true

	if event.is_action_pressed("focus_spell_up"):
		cycle_focus_spell(-1)
		return true

	if event.is_action_pressed("focus_spell_down"):
		cycle_focus_spell(1)
		return true

	if event.is_action_pressed("cast_spell") or event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		equip_selected_focus_spell_and_close()
		return true

	if event.is_action_pressed("ui_cancel"):
		close_focus_spell_menu()
		return true

	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey

		if not key_event.pressed or key_event.echo:
			return true

		match key_event.keycode:
			KEY_LEFT:
				cycle_focus_element(-1)
				return true
			KEY_RIGHT:
				cycle_focus_element(1)
				return true
			KEY_UP:
				cycle_focus_spell(-1)
				return true
			KEY_DOWN:
				cycle_focus_spell(1)
				return true
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				equip_selected_focus_spell_and_close()
				return true
			KEY_ESCAPE:
				close_focus_spell_menu()
				return true
			_:
				return true

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton

		if not mouse_event.pressed:
			return true

		match mouse_event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				cycle_focus_spell(-1)
				return true
			MOUSE_BUTTON_WHEEL_DOWN:
				cycle_focus_spell(1)
				return true
			MOUSE_BUTTON_LEFT:
				equip_selected_focus_spell_and_close()
				return true
			MOUSE_BUTTON_RIGHT:
				close_focus_spell_menu()
				return true
			_:
				return true

	return true


func handle_ground_targeting_input(event: InputEvent) -> bool:
	if event.is_action_pressed("cast_spell") or event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		confirm_ground_targeting()
		return true

	if event.is_action_pressed("ui_cancel"):
		cancel_ground_targeting(true)
		return true

	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			match key_event.keycode:
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					confirm_ground_targeting()
					return true
				KEY_ESCAPE:
					cancel_ground_targeting(true)
					return true

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed:
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				confirm_ground_targeting()
				return true
			if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
				cancel_ground_targeting(true)
				return true

	return true


func confirm_ground_targeting() -> bool:
	if not is_ground_targeting():
		return false

	var controller: RefCounted = get_ground_targeting_controller()
	var ability_resource: Resource = controller.get_ability()
	var ability: AbilityDefinition = ability_resource as AbilityDefinition
	var player: Node3D = controller.get_source_player()
	var spell_key: String = controller.get_spell_key()
	var target_position: Vector3 = controller.get_target_position()

	if ability == null or player == null:
		cancel_ground_targeting(false)
		return false

	if action_state != null and not action_state.can_cast():
		return true

	if not pay_ability_cost(ability):
		show_feedback("Not enough resources for " + ability.display_name + ".")
		return true

	if action_state != null:
		action_state.begin_cast(controller.get_cast_lock_duration(0.22))

	if spell_key == GROUND_SPELL_EARTH_SPIKE:
		var earth_payload: DamagePayload = make_earth_spike_ground_payload(ability)
		var hit_count: int = erupt_earth_spike(target_position, earth_payload, player)
		cancel_ground_targeting(false)
		if hit_count > 0:
			show_feedback("Earth Spike erupts and hits " + str(hit_count) + " target(s).")
		else:
			show_feedback("Earth Spike erupts.")
		return true

	if spell_key == GROUND_SPELL_POISON_BLOOM:
		spawn_poison_bloom(target_position, ability, player)
		cancel_ground_targeting(false)
		show_feedback("Poison Bloom unfurls.")
		return true

	cancel_ground_targeting(false)
	return true


func cancel_ground_targeting(should_show_feedback: bool = true) -> void:
	if not is_ground_targeting():
		return

	var spell_key: String = get_ground_targeting_controller().get_spell_key()
	get_ground_targeting_controller().cancel()
	focus_spell_menu_open = false

	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("hide_spell_focus_menu"):
		ui.hide_spell_focus_menu()

	if not should_show_feedback:
		return

	if spell_key == GROUND_SPELL_POISON_BLOOM:
		show_feedback("Poison Bloom canceled.")
	else:
		show_feedback("Earth Spike canceled.")


func get_earth_spike_target_config() -> Dictionary:
	return {
		"spell_key": GROUND_SPELL_EARTH_SPIKE,
		"marker_name": "EarthSpikeTargetMarker",
		"disc_name": "TargetDisc",
		"center_name": "TargetCenter",
		"radius": earth_spike_target_radius,
		"range": earth_spike_target_range,
		"initial_distance": earth_spike_initial_distance,
		"speed": earth_spike_marker_speed,
		"deadzone": earth_spike_marker_deadzone,
		"ground_y_offset": earth_spike_ground_y_offset,
		"cast_lock_duration": earth_spike_cast_lock_duration,
		"disc_color": Color(0.36, 0.27, 0.14, 0.32),
		"center_color": Color(0.36, 0.27, 0.14, 0.78),
		"disc_alpha": 0.32,
		"center_alpha": 0.78,
		"pulse_speed": 5.5,
		"pulse_size": 0.035,
		"emission_energy": 0.55,
	}


func get_poison_bloom_target_config() -> Dictionary:
	return {
		"spell_key": GROUND_SPELL_POISON_BLOOM,
		"marker_name": "PoisonBloomTargetMarker",
		"disc_name": "PoisonBloomDisc",
		"center_name": "PoisonBloomCenter",
		"radius": poison_bloom_target_radius,
		"range": poison_bloom_target_range,
		"initial_distance": poison_bloom_initial_distance,
		"speed": poison_bloom_marker_speed,
		"deadzone": poison_bloom_marker_deadzone,
		"ground_y_offset": poison_bloom_ground_y_offset,
		"cast_lock_duration": poison_bloom_cast_lock_duration,
		"disc_color": Color(0.22, 0.85, 0.22, 0.34),
		"center_color": Color(0.22, 0.85, 0.22, 0.78),
		"disc_alpha": 0.34,
		"center_alpha": 0.78,
		"pulse_speed": 4.4,
		"pulse_size": 0.055,
		"emission_energy": 0.72,
	}


func make_earth_spike_ground_payload(ability: AbilityDefinition) -> DamagePayload:
	var base_payload: Resource = get_ability_payload(ability)
	var payload: DamagePayload = DamagePayload.new()

	if base_payload is DamagePayload:
		var duplicate_payload: Resource = base_payload.duplicate(true)
		if duplicate_payload is DamagePayload:
			payload = duplicate_payload as DamagePayload

	payload.source_name = "Earth Spike"
	payload.hit_type = "ground_aoe"
	append_payload_tags(payload, ["earth_spike", "ground_targeted", "aoe"])
	return payload


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


func get_ability_payload(ability: AbilityDefinition) -> Resource:
	if ability == null:
		return null

	if ability.has_method("get_action_payload"):
		var method_payload: Variant = ability.get_action_payload()
		if method_payload is Resource:
			return method_payload as Resource

	if ability.payload != null:
		return ability.payload

	return null


func append_payload_tags(payload: DamagePayload, tags_to_add: Array[String]) -> void:
	if payload == null:
		return

	var next_tags: Array[String] = []
	for existing_tag: String in payload.tags:
		if existing_tag == "":
			continue
		if next_tags.has(existing_tag):
			continue
		next_tags.append(existing_tag)

	for tag: String in tags_to_add:
		if tag == "":
			continue
		if next_tags.has(tag):
			continue
		next_tags.append(tag)

	payload.tags = next_tags


func erupt_earth_spike(target_position: Vector3, payload: DamagePayload, source_actor: Node) -> int:
	show_earth_spike_erupt_visual(target_position)

	var hit_count: int = 0
	for target_node: Node in get_tree().get_nodes_in_group("enemy"):
		if not target_node is Node3D:
			continue

		var target: Node3D = target_node as Node3D
		if not is_valid_ground_target(target):
			continue

		var offset: Vector3 = target.global_position - target_position
		offset.y = 0.0
		if offset.length() > earth_spike_target_radius:
			continue

		var hit_payload: DamagePayload = payload.duplicate(true) as DamagePayload
		send_ground_payload_to_target(target, hit_payload)
		hit_count += 1

	return hit_count


func is_valid_ground_target(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if hit_receiver != null:
		var current_health: Variant = hit_receiver.get("current_health")
		if current_health != null and int(current_health) <= 0:
			return false

	if target.get_node_or_null("PayloadReceiver") != null:
		return true
	if target.get_node_or_null("HitReceiver") != null:
		return true
	if target.has_method("receive_damage_payload"):
		return true
	if target.has_method("receive_magic_hit"):
		return true

	return false


func send_ground_payload_to_target(target: Node, damage_payload: DamagePayload) -> Dictionary:
	var payload_receiver: Node = target.get_node_or_null("PayloadReceiver")

	if payload_receiver != null and payload_receiver.has_method("receive_payload"):
		return payload_receiver.receive_payload(damage_payload)

	if target.has_method("receive_damage_payload"):
		return target.receive_damage_payload(damage_payload)

	var hit_receiver: Node = target.get_node_or_null("HitReceiver")

	if hit_receiver != null:
		if hit_receiver.has_method("receive_payload"):
			return hit_receiver.receive_payload(damage_payload)

		if hit_receiver.has_method("receive_hit"):
			return hit_receiver.receive_hit(damage_payload.amount)

	if target.has_method("receive_magic_hit"):
		return target.receive_magic_hit(damage_payload.amount)

	return {}


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


func show_earth_spike_erupt_visual(target_position: Vector3) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return

	var root: Node3D = Node3D.new()
	root.name = "EarthSpikeEruption"
	root.global_position = target_position
	scene_root.add_child(root)

	var disc: MeshInstance3D = MeshInstance3D.new()
	disc.name = "EarthBurstDisc"
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var disc_mesh: CylinderMesh = CylinderMesh.new()
	disc_mesh.top_radius = earth_spike_target_radius
	disc_mesh.bottom_radius = earth_spike_target_radius
	disc_mesh.height = 0.045
	disc.mesh = disc_mesh
	disc.material_override = make_earth_spike_marker_material(0.42)
	root.add_child(disc)

	for index: int in range(5):
		var spike: MeshInstance3D = MeshInstance3D.new()
		spike.name = "StoneSpike" + str(index + 1)
		var spike_mesh: BoxMesh = BoxMesh.new()
		var height: float = 1.05 + float(index % 3) * 0.28
		spike_mesh.size = Vector3(0.32, height, 0.32)
		spike.mesh = spike_mesh
		spike.material_override = make_earth_spike_spike_material()
		var angle: float = TAU * float(index) / 5.0
		var radius: float = 0.25 + float(index % 2) * 0.48
		spike.position = Vector3(cos(angle) * radius, height * 0.5, sin(angle) * radius)
		spike.rotation = Vector3(deg_to_rad(10.0 + float(index) * 3.0), angle, deg_to_rad(-8.0 + float(index) * 2.0))
		spike.scale = Vector3(0.2, 0.05, 0.2)
		root.add_child(spike)

		var tween: Tween = root.create_tween()
		tween.tween_property(spike, "scale", Vector3.ONE, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var cleanup_tween: Tween = root.create_tween()
	cleanup_tween.tween_interval(0.5)
	cleanup_tween.tween_callback(root.queue_free)


func make_earth_spike_marker_material(alpha: float = 0.32) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.36, 0.27, 0.14, alpha)
	material.emission_enabled = true
	material.emission = Color(0.46, 0.34, 0.14, 1.0)
	material.emission_energy_multiplier = 0.55
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func make_earth_spike_spike_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.27, 0.22, 0.16, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.18, 0.12, 0.06, 1.0)
	material.emission_energy_multiplier = 0.25
	return material


func equip_selected_focus_spell_and_close() -> void:
	var selected_index: int = get_selected_focus_spell_global_index()

	if selected_index < 0:
		show_feedback("No learned " + get_selected_focus_element_display_name() + " spells yet.")
		update_focus_spell_menu_ui()
		return

	select_ability(selected_index)
	close_focus_spell_menu()
