extends Node

var player: CharacterBody3D
var riding: PlayerRidingController
var mount: RideableMount
var failures: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame
	player = get_node_or_null("Player") as CharacterBody3D
	riding = player.get_node_or_null("RidingController") as PlayerRidingController if player != null else null
	mount = RideableMount.new()
	mount.position = Vector3(1.5, 0.1, 0)
	add_child(mount)
	await get_tree().physics_frame
	_expect(player != null, "Player instantiates")
	_expect(riding != null, "RidingController is installed")
	_expect(mount.get_summon_contract().get("summonable", false), "Mount exposes summon contract")
	if riding != null and mount != null:
		_expect(riding.mount_mount(mount), "Grace can mount a nearby rideable")
		_expect(riding.is_riding(), "Mounted state is authoritative")
		mount.mount_stamina = mount.maximum_stamina
		mount.process_ridden_locomotion(0.5, Vector2(0, -1), true, false)
		_expect(mount.mount_stamina < mount.maximum_stamina, "Gallop consumes mount stamina")
		_expect(riding.dismount(), "Grace can dismount")
		_expect(not riding.is_riding(), "Dismount clears rider")
		_expect(mount.summon_to(Vector3(4, 0, 0)), "Unmounted rideable accepts summon command")
		_expect(mount.summon_state == "ANSWERING", "Summon enters answering state")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func _finish() -> void:
	if failures.is_empty():
		print("RIDEABLE MOUNT SMOKE TEST PASSED")
	else:
		push_error("RIDEABLE MOUNT SMOKE TEST FAILED: " + ", ".join(failures))
