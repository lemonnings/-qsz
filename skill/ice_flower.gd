extends Area2D

@export var sprite: AnimatedSprite2D
@export var collision_shape: CollisionShape2D
@export var rotation_offset: float = 0.0

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
		if randf() < PC.crit_chance:
			is_crit = true
			final_damage *= PC.crit_damage_multi
		
		if area.has_method("take_damage"):
			area.take_damage(int(final_damage), is_crit, false, "ice_flower")
			
		# 处理穿透
		if penetration_count > 0:
			penetration_count -= 1
			ice_damage *= (1.0 - pierce_decay) # 衰减伤害
		else:
			queue_free()
