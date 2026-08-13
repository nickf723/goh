extends "res://scripts/levels/prototype_weapon_arsenal_dojo.gd"
class_name PrototypeWeaponArsenalDojoV2

const FlailRigScene: PackedScene = preload(
	"res://scenes/weapons/flail_weapon_rig.tscn"
)


func _build_pedestals() -> void:
	super._build_pedestals()
	_tighten_sandbox_trails()
	var flail: WeaponDefinition = weapon_cache.get("flail") as WeaponDefinition
	if flail == null:
		return
	flail.runtime_rig_scene = FlailRigScene
	flail.set_meta("controlled_flexible_weapon", true)
	var pedestal: SandboxWeaponPedestal = get_node_or_null(
		"FlailPedestal"
	) as SandboxWeaponPedestal
	if pedestal != null:
		pedestal.configure(
			flail,
			WeaponSandboxCatalogScript.get_status_label("flail") + " • CONTROLLED"
		)


func _connect_weapon_controller() -> void:
	super._connect_weapon_controller()
	if weapon_controller == null:
		return
	# The first dojo used large opaque debug sweeps. Keep attack direction readable
	# without covering Grace and the target while we judge body motion.
	weapon_controller.sweep_start_alpha = 0.32
	weapon_controller.sweep_end_alpha = 0.0
	weapon_controller.camera_impact_amount = 0.055
	weapon_controller.debug_hitbox_lifetime = 0.12
	if "visual_facing_blend" in weapon_controller:
		weapon_controller.set("visual_facing_blend", 0.68)


func _tighten_sandbox_trails() -> void:
	for weapon_value: Variant in weapon_cache.values():
		if not (weapon_value is WeaponDefinition):
			continue
		var weapon: WeaponDefinition = weapon_value as WeaponDefinition
		var moveset: WeaponMovesetDefinition = weapon.get_moveset()
		if moveset == null:
			continue
		for attack: WeaponAttackDefinition in moveset.attacks:
			if attack == null:
				continue
			attack.trail_start_scale = Vector3(
				attack.trail_start_scale.x * 0.62,
				attack.trail_start_scale.y * 0.58,
				attack.trail_start_scale.z
			)
			attack.trail_end_scale = Vector3(
				attack.trail_end_scale.x * 0.68,
				attack.trail_end_scale.y * 0.62,
				attack.trail_end_scale.z
			)
			var trail: Color = attack.trail_color
			trail.a = minf(trail.a, 0.58)
			attack.trail_color = trail


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	var flail: WeaponDefinition = weapon_cache.get("flail") as WeaponDefinition
	data["combat_v2"] = true
	data["controlled_flail"] = (
		flail != null
		and flail.runtime_rig_scene == FlailRigScene
	)
	data["combat_feel_pass_01"] = true
	data["trail_alpha"] = (
		weapon_controller.sweep_start_alpha if weapon_controller != null else -1.0
	)
	return data
