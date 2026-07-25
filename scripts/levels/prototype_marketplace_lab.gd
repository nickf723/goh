extends Node3D
class_name PrototypeMarketplaceLab

const MerchantScript = preload("res://scripts/economy/merchant_trading_post.gd")
const LootScript = preload("res://scripts/economy/world_loot_pickup.gd")
const ChestScript = preload("res://scripts/economy/treasure_chest.gd")

const LAB_ITEM_IDS: Array[String] = [
	"healing_potion", "oil_flask", "noise_maker", "life_bloom", "springwater",
	"echo_reed", "frost_salt", "spark_ore", "starlit_gem",
]
const LAB_PICKUP_IDS: Array[String] = [
	"market_coin_1", "market_coin_2", "market_coin_3", "market_coin_4",
	"market_starlit_gem", "market_treasure_chest",
]


func _ready() -> void:
	Engine.time_scale = 1.0
	build_environment()
	build_market()
	build_merchant()
	build_loot_course()
	build_chest()
	configure_trial_inventory()
	GameState.set_objective("Collect treasure, trade with Mara, and use Buyback to recover a sold item.")
	show_message("Marketplace ready. Coins collect on contact; valuables and the chest use Interact.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene") and OS.has_feature("editor"):
		reset_marketplace()
		get_viewport().set_input_as_handled()


func configure_trial_inventory() -> void:
	GameState.set_currency(12)
	GameState.set_inventory_count("life_bloom", 2)
	GameState.set_inventory_count("healing_potion", 1)
	GameState.set_inventory_count("starlit_gem", 0)


func reset_marketplace() -> void:
	GameState.set_currency(0)
	for item_id: String in LAB_ITEM_IDS:
		GameState.set_inventory_count(item_id, 0)
	for pickup_id: String in LAB_PICKUP_IDS:
		GameState.clear_collected_pickup(pickup_id)
	get_tree().reload_current_scene()


func build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.07, 0.1)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.56, 0.68, 0.74)
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_color = Color(1.0, 0.82, 0.58)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)


func build_market() -> void:
	create_static_box("MarketSquare", Vector3(0.0, -0.55, 0.0), Vector3(28.0, 1.0, 28.0), Color(0.24, 0.28, 0.25))
	create_static_box("BackWall", Vector3(0.0, 2.5, -14.0), Vector3(28.0, 5.0, 0.5), Color(0.14, 0.18, 0.17))
	create_static_box("LeftWall", Vector3(-14.0, 2.5, 0.0), Vector3(0.5, 5.0, 28.0), Color(0.14, 0.18, 0.17))
	create_static_box("RightWall", Vector3(14.0, 2.5, 0.0), Vector3(0.5, 5.0, 28.0), Color(0.14, 0.18, 0.17))
	for x: float in [-9.0, 9.0]:
		create_static_box("SideStall" + str(x), Vector3(x, 0.5, -5.0), Vector3(4.5, 1.0, 2.0), Color(0.35, 0.16, 0.07))
	var title := make_label("MARKETPLACE", Vector3(0.0, 5.5, -13.6), Color(0.68, 0.94, 1.0), 48)
	add_child(title)
	var hint := make_label("TREASURE → WALLET → TRADE → BUYBACK", Vector3(0.0, 4.35, -13.55), Color(0.9, 0.78, 0.38), 26)
	add_child(hint)


func build_merchant() -> void:
	var merchant := Area3D.new()
	merchant.name = "MaraMerchant"
	merchant.position = Vector3(0.0, 0.0, -8.5)
	merchant.set_script(MerchantScript)
	merchant.set("merchant_name", "Mara's Field Goods")
	add_child(merchant)


func build_loot_course() -> void:
	var coin_positions: Array[Vector3] = [
		Vector3(-5.0, 0.0, 8.0),
		Vector3(-2.0, 0.0, 6.5),
		Vector3(2.0, 0.0, 6.5),
		Vector3(5.0, 0.0, 8.0),
	]
	for index: int in range(coin_positions.size()):
		var coin := Area3D.new()
		coin.name = "CoinPickup" + str(index + 1)
		coin.position = coin_positions[index]
		coin.set_script(LootScript)
		coin.set("loot_kind", "currency")
		coin.set("amount", 5 + index * 2)
		coin.set("pickup_id", LAB_PICKUP_IDS[index])
		coin.set("auto_collect", true)
		add_child(coin)
	var gem := Area3D.new()
	gem.name = "StarlitGemPickup"
	gem.position = Vector3(8.5, 0.0, 2.0)
	gem.set_script(LootScript)
	gem.set("loot_kind", "item")
	gem.set("item_id", "starlit_gem")
	gem.set("amount", 1)
	gem.set("pickup_id", "market_starlit_gem")
	gem.set("auto_collect", false)
	gem.set("prompt_text", "Collect Starlit Gem")
	gem.set("loot_color", Color(0.45, 0.82, 1.0))
	add_child(gem)


func build_chest() -> void:
	var chest := Area3D.new()
	chest.name = "MarketplaceTreasureChest"
	chest.position = Vector3(-8.5, 0.0, 1.5)
	chest.rotation_degrees.y = 18.0
	chest.set_script(ChestScript)
	chest.set("chest_id", "market_treasure_chest")
	chest.set("crown_reward", 24)
	chest.set("item_rewards", {"starlit_gem": 1, "springwater": 2})
	add_child(chest)


func create_static_box(node_name: String, position: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = make_material(color)
	body.add_child(mesh_instance)
	add_child(body)
	return body


func make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	return material


func make_label(text: String, position: Vector3, color: Color, font_size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = position
	label.font_size = font_size
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 7
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
