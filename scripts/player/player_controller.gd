extends CharacterBody3D

@export var move_speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var gravity: float = 18.0
@export var mouse_sensitivity: float = 0.0025
@export var spell_mana_cost: int = 1

@onready var camera_pivot: Node3D = $CameraPivot
@onready var interaction_area: Area3D = $InteractionArea
@onready var ability_caster: Node3D = $AbilityCaster
@onready var spell_label: Label = $SpellLabel

var dodge_controller: PlayerDodgeController

var camera_pitch: float = deg_to_rad(-15.0)
var min_pitch: float = deg_to_rad(-60.0)
var max_pitch: float = deg_to_rad(25.0)

var nearby_interactables: Array[Area3D] = []
var current_interactable: Area3D = null

var is_defeated: bool = false

func _ready() -> void:
	dodge_controller = find_dodge_controller()
	print("Player found dodge controller: ", dodge_controller.get_path() if dodge_controller != null else "none")

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera_pivot.rotation.x = camera_pitch

	interaction_area.area_entered.connect(_on_interaction_area_entered)
	interaction_area.area_exited.connect(_on_interaction_area_exited)
	GameState.player_defeated.connect(_on_player_defeated)

func _unhandled_input(event: InputEvent) -> void:
	if is_defeated:
		if event.is_action_pressed("restart_scene"):
			GameState.reset_run()
			get_tree().reload_current_scene()
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)

		camera_pitch -= event.relative.y * mouse_sensitivity
		camera_pitch = clamp(camera_pitch, min_pitch, max_pitch)
		camera_pivot.rotation.x = camera_pitch

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event.is_action_pressed("interact"):
		interact_with_current()
		
	if event.is_action_pressed("ability_slot_1"):
		ability_caster.select_ability(0)

	if event.is_action_pressed("ability_slot_2"):
		ability_caster.select_ability(1)
		
	if event.is_action_pressed("ability_slot_3"):
		ability_caster.select_ability(2)
		
	if event.is_action_pressed("ability_slot_4"):
		ability_caster.select_ability(3)
		
	if event.is_action_pressed("ability_slot_5"):
		ability_caster.select_ability(4)
		
	if event.is_action_pressed("ability_slot_6"):
		ability_caster.select_ability(5)
		
	if event.is_action_pressed("ability_slot_7"):
		ability_caster.select_ability(6)
		
	if event.is_action_pressed("ability_slot_8"):
		ability_caster.select_ability(7)
		
	if event.is_action_pressed("ability_slot_9"):
		ability_caster.select_ability(8)
		
	if event.is_action_pressed("ability_slot_0"):
		ability_caster.select_ability(9)
		
	if event.is_action_pressed("next_ability"):
		ability_caster.select_next_ability()

	if event.is_action_pressed("cast_spell"):
		ability_caster.cast_from_player(self)

func _physics_process(delta: float) -> void:
	if dodge_controller != null and dodge_controller.is_dodge_active():
		var dodge_velocity: Vector3 = dodge_controller.get_dodge_velocity()

		velocity.x = dodge_velocity.x
		velocity.z = dodge_velocity.z

		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			if velocity.y < 0.0:
				velocity.y = -0.1

		move_and_slide()
		return
	if is_defeated:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	var input_vector := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)

	var direction := Vector3.ZERO

	if input_vector.length() > 0.0:
		direction = (
			global_transform.basis.x * input_vector.x
			+ global_transform.basis.z * input_vector.y
		)
		direction.y = 0.0
		direction = direction.normalized()

	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity

	move_and_slide()

func _on_interaction_area_entered(area: Area3D) -> void:
	print("Area entered: ", area.name)

	if area.has_method("interact"):
		print("Interactable detected: ", area.name)
		nearby_interactables.append(area)
		current_interactable = area
		update_interaction_prompt()
	else:
		print("Area does not have interact(): ", area.name)

func _on_interaction_area_exited(area: Area3D) -> void:
	print("Area exited: ", area.name)

	if nearby_interactables.has(area):
		nearby_interactables.erase(area)

	if current_interactable == area:
		current_interactable = nearby_interactables.back() if nearby_interactables.size() > 0 else null

	update_interaction_prompt()

func update_interaction_prompt() -> void:
	var game_ui := get_game_ui()

	if game_ui == null:
		return

	if current_interactable == null:
		game_ui.hide_prompt()
		return

	var prompt := "Interact"

	if "prompt_text" in current_interactable:
		prompt = current_interactable.prompt_text

	game_ui.show_prompt(prompt)

func interact_with_current() -> void:
	print("Pressed interact.")

	if current_interactable == null:
		print("No current interactable.")
		return

	print("Interacting with: ", current_interactable.name)

	var interaction_result: Dictionary = current_interactable.interact()
	print("Interaction result: ", interaction_result)

	var ui: Node = get_game_ui()

	if ui == null:
		print("No game UI found.")
		return

	if interaction_result.has("message"):
		ui.show_message(interaction_result["message"])

	if interaction_result.has("objective") and interaction_result["objective"] != "":
		ui.set_objective(interaction_result["objective"])

	if interaction_result.has("show_prologue_choice") and interaction_result["show_prologue_choice"]:
		ui.show_prologue_choice()

func get_game_ui() -> Node:
	return get_tree().get_first_node_in_group("game_ui")
	
	var spent_mana: bool = GameState.spend_mana(spell_mana_cost)

	if not spent_mana:
		print("Not enough mana.")
		return

	var camera: Camera3D = get_viewport().get_camera_3d()
	var cast_direction: Vector3 = -global_transform.basis.z

	if camera != null:
		cast_direction = -camera.global_transform.basis.z

	print("Cast Arcane Spark. Mana: ", GameState.get_stat("mana"), " / ", GameState.get_stat("max_mana"))

func set_spell_label(ability_name: String) -> void:
	spell_label.text = "Spell: " + ability_name

func _on_player_defeated() -> void:
	is_defeated = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func find_dodge_controller() -> PlayerDodgeController:
	var direct_node: Node = get_node_or_null("DodgeController")

	if direct_node is PlayerDodgeController:
		return direct_node as PlayerDodgeController

	for child: Node in get_children():
		if child is PlayerDodgeController:
			return child as PlayerDodgeController

	return null
