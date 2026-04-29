extends Area2D

@export var sprite: AnimatedSprite2D
@export var collision_shape: CollisionShape2D

# 鸣雷属性
var damage: float = 0.0
var duration: float = 0.4
var elapsed: float = 0.0
var elite_bonus: float = 0.0 # 精英/首领额外伤害倍率

# 内部变量
var hit_targets: Dictionary = {}

func _ready() -> void:
	if not sprite:
		sprite = get_node_or_null("AnimatedSprite2D")
	if not collision_shape:
		collision_shape = get_node_or_null("CollisionShape2D")
	
	# 连接碰撞信号
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	elapsed += delta
	
	# 动画结束后淡出
	if elapsed > duration * 0.6:
		var fade_t = (elapsed - duration * 0.6) / (duration * 0.4)
		modulate.a = 1.0 - fade_t
	
	if elapsed >= duration:
		ObjectPool.recycle(self )

func setup_thunder_strike(pos: Vector2, p_damage: float, p_elite_bonus: float) -> void:
	global_position = pos
	damage = p_damage
	elite_bonus = p_elite_bonus
	elapsed = 0.0
	hit_targets.clear()
	modulate.a = 1.0
	
	# 播放动画
	if sprite:
		sprite.frame = 0
		sprite.play("default")
	
	# 立即检测重叠敌人
	call_deferred("_check_overlapping_enemies")

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
	var is_elite = enemy.is_in_group("elite")
	var is_boss = enemy.is_in_group("boss")
	
	var final_damage = damage
	
	# 精英/首领额外伤害
	if (is_elite or is_boss) and elite_bonus > 0.0:
		final_damage *= (1.0 + elite_bonus)
	
	# 应用八卦法则加成
	final_damage *= Faze.get_bagua_damage_multiplier()
	
	# 暴击判定
	var is_crit = false
	if randf() < PC.crit_chance:
		is_crit = true
		final_damage *= PC.crit_damage_multi
	
	# 应用伤害
	if enemy.has_method("take_damage"):
		enemy.take_damage(int(final_damage), is_crit, false, "faze_thunder_strike")
		HitParticleSpawner.spawn_by_weapon(get_tree(), enemy.global_position, "thunder")

## 对象池重置：清除状态供复用
func reset_for_pool() -> void:
	damage = 0.0
	elapsed = 0.0
	elite_bonus = 0.0
	hit_targets.clear()
	modulate.a = 1.0
	global_position = Vector2.ZERO
	if sprite:
		sprite.stop()
		sprite.frame = 0
