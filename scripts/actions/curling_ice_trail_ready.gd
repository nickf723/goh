extends "res://scripts/actions/curling_ice_trail.gd"
class_name CurlingIceTrailReady

# Physical support remains thin, while the interaction volumes rise above each
# strip so characters and movable objects reliably inherit slippery and
# frozen-water behavior while resting on the ice.

@export_range(0.2, 2.0, 0.05) var interaction_height: float = 0.85
@export_range(0.0, 0.3, 0.01) var interaction_surface_overlap: float = 0.08


func _add_collision_segment(
	parent: CollisionObject3D,
	world_position: Vector3,
	world_basis: Basis,
	segment_length: float
) -> void:
	if parent == null:
		return
	var shape_height: float = trail_thickness
	var collision_position: Vector3 = world_position
	if parent == slippery_area or parent == frozen_bridge_area:
		shape_height = maxf(interaction_height, trail_thickness)
		var surface_normal: Vector3 = world_basis.y.normalized()
		collision_position += surface_normal * (
			(shape_height - trail_thickness) * 0.5
			- maxf(interaction_surface_overlap, 0.0)
		)

	var collision := CollisionShape3D.new()
	collision.name = "IceSegmentCollision" + str(segment_positions.size())
	var shape := BoxShape3D.new()
	shape.size = Vector3(
		trail_width,
		shape_height,
		maxf(segment_length, 0.08)
	)
	collision.shape = shape
	parent.add_child(collision)
	collision.global_transform = Transform3D(
		world_basis,
		collision_position
	)


func _update_visual_segment(
	segment_index: int,
	world_position: Vector3,
	world_basis: Basis,
	segment_length: float
) -> void:
	super._update_visual_segment(
		segment_index,
		world_position,
		world_basis,
		segment_length
	)
	if (
		trail_multimesh == null
		or segment_index < 0
		or segment_index >= trail_multimesh.instance_count
		or segment_index >= segment_kinds.size()
	):
		return
	var is_water: bool = segment_kinds[segment_index] == "water"
	trail_multimesh.set_instance_color(
		segment_index,
		Color(
			0.8 if is_water else 0.66,
			0.98 if is_water else 0.91,
			1.0,
			0.86 if is_water else 0.78
		)
	)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["interaction_height"] = interaction_height
	data["interaction_surface_overlap"] = interaction_surface_overlap
	data["raised_interaction_volumes"] = true
	data["water_segment_tint"] = true
	return data
