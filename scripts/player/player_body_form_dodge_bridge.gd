extends Node
class_name PlayerBodyFormDodgeBridge

var actor: CharacterBody3D = null
var body_form_controller: PlayerBodyFormController = null
var dodge_controller: PlayerDodgeController = null
var baseline_profile: DodgeMotionProfile = null
var active_runtime_profile: DodgeMotionProfile = null
var current_form: String = "normal"
var profile_swap_count: int = 0


func _ready() -> void:
	actor = get_parent() as CharacterBody3D
	body_form_controller = get_parent().get_node_or_null(
		"BodyFormController"
	) as PlayerBodyFormController
	dodge_controller = get_parent().get_node_or_null(
		"PlayerDodgeController"
	) as PlayerDodgeController
	if dodge_controller != null:
		baseline_profile = dodge_controller.profile
	if body_form_controller != null:
		var callback := Callable(self, "_on_form_changed")
		if not body_form_controller.form_changed.is_connected(callback):
			body_form_controller.form_changed.connect(callback)
		_apply_form_profile(body_form_controller.get_current_form())
	add_to_group("body_form_dodge_bridges")
	add_to_group("debuggable")


func _exit_tree() -> void:
	if (
		body_form_controller != null
		and is_instance_valid(body_form_controller)
	):
		var callback := Callable(self, "_on_form_changed")
		if body_form_controller.form_changed.is_connected(callback):
			body_form_controller.form_changed.disconnect(callback)
	_restore_baseline_profile()


func _on_form_changed(
	_previous_form: String,
	next_form: String,
	_scale_multiplier: float
) -> void:
	_apply_form_profile(next_form)


func _apply_form_profile(form_id: String) -> void:
	current_form = form_id.strip_edges().to_lower()
	if dodge_controller == null or baseline_profile == null:
		return
	if current_form == "normal":
		_restore_baseline_profile()
		return

	var runtime: DodgeMotionProfile = (
		baseline_profile.duplicate(true) as DodgeMotionProfile
	)
	if runtime == null:
		return
	match current_form:
		"grown":
			runtime.distance = maxf(baseline_profile.distance * 0.78, 0.2)
			runtime.duration = maxf(baseline_profile.duration * 1.1, 0.12)
			runtime.cooldown = maxf(baseline_profile.cooldown * 1.15, 0.0)
			runtime.steering_strength = clampf(
				baseline_profile.steering_strength * 0.72,
				0.0,
				1.0
			)
			runtime.steering_turn_speed_degrees = maxf(
				baseline_profile.steering_turn_speed_degrees * 0.8,
				0.0
			)
			runtime.maximum_consecutive_dodges = maxi(
				baseline_profile.maximum_consecutive_dodges - 1,
				1
			)
		"shrunk":
			runtime.distance = maxf(baseline_profile.distance * 1.25, 0.2)
			runtime.duration = maxf(baseline_profile.duration * 0.78, 0.12)
			runtime.cooldown = maxf(baseline_profile.cooldown * 0.68, 0.0)
			runtime.steering_strength = clampf(
				baseline_profile.steering_strength * 1.35,
				0.0,
				1.0
			)
			runtime.steering_turn_speed_degrees = maxf(
				baseline_profile.steering_turn_speed_degrees * 1.3,
				0.0
			)
			runtime.maximum_consecutive_dodges = mini(
				baseline_profile.maximum_consecutive_dodges + 1,
				6
			)
		_:
			_restore_baseline_profile()
			return

	active_runtime_profile = runtime
	dodge_controller.profile = active_runtime_profile
	profile_swap_count += 1
	if actor != null:
		actor.set_meta("body_form_dodge_profile", current_form)


func _restore_baseline_profile() -> void:
	active_runtime_profile = null
	if dodge_controller != null and baseline_profile != null:
		dodge_controller.profile = baseline_profile
	if actor != null:
		actor.set_meta("body_form_dodge_profile", "normal")
	current_form = "normal"


func get_debug_data() -> Dictionary:
	return {
		"body_form_dodge_bridge": true,
		"form": current_form,
		"baseline_profile": baseline_profile != null,
		"runtime_profile": active_runtime_profile != null,
		"profile_swaps": profile_swap_count,
		"distance": (
			dodge_controller.get_profile_distance()
			if dodge_controller != null
			else 0.0
		),
		"duration": (
			dodge_controller.get_profile_duration()
			if dodge_controller != null
			else 0.0
		),
		"cooldown": (
			dodge_controller.get_profile_cooldown()
			if dodge_controller != null
			else 0.0
		),
		"maximum_chain": (
			dodge_controller.get_maximum_consecutive_dodges()
			if dodge_controller != null
			else 0
		),
	}
