extends Resource
class_name WeaponMovesetDefinition

@export var moveset_id: String = "moveset"
@export var display_name: String = "Moveset"
@export var entry_light_attack_id: String = ""
@export var entry_heavy_attack_id: String = ""
@export var attacks: Array[WeaponAttackDefinition] = []


func get_entry_attack(input_kind: String) -> WeaponAttackDefinition:
	if input_kind == "heavy":
		return get_attack(entry_heavy_attack_id)
	return get_attack(entry_light_attack_id)


func get_attack(attack_id: String) -> WeaponAttackDefinition:
	if attack_id == "":
		return null

	for attack: WeaponAttackDefinition in attacks:
		if attack == null:
			continue
		if attack.attack_id == attack_id:
			return attack

	return null


func get_follow_up(current_attack: WeaponAttackDefinition, input_kind: String) -> WeaponAttackDefinition:
	if current_attack == null:
		return get_entry_attack(input_kind)

	return get_attack(current_attack.get_next_attack_id(input_kind))


func get_attack_ids() -> Array[String]:
	var ids: Array[String] = []

	for attack: WeaponAttackDefinition in attacks:
		if attack == null or attack.attack_id == "":
			continue
		if not ids.has(attack.attack_id):
			ids.append(attack.attack_id)

	return ids


func validate_graph() -> Array[String]:
	var errors: Array[String] = []
	var ids: Array[String] = []

	for attack: WeaponAttackDefinition in attacks:
		if attack == null:
			errors.append("Moveset contains a null attack.")
			continue
		if attack.attack_id == "":
			errors.append("Moveset contains an attack with an empty id.")
			continue
		if ids.has(attack.attack_id):
			errors.append("Duplicate attack id: " + attack.attack_id)
		else:
			ids.append(attack.attack_id)

	if entry_light_attack_id == "" or not ids.has(entry_light_attack_id):
		errors.append("Missing valid light entry attack: " + entry_light_attack_id)

	if entry_heavy_attack_id == "" or not ids.has(entry_heavy_attack_id):
		errors.append("Missing valid heavy entry attack: " + entry_heavy_attack_id)

	for attack: WeaponAttackDefinition in attacks:
		if attack == null:
			continue
		for linked_id: String in [attack.next_light_attack_id, attack.next_heavy_attack_id]:
			if linked_id != "" and not ids.has(linked_id):
				errors.append(attack.attack_id + " links to missing attack: " + linked_id)

	return errors


func get_debug_rows() -> Array[String]:
	var rows: Array[String] = []

	for attack: WeaponAttackDefinition in attacks:
		if attack != null:
			rows.append(attack.get_debug_summary())

	return rows
