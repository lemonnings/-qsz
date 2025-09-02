extends Control

# 技能快捷键配置窗口管理器
# 用于管理技能快捷键的拖拽配置界面

class_name SkillHotkeyConfig

# UI节点引用
@export var skill_list_container: VBoxContainer
@export var hotkey_slots_container: HBoxContainer
@export var close_button: Button
@export var reset_button: Button
@export var confirm_button: Button

# 技能管理器引用
var active_skill_manager: ActiveSkillManager

# 技能槽位按钮
var hotkey_buttons: Dictionary = {}

# 技能项目列表
var skill_items: Array = []

# 拖拽相关
var dragging_skill: String = ""
var drag_preview: Control = null

# 信号
signal config_confirmed
signal config_cancelled

func _ready():
	# 获取技能管理器引用
	active_skill_manager = Global.ActiveSkillManager
	if not active_skill_manager:
		print("警告: 未找到ActiveSkillManager")
	
	# 初始化UI
	init_ui()
	
	# 连接信号
	connect_signals()
	
	# 刷新显示
	refresh_display()

func init_ui():
	"""初始化UI界面"""
	# 创建主容器
	if not skill_list_container:
		skill_list_container = VBoxContainer.new()
		skill_list_container.name = "SkillListContainer"
		add_child(skill_list_container)
	
	if not hotkey_slots_container:
		hotkey_slots_container = HBoxContainer.new()
		hotkey_slots_container.name = "HotkeyContainer"
		add_child(hotkey_slots_container)
	
	# 创建快捷键槽位
	create_hotkey_slots()
	
	# 创建按钮
	create_control_buttons()

func create_hotkey_slots():
	"""创建快捷键槽位"""
	var slot_keys = ["shift", "space", "q", "e"]
	var slot_names = ["Shift", "Space", "Q", "E"]
	
	for i in range(slot_keys.size()):
		var slot_key = slot_keys[i]
		var slot_name = slot_names[i]
		
		# 创建槽位容器
		var slot_container = VBoxContainer.new()
		slot_container.custom_minimum_size = Vector2(120, 150)
		hotkey_slots_container.add_child(slot_container)
		
		# 创建标签
		var label = Label.new()
		label.text = slot_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_container.add_child(label)
		
		# 创建槽位按钮
		var slot_button = Button.new()
		slot_button.custom_minimum_size = Vector2(100, 100)
		slot_button.text = "空"
		slot_button.name = "slot_" + slot_key
		slot_container.add_child(slot_button)
		
		# 设置拖拽接收
		slot_button.mouse_filter = Control.MOUSE_FILTER_PASS
		slot_button.connect("gui_input", Callable(self, "_on_slot_input").bind(slot_key))
		
		hotkey_buttons[slot_key] = slot_button

func create_control_buttons():
	"""创建控制按钮"""
	var button_container = HBoxContainer.new()
	add_child(button_container)
	
	# 重置按钮
	if not reset_button:
		reset_button = Button.new()
		reset_button.text = "重置"
		button_container.add_child(reset_button)
	
	# 确认按钮
	if not confirm_button:
		confirm_button = Button.new()
		confirm_button.text = "确认"
		button_container.add_child(confirm_button)
	
	# 关闭按钮
	if not close_button:
		close_button = Button.new()
		close_button.text = "关闭"
		button_container.add_child(close_button)

func connect_signals():
	"""连接信号"""
	if reset_button:
		reset_button.pressed.connect(_on_reset_pressed)
	
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)
	
	if close_button:
		close_button.pressed.connect(_on_close_pressed)

func refresh_display():
	"""刷新显示"""
	refresh_skill_list()
	refresh_hotkey_slots()

func refresh_skill_list():
	"""刷新技能列表"""
	# 清空现有技能项目
	for item in skill_items:
		if is_instance_valid(item):
			item.queue_free()
	skill_items.clear()
	
	if not active_skill_manager:
		return
	
	# 添加已掌握的技能
	var mastered_skills = active_skill_manager.get_mastered_skills()
	for skill in mastered_skills:
		create_skill_item(skill)
	
	# TODO: 添加法宝槽位
	create_treasure_item()

func create_skill_item(skill):
	"""创建技能项目"""
	var skill_item = create_draggable_item(skill.name, skill.id, "skill")
	skill_list_container.add_child(skill_item)
	skill_items.append(skill_item)

func create_treasure_item():
	"""创建法宝项目"""
	# TODO: 实现法宝系统后完善此功能
	var treasure_item = create_draggable_item("法宝(未实现)", "treasure_placeholder", "treasure")
	treasure_item.modulate = Color.GRAY  # 灰色表示未实现
	skill_list_container.add_child(treasure_item)
	skill_items.append(treasure_item)

func create_draggable_item(display_name: String, item_id: String, item_type: String) -> Control:
	"""创建可拖拽的项目"""
	var item_container = PanelContainer.new()
	item_container.custom_minimum_size = Vector2(200, 50)
	
	# 创建标签
	var label = Label.new()
	label.text = display_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item_container.add_child(label)
	
	# 设置拖拽数据
	item_container.set_meta("item_id", item_id)
	item_container.set_meta("item_type", item_type)
	item_container.set_meta("display_name", display_name)
	
	# 连接拖拽事件
	item_container.gui_input.connect(_on_item_input.bind(item_container))
	
	return item_container

func refresh_hotkey_slots():
	"""刷新快捷键槽位显示"""
	if not active_skill_manager:
		return
	
	for slot_key in hotkey_buttons.keys():
		var button = hotkey_buttons[slot_key]
		var skill_id = active_skill_manager.get_skill_slot(slot_key)
		
		if skill_id:
			var skill = active_skill_manager.get_skill_by_id(skill_id)
			if skill:
				button.text = skill.name
			else:
				button.text = skill_id  # 显示ID作为备选
		else:
			button.text = "空"

func _on_item_input(event: InputEvent, item: Control):
	"""处理技能项目输入"""
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			# 开始拖拽
			start_drag(item)

func start_drag(item: Control):
	"""开始拖拽"""
	dragging_skill = item.get_meta("item_id")
	
	# 创建拖拽预览
	create_drag_preview(item)
	
	# 设置鼠标捕获
	set_process(true)

func create_drag_preview(item: Control):
	"""创建拖拽预览"""
	if drag_preview:
		drag_preview.queue_free()
	
	drag_preview = item.duplicate()
	drag_preview.modulate = Color(1, 1, 1, 0.7)  # 半透明
	drag_preview.z_index = 100  # 置于最上层
	get_viewport().add_child(drag_preview)

func _process(_delta):
	"""处理拖拽过程"""
	if dragging_skill and drag_preview:
		# 更新预览位置
		drag_preview.global_position = get_global_mouse_position() - drag_preview.size / 2
		
		# 检查鼠标释放
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			end_drag()

func end_drag():
	"""结束拖拽"""
	set_process(false)
	
	# 清理拖拽预览
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null
	
	dragging_skill = ""

func _on_slot_input(event: InputEvent, slot_key: String):
	"""处理槽位输入"""
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			# 鼠标释放，检查是否有拖拽的技能
			if dragging_skill:
				assign_skill_to_slot(dragging_skill, slot_key)
				end_drag()
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			# 右键清空槽位
			clear_slot(slot_key)

func assign_skill_to_slot(skill_id: String, slot_key: String):
	"""将技能分配到槽位"""
	if not active_skill_manager:
		return
	
	# TODO: 检查法宝类型的处理
	if skill_id == "treasure_placeholder":
		print("法宝系统尚未实现")
		return
	
	# 分配技能到槽位
	if active_skill_manager.set_skill_slot(slot_key, skill_id):
		refresh_hotkey_slots()
		print("技能 ", skill_id, " 已分配到 ", slot_key, " 键")
	else:
		print("分配技能失败")

func clear_slot(slot_key: String):
	"""清空槽位"""
	if not active_skill_manager:
		return
	
	active_skill_manager.set_skill_slot(slot_key, "")
	refresh_hotkey_slots()
	print("已清空 ", slot_key, " 键槽位")

func _on_reset_pressed():
	"""重置按钮按下"""
	if not active_skill_manager:
		return
	
	# 清空所有槽位
	for slot_key in hotkey_buttons.keys():
		active_skill_manager.set_skill_slot(slot_key, "")
	
	refresh_hotkey_slots()
	print("已重置所有快捷键配置")

func _on_confirm_pressed():
	"""确认按钮按下"""
	# TODO: 保存配置到文件
	config_confirmed.emit()
	hide()
	print("快捷键配置已确认")

func _on_close_pressed():
	"""关闭按钮按下"""
	config_cancelled.emit()
	hide()

func show_config():
	"""显示配置窗口"""
	refresh_display()
	show()

func hide_config():
	"""隐藏配置窗口"""
	hide()

# 保存和加载配置的方法
func save_config_to_file():
	"""保存配置到文件"""
	# TODO: 实现配置文件保存
	pass

func load_config_from_file():
	"""从文件加载配置"""
	# TODO: 实现配置文件加载
	pass

# 注意：创建配置UI的方法应该在其他脚本中，不在这个文件中
# 如果需要在其他地方创建配置UI，请参考以下代码：
# var config_ui = SkillHotkeyConfig.new()
# add_child(config_ui)
# config_ui.show_config()