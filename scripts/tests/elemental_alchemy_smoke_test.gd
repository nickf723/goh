extends Node

var failures: Array[String] = []


func _ready() -> void:
	var cauldron := AlchemyCauldron.new()
	add_child(cauldron)
	await get_tree().process_frame
	_expect(cauldron.get_recipe_key(["springwater", "life_bloom"]) == "life_bloom|springwater", "Recipe keys ignore ingredient order")
	cauldron.apply_element("fire")
	_expect(cauldron.catalyst == "fire", "Valid elemental treatment is accepted")
	cauldron.apply_element("banana")
	_expect(cauldron.catalyst == "fire", "Unknown treatment is ignored")
	_expect(QuickItemCatalog.get_item("healing_potion") != null, "Healing Potion is a quick item")
	_expect(QuickItemCatalog.get_item("resonance_tonic") != null, "Resonance Tonic is a quick item")
	_expect(QuickItemCatalog.get_item("frost_vigor_draught") != null, "Frost Vigor Draught is a quick item")
	_expect(QuickItemCatalog.get_item("antidote") != null, "Antidote is a quick item")
	_expect(QuickItemCatalog.get_item("conductive_elixir") != null, "Conductive Elixir is a quick item")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func _finish() -> void:
	if failures.is_empty():
		print("ELEMENTAL ALCHEMY SMOKE TEST PASSED")
	else:
		push_error("ELEMENTAL ALCHEMY SMOKE TEST FAILED: " + ", ".join(failures))
