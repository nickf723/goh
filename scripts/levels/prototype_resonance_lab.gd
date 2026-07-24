extends Node3D
class_name PrototypeResonanceLab

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")
const LabLoadout: AbilityLoadout = preload(
	"res://data/loadouts/grace_resonance_lab_loadout.tres"
)

const LAB_FREQUENCIES: Array[float] = [
	110.0,
	220.0,
	440.0,
	660.0,
]

@export var enable_editor_f8_reset: bool = true
@export_range(0.03, 0.5, 0.01) var readout_refresh_interval: float = 0.08

@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
@onready var readout: Label = get_node_or_null(
	"ResonanceHUD/Panel/Margin/Readout"
) as Label

var resonant_bodies: Array[ResonantBody3D] = []
var frequency_index: int = 1
var runtime_payload: ResonancePayload = null
var active_frequency_label: Label3D = null
var gate_resonator: ResonantBody3D = null
var gate_body: AnimatableBody3D = null
var gate_closed_position: Vector3 = Vector3.ZERO
var gate_opened: bool = false
var glass_shards: Array[RigidBody3D] = []
var fractured_shards: int = 0
var primary_fork: ResonantBody3D = null
var sympathetic_fork: ResonantBody3D = null
var readout_timer: float = 0.0
var stat_snapshot: Dictionary = {}


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("resonance_lab")
	add_to_group("debuggable")
	stat_snapshot = GameState.get_stat_snapshot()
	build_laboratory()
	configure_player()
	GameState.set_objective(
		"Tune Resonant Pulse to excite materials, transfer vibration, open the gate, and fracture glass."
	)
	show_message(
		"Resonance Laboratory online. Interact cycles frequency; Cast releases Resonant Pulse."
	)
	refresh_readout()


func _process(delta: float) -> void:
	readout_timer -= delta
	if readout_timer <= 0.0:
		readout_timer = maxf(readout_refresh_interval, 0.03)
		refresh_readout()


func _exit_tree() -> void:
	for stat_name: Variant in stat_snapshot.keys():
		GameState.set_stat(str(stat_name), int(stat_snapshot[stat_name]))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		cycle_frequency()
		return
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if (
		key_event.pressed
		and not key_event.echo
		and key_event.physical_keycode == KEY_F8
		and enable_editor_f8_reset
		and OS.has_feature("editor")
	):
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()


func configure_player() -> void:
	if player == null:
		return
	var ability_caster: Node = player.get_node_or_null("AbilityCaster")
	if ability_caster != null:
		var runtime_loadout: AbilityLoadout = LabLoadout.duplicate(true) as AbilityLoadout
		var ability: AbilityDefinition = runtime_loadout.get_equipped_ability(0)
		if ability != null:
			runtime_payload = ability.get_action_payload() as ResonancePayload
			if runtime_payload != null:
				runtime_payload.frequency_hz = LAB_FREQUENCIES[frequency_index]
		ability_caster.set("loadout", runtime_loadout)
		ability_caster.set("current_ability_index", 0)
		if ability_caster.has_method("align_focus_menu_to_current_ability"):
			ability_caster.call("align_focus_menu_to_current_ability")
		if ability_caster.has_method("emit_current_ability"):
			ability_caster.call("emit_current_ability")
	var aerial: Node = player.get_node_or_null("AerialLocomotion")
	if aerial != null:
		aerial.set("double_jump_unlocked", false)
		aerial.set("hover_unlocked", false)
		aerial.set("flight_unlocked", false)
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	GameState.set_stat("sound", maxi(GameState.get_stat("sound"), 5))
	update_active_frequency_label()


func build_laboratory() -> void:
	create_static_box(
		"Floor",
		Vector3(0.0, -0.5, -1.5),
		Vector3(30.0, 1.0, 29.0),
		Color(0.055, 0.035, 0.075, 1.0)
	)
	create_static_box(
		"BackWall",
		Vector3(0.0, 5.0, -13.5),
		Vector3(30.0, 10.0, 0.6),
		Color(0.075, 0.04, 0.1, 1.0)
	)
	create_instruction_board()
	create_frequency_gallery()
	create_sympathetic_station()
	create_resonant_gate_station()
	create_fracture_station()


func create_instruction_board() -> void:
	add_world_label(
		"RESONANCE LABORATORY\n"
		+ "INTERACT tunes 110 / 220 / 440 / 660 Hz  •  CAST emits Resonant Pulse\n"
		+ "Matching frequencies accumulate energy  •  RESET restores every resonator",
		Vector3(0.0, 7.5, -13.0),
		Color(1.0, 0.48, 0.82, 1.0),
		25
	)
	active_frequency_label = add_world_label(
		"ACTIVE FREQUENCY\n220 Hz",
		Vector3(0.0, 4.2, 8.0),
		Color(1.0, 0.64, 0.92, 1.0),
		27
	)
	create_floor_marker(
		Vector3(0.0, 0.02, 8.0),
		Color(1.0, 0.32, 0.72, 1.0)
	)


func create_frequency_gallery() -> void:
	add_world_label(
		"SELECTIVE RESONANCE\nOnly the matching column should shake strongly",
		Vector3(0.0, 5.4, 3.0),
		Color(0.9, 0.62, 1.0, 1.0),
		22
	)
	var positions: Array[Vector3] = [
		Vector3(-5.4, 1.5, 3.0),
		Vector3(-1.8, 1.5, 3.0),
		Vector3(1.8, 1.5, 3.0),
		Vector3(5.4, 1.5, 3.0),
	]
	var colors: Array[Color] = [
		Color(0.2, 0.7, 1.0, 1.0),
		Color(0.62, 0.38, 1.0, 1.0),
		Color(1.0, 0.34, 0.74, 1.0),
		Color(1.0, 0.72, 0.22, 1.0),
	]
	for index: int in range(LAB_FREQUENCIES.size()):
		var resonator: ResonantBody3D = create_resonator(
			"Gallery" + str(int(LAB_FREQUENCIES[index])) + "Hz",
			positions[index],
			Vector3(1.25, 3.0, 1.25),
			LAB_FREQUENCIES[index],
			colors[index]
		)
		resonator.energy_capacity = 30.0
		resonator.damping_per_second = 0.65
		add_world_label(
			str(int(LAB_FREQUENCIES[index])) + " Hz",
			positions[index] + Vector3.UP * 2.15,
			colors[index],
			23
		)


func create_sympathetic_station() -> void:
	add_world_label(
		"SYMPATHETIC VIBRATION • 220 Hz\nCast near PRIMARY—the distant fork receives energy through coupling",
		Vector3(-9.0, 5.2, 0.5),
		Color(0.52, 0.84, 1.0, 1.0),
		21
	)
	create_floor_marker(
		Vector3(-9.0, 0.02, 7.0),
		Color(0.28, 0.68, 1.0, 1.0)
	)
	primary_fork = create_resonator(
		"PrimaryFork",
		Vector3(-9.0, 1.65, 2.0),
		Vector3(0.65, 3.3, 0.65),
		220.0,
		Color(0.26, 0.72, 1.0, 1.0)
	)
	primary_fork.coupling_group = "sympathetic_forks"
	primary_fork.coupling_radius = 5.5
	primary_fork.coupling_efficiency = 0.8
	primary_fork.propagation_threshold = 3.0
	primary_fork.damping_per_second = 0.24
	sympathetic_fork = create_resonator(
		"SympatheticFork",
		Vector3(-9.0, 1.65, -2.2),
		Vector3(0.65, 3.3, 0.65),
		220.0,
		Color(0.62, 0.9, 1.0, 1.0)
	)
	sympathetic_fork.coupling_group = "sympathetic_forks"
	sympathetic_fork.coupling_radius = 5.5
	sympathetic_fork.coupling_efficiency = 0.6
	sympathetic_fork.propagation_threshold = 100.0
	sympathetic_fork.damping_per_second = 0.2
	add_world_label(
		"PRIMARY",
		Vector3(-9.0, 3.75, 2.0),
		Color(0.3, 0.75, 1.0, 1.0),
		20
	)
	add_world_label(
		"COUPLED",
		Vector3(-9.0, 3.75, -2.2),
		Color(0.7, 0.94, 1.0, 1.0),
		20
	)


func create_resonant_gate_station() -> void:
	add_world_label(
		"RESONANT LOCK • 440 Hz\nRepeated matching pulses accumulate enough energy to raise the gate",
		Vector3(0.0, 6.0, -4.8),
		Color(1.0, 0.42, 0.74, 1.0),
		21
	)
	gate_resonator = create_resonator(
		"GateResonator",
		Vector3(0.0, 1.15, -3.1),
		Vector3(1.8, 2.3, 1.2),
		440.0,
		Color(1.0, 0.26, 0.68, 1.0)
	)
	gate_resonator.bandwidth_hz = 14.0
	gate_resonator.energy_capacity = 42.0
	gate_resonator.threshold_energy = 23.0
	gate_resonator.threshold_mode = ResonantBody3D.ThresholdMode.ACTIVATE
	gate_resonator.damping_per_second = 0.2
	gate_resonator.activated.connect(_on_gate_activated)

	gate_body = AnimatableBody3D.new()
	gate_body.name = "ResonantGate"
	gate_body.position = Vector3(0.0, 2.4, -7.4)
	gate_closed_position = gate_body.position
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(5.6, 4.8, 0.7)
	collision.shape = shape
	gate_body.add_child(collision)
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.name = "Visual"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = shape.size
	visual.mesh = mesh
	visual.material_override = ElementVisuals.make_material(
		Color(0.34, 0.16, 0.38, 1.0),
		0.45,
		1.0,
		false
	)
	gate_body.add_child(visual)
	add_child(gate_body)


func create_fracture_station() -> void:
	add_world_label(
		"GLASS FRACTURE • 660 Hz\nTune precisely and Cast nearby to burst the suspended glass",
		Vector3(8.6, 6.0, -5.0),
		Color(1.0, 0.78, 0.34, 1.0),
		21
	)
	create_floor_marker(
		Vector3(8.6, 0.02, 0.0),
		Color(1.0, 0.68, 0.18, 1.0)
	)
	var shard_offsets: Array[Vector3] = [
		Vector3(-1.0, 1.0, 0.0),
		Vector3(0.0, 1.2, 0.0),
		Vector3(1.0, 1.0, 0.0),
		Vector3(-0.55, -0.45, 0.0),
		Vector3(0.55, -0.45, 0.0),
	]
	for index: int in range(shard_offsets.size()):
		var shard: RigidBody3D = create_glass_shard(
			index,
			Vector3(8.6, 3.1, -5.8) + shard_offsets[index]
		)
		glass_shards.append(shard)


func create_resonator(
	body_name: String,
	position_value: Vector3,
	size_value: Vector3,
	frequency_hz: float,
	color: Color
) -> ResonantBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = body_name
	body.position = position_value
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.name = "Visual"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size_value
	visual.mesh = mesh
	visual.material_override = ElementVisuals.make_material(
		color,
		1.4,
		1.0,
		false
	)
	body.add_child(visual)
	var resonant_body: ResonantBody3D = ResonantBody3D.new()
	resonant_body.name = "ResonantBody3D"
	resonant_body.resonance_id = body_name.to_snake_case()
	resonant_body.natural_frequency_hz = frequency_hz
	resonant_body.bandwidth_hz = 16.0
	resonant_body.maximum_visual_displacement = 0.11
	resonant_body.maximum_visual_scale_pulse = 0.065
	body.add_child(resonant_body)
	add_child(body)
	resonant_bodies.append(resonant_body)
	return resonant_body


func create_glass_shard(index: int, position_value: Vector3) -> RigidBody3D:
	var shard: RigidBody3D = RigidBody3D.new()
	shard.name = "GlassShard" + str(index + 1)
	shard.position = position_value
	shard.mass = 2.0
	shard.freeze = true
	shard.linear_damp = 0.18
	shard.angular_damp = 0.22
	var size: Vector3 = Vector3(
		0.72 + float(index % 2) * 0.22,
		1.45 - float(index % 3) * 0.18,
		0.38
	)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	shard.add_child(collision)
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.name = "Visual"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = ElementVisuals.make_material(
		Color(0.72, 0.92, 1.0, 1.0),
		2.2,
		0.72,
		false
	)
	shard.add_child(visual)
	var resonant_body: ResonantBody3D = ResonantBody3D.new()
	resonant_body.name = "ResonantBody3D"
	resonant_body.resonance_id = "glass_shard_" + str(index + 1)
	resonant_body.natural_frequency_hz = 660.0
	resonant_body.bandwidth_hz = 13.0
	resonant_body.energy_capacity = 22.0
	resonant_body.threshold_energy = 9.5
	resonant_body.threshold_mode = ResonantBody3D.ThresholdMode.FRACTURE
	resonant_body.damping_per_second = 0.12
	resonant_body.maximum_visual_displacement = 0.14
	resonant_body.fractured.connect(_on_glass_shard_fractured.bind(shard, index))
	shard.add_child(resonant_body)
	add_child(shard)
	resonant_bodies.append(resonant_body)
	return shard


func _on_gate_activated(_resonant_body: ResonantBody3D) -> void:
	if gate_opened or gate_body == null:
		return
	gate_opened = true
	var tween: Tween = gate_body.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(
		gate_body,
		"position",
		gate_closed_position + Vector3.UP * 5.2,
		1.1
	)
	show_message("The 440 Hz resonant lock releases the gate.")


func _on_glass_shard_fractured(
	_resonant_body: ResonantBody3D,
	shard: RigidBody3D,
	index: int
) -> void:
	if shard == null or not is_instance_valid(shard) or not shard.freeze:
		return
	shard.freeze = false
	fractured_shards += 1
	var outward: Vector3 = Vector3(
		float(index - 2) * 0.55,
		0.75 + float(index % 2) * 0.25,
		0.55
	).normalized()
	shard.apply_central_impulse(outward * 7.0)
	shard.apply_torque_impulse(
		Vector3(0.5 + float(index) * 0.2, 0.8, -0.4) * 2.2
	)
	if fractured_shards == 1:
		show_message("The 660 Hz pulse fractures the suspended glass.")


func cycle_frequency() -> void:
	frequency_index = (frequency_index + 1) % LAB_FREQUENCIES.size()
	if runtime_payload != null:
		runtime_payload.frequency_hz = LAB_FREQUENCIES[frequency_index]
	update_active_frequency_label()
	show_message(
		"Resonant Pulse tuned to "
		+ str(int(LAB_FREQUENCIES[frequency_index]))
		+ " Hz."
	)


func update_active_frequency_label() -> void:
	if active_frequency_label == null:
		return
	active_frequency_label.text = (
		"ACTIVE FREQUENCY\n"
		+ str(int(LAB_FREQUENCIES[frequency_index]))
		+ " Hz"
	)


func refresh_readout() -> void:
	if readout == null:
		return
	var hottest: ResonantBody3D = null
	for resonant_body: ResonantBody3D in resonant_bodies:
		if resonant_body == null:
			continue
		if hottest == null or resonant_body.current_energy > hottest.current_energy:
			hottest = resonant_body
	var hottest_text: String = "none"
	if hottest != null:
		hottest_text = (
			hottest.resonance_id
			+ " "
			+ str(snappedf(hottest.current_energy, 0.1))
			+ "/"
			+ str(snappedf(hottest.energy_capacity, 0.1))
		)
	var sympathetic_energy: float = (
		sympathetic_fork.current_energy
		if sympathetic_fork != null
		else 0.0
	)
	readout.text = (
		"RESONANCE  •  Active "
		+ str(int(LAB_FREQUENCIES[frequency_index]))
		+ " Hz  •  Hottest "
		+ hottest_text
		+ "\nCoupled fork "
		+ str(snappedf(sympathetic_energy, 0.1))
		+ "  •  Gate "
		+ ("OPEN" if gate_opened else "closed")
		+ "  •  Glass "
		+ str(fractured_shards)
		+ "/"
		+ str(glass_shards.size())
		+ " fractured"
	)


func create_static_box(
	body_name: String,
	position_value: Vector3,
	size_value: Vector3,
	color: Color
) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = body_name
	body.position = position_value
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)
	var visual: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size_value
	visual.mesh = mesh
	visual.material_override = ElementVisuals.make_material(
		color,
		0.08,
		1.0,
		false
	)
	body.add_child(visual)
	add_child(body)
	return body


func create_floor_marker(position_value: Vector3, color: Color) -> void:
	var marker: MeshInstance3D = MeshInstance3D.new()
	marker.position = position_value
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.9
	mesh.bottom_radius = 0.9
	mesh.height = 0.04
	marker.mesh = mesh
	marker.material_override = ElementVisuals.make_material(
		color,
		2.0,
		1.0,
		false
	)
	add_child(marker)


func add_world_label(
	text_value: String,
	position_value: Vector3,
	color: Color,
	font_size: int
) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = text_value
	label.position = position_value
	label.font_size = font_size
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	return label


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	return {
		"resonance_lab": true,
		"resonant_bodies": resonant_bodies.size(),
		"active_frequency_hz": LAB_FREQUENCIES[frequency_index],
		"gate_open": gate_opened,
		"fractured_shards": fractured_shards,
		"sympathetic_energy": (
			sympathetic_fork.current_energy
			if sympathetic_fork != null
			else 0.0
		),
	}

