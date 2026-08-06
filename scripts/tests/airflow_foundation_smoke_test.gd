extends Node

const AirflowMathScript = preload("res://scripts/airflow/airflow_math.gd")
const AirflowManagerScript = preload("res://scripts/airflow/airflow_manager.gd")
const AirflowFieldScript = preload("res://scripts/airflow/airflow_field_3d.gd")
const GustAbility: Resource = preload("res://data/abilities/gust_ability.tres")
const AirflowLabScene: PackedScene = preload("res://scenes/levels/prototypes/prototype_airflow_lab_v1.tscn")
const AirflowTestBodyScene: PackedScene = preload(
	"res://scenes/actors/props/airflow_test_body.tscn"
)

var failures: Array[String] = []


func _ready() -> void:
	test_drag_math()
	await test_analytic_fields()
	await test_vertical_field_body_integration()
	test_gust_definition()
	await test_lab_contract()

	if failures.is_empty():
		print("AIRFLOW_FOUNDATION_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("AIRFLOW_FOUNDATION_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func test_drag_math() -> void:
	var air_velocity := Vector3(10.0, 0.0, 0.0)
	var light_acceleration: Vector3 = AirflowMathScript.compute_drag_acceleration(air_velocity, Vector3.ZERO, 1.0, 1.0, 1.0, 1.225, 1.0, 100.0)
	var heavy_acceleration: Vector3 = AirflowMathScript.compute_drag_acceleration(air_velocity, Vector3.ZERO, 10.0, 1.0, 1.0, 1.225, 1.0, 100.0)
	if light_acceleration.x <= 0.0:
		failures.append("Drag acceleration must follow the relative airflow direction")
	if light_acceleration.length() <= heavy_acceleration.length():
		failures.append("Equal aerodynamic area must accelerate a lighter body more strongly")


func test_analytic_fields() -> void:
	var manager: Node = AirflowManagerScript.new()
	manager.name = "SmokeAirflowManager"
	add_child(manager)
	var directional: Node3D = AirflowFieldScript.new() as Node3D
	directional.name = "SmokeDirectionalField"
	directional.set("field_id", "smoke_directional")
	directional.set("field_kind", AirflowFieldScript.FieldKind.DIRECTIONAL)
	directional.set("volume_shape", AirflowFieldScript.VolumeShape.BOX)
	directional.set("box_extents", Vector3(2.0, 2.0, 2.0))
	directional.set("local_direction", Vector3.RIGHT)
	directional.set("strength", 8.0)
	directional.set("edge_fade_fraction", 0.0)
	add_child(directional)
	await get_tree().process_frame

	var inside: Vector3 = manager.call("sample_total_airflow", Vector3.ZERO) as Vector3
	var outside: Vector3 = manager.call("sample_total_airflow", Vector3(8.0, 0.0, 0.0)) as Vector3
	if not is_equal_approx(inside.x, 8.0):
		failures.append("Directional field must return its authored velocity inside the volume")
	if outside.length() > 0.001:
		failures.append("Finite airflow fields must return zero outside their volume")

	var vortex: Node3D = AirflowFieldScript.new() as Node3D
	vortex.name = "SmokeVortexField"
	vortex.position = Vector3(10.0, 0.0, 0.0)
	vortex.set("field_id", "smoke_vortex")
	vortex.set("field_kind", AirflowFieldScript.FieldKind.VORTEX)
	vortex.set("volume_shape", AirflowFieldScript.VolumeShape.CYLINDER)
	vortex.set("radius", 4.0)
	vortex.set("cylinder_height", 6.0)
	vortex.set("strength", 6.0)
	vortex.set("vortex_inward_fraction", 0.25)
	vortex.set("edge_fade_fraction", 0.0)
	add_child(vortex)
	await get_tree().process_frame
	var vortex_sample: Vector3 = vortex.call("sample_air_velocity", Vector3(12.0, 0.0, 0.0), 0.0) as Vector3
	if abs(vortex_sample.z) <= 0.1:
		failures.append("Vortex field must include a tangential component")
	if vortex_sample.x >= 0.0:
		failures.append("Vortex field must include its authored inward radial component")

	directional.queue_free()
	vortex.queue_free()
	manager.queue_free()
	await get_tree().process_frame


func test_vertical_field_body_integration() -> void:
	var manager: Node = AirflowManagerScript.new()
	manager.name = "VerticalIntegrationAirflowManager"
	add_child(manager)

	var updraft: Node3D = AirflowFieldScript.new() as Node3D
	updraft.name = "VerticalIntegrationUpdraft"
	updraft.position = Vector3(0.0, 2.0, 0.0)
	updraft.set("field_id", "vertical_integration_updraft")
	updraft.set("field_kind", AirflowFieldScript.FieldKind.UPDRAFT)
	updraft.set("volume_shape", AirflowFieldScript.VolumeShape.CYLINDER)
	updraft.set("radius", 3.0)
	updraft.set("cylinder_height", 6.0)
	updraft.set("strength", 10.0)
	updraft.set("edge_fade_fraction", 0.0)
	updraft.set("turbulence_strength", 0.0)
	add_child(updraft)

	var light: FieldResponsiveBody = (
		AirflowTestBodyScene.instantiate() as FieldResponsiveBody
	)
	light.name = "VerticalLightBody"
	light.position = Vector3(-0.8, 2.0, 0.0)
	light.mass_override_kg = 2.0
	light.gravity_strength = 20.0
	var light_response: AirflowResponse = light.get_node_or_null(
		"AirflowResponse"
	) as AirflowResponse
	if light_response != null:
		light_response.mass_override_kg = 2.0
	add_child(light)

	var heavy: FieldResponsiveBody = (
		AirflowTestBodyScene.instantiate() as FieldResponsiveBody
	)
	heavy.name = "VerticalHeavyBody"
	heavy.position = Vector3(0.8, 2.0, 0.0)
	heavy.mass_override_kg = 18.0
	heavy.gravity_strength = 20.0
	var heavy_response: AirflowResponse = heavy.get_node_or_null(
		"AirflowResponse"
	) as AirflowResponse
	if heavy_response != null:
		heavy_response.mass_override_kg = 18.0
	add_child(heavy)

	await get_tree().process_frame
	var light_start_y: float = light.global_position.y
	var heavy_start_y: float = heavy.global_position.y
	for _frame: int in range(45):
		await get_tree().physics_frame

	if light.global_position.y <= light_start_y + 0.25:
		failures.append("A sustained updraft must lift a light FieldResponsiveBody against gravity")
	if heavy.global_position.y >= heavy_start_y - 0.1:
		failures.append("A heavy FieldResponsiveBody must continue falling when the same updraft cannot overcome gravity")
	if light.gravity_velocity <= heavy.gravity_velocity:
		failures.append("Vertical field integration must preserve mass-sensitive acceleration")
	if light.last_vertical_acceleration <= 0.0:
		failures.append("Light body must report positive net vertical acceleration inside the updraft")
	if heavy.last_vertical_acceleration >= 0.0:
		failures.append("Heavy body must report negative net vertical acceleration inside the same updraft")

	light.queue_free()
	heavy.queue_free()
	updraft.queue_free()
	manager.queue_free()
	await get_tree().process_frame


func test_gust_definition() -> void:
	if GustAbility == null:
		failures.append("Gust ability failed to load")
		return
	if str(GustAbility.get("spell_id")) != "gust":
		failures.append("Gust spell id must be gust")
	if str(GustAbility.get("element")) != "air":
		failures.append("Gust must belong to Air")
	if GustAbility.get("ability_scene") == null:
		failures.append("Gust must reference its moving field scene")


func test_lab_contract() -> void:
	if AirflowLabScene == null:
		failures.append("Airflow laboratory scene failed to load")
		return
	var lab: Node = AirflowLabScene.instantiate()
	if lab == null:
		failures.append("Airflow laboratory scene failed to instantiate")
		return
	add_child(lab)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame

	var manager: Node = lab.get_node_or_null("AirflowManager")
	var player: Node = lab.get_node_or_null("Player")
	var response: Node = player.get_node_or_null("AirflowResponse") if player != null else null
	var aerial: Node = player.get_node_or_null("AerialLocomotion") if player != null else null
	if manager == null or not manager.has_method("sample_total_airflow"):
		failures.append("Airflow laboratory must include a sampling manager")
	if player == null:
		failures.append("Airflow laboratory is missing Grace")
	if response == null:
		failures.append("Grace must include AirflowResponse")
	if aerial == null:
		failures.append("Grace must include AerialLocomotion")
	elif not bool(aerial.get("flight_unlocked")):
		failures.append("Airflow laboratory must unlock Flight for field testing")
	if lab.get_tree().get_nodes_in_group("airflow_fields").size() < 4:
		failures.append("Airflow laboratory must create directional, updraft, downdraft, and vortex fields")

	lab.queue_free()
	await get_tree().process_frame
