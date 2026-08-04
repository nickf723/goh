extends Node3D

const LabScene = preload("res://scenes/levels/prototypes/wildlife_navigation_rescue_lab_v1.tscn")
const WildlifeAnimalScript = preload("res://scripts/animals/navigation_bonded_animal_actor.gd")
const TEST_ANIMAL_ID: String = "smoke_test:command_authority_juniper"

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var lab: Node = LabScene.instantiate()
	add_child(lab)
	await get_tree().process_frame
	await get_tree().physics_frame
	await _wait_for_navigation(lab, 180)
	var animal: WildlifeAnimalScript = lab.call("get_test_animal") as WildlifeAnimalScript
	var player: Node3D = lab.call("get_test_player") as Node3D
	_expect(animal != null, "command lab spawns the navigation-aware companion")
	_expect(player != null, "command lab includes Grace")
	if animal == null or player == null:
		await _finish(lab, animal)
		return

	animal.persistent_animal_id = TEST_ANIMAL_ID
	animal.clear_persistent_bond()
	lab.call("rescue_animal")
	await get_tree().process_frame
	await _wait_for_navigation(lab, 120)
	animal.bonded = true
	animal.follow_enabled = true
	animal.relationship.trust = 0.82
	animal.relationship.familiarity = 0.8
	animal.relationship.fear_association = 0.0
	animal.set_drive("fear", 0.0)
	animal.relationship_label = animal.relationship.get_relationship_label(0.0)

	animal.global_position = Vector3(-6.0, 0.48, 7.5)
	player.global_position = Vector3(1.0, 1.05, 7.5)
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	var follow_result: Dictionary = lab.call("command_follow") as Dictionary
	_expect(bool(follow_result.get("ok", false)), "Follow command can be issued to a bonded companion")
	var follow_distance_before: float = animal.global_position.distance_to(player.global_position)
	for _frame: int in range(150):
		await get_tree().physics_frame
	var follow_distance_after: float = animal.global_position.distance_to(player.global_position)
	_expect(follow_distance_after < follow_distance_before - 1.0, "Follow command closes distance to Grace")
	_expect(str(animal.get_companion_command_data().get("command_id", "")) == "follow", "Follow becomes the authoritative command")

	var stay_result: Dictionary = lab.call("command_stay_here") as Dictionary
	var stay_data: Dictionary = animal.get_companion_command_data()
	var stay_anchor: Vector3 = stay_data.get("anchor", animal.global_position) as Vector3
	_expect(bool(stay_result.get("ok", false)), "Stay command can be issued during an active follow")
	_expect(str(stay_data.get("command_id", "")) == "stay", "Stay replaces Follow immediately")
	_expect(animal.current_action_id == "command_stay", "Stay immediately cancels the old follow action")
	_expect(Vector2(animal.velocity.x, animal.velocity.z).length() < 0.05, "Stay immediately cancels horizontal follow velocity")
	player.global_position = Vector3(14.0, 1.05, -8.0)
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	for _frame: int in range(120):
		await get_tree().physics_frame
	_expect(animal.global_position.distance_to(stay_anchor) < 0.7, "Stay does not resume following when Grace moves away")

	animal.global_position = stay_anchor + Vector3(3.0, 0.0, 0.0)
	animal.velocity = Vector3.ZERO
	animal.force_navigation_repath()
	for _frame: int in range(180):
		await get_tree().physics_frame
	_expect(animal.global_position.distance_to(stay_anchor) < 1.25, "Stay returns a displaced companion to its anchor")

	player.global_position = animal.global_position + Vector3(0.0, 0.55, 7.0)
	var come_result: Dictionary = lab.call("command_come_here") as Dictionary
	_expect(bool(come_result.get("ok", false)), "Come Here temporarily overrides Stay")
	for _frame: int in range(260):
		await get_tree().physics_frame
	var come_data: Dictionary = animal.get_companion_command_data()
	_expect(animal.global_position.distance_to(player.global_position) < 3.0, "Come Here brings the companion to Grace")
	_expect(str(come_data.get("last_completed_command_id", "")) == "come_here", "Come Here reports command completion")
	_expect(str(come_data.get("command_id", "")) == "stay", "Come Here completes into a new Stay anchor")

	var marker: Vector3 = lab.call("get_command_marker_position") as Vector3
	var move_result: Dictionary = lab.call("command_go_to_marker") as Dictionary
	_expect(bool(move_result.get("ok", false)), "Go There accepts a world destination")
	for _frame: int in range(360):
		await get_tree().physics_frame
	var marker_data: Dictionary = animal.get_companion_command_data()
	_expect(animal.global_position.distance_to(marker) < 1.6, "Go There reaches the course marker")
	_expect(str(marker_data.get("last_completed_command_id", "")) == "move_to", "Go There reports command completion")
	_expect(str(marker_data.get("command_id", "")) == "stay", "Go There completes into Stay at the destination")

	lab.call("command_follow")
	lab.call("trigger_command_fear")
	await get_tree().physics_frame
	var fear_data: Dictionary = animal.get_companion_command_data()
	_expect(str(fear_data.get("command_id", "")) == "follow", "fear retains the underlying Follow command")
	_expect(bool(fear_data.get("suspended", false)), "fear suspends command execution")
	lab.call("clear_command_fear")
	await get_tree().physics_frame
	var resumed_data: Dictionary = animal.get_companion_command_data()
	_expect(not bool(resumed_data.get("suspended", true)), "clearing fear resumes command authority")
	_expect(str(resumed_data.get("command_id", "")) == "follow", "the retained command resumes after fear")

	animal.global_position = Vector3(2.0, 0.48, 6.0)
	var persistent_stay: Dictionary = animal.issue_stay_command(animal.global_position, true)
	var saved_anchor: Vector3 = persistent_stay.get("anchor", animal.global_position) as Vector3
	animal.issue_follow_command(true)
	var loaded: bool = animal.reload_persistent_state()
	var loaded_data: Dictionary = animal.get_companion_command_data()
	_expect(loaded, "saved command record reloads")
	_expect(str(loaded_data.get("command_id", "")) == "follow", "most recently saved command is restored")
	animal.issue_stay_command(saved_anchor, true)
	animal.issue_follow_command(false)
	animal.reload_persistent_state()
	loaded_data = animal.get_companion_command_data()
	_expect(str(loaded_data.get("command_id", "")) == "stay", "persistent Stay survives an unsaved temporary command change")
	var restored_anchor: Vector3 = loaded_data.get("anchor", Vector3.ZERO) as Vector3
	_expect(restored_anchor.distance_to(saved_anchor) < 0.05, "persistent Stay anchor round-trips through the bond store")

	await _finish(lab, animal)


func _wait_for_navigation(lab: Node, maximum_frames: int) -> void:
	for _frame: int in range(maximum_frames):
		if bool(lab.call("is_navigation_ready")):
			return
		await get_tree().physics_frame


func _finish(lab: Node, animal: WildlifeAnimalScript) -> void:
	if animal != null and is_instance_valid(animal):
		animal.clear_persistent_bond()
		animal.persistent_animal_id = ""
	if lab != null and is_instance_valid(lab):
		lab.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("COMPANION_COMMAND_AUTHORITY_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("COMPANION_COMMAND_AUTHORITY_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
