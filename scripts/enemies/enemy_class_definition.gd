extends Resource
class_name EnemyClassDefinition

@export var class_id: String = "enemy_class"
@export var display_name: String = "Enemy Class"
@export_multiline var description: String = ""

@export var role_tags: Array[String] = []
@export var default_tags: Array[String] = ["enemy"]
@export_enum(
	"animal",
	"fantasy_creature",
	"human",
	"undead",
	"spirit",
	"machine",
	"other"
)
var creature_type: String = "fantasy_creature"

# HitReceiver.HitMode numeric values:
# 0 = INVULNERABLE, 1 = STANCE_ONLY, 2 = HEALTH_ONLY, 3 = STANCE_THEN_HEALTH.
@export var hit_mode: int = 2
@export var max_health: int = 4
@export var max_stance: int = 2
@export var resets_stance_after_break: bool = false
@export var disappears_when_defeated: bool = true
@export var restores_mana_when_defeated: int = 0

@export var weak_elements: Array[String] = []
@export var resistant_elements: Array[String] = []
@export var immune_elements: Array[String] = []
@export var weakness_multiplier: float = 2.0
@export var resistance_multiplier: float = 0.5

@export var move_speed: float = 2.2
@export var turn_speed: float = 9.0
@export var gravity: float = 18.0
@export var detection_radius: float = 9.0
@export var lose_interest_radius: float = 14.0
@export var preferred_distance: float = 1.4
@export var spacing_buffer: float = 0.25
@export var circle_when_waiting_to_attack: bool = true
@export var strafe_speed_multiplier: float = 0.65
@export var strafe_switch_interval: float = 1.2

@export var force_drag: float = 10.0
@export var max_force_speed: float = 8.0

@export var debug_notes: String = ""
