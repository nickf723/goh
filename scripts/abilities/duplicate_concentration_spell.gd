extends Node3D
class_name DuplicateConcentrationSpell

const DuplicateDefinition: Resource = preload(
	"res://data/concentration/duplicate_concentration.tres"
)
const ConcentrationRuntime = preload(
	"res://scripts/concentration/concentration_runtime_access.gd"
)
const DuplicateControllerScript = preload(
	"res://scripts/soul/soul_duplicate_controller.gd"
)


func execute(player: Node3D, _cast_direction: Vector3) -> void:
	if not player is CharacterBody3D:
		queue_free()
		return
	var actor: CharacterBody3D = player as CharacterBody3D
	var manager: Node = ConcentrationRuntime.ensure_manager(get_tree(), actor)
	if manager == null:
		_show_message("Duplicate could not establish its concentration service.")
		queue_free()
		return

	var already_active: bool = false
	if manager.has_method("has_effect"):
		already_active = bool(manager.call("has_effect", "duplicate_concentration"))
	else:
		var active_value: Variant = manager.get("active_effect")
		already_active = active_value is Resource and str((active_value as Resource).get("effect_id")) == "duplicate_concentration"
	if already_active:
		if manager.has_method("deactivate_effect_by_id"):
			manager.call("deactivate_effect_by_id", "duplicate_concentration", true)
		else:
			manager.call("deactivate_effect", true)
		queue_free()
		return

	var caster: Node = actor.get_node_or_null("AbilityCaster")
	if not bool(manager.call("activate_effect", DuplicateDefinition, caster)):
		_show_message("Duplicate could not take hold within the current concentration budget.")
		queue_free()
		return

	var existing: Node = get_tree().get_first_node_in_group("soul_duplicate_controller")
	if existing != null and is_instance_valid(existing):
		existing.queue_free()
	var controller := DuplicateControllerScript.new() as SoulDuplicateController
	controller.name = "SoulDuplicateController"
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = get_parent()
	if scene_root == null:
		manager.call("deactivate_effect_by_id", "duplicate_concentration", false)
		queue_free()
		return
	scene_root.add_child(controller)
	if not controller.bind_duplicate(actor, manager):
		controller.queue_free()
		if manager.has_method("deactivate_effect_by_id"):
			manager.call("deactivate_effect_by_id", "duplicate_concentration", false)
		_show_message("Duplicate could not resolve Grace's live action stream.")
	else:
		_show_message("Duplicate concentrates. Soul Grace now performs Grace's actions in parallel with independent collision and spell outcomes.")
	queue_free()


func _show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)
