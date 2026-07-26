extends CharacterBody3D
class_name EnemyActor

const AirborneReactionControllerScript = preload("res://scripts/combat/airborne_reaction_controller.gd")
const AirbornePresentationControllerScript = preload("res://scripts/visuals/airborne_presentation_controller.gd")

@export_group("Airborne Presentation")
@export var airborne_presentation_profile: AirbornePresentationProfile

@export_group("Defeat Presentation")
@export_range(0.0, 2.0, 0.05) var defeat_cleanup_delay: float = 0.55

@onready var payload_receiver: Node = get_node_or_null("PayloadReceiver")

var defeat_cleanup_started: bool = false
var airborne_reaction_controller: Node
var airborne_presentation_controller: Node


func _ready() -> void:
	add_to_group("enemy")
	ensure_airborne_reaction_controller()
	ensure_airborne_presentation_controller()


func ensure_airborne_reaction_controller() -> void:
	airborne_reaction_controller = get_node_or_null("AirborneReactionController")
	if airborne_reaction_controller != null:
		return

	airborne_reaction_controller = AirborneReactionControllerScript.new()
	airborne_reaction_controller.name = "AirborneReactionController"
	add_child(airborne_reaction_controller)


func ensure_airborne_presentation_controller() -> void:
	airborne_presentation_controller = get_node_or_null("AirbornePresentationController")
	if airborne_presentation_controller != null:
		return

	airborne_presentation_controller = AirbornePresentationControllerScript.new()
	airborne_presentation_controller.name = "AirbornePresentationController"
	airborne_presentation_controller.set("profile", airborne_presentation_profile)
	add_child(airborne_presentation_controller)


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	if payload_receiver != null and payload_receiver.has_method("receive_payload"):
		return payload_receiver.receive_payload(payload)

	return {
		"message": payload.source_name + " hits " + name + ", but PayloadReceiver is missing.",
		"objective": ""
	}


func receive_magic_hit(power: int = 1) -> Dictionary:
	var payload: DamagePayload = DamagePayload.new()
	payload.amount = power
	payload.stance_damage = power
	payload.element = "neutral"
	payload.source_name = "Legacy Magic Hit"
	payload.hit_type = "magic"
	payload.tags = ["magic", "legacy"]

	return receive_damage_payload(payload)


func begin_defeat_cleanup() -> void:
	if defeat_cleanup_started:
		return

	defeat_cleanup_started = true
	remove_from_group("enemy")
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0

	var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

	var telegraph: Node = get_node_or_null("EnemyTelegraph")
	if telegraph != null and telegraph.has_method("reset"):
		telegraph.call("reset")

	var visual: Node = get_node_or_null("VisualRoot")
	if visual != null and visual.has_method("start_defeat"):
		visual.call("start_defeat")

	for child: Node in get_children():
		if child == visual:
			continue
		if child.name in [
			"HitReceiver",
			"StatusReceiver",
			"PayloadReceiver",
			"ForceReceiver",
			"AirborneReactionController",
			"AirbornePresentationController",
			"EnemyBrain",
			"EnemyThreatSensor",
			"EnemyActionRunner",
		]:
			child.set_process(false)
			child.set_physics_process(false)

	if defeat_cleanup_delay <= 0.0:
		queue_free()
		return

	var timer: SceneTreeTimer = get_tree().create_timer(defeat_cleanup_delay)
	timer.timeout.connect(Callable(self, "_finish_defeat_cleanup"))


func _finish_defeat_cleanup() -> void:
	if is_inside_tree():
		queue_free()
