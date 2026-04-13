extends Area2D

@export var sprite: AnimatedSprite2D
@export var collision_shape: CollisionShape2D

# 基础属性
var damage: float = 0.0
var speed: float = 320.0 # 子弹飞行速度
var range_val: float = 300.0
var penetration_count: int = 0
var pierce_decay: float = 0.3 # 每次穿透降低30%
var duration: float = 0.0 # 根据射程和速度计算
var elapsed: float = 0.0

# 状态效果
var apply_light_accumulation: bool = false # 蓄光debuff
var accumulation_max_stacks_bonus: int = 0 # 蓄光上限加成

# 内部变量
var start_position: Vector2
var velocity: Vector2
var hit_targets: Dictionary = {}
var travelled_distance: float = 0.0
var reached_max_range: bool = false
var fade_out_duration: float = 0.4
var base_sprite_scale: Vector2 = Vector2.ONE
var base_collision_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	if not sprite:
		sprite = get_node_or_null("AnimatedSprite2D")
	if not collision_shape:
		collision_shape = get_node_or_null("CollisionShape2D")
	if sprite:
		base_sprite_scale = sprite.scale
	if collision_shape:
		base_collision_scale = collision_shape.scale
	
	if sprite:
		sprite.play("default")
		
	# 连接 area_entered 信号
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func setup_light_bullet(pos: Vector2, dir: Vector2, p_damage: float, p_range: float, p_penetration: int, options: Dictionary = {}) -> void:
	global_position = pos
	start_position = pos
	rotation = dir.angle()
	velocity = dir.normalized() * speed
	
	# 伤害仅由奖励直接累加（main_skill_light_bullet_damage），法则加成已在_build_light_bullet_data中累加
	var life_range_multiplier = Faze.get_life_range_multiplier(PC.faze_life_level)
	var bullet_range_multiplier = Faze.get_bullet_range_multiplier(PC.faze_bullet_level)
	damage = p_damage
	range_val = p_range * life_range_multiplier * bullet_range_multiplier * Global.get_attack_range_multiplier()
	penetration_count = p_penetration
	if sprite:
		sprite.scale = base_sprite_scale * Global.get_attack_range_multiplier()
	if collision_shape:
		collision_shape.scale = base_collision_scale * Global.get_attack_range_multiplier()
	
	# 读取特殊选项
	apply_light_accumulation = options.get("apply_light_accumulation", false)
	accumulation_max_stacks_bonus = options.get("accumulation_max_stacks_bonus", 0)
	
	duration = range_val / speed

func _process(delta: float) -> void:
	elapsed += delta
	if reached_max_range:
		modulate.a -= delta / fade_out_duration
		if modulate.a <= 0.0:
			queue_free()
		return
	
	travelled_distance += speed * delta
	position += velocity * delta
	
	if travelled_distance > range_val * 0.9:
		var fade_ratio = (travelled_distance - range_val * 0.9) / (range_val * 0.1)
		modulate.a = 1.0 - fade_ratio
	
	if travelled_distance >= range_val:
		reached_max_range = true
		velocity = Vector2.ZERO
		collision_shape.disabled = true

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies"):
		var enemy_id = area.get_instance_id()
		if hit_targets.has(enemy_id):
			return
		hit_targets[enemy_id] = true
		
		_deal_damage(area)
		Faze.on_bullet_hit()
		
		if penetration_count > 0:
			penetration_count -= 1
			damage *= (1.0 - pierce_decay)
		else:
			queue_free()

func _deal_damage(enemy: Area2D) -> void:
	var final_damage = damage
	var is_crit = false
	
	if randf() < PC.crit_chance:
		is_crit = true
		final_damage *= PC.crit_damage_multi
	
	# 如果是光弹伤害，需要考虑蓄光debuff的增伤
	# 但蓄光debuff是增加受到的光弹伤害，这个逻辑应该在 enemy_debuff_manager.gd 中处理
	# 这里只需要确保 enemy_debuff_manager 能够识别伤害来源或者伤害类型
	# 或者我们手动计算增伤？
	# 查看 enemy_debuff_manager.gd，damage_taken_multiplier 是通用的。
	# 但题目描述是“每层提升其受到光弹伤害5%”。这意味着只对光弹有效。
	# 这是一个特殊的增伤。
	# 我们可以检查敌人是否有 light_accumulation debuff，如果有，增加本次伤害。
	
	if enemy.get("debuff_manager") and enemy.debuff_manager.has_method("has_debuff"):
		if enemy.debuff_manager.has_debuff("light_accumulation"):
			var stacks = enemy.debuff_manager.active_debuffs["light_accumulation"]["stacks"]
			final_damage *= (1.0 + stacks * 0.05)
	
	# Apply final total damage multiplier
	if PC.light_bullet_final_damage_multi > 1.0:
		final_damage *= PC.light_bullet_final_damage_multi
	
	if enemy.has_method("take_damage"):
		enemy.take_damage(int(final_damage), is_crit, false, "light_bullet")
		# 击中粒子崩散特效
		HitParticleSpawner.spawn_by_weapon(get_tree(), enemy.global_position, "light_bullet")
		
	# 施加蓄光debuff
	if apply_light_accumulation:
		if enemy.get("debuff_manager") and enemy.debuff_manager.has_method("add_debuff"):
			enemy.debuff_manager.add_debuff("light_accumulation", accumulation_max_stacks_bonus)
