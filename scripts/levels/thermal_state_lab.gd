extends Node3D
class_name ThermalStateLab

const FireAbility: AbilityDefinition = preload("res://data/abilities/firebolt_ability.tres")
const IceAbility: AbilityDefinition = preload("res://data/abilities/ice_lance_ability.tres")

@export var readout_refresh_interval: float = 0.08

@onready var player: Node3D = get_node_or_null("Player") as Node3D

var ability_caster: Node
var initial_player_transform: Transform3D
var refresh_timer: float = 0.0
var active_spell_label: Label3D
var thermal_targets: Array[Dictionary] = []
var contact_link: ThermalContactLink
var water_volume: ThermalWaterVolume
var water_solver: DCCircuitSolver
var water_lamp: CircuitComponent
var water_lamp_light: OmniLight3D
var water_readout: Label3D
var heater_state: ThermalState
var heater_adapter: CircuitThermalAdapter
var heater_solver: DCCircuitSolver
var heater_readout: Label3D


func _ready() -> void:
	build_environment()
	resolve_contact_station(ThermalContactStation.build(self))
	resolve_phase_station(ThermalPhaseCircuitStation.build(self))
	resolve_heater_station(ThermalHeaterStation.build(self))
	configure_player()
	GameState.set_objective("Use Fire and Ice to change temperature, phase, heat transfer, and circuit behavior.")
	update_presentation()


func _process(delta: float) -> void:
	refresh_timer -= delta
	if refresh_timer > 0.0:
		return
	refresh_timer = max(readout_refresh_interval, 0.03)
	update_presentation()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		reset_lab()


func build_environment() -> void:
	ThermalLabGeometry.add_static_box(
		self, "Floor", Vector3(0.0, -0.5, 0.5), Vector3(20.0, 1.0, 18.0), Color(0.045, 0.055, 0.075, 1.0)
	)
	ThermalLabGeometry.add_static_box(
		self, "BackWall", Vector3(0.0, 2.0, 8.8), Vector3(20.0, 5.0, 0.6), Color(0.075, 0.085, 0.12, 1.0)
	)
	ThermalLabGeometry.add_static_box(
		self, "LeftWall", Vector3(-9.7, 2.0, 0.5), Vector3(0.6, 5.0, 18.0), Color(0.075, 0.085, 0.12, 1.0)
	)
	ThermalLabGeometry.add_static_box(
		self, "RightWall", Vector3(9.7, 2.0, 0.5), Vector3(0.6, 5.0, 18.0), Color(0.075, 0.085, 0.12, 1.0)
	)

	var light := DirectionalLight3D.new()
	light.name = "DirectionalLight3D"
	light.rotation_degrees = Vector3(-58.0, -28.0, 0.0)
	light.light_energy = 1.3
	light.shadow_enabled = true
	add_child(light)

	ThermalLabGeometry.add_label(
		self, "Title", "THERMAL STATE", Vector3(0.0, 4.6, -6.5), 42, Color(1.0, 0.76, 0.5, 1.0)
	)
	ThermalLabGeometry.add_label(
		self,
		"Instructions",
		"1 FIRE  •  2 ICE  •  LEFT: CONTACT  •  CENTER: WATER PHASE  •  RIGHT: RESISTIVE HEAT  •  F8 RESET",
		Vector3(0.0, 3.92, -6.35),
		21,
		Color(0.82, 0.88, 1.0, 1.0)
	)
	active_spell_label = ThermalLabGeometry.add_label(
		self,
		"ActiveSpell",
		"ACTIVE SPELL: FIREBOLT",
		Vector3(0.0, 3.3, -6.2),
		24,
		Color(1.0, 0.66, 0.34, 1.0)
	)


func resolve_contact_station(data: Dictionary) -> void:
	for raw_entry: Variant in data.get("targets", []):
		if raw_entry is Dictionary:
			thermal_targets.append(raw_entry as Dictionary)
	contact_link = data.get("contact_link") as ThermalContactLink


func resolve_phase_station(data: Dictionary) -> void:
	water_volume = data.get("water") as ThermalWaterVolume
	water_solver = data.get("solver") as DCCircuitSolver
	water_lamp = data.get("lamp") as CircuitComponent
	water_lamp_light = data.get("lamp_light") as OmniLight3D
	water_readout = data.get("readout") as Label3D


func resolve_heater_station(data: Dictionary) -> void:
	heater_state = data.get("state") as ThermalState
	heater_adapter = data.get("adapter") as CircuitThermalAdapter
	heater_solver = data.get("solver") as DCCircuitSolver
	heater_readout = data.get("readout") as Label3D
	thermal_targets.append({
		"name": "HEATING RESISTOR",
		"state": heater_state,
		"mesh": data.get("mesh") as MeshInstance3D,
		"label": null,
	})


func configure_player() -> void:
	if player == null:
		push_warning("Thermal laboratory could not find the player.")
		return
	player.add_to_group("player")
	initial_player_transform = player.transform
	ability_caster = player.get_node_or_null("AbilityCaster")
	if ability_caster == null:
		push_warning("Thermal laboratory could not find AbilityCaster.")
		return

	var loadout := AbilityLoadout.new()
	var learned: Array[AbilityDefinition] = []
	learned.append(FireAbility)
	learned.append(IceAbility)
	var equipped: Array[AbilityDefinition] = []
	equipped.append(FireAbility)
	equipped.append(IceAbility)
	loadout.learned_abilities = learned
	loadout.equipped_abilities = equipped
	loadout.quick_slot_count = 2
	ability_caster.set("loadout", loadout)
	ability_caster.set("current_ability_index", 0)
	var callback := Callable(self, "_on_ability_changed")
	if ability_caster.has_signal("ability_changed") and not ability_caster.is_connected("ability_changed", callback):
		ability_caster.connect("ability_changed", callback)
	if ability_caster.has_method("select_ability"):
		ability_caster.call("select_ability", 0, false)
	GameState.set_stat("mana", 999)


func _on_ability_changed(_ability_name: String, _ability_index: int) -> void:
	update_presentation()


func get_active_spell_name() -> String:
	if ability_caster != null and ability_caster.has_method("get_current_ability_name"):
		return str(ability_caster.call("get_current_ability_name"))
	return "Unavailable"


func update_presentation() -> void:
	if active_spell_label != null:
		active_spell_label.text = "ACTIVE SPELL: " + get_active_spell_name().to_upper()

	for entry: Dictionary in thermal_targets:
		var state: ThermalState = entry.get("state") as ThermalState
		var mesh: MeshInstance3D = entry.get("mesh") as MeshInstance3D
		var label: Label3D = entry.get("label") as Label3D
		if state == null:
			continue
		if mesh != null:
			mesh.material_override = ThermalLabGeometry.make_temperature_material(state.temperature_c)
		if label != null:
			label.text = (
				str(entry.get("name", "THERMAL BODY"))
				+ "\n"
				+ str(snapped(state.temperature_c, 0.1))
				+ " °C"
			)

	if water_lamp_light != null and water_lamp != null:
		water_lamp_light.visible = water_lamp.energized
	if water_readout != null and water_volume != null and water_solver != null:
		water_readout.text = (
			"WATER: " + water_volume.thermal_state.phase.to_upper()
			+ "  " + str(snapped(water_volume.thermal_state.temperature_c, 0.1)) + " °C"
			+ "\nCIRCUIT: " + ("CLOSED" if water_solver.circuit_closed else "OPEN")
			+ "  CURRENT: " + str(snapped(water_solver.current_amps, 0.01)) + " A"
		)

	if heater_readout != null and heater_state != null and heater_solver != null and heater_adapter != null:
		heater_readout.text = (
			"RESISTOR: " + str(snapped(heater_state.temperature_c, 0.1)) + " °C"
			+ "\nCURRENT: " + str(snapped(heater_solver.current_amps, 0.01)) + " A"
			+ "  HEAT: " + str(snapped(heater_adapter.last_power_w, 0.1)) + " W"
		)


func reset_lab() -> void:
	for entry: Dictionary in thermal_targets:
		var state: ThermalState = entry.get("state") as ThermalState
		if state != null:
			state.reset_target()
	if water_volume != null:
		water_volume.reset_target()
	if heater_adapter != null:
		heater_adapter.reset_target()
	if water_solver != null:
		water_solver.request_solve()
	if heater_solver != null:
		heater_solver.request_solve()
	if player != null:
		player.transform = initial_player_transform
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
	GameState.set_stat("mana", 999)
	refresh_timer = 0.0
	call_deferred("update_presentation")


func get_debug_data() -> Dictionary:
	return {
		"thermal_state_lab": true,
		"active_spell": get_active_spell_name(),
		"contact_transfer_j": contact_link.last_transfer_j if contact_link != null else 0.0,
		"water": water_volume.get_debug_data() if water_volume != null else {},
		"water_solver": water_solver.get_debug_data() if water_solver != null else {},
		"heater": heater_state.get_debug_data() if heater_state != null else {},
		"heater_adapter": heater_adapter.get_debug_data() if heater_adapter != null else {},
		"heater_solver": heater_solver.get_debug_data() if heater_solver != null else {},
	}
