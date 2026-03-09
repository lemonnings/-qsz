extends Area2D
class_name IceFlower

@export var sprite: AnimatedSprite2D
@export var collision_shape: CollisionShape2D
@export var rotation_offset: float = 0.0

static var main_skill_ice_damage: float = 0.6
static var ice_flower_range: float = 132.0
static var ice_flower_penetration_count: int = 0
static var ice_flower_pierce_decay: float = 0.0
static var ice_flower_extra_small_count: int = 4
static var ice_flower_spread_angle: float = 120.0
static var ice_flower_small_damage_ratio: float = 0.5
static var ice_flower_small_scale_ratio: float = 0.65
static var ice_flower_base_scale: float = 1.0

static func reset_data() -> void:
	main_skill_ice_damage = 0.6
	ice_flower_range = 132.0
	ice_flower_penetration_count = 0
	ice_flower_pierce_decay = 0.0
	ice_flower_extra_small_count = 4
	ice_flower_spread_angle = 120.0
	ice_flower_small_damage_ratio = 0.5
	ice_flower_small_scale_ratio = 0.65
	ice_flower_base_scale = 1.0

var ice_damage: float = 0.0
var ice_range: float = 0.0
var ice_direction: Vector2 = Vector2.RIGHT
var penetration_count: int = 0
var pierce_decay: float = 0.0

var sprite_base_scale: Vector2
var collision_base_scale: Vector2
var base_range: float = 0.0
var default_range: float = 120.0
var travel_speed: float = 300.0
var travel_duration: float = 0.0
var travel_elapsed: float = 0.0
var start_position: Vector2
var end_position: Vector2
var hit_targets: Dictionary = {}

static func fire_skill(scene: PackedScene, origin_pos: Vector2, tree: SceneTree) -> void:
	if not scene:
		return
		
	var data = _build_data()
	var spawn_position = origin_pos
	var base_direction = Vector2.RIGHT
	
	var player = tree.get_first_node_in_group("player")
	if player:
		var nearest_enemy = player.find_nearest_enemy()
		if nearest_enemy:
			base_direction = (nearest_enemy.position - player.position).normalized()
		else:
			if not player.sprite_direction_right:
				base_direction = Vector2.LEFT
			else:
				base_direction = Vector2.RIGHT
			
	# 发射主冰刺
	var main_ice = scene.instantiate()
	tree.current_scene.add_child(main_ice)
	main_ice.setup_ice_flower(
		spawn_position, 
		base_direction, 
		data.range, 
		data.damage, 
		data.penetration_count, 
		data.pierce_decay, 
		data.base_scale * PC.bullet_size
	)
	
	# 发射小冰刺
	var half_angle = data.spread_angle / 2.0
	for i in range(data.small_count):
		# 随机角度
		var random_angle = randf_range(-half_angle, half_angle)
		var small_direction = base_direction.rotated(deg_to_rad(random_angle))
		
		var small_ice = scene.instantiate()
		tree.current_scene.add_child(small_ice)
		
		var small_damage = data.damage * data.small_damage_ratio
		var small_scale = data.base_scale * data.small_scale_ratio * PC.bullet_size
		
		# 小冰刺也继承穿透和衰减
		small_ice.setup_ice_flower(
			spawn_position,
			small_direction,
			data.range,
			small_damage,
			data.penetration_count,
			data.pierce_decay,
			small_scale
		)

static func _build_data() -> Dictionary:
	# 基础属性
	var damage_multiplier = main_skill_ice_damage
	var small_damage_ratio = ice_flower_small_damage_ratio
	var spread_angle = ice_flower_spread_angle
	var small_count = ice_flower_extra_small_count
	var penetration_count = ice_flower_penetration_count
	var pierce_decay = ice_flower_pierce_decay
	var base_scale = ice_flower_base_scale
	var small_scale_ratio = ice_flower_small_scale_ratio
	var range_val = ice_flower_range
	var destroy_damage_multiplier = Faze.get_destroy_damage_multiplier(PC.faze_destroy_level)
	var bullet_damage_multiplier = Faze.get_bullet_damage_multiplier(PC.faze_bullet_level)
	var bullet_range_multiplier = Faze.get_bullet_range_multiplier(PC.faze_bullet_level)
	
	# 根据升级修正属性
	if PC.selected_rewards.has("Ice1"):
		damage_multiplier += 0.3
		spread_angle += 79.0
		small_count += 5
	
	if PC.selected_rewards.has("Ice2"):
		damage_multiplier += 0.3
		small_damage_ratio = 0.75 # 提升至75%
		
	if PC.selected_rewards.has("Ice3"):
		damage_multiplier += 0.2
		small_count += 8
		
	if PC.selected_rewards.has("Ice4"):
		damage_multiplier += 0.2
		penetration_count += 1
		pierce_decay = 0.4 # 衰减40%
		
	if PC.selected_rewards.has("Ice5"):
		damage_multiplier += 0.4
		base_scale += 0.3
		small_scale_ratio += 0.1
		
	if PC.selected_rewards.has("Ice11"):
		damage_multiplier += 0.2
		spread_angle += 79.0
		small_count += 8
		
	if PC.selected_rewards.has("Ice22"):
		damage_multiplier += 0.2
		small_damage_ratio = 1.0 # 等同于冰刺术伤害
		
	if PC.selected_rewards.has("Ice33"):
		damage_multiplier += 0.3
		small_damage_ratio = 1.0
		pierce_decay = max(0.0, pierce_decay - 0.05) # 每次伤害衰减降低5%
		
	if PC.selected_rewards.has("Ice44"):
		damage_multiplier += 0.7
		spread_angle += 79.0
		base_scale += 0.2
		small_count += 5
		
	if PC.selected_rewards.has("Ice55"):
		damage_multiplier += 0.6
		penetration_count += 2
		pierce_decay = max(0.0, pierce_decay - 0.05)
	
	damage_multiplier = damage_multiplier * destroy_damage_multiplier * bullet_damage_multiplier
	range_val = range_val * bullet_range_multiplier
	
	var final_damage = PC.pc_atk * damage_multiplier
	
	return {
		"damage": final_damage,
		"range": range_val,
		"spread_angle": spread_angle,
		"small_count": small_count,
		"penetration_count": penetration_count,
		"pierce_decay": pierce_decay,
		"base_scale": base_scale,
		"small_damage_ratio": small_damage_ratio,
		"small_scale_ratio": small_scale_ratio
	}

func _ready() -> void:
	if not sprite:
		sprite = get_node_or_null("AnimatedSprite2D")
	if not collision_shape:
		collision_shape = get_node_or_null("CollisionShape2D")

	if sprite:
		sprite_base_scale = sprite.scale
		if sprite.animation != "default" or not sprite.is_playing():
			sprite.play("default")
	
	if collision_shape:
		collision_base_scale = collision_shape.scale
		var rect_shape = collision_shape.shape as RectangleShape2D
		if rect_shape:
			base_range = rect_shape.size.x * collision_base_scale.x
	
	_apply_visual()
	
	# 连接 area_entered 信号
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	travel_elapsed += delta
	var t = travel_elapsed / travel_duration
	if t > 1.0:
		t = 1.0
	global_position = start_position.lerp(end_position, t)
	
	# 渐隐效果：最后20%的距离开始渐隐
	if t > 0.8:
		var fade_t = (t - 0.8) / 0.2
		modulate.a = 1.0 - fade_t
	
	if travel_elapsed >= travel_duration:
		queue_free()

func setup_ice_flower(p_start_position: Vector2, p_direction: Vector2, p_range: float, p_damage: float, p_penetration_count: int, p_pierce_decay: float, p_scale: float) -> void:
	start_position = p_start_position
	ice_direction = p_direction.normalized()
	ice_range = p_range
	if ice_range <= 0.0:
		ice_range = default_range
	ice_damage = p_damage
	penetration_count = p_penetration_count
	pierce_decay = p_pierce_decay
	
	end_position = start_position + ice_direction * ice_range
	travel_duration = ice_range / travel_speed
	
	# 应用缩放
	scale = Vector2(p_scale, p_scale)
	
	_apply_visual()

func _apply_visual() -> void:
	# 默认sprite朝上，需要顺时针旋转90度(PI/2)以匹配Godot的0度(右向)
	rotation = ice_direction.angle() + rotation_offset + PI / 2
	# global_position 已经在 _process 中设置，这里不需要重置，除非是初始化
	if travel_elapsed == 0.0:
		global_position = start_position

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies"):
		var body_id = area.get_instance_id()
		if hit_targets.has(body_id):
			return
		hit_targets[body_id] = true
		
	# 造成伤害
	var is_crit = false
	var final_damage = ice_damage
	var crit_data = Faze.apply_destroy_crit_overflow(PC.crit_chance, PC.crit_damage_multi, PC.faze_destroy_level)
	var crit_chance = crit_data["crit_chance"]
	var crit_multiplier = crit_data["crit_multi"]
	if randf() < crit_chance:
		is_crit = true
		crit_multiplier *= Faze.get_destroy_crit_fluctuation_multiplier(PC.faze_destroy_level)
		final_damage *= crit_multiplier
		
		# 处理穿透衰减
		# 注意：这里是瞬时伤害，对于穿透，通常需要减少 damage 或者 penetration_count
		# 但因为是 Area2D 移动，碰到一个敌人算一次
	if area.has_method("take_damage"):
		area.take_damage(int(final_damage), is_crit, false, "ice_flower")
		Faze.on_bullet_hit()
		
		if penetration_count > 0:
			penetration_count -= 1
			# 衰减伤害 (对下一个目标生效，但这里 final_damage 是局部变量)
			# 如果要衰减，需要修改实例变量 ice_damage
			if pierce_decay > 0:
				ice_damage *= (1.0 - pierce_decay)
		else:
			# 穿透次数用完，销毁
			queue_free()
