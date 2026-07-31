extends "res://scripts/enemies/enemy_attack_definition.gd"


@export_enum("contact", "projectile") var delivery_mode: String = "contact"
@export var projectile_scene: PackedScene
@export_range(0.1, 40.0, 0.1) var projectile_speed: float = 12.0
@export_range(0.0, 4.0, 0.05) var projectile_spawn_height: float = 0.75
@export_range(0.0, 4.0, 0.05) var projectile_spawn_distance: float = 0.65


func is_projectile_delivery() -> bool:
	return delivery_mode.strip_edges().to_lower() == "projectile"


func get_projectile_scene() -> PackedScene:
	return projectile_scene


func get_projectile_speed() -> float:
	return maxf(projectile_speed, 0.1)


func get_projectile_spawn_height() -> float:
	return maxf(projectile_spawn_height, 0.0)


func get_projectile_spawn_distance() -> float:
	return maxf(projectile_spawn_distance, 0.0)
