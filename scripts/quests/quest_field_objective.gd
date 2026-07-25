extends Area3D
class_name QuestFieldObjective

signal objective_resolved(objective: QuestFieldObjective)

@export var quest_id: String = ""
@export var objective_id: String = ""
@export var mode: String = "interact"
@export var prompt_text: String = "Investigate"
@export var message_text: String = ""
@export var required_stage: int = -1
@export var next_stage: int = -1
@export var next_objective: String = ""
@export var set_flag: String = ""
@export var optional_id: String = ""
@export var required_stat: String = ""
@export var required_stat_minimum: int = 0
@export var blocked_by_guard_group: String = ""
@export var distraction_flag: String = ""
@export var visual_color: Color = Color(0.4, 0.8, 1.0)
@export var one_shot: bool = true

var resolved: bool = false
var label: Label3D
var visual: Node3D


func _ready() -> void:
	add_to_group("interactable_target")
	add_to_group("quest_field_objective")
	add_to_group("debuggable")
	ensure_collision()
	build_visual()
	if mode == "discover":
		remove_from_group("interactable_target")
		body_entered.connect(_on_body_entered)


func interact() -> Dictionary:
	if resolved and one_shot:
		return {"message": "Nothing more is needed here.", "objective": ""}
	var quest: Dictionary = GameState.get_quest(quest_id)
	if set_flag != "" and GameState.get_flag(set_flag):
		resolved = true
		return {"message": "That objective is already complete.", "objective": ""}
	if quest.is_empty() or str(quest.get("state", "")) != "active":
		return {"message": "Grace has no reason to interfere with this yet.", "objective": ""}
	if next_stage >= 0 and int(quest.get("stage", 0)) >= next_stage:
		resolved = true
		return {"message": "That quest step is already complete.", "objective": ""}
	if required_stage >= 0 and int(quest.get("stage", 0)) < required_stage:
		return {"message": "Another step must be completed first.", "objective": ""}
	if required_stat != "" and GameState.get_stat(required_stat) < required_stat_minimum:
		return {
			"message": required_stat.capitalize() + " " + str(required_stat_minimum) + " is required.",
			"objective": "",
		}
	if blocked_by_guard_group != "" and guard_is_active() and not GameState.get_flag(distraction_flag):
		return {
			"message": "The Gremlin sentry is watching the map case. Defeat it or create a distraction first.",
			"objective": "Defeat or distract the sentry, or recover the case with Metal magic.",
		}
	resolve_objective()
	return {"message": message_text, "objective": next_objective}


func resolve_objective() -> void:
	if resolved and one_shot:
		return
	resolved = true
	if set_flag != "":
		GameState.set_flag(set_flag, true)
	if optional_id != "":
		GameState.complete_quest_optional(quest_id, optional_id)
	if next_stage >= 0:
		GameState.set_quest_stage(quest_id, next_stage, next_objective)
	objective_resolved.emit(self)
	if one_shot:
		monitoring = false
		monitorable = false
		if mode != "discover":
			set_deferred("visible", false)
	pulse()


func guard_is_active() -> bool:
	for guard: Node in get_tree().get_nodes_in_group(blocked_by_guard_group):
		if not is_instance_valid(guard):
			continue
		var receiver: Node = guard.get_node_or_null("HitReceiver")
		if receiver == null or int(receiver.get("current_health")) > 0:
			return true
	return false


func _on_body_entered(body: Node3D) -> void:
	if resolved or not body.is_in_group("player"):
		return
	var quest: Dictionary = GameState.get_quest(quest_id)
	if quest.is_empty() or str(quest.get("state", "")) != "active":
		return
	if next_stage >= 0 and int(quest.get("stage", 0)) >= next_stage:
		resolved = true
		return
	resolve_objective()
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message_text)


func ensure_collision() -> void:
	if get_node_or_null("CollisionShape3D") != null:
		return
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.0 if mode != "discover" else 4.0
	collision.shape = shape
	collision.position.y = 0.7
	add_child(collision)


func build_visual() -> void:
	if mode == "discover":
		return
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.8, 0.35, 0.6)
	mesh_instance.mesh = mesh
	mesh_instance.position.y = 0.35
	var material := StandardMaterial3D.new()
	material.albedo_color = visual_color
	material.emission_enabled = true
	material.emission = visual_color.darkened(0.25)
	material.emission_energy_multiplier = 0.8
	mesh_instance.material_override = material
	visual.add_child(mesh_instance)
	label = Label3D.new()
	label.text = prompt_text
	label.position = Vector3(0.0, 1.25, 0.0)
	label.font_size = 25
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 7
	label.modulate = visual_color
	visual.add_child(label)


func pulse() -> void:
	if visual == null:
		return
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3.ONE * 1.35, 0.1)
	tween.tween_property(visual, "scale", Vector3.ONE, 0.18)


func get_debug_data() -> Dictionary:
	return {
		"quest": quest_id,
		"objective": objective_id,
		"mode": mode,
		"resolved": resolved,
	}
