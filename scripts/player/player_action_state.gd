extends Node
class_name PlayerActionState

@export var allow_movement_during_focus_menu: bool = true
@export var allow_casting_during_focus_menu: bool = true
@export var allow_attacking_during_focus_menu: bool = false
@export var allow_dodging_during_focus_menu: bool = false
@export var allow_interaction_during_focus_menu: bool = false

var is_defeated: bool = false
var is_focus_menu_open: bool = false
var is_attacking: bool = false
var is_casting: bool = false
var is_interacting: bool = false
var is_dodging: bool = false

var attack_allows_cast_cancel: bool = false
var attack_allows_dodge_cancel: bool = false

var attack_lock_timer: float = 0.0
var cast_lock_timer: float = 0.0
var interact_lock_timer: float = 0.0
var dodge_lock_timer: float = 0.0


func _ready() -> void:
	add_to_group("debuggable")

	if not GameState.player_defeated.is_connected(_on_player_defeated):
		GameState.player_defeated.connect(_on_player_defeated)


func _process(delta: float) -> void:
	update_locks(delta)


func update_locks(delta: float) -> void:
	if attack_lock_timer > 0.0:
		attack_lock_timer -= delta

		if attack_lock_timer <= 0.0:
			end_attack()

	if cast_lock_timer > 0.0:
		cast_lock_timer -= delta

		if cast_lock_timer <= 0.0:
			is_casting = false

	if interact_lock_timer > 0.0:
		interact_lock_timer -= delta

		if interact_lock_timer <= 0.0:
			is_interacting = false

	if dodge_lock_timer > 0.0:
		dodge_lock_timer -= delta

		if dodge_lock_timer <= 0.0:
			is_dodging = false


func can_move() -> bool:
	if is_defeated:
		return false

	if is_interacting:
		return false

	if is_dodging:
		return false

	if is_focus_menu_open and not allow_movement_during_focus_menu:
		return false

	return true


func can_attack() -> bool:
	if is_defeated:
		return false

	if is_attacking or is_casting or is_interacting or is_dodging:
		return false

	if is_focus_menu_open and not allow_attacking_during_focus_menu:
		return false

	return true


func can_cast() -> bool:
	if is_defeated:
		return false

	if is_attacking and not attack_allows_cast_cancel:
		return false

	if is_casting or is_interacting or is_dodging:
		return false

	if is_focus_menu_open and not allow_casting_during_focus_menu:
		return false

	return true


func can_interact() -> bool:
	if is_defeated:
		return false

	if is_attacking or is_casting or is_interacting or is_dodging:
		return false

	if is_focus_menu_open and not allow_interaction_during_focus_menu:
		return false

	return true


func can_dodge() -> bool:
	if is_defeated:
		return false

	if is_attacking and not attack_allows_dodge_cancel:
		return false

	if is_casting or is_interacting or is_dodging:
		return false

	if is_focus_menu_open and not allow_dodging_during_focus_menu:
		return false

	return true


func begin_attack(lock_duration: float = 0.25) -> void:
	is_attacking = true
	attack_lock_timer = max(lock_duration, 0.01)
	attack_allows_cast_cancel = false
	attack_allows_dodge_cancel = false


func set_attack_cancel_permissions(allow_cast: bool, allow_dodge: bool) -> void:
	if not is_attacking:
		attack_allows_cast_cancel = false
		attack_allows_dodge_cancel = false
		return

	attack_allows_cast_cancel = allow_cast
	attack_allows_dodge_cancel = allow_dodge


func end_attack() -> void:
	is_attacking = false
	attack_lock_timer = 0.0
	attack_allows_cast_cancel = false
	attack_allows_dodge_cancel = false


func begin_cast(lock_duration: float = 0.18) -> void:
	if is_attacking and attack_allows_cast_cancel:
		end_attack()

	is_casting = true
	cast_lock_timer = max(lock_duration, 0.01)


func begin_interact(lock_duration: float = 0.25) -> void:
	is_interacting = true
	interact_lock_timer = max(lock_duration, 0.01)


func begin_dodge(lock_duration: float = 0.28) -> void:
	if is_attacking and attack_allows_dodge_cancel:
		end_attack()

	is_dodging = true
	dodge_lock_timer = max(lock_duration, 0.01)


func set_focus_menu_open(value: bool) -> void:
	is_focus_menu_open = value


func clear_action_locks() -> void:
	end_attack()
	is_casting = false
	is_interacting = false
	is_dodging = false
	cast_lock_timer = 0.0
	interact_lock_timer = 0.0
	dodge_lock_timer = 0.0


func _on_player_defeated() -> void:
	is_defeated = true
	clear_action_locks()


func reset_for_respawn() -> void:
	is_defeated = false
	is_focus_menu_open = false
	clear_action_locks()


func get_debug_data() -> Dictionary:
	return {
		"defeated": is_defeated,
		"focus": is_focus_menu_open,
		"attack": is_attacking,
		"cast": is_casting,
		"dodge": is_dodging,
		"interact": is_interacting,
		"cast_cancel": attack_allows_cast_cancel,
		"dodge_cancel": attack_allows_dodge_cancel,
	}
