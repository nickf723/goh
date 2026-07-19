extends Node3D
class_name ThermalPressureLab

const FireAbility: AbilityDefinition = preload("res://data/abilities/firebolt_ability.tres")
const IceAbility: AbilityDefinition = preload("res://data/abilities/ice_lance_ability.tres")

@export var readout_refresh_interval: float = 0.06

@onready var player: Node3D = get_node_or_null("Player") as Node3D

var ability_caster: Node
var initial_player_transform: Transform3D
var refresh_timer: float = 0.0
var active_spell_label: Label3D
var water: ThermalWaterVolume
var reservoir: PressureReservoir
var adapter: ThermalPressureAdapter
var valve: PressureReliefValve
var actuator: MechanicalActuator
var platform: Node3D
var gauge_needle: Node3D
var readout: Label3D


func _ready() -> void:
	build_environment()
	resolve_station(ThermalPressureStation.build(self))
	configure_player()
	GameState.set_objective("Heat the boiler, build steam pressure, raise the lift, then cool or vent it.")
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
		Vector3(0.0, -0.5, 0.8),
		Vector3(16.0, 1.0, 15.0),
		Color(0.045, 0.055, 0.075, 1.0)
	)
	ThermalLabGeometry.add_static_box(
		self,
		"BackWall",
		Vector3(0.0, 2.2, 8.0),
		Vector3(16.0, 5.4, 0.6),
		Color(0.075, 0.085, 0.12, 1.0)
	)
	ThermalLabGeometry.add_static_box(
		self,
		"LeftWall",
		Vector3(-7.7, 2.2, 0.8),
		Vector3(0.6, 5.4, 15.0),
		Color(0.075, 0.085, 0.12, 1.0)
	)
	ThermalLabGeometry.add_static_box(
		self,
		"RightWall",
		Vector3(7.7, 2.2, 0.8),
		Vector3(0.6, 5.4, 15.0),
		Color(0.075, 0.085, 0.12, 1.0)
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
		"THERMAL PRESSURE",
		Vector3(0.0, 4.9, -5.25),
		42,
		Color(1.0, 0.72, 0.42, 1.0)
	)
	ThermalLabGeometry.add_label(
		self,
		"Instructions",
		"1 FIRE  •  2 ICE  •  LEFT BOILER  →  CENTER VALVE  →  RIGHT LIFT  •  F8 RESET",
		Vector3(0.0, 4.2, -5.1),
		21,
		Color(0.82, 0.88, 1.0, 1.0)
	)
	active_spell_label = ThermalLabGeometry.add_label(
		self,
		"ActiveSpell",
		"ACTIVE SPELL: FIREBOLT",
		Vector3(0.0, 3.55, -4.95),
		24,
		Color(1.0, 0.62, 0.28, 1.0)
	)


func resolve_station(data: Dictionary) -> void:
	water = data.get("water") as ThermalWaterVolume
	reservoir = data.get("reservoir") as PressureReservoir
	adapter = data.get("adapter") as ThermalPressureAdapter
	valve = data.get("valve") as PressureReliefValve
	actuator = data.get("actuator") as MechanicalActuator
	platform = data.get("platform") as Node3D
	gauge_needle = data.get("gauge_needle") as Node3D
	readout = data.get("readout") as Label3D


func configure_player() -> void:
	if player == null:
		push_warning("Thermal pressure laboratory could not find the player.")
		return
	player.add_to_group("player")
	initial_player_transform = player.transform
	ability_caster = player.get_node_or_null("AbilityCaster")
	if ability_caster == null:
		push_warning("Thermal pressure laboratory could not find AbilityCaster.")
		return

	var loadout := AbilityLoadout.new()
	loadout.learned_abilities = [FireAbility, IceAbility]
	loadout.equipped_abilities = [FireAbility, IceAbility]
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
	if reservoir == null or water == null or adapter == null:
		return

	var ratio: float = reservoir.get_pressure_ratio()
	var pressure_color := Color(0.6, 0.82, 1.0, 1.0).lerp(Color(1.0, 0.56, 0.12, 1.0), ratio)
	if ratio >= 0.9:
		pressure_color = Color(1.0, 0.2, 0.08, 1.0)
	if gauge_needle != null:
		gauge_needle.rotation_degrees.z = lerpf(-105.0, 105.0, ratio)
	if readout != null:
		var phase_text: String = water.thermal_state.phase.to_upper()
		var lift_text: String = "RAISED" if actuator != null and actuator.is_activated else "LOWERED"
		var safety_text: String = "AUTO-VENTING" if valve != null and valve.automatic_venting else "SAFE"
		readout.text = (
			"BOILER: " + phase_text + "  "
			+ str(snapped(water.thermal_state.temperature_c, 0.1)) + " °C"
			+ "\nPRESSURE: " + str(snapped(reservoir.current_pressure, 0.1))
			+ " / " + str(snapped(reservoir.maximum_pressure, 0.1))
			+ "  FLOW: " + str(snapped(adapter.last_output_rate, 0.1)) + "/s"
			+ "\nLIFT: " + lift_text + "  •  RELIEF: " + safety_text
		)
		readout.modulate = pressure_color


func reset_lab() -> void:
	if water != null:
		water.reset_target()
	if reservoir != null:
		reservoir.reset_pressure()
	if adapter != null:
		adapter.reset_target()
	if valve != null:
		valve.reset_target()
	if actuator != null:
		actuator.reset_actuator()
	if player != null:
		player.transform = initial_player_transform
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
	GameState.set_stat("mana", 999)
	refresh_timer = 0.0
	call_deferred("update_presentation")


func get_debug_data() -> Dictionary:
	return {
		"thermal_pressure_lab": true,
		"active_spell": get_active_spell_name(),
		"water": water.get_debug_data() if water != null else {},
		"pressure": reservoir.get_debug_data() if reservoir != null else {},
		"adapter": adapter.get_debug_data() if adapter != null else {},
		"valve": valve.get_debug_data() if valve != null else {},
		"actuator": actuator.get_debug_data() if actuator != null else {},
		"platform_position": platform.position if platform != null else Vector3.ZERO,
	}
