extends "res://scripts/input/player_control_router.gd"


const PerformanceDockScript = preload(
	"res://scripts/ui/quick_spell_belt_performance.gd"
)

var dock_replacement_pending: bool = false
var performance_dock_installed: bool = false


func _process(delta: float) -> void:
	super._process(delta)
	if not performance_dock_installed and not dock_replacement_pending:
		dock_replacement_pending = true
		call_deferred("_ensure_performance_command_dock")


func _ensure_performance_command_dock() -> void:
	dock_replacement_pending = false
	_resolve_bindings()
	if actor == null:
		return
	var existing: Node = actor.get_node_or_null("QuickSpellBeltPresentation")
	if existing != null:
		var existing_script: Script = existing.get_script() as Script
		if (
			existing_script != null
			and existing_script.resource_path
			== "res://scripts/ui/quick_spell_belt_performance.gd"
		):
			performance_dock_installed = true
			return
		actor.remove_child(existing)
		existing.queue_free()
	var presentation: Node = PerformanceDockScript.new()
	presentation.name = "QuickSpellBeltPresentation"
	actor.add_child(presentation)
	performance_dock_installed = true


func is_ground_targeting_active() -> bool:
	return (
		ability_caster != null
		and ability_caster.has_method("is_ground_targeting")
		and bool(ability_caster.call("is_ground_targeting"))
	)


func is_focus_open() -> bool:
	if is_ground_targeting_active():
		return false
	if (
		ability_caster != null
		and ability_caster.has_method("is_focus_library_open")
	):
		return bool(ability_caster.call("is_focus_library_open"))
	return super.is_focus_open()


func handle_focus_action(pressed: bool) -> bool:
	if is_ground_targeting_active():
		focus_axis_x_latched = false
		focus_axis_y_latched = false
		return true
	return super.handle_focus_action(pressed)


func _input(event: InputEvent) -> void:
	_resolve_bindings()
	if event is InputEventJoypadButton and is_ground_targeting_active():
		var target_button: InputEventJoypadButton = event as InputEventJoypadButton
		if target_button.button_index in [
			JOY_BUTTON_DPAD_UP,
			JOY_BUTTON_DPAD_DOWN,
			JOY_BUTTON_DPAD_LEFT,
			JOY_BUTTON_DPAD_RIGHT,
		]:
			get_viewport().set_input_as_handled()
			return
	if (
		event is InputEventJoypadButton
		and is_focus_open()
		and _handle_focus_dpad(event as InputEventJoypadButton)
	):
		get_viewport().set_input_as_handled()
		return
	super._input(event)


func _handle_focus_dpad(event: InputEventJoypadButton) -> bool:
	if event.button_index not in [
		JOY_BUTTON_DPAD_UP,
		JOY_BUTTON_DPAD_DOWN,
		JOY_BUTTON_DPAD_LEFT,
		JOY_BUTTON_DPAD_RIGHT,
	]:
		return false
	if not event.pressed:
		return true
	if ability_caster == null:
		return true
	match event.button_index:
		JOY_BUTTON_DPAD_LEFT:
			if ability_caster.has_method("cycle_focus_element"):
				ability_caster.call("cycle_focus_element", -1)
		JOY_BUTTON_DPAD_RIGHT:
			if ability_caster.has_method("cycle_focus_element"):
				ability_caster.call("cycle_focus_element", 1)
		JOY_BUTTON_DPAD_UP:
			if ability_caster.has_method("cycle_focus_spell"):
				ability_caster.call("cycle_focus_spell", -1)
		JOY_BUTTON_DPAD_DOWN:
			if ability_caster.has_method("cycle_focus_spell"):
				ability_caster.call("cycle_focus_spell", 1)
	return true


func get_input_mode_debug_data() -> Dictionary:
	return {
		"ground_targeting": is_ground_targeting_active(),
		"focus_library": is_focus_open(),
		"right_stick_owner": (
			"ground_target"
			if is_ground_targeting_active()
			else ("focus_library" if is_focus_open() else "camera")
		),
		"optimized_dock_installed": performance_dock_installed,
	}
