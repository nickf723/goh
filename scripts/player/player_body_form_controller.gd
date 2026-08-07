extends Node3D
class_name PlayerBodyFormController

signal form_change_requested(requested_form: String, resolved_form: String)
signal form_changed(
	previous_form: String,
	current_form: String,
	scale_multiplier: float
)
signal form_change_rejected(requested_form: String, reason: String)
signal form_transition_finished(current_form: String)

const GameplayEffectAccessScript = preload(
	"res://scripts/effects/gameplay_effect_access.gd"
)
const ControllerHapticPatternScript = preload(
	"res://scripts/input/controller_haptic_pattern.gd"
)

const FORM_NORMAL: String = "normal"
const FORM_GROWN: String = "grown"
const FORM_SHRUNK: String = "shrunk"
const VALID_FORMS: Array[String] = [
	FORM_NORMAL,
	FORM_GROWN,
	FORM_SHRUNK,
]

@export_group("Form Scale")
@export_range(1.05, 3.0, 0.05) var grown_scale: float = 1.55
@export_range(0.25, 0.95, 0.01) var shrunk_scale: float = 0.58
@export_range(0.05, 1.0, 0.01) var transition_seconds: float = 0.28
@export_range(0.0, 0.2, 0.005) var clearance_probe_margin: float = 0.035

@export_group("Form Mass")
@export_range(1.0, 300.0, 1.0) var normal_mass_kg: float = 70.0
@export_range(1.0, 500.0, 1.0) var grown_mass_kg: float = 150.0
@export_range(1.0, 100.0, 1.0) var shrunk_mass_kg: float = 24.0

@export_group("Scene Paths")
@export var collision_shape_path: NodePath = NodePath("../CollisionShape3D")
@export var debug_capsule_path: NodePath = NodePath("../MeshInstance3D")
@export var visual_path: NodePath = NodePath("../GraceVisualV1")
@export var camera_pivot_path: NodePath = NodePath("../CameraPivot")
@export var spring_arm_path: NodePath = NodePath("../CameraPivot/SpringArm3D")
@export var interaction_area_path: NodePath = NodePath("../InteractionArea")
@export var weapon_controller_path: NodePath = NodePath("../WeaponController")
@export var ability_caster_path: NodePath = NodePath("../AbilityCaster")
@export var airflow_response_path: NodePath = NodePath("../AirflowResponse")

@export_group("Presentation")
@export_range(0.0, 8.0, 0.1) var aura_emission_energy: float = 2.1
@export_range(0.0, 8.0, 0.1) var transition_light_energy: float = 3.4
@export_range(0.1, 10.0, 0.1) var transition_light_range: float = 4.2
@export_range(0.0, 1.0, 0.05) var haptic_strength_scale: float = 1.0
@export var show_debug_messages: bool = false

var actor: CharacterBody3D = null
var collision_shape: CollisionShape3D = null
var debug_capsule: MeshInstance3D = null
var grace_visual: Node3D = null
var camera_pivot: Node3D = null
var spring_arm: SpringArm3D = null
var interaction_area: Area3D = null
var weapon_controller: Node3D = null
var ability_caster: Node = null
var airflow_response: Node = null

var baseline_ready: bool = false
var current_form: String = FORM_NORMAL
var current_scale: float = 1.0
var current_collision_height: float = 1.92
var current_collision_radius: float = 0.46
var current_mass_kg: float = 70.0
var transition_count: int = 0
var rejected_transition_count: int = 0
var last_rejection_reason: String = "none"
var last_requested_form: String = FORM_NORMAL

var base_collision_height: float = 1.92
var base_collision_radius: float = 0.46
var base_visual_scale: Vector3 = Vector3.ONE
var base_visual_position: Vector3 = Vector3(0.0, -0.92, 0.0)
var base_visual_ground_offset: float = 0.04
var base_camera_position: Vector3 = Vector3(0.0, 0.5, 0.0)
var base_spring_length: float = 6.0
var base_interaction_scale: Vector3 = Vector3.ONE
var base_weapon_scale: Vector3 = Vector3.ONE
var base_weapon_attack_origin_height: float = 1.0
var base_cast_spawn_height: float = 0.3
var base_floor_snap_length: float = 0.42
var base_airflow_mass_kg: float = 65.0
var base_airflow_cross_section: float = 0.78

var transition_tween: Tween = null
var aura_root: Node3D = null
var aura_inner: MeshInstance3D = null
var aura_outer: MeshInstance3D = null
var aura_material: StandardMaterial3D = null
var transition_light: OmniLight3D = null
var aura_time: float = 0.0
var pending_aura_hide: bool = false


func _ready() -> void:
	actor = get_parent() as CharacterBody3D
	add_to_group("player_body_form_controller")
	add_to_group("lab_resettable")
	add_to_group("debuggable")
	_build_aura()
	set_process(false)
	call_deferred("_capture_baseline")
	if not GameState.player_defeated.is_connected(_on_player_reset_event):
		GameState.player_defeated.connect(_on_player_reset_event)
	if not GameState.rest_resources_restored.is_connected(_on_player_reset_event):
		GameState.rest_resources_restored.connect(_on_player_reset_event)


func _exit_tree() -> void:
	_remove_form_effect()
	if GameState.player_defeated.is_connected(_on_player_reset_event):
		GameState.player_defeated.disconnect(_on_player_reset_event)
	if GameState.rest_resources_restored.is_connected(_on_player_reset_event):
		GameState.rest_resources_restored.disconnect(_on_player_reset_event)


func _process(delta: float) -> void:
	if current_form == FORM_NORMAL or aura_root == null:
		return
	aura_time += maxf(delta, 0.0)
	var pulse: float = 1.0 + sin(aura_time * 4.8) * 0.045
	var counter_pulse: float = 1.0 + sin(aura_time * 5.6 + 1.7) * 0.035
	if aura_inner != null:
		aura_inner.rotation.y += delta * (1.4 if current_form == FORM_GROWN else 2.8)
		aura_inner.scale = Vector3.ONE * pulse
	if aura_outer != null:
		aura_outer.rotation.y -= delta * (0.9 if current_form == FORM_GROWN else 3.4)
		aura_outer.scale = Vector3.ONE * counter_pulse


func request_form(requested_form: String) -> Dictionary:
	if not _ensure_baseline():
		return _reject_form(requested_form, "body form controller is not ready")
	var normalized: String = requested_form.strip_edges().to_lower()
	if normalized not in [FORM_GROWN, FORM_SHRUNK]:
		return _reject_form(requested_form, "unknown body form")
	last_requested_form = normalized
	var resolved_form: String = (
		FORM_NORMAL if current_form == normalized else normalized
	)
	form_change_requested.emit(normalized, resolved_form)
	if not can_fit_form(resolved_form):
		return _reject_form(
			normalized,
			"not enough room to expand into " + resolved_form
		)
	var previous: String = current_form
	_apply_form(resolved_form, true)
	return {
		"success": true,
		"requested_form": normalized,
		"previous_form": previous,
		"current_form": current_form,
		"returned_to_normal": current_form == FORM_NORMAL,
		"scale": current_scale,
		"mass_kg": current_mass_kg,
		"message": _get_form_message(current_form),
	}


func force_form(
	form_id: String,
	bypass_clearance: bool = true,
	animate: bool = false
) -> bool:
	if not _ensure_baseline():
		return false
	var normalized: String = form_id.strip_edges().to_lower()
	if normalized not in VALID_FORMS:
		return false
	if not bypass_clearance and not can_fit_form(normalized):
		return false
	_apply_form(normalized, animate)
	return true


func reset_target() -> void:
	if not _ensure_baseline():
		return
	_apply_form(FORM_NORMAL, false)
	last_rejection_reason = "none"
	last_requested_form = FORM_NORMAL


func can_fit_form(form_id: String) -> bool:
	if not _ensure_baseline():
		return false
	var normalized: String = form_id.strip_edges().to_lower()
	if normalized not in VALID_FORMS:
		return false
	var target_scale: float = _get_form_scale(normalized)
	var target_height: float = base_collision_height * target_scale
	var target_radius: float = base_collision_radius * target_scale
	if target_height <= current_collision_height + 0.001:
		return true
	if actor == null or actor.get_world_3d() == null:
		return false

	var test_shape := CapsuleShape3D.new()
	test_shape.radius = maxf(
		target_radius - clearance_probe_margin * 0.4,
		0.04
	)
	test_shape.height = maxf(
		target_height - clearance_probe_margin * 2.0,
		test_shape.radius * 2.0
	)
	var bottom_y: float = actor.global_position.y - current_collision_height * 0.5
	var test_position := Vector3(
		actor.global_position.x,
		bottom_y + target_height * 0.5 + clearance_probe_margin,
		actor.global_position.z
	)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = test_shape
	query.transform = Transform3D(Basis.IDENTITY, test_position)
	query.collision_mask = actor.collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.margin = 0.0
	query.exclude = _collect_actor_collision_rids()
	var hits: Array[Dictionary] = actor.get_world_3d().direct_space_state.intersect_shape(
		query,
		32
	)
	for hit: Dictionary in hits:
		var collider_value: Variant = hit.get("collider")
		if not collider_value is Node:
			return false
		var collider: Node = collider_value as Node
		if collider == actor or actor.is_ancestor_of(collider):
			continue
		return false
	return true


func get_current_form() -> String:
	return current_form


func get_current_scale() -> float:
	return current_scale


func get_current_mass_kg() -> float:
	return current_mass_kg


func is_grown() -> bool:
	return current_form == FORM_GROWN


func is_shrunk() -> bool:
	return current_form == FORM_SHRUNK


func is_transformed() -> bool:
	return current_form != FORM_NORMAL


func _capture_baseline() -> bool:
	if baseline_ready:
		return true
	if actor == null:
		actor = get_parent() as CharacterBody3D
	if actor == null:
		return false

	collision_shape = get_node_or_null(collision_shape_path) as CollisionShape3D
	debug_capsule = get_node_or_null(debug_capsule_path) as MeshInstance3D
	grace_visual = get_node_or_null(visual_path) as Node3D
	camera_pivot = get_node_or_null(camera_pivot_path) as Node3D
	spring_arm = get_node_or_null(spring_arm_path) as SpringArm3D
	interaction_area = get_node_or_null(interaction_area_path) as Area3D
	weapon_controller = get_node_or_null(weapon_controller_path) as Node3D
	ability_caster = get_node_or_null(ability_caster_path)
	airflow_response = get_node_or_null(airflow_response_path)
	if collision_shape == null or not collision_shape.shape is CapsuleShape3D:
		return false

	var capsule: CapsuleShape3D = collision_shape.shape as CapsuleShape3D
	base_collision_height = maxf(capsule.height, capsule.radius * 2.0)
	base_collision_radius = maxf(capsule.radius, 0.04)
	current_collision_height = base_collision_height
	current_collision_radius = base_collision_radius
	if grace_visual != null:
		base_visual_scale = grace_visual.scale
		base_visual_position = grace_visual.position
		base_visual_ground_offset = (
			base_visual_position.y + base_collision_height * 0.5
		)
	if camera_pivot != null:
		base_camera_position = camera_pivot.position
	if spring_arm != null:
		base_spring_length = spring_arm.spring_length
	if interaction_area != null:
		base_interaction_scale = interaction_area.scale
	if weapon_controller != null:
		base_weapon_scale = weapon_controller.scale
		var attack_origin_value: Variant = weapon_controller.get(
			"attack_origin_height"
		)
		if attack_origin_value != null:
			base_weapon_attack_origin_height = float(attack_origin_value)
	if ability_caster != null:
		var spawn_height_value: Variant = ability_caster.get("cast_spawn_height")
		if spawn_height_value != null:
			base_cast_spawn_height = float(spawn_height_value)
	base_floor_snap_length = actor.floor_snap_length
	if airflow_response != null:
		var mass_value: Variant = airflow_response.get("mass_override_kg")
		var area_value: Variant = airflow_response.get("cross_section_area")
		if mass_value != null:
			base_airflow_mass_kg = float(mass_value)
		if area_value != null:
			base_airflow_cross_section = float(area_value)

	baseline_ready = true
	current_form = FORM_NORMAL
	current_scale = 1.0
	current_mass_kg = normal_mass_kg
	_apply_actor_metadata(FORM_NORMAL, 1.0, normal_mass_kg)
	_update_aura_for_form(FORM_NORMAL)
	return true


func _ensure_baseline() -> bool:
	return baseline_ready or _capture_baseline()


func _apply_form(form_id: String, animate: bool) -> void:
	var previous_form: String = current_form
	var previous_visual_scale: Vector3 = (
		grace_visual.scale if grace_visual != null else base_visual_scale
	)
	var previous_weapon_scale: Vector3 = (
		weapon_controller.scale
		if weapon_controller != null
		else base_weapon_scale
	)
	var target_scale: float = _get_form_scale(form_id)
	var target_mass: float = _get_form_mass(form_id)
	var target_height: float = base_collision_height * target_scale
	var target_radius: float = base_collision_radius * target_scale
	var bottom_y: float = actor.global_position.y - current_collision_height * 0.5

	_kill_transition_tween()
	current_form = form_id
	current_scale = target_scale
	current_mass_kg = target_mass
	current_collision_height = target_height
	current_collision_radius = target_radius

	_apply_collision_shape(target_height, target_radius)
	actor.global_position.y = bottom_y + target_height * 0.5
	_apply_nonvisual_runtime(target_scale, target_mass, target_height, target_radius)
	_apply_form_effect(form_id)
	_refresh_effect_groups()
	_update_aura_for_form(form_id)
	transition_count += 1

	var target_visual_scale: Vector3 = base_visual_scale * target_scale
	var target_weapon_scale: Vector3 = base_weapon_scale * target_scale
	if grace_visual != null:
		var target_visual_position: Vector3 = base_visual_position
		target_visual_position.y = (
			-target_height * 0.5 + base_visual_ground_offset
		)
		grace_visual.position = target_visual_position
	if not animate or transition_seconds <= 0.0:
		if grace_visual != null:
			grace_visual.scale = target_visual_scale
		if weapon_controller != null:
			weapon_controller.scale = target_weapon_scale
		_apply_camera_targets(target_scale, false)
		_on_transition_finished()
	else:
		if grace_visual != null:
			grace_visual.scale = previous_visual_scale
		if weapon_controller != null:
			weapon_controller.scale = previous_weapon_scale
		_start_visual_transition(target_visual_scale, target_weapon_scale, target_scale)

	form_changed.emit(previous_form, current_form, current_scale)
	_refresh_dynamic_mass_mechanisms()
	_play_form_haptics(current_form)
	if show_debug_messages:
		print(
			"BODY_FORM ",
			previous_form,
			" -> ",
			current_form,
			" scale=",
			current_scale,
			" mass=",
			current_mass_kg
		)


func _apply_collision_shape(target_height: float, target_radius: float) -> void:
	if collision_shape != null and collision_shape.shape is CapsuleShape3D:
		var capsule := (
			(collision_shape.shape as CapsuleShape3D).duplicate(true)
			as CapsuleShape3D
		)
		capsule.radius = maxf(target_radius, 0.04)
		capsule.height = maxf(target_height, capsule.radius * 2.0)
		collision_shape.shape = capsule
	if debug_capsule != null and debug_capsule.mesh is CapsuleMesh:
		var mesh := (
			(debug_capsule.mesh as CapsuleMesh).duplicate(true)
			as CapsuleMesh
		)
		mesh.radius = maxf(target_radius, 0.04)
		mesh.height = maxf(target_height, mesh.radius * 2.0)
		debug_capsule.mesh = mesh


func _apply_nonvisual_runtime(
	target_scale: float,
	target_mass: float,
	target_height: float,
	target_radius: float
) -> void:
	if interaction_area != null:
		var interaction_scale: float = clampf(target_scale, 0.62, 1.65)
		interaction_area.scale = base_interaction_scale * interaction_scale
	if weapon_controller != null:
		weapon_controller.set(
			"attack_origin_height",
			base_weapon_attack_origin_height * target_scale
		)
	if ability_caster != null:
		ability_caster.set(
			"cast_spawn_height",
			base_cast_spawn_height * target_scale
		)
	actor.floor_snap_length = base_floor_snap_length * clampf(
		target_scale,
		0.65,
		1.45
	)
	if airflow_response != null:
		airflow_response.set(
			"mass_override_kg",
			base_airflow_mass_kg * (target_mass / maxf(normal_mass_kg, 1.0))
		)
		airflow_response.set(
			"cross_section_area",
			base_airflow_cross_section * target_scale * target_scale
		)
	_apply_actor_metadata(
		current_form,
		target_scale,
		target_mass,
		target_height,
		target_radius
	)


func _apply_actor_metadata(
	form_id: String,
	scale_value: float,
	mass_value: float,
	height_value: float = -1.0,
	radius_value: float = -1.0
) -> void:
	if actor == null:
		return
	var resolved_height: float = (
		height_value if height_value > 0.0 else base_collision_height * scale_value
	)
	var resolved_radius: float = (
		radius_value if radius_value > 0.0 else base_collision_radius * scale_value
	)
	actor.set_meta("body_form_id", form_id)
	actor.set_meta("body_form_scale", scale_value)
	actor.set_meta("body_form_mass_kg", mass_value)
	actor.set_meta("mechanism_mass_kg", mass_value)
	actor.set_meta("player_collision_height", resolved_height)
	actor.set_meta("player_collision_radius", resolved_radius)
	actor.set_meta("body_form_power_multiplier", _get_form_power(form_id))
	actor.set_meta("body_form_speed_multiplier", _get_form_speed(form_id))


func _start_visual_transition(
	target_visual_scale: Vector3,
	target_weapon_scale: Vector3,
	target_scale: float
) -> void:
	transition_tween = create_tween()
	transition_tween.set_trans(Tween.TRANS_BACK)
	transition_tween.set_ease(Tween.EASE_OUT)
	transition_tween.set_parallel(true)
	if grace_visual != null:
		transition_tween.tween_property(
			grace_visual,
			"scale",
			target_visual_scale,
			transition_seconds
		)
	if weapon_controller != null:
		transition_tween.tween_property(
			weapon_controller,
			"scale",
			target_weapon_scale,
			transition_seconds
		)
	_apply_camera_targets(target_scale, true)
	if transition_light != null:
		transition_light.light_energy = transition_light_energy
		transition_tween.tween_property(
			transition_light,
			"light_energy",
			0.0,
			transition_seconds
		)
	transition_tween.finished.connect(_on_transition_finished)


func _apply_camera_targets(target_scale: float, use_tween: bool) -> void:
	var target_camera_position: Vector3 = base_camera_position
	target_camera_position.y = base_camera_position.y * target_scale
	var target_spring_length: float = maxf(
		base_spring_length + (target_scale - 1.0) * 1.25,
		3.5
	)
	if use_tween and transition_tween != null:
		if camera_pivot != null:
			transition_tween.tween_property(
				camera_pivot,
				"position",
				target_camera_position,
				transition_seconds
			)
		if spring_arm != null:
			transition_tween.tween_property(
				spring_arm,
				"spring_length",
				target_spring_length,
				transition_seconds
			)
		return
	if camera_pivot != null:
		camera_pivot.position = target_camera_position
	if spring_arm != null:
		spring_arm.spring_length = target_spring_length


func _on_transition_finished() -> void:
	transition_tween = null
	if pending_aura_hide and current_form == FORM_NORMAL:
		pending_aura_hide = false
		if aura_root != null:
			aura_root.visible = false
	form_transition_finished.emit(current_form)


func _kill_transition_tween() -> void:
	if transition_tween != null and transition_tween.is_valid():
		transition_tween.kill()
	transition_tween = null


func _apply_form_effect(form_id: String) -> void:
	var source_id: String = _get_effect_source_id()
	match form_id:
		FORM_GROWN:
			GameplayEffectAccessScript.set_effect_source(
				source_id,
				["body_form_grown"],
				-1.0,
				["body_form", "transformation", "grown"]
			)
		FORM_SHRUNK:
			GameplayEffectAccessScript.set_effect_source(
				source_id,
				["body_form_shrunk"],
				-1.0,
				["body_form", "transformation", "shrunk"]
			)
		_:
			GameplayEffectAccessScript.remove_effect_source(source_id)


func _remove_form_effect() -> void:
	GameplayEffectAccessScript.remove_effect_source(_get_effect_source_id())


func _get_effect_source_id() -> String:
	return (
		"body_form:" + str(actor.get_instance_id())
		if actor != null
		else "body_form:unbound"
	)


func _refresh_effect_groups() -> void:
	var active_form: bool = current_form != FORM_NORMAL
	for group_name: String in [
		"spell_effects",
		"persistent_spell_effects",
		"body_form_effects",
	]:
		if active_form and not is_in_group(group_name):
			add_to_group(group_name)
		elif not active_form and is_in_group(group_name):
			remove_from_group(group_name)


func _refresh_dynamic_mass_mechanisms() -> void:
	if get_tree() == null:
		return
	for node: Node in get_tree().get_nodes_in_group(
		"mechanism_value_sources"
	):
		if node != null and node.has_method("refresh_pressed_state"):
			node.call_deferred("refresh_pressed_state")


func _build_aura() -> void:
	aura_root = Node3D.new()
	aura_root.name = "BodyFormAura"
	add_child(aura_root)

	aura_material = StandardMaterial3D.new()
	aura_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aura_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	aura_material.emission_enabled = true
	aura_material.emission_energy_multiplier = aura_emission_energy

	aura_inner = _make_aura_ring("InnerBodyFormRing", 0.42, 0.49)
	aura_outer = _make_aura_ring("OuterBodyFormRing", 0.56, 0.62)
	transition_light = OmniLight3D.new()
	transition_light.name = "BodyFormTransitionLight"
	transition_light.shadow_enabled = false
	transition_light.omni_range = transition_light_range
	transition_light.light_energy = 0.0
	aura_root.add_child(transition_light)
	aura_root.visible = false


func _make_aura_ring(
	ring_name: String,
	inner_radius: float,
	outer_radius: float
) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	ring.name = ring_name
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 24
	mesh.ring_segments = 8
	ring.mesh = mesh
	ring.material_override = aura_material
	aura_root.add_child(ring)
	return ring


func _update_aura_for_form(form_id: String) -> void:
	if aura_root == null or aura_material == null:
		return
	if form_id == FORM_NORMAL:
		pending_aura_hide = true
		set_process(false)
		if transition_tween == null:
			aura_root.visible = false
			pending_aura_hide = false
		return
	pending_aura_hide = false
	aura_root.visible = true
	set_process(true)
	aura_time = 0.0
	var form_color: Color = (
		Color(1.0, 0.16, 0.58, 0.72)
		if form_id == FORM_GROWN
		else Color(0.64, 0.36, 1.0, 0.74)
	)
	aura_material.albedo_color = form_color
	aura_material.emission = Color(
		form_color.r,
		form_color.g,
		form_color.b,
		1.0
	)
	if transition_light != null:
		transition_light.light_color = form_color
	var bottom_y: float = -current_collision_height * 0.5
	if aura_inner != null:
		aura_inner.position = Vector3(0.0, bottom_y + 0.10, 0.0)
		aura_inner.scale = Vector3.ONE * maxf(current_scale, 0.45)
	if aura_outer != null:
		aura_outer.position = Vector3(
			0.0,
			bottom_y + current_collision_height * 0.56,
			0.0
		)
		aura_outer.scale = Vector3.ONE * maxf(current_scale * 0.82, 0.42)


func _play_form_haptics(form_id: String) -> void:
	if get_tree() == null or get_tree().current_scene == null:
		return
	var pattern := ControllerHapticPatternScript.new() as ControllerHapticPattern
	get_tree().current_scene.add_child(pattern)
	var steps: Array = []
	match form_id:
		FORM_GROWN:
			steps = [
				{"weak": 0.16, "strong": 0.42, "duration": 0.06},
				{"weak": 0.25, "strong": 0.72, "duration": 0.10},
				{"weak": 0.12, "strong": 0.32, "duration": 0.08},
			]
		FORM_SHRUNK:
			steps = [
				{"weak": 0.54, "strong": 0.10, "duration": 0.035},
				{"weak": 0.0, "strong": 0.0, "duration": 0.018},
				{"weak": 0.42, "strong": 0.08, "duration": 0.04},
			]
		_:
			steps = [
				{"weak": 0.18, "strong": 0.18, "duration": 0.055},
			]
	pattern.play_pattern(
		"body_form_" + form_id,
		steps,
		actor,
		haptic_strength_scale
	)


func _collect_actor_collision_rids() -> Array[RID]:
	var result: Array[RID] = []
	_collect_collision_rids(actor, result)
	return result


func _collect_collision_rids(node: Node, target: Array[RID]) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node is CollisionObject3D:
		var rid: RID = (node as CollisionObject3D).get_rid()
		if rid.is_valid() and not target.has(rid):
			target.append(rid)
	for child: Node in node.get_children():
		_collect_collision_rids(child, target)


func _get_form_scale(form_id: String) -> float:
	match form_id:
		FORM_GROWN:
			return grown_scale
		FORM_SHRUNK:
			return shrunk_scale
	return 1.0


func _get_form_mass(form_id: String) -> float:
	match form_id:
		FORM_GROWN:
			return grown_mass_kg
		FORM_SHRUNK:
			return shrunk_mass_kg
	return normal_mass_kg


func _get_form_power(form_id: String) -> float:
	match form_id:
		FORM_GROWN:
			return 1.5
		FORM_SHRUNK:
			return 0.72
	return 1.0


func _get_form_speed(form_id: String) -> float:
	match form_id:
		FORM_GROWN:
			return 0.78
		FORM_SHRUNK:
			return 1.35
	return 1.0


func _reject_form(requested_form: String, reason: String) -> Dictionary:
	rejected_transition_count += 1
	last_rejection_reason = reason
	form_change_rejected.emit(requested_form, reason)
	_show_message("Body form rejected: " + reason + ".")
	return {
		"success": false,
		"requested_form": requested_form,
		"current_form": current_form,
		"reason": reason,
		"message": "Body form rejected: " + reason + ".",
	}


func _get_form_message(form_id: String) -> String:
	match form_id:
		FORM_GROWN:
			return "Grow: Grace becomes massive, powerful, and difficult to move."
		FORM_SHRUNK:
			return "Shrink: Grace becomes quick, light, and small enough for narrow routes."
	return "Grace returns to her ordinary size."


func _show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	elif show_debug_messages:
		print(text)


func _on_player_reset_event() -> void:
	if baseline_ready:
		_apply_form(FORM_NORMAL, false)


func get_debug_data() -> Dictionary:
	return {
		"body_form_controller": true,
		"baseline_ready": baseline_ready,
		"form": current_form,
		"scale": current_scale,
		"mass_kg": current_mass_kg,
		"collision_height": current_collision_height,
		"collision_radius": current_collision_radius,
		"transformed": is_transformed(),
		"grown": is_grown(),
		"shrunk": is_shrunk(),
		"can_fit_normal": can_fit_form(FORM_NORMAL) if baseline_ready else false,
		"can_fit_grown": can_fit_form(FORM_GROWN) if baseline_ready else false,
		"transitions": transition_count,
		"rejections": rejected_transition_count,
		"last_requested_form": last_requested_form,
		"last_rejection": last_rejection_reason,
		"effect_source_id": _get_effect_source_id(),
		"spell_effect_group": is_in_group("spell_effects"),
		"persistent_group": is_in_group("persistent_spell_effects"),
		"mechanism_mass_meta": (
			float(actor.get_meta("mechanism_mass_kg", 0.0))
			if actor != null
			else 0.0
		),
	}
