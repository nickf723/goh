extends RefCounted
class_name WaterPresentationTestFixture


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	var root := Node3D.new()
	root.name = "WaterPresentationFixture"
	host.add_child(root)

	var profile := FluidPresentationProfile.new()
	profile.wave_amplitude = 0.13
	profile.wave_speed = 1.4
	profile.flow_band_strength = 0.24
	profile.maximum_active_effects = 64

	var volume := FluidForceVolume.new()
	volume.name = "PresentationWater"
	volume.volume_size = Vector3(8.0, 3.0, 6.0)
	volume.flow_velocity_m_s = Vector3(1.8, 0.0, -0.6)
	volume.presentation_profile = profile
	volume.create_default_visuals = true
	volume.presentation_enabled = true
	root.add_child(volume)

	await host.get_tree().process_frame
	await host.get_tree().process_frame

	if volume.surface_mesh == null or volume.surface_material == null:
		failures.append("water presentation: a visible fluid should build a procedural surface and shader material")
	elif volume.surface_material.shader == null:
		failures.append("water presentation: the surface material should use the procedural water shader")
	if volume.presentation_renderer == null:
		failures.append("water presentation: a presentation-enabled volume should own a disturbance renderer")
	if not is_equal_approx(volume.get_presentation_profile().wave_amplitude, 0.13):
		failures.append("water presentation: authored profile values should reach the volume")

	volume.set_visual_state(120.0, 0.82, 0.66)
	if not is_equal_approx(volume.visual_temperature_c, 120.0):
		failures.append("water presentation: thermal state should remain available to the shader layer")
	if not is_equal_approx(volume.visual_electrical_intensity, 0.82):
		failures.append("water presentation: electrical intensity should remain available to the shader layer")
	if not is_equal_approx(volume.visual_turbulence, 0.66):
		failures.append("water presentation: turbulence should remain available to the shader layer")
	if volume.surface_material != null:
		var shader_electrical: Variant = volume.surface_material.get_shader_parameter("electrical_intensity")
		var shader_turbulence: Variant = volume.surface_material.get_shader_parameter("turbulence")
		if not shader_electrical is float or not is_equal_approx(float(shader_electrical), 0.82):
			failures.append("water presentation: electrical state should propagate to the surface shader")
		if not shader_turbulence is float or not is_equal_approx(float(shader_turbulence), 0.66):
			failures.append("water presentation: turbulence should propagate to the surface shader")

	var surface_position := Vector3(0.0, volume.get_surface_y(), 0.0)
	var entry := volume.emit_disturbance(
		FluidDisturbanceEvent.KIND_ENTRY,
		surface_position,
		Vector3.FORWARD,
		Vector3(0.8, -4.0, 1.2),
		2.2,
		0.7,
		"fixture_entry",
		["water", "impact"]
	)
	if entry == null or volume.disturbance_count != 1:
		failures.append("water presentation: entry events should be accepted by the fluid event hub")
	if volume.presentation_renderer != null and (
		volume.presentation_renderer.ripple_render_count < 1
		or volume.presentation_renderer.splash_render_count < 1
	):
		failures.append("water presentation: an entry event should create both a ripple and a splash")

	volume.emit_disturbance(
		FluidDisturbanceEvent.KIND_WAKE,
		surface_position,
		Vector3.RIGHT,
		Vector3(3.0, 0.0, 0.0),
		1.4,
		0.8,
		"fixture_wake"
	)
	if volume.presentation_renderer != null and volume.presentation_renderer.wake_render_count < 1:
		failures.append("water presentation: a wake event should create directional wake geometry")

	volume.emit_disturbance(
		FluidDisturbanceEvent.KIND_CHURN,
		surface_position,
		Vector3.BACK,
		Vector3(0.0, 0.0, -18.0),
		1.8,
		0.5,
		"fixture_propeller",
		["propeller"]
	)
	if volume.presentation_renderer != null and volume.presentation_renderer.churn_render_count < 1:
		failures.append("water presentation: a churn event should create wake, droplets, and bubbles")

	var previous_rejected: int = volume.presentation_renderer.rejected_count if volume.presentation_renderer != null else 0
	var invalid := FluidDisturbanceEvent.make(FluidDisturbanceEvent.KIND_RIPPLE, surface_position)
	invalid.velocity.x = INF
	if volume.presentation_renderer != null:
		volume.presentation_renderer.render_disturbance(invalid)
		if volume.presentation_renderer.rejected_count <= previous_rejected:
			failures.append("water presentation: non-finite disturbances should be rejected safely")

	var before_legacy: int = volume.disturbance_count
	volume.spawn_ripple(surface_position, 1.0)
	if volume.disturbance_count <= before_legacy:
		failures.append("water presentation: legacy ripple calls should route through the new event engine")
	if not entry.is_finite_event():
		failures.append("water presentation: accepted disturbances should remain finite")

	volume.reset_target()
	if volume.disturbance_count != 0 or volume.ripple_count != 0:
		failures.append("water presentation: reset should clear fluid event counters")
	if volume.presentation_renderer != null and not volume.presentation_renderer.active_effects.is_empty():
		failures.append("water presentation: reset should clear active procedural effects")

	root.queue_free()
	return failures
