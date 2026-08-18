extends "res://scripts/ui/player_hud_unified_budgeted.gd"
class_name PlayerHUDAdaptiveQuiet

# The unified HUD remains authoritative. This layer changes only presentation
# prominence, letting persistent information recede during ordinary traversal and
# wake smoothly when combat, context, resource pressure, or player intent needs it.

@export_group("Adaptive Quiet HUD")
@export_range(0.0, 1.0, 0.05) var quiet_stats_alpha: float = 0.48
@export_range(0.0, 1.0, 0.05) var quiet_action_alpha: float = 0.30
@export_range(0.0, 1.0, 0.05) var quiet_support_alpha: float = 0.16
@export_range(0.0, 1.0, 0.05) var quiet_activity_alpha: float = 0.72
@export_range(0.0, 1.0, 0.05) var alert_stats_alpha: float = 1.0
@export_range(1.0, 18.0, 0.5) var fade_in_response: float = 10.0
@export_range(1.0, 18.0, 0.5) var fade_out_response: float = 4.5
@export_range(0.5, 8.0, 0.25) var action_wake_seconds: float = 3.2
@export_range(0.1, 1.0, 0.05) var health_alert_ratio: float = 0.48
@export_range(0.1, 1.0, 0.05) var stamina_alert_ratio: float = 0.30
@export_range(0.1, 1.0, 0.05) var mana_alert_ratio: float = 0.26

var wake_remaining: float = 0.0
var last_quiet_state: bool = false
var last_stats_target: float = 1.0
var last_action_target: float = 1.0
var last_support_target: float = 1.0
var last_resource_pressure: float = 0.0
var adaptive_updates: int = 0


func _ready() -> void:
	super._ready()
	add_to_group("adaptive_quiet_hud")
	wake_remaining = action_wake_seconds


func _process(delta: float) -> void:
	super._process(delta)
	var step: float = maxf(delta, 0.0)
	wake_remaining = maxf(wake_remaining - step, 0.0)
	_capture_attention_inputs()
	_update_adaptive_prominence(step)


# The budgeted parent periodically refreshes zone visibility and restores its own
# mode alpha values. Preserve the adaptive exploration alpha across that refresh
# so quiet mode does not pulse bright every shell tick.
func _update_zone_visibility() -> void:
	var stats_alpha: float = stats_panel.modulate.a if stats_panel != null else 1.0
	var action_alpha: float = action_bar_zone.modulate.a if action_bar_zone != null else 1.0
	var support_alpha: float = support_zone.modulate.a if support_zone != null else 1.0
	var activity_alpha: float = activity_zone.modulate.a if activity_zone != null else 1.0
	super._update_zone_visibility()
	if current_mode_id != "exploration":
		return
	if stats_panel != null and stats_panel.visible:
		stats_panel.modulate.a = stats_alpha
	if action_bar_zone != null and action_bar_zone.visible:
		action_bar_zone.modulate.a = action_alpha
	if support_zone != null and support_zone.visible:
		support_zone.modulate.a = support_alpha
	if activity_zone != null and activity_zone.visible:
		activity_zone.modulate.a = activity_alpha


func _capture_attention_inputs() -> void:
	for action_name: StringName in [
		&"weapon_light_attack",
		&"weapon_heavy_attack",
		&"cast_spell",
		&"guard",
		&"dodge",
		&"interact",
		&"use_quick_item",
		&"crouch_toggle",
	]:
		if InputMap.has_action(action_name) and Input.is_action_just_pressed(action_name):
			wake_remaining = action_wake_seconds
			return


func _update_adaptive_prominence(delta: float) -> void:
	if root == null:
		return
	adaptive_updates += 1
	var attention: bool = _needs_full_attention()
	var pressure: float = _resource_pressure()
	last_resource_pressure = pressure
	var quiet: bool = not attention and wake_remaining <= 0.0 and pressure <= 0.001
	last_quiet_state = quiet

	var stats_target: float = quiet_stats_alpha if quiet else alert_stats_alpha
	if pressure > 0.0:
		stats_target = lerpf(quiet_stats_alpha, 1.0, pressure)
	var action_target: float = quiet_action_alpha if quiet else 1.0
	var support_target: float = quiet_support_alpha if quiet and not _support_needs_attention() else 1.0
	var activity_target: float = quiet_activity_alpha if quiet else 1.0
	last_stats_target = stats_target
	last_action_target = action_target
	last_support_target = support_target

	var response: float = fade_in_response if not quiet or pressure > 0.0 else fade_out_response
	var alpha: float = 1.0 - exp(-maxf(response, 0.01) * maxf(delta, 0.0))
	if stats_panel != null and stats_panel.visible:
		stats_panel.modulate.a = lerpf(stats_panel.modulate.a, stats_target, alpha)
	if action_bar_zone != null and action_bar_zone.visible:
		action_bar_zone.modulate.a = lerpf(action_bar_zone.modulate.a, action_target, alpha)
	if support_zone != null and support_zone.visible:
		support_zone.modulate.a = lerpf(support_zone.modulate.a, support_target, alpha)
	if activity_zone != null and activity_zone.visible:
		activity_zone.modulate.a = lerpf(activity_zone.modulate.a, activity_target, alpha)


func _needs_full_attention() -> bool:
	if current_mode_id != "exploration":
		return true
	if actor == null:
		return true
	var action_state: PlayerActionState = actor.get_node_or_null(
		"PlayerActionState"
	) as PlayerActionState
	if action_state != null and (
		action_state.is_attacking
		or action_state.is_casting
		or action_state.is_dodging
		or action_state.is_guarding
		or action_state.is_staggered
		or action_state.is_using_item
		or action_state.is_manipulating
	):
		return true
	if actor.has_method("has_lock_on_target") and bool(actor.call("has_lock_on_target")):
		return true
	if context_panel != null and context_panel.visible:
		return true
	if not activity_entries.is_empty():
		return true
	return false


func _support_needs_attention() -> bool:
	for entry: Dictionary in active_ability_entries:
		if bool(entry.get("attention", false)) or bool(entry.get("highlighted", false)):
			return true
	if support_status_label != null:
		var status_text: String = support_status_label.text.strip_edges().to_upper()
		if status_text not in ["", "READY", "NO PERSISTENT ABILITIES ACTIVE"]:
			return true
	return false


func _resource_pressure() -> float:
	var pressure: float = 0.0
	pressure = maxf(pressure, _low_ratio_pressure(
		GameState.get_stat("health"),
		GameState.get_stat("max_health"),
		health_alert_ratio
	))
	pressure = maxf(pressure, _low_ratio_pressure(
		GameState.get_stat("stamina"),
		GameState.get_stat("max_stamina"),
		stamina_alert_ratio
	))
	pressure = maxf(pressure, _low_ratio_pressure(
		GameState.get_stat("mana"),
		GameState.get_stat("max_mana"),
		mana_alert_ratio
	))
	return clampf(pressure, 0.0, 1.0)


func _low_ratio_pressure(
	current_value: int,
	maximum_value: int,
	threshold: float
) -> float:
	if maximum_value <= 0:
		return 0.0
	var ratio: float = clampf(
		float(current_value) / float(maximum_value),
		0.0,
		1.0
	)
	if ratio >= threshold:
		return 0.0
	return clampf(1.0 - ratio / maxf(threshold, 0.01), 0.0, 1.0)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["adaptive_quiet_hud"] = true
	data["quiet"] = last_quiet_state
	data["wake_remaining"] = snappedf(wake_remaining, 0.01)
	data["resource_pressure"] = snappedf(last_resource_pressure, 0.01)
	data["stats_target_alpha"] = snappedf(last_stats_target, 0.01)
	data["action_target_alpha"] = snappedf(last_action_target, 0.01)
	data["support_target_alpha"] = snappedf(last_support_target, 0.01)
	data["adaptive_updates"] = adaptive_updates
	data["information_removed"] = false
	data["gameplay_authority"] = false
	data["shell_refresh_preserves_alpha"] = true
	data["passive_abilities_can_recede"] = true
	return data
