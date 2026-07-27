extends Node3D

const ConversationNPCScript = preload("res://scripts/dialogue/conversation_npc.gd")

const FLAG_REPAIRED := "broken_waystation_relay_repaired"
const FLAG_METAL := "broken_waystation_repaired_metal"
const FLAG_EARTH := "broken_waystation_repaired_earth"
const FLAG_LIGHTNING := "broken_waystation_repaired_lightning"

@onready var player: CharacterBody3D = $Player
@onready var mission_label: Label = $MissionHUD/Panel/Margin/VBox/Mission
@onready var objective_label: Label = $MissionHUD/Panel/Margin/VBox/Objective
@onready var prompt_label: Label = $MissionHUD/Panel/Margin/VBox/Prompt
@onready var status_label: Label = $MissionHUD/Panel/Margin/VBox/Status

var tamsin: Area3D
var relay_root: Node3D
var broken_arm: Node3D
var repaired_arm: Node3D
var foundation_rubble: Node3D
var raised_foundation: Node3D
var dead_conduit: Node3D
var live_conduit: Node3D
var beacon_light: OmniLight3D
var beacon_core: MeshInstance3D
var result_label: Label3D
var repair_method := ""
var transformation_time := 0.0
var transformation_active := false


func _ready() -> void:
	Engine.time_scale = 1.0
	hide_legacy_prototype_nodes()
	build_environment()
	build_authored_waystation()
	build_waykeeper()
	apply_saved_state()
	set_objective(
		"Speak with Tamsin beside the damaged relay."
		if not GameState.get_flag(FLAG_REPAIRED)
		else "Inspect the restored relay and speak with Tamsin."
	)
	refresh_hud()


func _process(delta: float) -> void:
	if transformation_active:
		transformation_time += delta
		animate_repair(delta)
	update_context_hint()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene") and OS.has_feature("editor"):
		reset_encounter()
		get_viewport().set_input_as_handled()


func hide_legacy_prototype_nodes() -> void:
	for path: NodePath in [NodePath("World/Roadblock"), NodePath("World/RoadblockCollision"), NodePath("World/SignalCache"), NodePath("World/RepairedBeacon")]:
		var node := get_node_or_null(path)
		if node != null:
			node.visible = false
			node.process_mode = Node.PROCESS_MODE_DISABLED


func build_environment() -> void:
	var world_environment := $WorldEnvironment as WorldEnvironment
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.12, 0.22, 0.31)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.69, 0.75)
	environment.ambient_light_energy = 0.68
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	var sun := $DirectionalLight3D as DirectionalLight3D
	sun.light_color = Color(1.0, 0.76, 0.54)
	sun.light_energy = 1.2


func build_authored_waystation() -> void:
	var world := $World as Node3D
	add_static_box(world, "Ground", Vector3(30, 1, 34), Vector3(0, -0.5, 0), Color(0.16, 0.23, 0.14))
	add_static_box(world, "Road", Vector3(6.4, 0.14, 34), Vector3(0, 0.03, 0), Color(0.34, 0.27, 0.18))
	build_waystation_house(Vector3(6.8, 0, -3.5))
	build_work_camp(Vector3(-6.2, 0, -4.5))
	build_relay(Vector3(0, 0, 6.5))
	for tree_position: Vector3 in [Vector3(-11,0,-9), Vector3(11,0,-10), Vector3(-12,0,7), Vector3(12,0,9), Vector3(-9,0,14), Vector3(10,0,15)]:
		build_tree(tree_position)
	add_world_label("THE BROKEN WAYSTATION", Vector3(0, 6.2, -8), Color(1.0, 0.78, 0.38), 52)
	result_label = add_world_label(
		"The ridge relay has gone dark.",
		Vector3(0, 3.2, 5.2),
		Color(0.72, 0.85, 1.0),
		27
	)


func build_waystation_house(origin: Vector3) -> void:
	var root := Node3D.new()
	root.name = "WaystationHouse"
	root.position = origin
	$World.add_child(root)
	add_static_box(root, "StoneBase", Vector3(7, 0.8, 6), Vector3(0, 0.4, 0), Color(0.31, 0.3, 0.25))
	add_static_box(root, "TimberRoom", Vector3(6.4, 3.2, 5.4), Vector3(0, 2.3, 0), Color(0.3, 0.19, 0.1))
	add_visual_box(root, "RoofLeft", Vector3(4.2, 0.32, 6.2), Vector3(-1.55, 4.15, 0), Color(0.14, 0.1, 0.08), Vector3(0,0,-0.42))
	add_visual_box(root, "RoofRight", Vector3(4.2, 0.32, 6.2), Vector3(1.55, 4.15, 0), Color(0.14, 0.1, 0.08), Vector3(0,0,0.42))
	add_visual_box(root, "Door", Vector3(1.6, 2.5, 0.16), Vector3(-1.2, 1.65, -2.78), Color(0.16, 0.09, 0.045))
	add_visual_box(root, "Window", Vector3(1.5, 1.2, 0.12), Vector3(1.6, 2.35, -2.8), Color(0.24, 0.58, 0.72))
	add_visual_box(root, "Sign", Vector3(3.8, 0.75, 0.18), Vector3(0, 3.3, -2.92), Color(0.46, 0.3, 0.12))
	add_world_label("RIDGE RELAY POST", origin + Vector3(0, 3.35, -3.08), Color(1.0, 0.83, 0.48), 22)


func build_work_camp(origin: Vector3) -> void:
	var root := Node3D.new()
	root.name = "RepairCamp"
	root.position = origin
	$World.add_child(root)
	add_visual_box(root, "Canvas", Vector3(4.8, 0.16, 3.4), Vector3(0, 2.1, 0), Color(0.44, 0.34, 0.2), Vector3(0.1,0,-0.35))
	for leg: Vector3 in [Vector3(-2,1,1.3), Vector3(2,1,1.3), Vector3(-2,1,-1.3), Vector3(2,1,-1.3)]:
		add_visual_cylinder(root, "TentPole", 0.07, 2.1, leg, Color(0.24,0.14,0.07))
	add_static_box(root, "Workbench", Vector3(3.4, 0.25, 1.2), Vector3(0, 1.05, 0.5), Color(0.29, 0.17, 0.08))
	for x: float in [-1.3, 1.3]:
		add_visual_box(root, "BenchLeg", Vector3(0.22, 1.8, 0.22), Vector3(x, 0.45, 0.5), Color(0.2,0.11,0.05))
	add_visual_cylinder(root, "SpareGear", 0.62, 0.18, Vector3(-0.8,1.35,0.45), Color(0.38,0.42,0.43), Vector3(PI/2,0,0))
	add_visual_box(root, "ToolCase", Vector3(1.1,0.55,0.75), Vector3(0.9,1.35,0.45), Color(0.12,0.3,0.34))


func build_relay(origin: Vector3) -> void:
	relay_root = Node3D.new()
	relay_root.name = "DamagedRelay"
	relay_root.position = origin
	$World.add_child(relay_root)
	add_static_box(relay_root, "Foundation", Vector3(5.6, 0.7, 5.6), Vector3(0, 0.35, 0), Color(0.34,0.34,0.3))
	add_visual_cylinder(relay_root, "Tower", 0.5, 5.8, Vector3(0,3.2,0), Color(0.31,0.35,0.36), Vector3(0,0,0.11))
	add_visual_cylinder(relay_root, "Hub", 0.86, 0.55, Vector3(0.62,5.3,0), Color(0.42,0.33,0.18), Vector3(0,0,PI/2))
	broken_arm = Node3D.new()
	broken_arm.name = "BrokenSignalArm"
	relay_root.add_child(broken_arm)
	add_visual_box(broken_arm, "UpperArm", Vector3(3.6,0.28,0.34), Vector3(1.8,5.35,0), Color(0.37,0.25,0.12), Vector3(0,0,-0.2))
	add_visual_box(broken_arm, "FallenArm", Vector3(3.0,0.28,0.34), Vector3(2.0,1.3,0.8), Color(0.32,0.2,0.09), Vector3(0.1,0.3,0.95))
	repaired_arm = Node3D.new()
	repaired_arm.name = "RepairedSignalArm"
	repaired_arm.visible = false
	relay_root.add_child(repaired_arm)
	add_visual_box(repaired_arm, "SignalArm", Vector3(6.4,0.34,0.4), Vector3(0,5.45,0), Color(0.5,0.39,0.18))
	add_visual_cylinder(repaired_arm, "Counterweight", 0.42, 0.9, Vector3(-2.65,5.05,0), Color(0.29,0.31,0.31))
	foundation_rubble = Node3D.new()
	foundation_rubble.name = "FoundationRubble"
	relay_root.add_child(foundation_rubble)
	for p: Vector3 in [Vector3(-2.1,0.55,-1.7), Vector3(2.0,0.5,-1.4), Vector3(-1.8,0.45,1.8), Vector3(2.2,0.52,1.5)]:
		add_visual_sphere(foundation_rubble, "LooseStone", 0.58, p, Color(0.31,0.32,0.29), Vector3(1.2,0.7,1))
	raised_foundation = Node3D.new()
	raised_foundation.name = "RaisedFoundation"
	raised_foundation.visible = false
	relay_root.add_child(raised_foundation)
	for side: float in [-1.0, 1.0]:
		add_visual_box(raised_foundation, "StoneButtress", Vector3(1.1,1.7,3.6), Vector3(side*2.2,0.85,0), Color(0.42,0.43,0.37), Vector3(0,0,side*0.12))
	dead_conduit = Node3D.new()
	dead_conduit.name = "DeadConduit"
	relay_root.add_child(dead_conduit)
	for index: int in range(5):
		add_visual_cylinder(dead_conduit, "BrokenCable", 0.06, 1.2, Vector3(-1.3 + index*0.58,0.9,2.3), Color(0.11,0.12,0.12), Vector3(0.5,0,0.3))
	live_conduit = Node3D.new()
	live_conduit.name = "LiveConduit"
	live_conduit.visible = false
	relay_root.add_child(live_conduit)
	for index: int in range(7):
		add_visual_cylinder(live_conduit, "LiveCable", 0.07, 0.9, Vector3(-2.2 + index*0.72,0.82,2.25), Color(0.18,0.55,0.75), Vector3(PI/2,0,0))
	beacon_core = add_visual_sphere(relay_root, "BeaconCore", 0.48, Vector3(0,6.15,0), Color(0.16,0.19,0.21))
	beacon_light = OmniLight3D.new()
	beacon_light.name = "BeaconLight"
	beacon_light.position = Vector3(0,6.15,0)
	beacon_light.light_color = Color(0.4,0.8,1.0)
	beacon_light.light_energy = 0.0
	beacon_light.omni_range = 13.0
	relay_root.add_child(beacon_light)


func build_waykeeper() -> void:
	tamsin = Area3D.new()
	tamsin.name = "TamsinWaykeeper"
	tamsin.position = Vector3(-2.8, 0.1, 2.8)
	tamsin.set_script(ConversationNPCScript)
	tamsin.set("display_name", "Tamsin")
	tamsin.set("title", "Ridge Waykeeper")
	tamsin.set("prompt_text", "Talk to Tamsin")
	tamsin.set("portrait_color", Color(0.28,0.63,0.72))
	add_child(tamsin)
	var data := {
		"display_name": "Tamsin",
		"title": "Ridge Waykeeper",
		"portrait_color": Color(0.28,0.63,0.72),
		"entry": "start",
		"repeat_entry": "repaired",
		"resolved_flag": FLAG_REPAIRED,
		"nodes": {
			"start": {
				"speaker": "Tamsin",
				"text": "Mind the loose stone. The storm twisted our ridge relay half out of its foundation, snapped the signal arm, and burned every conduit in the base.",
				"choices": [
					{"id":"inspect","text":"What does the relay control?","next":"explain"},
					{"id":"metal_repair","text":"Reshape the broken arm and braces with Metal magic.","next":"metal_result","requires_stat":"metal","stat_minimum":1,"requirement_text":"Metal affinity 1 required","set_flag":FLAG_METAL,"relationship_delta":3,"objective":"Watch the restored relay return to service."},
					{"id":"earth_repair","text":"Raise a new stone foundation beneath the tower.","next":"earth_result","requires_stat":"earth","stat_minimum":1,"requirement_text":"Earth affinity 1 required","set_flag":FLAG_EARTH,"relationship_delta":2,"objective":"Watch the restored relay return to service."},
					{"id":"lightning_repair","text":"Reroute power through the surviving conduits.","next":"lightning_result","requires_stat":"lightning","stat_minimum":1,"requirement_text":"Lightning affinity 1 required","set_flag":FLAG_LIGHTNING,"relationship_delta":2,"objective":"Watch the restored relay return to service."},
					{"id":"leave","text":"I need to examine the damage first.","next":"leave"}
				]
			},
			"explain": {
				"speaker":"Tamsin",
				"text":"Every traveler between the wetlands and the mountain road watches that blue lamp. Dark means the pass is unsafe. Lit means shelter, supplies, and a clear route ahead. Right now, every town west of here thinks the ridge has vanished.",
				"choices":[
					{"id":"metal_after","text":"Then I will rebuild the arm.","next":"metal_result","requires_stat":"metal","stat_minimum":1,"requirement_text":"Metal affinity 1 required","set_flag":FLAG_METAL,"relationship_delta":3},
					{"id":"earth_after","text":"I can give the tower a stronger foundation.","next":"earth_result","requires_stat":"earth","stat_minimum":1,"requirement_text":"Earth affinity 1 required","set_flag":FLAG_EARTH,"relationship_delta":2},
					{"id":"lightning_after","text":"Let me restore the current first.","next":"lightning_result","requires_stat":"lightning","stat_minimum":1,"requirement_text":"Lightning affinity 1 required","set_flag":FLAG_LIGHTNING,"relationship_delta":2},
					{"id":"back","text":"Let me look around.","next":"start"}
				]
			},
			"metal_result":{"speaker":"Tamsin","text":"The iron is moving without heat... There. The arm is straight, the counterweight is seated, and the tower is standing true again.","next":"finish"},
			"earth_result":{"speaker":"Tamsin","text":"Those stones fit tighter than the original masonry. The foundation has stopped shifting. I can reconnect the arm from here.","next":"finish"},
			"lightning_result":{"speaker":"Tamsin","text":"Easy... The old copper is carrying it. The relay motor is turning again, and the safety lamp is waking up.","next":"finish"},
			"finish":{"speaker":"Tamsin","text":"Look west. The next post will see our light and answer. You did more than repair a machine; you put the ridge back on the map.","choices":[{"id":"complete_repair","text":"Keep the lamp burning.","set_flag":FLAG_REPAIRED,"relationship_delta":1,"objective":"The ridge relay is restored. Speak with Tamsin or continue east."}]},
			"leave":{"speaker":"Tamsin","text":"Take your time. The snapped arm, shattered footing, and burned conduits are all part of the same failure. Fix any one properly and I can finish the rest."},
			"repaired":{"speaker":"Tamsin","text":"The signal has already been answered from the western post. For the first time since the storm, travelers know this road still exists."}
		}
	}
	tamsin.call("configure", data)
	tamsin.connect("choice_selected", _on_tamsin_choice)
	tamsin.connect("conversation_finished", _on_tamsin_finished)


func _on_tamsin_choice(choice_id: String, _npc: Node) -> void:
	if choice_id in ["metal_repair", "metal_after"]:
		begin_repair("metal")
	elif choice_id in ["earth_repair", "earth_after"]:
		begin_repair("earth")
	elif choice_id in ["lightning_repair", "lightning_after"]:
		begin_repair("lightning")
	elif choice_id == "complete_repair":
		GameState.set_flag(FLAG_REPAIRED, true)
		set_objective("The ridge relay is restored. Speak with Tamsin or continue east.")
		refresh_hud()


func _on_tamsin_finished(_npc: Node) -> void:
	if GameState.get_flag(FLAG_REPAIRED):
		status_label.text = "RELAY ONLINE  •  Western posts have acknowledged the signal."


func begin_repair(method: String) -> void:
	if transformation_active or GameState.get_flag(FLAG_REPAIRED):
		return
	repair_method = method
	transformation_time = 0.0
	transformation_active = true
	broken_arm.visible = false
	foundation_rubble.visible = false
	dead_conduit.visible = false
	match method:
		"metal":
			repaired_arm.visible = true
			result_label.text = "Metal bends into a new signal arm and counterweight."
		"earth":
			raised_foundation.visible = true
			repaired_arm.visible = true
			result_label.text = "Stone rises and locks the leaning tower into place."
		"lightning":
			live_conduit.visible = true
			repaired_arm.visible = true
			result_label.text = "Blue current races through a newly joined circuit."
	beacon_core.material_override = emissive_material(Color(0.28,0.74,1.0), 2.0)
	status_label.text = "RESTORING RELAY  •  " + method.to_upper()


func animate_repair(delta: float) -> void:
	var pulse := 1.0 + sin(transformation_time * 8.0) * 0.12
	beacon_core.scale = Vector3.ONE * pulse
	beacon_light.light_energy = minf(transformation_time * 1.5, 2.6)
	if repaired_arm.visible:
		repaired_arm.rotation.y += delta * 0.35
	if transformation_time >= 2.2:
		transformation_active = false
		repaired_arm.rotation = Vector3.ZERO
		beacon_core.scale = Vector3.ONE
		beacon_light.light_energy = 2.6
		result_label.text = "The ridge beacon is alive. A distant blue answer flashes in the west."
		status_label.text = "RELAY RESTORED  •  Return to Tamsin."
		set_objective("Return to Tamsin beside the restored relay.")


func apply_saved_state() -> void:
	if not GameState.get_flag(FLAG_REPAIRED):
		return
	broken_arm.visible = false
	foundation_rubble.visible = false
	dead_conduit.visible = false
	repaired_arm.visible = true
	beacon_core.material_override = emissive_material(Color(0.28,0.74,1.0), 2.0)
	beacon_light.light_energy = 2.6
	if GameState.get_flag(FLAG_EARTH):
		raised_foundation.visible = true
	if GameState.get_flag(FLAG_LIGHTNING):
		live_conduit.visible = true
	result_label.text = "The restored relay marks the ridge road as open."


func update_context_hint() -> void:
	if tamsin == null or player == null:
		return
	if player.global_position.distance_to(tamsin.global_position) < 3.2:
		prompt_label.text = "INTERACT  •  Talk to Tamsin"
	elif player.global_position.distance_to(relay_root.global_position) < 5.5:
		prompt_label.text = "DAMAGED RELAY  •  Speak with Tamsin to choose a repair"
	else:
		prompt_label.text = ""


func reset_encounter() -> void:
	for flag: String in [FLAG_REPAIRED, FLAG_METAL, FLAG_EARTH, FLAG_LIGHTNING]:
		GameState.set_flag(flag, false)
	get_tree().reload_current_scene()


func set_objective(text_value: String) -> void:
	GameState.set_objective(text_value)
	objective_label.text = "OBJECTIVE  •  " + text_value
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("set_objective"):
		ui.call("set_objective", text_value)


func refresh_hud() -> void:
	mission_label.text = "THE BROKEN WAYSTATION  •  WAYKEEPER ENCOUNTER"
	status_label.text = (
		"RELAY ONLINE  •  Repair acknowledged across the ridge."
		if GameState.get_flag(FLAG_REPAIRED)
		else "RELAY OFFLINE  •  Arm broken  •  Foundation unstable  •  Conduits burned"
	)


func build_tree(position_value: Vector3) -> void:
	var root := Node3D.new()
	root.position = position_value
	$World.add_child(root)
	add_visual_cylinder(root, "Trunk", 0.35, 4.8, Vector3(0,2.4,0), Color(0.18,0.1,0.05))
	for p: Vector3 in [Vector3(0,5,0), Vector3(-0.8,4.7,0.2), Vector3(0.75,4.8,-0.25)]:
		add_visual_sphere(root, "Canopy", 1.3, p, Color(0.08,0.24,0.11), Vector3(1,0.8,1))


func add_static_box(parent: Node3D, node_name: String, size: Vector3, position_value: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material(color)
	body.add_child(visual)
	return body


func add_visual_box(parent: Node3D, node_name: String, size: Vector3, position_value: Vector3, color: Color, rotation_value := Vector3.ZERO) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	visual.rotation = rotation_value
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material(color)
	parent.add_child(visual)
	return visual


func add_visual_cylinder(parent: Node3D, node_name: String, radius: float, height: float, position_value: Vector3, color: Color, rotation_value := Vector3.ZERO) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	visual.rotation = rotation_value
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.9
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	visual.mesh = mesh
	visual.material_override = material(color)
	parent.add_child(visual)
	return visual


func add_visual_sphere(parent: Node3D, node_name: String, radius: float, position_value: Vector3, color: Color, scale_value := Vector3.ONE) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	visual.scale = scale_value
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	visual.mesh = mesh
	visual.material_override = material(color)
	parent.add_child(visual)
	return visual


func add_world_label(text_value: String, position_value: Vector3, color: Color, font_size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text_value
	label.position = position_value
	label.font_size = font_size
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 7
	label.modulate = color
	$World.add_child(label)
	return label


func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.82
	return result


func emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var result := material(color)
	result.emission_enabled = true
	result.emission = color
	result.emission_energy_multiplier = energy
	return result
