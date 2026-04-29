extends Node2D
class_name WarnRectUtil

# 预警矩形AOE工具类
# 用于创建boss技能的矩形范围预警效果

@warning_ignore("unused_signal")
signal warning_finished
@warning_ignore("unused_signal")
signal damage_dealt(damage_amount)

# 预警参数
var target_point: Vector2 = Vector2.ZERO # 目标点
var width: float = 100.0 # 矩形宽度
var warning_time: float = 2.0 # 预警时间
var damage: float = 50.0 # 伤害值
var animation_player: AnimationPlayer = null # 预警结束后播放的动画播放器
var source_name: String = "范围伤害" # 伤害来源名称
var attacker: Node2D = null # 实际攻击者，未设置时默认使用自身

# 内部变量
var warning_shape: Node2D
var current_time: float = 0.0
var is_warning_active: bool = false
var player_ref: Node2D
var rect_length: float = 0.0 # 矩形长度（从起始点到目标点的距离）
var rect_angle: float = 0.0 # 矩形角度
var start_position: Vector2 = Vector2.ZERO
var grow_time: float = 0.0

func _ready():
	# 获取玩家引用
	player_ref = get_tree().get_first_node_in_group("player")
	# 备选：如果组中未找到，尝试使用 PC.player_instance
	if not player_ref and is_instance_valid(PC.player_instance):
		player_ref = PC.player_instance
	
	# 创建预警形状
	create_warning_shape()

func create_warning_shape():
	"""创建预警的矩形形状"""
	var RectDrawer = preload("res://Script/util/rect_drawer.gd")
	warning_shape = RectDrawer.new()
	add_child(warning_shape)
	
	# 设置初始参数
	warning_shape.setup(0.0, width, rect_angle)
	warning_shape.position = Vector2.ZERO
	
	# 初始时不可见
	warning_shape.visible = false
	warning_shape.modulate.a = 0.0

func start_warning(pos: Vector2, _target_point: Vector2, _width: float = 100.0,
				  _warning_time: float = 2.0, _damage: float = 50.0, _source_name: String = "范围伤害", _animation_player: AnimationPlayer = null,
				  _grow_time: float = -1.0):
	"""开始预警
	pos: 生成位置（起始点）
	_target_point: 目标点
	_width: 矩形宽度
	_warning_time: 预警时间
	_damage: 伤害值
	_animation_player: 预警结束后播放的动画播放器
	"""
	start_position = pos
	target_point = _target_point
	width = _width
	warning_time = _warning_time
	source_name = _source_name
	damage = _damage
	animation_player = _animation_player
	if _grow_time < 0.0:
		grow_time = warning_time
	else:
		grow_time = min(_grow_time, warning_time)
	
	# 计算矩形长度和角度
	rect_length = start_position.distance_to(target_point)
	rect_angle = start_position.angle_to_point(target_point)
	
	global_position = start_position
	
	# 重置状态
	current_time = 0.0
	is_warning_active = true
	
	if warning_shape:
		warning_shape.visible = true
		update_warning_shape(0.0)

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
	var current_length = rect_length
	if current_time < grow_time:
		current_length = rect_length * (current_time / grow_time)
	update_warning_shape(current_length)
	
	if progress <= 0.25:
		warning_shape.modulate = Color(1.0, 0.0, 0.0, 0.175) # 红色，透明度0.35
	
	elif progress <= 0.75:
		warning_shape.modulate = Color(1.0, 0.0, 0.0, 0.175)
	
	elif progress <= 0.9:
		# 最后四分之一时间的前部分：开始闪烁
		var blink_progress = (progress - 0.75) / 0.15
		var blink_speed = 5.0 + blink_progress * 10.0 # 逐渐加快闪烁
		var blink_alpha = (sin(current_time * blink_speed) + 1.0) * 0.5 # 0到1的范围
		var final_alpha = 0.175 * (0.175 + blink_alpha * 0.65) # 0.35*0.35到0.35的范围
		warning_shape.modulate = Color(1.0, 0.0, 0.0, final_alpha)
	
	else:
		# 最后0.1秒：渐变消失
		var fade_progress = (progress - 0.9) / 0.1
		var alpha = 0.35 * (1.0 - fade_progress)
		warning_shape.modulate = Color(1.0, 0.0, 0.0, alpha)

func update_warning_shape(current_length: float):
	warning_shape.setup(current_length, width, rect_angle)
	warning_shape.position = Vector2(current_length / 2.0, 0.0).rotated(rect_angle)

func finish_warning():
	"""结束预警，检查伤害"""
	is_warning_active = false
	
	# 确保玩家引用有效（备选：延迟初始化时可能为 null）
	if not player_ref and is_instance_valid(PC.player_instance):
		player_ref = PC.player_instance
	
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
	"""检查玩家是否在矩形AOE范围内（以CollisionShape2D为准）"""
	if not player_ref:
		return false
	
	var hitbox_info = PC.get_player_hitbox_info()
	var player_pos: Vector2
	var player_radius: float = 0.0
	
	if hitbox_info.is_empty() or hitbox_info.get("type") != "circle":
		# fallback：使用玩家节点中心位置
		player_pos = player_ref.global_position
	else:
		player_pos = hitbox_info.get("position", player_ref.global_position)
		player_radius = hitbox_info.get("radius", 0.0)
	
	var relative_pos = player_pos - start_position
	var rotated_pos = relative_pos.rotated(-rect_angle)
	var half_width = width / 2.0
	
	if player_radius <= 0.0:
		return rotated_pos.x >= 0.0 and rotated_pos.x <= rect_length and abs(rotated_pos.y) <= half_width
	
	# 矩形与圆的相交检测：计算矩形上离圆心最近的点
	var closest_x = clampf(rotated_pos.x, 0.0, rect_length)
	var closest_y = clampf(rotated_pos.y, -half_width, half_width)
	var dx = rotated_pos.x - closest_x
	var dy = rotated_pos.y - closest_y
	return dx * dx + dy * dy <= player_radius * player_radius

func deal_damage_to_player():
	"""对玩家造成伤害"""
	if not player_ref or not is_instance_valid(player_ref):
		return
	if PC.invincible:
		return
	
	var actual_damage = int(damage * (1.0 - PC.damage_reduction_rate))
	var hit_source_name := source_name if not source_name.is_empty() else "范围伤害"
	var final_attacker: Node2D = attacker if is_instance_valid(attacker) else self
	PC.player_hit(actual_damage, final_attacker, hit_source_name)
	
	damage_dealt.emit(float(actual_damage))

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
