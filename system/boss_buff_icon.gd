extends Control
class_name BossBuffIcon

## Boss血条上的buff图标组件（36x36像素）
## 支持正面buff和debuff显示，debuff带红色1像素勾边

signal buff_expired

# 图标尺寸常量
const ICON_SIZE: int = 36
const OUTLINE_WIDTH: int = 1

# Buff数据
var buff_id: String
var remaining_time: float = 0.0
var stack_count: int = 1
var is_permanent: bool = false
var is_debuff: bool = false
var display_name: String = ""
var description: String = ""

# UI组件
var icon: TextureRect
var stack_label: Label
var timer_label: Label
var tooltip_panel: Panel
var background_panel: Panel

# 闪烁状态
enum FlashState { NONE, NORMAL_FLASH, FAST_FLASH }
var current_flash_state: FlashState = FlashState.NONE
var animation_player: AnimationPlayer

func _ready():
	_setup_ui()

func _setup_ui():
	# 不允许被容器拉伸，保持固定尺寸
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# 设置控件大小（图标24 + 倒计时空间）
	custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE + 12)
	size = Vector2(ICON_SIZE, ICON_SIZE + 12)
	# 用STOP捕获鼠标事件，让整个图标区域都能触发tooltip
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 背景面板（仅用于debuff红色勾边，默认完全透明）
	background_panel = Panel.new()
	background_panel.name = "BackgroundPanel"
	background_panel.size = Vector2(ICON_SIZE, ICON_SIZE)
	background_panel.position = Vector2(0, 0)
	background_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0) # 完全透明，debuff时才显示
	bg_style.corner_radius_top_left = 3
	bg_style.corner_radius_top_right = 3
	bg_style.corner_radius_bottom_left = 3
	bg_style.corner_radius_bottom_right = 3
	bg_style.border_width_left = 0
	bg_style.border_width_top = 0
	bg_style.border_width_right = 0
	bg_style.border_width_bottom = 0
	background_panel.add_theme_stylebox_override("panel", bg_style)
	add_child(background_panel)

	# 创建图标
	icon = TextureRect.new()
	icon.name = "Icon"
	icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.position = Vector2(0, 0)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)

	# 创建层数标签（覆盖在图标右上角）
	stack_label = Label.new()
	stack_label.name = "StackLabel"
	stack_label.size = Vector2(ICON_SIZE, ICON_SIZE)
	stack_label.position = Vector2(0, 0)
	stack_label.text = ""
	stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stack_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	stack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var custom_font = load("res://AssetBundle/Uranus_Pixel_11Px.ttf")
	stack_label.add_theme_font_override("font", custom_font)
	stack_label.add_theme_font_size_override("font_size", 17)
	stack_label.add_theme_color_override("font_color", Color.WHITE)
	stack_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	stack_label.add_theme_constant_override("shadow_offset_x", 1)
	stack_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(stack_label)

	# 创建倒计时标签（图标下方）
	timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.size = Vector2(ICON_SIZE, 12)
	timer_label.position = Vector2(0, ICON_SIZE)
	timer_label.text = ""
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_label.add_theme_font_override("font", custom_font)
	timer_label.add_theme_font_size_override("font_size", 17)
	timer_label.add_theme_color_override("font_color", Color.WHITE)
	timer_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	timer_label.add_theme_constant_override("shadow_offset_x", 1)
	timer_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(timer_label)

	# 创建动画播放器
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)
	_create_flash_animations()

	# 创建详细信息提示面板
	_create_tooltip()

	# 连接鼠标事件
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _create_flash_animations():
	var library = AnimationLibrary.new()

	# 普通闪烁动画（8秒以下）
	var normal_flash = Animation.new()
	normal_flash.length = 1.0
	normal_flash.loop_mode = Animation.LOOP_LINEAR
	var track_index = normal_flash.add_track(Animation.TYPE_VALUE)
	normal_flash.track_set_path(track_index, "Icon:modulate:a")
	normal_flash.track_insert_key(track_index, 0.0, 1.0)
	normal_flash.track_insert_key(track_index, 0.5, 0.3)
	normal_flash.track_insert_key(track_index, 1.0, 1.0)
	library.add_animation("normal_flash", normal_flash)

	# 快速闪烁动画（3秒以下）
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

## 设置buff数据（用于debuff类型，来自EnemyDebuffManager）
func setup_debuff(debuff_id: String, stacks: int, config):
	buff_id = debuff_id
	is_debuff = true
	display_name = config.display_name if config.display_name != "" else debuff_id
	description = config.description if config.description != "" else ""
	stack_count = stacks
	remaining_time = config.duration
	is_permanent = false # debuff都是临时的

	# 设置图标
	if config.icon_path != "" and ResourceLoader.exists(config.icon_path):
		icon.texture = load(config.icon_path)
	else:
		_use_placeholder_icon()

	# debuff红色勾边
	_set_debuff_outline(true)
	_update_display()

## 设置buff数据（用于boss正面buff，来自全局信号）
func setup_buff(buff_id_arg: String, p_display_name: String, icon_path: String, duration: float, stack: int, permanent: bool, desc: String):
	buff_id = buff_id_arg
	is_debuff = false
	display_name = p_display_name
	description = desc
	stack_count = stack
	remaining_time = duration
	is_permanent = permanent

	# 设置图标
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	else:
		_use_placeholder_icon()

	# 正面buff不需要红色勾边
	_set_debuff_outline(false)
	_update_display()

func _use_placeholder_icon():
	var placeholder_texture = ImageTexture.new()
	var placeholder_image = Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	placeholder_image.fill(Color(0.5, 0.5, 0.5, 0.5))
	placeholder_texture.set_image(placeholder_image)
	icon.texture = placeholder_texture

func _set_debuff_outline(enable: bool):
	var bg_style = background_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if bg_style == null:
		return
	if enable:
		bg_style.bg_color = Color(0, 0, 0, 0.5) # debuff才显示半透明黑色底
		bg_style.border_width_left = OUTLINE_WIDTH
		bg_style.border_width_top = OUTLINE_WIDTH
		bg_style.border_width_right = OUTLINE_WIDTH
		bg_style.border_width_bottom = OUTLINE_WIDTH
		bg_style.border_color = Color.RED
	else:
		bg_style.bg_color = Color(0, 0, 0, 0) # 正面buff完全透明
		bg_style.border_width_left = 0
		bg_style.border_width_top = 0
		bg_style.border_width_right = 0
		bg_style.border_width_bottom = 0

func _update_display():
	# 更新层数显示（永久buff总是显示层数，临时buff>1层时显示）
	if stack_count > 1 or (is_permanent and stack_count >= 1):
		stack_label.text = str(stack_count)
		stack_label.visible = true
	else:
		stack_label.visible = false

	# 更新倒计时显示（永久buff不显示倒计时）
	if is_permanent:
		timer_label.visible = false
	else:
		timer_label.visible = true
		if remaining_time > 0:
			timer_label.text = str(int(ceil(remaining_time)))
		else:
			timer_label.text = "0"

	# 更新闪烁状态
	_update_flash_state()

func _update_flash_state():
	if is_permanent:
		if current_flash_state != FlashState.NONE:
			current_flash_state = FlashState.NONE
			_apply_flash_state()
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

## 更新buff数据
func update_buff(new_remaining_time: float, new_stack: int):
	remaining_time = new_remaining_time
	stack_count = new_stack
	_update_display()

## 更新debuff数据（从EnemyDebuffManager获取剩余时间）
func update_debuff(new_remaining_time: float, new_stacks: int):
	remaining_time = new_remaining_time
	stack_count = new_stacks
	_update_display()

func _process(delta: float):
	# debuff的倒计时由boss_hp_bar通过update_debuff()外部更新，不需要自行倒计时
	# 仅boss正面buff自行倒计时
	if not is_debuff and not is_permanent and remaining_time > 0:
		remaining_time -= delta
		if remaining_time <= 0:
			remaining_time = 0
			buff_expired.emit()
		_update_display()

# -------------------- Tooltip --------------------
func _create_tooltip():
	tooltip_panel = Panel.new()
	tooltip_panel.name = "TooltipPanel"
	tooltip_panel.visible = false
	tooltip_panel.z_index = 100
	tooltip_panel.modulate.a = 0.0
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0, 0, 0.85)
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_left = 4
	style_box.corner_radius_bottom_right = 4
	style_box.border_width_left = 1
	style_box.border_width_top = 1
	style_box.border_width_right = 1
	style_box.border_width_bottom = 1
	style_box.border_color = Color(0.5, 0.5, 0.5, 0.8)
	tooltip_panel.add_theme_stylebox_override("panel", style_box)

	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.add_child(vbox)

	var custom_font = load("res://AssetBundle/Uranus_Pixel_11Px.ttf")

	# 名称标签
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_override("font", custom_font)
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_label)

	# 类型标签
	var type_label = Label.new()
	type_label.name = "TypeLabel"
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	type_label.add_theme_font_override("font", custom_font)
	type_label.add_theme_font_size_override("font_size", 13)
	type_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	vbox.add_child(type_label)

	# 描述标签
	var desc_label = Label.new()
	desc_label.name = "DescLabel"
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_label.add_theme_font_override("font", custom_font)
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	vbox.add_child(desc_label)

	vbox.position = Vector2(6, 4)
	add_child(tooltip_panel)

func _on_mouse_entered():
	if buff_id != "":
		_show_tooltip()

func _on_mouse_exited():
	_hide_tooltip()

func _show_tooltip():
	var name_label = tooltip_panel.get_node("VBoxContainer/NameLabel")
	var type_label = tooltip_panel.get_node("VBoxContainer/TypeLabel")
	var desc_label = tooltip_panel.get_node("VBoxContainer/DescLabel")

	name_label.text = display_name

	# 只显示层数
	if stack_count > 0:
		type_label.text = "%d 层" % stack_count
	else:
		type_label.text = ""

	# 描述文本（层数信息已经在type_label中显示）
	desc_label.text = description

	# 计算面板大小
	var content_width = 160.0
	var header_height = 20
	var type_height = 16
	var desc_height = desc_label.get_theme_font("font").get_multiline_string_size(description, HORIZONTAL_ALIGNMENT_LEFT, content_width - 12, 13).y
	content_width = max(content_width, name_label.get_theme_font("font").get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 16)
	var content_height = header_height + type_height + desc_height + 16

	tooltip_panel.size = Vector2(content_width, content_height)
	tooltip_panel.get_node("VBoxContainer").size = Vector2(content_width - 12, content_height - 8)

	# 位置：在图标上方显示
	tooltip_panel.position = Vector2((size.x - content_width) / 2.0, -content_height - 4)

	tooltip_panel.visible = true
	tooltip_panel.modulate.a = 0.0

	var tween = get_tree().create_tween()
	tween.tween_property(tooltip_panel, "modulate:a", 1.0, 0.1)

func _hide_tooltip():
	if tooltip_panel and tooltip_panel.visible:
		var tween = get_tree().create_tween()
		tween.tween_property(tooltip_panel, "modulate:a", 0.0, 0.1)
		tween.tween_callback(func():
			if is_instance_valid(tooltip_panel):
				tooltip_panel.visible = false
		)
