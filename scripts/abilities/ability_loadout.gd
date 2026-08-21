extends Resource
class_name AbilityLoadout

signal equipped_ability_changed(
	slot_index: int,
	ability: AbilityDefinition
)

const DEFAULT_ELEMENT_ORDER: Array[String] = [
	"water",
	"earth",
	"fire",
	"air",
	"ice",
	"metal",
	"lightning",
	"poison",
	"life",
	"death",
	"body",
	"soul",
	"dreams",
	"sound",
	"space",
	"time",
]

@export var learned_abilities: Array[AbilityDefinition] = []
@export var equipped_abilities: Array[AbilityDefinition] = []

# Keyboard 1-9 and 0 map to ten combat-ready spell slots. The learned library
# may remain much larger, while controller input cycles this same ten-slot belt.
@export var quick_slot_count: int = 10

@export_group("Authored Spell Library")
# Keep this opt-in so focused labs and tests can continue using tiny deterministic
# loadouts. The production Grace caster enables it before reading the Focus library.
@export var auto_discover_authored_abilities: bool = false
@export_dir var authored_ability_root: String = "res://data/abilities"

var _authored_library_cache: Array[AbilityDefinition] = []
var _authored_library_scanned: bool = false
var _authored_library_scan_count: int = 0


func get_equipped_ability(index: int) -> AbilityDefinition:
	if index < 0 or index >= equipped_abilities.size():
		return null

	return equipped_abilities[index]


func get_equipped_ability_count() -> int:
	return equipped_abilities.size()


func get_quick_slot_count() -> int:
	return 10


func get_equipped_ability_names() -> Array[String]:
	var names: Array[String] = []

	for ability: AbilityDefinition in equipped_abilities:
		if ability == null:
			names.append("Empty Slot")
		else:
			names.append(ability.display_name)

	return names


func get_equipped_slot_rows(current_ability_index: int = -1) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var slot_count: int = get_quick_slot_count()

	for slot_index: int in range(slot_count):
		var ability: AbilityDefinition = get_equipped_ability(slot_index)
		rows.append({
			"slot": slot_index,
			"ability": ability,
			"is_empty": ability == null,
			"is_current": slot_index == current_ability_index,
		})

	return rows


func get_learned_abilities() -> Array[AbilityDefinition]:
	var abilities: Array[AbilityDefinition] = []

	for ability: AbilityDefinition in learned_abilities:
		append_unique_ability(abilities, ability)

	if auto_discover_authored_abilities:
		for ability: AbilityDefinition in get_auto_discovered_abilities():
			append_unique_ability(abilities, ability)

	# Safety fallback for older resources or testing files that only filled equipped.
	if abilities.size() <= 0:
		for ability: AbilityDefinition in equipped_abilities:
			append_unique_ability(abilities, ability)

	return abilities


func get_auto_discovered_abilities() -> Array[AbilityDefinition]:
	if _authored_library_scanned:
		return _authored_library_cache.duplicate()

	_authored_library_scanned = true
	_authored_library_scan_count += 1
	_authored_library_cache.clear()
	var root: String = authored_ability_root.strip_edges()
	if root == "":
		return []

	var resource_paths: Array[String] = []
	_collect_ability_resource_paths(root, resource_paths)
	resource_paths.sort()
	for resource_path: String in resource_paths:
		var resource: Resource = ResourceLoader.load(resource_path)
		if resource is AbilityDefinition:
			append_unique_ability(
				_authored_library_cache,
				resource as AbilityDefinition
			)
	return _authored_library_cache.duplicate()


func invalidate_authored_library_cache() -> void:
	_authored_library_scanned = false
	_authored_library_cache.clear()


func _collect_ability_resource_paths(
	root_path: String,
	result: Array[String]
) -> void:
	var directory := DirAccess.open(root_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var child_path: String = root_path.path_join(entry)
			if directory.current_is_dir():
				_collect_ability_resource_paths(child_path, result)
			elif entry.get_extension().to_lower() in ["tres", "res"]:
				result.append(child_path)
		entry = directory.get_next()
	directory.list_dir_end()


func get_learned_spell_sections() -> Array[Dictionary]:
	var sections: Array[Dictionary] = []
	var learned: Array[AbilityDefinition] = get_learned_abilities()

	for element: String in DEFAULT_ELEMENT_ORDER:
		var element_spells: Array[AbilityDefinition] = []

		for ability: AbilityDefinition in learned:
			if ability == null:
				continue

			if ability.element == element:
				element_spells.append(ability)

		sections.append({
			"element": element,
			"title": element.capitalize(),
			"spells": element_spells,
		})

	return sections


func get_unassigned_learned_abilities() -> Array[AbilityDefinition]:
	var unassigned: Array[AbilityDefinition] = []
	var equipped_ids: Dictionary = {}
	for ability: AbilityDefinition in equipped_abilities:
		if ability != null:
			equipped_ids[ability.get_spell_id()] = true

	for ability: AbilityDefinition in get_learned_abilities():
		if ability == null:
			continue

		if not equipped_ids.has(ability.get_spell_id()):
			unassigned.append(ability)

	return unassigned


func equip_ability(slot_index: int, ability: AbilityDefinition) -> void:
	if slot_index < 0:
		return

	while equipped_abilities.size() <= slot_index:
		equipped_abilities.append(null)

	equipped_abilities[slot_index] = ability
	_sync_persistent_quick_slot(slot_index, ability)
	equipped_ability_changed.emit(slot_index, ability)


# The full equipment menu edits AbilityLoadout directly, while the permanent
# ten-slot belt persists spell IDs in GameState. Keeping the two writes atomic
# prevents a newly assigned spell from appearing as an invalid gray slot whose
# historical spell ID no longer exists in the runtime loadout.
func _sync_persistent_quick_slot(
	slot_index: int,
	ability: AbilityDefinition
) -> void:
	if slot_index < 0 or slot_index >= get_quick_slot_count():
		return
	if not GameState.has_method("set_quick_spell_slot"):
		return
	var spell_id: String = (
		ability.get_spell_id()
		if ability != null
		else ""
	)
	GameState.call(
		"set_quick_spell_slot",
		get_quickbar_loadout_id(),
		slot_index,
		spell_id
	)


func get_quickbar_loadout_id() -> String:
	if resource_path != "":
		return resource_path.get_file().get_basename()
	return "runtime_" + str(get_instance_id())


func learn_ability(ability: AbilityDefinition) -> void:
	if ability == null:
		return

	if knows_ability(ability):
		return

	learned_abilities.append(ability)


func knows_ability(ability: AbilityDefinition) -> bool:
	if ability == null:
		return false
	var spell_id: String = ability.get_spell_id()
	for known: AbilityDefinition in get_learned_abilities():
		if known != null and known.get_spell_id() == spell_id:
			return true
	return false


func append_unique_ability(target: Array[AbilityDefinition], ability: AbilityDefinition) -> void:
	if ability == null:
		return
	var incoming_id: String = ability.get_spell_id()
	for existing: AbilityDefinition in target:
		if existing == ability:
			return
		if (
			existing != null
			and incoming_id != ""
			and existing.get_spell_id() == incoming_id
		):
			return

	target.append(ability)


func get_library_debug_data() -> Dictionary:
	return {
		"auto_discover": auto_discover_authored_abilities,
		"root": authored_ability_root,
		"scanned": _authored_library_scanned,
		"scan_count": _authored_library_scan_count,
		"discovered_count": _authored_library_cache.size(),
		"learned_count": get_learned_abilities().size(),
		"equipped_count": equipped_abilities.size(),
	}
