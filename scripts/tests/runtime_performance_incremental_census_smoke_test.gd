extends Node

const PerformanceMonitorScript: Script = preload(
	"res://scripts/performance/runtime_performance_monitor.gd"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var fixture := Node.new()
	fixture.name = "LargeTreeFixture"
	add_child(fixture)
	for index: int in range(420):
		var child := Node.new()
		child.name = "CensusNode" + str(index)
		fixture.add_child(child)
		if index == 30:
			child.add_to_group("spell_effects")
		if index == 31:
			child.add_to_group("persistent_spell_effects")

	var monitor := PerformanceMonitorScript.new() as RuntimePerformanceMonitor
	monitor.name = "IncrementalCensusMonitor"
	monitor.show_on_start = false
	monitor.tree_census_nodes_per_frame = 32
	monitor.tree_census_refresh_seconds = 2.0
	add_child(monitor)
	await get_tree().process_frame
	monitor.set_process(false)
	monitor.set_overlay_visible(true)

	_expect(monitor.tree_census_active, "showing F7 begins an incremental tree census")
	monitor._step_tree_census(32)
	_expect(
		monitor.tree_census_scanned_nodes <= 32,
		"one census step never exceeds its authored per-frame node budget"
	)
	_expect(
		monitor.tree_census_active,
		"a large tree remains unfinished after one bounded census step"
	)

	var scanned_before_sample: int = monitor.tree_census_scanned_nodes
	monitor.record_frame_sample(0.016)
	monitor.sample_performance()
	_expect(
		monitor.tree_census_scanned_nodes == scanned_before_sample,
		"performance sampling does not synchronously walk the remaining tree"
	)
	_expect(
		monitor.tree_census_active,
		"sampling leaves the amortized census scheduled for later frames"
	)

	var safety: int = 0
	while monitor.tree_census_active and safety < 64:
		monitor._step_tree_census(32)
		safety += 1
	_expect(not monitor.tree_census_active, "bounded census eventually completes")
	_expect(
		monitor.tree_census_completed_count == 1,
		"completed census is counted exactly once"
	)
	_expect(
		int(monitor.latest_tree_counts.get("scanned_nodes", 0)) >= 420,
		"completed census records the large fixture without skipping nodes"
	)
	_expect(
		int(monitor.latest_tree_counts.get("spell_effects", 0)) >= 1,
		"census reports active spell-effect group counts without allocating node lists"
	)
	_expect(
		int(monitor.latest_tree_counts.get("persistent_spell_effects", 0)) >= 1,
		"census reports persistent spell effects"
	)

	monitor._begin_tree_census()
	_expect(monitor.tree_census_active, "a later census can begin")
	monitor.set_overlay_visible(false)
	_expect(not monitor.tree_census_active, "hiding F7 cancels unfinished census work")
	_expect(
		monitor.tree_census_stack.is_empty(),
		"cancelled census releases its traversal stack"
	)

	monitor.queue_free()
	fixture.queue_free()
	await get_tree().process_frame
	_finish()


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("RUNTIME_PERFORMANCE_INCREMENTAL_CENSUS_SMOKE_TEST: " + label)


func _finish() -> void:
	if failures.is_empty():
		print("RUNTIME_PERFORMANCE_INCREMENTAL_CENSUS_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("RUNTIME_PERFORMANCE_INCREMENTAL_CENSUS_SMOKE_TEST: " + failure)
	get_tree().quit(1)
