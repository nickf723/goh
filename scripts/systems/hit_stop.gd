extends Node

const MINIMUM_ACTIVE_TIME_SCALE: float = 0.01
const WATCHDOG_GRACE_MSEC: int = 180

var is_active: bool = false
var restore_time_scale: float = 1.0
var release_deadline_msec: int = 0
var active_request_id: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if (
		is_active
		and release_deadline_msec > 0
		and Time.get_ticks_msec() >= release_deadline_msec
	):
		_release(active_request_id)


func request(duration: float = 0.06, time_scale: float = 0.05) -> void:
	if duration <= 0.0:
		return

	# One hit-stop owns time at once. More impacts during that tiny window do not
	# stack additional awaits or overwrite the original restoration scale.
	if is_active:
		return

	is_active = true
	active_request_id += 1
	var request_id: int = active_request_id
	restore_time_scale = (
		Engine.time_scale
		if Engine.time_scale > MINIMUM_ACTIVE_TIME_SCALE
		else 1.0
	)
	Engine.time_scale = clampf(
		time_scale,
		MINIMUM_ACTIVE_TIME_SCALE,
		1.0
	)
	var duration_msec: int = maxi(int(ceil(duration * 1000.0)), 1)
	release_deadline_msec = (
		Time.get_ticks_msec()
		+ duration_msec
		+ WATCHDOG_GRACE_MSEC
	)

	# process_always + ignore_time_scale makes this timer independent of the very
	# slowdown it is responsible for. The ALWAYS-process watchdog above is a
	# second release path if a scene transition or coroutine interruption occurs.
	await get_tree().create_timer(duration, true, false, true).timeout
	_release(request_id)


func force_release() -> void:
	if not is_active and Engine.time_scale > MINIMUM_ACTIVE_TIME_SCALE:
		return
	active_request_id += 1
	Engine.time_scale = (
		restore_time_scale
		if restore_time_scale > MINIMUM_ACTIVE_TIME_SCALE
		else 1.0
	)
	is_active = false
	release_deadline_msec = 0


func _release(request_id: int) -> void:
	if not is_active or request_id != active_request_id:
		return
	Engine.time_scale = (
		restore_time_scale
		if restore_time_scale > MINIMUM_ACTIVE_TIME_SCALE
		else 1.0
	)
	is_active = false
	release_deadline_msec = 0


func get_debug_data() -> Dictionary:
	return {
		"active": is_active,
		"engine_time_scale": Engine.time_scale,
		"restore_time_scale": restore_time_scale,
		"release_deadline_msec": release_deadline_msec,
		"request_id": active_request_id,
	}
