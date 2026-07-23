extends Node3D
class_name MetalTetherAnchor3D

signal anchor_broken(anchor: MetalTetherAnchor3D, peak_tension: float)
signal anchor_reset(anchor: MetalTetherAnchor3D)

@export var anchor_id: String = "metal_anchor"
@export var display_name: String = "Metal Anchor"
@export var accepts_tether: bool = true
@export var breakable: bool = false
@export_range(50.0, 20000.0, 10.0) var break_strength: float = 6000.0
@export_range(0.0, 20000.0, 10.0) var maximum_transferred_force: float = 4800.0

var broken: bool = false
var current_tension: float = 0.0
var peak_tension: float = 0.0
var tether_count: int = 0


func _ready() -> void:
	add_to_group("metal_tether_anchors")
	add_to_group("debuggable")
	if anchor_id.strip_edges() == "":
		anchor_id = name
	_update_visual()


func can_accept_tether(_source: Node3D = null) -> bool:
	return accepts_tether and not broken


func get_tether_anchor_position() -> Vector3:
	return global_position


func get_tether_anchor_body() -> Node3D:
	var parent: Node = get_parent()
	if parent is Node3D:
		return parent as Node3D
	return self


func notify_tether_attached(_source: Node3D = null) -> void:
	tether_count += 1


func notify_tether_released(_source: Node3D = null) -> void:
	tether_count = maxi(tether_count - 1, 0)
	if tether_count <= 0:
		current_tension = 0.0


func receive_tether_tension(tension: float, source_position: Vector3) -> bool:
	if broken or not accepts_tether:
		return false

	current_tension = maxf(tension, 0.0)
	peak_tension = maxf(peak_tension, current_tension)
	_transfer_force_to_body(source_position)

	if breakable and current_tension > break_strength:
		break_anchor()
		return false
	return true


func break_anchor() -> void:
	if broken:
		return
	broken = true
	accepts_tether = false
	current_tension = 0.0
	_update_visual()
	anchor_broken.emit(self, peak_tension)


func reset_anchor() -> void:
	broken = false
	accepts_tether = true
	current_tension = 0.0
	peak_tension = 0.0
	tether_count = 0
	_update_visual()
	anchor_reset.emit(self)


func _transfer_force_to_body(source_position: Vector3) -> void:
	var body: Node3D = get_tether_anchor_body()
	if not body is RigidBody3D:
		return
	var direction: Vector3 = source_position - global_position
	if direction.length_squared() <= 0.0001:
		return
	(body as RigidBody3D).apply_central_force(
		direction.normalized() * minf(current_tension, maximum_transferred_force)
	)


func _update_visual() -> void:
	scale = Vector3.ONE * (0.58 if broken else 1.0)
	rotation.z = deg_to_rad(28.0) if broken else 0.0
	for child: Node in get_children():
		if child is GeometryInstance3D:
			(child as GeometryInstance3D).transparency = 0.62 if broken else 0.0


func get_debug_data() -> Dictionary:
	return {
		"metal_tether_anchor": anchor_id,
		"display_name": display_name,
		"available": can_accept_tether(),
		"breakable": breakable,
		"break_strength": break_strength,
		"tension": current_tension,
		"peak_tension": peak_tension,
		"broken": broken,
		"body": get_tether_anchor_body().name,
	}
