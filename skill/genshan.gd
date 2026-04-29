extends Area2D
class_name Genshan

@export var sprite: AnimatedSprite2D
@export var collision: CollisionShape2D

static var main_skill_genshan_damage: float = 1.2
static var genshan_final_damage_multi: float = 1.0
static var genshan_range: float = 230.0

static func reset_data() -> void:
	main_skill_genshan_damage = 1.2
	genshan_final_damage_multi = 1.0
	genshan_range = 230.0
	enemy_hit_records.clear()

# 基础属性
var damage: float = 0.0
var range_val: float = 230.0
var total_damage_multiplier: float = 1.0 # 用于降低总伤害（连山/连山-崩山）

# 渐进式生成相关
var direction: Vector2 = Vector2.RIGHT
var current_length: float = 0.0
var step_length: float = 0.1 # 每3像素生成一个sprite
var spawn_timer: float = 0.0
var spawn_interval: float = 0.3 # 0.3秒后生成下一个
var is_spawning: bool = true

# 伤害判定相关
var hit_targets: Dictionary = {}
var duration: float = 0.5 # 技能存在总时间（伸长后停留一会）
var elapsed: float = 0.0

# 视觉相关
var created_sprites: Array = []
var base_sprite_size: Vector2 = Vector2(44, 51)
var sprite_fade_in_time: float = 0.1
var sprite_sustain_time: float = 0.55
var sprite_fade_out_time: float = 0.15
var base_scale_val: float = 1.0 # 基础 scale，来自 setup
var has_applied_shield: bool = false

var can_apply_shield: bool = false # 控制当前实例是否可以施加护盾

# 静态变量记录敌人受伤时间戳 {enemy_id: [timestamp1, timestamp2, ...]}
static var enemy_hit_records: Dictionary = {}

# 静态方法处理发射逻辑
static func fire_skill(scene: PackedScene, origin_pos: Vector2, tree: SceneTree) -> void:
	if not scene:
		return
		
	# 基础方向：左右
	var directions = [Vector2.LEFT, Vector2.RIGHT]
	var dmg_multi = 1.0
	
	# Genshan1 (连山): 增加上下，总伤害降低30%
	if PC.selected_rewards.has("Genshan1"):
		directions.append(Vector2.UP)
		directions.append(Vector2.DOWN)
		dmg_multi *= 0.75
		
	# Genshan22 (连山-崩山): 四个斜向，总伤害额外降低30%
	if PC.selected_rewards.has("Genshan22"):
		# 四个斜向：左上，右上，左下，右下
		directions.append(Vector2(-1, -1).normalized())
		directions.append(Vector2(1, -1).normalized())
		directions.append(Vector2(-1, 1).normalized())
		directions.append(Vector2(1, 1).normalized())
		dmg_multi *= 0.75
	
	# 只有第一个生成的实例可以施加护盾
	var is_first = true
	for dir in directions:
		_spawn_genshan(scene, tree, origin_pos, dir, dmg_multi, is_first)
		is_first = false

static func _spawn_genshan(scene: PackedScene, tree: SceneTree, origin_pos: Vector2, dir: Vector2, multiplier: float, should_apply_shield: bool) -> void:
	var instance = scene.instantiate()
	tree.current_scene.add_child(instance)
	
	var spawn_damage = PC.pc_atk * main_skill_genshan_damage * genshan_final_damage_multi
	
	# 八卦法则伤害加成
	spawn_damage *= Faze.get_bagua_damage_multiplier()
	
	# 从全局攻击范围倍率获取基础 scale
	var base_scale = Global.get_attack_range_multiplier()
	
	instance.setup(origin_pos, dir, spawn_damage, genshan_range * Global.get_attack_range_multiplier(), multiplier, base_scale, should_apply_shield)

func setup(pos: Vector2, dir: Vector2, p_damage: float, p_range: float, p_multiplier: float, p_base_scale: float, p_can_apply_shield: bool) -> void:
	global_position = pos
	direction = dir.normalized()
	damage = p_damage
	range_val = p_range
	total_damage_multiplier = p_multiplier
	base_scale_val = p_base_scale # 新增变量存储 base_scale
	can_apply_shield = p_can_apply_shield
	
	# rotation = direction.angle() # 取消旋转，使用原始方向
	
	# 设置碰撞体初始状态
	if collision:
		# 使用 RectangleShape2D，初始长度很小
		var rect = RectangleShape2D.new()
		rect.size = Vector2(1, 51) # 初始宽度1
		collision.shape = rect
		collision.position = Vector2(0.5, 0)
		collision.rotation = direction.angle() # 碰撞体仍然需要旋转以匹配攻击方向
	
	# 生成第一个 sprite
	_add_next_sprite()

func _ready() -> void:
	if sprite:
		sprite.visible = false # 隐藏模板sprite
	connect("area_entered", Callable(self , "_on_area_entered"))

func _process(delta: float) -> void:
	elapsed += delta
	
	# 处理生成的 sprite 动画
	var active_sprites = 0
	for s_data in created_sprites:
		var s = s_data["sprite"]
		var t = s_data["time"]
		
		s_data["time"] += delta
		
		# 渐显 0.1s
		if t < sprite_fade_in_time:
			s.modulate.a = t / sprite_fade_in_time
		# 持续 0.5s (0.1 ~ 0.6)
		elif t < sprite_fade_in_time + sprite_sustain_time:
			s.modulate.a = 1.0
		# 渐隐 0.1s (0.6 ~ 0.7)
		elif t < sprite_fade_in_time + sprite_sustain_time + sprite_fade_out_time:
			var fade_t = t - (sprite_fade_in_time + sprite_sustain_time)
			s.modulate.a = 1.0 - (fade_t / sprite_fade_out_time)
		else:
			s.modulate.a = 0.0
			s.visible = false
			
		if s.visible:
			active_sprites += 1
			
	# 生成逻辑
	if is_spawning:
		spawn_timer += delta
		if spawn_timer >= spawn_interval:
			spawn_timer = 0.0
			_add_next_sprite()
			
	# 更新碰撞体范围
	# 碰撞体应该跟随生成的sprite延伸
	if collision and collision.shape is RectangleShape2D:
		collision.shape.size.x = current_length
		# 碰撞体的位置也需要根据 direction 设置
		# collision.rotation 已经设置好了，所以 collision.position 应该是沿着 direction 延伸一半长度
		# 但是如果 collision.rotation 已经设置了，那么 collision 的局部坐标系的 x 轴已经对齐了 direction
		# 所以如果 collision 是 Area2D 的子节点，且 Area2D 没有旋转
		# 那么 collision.position 设置为 direction * (current_length / 2.0) 是错误的，这会产生双重旋转效果（位置旋转+本身旋转）
		# 等等，如果 collision.rotation = direction.angle()，那么 collision 的局部 x 轴指向 direction
		# 此时 collision.position 应该是相对于 Area2D 原点的偏移。
		# 我们希望 collision 的中心点位于 0 到 current_length 的中点。
		# 这个中点的世界坐标偏移是 direction * (current_length / 2.0)。
		# 所以 collision.position 应该是 direction * (current_length / 2.0)。
		collision.position = direction * (current_length / 2.0)
	
	# 如果所有 sprite 都消失了，且不再生成，则销毁自身
	if not is_spawning and active_sprites == 0:
		queue_free()

func _add_next_sprite() -> void:
	# 下一个位置：上一个位置 + (sprite宽度 * scale) + 3 (间隔) ?
	# 硬编码的原始比例
	var hardcoded_scale = Vector2(3.265, 1.44)
	# 原始宽度 43 (假设是 texture 宽度，或者 base_sprite_size.x)
	var _base_width = 43.0
	
	# 如果是第一次生成
	if created_sprites.is_empty():
		# 第一个 sprite，scale = hardcoded_scale * 0.4 * base_scale_val
		var current_scale_multiplier = 0.35
		var final_scale = hardcoded_scale * current_scale_multiplier * base_scale_val
		
		# 计算实际宽度: 43.0 * current_scale_multiplier * base_scale_val
		var current_length_segment = 43.0 * current_scale_multiplier * base_scale_val
		var half_width = current_length_segment / 2.0
		
		_create_sprite_at(half_width, final_scale) # 中心点
		current_length = current_length_segment
	else:
		# 下一个 sprite 的 scale
		var spawn_index = created_sprites.size()
		var current_scale_multiplier = 0.35 + spawn_index * 0.175
		var final_scale = hardcoded_scale * current_scale_multiplier * base_scale_val
		
		var current_length_segment = 43.0 * current_scale_multiplier * base_scale_val
		
		# 下一个位置
		var next_center = current_length + 3.0 + (current_length_segment / 2.0)
		var next_end = current_length + 3.0 + current_length_segment
		
		if next_end <= range_val + (current_length_segment / 2.0): # 允许稍微超出
			_create_sprite_at(next_center, final_scale)
			current_length = next_end
		else:
			# 停止生成
			is_spawning = false

func _create_sprite_at(local_x: float, p_scale: Vector2) -> void:
	if not sprite:
		return
		
	var s = sprite.duplicate()
	add_child(s)
	s.visible = true
	
	# 根据 direction 设置位置
	# 如果不旋转容器，则需要手动旋转位置向量
	# direction 是归一化的方向向量
	s.position = direction * local_x
	
	s.modulate.a = 0.0 # 初始透明
	
	# 设置 scale
	s.scale = p_scale
	
	# 设置 offset 以实现底部锚点
	# base_sprite_size.y 是 51.0
	# offset.y = -25.5，这样 (0,0) 对应底部中心
	s.offset = Vector2(0, -base_sprite_size.y / 2.0)
	
	# 空间上的渐隐：距离终点最后10%
	# 这里我们在动画update里处理透明度，但也需要考虑位置带来的透明度上限
	# 如果在最后10%区域，最大透明度降低
	var max_alpha = 1.0
	if local_x > range_val * 0.9:
		var fade_ratio = (local_x - range_val * 0.9) / (range_val * 0.1)
		max_alpha = 1.0 - fade_ratio
		
	created_sprites.append({"sprite": s, "time": 0.0, "max_alpha": max_alpha})

# 覆盖 _process 中的透明度逻辑
# 修改上面的 _process

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies"):
		var enemy_id = area.get_instance_id()
		if hit_targets.has(enemy_id):
			return
		hit_targets[enemy_id] = true
		
		_deal_damage(area)

func _deal_damage(enemy: Area2D) -> void:
	# 检查伤害频率限制
	var enemy_id = enemy.get_instance_id()
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# 确定伤害限制次数
	var max_hits = 2
	if PC.selected_rewards.has("Genshan1"):
		max_hits = 4
	if PC.selected_rewards.has("Genshan22"):
		max_hits = 6
		
	# 初始化或清理记录
	if not enemy_hit_records.has(enemy_id):
		enemy_hit_records[enemy_id] = []
	
	# 移除1秒以前的记录
	var new_records = []
	for t in enemy_hit_records[enemy_id]:
		if current_time - t <= 1.0:
			new_records.append(t)
	
	if new_records.size() >= max_hits:
		# 达到上限，本次不造成伤害
		enemy_hit_records[enemy_id] = new_records # 更新清理后的记录
		return
		
	# 记录本次伤害
	new_records.append(current_time)
	enemy_hit_records[enemy_id] = new_records
	
	var final_damage = damage * total_damage_multiplier
	var is_crit = false
	
	# 暴击判定
	if randf() < PC.crit_chance:
		is_crit = true
		final_damage *= PC.crit_damage_multi
		
	# Genshan3 (崩山): 精英，首领及血量低于30%额外50%伤害
	if PC.selected_rewards.has("Genshan3"):
		var is_elite_or_boss = enemy.is_in_group("boss") or enemy.is_in_group("elite")
		var low_hp = false
		if enemy.has_method("get_hp_percent"):
			low_hp = enemy.get_hp_percent() < 0.3
		elif "hp" in enemy and "max_hp" in enemy:
			low_hp = (float(enemy.hp) / float(enemy.max_hp)) < 0.3
			
		if is_elite_or_boss or low_hp:
			final_damage *= 1.5
			
	# Genshan33 (震山-崩山): 对脆弱状态敌人额外50%伤害
	if PC.selected_rewards.has("Genshan33"):
		if enemy.get("debuff_manager") and enemy.debuff_manager.has_method("has_debuff"):
			if enemy.debuff_manager.has_debuff("vulnerable"):
				final_damage *= 1.5
	
	# 应用伤害
	if enemy.has_method("take_damage"):
		enemy.take_damage(int(final_damage), is_crit, false, "genshan")
		# 击中粒子崩散特效
		HitParticleSpawner.spawn_by_weapon(get_tree(), enemy.global_position, "genshan")
		# 艮山震屏
		GU.screen_shake(2.0, 0.1)
		
		# 八卦法则推衍度
		Faze.add_bagua_progress(1, enemy.is_in_group("elite") or enemy.is_in_group("boss"))
		if not is_instance_valid(enemy) or enemy.hp <= 0:
			Faze.add_bagua_progress(5, enemy.is_in_group("elite") or enemy.is_in_group("boss"))
		
	# Genshan2 (震山): 施加脆弱
	if PC.selected_rewards.has("Genshan2"):
		if enemy.get("debuff_manager") and enemy.debuff_manager.has_method("add_debuff"):
			enemy.debuff_manager.add_debuff("vulnerable", 4.0)
			
	# Genshan4 (护山): 获得护盾
	if PC.selected_rewards.has("Genshan4"):
		_apply_shield()

func _apply_shield() -> void:
	if not can_apply_shield:
		return
	if has_applied_shield:
		return
	has_applied_shield = true
	
	var base_shield = 60
	var hp_ratio = 0.03
	var shield_duration = 7.0
	
	# Genshan11 (震山-护山): 护盾提升50%，持续10秒
	if PC.selected_rewards.has("Genshan11"):
		base_shield = int(base_shield * 1.5)
		hp_ratio *= 1.5
		shield_duration = 10.0
		
	var shield_val = base_shield + (PC.pc_max_hp * hp_ratio)
	PC.add_shield(int(shield_val), shield_duration)
