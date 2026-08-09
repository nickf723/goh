extends CharacterBody3D
class_name HitReactionTestTarget

signal impact_received(data: Dictionary)

const CombatFeedback = preload("res://scripts/combat/combat_feedback.gd")

@export_enum("light", "armored", "unstoppable") var profile: String = "light"

var display_name: String = "Light Gremlin"
var home_position: Vector3
var visual_root: Node3D
var body_material: StandardMaterial3D
var accent_material: StandardMaterial3D
var reaction_controller: HitReactionController
var reaction_velocity: Vector3 = Vector3.ZERO
var reaction_timer: float = 0.0
var flash_timer: float = 0.0
var total_hits: int = 0
var last_damage: int = 0
var reaction_tween: Tween


func _ready() -> void:
	home_position = global_position
	add_to_group("enemy")
	add_to_group("combat_targetable")
	add_to_group("lab_resettable")
	reaction_controller = HitReactionController.new()
	reaction_controller.name = "HitReactionController"
	add_child(reaction_controller)
	_apply_profile()
	set_meta(
		"presentation_material",
		"flesh" if profile == "light" else "metal"
	)
	_build_collision()
	_build_visual()


func _physics_process(delta: float) -> void:
	flash_timer = maxf(flash_timer - delta, 0.0)
	reaction_timer = maxf(reaction_timer - delta, 0.0)
	if reaction_timer > 0.0 or not is_on_floor():
		velocity.x = reaction_velocity.x
		velocity.z = reaction_velocity.z
		velocity.y = reaction_velocity.y
		reaction_velocity.y -= 18.0 * delta
		reaction_velocity.x = move_toward(reaction_velocity.x, 0.0, 4.0 * delta)
		reaction_velocity.z = move_toward(reaction_velocity.z, 0.0, 4.0 * delta)
	else:
		var home_offset := home_position - global_position
		home_offset.y = 0.0
		velocity.x = home_offset.x * 3.5
		velocity.z = home_offset.z * 3.5
		velocity.y = -0.1
	move_and_slide()
	_update_material()


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	if payload == null:
		return {}
	total_hits += 1
	last_damage = maxi(payload.amount, 0)
	flash_timer = 0.14
	var result: Dictionary = {
		"message": display_name + " • " + str(last_damage) + " damage",
		"objective": "",
	}
	CombatFeedback.present_payload_impact(self, payload, result)
	return result


func receive_weapon_impact(payload: DamagePayload, direction: Vector3, attack: WeaponAttackDefinition) -> void:
	var result: Dictionary = reaction_controller.resolve_impact(payload, direction, attack)
	reaction_velocity = result.get("velocity", Vector3.ZERO)
	reaction_timer = float(result.get("duration", 0.0))
	_play_reaction(str(result.get("reaction", "RESIST")), direction, reaction_timer)
	_spawn_reaction_label(str(result.get("reaction", "RESIST")))
	impact_received.emit(get_debug_data())


func _apply_profile() -> void:
	match profile:
		"armored":
			display_name = "Armored Goblin"
			reaction_controller.configure({
				"poise": 15.0,
				"mass": 2.25,
				"armor": 0.5,
				"allows_launch": false,
				"poise_recovery": 3.8,
				"resistance_gain": 0.2,
			})
		"unstoppable":
			display_name = "Unstoppable Brute"
			reaction_controller.configure({
				"poise": 40.0,
				"mass": 7.0,
				"armor": 0.7,
				"super_armor": true,
				"allows_launch": false,
				"poise_recovery": 9.0,
				"resistance_gain": 0.1,
			})
		_:
			display_name = "Light Gremlin"
			reaction_controller.configure({
				"poise": 9.0,
				"mass": 1.0,
				"armor": 0.0,
				"allows_launch": true,
				"poise_recovery": 2.8,
				"resistance_gain": 0.3,
			})


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	var height: float = 2.1 if profile == "light" else (3.4 if profile == "armored" else 4.2)
	shape.radius = 0.62 if profile == "light" else (0.86 if profile == "armored" else 1.08)
	shape.height = height
	collision.shape = shape
	collision.position.y = height * 0.5
	add_child(collision)


func _build_visual() -> void:
	visual_root = Node3D.new()
	visual_root.name = "ReactionVisual"
	add_child(visual_root)
	body_material = _make_material(_profile_color(), false)
	accent_material = _make_material(_accent_color(), true)
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	var height: float = 2.1 if profile == "light" else (3.4 if profile == "armored" else 4.2)
	body_mesh.radius = 0.6 if profile == "light" else (0.84 if profile == "armored" else 1.06)
	body_mesh.height = height
	body.mesh = body_mesh
	body.position.y = height * 0.5
	body.material_override = body_material
	visual_root.add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.66 if profile == "light" else (0.82 if profile == "armored" else 1.0)
	head_mesh.height = head_mesh.radius * 2.0
	head.mesh = head_mesh
	head.position.y = height + head_mesh.radius * 0.15
	head.material_override = body_material
	visual_root.add_child(head)
	if profile != "light":
		var armor_plate := MeshInstance3D.new()
		var plate_mesh := BoxMesh.new()
		plate_mesh.size = Vector3(1.7 if profile == "armored" else 2.25, 1.2, 0.28)
		armor_plate.mesh = plate_mesh
		armor_plate.position = Vector3(0, height * 0.7, -0.65 if profile == "armored" else -0.86)
		armor_plate.material_override = accent_material
		visual_root.add_child(armor_plate)
	var label := Label3D.new()
	label.text = display_name.to_upper()
	label.position = Vector3(0, height + 1.15, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 24
	label.pixel_size = 0.008
	label.outline_size = 7
	label.modulate = _accent_color()
	visual_root.add_child(label)


func _play_reaction(reaction: String, direction: Vector3, duration: float) -> void:
	if visual_root == null:
		return
	if reaction_tween != null:
		reaction_tween.kill()
	var local_direction := global_transform.basis.inverse() * direction.normalized()
	var tilt: float = 4.0
	var squash := Vector3(1.03, 0.97, 1.03)
	match reaction:
		"FLINCH":
			tilt = 10.0
		"STAGGER", "GUARD BREAK":
			tilt = 20.0
			squash = Vector3(1.12, 0.82, 1.12)
		"LAUNCH":
			tilt = 28.0
			squash = Vector3(0.9, 1.18, 0.9)
		"SUPER ARMOR", "ADAPTED":
			tilt = 2.0
			squash = Vector3(1.06, 0.96, 1.06)
	visual_root.rotation_degrees = Vector3(-tilt, 0, -local_direction.x * tilt)
	visual_root.scale = squash
	reaction_tween = create_tween()
	reaction_tween.set_trans(Tween.TRANS_BACK)
	reaction_tween.set_ease(Tween.EASE_OUT)
	reaction_tween.parallel().tween_property(visual_root, "rotation_degrees", Vector3.ZERO, maxf(duration, 0.12))
	reaction_tween.parallel().tween_property(visual_root, "scale", Vector3.ONE, maxf(duration, 0.12))


func _spawn_reaction_label(reaction: String) -> void:
	var label := Label3D.new()
	label.text = reaction
	label.position = global_position + Vector3.UP * (4.8 if profile == "unstoppable" else 3.8)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 30
	label.pixel_size = 0.008
	label.outline_size = 8
	label.modulate = Color(1.0, 0.84, 0.3) if reaction != "SUPER ARMOR" else Color(1.0, 0.3, 0.18)
	get_tree().current_scene.add_child(label)
	var tween := label.create_tween()
	tween.parallel().tween_property(label, "position:y", label.position.y + 0.9, 0.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
	tween.finished.connect(label.queue_free)


func _make_material(color: Color, emissive: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.55
	material.metallic = 0.55 if profile != "light" else 0.05
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.55 if emissive else 0.0
	return material


func _profile_color() -> Color:
	match profile:
		"armored":
			return Color(0.24, 0.32, 0.42)
		"unstoppable":
			return Color(0.3, 0.08, 0.06)
		_:
			return Color(0.24, 0.62, 0.28)


func _accent_color() -> Color:
	match profile:
		"armored":
			return Color(0.48, 0.76, 1.0)
		"unstoppable":
			return Color(1.0, 0.28, 0.12)
		_:
			return Color(0.66, 1.0, 0.48)


func _update_material() -> void:
	if body_material == null:
		return
	var color := Color.WHITE if flash_timer > 0.0 else _profile_color()
	body_material.albedo_color = color
	body_material.emission = color
	body_material.emission_energy_multiplier = 2.4 if flash_timer > 0.0 else 0.0


func reset_target() -> void:
	global_position = home_position
	velocity = Vector3.ZERO
	reaction_velocity = Vector3.ZERO
	reaction_timer = 0.0
	total_hits = 0
	last_damage = 0
	reaction_controller.reset_reactions()
	if visual_root != null:
		visual_root.rotation_degrees = Vector3.ZERO
		visual_root.scale = Vector3.ONE


func is_target_defeated() -> bool:
	return false


func get_targeting_aim_point() -> Vector3:
	return global_position + Vector3.UP * (1.4 if profile == "light" else 2.0)


func get_debug_data() -> Dictionary:
	var data: Dictionary = reaction_controller.get_debug_data()
	data["name"] = display_name
	data["hits"] = total_hits
	data["damage"] = last_damage
	data["offset"] = snappedf(global_position.distance_to(home_position), 0.01)
	data["presentation_material"] = str(get_meta("presentation_material", "auto"))
	return data
