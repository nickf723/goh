extends "res://scripts/visuals/grace_production_presentation_controller.gd"
class_name GraceProductionPresentationControllerV2

@export_group("Runtime Visual Acceptance")
@export_range(0.05, 1.0, 0.05) var geometry_validation_delay: float = 0.25
@export_range(0.5, 2.0, 0.05) var minimum_visible_geometry_span: float = 1.3
@export var fall_back_from_collapsed_geometry: bool = true

var geometry_validation_remaining: float = 0.0
var geometry_validation_complete: bool = false
var last_visible_geometry_span: float = 0.0
var collapsed_geometry_rejected: bool = false


func _ready() -> void:
	super._ready()
	_reset_geometry_validation()


func _process(delta: float) -> void:
	super._process(delta)
	_validate_imported_geometry(maxf(delta, 0.0))


func install_imported_scene(scene: PackedScene) -> bool:
	var installed: bool = super.install_imported_scene(scene)
	_reset_geometry_validation()
	return installed


func activate_imported(require_production_ready: bool = false) -> bool:
	var activated: bool = super.activate_imported(require_production_ready)
	if activated:
		_reset_geometry_validation()
	return activated


func _reset_geometry_validation() -> void:
	geometry_validation_remaining = maxf(geometry_validation_delay, 0.05)
	geometry_validation_complete = false
	last_visible_geometry_span = 0.0
	collapsed_geometry_rejected = false


func _validate_imported_geometry(delta: float) -> void:
	if geometry_validation_complete or active_presentation != "imported":
		return
	geometry_validation_remaining -= delta
	if geometry_validation_remaining > 0.0:
		return
	geometry_validation_complete = true
	if imported_instance == null or not imported_instance.has_method("get_debug_data"):
		return
	var data: Dictionary = imported_instance.call("get_debug_data") as Dictionary
	if not bool(data.get("direct_bone_follow", false)):
		return
	last_visible_geometry_span = float(data.get("follower_span", 0.0))
	if last_visible_geometry_span >= minimum_visible_geometry_span:
		return
	collapsed_geometry_rejected = true
	push_error(
		"GraceProductionPresentation: imported geometry span collapsed to "
		+ str(snappedf(last_visible_geometry_span, 0.001))
		+ "m; restoring the proven procedural presentation."
	)
	if fall_back_from_collapsed_geometry:
		activate_procedural()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["production_presentation_v2"] = true
	data["geometry_validation_complete"] = geometry_validation_complete
	data["visible_geometry_span"] = snappedf(last_visible_geometry_span, 0.001)
	data["collapsed_geometry_rejected"] = collapsed_geometry_rejected
	data["minimum_visible_geometry_span"] = minimum_visible_geometry_span
	return data
