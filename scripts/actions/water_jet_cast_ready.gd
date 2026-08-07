extends "res://scripts/actions/water_jet_cast.gd"
class_name WaterJetCastReady

const GameplayEffectAccessScript = preload(
	"res://scripts/effects/gameplay_effect_access.gd"
)

# The production authority primes the stream transform immediately, preventing
# the reused cylinder meshes from appearing at the scene origin for one visual
# update interval after the channel begins. It also routes sustained Mana through
# the same gameplay-effect modifier contract as Flamethrower and ordinary casts.


func execute(player: Node3D, requested_direction: Vector3) -> void:
	super.execute(player, requested_direction)
	if not active or source_actor == null or not is_instance_valid(source_actor):
		return
	current_origin = _get_cast_origin()
	current_direction = _get_cast_direction(current_origin)
	current_hit = _resolve_stream_hit(current_origin, current_direction)
	current_stream_length = _get_stream_length(current_origin, current_hit)
	last_hit_name = _get_hit_name(current_hit)
	_update_visuals()


func get_effective_mana_rate() -> float:
	return maxf(
		GameplayEffectAccessScript.modify_float(
			"mana_cost",
			mana_per_second
		),
		0.0
	)


func _consume_channel_mana(delta: float) -> bool:
	var rate: float = get_effective_mana_rate()
	if rate <= 0.0:
		return true
	mana_fractional_cost += rate * maxf(delta, 0.0)
	var whole_cost: int = floori(mana_fractional_cost)
	if whole_cost <= 0:
		_store_mana_debt()
		return true

	var available: int = GameState.get_stat("mana")
	var spent: int = mini(whole_cost, available)
	if spent > 0:
		GameState.spend_mana(spent)
		total_mana_spent += spent
		mana_drained.emit(spent, GameState.get_stat("mana"))
	mana_fractional_cost -= float(spent)
	if mana_fractional_cost >= 1.0:
		mana_fractional_cost = fmod(mana_fractional_cost, 1.0)
	_store_mana_debt()
	return spent >= whole_cost and GameState.get_stat("mana") > 0


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["start_transform_primed"] = true
	data["effective_mana_per_second"] = get_effective_mana_rate()
	data["gameplay_effect_cost_modifier"] = true
	return data
