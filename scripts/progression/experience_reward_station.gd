extends Area3D
class_name ExperienceRewardStation

signal experience_awarded(amount: int, category: String)

@export var reward_name: String = "Exploration Discovery"
@export var reward_category: String = "exploration"
@export var experience_amount: int = 20
@export var repeatable: bool = true
@export var reward_id: String = ""
@export var prompt_text: String = "Claim experience"
@export var station_color: Color = Color(0.35, 0.78, 1.0)

var claimed: bool = false
var core: MeshInstance3D


func _ready() -> void:
	add_to_group("interactable_target")
	add_to_group("lab_resettable")
	if not repeatable and reward_id != "" and GameState.get_flag("experience_reward_" + reward_id):
		claimed = true
	build_visual()
	update_visual()


func _process(delta: float) -> void:
	if core == null:
		return
	core.rotation.y += delta * 1.15
	var pulse: float = 1.0 + sin(Time.get_ticks_msec() * 0.004) * 0.06
	core.scale = Vector3.ONE * pulse


func interact() -> Dictionary:
	if claimed and not repeatable:
		show_message(reward_name + " has already been learned from.")
		return {}
	var result: Dictionary = GameState.add_experience(experience_amount)
	if int(result.get("gained", 0)) <= 0:
		return {}
	experience_awarded.emit(experience_amount, reward_category)
	if not repeatable:
		claimed = true
		if reward_id != "":
			GameState.set_flag("experience_reward_" + reward_id, true)
		update_visual()
	var message: String = "+" + str(experience_amount) + " XP — " + reward_name
	if int(result.get("levels", 0)) > 0:
		message += "  LEVEL " + str(result.get("level", GameState.get_stat("level"))) + "!"
	show_message(message)
	return {}


func reset_target() -> void:
	claimed = false
	if reward_id != "":
		GameState.set_flag("experience_reward_" + reward_id, false)
	update_visual()


func update_visual() -> void:
	if core != null:
		core.modulate = Color(0.3, 0.34, 0.4) if claimed and not repeatable else Color.WHITE


func build_visual() -> void:
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.0
	shape.height = 2.0
	collision.shape = shape
	collision.position.y = 1.0
	add_child(collision)
	var pedestal := MeshInstance3D.new()
	var pedestal_mesh := CylinderMesh.new()
	pedestal_mesh.top_radius = 0.85
	pedestal_mesh.bottom_radius = 1.05
	pedestal_mesh.height = 0.65
	pedestal.mesh = pedestal_mesh
	pedestal.position.y = 0.32
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.16, 0.19, 0.23)
	stone.roughness = 0.72
	pedestal.material_override = stone
	add_child(pedestal)
	core = MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.42
	core_mesh.height = 0.84
	core.mesh = core_mesh
	core.position.y = 1.2
	var material := StandardMaterial3D.new()
	material.albedo_color = station_color
	material.emission_enabled = true
	material.emission = station_color.darkened(0.25)
	material.emission_energy_multiplier = 2.2
	core.material_override = material
	add_child(core)
	var label := Label3D.new()
	label.text = reward_name.to_upper() + "\n+" + str(experience_amount) + " XP"
	label.position = Vector3(0.0, 2.15, 0.0)
	label.font_size = 25
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 7
	label.modulate = station_color.lightened(0.2)
	add_child(label)


func show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)
	else:
		print(message)
