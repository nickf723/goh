extends Area3D
class_name SlipperySurfaceArea

signal body_registered(body: Node3D)
signal body_unregistered(body: Node3D)

const CHARACTER_SOURCES_META: String = "slippery_surface_sources"
const RIGID_SOURCES_META: String = "slippery_rigid_sources"
const ORIGINAL_LINEAR_DAMP_META: String = "slippery_original_linear_damp"
const ORIGINAL_ANGULAR_DAMP_META: String = "slippery_original_angular_damp"

@export_group("Character Traction")
@export_range(0.01, 1.0, 0.01) var acceleration_multiplier: float = 0.34
@export_range(0.01, 1.0, 0.01) var braking_multiplier: float = 0.08
@export_range(0.01, 1.0, 0.01) var turn_multiplier: float = 0.18
@export_range(0.01, 1.0, 0.01) var reversal_multiplier: float = 0.12

@export_group("Rigid Body Glide")
@export_range(0.0, 2.0, 0.01) var rigid_linear_damp: float = 0.04
@export_range(0.0, 2.0, 0.01) var rigid_angular_damp: float = 0.035

@export_group("Identity")
@export var surface_label: String = "Slippery Ice"
@export var surface_kind: String = "ice"

var tracked_bodies: Dictionary = {}
var registration_count: int = 0
var unregistration_count: int = 0
var rejected_body_count: int = 0
var last_body_name: String = "none"
var last_rejected_body_name: String = "none"


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = true
	var entered_callback := Callable(self, "_on_body_entered")
	var exited_callback := Callable(self, "_on_body_exited")
	if not body_entered.is_connected(entered_callback):
		body_entered.connect(entered_callback)
	if not body_exited.is_connected(exited_callback):
		body_exited.connect(exited_callback)
	add_to_group("slippery_surface_areas")
	add_to_group("debuggable")


func _exit_tree() -> void:
	clear_registered_bodies()


func _on_body_entered(body: Node3D) -> void:
	register_body(body)


func _on_body_exited(body: Node3D) -> void:
	unregister_body(body)


func register_body(body: Node3D) -> void:
	if body == null or not is_instance_valid(body):
		return
	if not _supports_body(body):
		rejected_body_count += 1
		last_rejected_body_name = str(body.name)
		return
	var body_id: int = body.get_instance_id()
	if tracked_bodies.has(body_id):
		return
	tracked_bodies[body_id] = body
	registration_count += 1
	last_body_name = str(body.name)
	_register_character_response(body)
	if body is RigidBody3D:
		_register_rigid_response(body as RigidBody3D)
	body.set_meta("last_slippery_surface_label", surface_label)
	body.set_meta("last_slippery_surface_kind", surface_kind)
	body_registered.emit(body)


func unregister_body(body: Node3D) -> void:
	if body == null:
		return
	var body_id: int = body.get_instance_id()
	if not tracked_bodies.has(body_id):
		return
	tracked_bodies.erase(body_id)
	unregistration_count += 1
	last_body_name = str(body.name)
	_unregister_character_response(body)
	if body is RigidBody3D:
		_unregister_rigid_response(body as RigidBody3D)
	body_unregistered.emit(body)


func _supports_body(body: Node3D) -> bool:
	return body is CharacterBody3D or body is RigidBody3D


func has_registered_body(body: Node) -> bool:
	return (
		body != null
		and is_instance_valid(body)
		and tracked_bodies.has(body.get_instance_id())
	)


func clear_registered_bodies() -> void:
	var bodies: Array[Node3D] = []
	for body_value: Variant in tracked_bodies.values():
		if body_value is Node3D:
			var body := body_value as Node3D
			if body != null and is_instance_valid(body):
				bodies.append(body)
	for body: Node3D in bodies:
		unregister_body(body)
	tracked_bodies.clear()


func _register_character_response(body: Node3D) -> void:
	var sources_value: Variant = body.get_meta(CHARACTER_SOURCES_META, {})
	var sources: Dictionary = (
		(sources_value as Dictionary).duplicate(true)
		if sources_value is Dictionary
		else {}
	)
	sources[get_instance_id()] = {
		"label": surface_label,
		"kind": surface_kind,
		"acceleration_multiplier": clampf(acceleration_multiplier, 0.01, 1.0),
		"braking_multiplier": clampf(braking_multiplier, 0.01, 1.0),
		"turn_multiplier": clampf(turn_multiplier, 0.01, 1.0),
		"reversal_multiplier": clampf(reversal_multiplier, 0.01, 1.0),
	}
	body.set_meta(CHARACTER_SOURCES_META, sources)


func _unregister_character_response(body: Node3D) -> void:
	var sources_value: Variant = body.get_meta(CHARACTER_SOURCES_META, {})
	if not sources_value is Dictionary:
		return
	var sources: Dictionary = (sources_value as Dictionary).duplicate(true)
	sources.erase(get_instance_id())
	if sources.is_empty():
		body.remove_meta(CHARACTER_SOURCES_META)
	else:
		body.set_meta(CHARACTER_SOURCES_META, sources)


func _register_rigid_response(body: RigidBody3D) -> void:
	if not body.has_meta(ORIGINAL_LINEAR_DAMP_META):
		body.set_meta(ORIGINAL_LINEAR_DAMP_META, body.linear_damp)
	if not body.has_meta(ORIGINAL_ANGULAR_DAMP_META):
		body.set_meta(ORIGINAL_ANGULAR_DAMP_META, body.angular_damp)
	var sources_value: Variant = body.get_meta(RIGID_SOURCES_META, {})
	var sources: Dictionary = (
		(sources_value as Dictionary).duplicate(true)
		if sources_value is Dictionary
		else {}
	)
	sources[get_instance_id()] = {
		"linear_damp": maxf(rigid_linear_damp, 0.0),
		"angular_damp": maxf(rigid_angular_damp, 0.0),
		"label": surface_label,
	}
	body.set_meta(RIGID_SOURCES_META, sources)
	_apply_rigid_response(body, sources)
	body.sleeping = false


func _unregister_rigid_response(body: RigidBody3D) -> void:
	var sources_value: Variant = body.get_meta(RIGID_SOURCES_META, {})
	if not sources_value is Dictionary:
		_restore_rigid_response(body)
		return
	var sources: Dictionary = (sources_value as Dictionary).duplicate(true)
	sources.erase(get_instance_id())
	if sources.is_empty():
		body.remove_meta(RIGID_SOURCES_META)
		_restore_rigid_response(body)
		return
	body.set_meta(RIGID_SOURCES_META, sources)
	_apply_rigid_response(body, sources)


func _apply_rigid_response(body: RigidBody3D, sources: Dictionary) -> void:
	var original_linear: float = float(
		body.get_meta(ORIGINAL_LINEAR_DAMP_META, body.linear_damp)
	)
	var original_angular: float = float(
		body.get_meta(ORIGINAL_ANGULAR_DAMP_META, body.angular_damp)
	)
	var resolved_linear: float = original_linear
	var resolved_angular: float = original_angular
	for source_value: Variant in sources.values():
		if not source_value is Dictionary:
			continue
		var source: Dictionary = source_value as Dictionary
		resolved_linear = minf(
			resolved_linear,
			maxf(float(source.get("linear_damp", resolved_linear)), 0.0)
		)
		resolved_angular = minf(
			resolved_angular,
			maxf(float(source.get("angular_damp", resolved_angular)), 0.0)
		)
	body.linear_damp = resolved_linear
	body.angular_damp = resolved_angular


func _restore_rigid_response(body: RigidBody3D) -> void:
	if body.has_meta(ORIGINAL_LINEAR_DAMP_META):
		body.linear_damp = float(body.get_meta(ORIGINAL_LINEAR_DAMP_META))
		body.remove_meta(ORIGINAL_LINEAR_DAMP_META)
	if body.has_meta(ORIGINAL_ANGULAR_DAMP_META):
		body.angular_damp = float(body.get_meta(ORIGINAL_ANGULAR_DAMP_META))
		body.remove_meta(ORIGINAL_ANGULAR_DAMP_META)


func get_debug_data() -> Dictionary:
	var body_names: Array[String] = []
	for body_value: Variant in tracked_bodies.values():
		if body_value is Node and is_instance_valid(body_value as Node):
			body_names.append(str((body_value as Node).name))
	body_names.sort()
	return {
		"slippery_surface": true,
		"label": surface_label,
		"kind": surface_kind,
		"tracked_bodies": tracked_bodies.size(),
		"body_names": body_names,
		"registrations": registration_count,
		"unregistrations": unregistration_count,
		"rejected_bodies": rejected_body_count,
		"last_body": last_body_name,
		"last_rejected_body": last_rejected_body_name,
		"acceleration_multiplier": acceleration_multiplier,
		"braking_multiplier": braking_multiplier,
		"turn_multiplier": turn_multiplier,
		"reversal_multiplier": reversal_multiplier,
		"rigid_linear_damp": rigid_linear_damp,
		"rigid_angular_damp": rigid_angular_damp,
	}
