extends Node3D
class_name MechanismBridgeOutput

signal output_state_changed(active: bool)

@export var display_name: String = "Mechanism Bridge"
@export var managed_root_path: NodePath = NodePath("BridgeRoot")
@export var state_label_path: NodePath = NodePath("StateLabel")
@export var starts_extended: bool = false
@export_range(0.05, 3.0, 0.05) var transition_seconds: float = 0.4
@export var extended_scale: Vector3 = Vector3.ONE
@export var retracted_scale: Vector3 = Vector3(0.02, 1.0, 1.0)

var active: bool = false
var managed_root: Node3D
var state_label: Label3D
var bridge_tween: Tween
var last_packet: Dictionary = {}


func _ready() -> void:
	add_to_group("mechanism_outputs")
	add_to_group("mechanism_bridges")
	add_to_group("lab_resettable")
	add_to_group("debuggable")
	managed_root = get_node_or_null(managed_root_path) as Node3D
	state_label = get_node_or_null(state_label_path) as Label3D
	set_bridge_extended(starts_extended, true, {"reason": "startup"})


func set_mechanism_active(next_active: bool, packet: Dictionary = {}) -> void:
	set_bridge_extended(next_active, false, packet)


func set_bridge_extended(
	next_extended: bool,
	immediate: bool = false,
	packet: Dictionary = {}
) -> void:
	var changed: bool = active != next_extended
	active = next_extended
	last_packet = packet.duplicate(true)
	_set_collision_enabled(active)
	var target_scale: Vector3 = extended_scale if active else retracted_scale
	if bridge_tween != null and bridge_tween.is_valid():
		bridge_tween.kill()
	if managed_root != null:
		managed_root.visible = true
		if immediate:
			managed_root.scale = target_scale
		else:
			bridge_tween = create_tween()
			bridge_tween.set_trans(Tween.TRANS_QUAD)
			bridge_tween.set_ease(Tween.EASE_IN_OUT)
			bridge_tween.tween_property(managed_root, "scale", target_scale, transition_seconds)
			if not active:
				bridge_tween.tween_callback(func() -> void:
					if managed_root != null:
						managed_root.visible = false
				)
	if state_label != null:
		state_label.text = display_name.to_upper() + "\n" + ("EXTENDED" if active else "RETRACTED")
	if changed:
		output_state_changed.emit(active)


func is_mechanism_active() -> bool:
	return active


func _set_collision_enabled(enabled: bool) -> void:
	if managed_root == null:
		return
	_set_collision_recursive(managed_root, enabled)


func _set_collision_recursive(node: Node, enabled: bool) -> void:
	if node is CollisionObject3D:
		var collision_object := node as CollisionObject3D
		if not collision_object.has_meta("mechanism_original_layer"):
			collision_object.set_meta("mechanism_original_layer", collision_object.collision_layer)
			collision_object.set_meta("mechanism_original_mask", collision_object.collision_mask)
		collision_object.collision_layer = int(collision_object.get_meta("mechanism_original_layer", 1)) if enabled else 0
		collision_object.collision_mask = int(collision_object.get_meta("mechanism_original_mask", 1)) if enabled else 0
	for child: Node in node.get_children():
		_set_collision_recursive(child, enabled)


func reset_target() -> void:
	set_bridge_extended(starts_extended, true, {"reason": "reset"})


func get_debug_data() -> Dictionary:
	return {
		"mechanism_bridge": true,
		"display_name": display_name,
		"extended": active,
		"packet": last_packet.duplicate(true),
	}
