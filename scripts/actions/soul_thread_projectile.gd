extends "res://scripts/actions/generic_projectile_safe.gd"
class_name SoulThreadProjectile

const SoulThreadLinkScene: PackedScene = preload(
	"res://scenes/actions/soul_thread_link.tscn"
)
const SpellPresentation = preload(
	"res://scripts/presentation/spell_presentation_bridge.gd"
)

@export_group("Thread Delivery")
@export_range(8.0, 40.0, 0.5) var projectile_speed: float = 22.0
@export_range(0.5, 5.0, 0.05) var projectile_lifetime: float = 2.8
@export_range(0.5, 30.0, 0.1) var link_duration: float = 8.0

var last_thread_result: String = "none"
var last_target_name: String = "none"


func _ready() -> void:
	speed = projectile_speed
	max_lifetime = projectile_lifetime
	show_miss_feedback = true
	trail_interval = 0.055
	super._ready()


func try_hit(raw_target: Node) -> void:
	var target: Node = find_payload_target(raw_target)
	if target == null or should_ignore_target(target):
		return
	var target_3d: Node3D = _resolve_target_3d(target)
	if target_3d == null:
		return
	var target_id: int = target_3d.get_instance_id()
	if hit_targets.has(target_id):
		return
	hit_targets[target_id] = true
	hit_count += 1
	last_target_name = target_3d.name

	var existing: Node = _find_existing_link(target_3d)
	if existing != null and existing.has_method("refresh_thread"):
		existing.call("refresh_thread", link_duration)
		last_thread_result = "refreshed"
		_present_thread_phase("resolve", target_3d, "thread_refreshed", 0.62)
		queue_free()
		return

	var link: Node = SoulThreadLinkScene.instantiate()
	if link == null:
		last_thread_result = "link_scene_failed"
		queue_free()
		return
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		link.free()
		last_thread_result = "no_scene_root"
		queue_free()
		return
	scene_root.add_child(link)
	if link.has_method("bind_to_actors") and bool(link.call("bind_to_actors", source_actor, target_3d)):
		if link.get("duration_seconds") != null:
			link.set("duration_seconds", link_duration)
		link.call("refresh_thread", link_duration)
		last_thread_result = "linked"
		_present_thread_phase("manifest", target_3d, "thread_bound", 0.92)
	else:
		link.queue_free()
		last_thread_result = "bind_failed"
	queue_free()


func _find_existing_link(target: Node3D) -> Node:
	if get_tree() == null or source_actor == null:
		return null
	for candidate: Node in get_tree().get_nodes_in_group("soul_thread_links"):
		if candidate == null or not is_instance_valid(candidate):
			continue
		if candidate.has_method("matches_link") and bool(candidate.call("matches_link", source_actor, target)):
			return candidate
	return null


func _resolve_target_3d(start_node: Node) -> Node3D:
	var current: Node = start_node
	while current != null:
		if current is Node3D:
			return current as Node3D
		current = current.get_parent()
	return null


func _present_thread_phase(
	phase: String,
	target: Node3D,
	detail: String,
	intensity: float
) -> void:
	SpellPresentation.present(self, phase, {
		"actor": source_actor,
		"target": target,
		"position": target.global_position + Vector3.UP * 0.8,
		"spell_id": "soul_thread",
		"spell_name": "Soul Thread",
		"element": "soul",
		"delivery_type": "projectile_actor_link",
		"targeting_style": "aimed",
		"detail": detail,
		"intensity": intensity,
	})


func get_debug_data() -> Dictionary:
	var data: Dictionary = get_airflow_debug_data()
	data["spell"] = "soul_thread"
	data["persistent_actor_link"] = true
	data["refreshes_existing_link"] = true
	data["direct_damage"] = false
	data["link_duration"] = link_duration
	data["last_result"] = last_thread_result
	data["last_target"] = last_target_name
	return data
