extends Node
class_name EmblemManager

# 纹章容器引用
var emblem_container: HBoxContainer

# 当前持有的纹章字典 {emblem_id: EmblemUI}
static var active_emblems: Dictionary = {}

# 纹章数据字典 {emblem_id: {stack, emblem_data}}
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

func _on_emblem_added(emblem_id: String, stack: int):
	print("Adding emblem: ", emblem_id, " Stack: ", stack)
	
	# 获取纹章配置数据
	var emblem_config = Global.SettingEmblem.get_emblem_data(emblem_id)
	if not emblem_config:
		print("Error: Emblem config not found for ID: ", emblem_id)
		return
	
	# 如果纹章已存在，更新它
	if active_emblems.has(emblem_id):
		_update_existing_emblem(emblem_id, stack, emblem_config)
	else:
		_create_new_emblem(emblem_id, stack, emblem_config)

func _create_new_emblem(emblem_id: String, stack: int, emblem_config):
	# 创建新的EmblemUI
	var emblem_ui = preload("res://Script/config/emblem_ui.gd").new()
	emblem_ui.name = "Emblem_" + emblem_id
	
	# 添加到容器
	if emblem_container:
		emblem_container.add_child(emblem_ui)
	
	# 设置纹章数据
	emblem_ui.setup_emblem(emblem_config, stack)
	
	# 保存引用
	active_emblems[emblem_id] = emblem_ui
	emblem_data[emblem_id] = {
		"stack": stack,
		"emblem_config": emblem_config
	}

func _update_existing_emblem(emblem_id: String, stack: int, emblem_config):
	var emblem_ui = active_emblems[emblem_id]
	var current_data = emblem_data[emblem_id]
	
	# 更新层数
	current_data["stack"] = min(stack, emblem_config.max_stack)
	
	# 更新UI显示
	emblem_ui.update_emblem(current_data["stack"])

func _on_emblem_removed(emblem_id: String):
	print("Removing emblem: ", emblem_id)
	
	if active_emblems.has(emblem_id):
		# 移除UI
		var emblem_ui = active_emblems[emblem_id]
		if emblem_ui and is_instance_valid(emblem_ui):
			emblem_ui.queue_free()
		
		# 清理数据
		active_emblems.erase(emblem_id)
		emblem_data.erase(emblem_id)

func _on_emblem_stack_changed(emblem_id: String, new_stack: int):
	if active_emblems.has(emblem_id) and emblem_data.has(emblem_id):
		var emblem_config = emblem_data[emblem_id]["emblem_config"]
		emblem_data[emblem_id]["stack"] = min(new_stack, emblem_config.max_stack)
		
		var emblem_ui = active_emblems[emblem_id]
		if emblem_ui and is_instance_valid(emblem_ui):
			emblem_ui.update_emblem(emblem_data[emblem_id]["stack"])

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