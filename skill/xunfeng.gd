extends Area2D
class_name Xunfeng

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

# State variables moved from PC
static var main_skill_xunfeng_damage: float = 0.55
static var xunfeng_final_damage_multi: float = 1.0
static var xunfeng_range: float = 280.0
static var xunfeng_size_scale: float = 1.0
static var xunfeng_speed: float = 400.0
static var xunfeng_cooldown: float = 0.6
static var xunfeng_penetration_count: int = 0
static var xunfeng_pierce_decay: float = 0.0
static var xunfeng_extra_blade_count_threshold: int = 3
static var xunfeng_extra_blade_damage_ratio: float = 0.6

static var extra_blade_angle_offset: float = 0.0
static var attack_count: int = 0

static func reset_data() -> void:
	main_skill_xunfeng_damage = 0.55
	xunfeng_final_damage_multi = 1.0
	xunfeng_range = 280.0
	xunfeng_size_scale = 1.0
	xunfeng_speed = 400.0
	xunfeng_cooldown = 0.6
	xunfeng_penetration_count = 0
	xunfeng_pierce_decay = 0.0
	xunfeng_extra_blade_count_threshold = 3
	xunfeng_extra_blade_damage_ratio = 0.6
	
	extra_blade_angle_offset = 0.0
	attack_count = 0

static func fire_skill(scene: PackedScene, origin_pos: Vector2, tree: SceneTree) -> void:
	if not scene:
		return
		
	var data = _build_data()
	
	# 发射主风刃 (随机方向)
	var random_angle = randf_range(0, 2 * PI)
	var dir = Vector2(cos(random_angle), sin(random_angle))
	
	_spawn_blade(scene, tree, origin_pos, dir, 1.0, data)
	
	attack_count += 1
	
	# 检查是否触发额外风刃 (Xunfeng3)
	if PC.selected_rewards.has("Xunfeng3"):
		if attack_count % data.extra_blade_count_threshold == 0:
			# 计算额外风刃的偏移角度
			var offset_rad = deg_to_rad(extra_blade_angle_offset)
			
			# 更新下次的偏移角度 (+15度)
			extra_blade_angle_offset += 15.0
			if extra_blade_angle_offset >= 360.0:
				extra_blade_angle_offset -= 360.0
				
			var up_dir = Vector2.UP.rotated(offset_rad)
			var down_dir = Vector2.DOWN.rotated(offset_rad)
			
			_spawn_blade(scene, tree, origin_pos, up_dir, data.extra_blade_damage_ratio, data)
			_spawn_blade(scene, tree, origin_pos, down_dir, data.extra_blade_damage_ratio, data)
			
			# Xunfeng33: 添加正左和正右
			if PC.selected_rewards.has("Xunfeng33"):
				var left_dir = Vector2.LEFT.rotated(offset_rad)
				var right_dir = Vector2.RIGHT.rotated(offset_rad)
				_spawn_blade(scene, tree, origin_pos, left_dir, data.extra_blade_damage_ratio, data)
				_spawn_blade(scene, tree, origin_pos, right_dir, data.extra_blade_damage_ratio, data)

static func _spawn_blade(scene: PackedScene, tree: SceneTree, origin_pos: Vector2, dir: Vector2, damage_ratio: float, data: Dictionary) -> void:
	var instance = scene.instantiate()
	tree.current_scene.add_child(instance)
	
	var final_damage = data.damage * damage_ratio
	
	instance.setup(origin_pos, dir, final_damage, data.speed, data.range, data.size_scale, data.penetration_count, data.pierce_decay)

static func _build_data() -> Dictionary:
	var damage_multiplier = main_skill_xunfeng_damage
	
	# 八卦法则伤害加成
	damage_multiplier *= Faze.get_bagua_damage_multiplier()
	
	var speed = xunfeng_speed
	var range_val = xunfeng_range
	var size_scale = xunfeng_size_scale
	var penetration_count = xunfeng_penetration_count
	var pierce_decay = xunfeng_pierce_decay
	var bullet_damage_multiplier = Faze.get_bullet_damage_multiplier(PC.faze_bullet_level)
	var bullet_range_multiplier = Faze.get_bullet_range_multiplier(PC.faze_bullet_level)
	var wind_damage_multiplier = Faze.get_wind_weapon_damage_multiplier(PC.faze_wind_level)
	
	var extra_blade_count_threshold = xunfeng_extra_blade_count_threshold
	var extra_blade_damage_ratio = xunfeng_extra_blade_damage_ratio
	
	# 这里添加升级逻辑，目前代码中没有看到具体的 Xunfeng 升级对属性的直接修正
	# 假设如果有升级，会在这里处理
	
	var final_damage = PC.pc_atk * damage_multiplier * xunfeng_final_damage_multi * bullet_damage_multiplier * wind_damage_multiplier
	range_val = range_val * bullet_range_multiplier
	
	return {
		"damage": final_damage,
		"speed": speed,
		"range": range_val,
		"size_scale": size_scale,
		"penetration_count": penetration_count,
		"pierce_decay": pierce_decay,
		"extra_blade_count_threshold": extra_blade_count_threshold,
		"extra_blade_damage_ratio": extra_blade_damage_ratio
	}

func setup(pos: Vector2, dir: Vector2, p_damage: float, p_speed: float, p_range: float, p_scale: float, p_penetration_count: int, p_pierce_decay: float) -> void:
	global_position = pos
	start_pos = pos
	direction = dir.normalized()
	damage = p_damage
	speed = p_speed
	range_val = p_range
	penetration_count = p_penetration_count
	pierce_decay = p_pierce_decay
	
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
			if area.is_in_group("elite") or area.is_in_group("boss"):
				final_damage = final_damage * Faze.get_wind_elite_boss_multiplier(PC.faze_wind_level, PC.wind_huanfeng_stacks)
				
			var damage_dealt = area.take_damage(int(final_damage), is_crit, false, "xunfeng")
			Faze.on_wind_weapon_hit()
			
			Faze.add_bagua_progress(1, area.is_in_group("elite") or area.is_in_group("boss"))
			if not is_instance_valid(area) or area.hp <= 0:
				Faze.add_bagua_progress(5, area.is_in_group("elite") or area.is_in_group("boss"))
				
			# 击退效果 (Xunfeng1)
			
			if penetration_count > 0:
				penetration_count -= 1
				if pierce_decay > 0:
					damage *= (1.0 - pierce_decay)
			else:
				queue_free()
