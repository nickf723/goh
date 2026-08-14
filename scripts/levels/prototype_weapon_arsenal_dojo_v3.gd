extends "res://scripts/levels/prototype_weapon_arsenal_dojo_v2.gd"
class_name PrototypeWeaponArsenalDojoV3

const AxeFocusCatalogScript = preload(
	"res://scripts/weapons/axe_weapon_focus_catalog_v1.gd"
)


func _build_pedestals() -> void:
	super._build_pedestals()
	var axe: WeaponDefinition = AxeFocusCatalogScript.build_weapon()
	if axe == null:
		return
	_tighten_axe_trails(axe)
	weapon_cache["axe"] = axe
	var pedestal: SandboxWeaponPedestal = get_node_or_null(
		"AxePedestal"
	) as SandboxWeaponPedestal
	if pedestal != null:
		pedestal.configure(
			axe,
			"AUTHORED • POWER / MOMENTUM / OPENINGS"
		)


func _tighten_axe_trails(axe: WeaponDefinition) -> void:
	var moveset: WeaponMovesetDefinition = axe.get_moveset()
	if moveset == null:
		return
	for attack: WeaponAttackDefinition in moveset.attacks:
		if attack == null:
			continue
		attack.trail_start_scale = Vector3(
			attack.trail_start_scale.x * 0.72,
			attack.trail_start_scale.y * 0.68,
			attack.trail_start_scale.z
		)
		attack.trail_end_scale = Vector3(
			attack.trail_end_scale.x * 0.78,
			attack.trail_end_scale.y * 0.72,
			attack.trail_end_scale.z
		)
		var trail: Color = attack.trail_color
		trail.a = minf(trail.a, 0.62)
		attack.trail_color = trail


func _refresh_status() -> void:
	super._refresh_status()
	if status_label == null or weapon_controller == null:
		return
	var weapon: WeaponDefinition = weapon_controller.equipped_weapon
	if weapon == null or weapon.weapon_class != "axe":
		return
	status_label.text = (
		weapon.display_name.to_upper()
		+ " • AUTHORED • AXE"
		+ " • POWER / MOMENTUM / OPENINGS"
		+ (" • LIVE ENEMIES" if enemies_live else "")
	)
	status_label.modulate = weapon.visual_accent_color


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	var axe: WeaponDefinition = weapon_cache.get("axe") as WeaponDefinition
	data["combat_v3"] = true
	data["authored_blue_axe"] = (
		axe != null
		and axe.get_meta("axe_focus_v1", false)
	)
	data["axe_playstyle"] = "power_momentum_openings"
	return data
