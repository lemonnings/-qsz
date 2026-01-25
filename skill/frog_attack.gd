extends Area2D

@onready var animated_sprite_2d = $AnimatedSprite2D

var speed = 150  # 火球飞行速度
var direction = Vector2.RIGHT # 火球默认飞行方向
var atk : float = SettingMoster.frog("atk") # 火球攻击力，与青蛙一致

func _ready() -> void:
	await get_tree().create_timer(6).timeout
	if !Global.is_level_up:
		queue_free()

func _physics_process(delta):
	# 每帧更新火球位置
	position += direction * speed * delta

# 设置火球的飞行方向 (支持任意方向)
func set_direction(dir: Vector2):
	# 标准化方向向量
	direction = dir.normalized()
	# 根据方向设置sprite的旋转角度
	if animated_sprite_2d:
		# 计算方向向量的角度（弧度）
		var angle = direction.angle()
		# 设置sprite旋转以匹配飞行方向
		animated_sprite_2d.rotation = angle

# 播放指定的动画
func play_animation(anim_name: String):
	animated_sprite_2d.play(anim_name)

# 当火球碰撞到其他物体时触发
func _on_body_entered(body: Node2D) -> void:
	# 检查碰撞对象是否为玩家角色且玩家非无敌状态
	if body is CharacterBody2D and not PC.invincible:
		Global.emit_signal("player_hit")
		var actual_damage = int(atk * (1.0 - PC.damage_reduction_rate)) # 计算实际伤害，考虑减伤
		PC.apply_damage(actual_damage) # 扣除玩家血量
		if PC.pc_hp <= 0:
			body.game_over() # 如果玩家血量耗尽，则游戏结束
		queue_free() # 火球击中目标后消失
