extends Node3D
class_name LightningProjectileVfx

@export var refresh_interval: float = 0.045
@export var trail_length: float = 1.9
@export var forward_reach: float = 0.28
@export var visual_intensity: float = 0.82

var projectile: Node3D
var renderer: LightningArcRenderer
var profile: LightningProfile
var refresh_timer: float = 0.0
var seed_counter: int = 31001


func _ready() -> void:
	projectile = get_parent() as Node3D
	renderer = LightningArcRenderer.new()
	renderer.name = "LightningArcRenderer"
	add_child(renderer)
	profile = LightningProfile.new()
	profile.thickness = 0.032
	profile.glow_width_multiplier = 3.6
	profile.duration_seconds = 0.085
	profile.subdivision_count = 4
	profile.jitter_amplitude = 0.18
	profile.branch_chance = 0.14
	profile.branch_depth = 1
	profile.branch_length_ratio = 0.24
	profile.maximum_branches = 2
	profile.flicker_frequency = 55.0
	profile.light_energy = 2.4
	profile.light_range = 3.5
	profile.impact_flash_scale = 0.08
	hide_legacy_mesh()


func _process(delta: float) -> void:
	if projectile == null or not is_instance_valid(projectile):
		return
	refresh_timer -= max(delta, 0.0)
	if refresh_timer > 0.0:
		return
	refresh_timer = max(refresh_interval, 0.015)
	seed_counter += 17
	var direction: Vector3 = get_projectile_direction()
	var center: Vector3 = projectile.global_position
	var event := LightningArcEvent.make(
		LightningArcEvent.KIND_DIRECT,
		center - direction * trail_length,
		center + direction * forward_reach,
		visual_intensity,
		seed_counter,
		"lightning_spark_projectile",
		["lightning", "spell", "projectile", "procedural"]
	)
	renderer.render_arc(event, profile)


func get_projectile_direction() -> Vector3:
	if projectile != null:
		var raw_direction: Variant = projectile.get("direction")
		if raw_direction is Vector3:
			var direction: Vector3 = raw_direction
			if direction.length() > 0.001:
				return direction.normalized()
	return -projectile.global_transform.basis.z.normalized() if projectile != null else Vector3.FORWARD


func hide_legacy_mesh() -> void:
	if projectile == null:
		return
	var legacy_mesh := projectile.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if legacy_mesh != null:
		legacy_mesh.visible = false
