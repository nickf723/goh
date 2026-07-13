extends Control
class_name DevelopmentControlCenter

const FeatureRegistryScript = preload("res://scripts/systems/feature_registry.gd")
const TITLE_SCENE: String = "res://scenes/ui/prototype_title_menu.tscn"
const WINDOW_TITLE: String = "Grace of Humanity | Development Control Center v0.8"

@onready var feature_list: ItemList = %FeatureList
@onready var health_label: Label = %HealthLabel
@onready var feature_title: Label = %FeatureTitle
@onready var feature_meta: Label = %FeatureMeta
@onready var description_label: Label = %DescriptionLabel
@onready var dependencies_label: Label = %DependenciesLabel
@onready var controls_label: Label = %ControlsLabel
@onready var state_label: Label = %StateLabel
@onready var manual_test_label: Label = %ManualTestLabel
@onready var limitations_label: Label = %LimitationsLabel
@onready var validation_label: Label = %ValidationLabel
@onready var status_label: Label = %StatusLabel
@onready var launch_button: Button = %LaunchButton
@onready var refresh_button: Button = %RefreshButton
@onready var return_button: Button = %ReturnButton

var registry_result: Dictionary = {}
var visible_features: Array[Dictionary] = []
var selected_feature_index: int = -1


func _ready() -> void:
	Engine.time_scale = 1.0
	DisplayServer.window_set_title(WINDOW_TITLE)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	feature_list.item_selected.connect(_on_feature_selected)
	feature_list.item_activated.connect(_on_feature_activated)
	launch_button.pressed.connect(launch_selected_feature)
	refresh_button.pressed.connect(reload_registry)
	return_button.pressed.connect(return_to_title)

	reload_registry()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		return_to_title()
		get_viewport().set_input_as_handled()


func reload_registry() -> void:
	registry_result = FeatureRegistryScript.load_registry()
	visible_features = FeatureRegistryScript.get_visible_features()
	feature_list.clear()
	selected_feature_index = -1

	health_label.text = FeatureRegistryScript.get_health_summary(registry_result)
	health_label.modulate = (
		Color(0.42, 1.0, 0.68, 1.0)
		if bool(registry_result.get("ok", false))
		else Color(1.0, 0.42, 0.36, 1.0)
	)

	for feature: Dictionary in visible_features:
		var feature_id: String = str(feature.get("id", "unknown"))
		var status: String = format_token(str(feature.get("status", "unknown")))
		var entry_errors: Array[String] = FeatureRegistryScript.get_feature_errors(feature_id, registry_result)
		var prefix: String = "✓ " if entry_errors.is_empty() else "! "
		var item_text: String = prefix + str(feature.get("display_name", feature_id)) + "  [" + status + "]"
		feature_list.add_item(item_text)
		var item_index: int = feature_list.item_count - 1
		feature_list.set_item_metadata(item_index, feature_id)
		feature_list.set_item_tooltip(item_index, str(feature.get("description", "")))
		feature_list.set_item_disabled(item_index, not entry_errors.is_empty())

	if visible_features.is_empty():
		show_empty_state()
		status_label.text = "No visible launchable features were found."
		return

	var first_enabled_index: int = find_first_enabled_item()
	if first_enabled_index < 0:
		show_empty_state()
		status_label.text = "Every registered launcher entry is invalid. Review the registry health output."
		return

	feature_list.select(first_enabled_index)
	selected_feature_index = first_enabled_index
	update_detail_panel()
	feature_list.grab_focus()
	status_label.text = "Registry loaded. NAVIGATE to a feature and SELECT to launch."


func find_first_enabled_item() -> int:
	for item_index: int in range(feature_list.item_count):
		if not feature_list.is_item_disabled(item_index):
			return item_index
	return -1


func _on_feature_selected(index: int) -> void:
	selected_feature_index = index
	update_detail_panel()


func _on_feature_activated(index: int) -> void:
	selected_feature_index = index
	update_detail_panel()
	launch_selected_feature()


func update_detail_panel() -> void:
	var feature: Dictionary = get_selected_feature()
	if feature.is_empty():
		show_empty_state()
		return

	var feature_id: String = str(feature.get("id", "unknown"))
	var entry_errors: Array[String] = FeatureRegistryScript.get_feature_errors(feature_id, registry_result)
	var dependencies: Array[String] = resolve_dependency_names(feature)
	var controls: Array[String] = string_array(feature.get("controls", []))
	var limitations: Array[String] = string_array(feature.get("limitations", []))

	feature_title.text = str(feature.get("display_name", feature_id))
	feature_meta.text = (
		format_token(str(feature.get("category", "Feature")))
		+ " • "
		+ str(feature.get("version", "unversioned"))
		+ " • "
		+ format_token(str(feature.get("status", "unknown")))
	)
	description_label.text = str(feature.get("description", "No description registered."))
	dependencies_label.text = "DEPENDENCIES\n" + ("None" if dependencies.is_empty() else " • ".join(dependencies))
	controls_label.text = "SEMANTIC CONTROLS\n" + ("None" if controls.is_empty() else " • ".join(controls))
	state_label.text = (
		"STATE POLICY\n"
		+ format_token(str(feature.get("temporary_state", "unknown")))
		+ " • Story integrated: "
		+ ("YES" if bool(feature.get("story_integrated", false)) else "NO")
	)
	manual_test_label.text = "MANUAL TEST\n" + str(feature.get("manual_test", "Not registered"))
	limitations_label.text = "KNOWN LIMITATIONS\n" + format_bullets(limitations)

	if entry_errors.is_empty():
		validation_label.text = "VALIDATION\nREADY • scene and contracts resolved"
		validation_label.modulate = Color(0.42, 1.0, 0.68, 1.0)
		launch_button.disabled = not bool(feature.get("launchable", false))
	else:
		validation_label.text = "VALIDATION\nBLOCKED\n" + format_bullets(entry_errors)
		validation_label.modulate = Color(1.0, 0.42, 0.36, 1.0)
		launch_button.disabled = true

	launch_button.text = "LAUNCH " + str(feature.get("display_name", "FEATURE")).to_upper()


func show_empty_state() -> void:
	feature_title.text = "NO FEATURE SELECTED"
	feature_meta.text = "REGISTRY"
	description_label.text = "The Control Center could not resolve a valid feature entry."
	dependencies_label.text = "DEPENDENCIES\nNone"
	controls_label.text = "SEMANTIC CONTROLS\nNAVIGATE • SELECT • BACK"
	state_label.text = "STATE POLICY\nNone"
	manual_test_label.text = "MANUAL TEST\nNot available"
	limitations_label.text = "KNOWN LIMITATIONS\n• Registry data is unavailable or invalid."
	validation_label.text = "VALIDATION\nBLOCKED"
	validation_label.modulate = Color(1.0, 0.42, 0.36, 1.0)
	launch_button.text = "LAUNCH"
	launch_button.disabled = true


func get_selected_feature() -> Dictionary:
	if selected_feature_index < 0 or selected_feature_index >= feature_list.item_count:
		return {}

	var feature_id: String = str(feature_list.get_item_metadata(selected_feature_index))
	for feature: Dictionary in visible_features:
		if str(feature.get("id", "")) == feature_id:
			return feature
	return {}


func launch_selected_feature() -> void:
	var feature: Dictionary = get_selected_feature()
	if feature.is_empty():
		status_label.text = "No feature is selected."
		return

	var feature_id: String = str(feature.get("id", "unknown"))
	var entry_errors: Array[String] = FeatureRegistryScript.get_feature_errors(feature_id, registry_result)
	if not entry_errors.is_empty():
		status_label.text = "Launch blocked: " + entry_errors[0]
		return

	var scene_path: String = str(feature.get("scene", ""))
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		status_label.text = "Launch blocked: scene is unavailable: " + scene_path
		return

	status_label.text = "Launching " + str(feature.get("display_name", feature_id)) + "..."
	Engine.time_scale = 1.0
	var change_error: Error = get_tree().change_scene_to_file(scene_path)
	if change_error != OK:
		status_label.text = "Launch failed with error " + str(change_error) + ": " + scene_path


func return_to_title() -> void:
	Engine.time_scale = 1.0
	if not ResourceLoader.exists(TITLE_SCENE):
		status_label.text = "Title scene is unavailable: " + TITLE_SCENE
		return

	var change_error: Error = get_tree().change_scene_to_file(TITLE_SCENE)
	if change_error != OK:
		status_label.text = "Could not return to title. Error: " + str(change_error)


func resolve_dependency_names(feature: Dictionary) -> Array[String]:
	var names: Array[String] = []
	var raw_dependencies: Variant = feature.get("dependencies", [])
	if not raw_dependencies is Array:
		return names

	for raw_dependency: Variant in raw_dependencies as Array:
		var dependency_id: String = str(raw_dependency)
		var dependency: Dictionary = FeatureRegistryScript.get_feature_by_id(dependency_id)
		if dependency.is_empty():
			names.append(dependency_id + " [MISSING]")
		else:
			names.append(str(dependency.get("display_name", dependency_id)))
	return names


func string_array(raw_values: Variant) -> Array[String]:
	var values: Array[String] = []
	if not raw_values is Array:
		return values
	for raw_value: Variant in raw_values as Array:
		values.append(str(raw_value))
	return values


func format_bullets(values: Array[String]) -> String:
	if values.is_empty():
		return "• None registered"

	var rows: Array[String] = []
	for value: String in values:
		rows.append("• " + value)
	return "\n".join(rows)


func format_token(value: String) -> String:
	return value.replace("_", " ").to_upper()


func get_debug_data() -> Dictionary:
	return {
		"registry_ok": bool(registry_result.get("ok", false)),
		"feature_count": visible_features.size(),
		"selected_feature": str(get_selected_feature().get("id", "none")),
		"registry_errors": registry_result.get("errors", []),
	}
