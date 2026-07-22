extends Node

const LabScene: PackedScene = preload("res://scenes/levels/prototypes/prototype_enemy_personality_lab_v1.tscn")
const PersonalityTraits = preload("res://scripts/enemies/enemy_personality_traits.gd")

const EXPECTED_LANES: Array[Dictionary] = [
	{"enemy": "CautiousGoblin", "profile": "cautious", "target": "personality_lab_cautious_target"},
	{"enemy": "BoldGoblin", "profile": "bold", "target": "personality_lab_bold_target"},
	{"enemy": "SkittishGoblin", "profile": "skittish", "target": "personality_lab_skittish_target"},
	{"enemy": "BruteGoblin", "profile": "brute", "target": "personality_lab_brute_target"},
]

var failures: Array[String] = []


func _ready() -> void:
	var lab: Node = LabScene.instantiate()
	if lab == null:
		failures.append("Enemy Personality Laboratory scene must instantiate")
		finish()
		return

	add_child(lab)
	await get_tree().process_frame
	await get_tree().process_frame
	validate_lanes(lab)

	lab.queue_free()
	await get_tree().process_frame
	var reset_lab: Node = LabScene.instantiate()
	add_child(reset_lab)
	await get_tree().process_frame
	validate_lanes(reset_lab, "reset ")
	reset_lab.queue_free()
	finish()


func validate_lanes(lab: Node, prefix: String = "") -> void:
	for expected: Dictionary in EXPECTED_LANES:
		var enemy_name: String = str(expected["enemy"])
		var enemy: Node = lab.get_node_or_null("Lanes/" + enemy_name)
		if enemy == null:
			failures.append(prefix + enemy_name + " lane enemy is missing")
			continue

		var brain: Node = enemy.get_node_or_null("EnemyBrain")
		if brain == null:
			failures.append(prefix + enemy_name + " EnemyBrain is missing")
			continue

		var profile_id: String = str(brain.get("personality_id"))
		var expected_profile: String = str(expected["profile"])
		if profile_id != expected_profile:
			failures.append(prefix + enemy_name + " expected " + expected_profile + " but found " + profile_id)
		if PersonalityTraits.normalize_profile_id(profile_id) != expected_profile:
			failures.append(prefix + enemy_name + " does not use a registered personality profile")
		if str(brain.get("player_group")) != str(expected["target"]):
			failures.append(prefix + enemy_name + " has the wrong lane target group")


func finish() -> void:
	if failures.is_empty():
		print("ENEMY_PERSONALITY_LAB_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("ENEMY_PERSONALITY_LAB_SMOKE_TEST: " + failure)
	get_tree().quit(1)
