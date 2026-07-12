extends CharacterBody3D

@export var display_name: String = "Animated Armor"
@export var player_group: String = "player"
@export var boss_gate_path: NodePath = NodePath("../BossExitGate")
@export var hit_receiver_path: NodePath = NodePath("HitReceiver")
@export var visual_root_path: NodePath = NodePath("VisualRoot")
@export var windup_marker_path: NodePath = NodePath("WindupMarker")
@export var pulse_marker_path: NodePath = NodePath("PulseMarker")

@export var move_speed: float = 2.1
@export var turn_speed: float = 6.0
@export var gravity: float = 18.0
@export var detection_range: float = 18.0
@export var melee_range: float = 2.55
@export var pulse_range: float = 7.0
@export var melee_damage: int = 2
@export var pulse_damage: int = 1
@export var melee_windup: float = 0.82
@export var pulse_windup: float = 1.18
@export var recovery_time: float = 0.72
@export var attack_cooldown: float = 0.55
@export var death_reward_mana: int = 3

var player: Node3D
var state: String = "idle"
var state_timer: float = 0.0
var cooldown_timer: float = 0.0
var queued_attack: String = "melee"
var next_attack: String = "pulse"
var is_defeated: bool = false

@onready var hit_receiver: Node = get_node_or_null(hit_receiver_path)
@onready var visual_root: Node3D = get_node_or_null(visual_root_path) as Node3D
@onready var windup_marker: Node3D = get_node_or_null(windup_marker_path) as Node3D
@onready var pulse_marker: Node3D = get_node_or_null(pulse_marker_path) as Node3D


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	add_to_group("debuggable")
	hide_attack_markers()
	connect_health_depleted()


func _physics_process(delta: float) -> void:
	if is_defeated:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if GameState.get_stat("health") <= 0:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	refresh_player()
	update_cooldown(delta)

	match state:
		"idle":
			process_idle()
		"chase":
			process_chase(delta)
		"windup":
			process_windup(delta)
		"recover":
			process_recover(delta)
		_:
			state = "idle"

	apply_gravity(delta)
	move_and_slide()


func connect_health_depleted() -> void:
	if hit_receiver == null:
		return

	if not hit_receiver.has_signal("health_depleted"):
		return

	var callback: Callable = Callable(self, "_on_health_depleted")

	if not hit_receiver.health_depleted.is_connected(callback):
		hit_receiver.health_depleted.connect(callback)


func refresh_player() -> void:
	if player != null and is_instance_valid(player):
		return

	var found_player: Node = get_tree().get_first_node_in_group(player_group)

	if found_player is Node3D:
		player = found_player as Node3D


func update_cooldown(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta


func process_idle() -> void:
	clear_horizontal_velocity()

	if player == null:
		return

	if get_distance_to_player() <= detection_range:
		state = "chase"


func process_chase(delta: float) -> void:
	if player == null:
		state = "idle"
		return

	var distance: float = get_distance_to_player()

	if distance > detection_range:
		state = "idle"
		return

	face_player(delta)

	if cooldown_timer <= 0.0:
		if next_attack == "pulse" and distance <= pulse_range:
			start_attack("pulse")
			return

		if distance <= melee_range:
			start_attack("melee")
			return

	move_toward_player(delta)


func start_attack(attack_name: String) -> void:
	queued_attack = attack_name
	state = "windup"
	state_timer = melee_windup if attack_name == "melee" else pulse_windup
	clear_horizontal_velocity()
	show_attack_marker(attack_name)

	if attack_name == "melee":
		show_message(display_name + " raises its hammer.")
	else:
		show_message(display_name + " gathers a blue magic pulse.")


func process_windup(delta: float) -> void:
	clear_horizontal_velocity()
	face_player(delta)
	pulse_windup_marker(delta)
	state_timer -= delta

	if state_timer <= 0.0:
		perform_attack()
		state = "recover"
		state_timer = recovery_time
		cooldown_timer = attack_cooldown
		next_attack = "pulse" if queued_attack == "melee" else "melee"
		hide_attack_markers()


func process_recover(delta: float) -> void:
	clear_horizontal_velocity()
	state_timer -= delta

	if state_timer <= 0.0:
		state = "chase"


func perform_attack() -> void:
	if queued_attack == "pulse":
		perform_pulse_attack()
		return

	perform_melee_attack()


func perform_melee_attack() -> void:
	if player == null:
		return

	if get_distance_to_player() > melee_range:
		show_message(display_name + " slams the stone, but Grace is clear.")
		return

	GameState.take_damage(melee_damage)
	show_message(display_name + " lands a heavy hammer slam.")


func perform_pulse_attack() -> void:
	if player == null:
		return

	if get_distance_to_player() > pulse_range:
		show_message(display_name + " releases a pulse into empty air.")
		return

	GameState.take_damage(pulse_damage)
	show_message(display_name + " releases a magic pulse.")


func move_toward_player(_delta: float) -> void:
	if player == null:
		clear_horizontal_velocity()
		return

	var direction: Vector3 = player.global_position - global_position
	direction.y = 0.0

	if direction.length() <= 0.01:
		clear_horizontal_velocity()
		return

	direction = direction.normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed


func face_player(delta: float) -> void:
	if player == null:
		return

	var direction: Vector3 = player.global_position - global_position
	direction.y = 0.0

	if direction.length() <= 0.01:
		return

	var target_angle: float = atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_angle, clamp(turn_speed * delta, 0.0, 1.0))


func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if velocity.y < 0.0:
			velocity.y = -0.1


func clear_horizontal_velocity() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func get_distance_to_player() -> float:
	if player == null:
		return INF

	return global_position.distance_to(player.global_position)


func show_attack_marker(attack_name: String) -> void:
	hide_attack_markers()

	if windup_marker != null:
		windup_marker.visible = true

	if attack_name == "pulse" and pulse_marker != null:
		pulse_marker.visible = true
		pulse_marker.scale = Vector3.ONE


func pulse_windup_marker(delta: float) -> void:
	if visual_root != null:
		visual_root.rotation.y += delta * 0.9

	if pulse_marker != null and pulse_marker.visible:
		var grow: float = 1.0 + (pulse_windup - max(state_timer, 0.0)) * 0.65
		pulse_marker.scale = Vector3(grow, 1.0, grow)


func hide_attack_markers() -> void:
	if windup_marker != null:
		windup_marker.visible = false

	if pulse_marker != null:
		pulse_marker.visible = false


func _on_health_depleted() -> void:
	if is_defeated:
		return

	is_defeated = true
	remove_from_group("enemy")
	remove_from_group("boss")
	clear_horizontal_velocity()
	hide_attack_markers()

	if death_reward_mana > 0:
		GameState.restore_mana(death_reward_mana)

	show_message(display_name + " collapses. The final gate opens.")
	unlock_boss_gate()
	queue_free()


func unlock_boss_gate() -> void:
	var boss_gate: Node = get_node_or_null(boss_gate_path)

	if boss_gate != null and boss_gate.has_method("unlock"):
		boss_gate.unlock()


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	return {
		"boss": display_name,
		"state": state,
		"attack": queued_attack,
		"next": next_attack,
		"cooldown": cooldown_timer,
		"defeated": is_defeated,
	}
