extends Node

signal objective_changed(new_objective: String)
signal flag_changed(flag_name: String, value: bool)
signal stat_changed(stat_name: String, value: int)
signal player_defeated
signal save_completed(save_data: Dictionary)
signal save_loaded(save_data: Dictionary)

const StatCatalogScript = preload("res://scripts/systems/stat_catalog.gd")
const SAVE_VERSION: int = 1
const SAVE_SLOT_PATH: String = "user://goh_save_slot_1.json"

var current_objective: String = "Look around."
var stats: Dictionary = StatCatalogScript.get_default_stats()
var last_save_data: Dictionary = {}

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

	if not should_emit:
		return

	for stat_name: String in stats.keys():
		stat_changed.emit(stat_name, int(stats[stat_name]))


func take_damage(amount: int) -> void:
	if player_invulnerable:
		print("Grace avoided the hit.")
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
	var current_stamina: int = get_stat("stamina")

	if current_stamina < amount:
		return false

	set_stat("stamina", current_stamina - amount)
	return true


func restore_stamina(amount: int) -> void:
	var current_stamina: int = get_stat("stamina")
	var max_stamina: int = get_stat("max_stamina")
	var new_stamina: int = clamp(current_stamina + amount, 0, max_stamina)

	set_stat("stamina", new_stamina)


func spend_mana(amount: int) -> bool:
	var current_mana: int = get_stat("mana")

	if current_mana < amount:
		return false

	set_stat("mana", current_mana - amount)
	return true


func restore_mana(amount: int) -> void:
	var current_mana: int = get_stat("mana")
	var max_mana: int = get_stat("max_mana")
	var new_mana: int = clamp(current_mana + amount, 0, max_mana)

	set_stat("mana", new_mana)


func damage_stance(amount: int) -> void:
	var current_stance: int = get_stat("stance")
	var new_stance: int = clamp(current_stance - amount, 0, get_stat("max_stance"))

	set_stat("stance", new_stance)


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


func reset_run() -> void:
	current_objective = "Look around."
	reset_stats_to_defaults(false)

	for flag_name: String in story_flags.keys():
		story_flags[flag_name] = false

	objective_changed.emit(current_objective)

	for stat_name: String in stats.keys():
		stat_changed.emit(stat_name, int(stats[stat_name]))


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
