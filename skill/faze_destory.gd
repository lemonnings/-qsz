extends Area2D

@export var sprite: AnimatedSprite2D
@export var collision_shape: CollisionShape2D

# 引爆属性
var damage: float = 0.0
var can_crit: bool = true
var destroy_level: int = 0
var damage_dealt: bool = false
var _elapsed: float = 0.0
var _base_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	if not sprite:
		sprite = get_node_or_null("AnimatedSprite2D")
	if not collision_shape:
		collision_shape = get_node_or_null("CollisionShape2D")
	_base_scale = scale

func setup_detonation(pos: Vector2, p_damage: float, p_can_crit: bool, p_destroy_level: int) -> void:
	global_position = pos
	damage = p_damage
	can_crit = p_can_crit
	destroy_level = p_destroy_level
	damage_dealt = false
	_elapsed = 0.0
	scale = _base_scale
	modulate.a = 1.0
	
	# 16阶: 在原有scale基础上 *2.25
	if destroy_level >= 16:
		scale *= 2.25
	
	# 播放动画
	if sprite:
		sprite.play("default")
	
	# 0.3秒后进行伤害判定（适配动画节奏）
	get_tree().create_timer(0.3, false).timeout.connect(_deal_damage_to_overlapping)
	
	# 引爆震屏
	GU.screen_shake(4.0, 0.2)

func _process(delta: float) -> void:
	_elapsed += delta
	# 动画14帧12fps ≈ 1.17秒，加缓冲
	if _elapsed > 1.3:
		ObjectPool.recycle(self )

func _deal_damage_to_overlapping() -> void:
	if damage_dealt:
		return
	damage_dealt = true
	
	var areas = get_overlapping_areas()
	for area in areas:
		if area.is_in_group("enemies") and area.has_method("take_damage"):
			if area.get("is_dead") == true:
				continue
			
			var final_damage = damage
			
			# 引爆伤害可暴击
			var is_crit = false
			if can_crit and randf() < PC.crit_chance:
				is_crit = true
				final_damage *= PC.crit_damage_multi
			
			area.take_damage(int(final_damage), is_crit, false, "faze_destory_detonation")

## 对象池重置：清除状态供复用
func reset_for_pool() -> void:
	damage = 0.0
	can_crit = true
	destroy_level = 0
	damage_dealt = false
	_elapsed = 0.0
	scale = _base_scale
	modulate.a = 1.0
	global_position = Vector2.ZERO
	if sprite:
		sprite.stop()
		sprite.frame = 0
