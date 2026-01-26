extends Area2D

@export var sprite: AnimatedSprite2D
@export var collision_shape: CollisionShape2D
@export var rotation_offset: float = -PI / 2.0

var thunder_scene: PackedScene = preload("res://Scenes/player/thunder.tscn")
var start_position: Vector2
var end_position: Vector2
var target_enemy: Node
var thunder_damage: float = 0.0
var chain_left: int = 0
var damage_decay: float = 0.3
var chain_range: float = 130.0
var paralyze_duration: float = 0.0
var boss_extra_damage: float = 0.0
var duration: float = 0.1
var sprite_base_scale: Vector2
var follow_node: Node

func setup_thunder(p_start_position: Vector2, p_end_position: Vector2, p_target_enemy: Node, p_damage: float, p_chain_left: int, p_damage_decay: float, p_chain_range: float, p_paralyze_duration: float, p_boss_extra_damage: float, p_follow_node: Node = null) -> void:
	start_position = p_start_position
	end_position = p_end_position
	target_enemy = p_target_enemy
	thunder_damage = p_damage
	chain_left = p_chain_left
	damage_decay = p_damage_decay
	chain_range = p_chain_range
	paralyze_duration = p_paralyze_duration
	boss_extra_damage = p_boss_extra_damage
	sprite_base_scale = sprite.scale
	follow_node = p_follow_node
	
	_apply_visual()
	_apply_damage_and_chain()

func _apply_visual() -> void:
	global_position = start_position.lerp(end_position, 0.5)
	var dir = end_position - start_position
	rotation = dir.angle() + rotation_offset
	
	if sprite.animation != "default" or not sprite.is_playing():
		sprite.play("default")
	var frame_texture = sprite.sprite_frames.get_frame_texture("default", 0)
	var base_height = frame_texture.get_size().y
	var distance = dir.length()
	var new_scale_y = sprite_base_scale.y * (distance / base_height)
	sprite.scale = Vector2(sprite_base_scale.x, new_scale_y)
	var circle_shape = collision_shape.shape as CircleShape2D
	circle_shape.radius = distance * 0.5

func _process(delta: float) -> void:
	if follow_node and is_instance_valid(follow_node):
		start_position = follow_node.global_position
		_apply_visual()

func _apply_damage_and_chain() -> void:
	if target_enemy:
		_apply_damage_to_enemy(target_enemy)
	
	if chain_left > 0 and target_enemy:
		var target_position = target_enemy.global_position
		var excluded_id = target_enemy.get_instance_id()
		await get_tree().create_timer(0.12).timeout
		var next_enemy = _find_nearest_enemy(target_position, excluded_id)
		if next_enemy:
			var next_damage = thunder_damage * (1.0 - damage_decay)
			var thunder_instance = thunder_scene.instantiate()
			get_tree().current_scene.add_child(thunder_instance)
			thunder_instance.setup_thunder(target_position, next_enemy.global_position, next_enemy, next_damage, chain_left - 1, damage_decay, chain_range, paralyze_duration, boss_extra_damage, null)
	
	await get_tree().create_timer(duration).timeout
	queue_free()

func _apply_damage_to_enemy(enemy: Node) -> void:
	var is_boss = enemy.is_in_group("boss")
	var final_damage = thunder_damage
	if is_boss and boss_extra_damage > 0.0:
		final_damage *= (1.0 + boss_extra_damage)
	enemy.take_damage(final_damage, false, false, "thunder")
	
	if not is_boss and paralyze_duration > 0.0:
		enemy.set_physics_process(false)
		enemy.set_process(false)
		await get_tree().create_timer(paralyze_duration).timeout
		enemy.set_physics_process(true)
		enemy.set_process(true)

func _find_nearest_enemy(from_position: Vector2, excluded_id: int) -> Node:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest_enemy = null
	var nearest_distance = INF
	
	for enemy in enemies:
		if enemy.get_instance_id() == excluded_id:
			continue
		var distance = from_position.distance_to(enemy.global_position)
		if distance <= chain_range and distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy
	
	return nearest_enemy
