extends Node
class_name BuffManager

# Buff类型枚举
enum BuffType {
	PERMANENT,  # 永久buff
	TEMPORARY   # 临时buff
}

# Buff数据结构
class BuffData:
	var id: String
	var name: String
	var icon_path: String
	var type: BuffType
	var max_stack: int = 1
	var description: String = ""
	
	func _init(buff_id: String, buff_name: String, buff_icon_path: String, buff_type: BuffType, buff_max_stack: int = 1, buff_description: String = ""):
		id = buff_id
		name = buff_name
		icon_path = buff_icon_path
		type = buff_type
		max_stack = buff_max_stack
		description = buff_description

# Buff配置字典
static var buff_configs: Dictionary = {}

# Buff容器引用
var buff_container: HBoxContainer

# 当前活跃的buff字典 {buff_id: BuffUI}
static var active_buffs: Dictionary = {}

# Buff数据字典 {buff_id: {remaining_time, stack, buff_data}}
static var buff_data: Dictionary = {}

func _ready():
	# 清理静态数据，防止跨局残留
	active_buffs.clear()
	buff_data.clear()

	# 初始化buff配置
	_init_buff_configs()
	
	# 连接全局信号
	Global.connect("buff_added", Callable(self, "_on_buff_added"))
	Global.connect("buff_removed", Callable(self, "_on_buff_removed"))
	Global.connect("buff_updated", Callable(self, "_on_buff_updated"))
	Global.connect("buff_stack_changed", Callable(self, "_on_buff_stack_changed"))

static func _init_buff_configs():
	buff_configs["faze_bullet"] = BuffData.new(
		"faze_bullet",
		"弹雨法则",
		"res://AssetBundle/Sprites/Sprite sheets/RingFire.png",
		BuffType.PERMANENT,
		99,
		"弹雨法则层数"
	)
	
	buff_configs["barrage_charge"] = BuffData.new(
		"barrage_charge",
		"弹幕积累",
		"res://AssetBundle/Sprites/Sprite sheets/RingFire.png",
		BuffType.PERMANENT,
		9999,
		"弹幕积累层数"
	)
	
	buff_configs["bagua_progress"] = BuffData.new(
		"bagua_progress",
		"推衍度",
		"res://AssetBundle/Sprites/Sprite sheets/RingFire.png",
		BuffType.PERMANENT,
		9999,
		"推衍度，下一层需要" + str(PC.faze_bagua_next_threshold) + "推衍度"
	)
	
	buff_configs["bagua_completed"] = BuffData.new(
		"bagua_completed",
		"推衍完成",
		"res://AssetBundle/Sprites/Sprite sheets/RingFire.png",
		BuffType.PERMANENT,
		9999,
		"已完成推衍的层数，每层提升4%的八卦类武器伤害加成与经验获取"
	)
	
	buff_configs["huanfeng"] = BuffData.new(
		"huanfeng",
		"唤风",
		"res://AssetBundle/Sprites/Sprite sheets/RingFire.png",
		BuffType.TEMPORARY,
		500,
		"唤风层数，每层提升0.1%攻击速度与移动速度，持续5秒"
	)
	
	buff_configs["mizongbu"] = BuffData.new(
		"mizongbu",
		"迷踪步",
		"res://AssetBundle/Sprites/Sprite sheets/RingFire.png",
		BuffType.TEMPORARY,
		1,
		"移动速度提升50%，减伤40%，造成伤害降低50%"
	)

	buff_configs["heal_hot"] = BuffData.new(
		"heal_hot",
		"疗愈",
		"res://AssetBundle/Sprites/Ghostpixxells_pixelfood/07_bread.png",
		BuffType.TEMPORARY,
		1,
		"持续恢复体力"
	)

	buff_configs["water_sheild"] = BuffData.new(
		"water_sheild",
		"水幕护体",
		"res://AssetBundle/Sprites/Ghostpixxells_pixelfood/07_bread.png",
		BuffType.TEMPORARY,
		1,
		"获得护盾并提升减伤率"
	)

	buff_configs["holy_fire"] = BuffData.new(
		"holy_fire",
		"神圣灼烧",
		"res://AssetBundle/Sprites/Ghostpixxells_pixelfood/07_bread.png",
		BuffType.TEMPORARY,
		1,
		"对周围造成伤害并恢复体力"
	)

	buff_configs["beastify"] = BuffData.new(
		"beastify",
		"魔化·趋桀",
		"res://AssetBundle/Sprites/Ghostpixxells_pixelfood/07_bread.png",
		BuffType.TEMPORARY,
		1,
		"大幅提升各项属性，并将攻击变为爪击"
	)

static func get_buff_data(buff_id: String) -> BuffData:
	if buff_configs.is_empty():
		_init_buff_configs()
		
	if buff_configs.has(buff_id):
		return buff_configs[buff_id]
	else:
		print("Warning: Buff ID '" + buff_id + "' not found in configs")
		return null

static func get_all_buff_ids() -> Array:
	if buff_configs.is_empty():
		_init_buff_configs()
	return buff_configs.keys()

static func update_buff_description(buff_id: String, new_description: String) -> void:
	if buff_configs.is_empty():
		_init_buff_configs()
		
	if buff_configs.has(buff_id):
		buff_configs[buff_id].description = new_description
		# 如果buff当前是活跃的，也更新其数据中的config引用（虽然引用应该指向同一个对象，但为了保险起见）
		if buff_data.has(buff_id):
			buff_data[buff_id]["buff_config"] = buff_configs[buff_id]
	else:
		print("Warning: Cannot update description, Buff ID '" + buff_id + "' not found")

static func update_bagua_progress_description() -> void:
	var new_desc = "推衍度，下一层需要" + str(PC.faze_bagua_next_threshold) + "推衍度"
	update_buff_description("bagua_progress", new_desc)

func setup_buff_container(container: HBoxContainer) -> void:
	buff_container = container
	if buff_container:
		# 设置容器属性
		buff_container.alignment = BoxContainer.ALIGNMENT_CENTER
		buff_container.add_theme_constant_override("separation", 8)

func _on_buff_added(buff_id: String, duration: float, stack: int):
	print("Adding buff: ", buff_id, " Duration: ", duration, " Stack: ", stack)
	
	# 获取buff配置数据
	var buff_config = get_buff_data(buff_id)
	if not buff_config:
		print("Error: Buff config not found for ID: ", buff_id)
		return  # 添加这行，如果配置不存在就直接返回
	
	# 如果buff已存在，更新它
	if active_buffs.has(buff_id):
		var buff_ui = active_buffs[buff_id]
		if is_instance_valid(buff_ui):
			_update_existing_buff(buff_id, duration, stack, buff_config)
		else:
			# 如果引用无效（可能是跨场景残留），清理并重新创建
			active_buffs.erase(buff_id)
			buff_data.erase(buff_id)
			_create_new_buff(buff_id, duration, stack, buff_config)
	else:
		_create_new_buff(buff_id, duration, stack, buff_config)

func _create_new_buff(buff_id: String, duration: float, stack: int, buff_config):
	# 创建新的BuffUI
	var buff_ui = preload("res://Script/config/buff_ui.gd").new()
	buff_ui.name = "Buff_" + buff_id
	
	# 添加到容器
	if buff_container:
		buff_container.add_child(buff_ui)
	
	# 设置buff数据
	buff_ui.setup_buff(buff_config, duration, stack)
	# 连接buff_expired信号，以便在buff UI自身计时结束后进行清理
	buff_ui.buff_expired.connect(_on_buff_ui_expired.bind(buff_id))
	
	# 保存引用
	active_buffs[buff_id] = buff_ui
	buff_data[buff_id] = {
		"remaining_time": duration,
		"stack": stack,
		"buff_config": buff_config
	}

func _on_buff_ui_expired(buff_id: String):
	# 这个函数由BuffUI的buff_expired信号触发
	print("BuffUI expired, removing: ", buff_id)
	_on_buff_removed(buff_id) # 调用已有的移除逻辑

func _update_existing_buff(buff_id: String, duration: float, stack: int, buff_config):
	var buff_ui = active_buffs[buff_id]
	var current_data = buff_data[buff_id]
	
	# 根据buff类型决定如何更新
	if buff_config.type == BuffType.PERMANENT:
		# 永久buff只更新层数
		current_data["stack"] = min(stack, buff_config.max_stack)
	else:
		# 临时buff更新时间和层数
		current_data["remaining_time"] = max(duration, current_data["remaining_time"])
		current_data["stack"] = min(stack, buff_config.max_stack)
	
	# 更新UI显示
	buff_ui.update_buff(current_data["remaining_time"], current_data["stack"])

func _on_buff_removed(buff_id: String):
	print("Removing buff: ", buff_id)
	
	if active_buffs.has(buff_id):
		# 移除UI
		var buff_ui = active_buffs[buff_id]
		if buff_ui and is_instance_valid(buff_ui):
			buff_ui.queue_free()
		
		# 清理数据
		active_buffs.erase(buff_id)
		buff_data.erase(buff_id)

func _on_buff_updated(buff_id: String, remaining_time: float, stack: int):
	if active_buffs.has(buff_id) and buff_data.has(buff_id):
		buff_data[buff_id]["remaining_time"] = remaining_time
		buff_data[buff_id]["stack"] = stack
		
		var buff_ui = active_buffs[buff_id]
		if buff_ui and is_instance_valid(buff_ui):
			buff_ui.update_buff(remaining_time, stack)

func _on_buff_stack_changed(buff_id: String, new_stack: int):
	if active_buffs.has(buff_id) and buff_data.has(buff_id):
		var buff_config = buff_data[buff_id]["buff_config"]
		buff_data[buff_id]["stack"] = min(new_stack, buff_config.max_stack)
		
		var buff_ui = active_buffs[buff_id]
		if buff_ui and is_instance_valid(buff_ui):
			buff_ui.update_buff(buff_data[buff_id]["remaining_time"], buff_data[buff_id]["stack"])

# 公共方法：添加buff
func add_buff(buff_id: String, duration: float = 0.0, stack: int = 1):
	Global.emit_signal("buff_added", buff_id, duration, stack)

# 公共方法：移除buff
static func remove_buff(buff_id: String):
	Global.emit_signal("buff_removed", buff_id)

# 公共方法：更新buff
func update_buff(buff_id: String, remaining_time: float, stack: int):
	Global.emit_signal("buff_updated", buff_id, remaining_time, stack)

# 公共方法：检查buff是否存在
static func has_buff(buff_id: String) -> bool:
	return active_buffs.has(buff_id)

# 公共方法：获取buff剩余时间
static func get_buff_remaining_time(buff_id: String) -> float:
	if buff_data.has(buff_id):
		return buff_data[buff_id]["remaining_time"]
	return 0.0

# 公共方法：获取buff层数
static func get_buff_stack(buff_id: String) -> int:
	if buff_data.has(buff_id):
		return buff_data[buff_id]["stack"]
	return 0

# 公共方法：清除所有buff
static func clear_all_buffs():
	for buff_id in active_buffs.keys():
		remove_buff(buff_id)

# 公共方法：获取所有活跃buff的ID列表
static func get_active_buff_ids() -> Array:
	return active_buffs.keys()
