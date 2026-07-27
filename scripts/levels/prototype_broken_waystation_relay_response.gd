extends "res://scripts/levels/prototype_broken_waystation_mission.gd"

const StoryInteractableScript = preload("res://scripts/interaction/story_interactable.gd")
const GoblinScene: PackedScene = preload("res://scenes/actors/enemies/goblin_drone.tscn")
const GremlinScene: PackedScene = preload("res://scenes/actors/enemies/gremlin_drone.tscn")

const FLAG_INVESTIGATION := "broken_waystation_relay_investigation"
const FLAG_CONDUIT_DISABLED := "broken_waystation_remote_conduit_disabled"
const FLAG_PRISM_RECOVERED := "broken_waystation_prism_recovered"
const FLAG_PRISM_RETURNED := "broken_waystation_prism_returned"
const FLAG_SPACE_OVERLOOK := "broken_waystation_space_overlook"

var trail_root: Node3D
var remote_relay: Node3D
var remote_core: MeshInstance3D
var remote_light: OmniLight3D
var response_label: Label3D
var conduit_visual: Node3D
var prism_visual: Node3D
var prism_interactable: Area3D
var conduit_interactable: Area3D
var space_interactable: Area3D
var encounter_enemies: Array[Node3D] = []
var encounter_started := false
var captain_spawned := false
var encounter_cleared := false
var response_pulse := 0.0


func _ready() -> void:
	super._ready()
	apply_response_saved_state()
	refresh_response_objective()


func _process(delta: float) -> void:
	super._process(delta)
	animate_response_site(delta)
	update_relay_response_flow()


func build_authored_waystation() -> void:
	super.build_authored_waystation()
	build_signal_trail()
	build_remote_relay_site()


func build_waykeeper() -> void:
	tamsin = Area3D.new()
	tamsin.name = "TamsinWaykeeper"
	tamsin.position = Vector3(-2.8, 0.1, 2.8)
	tamsin.set_script(ConversationNPCScript)
	tamsin.set("display_name", "Tamsin")
	tamsin.set("title", "Ridge Waykeeper")
	tamsin.set("prompt_text", "Talk to Tamsin")
	tamsin.set("portrait_color", Color(0.28, 0.63, 0.72))
	add_child(tamsin)
	var data := {
		"display_name": "Tamsin",
		"title": "Ridge Waykeeper",
		"portrait_color": Color(0.28, 0.63, 0.72),
		"entry": "start",
		"repeat_entry": "repaired",
		"resolved_flag": FLAG_REPAIRED,
		"entry_rules": [
			{"requires_flag": FLAG_PRISM_RETURNED, "node": "after_return"},
			{"requires_flag": FLAG_PRISM_RECOVERED, "node": "prism_return"},
			{"requires_flag": FLAG_INVESTIGATION, "blocked_by_flag": FLAG_PRISM_RECOVERED, "node": "investigating"},
			{"requires_flag": FLAG_REPAIRED, "node": "repaired"},
		],
		"nodes": {
			"start": {
				"speaker": "Tamsin",
				"text": "Mind the loose stone. The storm twisted our ridge relay half out of its foundation, snapped the signal arm, and burned every conduit in the base.",
				"choices": [
					{"id":"inspect", "text":"What does the relay control?", "next":"explain"},
					{"id":"metal_repair", "text":"Reshape the broken arm and braces with Metal magic.", "next":"metal_result", "requires_stat":"metal", "stat_minimum":1, "requirement_text":"Metal affinity 1 required", "set_flag":FLAG_METAL, "relationship_delta":3, "objective":"Watch the restored relay return to service."},
					{"id":"earth_repair", "text":"Raise a new stone foundation beneath the tower.", "next":"earth_result", "requires_stat":"earth", "stat_minimum":1, "requirement_text":"Earth affinity 1 required", "set_flag":FLAG_EARTH, "relationship_delta":2, "objective":"Watch the restored relay return to service."},
					{"id":"lightning_repair", "text":"Reroute power through the surviving conduits.", "next":"lightning_result", "requires_stat":"lightning", "stat_minimum":1, "requirement_text":"Lightning affinity 1 required", "set_flag":FLAG_LIGHTNING, "relationship_delta":2, "objective":"Watch the restored relay return to service."},
					{"id":"leave", "text":"I need to examine the damage first.", "next":"leave"},
				],
			},
			"explain": {
				"speaker":"Tamsin",
				"text":"Every traveler between the wetlands and the mountain road watches that blue lamp. Dark means the pass is unsafe. Lit means shelter, supplies, and a clear route ahead. Right now, every town west of here thinks the ridge has vanished.",
				"choices":[
					{"id":"metal_after", "text":"Then I will rebuild the arm.", "next":"metal_result", "requires_stat":"metal", "stat_minimum":1, "requirement_text":"Metal affinity 1 required", "set_flag":FLAG_METAL, "relationship_delta":3},
					{"id":"earth_after", "text":"I can give the tower a stronger foundation.", "next":"earth_result", "requires_stat":"earth", "stat_minimum":1, "requirement_text":"Earth affinity 1 required", "set_flag":FLAG_EARTH, "relationship_delta":2},
					{"id":"lightning_after", "text":"Let me restore the current first.", "next":"lightning_result", "requires_stat":"lightning", "stat_minimum":1, "requirement_text":"Lightning affinity 1 required", "set_flag":FLAG_LIGHTNING, "relationship_delta":2},
					{"id":"back", "text":"Let me look around.", "next":"start"},
				],
			},
			"metal_result":{"speaker":"Tamsin", "text":"The iron is moving without heat... There. The arm is straight, the counterweight is seated, and the tower is standing true again.", "next":"finish"},
			"earth_result":{"speaker":"Tamsin", "text":"Those stones fit tighter than the original masonry. The foundation has stopped shifting. I can reconnect the arm from here.", "next":"finish"},
			"lightning_result":{"speaker":"Tamsin", "text":"Easy... The old copper is carrying it. The relay motor is turning again, and the safety lamp is waking up.", "next":"finish"},
			"finish": {
				"speaker":"Tamsin",
				"text":"Look east. The next post should answer once our arm settles. You did more than repair a machine; you put the ridge back on the map.",
				"choices":[{"id":"complete_repair", "text":"Keep the lamp burning.", "set_flag":FLAG_REPAIRED, "relationship_delta":1, "objective":"Watch for an answering relay beyond the ridge."}],
			},
			"leave":{"speaker":"Tamsin", "text":"Take your time. The snapped arm, shattered footing, and burned conduits are all part of the same failure. Fix any one properly and I can finish the rest."},
			"repaired": {
				"speaker":"Tamsin",
				"text":"That eastern flash was wrong. Three short pulses, then one long. Waykeepers use that pattern only when a relay has been seized.",
				"choices":[
					{"id":"accept_investigation", "text":"I will follow the signal and inspect the eastern post.", "set_flag":FLAG_INVESTIGATION, "relationship_delta":2, "objective":"Follow the blue signal stakes to the abandoned eastern relay."},
					{"id":"ask_pattern", "text":"What should I expect at the other post?", "next":"pattern_warning"},
					{"id":"wait", "text":"I need to prepare first."},
				],
			},
			"pattern_warning": {
				"speaker":"Tamsin",
				"text":"A stone platform, a copper relay cage, and a maintenance ledge above it. The trail stakes will pulse while our beacon is lit. If something is operating that post, it will see you coming.",
				"choices":[
					{"id":"accept_after_warning", "text":"Then I will approach carefully.", "set_flag":FLAG_INVESTIGATION, "relationship_delta":2, "objective":"Follow the blue signal stakes to the abandoned eastern relay."},
					{"id":"back_repaired", "text":"Let me prepare.", "next":"repaired"},
				],
			},
			"investigating": {
				"speaker":"Tamsin",
				"text":"Follow the blue stakes through the pines. The old overlook sits left of the trail, and the relay platform is beyond the narrow stone bridge.",
			},
			"prism_return": {
				"speaker":"Tamsin",
				"text":"That prism is not one of ours. See the dark thread trapped inside the glass? Someone taught the relay to answer a signal it should never recognize.",
				"choices":[
					{"id":"return_prism", "text":"Give Tamsin the cracked signal prism.", "set_flag":FLAG_PRISM_RETURNED, "grant_item":"tamsin_eastern_route_chart", "grant_count":1, "relationship_delta":3, "objective":"Relay Response complete. Continue east when ready."},
				],
			},
			"after_return": {
				"speaker":"Tamsin",
				"text":"I have wrapped the prism and marked the eastern chart for you. Whatever sent that false reply came from beyond the mountain road, not from this ridge.",
			},
		},
	}
	tamsin.call("configure", data)
	tamsin.connect("choice_selected", _on_tamsin_choice)
	tamsin.connect("conversation_finished", _on_tamsin_finished)


func _on_tamsin_choice(choice_id: String, npc: Node) -> void:
	super._on_tamsin_choice(choice_id, npc)
	if choice_id in ["accept_investigation", "accept_after_warning"]:
		GameState.set_flag(FLAG_INVESTIGATION, true)
		activate_response_trail()
		set_objective("Follow the blue signal stakes to the abandoned eastern relay.")
		show_status("INVESTIGATION STARTED  •  The eastern stakes are responding.")
	elif choice_id == "return_prism":
		GameState.set_flag(FLAG_PRISM_RETURNED, true)
		GameState.set_weapon_mastery_points("sword", GameState.get_weapon_mastery_points("sword") + 10)
		set_objective("Relay Response complete. Continue east when ready.")
		show_status("RELAY RESPONSE COMPLETE  •  Route chart acquired  •  Sword mastery +10")


func animate_repair(delta: float) -> void:
	var was_active := transformation_active
	super.animate_repair(delta)
	if was_active and not transformation_active:
		response_pulse = 3.5
		activate_response_flash()


func build_signal_trail() -> void:
	trail_root = Node3D.new()
	trail_root.name = "EasternSignalTrail"
	$World.add_child(trail_root)
	add_static_box(trail_root, "TrailGround", Vector3(18, 0.8, 42), Vector3(0, -0.4, 37), Color(0.13, 0.2, 0.12))
	add_static_box(trail_root, "TrailPath", Vector3(4.8, 0.16, 37), Vector3(0, 0.04, 35), Color(0.29, 0.24, 0.16))
	for position_value: Vector3 in [Vector3(-7,0,20), Vector3(7,0,22), Vector3(-7.5,0,29), Vector3(7.2,0,31), Vector3(-7,0,41), Vector3(7,0,43), Vector3(-7.5,0,52), Vector3(7.4,0,54)]:
		build_tree(position_value)
	for index: int in range(6):
		var z_value := 19.0 + float(index) * 5.2
		build_signal_stake(Vector3(-2.3 if index % 2 == 0 else 2.3, 0, z_value), index)
	build_stone_bridge(Vector3(0, 0, 43.5))
	build_overlook(Vector3(-7.0, 0, 34.0))


func build_signal_stake(position_value: Vector3, index: int) -> void:
	var stake := Node3D.new()
	stake.name = "SignalStake%02d" % index
	stake.position = position_value
	trail_root.add_child(stake)
	add_visual_cylinder(stake, "Post", 0.11, 2.2, Vector3(0, 1.1, 0), Color(0.22, 0.17, 0.1))
	var lamp := add_visual_sphere(stake, "SignalLamp", 0.22, Vector3(0, 2.25, 0), Color(0.12, 0.22, 0.28))
	lamp.material_override = emissive_material(Color(0.22, 0.65, 1.0), 1.8)
	stake.visible = GameState.get_flag(FLAG_INVESTIGATION) or GameState.get_flag(FLAG_PRISM_RECOVERED)


func build_stone_bridge(origin: Vector3) -> void:
	var bridge := Node3D.new()
	bridge.name = "NarrowStoneBridge"
	bridge.position = origin
	trail_root.add_child(bridge)
	add_static_box(bridge, "BridgeDeck", Vector3(4.6, 0.55, 6.0), Vector3(0, 0.28, 0), Color(0.36, 0.36, 0.31))
	for side: float in [-1.0, 1.0]:
		add_visual_box(bridge, "BridgeRail", Vector3(0.28, 1.1, 6.0), Vector3(side * 2.15, 0.85, 0), Color(0.28, 0.28, 0.25))
	for z_value: float in [-2.2, 0.0, 2.2]:
		add_visual_box(bridge, "Crack", Vector3(1.3, 0.03, 0.12), Vector3(0.8 * sin(z_value), 0.57, z_value), Color(0.08, 0.08, 0.07), Vector3(0, 0.35, 0))


func build_overlook(origin: Vector3) -> void:
	var overlook := Node3D.new()
	overlook.name = "SignalOverlook"
	overlook.position = origin
	trail_root.add_child(overlook)
	add_static_box(overlook, "OverlookShelf", Vector3(6.0, 0.7, 5.5), Vector3(0, 1.1, 0), Color(0.31, 0.32, 0.27))
	add_visual_box(overlook, "OldSurveyFrame", Vector3(3.8, 0.25, 0.3), Vector3(0, 3.1, 0), Color(0.38, 0.28, 0.14))
	for side: float in [-1.0, 1.0]:
		add_visual_cylinder(overlook, "FramePost", 0.12, 3.0, Vector3(side * 1.7, 1.8, 0), Color(0.25, 0.16, 0.08))
	space_interactable = Area3D.new()
	space_interactable.name = "SpaceOverlookAnchor"
	space_interactable.position = Vector3(5.0, 0, 1.5)
	space_interactable.set_script(StoryInteractableScript)
	space_interactable.set("prompt_text", "Fold space to the survey overlook")
	space_interactable.set("required_flag", FLAG_INVESTIGATION)
	trail_root.add_child(space_interactable)
	space_interactable.connect("activated", _on_space_anchor_activated)
	add_visual_sphere(space_interactable, "SpaceGlyph", 0.5, Vector3(0, 0.6, 0), Color(0.42, 0.2, 0.72), Vector3(1, 0.18, 1))
	add_world_label("OLD SURVEY OVERLOOK", origin + Vector3(0, 4.2, 0), Color(0.68, 0.78, 1.0), 24)


func build_remote_relay_site() -> void:
	remote_relay = Node3D.new()
	remote_relay.name = "AbandonedEasternRelay"
	remote_relay.position = Vector3(0, 0, 56)
	$World.add_child(remote_relay)
	add_static_box(remote_relay, "RelayTerrace", Vector3(16, 0.9, 15), Vector3(0, -0.45, 0), Color(0.23, 0.25, 0.21))
	add_static_box(remote_relay, "RelayPlatform", Vector3(8, 0.65, 7), Vector3(0, 0.33, 0.5), Color(0.36, 0.35, 0.3))
	build_remote_tower()
	build_ruined_maintenance_shed(Vector3(5.1, 0, 3.0))
	build_conduit_station(Vector3(-4.8, 0, 1.5))
	build_prism_case(Vector3(0, 0.9, 1.0))
	response_label = add_world_label("THE EASTERN RELAY IS ANSWERING", Vector3(0, 6.8, 54), Color(0.42, 0.78, 1.0), 32)
	response_label.visible = GameState.get_flag(FLAG_REPAIRED)


func build_remote_tower() -> void:
	add_visual_cylinder(remote_relay, "RemoteTower", 0.46, 6.0, Vector3(0, 3.3, 0), Color(0.25, 0.3, 0.32), Vector3(0, 0, -0.08))
	add_visual_box(remote_relay, "RemoteArm", Vector3(5.5, 0.3, 0.38), Vector3(0, 5.7, 0), Color(0.35, 0.27, 0.13), Vector3(0, 0, 0.15))
	remote_core = add_visual_sphere(remote_relay, "RemoteSignalPrism", 0.55, Vector3(0, 6.35, 0), Color(0.14, 0.16, 0.2))
	remote_core.material_override = emissive_material(Color(0.35, 0.1, 0.52), 1.4)
	remote_light = OmniLight3D.new()
	remote_light.name = "RemoteRelayLight"
	remote_light.position = Vector3(0, 6.35, 0)
	remote_light.light_color = Color(0.55, 0.18, 0.8)
	remote_light.light_energy = 1.2 if GameState.get_flag(FLAG_REPAIRED) else 0.0
	remote_light.omni_range = 14.0
	remote_relay.add_child(remote_light)


func build_ruined_maintenance_shed(origin: Vector3) -> void:
	var shed := Node3D.new()
	shed.name = "RuinedMaintenanceShed"
	shed.position = origin
	remote_relay.add_child(shed)
	add_static_box(shed, "BackWall", Vector3(5.2, 3.5, 0.5), Vector3(0, 1.75, 2.2), Color(0.25, 0.17, 0.1))
	add_static_box(shed, "SideWall", Vector3(0.5, 3.5, 4.6), Vector3(2.35, 1.75, 0), Color(0.25, 0.17, 0.1))
	add_visual_box(shed, "CollapsedRoof", Vector3(5.7, 0.3, 4.8), Vector3(-0.4, 3.6, 0), Color(0.13, 0.09, 0.07), Vector3(0.12, 0, -0.22))
	add_visual_box(shed, "MapTable", Vector3(2.5, 0.2, 1.2), Vector3(0, 1.0, 0.8), Color(0.31, 0.19, 0.09))


func build_conduit_station(origin: Vector3) -> void:
	conduit_visual = Node3D.new()
	conduit_visual.name = "ExposedConduitAssembly"
	conduit_visual.position = origin
	remote_relay.add_child(conduit_visual)
	add_static_box(conduit_visual, "ConduitHousing", Vector3(3.2, 1.8, 2.2), Vector3(0, 0.9, 0), Color(0.22, 0.25, 0.25))
	for index: int in range(5):
		var cable := add_visual_cylinder(conduit_visual, "SparkingCable", 0.07, 1.3, Vector3(-1.0 + index * 0.5, 1.35, -1.15), Color(0.32, 0.62, 0.76), Vector3(PI / 2, 0, 0))
		cable.material_override = emissive_material(Color(0.24, 0.62, 0.9), 1.5)
	conduit_interactable = Area3D.new()
	conduit_interactable.name = "RelayConduitControl"
	conduit_interactable.position = origin + Vector3(0, 0, -1.7)
	conduit_interactable.set_script(StoryInteractableScript)
	conduit_interactable.set("prompt_text", "Disable the corrupted relay conduit")
	conduit_interactable.set("required_flag", FLAG_INVESTIGATION)
	conduit_interactable.set("blocked_flag", FLAG_CONDUIT_DISABLED)
	remote_relay.add_child(conduit_interactable)
	conduit_interactable.connect("activated", _on_conduit_activated)
	add_visual_cylinder(conduit_interactable, "ControlLever", 0.1, 1.5, Vector3(0, 0.8, 0), Color(0.42, 0.28, 0.12), Vector3(0, 0, 0.35))


func build_prism_case(origin: Vector3) -> void:
	prism_visual = Node3D.new()
	prism_visual.name = "CrackedPrismCase"
	prism_visual.position = origin
	remote_relay.add_child(prism_visual)
	add_visual_cylinder(prism_visual, "CaseRing", 0.95, 0.3, Vector3(0, 0.2, 0), Color(0.3, 0.31, 0.3))
	var prism := add_visual_sphere(prism_visual, "CrackedSignalPrism", 0.52, Vector3(0, 0.8, 0), Color(0.42, 0.12, 0.58), Vector3(0.75, 1.25, 0.75))
	prism.material_override = emissive_material(Color(0.48, 0.12, 0.68), 1.8)
	prism_interactable = Area3D.new()
	prism_interactable.name = "CrackedPrismInteractable"
	prism_interactable.position = origin
	prism_interactable.set_script(StoryInteractableScript)
	prism_interactable.set("prompt_text", "Recover the cracked signal prism")
	prism_interactable.set("active", false)
	remote_relay.add_child(prism_interactable)
	prism_interactable.connect("activated", _on_prism_activated)


func activate_response_flash() -> void:
	if response_label != null:
		response_label.visible = true
	if remote_light != null:
		remote_light.light_energy = 2.0
	if remote_core != null:
		remote_core.material_override = emissive_material(Color(0.52, 0.12, 0.78), 2.2)


func activate_response_trail() -> void:
	if trail_root == null:
		return
	for child: Node in trail_root.get_children():
		if child.name.begins_with("SignalStake"):
			child.visible = true
	if response_label != null:
		response_label.visible = true
	if space_interactable != null:
		space_interactable.call("set_active", true)
	if conduit_interactable != null:
		conduit_interactable.call("set_active", true)


func update_relay_response_flow() -> void:
	if not GameState.get_flag(FLAG_INVESTIGATION):
		return
	if not encounter_started and not encounter_cleared and player.global_position.z > 47.0:
		start_remote_encounter()
	if encounter_started:
		prune_response_enemies()
		if encounter_enemies.is_empty():
			if not captain_spawned:
				spawn_relay_captain()
			else:
				finish_remote_encounter()


func start_remote_encounter() -> void:
	encounter_started = true
	show_status("EASTERN RELAY  •  A lookout spots Grace above the bridge.")
	spawn_response_enemy(GremlinScene, Vector3(-3.8, 0.6, 53.5), "RelayLookout")
	spawn_response_enemy(GoblinScene, Vector3(3.5, 0.7, 57.0), "RelayMechanist")


func spawn_relay_captain() -> void:
	captain_spawned = true
	show_status("REINFORCEMENT  •  The relay captain drops from the maintenance ledge.")
	spawn_response_enemy(GoblinScene, Vector3(5.0, 3.9, 58.5), "RelayCaptain")


func spawn_response_enemy(scene: PackedScene, position_value: Vector3, enemy_name: String) -> void:
	var enemy := scene.instantiate()
	if not enemy is Node3D:
		enemy.queue_free()
		return
	$EnemyContainer.add_child(enemy)
	(enemy as Node3D).global_position = position_value
	enemy.name = enemy_name
	enemy.add_to_group("relay_response_enemy")
	encounter_enemies.append(enemy as Node3D)


func prune_response_enemies() -> void:
	var remaining: Array[Node3D] = []
	for enemy: Node3D in encounter_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			remaining.append(enemy)
	encounter_enemies = remaining


func finish_remote_encounter() -> void:
	encounter_started = false
	encounter_cleared = true
	prism_interactable.call("set_active", true)
	show_status("RELAY SECURED  •  The cracked prism can now be recovered.")
	set_objective("Recover the cracked signal prism from the eastern relay.")
	response_label.text = "THE FALSE SIGNAL HAS GONE SILENT"
	remote_light.light_energy = 0.35


func _on_space_anchor_activated(_interactable: Node) -> void:
	if GameState.get_stat("space") < 1:
		show_status("SPACE AFFINITY 1 REQUIRED  •  The overlook remains out of reach.")
		space_interactable.set("used", false)
		return
	GameState.set_flag(FLAG_SPACE_OVERLOOK, true)
	player.global_position = Vector3(-7.0, 2.4, 34.0)
	player.velocity = Vector3.ZERO
	show_status("SPACE ROUTE  •  Grace folds directly onto the old survey overlook.")


func _on_conduit_activated(_interactable: Node) -> void:
	if GameState.get_stat("lightning") < 1 and GameState.get_stat("metal") < 1:
		show_status("LIGHTNING OR METAL AFFINITY 1 REQUIRED  •  The live housing cannot be handled safely.")
		conduit_interactable.set("used", false)
		return
	GameState.set_flag(FLAG_CONDUIT_DISABLED, true)
	conduit_visual.visible = false
	remote_light.light_energy = 0.55
	show_status("CORRUPTED CONDUIT DISABLED  •  The relay captain will enter without powered support.")


func _on_prism_activated(_interactable: Node) -> void:
	GameState.set_flag(FLAG_PRISM_RECOVERED, true)
	prism_visual.visible = false
	remote_core.material_override = material(Color(0.12, 0.14, 0.16))
	remote_light.light_energy = 0.0
	response_label.text = "CRACKED SIGNAL PRISM RECOVERED"
	show_status("EVIDENCE RECOVERED  •  A dark elemental thread moves inside the glass.")
	set_objective("Return the cracked signal prism to Tamsin.")


func animate_response_site(delta: float) -> void:
	if remote_core == null or remote_light == null:
		return
	if GameState.get_flag(FLAG_PRISM_RECOVERED):
		return
	var pulse := 0.65 + sin(Time.get_ticks_msec() * 0.006) * 0.35
	remote_core.scale = Vector3.ONE * (1.0 + pulse * 0.08)
	if GameState.get_flag(FLAG_REPAIRED):
		remote_light.light_energy = maxf(remote_light.light_energy, 1.0 + pulse * 0.8)
	if response_pulse > 0.0:
		response_pulse -= delta
		remote_light.light_energy = 2.6 + pulse


func apply_response_saved_state() -> void:
	if GameState.get_flag(FLAG_INVESTIGATION):
		activate_response_trail()
	if GameState.get_flag(FLAG_CONDUIT_DISABLED):
		conduit_visual.visible = false
	if GameState.get_flag(FLAG_PRISM_RECOVERED):
		encounter_cleared = true
		prism_visual.visible = false
		prism_interactable.call("set_active", false)
		remote_light.light_energy = 0.0
		response_label.text = "CRACKED SIGNAL PRISM RECOVERED"
	if GameState.get_flag(FLAG_PRISM_RETURNED):
		response_label.text = "EASTERN RELAY SECURED"


func refresh_response_objective() -> void:
	if GameState.get_flag(FLAG_PRISM_RETURNED):
		set_objective("Relay Response complete. Continue east when ready.")
	elif GameState.get_flag(FLAG_PRISM_RECOVERED):
		set_objective("Return the cracked signal prism to Tamsin.")
	elif GameState.get_flag(FLAG_INVESTIGATION):
		set_objective("Follow the blue signal stakes to the abandoned eastern relay.")


func show_status(text_value: String) -> void:
	status_label.text = text_value
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text_value)


func reset_encounter() -> void:
	for flag: String in [FLAG_REPAIRED, FLAG_METAL, FLAG_EARTH, FLAG_LIGHTNING, FLAG_INVESTIGATION, FLAG_CONDUIT_DISABLED, FLAG_PRISM_RECOVERED, FLAG_PRISM_RETURNED, FLAG_SPACE_OVERLOOK]:
		GameState.set_flag(flag, false)
	get_tree().reload_current_scene()
