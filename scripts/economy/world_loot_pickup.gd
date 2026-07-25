extends Area3D
class_name WorldLootPickup

signal collected(kind: String, item_id: String, amount: int)

const EconomyCatalogScript = preload("res://scripts/economy/economy_catalog.gd")

@export_enum("currency", "item") var loot_kind: String = "currency"
@export var item_id: String = ""
@export var amount: int = 1
@export var pickup_id: String = ""
@export var auto_collect: bool = true
@export var prompt_text: String = "Collect loot"
@export var loot_color: Color = Color(1.0, 0.78, 0.18)

var claimed: bool = false
var visual_root: Node3D


func _ready() -> void:
	add_to_group("interactable_target")
	add_to_group("lab_resettable")
	if pickup_id != "" and GameState.has_collected_pickup(pickup_id):
		claimed = true
		visible = false
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		return
	build_visual()
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if visual_root == null or claimed:
		return
	visual_root.rotation.y += delta * 1.8
	visual_root.position.y = 0.62 + sin(Time.get_ticks_msec() * 0.004) * 0.09


func interact() -> Dictionary:
	collect_loot()
	return {}


func _on_body_entered(body: Node3D) -> void:
	if auto_collect and body.is_in_group("player"):
		collect_loot()


func collect_loot() -> bool:
	if claimed:
		return false
	var granted: int = 0
	if loot_kind == "currency":
		granted = GameState.add_currency(amount)
	else:
		granted = GameState.add_inventory_item(item_id, amount)
	if granted <= 0:
		show_message("Cannot carry any more " + get_display_name() + ".")
		return false
	claimed = true
	if pickup_id != "":
		GameState.mark_collected_pickup(pickup_id)
	collected.emit(loot_kind, item_id, granted)
	show_message("Collected " + str(granted) + " " + get_display_name() + ".")
	visible = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	return true


func get_display_name() -> String:
	if loot_kind == "currency":
		return "crowns"
	return EconomyCatalogScript.get_display_name(item_id)


func reset_target() -> void:
	claimed = false
	if pickup_id != "":
		GameState.clear_collected_pickup(pickup_id)
	visible = true
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)


func build_visual() -> void:
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.65
	collision.shape = sphere
	collision.position.y = 0.65
	add_child(collision)
	visual_root = Node3D.new()
	add_child(visual_root)
	var mesh_instance := MeshInstance3D.new()
	if loot_kind == "currency":
		var coin := CylinderMesh.new()
		coin.top_radius = 0.28
		coin.bottom_radius = 0.28
		coin.height = 0.08
		coin.radial_segments = 20
		mesh_instance.mesh = coin
		mesh_instance.rotation_degrees.x = 90.0
	else:
		var gem := PrismMesh.new()
		gem.size = Vector3(0.45, 0.65, 0.35)
		mesh_instance.mesh = gem
	var material := StandardMaterial3D.new()
	material.albedo_color = loot_color
	material.metallic = 0.72 if loot_kind == "currency" else 0.2
	material.roughness = 0.24
	material.emission_enabled = true
	material.emission = loot_color.darkened(0.35)
	material.emission_energy_multiplier = 1.4
	mesh_instance.material_override = material
	visual_root.add_child(mesh_instance)
	var label := Label3D.new()
	label.text = (str(amount) + " C") if loot_kind == "currency" else get_display_name().to_upper()
	label.position = Vector3(0.0, 0.72, 0.0)
	label.font_size = 25
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	label.modulate = loot_color.lightened(0.2)
	visual_root.add_child(label)


func show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)
	else:
		print(message)
