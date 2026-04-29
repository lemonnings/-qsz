extends Area2D
class_name FazeLight

@export var sprite: AnimatedSprite2D
@export var collision_shape: CollisionShape2D

var base_sprite_scale: Vector2 = Vector2.ONE

# ---- 静态入口：由 faze.gd 调用 ----
static func fire_skill(scene: PackedScene, player_pos: Vector2, tree: SceneTree) -> void:
	if not scene:
		return
	var instance = scene.instantiate()
	tree.current_scene.add_child(instance)
	instance.setup(player_pos)

# ---- 计算神圣光辉伤害倍率（基于法则描述，与圣光术武器无关）----
static func _get_sacred_light_damage_percent(level: int) -> float:
	# 7阶：300%   10阶：500%   16阶：1800%
	if level >= 16:
		return 18.0
	if level >= 10:
		return 5.0
	return 3.0

# ---- 计算神圣光辉范围倍率（相对 tscn 原始 scale）----
static func _get_sacred_light_range_scale(level: int) -> float:
	# 13阶：250%   10阶：150%   其他：100%
	if level >= 13:
		return 2.5
	if level >= 10:
		return 1.5
	return 1.0

# ---- 实例初始化 ----
func setup(pos: Vector2) -> void:
	global_position = pos

	if not collision_shape:
		collision_shape = get_node_or_null("CollisionShape2D")
	if not sprite:
		sprite = get_node_or_null("AnimatedSprite2D")

	if sprite:
		base_sprite_scale = sprite.scale

	# 根据法则阶位应用范围倍率（10阶*1.5，13阶*2.5）
	var range_scale = _get_sacred_light_range_scale(PC.faze_life_level)
	if range_scale != 1.0:
		if collision_shape:
			collision_shape.scale = collision_shape.scale * range_scale
		if sprite:
			sprite.scale = base_sprite_scale * range_scale

	# 开启碰撞检测
	monitoring = true
	monitorable = true

	# 等待物理帧刷新重叠后立刻判定伤害
	await get_tree().physics_frame
	await get_tree().physics_frame
	_apply_damage()
	
	# 神圣光辉震屏
	GU.screen_shake(3.0, 0.15)

	# 播放动画后消失
	if sprite:
		sprite.play("default")
		if not sprite.animation_finished.is_connected(_on_animation_done):
			sprite.animation_finished.connect(_on_animation_done)
	else:
		# 无动画则直接延时消失
		get_tree().create_timer(0.5).timeout.connect(queue_free)

func _on_animation_done() -> void:
	queue_free()

func _apply_damage() -> void:
	if not is_instance_valid(self ):
		return
	var level = PC.faze_life_level
	var damage_percent = _get_sacred_light_damage_percent(level)
	var final_damage = PC.pc_atk * damage_percent

	var areas = get_overlapping_areas()
	for area in areas:
		if area.is_in_group("enemies") and area.has_method("take_damage"):
			area.take_damage(int(final_damage), false, false, "faze_sacred_light")
