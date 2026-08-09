extends Node

const GreenScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_green_grotto_art_target_v1.tscn"
)
const AirflowManagerScript = preload(
	"res://scripts/airflow/airflow_manager.gd"
)
const AirflowFieldScript = preload(
	"res://scripts/airflow/airflow_field_3d.gd"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var target: Node = GreenScene.instantiate()
	add_child(target)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	_expect(target is PrototypeGreenGrottoMotionPass, "Green Grotto installs environmental motion integration")
	_expect(
		str(target.get_meta("environmental_motion_authority", ""))
		== "EnvironmentalMotionDirector",
		"Green Grotto declares EnvironmentalMotionDirector authority"
	)

	var director: EnvironmentalMotionDirector3D = target.get_node_or_null(
		"EnvironmentalMotionDirector"
	) as EnvironmentalMotionDirector3D
	_expect(director != null, "EnvironmentalMotionDirector node exists")
	if director != null:
		_validate_director_contract(director)
		_validate_green_registration(target, director)
		_validate_spatial_motion_zones(target, director)
		_validate_motion_and_restore(director)
		_validate_grace_accessory_bridge(target, director)
		_validate_systemic_airflow_bridge(target, director)

	target.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_director_contract(director: EnvironmentalMotionDirector3D) -> void:
	var data: Dictionary = director.get_debug_data()
	_expect(bool(data.get("environmental_motion_director", false)), "Director publishes environmental-motion contract")
	_expect(str(data.get("profile_id", "")) == "green_grotto_motion", "Director owns Green Grotto motion profile")
	_expect(str(data.get("channel", "")) == "green_grotto_motion", "Director uses Green Grotto motion channel")
	_expect(bool(data.get("enabled", false)), "Director starts enabled")
	_expect(bool(data.get("debug_hotkeys", false)), "Green benchmark enables F5 motion comparison")
	_expect(bool(data.get("visual_only_ambient_wind", false)), "ambient wind is presentation-only")
	_expect(bool(data.get("systemic_airflow_aware", false)), "Director can listen to real airflow")
	_expect(str(data.get("airflow_manager", "")) == "", "Green does not create gameplay airflow just for ambience")


func _validate_green_registration(
	target: Node,
	director: EnvironmentalMotionDirector3D
) -> void:
	var data: Dictionary = director.get_debug_data()
	var kinds: Dictionary = _dictionary_value(data.get("target_kinds", {}))
	_expect(int(data.get("target_count", 0)) >= 100, "Green enrolls a substantial living-environment target set")
	_expect(int(kinds.get("foliage", 0)) >= 55, "ferns, cycads, and ground foliage animate by cluster")
	_expect(int(kinds.get("canopy", 0)) >= 28, "dense canopy crowns animate on a slow motion layer")
	_expect(int(kinds.get("vine", 0)) >= 24, "hanging vines receive delayed wind motion")
	_expect(int(kinds.get("water", 0)) == 2, "only upper stream and lower basin receive surface breathing")
	_expect(int(kinds.get("waterfall", 0)) == 4, "all four localized waterfall sheets receive flutter")

	var pass_data: Dictionary = {}
	if target.has_method("get_debug_data"):
		var value: Variant = target.call("get_debug_data")
		pass_data = _dictionary_value(value)
	_expect(bool(pass_data.get("green_grotto_environmental_motion", false)), "Green pass reports environmental motion")
	_expect(bool(pass_data.get("visual_ambient_wind_only", false)), "Green pass records no ambient gameplay force")
	_expect(bool(pass_data.get("wind_well_can_drive_environment_motion", false)), "Green pass records Wind Well interoperability")
	_expect(bool(pass_data.get("grace_accessory_wind", false)), "Green pass routes environment wind into Grace accessories")


func _validate_spatial_motion_zones(
	target: Node,
	director: EnvironmentalMotionDirector3D
) -> void:
	for zone_name: String in [
		"EntranceMotionZone",
		"CanopyMotionZone",
		"WaterfallMotionZone",
		"ShrineMotionZone",
	]:
		var zone: EnvironmentalMotionZone3D = target.get_node_or_null(zone_name) as EnvironmentalMotionZone3D
		_expect(zone != null, zone_name + " exists")
		if zone != null:
			_expect(zone.channel == "green_grotto_motion", zone_name + " shares the Director channel")
			_expect(zone.get_blend_weight(zone.global_position) >= 0.99, zone_name + " reaches full strength at center")

	director.elapsed = 0.0
	var entrance_wind: Vector3 = director.sample_visual_wind_at(Vector3(0.0, 4.0, 12.5), 0.3)
	var canopy_wind: Vector3 = director.sample_visual_wind_at(Vector3(0.0, 7.0, 0.0), 0.3)
	_expect(canopy_wind.length() > entrance_wind.length() * 1.35, "canopy opening visibly breathes harder than sheltered entrance")


func _validate_motion_and_restore(director: EnvironmentalMotionDirector3D) -> void:
	var foliage: Node3D = _first_motion_target_of_kind(director, "foliage")
	_expect(foliage != null, "test resolves a registered foliage cluster")
	if foliage == null:
		return
	var record: Dictionary = director.targets.get(foliage.get_instance_id(), {}) as Dictionary
	var base_position: Vector3 = record.get("base_position", foliage.position)
	var base_rotation: Vector3 = record.get("base_rotation", foliage.rotation)
	var base_scale: Vector3 = record.get("base_scale", foliage.scale)

	director.elapsed = 1.75
	director.call("_animate_targets", 0.22)
	var moved: bool = (
		foliage.rotation.distance_to(base_rotation) > 0.00005
		or foliage.position.distance_to(base_position) > 0.00005
		or foliage.scale.distance_to(base_scale) > 0.00005
	)
	_expect(moved, "ambient motion changes a foliage cluster transform")

	director.set_enabled(false)
	_expect(foliage.position.distance_to(base_position) < 0.000001, "F5/OFF restores exact authored position")
	_expect(foliage.rotation.distance_to(base_rotation) < 0.000001, "F5/OFF restores exact authored rotation")
	_expect(foliage.scale.distance_to(base_scale) < 0.000001, "F5/OFF restores exact authored scale")
	_expect(int(director.get_debug_data().get("restored_target_count", 0)) == director.targets.size(), "disable restores every live registered target")
	director.set_enabled(true)


func _validate_grace_accessory_bridge(
	target: Node,
	director: EnvironmentalMotionDirector3D
) -> void:
	var accessory: PlayerAccessoryWindResponse = target.get_node_or_null(
		"Player/AccessoryWindResponse"
	) as PlayerAccessoryWindResponse
	_expect(accessory != null, "Green installs Grace accessory wind response")
	if accessory == null:
		return
	var data: Dictionary = accessory.get_debug_data()
	_expect(bool(data.get("player_accessory_wind_response", false)), "accessory bridge publishes debug contract")
	_expect(bool(data.get("additive_only", false)), "accessory wind is additive to existing Grace animation")
	_expect(bool(data.get("sash", false)), "accessory bridge resolves Grace sash pivot")
	_expect(bool(data.get("hair_locks", false)), "accessory bridge resolves both hair pivots")
	_expect(str(data.get("director", "")) == director.name, "Grace listens to the same Environmental Motion Director as the level")
	var ambient_wind: Vector3 = accessory.sample_environment_wind_for_test()
	_expect(ambient_wind.length() > 0.05, "Grace accessories inherit the level's ambient visual wind")


func _validate_systemic_airflow_bridge(
	target: Node,
	director: EnvironmentalMotionDirector3D
) -> void:
	var accessory: PlayerAccessoryWindResponse = target.get_node_or_null(
		"Player/AccessoryWindResponse"
	) as PlayerAccessoryWindResponse
	var ambient_accessory_speed: float = 0.0
	if accessory != null:
		ambient_accessory_speed = accessory.sample_environment_wind_for_test().length()

	var manager: AirflowManager = AirflowManagerScript.new() as AirflowManager
	manager.name = "MotionTestAirflowManager"
	target.add_child(manager)
	var field: AirflowField3D = AirflowFieldScript.new() as AirflowField3D
	field.name = "MotionTestDirectionalField"
	field.field_id = "motion_test_field"
	field.field_kind = AirflowField3D.FieldKind.DIRECTIONAL
	field.volume_shape = AirflowField3D.VolumeShape.BOX
	field.box_extents = Vector3(40.0, 30.0, 40.0)
	field.local_direction = Vector3.RIGHT
	field.strength = 5.0
	field.turbulence_strength = 0.0
	target.add_child(field)
	manager.register_field(field)

	director.call("_resolve_airflow_manager")
	_expect(director.airflow_manager == manager, "Director discovers a gameplay AirflowManager when one appears")
	var sampled: Vector3 = manager.sample_total_airflow_fast(Vector3.ZERO, 0.0)
	_expect(sampled.length() > 4.8, "test airflow field provides meaningful systemic wind")

	director.elapsed += 2.0
	for raw_id: Variant in director.targets.keys():
		var record: Dictionary = director.targets[int(raw_id)] as Dictionary
		record["next_airflow_sample"] = 0.0
		director.targets[int(raw_id)] = record
	director.call("_animate_targets", 0.18)
	var data: Dictionary = director.get_debug_data()
	_expect(int(data.get("systemic_sample_count", 0)) > 0, "Director samples real airflow for enrolled environment targets")
	_expect(float(data.get("last_systemic_airflow_speed", 0.0)) > 4.5, "environment presentation receives strong local airflow")

	if accessory != null:
		var systemic_accessory_speed: float = accessory.sample_environment_wind_for_test().length()
		_expect(systemic_accessory_speed > ambient_accessory_speed + 0.35, "real airflow increases Grace's sash/hair wind response too")


func _first_motion_target_of_kind(
	director: EnvironmentalMotionDirector3D,
	kind: String
) -> Node3D:
	for raw_id: Variant in director.targets.keys():
		var record: Dictionary = director.targets[int(raw_id)] as Dictionary
		if str(record.get("kind", "")) != kind:
			continue
		var weak_value: Variant = record.get("ref", null)
		if weak_value is WeakRef:
			var target_value: Variant = (weak_value as WeakRef).get_ref()
			if target_value is Node3D:
				return target_value as Node3D
	return null


func _dictionary_value(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value as Dictionary
	return {}


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("ENVIRONMENTAL_MOTION_DIRECTOR_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("ENVIRONMENTAL_MOTION_DIRECTOR_SMOKE_TEST: " + failure)
	get_tree().quit(1)
