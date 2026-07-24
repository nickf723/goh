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

@export_group("Base Attributes")
@export var damage: int = 1
@export var stance_damage: int = 1
@export var range: float = 2.0
@export var attack_speed: float = 1.0
@export var cooldown: float = 0.45
@export var cone_angle_degrees: float = 85.0
@export var max_targets: int = 3
@export var stamina_cost: int = 0
@export_range(1.0, 6.0, 0.05) var critical_multiplier: float = 2.0

@export_group("Moveset")
@export var moveset: WeaponMovesetDefinition

@export_group("Prototype Visual Identity")
@export var visual_primary_color: Color = Color(0.72, 0.78, 0.9, 1.0)
@export var visual_secondary_color: Color = Color(0.22, 0.18, 0.28, 1.0)
@export var visual_accent_color: Color = Color(1.0, 0.78, 0.28, 1.0)
@export var visual_scale: float = 1.0
@export var runtime_rig_scene: PackedScene

# Pure metadata for build identity. These do not alter weapon damage yet.
@export_group("Scaling Identity")
@export var scaling_stats: Array[String] = ["power", "dexterity"]
@export_multiline var scaling_note: String = "Prototype weapon scaling identity only. Damage formulas are not active yet."

@export_group("Fallback Payload")
@export var light_payload: DamagePayload


func get_light_payload() -> DamagePayload:
	var payload: DamagePayload

	if light_payload != null:
		payload = light_payload.duplicate(true) as DamagePayload
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


func get_moveset() -> WeaponMovesetDefinition:
	return moveset


func has_moveset() -> bool:
	return moveset != null and moveset.attacks.size() > 0


func get_scaling_stats() -> Array[String]:
	var resolved_scaling: Array[String] = []

	for stat_name: String in scaling_stats:
		if stat_name == "":
			continue

		if resolved_scaling.has(stat_name):
			continue

		resolved_scaling.append(stat_name)

	return resolved_scaling


func get_scaling_note() -> String:
	if scaling_note != "":
		return scaling_note

	return "Prototype weapon scaling identity only. Damage formulas are not active yet."


func get_scaling_summary() -> String:
	var resolved_scaling: Array[String] = get_scaling_stats()

	if resolved_scaling.size() <= 0:
		return "none"

	return " / ".join(resolved_scaling)


func get_combat_summary() -> String:
	var moveset_name: String = "legacy swing"
	if moveset != null:
		moveset_name = moveset.display_name

	return (
		display_name
		+ " | "
		+ weapon_class
		+ " | dmg "
		+ str(damage)
		+ " | stance "
		+ str(stance_damage)
		+ " | crit x"
		+ str(snapped(critical_multiplier, 0.05))
		+ " | speed "
		+ str(attack_speed)
		+ " | "
		+ moveset_name
	)
