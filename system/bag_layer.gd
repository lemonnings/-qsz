extends CanvasLayer

# 背包物品管理器 - 负责背包界面展示和交互

@export var bag_panel: Panel # 背包页右侧显示的panel
@export var all: Button # 全部页签
@export var consumable: Button # 消耗页签
@export var material: Button # 材料页签
@export var special: Button # 特殊页签

@export var bag_detail: FlowContainer # 背包显示格子容器
@export var bag_item1: Panel # 具体的每个格子，共7*4=28个格子
@export var bag_item2: Panel
@export var bag_item3: Panel
@export var bag_item4: Panel
@export var bag_item5: Panel
@export var bag_item6: Panel
@export var bag_item7: Panel
@export var bag_item8: Panel
@export var bag_item9: Panel
@export var bag_item10: Panel
@export var bag_item11: Panel
@export var bag_item12: Panel
@export var bag_item13: Panel
@export var bag_item14: Panel
@export var bag_item15: Panel
@export var bag_item16: Panel
@export var bag_item17: Panel
@export var bag_item18: Panel
@export var bag_item19: Panel
@export var bag_item20: Panel
@export var bag_item21: Panel
@export var bag_item22: Panel
@export var bag_item23: Panel
@export var bag_item24: Panel
@export var bag_item25: Panel
@export var bag_item26: Panel
@export var bag_item27: Panel
@export var bag_item28: Panel

@export var page1: Button # 切换背包分頁1~3
@export var page2: Button
@export var page3: Button

@export var now_character: AnimatedSprite2D # 当前角色人物的动画
@export var now_character_name: RichTextLabel # 当前角色名字
@export var now_character_attr: RichTextLabel # 当前角色属性

@export var other_attr: Button # 次要属性按钮
@export var exit_button: Button # 退出界面按钮

# 当前页签和分页状态
var current_tab: String = "all" # all, consumable, material, special
var current_page: int = 1
const ITEMS_PER_PAGE: int = 28

# 背包格子数组
var bag_slots: Array = []

# 排序后的物品列表
var sorted_items: Array = []

# 悬浮提示框
var tooltip_panel: Panel = null
var tooltip_visible: bool = false

# 次要属性面板
var secondary_attr_panel: Panel = null
var secondary_attr_tween: Tween = null # 次要属性面板动画

# 双击检测
var last_click_time: float = 0.0
var last_click_slot: int = -1
const DOUBLE_CLICK_TIME: float = 0.3

# 界面过渡动画
var transition_tween: Tween

# 提示框字体
var tooltip_font: Font = null
const TOOLTIP_FONT_SIZE: int = 24

func _ready():
	# 预加载字体
	if ResourceLoader.exists("res://AssetBundle/Uranus_Pixel_11Px.ttf"):
		tooltip_font = load("res://AssetBundle/Uranus_Pixel_11Px.ttf")
	
	# 初始化背包格子数组
	_init_bag_slots()
	
	# 连接页签按钮信号
	if all:
		all.pressed.connect(_on_all_pressed)
	if consumable:
		consumable.pressed.connect(_on_consumable_pressed)
	if material:
		material.pressed.connect(_on_material_pressed)
	if special:
		special.pressed.connect(_on_special_pressed)
	
	# 连接分页按钮信号
	if page1:
		page1.pressed.connect(_on_page1_pressed)
	if page2:
		page2.pressed.connect(_on_page2_pressed)
	if page3:
		page3.pressed.connect(_on_page3_pressed)
	
	# 连接退出按钮信号
	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)
	
	# 创建悬浮提示框
	_create_tooltip()
	
	# 创建次要属性面板
	_create_secondary_attr_panel()
	
	# 连接次要属性按钮鼠标事件
	if other_attr:
		other_attr.mouse_entered.connect(_on_other_attr_mouse_entered)
		other_attr.mouse_exited.connect(_on_other_attr_mouse_exited)
	
	# 监听可见性变化信号 - 每次显示时刷新界面
	visibility_changed.connect(_on_visibility_changed)

# 可见性变化时调用
func _on_visibility_changed():
	if visible:
		# 每次显示背包时刷新角色属性信息
		_update_character_info()
		
		# 默认选择全部标签并刷新显示
		current_tab = "all"
		current_page = 1
		_update_items_display()
		_update_tab_buttons()

# 初始化背包格子数组
func _init_bag_slots():
	bag_slots = [
		bag_item1, bag_item2, bag_item3, bag_item4, bag_item5, bag_item6, bag_item7,
		bag_item8, bag_item9, bag_item10, bag_item11, bag_item12, bag_item13, bag_item14,
		bag_item15, bag_item16, bag_item17, bag_item18, bag_item19, bag_item20, bag_item21,
		bag_item22, bag_item23, bag_item24, bag_item25, bag_item26, bag_item27, bag_item28
	]
	
	# 为每个格子设置鼠标事件
	for i in range(bag_slots.size()):
		var slot = bag_slots[i]
		if slot:
			# 确保格子能接收鼠标事件
			slot.mouse_filter = Control.MOUSE_FILTER_STOP
			slot.gui_input.connect(_on_slot_gui_input.bind(i))
			slot.mouse_entered.connect(_on_slot_mouse_entered.bind(i))
			slot.mouse_exited.connect(_on_slot_mouse_exited.bind(i))

# 更新角色信息显示
func _update_character_info():
	# 更新角色名称
	if now_character_name:
		now_character_name.text = PC.get_character_display_name()
	
	# 更新角色属性
	if now_character_attr:
		now_character_attr.bbcode_enabled = true
		now_character_attr.text = PC.get_character_attributes_text()
	
	# 更新角色动画
	if now_character:
		var anim_name = PC.get_character_animation_name()
		if now_character.sprite_frames and now_character.sprite_frames.has_animation(anim_name):
			now_character.play(anim_name)

# 页签按钮点击事件
func _on_all_pressed():
	_select_tab("all")

func _on_consumable_pressed():
	_select_tab("consumable")

func _on_material_pressed():
	_select_tab("material")

func _on_special_pressed():
	_select_tab("special")

# 分页按钮点击事件
func _on_page1_pressed():
	_select_page(1)

func _on_page2_pressed():
	_select_page(2)

func _on_page3_pressed():
	_select_page(3)

# 选择页签
func _select_tab(tab: String):
	current_tab = tab
	current_page = 1
	_update_items_display()
	_update_tab_buttons()

# 选择分页
func _select_page(page: int):
	current_page = page
	_update_items_display()
	_update_page_buttons()

# 更新页签按钮状态
func _update_tab_buttons():
	# 可以根据需要添加选中状态的视觉反馈
	pass

# 更新分页按钮状态
func _update_page_buttons():
	# 可以根据需要添加选中状态的视觉反馈
	pass

# 更新物品显示
func _update_items_display():
	# 获取排序后的物品列表
	sorted_items = _get_sorted_items()
	
	# 计算当前页的物品范围
	var start_index = (current_page - 1) * ITEMS_PER_PAGE
	var end_index = min(start_index + ITEMS_PER_PAGE, sorted_items.size())
	
	# 更新每个格子
	for i in range(ITEMS_PER_PAGE):
		var slot = bag_slots[i]
		if !slot:
			continue
		
		var item_index = start_index + i
		if item_index < sorted_items.size():
			var item_data = sorted_items[item_index]
			_setup_slot(slot, item_data)
		else:
			_clear_slot(slot)

# 获取排序后的物品列表
func _get_sorted_items() -> Array:
	var items = []
	
	# 遍历玩家背包
	for item_id in Global.player_inventory.keys():
		var count = Global.player_inventory[item_id]
		if count <= 0:
			continue
		
		var item_data = ItemManager.get_item_all_data(item_id)
		if item_data.is_empty():
			continue
		
		var item_type = item_data.get("item_type", "")
		
		# 根据当前页签过滤
		if current_tab == "consumable" and item_type != "consumable":
			continue
		elif current_tab == "material" and item_type != "material":
			continue
		elif current_tab == "special" and item_type != "special" and item_type != "equip":
			continue
		
		items.append({
			"item_id": item_id,
			"count": count,
			"item_type": item_type,
			"item_data": item_data
		})
	
	# 排序：消耗 > 材料 > 特殊
	items.sort_custom(_compare_items)
	
	return items

# 物品排序比较函数
func _compare_items(a: Dictionary, b: Dictionary) -> bool:
	var type_order = {
		"consumable": 0,
		"immediate": 1,
		"material": 2,
		"special": 3,
		"equip": 4
	}
	
	var order_a = type_order.get(a.item_type, 5)
	var order_b = type_order.get(b.item_type, 5)
	
	if order_a != order_b:
		return order_a < order_b
	
	# 相同类型按ID排序
	return a.item_id < b.item_id

# 设置格子显示
func _setup_slot(slot: Panel, item_data: Dictionary):
	# 查找或创建图标节点
	var icon_node = slot.get_node_or_null("Icon")
	if !icon_node:
		icon_node = TextureRect.new()
		icon_node.name = "Icon"
		icon_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_node.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_node.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_node.offset_left = 4
		icon_node.offset_top = 16
		icon_node.offset_right = -4
		icon_node.offset_bottom = -16
		slot.add_child(icon_node)
	
	# 查找或创建数量标签
	var count_label = slot.get_node_or_null("CountLabel")
	if !count_label:
		count_label = Label.new()
		count_label.name = "CountLabel"
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		count_label.offset_left = -4
		count_label.offset_top = 2
		count_label.offset_right = -12
		count_label.offset_bottom = -8
		# 设置字体样式（带黑色描边）
		_setup_label_style(count_label)
		slot.add_child(count_label)
	
	# 设置图标
	var icon_path = item_data.item_data.get("item_icon", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon_node.texture = load(icon_path)
	else:
		icon_node.texture = null
	
	# 设置数量
	if item_data.count > 1:
		count_label.text = str(item_data.count)
	else:
		count_label.text = ""
	
	# 存储物品数据到格子的meta
	slot.set_meta("item_id", item_data.item_id)
	slot.set_meta("item_data", item_data)
	icon_node.visible = true
	count_label.visible = true

# 清空格子
func _clear_slot(slot: Panel):
	var icon_node = slot.get_node_or_null("Icon")
	if icon_node:
		icon_node.texture = null
		icon_node.visible = false
	
	var count_label = slot.get_node_or_null("CountLabel")
	if count_label:
		count_label.text = ""
		count_label.visible = false
	
	slot.remove_meta("item_id")
	slot.remove_meta("item_data")

# 为Label设置字体样式（带黑色描边）
func _setup_label_style(label: Label, font_color: Color = Color.WHITE):
	if tooltip_font:
		label.add_theme_font_override("font", tooltip_font)
	label.add_theme_font_size_override("font_size", TOOLTIP_FONT_SIZE)
	label.add_theme_color_override("font_color", font_color)
	# 设置黑色描边
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)

# 创建悬浮提示框
func _create_tooltip():
	tooltip_panel = Panel.new()
	tooltip_panel.name = "TooltipPanel"
	tooltip_panel.visible = false
	tooltip_panel.z_index = 100
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 设置半透明黑色背景
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	tooltip_panel.add_theme_stylebox_override("panel", style)
	
	# 创建内容容器
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	# 不使用FULL_RECT，让VBox根据内容自动计算大小
	vbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
	vbox.position = Vector2(10, 8)
	tooltip_panel.add_child(vbox)
	
	# 物品图标和名称行
	var header_hbox = HBoxContainer.new()
	header_hbox.name = "Header"
	vbox.add_child(header_hbox)
	
	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(32, 32)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header_hbox.add_child(icon)
	
	var name_label = Label.new()
	name_label.name = "NameLabel"
	_setup_label_style(name_label)
	header_hbox.add_child(name_label)
	
	# 物品分类
	var type_label = Label.new()
	type_label.name = "TypeLabel"
	_setup_label_style(type_label, Color(0.7, 0.7, 0.7))
	vbox.add_child(type_label)
	
	# 分隔线
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	# 物品描述
	var desc_label = Label.new()
	desc_label.name = "DescLabel"
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(200, 0)
	_setup_label_style(desc_label)
	vbox.add_child(desc_label)
	
	# 分隔线
	var separator2 = HSeparator.new()
	vbox.add_child(separator2)
	# 售价
	var price_label = Label.new()
	price_label.name = "PriceLabel"
	_setup_label_style(price_label, Color(1.0, 0.85, 0.0))
	vbox.add_child(price_label)
	
	# 使用提示（消耗品专用）
	var use_hint_label = Label.new()
	use_hint_label.name = "UseHintLabel"
	_setup_label_style(use_hint_label, Color(1.0, 1.0, 0.0))
	use_hint_label.visible = false
	vbox.add_child(use_hint_label)
	
	add_child(tooltip_panel)

# 显示悬浮提示
func _show_tooltip(slot_index: int):
	var slot = bag_slots[slot_index]
	if !slot or !slot.has_meta("item_data"):
		_hide_tooltip()
		return
	
	var item_data = slot.get_meta("item_data")
	var item_info = item_data.item_data
	
	# 获取提示框内容节点
	var vbox = tooltip_panel.get_node("VBox")
	var header = vbox.get_node("Header")
	var icon = header.get_node("Icon")
	var name_label = header.get_node("NameLabel")
	var type_label = vbox.get_node("TypeLabel")
	var desc_label = vbox.get_node("DescLabel")
	var price_label = vbox.get_node("PriceLabel")
	var use_hint_label = vbox.get_node("UseHintLabel")
	
	# 先重置所有控件的大小，避免上一次的布局影响新的计算
	tooltip_panel.size = Vector2.ZERO
	tooltip_panel.custom_minimum_size = Vector2.ZERO
	vbox.size = Vector2.ZERO
	desc_label.size = Vector2.ZERO
	desc_label.custom_minimum_size = Vector2(200, 0) # 重新设置最小宽度
	
	# 设置图标
	var icon_path = item_info.get("item_icon", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	else:
		icon.texture = null
	
	# 设置名称（根据品质设置颜色）
	var item_name = item_info.get("item_name", item_data.item_id)
	var item_rare = item_info.get("item_rare", "common")
	name_label.text = "  " + item_name
	name_label.add_theme_color_override("font_color", _get_rare_color(item_rare))
	
	# 设置分类
	var item_type = item_info.get("item_type", "")
	type_label.text = _get_type_display_name(item_type)
	
	# 设置描述
	var detail = item_info.get("item_detail", "")
	var source = item_info.get("item_source", "")
	var full_desc = detail
	if source != "":
		full_desc += "\n\n[\u6765\u6e90] " + source
	desc_label.text = full_desc
	
	# 设置售价
	var price = item_info.get("item_price", 0)
	price_label.text = "售价: " + str(price)
	
	# 设置使用提示
	if item_type == "consumable" and ItemManager.can_use_item(item_data.item_id):
		use_hint_label.text = "\n双击使用物品"
		use_hint_label.visible = true
	else:
		use_hint_label.visible = false
	
	# 等待两帧让布局完全更新
	# 第一帧：重置生效
	await get_tree().process_frame
	# 第二帧：新内容布局计算完成
	await get_tree().process_frame
	
	# 获取VBox的实际内容大小
	var content_size = vbox.get_combined_minimum_size()
	# 加上边距 (10+10, 8+8)
	var panel_size = content_size + Vector2(20, 16)
	tooltip_panel.custom_minimum_size = panel_size
	tooltip_panel.size = panel_size
	
	# 将提示框放在格子旁边
	var slot_global_pos = slot.global_position
	var tooltip_pos = slot_global_pos + Vector2(slot.size.x + 10, 0)
	
	# 确保提示框不超出屏幕
	var viewport_size = get_viewport().get_visible_rect().size
	if tooltip_pos.x + tooltip_panel.size.x > viewport_size.x:
		tooltip_pos.x = slot_global_pos.x - tooltip_panel.size.x - 10
	if tooltip_pos.y + tooltip_panel.size.y > viewport_size.y:
		tooltip_pos.y = viewport_size.y - tooltip_panel.size.y - 10
	
	tooltip_panel.global_position = tooltip_pos
	tooltip_panel.visible = true
	tooltip_visible = true

# 隐藏悬浮提示
func _hide_tooltip():
	if tooltip_panel:
		tooltip_panel.visible = false
	tooltip_visible = false

# 获取品质颜色
func _get_rare_color(rare: String) -> Color:
	match rare:
		"common":
			return Color(1.0, 1.0, 1.0) # 白色
		"rare":
			return Color(0.2, 0.5, 1.0) # 蓝色
		"epic":
			return Color(0.7, 0.3, 0.9) # 紫色
		"legendary":
			return Color(1.0, 0.8, 0.0) # 金色
		"artifact":
			return Color(1.0, 0.2, 0.2) # 红色
		_:
			return Color(1.0, 1.0, 1.0)

# 获取类型显示名称
func _get_type_display_name(item_type: String) -> String:
	match item_type:
		"consumable":
			return "[消耗品]"
		"material":
			return "[材料]"
		"special":
			return "[特殊]"
		"equip":
			return "[装备]"
		"immediate":
			return "[即时]"
		_:
			return "[未知]"

# 格子鼠标事件处理
func _on_slot_gui_input(event: InputEvent, slot_index: int):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_slot_click(slot_index)

# 处理格子点击
func _handle_slot_click(slot_index: int):
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# 检测双击
	if last_click_slot == slot_index and (current_time - last_click_time) < DOUBLE_CLICK_TIME:
		_on_slot_double_click(slot_index)
		last_click_slot = -1
		last_click_time = 0
	else:
		last_click_slot = slot_index
		last_click_time = current_time

# 双击格子事件
func _on_slot_double_click(slot_index: int):
	var slot = bag_slots[slot_index]
	if !slot or !slot.has_meta("item_id"):
		return
	
	var item_id = slot.get_meta("item_id")
	var item_data = slot.get_meta("item_data")
	
	# 检查是否可以使用
	if !ItemManager.can_use_item(item_id):
		_show_message("该物品无法使用")
		return
	
	# 使用物品
	var result = ItemManager.use_item(item_id, 1)
	if result.success:
		_show_message(result.message)
		# 刷新显示
		_update_items_display()
		_update_character_info()
		_hide_tooltip()
	else:
		_show_message(result.message)

# 鼠标进入格子
func _on_slot_mouse_entered(slot_index: int):
	_show_tooltip(slot_index)

# 鼠标离开格子
func _on_slot_mouse_exited(slot_index: int):
	_hide_tooltip()

# 显示消息提示
func _show_message(message: String):
	var main_town = get_parent()
	if main_town and main_town.tip:
		main_town.tip.start_animation(message, 0.5)
	else:
		print("[Bag] ", message)

# 退出按钮点击事件
func _on_exit_pressed():
	# 保存游戏
	Global.save_game()
	_transition_to_layer()

# 界面过渡动画
func _transition_to_layer():
	if transition_tween:
		transition_tween.kill()
	
	transition_tween = create_tween()
	transition_tween.set_parallel(true)
	
	# 淡出当前层的所有子节点
	for child in get_children():
		if child.has_method("set_modulate"):
			transition_tween.tween_property(child, "modulate:a", 0.0, 0.125)
	
	# 等待淡出完成后处理退出逻辑
	transition_tween.tween_callback(_handle_exit).set_delay(0.125)

# 处理退出逻辑
func _handle_exit():
	# 调用main_town的_on_exit_pressed方法来处理dark_overlay
	var main_town = get_parent()
	if main_town and main_town.has_method("_on_exit_pressed"):
		main_town._on_exit_pressed()
	
	_switch_layers()

# 切换界面层
func _switch_layers():
	# 隐藏当前层
	visible = false
	# 重置所有子节点的透明度
	for child in get_children():
		if child.has_method("set_modulate"):
			child.modulate.a = 1.0
	
	# 保存游戏
	Global.save_game()
	
	# 恢复玩家控制和游戏状态
	PC.movement_disabled = false
	get_tree().paused = false

# 刷新背包显示（供外部调用）
func refresh_bag():
	_update_character_info()
	_update_items_display()

# 显示背包界面
func show_bag():
	visible = true
	PC.movement_disabled = true
	get_tree().paused = true
	refresh_bag()

# 创建次要属性面板
func _create_secondary_attr_panel():
	secondary_attr_panel = Panel.new()
	secondary_attr_panel.name = "SecondaryAttrPanel"
	secondary_attr_panel.visible = false
	secondary_attr_panel.z_index = 100
	secondary_attr_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	secondary_attr_panel.modulate.a = 0.0 # 初始透明
	
	# 设置半透明黑色背景
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.65)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	secondary_attr_panel.add_theme_stylebox_override("panel", style)
	
	# 创建内容标签
	var content_label = Label.new()
	content_label.name = "ContentLabel"
	content_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	content_label.position = Vector2(12, 10)
	content_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER # 文字居中
	_setup_label_style(content_label)
	secondary_attr_panel.add_child(content_label)
	
	add_child(secondary_attr_panel)

# 次要属性按钮鼠标进入
func _on_other_attr_mouse_entered():
	_show_secondary_attr_panel()

# 次要属性按钮鼠标离开
func _on_other_attr_mouse_exited():
	_hide_secondary_attr_panel()

# 显示次要属性面板
func _show_secondary_attr_panel():
	if !secondary_attr_panel or !other_attr:
		return
	
	# 获取次要属性文本
	var content_label = secondary_attr_panel.get_node("ContentLabel")
	if content_label:
		content_label.text = PC.get_secondary_attributes_text()
	
	# 等待一帧让布局更新
	await get_tree().process_frame
	
	# 计算面板大小
	if content_label:
		var content_size = content_label.get_combined_minimum_size()
		var panel_size = content_size + Vector2(24, 20)
		secondary_attr_panel.custom_minimum_size = panel_size
		secondary_attr_panel.size = panel_size
	
	# 将面板放在按钮上方
	var btn_global_pos = other_attr.global_position
	var panel_pos = btn_global_pos - Vector2(-5, secondary_attr_panel.size.y + 5)
	
	# 确保不超出屏幕顶部
	if panel_pos.y < 0:
		panel_pos.y = btn_global_pos.y + other_attr.size.y + 5
	
	# 确保不超出屏幕右侧
	var viewport_size = get_viewport().get_visible_rect().size
	if panel_pos.x + secondary_attr_panel.size.x > viewport_size.x:
		panel_pos.x = viewport_size.x - secondary_attr_panel.size.x - 10
	
	secondary_attr_panel.global_position = panel_pos
	secondary_attr_panel.visible = true
	
	# 渐入动画 - 先停止旧动画
	if secondary_attr_tween and secondary_attr_tween.is_valid():
		secondary_attr_tween.kill()
	secondary_attr_tween = create_tween()
	secondary_attr_tween.tween_property(secondary_attr_panel, "modulate:a", 1.0, 0.3)

# 隐藏次要属性面板
func _hide_secondary_attr_panel():
	if secondary_attr_panel:
		# 渐出动画 - 先停止旧动画
		if secondary_attr_tween and secondary_attr_tween.is_valid():
			secondary_attr_tween.kill()
		secondary_attr_tween = create_tween()
		secondary_attr_tween.tween_property(secondary_attr_panel, "modulate:a", 0.0, 0.3)
		secondary_attr_tween.tween_callback(func(): secondary_attr_panel.visible = false)
