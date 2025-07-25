extends Node2D
class_name WarnSectorUtil

# 预警扇形AOE工具类
# 用于创建boss技能的扇形范围预警效果

signal warning_finished
signal damage_dealt(damage_amount)

# 预警参数
var target_point: Vector2 = Vector2.ZERO  # 目标点
var sector_angle: float = 60.0            # 扇形角度（度）
var radius: float = 200.0                 # 扇形半径
var warning_time: float = 2.0             # 预警时间
var damage: float = 50.0                  # 伤害值
var animation_player: AnimationPlayer = null  # 预警结束后播放的动画播放器

# 内部变量
var warning_shape: Node2D
var current_time: float = 0.0
var start_position: Vector2
var is_warning_active: bool = false
var player_ref: Node2D
var center_direction: float = 0.0  # 扇形中心方向角度
var current_alpha: float = 0.0
var initial_scale: Vector2 = Vector2(0.1, 0.1)

func _ready():
	# 获取玩家引用
	player_ref = get_tree().get_first_node_in_group("player")
	
	# 创建预警形状
	create_warning_shape()

func create_warning_shape():
	"""创建预警的扇形形状"""
	warning_shape = preload("res://util/sector_drawer.gd").new()
	add_child(warning_shape)
	warning_shape.z_index = 10 # 确保在其他元素之上

func start_warning(pos: Vector2, p_target_point: Vector2, p_sector_angle: float, p_warning_time: float, p_damage: float, p_animation_player: AnimationPlayer = null):
	"""开始预警
	pos: 生成位置（扇形顶点）
	p_target_point: 目标点，决定扇形方向
	p_sector_angle: 扇形角度（度）
	p_warning_time: 预警时间
	p_damage: 伤害值
	p_animation_player: 预警结束后播放的动画播放器
	"""
	self.start_position = pos
	self.target_point = p_target_point
	self.sector_angle = deg_to_rad(p_sector_angle) # 转换为弧度
	self.warning_time = p_warning_time
	self.damage = p_damage
	self.animation_player = p_animation_player
	self.current_time = 0.0
	self.current_alpha = 0.0

	global_position = start_position

	if not is_instance_valid(warning_shape):
		create_warning_shape()

	# 计算扇形半径和方向
	var direction_vector = target_point - start_position
	self.radius = direction_vector.length()
	self.center_direction = direction_vector.angle()

	warning_shape.setup(radius, sector_angle, center_direction)
	warning_shape.modulate.a = 0.0 # 初始透明度为0
	warning_shape.scale = initial_scale # 初始缩放
	warning_shape.show()

	is_warning_active = true
	set_process(true)

func _process(delta):
	if not is_warning_active:
		return
	
	current_time += delta
	var progress = current_time / warning_time
	
	if progress <= 1.0:
		update_warning_visual(progress)
	else:
		# 预警结束
		finish_warning()

func update_warning_visual(progress: float):
	"""更新预警视觉效果"""
	if not warning_shape:
		return
	
	if progress <= 0.25:
		# 前四分之一时间：从中心向外扩散
		var expand_progress = progress / 0.25
		var current_scale = expand_progress
		warning_shape.scale = Vector2(current_scale, current_scale)
		warning_shape.modulate = Color(1.0, 0.0, 0.0, 0.35)  # 红色，透明度0.35
	
	elif progress <= 0.75:
		# 中间时间：保持稳定
		warning_shape.scale = Vector2(1.0, 1.0)
		warning_shape.modulate = Color(1.0, 0.0, 0.0, 0.35)
	
	elif progress <= 0.9:
		# 最后四分之一时间的前部分：开始闪烁
		var blink_progress = (progress - 0.75) / 0.15
		var blink_speed = 5.0 + blink_progress * 10.0  # 逐渐加快闪烁
		var blink_alpha = (sin(current_time * blink_speed) + 1.0) * 0.5  # 0到1的范围
		var final_alpha = 0.35 * (0.35 + blink_alpha * 0.65)  # 0.35*0.35到0.35的范围
		warning_shape.modulate = Color(1.0, 0.0, 0.0, final_alpha)
	
	else:
		# 最后0.1秒：渐变消失
		var fade_progress = (progress - 0.9) / 0.1
		var alpha = 0.35 * (1.0 - fade_progress)
		warning_shape.modulate = Color(1.0, 0.0, 0.0, alpha)

func finish_warning():
	"""结束预警，检查伤害"""
	is_warning_active = false
	
	# 检查玩家是否在范围内
	if player_ref and is_player_in_range():
		# 对玩家造成伤害
		deal_damage_to_player()
	
	# 播放动画（如果有）
	if animation_player != null:
		play_animation()
	
	# 隐藏预警形状
	if warning_shape:
		warning_shape.visible = false
	
	# 发送信号
	warning_finished.emit()

func is_player_in_range() -> bool:
	"""检查玩家是否在扇形AOE范围内"""
	if not player_ref:
		return false
	
	# 计算玩家相对于扇形顶点的位置
	var player_pos = player_ref.global_position
	var relative_pos = player_pos - global_position
	
	# 检查距离是否在半径范围内
	var distance = relative_pos.length()
	if distance > radius:
		return false
	
	# 计算玩家相对于扇形中心的角度
	var player_angle = relative_pos.angle()
	var angle_diff = abs(angle_difference(player_angle, center_direction))
	
	# 检查角度是否在扇形范围内
	var half_sector_angle = sector_angle / 2.0
	return angle_diff <= half_sector_angle

func angle_difference(angle1: float, angle2: float) -> float:
	"""计算两个角度之间的最小差值"""
	var diff = angle1 - angle2
	while diff > PI:
		diff -= 2 * PI
	while diff < -PI:
		diff += 2 * PI
	return diff

func deal_damage_to_player():
	"""对玩家造成伤害"""
	if player_ref and player_ref.has_method("take_damage"):
		player_ref.take_damage(damage)
		damage_dealt.emit(damage)

func play_animation():
	"""播放预警结束后的动画"""
	if animation_player != null and is_instance_valid(animation_player):
		animation_player.play()

func cleanup():
	"""清理资源"""
	is_warning_active = false
	if warning_shape:
		warning_shape.queue_free()
	queue_free()