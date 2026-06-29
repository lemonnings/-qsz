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
var _active_icon_child_mouse_filters: Dictionary = {}
var _skip_next_level_up_delay: bool = false
var _skill_resume_request_id: int = 0
var _slow_motion_focus_request_id: int = 0
var _mobile_reward_guard_until_msec: int = 0
var _mobile_reward_guard_request_id: int = 0

const SKILL_RESUME_BATCH_SIZE := 4
const REFRESH_ALL_UNLOCKED_ID := -1
const LEVEL_UP_REWARD_OPEN_FADE_DURATION := 0.15
const LEVEL_UP_REWARD_EXPAND_DURATION := 0.15
const MOBILE_LEVEL_UP_INPUT_GUARD_SECONDS: float = 0.2
const REWARD_BUFF_HINT_OVERRIDES := {
	"泥沼": "移动速度降低 25 %",
	"减速": "移动速度降低 25 %",
	"易伤": "受到的伤害增加 20 %",
	"燃烧": "每秒受到 40 %攻击力的伤害，并对周围小范围内敌人造成一半的伤害",
	"聚怪": "牵引附近敌人"
}
const REWARD_BUFF_HINT_IGNORED_NAMES := {
	"护盾": true,
	"回复": true
}

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
	if Global.current_stage_difficulty == Global.STAGE_DIFFICULTY_POETRY:
		if main_skill_name == "" and refresh_id == 0:
			pending_level_ups = max(0, pending_level_ups - 1)
			_resolve_poetry_level_up_without_popup(scene_tree, true)
		else:
			_resolve_poetry_level_up_without_popup(scene_tree, false)
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
		await scene_tree.create_timer(0.08, false, false, false).timeout
	
	# await期间玩家可能已死亡，重新检查
	if PC.is_game_over:
		_force_cleanup_level_up_ui()
		return
	
	if refresh_id == 0:
		lv_up_change.modulate.a = 0.0
	lv_up_change.visible = true
	if canvas_layer and canvas_layer.has_method("set_level_up_exit_button_visible"):
		canvas_layer.set_level_up_exit_button_visible(main_skill_name == "")
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
	
	# 0是默认三个抽选，123是单独刷新，REFRESH_ALL_UNLOCKED_ID是刷新所有未锁定栏位
	var reward1 = null
	var reward2 = null
	var reward3 = null
	
	# 主技能进阶时，检查进阶池是否完全为空
	var advance_pool_is_empty = false
	if main_skill_name != "":
		advance_pool_is_empty = LvUp.is_advance_pool_empty(main_skill_name)
	
	# 普通升级时，已确认锁定的位置不抽取（节省奖池）
	var skip_reward1 = (main_skill_name == "" and (locked_rewards.has(1) or (refresh_id == REFRESH_ALL_UNLOCKED_ID and tentative_locked_rewards.has(1))))
	var skip_reward2 = (main_skill_name == "" and (locked_rewards.has(2) or (refresh_id == REFRESH_ALL_UNLOCKED_ID and tentative_locked_rewards.has(2))))
	var skip_reward3 = (main_skill_name == "" and (locked_rewards.has(3) or (refresh_id == REFRESH_ALL_UNLOCKED_ID and tentative_locked_rewards.has(3))))
	
	# 收集已确认锁定的奖励ID，排除在抽取之外。主技能进阶不受普通升级锁定影响。
	var exclude_reward_ids: Array[String] = []
	if main_skill_name == "":
		for btn_id in locked_rewards.keys():
			var locked_reward = locked_rewards[btn_id]
			if locked_reward != null:
				exclude_reward_ids.append(locked_reward.id)
		for btn_id in tentative_locked_rewards.keys():
			var locked_reward = tentative_locked_rewards[btn_id]
			if locked_reward != null:
				exclude_reward_ids.append(locked_reward.id)
	if not exclude_reward_ids.is_empty():
		print("[Lock] 抽取排除已锁定奖励: ", exclude_reward_ids)
	
	# 调试：打印当前概率阈值
	print("[Reward] 概率阈值: red_p=", PC.now_red_p, " gold_p=", PC.now_gold_p, " darkorchid_p=", PC.now_darkorchid_p, " | 累积: red<=", PC.now_red_p, " gold<=", PC.now_gold_p + PC.now_red_p, " darkorchid<=", PC.now_darkorchid_p + PC.now_gold_p + PC.now_red_p)
	
	var should_roll_reward1 := (refresh_id == 0 or refresh_id == 1 or refresh_id == REFRESH_ALL_UNLOCKED_ID) and not skip_reward1
	var should_roll_reward2 := (refresh_id == 0 or refresh_id == 2 or refresh_id == REFRESH_ALL_UNLOCKED_ID) and not skip_reward2
	var should_roll_reward3 := (refresh_id == 0 or refresh_id == 3 or refresh_id == REFRESH_ALL_UNLOCKED_ID) and not skip_reward3

	if should_roll_reward1:
		reward1 = LvUp.get_reward_level(r1_rand, main_skill_name, exclude_reward_ids)
		if reward1 == null:
			if refresh_id > 0:
				PC.refresh_num += 1
			print("普通抽取池已空")
		elif reward1.reward_name == "noReward":
			if refresh_id > 0:
				PC.refresh_num += 1
			print("专属技能抽取池已空")
		# 如果是主技能进阶且进阶池不为空，但抽到了精进，则隐藏该选项
		elif main_skill_name != "" and not advance_pool_is_empty and reward1.id == "NoAdvance":
			reward1 = null
			if refresh_id > 0:
				PC.refresh_num += 1
			print("进阶池不为空，跳过精进选项")
	if should_roll_reward2:
		reward2 = LvUp.get_reward_level(r2_rand, main_skill_name, exclude_reward_ids)
		if reward2 == null:
			if refresh_id > 0:
				PC.refresh_num += 1
			print("普通抽取池已空")
		elif reward2.reward_name == "noReward":
			if refresh_id > 0:
				PC.refresh_num += 1
			print("专属技能抽取池已空")
		# 如果是主技能进阶且进阶池不为空，但抽到了精进，则隐藏该选项
		elif main_skill_name != "" and not advance_pool_is_empty and reward2.id == "NoAdvance":
			reward2 = null
			if refresh_id > 0:
				PC.refresh_num += 1
			print("进阶池不为空，跳过精进选项")
	if should_roll_reward3:
		reward3 = LvUp.get_reward_level(r3_rand, main_skill_name, exclude_reward_ids)
		if reward3 == null:
			if refresh_id > 0:
				PC.refresh_num += 1
			print("普通抽取池已空")
		elif reward3.reward_name == "noReward":
			if refresh_id > 0:
				PC.refresh_num += 1
			print("专属技能抽取池已空")
		# 如果是主技能进阶且进阶池不为空，但抽到了精进，则隐藏该选项
		elif main_skill_name != "" and not advance_pool_is_empty and reward3.id == "NoAdvance":
			reward3 = null
			if refresh_id > 0:
				PC.refresh_num += 1
			print("进阶池不为空，跳过精进选项")
	
	# 设置刷新按钮和锁定按钮可见性
	var refresh_b1 = lv_up_change_b1.get_node_or_null("BanButton")
	if refresh_b1 == null:
		refresh_b1 = lv_up_change_b1.get_node_or_null("RefreshButton")
	var refresh_b2 = lv_up_change_b2.get_node_or_null("BanButton2")
	if refresh_b2 == null:
		refresh_b2 = lv_up_change_b2.get_node_or_null("RefreshButton2")
	var refresh_b3 = lv_up_change_b3.get_node_or_null("BanButton3")
	if refresh_b3 == null:
		refresh_b3 = lv_up_change_b3.get_node_or_null("RefreshButton3")
	var refresh_all_button = lv_up_change.get_node_or_null("LevelUpChange_Panel#RefreshNum/RefreshButton")
	var lock_b1 = lv_up_change_b1.get_node_or_null("LockButton")
	var lock_b2 = lv_up_change_b2.get_node_or_null("LockButton2")
	var lock_b3 = lv_up_change_b3.get_node_or_null("LockButton3")
	
	if main_skill_name != "":
		# 主技能进阶时隐藏禁用、刷新和锁定按钮
		if refresh_b1: refresh_b1.visible = false
		if refresh_b2: refresh_b2.visible = false
		if refresh_b3: refresh_b3.visible = false
		if refresh_all_button: refresh_all_button.visible = false
		if lock_b1: lock_b1.visible = false
		if lock_b2: lock_b2.visible = false
		if lock_b3: lock_b3.visible = false
	else:
		# 普通升级时显示禁用、刷新和锁定按钮（锁定后不隐藏，以便取消）
		if refresh_b1: refresh_b1.visible = true
		if refresh_b2: refresh_b2.visible = true
		if refresh_b3: refresh_b3.visible = true
		if refresh_all_button: refresh_all_button.visible = true
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
	lv_up_change_b1.disabled = false
	lv_up_change_b2.disabled = false
	lv_up_change_b3.disabled = false
	
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
	
	# 重置按钮颜色。按钮在open阶段保持透明，expand阶段再淡入。
	var show_locked_style := main_skill_name == ""
	var is_locked_1 = show_locked_style and (locked_rewards.has(1) or tentative_locked_rewards.has(1))
	var is_locked_2 = show_locked_style and (locked_rewards.has(2) or tentative_locked_rewards.has(2))
	var is_locked_3 = show_locked_style and (locked_rewards.has(3) or tentative_locked_rewards.has(3))
	if main_skill_name == "":
		var deduped_rewards: Array = _dedupe_same_weapon_upgrade_rewards([reward1, reward2, reward3], [is_locked_1, is_locked_2, is_locked_3], exclude_reward_ids)
		reward1 = deduped_rewards[0]
		reward2 = deduped_rewards[1]
		reward3 = deduped_rewards[2]
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
		elif refresh_id == 0 or refresh_id == 1 or refresh_id == REFRESH_ALL_UNLOCKED_ID:
			lv_up_change_b1.visible = false
		
		if reward2 != null:
			_configure_reward_button(lv_up_change_b2, reward2, rect_ready, rect_off, rect_on, refresh_id, 2)
			_set_reward_button_y(lv_up_change_b2, 285.0)
		elif refresh_id == 0 or refresh_id == 2 or refresh_id == REFRESH_ALL_UNLOCKED_ID:
			lv_up_change_b2.visible = false
		
		if reward3 != null:
			_configure_reward_button(lv_up_change_b3, reward3, rect_ready, rect_off, rect_on, refresh_id, 3)
			_set_reward_button_y(lv_up_change_b3, 486.0)
		elif refresh_id == 0 or refresh_id == 3 or refresh_id == REFRESH_ALL_UNLOCKED_ID:
			lv_up_change_b3.visible = false
	
	# 保存当前奖励数据
	# 普通升级(refresh_id==0)时清空全部；单个刷新时只更新对应位置
	if refresh_id == 0:
		current_rewards.clear()
	if reward1 != null:
		current_rewards[1] = reward1
	elif refresh_id == 1 or refresh_id == REFRESH_ALL_UNLOCKED_ID:
		current_rewards.erase(1)
	if reward2 != null:
		current_rewards[2] = reward2
	elif refresh_id == 2 or refresh_id == REFRESH_ALL_UNLOCKED_ID:
		current_rewards.erase(2)
	if reward3 != null:
		current_rewards[3] = reward3
	elif refresh_id == 3 or refresh_id == REFRESH_ALL_UNLOCKED_ID:
		current_rewards.erase(3)
	print("[Lock] current_rewards 已设置: keys=", current_rewards.keys(), "| reward1=", reward1.reward_name if reward1 else "null", "| reward2=", reward2.reward_name if reward2 else "null", "| reward3=", reward3.reward_name if reward3 else "null")
	
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
	
	_begin_mobile_level_up_input_guard(refresh_id, main_skill_name)
	if canvas_layer and canvas_layer.has_method("_update_ban_button_states"):
		canvas_layer._update_ban_button_states()
	_play_level_up_reward_open_animation(refresh_id, main_skill_name)


func _set_reward_button_y(button: Button, y: float) -> void:
	button.position = Vector2(button.position.x, y)

func _dedupe_same_weapon_upgrade_rewards(rewards: Array, locked_flags: Array, base_exclude_ids: Array[String]) -> Array:
	var used_weapon_keys: Dictionary = {}
	var result: Array = rewards.duplicate()
	for i in range(result.size()):
		var reward = result[i]
		var weapon_key: String = _get_weapon_upgrade_key(reward)
		if weapon_key.is_empty():
			continue
		if not used_weapon_keys.has(weapon_key):
			used_weapon_keys[weapon_key] = true
			continue
		if i < locked_flags.size() and bool(locked_flags[i]):
			continue
		result[i] = _reroll_without_weapon_upgrade_duplicates(used_weapon_keys, base_exclude_ids)
		var new_key: String = _get_weapon_upgrade_key(result[i])
		if not new_key.is_empty():
			used_weapon_keys[new_key] = true
	return result

func _reroll_without_weapon_upgrade_duplicates(used_weapon_keys: Dictionary, base_exclude_ids: Array[String]):
	var exclude_ids: Array[String] = base_exclude_ids.duplicate()
	for attempt in range(24):
		var reward = LvUp.get_reward_level(randf_range(0.0, 100.0), "", exclude_ids)
		if reward == null:
			return null
		if reward.reward_name == "noReward":
			return reward
		var weapon_key: String = _get_weapon_upgrade_key(reward)
		if weapon_key.is_empty() or not used_weapon_keys.has(weapon_key):
			return reward
		exclude_ids.append(reward.id)
	return null

func _get_weapon_upgrade_key(reward) -> String:
	if reward == null:
		return ""
	if not bool(reward.if_main_skill):
		return ""
	var faction: String = str(reward.faction).strip_edges().to_lower()
	if faction.is_empty():
		return ""
	return faction


func _create_level_up_ui_tween(trans_type: Tween.TransitionType, ease_type: Tween.EaseType) -> Tween:
	var tween = create_tween().set_trans(trans_type).set_ease(ease_type)
	tween.set_parallel(true)
	tween.set_ignore_time_scale(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return tween


func _play_level_up_reward_open_animation(refresh_id: int, main_skill_name: String) -> void:
	var use_center_expand := (
		refresh_id == 0
		and main_skill_name == ""
		and lv_up_change_b2.visible
		and (lv_up_change_b1.visible or lv_up_change_b3.visible)
	)
	
	if not use_center_expand:
		if refresh_id != 0:
			lv_up_change.modulate.a = 1.0
		var fade_tween = _create_level_up_ui_tween(Tween.TRANS_SINE, Tween.EASE_OUT)
		var fade_duration: float = 0.5
		if refresh_id == 0:
			fade_duration = LEVEL_UP_REWARD_OPEN_FADE_DURATION
		fade_tween.tween_property(lv_up_change, "modulate:a", 1.0, fade_duration)
		if refresh_id == 0:
			fade_tween.finished.connect(func():
				if not lv_up_change.visible:
					return
				_play_level_up_reward_button_fade_in()
			)
		else:
			if lv_up_change_b1.visible:
				fade_tween.parallel().tween_property(lv_up_change_b1, "modulate:a", 1.0, fade_duration)
			if lv_up_change_b2.visible:
				fade_tween.parallel().tween_property(lv_up_change_b2, "modulate:a", 1.0, fade_duration)
			if lv_up_change_b3.visible:
				fade_tween.parallel().tween_property(lv_up_change_b3, "modulate:a", 1.0, fade_duration)
		return
	
	var center_position := lv_up_change_b2.position
	var button1_target := lv_up_change_b1.position
	var button3_target := lv_up_change_b3.position
	
	lv_up_change.modulate.a = 0.0
	lv_up_change_b2.modulate.a = 0.0
	if lv_up_change_b1.visible:
		lv_up_change_b1.position = center_position
		lv_up_change_b1.modulate.a = 0.0
	if lv_up_change_b3.visible:
		lv_up_change_b3.position = center_position
		lv_up_change_b3.modulate.a = 0.0
	
	var panel_fade_tween = _create_level_up_ui_tween(Tween.TRANS_SINE, Tween.EASE_OUT)
	panel_fade_tween.tween_property(lv_up_change, "modulate:a", 1.0, LEVEL_UP_REWARD_OPEN_FADE_DURATION)
	panel_fade_tween.finished.connect(func():
		if not lv_up_change.visible:
			return
		_play_level_up_reward_expand_animation(button1_target, button3_target)
	)


func _play_level_up_reward_expand_animation(button1_target: Vector2, button3_target: Vector2) -> void:
	var expand_tween = _create_level_up_ui_tween(Tween.TRANS_CUBIC, Tween.EASE_IN)
	if lv_up_change_b2.visible:
		expand_tween.tween_property(lv_up_change_b2, "modulate:a", 1.0, LEVEL_UP_REWARD_EXPAND_DURATION)
	if lv_up_change_b1.visible:
		expand_tween.tween_property(lv_up_change_b1, "position", button1_target, LEVEL_UP_REWARD_EXPAND_DURATION)
		expand_tween.tween_property(lv_up_change_b1, "modulate:a", 1.0, LEVEL_UP_REWARD_EXPAND_DURATION)
	if lv_up_change_b3.visible:
		expand_tween.tween_property(lv_up_change_b3, "position", button3_target, LEVEL_UP_REWARD_EXPAND_DURATION)
		expand_tween.tween_property(lv_up_change_b3, "modulate:a", 1.0, LEVEL_UP_REWARD_EXPAND_DURATION)


func _play_level_up_reward_button_fade_in() -> void:
	var fade_tween = _create_level_up_ui_tween(Tween.TRANS_CUBIC, Tween.EASE_IN)
	if lv_up_change_b1.visible:
		fade_tween.tween_property(lv_up_change_b1, "modulate:a", 1.0, LEVEL_UP_REWARD_EXPAND_DURATION)
	if lv_up_change_b2.visible:
		fade_tween.tween_property(lv_up_change_b2, "modulate:a", 1.0, LEVEL_UP_REWARD_EXPAND_DURATION)
	if lv_up_change_b3.visible:
		fade_tween.tween_property(lv_up_change_b3, "modulate:a", 1.0, LEVEL_UP_REWARD_EXPAND_DURATION)

func _begin_mobile_level_up_input_guard(refresh_id: int, main_skill_name: String) -> void:
	if not Global.is_mobile_input_mode():
		return
	if refresh_id != 0:
		return
	Global.emit_signal("mobile_input_reset_requested")
	_mobile_reward_guard_request_id += 1
	var request_id: int = _mobile_reward_guard_request_id
	var guard_seconds: float = MOBILE_LEVEL_UP_INPUT_GUARD_SECONDS + _get_level_up_open_animation_seconds(main_skill_name)
	_mobile_reward_guard_until_msec = Time.get_ticks_msec() + int(guard_seconds * 1000.0)
	_set_level_up_choice_buttons_disabled(true)
	_finish_mobile_level_up_input_guard_after_delay(request_id, guard_seconds)

func _finish_mobile_level_up_input_guard_after_delay(request_id: int, guard_seconds: float) -> void:
	await get_tree().create_timer(guard_seconds, true, false, true).timeout
	if request_id != _mobile_reward_guard_request_id:
		return
	if PC.is_game_over:
		return
	_mobile_reward_guard_until_msec = 0
	_set_level_up_choice_buttons_disabled(false)

func _get_level_up_open_animation_seconds(_main_skill_name: String) -> float:
	return LEVEL_UP_REWARD_OPEN_FADE_DURATION + LEVEL_UP_REWARD_EXPAND_DURATION

func _is_mobile_level_up_input_guard_active() -> bool:
	return Global.is_mobile_input_mode() and Time.get_ticks_msec() < _mobile_reward_guard_until_msec

func _set_level_up_choice_buttons_disabled(disabled: bool) -> void:
	var buttons: Array[Button] = [lv_up_change_b1, lv_up_change_b2, lv_up_change_b3]
	for button in buttons:
		if button != null and is_instance_valid(button):
			button.disabled = disabled
			_set_child_base_buttons_disabled(button, disabled)
	if canvas_layer and canvas_layer.has_method("set_level_up_exit_button_enabled"):
		canvas_layer.set_level_up_exit_button_enabled(not disabled)
	if not disabled and canvas_layer and canvas_layer.has_method("_update_ban_button_states"):
		canvas_layer._update_ban_button_states()

func _set_child_base_buttons_disabled(node: Node, disabled: bool) -> void:
	for child in node.get_children():
		if child is BaseButton:
			(child as BaseButton).disabled = disabled
		_set_child_base_buttons_disabled(child, disabled)


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
	_update_reward_buff_hint(button, reward.detail)
	var callback: Callable = Callable(LvUp, reward.on_selected)
	var connect_array = button.pressed.get_connections()
	if !connect_array.is_empty():
		for conn in connect_array:
			button.pressed.disconnect(conn.callable)
	# 包装回调，在选择前处理锁定逻辑并记录派系
	var reward_faction = reward.faction
	var wrapped_callback = func():
		if _is_mobile_level_up_input_guard_active():
			return
		_on_reward_button_selected(button_id)
		LvUp._last_applied_reward_faction = reward_faction
		callback.call()
	button.pressed.connect(wrapped_callback)

func _update_reward_buff_hint(button: Button, detail: String) -> void:
	var hint_label: RichTextLabel = _get_or_create_reward_buff_hint(button)
	var hint_text: String = _get_reward_buff_hint_text(detail)
	hint_label.text = hint_text
	hint_label.visible = not hint_text.is_empty()
	if hint_label.visible:
		_resize_reward_buff_hint(hint_label)

func _get_or_create_reward_buff_hint(button: Button) -> RichTextLabel:
	var existing_hint: Node = button.get_node_or_null("BuffHint")
	if existing_hint is RichTextLabel:
		return existing_hint as RichTextLabel
	
	var hint_label := RichTextLabel.new()
	hint_label.name = "BuffHint"
	hint_label.z_index = 21
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.bbcode_enabled = true
	hint_label.scroll_active = false
	hint_label.fit_content = true
	hint_label.offset_left = 760.0
	hint_label.offset_top = 5.0
	hint_label.offset_right = 1075.0
	hint_label.offset_bottom = 29.0
	hint_label.add_theme_font_size_override("normal_font_size", 18)
	hint_label.add_theme_color_override("font_outline_color", Color(0.12, 0.12, 0.12, 0.8))
	hint_label.add_theme_constant_override("outline_size", 4)
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = Color(0.0, 0.0, 0.0, 0.32)
	background_style.content_margin_left = 1.0
	background_style.content_margin_right = 1.0
	background_style.content_margin_top = 1.0
	background_style.content_margin_bottom = 1.0
	hint_label.add_theme_stylebox_override("normal", background_style)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	button.add_child(hint_label)
	return hint_label

func _resize_reward_buff_hint(hint_label: RichTextLabel) -> void:
	var right_edge: float = 1075.0
	var font: Font = hint_label.get_theme_font("normal_font")
	var font_size: int = hint_label.get_theme_font_size("normal_font_size")
	var first_line: String = hint_label.text.split("\n")[0]
	var line_width: float = font.get_string_size(first_line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var line_height: float = font.get_height(font_size)
	
	var target_width: float = line_width + 2.0
	hint_label.offset_right = right_edge
	hint_label.offset_left = right_edge - target_width
	hint_label.offset_bottom = hint_label.offset_top + line_height + 2.0

func _get_reward_buff_hint_text(detail: String) -> String:
	var descriptions: Dictionary = _get_reward_buff_hint_descriptions()
	var seen_names: Dictionary = {}
	var hint_lines: Array[String] = []
	var search_index: int = 0
	
	while search_index < detail.length():
		var start_index: int = detail.find("【", search_index)
		if start_index == -1:
			break
		var end_index: int = detail.find("】", start_index + 1)
		if end_index == -1:
			break
		
		var buff_name: String = detail.substr(start_index + 1, end_index - start_index - 1)
		if REWARD_BUFF_HINT_IGNORED_NAMES.has(buff_name):
			search_index = end_index + 1
			continue
		if descriptions.has(buff_name) and not seen_names.has(buff_name):
			seen_names[buff_name] = true
			hint_lines.append("【%s】：%s" % [buff_name, descriptions[buff_name]])
		
		search_index = end_index + 1
	
	return "；".join(hint_lines)

func _get_reward_buff_hint_descriptions() -> Dictionary:
	var descriptions: Dictionary = REWARD_BUFF_HINT_OVERRIDES.duplicate()
	
	for debuff_id in EnemyDebuffManager.debuff_configs.keys():
		var debuff_config: EnemyDebuffManager.DebuffData = EnemyDebuffManager.debuff_configs[debuff_id]
		var display_name: String = debuff_config.display_name
		var description: String = debuff_config.description
		if not display_name.is_empty() and not description.is_empty() and not descriptions.has(display_name):
			descriptions[display_name] = _format_reward_buff_hint_description(description)
	
	for buff_id in BuffManager.buff_configs.keys():
		var buff_config: BuffManager.BuffData = BuffManager.buff_configs[buff_id]
		var buff_name: String = buff_config.name
		var buff_description: String = buff_config.description
		if not buff_name.is_empty() and not buff_description.is_empty() and not descriptions.has(buff_name):
			descriptions[buff_name] = _format_reward_buff_hint_description(buff_description)
	
	return descriptions

func _format_reward_buff_hint_description(description: String) -> String:
	var formatted_description: String = description.replace("%", " %")
	var digit_regex := RegEx.new()
	var compile_error: Error = digit_regex.compile("(\\d)([^\\d\\s%])")
	if compile_error != OK:
		return formatted_description
	formatted_description = digit_regex.sub(formatted_description, "$1 $2", true)
	return formatted_description.strip_edges()

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
		if _is_mobile_level_up_input_guard_active():
			return
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
		_resolve_poetry_level_up_without_popup(scene_tree, pending_level_ups > 0)
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
	elif PC.main_skill_zhuazhuajuchui != 0 and PC.main_skill_zhuazhuajuchui_advance < int(PC.main_skill_zhuazhuajuchui / 3.0):
		PC.main_skill_zhuazhuajuchui_advance += 1
		handle_level_up("Zhuazhuajuchui", 0, scene_tree, viewport)
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
	if PC.main_skill_zhuazhuajuchui != 0 and PC.main_skill_zhuazhuajuchui_advance < int(PC.main_skill_zhuazhuajuchui / 3.0):
		PC.main_skill_zhuazhuajuchui_advance += 1
		return "Zhuazhuajuchui"
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
		"Zhuazhuajuchui":
			if PC.main_skill_zhuazhuajuchui != 0 and PC.main_skill_zhuazhuajuchui_advance < int(PC.main_skill_zhuazhuajuchui / 3.0):
				PC.main_skill_zhuazhuajuchui_advance += 1
				return "Zhuazhuajuchui"
	return ""

# 玩家点击某个奖励按钮时的处理（在奖励效果应用前调用）
func _on_reward_button_selected(selected_button_id: int) -> void:
	if _is_mobile_level_up_input_guard_active():
		return
	SEManager.play("212")
	if now_main_skill_name != "":
		return
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
	
	if canvas_layer and canvas_layer.has_method("set_level_up_exit_button_visible"):
		canvas_layer.set_level_up_exit_button_visible(false)
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
	lv_up_change_b1.disabled = false
	lv_up_change_b2.disabled = false
	lv_up_change_b3.disabled = false
	_mobile_reward_guard_request_id += 1
	_mobile_reward_guard_until_msec = 0
	if Global.is_mobile_input_mode():
		Global.emit_signal("mobile_input_reset_requested")
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
		_skill_resume_request_id += 1
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
		if Global.is_mobile_input_mode():
			Global.emit_signal("mobile_input_reset_requested")
		if canvas_layer and canvas_layer.has_method("_update_lv_up_start_button_badge"):
			canvas_layer._update_lv_up_start_button_badge()
		if get_tree():
			get_tree().set_pause(false)
			# 恢复人物和怪物的动画
			_resume_all_animations(get_tree())
		# 技能冷却分批恢复，避免暂停解除后一帧内多个冷却同时 timeout。
		_resume_skill_nodes_staggered()
		# 只有普通升级结束时播放0.5秒缓速；如果是advance升级后结束则跳过
		if now_main_skill_name == "":
			_play_slow_motion_focus()

# 刷新按钮处理函数
func handle_refresh_button(refresh_id: int, scene_tree: SceneTree = null, viewport: Viewport = null) -> void:
	if _is_mobile_level_up_input_guard_active():
		return
	if PC.refresh_num > 0:
		PC.refresh_num -= 1
	
	# 只有在当前升级界面确实是主技能进阶时才传递main_skill_name
	# 通过检查当前是否有有效的main_skill_name来判断
	var current_main_skill = now_main_skill_name if now_main_skill_name != "" else ""
	handle_level_up(current_main_skill, refresh_id, scene_tree, viewport)

func handle_refresh_unlocked_buttons(scene_tree: SceneTree = null, viewport: Viewport = null) -> void:
	if _is_mobile_level_up_input_guard_active():
		return
	if now_main_skill_name != "":
		return
	if PC.refresh_num <= 0:
		return
	PC.refresh_num -= 1
	handle_level_up("", REFRESH_ALL_UNLOCKED_ID, scene_tree, viewport)

func handle_refresh_button_without_cost(refresh_id: int, scene_tree: SceneTree = null, viewport: Viewport = null) -> void:
	if _is_mobile_level_up_input_guard_active():
		return
	if now_main_skill_name != "":
		return
	var refresh_num_before := PC.refresh_num
	handle_level_up("", refresh_id, scene_tree, viewport)
	if PC.refresh_num > refresh_num_before:
		PC.refresh_num = refresh_num_before

func skip_current_level_up() -> void:
	if _is_mobile_level_up_input_guard_active():
		return
	if PC.is_game_over:
		_force_cleanup_level_up_ui()
		return
	if now_main_skill_name != "":
		return
	if not lv_up_change or not lv_up_change.visible:
		return
	if canvas_layer and canvas_layer.has_method("set_level_up_exit_button_visible"):
		canvas_layer.set_level_up_exit_button_visible(false)
	if not tentative_locked_rewards.is_empty():
		print("[Lock] 跳过领悟，清空临时锁定数据: ", tentative_locked_rewards.keys())
		tentative_locked_rewards.clear()
	current_rewards.clear()
	lv_up_change_b1.disabled = true
	lv_up_change_b2.disabled = true
	lv_up_change_b3.disabled = true
	LvUp.skip_level_up_action()

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
		value *= 10
	elif level >= 60:
		value *= 5
	elif level >= 50:
		value *= 2.5
	elif level >= 40:
		value *= 1.5
	if level <= 1:
		value *= 0.5
	value += _get_early_level_required_exp_bonus(level)
	# 修习树领悟篇：升级经验需求降低
	var reduction_mult = clampf(1.0 - Global.study_exp_reduction, 0.2, 1.0)
	return value * reduction_mult

func _get_early_level_required_exp_bonus(level: int) -> float:
	var extra_bonus: float = 500.0 if level >= 1 and level <= 5 else 0.0
	match level:
		1, 2:
			return 500.0 + extra_bonus
		3, 4:
			return 1000.0 + extra_bonus
		5, 6:
			return 900.0 + extra_bonus
		_:
			return extra_bonus

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
	lv_up_change_b1.disabled = false
	lv_up_change_b2.disabled = false
	lv_up_change_b3.disabled = false
	if canvas_layer and canvas_layer.has_method("set_level_up_exit_button_visible"):
		canvas_layer.set_level_up_exit_button_visible(false)
	_set_active_skill_icons_interactive(true)
	# 恢复Buff悬停提示
	BuffManager.set_buffs_interactive(true)
	BOSS_HP_BAR_SCRIPT.set_boss_buffs_interactive(true)
	Global.is_level_up = false
	_skill_resume_request_id += 1
	pending_level_ups = 0
	_clear_poetry_advance_pending()
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

func _resolve_poetry_level_up_without_popup(scene_tree: SceneTree = null, apply_level_growth: bool = true) -> void:
	_cleanup_dark_overlay()
	if lv_up_change:
		lv_up_change.visible = false
		lv_up_change.modulate.a = 1.0
	if lv_up_change_b1:
		lv_up_change_b1.disabled = false
	if lv_up_change_b2:
		lv_up_change_b2.disabled = false
	if lv_up_change_b3:
		lv_up_change_b3.disabled = false
	if canvas_layer and canvas_layer.has_method("set_level_up_exit_button_visible"):
		canvas_layer.set_level_up_exit_button_visible(false)
	_set_active_skill_icons_interactive(true)
	BuffManager.set_buffs_interactive(true)
	BOSS_HP_BAR_SCRIPT.set_boss_buffs_interactive(true)
	Global.is_level_up = false
	pending_level_ups = 0
	_skip_next_level_up_delay = false
	current_rewards.clear()
	tentative_locked_rewards.clear()
	now_main_skill_name = ""
	_skill_resume_request_id += 1
	for skill_node in skill_nodes:
		if skill_node and is_instance_valid(skill_node) and skill_node.has_method("set_game_paused"):
			skill_node.set_game_paused(false)
	if scene_tree:
		scene_tree.set_pause(false)
		_resume_all_animations(scene_tree)
	elif get_tree():
		get_tree().set_pause(false)
		_resume_all_animations(get_tree())
	if apply_level_growth:
		LvUp.global_level_up()
		if Faze.manager_instance:
			Faze.manager_instance.check_and_apply_law_bonuses()
		AchievementManager.scan_runtime_progress(false)
	if canvas_layer and canvas_layer.has_method("_refresh_faze_ui"):
		canvas_layer._refresh_faze_ui()
	if canvas_layer and canvas_layer.has_method("_update_lv_up_start_button_badge"):
		canvas_layer._update_lv_up_start_button_badge()
	print("[LvUp] 诗想难度跳过领悟/进阶界面，已结算升级属性")

func _clear_poetry_advance_pending() -> void:
	PC.main_skill_swordQi_advance = int(PC.main_skill_swordQi / 3.0)
	PC.main_skill_branch_advance = int(PC.main_skill_branch / 3.0)
	PC.main_skill_moyan_advance = int(PC.main_skill_moyan / 3.0)
	PC.main_skill_riyan_advance = int(PC.main_skill_riyan / 3.0)
	PC.main_skill_ringFire_advance = int(PC.main_skill_ringFire / 3.0)
	PC.main_skill_thunder_advance = int(PC.main_skill_thunder / 3.0)
	PC.main_skill_bloodwave_advance = int(PC.main_skill_bloodwave / 3.0)
	PC.main_skill_bloodboardsword_advance = int(PC.main_skill_bloodboardsword / 3.0)
	PC.main_skill_ice_advance = int(PC.main_skill_ice / 3.0)
	PC.main_skill_thunder_break_advance = int(PC.main_skill_thunder_break / 3.0)
	PC.main_skill_light_bullet_advance = int(PC.main_skill_light_bullet / 3.0)
	PC.main_skill_qigong_advance = int(PC.main_skill_qigong / 3.0)
	PC.main_skill_water_advance = int(PC.main_skill_water / 3.0)
	PC.main_skill_qiankun_advance = int(PC.main_skill_qiankun / 3.0)
	PC.main_skill_xuanwu_advance = int(PC.main_skill_xuanwu / 3.0)
	PC.main_skill_xunfeng_advance = int(PC.main_skill_xunfeng / 3.0)
	PC.main_skill_genshan_advance = int(PC.main_skill_genshan / 3.0)
	PC.main_skill_duize_advance = int(PC.main_skill_duize / 3.0)
	PC.main_skill_dragonwind_advance = int(PC.main_skill_dragonwind / 3.0)
	PC.main_skill_holylight_advance = int(PC.main_skill_holylight / 3.0)
	PC.main_skill_zhuazhuajuchui_advance = int(PC.main_skill_zhuazhuajuchui / 3.0)

func pause_battle_for_external_popup(scene_tree: SceneTree) -> void:
	_skill_resume_request_id += 1
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
	if scene_tree:
		scene_tree.set_pause(false)
		_resume_all_animations(scene_tree)
	_resume_skill_nodes_staggered()

func _resume_skill_nodes_staggered() -> void:
	_skill_resume_request_id += 1
	var request_id := _skill_resume_request_id
	var scene_tree := get_tree()
	if scene_tree == null:
		_set_skill_nodes_paused(false)
		return
	await scene_tree.process_frame
	var resumed_count := 0
	for skill_node in skill_nodes:
		if request_id != _skill_resume_request_id or PC.is_game_over or Global.is_level_up:
			return
		if skill_node and is_instance_valid(skill_node) and skill_node.has_method("set_game_paused"):
			skill_node.set_game_paused(false)
			resumed_count += 1
			if resumed_count % SKILL_RESUME_BATCH_SIZE == 0:
				await scene_tree.process_frame

func _set_skill_nodes_paused(paused: bool) -> void:
	for skill_node in skill_nodes:
		if skill_node and is_instance_valid(skill_node) and skill_node.has_method("set_game_paused"):
			skill_node.set_game_paused(paused)

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
			_restore_active_icon_children(icon)
		else:
			if not _active_icon_mouse_filters.has(icon):
				_active_icon_mouse_filters[icon] = icon.mouse_filter
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_set_active_icon_children_ignore(icon)
	if interactive:
		_active_icon_mouse_filters.clear()
		_active_icon_child_mouse_filters.clear()

func _set_active_icon_children_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			var control := child as Control
			if not _active_icon_child_mouse_filters.has(control):
				_active_icon_child_mouse_filters[control] = control.mouse_filter
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_active_icon_children_ignore(child)

func _restore_active_icon_children(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			var control := child as Control
			if _active_icon_child_mouse_filters.has(control):
				control.mouse_filter = int(_active_icon_child_mouse_filters[control])
		_restore_active_icon_children(child)

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
	if PC.main_skill_zhuazhuajuchui != 0 and PC.main_skill_zhuazhuajuchui_advance < int(PC.main_skill_zhuazhuajuchui / 3.0):
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
	if PC.main_skill_zhuazhuajuchui != 0 and PC.main_skill_zhuazhuajuchui_advance < int(PC.main_skill_zhuazhuajuchui / 3.0): count += 1
	return count

# 升级完成后0.5秒引擎减速效果，让玩家看清当前位置
func _play_slow_motion_focus() -> void:
	if not Global.time_slow_enabled:
		return
	_slow_motion_focus_request_id += 1
	var request_id := _slow_motion_focus_request_id
	Engine.time_scale = minf(Engine.time_scale, 0.2)
	# 使用不受time_scale影响的SceneTreeTimer，0.5s就是真实时间里的0.5s。
	get_tree().create_timer(0.5, true, false, true).timeout.connect(func():
		if request_id != _slow_motion_focus_request_id or PC.is_game_over or Global.is_level_up:
			return
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
