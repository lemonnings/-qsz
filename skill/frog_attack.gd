extends Area2D

@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var outline_sprite_2d = $OutlineSprite2D

const DEFAULT_SPEED: float = 150.0
const DEFAULT_MAX_RANGE: float = 900.0

var speed: float = DEFAULT_SPEED # 火球飞行速度
var direction = Vector2.RIGHT # 火球默认飞行方向
var atk: float = SettingMoster.frog("atk") # 火球攻击力，与青蛙一致
var max_range: float = DEFAULT_MAX_RANGE # 默认保持原 6 秒 * 150 速度的销毁距离
var traveled_distance: float = 0.0

func _ready() -> void:
	_resolve_nodes()
	traveled_distance = 0.0
	add_to_group(Global.MORETIP_OUTLINE_TARGET_GROUP)
	if animated_sprite_2d and not animated_sprite_2d.frame_changed.is_connected(_sync_outline_frame):
		animated_sprite_2d.frame_changed.connect(_sync_outline_frame)
	if outline_sprite_2d:
		outline_sprite_2d.stop()
	_sync_outline_frame()
	set_outline_enabled(Global.moretip)

func _resolve_nodes() -> void:
	if not animated_sprite_2d:
		animated_sprite_2d = get_node_or_null("AnimatedSprite2D")
	if not outline_sprite_2d:
		outline_sprite_2d = get_node_or_null("OutlineSprite2D")

func setup_projectile(spawn_position: Vector2, dir: Vector2, p_atk: float, p_speed: float = DEFAULT_SPEED, p_max_range: float = DEFAULT_MAX_RANGE) -> void:
	_resolve_nodes()
	global_position = spawn_position
	traveled_distance = 0.0
	atk = p_atk
	speed = p_speed
	max_range = p_max_range
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	set_direction(dir)
	play_animation("fire")
	set_outline_enabled(Global.moretip)

func set_outline_enabled(enabled: bool) -> void:
	_resolve_nodes()
	if outline_sprite_2d:
		outline_sprite_2d.visible = enabled

func _sync_outline_frame() -> void:
	_resolve_nodes()
	if not animated_sprite_2d or not outline_sprite_2d:
		return
	outline_sprite_2d.animation = animated_sprite_2d.animation
	outline_sprite_2d.set_frame_and_progress(animated_sprite_2d.frame, animated_sprite_2d.frame_progress)

func _physics_process(delta):
	# 每帧更新火球位置
	var step = direction * speed * delta
	position += step
	traveled_distance += step.length()
	if traveled_distance >= max_range:
		ObjectPool.recycle(self )

# 设置火球的飞行方向 (支持任意方向)
func set_direction(dir: Vector2):
	_resolve_nodes()
	# 标准化方向向量
	direction = dir.normalized()
	# 根据方向设置sprite的旋转角度
	if animated_sprite_2d:
		# 计算方向向量的角度（弧度）
		var angle = direction.angle()
		# 设置sprite旋转以匹配飞行方向
		animated_sprite_2d.rotation = angle
		if outline_sprite_2d:
			outline_sprite_2d.rotation = angle

# 播放指定的动画
func play_animation(anim_name: String):
	_resolve_nodes()
	if animated_sprite_2d:
		animated_sprite_2d.play(anim_name)
	if outline_sprite_2d:
		outline_sprite_2d.animation = anim_name
		outline_sprite_2d.stop()
	_sync_outline_frame()

# 当火球碰撞到其他物体时触发
func _on_body_entered(body: Node2D) -> void:
	# 检查碰撞对象是否为玩家角色且玩家非无敌状态
	if body is CharacterBody2D and not PC.invincible:
		var actual_damage = int(atk * (1.0 - PC.damage_reduction_rate)) # 计算实际伤害，考虑减伤
		PC.player_hit(int(actual_damage), self , "") # 扣除玩家血量
		ObjectPool.recycle(self ) # 火球击中目标后消失

func reset_for_pool() -> void:
	speed = DEFAULT_SPEED
	direction = Vector2.RIGHT
	atk = SettingMoster.frog("atk")
	max_range = DEFAULT_MAX_RANGE
	traveled_distance = 0.0
	global_position = Vector2.ZERO
	rotation = 0.0
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	_resolve_nodes()
	if animated_sprite_2d:
		animated_sprite_2d.rotation = 0.0
		animated_sprite_2d.animation = "fire"
		animated_sprite_2d.frame = 0
		animated_sprite_2d.play("fire")
	if outline_sprite_2d:
		outline_sprite_2d.rotation = 0.0
		outline_sprite_2d.animation = "fire"
		outline_sprite_2d.frame = 0
		outline_sprite_2d.stop()
		outline_sprite_2d.visible = Global.moretip
