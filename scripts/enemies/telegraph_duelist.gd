extends CharacterBody3D
class_name TelegraphDuelist

signal phase_changed(data: Dictionary)
signal attack_resolved(data: Dictionary)

const PHASE_IDLE := "IDLE"
const PHASE_WINDUP := "WINDUP"
const PHASE_ACTIVE := "ACTIVE"
const PHASE_RECOVERY := "RECOVERY"
const PHASE_STAGGERED := "STAGGERED"

@export var attack_interval: float = 0.85
@export var engagement_range: float = 8.0

var phase: String = PHASE_IDLE
var phase_timer: float = 1.1
var attack_index: int = 0
var current_attack: Dictionary = {}
var attack_heading: Vector3 = Vector3.FORWARD
var hit_applied: bool = false
var counter_window_remaining: float = 0.0
var last_result: String = "WAITING"
var total_attacks: int = 0
var total_interrupts: int = 0
var home_position: Vector3

var visual_root: Node3D
var body_material: StandardMaterial3D
var weapon_pivot: Node3D
var indicator: MeshInstance3D
var indicator_material: StandardMaterial3D
var phase_label: Label3D
var reaction_tween: Tween
var player: CharacterBody3D


func _ready() -> void:
	home_position = global_position
	add_to_group("enemy")
	add_to_group("combat_targetable")
	add_to_group("lab_resettable")
	_build_collision()
	_build_visual()
	call_deferred("_find_player")


func _physics_process(delta: float) -> void:
	counter_window_remaining = maxf(counter_window_remaining - delta, 0.0)
	phase_timer = maxf(phase_timer - delta, 0.0)
	_update_phase_visual(delta)
	match phase:
		PHASE_IDLE:
			if phase_timer <= 0.0 and _can_attack_player():
				_start_next_attack()
		PHASE_WINDUP:
			if phase_timer <= 0.0:
				_begin_active_phase()
		PHASE_ACTIVE:
			if not hit_applied:
				hit_applied = true
				_execute_attack()
			if phase_timer <= 0.0:
				_set_phase(PHASE_RECOVERY, float(current_attack.get("recovery", 0.5)))
		PHASE_RECOVERY, PHASE_STAGGERED:
			if phase_timer <= 0.0:
				current_attack = {}
				_set_phase(PHASE_IDLE, attack_interval)
	velocity = Vector3.ZERO
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	move_and_slide()


func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D


func _can_attack_player() -> bool:
	if player == null or not is_instance_valid(player):
		_find_player()
	return player != null and global_position.distance_to(player.global_position) <= engagement_range


func _start_next_attack() -> void:
	var profiles: Array[Dictionary] = _get_attack_profiles()
	current_attack = profiles[attack_index % profiles.size()].duplicate(true)
	attack_index = (attack_index + 1) % profiles.size()
	hit_applied = false
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	attack_heading = to_player.normalized() if to_player.length_squared() > 0.001 else -global_transform.basis.z
	look_at(global_position + attack_heading, Vector3.UP)
	_configure_indicator()
	_set_phase(PHASE_WINDUP, float(current_attack.get("windup", 0.6)))


func _begin_active_phase() -> void:
	_set_phase(PHASE_ACTIVE, float(current_attack.get("active", 0.12)))


func _execute_attack() -> void:
	total_attacks += 1
	if player == null or not _player_inside_attack():
		last_result = "MISS"
		attack_resolved.emit(get_debug_data())
		return
	var payload := DamagePayload.new()
	payload.amount = int(current_attack.get("damage", 7))
	payload.stance_damage = int(current_attack.get("stance", 5))
	payload.knockback_strength = float(current_attack.get("knockback", 3.0))
	payload.source_name = str(current_attack.get("name", "Telegraphed Strike"))
	payload.hit_type = "enemy_attack"
	payload.tags = ["physical", "enemy", "telegraphed"]
	var resolver: PlayerPerfectDodgeController = player.get_node_or_null("PlayerPerfectDodgeController") as PlayerPerfectDodgeController
	var result: Dictionary = {}
	if resolver != null:
		result = resolver.resolve_telegraphed_attack(payload, self)
	else:
		var defense := player.get_node_or_null("PlayerDefenseController") as PlayerDefenseController
		if defense != null:
			result = defense.resolve_incoming_attack(payload, self)
	last_result = str(result.get("outcome", "HIT")).to_upper()
	attack_resolved.emit(get_debug_data())


func _player_inside_attack() -> bool:
	var offset: Vector3 = player.global_position - global_position
	offset.y = 0.0
	var distance: float = offset.length()
	if distance > float(current_attack.get("range", 3.0)):
		return false
	var minimum_dot: float = float(current_attack.get("minimum_dot", -1.0))
	if minimum_dot <= -0.99 or distance <= 0.01:
		return true
	return attack_heading.dot(offset.normalized()) >= minimum_dot


func grant_counter_window(duration: float) -> void:
	counter_window_remaining = maxf(counter_window_remaining, duration)
	last_result = "COUNTER OPEN"
	_update_material()


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	if payload == null:
		return {}
	return {
		"message": str(current_attack.get("name", "Duelist")) + " takes " + str(payload.amount) + " damage.",
		"objective": "",
	}


func receive_weapon_impact(_payload: DamagePayload, direction: Vector3, _attack: WeaponAttackDefinition) -> void:
	var vulnerable_windup: bool = phase == PHASE_WINDUP and not bool(current_attack.get("committed", false))
	if counter_window_remaining > 0.0 or vulnerable_windup or phase == PHASE_RECOVERY:
		total_interrupts += 1
		last_result = "INTERRUPTED"
		counter_window_remaining = 0.0
		_play_reaction(direction, 18.0)
		_set_phase(PHASE_STAGGERED, 0.72)
		_show_world_text("INTERRUPT", Color(0.45, 0.88, 1.0))
	else:
		last_result = "SUPER ARMOR"
		_play_reaction(direction, 3.0)
		_show_world_text("SUPER ARMOR", Color(1.0, 0.32, 0.16))


func force_attack(next_index: int) -> void:
	attack_index = posmod(next_index, _get_attack_profiles().size())
	current_attack = {}
	_set_phase(PHASE_IDLE, 0.08)


func _get_attack_profiles() -> Array[Dictionary]:
	return [
		{
			"name": "Wide Sweep", "windup": 0.62, "active": 0.14, "recovery": 0.58,
			"range": 3.25, "minimum_dot": -1.0, "damage": 6, "stance": 4,
			"shape": "circle", "color": Color(1.0, 0.48, 0.12), "committed": false,
		},
		{
			"name": "Overhead Crush", "windup": 0.82, "active": 0.12, "recovery": 0.78,
			"range": 2.65, "minimum_dot": 0.35, "damage": 10, "stance": 8,
			"shape": "wedge", "color": Color(1.0, 0.18, 0.08), "committed": true,
		},
		{
			"name": "Driving Thrust", "windup": 0.42, "active": 0.1, "recovery": 0.48,
			"range": 4.7, "minimum_dot": 0.82, "damage": 7, "stance": 5,
			"shape": "lane", "color": Color(1.0, 0.68, 0.12), "committed": false,
		},
		{
			"name": "Delayed Ruin", "windup": 1.18, "active": 0.16, "recovery": 0.92,
			"range": 3.8, "minimum_dot": -1.0, "damage": 12, "stance": 10,
			"shape": "circle", "color": Color(0.92, 0.16, 0.7), "committed": true,
		},
	]


func _set_phase(next_phase: String, duration: float) -> void:
	phase = next_phase
	phase_timer = maxf(duration, 0.0)
	if phase_label != null:
		phase_label.text = phase if current_attack.is_empty() else str(current_attack.get("name", "Attack")).to_upper() + "\n" + phase
	if indicator != null:
		indicator.visible = phase == PHASE_WINDUP or phase == PHASE_ACTIVE
	_update_material()
	phase_changed.emit(get_debug_data())


func _configure_indicator() -> void:
	if indicator == null:
		return
	var shape_name: String = str(current_attack.get("shape", "circle"))
	if shape_name == "lane":
		var box := BoxMesh.new()
		box.size = Vector3(1.25, 0.035, float(current_attack.get("range", 4.0)))
		indicator.mesh = box
		indicator.position = Vector3(0, 0.04, -float(current_attack.get("range", 4.0)) * 0.5)
	else:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = float(current_attack.get("range", 3.0))
		cylinder.bottom_radius = cylinder.top_radius
		cylinder.height = 0.035
		cylinder.radial_segments = 48
		indicator.mesh = cylinder
		indicator.position = Vector3(0, 0.04, 0)
	indicator_material.albedo_color = Color(current_attack.get("color", Color.RED), 0.24)
	indicator_material.emission = Color(current_attack.get("color", Color.RED))


func _update_phase_visual(_delta: float) -> void:
	if indicator != null and indicator.visible:
		var total: float = maxf(float(current_attack.get("windup", 0.6)), 0.01)
		var readiness: float = 1.0 - clampf(phase_timer / total, 0.0, 1.0) if phase == PHASE_WINDUP else 1.0
		indicator_material.albedo_color.a = lerpf(0.16, 0.62, readiness)
		indicator_material.emission_energy_multiplier = lerpf(0.6, 2.4, readiness)
		indicator.scale.y = 1.0 + sin(Time.get_ticks_msec() * 0.02) * 0.12
	if weapon_pivot != null and phase == PHASE_WINDUP:
		var windup_total: float = maxf(float(current_attack.get("windup", 0.6)), 0.01)
		var progress: float = 1.0 - phase_timer / windup_total
		weapon_pivot.rotation_degrees.x = lerpf(-20.0, -105.0, clampf(progress, 0.0, 1.0))


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.9
	shape.height = 3.4
	collision.shape = shape
	collision.position.y = 1.7
	add_child(collision)


func _build_visual() -> void:
	visual_root = Node3D.new()
	visual_root.name = "DuelistVisual"
	add_child(visual_root)
	body_material = StandardMaterial3D.new()
	body_material.albedo_color = Color(0.22, 0.12, 0.1)
	body_material.metallic = 0.42
	body_material.roughness = 0.52
	body_material.emission_enabled = true
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.86
	body_mesh.height = 3.4
	body.mesh = body_mesh
	body.position.y = 1.7
	body.material_override = body_material
	visual_root.add_child(body)
	weapon_pivot = Node3D.new()
	weapon_pivot.position = Vector3(0.95, 2.3, 0)
	visual_root.add_child(weapon_pivot)
	var weapon := MeshInstance3D.new()
	var weapon_mesh := BoxMesh.new()
	weapon_mesh.size = Vector3(0.18, 0.18, 3.3)
	weapon.mesh = weapon_mesh
	weapon.position.z = -1.3
	var weapon_material := StandardMaterial3D.new()
	weapon_material.albedo_color = Color(0.72, 0.78, 0.84)
	weapon_material.metallic = 0.9
	weapon_material.roughness = 0.24
	weapon.material_override = weapon_material
	weapon_pivot.add_child(weapon)
	phase_label = Label3D.new()
	phase_label.position = Vector3(0, 4.4, 0)
	phase_label.text = "DUELIST\nIDLE"
	phase_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	phase_label.font_size = 24
	phase_label.pixel_size = 0.008
	phase_label.outline_size = 7
	phase_label.modulate = Color(1.0, 0.76, 0.32)
	visual_root.add_child(phase_label)
	indicator = MeshInstance3D.new()
	indicator.name = "AttackTelegraph"
	indicator.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	indicator_material = StandardMaterial3D.new()
	indicator_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	indicator_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	indicator_material.emission_enabled = true
	indicator.material_override = indicator_material
	indicator.visible = false
	add_child(indicator)
	_update_material()


func _update_material() -> void:
	if body_material == null:
		return
	var color := Color(0.22, 0.12, 0.1)
	if counter_window_remaining > 0.0:
		color = Color(0.12, 0.54, 0.82)
	elif phase == PHASE_WINDUP:
		color = Color(0.62, 0.2, 0.08) if not bool(current_attack.get("committed", false)) else Color(0.72, 0.08, 0.05)
	elif phase == PHASE_RECOVERY:
		color = Color(0.2, 0.48, 0.62)
	elif phase == PHASE_STAGGERED:
		color = Color(0.36, 0.72, 1.0)
	body_material.albedo_color = color
	body_material.emission = color
	body_material.emission_energy_multiplier = 0.75 if phase != PHASE_IDLE or counter_window_remaining > 0.0 else 0.0


func _play_reaction(direction: Vector3, tilt: float) -> void:
	if reaction_tween != null:
		reaction_tween.kill()
	var local_direction: Vector3 = global_transform.basis.inverse() * direction.normalized()
	visual_root.rotation_degrees = Vector3(-tilt, 0, -local_direction.x * tilt)
	reaction_tween = create_tween()
	reaction_tween.set_trans(Tween.TRANS_BACK)
	reaction_tween.set_ease(Tween.EASE_OUT)
	reaction_tween.tween_property(visual_root, "rotation_degrees", Vector3.ZERO, 0.35)


func _show_world_text(text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = global_position + Vector3.UP * 4.8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 30
	label.pixel_size = 0.008
	label.outline_size = 8
	label.modulate = color
	get_tree().current_scene.add_child(label)
	var tween := label.create_tween()
	tween.parallel().tween_property(label, "position:y", label.position.y + 0.9, 0.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
	tween.finished.connect(label.queue_free)


func reset_target() -> void:
	global_position = home_position
	velocity = Vector3.ZERO
	attack_index = 0
	current_attack = {}
	counter_window_remaining = 0.0
	last_result = "WAITING"
	total_attacks = 0
	total_interrupts = 0
	weapon_pivot.rotation_degrees = Vector3.ZERO
	_set_phase(PHASE_IDLE, 1.0)


func is_target_defeated() -> bool:
	return false


func get_targeting_aim_point() -> Vector3:
	return global_position + Vector3.UP * 2.0


func get_debug_data() -> Dictionary:
	return {
		"phase": phase,
		"timer": snappedf(phase_timer, 0.01),
		"attack": str(current_attack.get("name", "None")),
		"committed": bool(current_attack.get("committed", false)),
		"counter": snappedf(counter_window_remaining, 0.01),
		"result": last_result,
		"attacks": total_attacks,
		"interrupts": total_interrupts,
	}
