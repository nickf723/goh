extends Node

const TacticalNavigationLabScene: PackedScene = preload("res://scenes/levels/prototypes/prototype_tactical_navigation_lab_v1.tscn")
const HazardScript = preload("res://scripts/navigation/tactical_navigation_hazard.gd")

var failures: Array[String] = []


func _ready() -> void:
	test_hazard_personality_contract()
	await test_laboratory_contract()
	if failures.is_empty():
		print("TACTICAL_NAVIGATION_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("TACTICAL_NAVIGATION_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func test_hazard_personality_contract() -> void:
	var hazard: TacticalNavigationHazard = HazardScript.new() as TacticalNavigationHazard
	hazard.radius = 2.0
	hazard.cost_per_meter = 2.0
	add_child(hazard)
	var sample_position: Vector3 = hazard.global_position
	var cautious_cost: float = hazard.get_cost_at_position(sample_position, "cautious")
	var bold_cost: float = hazard.get_cost_at_position(sample_position, "bold")
	var skittish_cost: float = hazard.get_cost_at_position(sample_position, "skittish")
	var brute_cost: float = hazard.get_cost_at_position(sample_position, "brute")
	if cautious_cost <= bold_cost:
		failures.append("Cautious routing must price danger above Bold routing")
	if skittish_cost <= cautious_cost:
		failures.append("Skittish routing must price danger above Cautious routing")
	if brute_cost >= bold_cost:
		failures.append("Brute routing must price danger below Bold routing")
	hazard.queue_free()


func test_laboratory_contract() -> void:
	if TacticalNavigationLabScene == null:
		failures.append("Tactical Navigation laboratory scene failed to load")
		return
	var lab: Node = TacticalNavigationLabScene.instantiate()
	if lab == null:
		failures.append("Tactical Navigation laboratory scene failed to instantiate")
		return
	add_child(lab)
	await get_tree().process_frame
	for frame_index: int in range(8):
		await get_tree().physics_frame
	await get_tree().process_frame

	var regions: Array[Node] = []
	for child: Node in lab.get_children():
		if child is NavigationRegion3D:
			regions.append(child)
	if regions.size() < 4:
		failures.append("Laboratory requires one NavigationRegion3D per personality lane")
	if get_tree().get_nodes_in_group("tactical_route_anchors").size() < 8:
		failures.append("Laboratory requires safe and shortcut route anchors for every lane")
	if get_tree().get_nodes_in_group("tactical_navigation_hazards").size() < 4:
		failures.append("Laboratory requires one shortcut hazard per lane")

	var route_by_personality: Dictionary = {}
	var navigation_components: Array[Node] = get_tree().get_nodes_in_group("tactical_navigation_components")
	if navigation_components.size() < 4:
		failures.append("Laboratory requires four TacticalNavigationAgent components")
	for component_node: Node in navigation_components:
		if not lab.is_ancestor_of(component_node):
			continue
		var component: TacticalNavigationAgent = component_node as TacticalNavigationAgent
		if component == null:
			continue
		route_by_personality[component.personality_id] = component.chosen_route_id
		if not component.navigation_ready:
			failures.append(component.personality_id + " navigation never synchronized")
		if component.chosen_route_id == "none":
			failures.append(component.personality_id + " failed to choose a route")
		if component.get_current_navigation_path().is_empty():
			failures.append(component.personality_id + " received an empty Navigation path")

	for expected: String in ["cautious", "bold", "skittish", "brute"]:
		if not route_by_personality.has(expected):
			failures.append("Missing Tactical Navigation personality: " + expected)
	if route_by_personality.has("cautious") and not str(route_by_personality["cautious"]).contains("safe"):
		failures.append("Cautious should prefer the safe route while danger is active")
	if route_by_personality.has("skittish") and not str(route_by_personality["skittish"]).contains("safe"):
		failures.append("Skittish should prefer the safe route while danger is active")
	if route_by_personality.has("bold") and not str(route_by_personality["bold"]).contains("shortcut"):
		failures.append("Bold should accept the hazardous shortcut")
	if route_by_personality.has("brute") and not str(route_by_personality["brute"]).contains("shortcut"):
		failures.append("Brute should nearly ignore shortcut danger")

	lab.queue_free()
	await get_tree().process_frame
