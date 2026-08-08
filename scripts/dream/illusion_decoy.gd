extends Area3D
class_name DreamIllusionDecoy

signal illusion_attacked(payload: DamagePayload, attacker: Node3D)
signal illusion_expired(reason: String)

const GraceVisualScene: PackedScene = preload(
	"res://scenes/actors/player/grace_wire_visual_v1.tscn"
)

@export_range(0.5, 30.0, 0.1) var lifetime_seconds: float = 8.0
@export_range(0.1, 4.0, 0.05) var perceived_threat_score: float = 1.35
@export_range(0.1, 4.0, 0.05) var perception_priority: float = 1.45
@export_range(0.0, 1.0, 0.01) var body_alpha: float = 0.52
@export_range(0.0, 8.0, 0.1) var emission_energy: float = 2.5
@export_range(0.05, 1.0, 0.01) var attack_flicker_seconds: float = 0.18
@export_range(4.0, 60.0, 1.0) var visual_updates_per_second: float = 24.0

var source_actor: Node3D = null
var cast_serial: int = 0
var remaining: float = 8.0
var elapsed: float = 0.0
var attack_flicker_remaining: float = 0.0
var attack_count: int = 0
var last_attack_source: String = "none"
var grace_visual: Node3D = null
var aura_ring: MeshInstance3D = null
var aura_material: StandardMaterial3D = null
var visual_geometry: Array[GeometryInstance3D] = []
var visual_accumulator: float = 0.0
var expired: bool = false


func _ready() -> void:
	add_to_group("perception_targets")
	add_to_group("illusion_decoys")
	add_to_group("spell_effects")
	add_to_group("persistent_spell_effects")
	add_to_group("lab_resettable")
	add_to_group("debuggable")
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	monitorable = true
	set_meta("perception_authenticity", 0.0)
	set_meta("combat_authority", false)
	set_meta("perceived_threat_score", perceived_threat_score)
	set_meta("perception_priority", perception_priority)
	set_meta("perceived_threatening", true)
	set_meta("perception_target_kind", "illusion")
	_build_collision()
	_build_visual()
	remaining = maxf(lifetime_seconds, 0.5)
	set_process(true)


func configure(
	caster: Node3D,
	serial: int,
	duration_override: float = -1.0
) -> void:
	source_actor = caster
	cast_serial = maxi(serial, 0)
	if duration_override > 0.0:
		lifetime_seconds = duration_override
	remaining = maxf(lifetime_seconds, 0.5)
	set_meta(
		"illusion_source_id",
		source_actor.get_instance_id() if source_actor != null else 0
	)
	set_meta("illusion_cast_serial", cast_serial)


func _process(delta: float) -> void:
	if expired:
		return
	var step: float = maxf(delta, 0.0)
	elapsed += step
	remaining = maxf(remaining - step, 0.0)
	attack_flicker_remaining = maxf(attack_flicker_remaining - step, 0.0)
	visual_accumulator += step
	var interval: float = 1.0 / maxf(visual_updates_per_second, 1.0)
	if visual_accumulator >= interval:
		visual_accumulator = fmod(visual_accumulator, interval)
		_update_visual()
	if remaining <= 0.0:
		expire_illusion("duration_complete")


func is_perception_target() -> bool:
	return not expired


func get_perceived_target_position(_observer: Node3D = null) -> Vector3:
	return global_position


func get_perceived_threat_score(_observer: Node3D = null) -> float:
	return perceived_threat_score


func get_perception_authenticity() -> float:
	return 0.0


func is_perceived_threatening() -> bool:
	return true


func has_combat_authority() -> bool:
	return false


func can_receive_damage() -> bool:
	return false


func belongs_to_source(candidate: Node) -> bool:
	return source_actor != null and candidate == source_actor


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	if payload == null:
		return {"received": false, "reason": "missing_payload"}
	attack_count += 1
	last_attack_source = payload.source_name
	attack_flicker_remaining = attack_flicker_seconds
	illusion_attacked.emit(payload, null)
	return {
		"received": true,
		"illusion": true,
		"authentic": false,
		"damage": 0,
		"stance_damage": 0,
		"message": payload.source_name + " passes through the Illusion.",
	}


func receive_magic_hit(_damage: int) -> Dictionary:
	var payload := DamagePayload.new()
	payload.amount = 0
	payload.source_name = "Magic"
	return receive_damage_payload(payload)


func reset_target() -> void:
	expire_illusion("reset")


func expire_illusion(reason: String = "expired") -> void:
	if expired:
		return
	expired = true
	set_process(false)
	illusion_expired.emit(reason)
	queue_free()


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "PerceptionAndAttackShape"
	collision.position = Vector3(0.0, 0.96, 0.0)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.46
	capsule.height = 1.92
	collision.shape = capsule
	add_child(collision)


func _build_visual() -> void:
	grace_visual = GraceVisualScene.instantiate() as Node3D
	if grace_visual != null:
		grace_visual.name = "IllusionGraceVisual"
		grace_visual.position = Vector3(0.0, -0.92, 0.0)
		add_child(grace_visual)
		grace_visual.set_process(false)
		grace_visual.set_physics_process(false)
		_tint_recursive(grace_visual)

	aura_ring = MeshInstance3D.new()
	aura_ring.name = "DreamRipple"
	aura_ring.position = Vector3(0.0, 0.05, 0.0)
	aura_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var torus := TorusMesh.new()
	torus.inner_radius = 0.62
	torus.outer_radius = 0.72
	torus.rings = 24
	torus.ring_segments = 8
	aura_ring.mesh = torus
	aura_material = StandardMaterial3D.new()
	aura_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aura_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_material.albedo_color = Color(0.36, 0.28, 1.0, 0.48)
	aura_material.emission_enabled = true
	aura_material.emission = Color(0.38, 0.22, 1.0)
	aura_material.emission_energy_multiplier = 2.4
	aura_ring.material_override = aura_material
	add_child(aura_ring)


func _tint_recursive(node: Node) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		geometry.transparency = 0.28
		visual_geometry.append(geometry)
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0.34, 0.28, 1.0, body_alpha)
		material.emission_enabled = true
		material.emission = Color(0.3, 0.2, 1.0)
		material.emission_energy_multiplier = emission_energy
		mesh_instance.material_override = material
	for child: Node in node.get_children():
		_tint_recursive(child)


func _update_visual() -> void:
	var lifetime_ratio: float = clampf(
		remaining / maxf(lifetime_seconds, 0.01),
		0.0,
		1.0
	)
	var shimmer: float = 1.0 + sin(elapsed * 7.0) * 0.025
	if grace_visual != null:
		grace_visual.scale = Vector3.ONE * shimmer
		grace_visual.rotation.y = sin(elapsed * 1.7) * 0.025
		var attack_alpha: float = (
			0.42
			if attack_flicker_remaining > 0.0 and int(elapsed * 36.0) % 2 == 0
			else 0.22
		)
		for geometry: GeometryInstance3D in visual_geometry:
			if geometry != null and is_instance_valid(geometry):
				geometry.transparency = attack_alpha + (1.0 - lifetime_ratio) * 0.28
	if aura_ring != null:
		aura_ring.rotation.y += 0.08
		var ring_pulse: float = 1.0 + sin(elapsed * 5.0) * 0.08
		aura_ring.scale = Vector3(ring_pulse, 1.0, ring_pulse)


func get_debug_data() -> Dictionary:
	return {
		"illusion_decoy": true,
		"cast_serial": cast_serial,
		"remaining": snappedf(remaining, 0.01),
		"attacks_received": attack_count,
		"last_attack_source": last_attack_source,
		"perception_authenticity": 0.0,
		"combat_authority": false,
		"perceived_threat_score": perceived_threat_score,
		"perception_priority": perception_priority,
		"source_id": source_actor.get_instance_id() if source_actor != null else 0,
		"cached_visuals": visual_geometry.size(),
		"visual_hz": visual_updates_per_second,
	}
