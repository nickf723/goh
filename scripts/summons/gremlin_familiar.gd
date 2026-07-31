extends "res://scripts/summons/spectral_familiar.gd"
class_name GremlinFamiliar

const AbilityCatalog = preload(
	"res://scripts/summons/creature_ability_catalog.gd"
)
const TargetCandidate = preload(
	"res://scripts/ai/tactical_target_candidate.gd"
)
const TargetAllocator = preload(
	"res://scripts/ai/target_allocation_blackboard.gd"
)
const TargetEvaluator = preload(
	"res://scripts/ai/role_aware_target_evaluator.gd"
)
const GremlinVisualScene: PackedScene = preload(
	"res://scenes/actors/enemies/gremlin_visual_v1.tscn"
)
const FamiliarMireProjectileScene: PackedScene = preload(
	"res://scenes/actions/gremlin_familiar_mire_projectile.tscn"
)

const COMMAND_FOCUS: String = "FOCUS"
const FAMILIAR_SQUAD_ID: String = "grace_familiars"
const SPECIES_ID: String = "gremlin"

@export_group("Familiar Tactics")
@export_range(0.1, 1.0, 0.05) var target_decision_interval: float = 0.35
@export_range(0.1, 2.0, 0.05) var target_claim_duration: float = 0.9
@export_range(2.0, 20.0, 0.5) var familiar_target_range: float = 14.0

@export_group("Technique Motion")
@export_range(2.0, 20.0, 0.5) var pounce_speed: float = 9.5
@export_range(0.1, 1.0, 0.05) var pounce_duration: float = 0.34
@export_range(2.0, 20.0, 0.5) var backstep_speed: float = 8.0
@export_range(0.1, 1.0, 0.05) var backstep_duration: float = 0.28

var familiar_role: String = "skirmisher"
var familiar_temperament: String = "balanced"
var technique_ids: Array[String] = ["bite", "backstep"]
var familiar_definition: Resource = null

var target_decision_timer: float = 0.0
var action_cooldowns: Dictionary = {}
var selected_technique_id: String = "none"
var pounce_remaining: float = 0.0
var pounce_target: Node3D = null
var pounce_hit_registered: bool = false
var backstep_remaining: float = 0.0
var backstep_direction: Vector3 = Vector3.ZERO
var target_evaluation_count: int = 0
var target_switch_count: int = 0
var last_target_plan: Dictionary = {}


func _ready() -> void:
	display_name = "Gremlin Familiar"
	maximum_health = 14
	current_health = maximum_health
	move_speed = 5.6
	acceleration = 20.0
	follow_distance = 2.2
	target_search_range = familiar_target_range
	attack_range = 1.25
	attack_interval = 0.72
	super._ready()
	add_to_group("gremlin_familiar")
	add_to_group("enemy_targetable")
	collision_layer = 2
	collision_mask = 1


func configure_familiar(loadout: Dictionary, definition: Resource = null) -> void:
	familiar_definition = definition
	familiar_role = str(loadout.get("role", "skirmisher")).to_lower()
	familiar_temperament = str(loadout.get("temperament", "balanced")).to_lower()
	technique_ids = _string_array(loadout.get("technique_ids", ["bite", "backstep"]))
	if technique_ids.is_empty():
		technique_ids = ["bite"]
	var configured_command: String = str(loadout.get("command", "ASSIST")).to_upper()
	match configured_command:
		"RALLY":
			set_command(COMMAND_FOLLOW)
		"HOLD":
			set_command(COMMAND_STAY)
		"FOCUS":
			set_command(COMMAND_FOCUS)
		_:
			set_command(COMMAND_ASSIST)
	_refresh_attack_range()
	target_decision_timer = 0.0
	_refresh_target()


func set_command(next_command: String) -> void:
	if next_command not in [COMMAND_FOLLOW, COMMAND_STAY, COMMAND_ASSIST, COMMAND_FOCUS]:
		return
	command = next_command
	if command == COMMAND_STAY:
		stay_position = global_position
		current_target = null
		_release_target_claims("holding position")
	elif command == COMMAND_FOCUS:
		current_target = null
		target_decision_timer = 0.0
	command_changed.emit(command)


func cycle_command() -> String:
	match command:
		COMMAND_FOLLOW:
			set_command(COMMAND_FOCUS)
		COMMAND_FOCUS:
			set_command(COMMAND_ASSIST)
		COMMAND_ASSIST:
			set_command(COMMAND_STAY)
		_:
			set_command(COMMAND_FOLLOW)
	return command


func _physics_process(delta: float) -> void:
	target_decision_timer = maxf(target_decision_timer - maxf(delta, 0.0), 0.0)
	_update_action_cooldowns(delta)
	if pounce_remaining > 0.0:
		_process_pounce(delta)
		return
	if backstep_remaining > 0.0:
		_process_backstep(delta)
		return
	super._physics_process(delta)


func _refresh_target() -> void:
	if command == COMMAND_STAY:
		current_target = null
		return
	var locked: Node3D = _get_summoner_locked_target()
	if command == COMMAND_FOCUS:
		_set_allocated_target(locked if _valid_enemy(locked) else null, "Grace focus target")
		return
	if command == COMMAND_FOLLOW:
		_set_allocated_target(locked if _valid_enemy(locked) else null, "Rally escort")
		return
	if locked != null and _valid_enemy(locked):
		_set_allocated_target(locked, "Grace focus preference")
		return
	if target_decision_timer > 0.0 and _valid_enemy(current_target):
		return
	var candidates: Array[Dictionary] = _collect_enemy_candidates()
	if candidates.is_empty():
		_set_allocated_target(null, "No valid enemies")
		return
	var contexts: Dictionary = {}
	for candidate: Dictionary in candidates:
		var target_id: int = int(candidate.get("target_id", 0))
		contexts[target_id] = TargetAllocator.get_target_context(
			FAMILIAR_SQUAD_ID,
			target_id,
			get_instance_id()
		)
	var preferred_distance: float = 1.5
	if technique_ids.has("mire_spit"):
		preferred_distance = 5.5
	elif technique_ids.has("pounce"):
		preferred_distance = 2.5
	last_target_plan = TargetEvaluator.choose_best(
		candidates,
		contexts,
		familiar_role,
		{
			"preferred_distance": preferred_distance,
			"distance_span": familiar_target_range,
			"overkill_penalty": 14.0,
			"attention_penalty": 1.5,
		}
	)
	target_evaluation_count += 1
	var selected_value: Variant = last_target_plan.get("selected", {})
	var next_target: Node3D = null
	if selected_value is Dictionary:
		var target_value: Variant = (selected_value as Dictionary).get("target_ref")
		if target_value is Node3D and _valid_enemy(target_value as Node3D):
			next_target = target_value as Node3D
	_set_allocated_target(next_target, str(last_target_plan.get("reason", "Target selected")))
	target_decision_timer = target_decision_interval + float(get_instance_id() % 5) * 0.015


func _collect_enemy_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for node_value: Variant in get_tree().get_nodes_in_group("enemy"):
		if not node_value is Node3D:
			continue
		var target: Node3D = node_value as Node3D
		if not _valid_enemy(target):
			continue
		if global_position.distance_to(target.global_position) > familiar_target_range:
			continue
		var candidate: Dictionary = TargetCandidate.capture(self, target)
		if not candidate.is_empty():
			candidates.append(candidate)
	return candidates


func _set_allocated_target(next_target: Node3D, reason: String) -> void:
	var previous_id: int = current_target.get_instance_id() if _valid_enemy(current_target) else 0
	var next_id: int = next_target.get_instance_id() if _valid_enemy(next_target) else 0
	if previous_id != next_id:
		target_switch_count += 1
	TargetAllocator.release_owner(
		get_instance_id(),
		FAMILIAR_SQUAD_ID,
		"",
		"familiar target changed"
	)
	current_target = next_target
	if _valid_enemy(current_target):
		TargetAllocator.claim_target(
			FAMILIAR_SQUAD_ID,
			get_instance_id(),
			display_name,
			current_target.get_instance_id(),
			str(current_target.name),
			"attention",
			0.0,
			[],
			target_claim_duration,
			0.0,
			{"role": familiar_role, "reason": reason}
		)


func _valid_enemy(candidate: Node3D) -> bool:
	if not is_instance_valid(candidate) or candidate == self:
		return false
	if candidate.is_queued_for_deletion():
		return false
	return not TargetCandidate.is_defeated(candidate)


func _attack_target() -> void:
	if not _valid_enemy(current_target):
		return
	var distance: float = global_position.distance_to(current_target.global_position)
	var technique_id: String = _choose_technique(distance)
	if technique_id == "":
		attack_timer = 0.12
		return
	selected_technique_id = technique_id
	match technique_id:
		"mire_spit":
			_perform_mire_spit()
		"pounce":
			_begin_pounce()
		"backstep":
			_begin_backstep()
		_:
			_perform_contact_technique("bite")


func _choose_technique(distance: float) -> String:
	var candidates: Array[Dictionary] = []
	for technique_id: String in technique_ids:
		if float(action_cooldowns.get(technique_id, 0.0)) > 0.0:
			continue
		var option: Resource = AbilityCatalog.get_option(SPECIES_ID, technique_id)
		if option == null:
			continue
		var minimum: float = float(option.call("get_minimum_start_distance")) if option.has_method("get_minimum_start_distance") else 0.0
		var maximum: float = float(option.call("get_maximum_start_distance")) if option.has_method("get_maximum_start_distance") else attack_range
		if distance < minimum or distance > maximum:
			continue
		var score: float = float(option.call("get_selection_weight")) if option.has_method("get_selection_weight") else 1.0
		match technique_id:
			"mire_spit":
				if familiar_role == "primer":
					score += 6.0
				if distance >= 3.0:
					score += 2.0
			"pounce":
				if familiar_role == "skirmisher":
					score += 3.0
				if familiar_temperament == "bold":
					score += 2.0
			"backstep":
				var health_fraction: float = float(current_health) / float(maxi(maximum_health, 1))
				if familiar_temperament == "cautious":
					score += 2.5
				if health_fraction <= 0.45:
					score += 5.0
				else:
					score -= 2.5
			"bite":
				if distance <= 1.15:
					score += 2.0
		candidates.append({"id": technique_id, "score": score})
	if candidates.is_empty():
		return ""
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_score: float = float(a.get("score", 0.0))
		var b_score: float = float(b.get("score", 0.0))
		if not is_equal_approx(a_score, b_score):
			return a_score > b_score
		return str(a.get("id", "")) < str(b.get("id", ""))
	)
	return str(candidates[0].get("id", ""))


func _perform_contact_technique(technique_id: String) -> void:
	var payload: DamagePayload = _get_runtime_payload(technique_id)
	if payload == null or not _valid_enemy(current_target):
		return
	attack_timer = _get_technique_cooldown(technique_id)
	action_cooldowns[technique_id] = attack_timer
	var result: Dictionary = _send_payload(current_target, payload)
	last_attack_result = str(result.get("message", technique_id.capitalize()))
	attack_performed.emit(current_target, result)
	_spawn_attack_flash(current_target.global_position)
	_claim_action_target(technique_id, payload)


func _begin_pounce() -> void:
	if not _valid_enemy(current_target):
		return
	pounce_target = current_target
	pounce_remaining = pounce_duration
	pounce_hit_registered = false
	attack_timer = _get_technique_cooldown("pounce")
	action_cooldowns["pounce"] = attack_timer
	_claim_action_target("pounce", _get_runtime_payload("pounce"))


func _process_pounce(delta: float) -> void:
	pounce_remaining = maxf(pounce_remaining - delta, 0.0)
	if not _valid_enemy(pounce_target):
		_finish_pounce()
		return
	var direction: Vector3 = pounce_target.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		direction = direction.normalized()
		velocity.x = direction.x * pounce_speed
		velocity.z = direction.z * pounce_speed
		_face_position(pounce_target.global_position, delta)
	if not pounce_hit_registered and global_position.distance_to(pounce_target.global_position) <= 1.05:
		var payload: DamagePayload = _get_runtime_payload("pounce")
		var result: Dictionary = _send_payload(pounce_target, payload)
		last_attack_result = str(result.get("message", "Pounce"))
		attack_performed.emit(pounce_target, result)
		_spawn_attack_flash(pounce_target.global_position)
		pounce_hit_registered = true
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1
	move_and_slide()
	_update_visual()
	if pounce_remaining <= 0.0 or pounce_hit_registered:
		_finish_pounce()


func _finish_pounce() -> void:
	pounce_remaining = 0.0
	pounce_target = null
	pounce_hit_registered = false
	velocity.x = 0.0
	velocity.z = 0.0


func _begin_backstep() -> void:
	if not _valid_enemy(current_target):
		return
	backstep_direction = global_position - current_target.global_position
	backstep_direction.y = 0.0
	if backstep_direction.length_squared() <= 0.001:
		backstep_direction = global_transform.basis.z
	backstep_direction = backstep_direction.normalized()
	backstep_remaining = backstep_duration
	attack_timer = _get_technique_cooldown("backstep")
	action_cooldowns["backstep"] = attack_timer
	_claim_action_target("backstep", null)


func _process_backstep(delta: float) -> void:
	backstep_remaining = maxf(backstep_remaining - delta, 0.0)
	velocity.x = backstep_direction.x * backstep_speed
	velocity.z = backstep_direction.z * backstep_speed
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1
	move_and_slide()
	_update_visual()
	if backstep_remaining <= 0.0:
		velocity.x = 0.0
		velocity.z = 0.0


func _perform_mire_spit() -> void:
	if not _valid_enemy(current_target):
		return
	var action: Resource = AbilityCatalog.get_action(SPECIES_ID, "mire_spit")
	var payload: DamagePayload = _get_runtime_payload("mire_spit")
	if action == null or payload == null:
		return
	var projectile_value: Variant = FamiliarMireProjectileScene.instantiate()
	if not projectile_value is Node3D:
		return
	var projectile: Node3D = projectile_value as Node3D
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		projectile.queue_free()
		return
	scene_root.add_child(projectile)
	var origin: Vector3 = global_position + Vector3.UP * 0.75
	var target_point: Vector3 = current_target.global_position + Vector3.UP * 0.6
	if current_target.has_method("get_targeting_aim_point"):
		var point_value: Variant = current_target.call("get_targeting_aim_point")
		if point_value is Vector3:
			target_point = point_value as Vector3
	var direction: Vector3 = target_point - origin
	if direction.length_squared() <= 0.001:
		direction = -global_transform.basis.z
	projectile.global_position = origin + direction.normalized() * 0.55
	if projectile.has_method("set_source_actor"):
		projectile.call("set_source_actor", self)
	if projectile.has_method("set_payload"):
		projectile.call("set_payload", payload)
	if action.has_method("get_projectile_speed"):
		projectile.set("speed", float(action.call("get_projectile_speed")))
	if projectile.has_method("launch"):
		projectile.call("launch", direction.normalized())
	attack_timer = _get_technique_cooldown("mire_spit")
	action_cooldowns["mire_spit"] = attack_timer
	last_attack_result = "Launched Mire Spit"
	_claim_action_target("mire_spit", payload)


func _get_runtime_payload(technique_id: String) -> DamagePayload:
	var action: Resource = AbilityCatalog.get_action(SPECIES_ID, technique_id)
	if not action is EnemyAttackDefinition:
		return null
	var authored: DamagePayload = (action as EnemyAttackDefinition).get_payload()
	if authored == null:
		return null
	var copy_value: Variant = authored.duplicate(true)
	if not copy_value is DamagePayload:
		return null
	var payload: DamagePayload = copy_value as DamagePayload
	payload.source_name = display_name + " " + technique_id.replace("_", " ").capitalize()
	if not payload.tags.has("summon"):
		payload.tags.append("summon")
	if not payload.tags.has("friendly"):
		payload.tags.append("friendly")
	return payload


func _get_technique_cooldown(technique_id: String) -> float:
	var option: Resource = AbilityCatalog.get_option(SPECIES_ID, technique_id)
	if option != null and option.has_method("get_reuse_cooldown"):
		return maxf(float(option.call("get_reuse_cooldown")), 0.1)
	return attack_interval


func _send_payload(target: Node, payload: DamagePayload) -> Dictionary:
	if target == null or payload == null:
		return {}
	if target.has_method("receive_damage_payload"):
		var value: Variant = target.call("receive_damage_payload", payload)
		return value as Dictionary if value is Dictionary else {}
	var receiver: Node = target.get_node_or_null("PayloadReceiver")
	if receiver == null:
		receiver = target.get_node_or_null("HitReceiver")
	if receiver != null and receiver.has_method("receive_payload"):
		var receiver_value: Variant = receiver.call("receive_payload", payload)
		return receiver_value as Dictionary if receiver_value is Dictionary else {}
	return {}


func _claim_action_target(technique_id: String, payload: DamagePayload) -> void:
	if not _valid_enemy(current_target):
		return
	TargetAllocator.release_owner(
		get_instance_id(),
		FAMILIAR_SQUAD_ID,
		"",
		"familiar action claim replaced"
	)
	var claim_kind: String = "melee"
	var expected_damage: float = 0.0
	var control_tags: Array[String] = []
	if payload != null:
		expected_damage = float(maxi(payload.amount, 0)) + float(maxi(payload.stance_damage, 0)) * 0.45
		if payload.status_effect != "":
			control_tags.append(payload.status_effect)
	if technique_id == "mire_spit":
		claim_kind = "setup"
	elif technique_id == "backstep":
		claim_kind = "attention"
	TargetAllocator.claim_target(
		FAMILIAR_SQUAD_ID,
		get_instance_id(),
		display_name,
		current_target.get_instance_id(),
		str(current_target.name),
		claim_kind,
		expected_damage,
		control_tags,
		target_claim_duration,
		0.0,
		{"technique": technique_id, "role": familiar_role}
	)


func _release_target_claims(reason: String) -> void:
	TargetAllocator.release_owner(
		get_instance_id(),
		FAMILIAR_SQUAD_ID,
		"",
		reason
	)


func _update_action_cooldowns(delta: float) -> void:
	var expired: Array[String] = []
	for key_value: Variant in action_cooldowns.keys():
		var key: String = str(key_value)
		var remaining: float = maxf(float(action_cooldowns.get(key, 0.0)) - delta, 0.0)
		if remaining <= 0.0:
			expired.append(key)
		else:
			action_cooldowns[key] = remaining
	for key: String in expired:
		action_cooldowns.erase(key)


func _refresh_attack_range() -> void:
	attack_range = 1.25
	if technique_ids.has("pounce"):
		attack_range = maxf(attack_range, 3.1)
	if technique_ids.has("mire_spit"):
		attack_range = maxf(attack_range, 10.5)


func _build_body() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.48
	shape.height = 1.2
	collision.shape = shape
	collision.position.y = 0.6
	add_child(collision)
	var visual_value: Variant = GremlinVisualScene.instantiate()
	if visual_value is Node3D:
		visual_root = visual_value as Node3D
		visual_root.name = "GremlinVisual"
		visual_root.scale = Vector3.ONE * 0.9
		add_child(visual_root)
	var label := Label3D.new()
	label.name = "CommandLabel"
	label.position = Vector3(0, 2.0, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 22
	label.pixel_size = 0.006
	label.outline_size = 7
	label.modulate = Color(0.42, 1.0, 0.72)
	add_child(label)


func _update_visual() -> void:
	if visual_root != null:
		visual_root.position.y = sin(elapsed * 4.5) * 0.045
		visual_root.rotation.z = sin(elapsed * 3.2) * 0.025
	var label: Label3D = get_node_or_null("CommandLabel") as Label3D
	if label != null:
		label.text = (
			display_name
			+ "\n" + _command_label()
			+ " • " + familiar_role.to_upper()
			+ " • " + str(current_health) + "/" + str(maximum_health)
		)


func _command_label() -> String:
	match command:
		COMMAND_FOLLOW:
			return "RALLY"
		COMMAND_STAY:
			return "HOLD"
		COMMAND_FOCUS:
			return "FOCUS"
		_:
			return "ASSIST"


func _defeat() -> void:
	_release_target_claims("familiar defeated")
	super._defeat()


func _exit_tree() -> void:
	_release_target_claims("familiar removed")


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["species_id"] = SPECIES_ID
	data["familiar_role"] = familiar_role
	data["temperament"] = familiar_temperament
	data["technique_ids"] = technique_ids.duplicate()
	data["selected_technique"] = selected_technique_id
	data["target_evaluations"] = target_evaluation_count
	data["target_switches"] = target_switch_count
	data["target_plan"] = last_target_plan.duplicate(true)
	data["pouncing"] = pounce_remaining > 0.0
	data["backstepping"] = backstep_remaining > 0.0
	return data


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var text: String = str(raw)
			if text != "" and not result.has(text):
				result.append(text)
	return result
