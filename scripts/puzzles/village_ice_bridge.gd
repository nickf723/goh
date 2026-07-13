extends StaticBody3D
class_name VillageIceBridge

@export var bridge_id: String = "village_ice_bridge"
@export var completion_flag: String = ""
@export var objective_after: String = "Cross the frozen ravine."
@export var freeze_message: String = "The soaked crossing crystallizes into a stable ice path."
@export var target_collision_path: NodePath = NodePath("TargetCollision")
@export var bridge_collision_path: NodePath = NodePath("BridgeCollision")
@export var water_visual_path: NodePath = NodePath("WaterVisual")
@export var ice_visual_path: NodePath = NodePath("IceVisual")
@export var status_receiver_path: NodePath = NodePath("StatusReceiver")

var is_frozen_bridge: bool = false

@onready var target_collision: CollisionShape3D = get_node_or_null(target_collision_path) as CollisionShape3D
@onready var bridge_collision: CollisionShape3D = get_node_or_null(bridge_collision_path) as CollisionShape3D
@onready var water_visual: MeshInstance3D = get_node_or_null(water_visual_path) as MeshInstance3D
@onready var ice_visual: MeshInstance3D = get_node_or_null(ice_visual_path) as MeshInstance3D
@onready var status_receiver: Node = get_node_or_null(status_receiver_path)


func _ready() -> void:
	add_to_group("village_ice_bridge")
	add_to_group("debuggable")

	if completion_flag != "" and GameState.get_flag(completion_flag):
		freeze_bridge(false)
	else:
		set_bridge_state(false)


func _process(_delta: float) -> void:
	if is_frozen_bridge or status_receiver == null:
		return

	if status_receiver.has_method("has_status") and bool(status_receiver.call("has_status", "frozen")):
		freeze_bridge(true)


func freeze_bridge(announce: bool = true) -> void:
	if is_frozen_bridge:
		return

	is_frozen_bridge = true
	set_bridge_state(true)

	if completion_flag != "":
		GameState.set_flag(completion_flag, true)

	if objective_after != "":
		GameState.set_objective(objective_after)

	if announce:
		show_message(freeze_message)


func set_bridge_state(frozen: bool) -> void:
	if bridge_collision != null:
		bridge_collision.set_deferred("disabled", not frozen)

	if ice_visual != null:
		ice_visual.visible = frozen

	if water_visual != null:
		water_visual.visible = not frozen

	if target_collision != null:
		target_collision.set_deferred("disabled", false)


func reset_bridge() -> void:
	is_frozen_bridge = false
	set_bridge_state(false)
	if status_receiver != null and status_receiver.has_method("clear_all_statuses"):
		status_receiver.call("clear_all_statuses")
	if completion_flag != "":
		GameState.set_flag(completion_flag, false)


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	return {
		"bridge": bridge_id,
		"frozen": is_frozen_bridge,
		"statuses": status_receiver.get("active_statuses") if status_receiver != null else {},
	}
