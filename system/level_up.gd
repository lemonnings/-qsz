extends Node
class_name LevelUpManager

# 升级管理器 - 处理升级界面逻辑
# 从stage1.gd中提取的升级相关功能

# 信号定义
signal level_up_ui_ready
signal level_up_selection_made

# 升级界面相关变量
var now_main_skill_name: String = ""
var pending_level_ups: int = 0

# UI节点引用（通过参数传递）
var canvas_layer: CanvasLayer
var lv_up_change: Node2D
var lv_up_change_b1: Button
var lv_up_change_b2: Button
var lv_up_change_b3: Button
var layer_ui: CanvasLayer
var skill_nodes: Array[TextureButton] = []

# 初始化升级管理器
func initialize(p_canvas_layer: CanvasLayer, p_lv_up_change: Node2D, 
			   p_lv_up_change_b1: Button, p_lv_up_change_b2: Button, 
			   p_lv_up_change_b3: Button, p_layer_ui: CanvasLayer,
			   p_skill_nodes: Array[TextureButton]):
	canvas_layer = p_canvas_layer
	lv_up_change = p_lv_up_change
	lv_up_change_b1 = p_lv_up_change_b1
	lv_up_change_b2 = p_lv_up_change_b2
	lv_up_change_b3 = p_lv_up_change_b3
	layer_ui = p_layer_ui
	skill_nodes = p_skill_nodes

# 主要升级处理函数
func handle_level_up(main_skill_name: String = '', refresh_id: int = 0, 
					 scene_tree: SceneTree = null, viewport: Viewport = null) -> void:
	if scene_tree:
		await scene_tree.create_timer(0.25).timeout
	
	now_main_skill_name = main_skill_name # Always update now_main_skill_name from the parameter
	pending_level_ups -= 1
	Global.is_level_up = true
	lv_up_change.visible = true
	
	PC.last_speed = PC.pc_speed
	PC.last_atk_speed = PC.pc_atk_speed
	PC.last_lunky_level = PC.now_lunky_level
	
	# 确定刷出来的三个升级奖励的等级
	var r1_rand = randf_range(0, 100)
	var r2_rand = randf_range(0, 100)
	var r3_rand = randf_range(0, 100)
	
	# 0是默认三个抽选的，123是单独刷新
	var reward1 = null
	var reward2 = null
	var reward3 = null
	if refresh_id == 0 or refresh_id == 1:
		reward1 = LvUp.get_reward_level(r1_rand, main_skill_name)
		if reward1 == null:
			if refresh_id != 0:	
				PC.refresh_num += 1
			print("普通抽取池已空")
		elif reward1.reward_name == "noReward":
			if refresh_id != 0:
				PC.refresh_num += 1
			print("特殊技能抽取池已空")
	if refresh_id == 0 or refresh_id == 2:
		reward2 = LvUp.get_reward_level(r2_rand, main_skill_name)
		if reward2 == null:
			if refresh_id != 0:	
				PC.refresh_num += 1
			print("普通抽取池已空")
		elif reward2.reward_name == "noReward":
			if refresh_id != 0:
				PC.refresh_num += 1
			print("特殊技能抽取池已空")
	if refresh_id == 0 or refresh_id == 3:
		reward3 = LvUp.get_reward_level(r3_rand, main_skill_name)
		if reward3 == null:
			if refresh_id != 0:	
				PC.refresh_num += 1
			print("普通抽取池已空")
		elif reward3.reward_name == "noReward":
			if refresh_id != 0:	
				PC.refresh_num += 1
			print("特殊技能抽取池已空")
	
	# 创建背景变暗效果
	if refresh_id == 0:
		var dark_overlayOld = null
		if has_meta("dark_overlay"):
			dark_overlayOld = get_meta("dark_overlay")
		if dark_overlayOld == null or not is_instance_valid(dark_overlayOld):
			var dark_overlay = ColorRect.new()
			dark_overlay.color = Color(0, 0, 0, 0.35)  # 黑色，50%透明度
			if viewport:
				dark_overlay.size = viewport.get_visible_rect().size * 4
			dark_overlay.position = Vector2(-1000, 0)
			dark_overlay.z_index = 0  # 确保在其他元素之上，但在CanvasLayer之下
			dark_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
			dark_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			canvas_layer.add_child(dark_overlay)
			# 存储dark_overlay引用以便后续清理
			set_meta("dark_overlay", dark_overlay)
	
	# 设置按钮初始状态为不可见
	lv_up_change_b1.visible = true
	lv_up_change_b2.visible = true
	lv_up_change_b3.visible = true
	if refresh_id == 0:
		lv_up_change_b1.modulate.a = 0.0
		lv_up_change_b2.modulate.a = 0.0
		lv_up_change_b3.modulate.a = 0.0
	
	# 连接升级选择完成信号，用于清理dark_overlay
	if !Global.is_connected("level_up_selection_complete", _on_level_up_selection_complete):
		Global.connect("level_up_selection_complete", _on_level_up_selection_complete)
	
	var rect_ready = Rect2(4, 176, 8, 16)
	var rect_off = Rect2(20, 176, 8, 16)
	var rect_on = Rect2(36, 176, 8, 16)
	
	# 配置第一个按钮
	if reward1 != null:
		_configure_reward_button(lv_up_change_b1, reward1, rect_ready, rect_off, rect_on, refresh_id)
	elif refresh_id == 0:
		lv_up_change_b1.visible = false
	
	# 配置第二个按钮
	if reward2 != null:
		_configure_reward_button(lv_up_change_b2, reward2, rect_ready, rect_off, rect_on, refresh_id)
	elif refresh_id == 0:
		lv_up_change_b2.visible = false
	
	# 配置第三个按钮
	if reward3 != null:
		_configure_reward_button(lv_up_change_b3, reward3, rect_ready, rect_off, rect_on, refresh_id)
	elif refresh_id == 0:
		lv_up_change_b3.visible = false
	
	# 创建渐显动画
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)  # 允许并行动画
	tween.set_ignore_time_scale(true) # 确保tween在暂停时也能运行
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	# 设置升级界面相关节点在暂停时仍能处理
	layer_ui.process_mode = Node.PROCESS_MODE_ALWAYS # 通常不需要对根CanvasLayer设置
	lv_up_change.process_mode = Node.PROCESS_MODE_ALWAYS
	lv_up_change_b1.process_mode = Node.PROCESS_MODE_ALWAYS
	lv_up_change_b2.process_mode = Node.PROCESS_MODE_ALWAYS
	lv_up_change_b3.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 立即暂停游戏
	for skill_node in skill_nodes:
		if skill_node.has_method("set_game_paused"):
			skill_node.set_game_paused(true)
	
	if scene_tree:
		scene_tree.set_pause(true)
	
	# 0.5秒渐显动画
	if lv_up_change_b1.visible:
		tween.tween_property(lv_up_change_b1, "modulate:a", 1.0, 0.5)
	if lv_up_change_b2.visible:
		tween.tween_property(lv_up_change_b2, "modulate:a", 1.0, 0.5)
	if lv_up_change_b3.visible:
		tween.tween_property(lv_up_change_b3, "modulate:a", 1.0, 0.5)

# 配置奖励按钮的私有函数
func _configure_reward_button(button: Button, reward, rect_ready: Rect2, rect_off: Rect2, rect_on: Rect2, refresh_id: int):
	# 配置button内部要显示的数据
	var lvcb: Sprite2D = button.get_node("Pic")
	var lvTitle: RichTextLabel = button.get_node("Panel/Title")
	var lvcbd: RichTextLabel = button.get_node("Panel/Detail")
	var lvSkillLv: RichTextLabel = button.get_node("Panel/SkillLv")
	var lvAdvanceProgress1: Sprite2D = button.get_node("Panel/AdvanceProgress1")
	var lvAdvanceProgress2: Sprite2D = button.get_node("Panel/AdvanceProgress2")
	var lvAdvanceProgress3: Sprite2D = button.get_node("Panel/AdvanceProgress3")
	var lvAdvanceProgress4: Sprite2D = button.get_node("Panel/AdvanceProgress4")
	var lvAdvanceProgress5: Sprite2D = button.get_node("Panel/AdvanceProgress5")
	
	lvSkillLv.visible = false
	lvAdvanceProgress1.visible = false
	lvAdvanceProgress2.visible = false
	lvAdvanceProgress3.visible = false
	lvAdvanceProgress4.visible = false
	lvAdvanceProgress5.visible = false
	lvcbd.size = Vector2(160, 219)
	lvcbd.position = Vector2(0, 59)
	
	# 如果抽取到的是主要技能，则渲染进阶状态
	if reward.if_main_skill and !reward.if_advance:
		lvcbd.size = Vector2(160, 175)
		lvcbd.position = Vector2(0, 103)
		lvSkillLv.visible = true
		lvAdvanceProgress1.visible = true
		lvAdvanceProgress2.visible = true
		lvAdvanceProgress3.visible = true
		lvAdvanceProgress4.visible = true
		lvAdvanceProgress5.visible = true
		
		lvAdvanceProgress1.region_rect = rect_off
		lvAdvanceProgress2.region_rect = rect_off
		lvAdvanceProgress3.region_rect = rect_off
		lvAdvanceProgress4.region_rect = rect_off
		lvAdvanceProgress5.region_rect = rect_off
		
		var mainLV = LvUp._select_PC_main_skill_lv(reward.faction)
		lvSkillLv.text = "LV. " + str(mainLV)
		
		var lights_to_turn_on = min(mainLV % 5, mainLV)
		if lights_to_turn_on >= 0 :
			lvAdvanceProgress1.region_rect = rect_ready
		if lights_to_turn_on >= 1 :
			lvAdvanceProgress1.region_rect = rect_on
			lvAdvanceProgress2.region_rect = rect_ready
		if lights_to_turn_on >= 2 :
			lvAdvanceProgress2.region_rect = rect_on
			lvAdvanceProgress3.region_rect = rect_ready
		if lights_to_turn_on >= 3 :
			lvAdvanceProgress3.region_rect = rect_on
			lvAdvanceProgress4.region_rect = rect_ready
		if lights_to_turn_on >= 4 :
			lvAdvanceProgress4.region_rect = rect_on
			lvAdvanceProgress5.region_rect = rect_ready
	
	lvcb.region_rect = GU.parse_rect_from_func_string(reward.icon)
	lvTitle.text = "[color=" + reward.rarity + "]" + reward.reward_name + "[/color]"
	lvcbd.text = reward.detail
	var callback: Callable = Callable(LvUp, reward.on_selected)
	var connect_array = button.pressed.get_connections()
	if !connect_array.is_empty():
		for conn in connect_array:
			button.pressed.disconnect(conn.callable)
	button.pressed.connect(callback)

# 检查并处理待升级
func check_and_process_pending_level_ups(scene_tree: SceneTree = null, viewport: Viewport = null) -> void:
	# 清理dark_overlay
	_cleanup_dark_overlay()
	
	# 恢复技能节点状态
	for skill_node in skill_nodes:
		if skill_node.has_method("set_game_paused"):
			skill_node.set_game_paused(false)
	
	var advance_change = int(PC.main_skill_swordQi / 5)
	if PC.main_skill_swordQi != 0 and (PC.main_skill_swordQi % 5 == 0) and PC.main_skill_swordQi_advance < advance_change :
		PC.main_skill_swordQi_advance += 1
		handle_level_up("swordQi", 0, scene_tree, viewport)
		# 主技能进阶完成后清空now_main_skill_name
	# 如果没有主技能进阶，或者主技能进阶处理完毕后，再处理普通待升级
	elif pending_level_ups > 0: 
		handle_level_up("", 0, scene_tree, viewport)
		# 清理升级选择时创建的背景变暗效果（仅普通升级时）
		now_main_skill_name = ""

# 升级选择完成回调
func _on_level_up_selection_complete(viewport: Viewport = null) -> void:
	# 清理升级选择时创建的背景变暗效果
	_cleanup_dark_overlay()
	# 隐藏升级界面
	lv_up_change.visible = false
	Global.is_level_up = false
	# 恢复游戏
	if get_tree():
		get_tree().set_pause(false)

# 刷新按钮处理函数
func handle_refresh_button(refresh_id: int, scene_tree: SceneTree = null, viewport: Viewport = null) -> void:
	if PC.refresh_num > 0:
		PC.refresh_num -= 1
	
	# 只有在当前升级界面确实是主技能进阶时才传递main_skill_name
	# 通过检查当前是否有有效的main_skill_name来判断
	var current_main_skill = now_main_skill_name if now_main_skill_name != "" else ""
	handle_level_up(current_main_skill, refresh_id, scene_tree, viewport)

# 增加待升级数量
func add_pending_level_up() -> void:
	pending_level_ups += 1

# 获取待升级数量
func get_pending_level_ups() -> int:
	return pending_level_ups

# 设置待升级数量
func set_pending_level_ups(value: int) -> void:
	pending_level_ups = value

# 获取当前主技能名称
func get_now_main_skill_name() -> String:
	return now_main_skill_name

# 设置当前主技能名称
func set_now_main_skill_name(value: String) -> void:
	now_main_skill_name = value

# 获取升级所需经验值
func get_required_lv_up_value(level: int) -> float:
	var value: float = 1000
	for i in range(level):
		value = (value + 300) * 1.05
	return value

# 清理dark_overlay的私有函数
func _cleanup_dark_overlay() -> void:
	if has_meta("dark_overlay"):
		var dark_overlay = get_meta("dark_overlay")
		if dark_overlay != null and is_instance_valid(dark_overlay):
			dark_overlay.queue_free()
		remove_meta("dark_overlay")
