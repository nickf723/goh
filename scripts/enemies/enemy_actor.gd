extends CharacterBody3D
class_name EnemyActor

const AirborneReactionControllerScript = preload("res://scripts/combat/airborne_reaction_controller.gd")
const AirbornePresentationControllerScript = preload("res://scripts/visuals/airborne_presentation_controller.gd")
const EnemyReactionPresentationBridgeScript = preload(
	"res://scripts/visuals/enemy_reaction_presentation_bridge.gd"
)
const CreatureObservationAccess = preload(
	"res://scripts/animals/creature_observation_access.gd"
)

@export_group("Creature Identity")
@export var creature_species_id: String = ""
@export var creature_observation_enabled: bool = true

@export_group("Airborne Presentation")
@export var airborne_presentation_profile: AirbornePresentationProfile

@export_group("Defeat Presentation")
@export_range(0.0, 2.0, 0.05) var defeat_cleanup_delay: float = 0.55

@onready var payload_receiver: Node = get_node_or_null("PayloadReceiver")

var defeat_cleanup_started: bool = false
var airborne_reaction_controller: Node
var airborne_presentation_controller: Node
var reaction_presentation_bridge: Node


func _ready() -> void:
	add_to_group("enemy")
	_register_creature_observation()
	ensure_airborne_reaction_controller()
	ensure_airborne_presentation_controller()
	ensure_reaction_presentation_bridge()


func _register_creature_observation() -> void:
	var normalized_species: String = creature_species_id.strip_edges().to_lower()
	if not creature_observation_enabled or normalized_species == "":
		return
	set_meta("creature_species_id", normalized_species)
	add_to_group("creature_observable")
	CreatureObservationAccess.call_service(
		get_tree(),
		"register_creature",
		[self]
	)


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


func ensure_reaction_presentation_bridge() -> void:
	reaction_presentation_bridge = get_node_or_null("EnemyReactionPresentationBridge")
	if reaction_presentation_bridge != null:
		return
	reaction_presentation_bridge = EnemyReactionPresentationBridgeScript.new()
	reaction_presentation_bridge.name = "EnemyReactionPresentationBridge"
	add_child(reaction_presentation_bridge)


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
	_report_creature_defeat()
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
			"EnemyReactionPresentationBridge",
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


func _report_creature_defeat() -> void:
	if not creature_observation_enabled or not has_meta("creature_species_id"):
		return
	CreatureObservationAccess.call_service(
		get_tree(),
		"report_creature_defeated",
		[self]
	)


func _finish_defeat_cleanup() -> void:
	if is_inside_tree():
		queue_free()
