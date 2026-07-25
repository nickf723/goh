extends Node

var player: Node3D
var manager: PlayerSummonManager
var failures: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	player = get_node_or_null("Player") as Node3D
	manager = player.get_node_or_null("SummonManager") as PlayerSummonManager if player != null else null
	_expect(player != null, "Player instantiates")
	_expect(manager != null, "SummonManager is installed")
	if manager != null:
		GameState.set_stat("max_mana", 30)
		GameState.set_stat("mana", 30)
		_expect(manager.summon_familiar(), "Definition creates a familiar")
		var familiar: SpectralFamiliar = manager.get_active_summon()
		_expect(familiar != null, "Manager owns the active summon")
		if familiar != null:
			familiar.set_command(SpectralFamiliar.COMMAND_STAY)
			_expect(familiar.command == SpectralFamiliar.COMMAND_STAY, "Stay command persists")
			familiar.set_command(SpectralFamiliar.COMMAND_ASSIST)
			_expect(familiar.command == SpectralFamiliar.COMMAND_ASSIST, "Assist command persists")
			familiar.recall_to_summoner()
		_expect(manager.dismiss_summon(false), "Dismiss clears active summon")
		_expect(manager.get_active_summon() == null, "No stale summon remains")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func _finish() -> void:
	if failures.is_empty():
		print("SUMMONING SMOKE TEST PASSED")
	else:
		push_error("SUMMONING SMOKE TEST FAILED: " + ", ".join(failures))
