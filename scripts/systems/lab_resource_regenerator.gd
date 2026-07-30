extends Node
class_name LabResourceRegenerator


@export_range(0.0, 100.0, 0.5) var mana_per_second: float = 18.0
@export_range(0.0, 100.0, 0.5) var stamina_per_second: float = 10.0
@export_range(0.0, 100.0, 0.5) var focus_per_second: float = 8.0

var mana_buffer: float = 0.0
var stamina_buffer: float = 0.0
var focus_buffer: float = 0.0


func _process(delta: float) -> void:
	mana_buffer = _regenerate_stat("mana", "max_mana", mana_per_second, mana_buffer, delta)
	stamina_buffer = _regenerate_stat(
		"stamina",
		"max_stamina",
		stamina_per_second,
		stamina_buffer,
		delta
	)
	focus_buffer = _regenerate_stat("focus", "max_focus", focus_per_second, focus_buffer, delta)


func _regenerate_stat(
	stat_id: String,
	maximum_stat_id: String,
	rate: float,
	buffer: float,
	delta: float
) -> float:
	var current: int = GameState.get_stat(stat_id)
	var maximum: int = GameState.get_stat(maximum_stat_id)
	if rate <= 0.0 or maximum <= 0 or current >= maximum:
		return 0.0
	buffer += maxf(delta, 0.0) * rate
	var whole_points: int = int(floor(buffer))
	if whole_points <= 0:
		return buffer
	GameState.set_stat(stat_id, mini(current + whole_points, maximum))
	return buffer - float(whole_points)


func get_debug_data() -> Dictionary:
	return {
		"mana_per_second": mana_per_second,
		"stamina_per_second": stamina_per_second,
		"focus_per_second": focus_per_second,
	}
