extends Area2D

## 魔纹阵：在脚下展开魔纹阵，范围内提升攻速、加速咏唱技能冷却、缩短咏唱时间

@export var sprite: AnimatedSprite2D
@export var collisionShape: CollisionShape2D

var duration: float = 15.0
var atk_speed_bonus: float = 0.25
var chant_cd_accel: float = 1.0
var chant_time_reduce: float = 0.5
var _buff_active: bool = false
var _effect_radius: float = 100.0
var _breathing_tween: Tween = null
var _is_fading_out: bool = false

@onready var player = get_tree().get_first_node_in_group("player")

func _ready():
	z_index = -10
	# 回退查找节点（tscn中未绑定@export变量）
	if not sprite:
		sprite = get_node_or_null("AnimatedSprite2D2")
	if not collisionShape:
		collisionShape = get_node_or_null("CollisionShape2D2")
	if sprite:
		sprite.visible = false
		sprite.stop()
	if collisionShape:
		collisionShape.disabled = true
	set_process(false)

func start(duration_time: float, atk_spd_bonus: float = 0.25, cd_accel: float = 1.0, chant_reduce: float = 0.5) -> void:
	duration = duration_time
	atk_speed_bonus = atk_spd_bonus
	chant_cd_accel = cd_accel
	chant_time_reduce = chant_reduce
	
	# 从碰撞形状获取效果半径（考虑缩放）
	if collisionShape and collisionShape.shape:
		var shape_scale = collisionShape.scale
		if collisionShape.shape is CircleShape2D:
			_effect_radius = (collisionShape.shape as CircleShape2D).radius * max(shape_scale.x, shape_scale.y)
		elif collisionShape.shape is CapsuleShape2D:
			_effect_radius = (collisionShape.shape as CapsuleShape2D).height * 0.5 * max(shape_scale.x, shape_scale.y)
	
	# 显示魔纹阵动画，0.2秒渐入
	if sprite:
		sprite.visible = true
		sprite.play("default")
		sprite.modulate.a = 0.0
		var fade_in = create_tween()
		fade_in.tween_property(sprite, "modulate:a", 0.6, 0.2)
		fade_in.tween_callback(_start_breathing)
	
	if collisionShape:
		collisionShape.disabled = false
	
	Global.emit_signal("buff_added", "magic", duration, 1)
	_apply_buffs()
	set_process(true)

func _start_breathing():
	if not sprite or _is_fading_out:
		return
	_breathing_tween = create_tween().set_loops()
	_breathing_tween.tween_property(sprite, "modulate:a", 0.6, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breathing_tween.tween_property(sprite, "modulate:a", 0.3, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _process(delta):
	if _is_fading_out:
		return
	duration -= delta
	
	if player and is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist <= _effect_radius:
			if not _buff_active:
				_apply_buffs()
		else:
			if _buff_active:
				_remove_buffs()
	
	if duration <= 0:
		_start_fade_out()

func _start_fade_out():
	_is_fading_out = true
	if _buff_active:
		_remove_buffs()
	Global.emit_signal("buff_removed", "magic")
	if _breathing_tween and _breathing_tween.is_valid():
		_breathing_tween.kill()
	if sprite:
		var fade_out = create_tween()
		fade_out.tween_property(sprite, "modulate:a", 0.0, 0.2)
		fade_out.tween_callback(queue_free)
	else:
		queue_free()

func _apply_buffs():
	if _buff_active:
		return
	_buff_active = true
	PC.pc_atk_speed += atk_speed_bonus
	PC.chant_cooldown_acceleration += chant_cd_accel
	PC.chant_time_reduction += chant_time_reduce

func _remove_buffs():
	if not _buff_active:
		return
	_buff_active = false
	PC.pc_atk_speed -= atk_speed_bonus
	PC.chant_cooldown_acceleration -= chant_cd_accel
	PC.chant_time_reduction -= chant_time_reduce

func _exit_tree():
	if _buff_active:
		_remove_buffs()
