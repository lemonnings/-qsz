extends Node2D

@export var rotation_speed: float = PI * 1
@export var radius: float = 70.0
@export var fire_count: int = 4
@export var hit_cooldown: float = 0.4

@onready var player = get_tree().get_first_node_in_group("player")

var current_angle: float = 0.0

func _ready() -> void:
	Global.connect("ringFire_damage_triggered", Callable(self , "_on_ringFire_damage_triggered"))


func _physics_process(delta: float) -> void:
	if player:
		global_position = player.global_position
		if player.has_method("is_beastify_replacing_weapon") and player.is_beastify_replacing_weapon("RingFire"):
			visible = false
			return
		visible = true
		current_angle += rotation_speed * delta
		if current_angle > 2 * PI:
			current_angle -= 2 * PI

		var child_count: int = get_child_count()
		for i in range(child_count):
			var child: Node2D = get_child(i) as Node2D
			if child == null:
				continue
			var angle: float = current_angle + (2 * PI * i) / float(child_count)
			child.position = Vector2(cos(angle), sin(angle)) * radius
			child.rotation = angle + PI / 2


func _on_ringFire_damage_triggered():
	if player and player.has_method("is_beastify_replacing_weapon") and player.is_beastify_replacing_weapon("RingFire"):
		for raw_child in get_children():
			var existing_child: Node = raw_child as Node
			remove_child(existing_child)
			existing_child.queue_free()
		return
	var current_fire_count = fire_count
	var current_rotation_speed = PI * 1 # 始终从基础值出发，避免累乘

	if PC.selected_rewards.has("RingFire1"):
		current_fire_count += 1
	if PC.selected_rewards.has("RingFire11"):
		current_fire_count += 1
		current_rotation_speed *= 1.1
	if PC.selected_rewards.has("RingFire2"):
		current_rotation_speed *= 1.25

	rotation_speed = current_rotation_speed
	
	for raw_child in get_children():
		var child: Node = raw_child as Node
		remove_child(child)
		child.queue_free()

	# 确保只实例化一次
	for i in range(current_fire_count):
		var fire_instance: Node2D = preload("res://Scenes/player/ring_fire.tscn").instantiate() as Node2D
		add_child(fire_instance)
		var angle = (2 * PI * i) / current_fire_count
		fire_instance.position = Vector2(cos(angle), sin(angle)) * radius
		fire_instance.set("hit_cooldown", hit_cooldown)
