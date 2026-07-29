extends CanvasLayer
class_name QuickItemBeltUI

@export_range(0.02, 0.5, 0.01) var refresh_interval: float = 0.08

@onready var title_label: Label = get_node_or_null("Panel/Margin/VBox/Title") as Label
@onready var up_label: Label = get_node_or_null("Panel/Margin/VBox/UpLabel") as Label
@onready var left_label: Label = get_node_or_null("Panel/Margin/VBox/Middle/LeftLabel") as Label
@onready var center_label: Label = get_node_or_null("Panel/Margin/VBox/Middle/CenterLabel") as Label
@onready var right_label: Label = get_node_or_null("Panel/Margin/VBox/Middle/RightLabel") as Label
@onready var down_label: Label = get_node_or_null("Panel/Margin/VBox/DownLabel") as Label
@onready var progress_label: Label = get_node_or_null("Panel/Margin/VBox/ProgressLabel") as Label

var controller: PlayerQuickItemController
var router: Node
var refresh_timer: float = 0.0


func _ready() -> void:
	_resolve_bindings()
	refresh_display()


func _process(delta: float) -> void:
	refresh_timer -= delta
	if refresh_timer > 0.0:
		return
	refresh_timer = maxf(refresh_interval, 0.02)
	_resolve_bindings()
	refresh_display()


func _resolve_bindings() -> void:
	var player: Node = get_parent()
	if player == null:
		return
	if controller == null or not is_instance_valid(controller):
		controller = player.get_node_or_null(
			"PlayerQuickItemController"
		) as PlayerQuickItemController
	if router == null or not is_instance_valid(router):
		router = player.get_node_or_null("PlayerControlRouter")


func refresh_display() -> void:
	if controller == null or not is_instance_valid(controller):
		visible = false
		return
	visible = true
	if title_label != null:
		title_label.text = "QUICK ITEM"

	var selected_slot: int = 0
	if router != null and router.has_method("get_selected_quick_item_slot"):
		selected_slot = int(router.call("get_selected_quick_item_slot"))
	set_selected_item_label(selected_slot)

	if left_label != null:
		left_label.visible = false
	if right_label != null:
		right_label.visible = false
	if center_label != null:
		center_label.visible = true
		center_label.custom_minimum_size = Vector2(164.0, 0.0)
		center_label.text = (
			"USING"
			if controller.is_using_item()
			else "UP: TAP CYCLE • HOLD USE"
		)
		center_label.modulate = (
			Color(0.42, 0.9, 1.0, 1.0)
			if controller.is_using_item()
			else Color(0.72, 0.78, 0.9, 1.0)
		)

	if down_label != null:
		down_label.text = "▼  DIVINE SPECIAL"
		down_label.modulate = Color(1.0, 0.52, 0.16, 0.9)

	if progress_label != null:
		if controller.is_using_item():
			var duration: float = maxf(controller.use_total_duration, 0.01)
			var progress: float = 1.0 - (controller.use_timer / duration)
			progress_label.text = (
				controller.active_item.short_label
				+ "  "
				+ str(roundi(progress * 100.0))
				+ "%"
			)
		else:
			progress_label.text = ""
		progress_label.visible = controller.is_using_item()


func set_selected_item_label(slot_index: int) -> void:
	if up_label == null:
		return
	var item: QuickItemDefinition = controller.get_slot_item(slot_index)
	if item == null:
		up_label.text = "▲  NO QUICK ITEM"
		up_label.modulate = Color(0.42, 0.46, 0.56, 1.0)
		return
	up_label.text = (
		"▲  "
		+ item.short_label
		+ " ×"
		+ str(controller.get_slot_charges(slot_index))
	)
	if controller.active_slot == slot_index:
		up_label.modulate = Color(0.35, 0.92, 1.0, 1.0)
	elif controller.get_slot_charges(slot_index) <= 0:
		up_label.modulate = Color(0.48, 0.32, 0.35, 1.0)
	else:
		up_label.modulate = Color(0.9, 0.95, 1.0, 1.0)
