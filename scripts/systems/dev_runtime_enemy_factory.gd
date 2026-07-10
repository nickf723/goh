extends RefCounted
class_name DevRuntimeEnemyFactory

const EnemyBrainScript: Script = preload("res://scripts/enemies/enemy_brain.gd")
const EnemyDefinitionScript: Script = preload("res://scripts/enemies/enemy_definition.gd")
const EnemyTelegraphScript: Script = preload("res://scripts/enemies/enemy_telegraph.gd")
const ZombieDefinitionResource: Resource = preload("res://data/enemies/zombie_definition.tres")
const ZombieGrabAttackResource: Resource = preload("res://data/enemy_attacks/zombie_grab_attack.tres")

const PayloadReceiverScript: Script = preload("res://scripts/combat/payload_receiver.gd")
const HitReceiverScript: Script = preload("res://scripts/combat/hit_receiver.gd")
const StatusReceiverScript: Script = preload("res://scripts/combat/status_receiver.gd")
const ForceReceiverScript: Script = preload("res://scripts/combat/force_receiver.gd")
const TagComponentScript: Script = preload("res://scripts/core/tag_component.gd")


static func create_zombie() -> CharacterBody3D:
	var zombie: CharacterBody3D = CharacterBody3D.new()
	zombie.name = "ZombieDrone"
	zombie.add_to_group("enemy")
	zombie.add_to_group("dev_spawned")
	zombie.collision_layer = 1
	zombie.collision_mask = 1

	add_collision(zombie)
	add_visual(zombie)
	add_receivers(zombie)
	add_brain(zombie)

	return zombie


static func add_collision(enemy: CharacterBody3D) -> void:
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "CollisionShape3D"

	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.7
	collision.shape = shape
	collision.position = Vector3(0.0, 0.85, 0.0)

	enemy.add_child(collision)


static func add_visual(enemy: CharacterBody3D) -> void:
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.name = "ZombieMesh"

	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = 0.42
	mesh.height = 1.7
	visual.mesh = mesh
	visual.position = Vector3(0.0, 0.85, 0.0)

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.42, 0.62, 0.36, 1.0)
	material.roughness = 0.8
	visual.material_override = material

	enemy.add_child(visual)


static func add_receivers(enemy: CharacterBody3D) -> void:
	var payload_receiver: Node = PayloadReceiverScript.new()
	payload_receiver.name = "PayloadReceiver"
	enemy.add_child(payload_receiver)

	var hit_receiver: Node = HitReceiverScript.new()
	hit_receiver.name = "HitReceiver"
	hit_receiver.set("target_name", "Zombie")
	hit_receiver.set("hit_mode", 3)
	hit_receiver.set("max_health", 10)
	hit_receiver.set("current_health", 10)
	hit_receiver.set("max_stance", 5)
	hit_receiver.set("current_stance", 5)
	hit_receiver.set("resets_stance_after_break", false)
	hit_receiver.set("disappears_when_defeated", true)
	enemy.add_child(hit_receiver)

	var status_receiver: Node = StatusReceiverScript.new()
	status_receiver.name = "StatusReceiver"
	enemy.add_child(status_receiver)

	var force_receiver: Node = ForceReceiverScript.new()
	force_receiver.name = "ForceReceiver"
	force_receiver.set("drag", 7.5)
	force_receiver.set("max_force_speed", 5.5)
	enemy.add_child(force_receiver)

	var tag_component: Node = TagComponentScript.new()
	tag_component.name = "TagComponent"
	tag_component.set("tags", ["enemy", "monster", "zombie", "undead", "organic", "slow", "staggerable"])
	enemy.add_child(tag_component)

	var telegraph: Node = EnemyTelegraphScript.new()
	telegraph.name = "EnemyTelegraph"
	telegraph.set("windup_scale", Vector3(1.08, 1.16, 1.08))
	telegraph.set("windup_flash_color", Color(0.9, 0.15, 0.08, 1.0))
	enemy.add_child(telegraph)


static func add_brain(enemy: CharacterBody3D) -> void:
	var brain: Node = EnemyBrainScript.new()
	brain.name = "EnemyBrain"
	brain.set("enemy_definition", make_zombie_definition())
	brain.set("default_attack", make_zombie_attack())
	enemy.add_child(brain)


static func make_zombie_definition() -> Resource:
	return ZombieDefinitionResource.duplicate(true)


static func make_zombie_attack() -> Resource:
	return ZombieGrabAttackResource.duplicate(true)
