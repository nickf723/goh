extends Node
class_name LargeEnemyTraversalController

signal traversal_state_changed(state_name: String)
signal grab_progress_changed(current: int, required: int)

@export_range(0.5, 8.0, 0.1) var mount_range: float = 3.4
@export_range(0.1, 8.0, 0.1) var climb_speed: float = 3.0
@export_range(0.1, 20.0, 0.1) var stamina_per_second: float = 6.0
@export_range(1, 12, 1) var escape_inputs_required: int = 4
@export_range(0.5, 5.0, 0.1) var grab_escape_seconds: float = 2.4

var player: CharacterBody3D = null
var large_enemy: Node3D = null
var anchors: Array[Node3D] = []
var anchor_index: int = -1
var is_attached: bool = false
var is_grabbed: bool = false
var grab_timer: float = 0.0
var escape_inputs: int = 0
var stamina_accumulator: float = 0.0
var status_message: String = "Approach a vulnerable large enemy and press Interact to climb."


func setup(player_node: CharacterBody3D, enemy_node: Node3D) -> void:
	player = player_node
	large_enemy = enemy_node
	_refresh_anchors()
	add_to_group("large_enemy_traversal_controller")


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if is_grabbed:
		_process_grab(delta)
	elif is_attached:
		_process_climb(delta)


func _unhandled_input(event: InputEvent) -> void:
	if player == null:
		return
	if is_grabbed:
		if event.is_action_pressed("weapon_light_attack") or event.is_action_pressed("dodge"):
			escape_inputs += 1
			grab_progress_changed.emit(escape_inputs, escape_inputs_required)
			status_message = "ESCAPE  " + str(escape_inputs) + " / " + str(escape_inputs_required)
			if escape_inputs >= escape_inputs_required:
				_release_grab(true)
			get_viewport().set_input_as_handled()
		return
	if is_attached:
		if event.is_action_pressed("jump") or event.is_action_pressed("dodge"):
			detach(Vector3.UP * 5.0 + _away_direction() * 4.0, "Grace leaps clear.")
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		try_attach()


func try_attach() -> bool:
	if is_attached or is_grabbed or large_enemy == null:
		return false
	if large_enemy.has_method("can_player_climb") and not bool(large_enemy.call("can_player_climb")):
		status_message = _enemy_name() + " must be vulnerable before Grace can climb it."
		_show_message(status_message)
		return false
	_refresh_anchors()
	var nearest_index: int = -1
	var nearest_distance: float = INF
	for index: int in range(anchors.size()):
		var anchor: Node3D = anchors[index]
		if anchor == null or not is_instance_valid(anchor):
			continue
		var distance: float = player.global_position.distance_to(anchor.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index
	if nearest_index < 0 or nearest_distance > mount_range:
		status_message = "No climb anchor within reach."
		_show_message(status_message)
		return false
	anchor_index = nearest_index
	is_attached = true
	stamina_accumulator = 0.0
	_set_manipulating(true)
	status_message = "CLIMBING • Move vertically • Jump/Dodge to leap away • Hold Interact to brace"
	traversal_state_changed.emit("climbing")
	_show_message("Grace catches hold of " + _enemy_name() + ".")
	return true


func _process_climb(delta: float) -> void:
	if large_enemy == null or not is_instance_valid(large_enemy):
		detach(Vector3.DOWN, "The climb target is gone.")
		return
	if large_enemy.has_method("can_player_climb") and not bool(large_enemy.call("can_player_climb")):
		detach(Vector3.UP * 3.0 + _away_direction() * 5.0, _enemy_name() + " recovers and throws Grace clear.")
		return
	_refresh_anchors()
	if anchor_index < 0 or anchor_index >= anchors.size():
		detach(Vector3.DOWN, "Grace loses her grip.")
		return
	var vertical_input: float = Input.get_axis("move_back", "move_forward")
	if absf(vertical_input) > 0.25:
		var direction: int = 1 if vertical_input > 0.0 else -1
		var next_index: int = clampi(anchor_index + direction, 0, anchors.size() - 1)
		if next_index != anchor_index:
			var distance: float = anchors[anchor_index].global_position.distance_to(anchors[next_index].global_position)
			if distance <= climb_speed * 1.25:
				anchor_index = next_index
	var target: Vector3 = anchors[anchor_index].global_position + _away_direction() * 0.62
	player.velocity = Vector3.ZERO
	player.global_position = player.global_position.lerp(target, clampf(delta * 12.0, 0.0, 1.0))
	stamina_accumulator += stamina_per_second * maxf(delta, 0.0)
	var spend: int = floori(stamina_accumulator)
	if spend > 0:
		stamina_accumulator -= float(spend)
		if not GameState.spend_stamina(spend):
			detach(Vector3.DOWN * 3.0 + _away_direction() * 2.0, "Grace runs out of stamina and falls.")


func on_large_enemy_shake(strength: float = 1.0) -> void:
	if not is_attached:
		return
	if Input.is_action_pressed("interact"):
		var brace_cost: int = maxi(1, roundi(4.0 * strength))
		if GameState.spend_stamina(brace_cost):
			status_message = "BRACED • The shake drains " + str(brace_cost) + " stamina."
			_show_message(status_message)
			return
	detach(Vector3.UP * (2.5 + strength) + _away_direction() * (6.0 + strength * 2.0), _enemy_name() + " shakes Grace loose!")


func start_enemy_grab(enemy: Node3D) -> void:
	if is_attached:
		detach(Vector3.ZERO, "")
	if is_grabbed:
		return
	large_enemy = enemy
	is_grabbed = true
	grab_timer = grab_escape_seconds
	escape_inputs = 0
	_set_manipulating(true)
	status_message = "GRABBED • Tap Light Attack or Dodge  " + str(escape_inputs_required) + " times!"
	traversal_state_changed.emit("grabbed")
	_show_message(status_message)


func _process_grab(delta: float) -> void:
	if large_enemy == null or not is_instance_valid(large_enemy):
		_release_grab(true)
		return
	grab_timer -= maxf(delta, 0.0)
	var hold_point: Vector3 = large_enemy.global_position + Vector3.UP * 4.7 - large_enemy.global_transform.basis.z * 1.8
	if large_enemy.has_method("get_grab_hold_point"):
		hold_point = large_enemy.call("get_grab_hold_point")
	player.velocity = Vector3.ZERO
	player.global_position = player.global_position.lerp(hold_point, clampf(delta * 14.0, 0.0, 1.0))
	status_message = "GRABBED • ESCAPE " + str(escape_inputs) + " / " + str(escape_inputs_required) + " • " + str(snappedf(grab_timer, 0.1)) + " s"
	if grab_timer <= 0.0:
		var payload := DamagePayload.new()
		payload.amount = 9
		payload.stance_damage = 10
		payload.element = "metal"
		payload.source_name = _enemy_name() + " Crushing Grip"
		payload.hit_type = "enemy_attack"
		payload.tags = ["large_enemy", "grab", "escape_failed"]
		if large_enemy.has_method("get_failed_grab_payload"):
			var custom_payload: Variant = large_enemy.call("get_failed_grab_payload")
			if custom_payload is DamagePayload:
				payload = custom_payload as DamagePayload
		var defense: Node = player.get_node_or_null("PlayerDefenseController")
		if defense != null and defense.has_method("resolve_incoming_attack"):
			defense.call("resolve_incoming_attack", payload, large_enemy)
		else:
			GameState.take_damage(payload.amount)
		_release_grab(false)


func _release_grab(escaped: bool) -> void:
	is_grabbed = false
	_set_manipulating(false)
	player.velocity = Vector3.UP * 4.0 + _away_direction() * (5.0 if escaped else 7.0)
	status_message = "ESCAPED" if escaped else "CRUSHED AND THROWN"
	traversal_state_changed.emit("grounded")
	_show_message("Grace breaks the grip!" if escaped else "The Colossus crushes and throws Grace.")


func detach(impulse: Vector3 = Vector3.ZERO, message: String = "") -> void:
	if not is_attached:
		return
	is_attached = false
	anchor_index = -1
	_set_manipulating(false)
	player.velocity = impulse
	status_message = "Grounded • Interact near a vulnerable anchor to climb."
	traversal_state_changed.emit("grounded")
	if message != "":
		_show_message(message)


func get_state_name() -> String:
	if is_grabbed:
		return "GRABBED"
	if is_attached:
		return "CLIMBING"
	return "GROUNDED"


func get_status_text() -> String:
	return status_message


func _refresh_anchors() -> void:
	anchors.clear()
	if large_enemy == null or not large_enemy.has_method("get_climb_anchors"):
		return
	var anchor_values: Array = large_enemy.call("get_climb_anchors")
	for anchor_value: Variant in anchor_values:
		if anchor_value is Node3D:
			anchors.append(anchor_value as Node3D)


func _away_direction() -> Vector3:
	if player == null or large_enemy == null:
		return Vector3.BACK
	var direction: Vector3 = player.global_position - large_enemy.global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.01:
		direction = -large_enemy.global_transform.basis.z
	return direction.normalized()


func _set_manipulating(active: bool) -> void:
	var action_state: Node = player.get_node_or_null("PlayerActionState")
	if action_state != null:
		action_state.set("is_manipulating", active)


func _enemy_name() -> String:
	if large_enemy == null:
		return "The large enemy"
	if large_enemy.has_method("get_enemy_display_name"):
		return str(large_enemy.call("get_enemy_display_name"))
	var value: Variant = large_enemy.get("display_name")
	if value != null and str(value) != "":
		return str(value)
	return large_enemy.name.capitalize()


func _show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)
	else:
		print(message)
