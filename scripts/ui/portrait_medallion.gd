extends Control
class_name PortraitMedallion


@export var display_name: String = "Grace"
@export var accent_color: Color = Color(0.96, 0.68, 0.24, 1.0)
@export var skin_color: Color = Color(0.57, 0.35, 0.24, 1.0)
@export var hair_color: Color = Color(0.055, 0.045, 0.05, 1.0)
@export var expression: String = "neutral"
@export var is_grace: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A parent surface may deliberately request a compact portrait before the
	# node enters the tree. Only apply the medallion default when no size was
	# supplied, otherwise the portrait can force its entire HUD lane off-screen.
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(168.0, 168.0)
	queue_redraw()


func configure(
	new_name: String,
	new_accent: Color,
	new_expression: String = "neutral",
	grace_portrait: bool = true
) -> void:
	display_name = new_name
	accent_color = new_accent
	expression = new_expression
	is_grace = grace_portrait
	if not grace_portrait:
		skin_color = new_accent.lightened(0.28).lerp(
			Color(0.62, 0.42, 0.3, 1.0),
			0.55
		)
		hair_color = new_accent.darkened(0.72)
	else:
		skin_color = Color(0.57, 0.35, 0.24, 1.0)
		hair_color = Color(0.055, 0.045, 0.05, 1.0)
	queue_redraw()


func set_expression(value: String) -> void:
	if expression == value:
		return
	expression = value
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = maxf(minf(size.x, size.y) * 0.5 - 5.0, 8.0)
	var glow: Color = accent_color
	glow.a = 0.22

	draw_circle(center, radius + 4.0, Color(0.0, 0.0, 0.0, 0.62))
	draw_circle(center, radius + 1.0, glow)
	draw_arc(center, radius, 0.0, TAU, 96, accent_color, 3.0, true)
	draw_arc(
		center,
		radius - 6.0,
		0.0,
		TAU,
		96,
		Color(accent_color.r, accent_color.g, accent_color.b, 0.42),
		1.0,
		true
	)
	draw_circle(center, radius - 9.0, Color(0.018, 0.022, 0.032, 0.96))

	_draw_shoulders(center, radius)
	_draw_hair(center, radius)
	_draw_face(center, radius)
	_draw_expression(center, radius)
	_draw_badge(center, radius)


func _draw_shoulders(center: Vector2, radius: float) -> void:
	var shoulder_color: Color = (
		Color(0.08, 0.11, 0.16, 1.0)
		if is_grace
		else accent_color.darkened(0.62)
	)
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(-radius * 0.68, radius * 0.66),
		center + Vector2(-radius * 0.42, radius * 0.34),
		center + Vector2(0.0, radius * 0.25),
		center + Vector2(radius * 0.42, radius * 0.34),
		center + Vector2(radius * 0.68, radius * 0.66),
	])
	draw_colored_polygon(points, shoulder_color)


func _draw_hair(center: Vector2, radius: float) -> void:
	var head_center: Vector2 = center + Vector2(0.0, -radius * 0.08)
	var hair_radius: float = radius * 0.48
	for offset: Vector2 in [
		Vector2(-0.28, -0.22),
		Vector2(0.0, -0.34),
		Vector2(0.28, -0.22),
		Vector2(-0.38, 0.04),
		Vector2(0.38, 0.04),
		Vector2(-0.34, 0.3),
		Vector2(0.34, 0.3),
	]:
		draw_circle(
			head_center + offset * hair_radius,
			hair_radius * 0.58,
			hair_color
		)


func _draw_face(center: Vector2, radius: float) -> void:
	var head_center: Vector2 = center + Vector2(0.0, -radius * 0.02)
	draw_set_transform(head_center, 0.0, Vector2(0.78, 1.03))
	draw_circle(Vector2.ZERO, radius * 0.43, skin_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var neck_color: Color = skin_color.darkened(0.08)
	var neck: Rect2 = Rect2(
		center.x - radius * 0.13,
		center.y + radius * 0.29,
		radius * 0.26,
		radius * 0.27
	)
	draw_rect(neck, neck_color)

	var nose_color: Color = skin_color.lightened(0.12)
	draw_line(
		center + Vector2(0.0, -radius * 0.03),
		center + Vector2(-radius * 0.025, radius * 0.13),
		nose_color,
		1.5,
		true
	)


func _draw_expression(center: Vector2, radius: float) -> void:
	var eye_y: float = center.y - radius * 0.07
	var eye_dx: float = radius * 0.18
	var eye_color: Color = Color(0.82, 0.93, 1.0, 1.0)
	var brow_color: Color = hair_color.lightened(0.15)
	var mouth_color: Color = Color(0.35, 0.12, 0.12, 1.0)

	if expression == "burning":
		eye_color = Color(1.0, 0.58, 0.16, 1.0)
	elif expression == "poisoned":
		eye_color = Color(0.58, 1.0, 0.34, 1.0)
	elif expression == "chilled":
		eye_color = Color(0.52, 0.9, 1.0, 1.0)

	var eye_radius: float = radius * (0.045 if expression != "attentive" else 0.058)
	draw_circle(Vector2(center.x - eye_dx, eye_y), eye_radius, eye_color)
	draw_circle(Vector2(center.x + eye_dx, eye_y), eye_radius, eye_color)
	draw_circle(Vector2(center.x - eye_dx, eye_y), eye_radius * 0.42, Color(0.02, 0.025, 0.035, 1.0))
	draw_circle(Vector2(center.x + eye_dx, eye_y), eye_radius * 0.42, Color(0.02, 0.025, 0.035, 1.0))

	var brow_tilt: float = 0.0
	if expression in ["focused", "burning", "low_health"]:
		brow_tilt = radius * 0.05
	elif expression in ["poisoned", "chilled"]:
		brow_tilt = -radius * 0.025
	draw_line(
		Vector2(center.x - eye_dx - radius * 0.09, eye_y - radius * 0.1 + brow_tilt),
		Vector2(center.x - eye_dx + radius * 0.09, eye_y - radius * 0.1 - brow_tilt),
		brow_color,
		3.0,
		true
	)
	draw_line(
		Vector2(center.x + eye_dx - radius * 0.09, eye_y - radius * 0.1 - brow_tilt),
		Vector2(center.x + eye_dx + radius * 0.09, eye_y - radius * 0.1 + brow_tilt),
		brow_color,
		3.0,
		true
	)

	var mouth_y: float = center.y + radius * 0.23
	match expression:
		"attentive":
			draw_arc(Vector2(center.x, mouth_y), radius * 0.11, 0.12, PI - 0.12, 20, mouth_color, 2.0, true)
		"low_health", "poisoned", "chilled":
			draw_arc(Vector2(center.x, mouth_y + radius * 0.07), radius * 0.12, PI + 0.18, TAU - 0.18, 20, mouth_color, 2.0, true)
		"burning":
			draw_circle(Vector2(center.x, mouth_y), radius * 0.065, mouth_color)
		_:
			draw_line(
				Vector2(center.x - radius * 0.12, mouth_y),
				Vector2(center.x + radius * 0.12, mouth_y),
				mouth_color,
				2.0,
				true
			)


func _draw_badge(center: Vector2, radius: float) -> void:
	var badge_center: Vector2 = center + Vector2(radius * 0.68, -radius * 0.62)
	draw_circle(badge_center, radius * 0.17, Color(0.015, 0.018, 0.026, 0.98))
	draw_arc(badge_center, radius * 0.17, 0.0, TAU, 32, accent_color, 2.0, true)
	draw_line(
		badge_center + Vector2(0.0, -radius * 0.08),
		badge_center + Vector2(0.0, radius * 0.08),
		accent_color,
		2.0,
		true
	)
	draw_line(
		badge_center + Vector2(-radius * 0.07, 0.0),
		badge_center + Vector2(radius * 0.07, 0.0),
		accent_color,
		2.0,
		true
	)
