extends Node

const ConversationNPCScript = preload("res://scripts/dialogue/conversation_npc.gd")


func _ready() -> void:
	var npc := Area3D.new()
	npc.name = "ConversationSmokeNPC"
	npc.set_script(ConversationNPCScript)
	npc.set("display_name", "Test Traveler")
	add_child(npc)
	npc.call("configure", {
		"entry": "start",
		"resolved_flag": "conversation_smoke_resolved",
		"repeat_entry": "repeat",
		"nodes": {
			"start": {
				"speaker": "Test Traveler",
				"text": "Conversation system loaded.",
				"choices": [
					{"id": "finish", "text": "Finish", "set_flag": "conversation_smoke_resolved"},
				],
			},
			"repeat": {
				"speaker": "Test Traveler",
				"text": "Persistent branch loaded.",
			},
		},
	})
	assert(npc.is_in_group("interactable_target"))
	assert(npc.has_method("interact"))
	assert(npc.has_method("begin_conversation"))
	assert(npc.get("conversation_data") is Dictionary)
	var nodes: Dictionary = (npc.get("conversation_data") as Dictionary).get("nodes", {})
	assert(nodes.has("start"))
	assert(nodes.has("repeat"))
	print("PASS: Conversation NPC contract and branching data loaded.")
