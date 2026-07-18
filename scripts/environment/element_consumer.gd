extends Area3D
class_name ElementConsumer

signal element_consumed(element: String, amount: float, source: String)
signal consumption_rejected(reason: String)

@export var consumer_id: String = "element_consumer"
@export var display_name: String = "Element Consumer"
@export var accepted_statuses: Array[String] = ["steamed"]
@export var accepted_status_sources: Array[String] = ["steam_burst"]
@export var accepted_elements: Array[String] = []
@export var required_payload_tags: Array[String] = []
@export var output_element: String = "steam"
@export var output_amount: float = 32.0
@export var output_target_path: NodePath
@export var output_method: String = "receive_element_output"
@export var event_cooldown: float = 0.18
@export var active: bool = true

var cooldown_timer: float = 0.0
var consumption_count: int = 0
var last_consumed_source: String = "none"
var last_consumed_element: String = "none"
var last_output_amount: float = 0.0


func _ready() -> void:
	monitoring = true
	monitorable = true
	add_to_group("debuggable")

	var status_receiver: Node = get_node_or_null("StatusReceiver")
	if status_receiver != null and status_receiver.has_signal("status_applied"):
		status_receiver.status_applied.connect(_on_status_applied)


func _process(delta: float) -> void:
	cooldown_timer = max(cooldown_timer - delta, 0.0)


func _on_status_applied(status_name: String, status_data: Dictionary) -> void:
	if not active or not accepted_statuses.has(status_name):
		return

	var source: String = str(status_data.get("source", "unknown"))
	if not accepted_status_sources.is_empty() and not accepted_status_sources.has(source):
		consumption_rejected.emit("status source " + source + " is not accepted")
		return

	deliver_output(output_element, output_amount, source, ["status", status_name])


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	if payload == null:
		return build_result(false, "empty payload")
	if not active:
		return build_result(false, "consumer inactive")
	if not accepted_elements.is_empty() and not accepted_elements.has(payload.element):
		return build_result(false, "element " + payload.element + " is not accepted")

	for required_tag: String in required_payload_tags:
		if not payload.tags.has(required_tag):
			return build_result(false, "missing payload tag " + required_tag)

	var delivered: float = deliver_output(
		payload.element,
		output_amount,
		payload.source_name,
		payload.tags
	)
	return build_result(delivered > 0.0, "delivered " + str(snapped(delivered, 0.1)))


func deliver_output(
	element_name: String,
	amount: float,
	source: String,
	tags: Array[String] = []
) -> float:
	if not active:
		consumption_rejected.emit("consumer inactive")
		return 0.0
	if cooldown_timer > 0.0:
		consumption_rejected.emit("consumer cooling down")
		return 0.0
	if amount <= 0.0:
		consumption_rejected.emit("output amount is zero")
		return 0.0

	var output_target: Node = get_node_or_null(output_target_path)
	if output_target == null:
		consumption_rejected.emit("output target missing")
		return 0.0
	if output_method == "" or not output_target.has_method(output_method):
		consumption_rejected.emit("output method missing")
		return 0.0

	var raw_result: Variant = output_target.call(output_method, element_name, amount, source, tags)
	var delivered: float = amount
	if raw_result is float or raw_result is int:
		delivered = float(raw_result)

	if delivered <= 0.0:
		consumption_rejected.emit("output target accepted nothing")
		return 0.0

	cooldown_timer = max(event_cooldown, 0.0)
	consumption_count += 1
	last_consumed_source = source
	last_consumed_element = element_name
	last_output_amount = delivered
	element_consumed.emit(element_name, delivered, source)
	return delivered


func build_result(success: bool, detail: String) -> Dictionary:
	return {
		"message": display_name + " | " + detail,
		"objective": "",
		"consumed": success,
	}


func reset_consumer() -> void:
	cooldown_timer = 0.0
	consumption_count = 0
	last_consumed_source = "none"
	last_consumed_element = "none"
	last_output_amount = 0.0


func get_debug_data() -> Dictionary:
	return {
		"consumer": consumer_id,
		"active": active,
		"accepted_statuses": accepted_statuses,
		"accepted_sources": accepted_status_sources,
		"output_element": output_element,
		"output_amount": output_amount,
		"consumptions": consumption_count,
		"last_source": last_consumed_source,
		"last_element": last_consumed_element,
		"last_amount": snapped(last_output_amount, 0.1),
		"cooldown": snapped(cooldown_timer, 0.01),
	}
