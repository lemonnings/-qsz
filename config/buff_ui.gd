extends Control
class_name BuffUI

# UI组件引用
signal buff_expired

@onready var icon: TextureRect
@onready var stack_label: Label
@onready var timer_label: Label
@onready var animation_player: AnimationPlayer
@onready var tooltip_panel: Panel

# Buff数据
var buff_id: String
var remaining_time: float = 0.0
var stack_count: int = 1
var stack_text_override: String = ""
var is_permanent: bool = false
var is_flashing: bool = false
var flash_speed: float = 1.0

# 图标尺寸常量
const ICON_SIZE: int = 36

# 闪烁状态
enum FlashState {
	NONE,
	NORMAL_FLASH, # 10秒以下开始闪烁
	FAST_FLASH # 3秒以下快速闪烁
}

var current_flash_state: FlashState = FlashState.NONE

func _ready():
	_setup_ui()

func _setup_ui():
	# 不允许被容器拉伸，保持固定尺寸
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# 设置控件大小（图标24 + 计时器区域）
	custom_minimum_size = Vector2(ICON_SIZE + 4, ICON_SIZE + 20)
	size = Vector2(ICON_SIZE + 4, ICON_SIZE + 20)
	mouse_filter = Control.MOUSE_FILTER_PASS

	# 创建图标
	icon = TextureRect.new()
	icon.name = "Icon"
	icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.position = Vector2(2, 16)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)

	# 创建层数标签（覆盖在图标右下角）
	stack_label = Label.new()
	stack_label.name = "StackLabel"
	stack_label.size = Vector2(ICON_SIZE, ICON_SIZE)
	stack_label.position = Vector2(2, 16)
	stack_label.text = ""
	stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stack_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	stack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var custom_font = load("res://AssetBundle/Uranus_Pixel_11Px.ttf")
	stack_label.add_theme_font_override("font", custom_font)
	stack_label.add_theme_font_size_override("font_size", 15)
	stack_label.add_theme_color_override("font_color", Color.WHITE)
	stack_label.add_theme_color_override("font_shadow_color", Color.SLATE_GRAY)
	stack_label.add_theme_constant_override("shadow_offset_x", 1)
	stack_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(stack_label)

	# 创建倒计时标签（图标上方）
	timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.size = Vector2(ICON_SIZE + 4, 16)
	timer_label.position = Vector2(0, -2)
	timer_label.text = ""
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_label.add_theme_font_override("font", custom_font)
	timer_label.add_theme_font_size_override("font_size", 15)
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
	is_permanent = (buff_data.type == BuffManager.BuffType.PERMANENT)

	if buff_data.icon_path != "" and ResourceLoader.exists(buff_data.icon_path):
		icon.texture = load(buff_data.icon_path)
	else:
		print("图标加载失败，使用透明占位符")
		var placeholder_texture = ImageTexture.new()
		var placeholder_image = Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
		placeholder_image.fill(Color(0, 0, 0, 0))
		placeholder_texture.set_image(placeholder_image)
		icon.texture = placeholder_texture

	_update_display()

func _update_display():
	if not stack_text_override.is_empty():
		stack_label.text = stack_text_override
		stack_label.visible = true
	elif stack_count > 1 or buff_id == "faze_bullet" or buff_id == "barrage_charge" or buff_id == "thunder_gun_ammo":
		stack_label.text = str(stack_count)
		stack_label.visible = true
	else:
		stack_label.visible = false

	if is_permanent:
		timer_label.visible = false
	else:
		timer_label.visible = true
		if remaining_time > 0:
			timer_label.text = str(int(ceil(remaining_time)) - 1)
		else:
			timer_label.text = "0"

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

func set_stack_text_override(text: String) -> void:
	stack_text_override = text
	_update_display()

func _process(delta: float):
	if Global.is_battle_time_paused():
		return
	if not is_permanent and remaining_time > 0:
		remaining_time -= delta
		if remaining_time <= 0:
			remaining_time = 0
			buff_expired.emit()
		_update_display()
		_update_flash_state()

func _create_tooltip():
	tooltip_panel = Panel.new()
	tooltip_panel.name = "TooltipPanel"
	tooltip_panel.visible = false
	tooltip_panel.z_index = 100
	tooltip_panel.modulate.a = 0.0
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0, 0, 0.4)
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	tooltip_panel.add_theme_stylebox_override("panel", style_box)

	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.add_child(vbox)

	var hbox = HBoxContainer.new()
	hbox.name = "HeaderHBox"
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hbox)

	var custom_font = load("res://AssetBundle/Uranus_Pixel_11Px.ttf")

	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_override("font", custom_font)
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	hbox.add_child(name_label)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(spacer)

	var type_label = Label.new()
	type_label.name = "TypeLabel"
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	type_label.add_theme_font_override("font", custom_font)
	type_label.add_theme_font_size_override("font_size", 18)
	type_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	hbox.add_child(type_label)

	var desc_label = Label.new()
	desc_label.name = "DescLabel"
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_label.add_theme_font_override("font", custom_font)
	desc_label.add_theme_font_size_override("font_size", 15)
	desc_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	vbox.add_child(desc_label)

	vbox.position = Vector2(8, 6)

	add_child(tooltip_panel)

func _on_mouse_entered():
	if buff_id != "":
		_show_tooltip()

func _on_mouse_exited():
	_hide_tooltip()

func _show_tooltip():
	var buff_data = BuffManager.get_buff_data(buff_id)
	if buff_data == null:
		return

	var name_label = tooltip_panel.get_node("VBoxContainer/HeaderHBox/NameLabel")
	name_label.text = buff_data.name

	var type_label = tooltip_panel.get_node("VBoxContainer/HeaderHBox/TypeLabel")
	var type_text = ""
	if buff_data.type == BuffManager.BuffType.PERMANENT:
		type_text = "永久"
	type_label.text = type_text

	var desc_label = tooltip_panel.get_node("VBoxContainer/DescLabel")
	desc_label.text = buff_data.description

	var content_size = Vector2(200, 0)
	var header_height = 24
	var desc_height = desc_label.get_theme_font("font").get_multiline_string_size(buff_data.description, HORIZONTAL_ALIGNMENT_LEFT, content_size.x - 16, 15).y
	content_size.y = header_height + desc_height + 24

	tooltip_panel.size = content_size
	tooltip_panel.get_node("VBoxContainer").size = Vector2(content_size.x - 16, content_size.y - 12)

	tooltip_panel.position = Vector2((size.x - content_size.x) / 2, -content_size.y - 5)

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
