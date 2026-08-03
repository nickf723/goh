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

@export var assembly_spell_id: String = "artificer_assembly"
@export var deploy_spell_id: String = "deploy_contraption"

var actor: Node3D
var manager: ArtificerConstructionManager
var action_state: PlayerActionState


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
		"manager": (
			resolved_manager.get_debug_data()
			if resolved_manager != null
			else {}
		),
	}
