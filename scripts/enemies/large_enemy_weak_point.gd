extends Area3D
class_name LargeEnemyWeakPoint

signal weak_point_damaged(part_id: String, current_health: int, maximum_health: int)
signal weak_point_broken(part_id: String)

@export var part_id: String = "weak_point"
@export var display_name: String = "Weak Point"
@export_range(1, 500, 1) var maximum_health: int = 24
@export_range(0.1, 3.0, 0.05) var damage_multiplier: float = 1.0
@export_range(0.1, 3.0, 0.05) var stance_multiplier: float = 1.0
@export_range(0.1, 3.0, 0.05) var collision_radius: float = 0.65
@export var weak_elements: Array[String] = []
@export var resistant_elements: Array[String] = []
@export var targeting_enabled: bool = true
@export var part_color: Color = Color(0.66, 0.74, 0.84, 1.0)
@export var broken_color: Color = Color(0.18, 0.16, 0.15, 0.55)

var current_health: int = 1
var broken: bool = false
var owner_enemy: Node3D = null
var visual: MeshInstance3D = null
var material: StandardMaterial3D = null
var hit_flash_timer: float = 0.0


func _ready() -> void:
	owner_enemy = get_parent() as Node3D
	current_health = maximum_health
	collision_layer = 1
	collision_mask = 0
	monitorable = true
	monitoring = false
	add_to_group("lock_on_weak_point")
	add_to_group("large_enemy_part")
	add_to_group("debuggable")
	_build_collision()
	_build_visual()
	_update_state()


func _process(delta: float) -> void:
	hit_flash_timer = max(hit_flash_timer - max(delta, 0.0), 0.0)
	if material == null:
		return
	var flash: float = clampf(hit_flash_timer / 0.16, 0.0, 1.0)
	material.emission_energy_multiplier = lerpf(
		0.18 if targeting_enabled and not broken else 0.0,
		4.5,
		flash
	)


func _build_collision() -> void:
	if get_node_or_null("CollisionShape3D") != null:
		return
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := SphereShape3D.new()
	shape.radius = collision_radius
	collision.shape = shape
	add_child(collision)


func _build_visual() -> void:
	visual = MeshInstance3D.new()
	visual.name = "WeakPointVisual"
	var sphere := SphereMesh.new()
	sphere.radius = collision_radius * 0.66
	sphere.height = collision_radius * 1.32
	sphere.radial_segments = 16
	sphere.rings = 10
	visual.mesh = sphere
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	material = StandardMaterial3D.new()
	material.albedo_color = part_color
	material.metallic = 0.82
	material.roughness = 0.24
	material.emission_enabled = true
	material.emission = Color(part_color.r, part_color.g, part_color.b, 1.0)
	material.emission_energy_multiplier = 0.18
	visual.material_override = material
	add_child(visual)


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	if payload == null:
		return {"message": display_name + " receives an empty payload.", "objective": ""}
	if broken or not targeting_enabled:
		if owner_enemy != null and owner_enemy.has_method("receive_damage_payload"):
			return owner_enemy.call("receive_damage_payload", payload)
		return {"message": display_name + " is no longer targetable.", "objective": ""}

	var element: String = payload.element.to_lower().strip_edges()
	var multiplier: float = damage_multiplier
	if weak_elements.has(element):
		multiplier *= 1.75
	elif resistant_elements.has(element):
		multiplier *= 0.45

	var applied_damage: int = max(1, roundi(float(max(payload.amount, 1)) * multiplier))
	var applied_stance: int = max(0, roundi(float(max(payload.stance_damage, 0)) * stance_multiplier))
	current_health = max(current_health - applied_damage, 0)
	hit_flash_timer = 0.16
	weak_point_damaged.emit(part_id, current_health, maximum_health)

	var owner_result: Dictionary = {}
	if owner_enemy != null and owner_enemy.has_method("receive_weak_point_payload"):
		var raw_result: Variant = owner_enemy.call(
			"receive_weak_point_payload",
			part_id,
			payload,
			applied_damage,
			applied_stance
		)
		if raw_result is Dictionary:
			owner_result = raw_result as Dictionary

	if current_health <= 0:
		break_part()
		var consequence: String = str(owner_result.get("message", ""))
		return {
			"message": display_name + " BREAKS!" + (("\n" + consequence) if consequence != "" else ""),
			"objective": str(owner_result.get("objective", "")),
		}

	return {
		"message": display_name + " takes " + str(applied_damage) + " part damage.",
		"objective": str(owner_result.get("objective", "")),
	}


func break_part() -> void:
	if broken:
		return
	broken = true
	targeting_enabled = false
	remove_from_group("lock_on_weak_point")
	_update_state()
	weak_point_broken.emit(part_id)
	if owner_enemy != null and owner_enemy.has_method("on_weak_point_broken"):
		owner_enemy.call("on_weak_point_broken", part_id)


func set_targeting_enabled(enabled_value: bool) -> void:
	if broken:
		targeting_enabled = false
	else:
		targeting_enabled = enabled_value
	if targeting_enabled:
		if not is_in_group("lock_on_weak_point"):
			add_to_group("lock_on_weak_point")
	else:
		remove_from_group("lock_on_weak_point")
	_update_state()


func _update_state() -> void:
	var collision: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.set_deferred("disabled", not targeting_enabled or broken)
	if material != null:
		var color: Color = broken_color if broken else part_color
		if not targeting_enabled and not broken:
			color = part_color.darkened(0.58)
		material.albedo_color = color
		material.emission = Color(color.r, color.g, color.b, 1.0)
	if visual != null:
		visual.scale = Vector3.ONE * (0.72 if broken else 1.0)


func get_targeting_owner() -> Node3D:
	return owner_enemy


func get_targeting_aim_point() -> Vector3:
	return global_position


func get_targeting_node() -> Node3D:
	return self


func get_lock_on_camera_distance_multiplier() -> float:
	if owner_enemy != null and owner_enemy.has_method("get_lock_on_camera_distance_multiplier"):
		return float(owner_enemy.call("get_lock_on_camera_distance_multiplier"))
	return 1.25


func is_targeting_enabled() -> bool:
	return targeting_enabled and not broken and is_visible_in_tree()


func is_target_defeated() -> bool:
	if broken or not targeting_enabled:
		return true
	if owner_enemy != null and owner_enemy.has_method("is_target_defeated"):
		return bool(owner_enemy.call("is_target_defeated"))
	return false


func reset_target() -> void:
	broken = false
	current_health = maximum_health
	targeting_enabled = part_id != "core"
	hit_flash_timer = 0.0
	_update_state()


func get_debug_data() -> Dictionary:
	return {
		"part": part_id,
		"display_name": display_name,
		"health": current_health,
		"maximum": maximum_health,
		"broken": broken,
		"targetable": targeting_enabled,
		"owner": owner_enemy.name if owner_enemy != null else "none",
	}
