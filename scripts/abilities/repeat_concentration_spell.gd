extends Node3D
class_name RepeatConcentrationSpell

const RepeatDefinition: Resource = preload(
	"res://data/concentration/repeat_concentration.tres"
)
const ConcentrationRuntime = preload(
	"res://scripts/concentration/concentration_runtime_access.gd"
)
const RepeatControllerScript = preload(
	"res://scripts/time/repeat_echo_controller_spell_replay.gd"
)


func execute(player: Node3D, _cast_direction: Vector3) -> void:
	if player == null or not is_instance_valid(player):
		queue_free()
		return
	var manager: Node = ConcentrationRuntime.ensure_manager(get_tree(), player)
	if manager == null:
		_show_message("Repeat could not establish its concentration service.")
		queue_free()
		return

	var active_value: Variant = manager.get("active_effect")
	var repeat_already_active: bool = (
		active_value is Resource
		and str((active_value as Resource).get("effect_id"))
		== "repeat_concentration"
	)
	if repeat_already_active:
		manager.call("deactivate_effect", true)
		queue_free()
		return

	var caster: Node = player.get_node_or_null("AbilityCaster")
	if not bool(manager.call("activate_effect", RepeatDefinition, caster)):
		_show_message("Repeat could not take hold.")
		queue_free()
		return

	var existing: RepeatEchoController = get_tree().get_first_node_in_group(
		"repeat_echo_controller"
	) as RepeatEchoController
	if existing != null and is_instance_valid(existing):
		existing.queue_free()

	var controller := RepeatControllerScript.new() as RepeatEchoControllerSpellReplay
	controller.name = "RepeatEchoController"
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = get_parent()
	if scene_root == null:
		manager.call("deactivate_effect", false)
		queue_free()
		return
	scene_root.add_child(controller)
	if not controller.bind_repeat(player, manager, RepeatDefinition):
		controller.queue_free()
		manager.call("deactivate_effect", false)
		_show_message("Repeat could not find Grace's timeline.")
	else:
		_show_message(
			"Repeat concentrates. The time echo follows Grace one second behind and independently replays clone-safe attacks and spells."
		)
	queue_free()


func _show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)
