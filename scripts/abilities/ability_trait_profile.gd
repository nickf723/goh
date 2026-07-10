extends Resource
class_name AbilityTraitProfile

@export var profile_id: String = "spell_profile"
@export var display_name: String = "Spell Profile"
@export_multiline var description: String = ""

# Shared taxonomy defaults for families of spells.
# Individual AbilityDefinition resources can add extra tags on top.
@export var roles: Array[String] = []
@export var targeting_style: String = "aimed"
@export var delivery_type: String = "projectile"

@export var combo_tags: Array[String] = []
@export var status_tags: Array[String] = []
@export var ui_tags: Array[String] = []
@export var debug_tags: Array[String] = []

@export_multiline var design_notes: String = ""


func get_summary() -> String:
	var parts: Array[String] = []
	parts.append(profile_id)

	if delivery_type != "":
		parts.append(delivery_type)

	if targeting_style != "":
		parts.append(targeting_style)

	if roles.size() > 0:
		parts.append("roles=" + ",".join(roles))

	return " | ".join(parts)


func get_all_profile_tags() -> Array[String]:
	var all_tags: Array[String] = []
	append_unique_strings(all_tags, roles)
	append_unique_strings(all_tags, combo_tags)
	append_unique_strings(all_tags, status_tags)
	append_unique_strings(all_tags, ui_tags)
	append_unique_strings(all_tags, debug_tags)

	if targeting_style != "" and not all_tags.has(targeting_style):
		all_tags.append(targeting_style)

	if delivery_type != "" and not all_tags.has(delivery_type):
		all_tags.append(delivery_type)

	return all_tags


func append_unique_strings(target: Array[String], source: Array[String]) -> void:
	for value: String in source:
		if value == "":
			continue

		if target.has(value):
			continue

		target.append(value)
