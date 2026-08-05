extends Resource
class_name AdventureChunkDefinition

enum ChunkCategory {
	STORY,
	EXPLORATION,
	COMBAT,
	PUZZLE,
	TRAVERSAL,
	SERVICE,
	OPTIONAL,
}

enum CompletionPolicy {
	MANUAL,
	ALL_REQUIREMENTS,
	ANY_REQUIREMENT,
}

@export_group("Identity")
@export var chunk_id: String = "adventure_chunk"
@export var display_name: String = "Adventure Chunk"
@export var category: ChunkCategory = ChunkCategory.EXPLORATION
@export_multiline var summary: String = "A self-contained piece of gameplay."

@export_group("Graph")
@export var required_chunk_ids: Array[String] = []
@export var optional: bool = false
@export var auto_activate_when_available: bool = true
@export var allow_replay: bool = false

@export_group("Completion")
@export var completion_policy: CompletionPolicy = CompletionPolicy.ALL_REQUIREMENTS
@export var completion_flag: String = ""
@export_range(0, 99, 1) var reward_mana: int = 0

@export_group("Presentation")
@export var objective_on_available: String = ""
@export var objective_on_activate: String = ""
@export var objective_on_complete: String = ""
@export var activation_message: String = ""
@export var completion_message: String = ""

@export_group("Managed Content")
@export var hide_content_when_locked: bool = true
@export var disable_content_when_locked: bool = true
@export var keep_content_after_complete: bool = true


func get_normalized_id() -> String:
	return normalize_id(chunk_id)


func get_normalized_dependencies() -> Array[String]:
	var resolved: Array[String] = []
	for raw_id: String in required_chunk_ids:
		var normalized: String = normalize_id(raw_id)
		if normalized != "" and not resolved.has(normalized):
			resolved.append(normalized)
	return resolved


func get_completion_flag() -> String:
	var normalized_flag: String = completion_flag.to_lower().strip_edges().replace(" ", "_")
	if normalized_flag != "":
		return normalized_flag
	var normalized_id: String = get_normalized_id()
	return "adventure_chunk_" + normalized_id if normalized_id != "" else ""


func validate_definition() -> Array[String]:
	var errors: Array[String] = []
	var normalized_id: String = get_normalized_id()
	if normalized_id == "":
		errors.append("chunk_id is empty")
	if display_name.strip_edges() == "":
		errors.append(normalized_id + " has no display_name")
	for dependency_id: String in get_normalized_dependencies():
		if dependency_id == normalized_id:
			errors.append(normalized_id + " depends on itself")
	if completion_policy not in [
		CompletionPolicy.MANUAL,
		CompletionPolicy.ALL_REQUIREMENTS,
		CompletionPolicy.ANY_REQUIREMENT,
	]:
		errors.append(normalized_id + " has an invalid completion policy")
	return errors


func get_debug_summary() -> Dictionary:
	return {
		"chunk_id": get_normalized_id(),
		"display_name": display_name,
		"category": ChunkCategory.keys()[int(category)],
		"dependencies": get_normalized_dependencies(),
		"optional": optional,
		"auto_activate": auto_activate_when_available,
		"completion_policy": CompletionPolicy.keys()[int(completion_policy)],
		"completion_flag": get_completion_flag(),
		"reward_mana": reward_mana,
	}


static func normalize_id(value: String) -> String:
	return value.to_lower().strip_edges().replace(" ", "_").replace("-", "_")
