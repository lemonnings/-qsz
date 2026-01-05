extends Node
class_name EmblemManager

# 纹章容器引用
var emblem_container: HBoxContainer

# 使用 Stage1 提供的 UI 组件
var emblem_icons: Array = []
var emblem_panels: Array = []
var emblem_details: Array = []
var emblem_stack_labels: Array = []  # 层数标签数组

# 当前持有的纹章字典 {emblem_id: {"slot": int}}
static var active_emblems: Dictionary = {}

# 纹章数据字典 {emblem_id: {stack, emblem_data, slot}}
static var emblem_data: Dictionary = {}

func _ready():
	# 连接全局信号
	Global.connect("emblem_added", Callable(self, "_on_emblem_added"))
	Global.connect("emblem_removed", Callable(self, "_on_emblem_removed"))
	Global.connect("emblem_stack_changed", Callable(self, "_on_emblem_stack_changed"))

func setup_emblem_container(container: HBoxContainer):
	emblem_container = container
	if emblem_container:
		# 设置容器属性
		emblem_container.alignment = BoxContainer.ALIGNMENT_CENTER
		emblem_container.add_theme_constant_override("separation", 8)

# 新的 UI 注册：使用 Stage1 暴露的 TextureRect、Panel、RichTextLabel
# 初始化 UI 槽位（由 stage1.gd 传入）
func setup_emblem_ui(icons: Array, panels: Array, details: Array) -> void:
	assert(icons.size() == panels.size() and panels.size() == details.size(), "setup_emblem_ui: 参数数组长度不一致")
	
	emblem_icons = icons
	emblem_panels = panels
	emblem_details = details
	
	# 基础初始化：隐藏面板、清空图标和详情，创建层数标签
	for i in range(emblem_icons.size()):
		var icon = emblem_icons[i]
		var panel = emblem_panels[i]
		var detail = emblem_details[i]
		assert(icon != null and panel != null and detail != null, "setup_emblem_ui: 存在空槽位节点")
		panel.visible = false
		detail.visible = false
		icon.texture = null
		detail.clear()
		# Godot 4.4 RichTextLabel：开启 BBCode 解析
		detail.bbcode_enabled = true
		
		# 为每个图标创建层数标签，显示在右下角
		var stack_label = Label.new()
		stack_label.name = "StackLabel_" + str(i)
		# 设置标签大小和位置（相对于父节点）
		stack_label.size = Vector2(20, 20)
		stack_label.position = Vector2(52, 42)  # 64x64图标的右下角
		stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# 设置字体大小和颜色，确保清晰可读
		stack_label.add_theme_font_size_override("font_size", 19)
		stack_label.add_theme_color_override("font_color", Color(1, 1, 1))  # 白色
		stack_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0))  # 黑色阴影
		stack_label.add_theme_constant_override("shadow_outline_size", 4)
		stack_label.visible = false  # 初始隐藏
		
		# 将标签添加到图标的父节点（面板）
		icon.add_child(stack_label)
		
		emblem_stack_labels.append(stack_label)

func _on_emblem_added(emblem_id: String, stack: int):
	print("Adding emblem: ", emblem_id, " Stack: ", stack)
	# 获取纹章配置数据
	var emblem_config = Global.SettingEmblem.get_emblem_data(emblem_id)
	# 如果纹章已存在，更新它
	if active_emblems.has(emblem_id):
		_update_existing_emblem(emblem_id, stack, emblem_config)
	else:
		_create_new_emblem(emblem_id, stack, emblem_config)


func _create_new_emblem(emblem_id: String, stack: int, emblem_config):
	# 选择一个空槽位；如果没有空槽，直接抛出异常（便于及时修改 UI）
	var slot := _find_empty_slot()
	assert(slot != -1, "没有可用的纹章UI槽位")
	# 保存引用与数据
	active_emblems[emblem_id] = {"slot": slot}
	emblem_data[emblem_id] = {
		"stack": stack,
		"emblem_config": emblem_config,
		"slot": slot
	}
	
	# 加载图标资源并设置到对应 TextureRect 特殊系统函数说明：load(path) 会在运行时加载资源（此处为 Texture2D）
	var tex: Texture2D = load(emblem_config.icon_path)
	emblem_icons[slot].texture = tex
	emblem_details[slot].text = _build_emblem_detail_text(emblem_config.name, emblem_config.description, stack, emblem_config.max_stack)
	
	_update_stack_label(slot, stack)

func _update_existing_emblem(emblem_id: String, stack: int, emblem_config):
	var current_data = emblem_data[emblem_id]
	# 更新层数（直接以最小值限制）
	current_data["stack"] = min(stack, emblem_config.max_stack)
	# 根据槽位更新详情文本
	var slot: int = current_data["slot"]
	emblem_details[slot].text = _build_emblem_detail_text(emblem_config.name, emblem_config.description, current_data["stack"], emblem_config.max_stack)
	
	# 更新层数标签显示
	_update_stack_label(slot, current_data["stack"])

func _on_emblem_removed(emblem_id: String):
	print("Removing emblem: ", emblem_id)
	if active_emblems.has(emblem_id):
		var slot: int = emblem_data[emblem_id]["slot"]
		# 清空槽位显示
		emblem_icons[slot].texture = null
		emblem_details[slot].text = ""
		emblem_panels[slot].visible = false
		emblem_details[slot].visible = false
		
		# 隐藏层数标签
		if slot < emblem_stack_labels.size() and emblem_stack_labels[slot]:
			emblem_stack_labels[slot].visible = false
		
		# 清理数据
		active_emblems.erase(emblem_id)
		emblem_data.erase(emblem_id)

func _on_emblem_stack_changed(emblem_id: String, new_stack: int):
	if active_emblems.has(emblem_id) and emblem_data.has(emblem_id):
		var emblem_config = emblem_data[emblem_id]["emblem_config"]
		emblem_data[emblem_id]["stack"] = min(new_stack, emblem_config.max_stack)
		var slot: int = emblem_data[emblem_id]["slot"]
		# 同步更新 UI 文本
		emblem_details[slot].text = _build_emblem_detail_text(emblem_config.name, emblem_config.description, emblem_data[emblem_id]["stack"], emblem_config.max_stack)
		
		# 更新层数标签显示
		_update_stack_label(slot, emblem_data[emblem_id]["stack"])

# 公共方法：添加纹章
static func add_emblem(emblem_id: String, stack: int = 1) -> bool:
	# 检查是否超过纹章数量上限
	if not active_emblems.has(emblem_id) and get_emblem_count() >= PC.emblem_slots_max:
		print("纹章数量已达上限：", PC.emblem_slots_max)
		return false
	# 获取纹章配置数据
	var emblem_config = Global.SettingEmblem.get_emblem_data(emblem_id)
	if not emblem_config:
		print("Error: Emblem config not found for ID: ", emblem_id)
		return false
	# 添加或更新纹章
	if active_emblems.has(emblem_id):
		var current_stack = emblem_data[emblem_id]["stack"]
		var new_stack = min(current_stack + stack, emblem_config.max_stack)
		Global.emit_signal("emblem_stack_changed", emblem_id, new_stack)
	else:
		Global.emit_signal("emblem_added", emblem_id, stack)
	# 更新PC中的纹章记录
	if PC.current_emblems.has(emblem_id):
		PC.current_emblems[emblem_id] = min(PC.current_emblems[emblem_id] + stack, emblem_config.max_stack)
	else:
		PC.current_emblems[emblem_id] = stack
	return true


# 公共方法：移除纹章
static func remove_emblem(emblem_id: String):
	Global.emit_signal("emblem_removed", emblem_id)
	# 同步更新PC中的纹章记录
	if PC.current_emblems.has(emblem_id):
		PC.current_emblems.erase(emblem_id)

# 公共方法：检查纹章是否存在
static func has_emblem(emblem_id: String) -> bool:
	return active_emblems.has(emblem_id)

# 公共方法：获取纹章层数
static func get_emblem_stack(emblem_id: String) -> int:
	if emblem_data.has(emblem_id):
		return emblem_data[emblem_id]["stack"]
	return 0

# 公共方法：清除所有纹章
static func clear_all_emblems():
	for emblem_id in active_emblems.keys():
		remove_emblem(emblem_id)
	# 清除PC中的纹章记录
	PC.current_emblems.clear()

# 公共方法：获取所有活跃纹章的ID列表
static func get_active_emblem_ids() -> Array:
	return active_emblems.keys()

# 公共方法：获取当前纹章数量
static func get_emblem_count() -> int:
	return active_emblems.size()

# 查找空槽位
func _find_empty_slot() -> int:
	for i in range(emblem_icons.size()):
		if not _slot_in_use(i):
			return i
	return -1

# 槽位是否被使用
func _slot_in_use(index: int) -> bool:
	for k in active_emblems.keys():
		if active_emblems[k].has("slot") and active_emblems[k]["slot"] == index:
			return true
	return false

# 更新层数标签显示
func _update_stack_label(slot: int, stack: int) -> void:
	if slot >= emblem_stack_labels.size() or not emblem_stack_labels[slot]:
		return
	
	var label = emblem_stack_labels[slot]
	if stack >= 1:
		label.text = str(stack)
		label.visible = true
	else:
		label.visible = false

# 构建纹章详情文本（RichTextLabel 使用 BBCode 文本）
func _build_emblem_detail_text(name: String, description: String, current_stack: int, max_stack: int) -> String:
	var lines: Array[String] = []
	lines.append("[font_size=30]" + name + "[/font_size]")
	lines.append("效果：" + description)
	lines.append("")
	lines.append("层数：" + str(current_stack))
	lines.append("最大层数：" + str(max_stack))
	return "\n".join(lines)
