extends "res://scripts/levels/ruined_village_outdoor_remaster_pass_legacy.gd"
class_name RuinedVillageOutdoorRemasterPass

const StylizedPBRMaterialLibrary = preload(
	"res://scripts/environment/stylized_pbr_material_library.gd"
)

@export var use_stylized_pbr_surface: bool = true

var stylized_pbr_result: Dictionary = {}
var stylized_pbr_applied: bool = false
var stylized_pbr_settle_frames: int = 1

# Child _ready() runs before the procedural village root has created its
# GeneratedGeometry and GeneratedDetails children. The legacy pass retried with
# call_deferred(), which could exhaust every attempt in one idle cycle on a cold
# import. Retry once per process frame instead so the parent has time to build.
#
# Once composition finishes, wait one further frame before replacing materials.
# This lets every modular piece finish its own procedural visual build and keeps
# the rollout bounded to OutdoorRemasterV1.


func _ready() -> void:
	add_to_group("ruined_village_outdoor_remaster_pass")
	set_process(true)


func _process(_delta: float) -> void:
	if not installed:
		_install()
	if not installed:
		return
	if stylized_pbr_settle_frames > 0:
		stylized_pbr_settle_frames -= 1
		return
	if not stylized_pbr_applied:
		_apply_stylized_pbr_surface()
	if stylized_pbr_applied:
		set_process(false)


func _apply_stylized_pbr_surface() -> void:
	if remaster_root == null:
		return

	var validation_failures: Array[String] = (
		StylizedPBRMaterialLibrary.validate_library()
	)
	stylized_pbr_result = {
		"enabled": use_stylized_pbr_surface,
		"profile": "global_surface_v1",
		"total": 0,
		"families": {},
		"unmapped": 0,
		"validation_errors": validation_failures.duplicate(),
	}
	if use_stylized_pbr_surface and validation_failures.is_empty():
		var apply_result: Dictionary = (
			StylizedPBRMaterialLibrary.apply_to_subtree(remaster_root)
		)
		stylized_pbr_result["total"] = int(
			apply_result.get("total", 0)
		)
		stylized_pbr_result["families"] = (
			apply_result.get("families", {}) as Dictionary
		).duplicate()
		stylized_pbr_result["unmapped"] = int(
			apply_result.get("unmapped", 0)
		)

	for failure: String in validation_failures:
		push_error("Ruined Village stylized PBR: " + failure)

	remaster_root.add_to_group("stylized_pbr_environment_rollout")
	remaster_root.set_meta(
		"stylized_pbr_result",
		stylized_pbr_result.duplicate(true)
	)
	remaster_root.set_meta(
		"stylized_pbr_profile",
		str(stylized_pbr_result.get("profile", ""))
	)
	remaster_root.set_meta(
		"stylized_pbr_enabled",
		bool(stylized_pbr_result.get("enabled", false))
	)
	stylized_pbr_applied = true


func get_debug_data() -> Dictionary:
	var result: Dictionary = super.get_debug_data()
	result["stylized_pbr"] = stylized_pbr_result.duplicate(true)
	return result
