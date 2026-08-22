extends Node

const MoveCatalog = preload("res://scripts/mobs/mob_move_catalog.gd")
const SpeciesCatalog = preload("res://scripts/mobs/mob_species_catalog.gd")
const Evaluator = preload("res://scripts/mobs/mob_move_evaluator.gd")
const Progression = preload("res://scripts/mobs/mob_progression_service.gd")
const Augments = preload("res://scripts/mobs/mob_move_augment_catalog.gd")
const PersonalityAdapter = preload("res://scripts/mobs/mob_personality_adapter.gd")
const BrainScript = preload("res://scripts/mobs/mob_brain_component.gd")
const ExecutionState = preload("res://scripts/mobs/mob_move_execution_state.gd")
const LocomotionCatalog = preload("res://scripts/mobs/mob_locomotion_catalog.gd")
const LocomotionExecutorScript = preload(
	"res://scripts/mobs/mob_locomotion_executor.gd"
)
const EffectRequest = preload("res://scripts/mobs/mob_move_effect_request.gd")
const PayloadBridge = preload("res://scripts/mobs/mob_payload_bridge.gd")
const EffectExecutorScript = preload(
	"res://scripts/mobs/mob_move_effect_executor.gd"
)
const VitalsScript = preload(
	"res://scripts/mobs/mob_vitals_component.gd"
)
const ConditionScript = preload(
	"res://scripts/combat/status_receiver.gd"
)
const GenericAnimalScript = preload(
	"res://scripts/animals/generic_animal_actor.gd"
)
const AbilityCatalog = preload("res://scripts/summons/creature_ability_catalog.gd")

class PayloadProbe:
	extends Node
	var received_payload: DamagePayload
	var receive_count: int = 0


	func receive_damage_payload(payload: DamagePayload) -> Dictionary:
		received_payload = payload
		receive_count += 1
		return {"message": "probe received " + payload.source_name}


class EffectSourceProbe:
	extends Node3D
	var targets: Array[Node] = []
	var recovery_count: int = 0
	var last_recovery_effect: Dictionary = {}


	func get_mob_effect_targets(_request: Dictionary) -> Array[Node]:
		return targets.duplicate()


	func get_mob_effect_origin(_request: Dictionary) -> Vector3:
		return global_position + Vector3.UP * 0.5


	func receive_mob_recovery(
		effect: Dictionary,
		_request: Dictionary
	) -> Dictionary:
		recovery_count += 1
		last_recovery_effect = effect.duplicate(true)
		return {"ok": true, "recovered": true}


class EffectTargetProbe:
	extends Node3D
	var receive_count: int = 0
	var last_payload: DamagePayload


	func receive_damage_payload(payload: DamagePayload) -> Dictionary:
		receive_count += 1
		last_payload = payload
		return {"message": "physical target received " + payload.source_name}


var failures: Array[String] = []
var original_profiles: Dictionary = {}
var effect_requests: Array[Dictionary] = []
var spawned_projectiles: Array[Node] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	_capture_profiles()
	_test_catalogs_and_shared_moves()
	_test_locomotion_profiles()
	_test_locomotion_executor()
	_test_mob_vitals()
	_test_mob_conditions()
	_test_effect_request_payload_bridge()
	_test_physical_effect_executor()
	_test_wolf_policy()
	_test_sheep_policy()
	_test_capybara_policy()
	_test_gorgon_policy()
	_test_personality_adaptation()
	_test_familiar_progression()
	await _test_brain_component()
	_restore_profiles()
	_finish()


func _test_catalogs_and_shared_moves() -> void:
	_expect(MoveCatalog.validate_catalog().is_empty(), "move catalog validates")
	_expect(SpeciesCatalog.validate_catalog().is_empty(), "species catalog validates")
	_expect(LocomotionCatalog.validate_catalog().is_empty(), "locomotion catalog validates")
	_expect(SpeciesCatalog.get_species_ids().size() >= 5, "foundation seeds five contrasting species")
	var bite: MobMoveDefinition = MoveCatalog.get_definition("bite")
	_expect(bite != null, "shared Bite move resolves")
	for species_id: String in ["wolf", "sheep", "capybara", "gorgon", "gremlin"]:
		var species_bite: MobMoveDefinition = AbilityCatalog.get_move_definition(species_id, "bite")
		_expect(species_bite != null, species_id + " references shared Bite")
		if species_bite != null and bite != null:
			_expect(species_bite.move_id == bite.move_id, species_id + " keeps common Bite identity")
	_expect(AbilityCatalog.get_option("gremlin", "bite") != null, "legacy Gremlin Bite execution adapter remains available")
	_expect(AbilityCatalog.get_action("gremlin", "pounce") != null, "legacy Gremlin Pounce action remains available")
	_expect(not bite.timing.is_empty(), "shared moves expose data-driven execution timing")
	var pounce: MobMoveDefinition = MoveCatalog.get_definition("pounce")
	var wade: MobMoveDefinition = MoveCatalog.get_definition("wade")
	_expect(
		pounce.required_locomotion_tags.has("jumper"),
		"Pounce requires a locomotion capability separately from legs"
	)
	_expect(
		wade.required_locomotion_tags.has("swimmer"),
		"Wade requires a validated swimming profile"
	)
	var bite_execution: Variant = ExecutionState.create(bite.to_dictionary())
	_expect(str(bite_execution.phase) == "startup", "move execution begins in startup")
	bite_execution.advance(0.17)
	_expect(str(bite_execution.phase) == "active", "move execution advances into its impact window")
	_expect(not bite_execution.can_interrupt(), "authored Bite impact window resists ordinary interruption")
	_expect(Augments.is_compatible(bite, "ferocious"), "Bite accepts attack augments")
	_expect(not Augments.is_compatible(bite, "wetting"), "Bite rejects projectile-only Wetting augment")


func _test_locomotion_profiles() -> void:
	var bird: Dictionary = LocomotionCatalog.resolve_profile(
		["legs", "wings", "beak"],
		["ground", "flight"]
	)
	_expect(
		(bird.get("failures", []) as Array).is_empty(),
		"winged body resolves ground and flight without species code"
	)
	_expect(
		(bird.get("modes", []) as Array).has("flight"),
		"flight is exposed as a volumetric movement mode"
	)
	var fish: Dictionary = LocomotionCatalog.resolve_profile(
		["fins", "gills", "mouth"],
		["swimming"]
	)
	_expect(
		(fish.get("modes", []) as Array).has("swimmer"),
		"swimming aliases normalize into the shared water mode"
	)
	var mole: Dictionary = LocomotionCatalog.resolve_profile(
		["legs", "claws", "digging_limbs"],
		["ground", "burrow"]
	)
	_expect(
		(mole.get("modes", []) as Array).has("burrower"),
		"digging anatomy unlocks volumetric burrowing"
	)
	var invalid_flyer: Dictionary = LocomotionCatalog.resolve_profile(
		["legs", "mouth"],
		["ground", "flight"]
	)
	_expect(
		not (invalid_flyer.get("failures", []) as Array).is_empty(),
		"flight is rejected when the body has no flight anatomy"
	)


func _test_locomotion_executor() -> void:
	var flyer := CharacterBody3D.new()
	flyer.name = "FlightLocomotionProbe"
	add_child(flyer)
	var flight_executor := (
		LocomotionExecutorScript.new() as MobLocomotionExecutor
	)
	flight_executor.name = "SwimmingController"
	flyer.add_child(flight_executor)
	var flight_configuration: Dictionary = flight_executor.configure(
		["legs", "wings", "beak"],
		["ground", "flight", "hover"],
		"flight"
	)
	_expect(
		bool(flight_configuration.get("ok", false))
		and flight_executor.active_mode == "flight",
		"runtime locomotion can initialize a winged animal in flight"
	)
	var flight_solution: Dictionary = flight_executor.resolve_velocity(
		Vector3(1.0, 1.0, 0.0),
		Vector3.ZERO,
		4.0,
		20.0,
		0.25
	)
	var flight_velocity: Vector3 = flight_solution.get(
		"velocity",
		Vector3.ZERO
	) as Vector3
	_expect(
		flight_velocity.y > 0.0
		and str(flight_solution.get("dimension", "")) == "volumetric",
		"flight executor preserves authored vertical steering"
	)
	_expect(
		not bool(flight_solution.get("uses_gravity", true)),
		"active flight suppresses ground gravity"
	)
	var landing: Dictionary = flight_executor.request_mode("ground", {
		"medium_tags": ["land"],
		"require_medium": true,
		"reason": "smoke_landing",
	})
	_expect(
		bool(landing.get("ok", false))
		and flight_executor.active_mode == "ground",
		"catalogued flight-to-ground transitions execute at runtime"
	)
	var ground_solution: Dictionary = flight_executor.resolve_velocity(
		Vector3(1.0, 1.0, 0.0),
		Vector3.ZERO,
		4.0,
		20.0,
		0.25
	)
	var ground_velocity: Vector3 = ground_solution.get(
		"velocity",
		Vector3.ZERO
	) as Vector3
	_expect(
		is_zero_approx(ground_velocity.y)
		and bool(ground_solution.get("uses_gravity", false)),
		"ground runtime projects movement to a plane and restores gravity"
	)
	var unsupported_swim: Dictionary = flight_executor.request_mode(
		"swimmer",
		{"medium_tags": ["water"]}
	)
	_expect(
		not bool(unsupported_swim.get("ok", true))
		and flight_executor.active_mode == "ground",
		"runtime rejects modes absent from the animal's validated profile"
	)

	var water := SwimmingWaterVolume.new()
	water.name = "AnimalWaterProbe"
	water.position = Vector3(0.0, -2.0, 0.0)
	water.surface_height_offset = 2.0
	water.current_velocity = Vector3(0.5, 0.0, 0.0)
	add_child(water)
	var swimmer := CharacterBody3D.new()
	swimmer.name = "SwimmingLocomotionProbe"
	swimmer.position = Vector3(0.0, -1.2, 0.0)
	add_child(swimmer)
	var swim_executor := (
		LocomotionExecutorScript.new() as MobLocomotionExecutor
	)
	swim_executor.name = "SwimmingController"
	swimmer.add_child(swim_executor)
	var swim_configuration: Dictionary = swim_executor.configure(
		["fins", "gills", "mouth", "tail"],
		["swimmer"],
		"swimmer"
	)
	swim_executor.enter_water(water)
	var swim_solution: Dictionary = swim_executor.resolve_velocity(
		Vector3.RIGHT,
		Vector3.ZERO,
		3.0,
		12.0,
		0.25
	)
	var swim_velocity: Vector3 = swim_solution.get(
		"velocity",
		Vector3.ZERO
	) as Vector3
	_expect(
		bool(swim_configuration.get("ok", false))
		and swim_velocity.x > 0.0
		and swim_velocity.y > 0.0,
		"swimming runtime combines steering, current, and surface buoyancy"
	)
	swim_executor.exit_water(water)
	_expect(
		not swim_executor.medium_available
		and swim_executor.should_use_gravity(),
		"water-only animals lose buoyancy and regain gravity outside water"
	)

	var capybara := GenericAnimalScript.new() as GenericAnimalActor
	capybara.species_id = "capybara"
	capybara.animal_name = "Locomotion Capybara"
	add_child(capybara)
	_expect(
		capybara.locomotion != null
		and capybara.get_node_or_null("SwimmingController")
			== capybara.locomotion
		and capybara.get_active_locomotion_mode() == "ground",
		"generic animals compose the shared runtime under the existing water-volume seam"
	)
	capybara.locomotion.enter_water(water)
	_expect(
		capybara.get_active_locomotion_mode() == "swimmer",
		"an amphibious generic animal enters its validated swimming mode"
	)
	var capybara_context: Dictionary = capybara.get_mob_decision_context()
	_expect(
		(capybara_context.get("self_tags", []) as Array).has(
			"locomotion_mode:swimmer"
		),
		"active locomotion mode is visible to Pokemon-like move policy gates"
	)
	capybara.locomotion.exit_water(water)
	_expect(
		capybara.get_active_locomotion_mode() == "ground",
		"an amphibious generic animal returns to ground after leaving water"
	)
	capybara.reset_actor()
	_expect(
		capybara.get_active_locomotion_mode() == "ground",
		"animal reset restores the authored initial locomotion mode"
	)

	capybara.queue_free()
	swimmer.queue_free()
	flyer.queue_free()
	water.queue_free()


func _test_mob_vitals() -> void:
	var vitals := VitalsScript.new() as MobVitalsComponent
	vitals.configure("wolf")
	add_child(vitals)
	_expect(
		is_equal_approx(vitals.maximum_health, 18.0),
		"vitals derive maximum health from the species catalog"
	)
	var bite_request: Dictionary = _effect_request_for("bite", 24)
	var payload: DamagePayload = PayloadBridge.create_damage_payload(
		bite_request
	)
	var damage_result: Dictionary = vitals.receive_damage_payload(payload)
	_expect(
		is_equal_approx(float(damage_result.get("damage_dealt", 0.0)), 3.0),
		"vitals accept the shared DamagePayload contract"
	)
	_expect(
		is_equal_approx(vitals.health, 15.0),
		"damage updates species-scaled health"
	)
	vitals.spend_stamina(4.0)
	var recovery_result: Dictionary = vitals.receive_mob_recovery(
		{"health": 1.0, "stamina": 2.0},
		{"request_id": "vitals:recovery", "move_id": "graze"}
	)
	_expect(
		is_equal_approx(float(recovery_result.get("health_recovered", 0.0)), 1.0)
		and is_equal_approx(
			float(recovery_result.get("stamina_recovered", 0.0)),
			2.0
		),
		"vitals recovery applies health and stamina through one contract"
	)
	vitals.apply_damage(999.0, "smoke")
	_expect(vitals.incapacitated, "zero health incapacitates an animal")
	vitals.apply_recovery(1.0)
	_expect(
		not vitals.incapacitated,
		"positive health recovery revives an incapacitated animal"
	)
	vitals.reset_to_full()
	_expect(
		is_equal_approx(vitals.health, vitals.maximum_health)
		and is_equal_approx(vitals.stamina, vitals.maximum_stamina),
		"vitals reset restores both resources"
	)
	vitals.queue_free()


func _test_mob_conditions() -> void:
	var conditions: Node = ConditionScript.new()
	conditions.name = "StatusReceiver"
	add_child(conditions)
	conditions.call("apply_status", "pack_focus", 1.0, 1.0, "Howl")
	_expect(
		bool(conditions.call("has_status", "pack_focus")),
		"canonical status receiver accepts support buffs"
	)
	conditions.call("sustain_status", "pack_focus", 0.5, 2.0, "Howl")
	_expect(
		is_equal_approx(
			float(conditions.call("get_status_strength", "pack_focus")),
			2.0
		),
		"condition refresh preserves the strongest authored application"
	)
	conditions.call("advance_statuses", 1.1)
	_expect(
		not bool(conditions.call("has_status", "pack_focus")),
		"timed mob conditions expire deterministically"
	)
	conditions.set("maximum_statuses", 1)
	conditions.call("apply_status", "pack_focus", 2.0, 1.0, "Howl")
	conditions.call("apply_status", "wet", 2.0, 1.0, "smoke")
	_expect(
		not bool(conditions.call("has_status", "wet")),
		"canonical status storage remains bounded"
	)
	conditions.call("clear_all_statuses")
	conditions.set("maximum_statuses", 24)

	var status_target := EffectTargetProbe.new()
	status_target.name = "StatusTarget"
	add_child(status_target)
	remove_child(conditions)
	status_target.add_child(conditions)
	var status_request: Dictionary = _effect_request_for("bite", 25)
	var payload_data: Dictionary = status_request.get("payload", {}).duplicate(true)
	payload_data["statuses"] = [{
		"id": "poisoned",
		"duration": 4.0,
		"strength": 0.75,
	}]
	status_request["payload"] = payload_data
	var status_result: Dictionary = PayloadBridge.deliver_to_target(
		status_request,
		status_target
	)
	_expect(
		bool(status_result.get("ok", false))
		and bool(conditions.call("has_status", "poisoned")),
		"additional payload statuses reach the shared StatusReceiver seam"
	)
	status_target.queue_free()

	var animal := GenericAnimalScript.new() as GenericAnimalActor
	animal.species_id = "wolf"
	animal.animal_name = "Condition Probe"
	add_child(animal)
	var mire_request: Dictionary = _effect_request_for("mire_spit", 26)
	var mire_payload: DamagePayload = PayloadBridge.create_damage_payload(
		mire_request
	)
	animal.receive_damage_payload(mire_payload)
	_expect(
		animal.condition_state != null
		and bool(animal.condition_state.call("has_status", "wet")),
		"generic animals retain a payload's primary status"
	)
	var animal_context: Dictionary = animal.get_mob_decision_context()
	_expect(
		(animal_context.get("self_tags", []) as Array).has("status:wet"),
		"active conditions are available to move policy evaluation"
	)
	animal.condition_state.call("apply_status", "stunned", 1.0, 1.0, "smoke")
	_expect(
		animal.is_action_blocked_by_status()
		and is_zero_approx(animal.get_status_movement_multiplier()),
		"canonical control statuses block animal actions and movement"
	)
	var blocked_decision: Dictionary = animal.force_decision(false)
	_expect(
		str(blocked_decision.get("reason", "")) == "status",
		"controlled animals cannot be forced into a new move"
	)
	animal.condition_state.call("remove_status", "stunned")
	animal.condition_state.call("apply_status", "chill", 2.0, 0.6, "smoke")
	_expect(
		is_equal_approx(animal.get_status_movement_multiplier(), 0.6),
		"animal locomotion consumes the canonical status multiplier"
	)
	var health_before_poison: float = animal.vitals.health
	animal.condition_state.call("apply_status", "poisoned", 2.0, 1.0, "smoke")
	animal.condition_state.call("advance_statuses", 1.1)
	_expect(
		animal.vitals.health < health_before_poison,
		"status damage falls back to the animal's shared payload receiver"
	)
	animal.queue_free()


func _test_effect_request_payload_bridge() -> void:
	var bite: MobMoveDefinition = MoveCatalog.get_definition("bite")
	var execution: Variant = ExecutionState.create(bite.to_dictionary(), {
		"execution_serial": 17,
		"actor_instance_id": 42,
		"species_id": "wolf",
	})
	execution.advance(0.17)
	_expect(execution.claim_active_effect(), "active Bite claims one effect request")
	_expect(not execution.claim_active_effect(), "one execution cannot claim its effect twice")
	var coarse_execution: Variant = ExecutionState.create(bite.to_dictionary())
	coarse_execution.advance(5.0)
	_expect(
		coarse_execution.claim_active_effect(),
		"coarse frames preserve an effect when they cross the whole active window"
	)
	var request: Dictionary = EffectRequest.build(execution.to_dictionary(), {
		"species_id": "wolf",
		"animal_name": "Smoke Wolf",
	})
	_expect(
		EffectRequest.validate_request(request).is_empty(),
		"normalized Bite effect request validates"
	)
	_expect(
		str(request.get("delivery", "")) == "contact_payload",
		"Bite resolves to shared contact payload delivery"
	)
	var payload: DamagePayload = PayloadBridge.create_damage_payload(request)
	_expect(payload != null, "Bite request creates a DamagePayload")
	if payload != null:
		_expect(payload.amount == 3, "Bite payload preserves authored damage")
		_expect(payload.stance_damage == 2, "Bite payload preserves authored stance damage")
		_expect(payload.tags.has("mob_move"), "animal payloads retain shared gameplay lineage")
		_expect(payload.tags.has("species:wolf"), "animal payloads record their species source")
	var probe := PayloadProbe.new()
	add_child(probe)
	var delivery: Dictionary = PayloadBridge.deliver_to_target(request, probe)
	_expect(bool(delivery.get("ok", false)), "animal payload reaches an existing receiver contract")
	_expect(probe.receive_count == 1, "payload bridge delivers exactly once per requested target")
	var mire: MobMoveDefinition = MoveCatalog.get_definition("mire_spit")
	var projectile_execution: Variant = ExecutionState.create(mire.to_dictionary(), {
		"execution_serial": 18,
		"species_id": "gremlin",
	})
	projectile_execution.advance(0.3)
	projectile_execution.claim_active_effect()
	var projectile_request: Dictionary = EffectRequest.build(
		projectile_execution.to_dictionary(),
		{"species_id": "gremlin"}
	)
	var premature_delivery: Dictionary = PayloadBridge.deliver_to_target(
		projectile_request,
		probe
	)
	_expect(
		bool(premature_delivery.get("requires_executor", false)),
		"projectiles require a physical impact before payload delivery"
	)
	var impact_delivery: Dictionary = PayloadBridge.deliver_to_target(
		projectile_request,
		probe,
		null,
		{"impact_confirmed": true}
	)
	_expect(bool(impact_delivery.get("ok", false)), "confirmed projectile impact delivers its payload")
	probe.queue_free()


func _test_physical_effect_executor() -> void:
	spawned_projectiles.clear()
	var source := EffectSourceProbe.new()
	source.name = "EffectSource"
	add_child(source)
	var near_target := EffectTargetProbe.new()
	near_target.name = "NearTarget"
	near_target.global_position = Vector3(1.0, 0.0, 0.0)
	add_child(near_target)
	var far_target := EffectTargetProbe.new()
	far_target.name = "FarTarget"
	far_target.global_position = Vector3(4.0, 0.0, 0.0)
	add_child(far_target)
	var executor := EffectExecutorScript.new() as MobMoveEffectExecutor
	executor.name = "MobMoveEffectExecutor"
	executor.automatic_execution = false
	executor.fallback_enemy_groups = []
	executor.fallback_ally_groups = []
	executor.projectile_spawned.connect(_capture_spawned_projectile)
	source.add_child(executor)

	source.targets = [near_target]
	var bite_request: Dictionary = _effect_request_for("bite", 31)
	var contact_result: Dictionary = executor.execute_request(bite_request)
	_expect(bool(contact_result.get("ok", false)), "contact executor delivers to an in-range target")
	_expect(near_target.receive_count == 1, "contact executor sends one shared payload")
	var duplicate_result: Dictionary = executor.execute_request(bite_request)
	_expect(bool(duplicate_result.get("duplicate", false)), "executor rejects a repeated request id")
	_expect(near_target.receive_count == 1, "duplicate execution cannot deal damage twice")

	source.targets = [far_target]
	var distant_bite: Dictionary = _effect_request_for("bite", 32)
	var distant_result: Dictionary = executor.execute_request(distant_bite)
	_expect(
		bool(distant_result.get("requires_target", false)),
		"contact targets outside authored range are rejected"
	)
	_expect(far_target.receive_count == 0, "out-of-range contact delivers no payload")

	near_target.add_to_group("mob_effect_fallback_probe")
	executor.fallback_enemy_groups = ["mob_effect_fallback_probe"]
	source.targets.clear()
	var authoritative_request: Dictionary = _effect_request_for("bite", 36)
	var authoritative_result: Dictionary = executor.execute_request(
		authoritative_request
	)
	_expect(
		bool(authoritative_result.get("requires_target", false)),
		"an authoritative provider may intentionally return no targets"
	)
	_expect(
		near_target.receive_count == 1,
		"fallback groups cannot override species-specific target ownership"
	)
	executor.fallback_enemy_groups = []
	near_target.remove_from_group("mob_effect_fallback_probe")

	source.targets = [near_target, near_target, far_target]
	var sweep_request: Dictionary = _effect_request_for("tail_sweep", 33)
	var sweep_result: Dictionary = executor.execute_request(sweep_request)
	_expect(int(sweep_result.get("delivered_count", 0)) == 1, "area executor filters range and duplicate targets")
	_expect(near_target.receive_count == 2, "area payload reaches each valid target once")
	_expect(far_target.receive_count == 0, "area payload excludes distant targets")

	source.targets.clear()
	var graze_request: Dictionary = _effect_request_for("graze", 34)
	var recovery_result: Dictionary = executor.execute_request(graze_request)
	_expect(bool(recovery_result.get("ok", false)), "recovery executor falls back to the acting animal")
	_expect(source.recovery_count == 1, "recovery request reaches the animal recovery contract")
	_expect(
		int(source.last_recovery_effect.get("health", 0)) == 1,
		"recovery receiver preserves authored Graze healing"
	)

	near_target.global_position = Vector3(4.0, 0.0, 0.0)
	source.targets = [near_target]
	var projectile_request: Dictionary = _effect_request_for("mire_spit", 35)
	var projectile_result: Dictionary = executor.execute_request(projectile_request)
	_expect(bool(projectile_result.get("ok", false)), "projectile executor spawns a physical projectile")
	_expect(executor.projectile_count == 1, "projectile spawn is counted once")
	_expect(spawned_projectiles.size() == 1, "projectile spawn signal exposes the physical action")
	var projectile_probe: Node = (
		spawned_projectiles[0]
		if not spawned_projectiles.is_empty()
		else null
	)
	executor.reset_executor()
	_expect(
		projectile_probe != null
		and projectile_probe.is_queued_for_deletion(),
		"executor reset retires physical projectiles still in flight"
	)
	var reset_debug: Dictionary = executor.get_debug_data()
	_expect(
		int(reset_debug.get("remembered_request_count", -1)) == 0,
		"executor request memory can be cleared on reset"
	)
	_expect(
		int(reset_debug.get("execution_count", -1)) == 0
		and int(reset_debug.get("projectile_count", -1)) == 0
		and int(reset_debug.get("live_projectile_count", -1)) == 0,
		"executor reset clears diagnostic counters and projectile ownership"
	)
	source.queue_free()
	near_target.queue_free()
	far_target.queue_free()


func _test_wolf_policy() -> void:
	var decision: Dictionary = Evaluator.choose_move("wolf", {
		"target_distance": 1.2,
		"self_health_ratio": 1.0,
		"ally_count": 2,
		"enemy_count": 1,
		"context_tags": ["hostile", "hunting"],
	})
	_expect(str(decision.get("move_id", "")) == "bite", "wolf treats Bite as standard close pressure")
	var bite_row: Dictionary = _find_move(Evaluator.evaluate_species("wolf", {
		"target_distance": 1.2,
		"ally_count": 2,
		"context_tags": ["hostile", "hunting"],
	}), "bite")
	_expect(bool(bite_row.get("eligible", false)), "wolf Bite is eligible without desperation tags")


func _test_sheep_policy() -> void:
	var ordinary_threat: Dictionary = {
		"target_distance": 1.0,
		"self_health_ratio": 1.0,
		"ally_count": 3,
		"enemy_count": 1,
		"context_tags": ["threatened", "predator_near", "target_close"],
	}
	var threatened_rows: Array[Dictionary] = Evaluator.evaluate_species("sheep", ordinary_threat)
	_expect(str(_first_eligible(threatened_rows).get("move_id", "")) == "flee", "threatened sheep chooses to flee")
	_expect(not bool(_find_move(threatened_rows, "bite").get("eligible", true)), "ordinary threat does not unlock sheep Bite")
	var cornered_rows: Array[Dictionary] = Evaluator.evaluate_species("sheep", {
		"target_distance": 1.0,
		"self_health_ratio": 0.7,
		"ally_count": 0,
		"enemy_count": 1,
		"context_tags": ["threatened", "cornered", "target_close"],
	})
	_expect(bool(_find_move(cornered_rows, "bite").get("eligible", false)), "cornered sheep may use shared Bite")
	_expect(bool(_find_move(cornered_rows, "headbutt").get("eligible", false)), "cornered sheep also unlocks Headbutt policy")
	var bite_only: Dictionary = Evaluator.choose_move("sheep", {
		"target_distance": 1.0,
		"self_health_ratio": 0.7,
		"context_tags": ["cornered", "threatened"],
		"allowed_move_ids": ["bite"],
	}, {"aggression": 0.95, "courage": 0.9})
	_expect(str(bite_only.get("move_id", "")) == "bite", "individual training can retain only conditional Sheep Bite")


func _test_capybara_policy() -> void:
	var calm_decision: Dictionary = Evaluator.choose_move("capybara", {
		"target_distance": 1.0,
		"ally_count": 4,
		"context_tags": ["safe", "water_near", "hot"],
	})
	_expect(["wade", "graze", "idle"].has(str(calm_decision.get("move_id", ""))), "calm capybara chooses habitat or ambient behavior")
	var water_rows: Array[Dictionary] = Evaluator.evaluate_species("capybara", {
		"target_distance": 2.0,
		"context_tags": ["water_near", "hot"],
	})
	_expect(bool(_find_move(water_rows, "wade").get("eligible", false)), "capybara recognizes water habitat opportunity")
	_expect(not bool(_find_move(water_rows, "bite").get("eligible", true)), "capybara does not casually Bite")
	var cornered_rows: Array[Dictionary] = Evaluator.evaluate_species("capybara", {
		"target_distance": 1.0,
		"context_tags": ["cornered", "threatened"],
	})
	_expect(bool(_find_move(cornered_rows, "bite").get("eligible", false)), "cornered capybara may defend itself with Bite")


func _test_gorgon_policy() -> void:
	var clear_sight: Dictionary = Evaluator.choose_move("gorgon", {
		"target_distance": 6.0,
		"self_health_ratio": 1.0,
		"context_tags": ["line_of_sight", "hostile", "target_stationary"],
	})
	_expect(str(clear_sight.get("move_id", "")) == "stone_gaze", "gorgon selects Stone Gaze with a clear midrange target")
	var immune_rows: Array[Dictionary] = Evaluator.evaluate_species("gorgon", {
		"target_distance": 6.0,
		"context_tags": ["line_of_sight", "hostile"],
		"target_tags": ["gaze_immune"],
	})
	_expect(not bool(_find_move(immune_rows, "stone_gaze").get("eligible", true)), "gorgon rejects Stone Gaze against gaze immunity")
	var crowded: Dictionary = Evaluator.choose_move("gorgon", {
		"target_distance": 2.0,
		"enemy_count": 3,
		"context_tags": ["crowded", "surrounded", "multiple_targets", "hostile"],
	})
	_expect(str(crowded.get("move_id", "")) == "tail_sweep", "crowded gorgon favors Tail Sweep")


func _test_personality_adaptation() -> void:
	var traits: Dictionary = PersonalityAdapter.from_enemy_profile("skittish")
	_expect(float(traits.get("courage", 1.0)) < 0.25, "old Skittish profile maps to low courage")
	var decision: Dictionary = Evaluator.choose_move("wolf", {
		"target_distance": 1.4,
		"self_health_ratio": 0.2,
		"ally_count": 0,
		"enemy_count": 3,
		"context_tags": ["hostile", "injured", "overwhelmed", "alone", "outnumbered"],
	}, traits)
	_expect(str(decision.get("move_id", "")) == "flee", "skittish wounded wolf prioritizes survival over Bite")
	var bold_sheep: Dictionary = PersonalityAdapter.apply_profile_to_species("sheep", "bold")
	_expect(float(bold_sheep.get("aggression", 0.0)) > 0.75, "Bold profile can specialize a normally passive species")


func _test_familiar_progression() -> void:
	var start: Dictionary = Progression.reset_profile("gremlin")
	_expect(int(start.get("level", 0)) == 1, "Gremlin familiar begins at level one")
	_expect(_strings(start.get("learned_moves", [])).has("bite"), "Gremlin familiar begins with Bite")
	_expect(not _strings(start.get("learned_moves", [])).has("mire_spit"), "advanced move begins locked")
	var experience_result: Dictionary = Progression.gain_experience("gremlin", 22)
	_expect(int(experience_result.get("level", 0)) == 3, "experience advances familiar across generic level thresholds")
	var learned_now: Array[String] = _strings(experience_result.get("learned_moves", []))
	_expect(learned_now.has("pounce") and learned_now.has("mire_spit"), "leveling automatically learns movepool unlocks")
	_expect(bool(Progression.equip_move("gremlin", "pounce").get("ok", false)), "learned Pounce equips")
	_expect(bool(Progression.equip_move("gremlin", "mire_spit").get("ok", false)), "learned Mire Spit equips")
	var upgrade: Dictionary = Progression.upgrade_move("gremlin", "bite", 1)
	_expect(int(upgrade.get("rank", 0)) == 2, "Bite rank upgrades generically")
	_expect(bool(Progression.set_move_augment("gremlin", "bite", "primary", "ferocious").get("ok", false)), "Bite accepts Ferocious augment")
	_expect(bool(Progression.set_move_augment("gremlin", "bite", "secondary", "venomous").get("ok", false)), "Bite accepts Venomous augment")
	var resolved: Dictionary = Progression.resolve_move("gremlin", "bite")
	var effect: Dictionary = resolved.get("effect", {}) as Dictionary
	_expect(float(effect.get("damage", 0.0)) > 3.0, "rank and Ferocious augment increase Bite damage")
	_expect(_statuses_have(effect.get("statuses", []), "poisoned"), "Venomous augment adds Poison rider")
	_expect(_strings(resolved.get("applied_augments", [])).has("ferocious"), "resolved move records applied augments")
	var trait_result: Dictionary = Progression.set_personality_trait("gremlin", "aggression", 0.9)
	_expect(bool(trait_result.get("ok", false)), "familiar personality training persists")
	var profile: Dictionary = Progression.get_profile("gremlin")
	var encoded: String = JSON.stringify(profile)
	var decoded: Variant = JSON.parse_string(encoded)
	_expect(decoded is Dictionary, "familiar profile is JSON-safe")
	_expect(_strings(profile.get("equipped_moves", [])).has("pounce"), "equipped movepool persists")
	var familiar_context: Dictionary = Progression.get_decision_context_profile("gremlin", {
		"target_distance": 1.2,
		"context_tags": ["hostile"],
	})
	var familiar_choice: Dictionary = Evaluator.choose_move(
		"gremlin",
		familiar_context,
		profile.get("personality_overrides", {}) as Dictionary
	)
	_expect(str(familiar_choice.get("move_id", "")) == "bite", "trained familiar evaluator respects equipped movepool and range")


func _test_brain_component() -> void:
	effect_requests.clear()
	var brain := BrainScript.new() as MobBrainComponent
	add_child(brain)
	brain.move_effect_requested.connect(_capture_effect_request)
	brain.configure("sheep", "cautious")
	brain.set_context({
		"target_distance": 1.0,
		"context_tags": ["threatened", "predator_near"],
	})
	var decision: Dictionary = brain.request_decision()
	_expect(str(decision.get("move_id", "")) == "flee", "attachable brain chooses from species policy")
	var committed: Dictionary = brain.commit_move("flee")
	_expect(bool(committed.get("ok", false)), "attachable brain commits selected move")
	_expect(float(brain.cooldowns.get("flee", 0.0)) > 0.0, "committing a move starts its cooldown")
	_expect(committed.get("execution_adapter") == null, "new species may select moves before a bespoke executor exists")
	brain.clear_cooldowns()
	var started: Dictionary = brain.begin_move("flee", {"source": "smoke_test"})
	_expect(bool(started.get("ok", false)), "brain begins a selected move lifecycle")
	_expect(brain.has_active_move(), "brain reports its committed active move")
	var blocked: Dictionary = brain.request_decision()
	_expect(bool(blocked.has("blocked_by_active_move")), "active move prevents roulette-style redecision")
	var active_step: Dictionary = brain.advance_active_move(0.08)
	_expect(str(active_step.get("phase", "")) == "active", "movement move enters active execution")
	_expect(effect_requests.size() == 1, "brain emits one effect request on active entry")
	_expect(
		str(effect_requests[0].get("effect_kind", "")) == "movement",
		"effect request preserves the selected move effect"
	)
	brain.advance_active_move(0.05)
	_expect(effect_requests.size() == 1, "remaining in the active phase does not duplicate effects")
	var interrupted: Dictionary = brain.interrupt_active_move("new_threat")
	_expect(bool(interrupted.get("interrupted", false)), "interruptible movement responds to a new threat")
	_expect(not brain.has_active_move(), "interrupted move releases the brain for another decision")
	var cooldown_rejected: Dictionary = brain.begin_move("flee")
	_expect(str(cooldown_rejected.get("error", "")) == "move is on cooldown", "interrupted moves retain their authored cooldown")
	brain.clear_cooldowns()
	var idle_started: Dictionary = brain.begin_move("idle")
	_expect(bool(idle_started.get("ok", false)), "brain can start a follow-up move")
	var completed: Dictionary = brain.advance_active_move(5.0)
	_expect(bool(completed.get("completed", false)), "move lifecycle reports natural completion")
	_expect(not brain.has_active_move(), "completed move releases the action slot")
	brain.clear_cooldowns()
	var request_count_before_interrupt: int = effect_requests.size()
	var bite_started: Dictionary = brain.begin_move("bite")
	_expect(bool(bite_started.get("ok", false)), "brain begins an interruptible Bite startup")
	var bite_interrupted: Dictionary = brain.interrupt_active_move("target_escaped")
	_expect(bool(bite_interrupted.get("interrupted", false)), "Bite can be cancelled before its impact window")
	_expect(
		effect_requests.size() == request_count_before_interrupt,
		"startup interruption prevents an unearned effect request"
	)
	_expect(not bool(brain.begin_move("missing_move").get("ok", true)), "unknown moves cannot enter execution")
	brain.queue_free()
	await get_tree().process_frame


func _effect_request_for(
	move_id: String,
	execution_serial: int
) -> Dictionary:
	var move: MobMoveDefinition = MoveCatalog.get_definition(move_id)
	var execution: Variant = ExecutionState.create(move.to_dictionary(), {
		"execution_serial": execution_serial,
		"actor_instance_id": 700,
		"species_id": "smoke_animal",
		"animal_name": "Smoke Animal",
	})
	execution.advance(10.0)
	execution.claim_active_effect()
	return EffectRequest.build(execution.to_dictionary(), {
		"species_id": "smoke_animal",
		"animal_name": "Smoke Animal",
	})


func _capture_spawned_projectile(
	_request: Dictionary,
	projectile: Node
) -> void:
	spawned_projectiles.append(projectile)


func _capture_effect_request(
	_move_id: String,
	request: Dictionary,
	_execution: Dictionary
) -> void:
	effect_requests.append(request.duplicate(true))


func _capture_profiles() -> void:
	for species_id: String in SpeciesCatalog.get_species_ids():
		var key: String = Progression.PROFILE_PREFIX + species_id
		original_profiles[species_id] = {
			"present": GameState.story_flags.has(key),
			"value": GameState.story_flags.get(key),
		}


func _restore_profiles() -> void:
	for species_id: String in SpeciesCatalog.get_species_ids():
		var key: String = Progression.PROFILE_PREFIX + species_id
		var snapshot: Dictionary = original_profiles.get(species_id, {}) as Dictionary
		if bool(snapshot.get("present", false)):
			GameState.story_flags[key] = snapshot.get("value")
		else:
			GameState.story_flags.erase(key)


func _find_move(rows: Array[Dictionary], move_id: String) -> Dictionary:
	for row: Dictionary in rows:
		if str(row.get("move_id", "")) == move_id:
			return row
	return {}


func _first_eligible(rows: Array[Dictionary]) -> Dictionary:
	for row: Dictionary in rows:
		if bool(row.get("eligible", false)):
			return row
	return {}


func _statuses_have(value: Variant, status_id: String) -> bool:
	if value is Array:
		for raw: Variant in value as Array:
			if raw is Dictionary and str((raw as Dictionary).get("id", "")) == status_id:
				return true
	return false


func _strings(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			result.append(str(raw))
	return result


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("MOB_ENGINE_FOUNDATION_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("MOB_ENGINE_FOUNDATION_SMOKE_TEST: " + failure)
	get_tree().quit(1)
