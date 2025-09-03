extends Control
class_name EmblemUI

# UI组件
var icon: TextureRect
var stack_label: Label
var background: NinePatchRect

# 纹章数据
var emblem_config
var current_stack: int = 1

func _init():
	# 设置基本属性
	size = Vector2(64, 64)
	
	# 创建背景
	background = NinePatchRect.new()
	background.size = Vector2(64, 64)
	background.position = Vector2.ZERO
	# TODO: 设置背景纹理
	# background.texture = preload("res://path/to/emblem_background.png")
	add_child(background)
	
	# 创建图标
	icon = TextureRect.new()
	icon.size = Vector2(48, 48)
	icon.position = Vector2(8, 8)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(icon)
	
	# 创建层数标签
	stack_label = Label.new()
	stack_label.size = Vector2(20, 20)
	stack_label.position = Vector2(44, 44)
	stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# TODO: 设置字体样式
	# stack_label.add_theme_font_size_override("font_size", 12)
	add_child(stack_label)

func setup_emblem(config, stack: int):
	emblem_config = config
	current_stack = stack
	
	# 设置图标
	if config.icon_path and config.icon_path != "":
		var texture = load(config.icon_path)
		if texture:
			icon.texture = texture
	
	# 更新层数显示
	update_stack_display()
	
	# 设置工具提示
	update_tooltip()

func update_emblem(stack: int):
	current_stack = stack
	update_stack_display()
	update_tooltip()

func update_stack_display():
	if current_stack > 1:
		stack_label.text = str(current_stack)
		stack_label.visible = true
	else:
		stack_label.visible = false

func update_tooltip():
	if emblem_config:
		var tooltip_text = emblem_config.name + "\n"
		tooltip_text += emblem_config.description + "\n"
		tooltip_text += "层数: " + str(current_stack) + "/" + str(emblem_config.max_stack)
		tooltip_text = tooltip_text