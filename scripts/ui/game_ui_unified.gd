extends "res://scripts/ui/game_ui_spell_icons_resolved.gd"
class_name GameUIUnified

var unified_objective_text: String = ""
var unified_prompt_text: String = ""
var hud_sync_remaining: float = 0.0


func _ready() -> void:
	super._ready()
	if objective_label != null:
		objective_label.visible = false
	call_deferred("_sync_unified_objective")


func _process(delta: float) -> void:
	hud_sync_remaining = maxf(hud_sync_remaining - maxf(delta, 0.0), 0.0)
	if hud_sync_remaining > 0.0:
		return
	hud_sync_remaining = 0.25
	_sync_unified_objective()
	if unified_prompt_text != "":
		_sync_unified_prompt()


func set_objective(text: String) -> void:
	super.set_objective(text)
	unified_objective_text = text.strip_edges()
	if objective_label != null:
		objective_label.visible = false
	_sync_unified_objective()


func show_prompt(text: String) -> void:
	super.show_prompt(text)
	unified_prompt_text = text.strip_edges()
	var shell: Node = _get_unified_hud()
	if shell == null:
		return
	prompt_label.visible = false
	_sync_unified_prompt()


func hide_prompt() -> void:
	super.hide_prompt()
	unified_prompt_text = ""
	var shell: Node = _get_unified_hud()
	if shell != null and shell.has_method("clear_context"):
		shell.call("clear_context", "interaction_prompt")


func show_message(text: String) -> void:
	var shell: Node = _get_unified_hud()
	if shell == null:
		super.show_message(text)
		return
	super.show_message(text)
	message_panel.modulate.a = 0.0
	if shell.has_method("publish_activity"):
		shell.call(
			"publish_activity",
			"system",
			text,
			"",
			2.65,
			"game_message",
			40,
			false,
			-1,
			-1
		)


func hide_message() -> void:
	super.hide_message()
	message_panel.modulate.a = 1.0


func _sync_unified_objective() -> void:
	var shell: Node = _get_unified_hud()
	if shell == null or not shell.has_method("set_objective_summary"):
		if objective_label != null:
			objective_label.visible = unified_objective_text != ""
		return
	objective_label.visible = false
	shell.call("set_objective_summary", unified_objective_text, "")


func _sync_unified_prompt() -> void:
	if unified_prompt_text == "":
		return
	var shell: Node = _get_unified_hud()
	if shell == null or not shell.has_method("publish_context"):
		return
	prompt_label.visible = false
	var prefix: String = get_interact_prompt_prefix().strip_edges()
	shell.call(
		"publish_context",
		"interaction_prompt",
		{
			"eyebrow": "INTERACT",
			"title": unified_prompt_text,
			"detail": "",
			"controls": prefix,
			"accent": Color(0.34, 0.9, 1.0),
			"valid": true,
		},
		20,
		0.0
	)


func _get_unified_hud() -> Node:
	var grouped: Node = get_tree().get_first_node_in_group("unified_hud_shell")
	if grouped != null:
		return grouped
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	var candidate: Node = scene.find_child("PlayerHUDV2", true, false)
	return candidate if candidate != null and candidate.has_method("get_hud_zone") else null


func get_unified_game_ui_debug_data() -> Dictionary:
	return {
		"objective": unified_objective_text,
		"prompt": unified_prompt_text,
		"hud_connected": _get_unified_hud() != null,
		"legacy_objective_hidden": objective_label != null and not objective_label.visible,
	}
