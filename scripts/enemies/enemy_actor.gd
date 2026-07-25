extends CharacterBody3D
class_name EnemyActor

@export_group("Defeat Presentation")
@export_range(0.0, 2.0, 0.05) var defeat_cleanup_delay: float = 0.55

@onready var payload_receiver: Node = get_node_or_null("PayloadReceiver")

var defeat_cleanup_started: bool = false


func _ready() -> void:
	add_to_group("enemy")


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
