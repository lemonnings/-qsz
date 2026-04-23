extends Area2D

## 花瓣投射物
## 用于 boss_a 的"落花"技能：从场地顶部飘落，碰到玩家造成伤害。
## 路径：垂直匀速下落 + 正弦横向摆动，模拟花瓣飘落的曲线轨迹。
## 外观：petal.png 带 1px 红色勾边（由 petal_outline.gdshader 实现）。

const DETOX_BUFF_ID := "boss_a_detox"
const DETOX_DURATION: float = 3.0
const GOLDEN_PETAL_TINT := Color(1.0, 0.95, 0.62, 1.0)

@onready var sprite: Sprite2D = $Sprite2D

# ——— 运行时参数（由外部通过 initialize() 赋值） ———
var damage: float = 0.0
var bottom_limit: float = 400.0 # 超过此 y 后销毁（由 boss 传入 bottom_boundary + 100）
var fall_speed_multiplier: float = 1.0
var is_golden: bool = false

# ——— 飘落参数 ———
const FALL_SPEED: float = 130.0 # 垂直下落速度（像素/秒）
var base_x: float = 0.0 # 横向摆动的中轴 x
var flutter_amplitude: float = 25.0 # 摆动幅度（像素），随机初始化
var flutter_speed: float = 2.0 # 摆动频率（rad/s），随机初始化
var flutter_phase: float = 0.0 # 摆动初相，随机初始化
var rotation_speed: float = 0.0 # 自旋速度（rad/s），随机初始化
var time: float = 0.0


func initialize(
	damage_val: float,
	pos: Vector2,
	_bottom_limit: float,
	fall_speed_multi: float = 1.0,
	golden: bool = false
) -> void:
	"""
	在 add_child() 之后调用，完成花瓣的所有运行时参数设置。
	Args:
	  damage_val       : 本次伤害值（boss.atk * 0.6）
	  pos              : 生成的全局坐标
	  _bottom_limit    : 销毁用的 y 下界（bottom_boundary + 100）
	  fall_speed_multi : 下落速度倍率
	  golden           : 是否为核心难度的金色功能花瓣
	"""
	damage = damage_val
	bottom_limit = _bottom_limit
	fall_speed_multiplier = fall_speed_multi
	is_golden = golden
	base_x = pos.x
	global_position = pos

	# 随机化飘落手感，避免所有花瓣运动轨迹雷同
	flutter_amplitude = randf_range(12.0, 32.0)
	flutter_speed = randf_range(1.5, 3.0)
	flutter_phase = randf_range(0.0, TAU)
	rotation_speed = randf_range(-1.5, 1.5)

	if is_golden:
		var sprite_node := get_node_or_null("Sprite2D") as Sprite2D
		if sprite_node:
			sprite_node.modulate = GOLDEN_PETAL_TINT


func _ready() -> void:
	add_to_group("boss_a_petal") # 便于 boss 死亡时批量清除
	if is_golden and sprite:
		sprite.modulate = GOLDEN_PETAL_TINT
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	time += delta

	# 垂直匀速下落
	global_position.y += FALL_SPEED * fall_speed_multiplier * delta

	# 正弦横向摆动：x = base_x + A·sin(ω·t + φ)
	global_position.x = base_x + sin(time * flutter_speed + flutter_phase) * flutter_amplitude

	# 自旋（视觉增强）
	rotation += rotation_speed * delta

	# 飞出场地底部后销毁
	if global_position.y > bottom_limit:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D):
		return

	if is_golden:
		Global.emit_signal("buff_added", DETOX_BUFF_ID, DETOX_DURATION, 1)
		queue_free()
		return

	if not PC.invincible:
		var dmg: int = max(1, int(damage))
		PC.player_hit(int(dmg), self , "落花")
		Global.emit_signal("player_hit")
		if PC.pc_hp <= 0:
			PC.player_instance.game_over()
	queue_free()
