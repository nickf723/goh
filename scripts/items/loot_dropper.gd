extends Node
class_name LootDropper

signal loot_spawned(results: Array[Dictionary], pickups: Array[WorldItemPickup])

@export var loot_table: LootTable
@export var pickup_scene: PackedScene = preload("res://scenes/items/world_item_pickup.tscn")
@export var drop_on_health_depleted: bool = true
@export var auto_collect_drops: bool = true
@export_range(0.0, 4.0, 0.05) var scatter_radius: float = 0.85
@export var fixed_seed: int = -1

var has_dropped: bool = false
var last_results: Array[Dictionary] = []
var last_reason: String = "not rolled"


func _ready() -> void:
	add_to_group("loot_dropper")
	add_to_group("debuggable")
	if drop_on_health_depleted:
		call_deferred("bind_hit_receiver")


func bind_hit_receiver() -> void:
	var owner_node: Node = get_parent()
	var receiver: Node = owner_node.get_node_or_null("HitReceiver") if owner_node != null else null
	if receiver == null or not receiver.has_signal("health_depleted"):
		last_reason = "no HitReceiver health_depleted signal"
		return
	var callback: Callable = Callable(self, "_on_health_depleted")
	if not receiver.is_connected("health_depleted", callback):
		receiver.connect("health_depleted", callback)
	last_reason = "armed"


func _on_health_depleted() -> void:
	drop_now()


func drop_now() -> Array[WorldItemPickup]:
	var spawned: Array[WorldItemPickup] = []
	if has_dropped:
		last_reason = "already dropped"
		return spawned
	has_dropped = true

	if loot_table == null or pickup_scene == null:
		last_reason = "missing table or pickup scene"
		return spawned

	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	if fixed_seed >= 0:
		random.seed = fixed_seed
	else:
		random.seed = int(Time.get_ticks_usec()) ^ get_instance_id()

	last_results = loot_table.roll_loot(random)
	var world_parent: Node = get_tree().current_scene
	if world_parent == null:
		world_parent = get_tree().root
	var origin: Vector3 = get_drop_origin()

	for result: Dictionary in last_results:
		var item: QuickItemDefinition = result.get("item_definition") as QuickItemDefinition
		var quantity: int = int(result.get("quantity", 0))
		if item == null or quantity <= 0:
			continue
		var pickup: WorldItemPickup = pickup_scene.instantiate() as WorldItemPickup
		if pickup == null:
			continue
		pickup.item_definition = item
		pickup.quantity = quantity
		pickup.pickup_id = ""
		pickup.prompt_text = "Collect " + item.display_name
		pickup.runtime_drop = true
		pickup.free_after_collect = true
		pickup.attract_to_player = auto_collect_drops
		pickup.auto_collect_when_near = auto_collect_drops
		world_parent.add_child(pickup)
		var angle: float = random.randf_range(0.0, TAU)
		var distance: float = random.randf_range(0.15, maxf(scatter_radius, 0.15))
		pickup.global_position = origin + Vector3(cos(angle) * distance, 0.45, sin(angle) * distance)
		spawned.append(pickup)

	last_reason = "rolled " + str(last_results.size()) + " item stacks"
	loot_spawned.emit(last_results, spawned)
	return spawned


func get_drop_origin() -> Vector3:
	var owner_3d: Node3D = get_parent() as Node3D
	if owner_3d != null:
		return owner_3d.global_position
	return Vector3.ZERO


func reset_dropper() -> void:
	has_dropped = false
	last_results.clear()
	last_reason = "reset"


func get_debug_data() -> Dictionary:
	return {
		"table": loot_table.display_name if loot_table != null else "none",
		"has_dropped": has_dropped,
		"reason": last_reason,
		"results": last_results,
	}
