extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const SpellManifest = preload(
	"res://scripts/abilities/spell_capability_manifest.gd"
)

const RESTORED_LIBRARY_SPELLS: Array[String] = [
	"echolocation",
	"resonant_pulse",
	"gust",
	"rain_weather",
	"snow_weather",
	"thunderstorm_weather",
	"flight_concentration",
]

var failures: Array[String] = []
var original_stats: Dictionary = {}
var original_quick_spell_loadouts: Dictionary = {}
var original_quick_spell_selected_slots: Dictionary = {}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	original_quick_spell_loadouts = GameState.quick_spell_loadouts.duplicate(true)
	original_quick_spell_selected_slots = (
		GameState.quick_spell_selected_slots.duplicate(true)
	)
	_prepare_stats()

	var floor: StaticBody3D = _make_floor()
	add_child(floor)
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "CompleteSpellLibraryTestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	player.add_to_group("player")
	player.add_to_group("weather_exposed")
	add_child(player)
	await _wait_frames(18)
	await get_tree().physics_frame

	var caster: Node = player.get_node_or_null("AbilityCaster")
	_expect(caster is AbilityCasterFocusLibrary, "player uses the learned-spell Focus library")
	if caster == null:
		_finish([player, floor])
		return

	var loadout_value: Variant = caster.get("loadout")
	var loadout: AbilityLoadout = (
		loadout_value as AbilityLoadout
		if loadout_value is AbilityLoadout
		else null
	)
	_expect(loadout != null, "complete library test resolves Grace's loadout")
	if loadout == null:
		_finish([player, floor])
		return

	var learned_ids: Array[String] = _get_spell_ids(loadout.get_learned_abilities())
	var equipped_ids: Array[String] = _get_spell_ids(loadout.equipped_abilities)
	var authored_abilities: Array[AbilityDefinition] = SpellManifest.scan_abilities()
	var authored_ids: Array[String] = _get_spell_ids(authored_abilities)
	_expect(
		learned_ids.size() == authored_ids.size(),
		"Grace's Focus library count matches every authored ability resource"
	)
	_expect(
		equipped_ids.size() == authored_ids.size(),
		"Grace's runtime casting references match every authored ability resource"
	)
	for spell_id: String in authored_ids:
		_expect(learned_ids.has(spell_id), spell_id + " appears in learned Focus spells")
		_expect(equipped_ids.has(spell_id), spell_id + " has a runtime casting reference")

	for spell_id: String in RESTORED_LIBRARY_SPELLS:
		_expect(learned_ids.has(spell_id), spell_id + " is restored to the complete Focus library")
		_expect(bool(caster.call("select_focus_spell_by_id", spell_id)), spell_id + " remains selectable through Focus")

	var sound_names: Array[String] = _get_focus_names(caster, "sound")
	_expect(sound_names.has("Echolocation"), "Echolocation appears inside the Sound Focus page")
	_expect(sound_names.has("Resonant Pulse"), "Resonant Pulse appears inside the Sound Focus page")
	var air_names: Array[String] = _get_focus_names(caster, "air")
	_expect(air_names.has("Gust"), "analytic Gust appears inside the Air Focus page")
	_expect(air_names.has("Flight"), "Flight appears inside the Air Focus page")
	_expect(_get_focus_names(caster, "water").has("Rain"), "Rain appears inside the Water Focus page")
	_expect(_get_focus_names(caster, "ice").has("Snowfall"), "Snowfall appears inside the Ice Focus page")
	_expect(_get_focus_names(caster, "lightning").has("Thunderstorm"), "Thunderstorm appears inside the Lightning Focus page")

	await _cast_and_verify_weather(caster, player, "rain_weather", "rain")
	await _cast_and_verify_weather(caster, player, "snow_weather", "snow")
	await _cast_and_verify_weather(caster, player, "thunderstorm_weather", "thunderstorm")

	var manager: Node = get_tree().get_first_node_in_group("concentration_manager")
	_expect(manager != null, "weather resolves one shared concentration manager")
	if manager != null and manager.has_method("has_effect"):
		_expect(bool(manager.call("has_effect", "thunderstorm_weather")), "Thunderstorm owns its concentration entry")

	var flight_index: int = _find_ability_index(loadout, "flight_concentration")
	_expect(flight_index >= 0, "Flight has a runtime index")
	if flight_index >= 0:
		caster.call("select_ability", flight_index, false)
		var did_cast_flight: bool = bool(caster.call("cast_from_player", player, 0.0, false))
		_expect(did_cast_flight, "Flight casts from the complete Focus library")
		await _wait_frames(3)

	var aerial: Node = player.get_node_or_null("AerialLocomotion")
	_expect(aerial != null, "player exposes aerial locomotion")
	if aerial != null:
		_expect(bool(aerial.get("flight_unlocked")), "learned Flight activates its development unlock")
		_expect(bool(aerial.get("flight_active")), "Flight enters the sustained flying state")

	manager = get_tree().get_first_node_in_group("concentration_manager")
	_expect(manager != null, "weather and Flight share one concentration manager")
	if manager != null:
		if manager.has_method("has_effect"):
			_expect(bool(manager.call("has_effect", "flight_concentration")), "Flight has its own concentration entry")
			_expect(bool(manager.call("has_effect", "thunderstorm_weather")), "Flight no longer evicts active weather")
			_expect(int(manager.call("get_active_effect_count")) == 2, "weather and Flight coexist inside one Mana budget")
		else:
			var active_effect: Variant = manager.get("active_effect")
			_expect(active_effect != null and str(active_effect.get("effect_id")) == "flight_concentration", "legacy concentration exposes Flight")
	_expect(_count_active_weather_controllers() == 1, "Flight can coexist with the active Thunderstorm")

	if aerial != null and aerial.has_method("finish_flight"):
		aerial.call("finish_flight", true, false)
		await _wait_frames(2)
		_expect(not bool(aerial.get("flight_active")), "Flight can be released normally")
	if manager != null and manager.has_method("has_effect"):
		_expect(not bool(manager.call("has_effect", "flight_concentration")), "releasing Flight removes only Flight")
		_expect(bool(manager.call("has_effect", "thunderstorm_weather")), "releasing Flight leaves Thunderstorm concentrated")

	_finish([player, floor])


func _cast_and_verify_weather(
	caster: Node,
	player: CharacterBody3D,
	spell_id: String,
	weather_kind: String
) -> void:
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		_expect(false, "weather cast resolves the runtime loadout")
		return
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout
	var ability_index: int = _find_ability_index(loadout, spell_id)
	_expect(ability_index >= 0, spell_id + " has a runtime index")
	if ability_index < 0:
		return
	caster.call("select_ability", ability_index, false)
	var did_cast: bool = bool(caster.call("cast_from_player", player, 0.0, false))
	_expect(did_cast, spell_id + " casts from the complete Focus library")
	await _wait_frames(3)

	var controller: Node = _find_weather_controller(weather_kind)
	_expect(controller != null, weather_kind + " creates or resolves a weather controller")
	if controller != null:
		_expect(bool(controller.get("active")), weather_kind + " becomes active")
		var definition: Variant = controller.get("weather_definition")
		_expect(definition != null and str(definition.get("weather_kind")) == weather_kind, weather_kind + " controller uses the matching definition")

	var manager: Node = get_tree().get_first_node_in_group("concentration_manager")
	_expect(manager != null, weather_kind + " resolves concentration at runtime")
	if manager != null:
		if manager.has_method("has_effect"):
			var definition_id: String = str(controller.get("weather_definition").get("effect_id")) if controller != null else ""
			_expect(bool(manager.call("has_effect", definition_id)), weather_kind + " owns an active concentration entry")
		else:
			var active_effect: Variant = manager.get("active_effect")
			_expect(active_effect != null and str(active_effect.get("weather_kind")) == weather_kind, weather_kind + " owns the active concentration effect")
	_expect(get_tree().get_node_count_in_group("concentration_manager") == 1, "weather spells share one concentration manager")
	_expect(get_tree().get_node_count_in_group("runtime_weather_controller") <= 1, "runtime weather keeps at most one generated controller")
	_expect(_count_active_weather_controllers() == 1, "weather remains exclusive with other weather")


func _find_weather_controller(weather_kind: String) -> Node:
	for controller: Node in get_tree().get_nodes_in_group("weather_controller"):
		if controller == null or not is_instance_valid(controller) or controller.is_queued_for_deletion():
			continue
		var definition: Variant = controller.get("weather_definition")
		if definition != null and str(definition.get("weather_kind")) == weather_kind:
			return controller
	return null


func _count_active_weather_controllers() -> int:
	var count: int = 0
	for controller: Node in get_tree().get_nodes_in_group("weather_controller"):
		if controller != null and is_instance_valid(controller) and not controller.is_queued_for_deletion() and bool(controller.get("active")):
			count += 1
	return count


func _get_focus_names(caster: Node, element: String) -> Array[String]:
	var names: Array[String] = []
	var raw_value: Variant = caster.call("get_focus_spell_names_for_element", element)
	if raw_value is Array:
		for raw_name: Variant in raw_value as Array:
			names.append(str(raw_name))
	return names


func _get_spell_ids(abilities: Array[AbilityDefinition]) -> Array[String]:
	var ids: Array[String] = []
	for ability: AbilityDefinition in abilities:
		if ability == null:
			continue
		var spell_id: String = ability.get_spell_id()
		if spell_id != "" and not ids.has(spell_id):
			ids.append(spell_id)
	return ids


func _find_ability_index(loadout: AbilityLoadout, spell_id: String) -> int:
	if loadout == null:
		return -1
	for ability_index: int in range(loadout.get_equipped_ability_count()):
		var ability: AbilityDefinition = loadout.get_equipped_ability(ability_index)
		if ability != null and ability.get_spell_id() == spell_id:
			return ability_index
	return -1


func _make_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "CompleteSpellLibraryFloor"
	floor.position = Vector3(0.0, -0.1, 0.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(40.0, 0.2, 40.0)
	collision.shape = shape
	floor.add_child(collision)
	return floor


func _prepare_stats() -> void:
	GameState.set_stat("max_health", 100)
	GameState.set_stat("health", 100)
	GameState.set_stat("max_mana", 100)
	GameState.set_stat("mana", 100)
	GameState.set_stat("max_stamina", 40)
	GameState.set_stat("stamina", 40)
	GameState.set_stat("max_stance", 35)
	GameState.set_stat("stance", 35)


func _wait_frames(frame_count: int) -> void:
	for _frame: int in range(maxi(frame_count, 0)):
		await get_tree().process_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("COMPLETE_SPELL_LIBRARY_SMOKE_TEST: " + label)


func _restore_state() -> void:
	GameState.stats = original_stats.duplicate(true)
	for stat_value: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_value)
		GameState.stat_changed.emit(stat_id, int(GameState.stats[stat_value]))
	GameState.quick_spell_loadouts = original_quick_spell_loadouts.duplicate(true)
	GameState.quick_spell_selected_slots = original_quick_spell_selected_slots.duplicate(true)


func _cleanup_runtime_services() -> void:
	for controller: Node in get_tree().get_nodes_in_group("runtime_weather_controller"):
		if controller == null or not is_instance_valid(controller):
			continue
		if controller.has_method("stop_weather"):
			controller.call("stop_weather", false)
		controller.queue_free()
	for manager: Node in get_tree().get_nodes_in_group("concentration_manager"):
		if manager == null or not is_instance_valid(manager):
			continue
		if manager.has_method("deactivate_all_effects"):
			manager.call("deactivate_all_effects", false)
		if bool(manager.get_meta("runtime_spell_library_service", false)):
			manager.queue_free()


func _finish(nodes: Array) -> void:
	Engine.time_scale = 1.0
	_cleanup_runtime_services()
	_restore_state()
	for node_value: Variant in nodes:
		if node_value is Node and is_instance_valid(node_value as Node):
			(node_value as Node).queue_free()
	if failures.is_empty():
		print("COMPLETE_SPELL_LIBRARY_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("COMPLETE_SPELL_LIBRARY_SMOKE_TEST: " + failure)
	get_tree().quit(1)
