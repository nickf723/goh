extends "res://scripts/ui/full_menu_shell_familiar.gd"
class_name FullMenuShellFamiliarDetail


func _render_compact_familiar_customization(parent: VBoxContainer) -> void:
	_render_compact_bonded_familiar_selection(parent)
	super._render_compact_familiar_customization(parent)


func _render_compact_bonded_familiar_selection(parent: VBoxContainer) -> void:
	var roster: BondedFamiliarRoster = _get_bonded_roster()
	var rows: Array[Dictionary] = (
		roster.get_roster_rows()
		if roster != null
		else []
	)
	parent.add_child(_make_magic_heading("BONDED FAMILIAR • NAMED COMPANION"))
	if rows.is_empty():
		var empty_label := Label.new()
		empty_label.name = "BondedFamiliarSpellDetailEmpty"
		empty_label.text = (
			"No rescued and bonded named animals are available. "
			+ "Form a bond in the world, then return here."
		)
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_font_size_override("font_size", 10)
		empty_label.add_theme_color_override("font_color", TEXT_SOFT)
		parent.add_child(empty_label)
		return

	var grid: GridContainer = make_visual_grid(mini(maxi(rows.size() + 1, 1), 3))
	grid.name = "BondedFamiliarSpellDetailGrid"
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(grid)
	var equipped_found: bool = false
	for row: Dictionary in rows:
		var animal_id: String = str(row.get("animal_id", ""))
		var animal_name: String = str(row.get("animal_name", animal_id.capitalize()))
		var equipped: bool = bool(row.get("equipped", false))
		var manifested: bool = bool(row.get("manifested", false))
		var trust_percent: int = roundi(
			clampf(float(row.get("trust", 0.0)), 0.0, 1.0) * 100.0
		)
		var badge: String = "MANIFESTED" if manifested else (
			"EQUIPPED" if equipped else "BONDED • TRUST " + str(trust_percent) + "%"
		)
		var before_count: int = grid.get_child_count()
		_add_compact_action_tile(
			grid,
			str(row.get("icon", "✦")),
			animal_name,
			badge,
			{"kind": "equip_bonded_familiar", "animal_id": animal_id},
			str(row.get("species_name", "Animal"))
			+ " • " + str(row.get("trust_tier", "Bonded"))
			+ ". Summon Familiar will manifest this individual.",
			54.0,
			9
		)
		if grid.get_child_count() > before_count:
			var tile: Node = grid.get_child(before_count)
			tile.name = "BondedFamiliar_" + animal_id.replace(":", "_")
			tile.set_meta("action_kind", "equip_bonded_familiar")
			tile.set_meta("animal_id", animal_id)
		equipped_found = equipped_found or equipped

	if equipped_found:
		var before_clear_count: int = grid.get_child_count()
		_add_compact_action_tile(
			grid,
			"◇",
			"Use Species Blueprint",
			"CLEAR NAMED SLOT",
			{"kind": "clear_bonded_familiar"},
			"Restore the previously prepared species familiar blueprint.",
			54.0,
			9
		)
		if grid.get_child_count() > before_clear_count:
			var clear_tile: Node = grid.get_child(before_clear_count)
			clear_tile.name = "ClearBondedFamiliarSlot"
			clear_tile.set_meta("action_kind", "clear_bonded_familiar")
