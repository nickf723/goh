extends Node3D

const TARGET_LAYER: int = 1

@export var radius: float = 2.75
@export var lifetime: float = 8.0
@export var arming_delay: float = 0.25
@export var trigger_pulse_lifetime: float = 0.55
@export var visual_height_scale: float = 0.025
@export var show_debug_prints: bool = true
@export var payload: DamagePayload

var runtime_payload: DamagePayload
var source_actor: Node3D
var lifetime_timer: float = 0.0
var arming_timer: float = 0.0
var has_triggered: bool = false

@onready var trigger_area: Area3D = get_node_or_null("TriggerArea")
@onready var trap_visual: MeshInstance3D = get_node_or_null("TrapVisual")
@onready var collision_shape: CollisionShape3D = get_node_or_null("TriggerArea/CollisionShape3D")


func _ready() -> void:
	add_to_group("debuggable")
	add_to_group("hazard_reactive")
	lifetime_timer = lifetime
	arming_timer = arming_delay
	configure_area()
	configure_visual()

	if show_debug_prints:
		print("Dream Trap waits at ", global_position)


func set_payload(new_payload: Resource) -> void:
	if new_payload is DamagePayload:
		runtime_payload = new_payload as DamagePayload


func set_source_actor(new_source_actor: Node) -> void:
	if new_source_actor is Node3D:
		source_actor = new_source_actor as Node3D


func _process(delta: float) -> void:
	lifetime_timer -= delta
	arming_timer -= delta
	update_visual_pulse()

	if lifetime_timer <= 0.0:
		queue_free()
		return

	if has_triggered:
		return

	if arming_timer > 0.0:
		return

	check_for_trigger()


func configure_area() -> void:
	if trigger_area == null:
		trigger_area = Area3D.new()
		trigger_area.name = "TriggerArea"
		add_child(trigger_area)

	trigger_area.monitoring = true
	trigger_area.monitorable = false
	trigger_area.collision_layer = 0
	trigger_area.collision_mask = TARGET_LAYER

	if collision_shape == null:
		collision_shape = trigger_area.get_node_or_null("CollisionShape3D") as CollisionShape3D

	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		trigger_area.add_child(collision_shape)

	var sphere_shape: SphereShape3D = collision_shape.shape as SphereShape3D
	if sphere_shape == null:
		sphere_shape = SphereShape3D.new()
		collision_shape.shape = sphere_shape

	sphere_shape.radius = radius


func configure_visual() -> void:
	if trap_visual == null:
		return

	trap_visual.scale = Vector3(radius, max(radius * visual_height_scale, 0.035), radius)


func update_visual_pulse() -> void:
	if trap_visual == null:
		return

	var age: float = lifetime - lifetime_timer
	var pulse_speed: float = 3.6
	var pulse_size: float = 0.035
	var height_scale: float = visual_height_scale

	if arming_timer > 0.0:
		pulse_speed = 8.0
		pulse_size = 0.025

	if has_triggered:
		pulse_speed = 12.0
		pulse_size = 0.18
		height_scale = visual_height_scale * 2.5

	var pulse: float = 1.0 + sin(age * pulse_speed) * pulse_size
	trap_visual.scale = Vector3(radius * pulse, max(radius * height_scale, 0.035), radius * pulse)


func check_for_trigger() -> void:
	if trigger_area == null:
		return

	var targets: Array[Node] = []

	for body: Node in trigger_area.get_overlapping_bodies():
		var body_target: Node = find_status_target(body)
		if body_target != null and not targets.has(body_target):
			targets.append(body_target)

	for area: Area3D in trigger_area.get_overlapping_areas():
		var area_target: Node = find_status_target(area)
		if area_target != null and not targets.has(area_target):
			targets.append(area_target)

	if targets.is_empty():
		return

	trigger_trap(targets[0])


func trigger_trap(target: Node) -> void:
	if has_triggered:
		return

	has_triggered = true
	apply_trap_to_target(target)
	show_trigger_feedback(target)
	show_result({"message": "Dream Trap springs."})

	if show_debug_prints:
		print("Dream Trap triggered by ", target.name)

	var cleanup_tween: Tween = create_tween()
	cleanup_tween.tween_interval(trigger_pulse_lifetime)
	cleanup_tween.tween_callback(queue_free)


func apply_trap_to_target(target: Node) -> void:
	var status_receiver: Node = get_component(target, "StatusReceiver")
	if status_receiver == null:
		return

	var dream_payload: DamagePayload = get_payload()
	var status_name: String = dream_payload.status_effect
	var status_duration: float = dream_payload.status_duration
	var status_strength: float = dream_payload.status_strength

	if status_name == "":
		status_name = "staggered"
	if status_duration <= 0.0:
		status_duration = 1.2
	if status_strength <= 0.0:
		status_strength = 1.0

	if status_receiver.has_method("apply_status"):
		status_receiver.apply_status(status_name, status_duration, status_strength, dream_payload.source_name)
	elif status_receiver.has_method("sustain_status"):
		status_receiver.sustain_status(status_name, status_duration, status_strength, dream_payload.source_name)


func show_trigger_feedback(target: Node) -> void:
	if not target is Node3D:
		return

	var target_3d: Node3D = target as Node3D
	var burst: Node3D = Node3D.new()
	burst.name = "DreamTrapBurst"
	burst.global_position = target_3d.global_position + Vector3.UP * 1.1
	get_tree().current_scene.add_child(burst)

	var bubble: MeshInstance3D = MeshInstance3D.new()
	bubble.name = "DreamBubble"
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 1.1
	bubble.mesh = sphere
	bubble.material_override = make_dream_material(0.52)
	burst.add_child(bubble)

	var tween: Tween = burst.create_tween()
	bubble.scale = Vector3.ONE * 0.15
	tween.tween_property(bubble, "scale", Vector3.ONE * 1.4, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(bubble, "scale", Vector3.ONE * 0.2, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(burst.queue_free)


func make_dream_material(alpha: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.62, 0.24, 0.95, alpha)
	material.emission_enabled = true
	material.emission = Color(0.66, 0.22, 1.0, 1.0)
	material.emission_energy_multiplier = 0.8
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func get_payload() -> DamagePayload:
	if runtime_payload != null:
		return runtime_payload

	if payload != null:
		return payload

	var fallback_payload: DamagePayload = DamagePayload.new()
	fallback_payload.amount = 0
	fallback_payload.stance_damage = 0
	fallback_payload.element = "dreams"
	fallback_payload.source_name = "Dream Trap"
	fallback_payload.hit_type = "trap"
	fallback_payload.status_effect = "staggered"
	fallback_payload.status_duration = 1.2
	fallback_payload.status_strength = 1.0
	fallback_payload.tags = ["dreams", "illusion", "trap", "field", "ground_targeted", "control"]
	return fallback_payload


func get_hazard_tags() -> Array[String]:
	return ["dreams", "illusion", "trap", "field", "hazard"]


func find_status_target(node: Node) -> Node:
	var current: Node = node

	while current != null:
		if get_component(current, "StatusReceiver") != null:
			return current

		current = current.get_parent()

	return null


func get_component(target: Node, component_name: String) -> Node:
	if target == null:
		return null

	var direct: Node = target.get_node_or_null(component_name)
	if direct != null:
		return direct

	for child: Node in target.get_children():
		if child.name == component_name:
			return child

	return null


func show_result(result: Dictionary) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui == null:
		if result.has("message") and result["message"] != "":
			print(result["message"])
		return

	if result.has("message") and result["message"] != "":
		ui.show_message(result["message"])

	if result.has("objective") and result["objective"] != "":
		ui.set_objective(result["objective"])


func get_debug_data() -> Dictionary:
	return {
		"radius": radius,
		"life": snapped(lifetime_timer, 0.1),
		"armed": arming_timer <= 0.0,
		"triggered": has_triggered,
		"payload": get_payload().source_name,
	}
