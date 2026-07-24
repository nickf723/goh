extends Node
class_name PlayerResourceController

signal resource_recovered(resource_name: String, amount: int)

@export_group("Stamina Recovery")
@export_range(0.0, 5.0, 0.05) var stamina_regeneration_delay: float = 0.7
@export_range(0.25, 10.0, 0.05) var stamina_empty_to_full_seconds: float = 2.4
@export var pause_stamina_during_actions: bool = true

@export_group("Stance Recovery")
@export_range(0.0, 8.0, 0.05) var stance_regeneration_delay: float = 2.0
@export_range(0.5, 15.0, 0.1) var stance_empty_to_full_seconds: float = 4.0
@export var pause_stance_during_defense: bool = true

var stamina_delay_remaining: float = 0.0
var stance_delay_remaining: float = 0.0
var stamina_accumulator: float = 0.0
var stance_accumulator: float = 0.0

@onready var action_state: PlayerActionState = get_parent().get_node_or_null("PlayerActionState") as PlayerActionState


func _ready() -> void:
	add_to_group("debuggable")
	if not GameState.resource_depleted.is_connected(_on_resource_depleted):
		GameState.resource_depleted.connect(_on_resource_depleted)


func _exit_tree() -> void:
	if GameState.resource_depleted.is_connected(_on_resource_depleted):
		GameState.resource_depleted.disconnect(_on_resource_depleted)


func _process(delta: float) -> void:
	advance_resources(delta)


func advance_resources(delta: float) -> void:
	if delta <= 0.0:
		return
	if action_state != null and action_state.is_defeated:
		return

	stamina_delay_remaining = maxf(stamina_delay_remaining - delta, 0.0)
	stance_delay_remaining = maxf(stance_delay_remaining - delta, 0.0)

	if stamina_delay_remaining <= 0.0 and can_regenerate_stamina():
		stamina_accumulator = recover_resource(
			"stamina",
			stamina_empty_to_full_seconds,
			stamina_accumulator,
			delta
		)

	if stance_delay_remaining <= 0.0 and can_regenerate_stance():
		stance_accumulator = recover_resource(
			"stance",
			stance_empty_to_full_seconds,
			stance_accumulator,
			delta
		)


func can_regenerate_stamina() -> bool:
	if not pause_stamina_during_actions or action_state == null:
		return true

	return not (
		action_state.is_attacking
		or action_state.is_casting
		or action_state.is_dodging
		or action_state.is_manipulating
		or action_state.is_guarding
		or action_state.is_staggered
		or action_state.is_using_item
	)


func can_regenerate_stance() -> bool:
	if not pause_stance_during_defense or action_state == null:
		return true
	return not (action_state.is_guarding or action_state.is_staggered)


func recover_resource(
	resource_name: String,
	empty_to_full_seconds: float,
	accumulator: float,
	delta: float
) -> float:
	var maximum: int = GameState.get_stat("max_" + resource_name)
	var current: int = GameState.get_stat(resource_name)

	if maximum <= 0 or current >= maximum:
		return 0.0

	var points_per_second: float = float(maximum) / maxf(empty_to_full_seconds, 0.01)
	accumulator += points_per_second * delta
	var whole_points: int = floori(accumulator)

	if whole_points <= 0:
		return accumulator

	var recovered: int = mini(whole_points, maximum - current)

	if resource_name == "stamina":
		GameState.restore_stamina(recovered)
	elif resource_name == "stance":
		GameState.restore_stance(recovered)

	resource_recovered.emit(resource_name, recovered)
	return accumulator - float(recovered)


func _on_resource_depleted(resource_name: String, _amount: int) -> void:
	match resource_name:
		"stamina":
			stamina_delay_remaining = stamina_regeneration_delay
			stamina_accumulator = 0.0
		"stance":
			stance_delay_remaining = stance_regeneration_delay
			stance_accumulator = 0.0


func reset_recovery_state() -> void:
	stamina_delay_remaining = 0.0
	stance_delay_remaining = 0.0
	stamina_accumulator = 0.0
	stance_accumulator = 0.0


func get_debug_data() -> Dictionary:
	return {
		"stamina_delay": snapped(stamina_delay_remaining, 0.01),
		"stamina_regenerating": stamina_delay_remaining <= 0.0 and can_regenerate_stamina(),
		"stamina_empty_to_full_seconds": stamina_empty_to_full_seconds,
		"stance_delay": snapped(stance_delay_remaining, 0.01),
		"stance_regenerating": stance_delay_remaining <= 0.0 and can_regenerate_stance(),
		"stance_empty_to_full_seconds": stance_empty_to_full_seconds,
	}
