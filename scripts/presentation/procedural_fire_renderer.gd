extends Node3D
class_name ProceduralFireRenderer

const FireEventScript = preload("res://scripts/presentation/fire_vfx_event.gd")
const FireProfileScript = preload("res://scripts/presentation/fire_presentation_profile.gd")
const FireVisualScript = preload("res://scripts/presentation/procedural_fire_visual.gd")

var active_visuals: Array[Node3D] = []
var rendered_count: int = 0
var rejected_count: int = 0
var kind_counts: Dictionary = {}
var last_event: Dictionary = {}


func _ready() -> void:
	add_to_group("debuggable")
	add_to_group("lab_resettable")
	add_to_group("vfx_gallery_clearable")


func render_event(event: RefCounted, profile: Resource = null) -> Node3D:
	prune_visuals()
	if event == null or not event.has_method("is_finite_event") or not bool(event.is_finite_event()):
		rejected_count += 1
		return null
	var working: RefCounted = event.duplicate_event()
	working.sanitize()
	var resolved_profile: Resource = profile.duplicate_profile() if profile != null and profile.has_method("duplicate_profile") else FireProfileScript.new()
	var visual := FireVisualScript.new() as Node3D
	visual.name = "ProceduralFire_" + str(working.kind)
	add_child(visual)
	visual.global_position = working.world_position
	visual.configure(working, resolved_profile)
	visual.expired.connect(_on_visual_expired)
	active_visuals.append(visual)
	rendered_count += 1
	kind_counts[working.kind] = int(kind_counts.get(working.kind, 0)) + 1
	last_event = working.get_debug_data()
	return visual


func render_kind(
	kind: String,
	world_position: Vector3,
	intensity: float,
	radius: float,
	profile_kind: String = "",
	source_id: String = "fire_renderer"
) -> Node3D:
	var event: RefCounted = FireEventScript.make(kind, world_position, intensity, radius, source_id, ["procedural", "fire"])
	var profile: Resource = FireProfileScript.new()
	if profile_kind != "":
		profile.apply_kind(profile_kind)
	return render_event(event, profile)


func _on_visual_expired(visual: Node3D) -> void:
	active_visuals.erase(visual)


func prune_visuals() -> void:
	var retained: Array[Node3D] = []
	for visual: Node3D in active_visuals:
		if visual != null and is_instance_valid(visual) and not visual.is_queued_for_deletion():
			retained.append(visual)
	active_visuals = retained


func reset_target() -> void:
	for visual: Node3D in active_visuals:
		if visual != null and is_instance_valid(visual):
			visual.queue_free()
	active_visuals.clear()
	rendered_count = 0
	rejected_count = 0
	kind_counts.clear()
	last_event.clear()


func get_debug_data() -> Dictionary:
	prune_visuals()
	return {
		"procedural_fire_renderer": true,
		"active_visuals": active_visuals.size(),
		"rendered": rendered_count,
		"rejected": rejected_count,
		"kinds": kind_counts.duplicate(),
		"last_event": last_event.duplicate(true),
	}
