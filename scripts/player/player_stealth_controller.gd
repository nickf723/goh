extends Node
class_name PlayerStealthController

signal crouch_changed(crouched: bool)
signal acoustic_event_emitted(category: String, loudness: float)
signal takedown_performed(target: Node3D)

@export var crouch_speed_multiplier: float = 0.48
@export var crouch_visibility_multiplier: float = 0.62
@export var concealment_visibility_multiplier: float = 0.32
@export var crouch_noise_multiplier: float = 0.26
@export var concealment_noise_multiplier: float = 0.5
@export var crouch_height_ratio: float = 0.62
@export var camera_drop: float = 0.42
@export var transition_speed: float = 10.0
@export var takedown_range: float = 2.15
@export var takedown_rear_dot: float = -0.2
@export var attack_loudness: float = 9.0
@export var spell_loudness: float = 11.0

var actor: CharacterBody3D
var manager: PerceptionStimulusManager
var crouched: bool = false
var concealed: bool = false
var current_noise: float = 0.0
var last_acoustic_category: String = "quiet"
var collision: CollisionShape3D
var capsule: CapsuleShape3D
var original_capsule_height: float = 2.0
var original_collision_position: Vector3
var camera_pivot: Node3D
var original_camera_position: Vector3
var visual_root: Node3D
var original_visual_scale: Vector3
var hud_layer: CanvasLayer
var state_label: Label
var noise_bar: ProgressBar


func _ready() -> void:
	actor = get_parent() as CharacterBody3D
	if actor == null:
		return
	manager = get_tree().get_first_node_in_group("perception_stimulus_manager") as PerceptionStimulusManager
	collision = actor.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null and collision.shape is CapsuleShape3D:
		capsule = collision.shape.duplicate() as CapsuleShape3D
		collision.shape = capsule
		original_capsule_height = capsule.height
		original_collision_position = collision.position
	camera_pivot = actor.get_node_or_null("CameraPivot") as Node3D
	if camera_pivot != null:
		original_camera_position = camera_pivot.position
	visual_root = actor.get_node_or_null("GraceVisualV1") as Node3D
	if visual_root != null:
		original_visual_scale = visual_root.scale
	ensure_input()
	ensure_movement_emitter()
	build_indicator()
	add_to_group("stealth_controllers")
	add_to_group("debuggable")


func _process(delta: float) -> void:
	if actor == null:
		return
	update_concealment()
	update_pose(delta)
	update_action_acoustics()
	current_noise = move_toward(current_noise, 0.0, delta * 8.0)
	update_indicator()


func _input(event: InputEvent) -> void:
	if actor == null or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("crouch_toggle"):
		if crouched:
			if can_stand():
				set_crouched(false)
			else:
				show_message("Not enough room to stand.")
		else:
			set_crouched(true)
		get_viewport().set_input_as_handled()
		return
	if crouched and event.is_action_pressed("interact"):
		var target: Node3D = find_takedown_target()
		if target != null:
			perform_takedown(target)
			get_viewport().set_input_as_handled()


func set_crouched(value: bool) -> void:
	if crouched == value:
		return
	crouched = value
	crouch_changed.emit(crouched)
	show_message("Crouched: quieter and harder to see." if crouched else "Standing.")


func is_crouched() -> bool:
	return crouched


func is_concealed() -> bool:
	return concealed


func get_movement_multiplier() -> float:
	return crouch_speed_multiplier if crouched else 1.0


func get_noise_multiplier() -> float:
	var multiplier: float = crouch_noise_multiplier if crouched else 1.0
	if concealed:
		multiplier *= concealment_noise_multiplier
	return multiplier


func get_visibility_multiplier() -> float:
	var multiplier: float = crouch_visibility_multiplier if crouched else 1.0
	if concealed:
		multiplier *= concealment_visibility_multiplier
	var speed: float = Vector3(actor.velocity.x, 0.0, actor.velocity.z).length() if actor != null else 0.0
	if speed > 3.8:
		multiplier *= 1.18
	return clampf(multiplier, 0.08, 1.25)


func report_acoustic_event(category: String, loudness: float) -> void:
	current_noise = clampf(loudness / 14.0, 0.0, 1.0)
	last_acoustic_category = category
	acoustic_event_emitted.emit(category, loudness)


func update_concealment() -> void:
	concealed = false
	if actor == null:
		return
	for node: Node in get_tree().get_nodes_in_group("stealth_concealment"):
		var area: Area3D = node as Area3D
		if area != null and area.overlaps_body(actor):
			concealed = true
			return


func update_pose(delta: float) -> void:
	var blend: float = clampf(transition_speed * delta, 0.0, 1.0)
	var crouch_amount: float = 1.0 if crouched else 0.0
	if capsule != null:
		var target_height: float = lerpf(original_capsule_height, original_capsule_height * crouch_height_ratio, crouch_amount)
		capsule.height = lerpf(capsule.height, target_height, blend)
		var drop: float = (original_capsule_height - target_height) * 0.5
		var target_collision_position: Vector3 = original_collision_position - Vector3.UP * drop
		collision.position = collision.position.lerp(target_collision_position, blend)
	if camera_pivot != null:
		var target_camera_position: Vector3 = original_camera_position - Vector3.UP * camera_drop * crouch_amount
		camera_pivot.position = camera_pivot.position.lerp(target_camera_position, blend)
	if visual_root != null:
		var target_scale: Vector3 = original_visual_scale
		target_scale.y *= lerpf(1.0, 0.78, crouch_amount)
		visual_root.scale = visual_root.scale.lerp(target_scale, blend)


func can_stand() -> bool:
	if actor == null or actor.get_world_3d() == null:
		return true
	var from: Vector3 = actor.global_position + Vector3.UP * 0.25
	var to: Vector3 = actor.global_position + Vector3.UP * (original_capsule_height * 0.55)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = [actor.get_rid()]
	var result: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(query)
	return result.is_empty()


func update_action_acoustics() -> void:
	if Input.is_action_just_pressed("weapon_light_attack"):
		emit_action_sound("weapon_swing", attack_loudness, "mid")
		set_crouched(false)
	elif Input.is_action_just_pressed("weapon_heavy_attack"):
		emit_action_sound("heavy_weapon_swing", attack_loudness * 1.3, "low")
		set_crouched(false)
	if Input.is_action_just_pressed("cast_spell"):
		emit_action_sound("spellcast", spell_loudness, "broadband")
		set_crouched(false)


func emit_action_sound(category: String, loudness: float, frequency: String) -> void:
	resolve_manager()
	if manager == null or actor == null:
		return
	var tags: Array[String] = ["acoustic", "player_action", "frequency:" + frequency]
	manager.emit_stimulus(actor.global_position, loudness, category, 0.75, actor, category.capitalize(), 1.15, tags)
	report_acoustic_event(category, loudness)


func find_takedown_target() -> Node3D:
	if actor == null:
		return null
	var best: Node3D
	var best_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		var enemy: Node3D = node as Node3D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var receiver: Node = enemy.get_node_or_null("HitReceiver")
		if receiver == null or int(receiver.get("current_health")) <= 0:
			continue
		var distance: float = actor.global_position.distance_to(enemy.global_position)
		if distance > takedown_range or distance >= best_distance:
			continue
		var enemy_forward: Vector3 = -enemy.global_transform.basis.z
		enemy_forward.y = 0.0
		var enemy_to_player: Vector3 = actor.global_position - enemy.global_position
		enemy_to_player.y = 0.0
		if enemy_forward.length_squared() > 0.01 and enemy_to_player.length_squared() > 0.01:
			if enemy_forward.normalized().dot(enemy_to_player.normalized()) > takedown_rear_dot:
				continue
		var sensor: Node = enemy.get_node_or_null("EnemyPerceptionSensor")
		if sensor != null and bool(sensor.get("target_visible")):
			continue
		best = enemy
		best_distance = distance
	return best


func perform_takedown(target: Node3D) -> void:
	var receiver: Node = target.get_node_or_null("HitReceiver")
	if receiver == null or not receiver.has_method("receive_hit"):
		return
	receiver.call("receive_hit", 999)
	emit_action_sound("stealth_takedown", 2.0, "low")
	takedown_performed.emit(target)
	show_message("Silent takedown.")


func resolve_manager() -> void:
	if manager == null or not is_instance_valid(manager):
		manager = get_tree().get_first_node_in_group("perception_stimulus_manager") as PerceptionStimulusManager


func ensure_movement_emitter() -> void:
	if actor.get_node_or_null("PerceptionMovementEmitter") != null:
		return
	var emitter_script: Script = load("res://scripts/perception/perception_movement_emitter.gd") as Script
	if emitter_script == null:
		return
	var emitter: Node = emitter_script.new()
	emitter.name = "PerceptionMovementEmitter"
	call_deferred("attach_movement_emitter", emitter)


func attach_movement_emitter(emitter: Node) -> void:
	if actor == null or not is_instance_valid(actor):
		emitter.queue_free()
		return
	if actor.get_node_or_null("PerceptionMovementEmitter") != null:
		emitter.queue_free()
		return
	actor.add_child(emitter)


func ensure_input() -> void:
	if not InputMap.has_action("crouch_toggle"):
		InputMap.add_action("crouch_toggle", 0.2)
	var has_key: bool = false
	var has_stick: bool = false
	for event: InputEvent in InputMap.action_get_events("crouch_toggle"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_CTRL:
			has_key = true
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_LEFT_STICK:
			has_stick = true
	if not has_key:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = KEY_CTRL
		InputMap.action_add_event("crouch_toggle", key_event)
	if not has_stick:
		var joy_event := InputEventJoypadButton.new()
		joy_event.button_index = JOY_BUTTON_LEFT_STICK
		InputMap.action_add_event("crouch_toggle", joy_event)


func build_indicator() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 24
	actor.add_child.call_deferred(hud_layer)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.position = Vector2(22.0, -112.0)
	panel.custom_minimum_size = Vector2(230.0, 82.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.05, 0.86)
	style.border_color = Color(0.28, 0.58, 0.75, 0.75)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	hud_layer.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	state_label = Label.new()
	state_label.add_theme_font_size_override("font_size", 16)
	box.add_child(state_label)
	noise_bar = ProgressBar.new()
	noise_bar.max_value = 1.0
	noise_bar.show_percentage = false
	noise_bar.custom_minimum_size = Vector2(200.0, 9.0)
	box.add_child(noise_bar)
	var hint := Label.new()
	hint.text = "L3 / Ctrl  Crouch"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.48, 0.58, 0.68))
	box.add_child(hint)


func update_indicator() -> void:
	if state_label == null:
		return
	if concealed and crouched:
		state_label.text = "● CONCEALED   Noise: " + last_acoustic_category.capitalize()
		state_label.add_theme_color_override("font_color", Color(0.42, 1.0, 0.66))
	elif crouched:
		state_label.text = "◐ CROUCHED   Noise: " + last_acoustic_category.capitalize()
		state_label.add_theme_color_override("font_color", Color(0.54, 0.82, 1.0))
	else:
		state_label.text = "○ EXPOSED   Noise: " + last_acoustic_category.capitalize()
		state_label.add_theme_color_override("font_color", Color(0.86, 0.88, 0.9))
	noise_bar.value = current_noise


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)


func get_debug_data() -> Dictionary:
	return {
		"crouched": crouched,
		"concealed": concealed,
		"noise_multiplier": get_noise_multiplier(),
		"visibility_multiplier": get_visibility_multiplier(),
		"last_sound": last_acoustic_category,
	}
