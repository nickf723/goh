extends "res://scripts/levels/prototype_polish_studio.gd"
class_name PrototypePolishStudioSpells

const SpellPresentation = preload(
	"res://scripts/presentation/spell_presentation_bridge.gd"
)

const SPELL_PREVIEWS: Array[Dictionary] = [
	{
		"phase": "release", "spell_id": "firebolt", "spell_name": "Firebolt",
		"element": "fire", "delivery_type": "projectile", "intensity": 0.62,
	},
	{
		"phase": "manifest", "spell_id": "sprout", "spell_name": "Plant Summon",
		"element": "life", "delivery_type": "ground_summon", "intensity": 0.68,
	},
	{
		"phase": "latch", "spell_id": "vine_grapple", "spell_name": "Vine Grapple",
		"element": "life", "delivery_type": "channeled_tether", "intensity": 0.55,
	},
	{
		"phase": "manifest", "spell_id": "death_hex", "spell_name": "Death Hex",
		"element": "death", "delivery_type": "projectile_curse", "intensity": 0.7,
	},
	{
		"phase": "handoff", "spell_id": "wraith_pursuit", "spell_name": "Wraith Pursuit",
		"element": "death", "delivery_type": "projectile_spirit_pursuit", "intensity": 0.78,
	},
]

var spell_preview_index: int = 0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_F6:
			_preview_next_spell_profile()
			get_viewport().set_input_as_handled()
			return
	super._unhandled_input(event)


func _update_hud() -> void:
	if status_label == null:
		return
	var lines: Array[String] = [
		"PRESENTATION DIRECTOR  •  F5 impact preview  •  F6 spell preview  •  F8 reset",
		"Walk the floor strips, hit reaction targets, break props, and cast spells freely.",
	]
	if last_event.is_empty():
		lines.append("Last event: waiting for input…")
	else:
		var event_type: String = str(last_event.get("event_type", "event")).to_upper()
		var parts: Array[String] = ["#" + str(last_event.get("event_id", 0)), event_type]
		for key: String in [
			"phase", "spell_id", "tier", "material", "element", "reaction", "delivery_type", "haptic",
		]:
			var value: String = str(last_event.get(key, ""))
			if value != "":
				parts.append(key.to_upper() + " " + value.to_upper())
		lines.append("  •  ".join(parts))
		var audio_value: Variant = last_event.get("audio", {})
		lines.append("Audio: " + _audio_summary(audio_value))
	status_label.text = "\n".join(lines)


func _preview_next_spell_profile() -> void:
	if SPELL_PREVIEWS.is_empty():
		return
	var row: Dictionary = SPELL_PREVIEWS[spell_preview_index % SPELL_PREVIEWS.size()]
	spell_preview_index += 1
	var context: Dictionary = row.duplicate(true)
	context["position"] = Vector3(0.0, 1.35, -5.0)
	context["detail"] = "polish_studio_preview"
	SpellPresentation.present(self, str(row.get("phase", "release")), context)
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call(
			"show_message",
			"Spell preview • "
			+ str(row.get("spell_name", "Spell"))
			+ " • "
			+ str(row.get("phase", "release")).capitalize()
		)


func _reset_studio() -> void:
	super._reset_studio()
	spell_preview_index = 0


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["spell_preview_profiles"] = SPELL_PREVIEWS.size()
	data["spell_preview_index"] = spell_preview_index
	return data
