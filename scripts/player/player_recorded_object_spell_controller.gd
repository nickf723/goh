extends Node
class_name PlayerRecordedObjectSpellController

const ManagerScript = preload(
	"res://scripts/objects/recorded_object_manager_spell.gd"
)
const Catalog = preload(
	"res://scripts/objects/recorded_object_catalog.gd"
)

const SHARED_PLACEMENT_ID: String = "recorded_object"

@export var handled_spell_id: String = "recorded_object_summon"

var actor: Node3D
var manager: RecordedObjectManagerSpell
var action_state: PlayerActionState
var shared_session_active: bool = false
var previous_keyboard_controls: bool = true
var previous_controller_controls: bool = true


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
	_show_message("Reproducing " + _blueprint_name(blueprint_id) + ".")
	return true


# Global persistent-ability context contract.
func can_handle_ability_context(ability: AbilityDefinition) -> bool:
	return can_handle_ability(ability)


func is_ability_context_available(ability: AbilityDefinition) -> bool:
	return (
		can_handle_ability_context(ability)
		and not Catalog.get_recorded_blueprint_ids().is_empty()
	)


func has_active_ability_context() -> bool:
	var resolved_manager: RecordedObjectManagerSpell = get_manager()
	return (
		resolved_manager != null
		and (
			resolved_manager.placement_active
			or resolved_manager.get_active_count() > 0
		)
	)


func get_ability_context_spec(ability: AbilityDefinition) -> Dictionary:
	if not is_ability_context_available(ability):
		return {}
	var recorded: Array[String] = Catalog.get_recorded_blueprint_ids()
	var selected_id: String = Catalog.get_selected_blueprint_id()
	if selected_id == "" and not recorded.is_empty():
		Catalog.select_blueprint(recorded[0])
		selected_id = recorded[0]
	var definition: Dictionary = Catalog.get_definition(selected_id)
	var active_count: int = get_manager().get_active_count() if get_manager() != null else 0
	var actions: Array[Dictionary] = [
		{
			"id": "reproduce_selected",
			"label": "Place " + str(definition.get("short_name", "Object")),
			"description": (
				str(definition.get("display_name", selected_id.capitalize()))
				+ " • " + str(definition.get("mana_cost", 0)) + " mana"
			),
		},
		{
			"id": "previous_blueprint",
			"label": "Previous Object",
			"description": "Prepare the previous recorded blueprint.",
		},
		{
			"id": "next_blueprint",
			"label": "Next Object",
			"description": "Prepare the next recorded blueprint.",
		},
	]
	if active_count > 0:
		actions.append({
			"id": "recall_last",
			"label": "Recall Last",
			"description": "Dismiss the most recently reproduced object.",
		})
		actions.append({
			"id": "dismiss_all",
			"label": "Dismiss All",
			"description": "Dismiss every reproduced object currently in the world.",
		})
	return {
		"context_id": "recorded_objects",
		"title": "Recorded Objects",
		"subtitle": (
			_blueprint_name(selected_id)
			+ " prepared • " + str(active_count) + " active"
		),
		"selected_id": "reproduce_selected",
		"actions": actions,
	}


func execute_ability_context_action(
	action_id: String,
	_payload: Variant = Vector3.INF
) -> Dictionary:
	manager = _ensure_spell_manager()
	if manager == null:
		return {"ok": false, "error": "Object reproduction is unavailable."}
	var normalized: String = action_id.to_lower().strip_edges()
	match normalized:
		"reproduce_selected":
			return {
				"ok": true,
				"begin_shared_placement": SHARED_PLACEMENT_ID,
			}
		"previous_blueprint":
			return _cycle_blueprint(-1)
		"next_blueprint":
			return _cycle_blueprint(1)
		"recall_last":
			var objects: Array[RecordedObjectInstance] = manager.get_active_objects()
			if objects.is_empty():
				return {"ok": false, "error": "No reproduced object is active."}
			var last: RecordedObjectInstance = objects.back()
			manager.active_objects.erase(last)
			if last != null and is_instance_valid(last):
				last.queue_free()
			manager.active_objects_changed.emit(manager.active_objects.size())
			return {"ok": true, "message": "Most recent recorded object recalled."}
		"dismiss_all":
			if manager.get_active_count() <= 0:
				return {"ok": false, "error": "No reproduced objects are active."}
			manager.clear_spawned_objects()
			return {"ok": true, "message": "All recorded objects dismissed."}
		_:
			return {"ok": false, "error": "Unknown recorded-object action."}


# Shared placement provider contract.
func begin_shared_placement(placement_id: String) -> Dictionary:
	if placement_id != SHARED_PLACEMENT_ID:
		return {"ok": false, "error": "Unknown recorded-object placement."}
	manager = _ensure_spell_manager()
	if manager == null:
		return {"ok": false, "error": "Object reproduction is unavailable."}
	var selected_id: String = Catalog.get_selected_blueprint_id()
	if selected_id == "" or not manager.select_blueprint(selected_id):
		return {"ok": false, "error": "No recorded blueprint is prepared."}
	if manager.placement_active:
		manager.cancel_placement()
	previous_keyboard_controls = manager.keyboard_controls_enabled
	previous_controller_controls = manager.controller_controls_enabled
	manager.keyboard_controls_enabled = false
	manager.controller_controls_enabled = false
	if not manager.begin_placement():
		_restore_manager_controls()
		return {"ok": false, "error": "Recorded-object placement could not begin."}
	manager.keyboard_controls_enabled = false
	manager.controller_controls_enabled = false
	shared_session_active = true
	return {
		"ok": true,
		"message": "Placing " + _blueprint_name(selected_id) + ".",
	}


func get_shared_placement_state(placement_id: String) -> Dictionary:
	if placement_id != SHARED_PLACEMENT_ID or manager == null:
		return {"session_active": false, "valid": false}
	var selected_id: String = Catalog.get_selected_blueprint_id()
	var definition: Dictionary = Catalog.get_definition(selected_id)
	var debug: Dictionary = manager.get_debug_data()
	return {
		"session_active": shared_session_active and manager.placement_active,
		"eyebrow": "REPRODUCE OBJECT",
		"title": str(definition.get("icon", "▣")) + "  " + _blueprint_name(selected_id),
		"valid": bool(debug.get("placement_valid", false)),
		"reason": str(debug.get("invalid_reason", "That reproduction cannot fit there.")),
		"depth": float(debug.get("placement_depth_offset", 0.0)),
		"rotation": float(debug.get("yaw_degrees", 0.0)),
		"mana_cost": int(definition.get("mana_cost", 0)),
		"active_count": manager.get_active_count(),
		"active_limit": int(definition.get("maximum_active", 1)),
		"variant_count": Catalog.get_recorded_blueprint_ids().size(),
	}


func adjust_shared_placement_depth(
	placement_id: String,
	direction: int
) -> Dictionary:
	if not _shared_session_matches(placement_id):
		return {"ok": false, "error": "Recorded-object placement is not active."}
	manager.adjust_depth(direction)
	return {"ok": true}


func rotate_shared_placement(
	placement_id: String,
	direction: int
) -> Dictionary:
	if not _shared_session_matches(placement_id):
		return {"ok": false, "error": "Recorded-object placement is not active."}
	manager.rotate_preview(direction)
	return {"ok": true}


func cycle_shared_placement_variant(
	placement_id: String,
	direction: int
) -> Dictionary:
	if not _shared_session_matches(placement_id):
		return {"ok": false, "error": "Recorded-object placement is not active."}
	var recorded: Array[String] = Catalog.get_recorded_blueprint_ids()
	if recorded.size() <= 1:
		return {"ok": false, "error": "No other recorded object is available."}
	var index: int = recorded.find(Catalog.get_selected_blueprint_id())
	index = posmod((0 if index < 0 else index) + signi(direction), recorded.size())
	var selected_id: String = recorded[index]
	if not Catalog.select_blueprint(selected_id) or not manager.select_blueprint(selected_id):
		return {"ok": false, "error": "That recorded object could not be prepared."}
	manager.keyboard_controls_enabled = false
	manager.controller_controls_enabled = false
	return {
		"ok": true,
		"message": "Prepared: " + _blueprint_name(selected_id) + ".",
	}


func confirm_shared_placement(placement_id: String) -> Dictionary:
	if not _shared_session_matches(placement_id):
		return {"ok": false, "error": "Recorded-object placement is not active."}
	var selected_id: String = Catalog.get_selected_blueprint_id()
	var instance: RecordedObjectInstance = manager.confirm_placement()
	if instance == null:
		return {
			"ok": false,
			"error": manager.invalid_reason if manager.invalid_reason != "" else "That object cannot fit there.",
		}
	shared_session_active = false
	_restore_manager_controls()
	return {
		"ok": true,
		"message": _blueprint_name(selected_id) + " reproduced.",
		"object": instance,
	}


func confirm_shared_placement_at(
	placement_id: String,
	world_position: Vector3,
	yaw_degrees: float = 0.0
) -> Dictionary:
	if not _shared_session_matches(placement_id):
		return {"ok": false, "error": "Recorded-object placement is not active."}
	var selected_id: String = Catalog.get_selected_blueprint_id()
	var instance: RecordedObjectInstance = manager.place_selected_at(
		world_position,
		yaw_degrees,
		false,
		false
	)
	if instance == null:
		return {
			"ok": false,
			"error": manager.invalid_reason if manager.invalid_reason != "" else "That object cannot fit there.",
		}
	manager.cancel_placement()
	shared_session_active = false
	_restore_manager_controls()
	return {
		"ok": true,
		"message": _blueprint_name(selected_id) + " reproduced.",
		"object": instance,
	}


func cancel_shared_placement(placement_id: String) -> void:
	if placement_id != SHARED_PLACEMENT_ID:
		return
	if manager != null and manager.placement_active:
		manager.cancel_placement()
	shared_session_active = false
	_restore_manager_controls()


func get_ability_context_status() -> Dictionary:
	var resolved_manager: RecordedObjectManagerSpell = get_manager()
	if resolved_manager == null:
		return {"active": false}
	var active_count: int = resolved_manager.get_active_count()
	if active_count <= 0 and not resolved_manager.placement_active:
		return {"active": false}
	var selected_id: String = Catalog.get_selected_blueprint_id()
	var state: String = (
		"Shared placement active"
		if shared_session_active and resolved_manager.placement_active
		else str(active_count) + " active • " + _blueprint_name(selected_id) + " prepared"
	)
	return {
		"active": true,
		"title": "Recorded Objects",
		"state": state,
		"hint": "Select Reproduce Object and press Cast to manage",
	}


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


func _shared_session_matches(placement_id: String) -> bool:
	return (
		placement_id == SHARED_PLACEMENT_ID
		and shared_session_active
		and manager != null
		and manager.placement_active
	)


func _restore_manager_controls() -> void:
	if manager == null or not is_instance_valid(manager):
		return
	manager.keyboard_controls_enabled = previous_keyboard_controls
	manager.controller_controls_enabled = previous_controller_controls


func _cycle_blueprint(direction: int) -> Dictionary:
	var recorded: Array[String] = Catalog.get_recorded_blueprint_ids()
	if recorded.is_empty():
		return {"ok": false, "error": "No recorded blueprints are available."}
	var index: int = recorded.find(Catalog.get_selected_blueprint_id())
	if index < 0:
		index = 0
	else:
		index = posmod(index + signi(direction), recorded.size())
	var selected_id: String = recorded[index]
	if not Catalog.select_blueprint(selected_id):
		return {"ok": false, "error": "That blueprint could not be prepared."}
	if manager != null:
		manager.select_blueprint(selected_id)
	return {
		"ok": true,
		"keep_open": true,
		"selected_id": "reproduce_selected",
		"message": "Prepared: " + _blueprint_name(selected_id) + ".",
	}


func _blueprint_name(blueprint_id: String) -> String:
	if blueprint_id == "":
		return "No object"
	return str(Catalog.get_definition(blueprint_id).get(
		"display_name",
		blueprint_id.capitalize()
	))


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
		"placement_active": resolved_manager.placement_active if resolved_manager != null else false,
		"shared_session_active": shared_session_active,
		"active_count": resolved_manager.get_active_count() if resolved_manager != null else 0,
		"context_available": not Catalog.get_recorded_blueprint_ids().is_empty(),
	}
