extends Node3D
class_name FireProjectileVfx

const FireEventScript = preload("res://scripts/presentation/fire_vfx_event.gd")
const FireProfileScript = preload("res://scripts/presentation/fire_presentation_profile.gd")
const FireVisualScript = preload("res://scripts/presentation/procedural_fire_visual.gd")

@export var visual_intensity: float = 0.95
@export var trail_length_scale: float = 0.75

var projectile: Node3D
var visual: Node3D
var profile: Resource
var event: RefCounted
var event_seed: int = 4103


func _ready() -> void:
	projectile = get_parent() as Node3D
	profile = FireProfileScript.new()
	profile.apply_kind("firebolt")
	profile.persistent = true
	profile.flame_height *= trail_length_scale
	event = FireEventScript.make(
		FireEventScript.KIND_PROJECTILE,
		global_position,
		visual_intensity,
		float(profile.flame_radius),
		"firebolt_projectile",
		["fire", "spell", "projectile", "procedural"]
	)
	event.smoke_strength = 0.18
	event.ember_strength = 1.0
	event.event_seed = event_seed
	visual = FireVisualScript.new() as Node3D
	visual.name = "ProceduralFireboltVisual"
	add_child(visual)
	visual.configure(event, profile)
	hide_legacy_mesh()
	update_orientation()


func _process(_delta: float) -> void:
	if projectile == null or not is_instance_valid(projectile) or visual == null:
		return
	update_orientation()
	visual.apply_state(visual_intensity, -get_projectile_direction() * 1.8, 0.18, 1.0)


func get_projectile_direction() -> Vector3:
	if projectile != null:
		var raw_direction: Variant = projectile.get("direction")
		if raw_direction is Vector3:
			var direction: Vector3 = raw_direction
			if direction.length() > 0.001:
				return direction.normalized()
	return -projectile.global_transform.basis.z.normalized() if projectile != null else Vector3.FORWARD


func update_orientation() -> void:
	if visual == null:
		return
	var trail_direction: Vector3 = -get_projectile_direction()
	visual.quaternion = Quaternion(Vector3.UP, trail_direction)
	visual.position = trail_direction * 0.18


func hide_legacy_mesh() -> void:
	if projectile == null:
		return
	var legacy_mesh := projectile.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if legacy_mesh != null:
		legacy_mesh.visible = false


func get_debug_data() -> Dictionary:
	var legacy_hidden: bool = true
	if projectile != null:
		var legacy_mesh := projectile.get_node_or_null("MeshInstance3D") as MeshInstance3D
		if legacy_mesh != null:
			legacy_hidden = not legacy_mesh.visible
	var visual_debug: Dictionary = {}
	if visual != null and visual.has_method("get_debug_data"):
		visual_debug = visual.call("get_debug_data") as Dictionary
	return {
		"fire_projectile_vfx": true,
		"legacy_hidden": legacy_hidden,
		"direction": get_projectile_direction(),
		"visual": visual_debug,
	}
