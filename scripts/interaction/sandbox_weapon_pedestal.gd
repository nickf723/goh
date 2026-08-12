extends Area3D
class_name SandboxWeaponPedestal

const FlailRigScene: PackedScene = preload("res://scenes/weapons/flail_weapon_rig.tscn")

var weapon: WeaponDefinition
var prompt_text: String = "Equip sandbox weapon"
var status_label: String = "PROXY"


func configure(new_weapon: WeaponDefinition, new_status_label: String) -> void:
	weapon = new_weapon
	status_label = new_status_label
	if weapon != null and weapon.weapon_class == "flail":
		weapon.runtime_rig_scene = FlailRigScene
	prompt_text = "Equip " + (weapon.display_name if weapon != null else "weapon")
	if is_inside_tree():
		_refresh_visuals()


func _ready() -> void:
	add_to_group("debuggable")
	_build_collision()
	_build_pedestal()
	_refresh_visuals()


func interact() -> Dictionary:
	if weapon == null:
		return {"message": "This pedestal is empty.", "objective": "Choose another weapon class."}
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return {"message": "No player can equip this weapon.", "objective": ""}
	var controller: Node = player.get_node_or_null("WeaponController")
	if controller == null or not controller.has_method("equip_weapon"):
		return {"message": "Grace has no weapon controller.", "objective": ""}
	controller.call("equip_weapon", weapon)
	return {
		"message": (
			weapon.display_name + " equipped. "
			+ ("Existing authored moveset." if status_label == "AUTHORED" else "Development proxy: judge the class idea, not final move quality.")
		),
		"objective": "Compare its Light chain, Heavy branches, dash attack, aerial attacks, reach, commitment, and hit feel.",
	}


func _build_collision() -> void:
	if get_node_or_null("CollisionShape3D") != null:
		return
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.position = Vector3(0.0, 0.75, 0.0)
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 1.65, 1.45)
	collision.shape = shape
	add_child(collision)


func _build_pedestal() -> void:
	if get_node_or_null("Pedestal") != null:
		return
	var pedestal := MeshInstance3D.new()
	pedestal.name = "Pedestal"
	pedestal.position = Vector3(0.0, 0.32, 0.0)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.85, 0.64, 1.2)
	pedestal.mesh = mesh
	pedestal.material_override = _make_material(Color(0.075, 0.085, 0.12, 1.0), false)
	add_child(pedestal)

	var stripe := MeshInstance3D.new()
	stripe.name = "ClassStripe"
	stripe.position = Vector3(0.0, 0.67, 0.0)
	var stripe_mesh := BoxMesh.new()
	stripe_mesh.size = Vector3(2.0, 0.08, 1.3)
	stripe.mesh = stripe_mesh
	add_child(stripe)

	var label := Label3D.new()
	label.name = "WeaponLabel"
	label.position = Vector3(0.0, 1.5, 0.0)
	label.font_size = 28
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	add_child(label)


func _refresh_visuals() -> void:
	var stripe: MeshInstance3D = get_node_or_null("ClassStripe") as MeshInstance3D
	var label: Label3D = get_node_or_null("WeaponLabel") as Label3D
	if weapon == null:
		if label != null:
			label.text = "EMPTY"
		return
	if stripe != null:
		stripe.material_override = _make_material(weapon.visual_accent_color, true)
	if label != null:
		label.text = (
			weapon.weapon_class.to_upper()
			+ "\n"
			+ status_label
		)
		label.modulate = weapon.visual_accent_color


func _make_material(color: Color, emissive: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.38
	material.roughness = 0.42
	if emissive:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b, 1.0)
		material.emission_energy_multiplier = 0.85
	return material


func get_debug_data() -> Dictionary:
	return {
		"sandbox_weapon_pedestal": true,
		"class": weapon.weapon_class if weapon != null else "none",
		"status": status_label,
		"weapon": weapon.display_name if weapon != null else "empty",
		"simplified_flail_rig": (
			weapon != null
			and weapon.weapon_class == "flail"
			and weapon.runtime_rig_scene == FlailRigScene
		),
	}
