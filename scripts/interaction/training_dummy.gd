extends Area3D

@export var prompt_text: String = "Practice Strike"

@export var stamina_cost: int = 1
@export var restores_player_stamina_after_failed_use: bool = true

@onready var hit_receiver: Node = $HitReceiver
@onready var targeting_collision: CollisionShape3D = $CollisionShape3D


func interact() -> Dictionary:
	var current_stamina: int = GameState.get_stat("stamina")

	if current_stamina >= stamina_cost:
		GameState.set_stat("stamina", current_stamina - stamina_cost)

		return {
			"message": "Grace strikes the dummy.",
			"objective": "The dummy uses a reusable HitReceiver now."
		}

	if restores_player_stamina_after_failed_use:
		var max_player_stamina: int = GameState.get_stat("max_stamina")
		GameState.set_stat("stamina", max_player_stamina)

		return {
			"message": "Grace catches her breath. Stamina restored.",
			"objective": "Try striking the dummy again."
		}

	return {
		"message": "Grace is too tired to strike.",
		"objective": "Find a way to restore stamina."
	}


func receive_magic_hit(power: int = 1) -> Dictionary:
	return hit_receiver.receive_hit(power)


func get_targeting_aim_point() -> Vector3:
	if targeting_collision != null:
		return targeting_collision.global_position
	return global_position


func get_targeting_owner() -> Node3D:
	return self
