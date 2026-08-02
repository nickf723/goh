extends Node
class_name PlayerRecordedObjectSpellController

const ManagerScript = preload(
	"res://scripts/objects/recorded_object_manager_spell.gd"
)
const Catalog = preload(
	"res://scripts/objects/recorded_object_catalog.gd"
)

@export var handled_spell_id: String = "recorded_object_summon"

var actor: Node3D
var manager: RecordedObjectManagerSpell
var action_state: PlayerActionState


func _ready() -> void:
	actor = get_parent() as Node3D
	if actor != null:
		action_state = actor.get_node_or_null(
			"PlayerActionState"
		) as PlayerActionState
	manager = _ensure_spell_manager()
	add_to_group("player_ability_channels")
	add_to_group("recorded_object_spell_controllers")
	add_to_group("debuggable")


func can_handle_ability(ability: AbilityDefinition) -> bool:
	return (
		ability != null
		and ability.get_spell_id() == handled_spell_id
	)


func begin_ability_channel(
	source_player: Node3D,
	ability: AbilityDefinition
) -> bool:
	if source_player != actor or not can_handle_ability(ability):
		return false
	manager = _ensure_spell_manager()
	if manager == null:
		_show_message("Object reproduction is unavailable in this scene.")
		return false
	var blueprint_id: String = Catalog.get_selected_blueprint_id()
	if blueprint_id == "" or not Catalog.is_recorded(blueprint_id):
		_show_message(
			"Prepare a recorded object in Magic, Items, or the Blueprint record first."
		)
		return false
	if manager.placement_active:
		manager.cancel_placement()
	if not manager.select_blueprint(blueprint_id):
		return false
	if not manager.begin_placement():
		return false
	if action_state != null:
		action_state.begin_cast(0.12)
	_show_message(
		"Reproducing "
		+ str(Catalog.get_definition(blueprint_id).get(
			"display_name",
			blueprint_id.capitalize()
		))
		+ "."
	)
	return true


func get_manager() -> RecordedObjectManagerSpell:
	if manager == null or not is_instance_valid(manager):
		manager = _ensure_spell_manager()
	return manager


func _ensure_spell_manager() -> RecordedObjectManagerSpell:
	if actor == null or not is_instance_valid(actor):
		return null
	var direct: Node = actor.get_node_or_null("RecordedObjectManager")
	if direct is RecordedObjectManagerSpell:
		var existing := direct as RecordedObjectManagerSpell
		existing.bind_actor(actor)
		return existing

	# Upgrade the earlier manager without leaving two nodes listening for input.
	if direct is RecordedObjectManager:
		var old_manager := direct as RecordedObjectManager
		old_manager.cancel_placement()
		old_manager.controller_controls_enabled = false
		old_manager.keyboard_controls_enabled = false
		old_manager.remove_from_group("recorded_object_manager")
		old_manager.name = "RecordedObjectManagerLegacy"
		old_manager.queue_free()

	var created := ManagerScript.new() as RecordedObjectManagerSpell
	created.name = "RecordedObjectManager"
	actor.add_child(created)
	created.bind_actor(actor)
	return created


func _show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)
	else:
		print(message)


func get_debug_data() -> Dictionary:
	var resolved_manager: RecordedObjectManagerSpell = get_manager()
	return {
		"spell_id": handled_spell_id,
		"manager_ready": resolved_manager != null,
		"selected_blueprint": Catalog.get_selected_blueprint_id(),
		"placement_active": (
			resolved_manager.placement_active
			if resolved_manager != null
			else false
		),
	}
