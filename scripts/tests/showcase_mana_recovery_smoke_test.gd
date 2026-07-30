extends Node

const ShowcaseScript = preload(
	"res://scripts/levels/prototype_animation_showcase_fire_specialist.gd"
)
const TelemetryGateScript = preload(
	"res://scripts/ui/showcase_telemetry_gate.gd"
)

var failures: Array[String] = []
var original_stats: Dictionary = {}


func _ready() -> void:
	original_stats = GameState.get_stat_snapshot()
	var showcase: PrototypeAnimationShowcaseFireSpecialist = (
		ShowcaseScript.new() as PrototypeAnimationShowcaseFireSpecialist
	)
	showcase.showcase_mana_capacity = 12
	showcase.showcase_mana_regeneration_delay = 0.35
	showcase.showcase_mana_empty_to_full_seconds = 1.2
	showcase._configure_showcase_mana()

	_expect(GameState.get_stat("max_mana") == 12, "Showcase installs its test mana capacity")
	_expect(GameState.get_stat("mana") == 12, "Showcase begins with full mana")

	GameState.set_stat("mana", 4)
	showcase._advance_showcase_mana(0.2)
	_expect(GameState.get_stat("mana") == 4, "Mana waits through the showcase recovery delay")
	showcase._advance_showcase_mana(0.2)
	_expect(GameState.get_stat("mana") > 4, "Mana begins rapidly recovering after the delay")
	showcase._advance_showcase_mana(2.0)
	_expect(GameState.get_stat("mana") == 12, "Showcase mana recovery caps at maximum")

	GameState.set_stat("mana", 1)
	showcase._refill_showcase_mana(false)
	_expect(GameState.get_stat("mana") == 12, "Manual showcase refill restores all mana")
	_expect(showcase.showcase_mana_delay_remaining == 0.0, "Manual refill clears the recovery delay")
	_expect(showcase.showcase_mana_accumulator == 0.0, "Manual refill clears fractional recovery")

	_validate_telemetry_gate()
	showcase.free()
	_restore_stats()
	if failures.is_empty():
		print("SHOWCASE_MANA_RECOVERY_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("SHOWCASE_MANA_RECOVERY_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func _validate_telemetry_gate() -> void:
	var gate: ShowcaseTelemetryGate = (
		TelemetryGateScript.new() as ShowcaseTelemetryGate
	)
	var panel := PanelContainer.new()
	var label := Label.new()
	panel.add_child(label)
	gate.telemetry_panel = panel

	gate.set_telemetry_visible(false, false)
	_expect(
		not panel.visible and not gate.telemetry_visible,
		"Showcase telemetry is hidden for the normal play view"
	)
	gate.set_telemetry_visible(true, false)
	_expect(
		panel.visible and gate.telemetry_visible,
		"Showcase telemetry remains available on demand"
	)

	panel.free()
	gate.free()


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _restore_stats() -> void:
	GameState.stats = original_stats.duplicate(true)
	for stat_variant: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_variant)
		GameState.stat_changed.emit(
			stat_id,
			int(GameState.stats[stat_variant])
		)
