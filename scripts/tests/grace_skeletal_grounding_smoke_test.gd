extends Node

const SkeletalGraceScene: PackedScene = preload(
	"res://scenes/actors/player/grace_humanoid_skeletal_proxy_v1.tscn"
)

var failures: Array[String] = []


func _ready() -> void:
	var rig: Node = SkeletalGraceScene.instantiate()
	add_child(rig)
	await get_tree().process_frame

	var data: Dictionary = {}
	if rig != null and rig.has_method("get_debug_data"):
		data = rig.call("get_debug_data") as Dictionary
	else:
		failures.append("skeletal Grace exposes debug data")

	_expect(bool(data.get("grounding_fix", false)), "grounding correction is active")
	_expect(bool(data.get("rest_pose_initialized", false)), "child bone pose translations initialize from rest")
	_expect(bool(data.get("pelvis_rest_preserved", false)), "pelvis animation preserves authored rest height")
	_expect(bool(data.get("weapon_language_v2", false)), "skeletal Grace owns diversified weapon language layer")
	var language_classes: Array = data.get("authored_language_classes", []) as Array
	for weapon_class: String in ["sword", "hammer", "lance", "daggers"]:
		_expect(language_classes.has(weapon_class), weapon_class + " has authored skeletal combat language")

	var foot_height: float = float(data.get("foot_height", 999.0))
	var span: float = float(data.get("head_to_foot_span", 0.0))
	var hand_span: float = float(data.get("hand_span", 0.0))
	var leg_span: float = float(data.get("leg_span", 0.0))
	_expect(absf(foot_height) < 0.16, "feet remain near the skeletal ground plane")
	_expect(span > 1.45, "head remains a full humanoid height above the feet")
	_expect(hand_span > 0.55, "left and right hands remain separated by articulated arms")
	_expect(leg_span > 0.6, "thigh-to-foot chain preserves articulated leg length")

	if rig != null and is_instance_valid(rig):
		rig.queue_free()
	await get_tree().process_frame
	_finish()


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("GRACE_SKELETAL_GROUNDING_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("GRACE_SKELETAL_GROUNDING_SMOKE_TEST: " + failure)
	get_tree().quit(1)
