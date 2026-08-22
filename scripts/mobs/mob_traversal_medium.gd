extends Area3D
class_name MobTraversalMedium

const LocomotionCatalog = preload(
	"res://scripts/mobs/mob_locomotion_catalog.gd"
)

@export var locomotion_mode: String = "climber"
@export var medium_tags: Array[String] = ["vertical_surface"]
@export var local_surface_normal: Vector3 = Vector3.FORWARD
@export var adhesion_strength: float = 1.8
@export var route_points: PackedVector3Array = PackedVector3Array()
@export var loop_route: bool = true
@export var waypoint_radius: float = 0.42
@export var habitat_label: String = "Traversal Habitat"

var route_indices: Dictionary = {}
var entry_count: int = 0
var exit_count: int = 0
var guidance_sample_count: int = 0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_to_group("mob_traversal_medium")
	add_to_group("mob_traversal_medium:" + locomotion_mode)


func configure(
	requested_mode: String,
	requested_tags: Array[String],
	requested_surface_normal: Vector3,
	requested_route_points: PackedVector3Array,
	requested_label: String = "Traversal Habitat"
) -> Dictionary:
	locomotion_mode = LocomotionCatalog.normalize_id(requested_mode)
	medium_tags = _normalized_tags(requested_tags)
	local_surface_normal = requested_surface_normal.normalized()
	route_points = requested_route_points
	habitat_label = requested_label
	var definition: MobLocomotionDefinition = LocomotionCatalog.get_definition(
		locomotion_mode
	)
	if definition == null or definition.capability_kind != "mode":
		return {
			"ok": false,
			"error": "unknown traversal mode " + locomotion_mode,
		}
	if medium_tags.is_empty():
		medium_tags = definition.medium_tags.duplicate()
	if not _arrays_intersect(medium_tags, definition.medium_tags):
		return {
			"ok": false,
			"error": "traversal medium does not match " + locomotion_mode,
		}
	if definition.dimension == "surface" and local_surface_normal.is_zero_approx():
		return {
			"ok": false,
			"error": "surface traversal requires a normal",
		}
	return {
		"ok": true,
		"mode": locomotion_mode,
		"medium_tags": medium_tags.duplicate(),
		"route_point_count": route_points.size(),
	}


func get_locomotion_mode() -> String:
	return locomotion_mode


func get_medium_tags() -> Array[String]:
	return medium_tags.duplicate()


func get_locomotion_context(_world_position: Vector3) -> Dictionary:
	var context: Dictionary = {
		"medium_tags": medium_tags.duplicate(),
		"habitat_label": habitat_label,
	}
	var definition: MobLocomotionDefinition = LocomotionCatalog.get_definition(
		locomotion_mode
	)
	if definition != null and definition.dimension == "surface":
		var world_normal: Vector3 = (
			global_transform.basis * local_surface_normal
		).normalized()
		context["surface_normal"] = world_normal
		context["external_velocity"] = (
			-world_normal * maxf(adhesion_strength, 0.0)
		)
	return context


func get_guidance_target(actor: Node3D) -> Dictionary:
	guidance_sample_count += 1
	if actor == null or route_points.is_empty():
		return {
			"found": false,
			"medium": self,
		}
	var actor_id: int = int(actor.get_instance_id())
	var route_index: int = int(route_indices.get(
		actor_id,
		_initial_route_index(actor.global_position)
	))
	var target: Vector3 = get_route_point_world(route_index)
	if (
		actor.global_position.distance_to(target)
		<= maxf(waypoint_radius, 0.05)
	):
		route_index = _advance_route_index(route_index)
		target = get_route_point_world(route_index)
	route_indices[actor_id] = route_index
	return {
		"found": true,
		"medium": self,
		"mode": locomotion_mode,
		"route_index": route_index,
		"target": target,
	}


func get_route_point_world(route_index: int) -> Vector3:
	if route_points.is_empty():
		return global_position
	var safe_index: int = clampi(
		route_index,
		0,
		route_points.size() - 1
	)
	return global_transform * route_points[safe_index]


func get_entry_position() -> Vector3:
	return get_route_point_world(0)


func place_actor(actor: Node3D) -> Dictionary:
	if actor == null:
		return {
			"ok": false,
			"error": "actor is unavailable",
		}
	var controller: Node = actor.get_node_or_null("SwimmingController")
	if (
		controller == null
		or not controller.has_method("enter_traversal_medium")
	):
		return {
			"ok": false,
			"error": "actor has no traversal-aware locomotion executor",
		}
	actor.global_position = get_entry_position()
	if actor is CharacterBody3D:
		(actor as CharacterBody3D).velocity = Vector3.ZERO
	route_indices[int(actor.get_instance_id())] = (
		1 if route_points.size() > 1 else 0
	)
	var result: Variant = controller.call(
		"enter_traversal_medium",
		self
	)
	if result is Dictionary:
		return result as Dictionary
	return {
		"ok": true,
		"mode": locomotion_mode,
	}


func reset_actor_route(actor: Node3D) -> void:
	if actor == null:
		return
	route_indices.erase(int(actor.get_instance_id()))


func get_debug_data() -> Dictionary:
	return {
		"label": habitat_label,
		"mode": locomotion_mode,
		"medium_tags": medium_tags.duplicate(),
		"surface_normal": (
			global_transform.basis * local_surface_normal
		).normalized(),
		"adhesion_strength": adhesion_strength,
		"route_point_count": route_points.size(),
		"tracked_actor_count": route_indices.size(),
		"entries": entry_count,
		"exits": exit_count,
		"guidance_samples": guidance_sample_count,
	}


func _on_body_entered(body: Node3D) -> void:
	var controller: Node = body.get_node_or_null("SwimmingController")
	if (
		controller == null
		or not controller.has_method("enter_traversal_medium")
	):
		return
	entry_count += 1
	controller.call("enter_traversal_medium", self)


func _on_body_exited(body: Node3D) -> void:
	route_indices.erase(int(body.get_instance_id()))
	var controller: Node = body.get_node_or_null("SwimmingController")
	if (
		controller == null
		or not controller.has_method("exit_traversal_medium")
	):
		return
	exit_count += 1
	controller.call("exit_traversal_medium", self)


func _initial_route_index(world_position: Vector3) -> int:
	if route_points.size() <= 1:
		return 0
	var nearest_index: int = 0
	var nearest_distance: float = INF
	for route_index: int in range(route_points.size()):
		var distance: float = world_position.distance_squared_to(
			get_route_point_world(route_index)
		)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = route_index
	return _advance_route_index(nearest_index)


func _advance_route_index(route_index: int) -> int:
	if route_points.size() <= 1:
		return 0
	if loop_route:
		return posmod(route_index + 1, route_points.size())
	return mini(route_index + 1, route_points.size() - 1)


func _arrays_intersect(
	left: Array[String],
	right: Array[String]
) -> bool:
	for value: String in left:
		if right.has(value):
			return true
	return false


func _normalized_tags(value: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for raw: String in value:
		var normalized: String = raw.to_lower().strip_edges()
		if normalized != "" and not result.has(normalized):
			result.append(normalized)
	return result
