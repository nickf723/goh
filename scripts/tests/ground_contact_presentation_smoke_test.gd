extends Node

const GreenScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_green_grotto_art_target_v1.tscn"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var target: Node = GreenScene.instantiate()
	add_child(target)
	for _index: int in range(6):
		await get_tree().process_frame

	var director: GreenGrottoGroundContactAdapter = target.get_node_or_null(
		"GreenGrottoGroundContact"
	) as GreenGrottoGroundContactAdapter
	var lighting: LightingDirector3D = target.get_node_or_null(
		"LightingDirector"
	) as LightingDirector3D
	var player: CharacterBody3D = target.get_node_or_null(
		"Player"
	) as CharacterBody3D
	_expect(director != null, "Green installs Ground Contact Presentation")
	_expect(lighting != null, "contact test resolves LightingDirector")
	_expect(player != null, "contact test resolves Grace")
	if director != null and lighting != null and player != null:
		_validate_contract(director)
		_validate_surface_tags(target, director, player)
		await _validate_quality_and_bursts(director, lighting, player)

	target.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_contract(director: GreenGrottoGroundContactAdapter) -> void:
	var data: Dictionary = director.get_debug_data()
	_expect(bool(data.get("ground_contact_presentation_director", false)), "Ground Contact publishes shared presentation contract")
	_expect(bool(data.get("green_grotto_ground_contact_adapter", false)), "Green adapter publishes authored surface contract")
	_expect(bool(data.get("initialized", false)), "Ground Contact initializes with profile and particle pool")
	_expect(str(data.get("profile_id", "")) == "green_grotto_ground_contact", "Green uses dedicated ground contact profile")
	_expect(bool(data.get("event_listener", false)), "Ground Contact listens to Presentation Director semantic events")
	_expect(bool(data.get("pooled_multimesh", false)), "Ground Contact uses one pooled MultiMesh")
	_expect(bool(data.get("raycasts_on_semantic_events_only", false)), "Ground Contact only raycasts when movement semantics arrive")
	_expect(bool(data.get("follows_lighting_quality", false)), "Ground Contact follows F7 quality")
	_expect(bool(data.get("collision_unchanged", false)), "Ground Contact leaves collision unchanged")
	_expect(not bool(data.get("gameplay_authority", true)), "Ground Contact owns no gameplay state")
	_expect(int(data.get("pool_size", 0)) == 72, "Green contact pool stays fixed at 72 particles")
	_expect(int(data.get("tagged_surfaces", 0)) >= 10, "Green adapter tags a useful collision surface set")
	var tagged: Dictionary = _dictionary_value(data.get("tagged_counts", {}))
	_expect(int(tagged.get("paving", 0)) >= 8, "causeway and shrine collision are tagged as paving")
	_expect(int(tagged.get("moss_soil", 0)) >= 1, "arrival shelf is tagged as moss/soil")
	_expect(int(tagged.get("wet_stone", 0)) >= 1, "waterfall-side ledges receive wet-stone contact tags")


func _validate_surface_tags(
	target: Node,
	director: GreenGrottoGroundContactAdapter,
	player: CharacterBody3D
) -> void:
	var arrival: Node = target.get_node_or_null(
		"GreenGrottoArt/Terrain/ArrivalShelf"
	)
	_expect(arrival != null, "contact test resolves ArrivalShelf")
	if arrival != null:
		_expect(str(arrival.get_meta("contact_surface", "")) == "moss_soil", "ArrivalShelf owns moss_soil contact metadata")

	var causeway: Node = target.get_node_or_null(
		"GreenGrottoArt/AncientRuins/CausewaySlab00"
	)
	_expect(causeway != null, "contact test resolves CausewaySlab00")
	if causeway != null:
		_expect(str(causeway.get_meta("contact_surface", "")) == "paving", "CausewaySlab00 owns paving contact metadata")

	var actor_id: int = player.get_instance_id()
	var arrival_surface: String = director.resolve_contact_surface(
		Vector3(0.0, 0.08, 13.0),
		"stone",
		actor_id
	)
	_expect(arrival_surface == "moss_soil", "contact ray resolves arrival moss/soil surface")
	var causeway_surface: String = director.resolve_contact_surface(
		Vector3(0.0, 0.34, 8.7),
		"stone",
		actor_id
	)
	_expect(causeway_surface == "paving", "contact ray resolves causeway paving surface")


func _validate_quality_and_bursts(
	director: GreenGrottoGroundContactAdapter,
	lighting: LightingDirector3D,
	player: CharacterBody3D
) -> void:
	var actor_id: int = player.get_instance_id()
	director.clear_particles()
	lighting.set_quality(LightingDirector3D.Quality.PERFORMANCE)
	await get_tree().process_frame
	director.call("_on_event_presented", "footstep", {
		"position": Vector3(0.0, 0.08, 13.0),
		"material": "stone",
		"strength": 0.25,
		"actor_instance_id": actor_id,
		"event_id": 101,
	})
	_expect(director.get_active_particle_count() == 0, "Performance contact density is zero")

	lighting.set_quality(LightingDirector3D.Quality.BALANCED)
	await get_tree().process_frame
	director.call("_on_event_presented", "footstep", {
		"position": Vector3(0.0, 0.08, 13.0),
		"material": "stone",
		"strength": 0.25,
		"actor_instance_id": actor_id,
		"event_id": 102,
	})
	var balanced_count: int = director.get_active_particle_count()
	_expect(balanced_count >= 2 and balanced_count <= 3, "Balanced moss/soil footstep uses reduced particle density")
	_expect(str(director.get_debug_data().get("last_surface", "")) == "moss_soil", "Balanced burst records detailed moss/soil surface")

	director.clear_particles()
	lighting.set_quality(LightingDirector3D.Quality.CINEMATIC)
	await get_tree().process_frame
	director.call("_on_event_presented", "landing", {
		"position": Vector3(0.0, 0.34, 8.7),
		"material": "stone",
		"strength": 0.92,
		"actor_instance_id": actor_id,
		"event_id": 103,
	})
	var cinematic_count: int = director.get_active_particle_count()
	_expect(cinematic_count >= 5, "Cinematic hard landing produces a stronger paving burst")
	_expect(str(director.get_debug_data().get("last_surface", "")) == "paving", "Cinematic landing records detailed paving surface")
	_expect(str(director.get_debug_data().get("last_event_type", "")) == "landing", "Ground Contact distinguishes landing from footstep")

	var pool_nodes: Array[Node] = []
	for child: Node in director.get_children():
		if child is MultiMeshInstance3D:
			pool_nodes.append(child)
	_expect(pool_nodes.size() == 1, "all contact chips stay inside one MultiMesh draw pool")


func _dictionary_value(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("GROUND_CONTACT_PRESENTATION_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("GROUND_CONTACT_PRESENTATION_SMOKE_TEST: " + failure)
	get_tree().quit(1)
