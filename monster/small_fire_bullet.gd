extends Area2D

@export var bullet_speed: float  # Boss子弹速度
@export var bullet_damage: float  # Boss子弹伤害
@export var bullet_range: float = 4000.0  # 子弹射程
@export var rotation_speed_degrees: float = 1080.0

var direction: Vector2 = Vector2.RIGHT
var start_position: Vector2
var traveled_distance: float = 0.0

func _ready() -> void:
	# 记录子弹起始位置
	start_position = global_position
	
	# 添加到bullet组
	add_to_group("boss_bullet")
	
	# 连接碰撞信号
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# 3秒后自动销毁
	await get_tree().create_timer(3.0).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	# 子弹移动
	position += direction * bullet_speed * delta
	rotation += deg_to_rad(rotation_speed_degrees * delta)
	# 更新已飞行距离
	traveled_distance = start_position.distance_to(global_position)
	
	# 检查是否超出射程
	if traveled_distance >= bullet_range:
		queue_free()


func set_direction(new_direction: Vector2) -> void:
	direction = new_direction.normalized()
	# 设置子弹旋转角度
	rotation = direction.angle()

func _on_body_entered(body: Node2D) -> void:
	# 击中玩家
	if body.is_in_group("player"):
		Global.emit_signal("player_hit")
		PC.apply_damage(int(bullet_damage))
		if PC.pc_hp <= 0:
			PC.player_instance.game_over()
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	# 可以在这里处理与其他区域的碰撞
	pass
