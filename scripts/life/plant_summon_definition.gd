extends Resource
class_name PlantSummonDefinition

@export_group("Identity")
@export var plant_id: String = ""
@export var display_name: String = "Plant"
@export_multiline var description: String = ""
@export var growth_archetype: String = "utility"
@export var discovery_tags: Array[String] = []
@export var roles: Array[String] = []
@export_file("*.tscn") var summon_scene_path: String = ""

@export_group("Growth")
@export_range(0.5, 60.0, 0.25) var lifetime: float = 10.0
@export_range(0.2, 6.0, 0.05) var growth_height: float = 1.0
@export_range(0.2, 5.0, 0.05) var canopy_radius: float = 0.8
@export_range(0.05, 1.0, 0.01) var body_thickness: float = 0.2
@export_range(1, 12, 1) var maximum_active_per_caster: int = 3

@export_group("Traversal / Physics")
@export var creates_platform: bool = false
@export var climbable: bool = false
@export_range(0.0, 20.0, 0.1) var character_growth_lift_speed: float = 0.0
@export_range(0.0, 20.0, 0.1) var rigid_growth_lift_speed: float = 0.0
@export_range(0.0, 20.0, 0.1) var bounce_strength: float = 0.0

@export_group("Combat")
@export_range(0, 100, 1) var contact_damage: int = 0
@export_range(0, 100, 1) var attack_damage: int = 0
@export_range(0.0, 20.0, 0.1) var attack_range: float = 0.0
@export_range(0.1, 10.0, 0.1) var attack_interval: float = 1.0
@export var hostile_to_enemies: bool = false
@export var traps_targets: bool = false


func get_role_summary() -> String:
	return ", ".join(roles) if not roles.is_empty() else growth_archetype


func get_debug_data() -> Dictionary:
	return {
		"plant_id": plant_id,
		"display_name": display_name,
		"archetype": growth_archetype,
		"roles": roles.duplicate(),
		"scene_path": summon_scene_path,
		"lifetime": lifetime,
		"height": growth_height,
		"radius": canopy_radius,
		"platform": creates_platform,
		"climbable": climbable,
		"contact_damage": contact_damage,
		"attack_damage": attack_damage,
		"attack_range": attack_range,
		"hostile_to_enemies": hostile_to_enemies,
	}
