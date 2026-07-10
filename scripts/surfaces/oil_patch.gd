extends Area3D

@export var oily_duration: float = 8.0
@export var oily_strength: float = 1.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _on_body_entered(body: Node3D) -> void:
	apply_oil_to_target(body)

func _on_area_entered(area: Area3D) -> void:
	var parent: Node = area.get_parent()

	if parent != null:
		apply_oil_to_target(parent)

func apply_oil_to_target(target: Node) -> void:
	var status_receiver: Node = target.get_node_or_null("StatusReceiver")

	if status_receiver != null and status_receiver.has_method("apply_status"):
		status_receiver.apply_status("oily", oily_duration, oily_strength, "oil_patch")
		show_message(target.name + " is coated in oil.")
		return

	var tag_component: Node = target.get_node_or_null("TagComponent")

	if tag_component != null and tag_component.has_method("add_tag"):
		tag_component.add_tag("oily")
		show_message(target.name + " gains oily tag.")

func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)
