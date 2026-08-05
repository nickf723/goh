extends Node
class_name LabResourceRegenerator

signal resource_regenerated(
	stat_id: String,
	amount: int,
	current_value: int,
	maximum_value: int
)

@export_group("Regeneration")
@export_range(0.0, 100.0, 0.5) var mana_per_second: float = 18.0
@export_range(0.0, 100.0, 0.5) var stamina_per_second: float = 10.0
@export_range(0.0, 100.0, 0.5) var focus_per_second: float = 8.0
@export var refill_on_ready: bool = true

var mana_buffer: float = 0.0
var stamina_buffer: float = 0.0
var focus_buffer: float = 0.0
var total_mana_restored: int = 0
var total_stamina_restored: int = 0
var total_focus_restored: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("lab_resource_regenerators")
	add_to_group("debuggable")
	if refill_on_ready:
		refill_resources()


func _process(delta: float) -> void:
	mana_buffer = _regenerate_stat(
		"mana",
		"max_mana",
		mana_per_second,
		mana_buffer,
		delta
	)
	stamina_buffer = _regenerate_stat(
		"stamina",
		"max_stamina",
		stamina_per_second,
		stamina_buffer,
		delta
	)
	focus_buffer = _regenerate_stat(
		"focus",
		"max_focus",
		focus_per_second,
		focus_buffer,
		delta
	)


func refill_resources() -> Dictionary:
	var restored: Dictionary = {}
	for row: Dictionary in [
		{"stat": "mana", "maximum": "max_mana"},
		{"stat": "stamina", "maximum": "max_stamina"},
		{"stat": "focus", "maximum": "max_focus"},
	]:
		var stat_id: String = str(row["stat"])
		var maximum_stat_id: String = str(row["maximum"])
		var current: int = GameState.get_stat(stat_id)
		var maximum: int = GameState.get_stat(maximum_stat_id)
		var amount: int = maxi(maximum - current, 0)
		if amount <= 0:
			continue
		GameState.set_stat(stat_id, maximum)
		_track_restoration(stat_id, amount, maximum, maximum)
		restored[stat_id] = amount
	mana_buffer = 0.0
	stamina_buffer = 0.0
	focus_buffer = 0.0
	return restored


func _regenerate_stat(
	stat_id: String,
	maximum_stat_id: String,
	rate: float,
	buffer: float,
	delta: float
) -> float:
	var current: int = GameState.get_stat(stat_id)
	var maximum: int = GameState.get_stat(maximum_stat_id)
	if rate <= 0.0 or maximum <= 0:
		return 0.0
	if current >= maximum:
		# Never stockpile invisible regeneration while full. Otherwise the next cast
		# could be refunded instantly by several seconds of stored fractional credit.
		return 0.0
	buffer += maxf(delta, 0.0) * rate
	var whole_points: int = int(floor(buffer))
	if whole_points <= 0:
		return buffer
	var restored: int = mini(whole_points, maximum - current)
	var next_value: int = current + restored
	GameState.set_stat(stat_id, next_value)
	_track_restoration(stat_id, restored, next_value, maximum)
	return buffer - float(restored)


func _track_restoration(
	stat_id: String,
	amount: int,
	current_value: int,
	maximum_value: int
) -> void:
	if amount <= 0:
		return
	match stat_id:
		"mana":
			total_mana_restored += amount
		"stamina":
			total_stamina_restored += amount
		"focus":
			total_focus_restored += amount
	resource_regenerated.emit(stat_id, amount, current_value, maximum_value)


func get_debug_data() -> Dictionary:
	return {
		"lab_resource_regenerator": true,
		"mana_per_second": mana_per_second,
		"stamina_per_second": stamina_per_second,
		"focus_per_second": focus_per_second,
		"mana_buffer": snappedf(mana_buffer, 0.01),
		"stamina_buffer": snappedf(stamina_buffer, 0.01),
		"focus_buffer": snappedf(focus_buffer, 0.01),
		"total_mana_restored": total_mana_restored,
		"total_stamina_restored": total_stamina_restored,
		"total_focus_restored": total_focus_restored,
	}
