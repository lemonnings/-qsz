extends Control

## Boss血条控制脚本
## 该脚本管理一个多层Boss血条的显示和逻辑。
## 它会动态创建ProgressBar子节点并添加到health_bar_container中（如果已设置），或者直接添加到自身。

#-------------------- Exported Variables (可在编辑器中配置的变量) --------------------#
## Boss的总最大生命值
@export var hpMax: float
## Boss的当前总生命值
@export var hp: float
## Boss血条的总层数（即ProgressBar的数量）
@export var hp_bar_num: int

## （可选）容纳所有ProgressBar子节点的Node2D容器。
## 如果未设置，ProgressBar将作为此Control节点的子节点创建。
@export var health_bar_container: Node2D = null 
## 是否显示整个血条UI（包括其容器）
@export var health_bar_shown: bool = false
## Boss的名字
@export var boss_name: String = "BOSS"

#-------------------- Constants (常量) --------------------#
## 每层血条的颜色定义数组。可以根据需要扩展。
const BAR_COLORS: Array[Color] = [
	Color.RED,       # 第一条血的颜色
	Color.ORANGE,    # 第二条血的颜色
	Color.YELLOW,    # 第三条血的颜色
	Color.GREEN,     # 第四条血的颜色
	Color.ROYAL_BLUE,       # 第五条血的颜色
	Color.PURPLE       # 第五条血的颜色
]

#-------------------- Private Variables (私有变量) --------------------#
## 存储动态创建的ProgressBar节点的数组。
var _progress_bars_nodes: Array[ProgressBar] = []
## 显示Boss名字的Label节点
@export var _boss_name_label: Label
## 显示血条层数的Label节点
@export var _bar_count_label: Label

#-------------------- Godot Lifecycle Methods (Godot生命周期函数) --------------------#
func _ready():
	Global.connect("boss_hp_bar_show", Callable(self, "_on_boss_hp_bar_show"))
	Global.connect("boss_hp_bar_hide", Callable(self, "_on_boss_hp_bar_hide"))
	Global.connect("boss_hp_bar_initialize", Callable(self, "_on_boss_hp_bar_initialize"))
	Global.connect("boss_hp_bar_take_damage", Callable(self, "_on_boss_hp_bar_take_damage"))
	# 初始化时，根据health_bar_shown设置此Control节点自身的可见性。
	visible = health_bar_shown
	# 设置整体透明度为80%
	#self.modulate.a = 0.8 # 初始透明度，渐入动画会覆盖它

	# --- UI定位逻辑 (此Control节点) --- #
	grow_horizontal = GROW_DIRECTION_BOTH


	# 创建并配置Boss名字标签
	_boss_name_label.z_index = 100
	_boss_name_label.text = boss_name
	_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_boss_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boss_name_label.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_boss_name_label.anchor_right = 0.3 # 占据左边30%宽度，可调整
	_boss_name_label.offset_left = 20 # 左边距
	_boss_name_label.offset_right = -5 # 右边距 (相对于anchor_right)

	# 创建并配置血条条数标签
	_bar_count_label.z_index = 100
	_bar_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bar_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bar_count_label.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_bar_count_label.anchor_left = 0.7 # 从右边70%开始，可调整
	_bar_count_label.offset_right = -20 # 右边距
	_bar_count_label.offset_left = 5 # 左边距 (相对于anchor_left)
	
	# 确保ProgressBar在标签下方，或者调整ProgressBar的边距
	# 这里我们让ProgressBar填充中间区域
	# 如果health_bar_container是self，那么ProgressBar会填充整个Control
	# 这时标签会覆盖在ProgressBar上，如果ProgressBar背景不透明，可能需要调整
	# 一个简单的处理是让ProgressBar的区域稍微缩小，或者让标签背景透明

	await get_tree().process_frame 


#-------------------- Private Helper Methods (私有辅助函数) --------------------#
## 动态创建并配置ProgressBar子节点。
func _create_and_configure_bars():
	# 清理旧的ProgressBar节点
	for bar_node in _progress_bars_nodes: # 先从数组中移除并释放
		if is_instance_valid(bar_node):
			bar_node.queue_free()
	_progress_bars_nodes.clear()

	var parent_node = health_bar_container if is_instance_valid(health_bar_container) else self
	# 如果父节点是health_bar_container，也清理它之前的ProgressBar子节点
	if is_instance_valid(health_bar_container):
		for child in health_bar_container.get_children():
			if child is ProgressBar:
				child.queue_free()

	var bar_height = custom_minimum_size.y # 使用此Control节点的高度作为bar的高度
	var bar_width = custom_minimum_size.x  # 使用此Control节点的宽度作为bar的宽度

	# 从最上层（视觉上的顶层，数组中的高索引）开始创建，以便绘制顺序正确（后加的在上面）
	# 但为了逻辑上从底层血条开始算，我们按索引顺序创建，然后在_update_display中处理显示逻辑
	for i in range(hp_bar_num):
		var bar_node = ProgressBar.new()
		_progress_bars_nodes.append(bar_node)
		parent_node.add_child(bar_node)

		# --- 配置ProgressBar --- #
		bar_node.name = "HPBarLayer_" + str(i) # 方便调试
		bar_node.value = 0 # 初始值，将在_update_display中设置
		bar_node.max_value = 100 # 临时值，将在_update_display中根据hp_per_segment设置
		bar_node.show_percentage = false # 不显示百分比文本
		
		# 设置大小和位置使其堆叠
		# ProgressBar作为Control节点，其大小和位置受父节点影响
		# 如果父节点是此Control，它们将填充此Control的区域
		# 如果父节点是health_bar_container (Node2D)，需要手动设置size
		bar_node.anchor_right = 1.0
		bar_node.anchor_bottom = 1.0
		bar_node.offset_left = 0
		bar_node.offset_top = 0
		bar_node.offset_right = 0
		bar_node.offset_bottom = 0
		# 如果父节点是Node2D，则需要设置size
		if parent_node is Node2D:
			bar_node.size = Vector2(bar_width, bar_height)
			bar_node.position = Vector2(0,0) # Node2D的子节点位置相对于Node2D

		# 设置前景（填充）颜色和样式
		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = BAR_COLORS[i % BAR_COLORS.size()] # 循环使用颜色

		fill_style.corner_radius_top_left = 10
		fill_style.corner_radius_top_right = 10
		fill_style.corner_radius_bottom_right = 10
		fill_style.corner_radius_bottom_left = 10
		bar_node.add_theme_stylebox_override("fill", fill_style)
		
		# 设置背景样式（包括描边和圆角，背景色透明）
		var background_style = StyleBoxFlat.new()
		if i == 0 :
			background_style.bg_color = Color(0,0,0,0.3) # 背景完全透明
		else:
			background_style.bg_color = Color(0,0,0,0) # 背景完全透明
		background_style.corner_radius_top_left = 10
		background_style.corner_radius_top_right = 10
		background_style.corner_radius_bottom_right = 10
		background_style.corner_radius_bottom_left = 10
		bar_node.add_theme_stylebox_override("background", background_style)

	# 如果ProgressBar是直接子节点，确保它们按添加顺序堆叠（后添加的在上面）
	# Godot默认就是这样处理Control子节点的绘制顺序

## 更新所有ProgressBar的显示状态（值和可见性）。
func _update_display():
	if hp <= 0:
		queue_free()
		return
	
	if _progress_bars_nodes.is_empty() and hp_bar_num > 0:
		_create_and_configure_bars() # 如果为空，尝试重新创建
		if _progress_bars_nodes.is_empty() and hp_bar_num > 0: return

	if hp_bar_num <= 0:
		for bar_node in _progress_bars_nodes: bar_node.visible = false
		return

	var hp_per_segment: float = hpMax / float(hp_bar_num)
	if hp_per_segment <= 0: hp_per_segment = 1.0 

	var remaining_hp_total = hp
	var now_hp_bar_num = hp_bar_num
	# 遍历所有ProgressBar，从最底层（索引0）到最顶层（索引 hp_bar_num - 1）
	# ProgressBar的绘制顺序是后添加的在最上面，所以_progress_bars_nodes[0]在最下面
	for i in range(_progress_bars_nodes.size()):
		var bar_node: ProgressBar = _progress_bars_nodes[i]
		if i < hp_bar_num: # 只操作有效数量的bar
			bar_node.max_value = hp_per_segment
			bar_node.visible = health_bar_shown # 根据整体设置可见性

			if remaining_hp_total >= hp_per_segment:
				bar_node.value = hp_per_segment # 此层血条是满的
				remaining_hp_total -= hp_per_segment
			elif remaining_hp_total > 0:
				bar_node.value = remaining_hp_total # 此层血条部分填充
				remaining_hp_total = 0
			else:
				now_hp_bar_num -= 1
				bar_node.value = 0 # 此层血条是空的
		else: # 超出hp_bar_num的bar（理论上不应发生，因为我们动态创建）
			bar_node.visible = false

	# 更新血条条数标签
	if is_instance_valid(_bar_count_label):
		_bar_count_label.text = "ｘ " + str(now_hp_bar_num)

	# 更新Boss名字标签 (如果需要动态更新)
	if is_instance_valid(_boss_name_label):
		_boss_name_label.text = boss_name # 假设boss_name可能在运行时改变

	# 更新整体UI可见性
	if is_instance_valid(health_bar_container): health_bar_container.visible = health_bar_shown
	visible = health_bar_shown # self.visible = health_bar_shown
	# 确保标签也根据整体可见性显示/隐藏
	if is_instance_valid(_boss_name_label): _boss_name_label.visible = health_bar_shown
	if is_instance_valid(_bar_count_label): _bar_count_label.visible = health_bar_shown

## 平滑动画更新血条值
func _animate_hp_change(from_hp: float, to_hp: float):
	# 如果boss死亡，直接隐藏血条并销毁
	if to_hp <= 0:
		_hide_and_destroy_hp_bar()
		return
	
	if _progress_bars_nodes.is_empty() or hp_bar_num <= 0:
		_update_display()
		return
	
	var hp_per_segment: float = hpMax / float(hp_bar_num)
	if hp_per_segment <= 0: 
		_update_display()
		return
	
	# 创建动画补间
	var tween = get_tree().create_tween()
	tween.set_parallel(true) # 允许多个动画同时进行
	
	# 计算动画持续时间，根据伤害量调整（减半）
	var damage_ratio = abs(from_hp - to_hp) / hpMax
	var animation_duration = clamp(0.15 + damage_ratio * 0.25, 0.15, 0.5)
	
	# 为每个血条创建平滑过渡动画
	for i in range(min(_progress_bars_nodes.size(), hp_bar_num)):
		var bar_node: ProgressBar = _progress_bars_nodes[i]
		if not is_instance_valid(bar_node):
			continue
		
		# 计算这个血条在from_hp和to_hp状态下的值
		var from_value = _calculate_bar_value_at_hp(i, from_hp, hp_per_segment)
		var to_value = _calculate_bar_value_at_hp(i, to_hp, hp_per_segment)
		
		# 如果值有变化，创建动画
		if abs(from_value - to_value) > 0.01:
			bar_node.value = from_value
			tween.tween_property(bar_node, "value", to_value, animation_duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		
	# 动画完成后更新标签和其他UI元素
	tween.tween_callback(_update_labels_and_ui)

## 计算指定血条在特定HP值下应该显示的值
func _calculate_bar_value_at_hp(bar_index: int, target_hp: float, hp_per_segment: float) -> float:
	var remaining_hp = target_hp
	
	# 跳过前面的血条
	for i in range(bar_index):
		if remaining_hp >= hp_per_segment:
			remaining_hp -= hp_per_segment
		else:
			remaining_hp = 0
			break
	
	# 计算当前血条的值
	if remaining_hp >= hp_per_segment:
		return hp_per_segment
	elif remaining_hp > 0:
		return remaining_hp
	else:
		return 0

## 更新标签和UI元素（不包括血条值）
func _update_labels_and_ui():
	var hp_per_segment: float = hpMax / float(hp_bar_num) if hp_bar_num > 0 else hpMax
	var now_hp_bar_num = _get_current_hp_bar_count()
	
	# 更新血条条数标签
	if is_instance_valid(_bar_count_label):
		_bar_count_label.text = "ｘ " + str(now_hp_bar_num)

	# 更新Boss名字标签
	if is_instance_valid(_boss_name_label):
		_boss_name_label.text = boss_name

	# 更新整体UI可见性
	if is_instance_valid(health_bar_container): health_bar_container.visible = health_bar_shown
	visible = health_bar_shown
	if is_instance_valid(_boss_name_label): _boss_name_label.visible = health_bar_shown
	if is_instance_valid(_bar_count_label): _bar_count_label.visible = health_bar_shown

## 隐藏并销毁血条的函数
func _hide_and_destroy_hp_bar():
	# 创建淡出动画
	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(queue_free)

#-------------------- Public Methods (公共方法) --------------------#
## 受到伤害时调用此函数
func _on_boss_hp_bar_take_damage(damage_amount: float):
	var old_hp = hp
	hp = clamp(hp - damage_amount, 0.0, hpMax)
	
	# 使用平滑过渡动画更新血条
	_animate_hp_change(old_hp, hp)

	if hp <= 0.0:
		print("Boss defeated! HP Bar notified.")

# 原有的take_damage可以保留或移除，如果外部直接调用此脚本实例的方法
func take_damage(damage_amount: float):
	# 为了保持一致性，让这个方法也调用 _on_boss_hp_bar_take_damage
	# 或者将主要逻辑放在这里，然后 _on_boss_hp_bar_take_damage 调用它
	# 当前选择让信号处理函数作为主要逻辑点
	_on_boss_hp_bar_take_damage(damage_amount)

# Helper function to get current visible HP bar count based on HP
func _get_current_hp_bar_count() -> int:
	if hp_bar_num <= 0 or hpMax <=0:
		return 0
	var hp_per_segment: float = hpMax / float(hp_bar_num)
	if hp_per_segment <= 0: return hp_bar_num # Avoid division by zero or negative
	var current_bars = ceil(hp / hp_per_segment)
	return int(clamp(current_bars, 0, hp_bar_num))


## 在运行时动态更改hpMax, hp, 或 hp_bar_num
func refresh_bar_config_and_display():
	_create_and_configure_bars() 
	_update_display()            

func _on_boss_hp_bar_show():
	health_bar_shown = true
	# 先确保节点是可见的，以便动画可以播放
	visible = true 
	if is_instance_valid(health_bar_container):
		health_bar_container.visible = true
	if is_instance_valid(_boss_name_label): _boss_name_label.visible = true
	if is_instance_valid(_bar_count_label): _bar_count_label.visible = true
	
	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate:a", 0.8, 0.5).from(0.0) # 从完全透明渐变到0.8透明度
	# _update_display() 应该在动画开始前或动画逻辑中被调用，以确保内容正确
	# 如果_update_display本身会改变visible状态，需要小心处理
	# 这里假设_update_display主要是更新血条的值和文本，而不是整体可见性动画
	_update_display() # 更新内容，但不直接控制这里的动画透明度

func _on_boss_hp_bar_hide():
	health_bar_shown = false
	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5).from(modulate.a) # 从当前透明度渐变到完全透明
	# 动画完成后再彻底隐藏节点，或者依赖 modulate.a = 0 来隐藏
	tween.tween_callback(Callable(self, "_finalize_hide"))

func _finalize_hide():
	# 这个函数在隐藏动画结束后被调用
	# _update_display() 会根据 health_bar_shown 设置子节点可见性
	_update_display() 
	# visible = false # 如果modulate.a = 0 不足以隐藏所有内容，可以在这里设置

func _on_boss_hp_bar_initialize(max_hp: float, current_hp: float, bar_num: int, bar_boss_name: String):
	hpMax = max_hp
	hp = current_hp
	hp_bar_num = bar_num
	boss_name = bar_boss_name
	refresh_bar_config_and_display()

func set_health_bar_shown(is_shown: bool):
	health_bar_shown = is_shown
	_update_display()
