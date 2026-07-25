extends Node
class_name PlayerPerfectDodgeController

signal perfect_dodge_succeeded(result: Dictionary)
signal dodge_resolved(result: Dictionary)

@export_range(0.04, 0.3, 0.01) var perfect_window_seconds: float = 0.12
@export_range(0, 20, 1) var stamina_reward: int = 8
@export_range(0.1, 2.0, 0.05) var counter_window_seconds: float = 0.85

var perfect_remaining: float = 0.0
var was_dodging: bool = false
var perfect_dodge_count: int = 0
var last_outcome: String = "READY"

@onready var actor: CharacterBody3D = get_parent() as CharacterBody3D
@onready var dodge_controller: PlayerDodgeController = get_parent().get_node_or_null("DodgeController") as PlayerDodgeController
@onready var defense_controller: PlayerDefenseController = get_parent().get_node_or_null("PlayerDefenseController") as PlayerDefenseController


func _ready() -> void:
	if dodge_controller == null and actor != null:
		for child: Node in actor.get_children():
			if child is PlayerDodgeController:
				dodge_controller = child as PlayerDodgeController
				break
	add_to_group("debuggable")


func _process(delta: float) -> void:
	var dodging: bool = dodge_controller != null and dodge_controller.is_dodge_active()
	if dodging and not was_dodging:
		perfect_remaining = perfect_window_seconds
	if perfect_remaining > 0.0:
		perfect_remaining = maxf(perfect_remaining - delta, 0.0)
	was_dodging = dodging


func resolve_telegraphed_attack(payload: DamagePayload, attacker: Node3D) -> Dictionary:
	if payload == null:
		return {"outcome": "ignored", "message": ""}
	var dodging: bool = dodge_controller != null and dodge_controller.is_dodge_active()
	if dodging and perfect_remaining > 0.0:
		perfect_remaining = 0.0
		perfect_dodge_count += 1
		last_outcome = "PERFECT DODGE"
		_reward_player()
		if attacker != null and attacker.has_method("grant_counter_window"):
			attacker.call("grant_counter_window", counter_window_seconds)
		HitStop.request(0.1, 0.22)
		var perfect_result := {
			"outcome": "perfect_dodge",
			"message": "Perfect Dodge! Counter window opened.",
			"stamina_reward": stamina_reward,
			"counter_window": counter_window_seconds,
		}
		perfect_dodge_succeeded.emit(perfect_result)
		dodge_resolved.emit(perfect_result)
		_show_message(str(perfect_result["message"]))
		return perfect_result
	if defense_controller != null:
		var result: Dictionary = defense_controller.resolve_incoming_attack(payload, attacker)
		last_outcome = str(result.get("outcome", "hit")).to_upper()
		dodge_resolved.emit(result)
		return result
	return {"outcome": "unresolved", "message": "No defense receiver."}


func _reward_player() -> void:
	var maximum: int = GameState.get_stat("max_stamina")
	var current: int = GameState.get_stat("stamina")
	GameState.set_stat("stamina", mini(current + stamina_reward, maximum))


func reset_perfect_dodge() -> void:
	perfect_remaining = 0.0
	was_dodging = false
	perfect_dodge_count = 0
	last_outcome = "READY"


func get_debug_data() -> Dictionary:
	return {
		"window": snappedf(perfect_remaining, 0.01),
		"count": perfect_dodge_count,
		"outcome": last_outcome,
		"dodging": dodge_controller != null and dodge_controller.is_dodge_active(),
	}


func _show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)
