extends Control
class_name BuffUI

# UI组件引用
signal buff_expired

@onready var icon: TextureRect
@onready var stack_label: Label
@onready var timer_label: Label
@onready var animation_player: AnimationPlayer
@onready var tooltip_panel: Panel
#@onready var tooltip_tween: Tween # 将在需要时动态创建

# Buff数据
var buff_id: String
var remaining_time: float = 0.0
var stack_count: int = 1
var is_permanent: bool = false
var is_flashing: bool = false
var flash_speed: float = 1.0

# 闪烁状态
enum FlashState {
	NONE,
	NORMAL_FLASH,  # 10秒以下开始闪烁
	FAST_FLASH     # 3秒以下快速闪烁
}

var current_flash_state: FlashState = FlashState.NONE

func _ready():
	# 创建UI组件
	_setup_ui()
	
	## 连接动画播放器
	#if animation_player:
		#animation_player.animation_finished.connect(_on_animation_finished)

func _setup_ui():
	# 设置控件大小
	custom_minimum_size = Vector2(64, 80)
	size = Vector2(64, 80)
	
	# 创建图标
	icon = TextureRect.new()
	icon.name = "Icon"
	icon.size = Vector2(32, 32)
	icon.position = Vector2(18, 21)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(icon)
	
	# 创建层数标签（覆盖在图标上）
	stack_label = Label.new()
	stack_label.name = "StackLabel"
	stack_label.size = Vector2(36, 36)
	stack_label.position = Vector2(30, 29)  # 与图标相同位置
	stack_label.text = "1"
	stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 设置字体样式
	var custom_font = load("res://AssetBundle/Uranus_Pixel_11Px.ttf")
	stack_label.add_theme_font_override("font", custom_font)
	stack_label.add_theme_font_size_override("font_size", 22)
	stack_label.add_theme_color_override("font_color", Color.WHITE)
	stack_label.add_theme_color_override("font_shadow_color", Color.SLATE_GRAY)
	stack_label.add_theme_constant_override("shadow_offset_x", 1)
	stack_label.add_theme_constant_override("shadow_offset_y", 1)
	# 确保层数标签在图标之上（后添加的子节点z轴更高）
	add_child(stack_label)
	
	# 创建倒计时标签（上方）
	timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.size = Vector2(64, 20)
	timer_label.position = Vector2(5, -3)
	timer_label.text = "10"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 设置字体样式
	timer_label.add_theme_font_override("font", custom_font)
	timer_label.add_theme_font_size_override("font_size", 24)
	timer_label.add_theme_color_override("font_color", Color.WHITE)
	timer_label.add_theme_color_override("font_shadow_color", Color.SLATE_GRAY)
	timer_label.add_theme_constant_override("shadow_offset_x", 1)
	timer_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(timer_label)
	
	# 创建动画播放器
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)
	
	# 创建闪烁动画
	_create_flash_animations()
	
	# 创建详细信息显示框
	_create_tooltip()
	
	# 连接鼠标事件
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _create_flash_animations():
	# 创建普通闪烁动画（10秒以下）
	var normal_flash = Animation.new()
	normal_flash.length = 1.0
	normal_flash.loop_mode = Animation.LOOP_LINEAR
	
	var track_index = normal_flash.add_track(Animation.TYPE_VALUE)
	normal_flash.track_set_path(track_index, "Icon:modulate:a")
	normal_flash.track_insert_key(track_index, 0.0, 1.0)
	normal_flash.track_insert_key(track_index, 0.5, 0.3)
	normal_flash.track_insert_key(track_index, 1.0, 1.0)
	
	var library = AnimationLibrary.new()
	library.add_animation("normal_flash", normal_flash)
	
	# 创建快速闪烁动画（3秒以下）
	var fast_flash = Animation.new()
	fast_flash.length = 0.3
	fast_flash.loop_mode = Animation.LOOP_LINEAR
	
	var fast_track_index = fast_flash.add_track(Animation.TYPE_VALUE)
	fast_flash.track_set_path(fast_track_index, "Icon:modulate:a")
	fast_flash.track_insert_key(fast_track_index, 0.0, 1.0)
	fast_flash.track_insert_key(fast_track_index, 0.15, 0.2)
	fast_flash.track_insert_key(fast_track_index, 0.3, 1.0)
	
	library.add_animation("fast_flash", fast_flash)
	animation_player.add_animation_library("default", library)

func setup_buff(buff_data, duration: float = 0.0, stack: int = 1):
	buff_id = buff_data.id
	remaining_time = duration
	stack_count = stack
	is_permanent = (buff_data.type == Global.SettingBuff.BuffType.PERMANENT)
	
	# 设置图标
	print("=== Buff图标加载调试 ===")
	print("Buff ID: ", buff_data.id)
	print("图标路径: ", buff_data.icon_path)
	print("路径是否为空: ", buff_data.icon_path == "")
	print("文件是否存在: ", ResourceLoader.exists(buff_data.icon_path))
	
	if buff_data.icon_path != "" and ResourceLoader.exists(buff_data.icon_path):
		print("正在加载图标...")
		icon.texture = load(buff_data.icon_path)
		print("图标加载成功")
	else:
		print("图标加载失败，使用透明占位符")
		# 创建透明占位图标
		var placeholder_texture = ImageTexture.new()
		var placeholder_image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		placeholder_image.fill(Color(0, 0, 0, 0))  # 完全透明
		placeholder_texture.set_image(placeholder_image)
		icon.texture = placeholder_texture
	
	# 更新UI显示
	_update_display()



func _update_display():
	# 更新层数显示
	if stack_count > 1:
		stack_label.text = str(stack_count)
		stack_label.visible = true
	else:
		stack_label.visible = false
	
	# 更新倒计时显示
	if is_permanent:
		timer_label.visible = false
	else:
		timer_label.visible = true
		if remaining_time > 0:
			timer_label.text = str(int(ceil(remaining_time)) - 1)
		else:
			timer_label.text = "0"
	
	# 更新闪烁状态
	_update_flash_state()

func _update_flash_state():
	if is_permanent:
		return
	
	var new_flash_state: FlashState
	
	if remaining_time <= 3.0:
		new_flash_state = FlashState.FAST_FLASH
	elif remaining_time <= 8.0:
		new_flash_state = FlashState.NORMAL_FLASH
	else:
		new_flash_state = FlashState.NONE
	
	if new_flash_state != current_flash_state:
		current_flash_state = new_flash_state
		_apply_flash_state()

func _apply_flash_state():
	match current_flash_state:
		FlashState.NONE:
			animation_player.stop()
			icon.modulate.a = 1.0
		FlashState.NORMAL_FLASH:
			animation_player.play("default/normal_flash")
		FlashState.FAST_FLASH:
			animation_player.play("default/fast_flash")

func update_buff(new_remaining_time: float, new_stack: int):
	remaining_time = new_remaining_time
	stack_count = new_stack
	_update_display()

func _process(delta: float):
	if not is_permanent and remaining_time > 0:
		remaining_time -= delta
		if remaining_time <= 0:
			remaining_time = 0
			# 发送buff过期信号
			buff_expired.emit()
			# 父节点应该连接到buff_expired信号，并在收到信号时调用 queue_free() 来移除此buff实例。
			# 例如: buff_ui_instance.buff_expired.connect(func(): buff_ui_instance.queue_free())
			# 或者，如果父节点管理一个buff列表/字典，则可以在信号处理函数中移除它并queue_free。
		_update_display()
		_update_flash_state()

func _create_tooltip():
	# 创建详细信息面板
	tooltip_panel = Panel.new()
	tooltip_panel.name = "TooltipPanel"
	tooltip_panel.visible = false
	tooltip_panel.z_index = 100
	tooltip_panel.modulate.a = 0.0  # 初始透明度为0
	
	# 设置面板样式（圆角、80%透明度黑色背景）
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0, 0, 0.4)  # 80%透明度的黑色
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	#style_box.border_width_left = 1
	#style_box.border_width_right = 1
	#style_box.border_width_top = 1
	#style_box.border_width_bottom = 1
	#style_box.border_color = Color.LIGHT_GRAY
	tooltip_panel.add_theme_stylebox_override("panel", style_box)
	
	# 创建垂直布局容器
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	tooltip_panel.add_child(vbox)
	
	# 创建第一行的水平布局容器（名称和类型/最大层数）
	var hbox = HBoxContainer.new()
	hbox.name = "HeaderHBox"
	vbox.add_child(hbox)
	
	# 自定义字体
	var custom_font = load("res://AssetBundle/Uranus_Pixel_11Px.ttf")
	
	# Buff名称标签（左对齐）
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.add_theme_font_override("font", custom_font)
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	hbox.add_child(name_label)
	
	# 添加弹性空间
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)
	
	# 类型和最大层数标签（右对齐）
	var type_label = Label.new()
	type_label.name = "TypeLabel"
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	type_label.add_theme_font_override("font", custom_font)
	type_label.add_theme_font_size_override("font_size", 18)
	type_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	hbox.add_child(type_label)
	
	# 描述标签（第二行开始）
	var desc_label = Label.new()
	desc_label.name = "DescLabel"
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_override("font", custom_font)
	desc_label.add_theme_font_size_override("font_size", 15)
	desc_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	vbox.add_child(desc_label)
	
	# 设置面板内边距
	vbox.position = Vector2(8, 6)
	
	# Tween将在_show_tooltip和_hide_tooltip中按需创建
	
	add_child(tooltip_panel) # 将tooltip_panel作为BuffUI的子节点

func _on_mouse_entered():
	if buff_id != "":
		_show_tooltip()

func _on_mouse_exited():
	_hide_tooltip()

func _show_tooltip():
	var buff_data = Global.SettingBuff.get_buff_data(buff_id)
	if buff_data == null:
		return
	
	# 更新名称
	var name_label = tooltip_panel.get_node("VBoxContainer/HeaderHBox/NameLabel")
	name_label.text = buff_data.name
	
	# 更新类型和最大层数信息
	var type_label = tooltip_panel.get_node("VBoxContainer/HeaderHBox/TypeLabel")
	var type_text = ""
	if buff_data.type == Global.SettingBuff.BuffType.PERMANENT:
		type_text = "永久"
	#type_text += "最大层数：" + str(buff_data.max_stack)
	type_label.text = type_text
	
	# 更新描述
	var desc_label = tooltip_panel.get_node("VBoxContainer/DescLabel")
	desc_label.text = buff_data.description
	
	# 计算面板大小
	var content_size = Vector2(200, 0)  # 基础宽度
	var header_height = 24
	var desc_height = desc_label.get_theme_font("font").get_multiline_string_size(buff_data.description, HORIZONTAL_ALIGNMENT_LEFT, content_size.x - 16, 15).y
	content_size.y = header_height + desc_height + 24  # 加上内边距
	
	tooltip_panel.size = content_size
	tooltip_panel.get_node("VBoxContainer").size = Vector2(content_size.x - 16, content_size.y - 12)
	
	# 设置位置（在buff图标上方并水平居中）
	# 由于tooltip_panel现在是BuffUI的子节点，其position是相对于BuffUI的
	tooltip_panel.position = Vector2((size.x - content_size.x) / 2, -content_size.y - 5)
	
	# 显示面板并开始渐入动画
	tooltip_panel.visible = true
	tooltip_panel.modulate.a = 0.0
	
	var tween = get_tree().create_tween() # 每次都创建新的Tween
	tween.tween_property(tooltip_panel, "modulate:a", 1.0, 0.1)

func _hide_tooltip():
	if tooltip_panel and tooltip_panel.visible:
		var tween = get_tree().create_tween() # 每次都创建新的Tween
		# 开始渐出动画（0.1秒）
		tween.tween_property(tooltip_panel, "modulate:a", 0.0, 0.1)
		tween.tween_callback(func(): 
			if is_instance_valid(tooltip_panel):
				tooltip_panel.visible = false
		)

#func _on_animation_finished(_anim_name: String):
	## 动画结束后的处理（如果需要）
	#pass
