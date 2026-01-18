extends Area2D

@export var damage_interval: float = 1.0 # 赤曜伤害频率：1秒/次

var player_node: Node2D
@export var damage_timer: Timer
var is_initialized: bool = false

# @export var riyan_cooldown : float = 0.5
# @export var riyan_hp_max_damage : float = 0.4

func _ready() -> void:
	Global.connect("riyan_damage_triggered", Callable(self, "_on_get_riyan"))

func _process(delta: float) -> void:
	if player_node:
		global_position = player_node.global_position

func _on_damage_timer_timeout() -> void:
	if player_node:
		var damage_amount: float = (PC.pc_atk * PC.riyan_atk_damage) + (PC.pc_max_hp * PC.riyan_hp_max_damage)
		
		for area in get_overlapping_areas():
			if area.is_in_group("enemies") and area.has_method("take_damage"):
				area.take_damage(damage_amount, false, false, "riyan")

func _exit_tree() -> void:
	if damage_timer and is_instance_valid(damage_timer):
		remove_child(damage_timer)
		damage_timer.queue_free()

func _on_get_riyan():
	# 如果已经初始化过，直接返回
	if is_initialized:
		return
	
	player_node = get_tree().get_first_node_in_group("player")
	
	global_position = player_node.global_position
	
	# 创建圆形碰撞体
	var collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = PC.riyan_range
	collision_shape.shape = circle_shape
	add_child(collision_shape)
	
	collision_layer = 0 # 不作为碰撞源
	
	# 绘制视觉效果
	var draw_node = Node2D.new()
	add_child(draw_node)
	draw_node.queue_redraw()
	draw_node.draw.connect(func():
		var color_fill = Color(1.0, 0.6, 0.0, 0.2) # 浅橙色填充
		var color_border = Color(1.0, 0.6, 0.0, 0.5) # 橙色描边
		var border_width = 2.0
		draw_node.draw_circle(Vector2.ZERO, PC.riyan_range, color_fill)
		draw_node.draw_arc(Vector2.ZERO, PC.riyan_range, 0, PI * 2, 64, color_border, border_width, true)
		draw_node.z_index = -1
	)
	
	damage_timer.start()
	set_process(true)
	
	# 标记为已初始化
	is_initialized = true
