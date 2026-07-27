extends Area3D
class_name StoryInteractable

signal activated(interactable: StoryInteractable)

@export var prompt_text: String = "Interact"
@export var active: bool = true
@export var one_shot: bool = false
@export var required_flag: String = ""
@export var blocked_flag: String = ""

var used: bool = false


func _ready() -> void:
	add_to_group("interactable_target")
	add_to_group("story_interactable")
	ensure_collision()
	refresh_state()


func interact() -> Dictionary:
	if not can_activate():
		return {"message": "Nothing responds yet.", "objective": ""}
	used = true
	activated.emit(self)
	if one_shot:
		active = false
		refresh_state()
	return {}


func can_activate() -> bool:
	if not active or (used and one_shot):
		return false
	if required_flag != "" and not GameState.get_flag(required_flag):
		return false
	if blocked_flag != "" and GameState.get_flag(blocked_flag):
		return false
	return true


func set_active(value: bool) -> void:
	active = value
	refresh_state()


func refresh_state() -> void:
	monitoring = can_activate()
	monitorable = can_activate()
	visible = active


func ensure_collision() -> void:
	if get_node_or_null("CollisionShape3D") != null:
		return
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.25
	collision.shape = shape
	collision.position.y = 0.7
	add_child(collision)
