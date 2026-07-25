extends Area3D
class_name AlchemyIngredientPickup

signal ingredient_collected(ingredient_id: String, amount: int)

@export var ingredient_id: String = "life_bloom"
@export var display_name: String = "Life Bloom"
@export var element: String = "life"
@export_range(1, 9, 1) var amount: int = 2
@export var ingredient_color: Color = Color(0.35, 0.95, 0.45)
@export var prompt_text: String = "Gather ingredient"
@export var respawns_in_lab: bool = true

var collected: bool = false
var visual: Node3D


func _ready() -> void:
	add_to_group("interactable_target")
	add_to_group("alchemy_ingredient")
	add_to_group("lab_resettable")
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.65
	collision.shape = shape
	collision.position.y = 0.5
	add_child(collision)
	build_visual()


func interact() -> Dictionary:
	if collected:
		return {"message": "The ingredient patch is empty.", "objective": ""}
	var added: int = GameState.add_inventory_item(ingredient_id, amount)
	if added <= 0:
		return {"message": display_name + " storage is full.", "objective": ""}
	collected = true
	visible = false
	monitoring = false
	monitorable = false
	ingredient_collected.emit(ingredient_id, added)
	return {
		"message": "Gathered " + display_name + " ×" + str(added) + ".",
		"objective": "Choose two ingredients at the alchemy cauldron.",
	}


func reset_target() -> void:
	if not respawns_in_lab:
		return
	collected = false
	visible = true
	monitoring = true
	monitorable = true


func build_visual() -> void:
	visual = Node3D.new()
	visual.name = "IngredientVisual"
	add_child(visual)
	for index: int in range(5):
		var petal := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.16
		mesh.height = 0.32
		petal.mesh = mesh
		var angle: float = TAU * float(index) / 5.0
		petal.position = Vector3(cos(angle) * 0.24, 0.35 + float(index % 2) * 0.08, sin(angle) * 0.24)
		var material := StandardMaterial3D.new()
		material.albedo_color = ingredient_color
		material.emission_enabled = true
		material.emission = ingredient_color.darkened(0.35)
		material.emission_energy_multiplier = 0.75
		petal.material_override = material
		visual.add_child(petal)
	var label := Label3D.new()
	label.text = display_name + "\n" + element.to_upper()
	label.position = Vector3(0.0, 1.2, 0.0)
	label.font_size = 24
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 7
	label.modulate = ingredient_color
	visual.add_child(label)


func _process(delta: float) -> void:
	if visual != null and not collected:
		visual.rotate_y(delta * 0.7)
