extends Node3D
class_name MotorLab

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
var generator_shaft: RotationalShaftState
var turbine: PressureTurbine
var generator: RotationalGeneratorSource
var solver: DCCircuitSolver
var lamp: CircuitComponent
var lamp_light: OmniLight3D
var valve: PressureReliefValve
var readout: Label3D
var generator_clutch_label: Label3D
var motor: ElectricMotorComponent
var motor_shaft: RotationalShaftState
var conveyor: RotationalConveyorDrive
var carriage: Node3D
var motor_label: Label3D
var conveyor_label: Label3D


func _ready() -> void:
	build_environment()
	resolve_machine(MotorMachineStation.build(self))
	configure_player()
	GameState.set_objective("Use Fire to drive the generator, motor, and conveyor through the full energy chain.")
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
		Vector3(24.0, 1.0, 19.0),
		Color(0.035, 0.045, 0.065, 1.0)
	)
	ThermalLabGeometry.add_static_box(
		self,
		"BackWall",
		Vector3(0.0, 2.0, 9.4),
		Vector3(24.0, 5.0, 0.6),
		Color(0.065, 0.08, 0.115, 1.0)
	)
	ThermalLabGeometry.add_static_box(
		self,
		"LeftWall",
		Vector3(-11.7, 2.0, 0.6),
		Vector3(0.6, 5.0, 19.0),
		Color(0.065, 0.08, 0.115, 1.0)
	)
	ThermalLabGeometry.add_static_box(
		self,
		"RightWall",
		Vector3(11.7, 2.0, 0.6),
		Vector3(0.6, 5.0, 19.0),
		Color(0.065, 0.08, 0.115, 1.0)
	)

	var light := DirectionalLight3D.new()
	light.name = "DirectionalLight3D"
	light.rotation_degrees = Vector3(-58.0, -28.0, 0.0)
	light.light_energy = 1.35
	light.shadow_enabled = true
	add_child(light)

	ThermalLabGeometry.add_label(
		self,
		"Title",
		"ENERGY OUROBOROS",
		Vector3(0.0, 4.95, -6.65),
		42,
		Color(1.0, 0.78, 0.46, 1.0)
	)
	ThermalLabGeometry.add_label(
		self,
		"Instructions",
		"1 FIRE  •  2 ICE  •  HEAT → STEAM → ROTATION → ELECTRICITY → ROTATION → WORK  •  INTERACT WITH THREE CLUTCHES  •  F8 RESET",
		Vector3(0.0, 4.25, -6.35),
		19,
		Color(0.8, 0.88, 1.0, 1.0)
	)
	active_spell_label = ThermalLabGeometry.add_label(
		self,
		"ActiveSpell",
		"ACTIVE SPELL: FIREBOLT",
		Vector3(0.0, 3.62, -6.1),
		23,
		Color(1.0, 0.64, 0.3, 1.0)
	)


func resolve_machine(data: Dictionary) -> void:
	water = data.get("water") as ThermalWaterVolume
	reservoir = data.get("reservoir") as PressureReservoir
	thermal_adapter = data.get("thermal_adapter") as ThermalPressureAdapter
	generator_shaft = data.get("shaft") as RotationalShaftState
	turbine = data.get("turbine") as PressureTurbine
	generator = data.get("generator") as RotationalGeneratorSource
	solver = data.get("solver") as DCCircuitSolver
	lamp = data.get("lamp") as CircuitComponent
	lamp_light = data.get("lamp_light") as OmniLight3D
	valve = data.get("valve") as PressureReliefValve
	readout = data.get("readout") as Label3D
	generator_clutch_label = data.get("clutch_label") as Label3D
	motor = data.get("motor") as ElectricMotorComponent
	motor_shaft = data.get("motor_shaft") as RotationalShaftState
	conveyor = data.get("conveyor") as RotationalConveyorDrive
	carriage = data.get("carriage") as Node3D
	motor_label = data.get("motor_label") as Label3D
	conveyor_label = data.get("conveyor_label") as Label3D


func configure_player() -> void:
	if player == null:
		push_warning("Motor laboratory could not find the player.")
		return
	player.add_to_group("player")
	initial_player_transform = player.transform
	ability_caster = player.get_node_or_null("AbilityCaster")
	if ability_caster == null:
		push_warning("Motor laboratory could not find AbilityCaster.")
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
	if water == null or reservoir == null or generator_shaft == null or generator == null or solver == null or motor == null or motor_shaft == null:
		return

	if lamp_light != null:
		lamp_light.visible = lamp != null and lamp.energized
		lamp_light.light_energy = 1.0 + solver.current_amps * 1.2 if lamp_light.visible else 0.0
	if generator_clutch_label != null:
		generator_clutch_label.text = (
			"GENERATOR CLUTCH\n"
			+ ("COUPLED  •  INTERACT TO DISCONNECT" if generator.coupled else "DISCONNECTED  •  INTERACT TO COUPLE")
		)
		generator_clutch_label.modulate = Color(0.72, 1.0, 0.72, 1.0) if generator.coupled else Color(1.0, 0.48, 0.42, 1.0)
	if motor_label != null:
		motor_label.text = (
			"MOTOR WINDING\n"
			+ ("FORWARD" if motor.winding_sign > 0 else "REVERSED")
			+ "  •  INTERACT TO REVERSE"
		)
		motor_label.modulate = Color(0.62, 0.86, 1.0, 1.0) if motor.winding_sign > 0 else Color(1.0, 0.66, 0.32, 1.0)
	if conveyor_label != null and conveyor != null:
		conveyor_label.text = (
			"CONVEYOR CLUTCH\n"
			+ ("COUPLED  •  INTERACT TO DISCONNECT" if conveyor.coupled else "DISCONNECTED  •  INTERACT TO COUPLE")
		)
		conveyor_label.modulate = Color(0.72, 1.0, 0.72, 1.0) if conveyor.coupled else Color(1.0, 0.48, 0.42, 1.0)

	if readout != null:
		var circuit_text: String = "CLOSED" if solver.circuit_closed else "OPEN"
		var lamp_text: String = "ON" if lamp != null and lamp.energized else "OFF"
		var motor_direction: String = "FORWARD" if motor_shaft.current_rpm >= 0.0 else "REVERSE"
		var load_text: String = "WORKING" if conveyor != null and conveyor.coupled and absf(motor_shaft.current_rpm) > 10.0 else "IDLE"
		readout.text = (
			"WATER: " + water.thermal_state.phase.to_upper()
			+ "  " + str(snapped(water.thermal_state.temperature_c, 0.1)) + " °C"
			+ "  PRESSURE: " + str(snapped(reservoir.current_pressure, 0.1))
			+ "\nGENERATOR SHAFT: " + str(snapped(generator_shaft.current_rpm, 1.0)) + " RPM"
			+ "  OUTPUT: " + str(snapped(generator.generated_voltage, 0.1)) + " V"
			+ "\nCIRCUIT: " + circuit_text
			+ "  CURRENT: " + str(snapped(solver.current_amps, 0.01)) + " A"
			+ "  LAMP: " + lamp_text
			+ "\nMOTOR SHAFT: " + str(snapped(motor_shaft.current_rpm, 1.0)) + " RPM " + motor_direction
			+ "  POWER: " + str(snapped(motor.last_electrical_power_w, 0.1)) + " W"
			+ "\nCONVEYOR: " + load_text
			+ "  TRAVEL: " + str(snapped(conveyor.total_distance_moved, 0.1) if conveyor != null else 0.0) + " m"
		)

	if not completion_announced and conveyor != null and conveyor.total_distance_moved > 0.4:
		completion_announced = true
		GameState.set_objective("Reverse the motor winding, then disconnect the conveyor and generator clutches.")
		show_message("The full energy chain now ends in useful mechanical work.")


func reset_lab() -> void:
	if water != null:
		water.reset_target()
	if reservoir != null:
		reservoir.reset_pressure()
	if thermal_adapter != null:
		thermal_adapter.reset_target()
	if turbine != null:
		turbine.reset_target()
	if generator_shaft != null:
		generator_shaft.reset_target()
	if generator != null:
		generator.reset_target()
	if motor != null:
		motor.reset_target()
	if motor_shaft != null:
		motor_shaft.reset_target()
	if conveyor != null:
		conveyor.reset_target()
	if valve != null:
		valve.reset_target()
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
	show_message("Energy ouroboros laboratory reset.")


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	return {
		"motor_lab": true,
		"active_spell": get_active_spell_name(),
		"water": water.get_debug_data() if water != null else {},
		"pressure": reservoir.get_debug_data() if reservoir != null else {},
		"generator_shaft": generator_shaft.get_debug_data() if generator_shaft != null else {},
		"generator": generator.get_debug_data() if generator != null else {},
		"solver": solver.get_debug_data() if solver != null else {},
		"motor": motor.get_debug_data() if motor != null else {},
		"motor_shaft": motor_shaft.get_debug_data() if motor_shaft != null else {},
		"conveyor": conveyor.get_debug_data() if conveyor != null else {},
	}
