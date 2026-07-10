extends Area3D

@export var speed: float = 12.0
@export var lifetime: float = 2.0
@export var hit_power: int = 1
@export var damage_payload: DamagePayload
@export var payload: DamagePayload

var runtime_payload: DamagePayload
var direction: Vector3 = Vector3.FORWARD
var age: float = 0.0

var hit_flash_scene: PackedScene = preload("res://scenes/effects/hit_flash.tscn")

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

	age += delta
	if age >= lifetime:
		queue_free()

func launch(new_direction: Vector3) -> void:
	direction = new_direction.normalized()

func _on_area_entered(area: Area3D) -> void:
	if area.has_method("receive_magic_hit"):
		var result: Dictionary = send_hit_to_target(area)
		show_hit_result(result)
		spawn_hit_flash(global_position)
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("receive_magic_hit"):
		var result: Dictionary = send_hit_to_target(body)
		show_hit_result(result)
		spawn_hit_flash(global_position)
		queue_free()

func show_hit_result(result: Dictionary) -> void:
	
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui == null:
		return

	if result.has("message"):
		ui.show_message(result["message"])

	if result.has("objective") and result["objective"] != "":
		ui.set_objective(result["objective"])	

func spawn_hit_flash(hit_position: Vector3) -> void:
	var flash: Node3D = hit_flash_scene.instantiate()
	get_tree().current_scene.add_child(flash)
	flash.global_position = hit_position

func send_hit_to_target(target: Node) -> Dictionary:
	var payload: DamagePayload = get_payload()

	var payload_receiver: Node = target.get_node_or_null("PayloadReceiver")

	if payload_receiver != null and payload_receiver.has_method("receive_payload"):
		return payload_receiver.receive_payload(payload)

	if target.has_method("receive_damage_payload"):
		return target.receive_damage_payload(payload)

	var hit_receiver: Node = target.get_node_or_null("HitReceiver")

	if hit_receiver != null and hit_receiver.has_method("receive_payload"):
		return hit_receiver.receive_payload(payload)

	if target.has_method("receive_magic_hit"):
		return target.receive_magic_hit(hit_power)

	return {
		"message": payload.source_name + " hits " + target.name + ", but nothing happens.",
		"objective": ""
	}

	if target.has_method("receive_damage_payload"):
		return target.receive_damage_payload(payload)


	if hit_receiver != null and hit_receiver.has_method("receive_payload"):
		return hit_receiver.receive_payload(payload)

	if target.has_method("receive_magic_hit"):
		return target.receive_magic_hit(hit_power)

	return {
		"message": payload.source_name + " hits " + target.name + ", but nothing happens.",
		"objective": ""
	}

func set_payload(new_payload: DamagePayload) -> void:
	runtime_payload = new_payload

func get_payload() -> DamagePayload:
	if runtime_payload != null:
		return runtime_payload

	if payload != null:
		return payload

	var fallback_payload: DamagePayload = DamagePayload.new()
	fallback_payload.amount = hit_power
	fallback_payload.stance_damage = hit_power
	fallback_payload.element = "neutral"
	fallback_payload.source_name = "Unnamed Projectile"
	fallback_payload.hit_type = "projectile"
	fallback_payload.tags = ["magic", "projectile"]

	return fallback_payload
	if runtime_payload != null:
		return runtime_payload

	if payload != null:
		return payload

	fallback_payload.amount = hit_power
	fallback_payload.stance_damage = hit_power
	fallback_payload.element = "neutral"
	fallback_payload.source_name = "Unnamed Projectile"
	fallback_payload.hit_type = "projectile"
	fallback_payload.tags = ["magic", "projectile"]

	return fallback_payload
