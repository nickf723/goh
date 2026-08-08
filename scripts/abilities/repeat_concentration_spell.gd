extends Node3D
class_name RepeatConcentrationSpell

const RepeatDefinition: Resource = preload(
	"res://data/concentration/repeat_concentration.tres"
)
const ConcentrationRuntime = preload(
	"res://scripts/concentration/concentration_runtime_access.gd"
)
const RepeatControllerScript = preload(
	"res://scripts/time/repeat_echo_controller_illusion_ready.gd"
)

const REPEAT_EFFECT_ID: String = "repeat_concentration"


func execute(player: Node3D, _cast_direction: Vector3) -> void:
	if player == null or not is_instance_valid(player):
		queue_free()
		return
	var manager: Node = ConcentrationRuntime.ensure_manager(get_tree(), player)
	if manager == null:
		_show_message("Repeat could not establish its concentration service.")
		queue_free()
		return

	var repeat_already_active: bool = false
	if manager.has_method("has_effect"):
		repeat_already_active = bool(manager.call("has_effect", REPEAT_EFFECT_ID))
	else:
		var active_value: Variant = manager.get("active_effect")
		repeat_already_active = (
			active_value is Resource
			and str((active_value as Resource).get("effect_id"))
			== REPEAT_EFFECT_ID
		)
	if repeat_already_active:
		if manager.has_method("deactivate_effect_by_id"):
			manager.call("deactivate_effect_by_id", REPEAT_EFFECT_ID, true)
		else:
			manager.call("deactivate_effect", true)
		queue_free()
		return

	var caster: Node = player.get_node_or_null("AbilityCaster")
	if not bool(manager.call("activate_effect", RepeatDefinition, caster)):
		_show_message("Repeat could not take hold within the current concentration budget.")
		queue_free()
		return

	var existing: RepeatEchoController = get_tree().get_first_node_in_group(
		"repeat_echo_controller"
	) as RepeatEchoController
	if existing != null and is_instance_valid(existing):
		existing.queue_free()

	var controller := RepeatControllerScript.new() as RepeatEchoControllerIllusionReady
	controller.name = "RepeatEchoController"
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = get_parent()
	if scene_root == null:
		_release_repeat(manager, false)
		queue_free()
		return
	scene_root.add_child(controller)
	if not controller.bind_repeat(player, manager, RepeatDefinition):
		controller.queue_free()
		_release_repeat(manager, false)
		_show_message("Repeat could not find Grace's timeline.")
	else:
		_show_message(
			"Repeat concentrates. Grace and every active Soul Duplicate now receive independent delayed history lanes."
		)
	queue_free()


func _release_repeat(manager: Node, show_feedback: bool) -> void:
	if manager == null:
		return
	if manager.has_method("deactivate_effect_by_id"):
		manager.call("deactivate_effect_by_id", REPEAT_EFFECT_ID, show_feedback)
	elif manager.has_method("deactivate_effect"):
		manager.call("deactivate_effect", show_feedback)


func _show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)
