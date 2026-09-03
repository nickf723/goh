extends Node

const LabScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_organic_surface_lab_v1.tscn"
)
const Recipe: OrganicSurfaceRecipe = preload(
	"res://data/environment_surfaces/meadow_ground_seed_recipe_v1.tres"
)
const EXPECTED_SHADER_PATH: String = (
	"res://shaders/environment/stylized_location_ground_v1.gdshader"
)
const EXPECTED_TEMPLATE_PATH: String = (
	"res://art/materials/environment/natural/"
	+ "stylized_pbr_meadow_ground_v1.tres"
)

var failures: Array[String] = []
var lab: PrototypeOrganicSurfaceLabV1


func _ready() -> void:
	lab = LabScene.instantiate() as PrototypeOrganicSurfaceLabV1
	if lab == null:
		failures.append("organic surface lab failed to instantiate")
	else:
		add_child(lab)

	for _frame: int in range(4):
		await get_tree().process_frame

	_validate_recipe()
	_validate_scene_contract()
	_validate_preview_bank()
	_validate_rebuild()
	_validate_bank_cycle()
	_validate_presentation()

	if lab != null and is_instance_valid(lab):
		lab.queue_free()
	await get_tree().process_frame

	if failures.is_empty():
		print("ORGANIC_SURFACE_LAB_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("ORGANIC_SURFACE_LAB_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func _validate_recipe() -> void:
	if Recipe == null:
		failures.append("meadow ground recipe is missing")
		return
	if Recipe.recipe_id != "meadow_ground_seed_recipe_v1":
		failures.append("recipe id changed unexpectedly")
	if Recipe.generator_version != 1:
		failures.append("generator version must begin at one")
	if Recipe.material_template == null:
		failures.append("recipe material template is missing")
		return
	if Recipe.material_template.resource_path != EXPECTED_TEMPLATE_PATH:
		failures.append("recipe no longer owns the meadow material preset")
	if Recipe.material_template.shader == null:
		failures.append("recipe material has no shader")
	elif Recipe.material_template.shader.resource_path != EXPECTED_SHADER_PATH:
		failures.append("recipe material uses the wrong ground shader")

	var first_signature: String = Recipe.get_signature(Recipe.seed)
	var repeated_signature: String = Recipe.get_signature(Recipe.seed)
	if first_signature.is_empty() or first_signature != repeated_signature:
		failures.append("same recipe and seed are not deterministic")
	if first_signature == Recipe.get_signature(Recipe.seed + 7919):
		failures.append("different seeds do not produce different recipes")
	var parameters: Dictionary = Recipe.get_seed_parameters(Recipe.seed)
	for parameter_name: StringName in OrganicSurfaceRecipe.SIGNATURE_PARAMETERS:
		if not parameters.has(parameter_name):
			failures.append(
				"recipe omits seeded parameter: " + str(parameter_name)
			)


func _validate_scene_contract() -> void:
	if lab == null:
		return
	if not lab.is_in_group("organic_surface_lab"):
		failures.append("lab root group is missing")
	if not lab.is_in_group("authored_environment_composition"):
		failures.append("lab sits outside authored environment ownership")
	if str(lab.get_meta("lab_id", "")) != (
		"seeded_organic_surface_lab_v1"
	):
		failures.append("lab id changed unexpectedly")
	if not lab.has_method("get_debug_data"):
		failures.append("lab debug contract is missing")
	if get_tree().paused:
		failures.append("lab did not recover from paused launcher state")
	if lab.get_node_or_null("Player") != null:
		failures.append("material lab should not instantiate Grace")


func _validate_preview_bank() -> void:
	if lab == null:
		return
	var debug_data: Dictionary = lab.get_debug_data()
	if int(debug_data.get("preview_count", 0)) != 8:
		failures.append("lab must contain eight comparison plots")
	if int(debug_data.get("unique_seed_count", 0)) != 7:
		failures.append("canonical bank must contain one twin seed pair")
	if not bool(debug_data.get("twin_seed_match", false)):
		failures.append("twin plots do not share the same seed")
	if not bool(debug_data.get("twin_visual_match", false)):
		failures.append("same-seed twins drift across world coordinates")
	if str(debug_data.get("generator_id", "")) != (
		OrganicSurfaceRecipe.GENERATOR_ID
	):
		failures.append("generator id is missing from lab debug data")
	if int(debug_data.get("generator_version", 0)) != 1:
		failures.append("generator version is missing from lab debug data")
	if str(debug_data.get("shader_path", "")) != EXPECTED_SHADER_PATH:
		failures.append("preview bank does not use the location-ground shader")

	var signatures: Array = debug_data.get("local_signatures", []) as Array
	if signatures.size() != 8:
		failures.append("preview signatures are incomplete")
	elif str(signatures[0]).is_empty() or signatures[0] != signatures[1]:
		failures.append("twin local signatures do not match")

	for surface: MeshInstance3D in lab.preview_surfaces:
		var material: ShaderMaterial = (
			surface.material_override as ShaderMaterial
		)
		if material == null:
			failures.append("preview surface is missing its generated material")
			continue
		if not material.has_meta("organic_surface_signature"):
			failures.append("generated material omits its recipe signature")
		if not material.has_meta("organic_surface_seed"):
			failures.append("generated material omits its source seed")


func _validate_rebuild() -> void:
	if lab == null:
		return
	var before_signature: String = lab.get_preview_local_signature(0)
	if not lab.rebuild_selected_preview():
		failures.append("selected preview rebuild reported recipe drift")
	var after_signature: String = lab.get_preview_local_signature(0)
	if before_signature != after_signature:
		failures.append("selected preview changed after same-seed rebuild")
	var debug_data: Dictionary = lab.get_debug_data()
	if int(debug_data.get("rebuild_count", 0)) != 1:
		failures.append("rebuild count was not recorded")
	if not bool(debug_data.get("last_rebuild_matched", false)):
		failures.append("rebuild verification state did not remain passing")


func _validate_bank_cycle() -> void:
	if lab == null:
		return
	var canonical_signature: String = lab.get_preview_local_signature(0)
	lab.next_seed_bank()
	var next_debug: Dictionary = lab.get_debug_data()
	if int(next_debug.get("bank_index", 0)) != 1:
		failures.append("next seed bank did not advance")
	if not bool(next_debug.get("twin_visual_match", false)):
		failures.append("twin verification failed in the next seed bank")
	if canonical_signature == lab.get_preview_local_signature(0):
		failures.append("next seed bank did not change the surface recipe")

	lab.reset_seed_bank()
	var reset_debug: Dictionary = lab.get_debug_data()
	if int(reset_debug.get("bank_index", -1)) != 0:
		failures.append("reset did not restore the canonical bank")
	if lab.get_preview_local_signature(0) != canonical_signature:
		failures.append("reset did not restore the canonical signature")


func _validate_presentation() -> void:
	if lab == null:
		return
	var camera: Camera3D = lab.get_node_or_null(
		"InspectionCamera"
	) as Camera3D
	if camera == null or not camera.current:
		failures.append("inspection camera is missing or inactive")
	if lab.get_node_or_null("LaboratoryUI") == null:
		failures.append("laboratory readout is missing")
	var debug_data: Dictionary = lab.get_debug_data()
	var environment_data: Dictionary = debug_data.get(
		"environment",
		{}
	) as Dictionary
	for required_flag: String in [
		"procedural_sky",
		"aces",
		"ssao",
		"warm_key_cool_fill",
	]:
		if not bool(environment_data.get(required_flag, false)):
			failures.append(
				"presentation flag is false: " + required_flag
			)
	for enemy: Node in get_tree().get_nodes_in_group("enemy"):
		if lab.is_ancestor_of(enemy):
			failures.append("material lab unexpectedly contains an enemy")
			break
	for interactable: Node in get_tree().get_nodes_in_group("interactable"):
		if lab.is_ancestor_of(interactable):
			failures.append(
				"material lab unexpectedly contains an interactable"
			)
			break
