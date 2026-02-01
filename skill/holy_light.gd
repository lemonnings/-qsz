extends Area2D

@export var sprite : AnimatedSprite2D
@export var collision : CollisionShape2D

var damage: float = 0.0
var heal_base: int = 0
var heal_ratio: float = 0.0
var duration: float = 3.0
var center_extra_damage: float = 0.0
var dot_damage: float = 0.0
var range_scale: float = 1.0

var heal_timer: float = 0.0
var dot_timer: float = 0.0

# 视觉参数
var circle_color = Color(1, 1, 0.6, 0.3) # 浅黄色
var radius: float = 0.0

func setup(pos: Vector2, p_damage: float, p_heal_base: int, p_heal_ratio: float, p_duration: float, p_range_scale: float, options: Dictionary = {}) -> void:
	global_position = pos
	damage = p_damage
	heal_base = p_heal_base
	heal_ratio = p_heal_ratio
	duration = p_duration
	range_scale = p_range_scale
	
	center_extra_damage = options.get("center_extra_damage", 0.0)
	dot_damage = options.get("dot_damage", 0.0)
	
	if not collision:
		collision = get_node_or_null("CollisionShape2D")
	
	if collision and collision.shape is CircleShape2D:
		radius = collision.shape.radius * range_scale + 5 # collision范围+5像素
		# 调整collision scale
		collision.scale = Vector2(range_scale, range_scale)
	else:
		radius = 100.0 * range_scale + 5 # 默认值
	
	# 初始状态
	scale = Vector2.ZERO
	rotation = 0
	
	# 进场动画：从中心点开始逐渐生成，0.5秒内扩大至全部范围
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# 1秒后爆发伤害
	get_tree().create_timer(1.0).timeout.connect(_on_burst)
	
	# 销毁定时器
	get_tree().create_timer(duration).timeout.connect(queue_free)

func _process(delta: float) -> void:
	# 旋转：每2秒旋转360度
	rotation += PI * delta 
	
	# 治疗逻辑 (每秒)
	heal_timer += delta
	if heal_timer >= 1.0:
		heal_timer = 0.0
		_process_heal()
		
	# 持续伤害逻辑 (每秒)
	if dot_damage > 0:
		dot_timer += delta
		if dot_timer >= 1.0:
			dot_timer = 0.0
			_process_dot()
			
	queue_redraw()

func _draw() -> void:
	# 绘制光圈
	# 填充一个透明度是0.3的浅黄色光圈，向外渐变透明
	# 简单模拟：绘制多层不同透明度的圆
	var steps = 10
	for i in range(steps):
		var r = radius * (float(steps - i) / steps)
		var alpha = circle_color.a * (float(i + 1) / steps)
		var color = circle_color
		color.a = alpha * 0.15 # 调整透明度使其叠加后接近目标
		draw_circle(Vector2.ZERO, r, color)
		
	# 绘制最外圈
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, circle_color, 2.0)

func _on_burst() -> void:
	if not is_instance_valid(self):
		return
		
	# 闪烁白光
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(3, 3, 3, 1), 0.1) # 变亮
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.1) # 恢复
	
	# 变为透明度0.4
	circle_color.a = 0.4
	
	# 造成伤害
	var bodies = get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("monster"):
			_deal_damage(body)

func _deal_damage(body: Node2D) -> void:
	var final_damage = damage
	
	# 中心额外伤害
	if center_extra_damage > 0:
		# 判断是否在中心 (例如半径的1/3内)
		var dist = global_position.distance_to(body.global_position)
		if dist < radius * 0.33:
			final_damage *= (1.0 + center_extra_damage)
	
	if body.has_method("on_hit"):
		body.on_hit(final_damage)

func _process_heal() -> void:
	if not is_instance_valid(PC.player_instance):
		return
		
	# 检查玩家是否在范围内
	var dist = global_position.distance_to(PC.player_instance.global_position)
	# 考虑到scale，实际范围需要乘以scale (这里scale已经是1了，因为setup动画结束)
	if dist <= radius:
		var heal_val = heal_base
		if PC.pc_max_hp > 0:
			heal_val += int(PC.pc_max_hp * heal_ratio)
			
		# 应用治疗加成
		heal_val = int(heal_val * (1.0 + PC.heal_multi))
		
		if PC.pc_hp < PC.pc_max_hp:
			PC.pc_hp = min(PC.pc_hp + heal_val, PC.pc_max_hp)
			Global.play_hit_anime(PC.player_instance.global_position, false, 0) # 借用hit anime或者播放治疗音效
			# 可以添加治疗飘字
			var damage_label_scene = preload("res://Scenes/global/damage.tscn")
			var damage_label = damage_label_scene.instantiate()
			get_tree().current_scene.add_child(damage_label)
			damage_label.show_damage_number(2, heal_val, PC.player_instance.global_position) # 2代表治疗

func _process_dot() -> void:
	var bodies = get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("monster"):
			if body.has_method("on_hit"):
				body.on_hit(dot_damage)
