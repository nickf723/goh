extends Node
class_name PlayerArtificerSpellController

const ManagerScript = preload(
	"res://scripts/builds/artificer_construction_manager_safe.gd"
)
const PartCatalog = preload(
	"res://scripts/builds/engineering_part_catalog.gd"
)
const BuildCatalog = preload(
	"res://scripts/builds/engineering_build_catalog.gd"
)

const ASSEMBLY_PLACEMENT_ID: String = "artificer_part"
const DEPLOY_PLACEMENT_ID: String = "artificer_deploy"

@export var assembly_spell_id: String = "artificer_assembly"
@export var deploy_spell_id: String = "deploy_contraption"

var actor: Node3D
var manager: ArtificerConstructionManager
var action_state: PlayerActionState
var shared_session_id: String = ""
var previous_keyboard_controls: bool = true


func _ready() -> void:
	actor = get_parent() as Node3D
	if actor != null:
		action_state = actor.get_node_or_null(
			"PlayerActionState"
		) as PlayerActionState
	PartCatalog.ensure_prototype_baseline()
	manager = _ensure_manager()
	add_to_group("player_ability_channels")
	add_to_group("player_artificer_spell_controllers")
	add_to_group("debuggable")


func can_handle_ability(ability: AbilityDefinition) -> bool:
	if ability == null:
		return false
	return ability.get_spell_id() in [assembly_spell_id, deploy_spell_id]


func begin_ability_channel(
	source_player: Node3D,
	ability: AbilityDefinition
) -> bool:
	if source_player != actor or not can_handle_ability(ability):
		return false
	manager = _ensure_manager()
	if manager == null:
		_show_message("Artificer construction is unavailable in this scene.")
		return false
	var spell_id: String = ability.get_spell_id()
	var started: bool = false
	if spell_id == assembly_spell_id:
		started = manager.begin_assembly()
	elif spell_id == deploy_spell_id:
		started = manager.begin_deploy()
	if started and action_state != null:
		action_state.begin_cast(0.12)
	return started


# Global persistent-ability context contract.
func can_handle_ability_context(ability: AbilityDefinition) -> bool:
	return can_handle_ability(ability)


func is_ability_context_available(ability: AbilityDefinition) -> bool:
	if not can_handle_ability_context(ability):
		return false
	if ability.get_spell_id() == assembly_spell_id:
		return not PartCatalog.get_unlocked_part_ids().is_empty()
	return not BuildCatalog.get_saved_build_ids().is_empty()


func has_active_ability_context() -> bool:
	var resolved_manager: ArtificerConstructionManager = get_manager()
	return (
		resolved_manager != null
		and (
			resolved_manager.mode != ArtificerConstructionManager.MODE_NONE
			or not resolved_manager.draft_parts.is_empty()
			or resolved_manager.get_active_count() > 0
		)
	)


func get_ability_context_spec(ability: AbilityDefinition) -> Dictionary:
	if not is_ability_context_available(ability):
		return {}
	if ability.get_spell_id() == assembly_spell_id:
		return _get_assembly_context_spec()
	return _get_deploy_context_spec()


func _get_assembly_context_spec() -> Dictionary:
	var selected_part: String = PartCatalog.get_selected_part_id()
	var definition: Dictionary = PartCatalog.get_definition(selected_part)
	var draft_count: int = manager.draft_parts.size() if manager != null else 0
	var actions: Array[Dictionary] = [
		{
			"id": "place_part",
			"label": "Attach " + str(definition.get("display_name", "Part")),
			"description": "Enter shared placement for the prepared engineering part.",
		},
		{
			"id": "previous_part",
			"label": "Previous Part",
			"description": "Prepare the previous unlocked engineering part.",
		},
		{
			"id": "next_part",
			"label": "Next Part",
			"description": "Prepare the next unlocked engineering part.",
		},
	]
	if draft_count > 0:
		actions.append({
			"id": "undo_part",
			"label": "Undo Last Part",
			"description": "Remove the most recently attached engineering part.",
		})
		actions.append({
			"id": "clear_draft",
			"label": "Clear Draft",
			"description": "Discard every part in the current draft.",
		})
	if draft_count >= 2:
		actions.append({
			"id": "finalize_blueprint",
			"label": "Save Blueprint",
			"description": "Save this draft into the prepared custom contraption slot.",
		})
	return {
		"context_id": "artificer_assembly",
		"title": "Artificer Assembly",
		"subtitle": (
			str(definition.get("display_name", selected_part.capitalize()))
			+ " prepared • " + str(draft_count) + " draft parts"
		),
		"selected_id": "place_part",
		"actions": actions,
	}


func _get_deploy_context_spec() -> Dictionary:
	var selected_build: String = BuildCatalog.get_selected_build_id()
	var definition: Dictionary = BuildCatalog.get_definition(selected_build)
	var active_count: int = manager.get_active_count() if manager != null else 0
	var actions: Array[Dictionary] = [
		{
			"id": "deploy_selected",
			"label": "Deploy " + str(definition.get("short_name", "Contraption")),
			"description": (
				str(definition.get("display_name", selected_build.capitalize()))
				+ " • " + str(definition.get("mana_cost", 0)) + " mana"
			),
		},
		{
			"id": "previous_build",
			"label": "Previous Blueprint",
			"description": "Prepare the previous saved contraption blueprint.",
		},
		{
			"id": "next_build",
			"label": "Next Blueprint",
			"description": "Prepare the next saved contraption blueprint.",
		},
	]
	if active_count > 0:
		actions.append({
			"id": "recall_contraption",
			"label": "Recall Last",
			"description": "Dismiss the most recently deployed contraption.",
		})
		actions.append({
			"id": "dismiss_contraptions",
			"label": "Dismiss All",
			"description": "Dismiss every active contraption.",
		})
	return {
		"context_id": "deploy_contraption",
		"title": "Deploy Contraption",
		"subtitle": (
			str(definition.get("display_name", selected_build.capitalize()))
			+ " prepared • " + str(active_count) + " active"
		),
		"selected_id": "deploy_selected",
		"actions": actions,
	}


func execute_ability_context_action(
	action_id: String,
	_payload: Variant = Vector3.INF
) -> Dictionary:
	manager = _ensure_manager()
	if manager == null:
		return {"ok": false, "error": "Artificer construction is unavailable."}
	var normalized: String = action_id.to_lower().strip_edges()
	match normalized:
		"place_part":
			return {
				"ok": true,
				"begin_shared_placement": ASSEMBLY_PLACEMENT_ID,
			}
		"previous_part":
			return _cycle_part(-1)
		"next_part":
			return _cycle_part(1)
		"undo_part":
			if not manager.undo_last_part():
				return {"ok": false, "error": "The artificer draft is already empty."}
			return {
				"ok": true,
				"keep_open": true,
				"selected_id": "place_part",
				"message": "Last engineering part removed.",
			}
		"clear_draft":
			if manager.draft_parts.is_empty():
				return {"ok": false, "error": "The artificer draft is already empty."}
			manager.clear_draft()
			return {
				"ok": true,
				"keep_open": true,
				"selected_id": "place_part",
				"message": "Artificer draft cleared.",
			}
		"finalize_blueprint":
			var saved: Dictionary = manager.finalize_draft(false, false)
			if not bool(saved.get("ok", false)):
				return {
					"ok": false,
					"error": str(saved.get("error", "The blueprint could not be saved.")),
				}
			return {
				"ok": true,
				"message": "Contraption blueprint saved.",
				"build_id": str(saved.get("build_id", "")),
			}
		"deploy_selected":
			return {
				"ok": true,
				"begin_shared_placement": DEPLOY_PLACEMENT_ID,
			}
		"previous_build":
			return _cycle_build(-1)
		"next_build":
			return _cycle_build(1)
		"recall_contraption":
			if manager.active_contraptions.is_empty():
				return {"ok": false, "error": "No contraption is active."}
			var last: ArtificerContraptionInstance = manager.active_contraptions.back()
			manager.active_contraptions.erase(last)
			if last != null and is_instance_valid(last):
				last.queue_free()
			manager.active_contraptions_changed.emit(manager.active_contraptions.size())
			return {"ok": true, "message": "Most recent contraption recalled."}
		"dismiss_contraptions":
			if manager.get_active_count() <= 0:
				return {"ok": false, "error": "No contraptions are active."}
			manager.clear_active_contraptions()
			return {"ok": true, "message": "All contraptions dismissed."}
		_:
			return {"ok": false, "error": "Unknown Artificer context action."}


# Shared placement provider contract.
func begin_shared_placement(placement_id: String) -> Dictionary:
	manager = _ensure_manager()
	if manager == null:
		return {"ok": false, "error": "Artificer construction is unavailable."}
	if placement_id not in [ASSEMBLY_PLACEMENT_ID, DEPLOY_PLACEMENT_ID]:
		return {"ok": false, "error": "Unknown Artificer placement mode."}
	if manager.mode != ArtificerConstructionManager.MODE_NONE:
		manager.cancel_mode()
	previous_keyboard_controls = manager.keyboard_controls_enabled
	manager.keyboard_controls_enabled = false
	var started: bool = false
	if placement_id == ASSEMBLY_PLACEMENT_ID:
		started = manager.begin_assembly()
	else:
		var selected_build: String = BuildCatalog.get_selected_build_id()
		started = selected_build != "" and manager.begin_deploy(selected_build)
	if not started:
		_restore_manager_controls()
		return {"ok": false, "error": "Artificer placement could not begin."}
	manager.keyboard_controls_enabled = false
	shared_session_id = placement_id
	return {
		"ok": true,
		"message": (
			"Placing " + _part_name(PartCatalog.get_selected_part_id()) + "."
			if placement_id == ASSEMBLY_PLACEMENT_ID
			else "Deploying " + _build_name(BuildCatalog.get_selected_build_id()) + "."
		),
	}


func get_shared_placement_state(placement_id: String) -> Dictionary:
	if not _shared_session_matches(placement_id):
		return {"session_active": false, "valid": false}
	var debug: Dictionary = manager.get_debug_data()
	if placement_id == ASSEMBLY_PLACEMENT_ID:
		var part_id: String = PartCatalog.get_selected_part_id()
		var part: Dictionary = PartCatalog.get_definition(part_id)
		return {
			"session_active": manager.mode == ArtificerConstructionManager.MODE_ASSEMBLY,
			"eyebrow": "ARTIFICER ASSEMBLY",
			"title": str(part.get("icon", "⚙")) + "  " + _part_name(part_id),
			"valid": bool(debug.get("placement_valid", false)),
			"reason": str(debug.get("invalid_reason", "That part cannot attach there.")),
			"depth": float(debug.get("depth_offset", 0.0)),
			"rotation": float(debug.get("yaw_degrees", 0.0)),
			"mana_cost": int(part.get("mana_cost", 0)),
			"draft_count": manager.draft_parts.size(),
			"variant_count": PartCatalog.get_unlocked_part_ids().size(),
		}
	var build_id: String = BuildCatalog.get_selected_build_id()
	var build: Dictionary = BuildCatalog.get_definition(build_id)
	return {
		"session_active": manager.mode == ArtificerConstructionManager.MODE_DEPLOY,
		"eyebrow": "DEPLOY CONTRAPTION",
		"title": str(build.get("icon", "⌬")) + "  " + _build_name(build_id),
		"valid": bool(debug.get("placement_valid", false)),
		"reason": str(debug.get("invalid_reason", "That contraption cannot fit there.")),
		"depth": float(debug.get("depth_offset", 0.0)),
		"rotation": float(debug.get("yaw_degrees", 0.0)),
		"mana_cost": int(build.get("mana_cost", 0)),
		"active_count": manager.get_active_count(),
		"active_limit": manager.maximum_active_contraptions,
		"variant_count": BuildCatalog.get_saved_build_ids().size(),
	}


func adjust_shared_placement_depth(
	placement_id: String,
	direction: int
) -> Dictionary:
	if not _shared_session_matches(placement_id):
		return {"ok": false, "error": "Artificer placement is not active."}
	manager.adjust_depth(direction)
	return {"ok": true}


func rotate_shared_placement(
	placement_id: String,
	direction: int
) -> Dictionary:
	if not _shared_session_matches(placement_id):
		return {"ok": false, "error": "Artificer placement is not active."}
	manager.rotate_preview(direction)
	return {"ok": true}


func cycle_shared_placement_variant(
	placement_id: String,
	direction: int
) -> Dictionary:
	if not _shared_session_matches(placement_id):
		return {"ok": false, "error": "Artificer placement is not active."}
	if placement_id == ASSEMBLY_PLACEMENT_ID:
		var selected_part: String = manager.cycle_part(direction)
		if selected_part == "":
			return {"ok": false, "error": "No alternate engineering part is available."}
		manager.keyboard_controls_enabled = false
		return {
			"ok": true,
			"message": "Prepared: " + _part_name(selected_part) + ".",
		}
	var builds: Array[String] = BuildCatalog.get_saved_build_ids()
	if builds.size() <= 1:
		return {"ok": false, "error": "No alternate contraption is available."}
	var index: int = builds.find(BuildCatalog.get_selected_build_id())
	index = posmod((0 if index < 0 else index) + signi(direction), builds.size())
	var build_id: String = builds[index]
	if not BuildCatalog.select_build(build_id):
		return {"ok": false, "error": "That contraption could not be prepared."}
	manager.selected_deploy_build_id = build_id
	manager.call("_rebuild_preview")
	manager.call("_update_target_from_camera")
	manager.call("_update_preview")
	manager.keyboard_controls_enabled = false
	return {
		"ok": true,
		"message": "Prepared: " + _build_name(build_id) + ".",
	}


func confirm_shared_placement(placement_id: String) -> Dictionary:
	if not _shared_session_matches(placement_id):
		return {"ok": false, "error": "Artificer placement is not active."}
	if placement_id == ASSEMBLY_PLACEMENT_ID:
		var part_id: String = PartCatalog.get_selected_part_id()
		var placed_part: Node = manager.confirm_placement()
		if placed_part == null:
			return {
				"ok": false,
				"error": manager.invalid_reason if manager.invalid_reason != "" else "That part cannot attach there.",
			}
		return {
			"ok": true,
			"keep_active": true,
			"message": _part_name(part_id) + " attached.",
			"part": placed_part,
		}
	var build_id: String = BuildCatalog.get_selected_build_id()
	var contraption: Node = manager.confirm_placement()
	if contraption == null:
		return {
			"ok": false,
			"error": manager.invalid_reason if manager.invalid_reason != "" else "That contraption cannot fit there.",
		}
	shared_session_id = ""
	_restore_manager_controls()
	return {
		"ok": true,
		"message": _build_name(build_id) + " deployed.",
		"contraption": contraption,
	}


func confirm_shared_placement_at(
	placement_id: String,
	world_position: Vector3,
	yaw_degrees: float = 0.0
) -> Dictionary:
	if not _shared_session_matches(placement_id):
		return {"ok": false, "error": "Artificer placement is not active."}
	if placement_id == ASSEMBLY_PLACEMENT_ID:
		var part_id: String = PartCatalog.get_selected_part_id()
		var placed_part: Node3D = manager.place_prepared_part_at(
			world_position,
			yaw_degrees,
			false
		)
		if placed_part == null:
			return {
				"ok": false,
				"error": manager.invalid_reason if manager.invalid_reason != "" else "That part cannot attach there.",
			}
		return {
			"ok": true,
			"keep_active": true,
			"message": _part_name(part_id) + " attached.",
			"part": placed_part,
		}
	var build_id: String = BuildCatalog.get_selected_build_id()
	manager.selected_deploy_build_id = build_id
	var contraption: ArtificerContraptionInstance = manager.deploy_selected_at(
		world_position,
		yaw_degrees,
		false,
		false
	)
	if contraption == null:
		return {
			"ok": false,
			"error": manager.invalid_reason if manager.invalid_reason != "" else "That contraption cannot fit there.",
		}
	manager.cancel_mode()
	shared_session_id = ""
	_restore_manager_controls()
	return {
		"ok": true,
		"message": _build_name(build_id) + " deployed.",
		"contraption": contraption,
	}


func cancel_shared_placement(placement_id: String) -> void:
	if placement_id not in [ASSEMBLY_PLACEMENT_ID, DEPLOY_PLACEMENT_ID]:
		return
	if manager != null and manager.mode != ArtificerConstructionManager.MODE_NONE:
		manager.cancel_mode()
	shared_session_id = ""
	_restore_manager_controls()


func get_ability_context_status() -> Dictionary:
	var resolved_manager: ArtificerConstructionManager = get_manager()
	if resolved_manager == null:
		return {"active": false}
	var draft_count: int = resolved_manager.draft_parts.size()
	var active_count: int = resolved_manager.get_active_count()
	if (
		resolved_manager.mode == ArtificerConstructionManager.MODE_NONE
		and draft_count <= 0
		and active_count <= 0
	):
		return {"active": false}
	var state_parts: Array[String] = []
	if shared_session_id == ASSEMBLY_PLACEMENT_ID:
		state_parts.append("Shared assembly active")
	elif shared_session_id == DEPLOY_PLACEMENT_ID:
		state_parts.append("Shared deployment active")
	if draft_count > 0:
		state_parts.append(str(draft_count) + " draft parts")
	if active_count > 0:
		state_parts.append(str(active_count) + " contraptions active")
	return {
		"active": true,
		"title": "Artificer",
		"state": " • ".join(state_parts),
		"hint": "Select Assembly or Deploy and press Cast to manage",
	}


func begin_deploy_blueprint(build_id: String) -> bool:
	manager = _ensure_manager()
	if manager == null or not BuildCatalog.select_build(build_id):
		return false
	return manager.begin_deploy(build_id)


func prepare_part(part_id: String) -> bool:
	return PartCatalog.select_part(part_id)


func prepare_blueprint(build_id: String) -> bool:
	return BuildCatalog.select_build(build_id)


func get_manager() -> ArtificerConstructionManager:
	if manager == null or not is_instance_valid(manager):
		manager = _ensure_manager()
	return manager


func _ensure_manager() -> ArtificerConstructionManager:
	if actor == null or not is_instance_valid(actor):
		return null
	var existing: Node = actor.get_node_or_null("ArtificerConstructionManager")
	if existing is ArtificerConstructionManager:
		var resolved := existing as ArtificerConstructionManager
		resolved.bind_actor(actor)
		return resolved
	var created := ManagerScript.new() as ArtificerConstructionManagerSafe
	created.name = "ArtificerConstructionManager"
	actor.add_child(created)
	created.bind_actor(actor)
	return created


func _shared_session_matches(placement_id: String) -> bool:
	if manager == null or shared_session_id != placement_id:
		return false
	if placement_id == ASSEMBLY_PLACEMENT_ID:
		return manager.mode == ArtificerConstructionManager.MODE_ASSEMBLY
	if placement_id == DEPLOY_PLACEMENT_ID:
		return manager.mode == ArtificerConstructionManager.MODE_DEPLOY
	return false


func _restore_manager_controls() -> void:
	if manager != null and is_instance_valid(manager):
		manager.keyboard_controls_enabled = previous_keyboard_controls


func _cycle_part(direction: int) -> Dictionary:
	var selected_id: String = PartCatalog.cycle_selected_part(direction)
	if selected_id == "":
		return {"ok": false, "error": "No engineering parts are unlocked."}
	return {
		"ok": true,
		"keep_open": true,
		"selected_id": "place_part",
		"message": "Prepared: " + _part_name(selected_id) + ".",
	}


func _cycle_build(direction: int) -> Dictionary:
	var builds: Array[String] = BuildCatalog.get_saved_build_ids()
	if builds.is_empty():
		return {"ok": false, "error": "No contraption blueprints are saved."}
	var index: int = builds.find(BuildCatalog.get_selected_build_id())
	if index < 0:
		index = 0
	else:
		index = posmod(index + signi(direction), builds.size())
	var build_id: String = builds[index]
	if not BuildCatalog.select_build(build_id):
		return {"ok": false, "error": "That contraption could not be prepared."}
	if manager != null:
		manager.selected_deploy_build_id = build_id
	return {
		"ok": true,
		"keep_open": true,
		"selected_id": "deploy_selected",
		"message": "Prepared: " + _build_name(build_id) + ".",
	}


func _part_name(part_id: String) -> String:
	return str(PartCatalog.get_definition(part_id).get(
		"display_name",
		part_id.capitalize()
	))


func _build_name(build_id: String) -> String:
	return str(BuildCatalog.get_definition(build_id).get(
		"display_name",
		build_id.capitalize()
	))


func _show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)
	else:
		print(message)


func get_debug_data() -> Dictionary:
	var resolved_manager: ArtificerConstructionManager = get_manager()
	return {
		"assembly_spell_id": assembly_spell_id,
		"deploy_spell_id": deploy_spell_id,
		"manager_ready": resolved_manager != null,
		"selected_part": PartCatalog.get_selected_part_id(),
		"selected_blueprint": BuildCatalog.get_selected_build_id(),
		"shared_session_id": shared_session_id,
		"assembly_context_available": not PartCatalog.get_unlocked_part_ids().is_empty(),
		"deploy_context_available": not BuildCatalog.get_saved_build_ids().is_empty(),
		"manager": resolved_manager.get_debug_data() if resolved_manager != null else {},
	}
