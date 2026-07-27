extends RefCounted
class_name AuthoredEncounterSequence

var waves: Array[Dictionary] = []
var active_wave: int = -1
var active_enemies: Array[Node3D] = []
var completed: bool = false


func configure(wave_definitions: Array[Dictionary]) -> void:
	waves = wave_definitions.duplicate(true)
	active_wave = -1
	active_enemies.clear()
	completed = waves.is_empty()


func begin_next_wave(parent: Node, spawn_callback: Callable) -> Array[Node3D]:
	prune()
	if not active_enemies.is_empty() or completed:
		return active_enemies
	active_wave += 1
	if active_wave >= waves.size():
		completed = true
		return []
	var wave: Dictionary = waves[active_wave]
	for spawn_variant: Variant in wave.get("spawns", []):
		if not spawn_variant is Dictionary:
			continue
		var enemy_variant: Variant = spawn_callback.call(parent, spawn_variant)
		if enemy_variant is Node3D and is_instance_valid(enemy_variant):
			active_enemies.append(enemy_variant as Node3D)
	return active_enemies


func prune() -> void:
	var remaining: Array[Node3D] = []
	for enemy: Node3D in active_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			remaining.append(enemy)
	active_enemies = remaining
	if active_enemies.is_empty() and active_wave >= waves.size() - 1 and active_wave >= 0:
		completed = true


func can_advance() -> bool:
	prune()
	return active_enemies.is_empty() and not completed


func is_complete() -> bool:
	prune()
	return completed


func reset() -> void:
	for enemy: Node3D in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	active_enemies.clear()
	active_wave = -1
	completed = waves.is_empty()
