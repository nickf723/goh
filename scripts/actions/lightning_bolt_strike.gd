extends Node3D
class_name LightningBoltStrike

signal warning_started(target_position: Vector3)
signal bolt_struck(target_position: Vector3, hit_count: int)
signal target_struck(target: Node, result: Dictionary)
signal strike_finished(hit_count: int)

@export_group("Timing")
@export_range(0.05, 3.0, 0.05) var warning_seconds: float = 0.38
@export_range(0.05, 2.0, 0.05) var impact_visual_seconds: float = 0.28

@export_group("Direct Strike")
@export_range(0.1, 5.0, 0.05) var strike_radius: float = 0.78
@export_range(0.5, 8.0, 0.05) var preview_radius: float = 1.8
@export_range(1.0, 20.0, 0.1) var query_height: float = 5.0
@export_range(2.0, 40.0, 0.5) var sky_height: float = 15.0
@export_flags_3d_physics var collision_mask: int = 1

@export_group("Presentation")
@export_range(0.0, 8.0, 0.1) var warning_pulse_speed: float = 5.6
@export_range(0.0, 0.25, 0.01) var warning_pulse_size: float = 0.055
@export var show_debug_messages: bool = false

var source_actor: Node3D
var runtime_payload: DamagePayload
var active: bool = false
var struck: bool = false
var elapsed: float = 0.0
var impact_remaining: float = 0.0
var hit_target_ids: Dictionary = {}
var hit_target_names: Array[String] = []
var last_results: Array[Dictionary] = []
var collision_exclusions: Array[RID] = []

var warning_root: Node3D
var warning_disc: MeshInstance3D
var direct_disc: MeshInstance3D
var bolt_root: Node3D
var main_bolt: MeshInstance3D
var impact_flash: MeshInstance3D
var strike_light: OmniLight3D


func _ready() -> void:
	add_to_group("lightning_bolt_strikes")
	add_to_group("debuggable")
	_build_visuals()
	set_process(false)


func _process(delta: float) -> void:
	advance_strike(delta)


func set_payload(new_payload: Resource) -> void:
	if new_payload is DamagePayload:
		runtime_payload = (new_payload as DamagePayload).duplicate(true) as DamagePayload


func set_source_actor(new_source_actor: Node) -> void:
	if new_source_actor is Node3D:
		source_actor = new_source_actor as Node3D


func begin_strike() -> void:
	if active:
		return
	active = true
	struck = false
	elapsed = 0.0
	impact_remaining = 0.0
	hit_target_ids.clear()
	hit_target_names.clear()
	last_results.clear()
	collision_exclusions.clear()
	if source_actor != null and is_instance_valid(source_actor):
		_collect_collision_rids(source_actor, collision_exclusions)
	if warning_root != null:
		warning_root.visible = true
	if bolt_root != null:
		bolt_root.visible = false
	set_process(true)
	warning_started.emit(global_position)


func advance_strike(delta: float) -> bool:
	if not active:
		return false
	var safe_delta: float = maxf(delta, 0.0)
	elapsed += safe_delta
	if not struck:
		_update_warning_visual()
		if elapsed + 0.0001 >= maxf(warning_seconds, 0.05):
			_resolve_direct_strike()
		return true

	impact_remaining = maxf(impact_remaining - safe_delta, 0.0)
	_update_impact_visual()
	if impact_remaining <= 0.0:
		finish_strike()
		return false
	return true


func finish_strike() -> void:
	if not active:
		return
	active = false
	set_process(false)
	strike_finished.emit(hit_target_ids.size())
	queue_free()


func _resolve_direct_strike() -> void:
	if struck:
		return
	struck = true
	impact_remaining = maxf(impact_visual_seconds, 0.05)
	if warning_root != null:
		warning_root.visible = false
	if bolt_root != null:
		bolt_root.visible = true

	for target: Node in _collect_direct_targets():
		var result: Dictionary = _deliver_payload(target)
		last_results.append(result.duplicate(true))
		target_struck.emit(target, result)

	bolt_struck.emit(global_position, hit_target_ids.size())
	if show_debug_messages:
		print(
			"LIGHTNING_BOLT strike at ",
			global_position,
			" hits ",
			hit_target_names
		)


func _collect_direct_targets() -> Array[Node]:
	var targets: Array[Node] = []
	var world: World3D = get_world_3d()
	if world == null:
		return targets

	var shape := CylinderShape3D.new()
	shape.radius = maxf(strike_radius, 0.1)
	shape.height = maxf(query_height, 1.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(
		Basis.IDENTITY,
		global_position + Vector3.UP * shape.height * 0.5
	)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = collision_exclusions

	for result: Dictionary in world.direct_space_state.intersect_shape(query, 64):
		var collider_value: Variant = result.get("collider")
		if not collider_value is Node:
			continue
		var target: Node = _resolve_effect_target(collider_value as Node)
		if target == null:
			continue
		var flat_offset: Vector3 = _get_target_position(target) - global_position
		flat_offset.y = 0.0
		if flat_offset.length() > strike_radius + 0.08:
			continue
		var target_id: int = target.get_instance_id()
		if hit_target_ids.has(target_id):
			continue
		hit_target_ids[target_id] = true
		hit_target_names.append(str(target.name))
		targets.append(target)
	return targets


func _resolve_effect_target(start_node: Node) -> Node:
	var current: Node = start_node
	while current != null:
		if source_actor != null and is_instance_valid(source_actor):
			if current == source_actor or source_actor.is_ancestor_of(current):
				return null
		if _is_effect_target(current):
			return current
		if current == get_tree().current_scene:
			break
		current = current.get_parent()
	return null


func _is_effect_target(node: Node) -> bool:
	if node == null:
		return false
	return (
		node.get_node_or_null("PayloadReceiver") != null
		or node.get_node_or_null("HitReceiver") != null
		or node.has_method("receive_damage_payload")
		or node.has_method("receive_magic_hit")
	)


func _deliver_payload(target: Node) -> Dictionary:
	var payload: DamagePayload = get_payload().duplicate(true) as DamagePayload
	var payload_receiver: Node = target.get_node_or_null("PayloadReceiver")
	if payload_receiver != null and payload_receiver.has_method("receive_payload"):
		var receiver_result: Variant = payload_receiver.call("receive_payload", payload)
		return (
			(receiver_result as Dictionary).duplicate(true)
			if receiver_result is Dictionary
			else {}
		)
	if target.has_method("receive_damage_payload"):
		var direct_result: Variant = target.call("receive_damage_payload", payload)
		return (
			(direct_result as Dictionary).duplicate(true)
			if direct_result is Dictionary
			else {}
		)
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if hit_receiver != null and hit_receiver.has_method("receive_payload"):
		var hit_result: Variant = hit_receiver.call("receive_payload", payload)
		return (
			(hit_result as Dictionary).duplicate(true)
			if hit_result is Dictionary
			else {}
		)
	if target.has_method("receive_magic_hit"):
		var legacy_result: Variant = target.call("receive_magic_hit", payload.amount)
		return (
			(legacy_result as Dictionary).duplicate(true)
			if legacy_result is Dictionary
			else {}
		)
	return {}


func get_payload() -> DamagePayload:
	if runtime_payload != null:
		return runtime_payload
	var fallback := DamagePayload.new()
	fallback.amount = 5
	fallback.stance_damage = 4
	fallback.element = "lightning"
	fallback.source_name = "Lightning Bolt"
	fallback.hit_type = "sky_strike"
	fallback.status_effect = "stunned"
	fallback.status_duration = 0.6
	fallback.status_strength = 1.0
	fallback.tags = [
		"lightning",
		"magic",
		"ground_targeted",
		"sky_strike",
		"direct_strike",
		"burst",
	]
	return fallback


func _get_target_position(target: Node) -> Vector3:
	if target is Node3D:
		return (target as Node3D).global_position
	var parent: Node = target.get_parent()
	return (
		(parent as Node3D).global_position
		if parent is Node3D
		else global_position
	)


func _collect_collision_rids(node: Node, target: Array[RID]) -> void:
	if node is CollisionObject3D:
		var rid: RID = (node as CollisionObject3D).get_rid()
		if rid.is_valid() and not target.has(rid):
			target.append(rid)
	for child: Node in node.get_children():
		_collect_collision_rids(child, target)


func _build_visuals() -> void:
	warning_root = Node3D.new()
	warning_root.name = "WarningRoot"
	add_child(warning_root)

	warning_disc = _create_disc(
		"OuterWarningDisc",
		preview_radius,
		Color(0.12, 0.28, 1.0, 0.22),
		1.4
	)
	warning_disc.position.y = 0.035
	warning_root.add_child(warning_disc)

	direct_disc = _create_disc(
		"DirectStrikeDisc",
		strike_radius,
		Color(0.72, 0.9, 1.0, 0.72),
		3.6
	)
	direct_disc.position.y = 0.065
	warning_root.add_child(direct_disc)

	bolt_root = Node3D.new()
	bolt_root.name = "BoltRoot"
	bolt_root.visible = false
	add_child(bolt_root)

	main_bolt = MeshInstance3D.new()
	main_bolt.name = "MainBolt"
	main_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bolt_mesh := CylinderMesh.new()
	bolt_mesh.top_radius = 0.075
	bolt_mesh.bottom_radius = 0.16
	bolt_mesh.height = sky_height
	bolt_mesh.radial_segments = 8
	main_bolt.mesh = bolt_mesh
	main_bolt.position = Vector3(0.0, sky_height * 0.5, 0.0)
	main_bolt.material_override = _make_lightning_material(
		Color(0.76, 0.92, 1.0, 0.96),
		6.5
	)
	bolt_root.add_child(main_bolt)

	for branch_index: int in range(4):
		var branch := MeshInstance3D.new()
		branch.name = "BoltBranch" + str(branch_index + 1)
		branch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var branch_mesh := BoxMesh.new()
		branch_mesh.size = Vector3(0.045, 2.4, 0.045)
		branch.mesh = branch_mesh
		branch.position = Vector3(
			(-0.34 if branch_index % 2 == 0 else 0.34),
			2.1 + float(branch_index) * 2.7,
			(-0.16 if branch_index < 2 else 0.16)
		)
		branch.rotation_degrees = Vector3(
			12.0 * (-1.0 if branch_index < 2 else 1.0),
			20.0 * float(branch_index),
			18.0 * (-1.0 if branch_index % 2 == 0 else 1.0)
		)
		branch.material_override = _make_lightning_material(
			Color(0.34, 0.58, 1.0, 0.82),
			4.8
		)
		bolt_root.add_child(branch)

	impact_flash = _create_disc(
		"ImpactFlash",
		strike_radius * 1.25,
		Color(0.72, 0.92, 1.0, 0.82),
		5.8
	)
	impact_flash.position.y = 0.08
	bolt_root.add_child(impact_flash)

	strike_light = OmniLight3D.new()
	strike_light.name = "StrikeLight"
	strike_light.position = Vector3(0.0, 1.4, 0.0)
	strike_light.light_color = Color(0.58, 0.78, 1.0)
	strike_light.light_energy = 5.2
	strike_light.omni_range = 9.0
	strike_light.shadow_enabled = false
	bolt_root.add_child(strike_light)


func _create_disc(
	node_name: String,
	radius: float,
	color: Color,
	emission_energy: float
) -> MeshInstance3D:
	var disc := MeshInstance3D.new()
	disc.name = node_name
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := CylinderMesh.new()
	mesh.top_radius = maxf(radius, 0.05)
	mesh.bottom_radius = maxf(radius, 0.05)
	mesh.height = 0.035
	mesh.radial_segments = 32
	disc.mesh = mesh
	disc.material_override = _make_lightning_material(color, emission_energy)
	return disc


func _make_lightning_material(
	color: Color,
	emission_energy: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = emission_energy
	return material


func _update_warning_visual() -> void:
	if warning_root == null:
		return
	var pulse: float = 1.0 + sin(elapsed * warning_pulse_speed * TAU) * warning_pulse_size
	warning_root.scale = Vector3(pulse, 1.0, pulse)
	if direct_disc != null:
		var center_pulse: float = 1.0 + sin(elapsed * 19.0) * 0.11
		direct_disc.scale = Vector3(center_pulse, 1.0, center_pulse)


func _update_impact_visual() -> void:
	var ratio: float = clampf(
		impact_remaining / maxf(impact_visual_seconds, 0.05),
		0.0,
		1.0
	)
	if bolt_root != null:
		var flicker: float = 0.82 + absf(sin(elapsed * 47.0)) * 0.32
		bolt_root.scale = Vector3(flicker, 1.0, flicker)
	if strike_light != null:
		strike_light.light_energy = 1.0 + ratio * 5.2
	if impact_flash != null:
		impact_flash.scale = Vector3.ONE * (1.0 + (1.0 - ratio) * 0.8)
		impact_flash.modulate.a = ratio


func get_debug_data() -> Dictionary:
	return {
		"lightning_bolt_strike": true,
		"active": active,
		"struck": struck,
		"elapsed": snappedf(elapsed, 0.01),
		"warning_seconds": warning_seconds,
		"strike_radius": strike_radius,
		"preview_radius": preview_radius,
		"peripheral_effect_count": 0,
		"peripheral_upgrade_reserved": preview_radius > strike_radius,
		"hit_count": hit_target_ids.size(),
		"targets": hit_target_names.duplicate(),
		"payload_amount": get_payload().amount,
		"payload_stance_damage": get_payload().stance_damage,
		"results": last_results.duplicate(true),
	}
