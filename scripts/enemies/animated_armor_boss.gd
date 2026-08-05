extends CharacterBody3D
class_name AnimatedArmorBoss

enum Judgment {
	NEUTRAL,
	SCARLET,
	AZURE,
	INDIGO,
}

const COLORED_JUDGMENT_ORDER = [
	Judgment.SCARLET,
	Judgment.AZURE,
	Judgment.INDIGO,
]

const JUDGMENT_NAMES: Dictionary = {
	Judgment.NEUTRAL: "neutral",
	Judgment.SCARLET: "scarlet",
	Judgment.AZURE: "azure",
	Judgment.INDIGO: "indigo",
}

const JUDGMENT_COLORS: Dictionary = {
	Judgment.NEUTRAL: Color(0.56, 0.24, 1.0, 1.0),
	Judgment.SCARLET: Color(1.0, 0.17, 0.06, 1.0),
	Judgment.AZURE: Color(0.05, 0.56, 1.0, 1.0),
	Judgment.INDIGO: Color(0.22, 0.16, 1.0, 1.0),
}

const JUDGMENT_WEAKNESSES: Dictionary = {
	Judgment.NEUTRAL: ["fire", "lightning"],
	Judgment.SCARLET: ["water", "ice"],
	Judgment.AZURE: ["lightning", "ice"],
	Judgment.INDIGO: ["earth", "metal"],
}

const JUDGMENT_RESISTANCES: Dictionary = {
	Judgment.NEUTRAL: ["poison", "dreams"],
	Judgment.SCARLET: ["fire", "poison"],
	Judgment.AZURE: ["water", "fire"],
	Judgment.INDIGO: ["lightning", "sound"],
}

@export_group("Identity")
@export var display_name: String = "Animated Armor"
@export var player_group: String = "player"
@export var boss_gate_path: NodePath = NodePath("../BossExitGate")
@export var hit_receiver_path: NodePath = NodePath("HitReceiver")
@export var visual_root_path: NodePath = NodePath("VisualRoot")
@export var windup_marker_path: NodePath = NodePath("WindupMarker")
@export var pulse_marker_path: NodePath = NodePath("PulseMarker")
@export var collision_shape_path: NodePath = NodePath("CollisionShape3D")

@export_group("Baseline Combat")
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
@export var defeat_presentation_duration: float = 1.35

@export_group("Scarlet Judgment")
@export var scarlet_fissure_range: float = 9.0
@export var scarlet_fissure_width: float = 2.2
@export var scarlet_fissure_damage: int = 2
@export var scarlet_fissure_stance_damage: int = 2
@export var scarlet_fissure_windup: float = 1.02
@export var scarlet_move_multiplier: float = 1.28

@export_group("Azure Judgment")
@export var azure_wave_range: float = 8.2
@export_range(60.0, 360.0, 5.0) var azure_wave_arc_degrees: float = 240.0
@export var azure_wave_damage: int = 1
@export var azure_wave_stance_damage: int = 2
@export var azure_wave_windup: float = 1.24
@export var azure_push_speed: float = 7.2
@export var azure_push_seconds: float = 0.42
@export var azure_move_multiplier: float = 0.82

@export_group("Indigo Judgment")
@export var indigo_mark_radius: float = 1.7
@export var indigo_mark_damage: int = 2
@export var indigo_mark_stance_damage: int = 1
@export var indigo_mark_windup: float = 1.34
@export var indigo_preferred_min_range: float = 4.8
@export var indigo_preferred_max_range: float = 10.5
@export var indigo_move_multiplier: float = 0.94

@export_group("Core Break")
@export var stance_transition_recovery: float = 0.82
@export_range(0.1, 0.8, 0.05) var final_phase_health_ratio: float = 0.35
@export_range(0.35, 1.0, 0.05) var final_phase_windup_multiplier: float = 0.72
@export_range(0.25, 1.0, 0.05) var final_phase_cooldown_multiplier: float = 0.58
@export_range(0.5, 1.0, 0.05) var final_phase_recovery_multiplier: float = 0.82
@export_range(1.0, 2.0, 0.05) var final_phase_move_multiplier: float = 1.18

var player: Node3D
var state: String = "idle"
var state_timer: float = 0.0
var cooldown_timer: float = 0.0
var queued_attack: String = "melee"
var next_attack: String = "pulse"
var is_defeated: bool = false

var current_judgment: int = Judgment.NEUTRAL
var previous_judgment: int = Judgment.NEUTRAL
var colored_judgment_index: int = 0
var judgment_awakened: bool = false
var core_exposed: bool = false
var final_phase_active: bool = false
var final_phase_announced: bool = false
var attack_pattern_index: int = 0
var attack_count: int = 0
var signature_attack_count: int = 0
var judgment_change_count: int = 0
var core_break_count: int = 0
var locked_target_position: Vector3 = Vector3.ZERO
var last_attack_hit: bool = false
var last_attack_result: Dictionary = {}
var aura_age: float = 0.0

var judgment_aura: MeshInstance3D
var fissure_marker: MeshInstance3D
var indigo_target_marker: MeshInstance3D

@onready var hit_receiver: Node = get_node_or_null(hit_receiver_path)
@onready var visual_root: Node3D = get_node_or_null(visual_root_path) as Node3D
@onready var windup_marker: MeshInstance3D = (
	get_node_or_null(windup_marker_path) as MeshInstance3D
)
@onready var pulse_marker: MeshInstance3D = (
	get_node_or_null(pulse_marker_path) as MeshInstance3D
)
@onready var collision_shape: CollisionShape3D = (
	get_node_or_null(collision_shape_path) as CollisionShape3D
)


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	add_to_group("prismatic_judgment_boss")
	add_to_group("debuggable")
	_create_prismatic_telegraphs()
	hide_attack_markers()
	_connect_hit_receiver_signals()
	_apply_judgment_profile(false)
	refresh_player()


func _exit_tree() -> void:
	if (
		indigo_target_marker != null
		and is_instance_valid(indigo_target_marker)
		and not indigo_target_marker.is_queued_for_deletion()
	):
		indigo_target_marker.queue_free()


func _physics_process(delta: float) -> void:
	aura_age += delta
	_update_aura_animation()

	if is_defeated:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if GameState.get_stat("health") <= 0:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	refresh_player()
	_update_final_phase()
	update_cooldown(delta)

	if core_exposed or state == "exposed":
		clear_horizontal_velocity()
	elif state == "idle":
		process_idle()
	elif state == "chase":
		process_chase(delta)
	elif state == "windup":
		process_windup(delta)
	elif state == "recover":
		process_recover(delta)
	else:
		state = "idle"

	apply_gravity(delta)
	move_and_slide()


func _connect_hit_receiver_signals() -> void:
	_connect_receiver_signal("health_depleted", "_on_health_depleted")
	_connect_receiver_signal("health_changed", "_on_health_changed")
	_connect_receiver_signal(
		"critical_window_opened",
		"_on_critical_window_opened"
	)
	_connect_receiver_signal(
		"critical_window_closed",
		"_on_critical_window_closed"
	)
	_connect_receiver_signal("critical_struck", "_on_critical_struck")


func _connect_receiver_signal(
	signal_name: StringName,
	method_name: StringName
) -> void:
	if hit_receiver == null or not hit_receiver.has_signal(signal_name):
		return
	var callback := Callable(self, method_name)
	if not hit_receiver.is_connected(signal_name, callback):
		hit_receiver.connect(signal_name, callback)


func refresh_player() -> void:
	if player != null and is_instance_valid(player):
		return
	var found_player: Node = get_tree().get_first_node_in_group(player_group)
	if found_player is Node3D:
		player = found_player as Node3D


func update_cooldown(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer = maxf(cooldown_timer - delta, 0.0)


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
		var chosen_attack: String = choose_next_attack(distance)
		if chosen_attack != "":
			start_attack(chosen_attack)
			return

	move_for_current_judgment()


func choose_next_attack(distance: float) -> String:
	var signature: String = get_signature_attack(current_judgment)
	if (
		final_phase_active
		and previous_judgment != Judgment.NEUTRAL
		and attack_pattern_index % 3 == 2
	):
		var previous_signature: String = get_signature_attack(previous_judgment)
		if can_start_attack(previous_signature, distance):
			return previous_signature

	if attack_pattern_index % 2 == 0 and can_start_attack(signature, distance):
		return signature
	if distance <= melee_range:
		return "melee"
	if current_judgment == Judgment.INDIGO:
		return "indigo_mark"
	if distance <= pulse_range:
		return "pulse"
	if can_start_attack(signature, distance):
		return signature
	return ""


func can_start_attack(attack_name: String, distance: float) -> bool:
	match attack_name:
		"melee":
			return distance <= melee_range
		"pulse":
			return distance <= pulse_range
		"scarlet_fissure":
			return distance <= scarlet_fissure_range
		"azure_wave":
			return distance <= azure_wave_range
		"indigo_mark":
			return distance <= detection_range
		_:
			return false


func get_signature_attack(judgment: int) -> String:
	match judgment:
		Judgment.SCARLET:
			return "scarlet_fissure"
		Judgment.AZURE:
			return "azure_wave"
		Judgment.INDIGO:
			return "indigo_mark"
		_:
			return "pulse"


func start_attack(attack_name: String) -> void:
	if core_exposed or is_defeated:
		return
	queued_attack = attack_name
	state = "windup"
	state_timer = get_attack_windup(attack_name)
	clear_horizontal_velocity()
	if attack_name == "indigo_mark":
		lock_indigo_target()
	show_attack_marker(attack_name)
	begin_visual_windup(attack_name, state_timer)
	attack_pattern_index += 1
	attack_count += 1
	if attack_name in ["scarlet_fissure", "azure_wave", "indigo_mark"]:
		signature_attack_count += 1
	show_message(get_attack_windup_message(attack_name))


func get_attack_windup(attack_name: String) -> float:
	var base_windup: float = melee_windup
	match attack_name:
		"pulse":
			base_windup = pulse_windup
		"scarlet_fissure":
			base_windup = scarlet_fissure_windup
		"azure_wave":
			base_windup = azure_wave_windup
		"indigo_mark":
			base_windup = indigo_mark_windup
		_:
			base_windup = melee_windup
	if final_phase_active:
		base_windup *= final_phase_windup_multiplier
	return maxf(base_windup, 0.1)


func get_attack_windup_message(attack_name: String) -> String:
	match attack_name:
		"melee":
			return display_name + " raises its judgment hammer."
		"pulse":
			return display_name + " opens its core and gathers a violet pulse."
		"scarlet_fissure":
			return "Scarlet Judgment heats the hammer and traces a burning fault."
		"azure_wave":
			return "Azure Judgment opens a sweeping tide around the armor."
		"indigo_mark":
			return "Indigo Judgment fixes a lightning rune beneath Grace."
		_:
			return display_name + " prepares judgment."


func process_windup(delta: float) -> void:
	clear_horizontal_velocity()
	face_player(delta)
	update_visual_windup()
	update_attack_telegraph()
	state_timer -= delta

	if state_timer <= 0.0:
		perform_attack()
		state = "recover"
		state_timer = get_effective_recovery_time()
		cooldown_timer = get_effective_attack_cooldown()
		next_attack = "pulse" if queued_attack == "melee" else "melee"
		hide_attack_markers()


func process_recover(delta: float) -> void:
	clear_horizontal_velocity()
	state_timer -= delta
	if state_timer <= 0.0:
		clear_visual_attack_pose()
		state = "chase"


func get_effective_recovery_time() -> float:
	var result: float = recovery_time
	if final_phase_active:
		result *= final_phase_recovery_multiplier
	return maxf(result, 0.1)


func get_effective_attack_cooldown() -> float:
	var result: float = attack_cooldown
	if final_phase_active:
		result *= final_phase_cooldown_multiplier
	return maxf(result, 0.08)


func perform_attack() -> void:
	if core_exposed or is_defeated:
		return
	release_visual_attack(queued_attack)
	match queued_attack:
		"pulse":
			perform_pulse_attack()
		"scarlet_fissure":
			perform_scarlet_fissure()
		"azure_wave":
			perform_azure_wave()
		"indigo_mark":
			perform_indigo_mark()
		_:
			perform_melee_attack()


func perform_melee_attack() -> void:
	if player == null:
		return
	if get_distance_to_player() > melee_range:
		last_attack_hit = false
		show_message(display_name + " slams the stone, but Grace is clear.")
		return
	var payload := _make_attack_payload(
		melee_damage,
		2,
		"metal",
		"Judgment Hammer",
		"melee",
		["boss", "physical", "weapon", "melee", "hammer"]
	)
	_deliver_attack_payload(payload)


func perform_pulse_attack() -> void:
	if player == null:
		return
	if get_distance_to_player() > pulse_range:
		last_attack_hit = false
		show_message(display_name + " releases a pulse into empty air.")
		return
	var payload := _make_attack_payload(
		pulse_damage,
		1,
		"space",
		"Violet Judgment Pulse",
		"magic",
		["boss", "magic", "area", "pulse", "space"]
	)
	_deliver_attack_payload(payload)


func perform_scarlet_fissure() -> void:
	if player == null:
		return
	if not is_position_inside_scarlet_fissure(player.global_position):
		last_attack_hit = false
		show_message("The scarlet fault erupts past Grace.")
		return
	var payload := _make_attack_payload(
		scarlet_fissure_damage,
		scarlet_fissure_stance_damage,
		"fire",
		"Scarlet Judgment Fissure",
		"magic",
		["boss", "magic", "line", "fire", "fissure"]
	)
	_deliver_attack_payload(payload)


func perform_azure_wave() -> void:
	if player == null:
		return
	if not is_position_inside_azure_wave(player.global_position):
		last_attack_hit = false
		show_message("Grace slips through the opening in the azure sweep.")
		return
	var payload := _make_attack_payload(
		azure_wave_damage,
		azure_wave_stance_damage,
		"water",
		"Azure Judgment Wave",
		"magic",
		["boss", "magic", "area", "water", "wave"]
	)
	_deliver_attack_payload(
		payload,
		azure_push_speed,
		azure_push_seconds
	)


func perform_indigo_mark() -> void:
	if player == null:
		return
	if not is_position_inside_indigo_mark(player.global_position):
		last_attack_hit = false
		show_message("Indigo lightning strikes the abandoned rune.")
		return
	var payload := _make_attack_payload(
		indigo_mark_damage,
		indigo_mark_stance_damage,
		"lightning",
		"Indigo Judgment Mark",
		"magic",
		["boss", "magic", "targeted", "lightning", "delayed"]
	)
	_deliver_attack_payload(payload)


func _make_attack_payload(
	damage: int,
	stance_damage: int,
	element: String,
	source_name: String,
	hit_type: String,
	tags: Array
) -> DamagePayload:
	var payload := DamagePayload.new()
	payload.amount = maxi(damage, 0)
	payload.stance_damage = maxi(stance_damage, 0)
	payload.element = element
	payload.source_name = source_name
	payload.hit_type = hit_type
	payload.tags.clear()
	for tag_value: Variant in tags:
		payload.tags.append(str(tag_value))
	return payload


func _deliver_attack_payload(
	payload: DamagePayload,
	push_speed: float = 0.0,
	push_seconds: float = 0.0
) -> Dictionary:
	last_attack_hit = false
	last_attack_result.clear()
	if payload == null or player == null:
		return last_attack_result

	var health_before: int = GameState.get_stat("health")
	var defense: Node = player.get_node_or_null("PlayerDefenseController")
	if defense != null and defense.has_method("resolve_incoming_attack"):
		var result_value: Variant = defense.call(
			"resolve_incoming_attack",
			payload,
			self
		)
		if result_value is Dictionary:
			last_attack_result = (result_value as Dictionary).duplicate(true)
	else:
		GameState.take_damage(payload.amount)
		last_attack_result = {
			"outcome": "hit",
			"source": payload.source_name,
			"damage": payload.amount,
		}

	var outcome: String = str(last_attack_result.get("outcome", "hit"))
	last_attack_hit = (
		GameState.get_stat("health") < health_before
		or outcome in ["hit", "blocked", "guard_broken"]
	)

	var push_blocked: bool = outcome in [
		"dodged",
		"perfect_guard",
		"elemental_authority",
		"divine_special_fire_immunity",
	]
	if (
		push_speed > 0.0
		and push_seconds > 0.0
		and defense != null
		and defense.has_method("start_hit_reaction")
		and not push_blocked
	):
		var push_direction: Vector3 = player.global_position - global_position
		push_direction.y = 0.0
		if push_direction.length() > 0.01:
			defense.call(
				"start_hit_reaction",
				push_direction.normalized(),
				push_seconds,
				push_speed
			)

	if last_attack_hit:
		show_message(payload.source_name + " reaches Grace.")
	return last_attack_result


func is_position_inside_scarlet_fissure(
	world_position: Vector3
) -> bool:
	var offset: Vector3 = world_position - global_position
	offset.y = 0.0
	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	var right: Vector3 = global_transform.basis.x
	right.y = 0.0
	if forward.length() <= 0.01 or right.length() <= 0.01:
		return false
	forward = forward.normalized()
	right = right.normalized()
	var forward_distance: float = offset.dot(forward)
	var lateral_distance: float = absf(offset.dot(right))
	return (
		forward_distance >= -0.4
		and forward_distance <= scarlet_fissure_range
		and lateral_distance <= scarlet_fissure_width * 0.5
	)


func is_position_inside_azure_wave(world_position: Vector3) -> bool:
	var offset: Vector3 = world_position - global_position
	offset.y = 0.0
	var distance: float = offset.length()
	if distance > azure_wave_range:
		return false
	if distance <= 0.01:
		return true
	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	if forward.length() <= 0.01:
		return true
	var minimum_dot: float = cos(
		deg_to_rad(azure_wave_arc_degrees * 0.5)
	)
	return forward.normalized().dot(offset.normalized()) >= minimum_dot


func lock_indigo_target() -> void:
	if player == null:
		locked_target_position = global_position
	else:
		locked_target_position = player.global_position
		locked_target_position.y -= 0.9
	if indigo_target_marker != null:
		indigo_target_marker.global_position = locked_target_position


func is_position_inside_indigo_mark(world_position: Vector3) -> bool:
	var offset: Vector3 = world_position - locked_target_position
	offset.y = 0.0
	return offset.length() <= indigo_mark_radius


func move_for_current_judgment() -> void:
	if player == null:
		clear_horizontal_velocity()
		return

	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	var distance: float = to_player.length()
	if distance <= 0.01:
		clear_horizontal_velocity()
		return

	var direction: Vector3 = to_player.normalized()
	var speed: float = get_effective_move_speed()

	match current_judgment:
		Judgment.INDIGO:
			if distance < indigo_preferred_min_range:
				direction = -direction
			elif distance <= indigo_preferred_max_range:
				var strafe_sign: float = (
					-1.0
					if attack_pattern_index % 2 == 0
					else 1.0
				)
				direction = direction.cross(Vector3.UP) * strafe_sign
				speed *= 0.58
		Judgment.AZURE:
			if distance <= 4.8:
				clear_horizontal_velocity()
				return
		_:
			pass

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed


func get_effective_move_speed() -> float:
	var result: float = move_speed
	match current_judgment:
		Judgment.SCARLET:
			result *= scarlet_move_multiplier
		Judgment.AZURE:
			result *= azure_move_multiplier
		Judgment.INDIGO:
			result *= indigo_move_multiplier
		_:
			pass
	if final_phase_active:
		result *= final_phase_move_multiplier
	return result


func face_player(delta: float) -> void:
	if player == null:
		return
	var direction: Vector3 = player.global_position - global_position
	direction.y = 0.0
	if direction.length() <= 0.01:
		return
	var target_angle: float = atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(
		rotation.y,
		target_angle,
		clampf(turn_speed * delta, 0.0, 1.0)
	)


func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1


func clear_horizontal_velocity() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func get_distance_to_player() -> float:
	if player == null:
		return INF
	return global_position.distance_to(player.global_position)


func _create_prismatic_telegraphs() -> void:
	judgment_aura = MeshInstance3D.new()
	judgment_aura.name = "JudgmentAura"
	var aura_mesh := TorusMesh.new()
	aura_mesh.inner_radius = 1.65
	aura_mesh.outer_radius = 1.92
	aura_mesh.rings = 32
	aura_mesh.ring_segments = 10
	judgment_aura.mesh = aura_mesh
	judgment_aura.position = Vector3(0.0, 0.12, 0.0)
	judgment_aura.scale = Vector3(1.0, 0.08, 1.0)
	add_child(judgment_aura)

	fissure_marker = MeshInstance3D.new()
	fissure_marker.name = "ScarletFissureMarker"
	var fissure_mesh := BoxMesh.new()
	fissure_mesh.size = Vector3(
		scarlet_fissure_width,
		0.055,
		scarlet_fissure_range
	)
	fissure_marker.mesh = fissure_mesh
	fissure_marker.position = Vector3(
		0.0,
		0.13,
		-scarlet_fissure_range * 0.5
	)
	fissure_marker.visible = false
	add_child(fissure_marker)

	indigo_target_marker = MeshInstance3D.new()
	indigo_target_marker.name = "IndigoTargetMarker"
	var target_mesh := TorusMesh.new()
	target_mesh.inner_radius = indigo_mark_radius * 0.72
	target_mesh.outer_radius = indigo_mark_radius
	target_mesh.rings = 32
	target_mesh.ring_segments = 10
	indigo_target_marker.mesh = target_mesh
	indigo_target_marker.scale = Vector3(1.0, 0.08, 1.0)
	indigo_target_marker.visible = false
	var marker_parent: Node = get_parent()
	if marker_parent != null:
		marker_parent.add_child(indigo_target_marker)
	else:
		add_child(indigo_target_marker)

	_apply_marker_color(get_judgment_color())


func _update_aura_animation() -> void:
	if judgment_aura == null:
		return
	var pulse_amount: float = 0.055 if not core_exposed else 0.12
	var pulse_speed: float = 2.2 if not final_phase_active else 3.6
	var pulse: float = 1.0 + sin(aura_age * pulse_speed) * pulse_amount
	if core_exposed:
		pulse += 0.28
	judgment_aura.scale = Vector3(pulse, 0.08, pulse)
	judgment_aura.rotation.y = aura_age * (
		0.35 if not final_phase_active else 0.62
	)


func show_attack_marker(attack_name: String) -> void:
	hide_attack_markers()
	var attack_color: Color = get_attack_color(attack_name)
	_apply_marker_color(attack_color)
	if windup_marker != null:
		windup_marker.visible = true
	if attack_name in ["pulse", "azure_wave"] and pulse_marker != null:
		pulse_marker.visible = true
		pulse_marker.scale = Vector3.ONE
	if attack_name == "scarlet_fissure" and fissure_marker != null:
		fissure_marker.visible = true
	if attack_name == "indigo_mark" and indigo_target_marker != null:
		indigo_target_marker.visible = true
		indigo_target_marker.global_position = locked_target_position


func update_attack_telegraph() -> void:
	var total_windup: float = get_attack_windup(queued_attack)
	var progress: float = 1.0 - clampf(
		state_timer / maxf(total_windup, 0.01),
		0.0,
		1.0
	)
	if windup_marker != null and windup_marker.visible:
		var windup_pulse: float = 1.0 + sin(aura_age * 15.0) * 0.12
		windup_marker.scale = Vector3.ONE * windup_pulse
	if pulse_marker != null and pulse_marker.visible:
		var grow: float = 1.0 + progress * (
			1.2 if queued_attack == "azure_wave" else 0.78
		)
		pulse_marker.scale = Vector3(grow, 1.0, grow)
	if fissure_marker != null and fissure_marker.visible:
		fissure_marker.scale = Vector3(
			0.25 + progress * 0.75,
			1.0,
			maxf(progress, 0.08)
		)
	if indigo_target_marker != null and indigo_target_marker.visible:
		var target_pulse: float = 0.84 + progress * 0.28
		indigo_target_marker.scale = Vector3(
			target_pulse,
			0.08,
			target_pulse
		)


func hide_attack_markers() -> void:
	if windup_marker != null:
		windup_marker.visible = false
	if pulse_marker != null:
		pulse_marker.visible = false
	if fissure_marker != null:
		fissure_marker.visible = false
	if indigo_target_marker != null:
		indigo_target_marker.visible = false


func _apply_marker_color(color: Color) -> void:
	var aura_color: Color = (
		Color(1.0, 0.82, 0.28, 1.0)
		if core_exposed
		else color
	)
	if judgment_aura != null:
		judgment_aura.material_override = _make_glow_material(
			aura_color,
			0.48,
			2.4 if not final_phase_active else 3.4
		)
	var marker_material: StandardMaterial3D = _make_glow_material(
		color,
		0.42,
		3.2
	)
	if windup_marker != null:
		windup_marker.material_override = marker_material
	if pulse_marker != null:
		pulse_marker.material_override = marker_material
	if fissure_marker != null:
		fissure_marker.material_override = marker_material
	if indigo_target_marker != null:
		indigo_target_marker.material_override = marker_material


func _make_glow_material(
	color: Color,
	alpha: float,
	energy: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var transparent_color := color
	transparent_color.a = alpha
	material.albedo_color = transparent_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func get_attack_color(attack_name: String) -> Color:
	var judgment: int = current_judgment
	match attack_name:
		"scarlet_fissure":
			judgment = Judgment.SCARLET
		"azure_wave":
			judgment = Judgment.AZURE
		"indigo_mark":
			judgment = Judgment.INDIGO
		_:
			return get_judgment_color()
	var color_value: Variant = JUDGMENT_COLORS.get(
		judgment,
		get_judgment_color()
	)
	return color_value as Color


func get_judgment_color() -> Color:
	var color_value: Variant = JUDGMENT_COLORS.get(
		current_judgment,
		Color(0.56, 0.24, 1.0, 1.0)
	)
	return color_value as Color


func get_judgment_name(judgment: int = -1) -> String:
	var resolved: int = current_judgment if judgment < 0 else judgment
	return str(JUDGMENT_NAMES.get(resolved, "neutral"))


func set_judgment_stance(
	next_judgment: int,
	reason: String = "judgment_cycle",
	announce: bool = true
) -> void:
	var resolved: int = clampi(
		next_judgment,
		Judgment.NEUTRAL,
		Judgment.INDIGO
	)
	if resolved != current_judgment:
		previous_judgment = current_judgment
		current_judgment = resolved
		judgment_change_count += 1
	attack_pattern_index = 0
	_apply_judgment_profile(announce)
	if announce:
		show_message(
			get_judgment_name().capitalize()
			+ " Judgment takes command of the armor. "
			+ get_judgment_counter_hint()
		)
	last_attack_result = {
		"reason": reason,
		"judgment": get_judgment_name(),
	}


func _apply_judgment_profile(announce: bool = false) -> void:
	if hit_receiver != null:
		var weak_elements: Array[String] = []
		var resistant_elements: Array[String] = []
		if not core_exposed:
			for weak_value: Variant in JUDGMENT_WEAKNESSES.get(
				current_judgment,
				[]
			):
				weak_elements.append(str(weak_value))
			for resistant_value: Variant in JUDGMENT_RESISTANCES.get(
				current_judgment,
				[]
			):
				resistant_elements.append(str(resistant_value))
		hit_receiver.set("weak_elements", weak_elements)
		hit_receiver.set("resistant_elements", resistant_elements)
		hit_receiver.set("immune_elements", [])
		if hit_receiver.has_method("refresh_overhead_hud"):
			hit_receiver.call("refresh_overhead_hud")

	var color: Color = get_judgment_color()
	_apply_marker_color(color)
	if visual_root != null and visual_root.has_method(
		"set_judgment_state"
	):
		visual_root.call(
			"set_judgment_state",
			get_judgment_name(),
			color,
			core_exposed
		)
	if announce and final_phase_active:
		_apply_marker_color(color)


func get_judgment_counter_hint() -> String:
	match current_judgment:
		Judgment.SCARLET:
			return "Water and Ice bite through the heated shell."
		Judgment.AZURE:
			return "Lightning and Ice fracture the flowing guard."
		Judgment.INDIGO:
			return "Earth and Metal ground the lightning shell."
		_:
			return "Fire and Lightning test its neutral shell."


func advance_judgment_after_core() -> void:
	judgment_awakened = true
	var next_judgment: int = int(
		COLORED_JUDGMENT_ORDER[colored_judgment_index]
	)
	colored_judgment_index = (
		(colored_judgment_index + 1)
		% COLORED_JUDGMENT_ORDER.size()
	)
	set_judgment_stance(
		next_judgment,
		"core_reformed",
		true
	)


func _on_critical_window_opened(duration: float) -> void:
	if is_defeated:
		return
	core_break_count += 1
	core_exposed = true
	state = "exposed"
	state_timer = maxf(duration, 0.1)
	cooldown_timer = 0.0
	clear_horizontal_velocity()
	hide_attack_markers()
	_apply_judgment_profile(false)
	if visual_root != null and visual_root.has_method("set_core_exposed"):
		visual_root.call("set_core_exposed", true)
	show_message(
		"The "
		+ get_judgment_name().capitalize()
		+ " shell breaks. The violet core is exposed."
	)


func _on_critical_window_closed() -> void:
	if is_defeated:
		return
	core_exposed = false
	if visual_root != null and visual_root.has_method("set_core_exposed"):
		visual_root.call("set_core_exposed", false)
	advance_judgment_after_core()
	state = "recover"
	state_timer = stance_transition_recovery
	cooldown_timer = get_effective_attack_cooldown()


func _on_critical_struck(damage: int) -> void:
	if damage > 0:
		show_message(
			"Critical strike! "
			+ str(damage)
			+ " damage tears through the exposed core."
		)


func _on_health_changed(
	current_health: int,
	maximum_health: int
) -> void:
	_update_final_phase(current_health, maximum_health)


func _update_final_phase(
	current_health: int = -1,
	maximum_health: int = -1
) -> void:
	if hit_receiver == null or final_phase_active:
		return
	var resolved_current: int = (
		int(hit_receiver.get("current_health"))
		if current_health < 0
		else current_health
	)
	var resolved_maximum: int = (
		int(hit_receiver.get("max_health"))
		if maximum_health <= 0
		else maximum_health
	)
	if resolved_maximum <= 0:
		return
	var health_ratio: float = (
		float(resolved_current) / float(resolved_maximum)
	)
	if health_ratio > final_phase_health_ratio:
		return
	final_phase_active = true
	_apply_judgment_profile(false)
	if not final_phase_announced:
		final_phase_announced = true
		show_message(
			"The judgment core fractures into its final cadence. "
			+ "Old colors now bleed into the current stance."
		)


func begin_visual_windup(
	attack_name: String,
	duration: float
) -> void:
	if visual_root != null and visual_root.has_method(
		"begin_attack_windup"
	):
		visual_root.call(
			"begin_attack_windup",
			attack_name,
			duration
		)


func update_visual_windup() -> void:
	if visual_root == null or not visual_root.has_method(
		"update_attack_windup"
	):
		return
	var total_windup: float = get_attack_windup(queued_attack)
	var progress: float = 1.0 - clampf(
		state_timer / maxf(total_windup, 0.01),
		0.0,
		1.0
	)
	visual_root.call(
		"update_attack_windup",
		queued_attack,
		progress
	)


func release_visual_attack(attack_name: String) -> void:
	if visual_root != null and visual_root.has_method(
		"play_attack_release"
	):
		visual_root.call("play_attack_release", attack_name)


func clear_visual_attack_pose() -> void:
	if visual_root != null and visual_root.has_method(
		"clear_attack_pose"
	):
		visual_root.call("clear_attack_pose")


func _on_health_depleted() -> void:
	if is_defeated:
		return

	is_defeated = true
	core_exposed = false
	remove_from_group("enemy")
	remove_from_group("boss")
	clear_horizontal_velocity()
	hide_attack_markers()
	set_physics_process(false)

	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

	if visual_root != null and visual_root.has_method("play_defeat"):
		visual_root.call(
			"play_defeat",
			defeat_presentation_duration
		)

	show_message(
		display_name
		+ " collapses as its prismatic judgment core goes dark. "
		+ "The final gate opens."
	)
	unlock_boss_gate()

	await get_tree().create_timer(
		defeat_presentation_duration
	).timeout

	if is_inside_tree():
		queue_free()


func unlock_boss_gate() -> void:
	var boss_gate: Node = get_node_or_null(boss_gate_path)
	if boss_gate != null and boss_gate.has_method("unlock"):
		boss_gate.call("unlock")


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	var weak_elements: Variant = []
	var resistant_elements: Variant = []
	var current_health: int = 0
	var maximum_health: int = 0
	var current_stance: int = 0
	var maximum_stance: int = 0
	if hit_receiver != null:
		weak_elements = hit_receiver.get("weak_elements")
		resistant_elements = hit_receiver.get("resistant_elements")
		current_health = int(hit_receiver.get("current_health"))
		maximum_health = int(hit_receiver.get("max_health"))
		current_stance = int(hit_receiver.get("current_stance"))
		maximum_stance = int(hit_receiver.get("max_stance"))
	return {
		"boss": display_name,
		"state": state,
		"attack": queued_attack,
		"next": next_attack,
		"cooldown": snappedf(cooldown_timer, 0.01),
		"defeated": is_defeated,
		"judgment": get_judgment_name(),
		"previous_judgment": get_judgment_name(previous_judgment),
		"judgment_awakened": judgment_awakened,
		"judgment_changes": judgment_change_count,
		"core_exposed": core_exposed,
		"core_breaks": core_break_count,
		"final_phase": final_phase_active,
		"attack_count": attack_count,
		"signature_attacks": signature_attack_count,
		"last_attack_hit": last_attack_hit,
		"last_attack_result": last_attack_result.duplicate(true),
		"locked_target_position": locked_target_position,
		"weak_elements": weak_elements,
		"resistant_elements": resistant_elements,
		"health": str(current_health) + "/" + str(maximum_health),
		"stance": str(current_stance) + "/" + str(maximum_stance),
	}
