extends "res://scripts/levels/prototype_water_jet_spell_trial.gd"
class_name PrototypeWaterJetSpellTrialReady

# The pressure cargo is intentionally heavy, but the default rigid-body friction
# could absorb every small pressure impulse before motion began. Give this
# hydraulic-lane fixture an authored low-friction contact while keeping its 12 kg
# mass and the spell's general rigid-body behavior intact.

@export_range(0.0, 1.0, 0.01) var pressure_crate_friction: float = 0.14
@export_range(0.0, 5.0, 0.05) var pressure_crate_linear_damp: float = 0.62

var pressure_crate_material: PhysicsMaterial


func _ready() -> void:
	super._ready()
	_configure_pressure_crate()


func _configure_pressure_crate() -> void:
	if pressure_crate == null or not is_instance_valid(pressure_crate):
		return
	pressure_crate_material = PhysicsMaterial.new()
	pressure_crate_material.friction = clampf(
		pressure_crate_friction,
		0.0,
		1.0
	)
	pressure_crate_material.bounce = 0.0
	pressure_crate.physics_material_override = pressure_crate_material
	pressure_crate.linear_damp = maxf(pressure_crate_linear_damp, 0.0)
	pressure_crate.continuous_cd = true
	pressure_crate.sleeping = false
	pressure_crate.set_meta("water_jet_force_multiplier", 1.0)
	pressure_crate.set_meta("pressureworks_hydraulic_cargo", true)


func reset_trial() -> void:
	super.reset_trial()
	_configure_pressure_crate()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["pressure_crate_tuned"] = pressure_crate != null
	data["pressure_crate_mass"] = (
		pressure_crate.mass if pressure_crate != null else 0.0
	)
	data["pressure_crate_friction"] = (
		pressure_crate_material.friction
		if pressure_crate_material != null
		else -1.0
	)
	data["pressure_crate_linear_damp"] = (
		pressure_crate.linear_damp if pressure_crate != null else -1.0
	)
	data["pressure_crate_sleeping"] = (
		pressure_crate.sleeping if pressure_crate != null else false
	)
	data["pressure_crate_velocity"] = (
		pressure_crate.linear_velocity
		if pressure_crate != null
		else Vector3.ZERO
	)
	data["pressure_crate_speed"] = (
		pressure_crate.linear_velocity.length()
		if pressure_crate != null
		else 0.0
	)
	return data
