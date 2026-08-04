extends "res://scripts/levels/prototype_recorded_object_lab_integrated.gd"
class_name PrototypeRecordedObjectLabUnified

var unified_hud: Node
var lab_hud_suppressed: bool = false


func _build_hud() -> void:
	super._build_hud()
	_resolve_unified_hud()
	_suppress_lab_overlay()
	_publish_lab_mode()


func _refresh_hud() -> void:
	super._refresh_hud()
	_resolve_unified_hud()
	_suppress_lab_overlay()
	_publish_lab_mode()


func _create_label(
	text: String,
	position_value: Vector3,
	color: Color,
	font_size: int,
	parent_override: Node = null
) -> Label3D:
	var compact_size: int = maxi(int(round(float(font_size) * 0.68)), 13)
	var label: Label3D = super._create_label(
		text,
		position_value,
		color,
		compact_size,
		parent_override
	)
	label.pixel_size = 0.006
	label.outline_size = 6
	return label


func _resolve_unified_hud() -> void:
	if unified_hud != null and is_instance_valid(unified_hud):
		return
	unified_hud = get_tree().get_first_node_in_group("unified_hud_shell")
	if unified_hud != null:
		return
	if player != null and is_instance_valid(player):
		unified_hud = player.get_node_or_null("PlayerHUDV2")
		if unified_hud != null and not unified_hud.has_method("publish_mode"):
			unified_hud = null


func _suppress_lab_overlay() -> void:
	if hud_layer == null:
		return
	if unified_hud == null:
		hud_layer.visible = true
		lab_hud_suppressed = false
		return
	hud_layer.visible = false
	lab_hud_suppressed = true


func _publish_lab_mode() -> void:
	if unified_hud == null or not unified_hud.has_method("publish_mode"):
		return
	var selected_id: String = Catalog.get_selected_blueprint_id()
	var selected_name: String = "No blueprint prepared"
	if selected_id != "":
		var definition: Dictionary = Catalog.get_definition(selected_id)
		selected_name = str(definition.get(
			"display_name",
			selected_id.capitalize()
		))
	var active_count: int = manager.get_active_count() if manager != null else 0
	unified_hud.call(
		"publish_mode",
		"recorded_object_lab",
		{
			"eyebrow": "ELEMENTAL INTEROPERABILITY",
			"title": "Recorded Object Proving Ground",
			"detail": selected_name + "  •  " + str(active_count) + " active",
			"accent": Color(0.34, 0.78, 1.0),
		},
		15
	)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["unified_hud"] = unified_hud != null and is_instance_valid(unified_hud)
	data["lab_hud_suppressed"] = lab_hud_suppressed
	data["compact_world_labels"] = true
	return data
