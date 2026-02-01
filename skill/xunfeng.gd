extends Area2D

@export var sprite : AnimatedSprite2D
@export var collision : CollisionShape2D

var damage: float = 0.0
var speed: float = 400.0
var range_val: float = 280.0
var penetration_count: int = 0
var pierce_decay: float = 0.0
var start_pos: Vector2
var traveled_dist: float = 0.0
var direction: Vector2 = Vector2.RIGHT

# 静态函数，用于处理技能发射逻辑
static func fire_skill(scene: PackedScene, origin_pos: Vector2, tree: SceneTree) -> void:
	if not scene:
		return
		
	# 发射主风刃 (随机方向)
	var random_angle = randf_range(0, 2 * PI)
	var dir = Vector2(cos(random_angle), sin(random_angle))
	
	_spawn_blade(scene, tree, origin_pos, dir, 1.0)
	
	PC.xunfeng_attack_count += 1
	
	# 检查是否触发额外风刃 (Xunfeng3)
	if PC.selected_rewards.has("Xunfeng3"):
		if PC.xunfeng_attack_count % PC.xunfeng_extra_blade_count_threshold == 0:
			# 计算额外风刃的偏移角度
			var offset_rad = deg_to_rad(PC.xunfeng_extra_blade_angle_offset)
			
			# 更新下次的偏移角度 (+15度)
			PC.xunfeng_extra_blade_angle_offset += 15.0
			if PC.xunfeng_extra_blade_angle_offset >= 360.0:
				PC.xunfeng_extra_blade_angle_offset -= 360.0
				
			var up_dir = Vector2.UP.rotated(offset_rad)
			var down_dir = Vector2.DOWN.rotated(offset_rad)
			
			_spawn_blade(scene, tree, origin_pos, up_dir, PC.xunfeng_extra_blade_damage_ratio)
			_spawn_blade(scene, tree, origin_pos, down_dir, PC.xunfeng_extra_blade_damage_ratio)
			
			# Xunfeng33: 添加正左和正右
			if PC.selected_rewards.has("Xunfeng33"):
				var left_dir = Vector2.LEFT.rotated(offset_rad)
				var right_dir = Vector2.RIGHT.rotated(offset_rad)
				_spawn_blade(scene, tree, origin_pos, left_dir, PC.xunfeng_extra_blade_damage_ratio)
				_spawn_blade(scene, tree, origin_pos, right_dir, PC.xunfeng_extra_blade_damage_ratio)

static func _spawn_blade(scene: PackedScene, tree: SceneTree, origin_pos: Vector2, dir: Vector2, damage_ratio: float) -> void:
	var instance = scene.instantiate()
	tree.current_scene.add_child(instance)
	
	var damage = PC.pc_atk * PC.main_skill_xunfeng_damage * damage_ratio * PC.xunfeng_final_damage_multi
	
	instance.setup(origin_pos, dir, damage, PC.xunfeng_speed, PC.xunfeng_range, PC.xunfeng_size_scale)

func setup(pos: Vector2, dir: Vector2, p_damage: float, p_speed: float, p_range: float, p_scale: float) -> void:
	global_position = pos
	start_pos = pos
	direction = dir.normalized()
	damage = p_damage
	speed = p_speed
	range_val = p_range
	penetration_count = PC.xunfeng_penetration_count
	pierce_decay = PC.xunfeng_pierce_decay
	
	rotation = direction.angle()
	scale = Vector2(p_scale, p_scale)

func _ready() -> void:
	connect("area_entered", Callable(self, "_on_area_entered"))
	# 如果有 sprite，播放动画
	if sprite:
		sprite.play("default")

func _process(delta: float) -> void:
	var step = speed * delta
	position += direction * step
	traveled_dist += step
	
	if traveled_dist >= range_val:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies"):
		if area.has_method("take_damage"):
			var is_crit = false
			var final_damage = damage
			
			if randf() < PC.crit_chance:
				is_crit = true
				final_damage *= PC.crit_damage_multi
				
			area.take_damage(int(final_damage), is_crit, false, "xunfeng")
			
			if penetration_count > 0:
				penetration_count -= 1
				damage *= (1.0 - pierce_decay)
			else:
				queue_free()
