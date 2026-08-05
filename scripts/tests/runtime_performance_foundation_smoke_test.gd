extends Node

const PerformanceMonitorScript: Script = preload(
	"res://scripts/performance/runtime_performance_monitor.gd"
)
const GameUIScene: PackedScene = preload("res://scenes/ui/game_ui.tscn")
const MechanismLabScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_mechanism_network_lab_v1.tscn"
)
const GateScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_sliding_gate.tscn"
)
const IndicatorScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_indicator.tscn"
)
const ElementSensorScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_element_sensor.tscn"
)

var failures: Array[String] = []
var fraction_emit_count: int = 0


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	await _validate_monitor_budget_math()
	await _validate_shared_ui_installation()
	await _validate_cached_hardware_presentation()
	await _validate_budgeted_mechanism_lab()
	_finish()


func _validate_monitor_budget_math() -> void:
	var monitor := PerformanceMonitorScript.new() as RuntimePerformanceMonitor
	monitor.name = "PerformanceMonitorFixture"
	monitor.show_on_start = false
	monitor.sample_interval_seconds = 0.5
	monitor.target_fps = 60.0
	monitor.spike_threshold_ms = 25.0
	add_child(monitor)
	monitor.set_process(false)
	await get_tree().process_frame

	for _index: int in range(60):
		monitor.record_frame_sample(0.010)
	var green: Dictionary = monitor.sample_performance()
	_expect(str(green.get("budget_state", "")) == "green", "10 ms frames classify inside the 60 FPS budget")
	_expect(float(green.get("p95_frame_ms", 0.0)) <= 10.1, "monitor reports deterministic p95 frame time")
	_expect(float(green.get("one_percent_low_fps", 0.0)) >= 99.0, "monitor derives a readable one-percent-low FPS")

	for _index: int in range(20):
		monitor.record_frame_sample(0.040)
	var red: Dictionary = monitor.sample_performance()
	_expect(str(red.get("budget_state", "")) == "red", "40 ms frames classify outside the frame budget")
	_expect(int(red.get("recent_spikes", 0)) == 20, "monitor counts recent frame spikes")
	_expect(int(red.get("lifetime_spikes", 0)) >= 20, "monitor retains lifetime spike history")
	monitor.set_overlay_visible(true)
	_expect(monitor.is_overlay_visible(), "performance overlay can be shown for live profiling")
	monitor.set_overlay_visible(false)
	_expect(not monitor.is_overlay_visible(), "performance overlay can be hidden without disabling sampling")

	monitor.queue_free()
	await get_tree().process_frame


func _validate_shared_ui_installation() -> void:
	var ui: Node = GameUIScene.instantiate()
	ui.name = "PerformanceGameUIFixture"
	add_child(ui)
	await _wait_frames(4)
	var monitor: Node = ui.get_node_or_null("RuntimePerformanceMonitor")
	_expect(monitor is RuntimePerformanceMonitor, "shared GameUI installs the F7 performance monitor")
	var bridge: Node = ui.get_node_or_null("UnifiedHUDSourceBridge")
	_expect(bridge is UnifiedHUDSourceBridgeBudgeted, "shared GameUI uses the budgeted HUD source bridge")
	if bridge is UnifiedHUDSourceBridgeBudgeted:
		var data: Dictionary = bridge.call("get_debug_data") as Dictionary
		_expect(bool(data.get("budgeted_sync", false)), "HUD bridge reports budgeted synchronization")
		_expect(float(data.get("progression_sync_seconds", 0.0)) >= 0.15, "progression mirroring is throttled below frame rate")
	ui.queue_free()
	await get_tree().process_frame


func _validate_cached_hardware_presentation() -> void:
	var indicator: MechanismIndicator = IndicatorScene.instantiate() as MechanismIndicator
	indicator.name = "IndicatorPerformanceFixture"
	add_child(indicator)
	await get_tree().process_frame
	var initial_refreshes: int = indicator.presentation_refresh_count
	for _index: int in range(20):
		indicator.set_mechanism_active(false, {"repeated": true})
	_expect(indicator.presentation_refresh_count == initial_refreshes, "indicator ignores repeated identical presentation states")
	indicator.set_mechanism_active(true)
	_expect(indicator.presentation_refresh_count == initial_refreshes + 1, "indicator refreshes exactly once when state changes")
	_expect(indicator.state_label.visibility_range_end > 0.0, "indicator labels use renderer visibility ranges")

	var sensor: MechanismElementSensor = ElementSensorScene.instantiate() as MechanismElementSensor
	sensor.name = "SensorPerformanceFixture"
	add_child(sensor)
	await get_tree().process_frame
	var sensor_refreshes: int = sensor.presentation_refresh_count
	sensor.set_sensor_active(false, {"repeated": true})
	sensor.set_sensor_active(false, {"repeated": true})
	_expect(sensor.presentation_refresh_count == sensor_refreshes, "element sensor caches repeated dormant presentation")
	var fire := DamagePayload.new()
	fire.element = "fire"
	fire.source_name = "Performance Test"
	sensor.receive_damage_payload(fire)
	_expect(sensor.presentation_refresh_count == sensor_refreshes + 1, "element sensor refreshes once for an accepted state change")

	var gate: MechanismSlidingGate = GateScene.instantiate() as MechanismSlidingGate
	gate.name = "GatePerformanceFixture"
	add_child(gate)
	await get_tree().process_frame
	fraction_emit_count = 0
	var callback := Callable(self, "_on_gate_fraction_changed")
	gate.gate_fraction_changed.connect(callback)
	gate.set_gate_open(true, true)
	fraction_emit_count = 0
	gate.active = true
	for index: int in range(101):
		gate._apply_fraction(float(index) / 100.0)
	_expect(fraction_emit_count <= 15, "animated gate throttles fraction signals instead of emitting every tween frame")
	_expect(gate.last_label_state == "OPEN", "gate label settles on a coarse final state")
	_expect(gate.state_label.visibility_range_end > 0.0, "gate label uses renderer visibility range culling")

	indicator.queue_free()
	sensor.queue_free()
	gate.queue_free()
	await get_tree().process_frame


func _validate_budgeted_mechanism_lab() -> void:
	var lab: Node = MechanismLabScene.instantiate()
	lab.name = "PerformanceMechanismLabFixture"
	add_child(lab)
	await _wait_frames(10)
	_expect(lab is MechanismNetworkLabPerformance, "production mechanism lab uses the performance runtime")
	if not (lab is MechanismNetworkLabPerformance):
		lab.queue_free()
		await get_tree().process_frame
		return
	var performance_lab := lab as MechanismNetworkLabPerformance
	_expect(not performance_lab.is_processing(), "mechanism lab sleeps when no timer is active")
	var writes_before: int = performance_lab.presentation_write_count
	performance_lab._refresh_all_presentations()
	performance_lab._refresh_all_presentations()
	_expect(performance_lab.presentation_write_count == writes_before, "unchanged mechanism labels do not rebuild text meshes")
	_expect(performance_lab.presentation_skip_count > 0, "presentation cache records skipped writes")
	var labels_with_ranges: int = 0
	for label: Label3D in _collect_labels(performance_lab):
		if label.visibility_range_end > 0.0:
			labels_with_ranges += 1
	_expect(labels_with_ranges >= 10, "instructional Label3D surfaces are distance culled")

	var timer_lever: Node = performance_lab.get_node_or_null("Mechanisms/TimerLever")
	var timer_logic: MechanismLogicNode = performance_lab.get_node_or_null(
		"SignalNetwork/FiveSecondTimer"
	) as MechanismLogicNode
	_expect(timer_lever != null and timer_logic != null, "timer station remains available after optimization")
	if timer_lever != null and timer_logic != null:
		timer_lever.call("interact")
		await _wait_frames(2)
		_expect(performance_lab.is_processing(), "active timer wakes coarse presentation processing")
		timer_logic._process(6.0)
		await _wait_frames(2)
		_expect(not performance_lab.is_processing(), "timer completion returns the lab to sleep")

	var debug: Dictionary = performance_lab.get_debug_data()
	_expect(bool(debug.get("performance_budgeted", false)), "lab debug snapshot exposes its performance contract")
	performance_lab.queue_free()
	await get_tree().process_frame


func _collect_labels(root: Node) -> Array[Label3D]:
	var labels: Array[Label3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Label3D:
			labels.append(node as Label3D)
		for child: Node in node.get_children():
			stack.append(child)
	return labels


func _on_gate_fraction_changed(_fraction: float) -> void:
	fraction_emit_count += 1


func _wait_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("RUNTIME_PERFORMANCE_FOUNDATION_SMOKE_TEST: " + label)


func _finish() -> void:
	if failures.is_empty():
		print("RUNTIME_PERFORMANCE_FOUNDATION_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("RUNTIME_PERFORMANCE_FOUNDATION_SMOKE_TEST: " + failure)
	get_tree().quit(1)
