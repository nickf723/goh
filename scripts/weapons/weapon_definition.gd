extends Resource
class_name WeaponDefinition

@export_enum(
	"sword",
	"lance",
	"axe",
	"bow",
	"hammer",
	"mace",
	"daggers",
	"whip",
	"chains",
	"gauntlets",
	"flail",
	"halberd",
	"boomerang",
	"scythe",
	"staff",
	"shuriken"
)
var weapon_class: String = "sword"

@export var display_name: String = "Practice Sword"
@export var description: String = ""

@export var damage: int = 1
@export var stance_damage: int = 1
@export var range: float = 2.0
@export var attack_speed: float = 1.0
@export var cooldown: float = 0.45
@export var cone_angle_degrees: float = 85.0
@export var max_targets: int = 3
@export var stamina_cost: int = 0

@export var light_payload: DamagePayload


func get_light_payload() -> DamagePayload:
	var payload: DamagePayload

	if light_payload != null:
		payload = light_payload.duplicate(true)
	else:
		payload = DamagePayload.new()
		payload.source_name = display_name
		payload.element = "neutral"
		payload.hit_type = "melee"
		payload.tags = ["physical", "melee", "weapon"]

	payload.amount = damage
	payload.stance_damage = stance_damage
	payload.source_name = display_name
	payload.hit_type = "melee"

	if not payload.tags.has("weapon"):
		payload.tags.append("weapon")

	if not payload.tags.has("melee"):
		payload.tags.append("melee")

	return payload
