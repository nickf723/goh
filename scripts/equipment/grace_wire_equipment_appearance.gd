extends Node
class_name GraceWireEquipmentAppearance

const OUTFIT_SLOT: String = "outfit"

var visual: GraceWireMotionVisual
var current_outfit_id: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visual = get_parent().get_node_or_null("GraceVisualV1") as GraceWireMotionVisual
	if not GameState.equipment_changed.is_connected(_on_equipment_changed):
		GameState.equipment_changed.connect(_on_equipment_changed)
	apply_outfit(GameState.get_equipped_item(OUTFIT_SLOT))


func _exit_tree() -> void:
	if GameState != null and GameState.equipment_changed.is_connected(_on_equipment_changed):
		GameState.equipment_changed.disconnect(_on_equipment_changed)


func _on_equipment_changed(slot_id: String, item_id: String) -> void:
	if slot_id == OUTFIT_SLOT:
		apply_outfit(item_id)


func apply_outfit(outfit_id: String) -> void:
	current_outfit_id = outfit_id
	if visual != null:
		visual.set_wire_outfit(outfit_id)


func get_debug_data() -> Dictionary:
	return {
		"mode": "wire_palette",
		"outfit_id": current_outfit_id,
		"visual_ready": visual != null,
	}
