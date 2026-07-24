extends Node3D
class_name PlayerQuickItemController

signal belt_changed
signal item_use_started(slot_index: int, item: QuickItemDefinition, duration: float)
signal item_use_progress(slot_index: int, progress: float)
signal item_use_completed(slot_index: int, item: QuickItemDefinition, restored_amount: int)
signal item_use_cancelled(slot_index: int, item: QuickItemDefinition, reason: String)

const SLOT_UP: int = 0
const SLOT_LEFT: int = 1
const SLOT_RIGHT: int = 2
const SLOT_DOWN: int = 3
const SLOT_COUNT: int = 4

const SLOT_ACTIONS: Array[StringName] = [
	&"quick_item_up",
	&"quick_item_left",
	&"quick_item_right",
	&"quick_item_down",
]
const SLOT_JOYPAD_BUTTONS: Array[JoyButton] = [
	JOY_BUTTON_DPAD_UP,
	JOY_BUTTON_DPAD_LEFT,
	JOY_BUTTON_DPAD_RIGHT,
	JOY_BUTTON_DPAD_DOWN,
]
const SLOT_KEYBOARD_KEYS: Array[Key] = [KEY_UP, KEY_LEFT, KEY_RIGHT, KEY_DOWN]

@export_group("Quick Belt")
@export var up_item: QuickItemDefinition
@export var left_item: QuickItemDefinition
@export var right_item: QuickItemDefinition
@export var down_item: QuickItemDefinition

@export_group("Keyboard Convenience")
@export var healing_shortcut_key: Key = KEY_H

var charges: Array[int] = [0, 0, 0, 0]
var active_slot: int = -1
var active_item: QuickItemDefinition
var use_timer: float = 0.0
var use_total_duration: float = 0.0
var use_visual: Node3D

@onready var actor: CharacterBody3D = get_parent() as CharacterBody3D
@onready var action_state: PlayerActionState = get_parent().get_node_or_null("PlayerActionState") as PlayerActionState


func _ready() -> void:
	ensure_quick_item_input_map()
	initialize_charges()
	create_use_visual()
	add_to_group("debuggable")
	if GameState.has_signal("rest_resources_restored"):
		if not GameState.rest_resources_restored.is_connected(_on_rest_resources_restored):
			GameState.rest_resources_restored.connect(_on_rest_resources_restored)


func _exit_tree() -> void:
	if GameState.has_signal("rest_resources_restored"):
		if GameState.rest_resources_restored.is_connected(_on_rest_resources_restored):
			GameState.rest_resources_restored.disconnect(_on_rest_resources_restored)


func _process(delta: float) -> void:
	advance_use(delta)


func _unhandled_input(event: InputEvent) -> void:
	for slot_index: int in range(SLOT_COUNT):
		if event.is_action_pressed(SLOT_ACTIONS[slot_index]):
			if try_use_slot(slot_index):
				get_viewport().set_input_as_handled()
			return


func try_use_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return false
	if is_using_item():
		show_message("Already using " + active_item.display_name + ".")
		return false

	var item: QuickItemDefinition = get_slot_item(slot_index)
	if item == null:
		return false
	if get_slot_charges(slot_index) <= 0:
		show_message(item.display_name + " is empty. Rest to refill it.")
		return false
	if action_state == null or not action_state.can_use_item():
		return false
	if item.requires_grounded and actor != null and not actor.is_on_floor():
		show_message(item.display_name + " needs steady footing.")
		return false
	if not item.can_apply():
		show_message(item.display_name + " is not needed right now.")
		return false

	use_total_duration = item.get_use_duration()
	if not action_state.begin_item_use(use_total_duration + 0.2):
		return false

	active_slot = slot_index
	active_item = item
	use_timer = use_total_duration
	set_use_visual_visible(true)
	update_use_visual(0.0)
	item_use_started.emit(active_slot, active_item, use_total_duration)
	belt_changed.emit()
	show_message("Using " + active_item.display_name + "...")
	return true


func advance_use(delta: float) -> void:
	if not is_using_item() or delta <= 0.0:
		return
	if action_state == null or not action_state.is_using_item:
		cancel_active_use("interrupted")
		return

	use_timer = maxf(use_timer - delta, 0.0)
	var progress: float = 1.0 - (use_timer / maxf(use_total_duration, 0.01))
	update_use_visual(progress)
	item_use_progress.emit(active_slot, progress)

	if use_timer <= 0.0:
		complete_active_use()


func complete_active_use() -> void:
	if not is_using_item():
		return
	var completed_slot: int = active_slot
	var completed_item: QuickItemDefinition = active_item
	var restored_amount: int = completed_item.apply_effect()

	if restored_amount <= 0:
		cancel_active_use("no longer needed", false)
		show_message(completed_item.display_name + " is no longer needed.")
		return

	charges[completed_slot] = maxi(charges[completed_slot] - 1, 0)
	clear_active_use_state()
	item_use_completed.emit(completed_slot, completed_item, restored_amount)
	belt_changed.emit()
	show_message(
		completed_item.display_name
		+ " restores "
		+ str(restored_amount)
		+ " "
		+ completed_item.restore_resource_id.capitalize()
		+ "."
	)


func cancel_active_use(reason: String = "cancelled", show_feedback: bool = true) -> void:
	if not is_using_item():
		return
	var cancelled_slot: int = active_slot
	var cancelled_item: QuickItemDefinition = active_item
	clear_active_use_state()
	item_use_cancelled.emit(cancelled_slot, cancelled_item, reason)
	belt_changed.emit()
	if show_feedback:
		show_message(cancelled_item.display_name + " " + reason + ".")


func clear_active_use_state() -> void:
	if action_state != null:
		action_state.end_item_use()
	active_slot = -1
	active_item = null
	use_timer = 0.0
	use_total_duration = 0.0
	set_use_visual_visible(false)


func is_using_item() -> bool:
	return active_slot >= 0 and active_item != null


func get_movement_multiplier() -> float:
	if not is_using_item():
		return 1.0
	return active_item.get_movement_multiplier()


func allows_jump() -> bool:
	return not is_using_item()


func initialize_charges() -> void:
	for slot_index: int in range(SLOT_COUNT):
		var item: QuickItemDefinition = get_slot_item(slot_index)
		charges[slot_index] = item.get_max_charges() if item != null else 0
	belt_changed.emit()


func refill_rest_items() -> void:
	for slot_index: int in range(SLOT_COUNT):
		var item: QuickItemDefinition = get_slot_item(slot_index)
		if item != null and item.refill_on_rest:
			charges[slot_index] = item.get_max_charges()
	belt_changed.emit()


func reset_belt() -> void:
	cancel_active_use("reset", false)
	initialize_charges()


func set_slot_item(slot_index: int, item: QuickItemDefinition, refill: bool = true) -> void:
	match slot_index:
		SLOT_UP:
			up_item = item
		SLOT_LEFT:
			left_item = item
		SLOT_RIGHT:
			right_item = item
		SLOT_DOWN:
			down_item = item
		_:
			return
	charges[slot_index] = item.get_max_charges() if refill and item != null else 0
	belt_changed.emit()


func get_slot_item(slot_index: int) -> QuickItemDefinition:
	match slot_index:
		SLOT_UP:
			return up_item
		SLOT_LEFT:
			return left_item
		SLOT_RIGHT:
			return right_item
		SLOT_DOWN:
			return down_item
		_:
			return null


func get_slot_charges(slot_index: int) -> int:
	if slot_index < 0 or slot_index >= charges.size():
		return 0
	return charges[slot_index]


func get_slot_debug_data(slot_index: int) -> Dictionary:
	var item: QuickItemDefinition = get_slot_item(slot_index)
	return {
		"slot": slot_index,
		"action": str(SLOT_ACTIONS[slot_index]) if slot_index >= 0 and slot_index < SLOT_COUNT else "none",
		"item_id": item.item_id if item != null else "empty",
		"label": item.short_label if item != null else "—",
		"charges": get_slot_charges(slot_index),
		"maximum": item.get_max_charges() if item != null else 0,
	}


func _on_rest_resources_restored() -> void:
	cancel_active_use("rested", false)
	refill_rest_items()


func ensure_quick_item_input_map() -> void:
	for slot_index: int in range(SLOT_COUNT):
		var action_name: StringName = SLOT_ACTIONS[slot_index]
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name, 0.2)
		ensure_joypad_button(action_name, SLOT_JOYPAD_BUTTONS[slot_index])
		ensure_key(action_name, SLOT_KEYBOARD_KEYS[slot_index])
	ensure_key(SLOT_ACTIONS[SLOT_UP], healing_shortcut_key)


func ensure_joypad_button(action_name: StringName, button: JoyButton) -> void:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button:
			return
	var new_event: InputEventJoypadButton = InputEventJoypadButton.new()
	new_event.button_index = button
	InputMap.action_add_event(action_name, new_event)


func ensure_key(action_name: StringName, keycode: Key) -> void:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var key_event: InputEventKey = event as InputEventKey
			if key_event.physical_keycode == keycode or key_event.keycode == keycode:
				return
	var new_event: InputEventKey = InputEventKey.new()
	new_event.physical_keycode = keycode
	InputMap.action_add_event(action_name, new_event)


func create_use_visual() -> void:
	use_visual = Node3D.new()
	use_visual.name = "QuickItemUseVisual"
	use_visual.position = Vector3(0.42, 0.62, -0.3)

	var bottle: MeshInstance3D = MeshInstance3D.new()
	var bottle_mesh: CylinderMesh = CylinderMesh.new()
	bottle_mesh.top_radius = 0.07
	bottle_mesh.bottom_radius = 0.1
	bottle_mesh.height = 0.3
	bottle_mesh.radial_segments = 12
	bottle.mesh = bottle_mesh

	var bottle_material: StandardMaterial3D = StandardMaterial3D.new()
	bottle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bottle_material.albedo_color = Color(0.18, 0.82, 1.0, 0.82)
	bottle_material.metallic = 0.25
	bottle_material.roughness = 0.2
	bottle_material.emission_enabled = true
	bottle_material.emission = Color(0.02, 0.35, 0.8)
	bottle_material.emission_energy_multiplier = 1.25
	bottle.material_override = bottle_material
	use_visual.add_child(bottle)

	var cap: MeshInstance3D = MeshInstance3D.new()
	var cap_mesh: CylinderMesh = CylinderMesh.new()
	cap_mesh.top_radius = 0.045
	cap_mesh.bottom_radius = 0.045
	cap_mesh.height = 0.08
	cap_mesh.radial_segments = 10
	cap.mesh = cap_mesh
	cap.position = Vector3(0.0, 0.19, 0.0)
	var cap_material: StandardMaterial3D = StandardMaterial3D.new()
	cap_material.albedo_color = Color(0.9, 0.68, 0.18, 1.0)
	cap_material.metallic = 0.75
	cap_material.roughness = 0.28
	cap.material_override = cap_material
	use_visual.add_child(cap)

	add_child(use_visual)
	set_use_visual_visible(false)


func set_use_visual_visible(value: bool) -> void:
	if use_visual != null:
		use_visual.visible = value


func update_use_visual(progress: float) -> void:
	if use_visual == null:
		return
	var eased: float = smoothstep(0.0, 1.0, clampf(progress, 0.0, 1.0))
	use_visual.position = Vector3(0.42, lerpf(0.58, 0.9, eased), lerpf(-0.3, -0.18, eased))
	use_visual.rotation_degrees = Vector3(0.0, 0.0, lerpf(-12.0, -72.0, eased))
	var pulse: float = 1.0 + sin(progress * PI * 5.0) * 0.04
	use_visual.scale = Vector3.ONE * pulse


func show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)
	else:
		print(message)


func get_debug_data() -> Dictionary:
	var slot_rows: Array[Dictionary] = []
	for slot_index: int in range(SLOT_COUNT):
		slot_rows.append(get_slot_debug_data(slot_index))
	return {
		"using": is_using_item(),
		"active_slot": active_slot,
		"remaining": snapped(use_timer, 0.01),
		"duration": snapped(use_total_duration, 0.01),
		"movement": get_movement_multiplier(),
		"slots": slot_rows,
	}
