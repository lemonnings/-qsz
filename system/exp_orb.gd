extends Area2D
class_name ExpOrb

## 经验光点 - 敌人死亡后掉落，飞向玩家提供经验

# 经验值
var exp_value: int = 1

# 移动状态
enum State {RISE, TRACK, FADE}
var current_state: State = State.RISE

# 向上飘动参数
var rise_distance: float = 40.0
var rise_speed: float = 100.0 # 速度+50%
var rise_start_y: float = 0.0
var rise_target_y: float = 0.0

# 呼吸动画参数
var breath_time: float = 0.0
var breath_speed: float = 4.0 # 每秒6帧
var breath_min_scale: float = 0.7 # 最小缩放到30%
var breath_max_scale: float = 1.0
var base_sprite_scale: float = 1.0

# 旋转参数
var rotate_speed: float = 0.8 # 弧度/秒，缓慢旋转

# 追踪参数
var track_speed: float = 300.0
var player_ref: Node2D = null

# 渐隐参数
var fade_duration: float = 0.15
var fade_timer: float = 0.0

# 视觉组件
var sprite: Sprite2D = null

func _ready() -> void:
	# 创建像素风格的光点精灵
	_create_sprite()
	
	# 添加到经验光点组
	add_to_group("exp_orb")
	
	# 连接区域进入信号（备用）
	connect("area_entered", Callable(self , "_on_area_entered"))
	
	# 获取玩家引用
	_get_player_ref()
	
	# 初始化上升状态（在setup中设置，_ready中仅作保底初始化）
	rise_start_y = global_position.y
	rise_target_y = rise_start_y - rise_distance

func _create_sprite() -> void:
	# 创建像素风格的光点图像
	sprite = Sprite2D.new()
	add_child(sprite)
	
	# 创建像素光点纹理 (5x5像素)
	# 浅蓝色描边(1层) + 淡蓝色中层(1层) + 白色中心(1像素)
	var image = Image.create(5, 5, false, Image.FORMAT_RGBA8)
	
	# 浅蓝色描边 - 最外层 (RGB: 100, 180, 230)
	var outer_color = Color(0.4, 0.7, 0.9, 1.0)
	# 上边
	for x in range(5):
		image.set_pixel(x, 0, outer_color)
	# 下边
	for x in range(5):
		image.set_pixel(x, 4, outer_color)
	# 左边
	for y in range(5):
		image.set_pixel(0, y, outer_color)
	# 右边
	for y in range(5):
		image.set_pixel(4, y, outer_color)
	
	# 淡蓝色中层 - 第2层 (RGB: 180, 220, 255)
	var middle_color = Color(0.7, 0.86, 1.0, 1.0)
	for x in range(1, 4):
		image.set_pixel(x, 1, middle_color)
		image.set_pixel(x, 3, middle_color)
	image.set_pixel(1, 2, middle_color)
	image.set_pixel(3, 2, middle_color)
	
	# 白色中心 - 最里面 (1像素)
	image.set_pixel(2, 2, Color(1, 1, 1, 1))
	
	var texture = ImageTexture.create_from_image(image)
	sprite.texture = texture
	
	# 放大显示（原1.5缩小至50%）
	base_sprite_scale = 0.6
	sprite.scale = Vector2(base_sprite_scale, base_sprite_scale)
	
	# 居中
	sprite.offset = Vector2(-2.5, -2.5)
	
	# 整体透明度75%
	sprite.modulate.a = 0.75
	
	# 初始化呼吸动画
	breath_time = randf() * PI * 2 # 随机起始相位

func _get_player_ref() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0]

func _process(delta: float) -> void:
	# 更新呼吸动画
	_update_breath(delta)
	
	match current_state:
		State.RISE:
			_process_rise(delta)
		State.TRACK:
			_process_track(delta)
		State.FADE:
			_process_fade(delta)

func _update_breath(delta: float) -> void:
	# 每秒6帧的呼吸动画
	breath_time += delta * breath_speed * PI * 2
	# 使用sin函数在min和max之间振荡
	var t: float = 0.7 + ((sin(breath_time) + 1.0) / 2.0) * 0.3 # 0到1之间
	var breath_scale: float = breath_min_scale + (breath_max_scale - breath_min_scale) * t
	if sprite:
		sprite.scale = Vector2(base_sprite_scale * breath_scale, base_sprite_scale * breath_scale)
		# 缓慢旋转
		sprite.rotation += rotate_speed * delta

func _process_rise(delta: float) -> void:
	# 向上飘动
	var move_amount = rise_speed * delta
	global_position.y -= move_amount
	
	# 检查是否向上飘动了20像素
	if global_position.y <= rise_start_y - rise_distance:
		current_state = State.TRACK

func _process_track(delta: float) -> void:
	# 追踪玩家
	if not is_instance_valid(player_ref):
		_get_player_ref()
		if not is_instance_valid(player_ref):
			return
	
	var distance = global_position.distance_to(player_ref.global_position)
	
	# 飞入玩家身体内部7像素再进入渐隐状态（而非碰到边缘就消失）
	if distance <= 7.0:
		current_state = State.FADE
		fade_timer = fade_duration
		# 给玩家添加经验
		_give_exp_to_player()
		return
	
	# 向玩家方向移动
	var direction = (player_ref.global_position - global_position).normalized()
	global_position += direction * track_speed * delta

func _process_fade(delta: float) -> void:
	fade_timer -= delta
	
	# 渐隐效果
	if sprite:
		var alpha = (fade_timer / fade_duration) * 0.75
		sprite.modulate.a = alpha
	
	# 渐隐结束，销毁
	if fade_timer <= 0:
		queue_free()

func _give_exp_to_player() -> void:
	# 添加经验，并吃到全局/角色的经验获取倍率加成。
	var final_exp = int(max(1.0, round(float(exp_value) * Global.get_effective_exp_multiplier())))
	PC.pc_exp += final_exp

func _on_area_entered(area: Area2D) -> void:
	# 如果碰到玩家，立即进入追踪状态
	if area.is_in_group("player") or area.get_parent().is_in_group("player"):
		if current_state == State.RISE:
			current_state = State.TRACK

func setup(value: int, spawn_position: Vector2) -> void:
	exp_value = value
	global_position = spawn_position
	# 以怪物当前位置为起点，向上偏移20像素后开始追踪
	rise_start_y = spawn_position.y
	rise_target_y = rise_start_y - rise_distance
