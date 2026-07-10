extends Resource
class_name EnemyDefinition

@export var display_name: String = "Enemy"
@export var species_id: String = "enemy"
@export var faction_id: String = "monsters"
@export var spacing_buffer: float = 0.25
@export var circle_when_waiting_to_attack: bool = true
@export var strafe_speed_multiplier: float = 0.65
@export var strafe_switch_interval: float = 1.2

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

@export var tags: Array[String] = ["enemy"]

@export var move_speed: float = 2.2
@export var turn_speed: float = 9.0
@export var gravity: float = 18.0

@export var detection_radius: float = 9.0
@export var lose_interest_radius: float = 14.0
@export var preferred_distance: float = 1.4

@export var debug_notes: String = ""
