extends Node

# 鼠标动画管理器

# 鼠标图标资源
var mouse_textures: Array[Texture2D] = []
var current_frame: int = 0
var animation_timer: Timer
var animation_speed: float = 0.5  # 每帧持续时间（秒）

func _ready():
	# 加载三个鼠标图标
	mouse_textures.append(preload("res://AssetBundle/Sprites/Sprite sheets/Mouse sprites/Triangle Mouse icon 1.png"))
	mouse_textures.append(preload("res://AssetBundle/Sprites/Sprite sheets/Mouse sprites/Triangle Mouse icon 1.png"))
	mouse_textures.append(preload("res://AssetBundle/Sprites/Sprite sheets/Mouse sprites/Triangle Mouse icon 1.png"))
	
	# 创建定时器
	animation_timer = Timer.new()
	animation_timer.wait_time = animation_speed
	animation_timer.timeout.connect(_on_animation_timer_timeout)
	animation_timer.autostart = false
	add_child(animation_timer)

func start_mouse_animation():
	"""开始鼠标动画"""
	if mouse_textures.size() > 0:
		# 设置初始鼠标图标，大小放大二倍
		Input.set_custom_mouse_cursor(mouse_textures[0], Input.CURSOR_ARROW, Vector2(0, 0))
		current_frame = 0
		# 启动定时器
		animation_timer.start()

# 移除停止动画功能，只需要启动即可

func _on_animation_timer_timeout():
	"""定时器超时，切换到下一帧"""
	current_frame = (current_frame + 1) % mouse_textures.size()
	Input.set_custom_mouse_cursor(mouse_textures[current_frame], Input.CURSOR_ARROW, Vector2(0, 0))

func set_animation_speed(speed: float):
	"""设置动画速度"""
	animation_speed = speed
	animation_timer.wait_time = speed
