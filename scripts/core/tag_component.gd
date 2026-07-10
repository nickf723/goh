extends Node

@export var tags: Array[String] = []


func _ready() -> void:
	add_to_group("debuggable")

func has_tag(tag: String) -> bool:
	return tags.has(tag)

func has_any_tag(required_tags: Array[String]) -> bool:
	for tag: String in required_tags:
		if tags.has(tag):
			return true

	return false

func has_all_tags(required_tags: Array[String]) -> bool:
	for tag: String in required_tags:
		if not tags.has(tag):
			return false

	return true

func add_tag(tag: String) -> void:
	if tag == "":
		return

	if tags.has(tag):
		return

	tags.append(tag)

func remove_tag(tag: String) -> void:
	if tags.has(tag):
		tags.erase(tag)

func get_debug_data() -> Dictionary:
	return {
		"tags": tags,
	}
