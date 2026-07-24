extends CanvasLayer
class_name QuickItemBeltUI

@export_range(0.02, 0.5, 0.01) var refresh_interval: float = 0.08

@onready var up_label: Label = get_node_or_null("Panel/Margin/VBox/UpLabel") as Label
@onready var left_label: Label = get_node_or_null("Panel/Margin/VBox/Middle/LeftLabel") as Label
@onready var center_label: Label = get_node_or_null("Panel/Margin/VBox/Middle/CenterLabel") as Label
@onready var right_label: Label = get_node_or_null("Panel/Margin/VBox/Middle/RightLabel") as Label
@onready var down_label: Label = get_node_or_null("Panel/Margin/VBox/DownLabel") as Label
@onready var progress_label: Label = get_node_or_null("Panel/Margin/VBox/ProgressLabel") as Label

var controller: PlayerQuickItemController
var refresh_timer: float = 0.0


func _ready() -> void:
	controller = get_parent().get_node_or_null("PlayerQuickItemController") as PlayerQuickItemController
	refresh_display()


func _process(delta: float) -> void:
	refresh_timer -= delta
	if refresh_timer > 0.0:
		return
	refresh_timer = maxf(refresh_interval, 0.02)
	refresh_display()


func refresh_display() -> void:
	if controller == null or not is_instance_valid(controller):
		visible = false
		return
	visible = true
	set_slot_label(up_label, PlayerQuickItemController.SLOT_UP, "↑")
	set_slot_label(left_label, PlayerQuickItemController.SLOT_LEFT, "←")
	set_slot_label(right_label, PlayerQuickItemController.SLOT_RIGHT, "→")
	set_slot_label(down_label, PlayerQuickItemController.SLOT_DOWN, "↓")

	if center_label != null:
		center_label.text = "USING" if controller.is_using_item() else "ITEMS"
		center_label.modulate = Color(0.42, 0.9, 1.0, 1.0) if controller.is_using_item() else Color(0.72, 0.78, 0.9, 1.0)

	if progress_label != null:
		if controller.is_using_item():
			var duration: float = maxf(controller.use_total_duration, 0.01)
			var progress: float = 1.0 - (controller.use_timer / duration)
			progress_label.text = controller.active_item.short_label + "  " + str(roundi(progress * 100.0)) + "%"
		else:
			progress_label.text = "D-PAD • H USES UP"


func set_slot_label(label: Label, slot_index: int, arrow: String) -> void:
	if label == null:
		return
	var item: QuickItemDefinition = controller.get_slot_item(slot_index)
	if item == null:
		label.text = arrow + "  —"
		label.modulate = Color(0.38, 0.42, 0.52, 1.0)
		return
	label.text = arrow + "  " + item.short_label + " ×" + str(controller.get_slot_charges(slot_index))
	if controller.active_slot == slot_index:
		label.modulate = Color(0.35, 0.92, 1.0, 1.0)
	elif controller.get_slot_charges(slot_index) <= 0:
		label.modulate = Color(0.48, 0.32, 0.35, 1.0)
	else:
		label.modulate = Color(0.9, 0.95, 1.0, 1.0)
