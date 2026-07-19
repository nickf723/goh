extends RefCounted
class_name ElementVfxGalleryTestFixture


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	var gallery := ElementVfxGallery.new()
	gallery.name = "ElementVfxGalleryFixture"
	host.add_child(gallery)

	await host.get_tree().process_frame
	await host.get_tree().process_frame

	if gallery.impact_pool == null or gallery.motion_pool == null or gallery.theater_pool == null:
		failures.append("vfx gallery: the Water wing should build all three procedural fluid stages")
	if gallery.waterfall == null or gallery.waterfall.material_override == null:
		failures.append("vfx gallery: the motion theater should build a procedural waterfall curtain")
	if gallery.impact_exhibit == null or gallery.motion_exhibit == null:
		failures.append("vfx gallery: reusable impact and motion exhibits should be registered")
	if gallery.element_bays.size() != 16:
		failures.append("vfx gallery: the permanent room should reserve one bay for each core element")
	var active_bays: int = 0
	for bay: Node3D in gallery.element_bays:
		if bool(bay.get_meta("active", false)):
			active_bays += 1
			if str(bay.get_meta("element_id", "")) != "water":
				failures.append("vfx gallery: only the Water bay should be active in this slice")
	if active_bays != 1:
		failures.append("vfx gallery: exactly one element bay should be illuminated in v1")

	var waterfall_before: int = gallery.theater_pool.disturbance_count if gallery.theater_pool != null else 0
	gallery.emit_waterfall_impact()
	gallery.emit_theater_motion()
	if gallery.theater_pool != null and gallery.theater_pool.disturbance_count < waterfall_before + 2:
		failures.append("vfx gallery: waterfall and theater motion should generate live fluid events")
	if gallery.theater_pool != null and gallery.theater_pool.presentation_renderer != null:
		if gallery.theater_pool.presentation_renderer.ripple_render_count < 1:
			failures.append("vfx gallery: continuous water motion should render visible disturbance geometry")

	var impact_before: int = gallery.impact_exhibit.trigger_count if gallery.impact_exhibit != null else 0
	gallery.handle_gallery_action("impact_trigger")
	if gallery.impact_exhibit != null and gallery.impact_exhibit.trigger_count <= impact_before:
		failures.append("vfx gallery: the impact console should trigger the selected preview")
	var impact_kind_before: String = gallery.impact_exhibit.get_current_kind() if gallery.impact_exhibit != null else ""
	gallery.handle_gallery_action("impact_cycle")
	if gallery.impact_exhibit != null and gallery.impact_exhibit.get_current_kind() == impact_kind_before:
		failures.append("vfx gallery: the impact console should cycle effect kinds")

	var motion_before: int = gallery.motion_exhibit.trigger_count if gallery.motion_exhibit != null else 0
	gallery.handle_gallery_action("motion_trigger")
	if gallery.motion_exhibit != null and gallery.motion_exhibit.trigger_count <= motion_before:
		failures.append("vfx gallery: the motion console should trigger the selected preview")

	var initial_flow: Vector3 = gallery.theater_pool.flow_velocity_m_s if gallery.theater_pool != null else Vector3.ZERO
	gallery.handle_gallery_action("reverse_flow")
	if gallery.theater_pool != null and initial_flow.dot(gallery.theater_pool.flow_velocity_m_s) >= 0.0:
		failures.append("vfx gallery: reversing flow should reverse the procedural surface direction")

	gallery.state_index = 3
	gallery.apply_state_mode()
	if gallery.theater_pool != null and gallery.theater_pool.visual_electrical_intensity < 0.99:
		failures.append("vfx gallery: the electrified preview state should reach the water shader")
	gallery.state_index = 2
	gallery.apply_state_mode()
	if gallery.theater_pool != null and gallery.theater_pool.visual_temperature_c < 100.0:
		failures.append("vfx gallery: the hot preview state should reach the water shader")

	gallery.handle_gallery_action("toggle_waterfall")
	if gallery.waterfall_enabled or (gallery.waterfall != null and gallery.waterfall.visible):
		failures.append("vfx gallery: the waterfall control should pause the kinetic installation")

	gallery.handle_gallery_action("toggle_slow_motion")
	if not gallery.slow_motion_enabled or not is_equal_approx(Engine.time_scale, 0.35):
		failures.append("vfx gallery: slow motion should provide an inspectable effect playback mode")

	gallery.handle_gallery_action("clear_effects")
	for pool: FluidForceVolume in [gallery.impact_pool, gallery.motion_pool, gallery.theater_pool]:
		if pool != null and pool.presentation_renderer != null and not pool.presentation_renderer.active_effects.is_empty():
			failures.append("vfx gallery: clearing the room should release all active procedural effects")
			break

	gallery.reset_gallery()
	if not is_equal_approx(Engine.time_scale, 1.0) or gallery.slow_motion_enabled:
		failures.append("vfx gallery: reset should always restore normal global time")
	if not gallery.waterfall_enabled or gallery.waterfall == null or not gallery.waterfall.visible:
		failures.append("vfx gallery: reset should restore the waterfall")
	if gallery.theater_pool != null and not gallery.theater_pool.flow_velocity_m_s.is_equal_approx(gallery.initial_theater_flow):
		failures.append("vfx gallery: reset should restore the authored theater current")
	if not gallery.auto_replay_enabled or gallery.impact_exhibit == null or not gallery.impact_exhibit.auto_play:
		failures.append("vfx gallery: reset should restore automatic exhibit replay")
	if gallery.get_state_name() != "CALM" or gallery.get_intensity_label() != "STANDARD":
		failures.append("vfx gallery: reset should restore the default water state and intensity")

	gallery.queue_free()
	Engine.time_scale = 1.0
	return failures
