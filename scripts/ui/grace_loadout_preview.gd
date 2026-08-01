extends Control
class_name GraceLoadoutPreview

const DEFAULT_ACCENT: Color = Color(1.0, 0.7, 0.2, 1.0)
const NEUTRAL_METAL: Color = Color(0.78, 0.84, 0.94, 1.0)

var weapon_id: String = ""
var outfit_id: String = ""
var charm_id: String = ""
var relic_id: String = ""
var infusion_id: String = "none"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(360.0, 338.0)
	queue_redraw()


func configure(equipment: Dictionary, new_infusion_id: String) -> void:
	weapon_id = str(equipment.get("weapon", ""))
	outfit_id = str(equipment.get("outfit", ""))
	charm_id = str(equipment.get("charm", ""))
	relic_id = str(equipment.get("relic", ""))
	infusion_id = new_infusion_id
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = Vector2(size.x * 0.5, size.y * 0.47)
	var floor_y: float = size.y - 28.0
	var accent: Color = _get_infusion_color()
	var glow: Color = accent
	glow.a = 0.12

	draw_circle(center + Vector2(0.0, 18.0), 132.0, Color(0.025, 0.035, 0.052, 0.92))
	draw_circle(center + Vector2(0.0, 18.0), 126.0, glow)
	draw_arc(center + Vector2(0.0, 18.0), 126.0, 0.0, TAU, 96, Color(accent.r, accent.g, accent.b, 0.5), 2.0, true)
	draw_line(Vector2(48.0, floor_y), Vector2(size.x - 48.0, floor_y), Color(0.45, 0.52, 0.68, 0.38), 2.0, true)

	_draw_legs(center, floor_y)
	_draw_outfit(center)
	_draw_arms(center)
	_draw_head(center)
	_draw_weapon(center, accent)
	_draw_accessories(center, accent)


func _draw_legs(center: Vector2, floor_y: float) -> void:
	var leg_color: Color = Color(0.08, 0.105, 0.15, 1.0)
	var boot_color: Color = Color(0.045, 0.052, 0.072, 1.0)
	var hip_y: float = center.y + 80.0
	draw_line(Vector2(center.x - 22.0, hip_y), Vector2(center.x - 30.0, floor_y - 18.0), leg_color, 19.0, true)
	draw_line(Vector2(center.x + 22.0, hip_y), Vector2(center.x + 30.0, floor_y - 18.0), leg_color, 19.0, true)
	draw_line(Vector2(center.x - 40.0, floor_y - 10.0), Vector2(center.x - 19.0, floor_y - 10.0), boot_color, 13.0, true)
	draw_line(Vector2(center.x + 19.0, floor_y - 10.0), Vector2(center.x + 40.0, floor_y - 10.0), boot_color, 13.0, true)


func _draw_outfit(center: Vector2) -> void:
	var outfit_color: Color = _get_outfit_color()
	var trim_color: Color = outfit_color.lightened(0.22)
	var shoulder_y: float = center.y - 22.0
	var torso_points: PackedVector2Array = PackedVector2Array([
		Vector2(center.x - 54.0, shoulder_y),
		Vector2(center.x - 70.0, center.y + 92.0),
		Vector2(center.x + 70.0, center.y + 92.0),
		Vector2(center.x + 54.0, shoulder_y),
	])
	draw_colored_polygon(torso_points, outfit_color)
	draw_line(Vector2(center.x, shoulder_y + 8.0), Vector2(center.x, center.y + 78.0), trim_color, 3.0, true)
	draw_line(Vector2(center.x - 52.0, center.y + 50.0), Vector2(center.x + 52.0, center.y + 50.0), trim_color.darkened(0.15), 5.0, true)
	if outfit_id == "ironweave_jacket":
		for y_offset: float in [-4.0, 17.0, 38.0]:
			draw_line(Vector2(center.x - 44.0, center.y + y_offset), Vector2(center.x + 44.0, center.y + y_offset), Color(0.74, 0.79, 0.86, 0.42), 2.0, true)
	elif outfit_id == "apprentice_robe":
		draw_arc(Vector2(center.x, center.y + 19.0), 25.0, 0.0, TAU, 32, Color(0.72, 0.52, 1.0, 0.72), 2.0, true)
	elif outfit_id == "travelers_coat":
		draw_line(Vector2(center.x - 42.0, center.y + 7.0), Vector2(center.x + 42.0, center.y + 7.0), Color(0.78, 0.58, 0.31, 0.72), 4.0, true)


func _draw_arms(center: Vector2) -> void:
	var sleeve: Color = _get_outfit_color().darkened(0.08)
	var skin: Color = Color(0.57, 0.35, 0.24, 1.0)
	draw_line(Vector2(center.x - 51.0, center.y - 8.0), Vector2(center.x - 85.0, center.y + 54.0), sleeve, 18.0, true)
	draw_line(Vector2(center.x + 51.0, center.y - 8.0), Vector2(center.x + 85.0, center.y + 54.0), sleeve, 18.0, true)
	draw_circle(Vector2(center.x - 88.0, center.y + 60.0), 10.0, skin)
	draw_circle(Vector2(center.x + 88.0, center.y + 60.0), 10.0, skin)


func _draw_head(center: Vector2) -> void:
	var head_center: Vector2 = center + Vector2(0.0, -76.0)
	var skin: Color = Color(0.57, 0.35, 0.24, 1.0)
	var hair: Color = Color(0.055, 0.045, 0.05, 1.0)
	for offset: Vector2 in [
		Vector2(-25.0, -22.0), Vector2(0.0, -31.0), Vector2(25.0, -22.0),
		Vector2(-32.0, 0.0), Vector2(32.0, 0.0), Vector2(-26.0, 26.0), Vector2(26.0, 26.0),
	]:
		draw_circle(head_center + offset, 23.0, hair)
	draw_circle(head_center, 37.0, skin)
	draw_circle(head_center + Vector2(-13.0, -3.0), 3.8, Color(0.82, 0.93, 1.0, 1.0))
	draw_circle(head_center + Vector2(13.0, -3.0), 3.8, Color(0.82, 0.93, 1.0, 1.0))
	draw_line(head_center + Vector2(-10.0, 18.0), head_center + Vector2(10.0, 18.0), Color(0.34, 0.12, 0.12, 1.0), 2.0, true)


func _draw_weapon(center: Vector2, accent: Color) -> void:
	if weapon_id == "":
		return
	var hand: Vector2 = center + Vector2(88.0, 60.0)
	var weapon_color: Color = accent if infusion_id != "none" else NEUTRAL_METAL
	var weapon_glow: Color = weapon_color
	weapon_glow.a = 0.24
	match weapon_id:
		"training_hammer":
			var end: Vector2 = hand + Vector2(54.0, -88.0)
			draw_line(hand, end, Color(0.28, 0.18, 0.1, 1.0), 8.0, true)
			draw_line(end + Vector2(-24.0, 0.0), end + Vector2(24.0, 0.0), weapon_glow, 24.0, true)
			draw_line(end + Vector2(-24.0, 0.0), end + Vector2(24.0, 0.0), weapon_color, 15.0, true)
		"training_spear":
			var end: Vector2 = hand + Vector2(40.0, -150.0)
			draw_line(hand + Vector2(-18.0, 68.0), end, Color(0.34, 0.21, 0.1, 1.0), 6.0, true)
			var tip: PackedVector2Array = PackedVector2Array([end + Vector2(0.0, -18.0), end + Vector2(-10.0, 5.0), end + Vector2(10.0, 5.0)])
			draw_colored_polygon(tip, weapon_color)
		_:
			var end: Vector2 = hand + Vector2(46.0, -104.0)
			draw_line(hand + Vector2(-10.0, 22.0), end, weapon_glow, 13.0, true)
			draw_line(hand + Vector2(-10.0, 22.0), end, weapon_color, 7.0, true)
			draw_line(hand + Vector2(-16.0, 14.0), hand + Vector2(5.0, 34.0), Color(0.78, 0.58, 0.22, 1.0), 6.0, true)


func _draw_accessories(center: Vector2, accent: Color) -> void:
	if charm_id != "":
		var charm_position: Vector2 = center + Vector2(0.0, -22.0)
		draw_circle(charm_position, 9.0, Color(0.025, 0.03, 0.045, 1.0))
		draw_arc(charm_position, 9.0, 0.0, TAU, 24, accent, 2.0, true)
	if relic_id != "":
		var relic_position: Vector2 = center + Vector2(-52.0, 56.0)
		var relic_points: PackedVector2Array = PackedVector2Array([
			relic_position + Vector2(0.0, -11.0),
			relic_position + Vector2(10.0, 0.0),
			relic_position + Vector2(0.0, 11.0),
			relic_position + Vector2(-10.0, 0.0),
		])
		draw_colored_polygon(relic_points, accent.lightened(0.12))


func _get_outfit_color() -> Color:
	match outfit_id:
		"travelers_coat":
			return Color(0.16, 0.23, 0.31, 1.0)
		"apprentice_robe":
			return Color(0.24, 0.13, 0.39, 1.0)
		"ironweave_jacket":
			return Color(0.25, 0.29, 0.34, 1.0)
		_:
			return Color(0.075, 0.11, 0.17, 1.0)


func _get_infusion_color() -> Color:
	match infusion_id:
		"fire":
			return Color(1.0, 0.3, 0.08, 1.0)
		"ice":
			return Color(0.35, 0.88, 1.0, 1.0)
		"lightning":
			return Color(0.6, 0.46, 1.0, 1.0)
		"poison":
			return Color(0.46, 0.96, 0.2, 1.0)
		_:
			return DEFAULT_ACCENT
