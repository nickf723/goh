extends StaticBody3D
class_name VillageRouteGate

signal gate_opened(gate_id: String, method: String)

@export var gate_id: String = "village_gate"
@export var display_name: String = "Collapsed Debris"
@export var accepts_fire: bool = true
@export var accepts_ice_force_combo: bool = true
@export var require_heavy_for_shatter: bool = false
@export var starts_frozen: bool = false
@export var frozen_duration: float = 30.0
@export var completion_flag: String = ""
@export var objective_after: String = "The route is open."
@export var fire_message: String = "Fire consumes the dry debris and opens a route."
@export var freeze_message: String = "The debris freezes solid. A heavy impact could shatter it."
@export var shatter_message: String = "The frozen obstruction shatters apart."
@export var locked_message: String = "The obstruction barely moves. Fire could consume it, or ice and force might break it."
@export var collision_path: NodePath = NodePath("CollisionShape3D")
@export var visual_root_path: NodePath = NodePath("VisualRoot")

var is_open: bool = false
var is_frozen: bool = false
var frozen_timer: float = 0.0

@onready var collision_shape: CollisionShape3D = get_node_or_null(collision_path) as CollisionShape3D
@onready var visual_root: Node3D = get_node_or_null(visual_root_path) as Node3D


func _ready() -> void:
	add_to_group("village_route_gate")
	add_to_group("debuggable")

	sync_from_game_state()
	if is_open:
		return

	if starts_frozen:
		freeze_gate()


func _process(delta: float) -> void:
	if not is_frozen or is_open:
		return

	if frozen_timer <= 0.0:
		return

	frozen_timer -= delta
	if frozen_timer <= 0.0:
		is_frozen = false
		set_visual_tint(Color(0.42, 0.31, 0.2, 1.0), false)
		show_message("The ice coating melts away.")


func sync_from_game_state() -> void:
	if completion_flag == "":
		return
	if GameState.get_flag(completion_flag):
		open_gate("restored", false)


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	if payload == null:
		return {"message": "", "objective": ""}

	if is_open:
		return {"message": display_name + " is already cleared.", "objective": ""}

	var tags: Array[String] = payload.tags
	var is_fire_hit: bool = payload.element == "fire" or tags.has("fire") or tags.has("burning")
	var is_ice_hit: bool = payload.element == "ice" or tags.has("ice") or tags.has("freeze")
	var is_force_hit: bool = (
		tags.has("force")
		or tags.has("heavy")
		or tags.has("blunt")
		or payload.knockback_strength > 0.0
	)
	var meets_shatter_requirement: bool = (
		is_force_hit
		and (not require_heavy_for_shatter or tags.has("heavy"))
	)

	if accepts_fire and is_fire_hit:
		open_gate("fire")
		return {"message": fire_message, "objective": objective_after}

	if accepts_ice_force_combo and is_ice_hit:
		freeze_gate()
		return {"message": freeze_message, "objective": ""}

	if accepts_ice_force_combo and is_frozen and meets_shatter_requirement:
		open_gate("shatter")
		return {"message": shatter_message, "objective": objective_after}

	return {"message": locked_message, "objective": ""}


func freeze_gate() -> void:
	if is_open:
		return

	is_frozen = true
	frozen_timer = max(frozen_duration, 0.0)
	set_visual_tint(Color(0.45, 0.88, 1.0, 1.0), true)


func unlock() -> void:
	open_gate("encounter")


func open_gate(method: String = "unknown", update_progress: bool = true) -> void:
	if is_open:
		return

	is_open = true
	is_frozen = false
	frozen_timer = 0.0

	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

	if visual_root != null:
		if method == "restored":
			visual_root.position.y -= 3.2
			visual_root.scale = Vector3(1.0, 0.15, 1.0)
		else:
			var tween: Tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(visual_root, "position:y", visual_root.position.y - 3.2, 0.55)
			tween.tween_property(visual_root, "scale", Vector3(1.0, 0.15, 1.0), 0.55)

	if update_progress:
		if completion_flag != "":
			GameState.set_flag(completion_flag, true)

		if objective_after != "":
			GameState.set_objective(objective_after)

	if method == "encounter":
		show_message(display_name + " unlocks after the encounter.")

	gate_opened.emit(gate_id, method)


func set_visual_tint(color: Color, emissive: bool) -> void:
	if visual_root == null:
		return

	for child: Node in visual_root.get_children():
		if not child is MeshInstance3D:
			continue
		var mesh_instance: MeshInstance3D = child as MeshInstance3D
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.58
		if emissive:
			material.emission_enabled = true
			material.emission = color.darkened(0.25)
			material.emission_energy_multiplier = 0.8
		mesh_instance.material_override = material


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func reset_gate() -> void:
	is_open = false
	is_frozen = starts_frozen
	frozen_timer = frozen_duration if starts_frozen else 0.0
	if collision_shape != null:
		collision_shape.set_deferred("disabled", false)
	if visual_root != null:
		visual_root.position = Vector3.ZERO
		visual_root.scale = Vector3.ONE
	set_visual_tint(
		Color(0.45, 0.88, 1.0, 1.0) if starts_frozen else Color(0.42, 0.31, 0.2, 1.0),
		starts_frozen
	)
	if completion_flag != "":
		GameState.set_flag(completion_flag, false)


func get_debug_data() -> Dictionary:
	return {
		"gate": gate_id,
		"open": is_open,
		"frozen": is_frozen,
		"require_heavy_for_shatter": require_heavy_for_shatter,
		"timer": snapped(frozen_timer, 0.1),
	}
