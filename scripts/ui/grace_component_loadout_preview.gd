extends "res://scripts/ui/grace_loadout_preview.gd"
class_name GraceComponentLoadoutPreview

var headwear_id: String = ""
var gloves_id: String = ""
var footwear_id: String = ""


func configure(equipment: Dictionary, new_infusion_id: String) -> void:
	headwear_id = str(equipment.get("headwear", ""))
	gloves_id = str(equipment.get("gloves", ""))
	footwear_id = str(equipment.get("footwear", ""))
	super.configure(equipment, new_infusion_id)


func _draw() -> void:
	super._draw()
	var center: Vector2 = Vector2(size.x * 0.5, size.y * 0.47)
	var floor_y: float = size.y - 28.0
	_draw_headwear_component(center)
	_draw_glove_components(center)
	_draw_footwear_components(center, floor_y)


func _draw_headwear_component(center: Vector2) -> void:
	if headwear_id == "":
		return
	var head_center: Vector2 = center + Vector2(0.0, -79.0)
	var cloth: Color = Color(0.18, 0.28, 0.42, 1.0)
	if headwear_id == "scholars_cap":
		cloth = Color(0.32, 0.18, 0.52, 1.0)
		draw_colored_polygon(PackedVector2Array([
			head_center + Vector2(-42.0, -12.0),
			head_center + Vector2(0.0, -35.0),
			head_center + Vector2(42.0, -12.0),
			head_center + Vector2(30.0, 1.0),
			head_center + Vector2(-30.0, 1.0),
		]), cloth)
		draw_line(head_center + Vector2(0.0, -34.0), head_center + Vector2(38.0, -27.0), cloth.lightened(0.24), 3.0, true)
		return
	draw_arc(head_center, 41.0, PI, TAU, 32, cloth, 13.0, true)
	draw_line(head_center + Vector2(-39.0, 0.0), head_center + Vector2(39.0, 0.0), cloth.lightened(0.18), 4.0, true)
	draw_line(head_center + Vector2(34.0, -2.0), head_center + Vector2(50.0, 22.0), cloth, 8.0, true)


func _draw_glove_components(center: Vector2) -> void:
	if gloves_id == "":
		return
	var glove_color: Color = Color(0.2, 0.16, 0.14, 1.0)
	if gloves_id == "iron_grip_gloves":
		glove_color = Color(0.42, 0.48, 0.58, 1.0)
	for side: float in [-1.0, 1.0]:
		var hand: Vector2 = center + Vector2(83.0 * side, 48.0)
		draw_circle(hand, 12.0, glove_color)
		draw_line(hand + Vector2(-8.0 * side, -8.0), hand + Vector2(-17.0 * side, -21.0), glove_color.lightened(0.14), 8.0, true)
		if gloves_id == "iron_grip_gloves":
			draw_arc(hand, 12.0, 0.0, TAU, 20, Color(0.8, 0.86, 0.95, 0.72), 2.0, true)


func _draw_footwear_components(center: Vector2, floor_y: float) -> void:
	if footwear_id == "":
		return
	var boot_color: Color = Color(0.12, 0.09, 0.08, 1.0)
	var accent: Color = Color(0.42, 0.29, 0.17, 1.0)
	if footwear_id == "windstep_boots":
		boot_color = Color(0.11, 0.2, 0.32, 1.0)
		accent = Color(0.42, 0.82, 1.0, 1.0)
	for side: float in [-1.0, 1.0]:
		var ankle: Vector2 = Vector2(center.x + 30.0 * side, floor_y - 24.0)
		draw_line(ankle + Vector2(0.0, -23.0), ankle, boot_color, 18.0, true)
		draw_line(ankle, ankle + Vector2(19.0 * side, 7.0), boot_color, 15.0, true)
		draw_line(ankle + Vector2(-7.0 * side, -14.0), ankle + Vector2(8.0 * side, -8.0), accent, 3.0, true)
