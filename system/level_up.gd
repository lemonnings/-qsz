extends Node
class_name LevelUpManager

const BOSS_HP_BAR_SCRIPT = preload("res://Script/system/boss_hp_bar.gd")

# 升级管理器 - 处理升级界面逻辑
# 从stage1.gd中提取的升级相关功能

# 信号定义
@warning_ignore("unused_signal")
signal level_up_ui_ready
@warning_ignore("unused_signal")
signal level_up_selection_made

# 升级界面相关变量
var now_main_skill_name: String = ""
var pending_level_ups: int = 0
# 已确认的锁定奖励数据存储 {button_id: reward_data}，跨次升级保留
var locked_rewards: Dictionary = {}
# 当前界面临时锁定的奖励数据 {button_id: reward_data}，仅在当前界面有效
var tentative_locked_rewards: Dictionary = {}
# 当前显示的奖励数据 {button_id: reward_data}
var current_rewards: Dictionary = {}

# UI节点引用（通过参数传递）
var canvas_layer: CanvasLayer
var lv_up_change: Control
var lv_up_change_b1: Button
var lv_up_change_b2: Button
var lv_up_change_b3: Button
var layer_ui: CanvasLayer
var skill_nodes: Array[TextureButton] = []
var _active_icon_mouse_filters: Dictionary = {}
var _skip_next_level_up_delay: bool = false

# 初始化升级管理器
func initialize(p_canvas_layer: CanvasLayer, p_lv_up_change: Control,
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
	# 战败后不再弹出升级界面，防止游戏卡死
	if PC.is_game_over:
		return
	
	now_main_skill_name = main_skill_name
	# 只有普通升级的首次打开（refresh_id==0）才消耗 pending_level_ups
	# 刷新操作（refresh_id!=0）只是重抽奖励，不消耗升级次数
	# 进化升级也不消耗
	if main_skill_name == "" and refresh_id == 0:
		pending_level_ups = max(0, pending_level_ups - 1)
		print("[LvUp] handle_level_up 普通升级, pending_level_ups → ", pending_level_ups)
	elif main_skill_name == "" and refresh_id != 0:
		print("[LvUp] handle_level_up 刷新操作(refresh_id=", refresh_id, "), pending_level_ups = ", pending_level_ups, " (不变)")
	else:
		print("[LvUp] handle_level_up 进化升级(", main_skill_name, "), pending_level_ups = ", pending_level_ups, " (不变)")
	Global.is_level_up = true
	SEManager.play("203", true)
	var skip_open_delay = _skip_next_level_up_delay
	_skip_next_level_up_delay = false
	
	# 初始展示升级界面时才需要延迟（刷新按键点击时不延迟，由调用方管理过渡）
	# 手动模式由玩家主动点击触发，无需延迟
	if scene_tree and refresh_id == 0 and PC.instant_level_up and not skip_open_delay:
		await scene_tree.create_timer(0.25, false, false, false).timeout
	
	# await期间玩家可能已死亡，重新检查
	if PC.is_game_over:
		_force_cleanup_level_up_ui()
		return
	
	lv_up_change.visible = true
	_set_active_skill_icons_interactive(false)
	# 升级选项出现时关闭Buff悬停提示，避免遮挡按钮
	BuffManager.set_buffs_interactive(false)
	BOSS_HP_BAR_SCRIPT.set_boss_buffs_interactive(false)
	
	# 渐入 instant_level_up_button（与升级选项一同出现；刷新时按钮不渐入渐出）
	var is_refresh = (refresh_id != 0)
	if not is_refresh:
		_fade_instant_level_up_button(true, true)
	
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
	
	# 主技能进阶时，检查进阶池是否完全为空
	var advance_pool_is_empty = false
	if main_skill_name != "":
		advance_pool_is_empty = LvUp.is_advance_pool_empty(main_skill_name)
	
	# 普通升级时，已确认锁定的位置不抽取（节省奖池）
	var skip_reward1 = (main_skill_name == "" and locked_rewards.has(1))
	var skip_reward2 = (main_skill_name == "" and locked_rewards.has(2))
	var skip_reward3 = (main_skill_name == "" and locked_rewards.has(3))
	
	# 收集已确认锁定的奖励ID，排除在抽取之外
	var exclude_reward_ids: Array[String] = []
	for btn_id in locked_rewards.keys():
		var locked_reward = locked_rewards[btn_id]
		if locked_reward != null:
			exclude_reward_ids.append(locked_reward.id)
	if not exclude_reward_ids.is_empty():
		print("[Lock] 抽取排除已锁定奖励: ", exclude_reward_ids)
	
	# 调试：打印当前概率阈值
	print("[Reward] 概率阈值: red_p=", PC.now_red_p, " gold_p=", PC.now_gold_p, " darkorchid_p=", PC.now_darkorchid_p, " | 累积: red<=", PC.now_red_p, " gold<=", PC.now_gold_p + PC.now_red_p, " darkorchid<=", PC.now_darkorchid_p + PC.now_gold_p + PC.now_red_p)
	
	if (refresh_id == 0 or refresh_id == 1) and not skip_reward1:
		reward1 = LvUp.get_reward_level(r1_rand, main_skill_name, exclude_reward_ids)
		if reward1 == null:
			if refresh_id != 0:
				PC.refresh_num += 1
			print("普通抽取池已空")
		elif reward1.reward_name == "noReward":
			if refresh_id != 0:
				PC.refresh_num += 1
			print("特殊技能抽取池已空")
		# 如果是主技能进阶且进阶池不为空，但抽到了精进，则隐藏该选项
		elif main_skill_name != "" and not advance_pool_is_empty and reward1.id == "NoAdvance":
			reward1 = null
			if refresh_id != 0:
				PC.refresh_num += 1
			print("进阶池不为空，跳过精进选项")
	if (refresh_id == 0 or refresh_id == 2) and not skip_reward2:
		reward2 = LvUp.get_reward_level(r2_rand, main_skill_name, exclude_reward_ids)
		if reward2 == null:
			if refresh_id != 0:
				PC.refresh_num += 1
			print("普通抽取池已空")
		elif reward2.reward_name == "noReward":
			if refresh_id != 0:
				PC.refresh_num += 1
			print("特殊技能抽取池已空")
		# 如果是主技能进阶且进阶池不为空，但抽到了精进，则隐藏该选项
		elif main_skill_name != "" and not advance_pool_is_empty and reward2.id == "NoAdvance":
			reward2 = null
			if refresh_id != 0:
				PC.refresh_num += 1
			print("进阶池不为空，跳过精进选项")
	if (refresh_id == 0 or refresh_id == 3) and not skip_reward3:
		reward3 = LvUp.get_reward_level(r3_rand, main_skill_name, exclude_reward_ids)
		if reward3 == null:
			if refresh_id != 0:
				PC.refresh_num += 1
			print("普通抽取池已空")
		elif reward3.reward_name == "noReward":
			if refresh_id != 0:
				PC.refresh_num += 1
			print("特殊技能抽取池已空")
		# 如果是主技能进阶且进阶池不为空，但抽到了精进，则隐藏该选项
		elif main_skill_name != "" and not advance_pool_is_empty and reward3.id == "NoAdvance":
			reward3 = null
			if refresh_id != 0:
				PC.refresh_num += 1
			print("进阶池不为空，跳过精进选项")
	
	# 设置刷新按钮和锁定按钮可见性
	var refresh_b1 = lv_up_change_b1.get_node_or_null("RefreshButton")
	var refresh_b2 = lv_up_change_b2.get_node_or_null("RefreshButton2")
	var refresh_b3 = lv_up_change_b3.get_node_or_null("RefreshButton3")
	var lock_b1 = lv_up_change_b1.get_node_or_null("LockButton")
	var lock_b2 = lv_up_change_b2.get_node_or_null("LockButton2")
	var lock_b3 = lv_up_change_b3.get_node_or_null("LockButton3")
	
	if main_skill_name != "":
		# 主技能进阶时隐藏刷新按钮和锁定按钮
		if refresh_b1: refresh_b1.visible = false
		if refresh_b2: refresh_b2.visible = false
		if refresh_b3: refresh_b3.visible = false
		if lock_b1: lock_b1.visible = false
		if lock_b2: lock_b2.visible = false
		if lock_b3: lock_b3.visible = false
	else:
		# 普通升级时显示刷新按钮和锁定按钮（锁定后不隐藏，以便取消或刷新）
		if refresh_b1: refresh_b1.visible = true
		if refresh_b2: refresh_b2.visible = true
		if refresh_b3: refresh_b3.visible = true
		if lock_b1: lock_b1.visible = true
		if lock_b2: lock_b2.visible = true
		if lock_b3: lock_b3.visible = true

	# 创建背景变暗效果
	if refresh_id == 0:
		var dark_overlayOld = null
		if has_meta("dark_overlay"):
			dark_overlayOld = get_meta("dark_overlay")
		if dark_overlayOld == null or not is_instance_valid(dark_overlayOld):
			var dark_overlay = ColorRect.new()
			dark_overlay.color = Color(0, 0, 0, 0.35) # 黑色，50%透明度
			if viewport:
				dark_overlay.size = viewport.get_visible_rect().size * 4
			dark_overlay.position = Vector2(-1000, 0)
			dark_overlay.z_index = 0 # 确保在其他元素之上，但在CanvasLayer之下
			dark_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
			dark_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			canvas_layer.add_child(dark_overlay)
			# 存储dark_overlay引用以便后续清理
			set_meta("dark_overlay", dark_overlay)
	
	# 设置按钮初始状态为不可见
	lv_up_change_b1.visible = true
	lv_up_change_b2.visible = true
	lv_up_change_b3.visible = true
	
	# 如果是普通升级或刷新，有已确认锁定数据时强制覆盖对应位置
	# 主技能进阶时不消费锁定数据
	if main_skill_name == "" and not locked_rewards.is_empty():
		print("[Lock] 覆盖已确认锁定奖励: ", locked_rewards.keys())
		if locked_rewards.has(1):
			reward1 = locked_rewards[1]
			print("[Lock] 位置1覆盖: ", reward1.reward_name)
		if locked_rewards.has(2):
			reward2 = locked_rewards[2]
			print("[Lock] 位置2覆盖: ", reward2.reward_name)
		if locked_rewards.has(3):
			reward3 = locked_rewards[3]
			print("[Lock] 位置3覆盖: ", reward3.reward_name)
	
	# 再用当前界面临时锁定覆盖（临时锁定优先级高于已确认锁定）
	if main_skill_name == "" and not tentative_locked_rewards.is_empty():
		print("[Lock] 覆盖临时锁定奖励: ", tentative_locked_rewards.keys())
		if tentative_locked_rewards.has(1):
			reward1 = tentative_locked_rewards[1]
			print("[Lock] 位置1临时覆盖: ", reward1.reward_name)
		if tentative_locked_rewards.has(2):
			reward2 = tentative_locked_rewards[2]
			print("[Lock] 位置2临时覆盖: ", reward2.reward_name)
		if tentative_locked_rewards.has(3):
			reward3 = tentative_locked_rewards[3]
			print("[Lock] 位置3临时覆盖: ", reward3.reward_name)
	
	# 重置按钮颜色（锁定位置保持灰色0.5，其他位置从透明渐入）
	var is_locked_1 = locked_rewards.has(1) or tentative_locked_rewards.has(1)
	var is_locked_2 = locked_rewards.has(2) or tentative_locked_rewards.has(2)
	var is_locked_3 = locked_rewards.has(3) or tentative_locked_rewards.has(3)
	if refresh_id == 0:
		lv_up_change_b1.modulate = Color(1, 1, 1, 0.0) if not is_locked_1 else Color(0.5, 0.5, 0.5, 0.0)
		lv_up_change_b2.modulate = Color(1, 1, 1, 0.0) if not is_locked_2 else Color(0.5, 0.5, 0.5, 0.0)
		lv_up_change_b3.modulate = Color(1, 1, 1, 0.0) if not is_locked_3 else Color(0.5, 0.5, 0.5, 0.0)
	
	# 连接升级选择完成信号，用于清理dark_overlay
	if !Global.is_connected("level_up_selection_complete", _on_level_up_selection_complete):
		Global.connect("level_up_selection_complete", _on_level_up_selection_complete)
	
	var rect_ready = Rect2(4, 176, 8, 16)
	var rect_off = Rect2(20, 176, 8, 16)
	var rect_on = Rect2(36, 176, 8, 16)
	
	# 主技能进阶时，如果三个选项都为空，用精进填充第一个选项
	if main_skill_name != "" and reward1 == null and reward2 == null and reward3 == null:
		var no_advance_reward = LvUp._get_no_advance_reward()
		if no_advance_reward != null:
			reward1 = no_advance_reward
			print("进阶池完全为空，用精进填充第一个选项")
	
	# 主技能进阶时，只显示两个选项并调整Y轴位置
	if main_skill_name != "":
		# 隐藏第三个按钮
		lv_up_change_b3.visible = false
		
		# 调整前两个按钮的Y轴位置，保持场景中配置的当前尺寸不变
		if reward1 != null:
			_configure_reward_button(lv_up_change_b1, reward1, rect_ready, rect_off, rect_on, refresh_id, 1)
			_set_reward_button_y(lv_up_change_b1, 101.0 + 100.0)
		else:
			lv_up_change_b1.visible = false
		
		if reward2 != null:
			_configure_reward_button(lv_up_change_b2, reward2, rect_ready, rect_off, rect_on, refresh_id, 2)
			_set_reward_button_y(lv_up_change_b2, 101.0 + 350.0)
		else:
			lv_up_change_b2.visible = false
	else:
		# 普通升级时，正常配置三个按钮并重置原始位置
		if reward1 != null:
			_configure_reward_button(lv_up_change_b1, reward1, rect_ready, rect_off, rect_on, refresh_id, 1)
			_set_reward_button_y(lv_up_change_b1, 84.0)
		elif refresh_id == 0:
			lv_up_change_b1.visible = false
		
		if reward2 != null:
			_configure_reward_button(lv_up_change_b2, reward2, rect_ready, rect_off, rect_on, refresh_id, 2)
			_set_reward_button_y(lv_up_change_b2, 285.0)
		elif refresh_id == 0:
			lv_up_change_b2.visible = false
		
		if reward3 != null:
			_configure_reward_button(lv_up_change_b3, reward3, rect_ready, rect_off, rect_on, refresh_id, 3)
			_set_reward_button_y(lv_up_change_b3, 486.0)
		elif refresh_id == 0:
			lv_up_change_b3.visible = false
	
	# 保存当前奖励数据
	# 普通升级(refresh_id==0)时清空全部；单个刷新时只更新对应位置
	if refresh_id == 0:
		current_rewards.clear()
	if reward1 != null:
		current_rewards[1] = reward1
	elif refresh_id == 1:
		current_rewards.erase(1)
	if reward2 != null:
		current_rewards[2] = reward2
	elif refresh_id == 2:
		current_rewards.erase(2)
	if reward3 != null:
		current_rewards[3] = reward3
	elif refresh_id == 3:
		current_rewards.erase(3)
	print("[Lock] current_rewards 已设置: keys=", current_rewards.keys(), "| reward1=", reward1.reward_name if reward1 else "null", "| reward2=", reward2.reward_name if reward2 else "null", "| reward3=", reward3.reward_name if reward3 else "null")
	
	# 创建渐显动画
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true) # 允许并行动画
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
		if skill_node and skill_node.has_method("set_game_paused"):
			skill_node.set_game_paused(true)
	
	# 暂停人物和怪物的动画
	_pause_all_animations(scene_tree)
	
	if scene_tree:
		scene_tree.set_pause(true)
	
	# 0.5秒渐显动画
	if lv_up_change_b1.visible:
		tween.tween_property(lv_up_change_b1, "modulate:a", 1.0, 0.5)
	if lv_up_change_b2.visible:
		tween.tween_property(lv_up_change_b2, "modulate:a", 1.0, 0.5)
	if lv_up_change_b3.visible:
		tween.tween_property(lv_up_change_b3, "modulate:a", 1.0, 0.5)


func _set_reward_button_y(button: Button, y: float) -> void:
	button.position = Vector2(button.position.x, y)


# 配置奖励按钮的私有函数
func _configure_reward_button(button: Button, reward, rect_ready: Rect2, rect_off: Rect2, rect_on: Rect2, _refresh_id: int, button_id: int):
	# 配置button内部要显示的数据
	var lvcb: Sprite2D = button.get_node("Pic")
	var lvTitle: RichTextLabel = button.get_node("Title")
	var lvLabel: RichTextLabel = button.get_node("Label")
	var lvcbd: RichTextLabel = button.get_node("Panel/Detail")
	var lvSkillLv: RichTextLabel = button.get_node("SkillLv")
	var lvAdvanceProgress1: Sprite2D = button.get_node("AdvanceProgress1")
	var lvAdvanceProgress2: Sprite2D = button.get_node("AdvanceProgress2")
	var lvAdvanceProgress3: Sprite2D = button.get_node("AdvanceProgress3")
	
	lvSkillLv.visible = false
	lvAdvanceProgress1.visible = false
	lvAdvanceProgress2.visible = false
	lvAdvanceProgress3.visible = false
	lvLabel.visible = true
	
	# 如果抽取到的是主要技能，则渲染进阶状态
	if reward.if_main_skill and !reward.if_advance:
		lvLabel.visible = false
		lvSkillLv.visible = true
		lvAdvanceProgress1.visible = true
		lvAdvanceProgress2.visible = true
		lvAdvanceProgress3.visible = true
		
		lvAdvanceProgress1.region_rect = rect_off
		lvAdvanceProgress2.region_rect = rect_off
		lvAdvanceProgress3.region_rect = rect_off
		
		var mainLV = LvUp._select_PC_main_skill_lv(reward.faction)
		lvSkillLv.text = "LV. " + str(mainLV) + "→" + str(mainLV + 1)
		
		var lights_to_turn_on = min(mainLV % 3, mainLV)
		if lights_to_turn_on >= 1:
			lvAdvanceProgress1.region_rect = rect_on
		if lights_to_turn_on >= 2:
			lvAdvanceProgress2.region_rect = rect_on
	
	var icon_path = LvUp.get_icon_path(reward.icon)
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		lvcb.texture = load(icon_path)
		lvcb.region_enabled = false
	else:
		lvcb.texture = null
	lvTitle.text = "[color=" + reward.rarity + "]" + reward.reward_name + "[/color]"
	lvLabel.text = reward.chinese_faction
	lvcbd.text = reward.detail
	var callback: Callable = Callable(LvUp, reward.on_selected)
	var connect_array = button.pressed.get_connections()
	if !connect_array.is_empty():
		for conn in connect_array:
			button.pressed.disconnect(conn.callable)
	# 包装回调，在选择前处理锁定逻辑并记录派系
	var reward_faction = reward.faction
	var wrapped_callback = func():
		_on_reward_button_selected(button_id)
		LvUp._last_applied_reward_faction = reward_faction
		callback.call()
	button.pressed.connect(wrapped_callback)

func configure_reward_button_for_external(button: Button, reward, button_id: int, selected_callback: Callable) -> void:
	var rect_ready = Rect2(4, 176, 8, 16)
	var rect_off = Rect2(20, 176, 8, 16)
	var rect_on = Rect2(36, 176, 8, 16)
	_configure_reward_button(button, reward, rect_ready, rect_off, rect_on, 0, button_id)
	var connect_array = button.pressed.get_connections()
	if !connect_array.is_empty():
		for conn in connect_array:
			button.pressed.disconnect(conn.callable)
	var reward_faction = reward.faction
	var wrapped_callback = func():
		SEManager.play("212")
		LvUp._last_applied_reward_faction = reward_faction
		selected_callback.call(reward)
	button.pressed.connect(wrapped_callback)

func set_external_reward_button_y(button: Button, y: float) -> void:
	_set_reward_button_y(button, y)

# 检查并处理待升级
func check_and_process_pending_level_ups(scene_tree: SceneTree = null, viewport: Viewport = null) -> void:
	# 战败后不再处理待升级项，直接清理升级UI
	if PC.is_game_over:
		_force_cleanup_level_up_ui()
		return
	# 诗想难度不弹出任何领悟/进阶界面
	if Global.current_stage_difficulty == Global.STAGE_DIFFICULTY_POETRY:
		return
	# 清理dark_overlay
	_cleanup_dark_overlay()
	
	var keep_paused_for_next_popup = _skip_next_level_up_delay
	if not keep_paused_for_next_popup:
		# 非连续弹窗入口才恢复技能节点状态；连续升级期间保持暂停。
		for skill_node in skill_nodes:
			if skill_node and skill_node.has_method("set_game_paused"):
				skill_node.set_game_paused(false)
	
	var advance_change = int(PC.main_skill_swordQi / 3.0)
	if PC.main_skill_swordQi != 0 and PC.main_skill_swordQi_advance < advance_change:
		PC.main_skill_swordQi_advance += 1
		handle_level_up("Swordqi", 0, scene_tree, viewport)
		# 主技能进阶完成后清空now_main_skill_name
	elif PC.main_skill_branch != 0 and PC.main_skill_branch_advance < int(PC.main_skill_branch / 3.0):
		PC.main_skill_branch_advance += 1
		handle_level_up("Branch", 0, scene_tree, viewport)
	elif PC.main_skill_moyan != 0 and PC.main_skill_moyan_advance < int(PC.main_skill_moyan / 3.0):
		PC.main_skill_moyan_advance += 1
		handle_level_up("Moyan", 0, scene_tree, viewport)
	elif PC.main_skill_riyan != 0 and PC.main_skill_riyan_advance < int(PC.main_skill_riyan / 3.0):
		PC.main_skill_riyan_advance += 1
		handle_level_up("Riyan", 0, scene_tree, viewport)
	elif PC.main_skill_ringFire != 0 and PC.main_skill_ringFire_advance < int(PC.main_skill_ringFire / 3.0):
		PC.main_skill_ringFire_advance += 1
		handle_level_up("Ringfire", 0, scene_tree, viewport)
	elif PC.main_skill_thunder != 0 and PC.main_skill_thunder_advance < int(PC.main_skill_thunder / 3.0):
		PC.main_skill_thunder_advance += 1
		handle_level_up("Thunder", 0, scene_tree, viewport)
	elif PC.main_skill_bloodwave != 0 and PC.main_skill_bloodwave_advance < int(PC.main_skill_bloodwave / 3.0):
		PC.main_skill_bloodwave_advance += 1
		handle_level_up("Bloodwave", 0, scene_tree, viewport)
	elif PC.main_skill_bloodboardsword != 0 and PC.main_skill_bloodboardsword_advance < int(PC.main_skill_bloodboardsword / 3.0):
		PC.main_skill_bloodboardsword_advance += 1
		handle_level_up("Bloodboardsword", 0, scene_tree, viewport)
	elif PC.main_skill_ice != 0 and PC.main_skill_ice_advance < int(PC.main_skill_ice / 3.0):
		PC.main_skill_ice_advance += 1
		handle_level_up("Ice", 0, scene_tree, viewport)
	elif PC.main_skill_thunder_break != 0 and PC.main_skill_thunder_break_advance < int(PC.main_skill_thunder_break / 3.0):
		PC.main_skill_thunder_break_advance += 1
		handle_level_up("Thunderbreak", 0, scene_tree, viewport)
	elif PC.main_skill_light_bullet != 0 and PC.main_skill_light_bullet_advance < int(PC.main_skill_light_bullet / 3.0):
		PC.main_skill_light_bullet_advance += 1
		handle_level_up("Lightbullet", 0, scene_tree, viewport)
	elif PC.main_skill_qigong != 0 and PC.main_skill_qigong_advance < int(PC.main_skill_qigong / 3.0):
		PC.main_skill_qigong_advance += 1
		handle_level_up("Qigong", 0, scene_tree, viewport)
	elif PC.main_skill_water != 0 and PC.main_skill_water_advance < int(PC.main_skill_water / 3.0):
		PC.main_skill_water_advance += 1
		handle_level_up("Water", 0, scene_tree, viewport)
	elif PC.main_skill_qiankun != 0 and PC.main_skill_qiankun_advance < int(PC.main_skill_qiankun / 3.0):
		PC.main_skill_qiankun_advance += 1
		handle_level_up("Qiankun", 0, scene_tree, viewport)
	elif PC.main_skill_xuanwu != 0 and PC.main_skill_xuanwu_advance < int(PC.main_skill_xuanwu / 3.0):
		PC.main_skill_xuanwu_advance += 1
		handle_level_up("Xuanwu", 0, scene_tree, viewport)
	elif PC.main_skill_xunfeng != 0 and PC.main_skill_xunfeng_advance < int(PC.main_skill_xunfeng / 3.0):
		PC.main_skill_xunfeng_advance += 1
		handle_level_up("Xunfeng", 0, scene_tree, viewport)
	elif PC.main_skill_genshan != 0 and PC.main_skill_genshan_advance < int(PC.main_skill_genshan / 3.0):
		PC.main_skill_genshan_advance += 1
		handle_level_up("Genshan", 0, scene_tree, viewport)
	elif PC.main_skill_duize != 0 and PC.main_skill_duize_advance < int(PC.main_skill_duize / 3.0):
		PC.main_skill_duize_advance += 1
		handle_level_up("Duize", 0, scene_tree, viewport)
	elif PC.main_skill_dragonwind != 0 and PC.main_skill_dragonwind_advance < int(PC.main_skill_dragonwind / 3.0):
		PC.main_skill_dragonwind_advance += 1
		handle_level_up("Dragonwind", 0, scene_tree, viewport)
	elif PC.main_skill_holylight != 0 and PC.main_skill_holylight_advance < int(PC.main_skill_holylight / 3.0):
		PC.main_skill_holylight_advance += 1
		handle_level_up("Holylight", 0, scene_tree, viewport)
	# 如果没有主技能进阶，或者主技能进阶处理完毕后，再处理普通待升级
	elif pending_level_ups > 0:
		handle_level_up("", 0, scene_tree, viewport)
		# 清理升级选择时创建的背景变暗效果（仅普通升级时）
		now_main_skill_name = ""

func pop_next_pending_advance_name() -> String:
	var advance_change = int(PC.main_skill_swordQi / 3.0)
	if PC.main_skill_swordQi != 0 and PC.main_skill_swordQi_advance < advance_change:
		PC.main_skill_swordQi_advance += 1
		return "Swordqi"
	if PC.main_skill_branch != 0 and PC.main_skill_branch_advance < int(PC.main_skill_branch / 3.0):
		PC.main_skill_branch_advance += 1
		return "Branch"
	if PC.main_skill_moyan != 0 and PC.main_skill_moyan_advance < int(PC.main_skill_moyan / 3.0):
		PC.main_skill_moyan_advance += 1
		return "Moyan"
	if PC.main_skill_riyan != 0 and PC.main_skill_riyan_advance < int(PC.main_skill_riyan / 3.0):
		PC.main_skill_riyan_advance += 1
		return "Riyan"
	if PC.main_skill_ringFire != 0 and PC.main_skill_ringFire_advance < int(PC.main_skill_ringFire / 3.0):
		PC.main_skill_ringFire_advance += 1
		return "Ringfire"
	if PC.main_skill_thunder != 0 and PC.main_skill_thunder_advance < int(PC.main_skill_thunder / 3.0):
		PC.main_skill_thunder_advance += 1
		return "Thunder"
	if PC.main_skill_bloodwave != 0 and PC.main_skill_bloodwave_advance < int(PC.main_skill_bloodwave / 3.0):
		PC.main_skill_bloodwave_advance += 1
		return "Bloodwave"
	if PC.main_skill_bloodboardsword != 0 and PC.main_skill_bloodboardsword_advance < int(PC.main_skill_bloodboardsword / 3.0):
		PC.main_skill_bloodboardsword_advance += 1
		return "Bloodboardsword"
	if PC.main_skill_ice != 0 and PC.main_skill_ice_advance < int(PC.main_skill_ice / 3.0):
		PC.main_skill_ice_advance += 1
		return "Ice"
	if PC.main_skill_thunder_break != 0 and PC.main_skill_thunder_break_advance < int(PC.main_skill_thunder_break / 3.0):
		PC.main_skill_thunder_break_advance += 1
		return "Thunderbreak"
	if PC.main_skill_light_bullet != 0 and PC.main_skill_light_bullet_advance < int(PC.main_skill_light_bullet / 3.0):
		PC.main_skill_light_bullet_advance += 1
		return "Lightbullet"
	if PC.main_skill_qigong != 0 and PC.main_skill_qigong_advance < int(PC.main_skill_qigong / 3.0):
		PC.main_skill_qigong_advance += 1
		return "Qigong"
	if PC.main_skill_water != 0 and PC.main_skill_water_advance < int(PC.main_skill_water / 3.0):
		PC.main_skill_water_advance += 1
		return "Water"
	if PC.main_skill_qiankun != 0 and PC.main_skill_qiankun_advance < int(PC.main_skill_qiankun / 3.0):
		PC.main_skill_qiankun_advance += 1
		return "Qiankun"
	if PC.main_skill_xuanwu != 0 and PC.main_skill_xuanwu_advance < int(PC.main_skill_xuanwu / 3.0):
		PC.main_skill_xuanwu_advance += 1
		return "Xuanwu"
	if PC.main_skill_xunfeng != 0 and PC.main_skill_xunfeng_advance < int(PC.main_skill_xunfeng / 3.0):
		PC.main_skill_xunfeng_advance += 1
		return "Xunfeng"
	if PC.main_skill_genshan != 0 and PC.main_skill_genshan_advance < int(PC.main_skill_genshan / 3.0):
		PC.main_skill_genshan_advance += 1
		return "Genshan"
	if PC.main_skill_duize != 0 and PC.main_skill_duize_advance < int(PC.main_skill_duize / 3.0):
		PC.main_skill_duize_advance += 1
		return "Duize"
	if PC.main_skill_dragonwind != 0 and PC.main_skill_dragonwind_advance < int(PC.main_skill_dragonwind / 3.0):
		PC.main_skill_dragonwind_advance += 1
		return "Dragonwind"
	if PC.main_skill_holylight != 0 and PC.main_skill_holylight_advance < int(PC.main_skill_holylight / 3.0):
		PC.main_skill_holylight_advance += 1
		return "Holylight"
	return ""

func pop_pending_advance_name_for(main_skill_name: String) -> String:
	match main_skill_name:
		"Swordqi":
			if PC.main_skill_swordQi != 0 and PC.main_skill_swordQi_advance < int(PC.main_skill_swordQi / 3.0):
				PC.main_skill_swordQi_advance += 1
				return "Swordqi"
		"Branch":
			if PC.main_skill_branch != 0 and PC.main_skill_branch_advance < int(PC.main_skill_branch / 3.0):
				PC.main_skill_branch_advance += 1
				return "Branch"
		"Moyan":
			if PC.main_skill_moyan != 0 and PC.main_skill_moyan_advance < int(PC.main_skill_moyan / 3.0):
				PC.main_skill_moyan_advance += 1
				return "Moyan"
		"Riyan":
			if PC.main_skill_riyan != 0 and PC.main_skill_riyan_advance < int(PC.main_skill_riyan / 3.0):
				PC.main_skill_riyan_advance += 1
				return "Riyan"
		"Ringfire":
			if PC.main_skill_ringFire != 0 and PC.main_skill_ringFire_advance < int(PC.main_skill_ringFire / 3.0):
				PC.main_skill_ringFire_advance += 1
				return "Ringfire"
		"Thunder":
			if PC.main_skill_thunder != 0 and PC.main_skill_thunder_advance < int(PC.main_skill_thunder / 3.0):
				PC.main_skill_thunder_advance += 1
				return "Thunder"
		"Bloodwave":
			if PC.main_skill_bloodwave != 0 and PC.main_skill_bloodwave_advance < int(PC.main_skill_bloodwave / 3.0):
				PC.main_skill_bloodwave_advance += 1
				return "Bloodwave"
		"Bloodboardsword":
			if PC.main_skill_bloodboardsword != 0 and PC.main_skill_bloodboardsword_advance < int(PC.main_skill_bloodboardsword / 3.0):
				PC.main_skill_bloodboardsword_advance += 1
				return "Bloodboardsword"
		"Ice":
			if PC.main_skill_ice != 0 and PC.main_skill_ice_advance < int(PC.main_skill_ice / 3.0):
				PC.main_skill_ice_advance += 1
				return "Ice"
		"Thunderbreak":
			if PC.main_skill_thunder_break != 0 and PC.main_skill_thunder_break_advance < int(PC.main_skill_thunder_break / 3.0):
				PC.main_skill_thunder_break_advance += 1
				return "Thunderbreak"
		"Lightbullet":
			if PC.main_skill_light_bullet != 0 and PC.main_skill_light_bullet_advance < int(PC.main_skill_light_bullet / 3.0):
				PC.main_skill_light_bullet_advance += 1
				return "Lightbullet"
		"Qigong":
			if PC.main_skill_qigong != 0 and PC.main_skill_qigong_advance < int(PC.main_skill_qigong / 3.0):
				PC.main_skill_qigong_advance += 1
				return "Qigong"
		"Water":
			if PC.main_skill_water != 0 and PC.main_skill_water_advance < int(PC.main_skill_water / 3.0):
				PC.main_skill_water_advance += 1
				return "Water"
		"Qiankun":
			if PC.main_skill_qiankun != 0 and PC.main_skill_qiankun_advance < int(PC.main_skill_qiankun / 3.0):
				PC.main_skill_qiankun_advance += 1
				return "Qiankun"
		"Xuanwu":
			if PC.main_skill_xuanwu != 0 and PC.main_skill_xuanwu_advance < int(PC.main_skill_xuanwu / 3.0):
				PC.main_skill_xuanwu_advance += 1
				return "Xuanwu"
		"Xunfeng":
			if PC.main_skill_xunfeng != 0 and PC.main_skill_xunfeng_advance < int(PC.main_skill_xunfeng / 3.0):
				PC.main_skill_xunfeng_advance += 1
				return "Xunfeng"
		"Genshan":
			if PC.main_skill_genshan != 0 and PC.main_skill_genshan_advance < int(PC.main_skill_genshan / 3.0):
				PC.main_skill_genshan_advance += 1
				return "Genshan"
		"Duize":
			if PC.main_skill_duize != 0 and PC.main_skill_duize_advance < int(PC.main_skill_duize / 3.0):
				PC.main_skill_duize_advance += 1
				return "Duize"
		"Dragonwind":
			if PC.main_skill_dragonwind != 0 and PC.main_skill_dragonwind_advance < int(PC.main_skill_dragonwind / 3.0):
				PC.main_skill_dragonwind_advance += 1
				return "Dragonwind"
		"Holylight":
			if PC.main_skill_holylight != 0 and PC.main_skill_holylight_advance < int(PC.main_skill_holylight / 3.0):
				PC.main_skill_holylight_advance += 1
				return "Holylight"
	return ""

# 玩家点击某个奖励按钮时的处理（在奖励效果应用前调用）
func _on_reward_button_selected(selected_button_id: int) -> void:
	SEManager.play("212")
	# 处理当前界面临时锁定
	if not tentative_locked_rewards.is_empty():
		if tentative_locked_rewards.has(selected_button_id):
			# 玩家选择了被临时锁定的项 → 临时锁定全部不转为已确认，直接清空
			print("[Lock] 选择了临时锁定项 ", selected_button_id, "，清空所有临时锁定")
		else:
			# 玩家选择了其他项 → 临时锁定转为已确认锁定
			for btn_id in tentative_locked_rewards.keys():
				locked_rewards[btn_id] = tentative_locked_rewards[btn_id]
				print("[Lock] 临时锁定转正 位置", btn_id, ": ", tentative_locked_rewards[btn_id].reward_name)
		tentative_locked_rewards.clear()
	
	# 如果玩家选择了已确认锁定的项，消费掉该锁定
	if locked_rewards.has(selected_button_id):
		print("[Lock] 消费已确认锁定 位置", selected_button_id, ": ", locked_rewards[selected_button_id].reward_name)
		locked_rewards.erase(selected_button_id)

# 升级选择完成回调
func _on_level_up_selection_complete(_viewport: Viewport = null) -> void:
	# 战败后直接清理升级界面，防止游戏卡死
	if PC.is_game_over:
		_force_cleanup_level_up_ui()
		return
	
	# 清理升级选择时创建的背景变暗效果
	_cleanup_dark_overlay()
	# 清空当前界面临时锁定数据
	if not tentative_locked_rewards.is_empty():
		print("[Lock] 界面关闭，清空临时锁定数据: ", tentative_locked_rewards.keys())
		tentative_locked_rewards.clear()
	# 重置所有按钮颜色，清除锁定时留下的灰色滤镜
	lv_up_change_b1.modulate = Color(1, 1, 1, 1)
	lv_up_change_b2.modulate = Color(1, 1, 1, 1)
	lv_up_change_b3.modulate = Color(1, 1, 1, 1)
	# 清空当前奖励数据（已确认锁定数据保留到下次）
	current_rewards.clear()
	
	# 检查是否还有待升级（包括 advance）
	var has_more = _has_pending_upgrades()
	print("[LvUp] _on_level_up_selection_complete: pending=", pending_level_ups, " has_more=", has_more, " advance_pending=", _check_any_advance_pending(), " instant=", PC.instant_level_up)
	if canvas_layer and canvas_layer.has_method("_refresh_faze_ui"):
		canvas_layer._refresh_faze_ui()
	if canvas_layer and canvas_layer.has_method("_update_lv_up_start_button_badge"):
		canvas_layer._update_lv_up_start_button_badge()
	
	if has_more:
		# 连续升级/进阶期间，奖励脚本可能刚解除暂停；这里立刻接管并保持暂停，
		# 在暂停状态下等待0.25秒后直接弹出下一组选项。
		Global.is_level_up = true
		if canvas_layer and canvas_layer.has_method("_update_lv_up_start_button_badge"):
			canvas_layer._update_lv_up_start_button_badge()
		if get_tree():
			get_tree().set_pause(true)
			_pause_all_animations(get_tree())
		for skill_node in skill_nodes:
			if skill_node and skill_node.has_method("set_game_paused"):
				skill_node.set_game_paused(true)
		_fade_instant_level_up_button(false)
		var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.set_ignore_time_scale(true)
		tween.tween_property(lv_up_change, "modulate:a", 0.0, 0.25)
		tween.tween_callback(func():
			lv_up_change.modulate.a = 1.0
			_skip_next_level_up_delay = true
			check_and_process_pending_level_ups(get_tree(), get_viewport())
			if canvas_layer and canvas_layer.has_method("_update_lv_up_start_button_badge"):
				canvas_layer._update_lv_up_start_button_badge()
		)
	else:
		# 所有升级完成，隐藏界面
		lv_up_change.visible = false
		_set_active_skill_icons_interactive(true)
		# 恢复Buff悬停提示
		BuffManager.set_buffs_interactive(true)
		BOSS_HP_BAR_SCRIPT.set_boss_buffs_interactive(true)
		# 渐出 instant_level_up_button（与升级选项一同消失）
		_fade_instant_level_up_button(false)
		Global.is_level_up = false
		if canvas_layer and canvas_layer.has_method("_update_lv_up_start_button_badge"):
			canvas_layer._update_lv_up_start_button_badge()
		# 恢复技能节点暂停状态
		for skill_node in skill_nodes:
			if skill_node and skill_node.has_method("set_game_paused"):
				skill_node.set_game_paused(false)
		if get_tree():
			get_tree().set_pause(false)
			# 恢复人物和怪物的动画
			_resume_all_animations(get_tree())
		# 只有普通升级结束时播放0.5秒缓速；如果是advance升级后结束则跳过
		if now_main_skill_name == "":
			_play_slow_motion_focus()

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
	if not PC.instant_level_up:
		# 手动模式下通知 UI 显示 level_up_button
		Global.emit_signal("manual_level_up_pending")

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

# 获取升级所需经验值（升级经验）
func get_required_lv_up_value(level: int) -> float:
	# todo 测试期间/10
	var value: float = 700
	for i in range(level):
		value = (value + 1000 + 12 * (i + 1) * i)
	if level >= 70:
		value *= 4.0
	elif level >= 60:
		value *= 2.0
	elif level >= 50:
		value *= 1.5
	elif level >= 40:
		value *= 1.25
	if level <= 10:
		value *= 0.5
	# 修习树领悟篇：升级经验需求降低
	var reduction_mult = clampf(1.0 - Global.study_exp_reduction, 0.2, 1.0)
	return value * reduction_mult

# 清理dark_overlay的私有函数
func _cleanup_dark_overlay() -> void:
	if has_meta("dark_overlay"):
		var dark_overlay = get_meta("dark_overlay")
		if dark_overlay != null and is_instance_valid(dark_overlay):
			dark_overlay.queue_free()
		remove_meta("dark_overlay")

# 强制清理升级界面（战败时调用，防止游戏卡死）
func _force_cleanup_level_up_ui() -> void:
	_cleanup_dark_overlay()
	if lv_up_change:
		lv_up_change.visible = false
		lv_up_change.modulate.a = 1.0
	_set_active_skill_icons_interactive(true)
	# 恢复Buff悬停提示
	BuffManager.set_buffs_interactive(true)
	BOSS_HP_BAR_SCRIPT.set_boss_buffs_interactive(true)
	Global.is_level_up = false
	pending_level_ups = 0
	_skip_next_level_up_delay = false
	current_rewards.clear()
	tentative_locked_rewards.clear()
	now_main_skill_name = ""
	# 恢复技能节点状态
	for skill_node in skill_nodes:
		if skill_node and skill_node.has_method("set_game_paused"):
			skill_node.set_game_paused(false)
	# 取消游戏树暂停
	if get_tree():
		get_tree().set_pause(false)
	print("[LvUp] _force_cleanup_level_up_ui: 战败后强制清理升级界面")

func pause_battle_for_external_popup(scene_tree: SceneTree) -> void:
	_set_active_skill_icons_interactive(false)
	BuffManager.set_buffs_interactive(false)
	BOSS_HP_BAR_SCRIPT.set_boss_buffs_interactive(false)
	for skill_node in skill_nodes:
		if skill_node and skill_node.has_method("set_game_paused"):
			skill_node.set_game_paused(true)
	_pause_all_animations(scene_tree)
	if scene_tree:
		scene_tree.set_pause(true)

func resume_battle_from_external_popup(scene_tree: SceneTree) -> void:
	_set_active_skill_icons_interactive(true)
	BuffManager.set_buffs_interactive(true)
	BOSS_HP_BAR_SCRIPT.set_boss_buffs_interactive(true)
	for skill_node in skill_nodes:
		if skill_node and skill_node.has_method("set_game_paused"):
			skill_node.set_game_paused(false)
	if scene_tree:
		scene_tree.set_pause(false)
		_resume_all_animations(scene_tree)

# 暂停所有人物和怪物的动画
func _pause_all_animations(scene_tree: SceneTree) -> void:
	if not scene_tree:
		return
	
	# 暂停玩家动画
	var players = scene_tree.get_nodes_in_group("player")
	for player in players:
		var sprite = player.get_node_or_null("AnimatedSprite2D")
		if sprite and sprite is AnimatedSprite2D:
			sprite.pause()
	
	# 暂停怪物动画
	var enemies = scene_tree.get_nodes_in_group("enemies")
	for enemy in enemies:
		var sprite = enemy.get_node_or_null("AnimatedSprite2D")
		if sprite and sprite is AnimatedSprite2D:
			sprite.pause()


# 恢复所有人物和怪物的动画
func _resume_all_animations(scene_tree: SceneTree) -> void:
	if not scene_tree:
		return
	
	# 恢复玩家动画
	var players = scene_tree.get_nodes_in_group("player")
	for player in players:
		var sprite = player.get_node_or_null("AnimatedSprite2D")
		if sprite and sprite is AnimatedSprite2D:
			sprite.play()
	
	# 恢复怪物动画
	var enemies = scene_tree.get_nodes_in_group("enemies")
	for enemy in enemies:
		var sprite = enemy.get_node_or_null("AnimatedSprite2D")
		if sprite and sprite is AnimatedSprite2D:
			sprite.play()

func _set_active_skill_icons_interactive(interactive: bool) -> void:
	if not canvas_layer:
		return
	if not interactive and canvas_layer.has_method("hide_active_skill_label"):
		canvas_layer.hide_active_skill_label()
	var active_icons: Array[Control] = [
		canvas_layer.get("active1") as Control,
		canvas_layer.get("active2") as Control,
		canvas_layer.get("active3") as Control
	]
	for icon in active_icons:
		if not icon or not is_instance_valid(icon):
			continue
		if interactive:
			if _active_icon_mouse_filters.has(icon):
				icon.mouse_filter = int(_active_icon_mouse_filters[icon])
			else:
				icon.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			if not _active_icon_mouse_filters.has(icon):
				_active_icon_mouse_filters[icon] = icon.mouse_filter
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if interactive:
		_active_icon_mouse_filters.clear()

# ============== 待升级检查 ==============

# 检查是否还有待升级（普通 + advance）
func _has_pending_upgrades() -> bool:
	if pending_level_ups > 0:
		return true
	return _check_any_advance_pending()

# 仅检查是否有待触发的 advance（不执行）
func _check_any_advance_pending() -> bool:
	if PC.main_skill_swordQi != 0 and PC.main_skill_swordQi_advance < int(PC.main_skill_swordQi / 3.0):
		return true
	if PC.main_skill_branch != 0 and PC.main_skill_branch_advance < int(PC.main_skill_branch / 3.0):
		return true
	if PC.main_skill_moyan != 0 and PC.main_skill_moyan_advance < int(PC.main_skill_moyan / 3.0):
		return true
	if PC.main_skill_riyan != 0 and PC.main_skill_riyan_advance < int(PC.main_skill_riyan / 3.0):
		return true
	if PC.main_skill_ringFire != 0 and PC.main_skill_ringFire_advance < int(PC.main_skill_ringFire / 3.0):
		return true
	if PC.main_skill_thunder != 0 and PC.main_skill_thunder_advance < int(PC.main_skill_thunder / 3.0):
		return true
	if PC.main_skill_bloodwave != 0 and PC.main_skill_bloodwave_advance < int(PC.main_skill_bloodwave / 3.0):
		return true
	if PC.main_skill_bloodboardsword != 0 and PC.main_skill_bloodboardsword_advance < int(PC.main_skill_bloodboardsword / 3.0):
		return true
	if PC.main_skill_ice != 0 and PC.main_skill_ice_advance < int(PC.main_skill_ice / 3.0):
		return true
	if PC.main_skill_thunder_break != 0 and PC.main_skill_thunder_break_advance < int(PC.main_skill_thunder_break / 3.0):
		return true
	if PC.main_skill_light_bullet != 0 and PC.main_skill_light_bullet_advance < int(PC.main_skill_light_bullet / 3.0):
		return true
	if PC.main_skill_qigong != 0 and PC.main_skill_qigong_advance < int(PC.main_skill_qigong / 3.0):
		return true
	if PC.main_skill_water != 0 and PC.main_skill_water_advance < int(PC.main_skill_water / 3.0):
		return true
	if PC.main_skill_qiankun != 0 and PC.main_skill_qiankun_advance < int(PC.main_skill_qiankun / 3.0):
		return true
	if PC.main_skill_xuanwu != 0 and PC.main_skill_xuanwu_advance < int(PC.main_skill_xuanwu / 3.0):
		return true
	if PC.main_skill_xunfeng != 0 and PC.main_skill_xunfeng_advance < int(PC.main_skill_xunfeng / 3.0):
		return true
	if PC.main_skill_genshan != 0 and PC.main_skill_genshan_advance < int(PC.main_skill_genshan / 3.0):
		return true
	if PC.main_skill_duize != 0 and PC.main_skill_duize_advance < int(PC.main_skill_duize / 3.0):
		return true
	if PC.main_skill_dragonwind != 0 and PC.main_skill_dragonwind_advance < int(PC.main_skill_dragonwind / 3.0):
		return true
	if PC.main_skill_holylight != 0 and PC.main_skill_holylight_advance < int(PC.main_skill_holylight / 3.0):
		return true
	return false

# 计算待 advance 数量（用于 badge 显示）
func count_pending_advances() -> int:
	var count = 0
	if PC.main_skill_swordQi != 0 and PC.main_skill_swordQi_advance < int(PC.main_skill_swordQi / 3.0): count += 1
	if PC.main_skill_branch != 0 and PC.main_skill_branch_advance < int(PC.main_skill_branch / 3.0): count += 1
	if PC.main_skill_moyan != 0 and PC.main_skill_moyan_advance < int(PC.main_skill_moyan / 3.0): count += 1
	if PC.main_skill_riyan != 0 and PC.main_skill_riyan_advance < int(PC.main_skill_riyan / 3.0): count += 1
	if PC.main_skill_ringFire != 0 and PC.main_skill_ringFire_advance < int(PC.main_skill_ringFire / 3.0): count += 1
	if PC.main_skill_thunder != 0 and PC.main_skill_thunder_advance < int(PC.main_skill_thunder / 3.0): count += 1
	if PC.main_skill_bloodwave != 0 and PC.main_skill_bloodwave_advance < int(PC.main_skill_bloodwave / 3.0): count += 1
	if PC.main_skill_bloodboardsword != 0 and PC.main_skill_bloodboardsword_advance < int(PC.main_skill_bloodboardsword / 3.0): count += 1
	if PC.main_skill_ice != 0 and PC.main_skill_ice_advance < int(PC.main_skill_ice / 3.0): count += 1
	if PC.main_skill_thunder_break != 0 and PC.main_skill_thunder_break_advance < int(PC.main_skill_thunder_break / 3.0): count += 1
	if PC.main_skill_light_bullet != 0 and PC.main_skill_light_bullet_advance < int(PC.main_skill_light_bullet / 3.0): count += 1
	if PC.main_skill_qigong != 0 and PC.main_skill_qigong_advance < int(PC.main_skill_qigong / 3.0): count += 1
	if PC.main_skill_water != 0 and PC.main_skill_water_advance < int(PC.main_skill_water / 3.0): count += 1
	if PC.main_skill_qiankun != 0 and PC.main_skill_qiankun_advance < int(PC.main_skill_qiankun / 3.0): count += 1
	if PC.main_skill_xuanwu != 0 and PC.main_skill_xuanwu_advance < int(PC.main_skill_xuanwu / 3.0): count += 1
	if PC.main_skill_xunfeng != 0 and PC.main_skill_xunfeng_advance < int(PC.main_skill_xunfeng / 3.0): count += 1
	if PC.main_skill_genshan != 0 and PC.main_skill_genshan_advance < int(PC.main_skill_genshan / 3.0): count += 1
	if PC.main_skill_duize != 0 and PC.main_skill_duize_advance < int(PC.main_skill_duize / 3.0): count += 1
	if PC.main_skill_dragonwind != 0 and PC.main_skill_dragonwind_advance < int(PC.main_skill_dragonwind / 3.0): count += 1
	if PC.main_skill_holylight != 0 and PC.main_skill_holylight_advance < int(PC.main_skill_holylight / 3.0): count += 1
	return count

# 升级完成后0.5秒引擎减速效果，让玩家看清当前位置
func _play_slow_motion_focus() -> void:
	if not Global.time_slow_enabled:
		return
	Engine.time_scale = 0.2
	# 使用不受time_scale影响的SceneTreeTimer，0.1s实际时间 = 0.5s游戏时间
	get_tree().create_timer(0.5, true, false, true).timeout.connect(func():
		Engine.time_scale = Global.game_speed
	)

## 渐入/渐出 instant_level_up_button 及其 label，与升级选项界面同步
## fade_label: 是否同步渐入渐出label（刷新时不渐入label）
func _fade_instant_level_up_button(fade_in: bool, fade_label: bool = true) -> void:
	if not canvas_layer or not canvas_layer.has_method("get"):
		return
	var btn: CheckButton = canvas_layer.get("instant_level_up_button")
	var lbl: Label = canvas_layer.get("instant_level_up_button_label")
	if not btn or not is_instance_valid(btn):
		return
	if fade_in:
		btn.visible = true
		btn.modulate.a = 0.0
		var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(btn, "modulate:a", 1.0, 0.25)
		if fade_label and lbl and is_instance_valid(lbl):
			lbl.visible = true
			lbl.modulate.a = 0.0
			tw.parallel().tween_property(lbl, "modulate:a", 1.0, 0.25)
	else:
		var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(btn, "modulate:a", 0.0, 0.2)
		if fade_label and lbl and is_instance_valid(lbl):
			tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.2)
		tw.tween_callback(func():
			btn.visible = false
			btn.modulate.a = 1.0
			if fade_label and lbl and is_instance_valid(lbl):
				lbl.visible = false
				lbl.modulate.a = 1.0
		)
