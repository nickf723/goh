extends Node


func _ready() -> void:
	var failures: Array[String] = await ConductiveNetworkTestFixture.run(self)
	if failures.is_empty():
		print("CONDUCTIVE_NETWORK_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("CONDUCTIVE_NETWORK_SMOKE_TEST: " + failure)
	get_tree().quit(1)
