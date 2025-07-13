extends Node2D

@export var rotation_speed: float = PI * 1
@export var radius: float = 70.0
@export var fire_count: int = 4
@export var hit_cooldown: float = 0.3

@onready var player = get_tree().get_first_node_in_group("player")
var current_angle: float = 0.0

func _ready() -> void:
	Global.connect("ringFire_damage_triggered", Callable(self, "_on_ringFire_damage_triggered"))


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
			child.rotation = angle + PI / 2
			
func _on_ringFire_damage_triggered():
	var current_fire_count = fire_count
	var current_rotation_speed = rotation_speed

	if PC.selected_rewards.has("ringFire1"):
		current_fire_count += 1
		var fire_instance = preload("res://Scenes/player/ring_fire.tscn").instantiate()
		remove_child(fire_instance)
	if PC.selected_rewards.has("ringFire11"):
		current_fire_count += 1
		var fire_instance = preload("res://Scenes/player/ring_fire.tscn").instantiate()
		remove_child(fire_instance)
	if PC.selected_rewards.has("ringFire2"):
		current_rotation_speed *= 1.25
		var fire_instance = preload("res://Scenes/player/ring_fire.tscn").instantiate()
		remove_child(fire_instance)

	# 确保只实例化一次
	if get_child_count() == 0:
		for i in range(current_fire_count):
			var fire_instance = preload("res://Scenes/player/ring_fire.tscn").instantiate()
			add_child(fire_instance)
			var angle = (2 * PI * i) / current_fire_count
			fire_instance.position = Vector2(cos(angle), sin(angle)) * radius
			fire_instance.hit_cooldown = hit_cooldown
