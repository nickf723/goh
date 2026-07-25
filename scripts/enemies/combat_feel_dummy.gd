extends CharacterBody3D
class_name CombatFeelDummy

signal impact_received(data: Dictionary)

@export var display_name: String = "Responsive Training Dummy"
@export var guarded: bool = false
@export_range(0.5, 20.0, 0.1) var return_strength: float = 7.5
@export_range(0.5, 20.0, 0.1) var recoil_damping: float = 8.0

var home_position: Vector3
var visual_root: Node3D
var body_material: StandardMaterial3D
var flash_timer: float = 0.0
var recoil_velocity: Vector3 = Vector3.ZERO
var total_hits: int = 0
var last_damage: int = 0
var last_attack_name: String = "none"
var last_contact: String = "waiting"
var reaction_tween: Tween


func _ready() -> void:
	home_position = global_position
	add_to_group("enemy")
	add_to_group("combat_targetable")
	add_to_group("debuggable")
	add_to_group("lab_resettable")
	_build_collision()
	_build_visual()


func _physics_process(delta: float) -> void:
	flash_timer = maxf(flash_timer - maxf(delta, 0.0), 0.0)
	var home_offset: Vector3 = home_position - global_position
	home_offset.y = 0.0
	recoil_velocity += home_offset * return_strength * delta
	recoil_velocity = recoil_velocity.lerp(Vector3.ZERO, clampf(delta * recoil_damping, 0.0, 1.0))
	velocity.x = recoil_velocity.x
	velocity.z = recoil_velocity.z
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1
	move_and_slide()
	_update_material()


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	if payload == null:
		return {}
	total_hits += 1
	last_attack_name = payload.source_name
	last_damage = 0 if guarded else maxi(payload.amount, 0)
	last_contact = "GUARDED" if guarded else ("HEAVY" if payload.tags.has("heavy") or payload.tags.has("finisher") else "CLEAN")
	flash_timer = 0.16
	_spawn_damage_number(last_damage, last_contact)
	impact_received.emit(get_debug_data())
	return {
		"message": last_contact + " • " + payload.source_name + " • " + str(last_damage) + " damage",
		"objective": "",
		"contact_type": last_contact.to_lower(),
	}


func receive_weapon_impact(payload: DamagePayload, direction: Vector3, attack: WeaponAttackDefinition) -> void:
	var horizontal: Vector3 = direction
	horizontal.y = 0.0
	if horizontal.length_squared() <= 0.001:
		horizontal = Vector3.BACK
	var force: float = 1.2 + float(payload.amount) * 0.22 + payload.knockback_strength * 0.18
	if guarded:
		force *= 0.28
	recoil_velocity += horizontal.normalized() * force
	_play_reaction(horizontal.normalized(), attack, force)


func set_guarded(enabled: bool) -> void:
	guarded = enabled
	last_contact = "GUARD READY" if guarded else "OPEN"
	_update_material()


func toggle_guarded() -> void:
	set_guarded(not guarded)


func _play_reaction(direction: Vector3, attack: WeaponAttackDefinition, force: float) -> void:
	if visual_root == null:
		return
	if reaction_tween != null:
		reaction_tween.kill()
	var local_direction: Vector3 = global_transform.basis.inverse() * direction
	var heavy: bool = attack != null and (attack.input_kind == "heavy" or attack.damage_multiplier >= 1.5)
	var tilt: float = clampf(force * (2.2 if heavy else 1.35), 4.0, 18.0)
	visual_root.rotation_degrees = Vector3(-tilt, 0.0, -local_direction.x * tilt)
	visual_root.scale = Vector3(1.08, 0.9, 1.08) if heavy else Vector3(1.04, 0.96, 1.04)
	reaction_tween = create_tween()
	reaction_tween.set_trans(Tween.TRANS_BACK)
	reaction_tween.set_ease(Tween.EASE_OUT)
	reaction_tween.parallel().tween_property(visual_root, "rotation_degrees", Vector3.ZERO, 0.24 if heavy else 0.15)
	reaction_tween.parallel().tween_property(visual_root, "scale", Vector3.ONE, 0.24 if heavy else 0.15)


func _spawn_damage_number(amount: int, contact: String) -> void:
	var label := Label3D.new()
	label.text = contact + "  " + str(amount)
	label.position = global_position + Vector3(0, 3.3, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.pixel_size = 0.008
	label.outline_size = 7
	label.modulate = Color(0.52, 0.82, 1.0) if guarded else Color(1.0, 0.86, 0.34)
	get_tree().current_scene.add_child(label)
	var tween := label.create_tween()
	tween.parallel().tween_property(label, "position:y", label.position.y + 1.0, 0.48)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.48)
	tween.finished.connect(label.queue_free)


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.72
	shape.height = 2.8
	collision.shape = shape
	collision.position.y = 1.4
	add_child(collision)


func _build_visual() -> void:
	visual_root = Node3D.new()
	visual_root.name = "ReactionVisual"
	add_child(visual_root)
	body_material = StandardMaterial3D.new()
	body_material.albedo_color = Color(0.44, 0.28, 0.16)
	body_material.roughness = 0.82
	body_material.emission_enabled = true
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.7
	capsule.height = 2.8
	body.mesh = capsule
	body.position.y = 1.4
	body.material_override = body_material
	visual_root.add_child(body)
	var crossbar := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.2, 0.24, 0.24)
	crossbar.mesh = box
	crossbar.position = Vector3(0, 2.15, 0)
	crossbar.material_override = body_material
	visual_root.add_child(crossbar)
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 1.05
	base_mesh.bottom_radius = 1.15
	base_mesh.height = 0.35
	base.mesh = base_mesh
	base.position.y = 0.18
	base.material_override = body_material
	visual_root.add_child(base)


func _update_material() -> void:
	if body_material == null:
		return
	var base_color: Color = Color(0.22, 0.48, 0.76) if guarded else Color(0.44, 0.28, 0.16)
	if flash_timer > 0.0:
		base_color = Color.WHITE
	body_material.albedo_color = base_color
	body_material.emission = Color(base_color.r, base_color.g, base_color.b)
	body_material.emission_energy_multiplier = 2.8 if flash_timer > 0.0 else (0.45 if guarded else 0.0)


func reset_target() -> void:
	global_position = home_position
	velocity = Vector3.ZERO
	recoil_velocity = Vector3.ZERO
	total_hits = 0
	last_damage = 0
	last_attack_name = "none"
	last_contact = "waiting"
	guarded = false
	if visual_root != null:
		visual_root.rotation_degrees = Vector3.ZERO
		visual_root.scale = Vector3.ONE
	_update_material()


func is_target_defeated() -> bool:
	return false


func get_targeting_aim_point() -> Vector3:
	return global_position + Vector3.UP * 1.55


func get_debug_data() -> Dictionary:
	return {
		"hits": total_hits,
		"damage": last_damage,
		"attack": last_attack_name,
		"contact": last_contact,
		"guarded": guarded,
		"offset": snappedf(global_position.distance_to(home_position), 0.01),
	}
