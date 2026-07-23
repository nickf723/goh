extends Node3D
class_name StructuralAssembly3D

signal structure_recomputed(supported_members: int, released_members: int)
signal connection_failed(connection_id: String, reason: String, peak_stress_n: float)

@export var auto_process_loads: bool = true
@export_range(0.01, 0.5, 0.01) var load_refresh_interval: float = 0.05
@export var release_impulse: Vector3 = Vector3(0.0, -0.08, 0.0)

var members: Array[StructuralMember3D] = []
var connections: Array[StructuralConnection3D] = []
var load_timer: float = 0.0
var recompute_requested: bool = true


func _ready() -> void:
	add_to_group("structural_assemblies")
	add_to_group("debuggable")
	add_to_group("lab_resettable")
	call_deferred("rebuild_structure")


func _physics_process(delta: float) -> void:
	if recompute_requested:
		recompute_support_graph()
	if not auto_process_loads:
		return
	load_timer -= delta
	if load_timer <= 0.0:
		load_timer = maxf(load_refresh_interval, 0.01)
		step_structural_loads(load_refresh_interval)


func rebuild_structure() -> void:
	members.clear()
	connections.clear()
	for node: Node in find_children("*", "StructuralMember3D", true, false):
		register_member(node as StructuralMember3D)
	for node: Node in find_children("*", "StructuralConnection3D", true, false):
		register_connection(node as StructuralConnection3D)
	recompute_support_graph()


func register_member(member: StructuralMember3D) -> void:
	if member == null or members.has(member):
		return
	members.append(member)


func register_connection(connection: StructuralConnection3D) -> void:
	if connection == null or connections.has(connection):
		return
	connections.append(connection)
	connection.resolve_endpoints()
	if not connection.connection_failed.is_connected(_on_connection_failed):
		connection.connection_failed.connect(_on_connection_failed)
	if not connection.connection_reset.is_connected(_on_connection_reset):
		connection.connection_reset.connect(_on_connection_reset)


func recompute_support_graph() -> void:
	recompute_requested = false
	var reachable: Dictionary = {}
	var frontier: Array[StructuralMember3D] = []
	for connection: StructuralConnection3D in connections:
		if connection == null or connection.broken or not connection.has_world_anchor():
			continue
		for candidate: StructuralMember3D in [connection.member_a, connection.member_b]:
			if candidate == null or reachable.has(candidate):
				continue
			reachable[candidate] = true
			frontier.append(candidate)

	while not frontier.is_empty():
		var current: StructuralMember3D = frontier.pop_front()
		for connection: StructuralConnection3D in connections:
			if connection == null or connection.broken or not connection.contains_member(current):
				continue
			var other: StructuralMember3D = connection.get_other_member(current)
			if other == null or reachable.has(other):
				continue
			reachable[other] = true
			frontier.append(other)

	var supported_count: int = 0
	for member: StructuralMember3D in members:
		if member == null:
			continue
		var should_support: bool = reachable.has(member)
		member.set_supported(should_support, release_impulse if not should_support else Vector3.ZERO)
		if should_support:
			supported_count += 1
	structure_recomputed.emit(supported_count, members.size() - supported_count)


func step_structural_loads(_delta: float) -> void:
	if recompute_requested:
		recompute_support_graph()
	var connection_loads: Dictionary = {}
	for connection: StructuralConnection3D in connections:
		if connection != null and not connection.broken:
			connection_loads[connection] = 0.0

	for member: StructuralMember3D in members:
		if member == null or not member.supported:
			continue
		var active_connections: Array[StructuralConnection3D] = []
		for connection: StructuralConnection3D in connections:
			if (
				connection != null
				and not connection.broken
				and connection.contains_member(member)
			):
				active_connections.append(connection)
		if active_connections.is_empty():
			continue
		var shared_load_n: float = member.get_load_n() / float(active_connections.size())
		for connection: StructuralConnection3D in active_connections:
			connection_loads[connection] = (
				float(connection_loads.get(connection, 0.0))
				+ shared_load_n
			)

	for connection: StructuralConnection3D in connections:
		if connection == null or connection.broken:
			continue
		connection.set_sustained_load(float(connection_loads.get(connection, 0.0)))


func reset_structure() -> void:
	for member: StructuralMember3D in members:
		if member != null:
			member.reset_member()
	for connection: StructuralConnection3D in connections:
		if connection != null:
			connection.reset_connection()
	recompute_requested = true
	recompute_support_graph()


func reset_target() -> void:
	reset_structure()


func _on_connection_failed(
	connection: StructuralConnection3D,
	reason: String,
	peak_stress_n: float
) -> void:
	recompute_requested = true
	connection_failed.emit(connection.connection_id, reason, peak_stress_n)


func _on_connection_reset(_connection: StructuralConnection3D) -> void:
	recompute_requested = true


func get_intact_connection_count() -> int:
	var count: int = 0
	for connection: StructuralConnection3D in connections:
		if connection != null and not connection.broken:
			count += 1
	return count


func get_supported_member_count() -> int:
	var count: int = 0
	for member: StructuralMember3D in members:
		if member != null and member.supported:
			count += 1
	return count


func get_debug_data() -> Dictionary:
	return {
		"structural_assembly": name,
		"members": members.size(),
		"supported": get_supported_member_count(),
		"connections": connections.size(),
		"intact_connections": get_intact_connection_count(),
	}
