extends Resource
class_name EncounterDefinition

@export var encounter_id: String = "encounter"
@export var display_name: String = "Encounter"
@export_multiline var description: String = ""
@export var activation_radius: float = 16.0
@export var objective_on_start: String = "Defeat the enemies."
@export var objective_on_complete: String = "The route is clear."
@export var completion_message: String = "Encounter cleared."
@export var completion_flag: String = ""
@export var reward_mana: int = 0
@export var enemy_scenes: Array[PackedScene] = []
@export var spawn_positions: Array[Vector3] = []
@export var spawn_rotations_degrees: Array[Vector3] = []


func validate_definition() -> Array[String]:
	var errors: Array[String] = []

	if encounter_id.strip_edges() == "":
		errors.append("encounter_id is empty")

	if enemy_scenes.is_empty():
		errors.append(encounter_id + " has no enemy scenes")

	if spawn_positions.size() != enemy_scenes.size():
		errors.append(
			encounter_id
			+ " enemy/spawn count mismatch: "
			+ str(enemy_scenes.size())
			+ " scenes vs "
			+ str(spawn_positions.size())
			+ " positions"
		)

	if not spawn_rotations_degrees.is_empty() and spawn_rotations_degrees.size() != enemy_scenes.size():
		errors.append(
			encounter_id
			+ " rotation count must be zero or match enemy count"
		)

	for index: int in range(enemy_scenes.size()):
		if enemy_scenes[index] == null:
			errors.append(encounter_id + " has a null enemy scene at index " + str(index))

	return errors


func get_spawn_rotation(index: int) -> Vector3:
	if index < 0 or index >= spawn_rotations_degrees.size():
		return Vector3.ZERO
	return spawn_rotations_degrees[index]


func get_debug_summary() -> String:
	return (
		display_name
		+ " • enemies="
		+ str(enemy_scenes.size())
		+ " • radius="
		+ str(snapped(activation_radius, 0.1))
	)
