extends RefCounted

# Prototype spell modifier registry.
#
# This is intentionally data-driven but still small enough to inspect quickly.
# It gives prototype upgrades one place to declare:
# spell_id + unlock_id -> payload changes + projectile runtime changes + on-hit effects.

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")

const MODIFIER_DEFS: Dictionary = {
	"charged_firebolt": {
		"id": "charged_firebolt",
		"display_name": "Charged Firebolt",
		"unlock_id": "charged_firebolt",
		"spell_id": "firebolt",
		"behavior": "charge",
		"notes": "Charge timing still lives in AbilityCaster because it needs hold/release input state.",
		"payload_match_tags": ["charged", "firebolt"],
		"projectile": {
			"impact_style": "charged_firebolt",
		},
	},
	"piercing_ice_lance": {
		"id": "piercing_ice_lance",
		"display_name": "Piercing Ice Lance",
		"unlock_id": "piercing_ice_lance",
		"spell_id": "ice_lance",
		"behavior": "payload_projectile_modifier",
		"cast_message": "Piercing Ice Lance.",
		"cast_lock_duration": 0.18,
		"extra_mana_cost": 0,
		"payload": {
			"source_name": "Piercing Ice Lance",
			"min_amount": 2,
			"stance_bonus": 1,
			"min_stance_damage": 5,
			"status_duration_multiplier": 1.15,
			"tags_to_add": ["piercing", "upgrade", "ice_lance", "piercing_ice_lance"],
		},
		"payload_match_tags": ["piercing", "ice_lance"],
		"projectile": {
			"destroy_on_hit": true,
			"hit_limit": 4,
			"min_speed": 24.0,
			"min_lifetime": 3.05,
			"trail_interval": 0.028,
			"impact_radius": 1.18,
		},
	},
	"chain_lightning": {
		"id": "chain_lightning",
		"display_name": "Chain Lightning",
		"unlock_id": "chain_lightning",
		"spell_id": "lightning_spark",
		"behavior": "payload_projectile_on_hit_modifier",
		"cast_message": "Chain Lightning.",
		"cast_lock_duration": 0.18,
		"extra_mana_cost": 0,
		"payload": {
			"source_name": "Chain Lightning",
			"stance_bonus": 1,
			"min_stance_damage": 3,
			"status_duration_multiplier": 1.15,
			"tags_to_add": ["chain_lightning", "chain", "upgrade", "lightning_spark"],
		},
		"payload_match_tags": ["chain_lightning", "lightning_spark"],
		"projectile": {
			"min_speed": 26.0,
			"min_lifetime": 2.85,
			"trail_interval": 0.026,
			"impact_radius": 1.08,
		},
		"on_hit": {
			"effect": "chain_lightning",
			"max_jumps": 2,
			"radius": 5.5,
			"damage_multiplier": 0.75,
			"stance_multiplier": 0.70,
			"status_duration_multiplier": 0.85,
			"arc_duration": 0.18,
			"arc_thickness": 0.08,
		},
	},
}


static func get_modifier_definitions() -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []

	for modifier_id: String in MODIFIER_DEFS.keys():
		definitions.append(get_modifier_definition(modifier_id))

	return definitions


static func get_modifier_definition(modifier_id: String) -> Dictionary:
	if MODIFIER_DEFS.has(modifier_id):
		var definition: Dictionary = MODIFIER_DEFS[modifier_id] as Dictionary
		return definition.duplicate(true)

	return {}


static func get_active_modifier_definitions_for_ability(ability: Resource) -> Array[Dictionary]:
	var active_definitions: Array[Dictionary] = []
	var spell_id: String = get_ability_spell_id(ability)

	if spell_id == "":
		return active_definitions

	for definition: Dictionary in get_modifier_definitions():
		if str(definition.get("spell_id", "")) != spell_id:
			continue

		if not is_modifier_unlocked(definition):
			continue

		active_definitions.append(definition)

	return active_definitions


static func get_active_payload_modifier_definitions_for_ability(ability: Resource) -> Array[Dictionary]:
	var payload_definitions: Array[Dictionary] = []

	for definition: Dictionary in get_active_modifier_definitions_for_ability(ability):
		if not definition.has("payload"):
			continue

		payload_definitions.append(definition)

	return payload_definitions


static func has_active_payload_modifier_for_ability(ability: Resource) -> bool:
	return get_active_payload_modifier_definitions_for_ability(ability).size() > 0


static func build_modified_payload_for_ability(ability: Resource) -> Resource:
	var payload_definitions: Array[Dictionary] = get_active_payload_modifier_definitions_for_ability(ability)

	if payload_definitions.size() <= 0:
		return null

	var base_payload: Resource = get_ability_payload(ability)

	if not (base_payload is DamagePayload):
		return base_payload

	var duplicate_payload: Resource = base_payload.duplicate(true)

	if not (duplicate_payload is DamagePayload):
		return base_payload

	var modified_payload: DamagePayload = duplicate_payload as DamagePayload

	for definition: Dictionary in payload_definitions:
		apply_payload_modifier(modified_payload, definition)

	return modified_payload


static func get_cast_extra_mana_cost_for_ability(ability: Resource) -> int:
	var extra_cost: int = 0

	for definition: Dictionary in get_active_payload_modifier_definitions_for_ability(ability):
		extra_cost += int(definition.get("extra_mana_cost", 0))

	return extra_cost


static func get_cast_lock_duration_for_ability(ability: Resource, fallback_duration: float) -> float:
	var resolved_duration: float = fallback_duration

	for definition: Dictionary in get_active_payload_modifier_definitions_for_ability(ability):
		if definition.has("cast_lock_duration"):
			resolved_duration = max(resolved_duration, float(definition.get("cast_lock_duration", resolved_duration)))

	return resolved_duration


static func get_cast_message_for_ability(ability: Resource) -> String:
	var messages: Array[String] = []

	for definition: Dictionary in get_active_payload_modifier_definitions_for_ability(ability):
		var cast_message: String = str(definition.get("cast_message", ""))
		if cast_message != "":
			messages.append(cast_message)

	if messages.size() <= 0:
		return ""

	return " ".join(messages)


static func get_projectile_modifiers_for_payload(active_payload: DamagePayload) -> Array[Dictionary]:
	var projectile_modifiers: Array[Dictionary] = []

	if active_payload == null:
		return projectile_modifiers

	for definition: Dictionary in get_modifier_definitions():
		if not definition.has("projectile"):
			continue

		if not payload_matches_modifier(active_payload, definition):
			continue

		var projectile_modifier: Dictionary = (definition["projectile"] as Dictionary).duplicate(true)
		projectile_modifier["id"] = str(definition.get("id", ""))
		projectile_modifier["display_name"] = str(definition.get("display_name", projectile_modifier["id"]))
		projectile_modifiers.append(projectile_modifier)

	return projectile_modifiers


static func get_on_hit_modifiers_for_payload(active_payload: DamagePayload) -> Array[Dictionary]:
	var on_hit_modifiers: Array[Dictionary] = []

	if active_payload == null:
		return on_hit_modifiers

	for definition: Dictionary in get_modifier_definitions():
		if not definition.has("on_hit"):
			continue

		if not payload_matches_modifier(active_payload, definition):
			continue

		var on_hit_modifier: Dictionary = (definition["on_hit"] as Dictionary).duplicate(true)
		on_hit_modifier["id"] = str(definition.get("id", ""))
		on_hit_modifier["display_name"] = str(definition.get("display_name", on_hit_modifier["id"]))
		on_hit_modifiers.append(on_hit_modifier)

	return on_hit_modifiers


static func apply_on_hit_effects(
	source_node: Node,
	primary_target: Node,
	active_payload: DamagePayload,
	impact_position: Vector3,
	impact_direction: Vector3,
	used_target_ids: Dictionary
) -> Array[String]:
	var messages: Array[String] = []

	if source_node == null or active_payload == null:
		return messages

	for modifier: Dictionary in get_on_hit_modifiers_for_payload(active_payload):
		var effect_name: String = str(modifier.get("effect", ""))

		match effect_name:
			"chain_lightning":
				messages.append_array(apply_chain_lightning_on_hit(source_node, primary_target, active_payload, impact_position, modifier, used_target_ids))

	return messages


static func apply_chain_lightning_on_hit(
	source_node: Node,
	primary_target: Node,
	active_payload: DamagePayload,
	impact_position: Vector3,
	on_hit_rules: Dictionary,
	used_target_ids: Dictionary
) -> Array[String]:
	var messages: Array[String] = []

	if source_node == null or source_node.get_tree() == null:
		return messages

	var tree: SceneTree = source_node.get_tree()
	var max_jumps: int = max(int(on_hit_rules.get("max_jumps", 0)), 0)
	var radius: float = max(float(on_hit_rules.get("radius", 0.0)), 0.0)

	if max_jumps <= 0 or radius <= 0.0:
		return messages

	if primary_target != null:
		used_target_ids[primary_target.get_instance_id()] = true

	var current_position: Vector3 = get_target_position(primary_target, impact_position)
	var chain_payload: DamagePayload = make_chain_jump_payload(active_payload, on_hit_rules)

	for jump_index: int in range(max_jumps):
		var next_target: Node = find_nearest_chain_target(tree, current_position, radius, used_target_ids)

		if next_target == null:
			break

		used_target_ids[next_target.get_instance_id()] = true
		var next_position: Vector3 = get_target_position(next_target, current_position)
		spawn_lightning_arc(tree, current_position, next_position, on_hit_rules)
		ElementVisuals.spawn_impact(tree, next_position, "lightning", 0.95)

		var result: Dictionary = send_payload_to_target(source_node, next_target, chain_payload)
		if result.has("message") and str(result["message"]) != "":
			messages.append(str(result["message"]))

		current_position = next_position

	return messages


static func find_nearest_chain_target(tree: SceneTree, origin: Vector3, radius: float, used_target_ids: Dictionary) -> Node:
	if tree == null:
		return null

	var best_target: Node = null
	var best_distance: float = INF

	for candidate_node: Node in tree.get_nodes_in_group("enemy"):
		var target: Node = resolve_payload_target(candidate_node)

		if target == null:
			continue

		var target_id: int = target.get_instance_id()
		if used_target_ids.has(target_id):
			continue

		if is_target_defeated(target):
			continue

		var target_position: Vector3 = get_target_position(target, origin)
		var distance: float = origin.distance_to(target_position)

		if distance > radius:
			continue

		if distance < best_distance:
			best_distance = distance
			best_target = target

	return best_target


static func resolve_payload_target(start_node: Node) -> Node:
	var current: Node = start_node

	while current != null:
		if is_payload_target(current):
			return current

		var child_target: Node = find_payload_target_in_children(current)
		if child_target != null:
			return child_target

		current = current.get_parent()

	return null


static func find_payload_target_in_children(node: Node) -> Node:
	if node == null:
		return null

	for child: Node in node.get_children():
		if is_payload_target(child):
			return child

		var nested_target: Node = find_payload_target_in_children(child)
		if nested_target != null:
			return nested_target

	return null


static func is_payload_target(node: Node) -> bool:
	if node == null:
		return false

	if node.get_node_or_null("PayloadReceiver") != null:
		return true

	if node.get_node_or_null("HitReceiver") != null:
		return true

	if node.has_method("receive_damage_payload"):
		return true

	if node.has_method("receive_magic_hit"):
		return true

	return false


static func is_target_defeated(target: Node) -> bool:
	if target == null:
		return true

	var hit_receiver: Node = target.get_node_or_null("HitReceiver")

	if hit_receiver == null:
		return false

	var current_health: Variant = hit_receiver.get("current_health")

	if current_health != null and int(current_health) <= 0:
		return true

	return false


static func get_target_position(target: Node, fallback_position: Vector3) -> Vector3:
	var target_3d: Node3D = get_target_node_3d(target)

	if target_3d == null:
		return fallback_position

	return target_3d.global_position + Vector3.UP * 0.95


static func get_target_node_3d(target: Node) -> Node3D:
	if target == null:
		return null

	if target is Node3D:
		return target as Node3D

	var parent: Node = target.get_parent()
	if parent is Node3D:
		return parent as Node3D

	return null


static func make_chain_jump_payload(active_payload: DamagePayload, on_hit_rules: Dictionary) -> DamagePayload:
	var duplicate_payload: Resource = active_payload.duplicate(true)
	var chain_payload: DamagePayload = active_payload

	if duplicate_payload is DamagePayload:
		chain_payload = duplicate_payload as DamagePayload

	var damage_multiplier: float = float(on_hit_rules.get("damage_multiplier", 1.0))
	var stance_multiplier: float = float(on_hit_rules.get("stance_multiplier", 1.0))
	var status_duration_multiplier: float = float(on_hit_rules.get("status_duration_multiplier", 1.0))

	chain_payload.amount = max(1, int(round(float(chain_payload.amount) * damage_multiplier)))
	chain_payload.stance_damage = max(1, int(round(float(chain_payload.stance_damage) * stance_multiplier)))
	chain_payload.status_duration *= status_duration_multiplier
	chain_payload.source_name = "Chain Lightning Arc"
	append_payload_tags(chain_payload, ["chain_jump", "secondary_hit"])
	return chain_payload


static func send_payload_to_target(source_node: Node, target: Node, damage_payload: DamagePayload) -> Dictionary:
	if source_node != null and source_node.has_method("send_payload_to_target"):
		var result_variant: Variant = source_node.call("send_payload_to_target", target, damage_payload)
		if result_variant is Dictionary:
			return result_variant as Dictionary

	var payload_receiver: Node = target.get_node_or_null("PayloadReceiver")

	if payload_receiver != null and payload_receiver.has_method("receive_payload"):
		return payload_receiver.receive_payload(damage_payload)

	if target.has_method("receive_damage_payload"):
		return target.receive_damage_payload(damage_payload)

	var hit_receiver: Node = target.get_node_or_null("HitReceiver")

	if hit_receiver != null:
		if hit_receiver.has_method("receive_payload"):
			return hit_receiver.receive_payload(damage_payload)
		if hit_receiver.has_method("receive_hit"):
			return hit_receiver.receive_hit(damage_payload.amount)

	if target.has_method("receive_magic_hit"):
		return target.receive_magic_hit(damage_payload.amount)

	return {
		"message": damage_payload.source_name + " arcs into " + target.name + ", but nothing receives it.",
		"objective": "",
	}


static func spawn_lightning_arc(tree: SceneTree, start_position: Vector3, end_position: Vector3, on_hit_rules: Dictionary) -> void:
	if tree == null or tree.current_scene == null:
		return

	var distance: float = start_position.distance_to(end_position)
	if distance <= 0.01:
		return

	var thickness: float = max(float(on_hit_rules.get("arc_thickness", 0.08)), 0.02)
	var duration: float = max(float(on_hit_rules.get("arc_duration", 0.18)), 0.05)
	var arc: MeshInstance3D = MeshInstance3D.new()
	arc.name = "ChainLightningArc"
	arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(thickness, thickness, distance)
	arc.mesh = mesh

	var material: StandardMaterial3D = make_lightning_arc_material(0.9)
	arc.material_override = material
	tree.current_scene.add_child(arc)
	arc.global_position = (start_position + end_position) * 0.5
	arc.look_at(end_position, Vector3.UP)

	var tween: Tween = arc.create_tween()
	tween.set_parallel(true)
	tween.tween_property(material, "albedo_color", Color(0.45, 0.9, 1.0, 0.0), duration)
	tween.tween_property(arc, "scale", Vector3(1.0, 1.0, 0.12), duration)
	tween.set_parallel(false)
	tween.tween_callback(Callable(arc, "queue_free"))


static func make_lightning_arc_material(alpha: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.92, 1.0, alpha)
	material.emission_enabled = true
	material.emission = Color(0.45, 0.9, 1.0, 1.0)
	material.emission_energy_multiplier = 3.2
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


static func payload_matches_modifier(active_payload: DamagePayload, definition: Dictionary) -> bool:
	if active_payload == null:
		return false

	var required_tags_variant: Variant = definition.get("payload_match_tags", [])

	if not (required_tags_variant is Array):
		return false

	for required_tag_variant: Variant in required_tags_variant:
		var required_tag: String = str(required_tag_variant)
		if required_tag == "":
			continue

		if not payload_has_tag(active_payload, required_tag):
			return false

	return true


static func apply_payload_modifier(payload: DamagePayload, definition: Dictionary) -> void:
	if payload == null:
		return

	var payload_rules_variant: Variant = definition.get("payload", {})

	if not (payload_rules_variant is Dictionary):
		return

	var payload_rules: Dictionary = payload_rules_variant as Dictionary

	if payload_rules.has("source_name"):
		payload.source_name = str(payload_rules.get("source_name", payload.source_name))

	if payload_rules.has("amount_bonus"):
		payload.amount += int(payload_rules.get("amount_bonus", 0))

	if payload_rules.has("min_amount"):
		payload.amount = max(payload.amount, int(payload_rules.get("min_amount", payload.amount)))

	if payload_rules.has("stance_bonus"):
		payload.stance_damage += int(payload_rules.get("stance_bonus", 0))

	if payload_rules.has("min_stance_damage"):
		payload.stance_damage = max(payload.stance_damage, int(payload_rules.get("min_stance_damage", payload.stance_damage)))

	if payload_rules.has("status_duration_multiplier"):
		payload.status_duration *= float(payload_rules.get("status_duration_multiplier", 1.0))

	if payload_rules.has("tags_to_add"):
		append_payload_tags(payload, payload_rules.get("tags_to_add", []))


static func append_payload_tags(payload: DamagePayload, tags_to_add_variant: Variant) -> void:
	if payload == null:
		return

	if not (tags_to_add_variant is Array):
		return

	var next_tags: Array[String] = []

	for existing_tag_variant: Variant in payload.tags:
		var existing_tag: String = str(existing_tag_variant)
		if existing_tag == "":
			continue
		if next_tags.has(existing_tag):
			continue
		next_tags.append(existing_tag)

	for tag_variant: Variant in tags_to_add_variant:
		var tag: String = str(tag_variant)
		if tag == "":
			continue
		if next_tags.has(tag):
			continue
		next_tags.append(tag)

	payload.tags = next_tags


static func get_ability_spell_id(ability: Resource) -> String:
	if ability == null:
		return ""

	if ability.has_method("get_spell_id"):
		return str(ability.call("get_spell_id"))

	var spell_id_value: Variant = ability.get("spell_id")
	if spell_id_value != null and str(spell_id_value) != "":
		return str(spell_id_value)

	var display_name_value: Variant = ability.get("display_name")
	if display_name_value != null:
		return str(display_name_value).to_lower().replace(" ", "_")

	return ""


static func get_ability_payload(ability: Resource) -> Resource:
	if ability == null:
		return null

	if ability.has_method("get_action_payload"):
		var method_payload: Variant = ability.call("get_action_payload")
		if method_payload is Resource:
			return method_payload as Resource

	var action_payload: Variant = ability.get("action_payload")
	if action_payload is Resource:
		return action_payload as Resource

	var legacy_payload: Variant = ability.get("payload")
	if legacy_payload is Resource:
		return legacy_payload as Resource

	return null


static func is_modifier_unlocked(definition: Dictionary) -> bool:
	var unlock_id: String = str(definition.get("unlock_id", ""))

	if unlock_id == "":
		return false

	if not GameState.has_method("has_unlock"):
		return false

	return GameState.has_unlock(unlock_id)


static func payload_has_tag(active_payload: DamagePayload, tag_name: String) -> bool:
	if active_payload == null:
		return false

	var normalized_tag_name: String = tag_name.to_lower()

	for tag_variant: Variant in active_payload.tags:
		if str(tag_variant).to_lower() == normalized_tag_name:
			return true

	return false
