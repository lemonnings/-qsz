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
	Color.RED, # 第一条血的颜色
	Color.ORANGE, # 第二条血的颜色
	Color.YELLOW, # 第三条血的颜色
	Color.GREEN, # 第四条血的颜色
	Color.ROYAL_BLUE, # 第五条血的颜色
	Color.DARK_MAGENTA # 第五条血的颜色
]

#-------------------- Private Variables (私有变量) --------------------#
## 当前boss_hp_bar实例的静态引用，供level_up等外部模块控制buff交互
static var _current_instance: Control = null
## 存储动态创建的ProgressBar节点的数组。
var _progress_bars_nodes: Array[ProgressBar] = []
## 显示Boss名字的Label节点
@export var _boss_name_label: Label
## 显示血条层数的Label节点
@export var _bar_count_label: Label
## 显示boss当前读条名字
@export var skill_name: Label
## 显示boss当前读条剩余时间（每0.1秒刷新一次）
@export var chant_time: Label
## 显示boss当前读条进度条
@export var chant_bar: ProgressBar

# 读条内部状态
var _chant_total_time: float = 0.0
var _chant_elapsed: float = 0.0
var _chant_active: bool = false
var _chant_timer: Timer = null

# Buff显示相关
## Buff图标容器（HBoxContainer）
@export var buff_container: HBoxContainer
## 当前活跃的debuff图标 {debuff_id: BossBuffIcon}
var _active_debuff_icons: Dictionary = {}
## 当前活跃的boss正面buff图标 {buff_id: BossBuffIcon}
var _active_buff_icons: Dictionary = {}
## boss正面buff数据 {buff_id: {remaining_time, stack, is_permanent, display_name, icon_path, description}}
var _boss_buff_data: Dictionary = {}
## 引用当前boss的debuff_manager
var _boss_debuff_manager: EnemyDebuffManager = null
## 是否已连接boss的debuff信号
var _debuff_signals_connected: bool = false

#-------------------- Godot Lifecycle Methods (Godot生命周期函数) --------------------#
func _ready():
	Global.connect("boss_hp_bar_show", Callable(self , "_on_boss_hp_bar_show"))
	Global.connect("boss_hp_bar_hide", Callable(self , "_on_boss_hp_bar_hide"))
	Global.connect("boss_hp_bar_initialize", Callable(self , "_on_boss_hp_bar_initialize"))
	Global.connect("boss_hp_bar_take_damage", Callable(self , "_on_boss_hp_bar_take_damage"))
	Global.connect("boss_chant_start", Callable(self , "_on_boss_chant_start"))
	Global.connect("boss_chant_end", Callable(self , "_on_boss_chant_end"))
	# Boss正面buff信号
	Global.connect("boss_buff_added", Callable(self , "_on_boss_buff_added"))
	Global.connect("boss_buff_removed", Callable(self , "_on_boss_buff_removed"))
	Global.connect("boss_buff_updated", Callable(self , "_on_boss_buff_updated"))
	# 注册为当前实例
	_current_instance = self
	# 初始化时，根据health_bar_shown设置此Control节点自身的可见性。
	visible = health_bar_shown

	# Boss血条是纯展示元素，不需要拦截鼠标事件，
	# 避免遮挡升级面板的 RefreshButton 等交互控件
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_mouse_filter_recursive(self )

	# --- UI定位逻辑 (此Control节点) --- #
	grow_horizontal = GROW_DIRECTION_BOTH


	# 创建并配置Boss名字标签
	_boss_name_label.z_index = 20
	_boss_name_label.text = boss_name
	_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_boss_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boss_name_label.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_boss_name_label.anchor_right = 0.3 # 占据左边30%宽度，可调整
	_boss_name_label.offset_left = 20 # 左边距
	_boss_name_label.offset_right = -5 # 右边距 (相对于anchor_right)
	_boss_name_label.offset_bottom = -2

	# 创建并配置血条条数标签
	_bar_count_label.z_index = 20
	_bar_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bar_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bar_count_label.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_bar_count_label.anchor_left = 0.7 # 从右边70%开始，可调整
	_bar_count_label.offset_right = -20 # 右边距
	_bar_count_label.offset_left = 5 # 左边距 (相对于anchor_left)
	_boss_name_label.offset_bottom = -2
	
	# 确保ProgressBar在标签下方，或者调整ProgressBar的边距
	# 这里我们让ProgressBar填充中间区域
	# 如果health_bar_container是self，那么ProgressBar会填充整个Control
	# 这时标签会覆盖在ProgressBar上，如果ProgressBar背景不透明，可能需要调整
	# 一个简单的处理是让ProgressBar的区域稍微缩小，或者让标签背景透明

	await get_tree().process_frame

	# 初始化读条 UI 为隐藏状态
	_set_chant_ui_visible(false)

	# 设置读条进度条样式：褐色外框+白色微黄填充+褐色外发光
	if is_instance_valid(chant_bar):
		# 填充样式：白色带一点点黄色
		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = Color(0.98, 0.96, 0.82, 1.0) # 白色微黄
		fill_style.corner_radius_top_left = 2
		fill_style.corner_radius_top_right = 2
		fill_style.corner_radius_bottom_right = 2
		fill_style.corner_radius_bottom_left = 2
		# 褐色边框
		fill_style.border_width_left = 1
		fill_style.border_width_top = 1
		fill_style.border_width_right = 1
		fill_style.border_width_bottom = 1
		fill_style.border_color = Color(0.45, 0.30, 0.12, 0.9)
		# 褐色外发光效果
		fill_style.shadow_color = Color(0.45, 0.30, 0.12, 0.45)
		fill_style.shadow_size = 4
		chant_bar.add_theme_stylebox_override("fill", fill_style)
		# 背景样式：褐色外框半透明背景
		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = Color(0.15, 0.12, 0.08, 0.5)
		bg_style.corner_radius_top_left = 2
		bg_style.corner_radius_top_right = 2
		bg_style.corner_radius_bottom_right = 2
		bg_style.corner_radius_bottom_left = 2
		bg_style.border_width_left = 1
		bg_style.border_width_top = 1
		bg_style.border_width_right = 1
		bg_style.border_width_bottom = 1
		bg_style.border_color = Color(0.55, 0.40, 0.22, 0.7)
		# 背景也带褐色外发光
		bg_style.shadow_color = Color(0.55, 0.40, 0.22, 0.35)
		bg_style.shadow_size = 3
		chant_bar.add_theme_stylebox_override("background", bg_style)

	# 创建读条刷新 Timer（每 0.1 秒刷新一次）
	_chant_timer = Timer.new()
	_chant_timer.wait_time = 0.1
	_chant_timer.one_shot = false
	_chant_timer.timeout.connect(_on_chant_timer_tick)
	add_child(_chant_timer)

	# 创建并配置Buff图标容器
	_setup_buff_container()


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

	# 使用 CanvasGroup 包装进度条，这样修改透明度时多层血条就不会发生重叠叠加发灰的问题
	var canvas_group = parent_node.get_node_or_null("BarsCanvasGroup")
	if not is_instance_valid(canvas_group):
		canvas_group = CanvasGroup.new()
		canvas_group.name = "BarsCanvasGroup"
		parent_node.add_child(canvas_group)
		parent_node.move_child(canvas_group, 0)
	else:
		for child in canvas_group.get_children():
			if child is ProgressBar:
				child.queue_free()

	var bar_width = 800.0
	var bar_height = 40.0
	if parent_node is Control:
		bar_width = parent_node.size.x if parent_node.size.x > 0 else (parent_node.custom_minimum_size.x if parent_node.custom_minimum_size.x > 0 else 800)
		bar_height = parent_node.size.y if parent_node.size.y > 0 else (parent_node.custom_minimum_size.y if parent_node.custom_minimum_size.y > 0 else 40)
	elif parent_node == self:
		bar_width = size.x if size.x > 0 else (custom_minimum_size.x if custom_minimum_size.x > 0 else 800)
		bar_height = size.y if size.y > 0 else (custom_minimum_size.y if custom_minimum_size.y > 0 else 40)

	# 从最上层（视觉上的顶层，数组中的高索引）开始创建，以便绘制顺序正确（后加的在上面）
	# 但为了逻辑上从底层血条开始算，我们按索引顺序创建，然后在_update_display中处理显示逻辑
	for i in range(hp_bar_num):
		var bar_node = ProgressBar.new()
		_progress_bars_nodes.append(bar_node)
		canvas_group.add_child(bar_node)

		# --- 配置ProgressBar --- #
		bar_node.name = "HPBarLayer_" + str(i) # 方便调试
		bar_node.value = 0 # 初始值，将在_update_display中设置
		bar_node.max_value = 100 # 临时值，将在_update_display中根据hp_per_segment设置
		bar_node.show_percentage = false # 不显示百分比文本
		bar_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# 设置大小和位置使其堆叠
		bar_node.anchor_right = 1.0
		bar_node.anchor_bottom = 1.0
		bar_node.offset_left = 0
		bar_node.offset_top = 0
		bar_node.offset_right = 0
		bar_node.offset_bottom = 0
		# 因为 CanvasGroup 是 Node2D，所以我们必须手动设置子节点的大小和位置
		# 向上扩展5像素以增加厚度
		bar_node.size = Vector2(bar_width, bar_height + 5.0)
		bar_node.position = Vector2(0, -5.0)

		# 设置前景（填充）颜色和样式
		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = BAR_COLORS[i % BAR_COLORS.size()] # 循环使用颜色

		fill_style.corner_radius_top_left = 16
		fill_style.corner_radius_top_right = 16
		fill_style.corner_radius_bottom_right = 16
		fill_style.corner_radius_bottom_left = 16
		
		# 使用透明边框给背景边框让位，避免填充遮挡外边框
		fill_style.border_width_left = 4
		fill_style.border_width_top = 4
		fill_style.border_width_right = 4
		fill_style.border_width_bottom = 4
		fill_style.border_color = Color(0, 0, 0, 0)
		
		bar_node.add_theme_stylebox_override("fill", fill_style)
		
		# 设置背景样式（包括描边和圆角，背景色透明）
		var background_style = StyleBoxFlat.new()
		if i == 0:
			background_style.bg_color = Color(0, 0, 0, 0.3) # 背景完全透明
		else:
			background_style.bg_color = Color(0, 0, 0, 0) # 背景完全透明
			
		background_style.corner_radius_top_left = 16
		background_style.corner_radius_top_right = 16
		background_style.corner_radius_bottom_right = 16
		background_style.corner_radius_bottom_left = 16
		
		# 4像素描边，颜色与读条外框保持一致
		background_style.border_width_left = 4
		background_style.border_width_top = 4
		background_style.border_width_right = 4
		background_style.border_width_bottom = 4
		background_style.border_color = Color(0.35, 0.20, 0.02, 0.9)
		
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
	health_bar_shown = false
	_clear_all_buff_icons()
	# 断开debuff_manager信号
	_disconnect_boss_debuff_signals()
	# 清除静态引用
	_current_instance = null
	# 创建淡出动画
	var tween = get_tree().create_tween()
	tween.tween_property(self , "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_LINEAR)
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

# 原有的take_damage，外部直接调用此脚本实例的方法
func take_damage(damage_amount: float):
	_on_boss_hp_bar_take_damage(damage_amount)

# Helper function to get current visible HP bar count based on HP
func _get_current_hp_bar_count() -> int:
	if hp_bar_num <= 0 or hpMax <= 0:
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
	
	_update_display() # 更新内容，但不直接控制这里的动画透明度
	_update_buff_container_visibility()
	# 延迟一帧后尝试连接boss debuff信号
	await get_tree().process_frame
	_try_connect_boss_debuff_signals()

func _on_boss_hp_bar_hide():
	health_bar_shown = false
	var tween = get_tree().create_tween()
	tween.tween_property(self , "modulate:a", 0.0, 0.5).from(modulate.a) # 从当前透明度渐变到完全透明
	# 动画完成后再彻底隐藏节点，或者依赖 modulate.a = 0 来隐藏
	tween.tween_callback(Callable(self , "_finalize_hide"))

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
	# 清除旧的buff图标，断开旧boss信号
	_clear_all_buff_icons()
	_disconnect_boss_debuff_signals()
	refresh_bar_config_and_display()

# -------------------- Chant UI (读条 UI) --------------------#
func _set_chant_ui_visible(show: bool):
	if is_instance_valid(skill_name):
		skill_name.visible = show
	if is_instance_valid(chant_time):
		chant_time.visible = show
	if is_instance_valid(chant_bar):
		chant_bar.visible = show

func _on_boss_chant_start(skill_display_name: String, chant_duration: float):
	_chant_total_time = chant_duration
	_chant_elapsed = 0.0
	_chant_active = true

	if is_instance_valid(skill_name):
		skill_name.text = skill_display_name
	if is_instance_valid(chant_bar):
		chant_bar.max_value = chant_duration
		chant_bar.value = 0.0
	if is_instance_valid(chant_time):
		chant_time.text = str(snapped(chant_duration, 0.1)) + "s"

	_set_chant_ui_visible(true)
	if _chant_timer and not _chant_timer.is_stopped():
		_chant_timer.stop()
	if _chant_timer:
		_chant_timer.start()

func _on_boss_chant_end():
	_chant_active = false
	if _chant_timer and not _chant_timer.is_stopped():
		_chant_timer.stop()
	_set_chant_ui_visible(false)

# 每帧平滑更新进度条填充和防遮挡检测
func _process(delta: float):
	if _chant_active:
		_chant_elapsed += delta
		if is_instance_valid(chant_bar):
			chant_bar.value = min(_chant_elapsed, _chant_total_time)
		if _chant_elapsed >= _chant_total_time:
			_chant_active = false
			if _chant_timer and not _chant_timer.is_stopped():
				_chant_timer.stop()
			_set_chant_ui_visible(false)
			
	# 防遮挡检测：如果boss在血条范围内，将透明度降低至50%左右(这里设为0.4防遮挡)
	if health_bar_shown:
		var target_alpha = 0.8
		var boss = get_tree().get_first_node_in_group("boss")
		if is_instance_valid(boss) and boss is Node2D:
			var boss_screen_pos = boss.get_global_transform_with_canvas().origin
			# 稍微扩大一点判定范围
			var check_rect = get_global_rect().grow(75.0)
			# 检测boss中心或者偏上部位是否遮挡
			if check_rect.has_point(boss_screen_pos) or check_rect.has_point(boss_screen_pos + Vector2(0, -80)):
				target_alpha = 0.4
				
		modulate.a = lerp(modulate.a, target_alpha, 8.0 * delta)
		
		# 尝试连接boss的debuff_manager信号（如果尚未连接）
		if not _debuff_signals_connected:
			_try_connect_boss_debuff_signals()
		
		# 更新debuff图标的剩余时间（从EnemyDebuffManager的Timer获取）
		_update_debuff_remaining_times()

# Timer 仅负责每 0.1 秒刷新剩余时间文字
func _on_chant_timer_tick():
	if not _chant_active:
		_chant_timer.stop()
		return
	var remaining = max(_chant_total_time - _chant_elapsed, 0.0)
	if is_instance_valid(chant_time):
		chant_time.text = str(snapped(remaining, 0.1)) + "s"

func set_health_bar_shown(is_shown: bool):
	health_bar_shown = is_shown
	_update_display()


## 递归设置所有 Control 子节点的 mouse_filter 为 IGNORE
func _set_mouse_filter_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_mouse_filter_recursive(child)

# -------------------- Buff Display (Buff 显示) --------------------#
## 创建并配置Buff图标容器
func _setup_buff_container():
	if buff_container == null:
		buff_container = HBoxContainer.new()
		buff_container.name = "BuffContainer"
		buff_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		buff_container.alignment = BoxContainer.ALIGNMENT_BEGIN
		buff_container.add_theme_constant_override("separation", 2)
		add_child(buff_container)
	
	# 定位在boss名字下方、血条左下方
	buff_container.z_index = 20
	buff_container.anchor_right = 0.0
	buff_container.anchor_bottom = 0.0
	buff_container.offset_left = 20
	# 位于血条区域下方
	buff_container.offset_top = size.y + 2
	buff_container.offset_right = size.x
	buff_container.offset_bottom = size.y + 40
	buff_container.visible = false

## 尝试连接当前boss的debuff_manager信号
func _try_connect_boss_debuff_signals():
	if _debuff_signals_connected:
		return
	var boss = get_tree().get_first_node_in_group("boss")
	if not is_instance_valid(boss):
		return
	var dm = boss.get("debuff_manager")
	if dm != null and is_instance_valid(dm) and dm is EnemyDebuffManager:
		_boss_debuff_manager = dm
		if not dm.debuff_added_signal.is_connected(_on_boss_debuff_added):
			dm.debuff_added_signal.connect(_on_boss_debuff_added)
		if not dm.debuff_removed_signal.is_connected(_on_boss_debuff_removed):
			dm.debuff_removed_signal.connect(_on_boss_debuff_removed)
		if not dm.debuff_stack_changed_signal.is_connected(_on_boss_debuff_stack_changed):
			dm.debuff_stack_changed_signal.connect(_on_boss_debuff_stack_changed)
		_debuff_signals_connected = true
		# 同步已存在的debuff
		_sync_existing_debuffs()

## 同步boss身上已有的debuff（用于boss切换或信号延迟连接的情况）
func _sync_existing_debuffs():
	if _boss_debuff_manager == null or not is_instance_valid(_boss_debuff_manager):
		return
	for debuff_id in _boss_debuff_manager.active_debuffs:
		if not _active_debuff_icons.has(debuff_id):
			var debuff_entry = _boss_debuff_manager.active_debuffs[debuff_id]
			var config: EnemyDebuffManager.DebuffData = debuff_entry["config"]
			_create_debuff_icon(debuff_id, debuff_entry["stacks"], config)

## Boss身上debuff添加回调
func _on_boss_debuff_added(debuff_id: String, stacks: int):
	if _boss_debuff_manager == null or not is_instance_valid(_boss_debuff_manager):
		return
	if not _boss_debuff_manager.active_debuffs.has(debuff_id):
		return
	var debuff_entry = _boss_debuff_manager.active_debuffs[debuff_id]
	var config: EnemyDebuffManager.DebuffData = debuff_entry["config"]
	_create_debuff_icon(debuff_id, stacks, config)

## Boss身上debuff移除回调
func _on_boss_debuff_removed(debuff_id: String):
	_remove_debuff_icon(debuff_id)

## Boss身上debuff层数变化回调
func _on_boss_debuff_stack_changed(debuff_id: String, new_stacks: int):
	if _active_debuff_icons.has(debuff_id):
		var icon_node = _active_debuff_icons[debuff_id]
		if is_instance_valid(icon_node):
			icon_node.stack_count = new_stacks
			icon_node._update_display()

## 创建debuff图标
func _create_debuff_icon(debuff_id: String, stacks: int, config):
	if _active_debuff_icons.has(debuff_id):
		# 已存在，更新
		var existing = _active_debuff_icons[debuff_id]
		if is_instance_valid(existing):
			existing.stack_count = stacks
			existing._update_display()
			return
	# 创建新的BossBuffIcon
	var icon_node = BossBuffIcon.new()
	icon_node.name = "Debuff_" + debuff_id
	buff_container.add_child(icon_node)
	icon_node.setup_debuff(debuff_id, stacks, config)
	icon_node.buff_expired.connect(_on_debuff_icon_expired.bind(debuff_id))
	_active_debuff_icons[debuff_id] = icon_node
	_update_buff_container_visibility()

## 移除debuff图标
func _remove_debuff_icon(debuff_id: String):
	if _active_debuff_icons.has(debuff_id):
		var icon_node = _active_debuff_icons[debuff_id]
		if is_instance_valid(icon_node):
			icon_node.queue_free()
		_active_debuff_icons.erase(debuff_id)
		_update_buff_container_visibility()

## debuff图标自然过期回调
func _on_debuff_icon_expired(debuff_id: String):
	_remove_debuff_icon(debuff_id)

## Boss正面buff添加回调
func _on_boss_buff_added(buff_id: String, p_display_name: String, icon_path: String, duration: float, stack: int, permanent: bool, desc: String):
	if _active_buff_icons.has(buff_id):
		# 已存在，更新
		_update_existing_boss_buff(buff_id, duration, stack)
		return
	# 创建新的BossBuffIcon
	var icon_node = BossBuffIcon.new()
	icon_node.name = "BossBuff_" + buff_id
	buff_container.add_child(icon_node)
	icon_node.setup_buff(buff_id, p_display_name, icon_path, duration, stack, permanent, desc)
	icon_node.buff_expired.connect(_on_boss_buff_icon_expired.bind(buff_id))
	_active_buff_icons[buff_id] = icon_node
	_boss_buff_data[buff_id] = {
		"remaining_time": duration,
		"stack": stack,
		"is_permanent": permanent,
		"display_name": p_display_name,
		"icon_path": icon_path,
		"description": desc
	}
	_update_buff_container_visibility()

## Boss正面buff移除回调
func _on_boss_buff_removed(buff_id: String):
	if _active_buff_icons.has(buff_id):
		var icon_node = _active_buff_icons[buff_id]
		if is_instance_valid(icon_node):
			icon_node.queue_free()
		_active_buff_icons.erase(buff_id)
	_boss_buff_data.erase(buff_id)
	_update_buff_container_visibility()

## Boss正面buff更新回调
func _on_boss_buff_updated(buff_id: String, remaining_time: float, stack: int):
	_update_existing_boss_buff(buff_id, remaining_time, stack)

## 更新已有的boss正面buff
func _update_existing_boss_buff(buff_id: String, remaining_time: float, stack: int):
	if _active_buff_icons.has(buff_id):
		var icon_node = _active_buff_icons[buff_id]
		if is_instance_valid(icon_node):
			icon_node.update_buff(remaining_time, stack)
	if _boss_buff_data.has(buff_id):
		_boss_buff_data[buff_id]["remaining_time"] = remaining_time
		_boss_buff_data[buff_id]["stack"] = stack

## boss正面buff图标自然过期回调
func _on_boss_buff_icon_expired(buff_id: String):
	_on_boss_buff_removed(buff_id)

## 更新buff容器可见性
func _update_buff_container_visibility():
	if buff_container:
		var has_any = not _active_debuff_icons.is_empty() or not _active_buff_icons.is_empty()
		buff_container.visible = has_any and health_bar_shown

## 切换所有Boss血条上buff图标的鼠标交互（升级选项出现时关闭，消失时恢复）
static func set_boss_buffs_interactive(enabled: bool) -> void:
	var inst = _current_instance
	if not is_instance_valid(inst):
		return
	var filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	for icon in inst._active_debuff_icons.values():
		if is_instance_valid(icon):
			icon.mouse_filter = filter
	for icon in inst._active_buff_icons.values():
		if is_instance_valid(icon):
			icon.mouse_filter = filter

## 断开boss的debuff_manager信号
func _disconnect_boss_debuff_signals():
	if _boss_debuff_manager != null and is_instance_valid(_boss_debuff_manager):
		if _boss_debuff_manager.debuff_added_signal.is_connected(_on_boss_debuff_added):
			_boss_debuff_manager.debuff_added_signal.disconnect(_on_boss_debuff_added)
		if _boss_debuff_manager.debuff_removed_signal.is_connected(_on_boss_debuff_removed):
			_boss_debuff_manager.debuff_removed_signal.disconnect(_on_boss_debuff_removed)
		if _boss_debuff_manager.debuff_stack_changed_signal.is_connected(_on_boss_debuff_stack_changed):
			_boss_debuff_manager.debuff_stack_changed_signal.disconnect(_on_boss_debuff_stack_changed)
	_boss_debuff_manager = null
	_debuff_signals_connected = false

## 清除所有buff图标
func _clear_all_buff_icons():
	for debuff_id in _active_debuff_icons.keys():
		var icon_node = _active_debuff_icons[debuff_id]
		if is_instance_valid(icon_node):
			icon_node.queue_free()
	_active_debuff_icons.clear()
	
	for buff_id in _active_buff_icons.keys():
		var icon_node = _active_buff_icons[buff_id]
		if is_instance_valid(icon_node):
			icon_node.queue_free()
	_active_buff_icons.clear()
	_boss_buff_data.clear()
	
	if buff_container:
		buff_container.visible = false

## 从EnemyDebuffManager的Timer获取debuff剩余时间并更新图标
func _update_debuff_remaining_times():
	if _boss_debuff_manager == null or not is_instance_valid(_boss_debuff_manager):
		return
	for debuff_id in _active_debuff_icons:
		if not _boss_debuff_manager.active_debuffs.has(debuff_id):
			continue
		var icon_node = _active_debuff_icons[debuff_id]
		if not is_instance_valid(icon_node):
			continue
		var debuff_entry = _boss_debuff_manager.active_debuffs[debuff_id]
		var timer: Timer = debuff_entry["timer"]
		if is_instance_valid(timer) and not timer.is_stopped():
			var remaining = timer.time_left
			var stacks = debuff_entry["stacks"]
			icon_node.update_debuff(remaining, stacks)
