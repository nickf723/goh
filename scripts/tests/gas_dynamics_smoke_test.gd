extends Node

const SmokeGas: GasDefinition = preload("res://data/gas/smoke_gas.tres")
const PoisonGas: GasDefinition = preload("res://data/gas/poison_gas.tres")
const GasVolumeGridScript = preload("res://scripts/gas/gas_volume_grid.gd")
const GasManagerScript = preload("res://scripts/gas/gas_manager.gd")
const AirflowManagerScript = preload("res://scripts/airflow/airflow_manager.gd")
const GasLabScene: PackedScene = preload("res://scenes/levels/prototypes/prototype_gas_dynamics_lab_v1.tscn")

var failures: Array[String] = []


func _ready() -> void:
	test_gas_definitions()
	await test_density_grid_contract()
	await test_laboratory_contract()

	if failures.is_empty():
		print("GAS_DYNAMICS_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return

	for failure: String in failures:
		push_error("GAS_DYNAMICS_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func test_gas_definitions() -> void:
	if SmokeGas == null:
		failures.append("Smoke Gas definition failed to load")
	else:
		if SmokeGas.gas_id != "smoke":
			failures.append("Smoke Gas id must be smoke")
		if SmokeGas.buoyancy_velocity.y <= 0.0:
			failures.append("Smoke must have upward buoyancy")
		if SmokeGas.harmful:
			failures.append("Smoke v1 should obscure rather than damage")

	if PoisonGas == null:
		failures.append("Poison Gas definition failed to load")
	else:
		if PoisonGas.gas_id != "poison":
			failures.append("Poison Gas id must be poison")
		if PoisonGas.buoyancy_velocity.y >= 0.0:
			failures.append("Poison Gas must settle downward")
		if not PoisonGas.harmful:
			failures.append("Poison Gas must be harmful")


func test_density_grid_contract() -> void:
	var foundation := Node3D.new()
	foundation.name = "GasFoundationTest"
	add_child(foundation)

	var airflow_manager: Node = AirflowManagerScript.new()
	airflow_manager.name = "AirflowManager"
	foundation.add_child(airflow_manager)

	var gas_manager: Node = GasManagerScript.new()
	gas_manager.name = "GasManager"
	foundation.add_child(gas_manager)

	var volume: GasVolumeGrid = GasVolumeGridScript.new() as GasVolumeGrid
	volume.name = "TestSmokeVolume"
	volume.gas_definition = SmokeGas
	volume.grid_size = Vector3i(6, 4, 6)
	volume.cell_size = 1.0
	volume.show_density_visuals = false
	foundation.add_child(volume)

	await get_tree().process_frame
	volume.inject_density(volume.global_position, 0.8, 1.5)
	var initial_density: float = volume.sample_density(volume.global_position)
	if initial_density <= 0.0:
		failures.append("Injected density must be sampleable from the Gas grid")

	volume.simulate_step(0.1)
	if volume.get_total_density_mass() <= 0.0:
		failures.append("Gas grid must retain nonzero density after a simulation step")
	if not volume.has_method("sample_density"):
		failures.append("Gas grid must expose sample_density")
	if not volume.has_method("inject_density"):
		failures.append("Gas grid must expose inject_density")
	if float(gas_manager.call("sample_density", volume.global_position, "smoke")) <= 0.0:
		failures.append("GasManager must sample registered Gas volumes")

	foundation.queue_free()
	await get_tree().process_frame


func test_laboratory_contract() -> void:
	if GasLabScene == null:
		failures.append("Gas Dynamics laboratory scene failed to load")
		return

	var lab: Node = GasLabScene.instantiate()
	if lab == null:
		failures.append("Gas Dynamics laboratory scene failed to instantiate")
		return
	add_child(lab)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame

	var airflow_manager: Node = lab.get_node_or_null("AirflowManager")
	var gas_manager: Node = lab.get_node_or_null("GasManager")
	var player: Node = lab.get_node_or_null("Player")
	var smoke_volume: Node = lab.get_node_or_null("SmokeDensityGrid")
	var poison_volume: Node = lab.get_node_or_null("PoisonDensityGrid")
	var exposure_receiver: Node = player.get_node_or_null("GasExposureReceiver") if player != null else null

	if airflow_manager == null or not airflow_manager.has_method("sample_total_airflow"):
		failures.append("Gas laboratory requires the shared AirflowManager")
	if gas_manager == null or not gas_manager.has_method("sample_breakdown"):
		failures.append("Gas laboratory requires GasManager sampling")
	if smoke_volume == null or str(smoke_volume.get("gas_id")) != "smoke":
		failures.append("Gas laboratory must build a Smoke density grid")
	if poison_volume == null or str(poison_volume.get("gas_id")) != "poison":
		failures.append("Gas laboratory must build a Poison density grid")
	if exposure_receiver == null:
		failures.append("Grace must receive a GasExposureReceiver in the laboratory")
	if get_tree().get_nodes_in_group("gas_emitters").size() < 2:
		failures.append("Gas laboratory must contain Smoke and Poison emitters")
	if get_tree().get_nodes_in_group("gas_sensors").size() < 4:
		failures.append("Gas laboratory must contain density sensors")

	lab.queue_free()
	await get_tree().process_frame
