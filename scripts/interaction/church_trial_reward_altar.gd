extends Area3D

@export var prompt_text: String = "Claim Trial Sigil"
@export var reward_id: String = "church_trial_sigil"
@export var reward_display_name: String = "Church Trial Sigil"
@export var reward_kind: String = "Trial Relic"
@export_multiline var reward_description: String = "Proof that Grace survived the Church's trial and defeated the Animated Armor."
@export var reward_source: String = "First Church Trial"
@export_multiline var lore_message: String = "The sigil is warm, not with fire, but with judgment remembered. It marks Grace as one who passed the Church's first trial."
@export var completion_flag_name: String = "completed_church_trial"
@export var claimed_flag_name: String = "claimed_church_trial_sigil"
@export var objective_after: String = "Church Trial complete. Carry the sigil forward."
@export var save_position_offset: Vector3 = Vector3(0.0, 1.0, -1.25)
@export var restore_resources_on_claim: bool = true
@export var autosave_on_claim: bool = true
@export var sigil_visual_path: NodePath = NodePath("SigilVisual")
@export var claimed_marker_path: NodePath = NodePath("ClaimedGlow")

var claimed: bool = false

@onready var sigil_visual: Node3D = get_node_or_null(sigil_visual_path)
@onready var claimed_marker: Node3D = get_node_or_null(claimed_marker_path)


func _ready() -> void:
	add_to_group("reward")
	add_to_group("debuggable")
	claimed = GameState.get_flag(claimed_flag_name) or GameState.has_key_item(reward_id)

	if claimed and not GameState.has_key_item(reward_id):
		grant_key_item_only()

	refresh_visual_state()


func interact() -> Dictionary:
	if claimed or GameState.get_flag(claimed_flag_name) or GameState.has_key_item(reward_id):
		claimed = true
		refresh_visual_state()
		return {
			"message": reward_display_name + " already rests with Grace.",
			"objective": objective_after,
		}

	claimed = true
	GameState.set_flag(completion_flag_name, true)
	GameState.set_flag(claimed_flag_name, true)
	grant_key_item_only()

	if restore_resources_on_claim and GameState.has_method("restore_rest_resources"):
		GameState.restore_rest_resources()

	GameState.set_objective(objective_after)
	var save_message: String = ""

	if autosave_on_claim:
		var save_position: Vector3 = global_position + save_position_offset
		var save_result: Dictionary = GameState.save_at_bed(
			"victory_" + reward_id,
			reward_display_name + " Altar",
			save_position
		)

		if bool(save_result.get("ok", false)):
			save_message = " Progress saved."
		else:
			save_message = " Save failed: " + str(save_result.get("message", "Unknown save error."))

	refresh_visual_state()

	return {
		"message": "Grace claims the " + reward_display_name + ". " + lore_message + save_message,
		"objective": objective_after,
	}


func grant_key_item_only() -> void:
	if not GameState.has_method("add_key_item"):
		return

	GameState.add_key_item(reward_id, {
		"name": reward_display_name,
		"kind": reward_kind,
		"description": reward_description,
		"source": reward_source,
	})


func refresh_visual_state() -> void:
	if sigil_visual != null:
		sigil_visual.visible = not claimed

	if claimed_marker != null:
		claimed_marker.visible = claimed

	if claimed:
		prompt_text = "Trial Sigil Claimed"
	else:
		prompt_text = "Claim Trial Sigil"


func get_debug_data() -> Dictionary:
	return {
		"reward_id": reward_id,
		"claimed": claimed,
		"has_key_item": GameState.has_key_item(reward_id) if GameState.has_method("has_key_item") else false,
		"completion_flag": GameState.get_flag(completion_flag_name),
		"claimed_flag": GameState.get_flag(claimed_flag_name),
	}
