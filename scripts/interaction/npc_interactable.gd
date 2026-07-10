extends Area3D

@export var prompt_text: String = "Talk"
@export var speaker_name: String = "NPC"

@export_multiline var line_1: String = "Hello."
@export_multiline var line_2: String = "This is a reusable NPC."
@export_multiline var line_3: String = "The dialogue system is working."

@export var objective_after: String = ""

var current_line: int = 0
var has_shown_choice: bool = false
@export var shows_prologue_choice: bool = false


func interact() -> Dictionary:
	var lines: Array[String] = [line_1, line_2, line_3]
	var message: String = speaker_name + ": " + lines[current_line]
	var objective: String = ""
	var show_choice: bool = false

	if current_line >= lines.size() - 1:
		objective = objective_after

		if shows_prologue_choice and not has_shown_choice:
			show_choice = true
			has_shown_choice = true
	else:
		current_line += 1

	return {
		"message": message,
		"objective": objective,
		"show_prologue_choice": show_choice,
	}

func receive_magic_hit(power: int = 1) -> Dictionary:
	var hit_receiver: Node = get_node_or_null("HitReceiver")

	if hit_receiver == null:
		return {
			"message": "Arcane Spark flickers near " + speaker_name + ", but nothing happens.",
			"objective": ""
		}

	return hit_receiver.receive_hit(power)
