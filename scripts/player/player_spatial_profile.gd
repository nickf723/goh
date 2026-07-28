extends Resource
class_name PlayerSpatialProfile

@export var profile_id: String = "grace_default_v1"

@export_group("Physical Envelope")
@export_range(0.1, 2.0, 0.01) var collision_radius: float = 0.46
@export_range(0.3, 4.0, 0.01) var collision_height: float = 1.92
@export_range(0.0, 0.5, 0.01) var safe_destination_margin: float = 0.05

@export_group("Visual Silhouette")
@export_range(0.1, 1.0, 0.01) var robe_top_radius: float = 0.31
@export_range(0.1, 1.0, 0.01) var robe_bottom_radius: float = 0.50
@export_range(0.3, 2.0, 0.01) var robe_height: float = 1.00
@export_range(0.1, 1.0, 0.01) var torso_radius: float = 0.29
@export_range(0.02, 0.3, 0.005) var arm_radius: float = 0.075
@export_range(0.02, 0.3, 0.005) var cuff_radius: float = 0.095
@export_range(0.02, 0.3, 0.005) var hand_radius: float = 0.095
@export_range(0.05, 0.8, 0.01) var sash_radius: float = 0.34
@export_range(0.05, 0.8, 0.01) var boot_width: float = 0.22
@export_range(0.05, 1.0, 0.01) var boot_depth: float = 0.40
@export_range(0.1, 3.0, 0.01) var visual_width: float = 0.94
@export_range(0.5, 4.0, 0.01) var visual_height: float = 1.96

@export_group("Authored Space Clearance")
@export var land_clearance: Vector2 = Vector2(4.0, 3.8)
@export var swim_clearance: Vector2 = Vector2(5.5, 5.0)
@export var camera_clearance: Vector2 = Vector2(6.0, 5.0)

@export_group("Composition Zones")
@export_range(0.5, 5.0, 0.05) var primary_route_radius: float = 1.35
@export_range(0.5, 8.0, 0.05) var camera_route_radius: float = 2.55
@export_range(0.5, 5.0, 0.05) var interaction_radius: float = 1.80
@export_range(0.5, 6.0, 0.05) var landmark_radius: float = 2.40
@export_range(1.0, 12.0, 0.1) var combat_radius: float = 5.50


func get_clearance(traversal: String) -> Vector2:
	match traversal.to_lower().strip_edges():
		"swim", "swimming", "water":
			return swim_clearance
		"camera", "camera_comfort", "camera-comfort":
			return camera_clearance
		_:
			return land_clearance


func get_zone_radius(kind: String) -> float:
	match kind.to_lower().strip_edges():
		"camera", "camera_route":
			return camera_route_radius
		"interaction":
			return interaction_radius
		"landmark":
			return landmark_radius
		"combat":
			return combat_radius
		_:
			return primary_route_radius


func validate_profile() -> Array[String]:
	var errors: Array[String] = []
	if profile_id.strip_edges() == "":
		errors.append("Player spatial profile has no profile_id.")
	if collision_height < collision_radius * 2.0:
		errors.append("Collision height must be at least twice the capsule radius.")
	if robe_bottom_radius < robe_top_radius:
		errors.append("Robe hem must not be narrower than the robe waist in the default silhouette.")
	for row: Dictionary in [
		{"name": "land", "value": land_clearance},
		{"name": "swim", "value": swim_clearance},
		{"name": "camera", "value": camera_clearance},
	]:
		var value: Vector2 = row["value"] as Vector2
		if value.x <= collision_radius * 2.0 or value.y <= collision_height:
			errors.append(str(row["name"]) + " clearance is smaller than Grace's physical envelope.")
	return errors


func get_debug_data() -> Dictionary:
	return {
		"profile_id": profile_id,
		"collision_radius": collision_radius,
		"collision_height": collision_height,
		"visual_width": visual_width,
		"visual_height": visual_height,
		"land_clearance": land_clearance,
		"swim_clearance": swim_clearance,
		"camera_clearance": camera_clearance,
		"primary_route_radius": primary_route_radius,
		"camera_route_radius": camera_route_radius,
		"interaction_radius": interaction_radius,
		"landmark_radius": landmark_radius,
		"combat_radius": combat_radius,
	}
