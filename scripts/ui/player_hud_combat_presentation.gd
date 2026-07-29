extends Node
class_name PlayerHUDCombatPresentation


@export_range(0.05, 1.0, 0.05) var fade_speed: float = 6.0
@export_range(0.0, 1.0, 0.05) var target_warning_start_ratio: float = 0.82

var actor: CharacterBody3D
var hud: PlayerHUDV2
var stealth_controller: PlayerStealthController
var targeting_assist: CombatTargetingAssist
var avatar_manager: Node

var crouch_panel: PanelContainer
var crouch_icon_label: Label
var crouch_state_label: Label
var crouch_noise_bar: ProgressBar
var crouch_alpha: float = 0.0
var setup_complete: bool = false
var last_target_warning: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	actor = get_parent() as CharacterBody3D
	call_deferred("_finish_setup")
	add_to_group("player_hud_combat_presentation")


func _finish_setup() -> void:
	_resolve_bindings()
	if hud == null:
		call_deferred("_finish_setup")
		return
	_tone_down_stats()
	_build_crouch_indicator()
	_decorate_target_markers()
	setup_complete = true


func _process(delta: float) -> void:
	_resolve_bindings()
	if not setup_complete:
		_finish_setup()
		return
	_tone_down_stats()
	_suppress_legacy_stealth_indicator()
	_refresh_crouch_indicator(delta)
	_decorate_target_markers()
	_refresh_hard_target_warning()


func _resolve_bindings() -> void:
	if actor == null or not is_instance_valid(actor):
		actor = get_parent() as CharacterBody3D
	if actor == null:
		return
	if hud == null or not is_instance_valid(hud):
		hud = actor.get_node_or_null("PlayerHUDV2") as PlayerHUDV2
	if stealth_controller == null or not is_instance_valid(stealth_controller):
		stealth_controller = actor.get_node_or_null(
			"StealthController"
		) as PlayerStealthController
	if targeting_assist == null or not is_instance_valid(targeting_assist):
		targeting_assist = actor.get_node_or_null(
			"CombatTargetingAssist"
		) as CombatTargetingAssist
	if avatar_manager == null or not is_instance_valid(avatar_manager):
		avatar_manager = actor.get_node_or_null("AvatarManager")


func _tone_down_stats() -> void:
	if hud == null:
		return
	if hud.stats_panel != null:
		hud.stats_panel.offset_right = 420.0
		hud.stats_panel.offset_bottom = 202.0
	if hud.loadout_label != null:
		hud.loadout_label.visible = false
	if hud.base_stats_label != null:
		hud.base_stats_label.visible = false
	if hud.avatar_title_label != null:
		var avatar_name: String = "Grace"
		if (
			avatar_manager != null
			and avatar_manager.has_method("get_active_avatar_display_name")
		):
			avatar_name = str(
				avatar_manager.call("get_active_avatar_display_name")
			)
		hud.avatar_title_label.text = avatar_name.to_upper()
		hud.avatar_title_label.add_theme_font_size_override("font_size", 14)


func _build_crouch_indicator() -> void:
	if hud == null or hud.root == null or crouch_panel != null:
		return
	crouch_panel = PanelContainer.new()
	crouch_panel.name = "CompactCrouchIndicator"
	crouch_panel.anchor_left = 1.0
	crouch_panel.anchor_top = 1.0
	crouch_panel.anchor_right = 1.0
	crouch_panel.anchor_bottom = 1.0
	crouch_panel.offset_left = -438.0
	crouch_panel.offset_top = -82.0
	crouch_panel.offset_right = -236.0
	crouch_panel.offset_bottom = -24.0
	crouch_panel.visible = false
	crouch_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crouch_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.012, 0.02, 0.032, 0.92),
			Color(0.34, 0.66, 0.94, 0.66)
		)
	)
	hud.root.add_child(crouch_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	crouch_panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	margin.add_child(row)

	crouch_icon_label = Label.new()
	crouch_icon_label.text = "◒"
	crouch_icon_label.custom_minimum_size = Vector2(28.0, 0.0)
	crouch_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crouch_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crouch_icon_label.add_theme_font_size_override("font_size", 20)
	row.add_child(crouch_icon_label)

	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 3)
	row.add_child(stack)

	crouch_state_label = Label.new()
	crouch_state_label.text = "CROUCHED"
	crouch_state_label.add_theme_font_size_override("font_size", 11)
	stack.add_child(crouch_state_label)

	crouch_noise_bar = ProgressBar.new()
	crouch_noise_bar.min_value = 0.0
	crouch_noise_bar.max_value = 1.0
	crouch_noise_bar.value = 0.0
	crouch_noise_bar.show_percentage = false
	crouch_noise_bar.custom_minimum_size = Vector2(0.0, 5.0)
	crouch_noise_bar.add_theme_stylebox_override(
		"background",
		_make_bar_style(Color(0.045, 0.06, 0.08, 0.94))
	)
	crouch_noise_bar.add_theme_stylebox_override(
		"fill",
		_make_bar_style(Color(0.34, 0.72, 1.0, 0.94))
	)
	stack.add_child(crouch_noise_bar)


func _refresh_crouch_indicator(delta: float) -> void:
	if crouch_panel == null:
		return
	var crouched: bool = false
	var concealed: bool = false
	var noise: float = 0.0
	if stealth_controller != null:
		crouched = stealth_controller.is_crouched()
		concealed = stealth_controller.is_concealed()
		noise = clampf(float(stealth_controller.get("current_noise")), 0.0, 1.0)
	var dialogue_visible: bool = hud != null and hud.dialogue_panel != null and hud.dialogue_panel.visible
	var target_alpha: float = 1.0 if (crouched or concealed) and not dialogue_visible else 0.0
	crouch_alpha = move_toward(
		crouch_alpha,
		target_alpha,
		maxf(delta, 0.0) * fade_speed
	)
	crouch_panel.visible = crouch_alpha > 0.01
	crouch_panel.modulate.a = crouch_alpha
	if not crouch_panel.visible:
		return

	var accent: Color = (
		Color(0.36, 1.0, 0.62, 1.0)
		if concealed
		else Color(0.4, 0.78, 1.0, 1.0)
	)
	crouch_icon_label.text = "●" if concealed else "◒"
	crouch_state_label.text = "CONCEALED" if concealed else "CROUCHED"
	crouch_icon_label.add_theme_color_override("font_color", accent)
	crouch_state_label.add_theme_color_override("font_color", accent)
	crouch_noise_bar.value = noise
	crouch_noise_bar.add_theme_stylebox_override(
		"fill",
		_make_bar_style(accent)
	)
	crouch_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.012, 0.02, 0.032, 0.92),
			Color(accent.r, accent.g, accent.b, 0.62)
		)
	)


func _suppress_legacy_stealth_indicator() -> void:
	if stealth_controller == null:
		return
	var layer_value: Variant = stealth_controller.get("hud_layer")
	if layer_value is CanvasLayer:
		(layer_value as CanvasLayer).visible = false


func _decorate_target_markers() -> void:
	_decorate_soft_marker()
	_decorate_hard_marker()


func _decorate_soft_marker() -> void:
	if targeting_assist == null:
		return
	var marker_value: Variant = targeting_assist.get("soft_marker")
	if not marker_value is Node3D:
		return
	var marker: Node3D = marker_value as Node3D
	marker.set_meta("reticle_mode", "soft")
	var ring := marker.get_node_or_null("AimRing") as MeshInstance3D
	if ring != null and not bool(ring.get_meta("hud_v2_polished", false)):
		var torus := TorusMesh.new()
		torus.inner_radius = 0.205
		torus.outer_radius = 0.225
		torus.rings = 32
		torus.ring_segments = 8
		ring.mesh = torus
		ring.rotation_degrees.x = 90.0
		ring.set_meta("hud_v2_polished", true)
	if marker.get_node_or_null("CornerBrackets") != null:
		return
	var bracket_root := Node3D.new()
	bracket_root.name = "CornerBrackets"
	marker.add_child(bracket_root)
	var material: Material = null
	var material_value: Variant = targeting_assist.get("soft_marker_material")
	if material_value is Material:
		material = material_value as Material
	_add_corner_brackets(bracket_root, material, 0.31, 0.13, 0.025)


func _decorate_hard_marker() -> void:
	if actor == null:
		return
	var marker_value: Variant = actor.get("lock_on_marker")
	if not marker_value is MeshInstance3D:
		return
	var marker: MeshInstance3D = marker_value as MeshInstance3D
	marker.set_meta("reticle_mode", "hard")
	if marker.get_node_or_null("ReticleVisual") != null:
		return

	var material: Material = marker.material_override
	marker.mesh = null
	var visual := Node3D.new()
	visual.name = "ReticleVisual"
	marker.add_child(visual)

	var ring := MeshInstance3D.new()
	ring.name = "HardRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.285
	torus.outer_radius = 0.315
	torus.rings = 36
	torus.ring_segments = 8
	ring.mesh = torus
	ring.rotation_degrees.x = 90.0
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(ring)

	_add_corner_brackets(visual, material, 0.43, 0.17, 0.032)

	var center := MeshInstance3D.new()
	center.name = "CenterDiamond"
	var center_mesh := BoxMesh.new()
	center_mesh.size = Vector3(0.075, 0.075, 0.025)
	center.mesh = center_mesh
	center.rotation_degrees.z = 45.0
	center.material_override = material
	center.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(center)


func _add_corner_brackets(
	parent: Node3D,
	material: Material,
	radius: float,
	length: float,
	thickness: float
) -> void:
	for x_sign: float in [-1.0, 1.0]:
		for y_sign: float in [-1.0, 1.0]:
			var horizontal := MeshInstance3D.new()
			var horizontal_mesh := BoxMesh.new()
			horizontal_mesh.size = Vector3(length, thickness, 0.025)
			horizontal.mesh = horizontal_mesh
			horizontal.position = Vector3(
				x_sign * (radius - length * 0.5),
				y_sign * radius,
				0.0
			)
			horizontal.material_override = material
			horizontal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(horizontal)

			var vertical := MeshInstance3D.new()
			var vertical_mesh := BoxMesh.new()
			vertical_mesh.size = Vector3(thickness, length, 0.025)
			vertical.mesh = vertical_mesh
			vertical.position = Vector3(
				x_sign * radius,
				y_sign * (radius - length * 0.5),
				0.0
			)
			vertical.material_override = material
			vertical.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(vertical)


func _refresh_hard_target_warning() -> void:
	last_target_warning = 0.0
	if actor == null or not actor.has_method("has_lock_on_target"):
		return
	if not bool(actor.call("has_lock_on_target")):
		return
	var marker_value: Variant = actor.get("lock_on_marker")
	var target_value: Variant = actor.get("lock_on_target")
	if not marker_value is MeshInstance3D or not target_value is Node3D:
		return
	var marker: MeshInstance3D = marker_value as MeshInstance3D
	var target: Node3D = target_value as Node3D
	var lock_range: float = maxf(float(actor.get("lock_on_range")), 0.01)
	var distance_ratio: float = actor.global_position.distance_to(
		target.global_position
	) / lock_range
	var warning: float = clampf(
		(distance_ratio - target_warning_start_ratio)
		/ maxf(1.25 - target_warning_start_ratio, 0.01),
		0.0,
		1.0
	)
	var grace: float = maxf(
		float(actor.get("lock_on_visibility_grace_seconds")),
		0.01
	)
	warning = maxf(
		warning,
		clampf(float(actor.get("lock_on_visibility_timer")) / grace, 0.0, 1.0)
	)
	last_target_warning = warning
	marker.set_meta("warning_strength", warning)

	var base_color := Color(1.0, 0.76, 0.12, 0.94)
	if targeting_assist != null:
		base_color = targeting_assist.get_target_color(target, false)
	var warning_color := Color(1.0, 0.22, 0.08, 1.0)
	var resolved_color: Color = base_color.lerp(warning_color, warning)
	var material := marker.material_override as StandardMaterial3D
	if material != null:
		material.albedo_color = resolved_color
		material.emission = Color(
			resolved_color.r,
			resolved_color.g,
			resolved_color.b,
			1.0
		)
		material.emission_energy_multiplier = 1.55 + warning * 1.9

	var pulse_age: float = float(Time.get_ticks_msec()) * 0.001
	var pulse_speed: float = lerpf(4.5, 11.0, warning)
	var pulse_amount: float = lerpf(0.045, 0.15, warning)
	marker.scale = Vector3.ONE * (
		1.0 + sin(pulse_age * pulse_speed) * pulse_amount
	)


func _make_panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	return style


func _make_bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(3)
	return style


func get_debug_data() -> Dictionary:
	return {
		"setup_complete": setup_complete,
		"compact_stats": (
			hud != null
			and hud.loadout_label != null
			and not hud.loadout_label.visible
			and hud.base_stats_label != null
			and not hud.base_stats_label.visible
		),
		"crouch_visible": crouch_panel != null and crouch_panel.visible,
		"crouch_state": (
			crouch_state_label.text if crouch_state_label != null else ""
		),
		"soft_reticle": (
			targeting_assist != null
			and targeting_assist.get("soft_marker") is Node3D
			and (targeting_assist.get("soft_marker") as Node3D).get_node_or_null(
				"CornerBrackets"
			) != null
		),
		"hard_reticle": (
			actor != null
			and actor.get("lock_on_marker") is MeshInstance3D
			and (actor.get("lock_on_marker") as MeshInstance3D).get_node_or_null(
				"ReticleVisual"
			) != null
		),
		"target_warning": snappedf(last_target_warning, 0.01),
	}
