extends Area2D
class_name FazeLight

@export var sprite: AnimatedSprite2D
@export var collision_shape: CollisionShape2D

var base_sprite_scale: Vector2 = Vector2.ONE
var base_collision_scale: Vector2 = Vector2.ONE
var _base_scales_captured: bool = false
var _run_id: int = 0

const MAX_TARGETS_PER_FRAME := 16

# ---- 静态入口：由 faze.gd 调用 ----
static func fire_skill(scene: PackedScene, player_pos: Vector2, tree: SceneTree) -> void:
	if not scene:
		return
	var instance: FazeLight = null
	if Global.faze_light_pool != null:
		instance = Global.faze_light_pool.acquire(tree.current_scene) as FazeLight
	if instance == null:
		instance = scene.instantiate() as FazeLight
		tree.current_scene.add_child(instance)
	instance.setup(player_pos)

# ---- 计算神圣光辉伤害倍率（基于法则描述，与圣光术武器无关）----
static func _get_sacred_light_damage_percent(level: int) -> float:
	# 9阶：300%   16阶：500%   29阶：1800%
	if level >= 29:
		return 18.0
	if level >= 16:
		return 5.0
	return 3.0

# ---- 计算神圣光辉范围倍率（相对 tscn 原始 scale）----
static func _get_sacred_light_range_scale(level: int) -> float:
	# 16阶：范围提升   22阶：范围大幅提升
	if level >= 22:
		return 2.5
	if level >= 16:
		return 1.5
	return 1.0

# ---- 实例初始化 ----
func setup(pos: Vector2) -> void:
	_run_id += 1
	var run_id: int = _run_id
	CharacterEffects.include_enemy_collision_mask(self)
	_resolve_nodes()
	reset_visual_state()
	global_position = pos

	# 根据法则阶位应用范围倍率
	var range_scale: float = _get_sacred_light_range_scale(PC.faze_life_level)
	if range_scale != 1.0:
		if collision_shape:
			collision_shape.scale = base_collision_scale * range_scale
		if sprite:
			sprite.scale = base_sprite_scale * range_scale

	# 开启碰撞检测
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	call_deferred("_start_light", run_id)

func _start_light(run_id: int) -> void:
	if run_id != _run_id:
		return
	if not is_inside_tree():
		call_deferred("_start_light", run_id)
		return

	# 等待物理帧刷新重叠后立刻判定伤害
	await get_tree().physics_frame
	await get_tree().physics_frame
	if run_id != _run_id:
		return
	_apply_damage(run_id)
	
	# 神圣光辉震屏
	if run_id == _run_id:
		GU.screen_shake(3.0, 0.15)

	# 播放动画后消失
	if sprite:
		sprite.frame = 0
		sprite.modulate.a = 1.0
		sprite.play("default")
		if not sprite.animation_finished.is_connected(_on_animation_done):
			sprite.animation_finished.connect(_on_animation_done)
	else:
		# 无动画则直接延时消失
		get_tree().create_timer(0.5).timeout.connect(_on_fallback_timeout.bind(run_id))

func _on_animation_done() -> void:
	if not is_instance_valid(self):
		return
	ObjectPool.recycle(self)

func _on_fallback_timeout(run_id: int) -> void:
	if run_id == _run_id:
		ObjectPool.recycle(self)

func _resolve_nodes() -> void:
	if not collision_shape:
		collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not sprite:
		sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if _base_scales_captured:
		return
	if sprite:
		base_sprite_scale = sprite.scale
	if collision_shape:
		base_collision_scale = collision_shape.scale
	_base_scales_captured = true

func reset_visual_state() -> void:
	_resolve_nodes()
	modulate = Color.WHITE
	scale = Vector2.ONE
	rotation = 0.0
	if collision_shape:
		collision_shape.scale = base_collision_scale
	if sprite:
		sprite.scale = base_sprite_scale
		sprite.modulate = Color.WHITE
		sprite.rotation = 0.0
		sprite.stop()
		sprite.frame = 0

func _apply_damage(run_id: int) -> void:
	if not is_instance_valid(self ):
		return
	var level: int = PC.faze_life_level
	var damage_percent: float = _get_sacred_light_damage_percent(level)
	var final_damage: float = float(PC.pc_atk) * damage_percent

	var areas: Array[Area2D] = get_overlapping_areas()
	var processed_this_frame: int = 0
	for area in areas:
		if run_id != _run_id:
			return
		if area == null or not is_instance_valid(area):
			continue
		if area.is_in_group("enemies") and area.has_method("take_damage"):
			var target_damage: float = final_damage
			if area.is_in_group("boss"):
				target_damage *= 3.0
			area.take_damage(int(target_damage), false, false, "faze_sacred_light")
			processed_this_frame += 1
			if processed_this_frame >= MAX_TARGETS_PER_FRAME:
				processed_this_frame = 0
				await get_tree().process_frame
				if run_id != _run_id:
					return
				if not is_instance_valid(self):
					return
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

func reset_for_pool() -> void:
	_run_id += 1
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	reset_visual_state()
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
