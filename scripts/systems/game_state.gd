extends Node

signal objective_changed(new_objective: String)
signal flag_changed(flag_name: String, value: bool)
signal stat_changed(stat_name: String, value: int)
signal resource_depleted(resource_name: String, amount: int)
signal player_defeated
signal save_completed(save_data: Dictionary)
signal save_loaded(save_data: Dictionary)
signal key_item_changed(item_id: String, value: bool)
signal unlock_changed(unlock_id: String, value: bool)

const StatCatalogScript = preload("res://scripts/systems/stat_catalog.gd")
const UnlockCatalogScript = preload("res://scripts/systems/unlock_catalog.gd")
const SAVE_VERSION: int = 4
const SAVE_SLOT_PATH: String = "user://goh_save_slot_1.json"
const ARMOR_TRIAL_BLESSING_ID: String = "armor_trial_blessing"
const GUARD_STAT: String = "guard"
const MAX_GUARD_STAT: String = "max_guard"

const KEY_ITEM_DEFS: Dictionary = {
	"church_trial_sigil": {
		"id": "church_trial_sigil",
		"name": "Church Trial Sigil",
		"kind": "Trial Relic",
		"description": "Proof that Grace survived the Church's trial and defeated the Animated Armor.",
		"source": "First Church Trial",
	},
}

var current_objective: String = "Look around."
var stats: Dictionary = StatCatalogScript.get_default_stats()
var last_save_data: Dictionary = {}
var key_items: Dictionary = {}
var unlocks: Dictionary = {}

var story_flags: Dictionary = {
	"inspected_stone": false,
	"inspected_sign": false,
	"inspected_flowers": false,
	"met_church_finder": false,
	"chose_play_prologue": false,
	"chose_skip_prologue": false,
}

var player_invulnerable: bool = false
var player_invulnerability_timer: float = 0.0


func _process(delta: float) -> void:
	update_player_invulnerability(delta)


func set_objective(new_objective: String) -> void:
	current_objective = new_objective
	objective_changed.emit(current_objective)


func set_flag(flag_name: String, value: bool = true) -> void:
	story_flags[flag_name] = value
	flag_changed.emit(flag_name, value)


func get_flag(flag_name: String) -> bool:
	if not story_flags.has(flag_name):
		return false

	return story_flags[flag_name]


func set_stat(stat_name: String, value: int) -> void:
	stats[stat_name] = value
	stat_changed.emit(stat_name, value)


func get_stat(stat_name: String) -> int:
	if not stats.has(stat_name):
		return 0

	return int(stats[stat_name])


func add_stat(stat_name: String, amount: int) -> void:
	var current_value: int = get_stat(stat_name)
	set_stat(stat_name, current_value + amount)


func get_stat_snapshot() -> Dictionary:
	return stats.duplicate(true)


func get_story_flags_snapshot() -> Dictionary:
	return story_flags.duplicate(true)


func grant_unlock(unlock_id: String, unlock_data: Dictionary = {}) -> void:
	if unlock_id == "":
		return

	var row: Dictionary = UnlockCatalogScript.normalize_unlock(unlock_id, unlock_data)
	unlocks[unlock_id] = row
	unlock_changed.emit(unlock_id, true)


func revoke_unlock(unlock_id: String) -> void:
	if not unlocks.has(unlock_id):
		return

	unlocks.erase(unlock_id)
	unlock_changed.emit(unlock_id, false)


func has_unlock(unlock_id: String) -> bool:
	return unlocks.has(unlock_id)


func get_unlock_snapshot() -> Dictionary:
	return unlocks.duplicate(true)


func get_unlock_rows() -> Array:
	return UnlockCatalogScript.get_rows(get_unlock_snapshot())


func get_unlock_rows_by_type(unlock_type: String) -> Array:
	return UnlockCatalogScript.get_rows_by_type(get_unlock_snapshot(), unlock_type)


func get_modifier_unlock_rows() -> Array:
	return get_unlock_rows_by_type(UnlockCatalogScript.TYPE_MODIFIER)


func get_permission_unlock_rows() -> Array:
	return get_unlock_rows_by_type(UnlockCatalogScript.TYPE_PERMISSION)


func get_unlock_type_counts() -> Dictionary:
	return UnlockCatalogScript.get_type_counts(get_unlock_snapshot())


func get_active_modifier_ids() -> Array[String]:
	var modifier_ids: Array[String] = []

	for row_variant in get_modifier_unlock_rows():
		if not (row_variant is Dictionary):
			continue

		var row: Dictionary = row_variant as Dictionary
		modifier_ids.append(str(row.get("id", "")))

	return modifier_ids


func add_key_item(item_id: String, item_data: Dictionary = {}) -> void:
	if item_id == "":
		return

	var row: Dictionary = get_key_item_definition(item_id).duplicate(true)

	for key in item_data.keys():
		row[str(key)] = item_data[key]

	row["id"] = item_id
	row["acquired"] = true
	key_items[item_id] = row
	grant_unlock(item_id, {
		"type": UnlockCatalogScript.TYPE_KEY_ITEM,
		"display_name": str(row.get("name", item_id.capitalize())),
		"description": str(row.get("description", "A key item Grace carries.")),
		"source": str(row.get("source", "Unknown")),
		"menu_category": "Key Items",
		"related_key_item": item_id,
	})
	key_item_changed.emit(item_id, true)


func remove_key_item(item_id: String) -> void:
	if not key_items.has(item_id):
		return

	key_items.erase(item_id)
	revoke_unlock(item_id)
	key_item_changed.emit(item_id, false)


func has_key_item(item_id: String) -> bool:
	if key_items.has(item_id):
		return true

	if has_unlock(item_id):
		var unlock_definition: Dictionary = UnlockCatalogScript.get_definition(item_id)
		if str(unlock_definition.get("type", "")) == UnlockCatalogScript.TYPE_KEY_ITEM:
			return true

	# Backward compatibility for saves from the reward-altar pass before dedicated key items existed.
	if item_id == "church_trial_sigil" and get_flag("claimed_church_trial_sigil"):
		return true

	return false


func get_key_item_snapshot() -> Dictionary:
	var snapshot: Dictionary = key_items.duplicate(true)

	for unlock_id in unlocks.keys():
		if snapshot.has(unlock_id):
			continue

		var unlock_definition: Dictionary = UnlockCatalogScript.get_definition(str(unlock_id))
		if str(unlock_definition.get("type", "")) != UnlockCatalogScript.TYPE_KEY_ITEM:
			continue

		snapshot[unlock_id] = get_key_item_definition(str(unlock_id))
		snapshot[unlock_id]["acquired"] = true

	if get_flag("claimed_church_trial_sigil") and not snapshot.has("church_trial_sigil"):
		snapshot["church_trial_sigil"] = get_key_item_definition("church_trial_sigil")
		snapshot["church_trial_sigil"]["acquired"] = true

	return snapshot


func get_key_item_rows() -> Array:
	var rows: Array = []
	var snapshot: Dictionary = get_key_item_snapshot()

	for item_id in snapshot.keys():
		if not (snapshot[item_id] is Dictionary):
			continue

		var item: Dictionary = (snapshot[item_id] as Dictionary).duplicate(true)
		item["id"] = str(item.get("id", item_id))
		item["name"] = str(item.get("name", item["id"]))
		item["kind"] = str(item.get("kind", "Key Item"))
		item["description"] = str(item.get("description", "A key item Grace carries."))
		item["source"] = str(item.get("source", "Unknown"))
		rows.append(item)

	rows.sort_custom(sort_key_item_rows)
	return rows


func sort_key_item_rows(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("name", "")) < str(b.get("name", ""))


func get_key_item_definition(item_id: String) -> Dictionary:
	if KEY_ITEM_DEFS.has(item_id):
		return (KEY_ITEM_DEFS[item_id] as Dictionary).duplicate(true)

	var unlock_definition: Dictionary = UnlockCatalogScript.get_definition(item_id)
	if str(unlock_definition.get("type", "")) == UnlockCatalogScript.TYPE_KEY_ITEM:
		return {
			"id": item_id,
			"name": str(unlock_definition.get("display_name", item_id.capitalize())),
			"kind": str(unlock_definition.get("menu_category", "Key Item")),
			"description": str(unlock_definition.get("description", "A key item Grace carries.")),
			"source": str(unlock_definition.get("source", "Unknown")),
		}

	return {
		"id": item_id,
		"name": item_id.capitalize(),
		"kind": "Key Item",
		"description": "A key item Grace carries.",
		"source": "Unknown",
	}


func get_stat_menu_sections() -> Array[Dictionary]:
	return StatCatalogScript.get_menu_sections(stats)


func get_base_stat_sections() -> Array[Dictionary]:
	return StatCatalogScript.get_base_stat_sections(stats)


func get_elemental_affinity_sections() -> Array[Dictionary]:
	return StatCatalogScript.get_elemental_affinity_sections(stats)


func get_base_stat_ids() -> Array[String]:
	return StatCatalogScript.get_base_stat_ids()


func reset_stats_to_defaults(should_emit: bool = true) -> void:
	stats = StatCatalogScript.get_default_stats()
	stats.erase(GUARD_STAT)
	stats.erase(MAX_GUARD_STAT)

	if not should_emit:
		return

	for stat_name: String in stats.keys():
		stat_changed.emit(stat_name, int(stats[stat_name]))

	stat_changed.emit(GUARD_STAT, 0)
	stat_changed.emit(MAX_GUARD_STAT, 0)


func take_damage(amount: int) -> void:
	if player_invulnerable:
		print("Grace avoided the hit.")
		return

	if amount <= 0:
		return

	if consume_guard():
		print("Armor Trial Guard absorbs the hit.")
		show_system_message("Guard absorbs the hit.")
		return

	var current_health: int = get_stat("health")
	var max_health: int = get_stat("max_health")
	var new_health: int = clamp(current_health - amount, 0, max_health)

	print("Grace takes damage: ", amount)
	print("Health: ", current_health, " -> ", new_health)

	set_stat("health", new_health)

	if new_health <= 0:
		print("Grace defeated signal emitted.")
		player_defeated.emit()


func heal(amount: int) -> void:
	var current_health: int = get_stat("health")
	var max_health: int = get_stat("max_health")
	var new_health: int = clamp(current_health + amount, 0, max_health)

	set_stat("health", new_health)


func spend_stamina(amount: int) -> bool:
	if amount <= 0:
		return true

	var current_stamina: int = get_stat("stamina")

	if current_stamina < amount:
		return false

	set_stat("stamina", current_stamina - amount)
	resource_depleted.emit("stamina", amount)
	return true


func restore_stamina(amount: int) -> void:
	var current_stamina: int = get_stat("stamina")
	var max_stamina: int = get_stat("max_stamina")
	var new_stamina: int = clamp(current_stamina + amount, 0, max_stamina)

	set_stat("stamina", new_stamina)


func spend_mana(amount: int) -> bool:
	if amount <= 0:
		return true

	var current_mana: int = get_stat("mana")

	if current_mana < amount:
		return false

	set_stat("mana", current_mana - amount)
	resource_depleted.emit("mana", amount)
	return true


func restore_mana(amount: int) -> void:
	var current_mana: int = get_stat("mana")
	var max_mana: int = get_stat("max_mana")
	var new_mana: int = clamp(current_mana + amount, 0, max_mana)

	set_stat("mana", new_mana)


func damage_stance(amount: int) -> void:
	if amount <= 0:
		return

	var current_stance: int = get_stat("stance")
	var new_stance: int = clamp(current_stance - amount, 0, get_stat("max_stance"))
	var depleted_amount: int = current_stance - new_stance

	set_stat("stance", new_stance)

	if depleted_amount > 0:
		resource_depleted.emit("stance", depleted_amount)


func restore_stance(amount: int) -> void:
	var current_stance: int = get_stat("stance")
	var max_stance: int = get_stat("max_stance")
	var new_stance: int = clamp(current_stance + amount, 0, max_stance)

	set_stat("stance", new_stance)


func restore_rest_resources() -> void:
	set_stat("health", get_stat("max_health"))
	set_stat("mana", get_stat("max_mana"))
	set_stat("stamina", get_stat("max_stamina"))
	set_stat("stance", get_stat("max_stance"))


func apply_rest_unlocks() -> Array[String]:
	var messages: Array[String] = []

	if has_unlock(ARMOR_TRIAL_BLESSING_ID):
		if grant_guard(1, 1):
			messages.append("Armor Trial Blessing grants 1 Guard.")
		else:
			messages.append("Armor Trial Blessing keeps Guard ready.")

	return messages


func grant_guard(amount: int = 1, max_guard: int = 1) -> bool:
	if amount <= 0:
		return false

	var current_max_guard: int = max(max_guard, get_stat(MAX_GUARD_STAT))
	if current_max_guard <= 0:
		current_max_guard = 1

	set_stat(MAX_GUARD_STAT, current_max_guard)

	var current_guard: int = get_stat(GUARD_STAT)
	var new_guard: int = clamp(current_guard + amount, 0, current_max_guard)

	if new_guard == current_guard:
		return false

	set_stat(GUARD_STAT, new_guard)
	return true


func consume_guard(amount: int = 1) -> bool:
	var current_guard: int = get_stat(GUARD_STAT)

	if amount <= 0 or current_guard <= 0:
		return false

	set_stat(GUARD_STAT, max(current_guard - amount, 0))
	return true


func get_guard_label() -> String:
	return str(get_stat(GUARD_STAT)) + " / " + str(get_stat(MAX_GUARD_STAT))


func reset_run() -> void:
	current_objective = "Look around."
	reset_stats_to_defaults(false)
	key_items.clear()
	unlocks.clear()

	for flag_name: String in story_flags.keys():
		story_flags[flag_name] = false

	objective_changed.emit(current_objective)

	for stat_name: String in stats.keys():
		stat_changed.emit(stat_name, int(stats[stat_name]))

	stat_changed.emit(GUARD_STAT, 0)
	stat_changed.emit(MAX_GUARD_STAT, 0)

	for item_id in KEY_ITEM_DEFS.keys():
		key_item_changed.emit(str(item_id), false)

	for unlock_id in UnlockCatalogScript.UNLOCK_DEFS.keys():
		unlock_changed.emit(str(unlock_id), false)


func begin_player_invulnerability(duration: float) -> void:
	if duration <= 0.0:
		return

	player_invulnerable = true
	player_invulnerability_timer = max(player_invulnerability_timer, duration)


func update_player_invulnerability(delta: float) -> void:
	if not player_invulnerable:
		return

	player_invulnerability_timer -= delta

	if player_invulnerability_timer <= 0.0:
		player_invulnerability_timer = 0.0
		player_invulnerable = false


func is_player_invulnerable() -> bool:
	return player_invulnerable


func save_at_bed(bed_id: String, bed_name: String, bed_position: Vector3) -> Dictionary:
	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"bed_id": bed_id,
		"bed_name": bed_name,
		"scene_path": get_current_scene_path(),
		"bed_position": vector3_to_save_dict(bed_position),
		"stats": get_stat_snapshot(),
		"story_flags": get_story_flags_snapshot(),
		"key_items": get_key_item_snapshot(),
		"unlocks": get_unlock_snapshot(),
		"objective": current_objective,
		"saved_at": Time.get_datetime_string_from_system(false, true),
	}

	var write_result: Dictionary = write_save_data(save_data)

	if bool(write_result.get("ok", false)):
		last_save_data = save_data.duplicate(true)
		save_completed.emit(last_save_data)

	return write_result


func write_save_data(save_data: Dictionary) -> Dictionary:
	var save_file: FileAccess = FileAccess.open(SAVE_SLOT_PATH, FileAccess.WRITE)

	if save_file == null:
		return {
			"ok": false,
			"message": "Save failed: " + str(FileAccess.get_open_error()),
		}

	save_file.store_string(JSON.stringify(save_data, "\t"))
	save_file.close()

	return {
		"ok": true,
		"message": "Saved at " + str(save_data.get("bed_name", "Save Bed")) + ".",
		"path": SAVE_SLOT_PATH,
	}


func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_SLOT_PATH)


func load_save_data() -> Dictionary:
	if not has_save_file():
		return {}

	var save_text: String = FileAccess.get_file_as_string(SAVE_SLOT_PATH)
	var parsed_save = JSON.parse_string(save_text)

	if parsed_save is Dictionary:
		var save_data: Dictionary = parsed_save as Dictionary
		last_save_data = save_data.duplicate(true)
		return save_data

	return {}


func apply_save_for_current_scene() -> bool:
	var save_data: Dictionary = load_save_data()

	if save_data.is_empty():
		return false

	var saved_scene_path: String = str(save_data.get("scene_path", ""))
	var current_scene_path: String = get_current_scene_path()

	if saved_scene_path != "" and current_scene_path != "" and saved_scene_path != current_scene_path:
		return false

	return apply_save_data(save_data)


func apply_save_data(save_data: Dictionary) -> bool:
	if save_data.is_empty():
		return false

	apply_saved_stats(save_data)
	apply_saved_flags(save_data)
	apply_saved_unlocks(save_data)
	apply_saved_key_items(save_data)
	sync_legacy_progression_state()

	if save_data.has("objective"):
		set_objective(str(save_data["objective"]))

	if save_data.has("bed_position") and save_data["bed_position"] is Dictionary:
		var position_data: Dictionary = save_data["bed_position"] as Dictionary
		move_player_to_save_position(vector3_from_save_dict(position_data))

	last_save_data = save_data.duplicate(true)
	save_loaded.emit(last_save_data)
	return true


func apply_saved_stats(save_data: Dictionary) -> void:
	if not save_data.has("stats"):
		return

	if not save_data["stats"] is Dictionary:
		return

	var saved_stats: Dictionary = save_data["stats"] as Dictionary
	stats = StatCatalogScript.get_default_stats()

	for stat_name in saved_stats.keys():
		stats[str(stat_name)] = int(saved_stats[stat_name])

	for stat_name: String in stats.keys():
		stat_changed.emit(stat_name, int(stats[stat_name]))


func apply_saved_flags(save_data: Dictionary) -> void:
	if not save_data.has("story_flags"):
		return

	if not save_data["story_flags"] is Dictionary:
		return

	var saved_flags: Dictionary = save_data["story_flags"] as Dictionary

	for flag_name in saved_flags.keys():
		story_flags[str(flag_name)] = bool(saved_flags[flag_name])
		flag_changed.emit(str(flag_name), bool(saved_flags[flag_name]))


func apply_saved_unlocks(save_data: Dictionary) -> void:
	unlocks.clear()

	if not save_data.has("unlocks"):
		return

	if not save_data["unlocks"] is Dictionary:
		return

	var saved_unlocks: Dictionary = save_data["unlocks"] as Dictionary

	for unlock_id in saved_unlocks.keys():
		if saved_unlocks[unlock_id] is Dictionary:
			var unlock_data: Dictionary = (saved_unlocks[unlock_id] as Dictionary).duplicate(true)
			grant_unlock(str(unlock_id), unlock_data)
		elif bool(saved_unlocks[unlock_id]):
			grant_unlock(str(unlock_id))


func apply_saved_key_items(save_data: Dictionary) -> void:
	key_items.clear()

	if save_data.has("key_items") and save_data["key_items"] is Dictionary:
		var saved_key_items: Dictionary = save_data["key_items"] as Dictionary

		for item_id in saved_key_items.keys():
			if saved_key_items[item_id] is Dictionary:
				var item: Dictionary = (saved_key_items[item_id] as Dictionary).duplicate(true)
				item["id"] = str(item.get("id", item_id))
				item["acquired"] = true
				key_items[str(item_id)] = item
				grant_unlock(str(item_id), {
					"type": UnlockCatalogScript.TYPE_KEY_ITEM,
					"display_name": str(item.get("name", str(item_id).capitalize())),
					"description": str(item.get("description", "A key item Grace carries.")),
					"source": str(item.get("source", "Unknown")),
					"menu_category": "Key Items",
					"related_key_item": str(item_id),
				})

	if get_flag("claimed_church_trial_sigil") and not key_items.has("church_trial_sigil"):
		add_key_item("church_trial_sigil")

	for item_id in key_items.keys():
		key_item_changed.emit(str(item_id), true)


func sync_legacy_progression_state() -> void:
	if get_flag("claimed_church_trial_sigil") or has_key_item("church_trial_sigil"):
		grant_unlock("church_trial_sigil")
		grant_unlock("church_trial_doors")


func show_system_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)


func move_player_to_save_position(save_position: Vector3) -> void:
	var player: Node = get_tree().get_first_node_in_group("player")

	if not player is Node3D:
		return

	var player_3d: Node3D = player as Node3D
	player_3d.global_position = save_position

	if player is CharacterBody3D:
		var character_body: CharacterBody3D = player as CharacterBody3D
		character_body.velocity = Vector3.ZERO

	if "is_defeated" in player:
		player.set("is_defeated", false)


func get_current_scene_path() -> String:
	var current_scene: Node = get_tree().current_scene

	if current_scene == null:
		return ""

	return current_scene.scene_file_path


func vector3_to_save_dict(value: Vector3) -> Dictionary:
	return {
		"x": value.x,
		"y": value.y,
		"z": value.z,
	}


func vector3_from_save_dict(value: Dictionary) -> Vector3:
	return Vector3(
		float(value.get("x", 0.0)),
		float(value.get("y", 0.0)),
		float(value.get("z", 0.0))
	)
