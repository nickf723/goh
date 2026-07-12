extends "res://scripts/ui/full_menu_shell.gd"


func render_inventory() -> void:
	add_text_card(
		"Inventory",
		"The bag: key items, consumables, crafting materials, quest objects, and usable tools. Equipment decides what gets hotkeyed."
	)

	add_section_header("Key Items")
	var key_items: Array = menu_data.get("key_items", [])

	if key_items.size() <= 0:
		add_compact_card("Grace has no key items yet.", false, "Key Items")
	else:
		for item_variant in key_items:
			if item_variant is Dictionary:
				render_key_item_card(item_variant as Dictionary)

	add_section_header("Future Inventory")
	add_compact_card("Item Source  ·  choose item later  ·  assign to Equipment hotkey", false, "Items")
	add_compact_card("Consumables  ·  no item database yet  ·  potions / food / bombs / remedies", false, "Items")
	add_compact_card("Materials  ·  no material database yet  ·  ores / herbs / monster parts / relic scraps", false, "Materials")


func render_key_item_card(item: Dictionary) -> void:
	var item_name: String = str(item.get("name", item.get("id", "Key Item")))
	var item_kind: String = str(item.get("kind", "Key Item"))
	var item_source: String = str(item.get("source", "Unknown"))
	var line: String = item_name + "  ·  " + item_kind + "  ·  " + item_source
	add_compact_card(line, false, "Key Item")
