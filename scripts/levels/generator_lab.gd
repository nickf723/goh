extends Node3D
class_name GeneratorLab

const FireAbility: AbilityDefinition = preload("res://data/abilities/firebolt_ability.tres")
const IceAbility: AbilityDefinition = preload("res://data/abilities/ice_lance_ability.tres")

@export var readout_refresh_interval: float = 0.08

@onready var player: Node3D = get_node_or_null("Player") as Node3D

var ability_caster: Node
var initial_player_transform: Transform3D
var refresh_timer: float = 0.0
var completion_announced: bool = false
var active_spell_label: Label3D

var water: ThermalWaterVolume
var reservoir: PressureReservoir
var thermal_adapter: ThermalPressureAdapter
var shaft: RotationalShaftState
var turbine: PressureTurbine
var generator: RotationalGeneratorSource
var solver: DCCircuitSolver
var lamp: CircuitComponent
var lamp_light: OmniLight3D
var coil: ElectromagneticCoilComponent
var magnetic_field: MagneticDipoleField
var iron_puck: FieldResponsiveBody
var valve: PressureReliefValve
var readout: Label3D
var clutch_label: Label3D


func _ready() -> void:
	build_environment()
	resolve_machine(GeneratorMachineStation.build(self))
	configure_player()
	GameState.set_objective("Use Fire to boil the water and drive the generator circuit.")
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
		self,
		"Floor",
		Vector3(0.0, -0.5, 0.6),
		Vector3(22.0, 1.0, 19.0),
		Color(0.04, 0.05, 0.07, 1.0)
	)
	ThermalLabGeometry.add_static_box(
		self,
		"BackWall",
		Vector3(0.0, 2.0, 9.4),
		Vector3(22.0, 5.0, 0.6),
		Color(0.07, 0.085, 0.12, 1.0)
	)
	ThermalLabGeometry.add_static_box(
		self,
		"LeftWall",
		Vector3(-10.7, 2.0, 0.6),
		Vector3(0.6, 5.0, 19.0),
		Color(0.07, 0.085, 0.12, 1.0)
	)
	ThermalLabGeometry.add_static_box(
		self,
		"RightWall",
		Vector3(10.7, 2.0, 0.6),
		Vector3(0.6, 5.0, 19.0),
		Color(0.07, 0.085, 0.12, 1.0)
	)

	var light := DirectionalLight3D.new()
	light.name = "DirectionalLight3D"
	light.rotation_degrees = Vector3(-58.0, -28.0, 0.0)
	light.light_energy = 1.3
	light.shadow_enabled = true
	add_child(light)

	ThermalLabGeometry.add_label(
		self,
		"Title",
		"STEAM GENERATOR",
		Vector3(0.0, 4.9, -6.6),
		42,
		Color(1.0, 0.78, 0.48, 1.0)
	)
	ThermalLabGeometry.add_label(
		self,
		"Instructions",
		"1 FIRE  •  2 ICE  •  BOIL → PRESSURE → RPM → VOLTAGE  •  INTERACT WITH CLUTCH OR RELIEF VALVE  •  F8 RESET",
		Vector3(0.0, 4.2, -6.35),
		20,
		Color(0.8, 0.88, 1.0, 1.0)
	)
	active_spell_label = ThermalLabGeometry.add_label(
		self,
		"ActiveSpell",
		"ACTIVE SPELL: FIREBOLT",
		Vector3(0.0, 3.58, -6.1),
		23,
		Color(1.0, 0.64, 0.3, 1.0)
	)


func resolve_machine(data: Dictionary) -> void:
	water = data.get("water") as ThermalWaterVolume
	reservoir = data.get("reservoir") as PressureReservoir
	thermal_adapter = data.get("thermal_adapter") as ThermalPressureAdapter
	shaft = data.get("shaft") as RotationalShaftState
	turbine = data.get("turbine") as PressureTurbine
	generator = data.get("generator") as RotationalGeneratorSource
	solver = data.get("solver") as DCCircuitSolver
	lamp = data.get("lamp") as CircuitComponent
	lamp_light = data.get("lamp_light") as OmniLight3D
	coil = data.get("coil") as ElectromagneticCoilComponent
	magnetic_field = data.get("magnetic_field") as MagneticDipoleField
	iron_puck = data.get("iron_puck") as FieldResponsiveBody
	valve = data.get("valve") as PressureReliefValve
	readout = data.get("readout") as Label3D
	clutch_label = data.get("clutch_label") as Label3D


func configure_player() -> void:
	if player == null:
		push_warning("Generator laboratory could not find the player.")
		return
	player.add_to_group("player")
	initial_player_transform = player.transform
	ability_caster = player.get_node_or_null("AbilityCaster")
	if ability_caster == null:
		push_warning("Generator laboratory could not find AbilityCaster.")
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
	if water == null or reservoir == null or shaft == null or generator == null or solver == null:
		return

	if lamp_light != null:
		lamp_light.visible = lamp != null and lamp.energized
		lamp_light.light_energy = 1.0 + solver.current_amps * 1.2 if lamp_light.visible else 0.0
	if clutch_label != null:
		clutch_label.text = (
			"GENERATOR CLUTCH\n"
			+ ("COUPLED  •  INTERACT TO DISCONNECT" if generator.coupled else "DISCONNECTED  •  INTERACT TO COUPLE")
		)
		clutch_label.modulate = Color(0.72, 1.0, 0.72, 1.0) if generator.coupled else Color(1.0, 0.48, 0.42, 1.0)

	if readout != null:
		var circuit_text: String = "CLOSED" if solver.circuit_closed else "OPEN"
		var lamp_text: String = "ON" if lamp != null and lamp.energized else "OFF"
		var magnet_text: String = "MAGNETIC" if magnetic_field != null and magnetic_field.active else "OFF"
		var safety_text: String = "AUTO-VENT" if valve != null and valve.automatic_venting else "SAFE"
		readout.text = (
			"WATER: " + water.thermal_state.phase.to_upper()
			+ "  " + str(snapped(water.thermal_state.temperature_c, 0.1)) + " °C"
			+ "\nPRESSURE: " + str(snapped(reservoir.current_pressure, 0.1))
			+ " / " + str(snapped(reservoir.maximum_pressure, 0.1))
			+ "  " + safety_text
			+ "\nTURBINE: " + str(snapped(shaft.current_rpm, 1.0)) + " RPM"
			+ "  GENERATOR: " + str(snapped(generator.generated_voltage, 0.1)) + " V"
			+ "  " + ("COUPLED" if generator.coupled else "DISCONNECTED")
			+ "\nCIRCUIT: " + circuit_text
			+ "  CURRENT: " + str(snapped(solver.current_amps, 0.01)) + " A"
			+ "  LAMP: " + lamp_text
			+ "  COIL: " + magnet_text
		)

	if not completion_announced and solver.circuit_closed and solver.current_amps > 0.05:
		completion_announced = true
		GameState.set_objective("Disconnect the generator clutch, then cool or vent the boiler.")
		show_message("Steam rotation is now generating electrical power.")


func reset_lab() -> void:
	if water != null:
		water.reset_target()
	if reservoir != null:
		reservoir.reset_pressure()
	if thermal_adapter != null:
		thermal_adapter.reset_target()
	if turbine != null:
		turbine.reset_target()
	if shaft != null:
		shaft.reset_target()
	if generator != null:
		generator.reset_target()
	if valve != null:
		valve.reset_target()
	if iron_puck != null:
		iron_puck.reset_target()
	if solver != null:
		solver.request_solve()
	if player != null:
		player.transform = initial_player_transform
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
	GameState.set_stat("mana", 999)
	completion_announced = false
	refresh_timer = 0.0
	call_deferred("update_presentation")
	show_message("Generator laboratory reset.")


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	return {
		"generator_lab": true,
		"active_spell": get_active_spell_name(),
		"water": water.get_debug_data() if water != null else {},
		"pressure": reservoir.get_debug_data() if reservoir != null else {},
		"thermal_adapter": thermal_adapter.get_debug_data() if thermal_adapter != null else {},
		"turbine": turbine.get_debug_data() if turbine != null else {},
		"shaft": shaft.get_debug_data() if shaft != null else {},
		"generator": generator.get_debug_data() if generator != null else {},
		"solver": solver.get_debug_data() if solver != null else {},
		"coil": coil.get_debug_data() if coil != null else {},
		"iron_puck": iron_puck.get_debug_data() if iron_puck != null else {},
	}
