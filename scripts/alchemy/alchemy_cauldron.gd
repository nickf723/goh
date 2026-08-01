extends "res://scripts/alchemy/alchemy_cauldron_legacy.gd"

# Challenge-backed alchemy insight. The preserved cauldron core still owns
# brewing and inventory mutation; this layer adds a non-destructive preview
# after Kitchen Chemistry has been completed.

const RECIPE_INSIGHT_UNLOCK_ID: String = "alchemy_recipe_insight"
const INSIGHT_LOCKED_COLOR: Color = Color(0.44, 0.5, 0.58)
const INSIGHT_WAITING_COLOR: Color = Color(0.54, 0.75, 0.92)
const INSIGHT_PROMISING_COLOR: Color = Color(0.98, 0.76, 0.28)
const INSIGHT_STABLE_COLOR: Color = Color(0.4, 0.94, 0.62)
const INSIGHT_UNSTABLE_COLOR: Color = Color(0.88, 0.42, 0.48)

var insight_label: Label


func build_menu() -> void:
	super.build_menu()
	var left_column: VBoxContainer = catalyst_label.get_parent() as VBoxContainer
	if left_column == null:
		return
	insight_label = Label.new()
	insight_label.name = "AlchemyRecipeInsight"
	insight_label.custom_minimum_size = Vector2(0.0, 46.0)
	insight_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	insight_label.add_theme_font_size_override("font_size", 15)
	left_column.add_child(insight_label)
	left_column.move_child(insight_label, catalyst_label.get_index() + 1)
	_refresh_recipe_insight()


func refresh_menu() -> void:
	super.refresh_menu()
	_refresh_recipe_insight()


func has_recipe_insight() -> bool:
	return (
		GameState.has_method("has_unlock")
		and GameState.has_unlock(RECIPE_INSIGHT_UNLOCK_ID)
	)


func get_recipe_insight() -> Dictionary:
	if not has_recipe_insight():
		return {
			"state": "locked",
			"text": "◇ RECIPE INSIGHT LOCKED  •  Discover three potion formulas.",
			"color": INSIGHT_LOCKED_COLOR,
			"stable": false,
			"recipe_id": "",
			"required_catalyst": "",
		}
	if selected_ingredients.size() < 2:
		return {
			"state": "waiting",
			"text": "◈ ALCHEMICAL INSIGHT  •  Select two ingredients to compare their resonance.",
			"color": INSIGHT_WAITING_COLOR,
			"stable": false,
			"recipe_id": "",
			"required_catalyst": "",
		}
	var key: String = get_recipe_key(selected_ingredients)
	var recipe: Dictionary = RECIPES.get(key, {})
	if recipe.is_empty():
		return {
			"state": "unstable",
			"text": "× NO STABLE FORMULA  •  This pairing will collapse into sludge.",
			"color": INSIGHT_UNSTABLE_COLOR,
			"stable": false,
			"recipe_id": "",
			"required_catalyst": "",
			"ingredient_key": key,
		}
	var recipe_id: String = str(recipe.get("id", ""))
	var required_catalyst: String = str(recipe.get("catalyst", "none"))
	var discovered: bool = GameState.get_flag("recipe_discovered_" + recipe_id)
	var formula_name: String = (
		str(recipe.get("name", recipe_id.capitalize()))
		if discovered
		else "Unrecorded formula"
	)
	if catalyst == required_catalyst:
		return {
			"state": "stable",
			"text": "◆ STABLE FORMULA  •  " + formula_name + " is ready to brew.",
			"color": INSIGHT_STABLE_COLOR,
			"stable": true,
			"recipe_id": recipe_id,
			"required_catalyst": required_catalyst,
			"ingredient_key": key,
		}
	return {
		"state": "promising",
		"text": (
			"△ PROMISING PAIR  •  "
			+ formula_name
			+ " requires "
			+ required_catalyst.capitalize()
			+ " treatment."
		),
		"color": INSIGHT_PROMISING_COLOR,
		"stable": false,
		"recipe_id": recipe_id,
		"required_catalyst": required_catalyst,
		"ingredient_key": key,
	}


func _refresh_recipe_insight() -> void:
	if insight_label == null or not is_instance_valid(insight_label):
		return
	var insight: Dictionary = get_recipe_insight()
	insight_label.text = str(insight.get("text", ""))
	var color_value: Variant = insight.get("color", INSIGHT_LOCKED_COLOR)
	insight_label.add_theme_color_override(
		"font_color",
		color_value as Color if color_value is Color else INSIGHT_LOCKED_COLOR
	)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	var insight: Dictionary = get_recipe_insight()
	data["recipe_insight_unlocked"] = has_recipe_insight()
	data["recipe_insight_state"] = str(insight.get("state", "locked"))
	data["recipe_insight_recipe_id"] = str(insight.get("recipe_id", ""))
	data["recipe_insight_catalyst"] = str(
		insight.get("required_catalyst", "")
	)
	data["recipe_insight_label_present"] = (
		insight_label != null and is_instance_valid(insight_label)
	)
	return data
