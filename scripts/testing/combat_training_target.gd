extends CharacterBody3D
class_name CombatTrainingTarget

const AirborneReactionControllerScript = preload("res://scripts/combat/airborne_reaction_controller.gd")
const AirbornePresentationControllerScript = preload("res://scripts/visuals/airborne_presentation_controller.gd")

@export var target_label: String = "Combat Totem"
@export var gravity: float = 18.0
@export var reset_if_below_y: float = -4.0
@export var airborne_presentation_profile: AirbornePresentationProfile

@onready var hit_receiver: Node = get_node_or_null("HitReceiver")
@onready var status_receiver: Node = get_node_or_null("StatusReceiver")
@onready var force_receiver: Node = get_node_or_null("ForceReceiver")
@onready var name_label: Label3D = get_node_or_null("NameLabel")

var initial_transform: Transform3D
var airborne_reaction_controller: Node
var airborne_presentation_controller: Node


func _ready() -> void:
	initial_transform = global_transform
	add_to_group("enemy")
	add_to_group("combat_arena_resettable")
	add_to_group("airborne_presentation_target")
	add_to_group("debuggable")
	ensure_airborne_controllers()

	if name_label != null:
		name_label.text = target_label

	if hit_receiver != null:
		hit_receiver.set("target_name", target_label)


func ensure_airborne_controllers() -> void:
	airborne_reaction_controller = get_node_or_null("AirborneReactionController")
	if airborne_reaction_controller == null:
		airborne_reaction_controller = AirborneReactionControllerScript.new()
		airborne_reaction_controller.name = "AirborneReactionController"
		add_child(airborne_reaction_controller)

	airborne_presentation_controller = get_node_or_null("AirbornePresentationController")
	if airborne_presentation_controller == null:
		airborne_presentation_controller = AirbornePresentationControllerScript.new()
		airborne_presentation_controller.name = "AirbornePresentationController"
		airborne_presentation_controller.set("profile", airborne_presentation_profile)
		add_child(airborne_presentation_controller)


func _physics_process(delta: float) -> void:
	var external_velocity: Vector3 = Vector3.ZERO

	if force_receiver != null and force_receiver.has_method("consume_external_velocity"):
		external_velocity = force_receiver.call("consume_external_velocity", delta)

	velocity.x = external_velocity.x
	velocity.z = external_velocity.z

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1

	move_and_slide()

	if global_position.y < reset_if_below_y:
		reset_target()


func reset_target() -> void:
	global_transform = initial_transform
	velocity = Vector3.ZERO

	if hit_receiver != null:
		if hit_receiver.has_method("reset_health"):
			hit_receiver.call("reset_health")
		if hit_receiver.has_method("reset_stance"):
			hit_receiver.call("reset_stance")

	clear_statuses()

	if force_receiver != null:
		if force_receiver.has_method("reset_forces"):
			force_receiver.call("reset_forces")
		else:
			force_receiver.set("external_velocity", Vector3.ZERO)
			force_receiver.set("last_force_summary", "none")

	if airborne_reaction_controller != null and airborne_reaction_controller.has_method("reset_reaction"):
		airborne_reaction_controller.call("reset_reaction")
	if airborne_presentation_controller != null and airborne_presentation_controller.has_method("reset_presentation"):
		airborne_presentation_controller.call("reset_presentation")


func clear_statuses() -> void:
	if status_receiver == null:
		return

	if status_receiver.has_method("clear_all_statuses"):
		status_receiver.call("clear_all_statuses")
		return

	var active_statuses: Variant = status_receiver.get("active_statuses")
	if active_statuses is Dictionary:
		var status_dictionary: Dictionary = active_statuses as Dictionary
		for status_name: Variant in status_dictionary.keys():
			if status_receiver.has_method("remove_status"):
				status_receiver.call("remove_status", str(status_name))


func get_debug_data() -> Dictionary:
	return {
		"target": target_label,
		"position": global_position,
		"health": hit_receiver.get("current_health") if hit_receiver != null else -1,
		"stance": hit_receiver.get("current_stance") if hit_receiver != null else -1,
		"air": airborne_reaction_controller.call("get_debug_data") if airborne_reaction_controller != null and airborne_reaction_controller.has_method("get_debug_data") else {},
		"presentation": airborne_presentation_controller.call("get_debug_data") if airborne_presentation_controller != null and airborne_presentation_controller.has_method("get_debug_data") else {},
	}
