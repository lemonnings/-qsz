extends Node2D
class_name WarnCircleUtil

# 预警圆形/椭圆形AOE工具类
# 用于创建boss技能的范围预警效果

signal warning_finished
signal damage_dealt(damage_amount)
signal area_entered(player_node) # 玩家进入持续区域时触发
signal area_exited(player_node) # 玩家离开持续区域时触发
signal area_effect_triggered(player_node, effect_type) # 玩家接触区域时触发特定效果

# 释放模式枚举
enum ReleaseMode {
	INSTANT_DAMAGE, # 模式1：动画完成后直接判定伤害
	PERSISTENT_AREA # 模式2：动画完成后生成持续区域效果
}

# 预警参数
var aspect_ratio: float = 1.0 # 长宽比，1.0为圆形
var radius: float = 100.0 # 半径
var warning_time: float = 2.0 # 预警时间
var damage: float = 50.0 # 伤害值
var animation_player: AnimationPlayer = null # 预警结束后播放的动画播放器
var release_mode: ReleaseMode = ReleaseMode.INSTANT_DAMAGE # 释放模式
var area_sprite_scene: PackedScene = null # 持续区域显示的精灵场景
var area_duration: float = -1.0 # 持续区域持续时间，-1表示永久
var effect_type: String = "" # 区域效果类型（如"damage", "heal", "slow", "buff"等）

# 内部变量
var warning_shape: Node2D
var current_time: float = 0.0
var is_warning_active: bool = false
var player_ref: Node2D
var persistent_area: Area2D = null # 持续区域节点
var area_sprite: AnimatedSprite2D = null # 区域内的精灵
var area_timer: Timer = null # 区域持续时间计时器
var player_in_area: bool = false # 玩家是否在区域内

func _ready():
	# 设置为可暂停模式，升级等暂停期间动画也会暂停
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
	# 获取玩家引用
	player_ref = get_tree().get_first_node_in_group("player")
	
	# 创建预警形状
	create_warning_shape()

func create_warning_shape():
	var CircleDrawer = preload("res://Script/util/circle_drawer.gd")
	warning_shape = CircleDrawer.new()
	add_child(warning_shape)
	
	# 设置初始参数
	warning_shape.setup(radius, aspect_ratio)
	
	# 初始时不可见
	warning_shape.modulate.a = 0.0

func start_warning(pos: Vector2, _aspect_ratio: float = 1.0, _radius: float = 100.0,
				  _warning_time: float = 2.0, _damage: float = 50.0, _animation_player: AnimationPlayer = null,
				  _release_mode: ReleaseMode = ReleaseMode.INSTANT_DAMAGE, _area_sprite_scene: PackedScene = null,
				  _area_duration: float = -1.0, _effect_type: String = ""):
	# 开始预警
	# pos: 生成位置
	# _aspect_ratio: 长宽比
	# _radius: 半径
	# _warning_time: 预警时间
	# _damage: 伤害值
	# _animation_player: 预警结束后播放的动画播放器
	# _release_mode: 释放模式
	# _area_sprite_scene: 持续区域显示的精灵场景
	# _area_duration: 持续区域持续时间
	# _effect_type: 区域效果类型
	aspect_ratio = _aspect_ratio
	radius = _radius
	warning_time = _warning_time
	damage = _damage
	animation_player = _animation_player
	release_mode = _release_mode
	area_sprite_scene = _area_sprite_scene
	area_duration = _area_duration
	effect_type = _effect_type
	
	# 设置位置
	global_position = pos
	
	# 重置状态
	current_time = 0.0
	is_warning_active = true
	
	# 更新形状
	if warning_shape:
		warning_shape.setup(radius, aspect_ratio)

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
	if not warning_shape:
		return
	
	if progress <= 0.1:
		# 前四分之一时间：从中心向外扩散
		var expand_progress = progress / 0.1
		var current_scale = expand_progress
		warning_shape.scale = Vector2(current_scale, current_scale)
		warning_shape.modulate = Color(1.0, 0.0, 0.0, 0.35) # 红色，透明度0.35
	
	elif progress <= 0.65:
		# 中间时间：保持稳定
		warning_shape.scale = Vector2(1.0, 1.0)
		warning_shape.modulate = Color(1.0, 0.0, 0.0, 0.35)
	
	elif progress <= 0.8:
		# 开始闪烁阶段：缩短闪烁时间
		var blink_progress = (progress - 0.65) / 0.15
		var blink_speed = 3.0 + blink_progress * 6.0 # 逐渐加快闪烁
		var blink_alpha = (sin(current_time * blink_speed) + 1.0) * 0.5 # 0到1的范围
		# 修正透明度计算：在0.2到0.35之间闪烁，避免过暗
		var final_alpha = 0.2 + blink_alpha * 0.15
		warning_shape.modulate = Color(1.0, 0.0, 0.0, final_alpha)
	
	else:
		# 最后0.1秒：渐变消失
		var fade_progress = (progress - 0.9) / 0.1
		var alpha = 0.2 * (1.0 - fade_progress)
		warning_shape.modulate = Color(1.0, 0.0, 0.0, alpha)

func finish_warning():
	is_warning_active = false
	
	# 播放动画（如果有）
	if animation_player != null:
		play_animation()
	
	# 隐藏预警形状
	if warning_shape:
		warning_shape.visible = false
	
	# 根据释放模式执行不同逻辑
	if release_mode == ReleaseMode.INSTANT_DAMAGE:
		# 模式1：直接判定伤害
		if player_ref and is_player_in_range():
			deal_damage_to_player()
	else:
		# 模式2：创建持续区域效果
		create_persistent_area()
	
	# 发送信号
	warning_finished.emit()

func is_player_in_range() -> bool:
	if not player_ref:
		return false
	
	var distance_to_player = global_position.distance_to(player_ref.global_position)
	
	# 对于椭圆形，需要考虑长宽比
	if aspect_ratio != 1.0:
		# 简化处理：将玩家位置转换到标准圆形坐标系
		var relative_pos = player_ref.global_position - global_position
		var normalized_x = relative_pos.x / aspect_ratio
		var normalized_distance = Vector2(normalized_x, relative_pos.y).length()
		return normalized_distance <= radius
	else:
		# 圆形直接比较距离
		return distance_to_player <= radius

func deal_damage_to_player():
	if not player_ref or not is_instance_valid(player_ref):
		return
	
	# 检查无敌状态
	if PC.invincible:
		return
	
	# 触发受击效果
	Global.emit_signal("player_hit")
	
	# 计算实际伤害（考虑减伤率）
	var actual_damage = int(damage * (1.0 - PC.damage_reduction_rate))
	PC.apply_damage(actual_damage)
	
	print("圆形AOE对玩家造成伤害: ", actual_damage)
	
	# 检查死亡
	if PC.pc_hp <= 0:
		PC.player_instance.game_over()
	
	damage_dealt.emit(float(actual_damage))

func play_animation():
	# 这里可以根据具体需求实现动画播放逻辑
	# 例如：创建爆炸效果、震屏等
	if animation_player != null and is_instance_valid(animation_player):
		animation_player.play()

func create_persistent_area():
	"""创建持续区域效果"""
	# 创建Area2D节点
	persistent_area = Area2D.new()
	add_child(persistent_area)
	
	# 创建碰撞形状
	var collision_shape = CollisionShape2D.new()
	var shape: Shape2D
	
	if aspect_ratio == 1.0:
		# 圆形
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = radius
		shape = circle_shape
	else:
		# 椭圆形（使用矩形近似）
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(radius * 2 * aspect_ratio, radius * 2)
		shape = rect_shape
	
	collision_shape.shape = shape
	persistent_area.add_child(collision_shape)
	
	# 连接信号
	persistent_area.body_entered.connect(_on_area_body_entered)
	persistent_area.body_exited.connect(_on_area_body_exited)
	
	# 创建区域精灵（如果提供了场景）
	if area_sprite_scene != null:
		var sprite_instance = area_sprite_scene.instantiate()
		persistent_area.add_child(sprite_instance)
		# 从实例化的场景中查找AnimatedSprite2D节点
		area_sprite = sprite_instance.get_node_or_null("AnimatedSprite2D")
		if area_sprite == null:
			# 如果没有找到AnimatedSprite2D，尝试查找第一个AnimatedSprite2D子节点
			for child in sprite_instance.get_children():
				if child is AnimatedSprite2D:
					area_sprite = child
					break
		# 如果是AnimatedSprite2D，调整缩放以匹配红圈大小
		if area_sprite != null and area_sprite is AnimatedSprite2D:
			# AnimatedSprite2D纹理是64x64像素，但实际图像约58x58像素
			# 红圈直径是radius*2，使用实际图像大小58作为基准
			var sprite_scale = (radius * 2.0) / 54.0
			area_sprite.scale = Vector2(sprite_scale * aspect_ratio, sprite_scale)
			# 设置初始透明度为0，准备渐显动画
			area_sprite.modulate.a = 0.0
			area_sprite.play()
			# 创建渐显动画
			var fade_tween = create_tween()
			fade_tween.tween_property(area_sprite, "modulate:a", 1.0, 0.1)
	
	# 设置持续时间（如果不是永久）
	if area_duration > 0:
		area_timer = Timer.new()
		area_timer.wait_time = area_duration
		area_timer.one_shot = true
		area_timer.timeout.connect(_on_area_timeout)
		add_child(area_timer)
		area_timer.start()

func _on_area_body_entered(body: Node2D):
	"""玩家进入区域"""
	if body == player_ref and not player_in_area:
		player_in_area = true
		area_entered.emit(body)
		# 触发特定效果信号
		if effect_type != "":
			area_effect_triggered.emit(body, effect_type)

func _on_area_body_exited(body: Node2D):
	"""玩家离开区域"""
	if body == player_ref and player_in_area:
		player_in_area = false
		area_exited.emit(body)

func _on_area_timeout():
	"""区域持续时间结束"""
	destroy_persistent_area()

func destroy_persistent_area():
	"""销毁持续区域"""
	if persistent_area:
		persistent_area.queue_free()
		persistent_area = null
	if area_sprite:
		area_sprite = null
	if area_timer:
		area_timer.queue_free()
		area_timer = null
	player_in_area = false

func cleanup():
	is_warning_active = false
	destroy_persistent_area()
	if warning_shape:
		warning_shape.queue_free()
	queue_free()
