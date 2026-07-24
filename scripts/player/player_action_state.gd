extends Node
class_name PlayerActionState

@export var allow_movement_during_focus_menu: bool = true
@export var allow_casting_during_focus_menu: bool = true
@export var allow_attacking_during_focus_menu: bool = false
@export var allow_dodging_during_focus_menu: bool = false
@export var allow_interaction_during_focus_menu: bool = false

@export_group("Flight Restrictions")
@export var allow_attacking_during_flight: bool = false
@export var allow_casting_during_flight: bool = false
@export var allow_dodging_during_flight: bool = false
@export var allow_interaction_during_flight: bool = false
@export var allow_manipulation_during_flight: bool = false

var is_defeated: bool = false
var is_focus_menu_open: bool = false
var is_attacking: bool = false
var is_casting: bool = false
var is_interacting: bool = false
var is_dodging: bool = false
var is_manipulating: bool = false
var is_flying: bool = false
var is_guarding: bool = false
var is_staggered: bool = false
var is_using_item: bool = false

var attack_allows_cast_cancel: bool = false
var attack_allows_dodge_cancel: bool = false

var attack_lock_timer: float = 0.0
var cast_lock_timer: float = 0.0
var interact_lock_timer: float = 0.0
var dodge_lock_timer: float = 0.0
var stagger_lock_timer: float = 0.0
var item_use_lock_timer: float = 0.0


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
			end_dodge()

	if stagger_lock_timer > 0.0:
		stagger_lock_timer -= delta

		if stagger_lock_timer <= 0.0:
			end_stagger()

	if item_use_lock_timer > 0.0:
		item_use_lock_timer -= delta

		if item_use_lock_timer <= 0.0:
			end_item_use()


func can_move() -> bool:
	if is_defeated or is_staggered:
		return false

	if is_interacting:
		return false

	if is_dodging:
		return false

	if is_focus_menu_open and not allow_movement_during_focus_menu:
		return false

	return true


func flight_restrictions_apply() -> bool:
	if not is_flying:
		return false
	var actor: CharacterBody3D = get_parent() as CharacterBody3D
	return actor == null or not actor.is_on_floor()


func can_attack() -> bool:
	if is_defeated or is_manipulating or is_staggered or is_guarding or is_using_item:
		return false

	if flight_restrictions_apply() and not allow_attacking_during_flight:
		return false

	if is_attacking or is_casting or is_interacting or is_dodging:
		return false

	if is_focus_menu_open and not allow_attacking_during_focus_menu:
		return false

	return true


func can_cast() -> bool:
	if is_defeated or is_manipulating or is_staggered or is_guarding or is_using_item:
		return false

	if flight_restrictions_apply() and not allow_casting_during_flight:
		return false

	if is_attacking and not attack_allows_cast_cancel:
		return false

	if is_casting or is_interacting or is_dodging:
		return false

	if is_focus_menu_open and not allow_casting_during_focus_menu:
		return false

	return true


func can_interact() -> bool:
	if is_defeated or is_manipulating or is_staggered or is_guarding or is_using_item:
		return false

	if flight_restrictions_apply() and not allow_interaction_during_flight:
		return false

	if is_attacking or is_casting or is_interacting or is_dodging:
		return false

	if is_focus_menu_open and not allow_interaction_during_focus_menu:
		return false

	return true


func can_dodge() -> bool:
	if is_defeated or is_manipulating or is_staggered or is_using_item:
		return false

	if flight_restrictions_apply() and not allow_dodging_during_flight:
		return false

	if is_attacking and not attack_allows_dodge_cancel:
		return false

	if is_casting or is_interacting or is_dodging:
		return false

	if is_focus_menu_open and not allow_dodging_during_focus_menu:
		return false

	return true


func can_manipulate() -> bool:
	if is_defeated or is_focus_menu_open or is_staggered or is_guarding or is_using_item:
		return false
	if flight_restrictions_apply() and not allow_manipulation_during_flight:
		return false
	return not (is_attacking or is_casting or is_interacting or is_dodging or is_manipulating)


func begin_attack(lock_duration: float = 0.25) -> void:
	end_item_use()
	end_guard()
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
	end_item_use()
	end_guard()
	if is_attacking and attack_allows_cast_cancel:
		end_attack()

	is_casting = true
	cast_lock_timer = max(lock_duration, 0.01)


func begin_interact(lock_duration: float = 0.25) -> void:
	end_item_use()
	end_guard()
	is_interacting = true
	interact_lock_timer = max(lock_duration, 0.01)


func begin_dodge(lock_duration: float = 0.28) -> void:
	end_item_use()
	end_guard()
	if is_attacking and attack_allows_dodge_cancel:
		end_attack()

	is_dodging = true
	dodge_lock_timer = max(lock_duration, 0.01)


func end_dodge() -> void:
	is_dodging = false
	dodge_lock_timer = 0.0


func can_guard() -> bool:
	if is_defeated or is_staggered or is_focus_menu_open or is_using_item:
		return false
	if flight_restrictions_apply():
		return false
	return not (is_attacking or is_casting or is_interacting or is_dodging or is_manipulating)


func begin_guard() -> bool:
	if is_guarding:
		return true
	if not can_guard():
		return false
	is_guarding = true
	return true


func end_guard() -> void:
	is_guarding = false


func begin_stagger(lock_duration: float = 0.28) -> void:
	if is_defeated:
		return
	end_guard()
	clear_action_locks()
	is_staggered = true
	stagger_lock_timer = max(lock_duration, 0.01)


func end_stagger() -> void:
	is_staggered = false
	stagger_lock_timer = 0.0


func can_use_item() -> bool:
	if is_defeated or is_staggered or is_focus_menu_open or is_guarding or is_manipulating:
		return false
	if flight_restrictions_apply():
		return false
	return not (is_attacking or is_casting or is_interacting or is_dodging or is_using_item)


func begin_item_use(lock_duration: float = 0.8) -> bool:
	if not can_use_item():
		return false
	is_using_item = true
	item_use_lock_timer = maxf(lock_duration, 0.05)
	return true


func end_item_use() -> void:
	is_using_item = false
	item_use_lock_timer = 0.0


func begin_manipulation() -> bool:
	if not can_manipulate():
		return false
	is_manipulating = true
	return true


func end_manipulation() -> void:
	is_manipulating = false


func begin_flight() -> void:
	end_item_use()
	end_guard()
	is_flying = true
	end_attack()
	is_casting = false
	is_interacting = false
	is_dodging = false
	is_manipulating = false
	cast_lock_timer = 0.0
	interact_lock_timer = 0.0
	dodge_lock_timer = 0.0


func end_flight() -> void:
	is_flying = false


func set_focus_menu_open(value: bool) -> void:
	is_focus_menu_open = value
	if value:
		end_item_use()
		end_guard()
		end_manipulation()


func clear_action_locks() -> void:
	end_item_use()
	end_guard()
	end_attack()
	is_casting = false
	is_interacting = false
	is_dodging = false
	is_manipulating = false
	cast_lock_timer = 0.0
	interact_lock_timer = 0.0
	dodge_lock_timer = 0.0


func _on_player_defeated() -> void:
	is_defeated = true
	is_flying = false
	clear_action_locks()
	end_stagger()


func reset_for_respawn() -> void:
	is_defeated = false
	is_focus_menu_open = false
	is_flying = false
	clear_action_locks()
	end_stagger()


func get_debug_data() -> Dictionary:
	return {
		"defeated": is_defeated,
		"focus": is_focus_menu_open,
		"attack": is_attacking,
		"cast": is_casting,
		"dodge": is_dodging,
		"interact": is_interacting,
		"manipulating": is_manipulating,
		"flying": is_flying,
		"guarding": is_guarding,
		"staggered": is_staggered,
		"stagger_timer": snapped(stagger_lock_timer, 0.01),
		"using_item": is_using_item,
		"item_use_timer": snapped(item_use_lock_timer, 0.01),
		"flight_restrictions": flight_restrictions_apply(),
		"cast_cancel": attack_allows_cast_cancel,
		"dodge_cancel": attack_allows_dodge_cancel,
	}
