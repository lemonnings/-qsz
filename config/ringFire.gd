extends Node2D

@export var damage: float = 0.0
@export var rotation_speed: float = PI
@export var radius: float = 50.0
@export var fire_count: int = 4
@export var hit_cooldown: float = 0.3

@onready var player = get_tree().get_first_node_in_group("player")
var current_angle: float = 0.0

func _ready() -> void:
	damage = PC.pc_atk * 0.3
	for i in range(fire_count):
		var fire_instance = preload("res://scenes/fire_instance.tscn").instantiate()
		add_child(fire_instance)
		var angle = (2 * PI * i) / fire_count
		fire_instance.position = Vector2(cos(angle), sin(angle)) * radius
		fire_instance.damage = damage
		fire_instance.hit_cooldown = hit_cooldown

func _physics_process(delta: float) -> void:
	if player:
		global_position = player.global_position
		current_angle += rotation_speed * delta
		if current_angle > 2 * PI:
			current_angle -= 2 * PI
		
		for i in range(get_child_count()):
			var child = get_child(i)
			var angle = current_angle + (2 * PI * i) / fire_count
			child.position = Vector2(cos(angle), sin(angle)) * radius
