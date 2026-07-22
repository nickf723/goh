extends Node
class_name DropTableComponent

signal drops_spawned(count: int)

const DEFAULT_PICKUP_SCENE: PackedScene = preload("res://scenes/items/resource_pickup.tscn")

@export var trigger_signal_source_path: NodePath = NodePath("..")
@export var trigger_signal_name: String = "broken"
@export var reset_signal_name: String = "reset_completed"
@export var pickup_scene: PackedScene = DEFAULT_PICKUP_SCENE
@export var drop_entries: Array[PickupDropEntry] = []
@export_range(0, 8, 1) var random_rolls: int = 0
@export var roll_non_guaranteed_independently: bool = true
@export var allow_repeat_random_entries: bool = true

@export_group("Spawn")
@export var spawn_height: float = 0.35
@export var spawn_radius: float = 0.28
@export var horizontal_speed_min: float = 1.4
@export var horizontal_speed_max: float = 2.8
@export var upward_speed_min: float = 3.2
@export var upward_speed_max: float = 4.8

var signal_source: Node = null
var has_dropped: bool = false
var last_spawn_count: int = 0
var total_spawn_count: int = 0


func _ready() -> void:
	resolve_signal_source()
	connect_signals()
	add_to_group("drop_tables")
	add_to_group("debuggable")


func resolve_signal_source() -> void:
	signal_source = get_node_or_null(trigger_signal_source_path)


func connect_signals() -> void:
	if signal_source == null:
		push_warning(name + " could not find drop signal source at " + str(trigger_signal_source_path))
		return

	var drop_callback: Callable = Callable(self, "drop_all")
	if signal_source.has_signal(trigger_signal_name):
		if not signal_source.is_connected(trigger_signal_name, drop_callback):
			signal_source.connect(trigger_signal_name, drop_callback)
	else:
		push_warning(name + " could not find trigger signal " + trigger_signal_name)

	var reset_callback: Callable = Callable(self, "reset_drop_table")
	if signal_source.has_signal(reset_signal_name):
		if not signal_source.is_connected(reset_signal_name, reset_callback):
			signal_source.connect(reset_signal_name, reset_callback)


func drop_all() -> void:
	if has_dropped or pickup_scene == null:
		return

	has_dropped = true
	last_spawn_count = 0

	for entry: PickupDropEntry in drop_entries:
		if entry == null or not entry.guaranteed:
			continue
		spawn_entry(entry, entry.roll_count())

	if roll_non_guaranteed_independently:
		for entry: PickupDropEntry in drop_entries:
			if entry == null or entry.guaranteed:
				continue
			spawn_entry(entry, entry.roll_count())

	roll_weighted_entries()
	total_spawn_count += last_spawn_count
	drops_spawned.emit(last_spawn_count)


func roll_weighted_entries() -> void:
	if random_rolls <= 0:
		return

	var candidates: Array[PickupDropEntry] = []
	for entry: PickupDropEntry in drop_entries:
		if entry != null and not entry.guaranteed and entry.random_weight > 0.0:
			candidates.append(entry)

	for _roll_index: int in range(random_rolls):
		if candidates.is_empty():
			return

		var chosen: PickupDropEntry = choose_weighted_entry(candidates)
		if chosen == null:
			return

		spawn_entry(chosen, chosen.roll_count())
		if not allow_repeat_random_entries:
			candidates.erase(chosen)


func choose_weighted_entry(candidates: Array[PickupDropEntry]) -> PickupDropEntry:
	var total_weight: float = 0.0
	for entry: PickupDropEntry in candidates:
		total_weight += max(entry.random_weight, 0.0)

	if total_weight <= 0.0:
		return null

	var cursor: float = randf() * total_weight
	for entry: PickupDropEntry in candidates:
		cursor -= max(entry.random_weight, 0.0)
		if cursor <= 0.0:
			return entry

	return candidates.back()


func spawn_entry(entry: PickupDropEntry, count: int) -> void:
	if entry == null or entry.pickup_definition == null or count <= 0:
		return

	for _index: int in range(count):
		spawn_pickup(entry.pickup_definition, last_spawn_count)
		last_spawn_count += 1


func spawn_pickup(definition: PickupDefinition, spawn_index: int) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return

	var pickup: ResourcePickup = pickup_scene.instantiate() as ResourcePickup
	if pickup == null:
		push_warning(name + " pickup_scene did not instantiate ResourcePickup")
		return

	scene_root.add_child(pickup)
	var source_position: Vector3 = get_source_position()
	var angle: float = randf_range(0.0, TAU) + float(spawn_index) * 1.37
	var radial: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
	var horizontal_speed: float = randf_range(horizontal_speed_min, horizontal_speed_max)
	var upward_speed: float = randf_range(upward_speed_min, upward_speed_max)
	var velocity: Vector3 = radial * horizontal_speed + Vector3.UP * upward_speed
	pickup.configure(
		definition,
		source_position + Vector3.UP * spawn_height + radial * spawn_radius,
		velocity
	)


func get_source_position() -> Vector3:
	if signal_source is Node3D:
		return (signal_source as Node3D).global_position

	var parent_3d: Node3D = get_parent() as Node3D
	if parent_3d != null:
		return parent_3d.global_position

	return Vector3.ZERO


func reset_drop_table() -> void:
	has_dropped = false
	last_spawn_count = 0


func get_debug_data() -> Dictionary:
	return {
		"drop_table": true,
		"has_dropped": has_dropped,
		"entries": drop_entries.size(),
		"last_spawn_count": last_spawn_count,
		"total_spawn_count": total_spawn_count,
		"trigger_signal": trigger_signal_name,
	}
