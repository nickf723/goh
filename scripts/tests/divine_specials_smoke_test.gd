extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const RuviaAvatar: PlayableAvatarDefinition = preload(
	"res://data/avatars/ruvia_incarnation_prototype.tres"
)
const CombatFeelDummyScene: PackedScene = preload(
	"res://scenes/actors/enemies/combat_feel_dummy.tscn"
)

var failures: Array[String] = []
var original_stats: Dictionary = {}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	_prepare_stats()
	var floor: StaticBody3D = _make_floor()
	add_child(floor)
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "DivineSpecialTestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	add_child(player)
	var targets: Array[Node3D] = _spawn_targets()
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	var controller: PlayerDivineSpecialController = (
		player.get_node_or_null(
			"DivineSpecialController"
		) as PlayerDivineSpecialController
	)
	var defense: PlayerDefenseControllerElemental = (
		player.get_node_or_null(
			"PlayerDefenseController"
		) as PlayerDefenseControllerElemental
	)
	var status_receiver: PlayerStatusReceiver = (
		player.get_node_or_null("StatusReceiver") as PlayerStatusReceiver
	)
	var avatar_manager: PlayerAvatarManager = (
		player.get_node_or_null("AvatarManager") as PlayerAvatarManager
	)
	var manifestation_manager: PlayerManifestationManager = (
		player.get_node_or_null(
			"ManifestationManager"
		) as PlayerManifestationManager
	)

	_expect(controller != null, "Shared player installs DivineSpecialController")
	_expect(defense != null, "Shared player retains elemental defense")
	_expect(status_receiver != null, "Shared player retains status receiver")
	_expect(avatar_manager != null, "Shared player retains incarnation manager")
	_expect(
		manifestation_manager != null,
		"Shared player retains manifestation manager"
	)
	if (
		controller == null
		or defense == null
		or status_receiver == null
		or avatar_manager == null
		or manifestation_manager == null
	):
		_finish(player, floor, targets)
		return

	_validate_catalog_and_charge(controller)
	await _validate_caldera(controller)
	_clear_special_fields()
	await get_tree().process_frame
	await _validate_procession(controller)
	_clear_special_fields()
	await get_tree().process_frame
	await _validate_hearth(
		player,
		controller,
		defense,
		status_receiver
	)
	await _validate_manifestation_conflict(
		controller,
		manifestation_manager
	)
	await _validate_incarnated_performer(
		player,
		controller,
		avatar_manager
	)

	_clear_special_fields()
	await get_tree().process_frame
	_finish(player, floor, targets)


func _validate_catalog_and_charge(
	controller: PlayerDivineSpecialController
) -> void:
	var available: Array[DivineSpecialDefinition] = (
		controller.get_available_specials(true)
	)
	_expect(available.size() == 3, "Ruvia exposes three debug Divine Specials")
	_expect(
		controller.get_definition_by_id("ruvia_caldera_drop") != null,
		"Catalog contains Caldera Drop"
	)
	_expect(
		controller.get_definition_by_id("ruvia_wildfire_procession") != null,
		"Catalog contains Wildfire Procession"
	)
	_expect(
		controller.get_definition_by_id("ruvia_hearth_first_flame") != null,
		"Catalog contains Hearth of the First Flame"
	)
	controller.set_charge(0.0, "test_empty")
	var awarded: float = controller.award_charge(12.5, "test_award")
	_expect(is_equal_approx(awarded, 12.5), "Combat charge can be awarded")
	_expect(
		is_equal_approx(controller.divine_charge, 12.5),
		"Awarded Divine Charge is retained"
	)
	controller.force_full_charge("test_full")
	_expect(controller.is_ready(), "Full Divine Charge arms the selected Special")


func _validate_caldera(
	controller: PlayerDivineSpecialController
) -> void:
	controller.force_full_charge("caldera_test")
	_expect(
		controller.select_special_by_id("ruvia_caldera_drop", true),
		"Caldera Drop can be selected"
	)
	_expect(
		controller.activate_selected_special(true),
		"Caldera Drop activates"
	)
	_expect(
		controller.divine_charge <= 0.01,
		"Caldera Drop consumes the shared Divine Charge"
	)
	await get_tree().create_timer(1.2).timeout
	var result: Dictionary = controller.last_effect_result
	_expect(
		str(result.get("special_id", "")) == "ruvia_caldera_drop",
		"Caldera Drop reports its identity"
	)
	_expect(
		bool(result.get("impact_completed", false)),
		"Caldera Drop reaches its impact"
	)
	_expect(
		bool(result.get("fire_field_spawned", false)),
		"Caldera Drop leaves a burning crater"
	)
	_expect(
		int(result.get("targets_hit", 0)) > 0,
		"Caldera Drop affects nearby hostile targets"
	)


func _validate_procession(
	controller: PlayerDivineSpecialController
) -> void:
	controller.force_full_charge("procession_test")
	_expect(
		controller.select_special_by_id(
			"ruvia_wildfire_procession",
			true
		),
		"Wildfire Procession can be selected"
	)
	_expect(
		controller.activate_special_by_id_at(
			"ruvia_wildfire_procession",
			Vector3(0.0, 0.0, -14.0),
			Vector3.FORWARD,
			true
		),
		"Wildfire Procession activates"
	)
	await get_tree().create_timer(1.85).timeout
	var result: Dictionary = controller.last_effect_result
	_expect(
		str(result.get("special_id", ""))
		== "ruvia_wildfire_procession",
		"Wildfire Procession reports its identity"
	)
	_expect(
		int(result.get("eruptions_spawned", 0)) >= 8,
		"Wildfire Procession produces its full eruption line"
	)
	_expect(
		int(result.get("fields_spawned", 0)) >= 8,
		"Wildfire Procession leaves linked Fire terrain"
	)


func _validate_hearth(
	player: CharacterBody3D,
	controller: PlayerDivineSpecialController,
	defense: PlayerDefenseControllerElemental,
	status_receiver: PlayerStatusReceiver
) -> void:
	controller.force_full_charge("hearth_test")
	_expect(
		controller.select_special_by_id(
			"ruvia_hearth_first_flame",
			true
		),
		"Hearth of the First Flame can be selected"
	)
	GameState.set_stat("stance", 2)
	_expect(
		controller.activate_selected_special(true),
		"Hearth of the First Flame activates"
	)
	await get_tree().process_frame
	_expect(
		bool(player.get_meta("divine_special_fire_immunity", false)),
		"Hearth grants Fire protection"
	)
	var fire_payload: DamagePayload = DamagePayload.new()
	fire_payload.amount = 20
	fire_payload.stance_damage = 12
	fire_payload.element = "fire"
	fire_payload.source_name = "Hearth Regression Flame"
	fire_payload.hit_type = "magic"
	var defense_result: Dictionary = defense.resolve_incoming_attack(fire_payload)
	_expect(
		str(defense_result.get("outcome", ""))
		== "divine_special_fire_immunity",
		"Hearth negates incoming Fire damage"
	)
	status_receiver.apply_status("burning", 3.0, 2.0, "Hearth Regression")
	await get_tree().create_timer(0.7).timeout
	_expect(
		not status_receiver.has_status("burning"),
		"Hearth removes Burning before it can tick"
	)
	_expect(
		GameState.get_stat("stance") > 2,
		"Hearth restores allied stance over time"
	)
	_expect(controller.cancel_active_special("hearth_test_cleanup"), "Hearth can be cancelled safely")
	await get_tree().process_frame
	_expect(
		not bool(player.get_meta("divine_special_fire_immunity", false)),
		"Hearth removes Fire protection during cleanup"
	)


func _validate_manifestation_conflict(
	controller: PlayerDivineSpecialController,
	manifestation_manager: PlayerManifestationManager
) -> void:
	_expect(
		manifestation_manager.manifest_prototype(true),
		"Ruvia can manifest before a Divine Special"
	)
	var manifestation: ManifestedAvatarActor = (
		manifestation_manager.get_active_manifestation()
	)
	if manifestation != null:
		manifestation.set_physics_process(false)
	controller.force_full_charge("manifestation_conflict")
	_expect(
		controller.activate_special_by_id_at(
			"ruvia_caldera_drop",
			Vector3(0.0, 0.0, -4.0),
			Vector3.FORWARD,
			true
		),
		"Divine Special activation dismisses an autonomous patron"
	)
	_expect(
		not manifestation_manager.has_active_manifestation(),
		"Manifested Ruvia is gone before the Special performs"
	)
	await get_tree().create_timer(1.2).timeout


func _validate_incarnated_performer(
	player: CharacterBody3D,
	controller: PlayerDivineSpecialController,
	avatar_manager: PlayerAvatarManager
) -> void:
	_expect(
		avatar_manager.incarnate(RuviaAvatar, true),
		"Ruvia Incarnation remains compatible with Divine Specials"
	)
	controller.force_full_charge("incarnated_performer")
	_expect(
		controller.activate_special_by_id_at(
			"ruvia_caldera_drop",
			Vector3(0.0, 0.0, -4.0),
			Vector3.FORWARD,
			true
		),
		"Incarnated Ruvia activates Caldera Drop"
	)
	_expect(
		controller.active_effect != null
		and controller.active_effect.performer_actor == player,
		"Incarnation uses the stable player body as Special performer"
	)
	controller.cancel_active_special("incarnated_test_cleanup")
	await get_tree().process_frame
	_expect(
		avatar_manager.dismiss_avatar("divine_special_test"),
		"Grace returns after the incarnated Special test"
	)


func _spawn_targets() -> Array[Node3D]:
	var targets: Array[Node3D] = []
	var positions: Array[Vector3] = [
		Vector3(0.0, 0.0, -4.0),
		Vector3(-1.4, 0.0, -4.4),
		Vector3(1.4, 0.0, -4.4),
		Vector3(0.0, 0.0, -7.0),
		Vector3(0.0, 0.0, -10.0),
	]
	for target_index: int in range(positions.size()):
		var instance: Node = CombatFeelDummyScene.instantiate()
		if not (instance is Node3D):
			if instance != null:
				instance.queue_free()
			continue
		var target: Node3D = instance as Node3D
		target.name = "DivineSpecialSmokeTarget" + str(target_index + 1)
		target.position = positions[target_index]
		add_child(target)
		targets.append(target)
	return targets


func _clear_special_fields() -> void:
	for candidate: Node in get_tree().get_nodes_in_group("hazard_reactive"):
		if candidate is FireField and is_instance_valid(candidate):
			candidate.queue_free()


func _prepare_stats() -> void:
	GameState.set_stat("max_health", 100)
	GameState.set_stat("health", 100)
	GameState.set_stat("max_mana", 20)
	GameState.set_stat("mana", 20)
	GameState.set_stat("max_stamina", 20)
	GameState.set_stat("stamina", 20)
	GameState.set_stat("max_stance", 20)
	GameState.set_stat("stance", 20)


func _make_floor() -> StaticBody3D:
	var floor: StaticBody3D = StaticBody3D.new()
	floor.name = "DivineSpecialTestFloor"
	floor.position = Vector3(0.0, -0.1, 0.0)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(80.0, 0.2, 80.0)
	collision.shape = shape
	floor.add_child(collision)
	return floor


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _restore_stats() -> void:
	GameState.stats = original_stats.duplicate(true)
	for stat_value: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_value)
		GameState.stat_changed.emit(
			stat_id,
			int(GameState.stats[stat_value])
		)


func _finish(
	player: Node,
	floor: Node,
	targets: Array[Node3D]
) -> void:
	if player != null:
		player.queue_free()
	if floor != null:
		floor.queue_free()
	for target: Node3D in targets:
		if target != null and is_instance_valid(target):
			target.queue_free()
	_restore_stats()
	if failures.is_empty():
		print("DIVINE_SPECIALS_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("DIVINE_SPECIALS_SMOKE_TEST: " + failure)
	get_tree().quit(1)
