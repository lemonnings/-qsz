extends Node2D
class_name WarnRectUtil

# 预警矩形AOE工具类
# 用于创建boss技能的矩形范围预警效果

signal warning_finished
signal damage_dealt(damage_amount)

# 预警参数
var target_point: Vector2 = Vector2.ZERO  # 目标点
var width: float = 100.0                  # 矩形宽度
var warning_time: float = 2.0             # 预警时间
var damage: float = 50.0                  # 伤害值
var animation_player: AnimationPlayer = null  # 预警结束后播放的动画播放器

# 内部变量
var warning_shape: Node2D
var current_time: float = 0.0
var is_warning_active: bool = false
var player_ref: Node2D
var rect_length: float = 0.0  # 矩形长度（从起始点到目标点的距离）
var rect_angle: float = 0.0   # 矩形角度

func _ready():
	# 获取玩家引用
	player_ref = get_tree().get_first_node_in_group("player")
	
	# 创建预警形状
	create_warning_shape()

func create_warning_shape():
	"""创建预警的矩形形状"""
	var RectDrawer = preload("res://util/rect_drawer.gd")
	warning_shape = RectDrawer.new()
	add_child(warning_shape)
	
	# 设置初始参数
	warning_shape.setup(rect_length, width, rect_angle)
	
	# 初始时不可见
	warning_shape.modulate.a = 0.0

func start_warning(pos: Vector2, _target_point: Vector2, _width: float = 100.0, 
				  _warning_time: float = 2.0, _damage: float = 50.0, _animation_player: AnimationPlayer = null):
	"""开始预警
	pos: 生成位置（起始点）
	_target_point: 目标点
	_width: 矩形宽度
	_warning_time: 预警时间
	_damage: 伤害值
	_animation_player: 预警结束后播放的动画播放器
	"""
	target_point = _target_point
	width = _width
	warning_time = _warning_time
	damage = _damage
	animation_player = _animation_player
	
	# 计算矩形长度和角度
	rect_length = pos.distance_to(target_point)
	rect_angle = pos.angle_to_point(target_point)
	
	# 设置位置（矩形中心点）
	var center_pos = (pos + target_point) / 2.0
	global_position = center_pos
	
	# 重置状态
	current_time = 0.0
	is_warning_active = true
	
	# 更新形状圆形的
	if warning_shape:
		warning_shape.setup(rect_length, width, rect_angle)

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
	"""检查玩家是否在矩形AOE范围内"""
	if not player_ref:
		return false
	
	# 将玩家位置转换到矩形的本地坐标系
	var player_pos = player_ref.global_position
	var relative_pos = player_pos - global_position
	
	# 旋转坐标系，使矩形对齐到水平方向
	var rotated_pos = relative_pos.rotated(-rect_angle)
	
	# 检查是否在矩形范围内
	var half_length = rect_length / 2.0
	var half_width = width / 2.0
	
	return abs(rotated_pos.x) <= half_length and abs(rotated_pos.y) <= half_width

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