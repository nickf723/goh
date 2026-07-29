extends Node3D
class_name RuviaEmberHalberdRig

var weapon_definition: WeaponDefinition
var weapon_controller: WeaponController
var blade_materials: Array[StandardMaterial3D] = []
var accent_materials: Array[StandardMaterial3D] = []
var shaft_materials: Array[StandardMaterial3D] = []
var base_emission_energy: Dictionary = {}
var active_attack_id: String = ""
var active_phase: String = "idle"
var active_heat: float = 0.0
var active_finisher: bool = false
var total_target_hits: int = 0
var last_target_count: int = 0
var last_payload_element: String = "none"
var last_payload_status: String = "none"
var last_payload_tags: Array[String] = []


func _ready() -> void:
	add_to_group("ruvia_ember_halberd_rig")
	add_to_group("debuggable")
	_collect_materials(self)
	_apply_heat(0.0, false)


func configure_weapon(
	weapon: WeaponDefinition,
	controller: WeaponController
) -> void:
	weapon_definition = weapon
	weapon_controller = controller


func begin_attack(
	attack: WeaponAttackDefinition,
	attack_speed: float = 1.0
) -> void:
	if attack == null:
		return
	active_attack_id = attack.attack_id
	active_finisher = _is_finisher(attack)
	update_attack_pose(attack, 0.0, attack_speed)


func update_attack_pose(
	attack: WeaponAttackDefinition,
	elapsed: float,
	attack_speed: float = 1.0
) -> void:
	if attack == null:
		return
	active_attack_id = attack.attack_id
	active_finisher = _is_finisher(attack)
	var startup: float = maxf(attack.get_startup_duration(attack_speed), 0.001)
	var active: float = maxf(attack.get_active_duration(attack_speed), 0.001)
	var recovery: float = maxf(attack.get_recovery_duration(attack_speed), 0.001)
	var time: float = maxf(elapsed, 0.0)
	if time < startup:
		active_phase = "startup"
		active_heat = smoothstep(0.0, 1.0, clampf(time / startup, 0.0, 1.0))
	elif time < startup + active:
		active_phase = "active"
		active_heat = 1.0
	else:
		active_phase = "recovery"
		var recovery_weight: float = clampf(
			(time - startup - active) / recovery,
			0.0,
			1.0
		)
		active_heat = 1.0 - smoothstep(0.0, 1.0, recovery_weight)
	_apply_heat(active_heat, active_finisher)


func end_attack() -> void:
	active_attack_id = ""
	active_phase = "idle"
	active_heat = 0.0
	active_finisher = false
	_apply_heat(0.0, false)


func modify_attack_payload(
	payload: DamagePayload,
	attack: WeaponAttackDefinition
) -> void:
	if payload == null or attack == null:
		return
	_append_tag(payload.tags, "halberd")
	_append_tag(payload.tags, "ruvia")
	_append_tag(payload.tags, "two_handed")
	_append_tag(payload.tags, "divine_incarnation")

	var is_haft_check: bool = (
		attack.attack_id == "ruvia_halberd_l3"
		or attack.extra_tags.has("haft")
	)
	if is_haft_check:
		payload.element = "neutral"
		payload.status_effect = ""
		payload.status_duration = 0.0
		payload.status_strength = 0.0
		payload.tags.erase("fire")
		_append_tag(payload.tags, "physical")
		_append_tag(payload.tags, "haft")
		_append_tag(payload.tags, "close_control")
	else:
		payload.element = "fire"
		payload.status_effect = "burning"
		payload.status_duration = maxf(
			payload.status_duration,
			1.7 if attack.input_kind == "light" else 2.1
		)
		payload.status_strength = maxf(payload.status_strength, 1.0)
		_append_tag(payload.tags, "fire")
		_append_tag(payload.tags, "divine_fire")

	if attack.extra_tags.has("hook"):
		_append_tag(payload.tags, "pull")
		payload.knockback_strength *= 0.72
	if attack.attack_id == "ruvia_halberd_h4":
		payload.status_duration = maxf(payload.status_duration, 2.8)
		payload.status_strength = maxf(payload.status_strength, 1.4)
		payload.knockback_up_strength += 2.2
		_append_tag(payload.tags, "solar_descent")
		_append_tag(payload.tags, "divine_finisher")

	last_payload_element = payload.element
	last_payload_status = (
		payload.status_effect if payload.status_effect != "" else "none"
	)
	last_payload_tags = payload.tags.duplicate()


func on_weapon_targets_hit(
	targets: Array[Node],
	attack: WeaponAttackDefinition
) -> void:
	last_target_count = targets.size()
	total_target_hits += targets.size()
	if attack != null and not targets.is_empty():
		_apply_heat(1.0, _is_finisher(attack))


func get_debug_data() -> Dictionary:
	return {
		"rig_id": "ruvia_ember_halberd",
		"configured": weapon_definition != null and weapon_controller != null,
		"two_handed": true,
		"support_grip_supported": true,
		"active_attack_id": active_attack_id,
		"active_phase": active_phase,
		"active_heat": snappedf(active_heat, 0.01),
		"active_finisher": active_finisher,
		"blade_material_count": blade_materials.size(),
		"accent_material_count": accent_materials.size(),
		"shaft_material_count": shaft_materials.size(),
		"last_target_count": last_target_count,
		"total_target_hits": total_target_hits,
		"last_payload_element": last_payload_element,
		"last_payload_status": last_payload_status,
		"last_payload_tags": last_payload_tags.duplicate(),
	}


func _collect_materials(root: Node) -> void:
	for child: Node in root.get_children():
		if child is MeshInstance3D:
			var mesh_instance: MeshInstance3D = child as MeshInstance3D
			var source_material: StandardMaterial3D = (
				mesh_instance.material_override as StandardMaterial3D
			)
			if source_material != null:
				var material: StandardMaterial3D = (
					source_material.duplicate(true) as StandardMaterial3D
				)
				mesh_instance.material_override = material
				base_emission_energy[material.get_instance_id()] = (
					material.emission_energy_multiplier
				)
				match mesh_instance.name:
					"SpearTip", "AxeBlade":
						blade_materials.append(material)
					"Collar", "BackHook", "ButtCap":
						accent_materials.append(material)
					_:
						shaft_materials.append(material)
		_collect_materials(child)


func _apply_heat(weight: float, finisher: bool) -> void:
	var heat: float = clampf(weight, 0.0, 1.0)
	for material: StandardMaterial3D in blade_materials:
		var base: float = float(
			base_emission_energy.get(material.get_instance_id(), 1.5)
		)
		material.emission_energy_multiplier = (
			base + heat * (2.35 if finisher else 1.35)
		)
	for material: StandardMaterial3D in accent_materials:
		var base: float = float(
			base_emission_energy.get(material.get_instance_id(), 1.8)
		)
		material.emission_energy_multiplier = (
			base + heat * (1.65 if finisher else 0.9)
		)
	for material: StandardMaterial3D in shaft_materials:
		if not material.emission_enabled:
			continue
		var base: float = float(
			base_emission_energy.get(material.get_instance_id(), 0.0)
		)
		material.emission_energy_multiplier = base + heat * 0.35


func _is_finisher(attack: WeaponAttackDefinition) -> bool:
	return (
		attack != null
		and (
			attack.extra_tags.has("finisher")
			or attack.extra_tags.has("divine_finisher")
			or attack.attack_id == "ruvia_halberd_h4"
		)
	)


func _append_tag(tags: Array[String], tag: String) -> void:
	if tag != "" and not tags.has(tag):
		tags.append(tag)
