extends "res://scripts/divine_specials/divine_special_effect.gd"
class_name RuviaHearthOfFirstFlame

@export_range(2.0, 30.0, 0.25) var fallback_duration: float = 10.0
@export_range(0.2, 2.0, 0.05) var pulse_interval: float = 0.55
@export_range(0.5, 8.0, 0.1) var domain_radius: float = 6.4
@export_range(0.5, 8.0, 0.1) var field_flare_interval: float = 2.4
@export_range(0, 10, 1) var stance_recovery_per_pulse: int = 2

var duration_remaining: float = 0.0
var pulse_remaining: float = 0.0
var field_flare_remaining: float = 0.0
var immunity_token: String = ""
var domain_visual: MeshInstance3D
var domain_core: MeshInstance3D
var pulses_completed: int = 0
var fields_flared: int = 0
var stance_restored: int = 0


func begin_special() -> bool:
	if not super.begin_special():
		return false
	domain_radius = maxf(
		domain_radius,
		definition.area_radius if definition != null else domain_radius
	)
	target_position = project_point_to_floor(target_position)
	global_position = target_position
	duration_remaining = maxf(
		definition.active_duration
		if definition != null and definition.active_duration > 0.0
		else fallback_duration,
		0.1
	)
	pulse_remaining = 0.0
	field_flare_remaining = 0.0
	immunity_token = str(get_instance_id())
	owner_actor.set_meta("divine_special_fire_immunity", true)
	owner_actor.set_meta("divine_special_fire_immunity_token", immunity_token)
	_remove_owner_burning()
	_build_domain_visuals()
	if performer_actor == null or performer_actor != owner_actor:
		spawn_patron_projection(
			target_position + Vector3.UP * 0.96,
			atan2(-cast_direction.x, -cast_direction.z),
			1.08
		)
	spawn_pulse_disc(
		target_position + Vector3.UP * 0.045,
		0.35,
		domain_radius,
		0.52,
		Color(1.0, 0.48, 0.06, 0.62),
		0.1
	)
	return true


func _process(delta: float) -> void:
	super._process(delta)
	if not started or finished:
		return
	var step: float = maxf(delta, 0.0)
	duration_remaining = maxf(duration_remaining - step, 0.0)
	pulse_remaining = maxf(pulse_remaining - step, 0.0)
	field_flare_remaining = maxf(field_flare_remaining - step, 0.0)
	_update_domain_visual()
	if pulse_remaining <= 0.0:
		pulse_remaining = maxf(pulse_interval, 0.1)
		_apply_domain_pulse()
	if field_flare_remaining <= 0.0:
		field_flare_remaining = maxf(field_flare_interval, 0.2)
		fields_flared += _flare_fire_fields()
	if duration_remaining <= 0.0:
		_finish_special(
			true,
			"hearth_duration_completed",
			{
				"pulses_completed": pulses_completed,
				"fields_flared": fields_flared,
				"stance_restored": stance_restored,
			}
		)


func _build_domain_visuals() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	domain_visual = MeshInstance3D.new()
	domain_visual.name = "HearthDomainDisc"
	domain_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var disc_mesh: CylinderMesh = CylinderMesh.new()
	disc_mesh.top_radius = 1.0
	disc_mesh.bottom_radius = 1.0
	disc_mesh.height = 0.08
	disc_mesh.radial_segments = 64
	domain_visual.mesh = disc_mesh
	domain_visual.material_override = make_visual_material(
		Color(1.0, 0.24, 0.025, 0.24)
	)
	scene_root.add_child(domain_visual)
	domain_visual.global_position = target_position + Vector3.UP * 0.045
	domain_visual.scale = Vector3(domain_radius, 1.0, domain_radius)

	domain_core = MeshInstance3D.new()
	domain_core.name = "HearthDomainCore"
	domain_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var core_mesh: CylinderMesh = CylinderMesh.new()
	core_mesh.top_radius = 0.6
	core_mesh.bottom_radius = 1.3
	core_mesh.height = 3.2
	core_mesh.radial_segments = 32
	domain_core.mesh = core_mesh
	domain_core.material_override = make_visual_material(
		Color(1.0, 0.52, 0.08, 0.28)
	)
	scene_root.add_child(domain_core)
	domain_core.global_position = target_position + Vector3.UP * 1.55


func _update_domain_visual() -> void:
	var phase: float = elapsed * 3.2
	if domain_visual != null and is_instance_valid(domain_visual):
		var pulse: float = 1.0 + sin(phase) * 0.025
		domain_visual.scale = Vector3(
			domain_radius * pulse,
			1.0,
			domain_radius * pulse
		)
	if domain_core != null and is_instance_valid(domain_core):
		var core_pulse: float = 1.0 + sin(phase * 1.35) * 0.08
		domain_core.scale = Vector3(core_pulse, 1.0, core_pulse)


func _apply_domain_pulse() -> void:
	pulses_completed += 1
	_remove_owner_burning()
	_restore_owner_stance()
	clear_hostile_projectiles(target_position, domain_radius)

	var payload: DamagePayload = DamagePayload.new()
	payload.amount = 1
	payload.stance_damage = 2
	payload.element = "fire"
	payload.source_name = "Hearth of the First Flame"
	payload.hit_type = "divine_special_domain"
	payload.status_effect = "burning"
	payload.status_duration = 1.45
	payload.status_strength = 1.45
	payload.tags = [
		"fire",
		"divine_special",
		"domain",
		"hearth_first_flame",
		"sustained",
	]
	for target: Node in get_targets_in_radius(
		target_position,
		domain_radius,
		48
	):
		apply_payload_to_target(
			target,
			payload,
			target_position,
			0.0,
			0.0
		)

	if pulses_completed % 3 == 1:
		spawn_pulse_disc(
			target_position + Vector3.UP * 0.055,
			domain_radius * 0.25,
			domain_radius,
			0.42,
			Color(1.0, 0.68, 0.12, 0.34),
			0.06
		)


func _remove_owner_burning() -> void:
	if owner_actor == null:
		return
	var status_receiver: Node = owner_actor.get_node_or_null("StatusReceiver")
	if status_receiver != null and status_receiver.has_method("remove_status"):
		status_receiver.call("remove_status", "burning")


func _restore_owner_stance() -> void:
	if stance_recovery_per_pulse <= 0:
		return
	var current_stance: int = GameState.get_stat("stance")
	var maximum_stance: int = GameState.get_stat("max_stance")
	if maximum_stance <= 0 or current_stance >= maximum_stance:
		return
	var restored: int = mini(
		stance_recovery_per_pulse,
		maximum_stance - current_stance
	)
	GameState.set_stat("stance", current_stance + restored)
	stance_restored += restored


func _flare_fire_fields() -> int:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return 0
	var flared: int = 0
	for candidate: Node in _get_descendants(scene_root):
		if not (candidate is FireField):
			continue
		var field: FireField = candidate as FireField
		if field.global_position.distance_to(target_position) > domain_radius:
			continue
		if field.has_method("authority_flare"):
			field.call("authority_flare", 0.18, 0.35, 0.2)
			flared += 1
	return flared


func _cleanup_special() -> void:
	if owner_actor != null and is_instance_valid(owner_actor):
		if str(
			owner_actor.get_meta(
				"divine_special_fire_immunity_token",
				""
			)
		) == immunity_token:
			owner_actor.set_meta("divine_special_fire_immunity", false)
			owner_actor.remove_meta("divine_special_fire_immunity_token")
	if domain_visual != null and is_instance_valid(domain_visual):
		domain_visual.queue_free()
	if domain_core != null and is_instance_valid(domain_core):
		domain_core.queue_free()
	domain_visual = null
	domain_core = null
	super._cleanup_special()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["duration_remaining"] = snappedf(duration_remaining, 0.01)
	data["domain_radius"] = domain_radius
	data["pulses_completed"] = pulses_completed
	data["fields_flared"] = fields_flared
	data["stance_restored"] = stance_restored
	data["owner_fire_immunity"] = (
		owner_actor != null
		and bool(owner_actor.get_meta("divine_special_fire_immunity", false))
	)
	return data
