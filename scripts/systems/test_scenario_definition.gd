extends Resource
class_name TestScenarioDefinition

@export var scenario_id: String = "scenario"
@export var display_name: String = "Test Scenario"
@export_multiline var description: String = ""
@export_multiline var expected_result: String = ""
@export var recommended_ability_name: String = ""
@export var enemy_ids: Array[String] = []
@export var prop_scenes: Array[PackedScene] = []
@export var prop_offsets: Array[Vector3] = []


func get_prop_offset(index: int) -> Vector3:
	if index >= 0 and index < prop_offsets.size():
		return prop_offsets[index]

	return Vector3.ZERO


func get_guidance_text() -> String:
	var lines: Array[String] = [display_name]

	if description != "":
		lines.append(description)

	if recommended_ability_name != "":
		lines.append("Recommended: " + recommended_ability_name)

	if expected_result != "":
		lines.append("Expected: " + expected_result)

	return "\n".join(lines)
