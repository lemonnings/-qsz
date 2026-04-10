extends Area2D

@export var sprite: AnimatedSprite2D
@export var collision_shape: CollisionShape2D

# 基础属性
var damage: float = 0.0
var range_val: float = 200.0
var width: float = 40.0
var duration: float = 0.5 # 视觉持续时间
var elapsed: float = 0.0

# 特殊效果标志
var is_infinite_range: bool = false
var damage_drop_after_400: bool = false # ThunderBreak11: >400距离伤害减半
var crit_after_180: bool = false # ThunderBreak22: >180距离必定暴击
var apply_electrified: bool = false # ThunderBreak3: 感电
var damage_distance_bonus: bool = false # ThunderBreak4: 距离每10伤害+2%
var apply_vulnerable: bool = false # ThunderBreak33: 脆弱

# 内部变量
var hit_targets: Dictionary = {}
var created_sprites: Array = []
var base_scale: Vector2 = Vector2(1.24, 1.32)
var default_width: float = 40.0

func _ready() -> void:
	if not sprite:
		sprite = get_node_or_null("AnimatedSprite2D")
	if not collision_shape:
		collision_shape = get_node_or_null("CollisionShape2D")
	
	# 连接 area_entered 信号
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
		
	# 如果没有setup被调用（例如直接在场景中测试），使用默认值初始化
	if created_sprites.is_empty() and sprite:
		_update_visuals()
		_update_collision()

func _process(delta: float) -> void:
	elapsed += delta
	
	# 渐隐效果 (最后20%的时间)
	if elapsed > duration * 0.8:
		var fade_t = (elapsed - duration * 0.8) / (duration * 0.2)
		modulate.a = 1.0 - fade_t
	
	if elapsed >= duration:
		queue_free()

func setup_thunder_break(pos: Vector2, dir: Vector2, p_damage: float, p_range: float, p_width: float, options: Dictionary = {}) -> void:
	global_position = pos
	rotation = dir.angle()
	damage = p_damage
	range_val = p_range
	width = p_width
	
	# 读取特殊选项
	is_infinite_range = options.get("infinite_range", false)
	damage_drop_after_400 = options.get("damage_drop_after_400", false)
	crit_after_180 = options.get("crit_after_180", false)
	apply_electrified = options.get("apply_electrified", false)
	damage_distance_bonus = options.get("damage_distance_bonus", false)
	apply_vulnerable = options.get("apply_vulnerable", false)
	
	if is_infinite_range:
		range_val = 2000.0 # 地图最大长度
		
	_update_visuals()
	_update_collision()
	
	# 立即检测当前重叠的敌人
	call_deferred("_check_overlapping_enemies")

func _update_visuals() -> void:
	if not sprite:
		return
		# === 清理之前创建的所有视觉子节点 ===
	for child in created_sprites:
		if is_instance_valid(child):
			child.queue_free()
	created_sprites.clear()

	# 同样清理之前可能存在的 glow 线条（可选：如果你知道它们名字）
	# 或者更通用：清理所有 Line2D（如果你确定只有 glow 用 Line2D）
	for child in get_children():
		if child is Line2D:
			child.queue_free()

	# === 重新隐藏模板 sprite ===
	sprite.visible = false
	
	# 计算缩放比例
	# 宽度提升，scale也等比提升
	var scale_ratio = width / default_width
	var final_scale = base_scale * scale_ratio
	
	# 步长：假设base_scale对应50像素的步长，如果scale变大，步长也变大
	# 用户描述：长度280是5.6个sprite -> 280/5.6 = 50
	var stride = 35.0 * scale_ratio
	
	var num_sprites = ceil(range_val / stride)
	
	for i in range(num_sprites):
		var s = sprite.duplicate()
		s.visible = true
		s.scale = final_scale
		s.position = Vector2(i * stride + stride * 0.5, 0)
		s.play("default") # 确保播放动画
		add_child(s)
		created_sprites.append(s)
		
		# 直线末端10%渐隐
		var sprite_end_dist = (i + 1) * stride
		if sprite_end_dist > range_val * 0.95:
			# 简单的末端透明度处理
			s.modulate.a = 0.6
			
	# 添加蓝白色光线边缘提示
	_add_edge_glow()

func _add_edge_glow() -> void:
	var line_color = Color(0.5, 0.8, 1.0, 0.5) # 蓝白色，带透明度
	var line_width = 3.5
	
	# 上边缘
	var upper_line = Line2D.new()
	upper_line.points = [Vector2(0, -width / 2), Vector2(range_val + 10, -width / 2)]
	upper_line.default_color = line_color
	upper_line.width = line_width
	add_child(upper_line)
	
	# 下边缘
	var lower_line = Line2D.new()
	lower_line.points = [Vector2(0, width / 2), Vector2(range_val + 10, width / 2)]
	lower_line.default_color = line_color
	lower_line.width = line_width
	add_child(lower_line)
	
	# 创建渐隐动画
	var tween = create_tween()
	tween.set_loops() # 循环播放
	tween.tween_property(upper_line, "modulate:a", 0.2, 0.25).from(0.6)
	tween.tween_property(upper_line, "modulate:a", 0.6, 0.25)
	
	var tween2 = create_tween()
	tween2.set_loops()
	tween2.tween_property(lower_line, "modulate:a", 0.2, 0.25).from(0.6)
	tween2.tween_property(lower_line, "modulate:a", 0.6, 0.25)

func _update_collision() -> void:
	if not collision_shape:
		return
		
	var rect = RectangleShape2D.new()
	rect.size = Vector2(range_val, width)
	collision_shape.shape = rect
	
	# 碰撞体中心在 (range/2, 0)
	collision_shape.position = Vector2(range_val * 0.5, 0)

func _check_overlapping_enemies() -> void:
	var areas = get_overlapping_areas()
	for area in areas:
		_on_area_entered(area)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies"):
		var enemy_id = area.get_instance_id()
		if hit_targets.has(enemy_id):
			return
		hit_targets[enemy_id] = true
		
		_deal_damage(area)

func _deal_damage(enemy: Area2D) -> void:
	var dist = global_position.distance_to(enemy.global_position)
	
	# 法则伤害加成累加（不是乘法），避免奖励加成 × 法则加成的双重叠加
	var law_bonus = 0.0
	law_bonus += (Faze.get_destroy_damage_multiplier(PC.faze_destroy_level) - 1.0) # 破坏法则
	law_bonus += (Faze.get_thunder_weapon_damage_multiplier(PC.faze_thunder_level) - 1.0) # 雷鸣法则
	var final_damage = damage * (1.0 + law_bonus)
	
	if enemy.get("debuff_manager") and enemy.debuff_manager.has_method("has_debuff"):
		if enemy.debuff_manager.has_debuff("electrified"):
			final_damage *= (1.0 + Faze.get_thunder_damage_vs_electrified_bonus(PC.faze_thunder_level))
	
	var is_crit = false
	
	# 计算暴击
	var crit_data = Faze.apply_destroy_crit_overflow(PC.crit_chance, PC.crit_damage_multi, PC.faze_destroy_level)
	var crit_chance = crit_data["crit_chance"]
	var crit_multiplier = crit_data["crit_multi"]
	if randf() < crit_chance:
		is_crit = true
	
	# 特殊效果处理
	
	# ThunderBreak4: 距离每100伤害+2%	
	if damage_distance_bonus:
		var bonus_stacks = floor(dist / 10.0)
		final_damage *= (1.0 + bonus_stacks * 0.02)
		
	# ThunderBreak11: 超过400距离伤害降低50%
	if damage_drop_after_400 and dist > 400:
		final_damage *= 0.5
		
	# ThunderBreak22: 超过180距离必定暴击
	if crit_after_180 and dist > 180:
		is_crit = true
	
	if is_crit:
		crit_multiplier *= Faze.get_destroy_crit_fluctuation_multiplier(PC.faze_destroy_level)
		final_damage *= crit_multiplier
		
	# Apply final total damage multiplier
	if PC.thunder_break_final_damage_multi > 1.0:
		final_damage *= PC.thunder_break_final_damage_multi
		
	# 应用伤害
	if enemy.has_method("take_damage"):
		enemy.take_damage(int(final_damage), is_crit, false, "thunder_break")
		# 击中粒子崩散特效
		HitParticleSpawner.spawn_by_weapon(get_tree(), enemy.global_position, "thunderbreak")
		
	# 应用状态效果
	if apply_electrified:
		if enemy.has_method("apply_debuff_effect"):
			enemy.apply_debuff_effect("electrified")
		elif enemy.get("debuff_manager") and enemy.debuff_manager.has_method("add_debuff"):
			enemy.debuff_manager.add_debuff("electrified")
			
	if apply_vulnerable:
		if enemy.has_method("apply_debuff_effect"):
			enemy.apply_debuff_effect("vulnerable")
		elif enemy.get("debuff_manager") and enemy.debuff_manager.has_method("add_debuff"):
			enemy.debuff_manager.add_debuff("vulnerable")
