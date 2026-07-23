extends Marker3D
class_name TacticalRouteAnchor

@export var route_id: String = "route"
@export var lane_id: String = ""
@export var enabled: bool = true
@export var route_tags: Array[String] = []
@export_range(-20.0, 20.0, 0.1) var route_bias: float = 0.0


func _ready() -> void:
	add_to_group("tactical_route_anchors")
	add_to_group("debuggable")
	if route_id.strip_edges() == "":
		route_id = name


func matches_lane(requested_lane_id: String) -> bool:
	return enabled and (lane_id == "" or requested_lane_id == "" or lane_id == requested_lane_id)


func has_route_tag(tag: String) -> bool:
	return route_tags.has(tag.to_lower().strip_edges())


func get_debug_data() -> Dictionary:
	return {
		"tactical_route_anchor": route_id,
		"lane": lane_id,
		"enabled": enabled,
		"bias": route_bias,
		"position": global_position,
		"tags": route_tags.duplicate(),
	}
