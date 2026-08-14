extends "res://scripts/weapons/combat_weapon_controller_v3.gd"
class_name CombatWeaponControllerV4

const BowHeavyAimSolverScript = preload(
	"res://scripts/weapons/bow_heavy_aim_solver.gd"
)
const BOW_HEAVY_ACTION: StringName = &"weapon_heavy_attack"

@export_group("Bow Heavy Aim")
@export_range(0.2, 2.5, 0.05) var bow_full_draw_seconds: float = 1.1
@export_range(1.0, 2.0, 0.05) var bow_full_draw_damage_scale: float = 1.4
@export_range(0.0, 3.0, 0.1) var bow_full_draw_range_bonus: float = 1.6

@export_group("Chain Momentum")
@export_range(1, 5, 1) var chain_max_momentum: int = 3
@export_range(0.5, 5.0, 0.1) var chain_momentum_window: float = 2.4

var bow_aim_active: bool = false
var bow_aim_requested_after_attack: bool = false
var bow_aim_elapsed: float = 0.0
var bow_aim_attack: WeaponAttackDefinition
var bow_release_direction: Vector3 = Vector3.ZERO
var bow_aim_ui_root: Control
var bow_aim_reticle: Label
var bow_aim_draw_label: Label

var chain_momentum_stacks: int = 0
var chain_momentum_timer: float = 0.0
var chain_attack_momentum_spent: int = 0


func _process(delta: float) -> void:
	super._process(delta)
	_update_bow_aim(delta)
	_update_chain_momentum(delta)


func _unhandled_input(event: InputEvent) -> void:
	if _is_bow_equipped():
		if event.is_action_pressed(BOW_HEAVY_ACTION):
			if bow_aim_active:
				get_viewport().set_input_as_handled()
				return
			if current_attack != null:
				bow_aim_requested_after_attack = true
				get_viewport().set_input_as_handled()
				return
			if _can_begin_bow_aim() and _begin_bow_aim():
				get_viewport().set_input_as_handled()
				return
		if event.is_action_released(BOW_HEAVY_ACTION):
			if bow_aim_active:
				_release_bow_aim()
				get_viewport().set_input_as_handled()
				return
			if bow_aim_requested_after_attack:
				bow_aim_requested_after_attack = false
				queue_attack_input(INPUT_HEAVY)
				get_viewport().set_input_as_handled()
				return
		if bow_aim_active and event.is_action_pressed("weapon_light_attack"):
			_cancel_bow_aim()
	super._unhandled_input(event)


func _prepare_combat_flair_attack(
	attack: WeaponAttackDefinition
) -> WeaponAttackDefinition:
	var resolved: WeaponAttackDefinition = super._prepare_combat_flair_attack(attack)
	if resolved == null or equipped_weapon == null:
		return resolved
	if equipped_weapon.weapon_class == "chains":
		_apply_chain_momentum_to_attack(resolved)
	return resolved


func start_attack(attack: WeaponAttackDefinition) -> bool:
	var chain_heavy: bool = (
		equipped_weapon != null
		and equipped_weapon.weapon_class == "chains"
		and attack != null
		and attack.input_kind == INPUT_HEAVY
	)
	var momentum_spent: int = chain_momentum_stacks if chain_heavy else 0
	var started: bool = super.start_attack(attack)
	if started and chain_heavy:
		chain_attack_momentum_spent = momentum_spent
		chain_momentum_stacks = 0
		chain_momentum_timer = 0.0
	return started


func finish_current_attack() -> void:
	var completed: WeaponAttackDefinition = current_attack
	var completed_class: String = equipped_weapon.weapon_class if equipped_weapon != null else ""
	var chain_light_connected: bool = (
		completed != null
		and completed_class == "chains"
		and completed.input_kind == INPUT_LIGHT
		and last_attack_connected
	)
	var chain_heavy_completed: bool = (
		completed != null
		and completed_class == "chains"
		and completed.input_kind == INPUT_HEAVY
	)
	if chain_light_connected:
		chain_momentum_stacks = mini(chain_momentum_stacks + 1, chain_max_momentum)
		chain_momentum_timer = chain_momentum_window

	super.finish_current_attack()

	if chain_heavy_completed:
		chain_attack_momentum_spent = 0
	if (
		completed_class == "bow"
		and bow_aim_requested_after_attack
		and current_attack == null
		and Input.is_action_pressed(BOW_HEAVY_ACTION)
	):
		bow_aim_requested_after_attack = false
		_begin_bow_aim()


func cancel_current_attack(reason: String = "cancelled") -> void:
	var was_chain_heavy: bool = (
		current_attack != null
		and equipped_weapon != null
		and equipped_weapon.weapon_class == "chains"
		and current_attack.input_kind == INPUT_HEAVY
	)
	super.cancel_current_attack(reason)
	if was_chain_heavy:
		chain_attack_momentum_spent = 0


func find_targets(attack: WeaponAttackDefinition) -> Array[Node]:
	if (
		attack != null
		and equipped_weapon != null
		and equipped_weapon.weapon_class == "bow"
		and attack.extra_tags.has("bow_aimed_heavy")
		and bow_release_direction.length_squared() > 0.0001
	):
		return BowHeavyAimSolverScript.find_targets(self, attack, bow_release_direction)
	return super.find_targets(attack)


func _begin_bow_aim() -> bool:
	if not _can_begin_bow_aim():
		return false
	var requested: WeaponAttackDefinition = resolve_idle_attack(INPUT_HEAVY)
	if requested == null:
		return false
	bow_aim_attack = requested.duplicate(true) as WeaponAttackDefinition
	if bow_aim_attack == null:
		return false
	bow_aim_active = true
	bow_aim_elapsed = 0.0
	bow_release_direction = Vector3.ZERO
	_ensure_bow_aim_ui()
	_set_bow_aim_ui_visible(true)
	_update_bow_aim_ui(0.0)
	return true


func _release_bow_aim() -> void:
	if not bow_aim_active or bow_aim_attack == null:
		_cancel_bow_aim()
		return
	var attack: WeaponAttackDefinition = bow_aim_attack.duplicate(true) as WeaponAttackDefinition
	if attack == null:
		_cancel_bow_aim()
		return
	var charge: float = get_bow_draw_ratio()
	bow_release_direction = BowHeavyAimSolverScript.get_aim_direction(self)
	attack.startup_time = minf(attack.startup_time, 0.055)
	attack.damage_multiplier *= lerpf(1.0, bow_full_draw_damage_scale, charge)
	attack.stance_multiplier *= lerpf(1.0, 1.22, charge)
	attack.attack_range += bow_full_draw_range_bonus * charge
	attack.cone_angle_degrees = minf(attack.cone_angle_degrees, 8.0)
	attack.max_targets = 1
	_append_attack_tag(attack, "bow_aimed_heavy")
	_append_attack_tag(attack, "precision_shot")
	if charge >= 0.98:
		attack.display_name += " • Full Draw"
		_append_attack_tag(attack, "bow_full_draw")
	bow_aim_active = false
	bow_aim_attack = null
	bow_aim_elapsed = 0.0
	_set_bow_aim_ui_visible(false)
	if not start_attack(attack):
		bow_release_direction = Vector3.ZERO


func _cancel_bow_aim() -> void:
	bow_aim_active = false
	bow_aim_requested_after_attack = false
	bow_aim_elapsed = 0.0
	bow_aim_attack = null
	bow_release_direction = Vector3.ZERO
	_set_bow_aim_ui_visible(false)


func _update_bow_aim(delta: float) -> void:
	if not bow_aim_active:
		if equipped_weapon == null or equipped_weapon.weapon_class != "bow":
			bow_aim_requested_after_attack = false
		return
	if not _is_bow_equipped() or not _can_continue_bow_aim():
		_cancel_bow_aim()
		return
	if not Input.is_action_pressed(BOW_HEAVY_ACTION):
		_release_bow_aim()
		return
	bow_aim_elapsed = minf(bow_aim_elapsed + maxf(delta, 0.0), bow_full_draw_seconds)
	_update_bow_aim_ui(get_bow_draw_ratio())


func _can_begin_bow_aim() -> bool:
	if not _is_bow_equipped() or current_attack != null:
		return false
	if action_state != null and not action_state.can_attack():
		return false
	if dodge_controller != null and dodge_controller.is_dodge_active():
		return false
	var actor: Node3D = get_actor()
	return actor is CharacterBody3D and (actor as CharacterBody3D).is_on_floor()


func _can_continue_bow_aim() -> bool:
	if current_attack != null:
		return false
	if action_state != null and not action_state.can_attack():
		return false
	return true


func _is_bow_equipped() -> bool:
	return equipped_weapon != null and equipped_weapon.weapon_class == "bow"


func get_bow_draw_ratio() -> float:
	return clampf(bow_aim_elapsed / maxf(bow_full_draw_seconds, 0.01), 0.0, 1.0)


func is_bow_heavy_aiming() -> bool:
	return bow_aim_active


func _ensure_bow_aim_ui() -> void:
	if bow_aim_ui_root != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "BowHeavyAimLayer"
	layer.layer = 28
	add_child(layer)
	bow_aim_ui_root = Control.new()
	bow_aim_ui_root.name = "BowHeavyAimHUD"
	bow_aim_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bow_aim_ui_root)

	bow_aim_reticle = Label.new()
	bow_aim_reticle.text = "+"
	bow_aim_reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bow_aim_reticle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bow_aim_reticle.add_theme_font_size_override("font_size", 34)
	bow_aim_reticle.set_anchors_preset(Control.PRESET_CENTER)
	bow_aim_reticle.offset_left = -40.0
	bow_aim_reticle.offset_top = -38.0
	bow_aim_reticle.offset_right = 40.0
	bow_aim_reticle.offset_bottom = 38.0
	bow_aim_ui_root.add_child(bow_aim_reticle)

	bow_aim_draw_label = Label.new()
	bow_aim_draw_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bow_aim_draw_label.add_theme_font_size_override("font_size", 14)
	bow_aim_draw_label.set_anchors_preset(Control.PRESET_CENTER)
	bow_aim_draw_label.offset_left = -100.0
	bow_aim_draw_label.offset_top = 28.0
	bow_aim_draw_label.offset_right = 100.0
	bow_aim_draw_label.offset_bottom = 58.0
	bow_aim_ui_root.add_child(bow_aim_draw_label)
	bow_aim_ui_root.visible = false


func _set_bow_aim_ui_visible(visible_value: bool) -> void:
	if bow_aim_ui_root != null:
		bow_aim_ui_root.visible = visible_value


func _update_bow_aim_ui(charge: float) -> void:
	if bow_aim_draw_label == null:
		return
	bow_aim_draw_label.text = (
		"FULL DRAW"
		if charge >= 0.98
		else "DRAW " + str(roundi(charge * 100.0)) + "%"
	)


func _apply_chain_momentum_to_attack(attack: WeaponAttackDefinition) -> void:
	if attack == null or chain_momentum_stacks <= 0:
		return
	var stacks: float = float(chain_momentum_stacks)
	if attack.input_kind == INPUT_LIGHT:
		attack.startup_time *= maxf(0.7, 1.0 - 0.085 * stacks)
		attack.recovery_time *= maxf(0.78, 1.0 - 0.055 * stacks)
		attack.damage_multiplier *= 1.0 + 0.055 * stacks
		_append_attack_tag(attack, "chain_momentum_carried")
		return
	attack.startup_time *= maxf(0.6, 1.0 - 0.11 * stacks)
	attack.damage_multiplier *= 1.0 + 0.16 * stacks
	attack.stance_multiplier *= 1.0 + 0.14 * stacks
	attack.knockback_multiplier *= 1.0 + 0.08 * stacks
	attack.attack_range += 0.18 * stacks
	attack.max_targets += chain_momentum_stacks
	_append_attack_tag(attack, "chain_momentum_cashout")


func _update_chain_momentum(delta: float) -> void:
	if equipped_weapon == null or equipped_weapon.weapon_class != "chains":
		chain_momentum_stacks = 0
		chain_momentum_timer = 0.0
		chain_attack_momentum_spent = 0
		return
	if chain_momentum_stacks <= 0 or current_attack != null:
		return
	chain_momentum_timer -= maxf(delta, 0.0)
	if chain_momentum_timer <= 0.0:
		chain_momentum_stacks = 0
		chain_momentum_timer = 0.0


func get_chain_momentum_ratio() -> float:
	var visible_stacks: int = maxi(chain_momentum_stacks, chain_attack_momentum_spent)
	return clampf(float(visible_stacks) / float(maxi(chain_max_momentum, 1)), 0.0, 1.0)


func get_combat_v4_debug_data() -> Dictionary:
	return {
		"combat_weapon_controller_v4": true,
		"bow_hold_to_aim": true,
		"bow_aiming": bow_aim_active,
		"bow_draw_ratio": snappedf(get_bow_draw_ratio(), 0.01),
		"bow_true_vertical_aim": true,
		"chain_momentum": chain_momentum_stacks,
		"chain_momentum_spent": chain_attack_momentum_spent,
	}
