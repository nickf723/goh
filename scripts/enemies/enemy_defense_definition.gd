extends EnemyCombatActionDefinition
class_name EnemyDefenseDefinition

@export_enum("evade", "guard", "brace", "counter", "retreat")
var defense_style: String = "evade"
@export var defense_tags: Array[String] = ["defensive"]


func _init() -> void:
	action_id = "enemy_defense"
	action_kind = "defense"
	display_name = "Enemy Defense"
	role_tags = ["enemy_action", "defense"]
	movement_mode = "away_from_target"


func get_defense_style() -> String:
	return defense_style.to_lower().strip_edges()


func get_role_tags() -> Array[String]:
	var tags: Array[String] = super.get_role_tags()
	append_unique_strings(tags, defense_tags)

	if not tags.has("defensive"):
		tags.append("defensive")

	var style: String = get_defense_style()
	if style != "" and not tags.has(style):
		tags.append(style)

	return tags
