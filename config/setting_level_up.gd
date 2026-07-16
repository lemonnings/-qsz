extends Node

const ZHUAZHUAJUCHUI_SCRIPT = preload("res://Script/skill/zhuazhuajuchui.gd")
const SOUL_SICKLE_SCRIPT = preload("res://Script/skill/soul_sickle.gd")
const THUNDER_GUN_SCRIPT = preload("res://Script/skill/thunder_gun.gd")

# 全局奖励列表，从CSV加载
var all_rewards_list: Array[Reward] = []
var all_rewards_by_id: Dictionary = {}

# 记录最近一次升级选择的奖励派系（用于Summon权重衰减判断）
var _last_applied_reward_faction: String = ""
var _last_applied_reward: Reward = null

const REWARD_CONTEXT_LEVEL_UP := "level_up"
const REWARD_CONTEXT_QI_VORTEX_SHOP := "qi_vortex_shop"
const LEVEL_UP_BASE_ATK_FLAT_BONUS: int = 5
const LEVEL_UP_BASE_ATK_RATE: float = 0.10
var reward_apply_context: String = REWARD_CONTEXT_LEVEL_UP
var pre_applied_level_growth_count: int = 0
var spirit_attract_gain: float = 0.0
var spirit_regen_rate: float = 0.0
var spirit_attract_timer: Timer
var spirit_regen_timer: Timer
const SPIRIT_REGEN_MAX_RATE: float = 0.06
const SPIRIT_REGEN_MAX_GAIN_PER_TICK: float = 5000.0
const SPIRIT_REGEN_SHALLOW_STOP_TIME: float = 360.0
const SPIRIT_REGEN_DEEP_STOP_TIME: float = 420.0
const SPIRIT_REGEN_CORE_STOP_TIME: float = 480.0
var law_spirit_regen_bonus: float = 0.0

func _add_faze_weapon_upgrade_bonus(law_key: String, amount: float = 0.05) -> void:
	PlayerRewardWeights.record_weapon_upgrade_law_bonus(law_key, amount)

func _get_faze_level(law_key: String) -> int:
	match law_key:
		"treasure":
			return PC.faze_treasure_level
		"destroy":
			return PC.faze_destroy_level
		"summon":
			return PC.faze_summon_level
		"sword":
			return PC.faze_sword_level
		"blood":
			return PC.faze_blood_level
		"thunder":
			return PC.faze_thunder_level
		"fire":
			return PC.faze_fire_level
		"life":
			return PC.faze_life_level
		"sixsense":
			return PC.faze_sixsense_level
		"wind":
			return PC.faze_wind_level
		"shield":
			return PC.faze_shield_level
		"heal":
			return PC.faze_heal_level
		"bullet":
			return PC.faze_bullet_level
		"wide":
			return PC.faze_wide_level
		"deep":
			return PC.faze_deep_level
		"shehun":
			return PC.faze_shehun_level
	return 0

func _is_faze_at_least_5(law_key: String) -> bool:
	return _get_faze_level(law_key) >= 5

# 定义奖励数据结构
class Reward: # Reward 类定义了单个奖励所包含的所有属性。
	var id: String
	var rarity: String # 稀有度，例如: white, green, skyblue, darkorchid, gold, red 等。
	var reward_name: String # 技能/奖励的名称。
	var if_main_skill: bool # 布尔值，标记这是否是一个主要技能。
	var icon: String # 技能图标名称，对应 AssetBundle/Sprites/Sprite sheets/skillIcon/ 下的png文件名（不含扩展名）。
	var detail: String # 技能/奖励的详细描述文本。
	var max_acquisitions: int # 该奖励能被玩家获取的最大次数。
	var faction: String # 奖励所属的派系或类别。
	var chinese_faction: String # 中文派系
	var if_advance: bool # 布尔值，标记这是否是一个进阶技能（通常在特定等级，如每5级出现）。
	var precondition: String # 获取此奖励所需的前置奖励ID，多个ID用逗号分隔。
	var on_selected: String # 当奖励被选中时，需要调用的函数名称字符串。
	var tags: String # 标签，用于分类或筛选奖励。多个标签用逗号分隔。


# 根据图标名称构建完整的资源路径
static func get_icon_path(icon_name: String) -> String:
	if icon_name.is_empty():
		return ""
	return "res://AssetBundle/Sprites/Sprite sheets/skillIcon/" + icon_name + ".png"

const LINGWU_RARITY_PREFIXES: Array[String] = ["SSR", "UR", "SR", "R"]

func get_lingwu_series_key(reward_id: String) -> String:
	var id := reward_id.strip_edges()
	if id.is_empty() or id == "NoAdvance":
		return ""
	var upper_id := id.to_upper()
	for prefix in LINGWU_RARITY_PREFIXES:
		if upper_id.begins_with(prefix):
			var suffix := id.substr(prefix.length())
			if suffix.is_empty():
				return ""
			if not suffix.substr(0, 1).is_valid_int():
				return ""
			return suffix.to_lower()
	return ""

func is_lingwu_series_banned(reward_id: String) -> bool:
	var series_key := get_lingwu_series_key(reward_id)
	return not series_key.is_empty() and PC.banned_lingwu_series.has(series_key)

func _is_reward_banned_for_level_up(reward: Reward, main_skill_name: String) -> bool:
	if main_skill_name != "" or reward == null:
		return false
	if reward.if_main_skill or reward.if_advance:
		return false
	return is_lingwu_series_banned(reward.id)

func _is_lingwu_series_already_selected(reward: Reward, main_skill_name: String) -> bool:
	if main_skill_name != "" or reward == null:
		return false
	if reward.if_main_skill or reward.if_advance:
		return false
	if _reward_has_tag(reward, "emblem"):
		return false
	var series_key := get_lingwu_series_key(reward.id)
	if series_key.is_empty():
		return false
	for selected_id in PC.selected_rewards:
		if get_lingwu_series_key(str(selected_id)) == series_key:
			return true
	return false

func ban_lingwu_series_by_reward_id(reward_id: String) -> bool:
	var series_key := get_lingwu_series_key(reward_id)
	if series_key.is_empty():
		return false
	PC.banned_lingwu_series[series_key] = true
	var removed_count := 0
	for i in range(all_rewards_list.size() - 1, -1, -1):
		var reward: Reward = all_rewards_list[i]
		if get_lingwu_series_key(reward.id) == series_key:
			all_rewards_list.remove_at(i)
			removed_count += 1
	print("[Ban] 禁用领悟系列 ", series_key, "，移除候选数量: ", removed_count)
	return true


@warning_ignore("unused_signal")
signal player_lv_up_over

@warning_ignore("unused_signal")
signal lucky_level_up

@warning_ignore("unused_signal")
signal qi_vortex_shop_reward_selected

func _add_lucky_level(amount: int) -> void:
	if amount <= 0:
		return
	PC.now_lunky_level += amount
	PC._recalculate_reward_rarity_chances()
	Global.emit_signal("lucky_level_up", amount)

func _ready():
	# CSV文件路径，根据实际项目结构可能需要调整。
	_load_rewards_from_csv("res://Config/reward.csv")
	_setup_spirit_reward_timers()

# 从CSV文件加载奖励数据
func _load_rewards_from_csv(file_path: String):
	print("尝试从CSV读取奖励数据: ", file_path)
	all_rewards_list.clear()
	all_rewards_by_id.clear()
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not FileAccess.file_exists(file_path) or file == null:
		printerr("打开CSV奖励文件错误: ", file_path)
		return

	var headers: Array = []
	var is_first_line = true

	while not file.eof_reached():
		var csv_line = file.get_csv_line()
		# 跳过空行或实际上的空行
		if csv_line.is_empty() or (csv_line.size() == 1 and csv_line[0].is_empty()):
			continue

		if is_first_line:
			headers = []
			for h in csv_line:
				headers.append(h.strip_edges())

			is_first_line = false

			# 验证CSV文件的表头是否与预期的格式一致。
			var expected_headers = ["id", "rarity", "reward_name", "if_main_skill", "icon", "detail", "max_acquisitions", "faction", "if_advance", "precondition", "tags", "chinese_faction"]

			if headers.size() != expected_headers.size() or not headers == expected_headers:
				printerr("CSV表头与预期格式不匹配。预期: ", expected_headers, ", 实际: ", headers)
				file.close()
				return
		else:
			if csv_line.size() != headers.size():
				printerr("CSV表头/行大小不匹配于行: ", csv_line, " 文件: ", file_path)
				continue

			var reward_data: Dictionary = {}
			for i in range(headers.size()):
				reward_data[headers[i]] = csv_line[i].strip_edges()

			var new_reward = Reward.new()
			new_reward.id = reward_data.get("id", "")
			new_reward.rarity = reward_data.get("rarity", "white")
			new_reward.reward_name = reward_data.get("reward_name", "Unknown Reward")
			new_reward.if_main_skill = reward_data.get("if_main_skill", "false").to_lower() == "true"
			new_reward.icon = reward_data.get("icon", "")
			new_reward.detail = reward_data.get("detail", "")
			var max_acq_str = reward_data.get("max_acquisitions", "-1")
			new_reward.max_acquisitions = int(max_acq_str) if max_acq_str.is_valid_int() else -1
			new_reward.faction = reward_data.get("faction", "normal")
			new_reward.chinese_faction = reward_data.get("chinese_faction", "")
			new_reward.if_advance = reward_data.get("if_advance", "false").to_lower() == "true"
			new_reward.precondition = reward_data.get("precondition", "")
			# 读取CSV中的标签字段，多个标签以逗号分隔
			new_reward.tags = reward_data.get("tags", "")
			# 纹章系列可在单局内重复获取，CSV中的旧次数值不再限制该分类。
			if _reward_has_tag(new_reward, "emblem"):
				new_reward.max_acquisitions = -1
			new_reward.on_selected = "reward_" + new_reward.id

			all_rewards_list.append(new_reward)
			all_rewards_by_id[new_reward.id.to_lower()] = new_reward
	
	file.close()
	print("成功从 ", file_path, " 加载 ", all_rewards_list.size(), " 个奖励")


func get_reward_level(rand_num: float, main_skill_name: String = '', exclude_reward_ids: Array[String] = []) -> Reward:
	var selected_reward: Reward
	var selected_rarity: String
	if rand_num <= PC.now_red_p:
		selected_rarity = 'red'
		selected_reward = select_reward('red', main_skill_name, exclude_reward_ids)
	elif rand_num <= PC.now_gold_p + PC.now_red_p:
		selected_rarity = 'gold'
		selected_reward = select_reward('gold', main_skill_name, exclude_reward_ids)
	elif rand_num <= PC.now_darkorchid_p + PC.now_gold_p + PC.now_red_p:
		selected_rarity = 'darkorchid'
		selected_reward = select_reward('darkorchid', main_skill_name, exclude_reward_ids)
	else:
		selected_rarity = 'skyblue'
		selected_reward = select_reward('skyblue', main_skill_name, exclude_reward_ids)
	
	print("[Reward] rand_num=", rand_num, " -> 稀有度=", selected_rarity, " 结果=", selected_reward.reward_name if selected_reward else "null", " | exclude=", exclude_reward_ids)

	if selected_reward != null and selected_reward.id != "NoAdvance":
		for i in range(all_rewards_list.size()):
			var reward: Reward = all_rewards_list[i]
			if reward.id == selected_reward.id:
				all_rewards_list.remove_at(i)
				break
	return selected_reward


# 根据稀有度字符串从 all_rewards_list 中筛选奖励
func _get_rewards_by_rarity_str(rarity_str: String, main_skill_name: String) -> Array[Reward]:
	var filtered_rewards: Array[Reward] = []
	
	for reward_item in all_rewards_list:
		if main_skill_name == '':
			# 普通升级：按稀有度筛选，排除进阶技能
			if rarity_str != '' and reward_item.rarity == rarity_str and (reward_item.if_main_skill == false or (reward_item.if_main_skill == true and reward_item.if_advance == false)):
				filtered_rewards.append(reward_item)
		else:
			# 主技能进阶升级（5的倍数）：只抽取if_advance=true且faction匹配的技能，忽略稀有度
			if reward_item.if_advance == true and reward_item.faction == main_skill_name:
				filtered_rewards.append(reward_item)
			# elif reward_item.if_advance == true:
			# 	print("[DEBUG] 跳过进阶技能 %s: faction=%s (期望=%s)" % [reward_item.id, reward_item.faction, main_skill_name])

	return filtered_rewards
	
func _can_acquire_reward(reward: Reward) -> bool:
	return reward.max_acquisitions == -1 or PC.get_reward_acquisition_count(reward.id) < reward.max_acquisitions

func _reward_has_tag(reward: Reward, tag_name: String) -> bool:
	if reward == null or reward.tags == "":
		return false
	var expected_tag := tag_name.strip_edges().to_lower()
	for raw_tag in reward.tags.split(","):
		if str(raw_tag).strip_edges().to_lower() == expected_tag:
			return true
	return false

func _get_emblem_id_for_reward(reward: Reward) -> String:
	if reward == null or not _reward_has_tag(reward, "emblem"):
		return ""
	var numeric_id := str(reward.id).replace("SSR", "").replace("SR", "").replace("UR", "").replace("R", "")
	match numeric_id:
		"01":
			return "xueqi"
		"02":
			return "pozhen"
		"03":
			return "jinghong"
		"04":
			return "tafeng"
		"05":
			return "chenjing"
		"06":
			return "lianti"
		"07":
			return "jianbu"
		"08":
			return "manli"
		"10":
			return "ronghui"
		"12":
			return "jiahu"
		"13":
			return "guiyuan"
		"18":
			return "tiegu"
		_:
			return ""

func _should_skip_reward_for_emblem_limits(reward: Reward) -> bool:
	if not _reward_has_tag(reward, "emblem"):
		return false
	var emblem_id := _get_emblem_id_for_reward(reward)
	if emblem_id.is_empty():
		return false
	var current_stack := int(PC.current_emblems.get(emblem_id, EmblemManager.get_emblem_stack(emblem_id)))
	if current_stack > 0:
		return false
	if EmblemManager.get_emblem_count() >= PC.emblem_slots_max:
		print("纹章栏位已满，跳过新纹章奖励: " + reward.id)
		return true
	return false


func begin_qi_vortex_shop_reward_context() -> void:
	reward_apply_context = REWARD_CONTEXT_QI_VORTEX_SHOP

func clear_reward_context() -> void:
	reward_apply_context = REWARD_CONTEXT_LEVEL_UP

func reset_reward_pool() -> void:
	all_rewards_list = []
	_load_rewards_from_csv("res://Config/reward.csv")

func pre_apply_level_growth_for_pending_level() -> void:
	global_level_up()
	pre_applied_level_growth_count += 1

func _consume_or_apply_level_growth() -> void:
	if pre_applied_level_growth_count > 0:
		pre_applied_level_growth_count -= 1
		return
	global_level_up()

func _level_up_action():
	var context := reward_apply_context
	reward_apply_context = REWARD_CONTEXT_LEVEL_UP
	_apply_selected_weapon_upgrade_law_decay()
	# 升级后Summon派系权重衰减处理
	if _last_applied_reward_faction == "Summon":
		PlayerRewardWeights.on_faction_selected("Summon")
	PlayerRewardWeights.apply_summon_level_up_decay()
	_last_applied_reward_faction = ""
	_last_applied_reward = null
	
	reset_reward_pool()
	if context == REWARD_CONTEXT_LEVEL_UP:
		_consume_or_apply_level_growth()
	
	# 更新技能攻击速度（当攻速属性改变时）
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("update_skill_attack_speeds"):
		player.update_skill_attack_speeds()
		# 发射信号通知技能攻速更新
		Global.emit_signal("skill_attack_speed_updated")
	
	if context == REWARD_CONTEXT_QI_VORTEX_SHOP:
		qi_vortex_shop_reward_selected.emit()
	else:
		get_tree().set_pause(false)
		Global.is_level_up = false
		Global.emit_signal("level_up_selection_complete")
	
	# 更新法则属性加成
	if Faze.manager_instance:
		Faze.manager_instance.check_and_apply_law_bonuses()
	AchievementManager.scan_runtime_progress(false)
	
	# 宝器法则：升级后根据法则阶级和当前等级给予额外刷新次数
	if context == REWARD_CONTEXT_LEVEL_UP:
		var extra_refresh = Faze.get_treasure_extra_refresh_count(PC.faze_treasure_level, PC.pc_lv)
		if extra_refresh > 0:
			PC.refresh_num += extra_refresh
			print("[宝器法则] 本次升级获得额外刷新次数：", extra_refresh)
	
func skip_level_up_action() -> void:
	var context := reward_apply_context
	reward_apply_context = REWARD_CONTEXT_LEVEL_UP
	_last_applied_reward_faction = ""
	_last_applied_reward = null
	PlayerRewardWeights.apply_summon_level_up_decay()
	reset_reward_pool()
	if context == REWARD_CONTEXT_LEVEL_UP:
		_consume_or_apply_level_growth()
	
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("update_skill_attack_speeds"):
		player.update_skill_attack_speeds()
		Global.emit_signal("skill_attack_speed_updated")
	
	if context == REWARD_CONTEXT_QI_VORTEX_SHOP:
		qi_vortex_shop_reward_selected.emit()
	else:
		get_tree().set_pause(false)
		Global.is_level_up = false
		Global.emit_signal("level_up_selection_complete")
	
	if Faze.manager_instance:
		Faze.manager_instance.check_and_apply_law_bonuses()
	AchievementManager.scan_runtime_progress(false)
	
	if context == REWARD_CONTEXT_LEVEL_UP:
		var extra_refresh = Faze.get_treasure_extra_refresh_count(PC.faze_treasure_level, PC.pc_lv)
		if extra_refresh > 0:
			PC.refresh_num += extra_refresh
			print("[宝器法则] 本次升级获得额外刷新次数：", extra_refresh)

func _apply_selected_weapon_upgrade_law_decay() -> void:
	if _last_applied_reward == null:
		return
	if not bool(_last_applied_reward.if_main_skill):
		return
	if bool(_last_applied_reward.if_advance):
		return
	var reward_id := str(_last_applied_reward.id)
	if not _is_weapon_upgrade_reward_id(reward_id):
		return
	PlayerRewardWeights.record_weapon_upgrade_decay(str(_last_applied_reward.faction))

func _is_weapon_upgrade_reward_id(reward_id: String) -> bool:
	var normalized := reward_id.strip_edges()
	var upper := normalized.to_upper()
	for prefix in ["SSR", "UR", "SR", "R"]:
		if upper.begins_with(prefix):
			var suffix := normalized.substr(prefix.length())
			return not suffix.is_empty() and not suffix.substr(0, 1).is_valid_int()
	return false
	
	
func _select_PC_main_skill_lv(main_skill_name: String) -> int:
	if main_skill_name == "SwordQi":
		return PC.main_skill_swordQi
	elif main_skill_name == "Branch":
		return PC.main_skill_branch
	elif main_skill_name == "Moyan":
		return PC.main_skill_moyan
	elif main_skill_name == "Riyan":
		return PC.main_skill_riyan
	elif main_skill_name == "RingFire":
		return PC.main_skill_ringFire
	elif main_skill_name == "Thunder":
		return PC.main_skill_thunder
	elif main_skill_name == "Bloodwave":
		return PC.main_skill_bloodwave
	elif main_skill_name == "BloodBoardSword":
		return PC.main_skill_bloodboardsword
	elif main_skill_name == "Ice":
		return PC.main_skill_ice
	elif main_skill_name == "ThunderBreak":
		return PC.main_skill_thunder_break
	elif main_skill_name == "LightBullet":
		return PC.main_skill_light_bullet
	elif main_skill_name == "Qigong":
		return PC.main_skill_qigong
	elif main_skill_name == "Water":
		return PC.main_skill_water
	elif main_skill_name == "Qiankun":
		return PC.main_skill_qiankun
	elif main_skill_name == "Xuanwu":
		return PC.main_skill_xuanwu
	elif main_skill_name == "Xunfeng":
		return PC.main_skill_xunfeng
	elif main_skill_name == "Genshan":
		return PC.main_skill_genshan
	elif main_skill_name == "Duize":
		return PC.main_skill_duize
	elif main_skill_name == "HolyLight":
		return PC.main_skill_holylight
	elif main_skill_name == "DragonWind":
		return PC.main_skill_dragonwind
	elif main_skill_name == "Zhuazhuajuchui":
		return PC.main_skill_zhuazhuajuchui
	elif main_skill_name == "SoulSickle":
		return PC.main_skill_soul_sickle
	elif main_skill_name == "ThunderGun":
		return PC.main_skill_thunder_gun
	elif main_skill_name == "Yujian":
		return PC.main_skill_yujian
	return 0


# 返回待抽取的派系（使用 get_level_up_weights 计算权重A/B/C的合并结果）
func _select_faction_for_rarity(rarity_name: String) -> String:
	var level_up_weights: Dictionary = PlayerRewardWeights.get_level_up_weights(rarity_name)
	var total_weight: float = 0.0
	var weighted_factions: Array = []

	for faction_key in level_up_weights.keys():
		var weight: float = level_up_weights[faction_key]
		if weight > 0:
			total_weight += weight
			weighted_factions.append({"name": faction_key, "cumulative_weight": total_weight})

	if weighted_factions.is_empty():
		return "Normal" # 如果没有符合条件的派系，则回退到 Normal

	var random_roll: float = randf() * total_weight
	for wf in weighted_factions:
		if random_roll < wf.cumulative_weight:
			return wf.name

	return weighted_factions[-1].name

# 从奖励列表中等概率选择一个奖励。
func _select_reward_uniform(available_rewards: Array[Reward]) -> Reward:
	if available_rewards.is_empty():
		return null
	return available_rewards[randi() % available_rewards.size()]

# 主要的奖励选择函数：基于稀有度（CSV中的名称）、派系选择来获取一个奖励。
func select_reward(csv_rarity_name: String, main_skill_name: String = '', exclude_reward_ids: Array[String] = []) -> Reward:
	var max_rerolls = 100 # 设置最大重抽次数，防止无限循环。
	var is_main_skill_advance = false
	for i in range(max_rerolls):
		var selected_faction = _select_faction_for_rarity(csv_rarity_name) # _select_faction_for_rarity 也需要使用CSV中的稀有度名称。
		if main_skill_name != '':
			selected_faction = main_skill_name
			is_main_skill_advance = true
			csv_rarity_name = ''

		var all_rewards_for_rarity = _get_rewards_by_rarity_str(csv_rarity_name, main_skill_name)
		if main_skill_name != '':
			print("[DEBUG] select_reward 进阶池: main_skill_name=%s, 候选数量=%d" % [main_skill_name, all_rewards_for_rarity.size()])
		var faction_specific_rewards: Array[Reward] = []

		for r in all_rewards_for_rarity:
			if _should_skip_reward_for_emblem_limits(r):
				continue
			# 排除已锁定的奖励
			if r.id in exclude_reward_ids:
				print("奖励 '" + r.id + "' 已被锁定，跳过")
				continue
			if not _can_acquire_reward(r):
				print("奖励 '" + r.id + "' 已达最大获取次数: " + str(PC.get_reward_acquisition_count(r.id)) + "/" + str(r.max_acquisitions) + "，跳过")
				continue
			if _is_reward_banned_for_level_up(r, main_skill_name):
				print("奖励 '" + r.id + "' 所属系列已被禁用，跳过")
				continue
			if _is_lingwu_series_already_selected(r, main_skill_name):
				print("奖励 '" + r.id + "' 所属系列已获得，跳过")
				continue
			if main_skill_name != '':
				# 主技能进阶升级：_get_rewards_by_rarity_str已经筛选了if_advance=true和faction匹配的奖励
				faction_specific_rewards.append(r)
			else:
				# 普通升级：按派系筛选
				if r.faction == selected_faction:
					faction_specific_rewards.append(r)
		
		if csv_rarity_name in ['gold', 'darkorchid', 'red', 'skyblue']:
			print("[Reward] select_reward 稀有度=", csv_rarity_name, " 派系=", selected_faction, " 该派系候选=", faction_specific_rewards.size(), " 总候选=", all_rewards_for_rarity.size(), " exclude=", exclude_reward_ids)
				
		if faction_specific_rewards != null and faction_specific_rewards.size() != 0:
			var chosen_reward = _select_reward_uniform(faction_specific_rewards)
	
			if chosen_reward != null:
				# 检查前置条件
				var prerequisites_met = true
				if not chosen_reward.precondition.is_empty():
					var prereq_func_names = chosen_reward.precondition.split(",") # 假设前置条件函数名以逗号分隔。
					for func_name_str in prereq_func_names:
						var func_name = func_name_str.strip_edges()
						# 检查 LvUp (self) 是否有这个方法
						if self.has_method(func_name):
							var callable_func = Callable(self , func_name)
							var condition_met = callable_func.call()
							if not condition_met:
								prerequisites_met = false
								print("因未满足前置条件函数 '" + func_name + "' 而重抽奖励 '" + chosen_reward.id + "'")
								break
						else:
							print("错误：找不到前置条件函数 '" + func_name + "' 用于奖励 '" + chosen_reward.id + "'")
							prerequisites_met = false # 如果找不到函数，也视为条件不满足
							break
				
				if prerequisites_met:
					# 检查最大获取次数
					if _can_acquire_reward(chosen_reward):
						return chosen_reward # 成功找到符合条件的奖励。
					else:
						print("奖励 '" + chosen_reward.id + "' 已达最大获取次数: " + str(PC.get_reward_acquisition_count(chosen_reward.id)) + "/" + str(chosen_reward.max_acquisitions) + "，进行重抽。")
						# 继续下一次重抽尝试。
						continue
				else:
					# 前置条件未满足，继续下一次重抽尝试。
					continue
			else: # 如果在该派系下没有可选奖励，则重试。
				print("在稀有度 '" + csv_rarity_name + "' 的派系 '" + selected_faction + "' 下未找到奖励。重抽派系。")
				continue
		elif main_skill_name != '':
			# 进阶池为空时，返回NoAdvance默认强化选项
			return _get_no_advance_reward()
	
	print("稀有度 '" + csv_rarity_name + "' 已达到最大重抽次数。将返回null或该稀有度下首个可用的奖励。")
	# 如果达到最大重抽次数或未找到合适奖励时的回退逻辑。
	var all_rewards_for_rarity_fallback = _get_rewards_by_rarity_str(csv_rarity_name, main_skill_name)
	if not all_rewards_for_rarity_fallback.is_empty():
		# 尝试返回一个没有前置条件、或前置条件已满足、且未达到最大获取次数的奖励。
		for fallback_reward in all_rewards_for_rarity_fallback:
			if _should_skip_reward_for_emblem_limits(fallback_reward):
				continue
			if fallback_reward.id in exclude_reward_ids:
				continue
			if _is_reward_banned_for_level_up(fallback_reward, main_skill_name):
				print("奖励 '" + fallback_reward.id + "' 所属系列已被禁用，回退时跳过")
				continue
			if _is_lingwu_series_already_selected(fallback_reward, main_skill_name):
				print("奖励 '" + fallback_reward.id + "' 所属系列已获得，回退时跳过")
				continue
			var fb_prereq_met = true
			if not fallback_reward.precondition.is_empty():
				var prereq_func_names = fallback_reward.precondition.split(",") # 假设前置条件函数名以逗号分隔。
				for func_name_str in prereq_func_names:
					var func_name = func_name_str.strip_edges()
					if self.has_method(func_name):
						var callable_func = Callable(self , func_name)
						var condition_met = callable_func.call()
						if not condition_met:
							fb_prereq_met = false
							break
					else:
						fb_prereq_met = false # 如果找不到函数，也视为条件不满足
						break
			
			if fb_prereq_met and _can_acquire_reward(fallback_reward):
				return fallback_reward
		# 如果在回退逻辑中仍然找不到完全符合条件的奖励 (for current csv_rarity_name)
		print("在稀有度 '" + csv_rarity_name + "' 的回退逻辑中，未能找到完全符合条件的奖励。将尝试其他稀有度。")

	# 尝试从其他稀有度获取奖励
	print("稀有度 '" + csv_rarity_name + "' 无可用奖励后，开始尝试查找其他稀有度的奖励。")
	# 定义实际使用的稀有度名称（与CSV文件中的稀有度名称一致）
	var actual_rarity_levels: Array[String] = ["white", "green", "skyblue", "darkorchid", "gold", "red"]
	for other_rarity_name in actual_rarity_levels:
		if other_rarity_name == csv_rarity_name: # 跳过当前已尝试过的稀有度
			continue

		var rewards_from_other_rarity = _get_rewards_by_rarity_str(other_rarity_name, main_skill_name)
		
		if not rewards_from_other_rarity.is_empty():
			for potential_reward in rewards_from_other_rarity:
				if _should_skip_reward_for_emblem_limits(potential_reward):
					continue
				if potential_reward.id in exclude_reward_ids:
					continue
				if _is_reward_banned_for_level_up(potential_reward, main_skill_name):
					print("奖励 '" + potential_reward.id + "' 所属系列已被禁用，跨稀有度跳过")
					continue
				if _is_lingwu_series_already_selected(potential_reward, main_skill_name):
					print("奖励 '" + potential_reward.id + "' 所属系列已获得，跨稀有度跳过")
					continue
				# 检查前置条件 (使用与主循环相同的逻辑)
				var prereq_ok = true
				if not potential_reward.precondition.is_empty():
					var prereq_func_names = potential_reward.precondition.split(",")
					for func_name_str in prereq_func_names:
						var func_name = func_name_str.strip_edges()
						if self.has_method(func_name):
							var callable_func = Callable(self , func_name)
							if not callable_func.call():
								prereq_ok = false
								break
						else: # 前置条件函数未找到
							prereq_ok = false
							break
				
				if prereq_ok:
					# 检查最大获取次数
					if _can_acquire_reward(potential_reward):
						print("原稀有度 '" + csv_rarity_name + "' 无合适奖励。从备选稀有度 '" + other_rarity_name + "' 选中奖励: " + potential_reward.id)
						return potential_reward # 成功找到符合条件的奖励

	print("所有稀有度（包括 '" + csv_rarity_name + "' 的回退和其他稀有度）均尝试完毕，未找到任何可用奖励。")
	# 如果是主技能进阶但找不到任何奖励，返回NoAdvance默认强化选项
	if is_main_skill_advance:
		return _get_no_advance_reward()
	return null # 如果所有稀有度都尝试过后仍未找到，则返回null

# 获取NoAdvance默认强化奖励（当进阶池为空时使用）
func _get_no_advance_reward() -> Reward:
	for reward in all_rewards_list:
		if reward.id == "NoAdvance":
			return reward
	return null

# 根据ID查找奖励数据（供外部查询，如提示框等）
func get_reward_by_id(reward_id: String) -> Reward:
	var normalized_id := reward_id.to_lower()
	if all_rewards_by_id.has(normalized_id):
		return all_rewards_by_id[normalized_id]
	for reward in all_rewards_list:
		if reward.id.to_lower() == normalized_id:
			return reward
	return null

# 检查当前是否没有其他可进阶的技能（NoAdvance的前置条件）
func check_no_other_advance() -> bool:
	# 遍历所有奖励，检查是否还有可用的进阶技能
	for reward in all_rewards_list:
		if reward.if_advance and reward.id != "NoAdvance":
			return false
	return true

# 检查指定主技能的进阶池是否为空（用于升级界面判断是否需要填充精进）
func is_advance_pool_empty(main_skill_name: String) -> bool:
	#var filtered_rewards: Array[Reward] = []
	for reward_item in all_rewards_list:
		if reward_item.if_advance == true and reward_item.faction == main_skill_name and reward_item.id != "NoAdvance":
			# 检查前置条件和最大获取次数
			var prereq_met = true
			if not reward_item.precondition.is_empty():
				var prereq_func_names = reward_item.precondition.split(",")
				for func_name_str in prereq_func_names:
					var func_name = func_name_str.strip_edges()
					if self.has_method(func_name):
						var callable_func = Callable(self , func_name)
						if not callable_func.call():
							prereq_met = false
							break
					else:
						prereq_met = false
						break
			if prereq_met and (reward_item.max_acquisitions == -1 or PC.get_reward_acquisition_count(reward_item.id) < reward_item.max_acquisitions):
				return false # 找到一个可用的进阶选项，池不为空
	return true # 没有找到任何可用的进阶选项，池为空

func check_SR27() -> bool:
	return PC.selected_rewards.has("ring_bullet")
	
func check_SR30() -> bool:
	return PC.selected_rewards.has("wave_bullet")

func _can_add_weapon() -> bool:
	return PC.current_weapon_num < Global.max_weapon_num

func check_not_have_SR27() -> bool:
	return not PC.selected_rewards.has("ring_bullet")
	
func check_not_have_SR30() -> bool:
	return not PC.selected_rewards.has("wave_bullet")

# 检查伤害范围是否小于等于2.0（通用范围相关技能的前置条件）
func check_attack_range_condition() -> bool:
	return Global.get_attack_range_multiplier() <= 2.0

func check_Branch_condition() -> bool:
	return PC.selected_rewards.has("Branch")
	
func check_Moyan_condition() -> bool:
	return PC.selected_rewards.has("Moyan")

func check_SwordQi_condition() -> bool:
	return PC.selected_rewards.has("SwordQi")
	
func check_SplitSwordQi12() -> bool:
	return PC.selected_rewards.has("SplitSwordQi1") and PC.selected_rewards.has("SplitSwordQi2")
	
func check_SplitSwordQi13() -> bool:
	return PC.selected_rewards.has("SplitSwordQi1") and PC.selected_rewards.has("SplitSwordQi3")
	
func check_SplitSwordQi14() -> bool:
	return PC.selected_rewards.has("SplitSwordQi1") and PC.selected_rewards.has("SplitSwordQi4")

func check_SplitSwordQi23() -> bool:
	return PC.selected_rewards.has("SplitSwordQi2") and PC.selected_rewards.has("SplitSwordQi3")

func check_SplitSwordQi24() -> bool:
	return PC.selected_rewards.has("SplitSwordQi2") and PC.selected_rewards.has("SplitSwordQi4")

func check_SplitSwordQi34() -> bool:
	return PC.selected_rewards.has("SplitSwordQi3") and PC.selected_rewards.has("SplitSwordQi4")


# 检测主武器逻辑
func check_not_have_SwordQi() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("SwordQi")

func check_not_have_Branch() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("Branch")

func check_not_have_Moyan() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("Moyan")

func check_not_have_Riyan() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("Riyan")

func check_not_have_RingFire() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("RingFire")

func check_not_have_Thunder() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("Thunder")

func check_not_have_Bloodwave() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("Bloodwave")

func check_not_have_BloodBoardSword() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("BloodBoardSword")

func check_not_have_Ice() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("Ice")

func check_not_have_ThunderBreak() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("ThunderBreak")

func check_not_have_LightBullet() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("LightBullet")

func check_not_have_Qigong() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("Qigong")

func check_not_have_DragonWind() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("DragonWind")

func check_not_have_Zhuazhuajuchui() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("Zhuazhuajuchui")

func check_not_have_SoulSickle() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("SoulSickle")

func check_not_have_ThunderGun() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("ThunderGun")

func check_not_have_Yujian() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("Yujian")

func check_not_have_Water() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("Water")

func check_not_have_Qiankun() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("Qiankun")

func check_not_have_Xuanwu() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("Xuanwu")

func check_not_have_Xunfeng() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("Xunfeng")

func check_not_have_Genshan() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("Genshan")

func check_not_have_Duize() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("Duize")

func check_not_have_HolyLight() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("HolyLight")


func check_Thunder_condition() -> bool:
	return PC.selected_rewards.has("Thunder")

func check_Bloodwave_condition() -> bool:
	return PC.selected_rewards.has("Bloodwave")

func check_BloodBoardSword_condition() -> bool:
	return PC.selected_rewards.has("BloodBoardSword")

func check_Riyan_condition() -> bool:
	return PC.selected_rewards.has("Riyan")
	
func check_Riyan13() -> bool:
	return PC.selected_rewards.has("Riyan1") and PC.selected_rewards.has("Riyan3")

func check_Riyan14() -> bool:
	return PC.selected_rewards.has("Riyan1") and PC.selected_rewards.has("Riyan4")

func check_Riyan24() -> bool:
	return PC.selected_rewards.has("Riyan2") and PC.selected_rewards.has("Riyan4")

func check_Thunder1() -> bool:
	return PC.selected_rewards.has("Thunder1") and PC.selected_rewards.has("Thunder3")

func check_Thunder2() -> bool:
	return PC.selected_rewards.has("Thunder2") and PC.selected_rewards.has("Thunder4")

func check_Thunder3() -> bool:
	return PC.selected_rewards.has("Thunder1") and PC.selected_rewards.has("Thunder2")

func check_Branch1() -> bool:
	return PC.selected_rewards.has("Branch3") and PC.selected_rewards.has("Branch4")

func check_Branch12() -> bool:
	return PC.selected_rewards.has("Branch1") and PC.selected_rewards.has("Branch2")

func check_Branch3() -> bool:
	return PC.selected_rewards.has("Branch1") and PC.selected_rewards.has("Branch4")

func check_Branch2() -> bool:
	return PC.selected_rewards.has("Branch2") and PC.selected_rewards.has("Branch3")

func check_Bloodwave1() -> bool:
	return PC.selected_rewards.has("Bloodwave3") and PC.selected_rewards.has("Bloodwave4")

func check_Bloodwave2() -> bool:
	return PC.selected_rewards.has("Bloodwave3") and PC.selected_rewards.has("Bloodwave2")

func check_Bloodwave3() -> bool:
	return PC.selected_rewards.has("Bloodwave1") and PC.selected_rewards.has("Bloodwave4")

func check_BloodBoardSword1() -> bool:
	return PC.selected_rewards.has("BloodBoardSword1") and PC.selected_rewards.has("BloodBoardSword2")

func check_BloodBoardSword2() -> bool:
	return PC.selected_rewards.has("BloodBoardSword1") and PC.selected_rewards.has("BloodBoardSword4")

func check_BloodBoardSword3() -> bool:
	return PC.selected_rewards.has("BloodBoardSword2") and PC.selected_rewards.has("BloodBoardSword3")


func check_Ice_condition() -> bool:
	return PC.selected_rewards.has("Ice")

func check_Ice_condition1() -> bool:
	return PC.selected_rewards.has("Ice1") and PC.selected_rewards.has("Ice3")

func check_Ice_condition2() -> bool:
	return PC.selected_rewards.has("Ice2") and PC.selected_rewards.has("Ice3")

func check_Ice_condition3() -> bool:
	return PC.selected_rewards.has("Ice4") and PC.selected_rewards.has("Ice2")

func check_Ice_condition4() -> bool:
	return PC.selected_rewards.has("Ice5") and PC.selected_rewards.has("Ice1")

func check_Ice_condition5() -> bool:
	return PC.selected_rewards.has("Ice5") and PC.selected_rewards.has("Ice4")

func check_ThunderBreak_condition() -> bool:
	return PC.selected_rewards.has("ThunderBreak")

func check_ThunderBreak1() -> bool:
	return PC.selected_rewards.has("ThunderBreak1") and PC.selected_rewards.has("ThunderBreak2")

func check_ThunderBreak2() -> bool:
	return PC.selected_rewards.has("ThunderBreak2") and PC.selected_rewards.has("ThunderBreak4")

func check_ThunderBreak3() -> bool:
	return PC.selected_rewards.has("ThunderBreak1") and PC.selected_rewards.has("ThunderBreak3")

func check_speed_extreme() -> bool:
	return PC.attack_speed_bonus >= 0.8 and PC.move_speed_bonus >= 0.8

func check_mengyu_mastery() -> bool:
	var mengyu_count = 0
	for reward_id in PC.selected_rewards:
		if reward_id in ["R09", "SR09", "SSR09", "UR09"]:
			mengyu_count += 1
	return mengyu_count >= 5

func check_level_40() -> bool:
	return PC.pc_lv >= 40

func check_chaos_level_5() -> bool:
	return Faze.get_current_chaos_level() >= 5


func reward_RQigong():
	PC.main_skill_qigong += 1
	PC.attack_speed_bonus += 0.04
	PC.main_skill_qigong_damage += 0.04
	Qigong.sync_reward_modifiers()
	_level_up_action()

func reward_SRQigong():
	PC.main_skill_qigong += 1
	PC.attack_speed_bonus += 0.045
	PC.main_skill_qigong_damage += 0.05
	Qigong.sync_reward_modifiers()
	_level_up_action()

func reward_SSRQigong():
	PC.main_skill_qigong += 1
	PC.attack_speed_bonus += 0.05
	PC.main_skill_qigong_damage += 0.06
	Qigong.sync_reward_modifiers()
	_level_up_action()

func reward_URQigong():
	PC.main_skill_qigong += 1
	PC.attack_speed_bonus += 0.06
	PC.main_skill_qigong_damage += 0.08
	Qigong.sync_reward_modifiers()
	_level_up_action()


func reward_Qigong1():
	PC.faze_wind_level += 2
	PC.faze_wide_level += 2
	PC.selected_rewards.append("Qigong1")
	Qigong.sync_reward_modifiers()
	_level_up_action()

func reward_Qigong2():
	PC.faze_wind_level += 2
	PC.faze_wide_level += 2
	PC.selected_rewards.append("Qigong2")
	Qigong.sync_reward_modifiers()
	_level_up_action()

func reward_Qigong3():
	PC.faze_wind_level += 2
	PC.faze_wide_level += 2
	PC.selected_rewards.append("Qigong3")
	Qigong.sync_reward_modifiers()
	_level_up_action()

func reward_Qigong4():
	PC.faze_wind_level += 2
	PC.faze_wide_level += 2
	PC.selected_rewards.append("Qigong4")
	Qigong.sync_reward_modifiers()
	_level_up_action()

func reward_Qigong5():
	PC.faze_wind_level += 2
	PC.faze_wide_level += 2
	PC.selected_rewards.append("Qigong5")
	Qigong.sync_reward_modifiers()
	_level_up_action()

func reward_Qigong11():
	PC.faze_wind_level += 2
	PC.faze_wide_level += 2
	PC.selected_rewards.append("Qigong11")
	Qigong.sync_reward_modifiers()
	_level_up_action()

func reward_Qigong22():
	PC.faze_wind_level += 2
	PC.faze_wide_level += 2
	PC.selected_rewards.append("Qigong22")
	Qigong.sync_reward_modifiers()
	_level_up_action()

func reward_Qigong33():
	PC.faze_wind_level += 2
	PC.faze_wide_level += 2
	PC.selected_rewards.append("Qigong33")
	Qigong.sync_reward_modifiers()
	_level_up_action()

func reward_Qigong44():
	PC.faze_wind_level += 2
	PC.faze_wide_level += 2
	PC.selected_rewards.append("Qigong44")
	Qigong.sync_reward_modifiers()
	_level_up_action()

func reward_Qigong55():
	PC.faze_wind_level += 2
	PC.faze_wide_level += 2
	PC.selected_rewards.append("Qigong55")
	Qigong.sync_reward_modifiers()
	_level_up_action()

func check_Qigong_condition() -> bool:
	return PC.selected_rewards.has("Qigong")

func check_Qigong1() -> bool:
	return PC.selected_rewards.has("Qigong1")

func check_Qigong2() -> bool:
	return PC.selected_rewards.has("Qigong2")

func check_Qigong3() -> bool:
	return PC.selected_rewards.has("Qigong3")

func check_Qigong4() -> bool:
	return PC.selected_rewards.has("Qigong4")

func check_LightBullet_condition() -> bool:
	return PC.selected_rewards.has("LightBullet")

func check_LightBullet_condition1() -> bool:
	return PC.selected_rewards.has("LightBullet5") and PC.selected_rewards.has("LightBullet2")

func check_LightBullet_condition2() -> bool:
	return PC.selected_rewards.has("LightBullet4") and PC.selected_rewards.has("LightBullet1")

func check_LightBullet_condition3() -> bool:
	return PC.selected_rewards.has("LightBullet2") and PC.selected_rewards.has("LightBullet3")

func check_LightBullet_condition4() -> bool:
	return PC.selected_rewards.has("LightBullet1") and PC.selected_rewards.has("LightBullet4")


func check_Water_condition() -> bool:
	return PC.selected_rewards.has("Water")

func check_Water_condition1() -> bool:
	return PC.selected_rewards.has("Water1") and PC.selected_rewards.has("Water2")

func check_Water_condition2() -> bool:
	return PC.selected_rewards.has("Water3") and PC.selected_rewards.has("Water4")

func check_Water_condition3() -> bool:
	return PC.selected_rewards.has("Water1") and PC.selected_rewards.has("Water4")


func check_RingFire_condition() -> bool:
	return PC.selected_rewards.has("RingFire")

func check_RingFire_condition12() -> bool:
	return PC.selected_rewards.has("RingFire1") and PC.selected_rewards.has("RingFire2")

func check_RingFire_condition14() -> bool:
	return PC.selected_rewards.has("RingFire1") and PC.selected_rewards.has("RingFire4")

func check_RingFire_condition34() -> bool:
	return PC.selected_rewards.has("RingFire3") and PC.selected_rewards.has("RingFire4")


func check_Qiankun_condition() -> bool:
	return PC.selected_rewards.has("Qiankun")

func check_Qiankun_condition1() -> bool:
	return PC.selected_rewards.has("Qiankun1") and PC.selected_rewards.has("Qiankun3")

func check_Qiankun_condition2() -> bool:
	return PC.selected_rewards.has("Qiankun2") and PC.selected_rewards.has("Qiankun3")

func check_Qiankun_condition3() -> bool:
	return PC.selected_rewards.has("Qiankun2") and PC.selected_rewards.has("Qiankun4")

func check_Branch_condition1() -> bool:
	return PC.selected_rewards.has("Branch1")

func check_Branch_condition2() -> bool:
	return PC.selected_rewards.has("Branch2")

func check_Branch_condition3() -> bool:
	return PC.selected_rewards.has("Branch3")

func check_Branch_condition12() -> bool:
	return PC.selected_rewards.has("Branch1") and PC.selected_rewards.has("Branch2")

func check_Summon_condition() -> bool:
	return PC.summon_count < PC.summon_count_max

func check_Summon_condition_special() -> bool:
	return PC.summon_count < PC.summon_count_max

func check_have_Summon_condition() -> bool:
	return PC.summon_count > 0 or PC.selected_rewards.has("Yujian")

func check_Moyan12() -> bool:
	return PC.selected_rewards.has("Moyan1") and PC.selected_rewards.has("Moyan2")

func check_Moyan13() -> bool:
	return PC.selected_rewards.has("Moyan1") and PC.selected_rewards.has("Moyan3")

func check_Moyan23() -> bool:
	return PC.selected_rewards.has("Moyan3") and PC.selected_rewards.has("Moyan2")

func check_Moyan34() -> bool:
	return PC.selected_rewards.has("Moyan3") and PC.selected_rewards.has("Moyan4")


# --- 以下为具体的奖励效果实现函数 --- 

func reward_R01():
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.05)
	EmblemManager.add_emblem("xueqi", 1)
	_level_up_action()

func reward_SR01():
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.10)
	EmblemManager.add_emblem("xueqi", 1)
	_level_up_action()

func reward_SSR01():
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.18)
	EmblemManager.add_emblem("xueqi", 1)
	_level_up_action()

func reward_UR01():
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.20)
	EmblemManager.add_emblem("xueqi", 2)
	_level_up_action()

func reward_R02():
	PC.add_attack_percent_bonus(0.03)
	PC.attack_speed_bonus += 0.01
	EmblemManager.add_emblem("pozhen", 1)
	_level_up_action()

func reward_SR02():
	PC.add_attack_percent_bonus(0.04)
	PC.attack_speed_bonus += 0.02
	EmblemManager.add_emblem("pozhen", 1)
	_level_up_action()

func reward_SSR02():
	PC.add_attack_percent_bonus(0.05)
	PC.attack_speed_bonus += 0.03
	EmblemManager.add_emblem("pozhen", 1)
	_level_up_action()

func reward_UR02():
	PC.add_attack_percent_bonus(0.06)
	PC.attack_speed_bonus += 0.03
	EmblemManager.add_emblem("pozhen", 2)
	_level_up_action()

func reward_R03():
	PC.attack_speed_bonus += 0.04
	EmblemManager.add_emblem("jinghong", 1)
	_level_up_action()

func reward_SR03():
	PC.attack_speed_bonus += 0.07
	EmblemManager.add_emblem("jinghong", 1)
	_level_up_action()

func reward_SSR03():
	PC.attack_speed_bonus += 0.11
	EmblemManager.add_emblem("jinghong", 1)
	_level_up_action()

func reward_UR03():
	PC.attack_speed_bonus += 0.13
	EmblemManager.add_emblem("jinghong", 2)
	_level_up_action()

func reward_R04():
	PC.move_speed_bonus += 0.07
	PC.crit_chance += 0.01
	EmblemManager.add_emblem("tafeng", 1)
	_level_up_action()

func reward_SR04():
	PC.move_speed_bonus += 0.10
	PC.crit_chance += 0.015
	EmblemManager.add_emblem("tafeng", 1)
	_level_up_action()

func reward_SSR04():
	PC.move_speed_bonus += 0.14
	PC.crit_chance += 0.02
	EmblemManager.add_emblem("tafeng", 1)
	_level_up_action()

func reward_UR04():
	PC.move_speed_bonus += 0.18
	PC.crit_chance += 0.03
	EmblemManager.add_emblem("tafeng", 2)
	_level_up_action()

func reward_R05():
	PC.attack_speed_bonus += 0.06
	PC.move_speed_bonus -= 0.03
	EmblemManager.add_emblem("chenjing", 1)
	_level_up_action()

func reward_SR05():
	PC.attack_speed_bonus += 0.08
	PC.move_speed_bonus -= 0.035
	EmblemManager.add_emblem("chenjing", 1)
	_level_up_action()

func reward_SSR05():
	PC.attack_speed_bonus += 0.11
	PC.move_speed_bonus -= 0.04
	EmblemManager.add_emblem("chenjing", 1)
	_level_up_action()

func reward_UR05():
	PC.attack_speed_bonus += 0.16
	PC.move_speed_bonus -= 0.05
	EmblemManager.add_emblem("chenjing", 2)
	_level_up_action()
	
func reward_R06():
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.05)
	PC.damage_reduction_rate = min(PC.damage_reduction_rate + 0.01, 0.7)
	EmblemManager.add_emblem("lianti", 1)
	_level_up_action()

func reward_SR06():
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.07)
	PC.damage_reduction_rate = min(PC.damage_reduction_rate + 0.015, 0.7)
	EmblemManager.add_emblem("lianti", 1)
	_level_up_action()

func reward_SSR06():
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.10)
	PC.damage_reduction_rate = min(PC.damage_reduction_rate + 0.02, 0.7)
	EmblemManager.add_emblem("lianti", 1)
	_level_up_action()

func reward_UR06():
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.15)
	PC.damage_reduction_rate = min(PC.damage_reduction_rate + 0.03, 0.7)
	EmblemManager.add_emblem("lianti", 2)
	_level_up_action()

func reward_R07():
	PC.move_speed_bonus += 0.12
	EmblemManager.add_emblem("jianbu", 1)
	_level_up_action()

func reward_SR07():
	PC.move_speed_bonus += 0.15
	EmblemManager.add_emblem("jianbu", 1)
	_level_up_action()

func reward_SSR07():
	PC.move_speed_bonus += 0.19
	EmblemManager.add_emblem("jianbu", 1)
	_level_up_action()

func reward_UR07():
	PC.move_speed_bonus += 0.25
	EmblemManager.add_emblem("jianbu", 2)
	_level_up_action()

func reward_R08():
	PC.add_attack_percent_bonus(0.06)
	PC.move_speed_bonus -= 0.06
	EmblemManager.add_emblem("manli", 1)
	_level_up_action()

func reward_SR08():
	PC.add_attack_percent_bonus(0.07)
	PC.move_speed_bonus -= 0.07
	EmblemManager.add_emblem("manli", 1)
	_level_up_action()

func reward_SSR08():
	PC.add_attack_percent_bonus(0.08)
	PC.move_speed_bonus -= 0.08
	EmblemManager.add_emblem("manli", 1)
	_level_up_action()

func reward_UR08():
	PC.add_attack_percent_bonus(0.10)
	PC.move_speed_bonus -= 0.1
	EmblemManager.add_emblem("manli", 2)
	_level_up_action()

func reward_R09():
	_add_lucky_level(3)
	PC.faze_treasure_level += 1
	_add_faze_weapon_upgrade_bonus("treasure")
	_level_up_action()

func reward_SR09():
	_add_lucky_level(4)
	PC.faze_treasure_level += 1
	_add_faze_weapon_upgrade_bonus("treasure")
	_level_up_action()

func reward_SSR09():
	_add_lucky_level(6)
	PC.faze_treasure_level += 1
	_add_faze_weapon_upgrade_bonus("treasure")
	_level_up_action()

func reward_UR09():
	_add_lucky_level(10)
	PC.faze_treasure_level += 1
	_add_faze_weapon_upgrade_bonus("treasure")
	_level_up_action()

func reward_R10():
	PC.add_attack_percent_bonus(-0.04)
	EmblemManager.add_emblem("ronghui", 1)
	_level_up_action()

func reward_SR10():
	PC.add_attack_percent_bonus(-0.05)
	EmblemManager.add_emblem("ronghui", 1)
	_level_up_action()

func reward_SSR10():
	PC.add_attack_percent_bonus(-0.06)
	EmblemManager.add_emblem("ronghui", 1)
	_level_up_action()

func reward_UR10():
	PC.add_attack_percent_bonus(-0.06)
	EmblemManager.add_emblem("ronghui", 2)
	_level_up_action()


func reward_R12():
	_add_lucky_level(2)
	EmblemManager.add_emblem("jiahu", 1)
	_level_up_action()

func reward_SR12():
	_add_lucky_level(3)
	EmblemManager.add_emblem("jiahu", 1)
	_level_up_action()

func reward_SSR12():
	_add_lucky_level(4)
	EmblemManager.add_emblem("jiahu", 1)
	_level_up_action()

func reward_UR12():
	_add_lucky_level(6)
	EmblemManager.add_emblem("jiahu", 2)
	_level_up_action()

func reward_R13():
	PC.attack_speed_bonus += 0.06
	EmblemManager.add_emblem("guiyuan", 1)
	_level_up_action()

func reward_SR13():
	PC.attack_speed_bonus += 0.07
	EmblemManager.add_emblem("guiyuan", 1)
	_level_up_action()

func reward_SSR13():
	PC.attack_speed_bonus += 0.08
	EmblemManager.add_emblem("guiyuan", 1)
	_level_up_action()

func reward_UR13():
	PC.attack_speed_bonus += 0.08
	EmblemManager.add_emblem("guiyuan", 2)
	_level_up_action()

func reward_R14():
	PC.crit_chance += 0.04
	PC.attack_speed_bonus += 0.04
	PC.add_attack_percent_bonus(-0.02)
	_level_up_action()

func reward_SR14():
	PC.crit_chance += 0.05
	PC.attack_speed_bonus += 0.06
	PC.add_attack_percent_bonus(-0.02)
	_level_up_action()

func reward_SSR14():
	PC.crit_chance += 0.07
	PC.attack_speed_bonus += 0.08
	PC.add_attack_percent_bonus(-0.03)
	_level_up_action()

func reward_R15():
	PC.crit_damage_multi += 0.08
	PC.attack_speed_bonus += 0.04
	PC.faze_destroy_level += 1
	_add_faze_weapon_upgrade_bonus("destroy")
	_level_up_action()

func reward_SR15():
	PC.crit_damage_multi += 0.10
	PC.attack_speed_bonus += 0.05
	PC.faze_destroy_level += 1
	_add_faze_weapon_upgrade_bonus("destroy")
	_level_up_action()

func reward_SSR15():
	PC.crit_damage_multi += 0.12
	PC.attack_speed_bonus += 0.06
	PC.faze_destroy_level += 1
	_add_faze_weapon_upgrade_bonus("destroy")
	_level_up_action()

func reward_R16():
	PC.crit_chance += 0.05
	PC.crit_damage_multi += 0.08
	_level_up_action()

func reward_SR16():
	PC.crit_chance += 0.065
	PC.crit_damage_multi += 0.11
	_level_up_action()

func reward_SSR16():
	PC.crit_chance += 0.08
	PC.crit_damage_multi += 0.14
	_level_up_action()

func reward_R18():
	PC.damage_reduction_rate += 0.02
	EmblemManager.add_emblem("tiegu", 1)
	_level_up_action()

func reward_SR18():
	PC.damage_reduction_rate += 0.03
	EmblemManager.add_emblem("tiegu", 1)
	_level_up_action()

func reward_SSR18():
	PC.damage_reduction_rate += 0.04
	EmblemManager.add_emblem("tiegu", 1)
	_level_up_action()

func reward_UR18():
	PC.damage_reduction_rate += 0.04
	EmblemManager.add_emblem("tiegu", 2)
	_level_up_action()

func reward_R19():
	PC.pc_max_hp = int(PC.pc_max_hp * 1.10)
	PC.damage_reduction_rate += 0.005
	var extra_hp_bonus = min(0.10, PC.damage_reduction_rate * 0.004)
	PC.pc_max_hp = int(PC.pc_max_hp * (1 + extra_hp_bonus))
	_level_up_action()

func reward_SR19():
	PC.pc_max_hp = int(PC.pc_max_hp * 1.11)
	PC.damage_reduction_rate += 0.01
	var extra_hp_bonus = min(0.10, PC.damage_reduction_rate * 0.004)
	PC.pc_max_hp = int(PC.pc_max_hp * (1 + extra_hp_bonus))
	_level_up_action()

func reward_SSR19():
	PC.pc_max_hp = int(PC.pc_max_hp * 1.12)
	PC.damage_reduction_rate += 0.015
	var extra_hp_bonus = min(0.10, PC.damage_reduction_rate * 0.004)
	PC.pc_max_hp = int(PC.pc_max_hp * (1 + extra_hp_bonus))
	_level_up_action()

func reward_Ice():
	IceFlower.reset_data()
	PC.selected_rewards.append("Ice")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_destroy_level += 3
	PC.faze_bullet_level += 3
	# 初始化冷却时间
	var player = get_tree().get_first_node_in_group("player")
	if player and player.ice_flower_fire_speed:
		player.ice_flower_fire_speed.start()
	_level_up_action()

func reward_RIce():
	PC.main_skill_ice += 1
	PC.crit_chance += 0.01
	IceFlower.main_skill_ice_damage += 0.04
	_level_up_action()

func reward_SRIce():
	PC.main_skill_ice += 1
	PC.crit_chance += 0.011
	IceFlower.main_skill_ice_damage += 0.05
	_level_up_action()

func reward_SSRIce():
	PC.main_skill_ice += 1
	PC.crit_chance += 0.013
	IceFlower.main_skill_ice_damage += 0.06
	_level_up_action()

func reward_URIce():
	PC.main_skill_ice += 1
	PC.crit_chance += 0.03
	IceFlower.main_skill_ice_damage += 0.08
	_level_up_action()

func reward_Ice1():
	PC.faze_destroy_level += 2
	PC.faze_bullet_level += 2
	PC.selected_rewards.append("Ice1")
	_level_up_action()

func reward_Ice2():
	PC.faze_destroy_level += 2
	PC.faze_bullet_level += 2
	PC.selected_rewards.append("Ice2")
	_level_up_action()

func reward_Ice3():
	PC.faze_destroy_level += 2
	PC.faze_bullet_level += 2
	PC.selected_rewards.append("Ice3")
	_level_up_action()

func reward_Ice4():
	PC.faze_destroy_level += 2
	PC.faze_bullet_level += 2
	PC.selected_rewards.append("Ice4")
	_level_up_action()

func reward_Ice5():
	PC.faze_destroy_level += 2
	PC.faze_bullet_level += 2
	PC.selected_rewards.append("Ice5")
	_level_up_action()

func reward_Ice11():
	PC.faze_destroy_level += 2
	PC.faze_bullet_level += 2
	PC.selected_rewards.append("Ice11")
	_level_up_action()

func reward_Ice22():
	PC.faze_destroy_level += 2
	PC.faze_bullet_level += 2
	PC.selected_rewards.append("Ice22")
	_level_up_action()

func reward_Ice33():
	PC.faze_destroy_level += 2
	PC.faze_bullet_level += 2
	PC.selected_rewards.append("Ice33")
	_level_up_action()

func reward_Ice44():
	PC.faze_destroy_level += 2
	PC.faze_bullet_level += 2
	PC.selected_rewards.append("Ice44")
	_level_up_action()

func reward_Ice55():
	PC.faze_destroy_level += 2
	PC.faze_bullet_level += 2
	PC.selected_rewards.append("Ice55")
	_level_up_action()

# --- 天雷破相关奖励函数 ---
func reward_ThunderBreak():
	PC.selected_rewards.append("ThunderBreak")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_thunder_level += 3
	PC.faze_destroy_level += 3
	_level_up_action()

func reward_RThunderBreak():
	PC.main_skill_thunder_break += 1
	PC.crit_damage_multi += 0.04
	PC.thunder_break_final_damage_multi += 0.06
	_level_up_action()
	
func reward_SRThunderBreak():
	PC.main_skill_thunder_break += 1
	PC.crit_damage_multi += 0.045
	PC.thunder_break_final_damage_multi += 0.07
	_level_up_action()

func reward_SSRThunderBreak():
	PC.main_skill_thunder_break += 1
	PC.crit_damage_multi += 0.05
	PC.thunder_break_final_damage_multi += 0.08
	_level_up_action()

func reward_URThunderBreak():
	PC.main_skill_thunder_break += 1
	PC.crit_damage_multi += 0.06
	PC.thunder_break_final_damage_multi += 0.1
	_level_up_action()

func reward_ThunderBreak1():
	PC.faze_thunder_level += 2
	PC.faze_destroy_level += 2
	PC.selected_rewards.append("ThunderBreak1")
	_level_up_action()

func reward_ThunderBreak2():
	PC.faze_thunder_level += 2
	PC.faze_destroy_level += 2
	PC.selected_rewards.append("ThunderBreak2")
	_level_up_action()

func reward_ThunderBreak3():
	PC.faze_thunder_level += 2
	PC.faze_destroy_level += 2
	PC.selected_rewards.append("ThunderBreak3")
	_level_up_action()

func reward_ThunderBreak4():
	PC.faze_thunder_level += 2
	PC.faze_destroy_level += 2
	PC.selected_rewards.append("ThunderBreak4")
	_level_up_action()

func reward_ThunderBreak11():
	PC.faze_thunder_level += 2
	PC.faze_destroy_level += 2
	PC.selected_rewards.append("ThunderBreak11")
	_level_up_action()

func reward_ThunderBreak22():
	PC.faze_thunder_level += 2
	PC.faze_destroy_level += 2
	PC.selected_rewards.append("ThunderBreak22")
	_level_up_action()

func reward_ThunderBreak33():
	PC.faze_thunder_level += 2
	PC.faze_destroy_level += 2
	PC.selected_rewards.append("ThunderBreak33")
	_level_up_action()


# --- 光弹术相关奖励函数 ---
func reward_LightBullet():
	PC.selected_rewards.append("LightBullet")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_bullet_level += 3
	PC.faze_life_level += 3
	_level_up_action()

func reward_RLightBullet():
	PC.main_skill_light_bullet += 1
	PC.attack_speed_bonus += 0.04
	PC.light_bullet_final_damage_multi += 0.04
	_level_up_action()

func reward_SRLightBullet():
	PC.main_skill_light_bullet += 1
	PC.attack_speed_bonus += 0.045
	PC.light_bullet_final_damage_multi += 0.05
	_level_up_action()

func reward_SSRLightBullet():
	PC.main_skill_light_bullet += 1
	PC.attack_speed_bonus += 0.05
	PC.light_bullet_final_damage_multi += 0.06
	_level_up_action()

func reward_URLightBullet():
	PC.main_skill_light_bullet += 1
	PC.attack_speed_bonus += 0.06
	PC.light_bullet_final_damage_multi += 0.08
	_level_up_action()

func reward_LightBullet1():
	PC.selected_rewards.append("LightBullet1")
	PC.faze_bullet_level += 2
	PC.faze_life_level += 2
	_level_up_action()

func reward_LightBullet2():
	PC.selected_rewards.append("LightBullet2")
	PC.faze_bullet_level += 2
	PC.faze_life_level += 2
	_level_up_action()

func reward_LightBullet3():
	PC.selected_rewards.append("LightBullet3")
	PC.faze_bullet_level += 2
	PC.faze_life_level += 2
	PC.main_skill_light_bullet_damage += 0.1
	_level_up_action()

func reward_LightBullet4():
	PC.selected_rewards.append("LightBullet4")
	PC.faze_bullet_level += 2
	PC.faze_life_level += 2
	_level_up_action()

func reward_LightBullet5():
	PC.selected_rewards.append("LightBullet5")
	PC.faze_bullet_level += 2
	PC.faze_life_level += 2
	_level_up_action()

func reward_LightBullet11():
	PC.selected_rewards.append("LightBullet11")
	PC.faze_bullet_level += 2
	PC.faze_life_level += 2
	_level_up_action()

func reward_LightBullet22():
	PC.selected_rewards.append("LightBullet22")
	PC.faze_bullet_level += 2
	PC.faze_life_level += 2
	_level_up_action()

func reward_LightBullet33():
	PC.selected_rewards.append("LightBullet33")
	PC.faze_bullet_level += 2
	PC.faze_life_level += 2
	_level_up_action()

func reward_LightBullet44():
	PC.selected_rewards.append("LightBullet44")
	PC.faze_bullet_level += 2
	PC.faze_life_level += 2
	_level_up_action()

# --- 坎水诀相关奖励函数 ---
func reward_Water():
	PC.selected_rewards.append("Water")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_bagua_level += 3
	PC.faze_heal_level += 3
	_level_up_action()

func reward_RWater():
	PC.main_skill_water += 1
	PC.add_attack_percent_bonus(0.024)
	PC.heal_multi += 0.024
	PC.water_final_damage_multi += 0.06
	_level_up_action()

func reward_SRWater():
	PC.main_skill_water += 1
	PC.add_attack_percent_bonus(0.028)
	PC.heal_multi += 0.028
	PC.water_final_damage_multi += 0.07
	_level_up_action()

func reward_SSRWater():
	PC.main_skill_water += 1
	PC.add_attack_percent_bonus(0.032)
	PC.heal_multi += 0.032
	PC.water_final_damage_multi += 0.08
	_level_up_action()

func reward_URWater():
	PC.main_skill_water += 1
	PC.add_attack_percent_bonus(0.04)
	PC.heal_multi += 0.04
	PC.water_final_damage_multi += 0.1
	_level_up_action()

func reward_Water1():
	PC.selected_rewards.append("Water1")
	PC.faze_bagua_level += 2
	PC.faze_heal_level += 2
	_level_up_action()

func reward_Water2():
	PC.selected_rewards.append("Water2")
	PC.main_skill_water_damage += 0.15
	PC.faze_bagua_level += 2
	PC.faze_heal_level += 2
	_level_up_action()

func reward_Water3():
	PC.selected_rewards.append("Water3")
	PC.main_skill_water_damage += 0.1
	PC.faze_bagua_level += 2
	PC.faze_heal_level += 2
	PC.faze_shield_level += 2
	_level_up_action()

func reward_Water4():
	PC.selected_rewards.append("Water4")
	PC.main_skill_water_damage += 0.05
	PC.faze_bagua_level += 2
	PC.faze_heal_level += 2
	_level_up_action()

func reward_Water11():
	PC.selected_rewards.append("Water11")
	PC.main_skill_water_damage += 0.1
	PC.faze_bagua_level += 2
	PC.faze_heal_level += 2
	_level_up_action()

func reward_Water22():
	PC.selected_rewards.append("Water22")
	PC.main_skill_water_damage += 0.1
	PC.faze_bagua_level += 2
	PC.faze_heal_level += 2
	PC.faze_shield_level += 2
	_level_up_action()

func reward_Water33():
	PC.selected_rewards.append("Water33")
	PC.main_skill_water_damage += 0.1
	PC.faze_bagua_level += 2
	PC.faze_heal_level += 2
	_level_up_action()

# --- 乾坤双剑相关奖励函数 ---
func reward_Qiankun():
	Qiankun.reset_data()
	PC.selected_rewards.append("Qiankun")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_sword_level += 3
	PC.faze_bagua_level += 3
	# 初始化冷却时间
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if player.get("qiankun_fire_speed"):
			player.qiankun_fire_speed.start()
		# 立即初始化乾坤双剑实体
		if player.has_method("init_qiankun"):
			player.init_qiankun()
	_level_up_action()

func reward_RQiankun():
	PC.main_skill_qiankun += 1
	PC.add_attack_percent_bonus(0.04)
	Qiankun.qiankun_final_damage_multi += 0.06
	_level_up_action()

func reward_SRQiankun():
	PC.main_skill_qiankun += 1
	PC.add_attack_percent_bonus(0.045)
	Qiankun.qiankun_final_damage_multi += 0.07
	_level_up_action()

func reward_SSRQiankun():
	PC.main_skill_qiankun += 1
	PC.add_attack_percent_bonus(0.05)
	Qiankun.qiankun_final_damage_multi += 0.08
	_level_up_action()

func reward_URQiankun():
	PC.main_skill_qiankun += 1
	PC.add_attack_percent_bonus(0.06)
	Qiankun.qiankun_final_damage_multi += 0.1
	_level_up_action()

func reward_Qiankun1():
	PC.selected_rewards.append("Qiankun1")
	Qiankun.main_skill_qiankun_damage += 0.1
	Qiankun.qiankun_speed *= 1.2
	PC.faze_sword_level += 2
	PC.faze_bagua_level += 2
	_level_up_action()

func reward_Qiankun2():
	PC.selected_rewards.append("Qiankun2")
	Qiankun.main_skill_qiankun_damage += 0.1
	Qiankun.qiankun_range *= 1.3
	PC.faze_sword_level += 2
	PC.faze_bagua_level += 2
	_level_up_action()

func reward_Qiankun3():
	PC.selected_rewards.append("Qiankun3")
	Qiankun.main_skill_qiankun_damage += 0.1
	Qiankun.qiankun_speed_per_enemy = 0.02
	PC.faze_sword_level += 2
	PC.faze_bagua_level += 2
	_level_up_action()

func reward_Qiankun4():
	PC.selected_rewards.append("Qiankun4")
	Qiankun.main_skill_qiankun_damage += 0.1
	Qiankun.qiankun_damage_per_debuff = 0.3
	PC.faze_sword_level += 2
	PC.faze_bagua_level += 2
	_level_up_action()

func reward_Qiankun11():
	PC.selected_rewards.append("Qiankun11")
	Qiankun.main_skill_qiankun_damage += 0.1
	Qiankun.qiankun_speed *= 1.1
	Qiankun.qiankun_speed_per_enemy = 0.03
	PC.faze_sword_level += 2
	PC.faze_bagua_level += 2
	_level_up_action()

func reward_Qiankun22():
	PC.selected_rewards.append("Qiankun22")
	Qiankun.qiankun_range *= 1.2
	Qiankun.qiankun_damage_per_enemy = 0.03
	PC.faze_sword_level += 2
	PC.faze_bagua_level += 2
	_level_up_action()

func reward_Qiankun33():
	PC.selected_rewards.append("Qiankun33")
	Qiankun.main_skill_qiankun_damage += 0.1
	Qiankun.qiankun_crit_on_3_debuffs = true
	PC.faze_sword_level += 2
	PC.faze_bagua_level += 2
	_level_up_action()

# --- 环形子弹相关奖励函数 ---
# 获得环形子弹能力
func reward_R20():
	PC.summon_count += 1
	PC.faze_summon_level += 2
	PC.selected_rewards.append("blue_summon")
	# 通知battle场景添加召唤物 (类型0代表蓝色召唤物)
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(0) # 假设0是蓝色召唤物的类型ID
	_level_up_action()

func reward_R23():
	PC.summon_damage_multiplier += 0.08
	PC.summon_bullet_size_multiplier += 0.06
	PC.summon_interval_multiplier *= 0.97
	# 更新当前所有召唤物的属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()
	
func reward_SR23():
	PC.summon_damage_multiplier += 0.11
	PC.summon_bullet_size_multiplier += 0.08
	PC.summon_interval_multiplier *= 0.96
	# 更新当前所有召唤物的属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()

func reward_SSR23():
	PC.summon_damage_multiplier += 0.16
	PC.summon_bullet_size_multiplier += 0.10
	PC.summon_interval_multiplier *= 0.95
	# 更新当前所有召唤物的属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()

func reward_SR20():
	PC.summon_count += 1
	PC.selected_rewards.append("darkorchid_summon")
	PC.faze_summon_level += 2
	PC.new_summon = "darkorchid" # 记录最新获得的召唤物类型
	# 通知battle场景添加召唤物 (类型1代表紫色召唤物)
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(1) # 假设1是紫色召唤物的类型ID
	_level_up_action()

func reward_R24():
	PC.summon_damage_multiplier += 0.09
	PC.summon_bullet_size_multiplier += 0.05
	# 更新当前所有召唤物的属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()

func reward_SR24():
	PC.summon_damage_multiplier += 0.12
	PC.summon_bullet_size_multiplier += 0.075
	# 更新当前所有召唤物的属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()

func reward_SSR24():
	PC.summon_damage_multiplier += 0.18
	PC.summon_bullet_size_multiplier += 0.10
	# 更新当前所有召唤物的属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()
	
func reward_R25():
	PC.summon_damage_multiplier += 0.04
	PC.summon_interval_multiplier *= 0.95
	# 更新当前所有召唤物的属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()

func reward_SR25():
	PC.summon_damage_multiplier += 0.06
	PC.summon_interval_multiplier *= 0.93
	# 更新当前所有召唤物的属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()
	
func reward_SSR25():
	PC.summon_damage_multiplier += 0.09
	PC.summon_interval_multiplier *= 0.91
	# 更新当前所有召唤物的属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()
	
func reward_SSR20():
	PC.summon_count += 1
	PC.selected_rewards.append("gold_summon")
	PC.faze_summon_level += 2
	PC.new_summon = "gold" # 记录最新获得的召唤物类型
	# 通知battle场景添加召唤物 (类型2代表橙色/金色召唤物)
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(2) # 假设2是橙色/金色召唤物的类型ID
	_level_up_action()

# --- 红色召唤物相关奖励函数 ---
# 获得一个红色召唤物
func reward_UR20():
	PC.summon_count += 1
	PC.selected_rewards.append("red_summon")
	PC.faze_summon_level += 3
	PC.new_summon = "red" # 记录最新获得的召唤物类型
	# 通知battle场景添加召唤物 (类型3代表红色召唤物)
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(3) # 假设3是红色召唤物的类型ID
	_level_up_action()

# UR20Special: 获得陨灭剑灵 (红色特殊召唤物)
func reward_UR20Special():
	PC.summon_count += 1
	PC.selected_rewards.append("red_special_summon")
	PC.faze_summon_level += 2
	PC.new_summon = "red_special" # 记录最新获得的召唤物类型
	# 通知battle场景添加召唤物 (类型10代表陨灭剑灵 SWORD_SPIRIT)
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(10)
	_level_up_action()

# 橙色(金色)召唤物最大数量上限增加1
func reward_SR26():
	PC.summon_count_max += 1
	PC.faze_summon_level += 1
	PC.summon_damage_multiplier -= 0.15
	_level_up_action()

# 红色召唤物最大数量上限增加2
func reward_SSR26():
	PC.summon_count_max += 1
	PC.faze_summon_level += 1
	PC.summon_damage_multiplier -= 0.05
	_level_up_action()

# 红色召唤物最大数量上限增加2
func reward_UR26():
	PC.summon_count_max += 2
	PC.faze_summon_level += 1
	_level_up_action()

func reward_SR104():
	PC.summon_damage_multiplier += 0.06
	PC.summon_range_multiplier += 0.08
	_level_up_action()

func reward_SSR104():
	PC.summon_damage_multiplier += 0.09
	PC.summon_range_multiplier += 0.12
	_level_up_action()

func reward_SSR105():
	PC.summon_penetration_count += 1
	_level_up_action()

func reward_UR104():
	PC.summon_penetration_count += 1
	PC.summon_range_multiplier += 0.15
	PC.summon_damage_multiplier += 0.15
	_level_up_action()


func reward_SR21():
	PC.summon_count += 1
	PC.selected_rewards.append("darkorchid_heal_summon")
	PC.faze_summon_level += 2
	# 通知battle场景添加召唤物
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(4)
	_level_up_action()

func reward_SSR21():
	PC.summon_count += 1
	PC.selected_rewards.append("gold_heal_summon")
	PC.faze_summon_level += 2
	# 通知battle场景添加召唤物
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(5)
	_level_up_action()

func reward_UR21():
	PC.summon_count += 1
	PC.selected_rewards.append("red_heal_summon")
	PC.faze_summon_level += 3
	# 通知battle场景添加召唤物
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(6)
	_level_up_action()


func reward_SR22():
	PC.summon_count += 1
	PC.selected_rewards.append("darkorchid_aux_summon")
	PC.faze_summon_level += 2
	# 通知battle场景添加召唤物
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(7)
	_level_up_action()

func reward_SSR22():
	PC.summon_count += 1
	PC.selected_rewards.append("gold_aux_summon")
	PC.faze_summon_level += 2
	# 通知battle场景添加召唤物
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(8)
	_level_up_action()

func reward_UR22():
	PC.summon_count += 1
	PC.selected_rewards.append("red_aux_summon")
	PC.faze_summon_level += 3
	# 通知battle场景添加召唤物
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(9)
	_level_up_action()

func reward_SwordQi():
	PC.selected_rewards.append("SwordQi")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_sword_level += 3
	PC.faze_bullet_level += 3
	_level_up_action()

func reward_Branch():
	PC.selected_rewards.append("Branch")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_treasure_level += 3
	PC.faze_bullet_level += 3
	_level_up_action()

func reward_Moyan():
	PC.selected_rewards.append("Moyan")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_fire_level += 3
	PC.faze_destroy_level += 3
	_level_up_action()

func reward_RingFire():
	PC.selected_rewards.append("RingFire")
	PC.faze_fire_level += 3
	PC.faze_bagua_level += 3
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	_refresh_ring_fire_instances()
	_level_up_action()

func _refresh_ring_fire_instances() -> void:
	if PC.selected_rewards.has("RingFire"):
		Global.emit_signal("ringFire_damage_triggered")
	
func reward_Riyan():
	PC.selected_rewards.append("Riyan")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_fire_level += 3
	PC.faze_wide_level += 3
	_level_up_action()

func reward_Thunder():
	PC.selected_rewards.append("Thunder")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_thunder_level += 3
	PC.faze_bagua_level += 3
	_level_up_action()

func reward_Bloodwave():
	BloodWave.reset_data()
	PC.selected_rewards.append("Bloodwave")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_wide_level += 3
	PC.faze_blood_level += 3
	_level_up_action()

func reward_BloodBoardSword():
	PC.selected_rewards.append("BloodBoardSword")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_sword_level += 3
	PC.faze_blood_level += 3
	_level_up_action()

func reward_Zhuazhuajuchui():
	ZHUAZHUAJUCHUI_SCRIPT.reset_data()
	PC.selected_rewards.append("Zhuazhuajuchui")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_deep_level += 3
	PC.faze_blood_level += 3
	_level_up_action()

func reward_SoulSickle():
	SOUL_SICKLE_SCRIPT.reset_data()
	PC.selected_rewards.append("SoulSickle")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_shehun_level += 3
	PC.faze_deep_level += 3
	_level_up_action()

func reward_ThunderGun():
	THUNDER_GUN_SCRIPT.reset_data()
	PC.selected_rewards.append("ThunderGun")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_thunder_level += 3
	PC.faze_shehun_level += 3
	PC.main_skill_thunder_gun = max(PC.main_skill_thunder_gun, 1)
	_level_up_action()

func reward_RSwordQi():
	PC.main_skill_swordQi += 1
	PC.main_skill_swordQi_damage += 0.04
	PC.attack_speed_bonus += 0.04
	_level_up_action()

func reward_SRSwordQi():
	PC.main_skill_swordQi += 1
	PC.attack_speed_bonus += 0.045
	PC.main_skill_swordQi_damage += 0.05
	_level_up_action()
	
func reward_SSRSwordQi():
	PC.main_skill_swordQi += 1
	PC.attack_speed_bonus += 0.05
	PC.main_skill_swordQi_damage += 0.06
	_level_up_action()

func reward_SplitSwordQi1():
	PC.selected_rewards.append("SplitSwordQi1")
	PC.faze_sword_level += 2
	PC.faze_bullet_level += 2
	_level_up_action()
	
func reward_SplitSwordQi2():
	PC.selected_rewards.append("SplitSwordQi2")
	PC.main_skill_swordQi_damage += 0.1
	PC.faze_sword_level += 2
	PC.faze_bullet_level += 2
	_level_up_action()
	
func reward_SplitSwordQi3():
	PC.selected_rewards.append("SplitSwordQi3")
	PC.swordQi_penetration_count = max(PC.swordQi_penetration_count, 3) # 命中1次 + 穿透2次
	PC.faze_sword_level += 2
	PC.faze_bullet_level += 2
	_level_up_action()

func reward_SplitSwordQi4():
	PC.selected_rewards.append("SplitSwordQi4")
	PC.faze_sword_level += 2
	PC.faze_bullet_level += 2
	_level_up_action()
	
func reward_SplitSwordQi11():
	PC.selected_rewards.append("SplitSwordQi11")
	PC.main_skill_swordQi_damage += 0.05
	PC.faze_sword_level += 2
	PC.faze_bullet_level += 2
	_level_up_action()
	
func reward_SplitSwordQi12():
	PC.selected_rewards.append("SplitSwordQi12")
	PC.main_skill_swordQi_damage += 0.05
	PC.faze_sword_level += 2
	PC.faze_bullet_level += 2
	_level_up_action()
	
func reward_SplitSwordQi13():
	PC.selected_rewards.append("SplitSwordQi13")
	PC.main_skill_swordQi_damage += 0.1
	PC.faze_sword_level += 2
	PC.faze_bullet_level += 2
	_level_up_action()
	
func reward_SplitSwordQi21():
	PC.selected_rewards.append("SplitSwordQi21")
	PC.main_skill_swordQi_damage += 0.1
	PC.faze_sword_level += 2
	PC.faze_bullet_level += 2
	_level_up_action()
	
func reward_SplitSwordQi31():
	PC.selected_rewards.append("SplitSwordQi31")
	PC.main_skill_swordQi_damage += 0.1
	PC.swordQi_penetration_count = max(PC.swordQi_penetration_count, 4) # 命中1次 + 穿透3次
	PC.faze_sword_level += 2
	PC.faze_bullet_level += 2
	_level_up_action()
	
func reward_SplitSwordQi33():
	PC.selected_rewards.append("SplitSwordQi33")
	PC.faze_sword_level += 2
	PC.faze_bullet_level += 2
	_level_up_action()
	

func reward_RBranch():
	PC.main_skill_branch += 1
	PC.add_attack_percent_bonus(0.024)
	PC.exp_multi += 0.024
	PC.main_skill_branch_damage += 0.06
	_level_up_action()

func reward_SRBranch():
	PC.main_skill_branch += 1
	PC.add_attack_percent_bonus(0.028)
	PC.exp_multi += 0.028
	PC.main_skill_branch_damage += 0.07
	_level_up_action()
	
func reward_SSRBranch():
	PC.main_skill_branch += 1
	PC.add_attack_percent_bonus(0.032)
	PC.exp_multi += 0.032
	PC.main_skill_branch_damage += 0.08
	_level_up_action()

func reward_Branch1():
	PC.selected_rewards.append("Branch1")
	PC.main_skill_branch_damage -= 0.20
	PC.faze_treasure_level += 2
	PC.faze_bullet_level += 2
	_level_up_action()

func reward_Branch2():
	PC.selected_rewards.append("Branch2")
	PC.faze_treasure_level += 2
	PC.faze_bullet_level += 2
	_level_up_action()

func reward_Branch3():
	PC.selected_rewards.append("Branch3")
	PC.faze_treasure_level += 2
	PC.faze_bullet_level += 2
	_level_up_action()

func reward_Branch4():
	PC.selected_rewards.append("Branch4")
	PC.faze_treasure_level += 2
	PC.faze_bullet_level += 2
	_level_up_action()

func reward_Branch11():
	PC.selected_rewards.append("Branch11")
	PC.main_skill_branch_damage -= 0.20
	PC.faze_treasure_level += 2
	PC.faze_bullet_level += 2
	_level_up_action()

func reward_Branch21():
	PC.selected_rewards.append("Branch21")
	PC.faze_treasure_level += 2
	PC.faze_bullet_level += 2
	_level_up_action()

func reward_Branch12():
	PC.selected_rewards.append("Branch12")
	PC.faze_treasure_level += 2
	PC.faze_bullet_level += 2
	_level_up_action()

func reward_Branch31():
	PC.selected_rewards.append("Branch31")
	PC.faze_treasure_level += 2
	PC.faze_bullet_level += 2
	_level_up_action()

func reward_Branch22():
	PC.selected_rewards.append("Branch22")
	PC.main_skill_branch_damage += 0.1
	PC.faze_treasure_level += 2
	PC.faze_bullet_level += 2
	_level_up_action()

func reward_RMoyan():
	PC.main_skill_moyan += 1
	PC.crit_damage_multi += 0.04
	PC.main_skill_moyan_damage += 0.06
	_level_up_action()

func reward_SRMoyan():
	PC.main_skill_moyan += 1
	PC.crit_damage_multi += 0.045
	PC.main_skill_moyan_damage += 0.07
	_level_up_action()
	
func reward_SSRMoyan():
	PC.main_skill_moyan += 1
	PC.crit_damage_multi += 0.05
	PC.main_skill_moyan_damage += 0.08
	_level_up_action()

func reward_Moyan1():
	PC.selected_rewards.append("Moyan1")
	PC.main_skill_moyan_damage += 0.15
	PC.faze_fire_level += 2
	PC.faze_destroy_level += 2
	_level_up_action()

func reward_Moyan2():
	PC.selected_rewards.append("Moyan2")
	PC.main_skill_moyan_damage += 0.1
	PC.faze_fire_level += 2
	PC.faze_destroy_level += 2
	_level_up_action()

func reward_Moyan3():
	PC.selected_rewards.append("Moyan3")
	PC.faze_fire_level += 2
	PC.faze_destroy_level += 2
	_level_up_action()

func reward_Moyan12():
	PC.selected_rewards.append("Moyan12")
	PC.main_skill_moyan_damage += 0.1
	PC.faze_fire_level += 2
	PC.faze_destroy_level += 2
	_level_up_action()

func reward_Moyan23():
	PC.selected_rewards.append("Moyan23")
	PC.faze_fire_level += 2
	PC.faze_destroy_level += 2
	_level_up_action()

func reward_Moyan4():
	PC.selected_rewards.append("Moyan4")
	PC.main_skill_moyan_damage += 0.1
	PC.faze_fire_level += 2
	PC.faze_destroy_level += 2
	_level_up_action()

func reward_Moyan34():
	PC.selected_rewards.append("Moyan34")
	PC.main_skill_moyan_damage += 0.1
	PC.faze_fire_level += 2
	PC.faze_destroy_level += 2
	_level_up_action()


func reward_RRingFire():
	PC.main_skill_ringFire += 1
	PC.crit_chance += 0.01
	PC.main_skill_ringFire_damage += 0.06
	_level_up_action()

func reward_SRRingFire():
	PC.main_skill_ringFire += 1
	PC.crit_chance += 0.011
	PC.main_skill_ringFire_damage += 0.07
	_level_up_action()
	
func reward_SSRRingFire():
	PC.main_skill_ringFire += 1
	PC.crit_chance += 0.012
	PC.main_skill_ringFire_damage += 0.08
	_level_up_action()

func reward_RingFire1():
	PC.selected_rewards.append("RingFire1")
	PC.faze_fire_level += 2
	PC.faze_bagua_level += 2
	_refresh_ring_fire_instances()
	_level_up_action()

func reward_RingFire2():
	PC.selected_rewards.append("RingFire2")
	PC.faze_fire_level += 2
	PC.faze_bagua_level += 2
	_refresh_ring_fire_instances()
	_level_up_action()

func reward_RingFire3():
	PC.selected_rewards.append("RingFire3")
	PC.main_skill_ringFire_damage += 0.1
	PC.faze_fire_level += 2
	PC.faze_bagua_level += 2
	_refresh_ring_fire_instances()
	_level_up_action()

func reward_RingFire11():
	PC.selected_rewards.append("RingFire11")
	PC.faze_fire_level += 2
	PC.faze_bagua_level += 2
	_refresh_ring_fire_instances()
	_level_up_action()

func reward_RingFire4():
	PC.selected_rewards.append("RingFire4")
	PC.main_skill_ringFire_damage += 0.05
	PC.faze_fire_level += 2
	PC.faze_bagua_level += 2
	_refresh_ring_fire_instances()
	_level_up_action()

func reward_RingFire22():
	PC.selected_rewards.append("RingFire22")
	PC.faze_fire_level += 2
	PC.faze_bagua_level += 2
	_refresh_ring_fire_instances()
	_level_up_action()

func reward_RingFire33():
	PC.selected_rewards.append("RingFire33")
	PC.faze_fire_level += 2
	PC.faze_bagua_level += 2
	_refresh_ring_fire_instances()
	_level_up_action()

func reward_RRiyan():
	PC.main_skill_riyan += 1
	PC.add_attack_percent_bonus(0.024)
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.024)
	PC.main_skill_riyan_damage += 0.06
	_level_up_action()

func reward_SRRiyan():
	PC.main_skill_riyan += 1
	PC.add_attack_percent_bonus(0.028)
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.028)
	PC.main_skill_riyan_damage += 0.07
	_level_up_action()
	
func reward_SSRRiyan():
	PC.main_skill_riyan += 1
	PC.add_attack_percent_bonus(0.032)
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.032)
	PC.main_skill_riyan_damage += 0.08
	_level_up_action()

func reward_Riyan1():
	PC.selected_rewards.append("Riyan1")
	PC.main_skill_riyan_damage += 0.1
	PC.faze_fire_level += 2
	PC.faze_wide_level += 2
	_level_up_action()

func reward_Riyan2():
	PC.selected_rewards.append("Riyan2")
	PC.main_skill_riyan_damage += 0.1
	PC.faze_fire_level += 2
	PC.faze_wide_level += 2
	_level_up_action()

func reward_Riyan3():
	PC.selected_rewards.append("Riyan3")
	PC.main_skill_riyan_damage += 0.1
	PC.faze_fire_level += 2
	PC.faze_wide_level += 2
	_level_up_action()

func reward_Riyan4():
	PC.selected_rewards.append("Riyan4")
	PC.main_skill_riyan_damage += 0.1
	PC.faze_fire_level += 2
	PC.faze_wide_level += 2
	_level_up_action()

func reward_Riyan11():
	PC.selected_rewards.append("Riyan11")
	PC.main_skill_riyan_damage += 0.1
	PC.faze_fire_level += 2
	PC.faze_wide_level += 2
	_level_up_action()

func reward_Riyan22():
	PC.selected_rewards.append("Riyan22")
	PC.main_skill_riyan_damage += 0.15
	PC.faze_fire_level += 2
	PC.faze_wide_level += 2
	_level_up_action()

func reward_Riyan33():
	PC.selected_rewards.append("Riyan33")
	PC.main_skill_riyan_damage += 0.1
	PC.faze_fire_level += 2
	PC.faze_wide_level += 2
	_level_up_action()

func reward_RBloodwave():
	PC.main_skill_bloodwave += 1
	PC.final_damage_bonus += 0.02
	BloodWave.main_skill_bloodwave_damage += 0.06
	_level_up_action()

func reward_SRBloodwave():
	PC.main_skill_bloodwave += 1
	PC.final_damage_bonus += 0.022
	BloodWave.main_skill_bloodwave_damage += 0.07
	_level_up_action()

func reward_SSRBloodwave():
	PC.main_skill_bloodwave += 1
	PC.final_damage_bonus += 0.025
	BloodWave.main_skill_bloodwave_damage += 0.08
	_level_up_action()

func reward_URBloodwave():
	PC.main_skill_bloodwave += 1
	PC.final_damage_bonus += 0.03
	BloodWave.main_skill_bloodwave_damage += 0.10
	_level_up_action()

func reward_RBloodBoardSword():
	PC.main_skill_bloodboardsword += 1
	PC.add_attack_percent_bonus(0.04)
	PC.main_skill_bloodboardsword_damage += 0.06
	_level_up_action()

func reward_SRBloodBoardSword():
	PC.main_skill_bloodboardsword += 1
	PC.add_attack_percent_bonus(0.045)
	PC.main_skill_bloodboardsword_damage += 0.07
	_level_up_action()

func reward_SSRBloodBoardSword():
	PC.main_skill_bloodboardsword += 1
	PC.add_attack_percent_bonus(0.05)
	PC.main_skill_bloodboardsword_damage += 0.08
	_level_up_action()

func reward_URBloodBoardSword():
	PC.main_skill_bloodboardsword += 1
	PC.add_attack_percent_bonus(0.06)
	PC.main_skill_bloodboardsword_damage += 0.1
	_level_up_action()

func reward_BloodBoardSword1():
	PC.faze_blood_level += 2
	PC.faze_sword_level += 2
	PC.selected_rewards.append("BloodBoardSword1")
	PC.main_skill_bloodboardsword_damage += 0.1
	_level_up_action()

func reward_BloodBoardSword2():
	PC.faze_blood_level += 2
	PC.faze_sword_level += 2
	PC.selected_rewards.append("BloodBoardSword2")
	PC.main_skill_bloodboardsword_damage += 0.1
	_level_up_action()

func reward_BloodBoardSword3():
	PC.faze_blood_level += 2
	PC.faze_sword_level += 2
	PC.selected_rewards.append("BloodBoardSword3")
	_level_up_action()

func reward_BloodBoardSword4():
	PC.faze_blood_level += 2
	PC.faze_sword_level += 2
	PC.selected_rewards.append("BloodBoardSword4")
	_level_up_action()

func reward_BloodBoardSword11():
	PC.faze_blood_level += 2
	PC.faze_sword_level += 2
	PC.selected_rewards.append("BloodBoardSword11")
	PC.main_skill_bloodboardsword_damage += 0.1
	_level_up_action()

func reward_BloodBoardSword22():
	PC.faze_blood_level += 2
	PC.faze_sword_level += 2
	PC.selected_rewards.append("BloodBoardSword22")
	PC.main_skill_bloodboardsword_damage += 0.2
	_level_up_action()

func reward_BloodBoardSword33():
	PC.faze_blood_level += 2
	PC.faze_sword_level += 2
	PC.selected_rewards.append("BloodBoardSword33")
	_level_up_action()

func reward_RThunder():
	PC.main_skill_thunder += 1
	PC.final_damage_bonus += 0.02
	PC.main_skill_thunder_damage += 0.06
	_level_up_action()

func reward_SRThunder():
	PC.main_skill_thunder += 1
	PC.final_damage_bonus += 0.022
	PC.main_skill_thunder_damage += 0.07
	_level_up_action()

func reward_SSRThunder():
	PC.main_skill_thunder += 1
	PC.final_damage_bonus += 0.025
	PC.main_skill_thunder_damage += 0.08
	_level_up_action()

func reward_Thunder1():
	PC.faze_bagua_level += 2
	PC.faze_thunder_level += 2
	PC.selected_rewards.append("Thunder1")
	_level_up_action()

func reward_Thunder2():
	PC.faze_bagua_level += 2
	PC.faze_thunder_level += 2
	PC.selected_rewards.append("Thunder2")
	_level_up_action()

func reward_Thunder3():
	PC.faze_bagua_level += 2
	PC.faze_thunder_level += 2
	PC.selected_rewards.append("Thunder3")
	PC.main_skill_thunder_damage += 0.20
	_level_up_action()

func reward_Thunder4():
	PC.faze_bagua_level += 2
	PC.faze_thunder_level += 2
	PC.selected_rewards.append("Thunder4")
	_level_up_action()

func reward_Thunder11():
	PC.faze_bagua_level += 2
	PC.faze_thunder_level += 2
	PC.selected_rewards.append("Thunder11")
	_level_up_action()

func reward_Thunder22():
	PC.faze_bagua_level += 2
	PC.faze_thunder_level += 2
	PC.selected_rewards.append("Thunder22")
	PC.main_skill_thunder_damage += 0.15
	_level_up_action()

func reward_Thunder33():
	PC.faze_bagua_level += 2
	PC.faze_thunder_level += 2
	PC.selected_rewards.append("Thunder33")
	_level_up_action()

func reward_Bloodwave1():
	PC.faze_blood_level += 2
	PC.faze_wide_level += 2
	PC.selected_rewards.append("Bloodwave1")
	BloodWave.bloodwave_apply_bleed = true
	_level_up_action()

func reward_Bloodwave2():
	PC.faze_blood_level += 2
	PC.faze_wide_level += 2
	PC.selected_rewards.append("Bloodwave2")
	BloodWave.bloodwave_hp_cost_multi = 2.0
	BloodWave.bloodwave_extra_crit_chance += 0.35
	BloodWave.bloodwave_extra_crit_damage += 0.35
	_level_up_action()

func reward_Bloodwave3():
	PC.faze_blood_level += 2
	PC.faze_wide_level += 2
	PC.selected_rewards.append("Bloodwave3")
	BloodWave.bloodwave_missing_hp_damage_bonus = 0.01
	BloodWave.bloodwave_missing_hp_range_bonus = 0.02
	_level_up_action()

func reward_Bloodwave4():
	PC.faze_blood_level += 2
	PC.faze_wide_level += 2
	PC.selected_rewards.append("Bloodwave4")
	BloodWave.main_skill_bloodwave_damage += 0.1
	BloodWave.bloodwave_missing_hp_heal_bonus = 0.01
	_level_up_action()

func reward_Bloodwave11():
	PC.faze_blood_level += 2
	PC.faze_wide_level += 2
	PC.selected_rewards.append("Bloodwave11")
	BloodWave.bloodwave_missing_hp_damage_bonus = 0.015
	BloodWave.bloodwave_missing_hp_heal_bonus = 0.015
	_level_up_action()

func reward_Bloodwave22():
	PC.faze_blood_level += 2
	PC.faze_wide_level += 2
	PC.selected_rewards.append("Bloodwave22")
	BloodWave.bloodwave_hp_cost_multi = 3.0
	BloodWave.bloodwave_low_hp_cost_multiplier = 0.5
	BloodWave.bloodwave_low_hp_damage_bonus = 0.4
	BloodWave.bloodwave_low_hp_range_bonus = 0.4
	_level_up_action()

func reward_Bloodwave33():
	PC.faze_blood_level += 2
	PC.faze_wide_level += 2
	PC.selected_rewards.append("Bloodwave33")
	BloodWave.main_skill_bloodwave_damage += 0.05
	BloodWave.bloodwave_bleed_move_speed_bonus = 0.01
	_level_up_action()
	
func check_Xuanwu_condition() -> bool:
	return PC.selected_rewards.has("Xuanwu")

func check_Xuanwu_condition1() -> bool:
	return PC.selected_rewards.has("Xuanwu1") and PC.selected_rewards.has("Xuanwu2")

func check_Xuanwu_condition2() -> bool:
	return PC.selected_rewards.has("Xuanwu3") and PC.selected_rewards.has("Xuanwu4")

func check_Xuanwu_condition3() -> bool:
	return PC.selected_rewards.has("Xuanwu1") and PC.selected_rewards.has("Xuanwu3")

func reward_Xuanwu():
	Xuanwu.reset_data()
	PC.selected_rewards.append("Xuanwu")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_shield_level += 3
	PC.faze_treasure_level += 3
	_level_up_action()

func reward_RXuanwu():
	PC.main_skill_xuanwu += 1
	PC.add_attack_percent_bonus(0.024)
	PC.pc_armor += 5
	Xuanwu.xuanwu_final_damage_multi += 0.06
	_level_up_action()

func reward_SRXuanwu():
	PC.main_skill_xuanwu += 1
	PC.add_attack_percent_bonus(0.028)
	PC.pc_armor += 6
	Xuanwu.xuanwu_final_damage_multi += 0.07
	_level_up_action()

func reward_SSRXuanwu():
	PC.main_skill_xuanwu += 1
	PC.add_attack_percent_bonus(0.032)
	PC.pc_armor += 8
	Xuanwu.xuanwu_final_damage_multi += 0.08
	_level_up_action()

func reward_URXuanwu():
	PC.main_skill_xuanwu += 1
	PC.add_attack_percent_bonus(0.04)
	PC.pc_armor += 11
	Xuanwu.xuanwu_final_damage_multi += 0.1
	_level_up_action()

func reward_Xuanwu1():
	PC.selected_rewards.append("Xuanwu1")
	PC.faze_shield_level += 2
	PC.faze_treasure_level += 2
	Xuanwu.xuanwu_final_damage_multi += 0.15
	Xuanwu.xuanwu_shield_base += 15
	Xuanwu.xuanwu_shield_hp_ratio = 0.05
	_level_up_action()

func reward_Xuanwu2():
	PC.selected_rewards.append("Xuanwu2")
	PC.faze_shield_level += 2
	PC.faze_treasure_level += 2
	Xuanwu.xuanwu_final_damage_multi += 0.05
	Xuanwu.xuanwu_shield_bonus_damage = 3.0
	_level_up_action()

func reward_Xuanwu3():
	PC.selected_rewards.append("Xuanwu3")
	PC.faze_shield_level += 2
	PC.faze_treasure_level += 2
	Xuanwu.xuanwu_final_damage_multi += 0.15
	Xuanwu.xuanwu_shield_base += 20
	Xuanwu.xuanwu_slow_duration = 5.0
	_level_up_action()

func reward_Xuanwu4():
	PC.selected_rewards.append("Xuanwu4")
	PC.faze_shield_level += 2
	PC.faze_treasure_level += 2
	Xuanwu.xuanwu_width_scale = 1.2
	Xuanwu.xuanwu_vulnerable_duration = 5.0
	_level_up_action()

func reward_Xuanwu11():
	PC.selected_rewards.append("Xuanwu11")
	PC.faze_shield_level += 2
	PC.faze_treasure_level += 2
	Xuanwu.xuanwu_final_damage_multi += 0.1
	Xuanwu.xuanwu_shield_base += 20
	Xuanwu.xuanwu_shield_bonus_damage = 5.0
	_level_up_action()

func reward_Xuanwu22():
	PC.selected_rewards.append("Xuanwu22")
	PC.faze_shield_level += 2
	PC.faze_treasure_level += 2
	Xuanwu.xuanwu_final_damage_multi += 0.15
	Xuanwu.xuanwu_return_shield_bonus = 0.3
	_level_up_action()

func reward_Xuanwu33():
	PC.selected_rewards.append("Xuanwu33")
	PC.faze_shield_level += 2
	PC.faze_treasure_level += 2
	Xuanwu.xuanwu_final_damage_multi += 0.2
	Xuanwu.xuanwu_shield_base += 20
	Xuanwu.xuanwu_width_scale += 0.3
	_level_up_action()


func check_Xunfeng_condition() -> bool:
	return PC.selected_rewards.has("Xunfeng")

func check_Xunfeng_condition1() -> bool:
	return PC.selected_rewards.has("Xunfeng1") and PC.selected_rewards.has("Xunfeng4")

func check_Xunfeng_condition2() -> bool:
	return PC.selected_rewards.has("Xunfeng2") and PC.selected_rewards.has("Xunfeng3")

func check_Xunfeng_condition3() -> bool:
	return PC.selected_rewards.has("Xunfeng1") and PC.selected_rewards.has("Xunfeng3")

func check_DragonWind_condition() -> bool:
	return PC.selected_rewards.has("DragonWind")

func check_DragonWind_condition1() -> bool:
	return PC.selected_rewards.has("DragonWind1") and PC.selected_rewards.has("DragonWind2")

func check_DragonWind_condition2() -> bool:
	return PC.selected_rewards.has("DragonWind3") and PC.selected_rewards.has("DragonWind4")

func check_DragonWind_condition3() -> bool:
	return PC.selected_rewards.has("DragonWind2") and PC.selected_rewards.has("DragonWind3")

func check_Zhuazhuajuchui_condition() -> bool:
	return PC.selected_rewards.has("Zhuazhuajuchui")

func check_liliang_lv_10() -> bool:
	return PC.pc_lv >= 10

func check_liliang_lv_20() -> bool:
	return PC.pc_lv >= 20

func check_liliang_lv_25() -> bool:
	return PC.pc_lv >= 25

func check_Zhuazhuajuchui1() -> bool:
	return PC.selected_rewards.has("Zhuazhuajuchui1") and PC.selected_rewards.has("Zhuazhuajuchui4")

func check_Zhuazhuajuchui2() -> bool:
	return PC.selected_rewards.has("Zhuazhuajuchui2") and PC.selected_rewards.has("Zhuazhuajuchui1")

func check_Zhuazhuajuchui3() -> bool:
	return PC.selected_rewards.has("Zhuazhuajuchui3") and PC.selected_rewards.has("Zhuazhuajuchui4")

func check_SoulSickle_condition() -> bool:
	return PC.selected_rewards.has("SoulSickle")

func check_SoulSickle_condition1() -> bool:
	return PC.selected_rewards.has("SoulSickle1") and PC.selected_rewards.has("SoulSickle2")

func check_SoulSickle_condition2() -> bool:
	return PC.selected_rewards.has("SoulSickle3") and PC.selected_rewards.has("SoulSickle4")

func check_SoulSickle_condition3() -> bool:
	return PC.selected_rewards.has("SoulSickle2") and PC.selected_rewards.has("SoulSickle4")

func check_ThunderGun_condition() -> bool:
	return PC.selected_rewards.has("ThunderGun")

func check_ThunderGun_condition1() -> bool:
	return PC.selected_rewards.has("ThunderGun4") and PC.selected_rewards.has("ThunderGun3")

func check_ThunderGun_condition2() -> bool:
	return PC.selected_rewards.has("ThunderGun1") and PC.selected_rewards.has("ThunderGun2")

func check_ThunderGun_condition3() -> bool:
	return PC.selected_rewards.has("ThunderGun3") and PC.selected_rewards.has("ThunderGun2")

func reward_Xunfeng():
	Xunfeng.reset_data()
	PC.selected_rewards.append("Xunfeng")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_bagua_level += 3
	PC.faze_wind_level += 3
	_level_up_action()

func reward_RXunfeng():
	PC.main_skill_xunfeng += 1
	PC.move_speed_bonus += 0.024
	PC.attack_speed_bonus += 0.024
	Xunfeng.xunfeng_final_damage_multi += 0.06
	_level_up_action()

func reward_SRXunfeng():
	PC.main_skill_xunfeng += 1
	PC.move_speed_bonus += 0.028
	PC.attack_speed_bonus += 0.028
	Xunfeng.xunfeng_final_damage_multi += 0.07
	_level_up_action()

func reward_SSRXunfeng():
	PC.main_skill_xunfeng += 1
	PC.move_speed_bonus += 0.032
	PC.attack_speed_bonus += 0.032
	Xunfeng.xunfeng_final_damage_multi += 0.08
	_level_up_action()

func reward_URXunfeng():
	PC.main_skill_xunfeng += 1
	PC.move_speed_bonus += 0.04
	PC.attack_speed_bonus += 0.04
	Xunfeng.xunfeng_final_damage_multi += 0.1
	_level_up_action()

func reward_Xunfeng1():
	PC.selected_rewards.append("Xunfeng1")
	Xunfeng.xunfeng_final_damage_multi += 0.1
	Xunfeng.xunfeng_size_scale *= 1.35
	Xunfeng.xunfeng_range *= 1.20
	PC.faze_bagua_level += 2
	PC.faze_wind_level += 2
	_level_up_action()

func reward_Xunfeng2():
	PC.selected_rewards.append("Xunfeng2")
	Xunfeng.xunfeng_final_damage_multi += 0.1
	Xunfeng.xunfeng_speed *= 1.20
	Xunfeng.xunfeng_cooldown *= 0.90
	PC.faze_bagua_level += 2
	PC.faze_wind_level += 2
	_level_up_action()

func reward_Xunfeng3():
	PC.selected_rewards.append("Xunfeng3")
	Xunfeng.xunfeng_final_damage_multi += 0.05
	PC.faze_bagua_level += 2
	PC.faze_wind_level += 2
	# logic handled in player_action.gd
	_level_up_action()

func reward_Xunfeng4():
	PC.selected_rewards.append("Xunfeng4")
	Xunfeng.xunfeng_penetration_count = 999
	Xunfeng.xunfeng_pierce_decay = 0.50
	PC.faze_bagua_level += 2
	PC.faze_wind_level += 2
	_level_up_action()

func reward_Xunfeng11():
	PC.selected_rewards.append("Xunfeng11")
	Xunfeng.xunfeng_final_damage_multi += 0.1
	Xunfeng.xunfeng_size_scale *= 1.35
	Xunfeng.xunfeng_pierce_decay = 0.40
	PC.faze_bagua_level += 2
	PC.faze_wind_level += 2
	_level_up_action()

func reward_Xunfeng22():
	PC.selected_rewards.append("Xunfeng22")
	Xunfeng.xunfeng_final_damage_multi += 0.1
	Xunfeng.xunfeng_extra_blade_count_threshold = 2
	PC.faze_bagua_level += 2
	PC.faze_wind_level += 2
	_level_up_action()

func reward_Xunfeng33():
	PC.selected_rewards.append("Xunfeng33")
	Xunfeng.xunfeng_final_damage_multi += 0.05
	PC.faze_bagua_level += 2
	PC.faze_wind_level += 2
	# logic for diagonal extra blades handled in player_action.gd
	_level_up_action()

func reward_DragonWind():
	DragonWind.reset_data()
	PC.selected_rewards.append("DragonWind")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_treasure_level += 3
	PC.faze_wind_level += 3
	_level_up_action()

func reward_RDragonWind():
	PC.main_skill_dragonwind += 1
	PC.attack_speed_bonus += 0.024
	PC.crit_chance += 0.012
	DragonWind.dragonwind_final_damage_multi += 0.06
	PC.main_skill_dragonwind_damage = DragonWind.dragonwind_final_damage_multi
	_level_up_action()

func reward_SRDragonWind():
	PC.main_skill_dragonwind += 1
	PC.attack_speed_bonus += 0.028
	PC.crit_chance += 0.014
	DragonWind.dragonwind_final_damage_multi += 0.07
	PC.main_skill_dragonwind_damage = DragonWind.dragonwind_final_damage_multi
	_level_up_action()

func reward_SSRDragonWind():
	PC.main_skill_dragonwind += 1
	PC.attack_speed_bonus += 0.032
	PC.crit_chance += 0.016
	DragonWind.dragonwind_final_damage_multi += 0.08
	PC.main_skill_dragonwind_damage = DragonWind.dragonwind_final_damage_multi
	_level_up_action()

func reward_URDragonWind():
	PC.main_skill_dragonwind += 1
	PC.attack_speed_bonus += 0.04
	PC.crit_chance += 0.02
	DragonWind.dragonwind_final_damage_multi += 0.1
	PC.main_skill_dragonwind_damage = DragonWind.dragonwind_final_damage_multi
	_level_up_action()

func reward_DragonWind1():
	PC.selected_rewards.append("DragonWind1")
	DragonWind.dragonwind_final_damage_multi += 0.05
	DragonWind.dragonwind_range_scale *= 1.15
	DragonWind.dragonwind_pull_force *= 1.50
	PC.main_skill_dragonwind_damage = DragonWind.dragonwind_final_damage_multi
	PC.faze_treasure_level += 2
	PC.faze_wind_level += 2
	_level_up_action()

func reward_DragonWind2():
	PC.selected_rewards.append("DragonWind2")
	DragonWind.dragonwind_range_scale *= 1.35
	PC.main_skill_dragonwind_damage = DragonWind.dragonwind_final_damage_multi
	PC.faze_treasure_level += 2
	PC.faze_wind_level += 2
	_level_up_action()

func reward_DragonWind3():
	PC.selected_rewards.append("DragonWind3")
	DragonWind.dragonwind_center_bonus_ratio = 0.35
	PC.faze_treasure_level += 2
	PC.faze_wind_level += 2
	_level_up_action()

func reward_DragonWind4():
	PC.selected_rewards.append("DragonWind4")
	DragonWind.dragonwind_final_damage_multi += 0.10
	DragonWind.dragonwind_slow_duration = 5.0
	PC.main_skill_dragonwind_damage = DragonWind.dragonwind_final_damage_multi
	PC.faze_treasure_level += 2
	PC.faze_wind_level += 2
	_level_up_action()

func reward_DragonWind11():
	PC.selected_rewards.append("DragonWind11")
	DragonWind.dragonwind_final_damage_multi += 0.05
	DragonWind.dragonwind_pull_force *= 1.20
	DragonWind.dragonwind_range_scale *= 1.20
	PC.main_skill_dragonwind_damage = DragonWind.dragonwind_final_damage_multi
	PC.faze_treasure_level += 2
	PC.faze_wind_level += 2
	_level_up_action()

func reward_DragonWind22():
	PC.selected_rewards.append("DragonWind22")
	DragonWind.dragonwind_final_damage_multi += 0.05
	DragonWind.dragonwind_slow_damage_bonus = 0.30
	PC.main_skill_dragonwind_damage = DragonWind.dragonwind_final_damage_multi
	PC.faze_treasure_level += 2
	PC.faze_wind_level += 2
	_level_up_action()

func reward_DragonWind33():
	PC.selected_rewards.append("DragonWind33")
	DragonWind.dragonwind_center_bonus_ratio = 0.50
	DragonWind.dragonwind_boss_bonus_ratio = 0.50
	PC.faze_treasure_level += 2
	PC.faze_wind_level += 2
	_level_up_action()

func check_Yujian_condition() -> bool:
	return PC.selected_rewards.has("Yujian")

func check_Yujian_condition1() -> bool:
	return PC.selected_rewards.has("Yujian3") and PC.selected_rewards.has("Yujian2")

func check_Yujian_condition2() -> bool:
	return PC.selected_rewards.has("Yujian1") and PC.selected_rewards.has("Yujian4")

func check_Yujian_condition3() -> bool:
	return PC.selected_rewards.has("Yujian4") and PC.selected_rewards.has("Yujian2")

func _spawn_yujian_extra_summon(summon_type: int) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_yujian_extra_summon"):
		player.add_yujian_extra_summon(summon_type)

func _sync_yujian_player_state() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if player.has_method("sync_yujian_state"):
			player.sync_yujian_state()
		if player.has_method("update_summons_properties"):
			player.update_summons_properties()

func _refresh_yujian_summon_bonuses() -> void:
	PC.refresh_yujian_summon_bonuses()
	_sync_yujian_player_state()

func reward_Yujian():
	PC.selected_rewards.append("Yujian")
	PC.selected_rewards.append("yujian_blue_summon")
	PC.selected_rewards.append("yujian_darkorchid_summon")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.move_speed_bonus += 0.15
	PC.summon_penetration_count += 1
	PC.faze_summon_level += 4
	_spawn_yujian_extra_summon(0)
	_spawn_yujian_extra_summon(1)
	_sync_yujian_player_state()
	_level_up_action()

func reward_RYujian():
	PC.main_skill_yujian += 1
	PC.move_speed_bonus += 0.024
	PC.summon_damage_multiplier += 0.03
	_refresh_yujian_summon_bonuses()
	_level_up_action()

func reward_SRYujian():
	PC.main_skill_yujian += 1
	PC.move_speed_bonus += 0.028
	PC.summon_damage_multiplier += 0.04
	_refresh_yujian_summon_bonuses()
	_level_up_action()

func reward_SSRYujian():
	PC.main_skill_yujian += 1
	PC.move_speed_bonus += 0.032
	PC.summon_damage_multiplier += 0.05
	_refresh_yujian_summon_bonuses()
	_level_up_action()

func reward_URYujian():
	PC.main_skill_yujian += 1
	PC.move_speed_bonus += 0.04
	PC.summon_damage_multiplier += 0.06
	_refresh_yujian_summon_bonuses()
	_level_up_action()

func reward_Yujian1():
	PC.selected_rewards.append("Yujian1")
	PC.move_speed_bonus += 0.10
	PC.yujian_move_summon_damage_per_10 = 0.02
	PC.yujian_move_summon_damage_cap = 0.20
	PC.faze_summon_level += 2
	_refresh_yujian_summon_bonuses()
	_level_up_action()

func reward_Yujian2():
	PC.selected_rewards.append("Yujian2")
	PC.move_speed_bonus += 0.05
	PC.yujian_interval_reduction_per_level = 0.015
	PC.faze_summon_level += 2
	_refresh_yujian_summon_bonuses()
	_level_up_action()

func reward_Yujian3():
	PC.selected_rewards.append("Yujian3")
	PC.move_speed_bonus += 0.05
	PC.faze_summon_level += 2
	_spawn_yujian_extra_summon(2)
	_sync_yujian_player_state()
	_level_up_action()

func reward_Yujian4():
	PC.selected_rewards.append("Yujian4")
	PC.yujian_level_summon_damage_per_level = 0.015
	PC.faze_summon_level += 2
	_refresh_yujian_summon_bonuses()
	_level_up_action()

func reward_Yujian11():
	PC.selected_rewards.append("Yujian11")
	PC.faze_summon_level += 2
	_spawn_yujian_extra_summon(3)
	_refresh_yujian_summon_bonuses()
	_level_up_action()

func reward_Yujian22():
	PC.selected_rewards.append("Yujian22")
	PC.move_speed_bonus += 0.15
	PC.yujian_move_summon_damage_per_10 = 0.04
	PC.yujian_move_summon_damage_cap = 0.60
	PC.faze_summon_level += 2
	_refresh_yujian_summon_bonuses()
	_level_up_action()

func reward_Yujian33():
	PC.selected_rewards.append("Yujian33")
	PC.yujian_level_summon_damage_per_level = 0.03
	PC.faze_summon_level += 2
	_refresh_yujian_summon_bonuses()
	_level_up_action()

func check_Genshan_condition() -> bool:
	return PC.selected_rewards.has("Genshan")

func check_Genshan_condition1() -> bool:
	return PC.selected_rewards.has("Genshan2") and PC.selected_rewards.has("Genshan4")

func check_Genshan_condition2() -> bool:
	return PC.selected_rewards.has("Genshan1") and PC.selected_rewards.has("Genshan3")

func check_Genshan_condition3() -> bool:
	return PC.selected_rewards.has("Genshan2") and PC.selected_rewards.has("Genshan3")

func reward_Genshan():
	Genshan.reset_data()
	PC.selected_rewards.append("Genshan")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_bagua_level += 3
	PC.faze_shield_level += 3
	_level_up_action()

func reward_RGenshan():
	PC.main_skill_genshan += 1
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.024)
	PC.final_damage_bonus += 0.01
	Genshan.genshan_final_damage_multi += 0.06
	_level_up_action()

func reward_SRGenshan():
	PC.main_skill_genshan += 1
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.028)
	PC.final_damage_bonus += 0.011
	Genshan.genshan_final_damage_multi += 0.07
	_level_up_action()

func reward_SSRGenshan():
	PC.main_skill_genshan += 1
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.032)
	PC.final_damage_bonus += 0.013
	Genshan.genshan_final_damage_multi += 0.08
	_level_up_action()

func reward_URGenshan():
	PC.main_skill_genshan += 1
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.04)
	PC.final_damage_bonus += 0.015
	Genshan.genshan_final_damage_multi += 0.10
	_level_up_action()

func reward_Genshan1():
	PC.selected_rewards.append("Genshan1")
	PC.faze_bagua_level += 2
	PC.faze_shield_level += 2
	# Logic handled in genshan.gd: Up/Down direction, total damage -40%
	_level_up_action()

func reward_Genshan2():
	PC.selected_rewards.append("Genshan2")
	PC.faze_bagua_level += 2
	PC.faze_shield_level += 2
	# Logic handled in genshan.gd: Vulnerable debuff
	_level_up_action()

func reward_Genshan3():
	PC.selected_rewards.append("Genshan3")
	Genshan.genshan_final_damage_multi += 0.10
	PC.faze_bagua_level += 2
	PC.faze_shield_level += 2
	# Logic handled in genshan.gd: Extra damage to Elite/Boss
	_level_up_action()

func reward_Genshan4():
	PC.selected_rewards.append("Genshan4")
	Genshan.genshan_final_damage_multi += 0.10
	PC.faze_bagua_level += 2
	PC.faze_shield_level += 2
	# Logic handled in genshan.gd: Shield amount +40%
	_level_up_action()

func reward_Genshan11():
	PC.selected_rewards.append("Genshan11")
	Genshan.genshan_final_damage_multi += 0.15
	PC.faze_bagua_level += 2
	PC.faze_shield_level += 2
	# Logic handled in genshan.gd: Slow vulnerable enemies
	_level_up_action()

func reward_Genshan22():
	PC.selected_rewards.append("Genshan22")
	PC.faze_bagua_level += 2
	PC.faze_shield_level += 2
	# Logic handled in genshan.gd: Diagonal directions, total damage -35%
	_level_up_action()

func reward_Genshan33():
	PC.selected_rewards.append("Genshan33")
	PC.faze_bagua_level += 2
	PC.faze_shield_level += 2
	# Logic handled in genshan.gd: Extra damage to Vulnerable
	_level_up_action()


func check_Duize_condition() -> bool:
	return PC.selected_rewards.has("Duize")

func check_Duize_condition1() -> bool:
	return PC.selected_rewards.has("Duize1") and PC.selected_rewards.has("Duize4")

func check_Duize_condition2() -> bool:
	return PC.selected_rewards.has("Duize1") and PC.selected_rewards.has("Duize3")

func check_Duize_condition3() -> bool:
	return PC.selected_rewards.has("Duize2") and PC.selected_rewards.has("Duize4")

func reward_Duize():
	Duize.reset_data()
	PC.selected_rewards.append("Duize")
	PC.current_weapon_num += 1
	PC.faze_bagua_level += 3
	PC.faze_wide_level += 3
	_level_up_action()

func reward_RDuize():
	PC.main_skill_duize += 1
	PC.crit_damage_multi += 0.04
	Duize.duize_final_damage_multi += 0.06
	_level_up_action()

func reward_SRDuize():
	PC.main_skill_duize += 1
	PC.crit_damage_multi += 0.045
	Duize.duize_final_damage_multi += 0.07
	_level_up_action()

func reward_SSRDuize():
	PC.main_skill_duize += 1
	PC.crit_damage_multi += 0.05
	Duize.duize_final_damage_multi += 0.08
	_level_up_action()

func reward_URDuize():
	PC.main_skill_duize += 1
	PC.crit_damage_multi += 0.06
	Duize.duize_final_damage_multi += 0.1
	_level_up_action()

func reward_Duize1():
	PC.selected_rewards.append("Duize1")
	PC.faze_bagua_level += 2
	PC.faze_wide_level += 2
	Duize.duize_final_damage_multi += 0.15
	Duize.duize_slow_ratio = 0.30
	_level_up_action()

func reward_Duize2():
	PC.selected_rewards.append("Duize2")
	PC.faze_bagua_level += 2
	PC.faze_wide_level += 2
	Duize.duize_final_damage_multi += 0.1
	# Logic handled in duize.gd: Damage per debuff +30%
	_level_up_action()

func reward_Duize3():
	PC.selected_rewards.append("Duize3")
	PC.faze_bagua_level += 2
	PC.faze_wide_level += 2
	Duize.duize_range += Duize.BASE_RANGE * 0.30
	_level_up_action()

func reward_Duize4():
	PC.selected_rewards.append("Duize4")
	PC.faze_bagua_level += 2
	PC.faze_wide_level += 2
	# Logic handled in duize.gd: Apply Corrosion
	_level_up_action()

func reward_Duize11():
	PC.selected_rewards.append("Duize11")
	PC.faze_bagua_level += 2
	PC.faze_wide_level += 2
	# Logic handled in duize.gd: Corrosion damage bonus from 20% to 30%
	_level_up_action()

func reward_Duize22():
	PC.selected_rewards.append("Duize22")
	PC.faze_bagua_level += 2
	PC.faze_wide_level += 2
	Duize.duize_range += Duize.BASE_RANGE * 0.30 # Extra +30%
	_level_up_action()

func reward_Duize33():
	PC.selected_rewards.append("Duize33")
	PC.faze_bagua_level += 2
	PC.faze_wide_level += 2
	Duize.duize_final_damage_multi += 0.1
	# Logic handled in duize.gd: Damage per debuff +70%
	_level_up_action()

func check_HolyLight_condition() -> bool:
	return PC.selected_rewards.has("HolyLight")

func check_HolyLight_condition1() -> bool:
	return PC.selected_rewards.has("HolyLight1") and PC.selected_rewards.has("HolyLight2")

func check_HolyLight_condition2() -> bool:
	return PC.selected_rewards.has("HolyLight3") and PC.selected_rewards.has("HolyLight4")

func check_HolyLight_condition3() -> bool:
	return PC.selected_rewards.has("HolyLight2") and PC.selected_rewards.has("HolyLight4")

func reward_HolyLight():
	HolyLight.reset_data()
	PC.selected_rewards.append("HolyLight")
	PC.faze_heal_level += 3
	PC.faze_life_level += 3
	PC.current_weapon_num += 1
	# 初始化冷却时间
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get("holy_light_fire_speed"):
		player.holy_light_fire_speed.start()
	_level_up_action()

func reward_RHolyLight():
	PC.main_skill_holylight += 1
	PC.add_attack_percent_bonus(0.024)
	PC.heal_multi += 0.024
	HolyLight.main_skill_holylight_damage += 0.06
	_level_up_action()

func reward_SRHolyLight():
	PC.main_skill_holylight += 1
	PC.add_attack_percent_bonus(0.028)
	PC.heal_multi += 0.028
	HolyLight.main_skill_holylight_damage += 0.07
	_level_up_action()

func reward_SSRHolyLight():
	PC.main_skill_holylight += 1
	PC.add_attack_percent_bonus(0.032)
	PC.heal_multi += 0.032
	HolyLight.main_skill_holylight_damage += 0.08
	_level_up_action()

func reward_URHolyLight():
	PC.main_skill_holylight += 1
	PC.add_attack_percent_bonus(0.04)
	PC.heal_multi += 0.04
	HolyLight.main_skill_holylight_damage += 0.1
	_level_up_action()

func reward_HolyLight1():
	PC.selected_rewards.append("HolyLight1")
	PC.faze_heal_level += 2
	PC.faze_life_level += 2
	HolyLight.main_skill_holylight_damage += 0.1
	HolyLight.holylight_range_scale *= 1.25
	_level_up_action()

func reward_HolyLight2():
	PC.selected_rewards.append("HolyLight2")
	PC.faze_heal_level += 2
	PC.faze_life_level += 2
	HolyLight.main_skill_holylight_damage += 0.1
	HolyLight.holylight_range_scale *= 1.15
	HolyLight.holylight_center_extra_damage += 0.5
	_level_up_action()

func reward_HolyLight3():
	PC.selected_rewards.append("HolyLight3")
	PC.faze_heal_level += 2
	PC.faze_life_level += 2
	HolyLight.main_skill_holylight_damage += 0.15
	HolyLight.holylight_heal_base = 50
	HolyLight.holylight_heal_ratio = 0.045
	_level_up_action()

func reward_HolyLight4():
	PC.selected_rewards.append("HolyLight4")
	PC.faze_heal_level += 2
	PC.faze_life_level += 2
	HolyLight.main_skill_holylight_damage += 0.1
	HolyLight.holylight_range_scale *= 1.15
	HolyLight.holylight_vulnerable_damage_bonus = 1.0
	_level_up_action()

func reward_HolyLight11():
	PC.selected_rewards.append("HolyLight11")
	PC.faze_heal_level += 2
	PC.faze_life_level += 2
	HolyLight.main_skill_holylight_damage += 0.1
	HolyLight.holylight_range_scale *= 1.15
	HolyLight.holylight_center_extra_damage = 1.0
	_level_up_action()

func reward_HolyLight22():
	PC.selected_rewards.append("HolyLight22")
	PC.faze_heal_level += 2
	PC.faze_life_level += 2
	HolyLight.main_skill_holylight_damage += 0.1
	HolyLight.holylight_heal_ratio = 0.06
	_level_up_action()

func reward_HolyLight33():
	PC.selected_rewards.append("HolyLight33")
	PC.faze_heal_level += 2
	PC.faze_life_level += 2
	HolyLight.main_skill_holylight_damage += 0.1
	HolyLight.holylight_range_scale *= 1.15
	HolyLight.holylight_vulnerable_crit = true
	_level_up_action()


# Qigong Functions

func check_Qigong_condition1() -> bool:
	return PC.selected_rewards.has("Qigong3") and PC.selected_rewards.has("Qigong5")

func check_Qigong_condition2() -> bool:
	return PC.selected_rewards.has("Qigong4") and PC.selected_rewards.has("Qigong1")

func check_Qigong_condition3() -> bool:
	return PC.selected_rewards.has("Qigong2") and PC.selected_rewards.has("Qigong4")

func check_Qigong_condition4() -> bool:
	return PC.selected_rewards.has("Qigong1") and PC.selected_rewards.has("Qigong3")

func check_Qigong_condition5() -> bool:
	return PC.selected_rewards.has("Qigong5") and PC.selected_rewards.has("Qigong2")

func reward_Qigong():
	PC.selected_rewards.append("Qigong")
	PC.current_weapon_num += 1
	PC.faze_wind_level += 3
	PC.faze_wide_level += 3
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get("Qigong_fire_speed"):
		player.qigong_fire_speed.start()
	_level_up_action()


# 全局升级效果处理函数 (当选择某些特定被动后，升级时会触发额外属性转换)
func global_level_up():
	# 基础属性成长
	var atk_flat_bonus: int = LEVEL_UP_BASE_ATK_FLAT_BONUS + PC.lingwu_atk_flat_bonus
	PC.add_base_attack_growth(atk_flat_bonus, LEVEL_UP_BASE_ATK_RATE + PC.lingwu_atk_bonus)
	PC.pc_max_hp += 20
	PC.pc_start_max_hp += 20
	PC.pc_hp += 20 # 升级时也恢复一点HP
	# 每级额外提升2%生命上限；体质领悟只强化这段等级成长，避免按总血量重复大幅膨胀。
	var lv_hp_bonus_rate = 0.02 * (1.0 + PC.lingwu_hp_bonus)
	var lv_hp_bonus = int(PC.pc_start_max_hp * lv_hp_bonus_rate)
	PC.pc_max_hp += lv_hp_bonus
	PC.pc_start_max_hp += lv_hp_bonus

	# 蓄积(UR53)效果：每次升级额外+5%攻击
	if PC.xuji_remaining > 0:
		PC.add_attack_percent_bonus(0.05)
		PC.xuji_remaining -= 1

	# 每级护甲+1
	PC.pc_armor += 1
	# 护御领悟：每级额外护甲
	if PC.lingwu_armor_bonus > 0:
		PC.pc_armor += PC.lingwu_armor_bonus

	# 敏捷领悟：每级额外攻速
	if PC.lingwu_atk_speed_bonus > 0:
		PC.attack_speed_bonus += PC.lingwu_atk_speed_bonus
	# 速度领悟：每级额外移速
	if PC.lingwu_speed_bonus > 0:
		PC.move_speed_bonus += PC.lingwu_speed_bonus
	# 威压领悟：每级额外最终伤害
	if PC.lingwu_final_dmg_bonus > 0:
		PC.final_damage_bonus += PC.lingwu_final_dmg_bonus
	# 天命领悟：每级额外天命（根据类型不同计算）
	# R71：每4级+1 → 当前等级是4的倍数时+1
	# SR71：每3级+1 → 当前等级是3的倍数时+1
	# SSR71：每2级+1 → 当前等级是2的倍数时+1
	if PC.selected_rewards.has("R71"):
		if PC.pc_lv % 4 == 0:
			_add_lucky_level(1)
	if PC.selected_rewards.has("SR71"):
		if PC.pc_lv % 3 == 0:
			_add_lucky_level(1)
	if PC.selected_rewards.has("SSR71"):
		if PC.pc_lv % 2 == 0:
			_add_lucky_level(1)

	# 更新上次属性记录，用于下次比较变化
	PC.last_lunky_level = PC.now_lunky_level
	PC.last_speed = PC.move_speed_bonus
	PC.last_atk_speed = PC.attack_speed_bonus

	# 处理生命恢复效果 (基于 "hpRecover" 标记的数量)
	var recoverUp = PC.selected_rewards.count("hpRecover") # 获取 "hpRecover" 标记的数量
	var recoverNum = (0.1 + recoverUp * 0.05) * PC.pc_max_hp # 基础恢复10%HP，每多一个标记额外恢复5%HP
	# 修习树特殊篇：升级回复体力量提升
	recoverNum *= (1.0 + Global.study_levelup_heal_bonus)
	if PC.pc_hp + recoverNum > PC.pc_max_hp: # 如果恢复后超过HP上限
		PC.pc_hp = PC.pc_max_hp # 则设置为HP上限
	else:
		PC.pc_hp += int(recoverNum) # 否则直接增加恢复量

	# 修习树特殊篇：升级后额外提升攻击和HP
	if Global.study_levelup_atk_bonus > 0:
		PC.add_base_attack_growth(Global.study_levelup_atk_bonus, 0.0)
	if Global.study_levelup_hp_bonus > 0:
		PC.pc_max_hp += Global.study_levelup_hp_bonus
		PC.pc_start_max_hp += Global.study_levelup_hp_bonus
		PC.pc_hp += Global.study_levelup_hp_bonus
	if PC.xianqi_points > 0:
		_apply_xianqi_attribute_bonus()

func reward_Six1():
	PC.selected_rewards.append("Six1")
	PC.faze_sixsense_level += 1
	PC.crit_chance += 0.06
	PC.sixsense_base_crit_chance += 0.06
	_level_up_action()

func reward_Six2():
	PC.selected_rewards.append("Six2")
	PC.faze_sixsense_level += 1
	PC.crit_damage_multi += 0.12
	PC.sixsense_base_crit_damage_multi += 0.12
	_level_up_action()

func reward_Six3():
	PC.selected_rewards.append("Six3")
	PC.faze_sixsense_level += 1
	PC.final_damage_bonus += 0.06
	PC.sixsense_base_final_damage += 0.06
	_level_up_action()

func reward_Six4():
	PC.selected_rewards.append("Six4")
	PC.faze_sixsense_level += 1
	PC.attack_speed_bonus += 0.08
	PC.sixsense_base_atk_speed += 0.08
	_level_up_action()

func reward_Six5():
	PC.selected_rewards.append("Six5")
	PC.faze_sixsense_level += 1
	PC.damage_reduction_rate += 0.04
	PC.sixsense_base_damage_reduction += 0.04
	_level_up_action()

func reward_Six6():
	PC.selected_rewards.append("Six6")
	PC.faze_sixsense_level += 1
	PC.sixsense_base_atk += 0.06
	_level_up_action()

func check_have_Debuff() -> bool:
	if PC.selected_rewards.has("Bloodwave1"): return true
	if PC.selected_rewards.has("BloodBoardSword"): return true
	if PC.selected_rewards.has("RingFire4"): return true
	if PC.selected_rewards.has("Moyan"): return true
	if PC.selected_rewards.has("ThunderBreak3"): return true
	if PC.selected_rewards.has("Xuanwu4"): return true
	if PC.selected_rewards.has("ThunderBreak33"): return true
	if PC.selected_rewards.has("Genshan2"): return true
	if PC.selected_rewards.has("Qigong1"): return true
	if PC.selected_rewards.has("SplitSwordQi21"): return true
	if PC.selected_rewards.has("Water2"): return true
	if PC.selected_rewards.has("DragonWind4"): return true
	if PC.selected_rewards.has("Xuanwu3"): return true
	return false

func check_have_slow() -> bool:
	if PC.selected_rewards.has("SplitSwordQi21"): return true
	if PC.selected_rewards.has("Water2"): return true
	if PC.selected_rewards.has("DragonWind4"): return true
	if PC.selected_rewards.has("Xuanwu3"): return true
	return false

func check_have_electrification() -> bool:
	if PC.selected_rewards.has("ThunderBreak3"): return true
	if PC.selected_rewards.has("Qigong1"): return true
	return false

func check_have_vulnerable() -> bool:
	if PC.selected_rewards.has("Genshan2"): return true
	if PC.selected_rewards.has("ThunderBreak33"): return true
	return false

func check_have_vulnerability() -> bool:
	if PC.selected_rewards.has("Xuanwu4"): return true
	return false

func check_have_fire() -> bool:
	if PC.selected_rewards.has("RingFire4"): return true
	if PC.selected_rewards.has("Moyan"): return true
	return false

func check_have_bleed() -> bool:
	if PC.selected_rewards.has("Bloodwave1"): return true
	if PC.selected_rewards.has("BloodBoardSword"): return true
	return false

func check_have_two_hell_debuffs() -> bool:
	var debuff_type_count := 0
	if check_have_bleed():
		debuff_type_count += 1
	if check_have_electrification():
		debuff_type_count += 1
	if check_have_fire():
		debuff_type_count += 1
	return debuff_type_count >= 2

func reward_R33():
	PC.selected_rewards.append("R33")
	_level_up_action()

func reward_SR33():
	PC.selected_rewards.append("SR33")
	_level_up_action()

func reward_SSR33():
	PC.selected_rewards.append("SSR33")
	_level_up_action()

func reward_R34():
	PC.selected_rewards.append("R34")
	_level_up_action()

func reward_SR34():
	PC.selected_rewards.append("SR34")
	_level_up_action()

func reward_SSR34():
	PC.selected_rewards.append("SSR34")
	_level_up_action()

func reward_R35():
	PC.selected_rewards.append("R35")
	_level_up_action()

func reward_SR35():
	PC.selected_rewards.append("SR35")
	_level_up_action()

func reward_SSR35():
	PC.selected_rewards.append("SSR35")
	_level_up_action()

func reward_R36():
	PC.selected_rewards.append("R36")
	PC.faze_sword_level += 1
	_add_faze_weapon_upgrade_bonus("sword")
	_level_up_action()

func reward_SR36():
	PC.selected_rewards.append("SR36")
	PC.faze_sword_level += 1
	_add_faze_weapon_upgrade_bonus("sword")
	_level_up_action()

func reward_SSR36():
	PC.selected_rewards.append("SSR36")
	PC.faze_sword_level += 1
	_add_faze_weapon_upgrade_bonus("sword")
	_level_up_action()

func reward_R37():
	PC.selected_rewards.append("R37")
	PC.faze_blood_level += 1
	_add_faze_weapon_upgrade_bonus("blood")
	_level_up_action()

func reward_SR37():
	PC.selected_rewards.append("SR37")
	PC.faze_blood_level += 1
	_add_faze_weapon_upgrade_bonus("blood")
	_level_up_action()

func reward_SSR37():
	PC.selected_rewards.append("SSR37")
	PC.faze_blood_level += 1
	_add_faze_weapon_upgrade_bonus("blood")
	_level_up_action()

func reward_R38():
	PC.selected_rewards.append("R38")
	PC.faze_thunder_level += 1
	_add_faze_weapon_upgrade_bonus("thunder")
	_level_up_action()

func reward_SR38():
	PC.selected_rewards.append("SR38")
	PC.faze_thunder_level += 1
	_add_faze_weapon_upgrade_bonus("thunder")
	_level_up_action()

func reward_SSR38():
	PC.selected_rewards.append("SSR38")
	PC.faze_thunder_level += 1
	_add_faze_weapon_upgrade_bonus("thunder")
	_level_up_action()

func reward_R38a():
	PC.selected_rewards.append("R38a")
	PC.faze_fire_level += 1
	_add_faze_weapon_upgrade_bonus("fire")
	_level_up_action()

func reward_SR38a():
	PC.selected_rewards.append("SR38a")
	PC.faze_fire_level += 1
	_add_faze_weapon_upgrade_bonus("fire")
	_level_up_action()

func reward_SSR38a():
	PC.selected_rewards.append("SSR38a")
	PC.faze_fire_level += 1
	_add_faze_weapon_upgrade_bonus("fire")
	_level_up_action()

func reward_R39():
	PC.selected_rewards.append("R39")
	PC.final_damage_bonus += 0.07
	# 敌人数量增加逻辑需在刷怪脚本中处理
	_level_up_action()

func reward_SR39():
	PC.selected_rewards.append("SR39")
	PC.final_damage_bonus += 0.08
	_level_up_action()

func reward_SSR39():
	PC.selected_rewards.append("SSR39")
	PC.final_damage_bonus += 0.09
	_level_up_action()

func reward_R40():
	PC.selected_rewards.append("R40")
	_level_up_action()

func reward_SR40():
	PC.selected_rewards.append("SR40")
	_level_up_action()

func reward_SSR40():
	PC.selected_rewards.append("SSR40")
	_level_up_action()

func reward_R41():
	PC.exp_multi += 0.20
	PC.faze_life_level += 1
	_add_faze_weapon_upgrade_bonus("life")
	_level_up_action()

func reward_SR41():
	PC.exp_multi += 0.22
	PC.faze_life_level += 1
	_add_faze_weapon_upgrade_bonus("life")
	_level_up_action()

func reward_SSR41():
	PC.exp_multi += 0.24
	PC.faze_life_level += 1
	_add_faze_weapon_upgrade_bonus("life")
	_level_up_action()

func reward_UR42():
	# 疾风迅雷：15%攻击力 + 攻速加成10%的暴击率 + 移速加成30%的暴击伤害
	PC.add_attack_percent_bonus(0.15)
	PC.crit_chance += min(PC.attack_speed_bonus * 0.10, 0.15)
	PC.crit_damage_multi += min(PC.move_speed_bonus * 0.30, 0.45)
	_level_up_action()

func reward_UR43():
	# 梦玉成真：15天命 + 12%攻击力 + 12%攻击速度 + 12%体力上限
	_add_lucky_level(15)
	PC.add_attack_percent_bonus(0.12)
	PC.attack_speed_bonus += 0.12
	PC.pc_max_hp = int(PC.pc_max_hp * 1.12)
	_level_up_action()

func reward_UR44():
	# 已至极境：25%最终伤害 + 30护甲 + 12%减伤率
	PC.final_damage_bonus += 0.25
	PC.pc_armor += 30
	PC.damage_reduction_rate += 0.12
	_level_up_action()

func reward_UR45():
	# 混沌之力：全部法则层数之和，每层+0.2%攻击、+0.15%攻速、+0.1%最终伤害、+0.05%减伤率
	var total_faze = PC.faze_blood_level + PC.faze_sword_level + PC.faze_thunder_level + PC.faze_heal_level + PC.faze_summon_level + PC.faze_shield_level + PC.faze_fire_level + PC.faze_destroy_level + PC.faze_life_level + PC.faze_bullet_level + PC.faze_wide_level + PC.faze_bagua_level + PC.faze_treasure_level + PC.faze_chaos_level + PC.faze_skill_level + PC.faze_sixsense_level + PC.faze_wind_level + PC.faze_shehun_level
	PC.add_attack_percent_bonus(total_faze * 0.002)
	PC.attack_speed_bonus += total_faze * 0.0015
	PC.final_damage_bonus += total_faze * 0.001
	PC.damage_reduction_rate += total_faze * 0.0005
	_level_up_action()

func reward_NoAdvance():
	PC.pc_atk += 20
	PC.add_attack_percent_bonus(0.05)
	_level_up_action()

func reward_R42():
	PC.add_attack_percent_bonus(0.09)
	PC.pc_max_hp = int(PC.pc_max_hp * 0.96)
	PC.pc_start_max_hp = int(PC.pc_start_max_hp * 0.96)
	_level_up_action()

func reward_R43():
	PC.damage_reduction_rate = min(PC.damage_reduction_rate + 0.03, 0.7)
	PC.final_damage_bonus -= 0.01
	_level_up_action()

func reward_R44():
	PC.move_speed_bonus += 0.15
	PC.damage_reduction_rate = max(PC.damage_reduction_rate - 0.01, 0.0)
	PC.faze_wind_level += 1
	_add_faze_weapon_upgrade_bonus("wind")
	_level_up_action()

func reward_R45():
	PC.sheild_multi += 0.12
	PC.move_speed_bonus -= 0.04
	PC.faze_shield_level += 1
	_add_faze_weapon_upgrade_bonus("shield")
	_level_up_action()

func reward_R46():
	# 疗愈：治疗提升+12%，额外+1级愈疗法则
	PC.heal_multi += 0.12
	PC.move_speed_bonus -= 0.04
	PC.faze_heal_level += 1
	_add_faze_weapon_upgrade_bonus("heal")
	_level_up_action()

func reward_R47():
	PC.final_damage_bonus += 0.05
	PC.enemy_move_speed_multiplier += 0.05
	_level_up_action()

# ================= R42-R47 SR/SSR 升级 =================

func reward_SR42():
	PC.add_attack_percent_bonus(0.13)
	PC.pc_max_hp = int(PC.pc_max_hp * 0.97)
	PC.pc_start_max_hp = int(PC.pc_start_max_hp * 0.97)
	_level_up_action()

func reward_SSR42():
	PC.add_attack_percent_bonus(0.19)
	PC.pc_max_hp = int(PC.pc_max_hp * 0.96)
	PC.pc_start_max_hp = int(PC.pc_start_max_hp * 0.96)
	_level_up_action()

func reward_SR43():
	PC.damage_reduction_rate = min(PC.damage_reduction_rate + 0.03, 0.7)
	PC.pc_max_hp = int(PC.pc_max_hp * 0.99)
	PC.pc_start_max_hp = int(PC.pc_start_max_hp * 0.99)
	_level_up_action()

func reward_SSR43():
	PC.damage_reduction_rate = min(PC.damage_reduction_rate + 0.05, 0.7)
	PC.final_damage_bonus -= 0.02
	_level_up_action()

func reward_SR44():
	PC.move_speed_bonus += 0.15
	PC.damage_reduction_rate = max(PC.damage_reduction_rate - 0.01, 0.0)
	PC.faze_wind_level += 1
	_add_faze_weapon_upgrade_bonus("wind")
	_level_up_action()

func reward_SSR44():
	PC.move_speed_bonus += 0.24
	PC.damage_reduction_rate = max(PC.damage_reduction_rate - 0.02, 0.0)
	PC.faze_wind_level += 1
	_add_faze_weapon_upgrade_bonus("wind")
	_level_up_action()

func reward_SR45():
	# 保佑：护盾获取率+12%，额外+1级护佑法则
	PC.sheild_multi += 0.12
	PC.move_speed_bonus -= 0.06
	PC.faze_shield_level += 1
	_add_faze_weapon_upgrade_bonus("shield")
	_level_up_action()

func reward_SSR45():
	# 保佑：护盾获取率+18%，额外+1级护佑法则
	PC.sheild_multi += 0.18
	PC.move_speed_bonus -= 0.08
	PC.faze_shield_level += 1
	_add_faze_weapon_upgrade_bonus("shield")
	_level_up_action()

func reward_SR46():
	# 疗愈：治疗提升+12%，额外+1级愈疗法则
	PC.heal_multi += 0.12
	PC.move_speed_bonus -= 0.06
	PC.faze_heal_level += 1
	_add_faze_weapon_upgrade_bonus("heal")
	_level_up_action()

func reward_SSR46():
	# 疗愈：治疗提升+18%，额外+1级愈疗法则
	PC.heal_multi += 0.18
	PC.move_speed_bonus -= 0.08
	PC.faze_heal_level += 1
	_add_faze_weapon_upgrade_bonus("heal")
	_level_up_action()

func reward_SR47():
	PC.final_damage_bonus += 0.07
	PC.enemy_move_speed_multiplier += 0.04
	_level_up_action()

func reward_SSR47():
	PC.final_damage_bonus += 0.09
	PC.enemy_move_speed_multiplier += 0.05
	_level_up_action()

# ================= R48-SSR58 新系列 =================

func reward_R48():
	PC.selected_rewards.append("R48")
	PC.enemy_hp_multiplier += 0.05
	_level_up_action()

func reward_SR48():
	PC.selected_rewards.append("SR48")
	PC.enemy_hp_multiplier += 0.04
	_level_up_action()

func reward_SSR48():
	PC.selected_rewards.append("SSR48")
	PC.enemy_hp_multiplier += 0.03
	_level_up_action()

func reward_R49():
	PC.selected_rewards.append("R49")
	PC.enemy_move_speed_multiplier += 0.06
	_level_up_action()

func reward_SR49():
	PC.selected_rewards.append("SR49")
	PC.enemy_move_speed_multiplier += 0.07
	_level_up_action()

func reward_SSR49():
	PC.selected_rewards.append("SSR49")
	PC.enemy_move_speed_multiplier += 0.08
	_level_up_action()

func reward_R50():
	PC.selected_rewards.append("R50")
	PC.enemy_damage_multiplier += 0.05
	_level_up_action()

func reward_SR50():
	PC.selected_rewards.append("SR50")
	PC.enemy_damage_multiplier += 0.04
	_level_up_action()

func reward_SSR50():
	PC.selected_rewards.append("SSR50")
	PC.enemy_damage_multiplier += 0.03
	_level_up_action()

func reward_R51():
	PC.damage_reduction_rate = min(PC.damage_reduction_rate + 0.025, 0.7)
	PC.move_speed_bonus -= 0.05
	_level_up_action()

func reward_SR51():
	PC.damage_reduction_rate = min(PC.damage_reduction_rate + 0.03, 0.7)
	PC.move_speed_bonus -= 0.06
	_level_up_action()

func reward_SSR51():
	PC.damage_reduction_rate = min(PC.damage_reduction_rate + 0.04, 0.7)
	PC.move_speed_bonus -= 0.07
	_level_up_action()

func reward_R52():
	PC.final_damage_bonus += 0.05
	PC.enemy_move_speed_multiplier += 0.05
	_level_up_action()

func reward_SR52():
	PC.final_damage_bonus += 0.07
	PC.enemy_move_speed_multiplier += 0.04
	_level_up_action()

func reward_SSR52():
	PC.final_damage_bonus += 0.09
	PC.enemy_move_speed_multiplier += 0.06
	_level_up_action()

func reward_R53():
	PC.selected_rewards.append("R53")
	PC.add_attack_percent_bonus(0.07)
	_level_up_action()

func reward_SR53():
	PC.selected_rewards.append("SR53")
	PC.add_attack_percent_bonus(0.09)
	_level_up_action()

func reward_SSR53():
	PC.selected_rewards.append("SSR53")
	PC.add_attack_percent_bonus(0.12)
	_level_up_action()

func reward_R54():
	PC.selected_rewards.append("R54")
	PC.enemy_hp_multiplier += 0.03
	_add_lucky_level(5)
	_level_up_action()

func reward_SR54():
	PC.selected_rewards.append("SR54")
	PC.enemy_hp_multiplier += 0.03
	_add_lucky_level(6)
	_level_up_action()

func reward_SSR54():
	PC.selected_rewards.append("SSR54")
	PC.enemy_hp_multiplier += 0.03
	_add_lucky_level(8)
	_level_up_action()

func reward_R55():
	PC.move_speed_bonus += 0.16
	PC.add_attack_percent_bonus(-0.04)
	_level_up_action()

func reward_SR55():
	PC.move_speed_bonus += 0.24
	PC.add_attack_percent_bonus(-0.06)
	_level_up_action()

func reward_SSR55():
	PC.move_speed_bonus += 0.35
	PC.add_attack_percent_bonus(-0.09)
	_level_up_action()

func reward_R56():
	PC.add_attack_percent_bonus(0.11)
	PC.attack_speed_bonus += 0.05
	PC.pc_max_hp = int(PC.pc_max_hp * 0.95)
	PC.pc_start_max_hp = int(PC.pc_start_max_hp * 0.95)
	_level_up_action()

func reward_SR56():
	PC.add_attack_percent_bonus(0.13)
	PC.attack_speed_bonus += 0.06
	PC.pc_max_hp = int(PC.pc_max_hp * 0.94)
	PC.pc_start_max_hp = int(PC.pc_start_max_hp * 0.94)
	_level_up_action()

func reward_SSR56():
	PC.add_attack_percent_bonus(0.16)
	PC.attack_speed_bonus += 0.09
	PC.pc_max_hp = int(PC.pc_max_hp * 0.92)
	PC.pc_start_max_hp = int(PC.pc_start_max_hp * 0.92)
	_level_up_action()

func reward_R57():
	PC.pc_armor += 16
	PC.move_speed_bonus -= 0.06
	_level_up_action()

func reward_SR57():
	PC.pc_armor += 22
	PC.move_speed_bonus -= 0.08
	_level_up_action()

func reward_SSR57():
	PC.pc_armor += 32
	PC.move_speed_bonus -= 0.11
	_level_up_action()

func reward_R58():
	PC.attack_speed_bonus += 0.09
	PC.move_speed_bonus -= 0.05
	PC.faze_bullet_level += 1
	_add_faze_weapon_upgrade_bonus("bullet")
	_level_up_action()

func reward_SR58():
	PC.attack_speed_bonus += 0.13
	PC.move_speed_bonus -= 0.07
	PC.faze_bullet_level += 1
	_add_faze_weapon_upgrade_bonus("bullet")
	_level_up_action()

func reward_SSR58():
	PC.attack_speed_bonus += 0.18
	PC.move_speed_bonus -= 0.09
	PC.faze_bullet_level += 1
	_add_faze_weapon_upgrade_bonus("bullet")
	_level_up_action()

# ================= 行修系列（金色buff型） =================

func reward_SSR59():
	# 行修·悟：每移动4000距离，经验获取率+1%
	PC.selected_rewards.append("SSR59")
	PC.distance_buff_offsets["SSR59"] = PC.world_pixels_to_distance_steps(PC.total_distance_moved)
	_level_up_action()

func reward_SSR60():
	# 行修·缘：每移动4000距离，治愈精华掉落率+1%
	PC.selected_rewards.append("SSR60")
	PC.distance_buff_offsets["SSR60"] = PC.world_pixels_to_distance_steps(PC.total_distance_moved)
	_level_up_action()

# ================= 仙气凝聚系列 =================

func reward_R61():
	_apply_xianqi_condense("R61", 6)

func reward_SR61():
	_apply_xianqi_condense("SR61", 8)

func reward_SSR61():
	_apply_xianqi_condense("SSR61", 12)

func _apply_xianqi_condense(reward_id: String, layers: int) -> void:
	PC.selected_rewards.append(reward_id)
	PC.xianqi_points += layers
	_refresh_xianqi_buff()
	_apply_xianqi_attribute_bonus()
	_check_xianli_activation_reward()
	_level_up_action()

func _check_xianli_activation_reward():
	if PC.xianqi_points >= 100 and not PC.xianli_active:
		PC.xianli_active = true
		Global.emit_signal("buff_added", "xianli", 0.0, 1)

func _refresh_xianqi_buff() -> void:
	var stack = PC.xianqi_points
	if BuffManager.has_buff("xianqi"):
		Global.emit_signal("buff_stack_changed", "xianqi", stack)
	else:
		Global.emit_signal("buff_added", "xianqi", 0.0, stack)

func _get_xianqi_bonus_multiplier(layers: int) -> float:
	if layers >= 100:
		return 5.0
	if layers >= 30:
		return 3.0
	return 1.0

func _apply_xianqi_attribute_bonus() -> void:
	var layers := PC.xianqi_points
	var multiplier := _get_xianqi_bonus_multiplier(layers)
	var target_final_damage_bonus := float(layers) * 0.004 * multiplier
	var final_damage_delta := target_final_damage_bonus - PC.xianqi_final_damage_applied_bonus
	if not is_equal_approx(final_damage_delta, 0.0):
		PC.final_damage_bonus += final_damage_delta
		PC.xianqi_final_damage_applied_bonus = target_final_damage_bonus
	var target_hp_bonus := float(layers) * 0.002 * multiplier
	var target_hp_bonus_value := float(int(round(float(PC.pc_start_max_hp) * target_hp_bonus)))
	var hp_delta := int(round(target_hp_bonus_value - PC.xianqi_hp_applied_bonus))
	if hp_delta != 0:
		PC.pc_max_hp += hp_delta
		if hp_delta > 0:
			PC.pc_hp += hp_delta
		if PC.pc_hp > PC.pc_max_hp:
			PC.pc_hp = PC.pc_max_hp
		PC.xianqi_hp_applied_bonus = target_hp_bonus_value

# ================= 延域系列（射程提升） =================

func reward_R62():
	PC.add_attack_range(0.02)
	PC.attack_speed_bonus += 0.04
	PC.move_speed_bonus -= 0.04
	PC.faze_wide_level += 1
	_add_faze_weapon_upgrade_bonus("wide")
	_level_up_action()

func reward_SR62():
	PC.add_attack_range(0.03)
	PC.attack_speed_bonus += 0.06
	PC.move_speed_bonus -= 0.05
	PC.faze_wide_level += 1
	_add_faze_weapon_upgrade_bonus("wide")
	_level_up_action()

func reward_SSR62():
	PC.add_attack_range(0.05)
	PC.attack_speed_bonus += 0.08
	PC.move_speed_bonus -= 0.06
	PC.faze_wide_level += 1
	_add_faze_weapon_upgrade_bonus("wide")
	_level_up_action()

# ================= 天道碎片 =================

func _check_tiandao_fusion():
	# 检查是否已集齐三块天道碎片，触发融合
	if PC.selected_rewards.has("UR46") and PC.selected_rewards.has("UR47") and PC.selected_rewards.has("UR48"):
		# 移除三个碎片 buff，替换为得道 buff
		Global.emit_signal("buff_removed", "tiandao_1")
		Global.emit_signal("buff_removed", "tiandao_2")
		Global.emit_signal("buff_removed", "tiandao_3")
		# 添加得道 buff（永久）
		Global.emit_signal("buff_added", "dedao", 0.0, 1)
		# 应用得道属性加成（扣掉碎片已给的基础值，补足得道值）
		# 天道碎片已给：最终伤害+8%，体力上限+12%，减伤+5%
		# 得道总值：最终伤害+100%，体力+150%，减伤+70%
		# 追加差值：最终伤害+92%，体力+138%，减伤+65%
		PC.final_damage_bonus += 0.92
		PC.pc_max_hp = int(PC.pc_max_hp * 2.38) # 当前基础乘以(1+1.38)，即额外+138%
		PC.damage_reduction_rate = min(PC.damage_reduction_rate + 0.65, 0.95)

func reward_UR46():
	# 天道碎片·一：最终伤害+8%，获得碎片buff
	PC.selected_rewards.append("UR46")
	PC.final_damage_bonus += 0.08
	Global.emit_signal("buff_added", "tiandao_1", 0.0, 1)
	_check_tiandao_fusion()
	_level_up_action()

func reward_UR47():
	# 天道碎片·二：体力上限+12%，获得碎片buff
	PC.selected_rewards.append("UR47")
	PC.pc_max_hp = int(PC.pc_max_hp * 1.12)
	Global.emit_signal("buff_added", "tiandao_2", 0.0, 1)
	_check_tiandao_fusion()
	_level_up_action()

func reward_UR48():
	# 天道碎片·三：减伤率+5%，获得碎片buff
	PC.selected_rewards.append("UR48")
	PC.damage_reduction_rate = min(PC.damage_reduction_rate + 0.05, 0.95)
	Global.emit_signal("buff_added", "tiandao_3", 0.0, 1)
	_check_tiandao_fusion()
	_level_up_action()

func check_not_have_UR46() -> bool:
	return not PC.selected_rewards.has("UR46")

func check_not_have_UR47() -> bool:
	return not PC.selected_rewards.has("UR47")

func check_not_have_UR48() -> bool:
	return not PC.selected_rewards.has("UR48")

# ================= UR49-UR54 =================

func check_chaos_level_above_3() -> bool:
	return Faze.get_current_chaos_level() >= 5

func reward_UR49():
	# 混沌干预：层数最高的两个法则（不含混沌）各减2层，将9层随机分配给已拥有的其他法则（不含混沌/六识）
	PC.selected_rewards.append("UR49")
	var faze_vars = [
		["faze_blood_level", PC.faze_blood_level],
		["faze_sword_level", PC.faze_sword_level],
		["faze_thunder_level", PC.faze_thunder_level],
		["faze_heal_level", PC.faze_heal_level],
		["faze_summon_level", PC.faze_summon_level],
		["faze_shield_level", PC.faze_shield_level],
		["faze_fire_level", PC.faze_fire_level],
		["faze_destroy_level", PC.faze_destroy_level],
		["faze_life_level", PC.faze_life_level],
		["faze_bullet_level", PC.faze_bullet_level],
		["faze_wide_level", PC.faze_wide_level],
		["faze_bagua_level", PC.faze_bagua_level],
		["faze_treasure_level", PC.faze_treasure_level],
		["faze_skill_level", PC.faze_skill_level],
		["faze_sixsense_level", PC.faze_sixsense_level],
		["faze_wind_level", PC.faze_wind_level],
		["faze_shehun_level", PC.faze_shehun_level],
	]
	# 按层数降序排列
	faze_vars.sort_custom(func(a, b): return a[1] > b[1])
	# 最高的两个法则各减2层
	for i in range(min(2, faze_vars.size())):
		var var_name = faze_vars[i][0]
		var current_val = PC.get(var_name)
		var reduction = min(2, current_val)
		PC.set(var_name, current_val - reduction)
	# 将9层随机分配给其他法则，排除最高的两个、六识，以及未拥有的法则
	var other_vars = []
	for i in range(2, faze_vars.size()):
		var var_name = faze_vars[i][0]
		if var_name == "faze_sixsense_level":
			continue
		if PC.get(var_name) <= 0:
			continue
		other_vars.append(faze_vars[i])
	for _j in range(9):
		if other_vars.is_empty():
			break
		var idx = randi() % other_vars.size()
		var var_name = other_vars[idx][0]
		PC.set(var_name, PC.get(var_name) + 1)
		other_vars[idx][1] = PC.get(var_name) # 更新缓存值
	_level_up_action()

func reward_UR50():
	# 法则干预：层数最高的三个法则额外获得2层法则层数
	PC.selected_rewards.append("UR50")
	var faze_vars = [
		["faze_blood_level", PC.faze_blood_level],
		["faze_sword_level", PC.faze_sword_level],
		["faze_thunder_level", PC.faze_thunder_level],
		["faze_heal_level", PC.faze_heal_level],
		["faze_summon_level", PC.faze_summon_level],
		["faze_shield_level", PC.faze_shield_level],
		["faze_fire_level", PC.faze_fire_level],
		["faze_destroy_level", PC.faze_destroy_level],
		["faze_life_level", PC.faze_life_level],
		["faze_bullet_level", PC.faze_bullet_level],
		["faze_wide_level", PC.faze_wide_level],
		["faze_bagua_level", PC.faze_bagua_level],
		["faze_treasure_level", PC.faze_treasure_level],
		["faze_skill_level", PC.faze_skill_level],
		["faze_sixsense_level", PC.faze_sixsense_level],
		["faze_wind_level", PC.faze_wind_level],
		["faze_shehun_level", PC.faze_shehun_level],
	]
	faze_vars.sort_custom(func(a, b): return a[1] > b[1])
	for i in range(min(3, faze_vars.size())):
		var var_name = faze_vars[i][0]
		PC.set(var_name, PC.get(var_name) + 2)
	_level_up_action()

func reward_UR51():
	# 十八层：流血/感电/灼烧伤害+150%；有其中一种异常时，受到其他两异常伤害+150%（加算）
	PC.selected_rewards.append("UR51")
	PC.bleed_damage_multi += 1.5
	PC.electrification_damage_multi += 1.5
	PC.fire_damage_multi += 1.5
	PC.debuff_cross_damage_multi += 1.5
	_level_up_action()

func reward_UR52():
	PC.selected_rewards.append("UR52")
	PC.crit_chance += 0.30
	PC.crit_damage_multi -= 0.15
	_level_up_action()

func reward_UR53():
	PC.selected_rewards.append("UR53")
	PC.add_attack_percent_bonus(-0.05)
	PC.xuji_remaining += 5
	_level_up_action()

func reward_UR54():
	# 弃甲狂攻：减伤率-10%，最终伤害+66%
	PC.selected_rewards.append("UR54")
	PC.damage_reduction_rate = max(PC.damage_reduction_rate - 0.10, 0.0)
	PC.final_damage_bonus += 0.66
	_level_up_action()

# ================= R63-SSR70 领悟系列 =================

# 力量领悟：因等级提升获取的攻击提升
func reward_R63():
	PC.selected_rewards.append("R63")
	PC.lingwu_atk_flat_bonus += 3
	PC.lingwu_atk_bonus += 0.002
	_level_up_action()

func reward_SR63():
	PC.selected_rewards.append("SR63")
	PC.lingwu_atk_flat_bonus += 5
	PC.lingwu_atk_bonus += 0.0025
	_level_up_action()

func reward_SSR63():
	PC.selected_rewards.append("SSR63")
	PC.lingwu_atk_flat_bonus += 10
	PC.lingwu_atk_bonus += 0.003
	_level_up_action()

# 体质领悟：因等级提升获取的体力上限提升
func reward_R64():
	PC.selected_rewards.append("R64")
	PC.lingwu_hp_bonus += 0.15
	_level_up_action()

func reward_SR64():
	PC.selected_rewards.append("SR64")
	PC.lingwu_hp_bonus += 0.19
	_level_up_action()

func reward_SSR64():
	PC.selected_rewards.append("SSR64")
	PC.lingwu_hp_bonus += 0.26
	_level_up_action()

# 敏捷领悟：每升一级额外获取攻速
func reward_R65():
	PC.selected_rewards.append("R65")
	PC.lingwu_atk_speed_bonus += 0.015
	_level_up_action()

func reward_SR65():
	PC.selected_rewards.append("SR65")
	PC.lingwu_atk_speed_bonus += 0.018
	_level_up_action()

func reward_SSR65():
	PC.selected_rewards.append("SSR65")
	PC.lingwu_atk_speed_bonus += 0.025
	_level_up_action()

# 速度领悟：每升一级额外获取移速
func reward_R66():
	PC.selected_rewards.append("R66")
	PC.lingwu_speed_bonus += 0.02
	_level_up_action()

func reward_SR66():
	PC.selected_rewards.append("SR66")
	PC.lingwu_speed_bonus += 0.025
	_level_up_action()

func reward_SSR66():
	PC.selected_rewards.append("SSR66")
	PC.lingwu_speed_bonus += 0.033
	_level_up_action()

# 威压领悟：每升一级额外获取最终伤害
func reward_R67():
	PC.selected_rewards.append("R67")
	PC.lingwu_final_dmg_bonus += 0.012
	_level_up_action()

func reward_SR67():
	PC.selected_rewards.append("SR67")
	PC.lingwu_final_dmg_bonus += 0.014
	_level_up_action()

func reward_SSR67():
	PC.selected_rewards.append("SSR67")
	PC.lingwu_final_dmg_bonus += 0.017
	_level_up_action()

# 铸匠之魂：最终伤害+5%/7%/10%，武器升级概率+15%/20%/25%
func reward_R68():
	PC.selected_rewards.append("R68")
	PC.final_damage_bonus += 0.05
	PC.lingwu_weapon_upgrade_bonus += 0.15
	_level_up_action()

func reward_SR68():
	PC.selected_rewards.append("SR68")
	PC.final_damage_bonus += 0.07
	PC.lingwu_weapon_upgrade_bonus += 0.20
	_level_up_action()

func reward_SSR68():
	PC.selected_rewards.append("SSR68")
	PC.final_damage_bonus += 0.10
	PC.lingwu_weapon_upgrade_bonus += 0.25
	_level_up_action()

# 宝器之魂：天命+3/4/6，天命升级概率+15%/20%/25%
func reward_R69():
	PC.selected_rewards.append("R69")
	_add_lucky_level(3)
	PC.lingwu_lucky_upgrade_bonus += 0.15
	_level_up_action()

func reward_SR69():
	PC.selected_rewards.append("SR69")
	_add_lucky_level(4)
	PC.lingwu_lucky_upgrade_bonus += 0.20
	_level_up_action()

func reward_SSR69():
	PC.selected_rewards.append("SSR69")
	_add_lucky_level(6)
	PC.lingwu_lucky_upgrade_bonus += 0.25
	_level_up_action()

# 唤灵之魂：召唤物伤害+10%/13%/16%，唤灵升级概率+15%/20%/25%
func reward_R70():
	PC.selected_rewards.append("R70")
	PC.summon_damage_multiplier += 0.10
	PC.lingwu_summon_upgrade_bonus += 0.15
	_level_up_action()

func reward_SR70():
	PC.selected_rewards.append("SR70")
	PC.summon_damage_multiplier += 0.13
	PC.lingwu_summon_upgrade_bonus += 0.20
	_level_up_action()

func reward_SSR70():
	PC.selected_rewards.append("SSR70")
	PC.summon_damage_multiplier += 0.16
	PC.lingwu_summon_upgrade_bonus += 0.25
	_level_up_action()

# ================= 天命领悟系列 =================

# 天命领悟R71：每4级额外+1天命（等效0.25/级）
func reward_R71():
	PC.selected_rewards.append("R71")
	_level_up_action()

# 天命领悟SR71：每3级额外+1天命（等效0.333/级）
func reward_SR71():
	PC.selected_rewards.append("SR71")
	_level_up_action()

# 天命领悟SSR71：每2级额外+1天命（等效0.5/级）
func reward_SSR71():
	PC.selected_rewards.append("SSR71")
	_level_up_action()

# ================= 苦修系列（紫色，基于移动距离） =================

# 苦修·悟：每移动6000距离，经验获取率+1%
func reward_SR72():
	PC.selected_rewards.append("SR72")
	PC.distance_buff_offsets["SR72"] = PC.world_pixels_to_distance_steps(PC.total_distance_moved)
	_level_up_action()

# 苦修·缘：每移动6000距离，治愈精华掉落率+1%
func reward_SR73():
	PC.selected_rewards.append("SR73")
	PC.distance_buff_offsets["SR73"] = PC.world_pixels_to_distance_steps(PC.total_distance_moved)
	_level_up_action()

# 苦修·道：每移动9000距离，天命+1（需要苦修·悟或苦修·缘）
func reward_SR74():
	PC.selected_rewards.append("SR74")
	PC.distance_buff_offsets["SR74"] = PC.world_pixels_to_distance_steps(PC.total_distance_moved)
	_level_up_action()

# 行修·道：每移动6000距离，天命+1
func reward_SSR75():
	PC.selected_rewards.append("SSR75")
	PC.distance_buff_offsets["SSR75"] = PC.world_pixels_to_distance_steps(PC.total_distance_moved)
	_level_up_action()

# ================= 法则前置条件检查函数 =================
# 返回true表示法则等级>=5，允许对应法则+1奖励出现

func check_xiaofeng_faze_greater_than_3() -> bool:
	return check_xiaofeng_faze_at_least_5()

func check_huyou_faze_greater_than_3() -> bool:
	return check_huyou_faze_at_least_5()

func check_yuliao_faze_greater_than_3() -> bool:
	return check_yuliao_faze_at_least_5()

func check_guangyu_faze_greater_than_3() -> bool:
	return check_guangyu_faze_at_least_5()

func check_danyu_faze_greater_than_3() -> bool:
	return check_danyu_faze_at_least_5()

func check_pohuai_faze_greater_than_3() -> bool:
	return check_pohuai_faze_at_least_5()

func check_baoqi_faze_at_least_5() -> bool:
	return _is_faze_at_least_5("treasure")

func check_pohuai_faze_at_least_5() -> bool:
	return _is_faze_at_least_5("destroy")

func check_yuling_faze_at_least_5() -> bool:
	return _is_faze_at_least_5("summon")

func check_yuling_faze_over_15() -> bool:
	return PC.faze_summon_level > 15

func check_daojian_faze_at_least_5() -> bool:
	return _is_faze_at_least_5("sword")

func check_yuxue_faze_at_least_5() -> bool:
	return _is_faze_at_least_5("blood")

func check_minglei_faze_at_least_5() -> bool:
	return _is_faze_at_least_5("thunder")

func check_chiyan_faze_at_least_5() -> bool:
	return _is_faze_at_least_5("fire")

func check_shengling_faze_at_least_5() -> bool:
	return _is_faze_at_least_5("life")

func check_liushi_faze_at_least_5() -> bool:
	return _is_faze_at_least_5("sixsense")

func check_xiaofeng_faze_at_least_5() -> bool:
	return _is_faze_at_least_5("wind")

func check_huyou_faze_at_least_5() -> bool:
	return _is_faze_at_least_5("shield")

func check_yuliao_faze_at_least_5() -> bool:
	return _is_faze_at_least_5("heal")

func check_danyu_faze_at_least_5() -> bool:
	return _is_faze_at_least_5("bullet")

func check_guangyu_faze_at_least_5() -> bool:
	return _is_faze_at_least_5("wide")

func check_chenyuan_faze_at_least_5() -> bool:
	return _is_faze_at_least_5("deep")

func check_SR72_or_SR73() -> bool:
	return PC.selected_rewards.has("SR72") or PC.selected_rewards.has("SR73")

# ================= 护御领悟系列 =================

# 护御领悟R76：每升一级，额外获取1.5点护甲
func reward_R76():
	PC.selected_rewards.append("R76")
	PC.lingwu_armor_bonus += 1.5
	_level_up_action()

# 护御领悟SR76：每升一级，额外获取2点护甲
func reward_SR76():
	PC.selected_rewards.append("SR76")
	PC.lingwu_armor_bonus += 2.0
	_level_up_action()

# 护御领悟SSR76：每升一级，额外获取2.5点护甲
func reward_SSR76():
	PC.selected_rewards.append("SSR76")
	PC.lingwu_armor_bonus += 2.5
	_level_up_action()

# ================= 苦修·佑/行修·佑（移动距离护甲） =================

# 苦修·佑：每移动6000距离，护甲+2
func reward_SR77():
	PC.selected_rewards.append("SR77")
	PC.distance_buff_offsets["SR77"] = PC.world_pixels_to_distance_steps(PC.total_distance_moved)
	_level_up_action()

# 行修·佑：每移动4000距离，护甲+2
func reward_SSR78():
	PC.selected_rewards.append("SSR78")
	PC.distance_buff_offsets["SSR78"] = PC.world_pixels_to_distance_steps(PC.total_distance_moved)
	_level_up_action()

# ================= 护身系列 =================

# 护身（蓝）：护甲+12，移动速度-4%
func reward_R79():
	PC.selected_rewards.append("R79")
	PC.pc_armor += 12
	PC.move_speed_bonus -= 0.04
	_level_up_action()

# 护身（紫）：护甲+15，移动速度-5%
func reward_SR79():
	PC.selected_rewards.append("SR79")
	PC.pc_armor += 15
	PC.move_speed_bonus -= 0.05
	_level_up_action()

# 护身（金）：护甲+20，移动速度-6%
func reward_SSR79():
	PC.selected_rewards.append("SSR79")
	PC.pc_armor += 20
	PC.move_speed_bonus -= 0.06
	_level_up_action()

# ================= 攻守兼备系列 =================

# 攻守兼备（蓝）：攻击+4%，护甲+8
func reward_R80():
	PC.selected_rewards.append("R80")
	PC.add_attack_percent_bonus(0.04)
	PC.pc_armor += 8
	_level_up_action()

# 攻守兼备（紫）：攻击+5%，护甲+10
func reward_SR80():
	PC.selected_rewards.append("SR80")
	PC.add_attack_percent_bonus(0.05)
	PC.pc_armor += 10
	_level_up_action()

# 攻守兼备（金）：攻击+7%，护甲+14
func reward_SSR80():
	PC.selected_rewards.append("SSR80")
	PC.add_attack_percent_bonus(0.07)
	PC.pc_armor += 14
	_level_up_action()

# ================= 自愈系列 =================

# 自愈（蓝）：生命恢复+1.8%
func reward_R81():
	PC.selected_rewards.append("R81")
	PC.pc_hp_regen += 1.8
	_level_up_action()

# 自愈（紫）：生命恢复+2.2%
func reward_SR81():
	PC.selected_rewards.append("SR81")
	PC.pc_hp_regen += 2.2
	_level_up_action()

# 自愈（金）：生命恢复+2.6%
func reward_SSR81():
	PC.selected_rewards.append("SSR81")
	PC.pc_hp_regen += 2.6
	_level_up_action()

# ================= 抵抗系列 =================

# 抵抗（蓝）：护甲+5，生命恢复+1%
func reward_R82():
	PC.selected_rewards.append("R82")
	PC.pc_armor += 5
	PC.pc_hp_regen += 1.0
	_level_up_action()

# 抵抗（紫）：护甲+6，生命恢复+1.2%
func reward_SR82():
	PC.selected_rewards.append("SR82")
	PC.pc_armor += 6
	PC.pc_hp_regen += 1.2
	_level_up_action()

# 抵抗（金）：护甲+8，生命恢复+1.5%
func reward_SSR82():
	PC.selected_rewards.append("SSR82")
	PC.pc_armor += 8
	PC.pc_hp_regen += 1.5
	_level_up_action()

# ================= 痛楚/精魄/存续领悟系列 =================

func reward_R83():
	PC.selected_rewards.append("R83")
	_level_up_action()

func reward_SR83():
	PC.selected_rewards.append("SR83")
	_level_up_action()

func reward_SSR83():
	PC.selected_rewards.append("SSR83")
	_level_up_action()

func reward_R84():
	PC.selected_rewards.append("R84")
	_level_up_action()

func reward_SR84():
	PC.selected_rewards.append("SR84")
	_level_up_action()

func reward_SSR84():
	PC.selected_rewards.append("SSR84")
	_level_up_action()

func reward_R85():
	PC.selected_rewards.append("R85")
	PC.pc_armor += 5
	_level_up_action()

func reward_SR85():
	PC.selected_rewards.append("SR85")
	PC.pc_armor += 8
	_level_up_action()

func reward_SSR85():
	PC.selected_rewards.append("SSR85")
	PC.pc_armor += 12
	_level_up_action()

func _apply_layered_armor(reward_id: String, flat_armor: float, armor_ratio: float) -> void:
	PC.selected_rewards.append(reward_id)
	PC.pc_armor += flat_armor
	PC.pc_armor += ceil(PC.pc_armor * armor_ratio)
	_level_up_action()

func reward_R86():
	_apply_layered_armor("R86", 8.0, 0.04)

func reward_SR86():
	_apply_layered_armor("SR86", 10.0, 0.05)

func reward_SSR86():
	_apply_layered_armor("SSR86", 13.0, 0.06)

func reward_SR87():
	PC.selected_rewards.append("SR87")
	_level_up_action()

func reward_SSR87():
	PC.selected_rewards.append("SSR87")
	_level_up_action()

func _apply_toughness(reward_id: String, hp_regen_bonus: float, damage_reduction_penalty: float) -> void:
	PC.selected_rewards.append(reward_id)
	PC.pc_hp_regen += hp_regen_bonus
	PC.damage_reduction_rate = max(PC.damage_reduction_rate - damage_reduction_penalty, 0.0)
	_level_up_action()

func reward_R88():
	_apply_toughness("R88", 2.4, 0.005)

func reward_SR88():
	_apply_toughness("SR88", 3.0, 0.006)

func reward_SSR88():
	_apply_toughness("SSR88", 4.0, 0.008)

func _apply_survival_soul(reward_id: String, armor_bonus: float, live_weight_bonus: float) -> void:
	PC.selected_rewards.append(reward_id)
	PC.pc_armor += armor_bonus
	PC.lingwu_live_upgrade_bonus += live_weight_bonus
	_level_up_action()

func reward_R89():
	_apply_survival_soul("R89", 6.0, 0.15)

func reward_SR89():
	_apply_survival_soul("SR89", 8.0, 0.20)

func reward_SSR89():
	_apply_survival_soul("SSR89", 12.0, 0.25)

func reward_R90():
	PC.selected_rewards.append("R90")
	PC.update_spirit_reward_bonuses()
	_level_up_action()

func reward_SR90():
	PC.selected_rewards.append("SR90")
	PC.update_spirit_reward_bonuses()
	_level_up_action()

func reward_SSR90():
	PC.selected_rewards.append("SSR90")
	PC.update_spirit_reward_bonuses()
	_level_up_action()

func reward_R91():
	PC.selected_rewards.append("R91")
	PC.update_spirit_reward_bonuses()
	_level_up_action()

func reward_SR91():
	PC.selected_rewards.append("SR91")
	PC.update_spirit_reward_bonuses()
	_level_up_action()

func reward_SSR91():
	PC.selected_rewards.append("SSR91")
	PC.update_spirit_reward_bonuses()
	_level_up_action()

func _setup_spirit_reward_timers() -> void:
	spirit_attract_timer = Timer.new()
	spirit_attract_timer.name = "SpiritAttractTimer"
	spirit_attract_timer.wait_time = 3.0
	spirit_attract_timer.one_shot = false
	spirit_attract_timer.autostart = false
	spirit_attract_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(spirit_attract_timer)
	spirit_attract_timer.timeout.connect(_on_spirit_attract_timer_timeout)

	spirit_regen_timer = Timer.new()
	spirit_regen_timer.name = "SpiritRegenTimer"
	spirit_regen_timer.wait_time = 10.0
	spirit_regen_timer.one_shot = false
	spirit_regen_timer.autostart = false
	spirit_regen_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(spirit_regen_timer)
	spirit_regen_timer.timeout.connect(_on_spirit_regen_timer_timeout)

func reset_battle_reward_state() -> void:
	pre_applied_level_growth_count = 0
	spirit_attract_gain = 0.0
	spirit_regen_rate = 0.0
	law_spirit_regen_bonus = 0.0
	_refresh_spirit_attract_timer()
	_refresh_spirit_regen_timer()

func _get_current_battle_stage() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var current_scene := tree.current_scene
	if current_scene != null and current_scene.has_method("add_spirit"):
		return current_scene
	return null

func _get_current_spirit_raw() -> float:
	var battle_stage := _get_current_battle_stage()
	if battle_stage == null:
		return 0.0
	return float(battle_stage.get("spirit_raw"))

func _add_battle_spirit(amount: float) -> void:
	var battle_stage := _get_current_battle_stage()
	if battle_stage != null and amount > 0.0:
		battle_stage.call("add_spirit", amount)

func _refresh_spirit_attract_timer() -> void:
	if spirit_attract_timer == null:
		return
	if spirit_attract_gain > 0.0:
		if spirit_attract_timer.is_stopped():
			spirit_attract_timer.start()
	else:
		spirit_attract_timer.stop()

func _refresh_spirit_regen_timer() -> void:
	if spirit_regen_timer == null:
		return
	if spirit_regen_rate > 0.0:
		if spirit_regen_timer.is_stopped():
			spirit_regen_timer.start()
	else:
		spirit_regen_timer.stop()

func _on_spirit_attract_timer_timeout() -> void:
	_add_battle_spirit(spirit_attract_gain)

func _on_spirit_regen_timer_timeout() -> void:
	if _should_stop_spirit_regen_after_boss():
		if spirit_regen_timer != null:
			spirit_regen_timer.stop()
		return
	var current_spirit := _get_current_spirit_raw()
	_add_battle_spirit(minf(current_spirit * spirit_regen_rate, SPIRIT_REGEN_MAX_GAIN_PER_TICK))

func _should_stop_spirit_regen_after_boss() -> bool:
	var battle_stage := _get_current_battle_stage()
	if battle_stage != null and bool(battle_stage.get("boss_event_triggered")):
		return true
	var stop_time := SPIRIT_REGEN_CORE_STOP_TIME
	match Global.current_stage_difficulty:
		Global.STAGE_DIFFICULTY_SHALLOW:
			stop_time = SPIRIT_REGEN_SHALLOW_STOP_TIME
		Global.STAGE_DIFFICULTY_DEEP:
			stop_time = SPIRIT_REGEN_DEEP_STOP_TIME
		Global.STAGE_DIFFICULTY_CORE:
			stop_time = SPIRIT_REGEN_CORE_STOP_TIME
		Global.STAGE_DIFFICULTY_POETRY:
			return true
	return PC.real_time >= stop_time

func _apply_spirit_attract(reward_id: String, gain: float) -> void:
	PC.selected_rewards.append(reward_id)
	spirit_attract_gain += gain
	_refresh_spirit_attract_timer()
	_level_up_action()

func _apply_spirit_regen(reward_id: String, rate: float) -> void:
	PC.selected_rewards.append(reward_id)
	spirit_regen_rate = minf(spirit_regen_rate + rate, SPIRIT_REGEN_MAX_RATE)
	_refresh_spirit_regen_timer()
	_level_up_action()

func add_law_spirit_regen_bonus(delta: float, cap: float = SPIRIT_REGEN_MAX_RATE) -> void:
	law_spirit_regen_bonus = maxf(0.0, law_spirit_regen_bonus + delta)
	spirit_regen_rate = minf(spirit_regen_rate + delta, maxf(SPIRIT_REGEN_MAX_RATE, cap))
	if spirit_regen_rate < 0.0:
		spirit_regen_rate = 0.0
	_refresh_spirit_regen_timer()

func _apply_spirit_heart(reward_id: String, bonus: float) -> void:
	PC.selected_rewards.append(reward_id)
	PC.spirit_multi += bonus
	_level_up_action()

func _apply_deep_meditation(reward_id: String, exp_bonus: float) -> void:
	PC.selected_rewards.append(reward_id)
	PC.exp_multi += exp_bonus
	_level_up_action()

func _apply_battle_insight(reward_id: String, final_damage_bonus: float, exp_bonus: float) -> void:
	PC.selected_rewards.append(reward_id)
	PC.final_damage_bonus += final_damage_bonus
	PC.exp_multi += exp_bonus
	_level_up_action()

func _apply_flanking_battle(reward_id: String, speed_bonus: float, exp_bonus: float) -> void:
	PC.selected_rewards.append(reward_id)
	PC.move_speed_bonus += speed_bonus
	PC.exp_multi += exp_bonus
	_level_up_action()

func _apply_preparation(reward_id: String, refresh_count: int, exp_bonus: float) -> void:
	PC.selected_rewards.append(reward_id)
	PC.refresh_num += refresh_count
	PC.exp_multi += exp_bonus
	_level_up_action()

func _apply_zongheng(reward_id: String, range_bonus: float, atk_bonus: float, speed_penalty: float) -> void:
	PC.selected_rewards.append(reward_id)
	PC.add_attack_range(range_bonus)
	PC.add_attack_percent_bonus(atk_bonus)
	PC.move_speed_bonus -= speed_penalty
	_level_up_action()

func _apply_long_wind(reward_id: String, range_bonus: float, speed_bonus: float) -> void:
	PC.selected_rewards.append(reward_id)
	PC.add_attack_range(range_bonus)
	PC.move_speed_bonus += speed_bonus
	_level_up_action()

func _apply_daqiao_bugong(reward_id: String, range_bonus: float, atk_bonus: float, speed_penalty: float) -> void:
	PC.selected_rewards.append(reward_id)
	PC.add_attack_range(range_bonus)
	PC.add_attack_percent_bonus(atk_bonus)
	PC.move_speed_bonus -= speed_penalty
	PC.faze_deep_level += 1
	_add_faze_weapon_upgrade_bonus("deep")
	_level_up_action()

func _apply_lingshi_overflow(reward_id: String) -> void:
	PC.selected_rewards.append(reward_id)
	PC.add_attack_range(0.24)
	PC.attack_speed_bonus += 0.24
	PC.move_speed_bonus += 0.24
	_level_up_action()

func _apply_emblem_excitation(reward_id: String) -> void:
	PC.selected_rewards.append(reward_id)
	var total_stacks := EmblemManager.get_total_emblem_stacks()
	var atk_bonus := float(total_stacks) * 0.01
	var hp_bonus := float(total_stacks) * 0.005
	PC.add_attack_percent_bonus(atk_bonus)
	var hp_delta := int(round(float(PC.pc_start_max_hp) * hp_bonus))
	PC.pc_max_hp += hp_delta
	PC.pc_start_max_hp += hp_delta
	PC.pc_hp += hp_delta
	_level_up_action()

func _apply_emblem_awakening(reward_id: String) -> void:
	PC.selected_rewards.append(reward_id)
	var total_stacks := EmblemManager.get_total_emblem_stacks()
	var final_damage_target := float(total_stacks) * 0.012
	var final_damage_delta := final_damage_target - PC.emblem_awakening_final_damage_applied_bonus
	if not is_equal_approx(final_damage_delta, 0.0):
		PC.final_damage_bonus += final_damage_delta
		PC.emblem_awakening_final_damage_applied_bonus = final_damage_target
	var damage_reduction_target := float(total_stacks) * 0.005
	var damage_reduction_delta := damage_reduction_target - PC.emblem_awakening_damage_reduction_applied_bonus
	if not is_equal_approx(damage_reduction_delta, 0.0):
		PC.damage_reduction_rate = min(PC.damage_reduction_rate + damage_reduction_delta, 0.7)
		PC.emblem_awakening_damage_reduction_applied_bonus = damage_reduction_target
	_level_up_action()

func check_emblem_total_stacks_above_10() -> bool:
	return EmblemManager.get_total_emblem_stacks() > 10

func check_emblem_total_stacks_above_20() -> bool:
	return EmblemManager.get_total_emblem_stacks() > 20

func check_attack_range_at_least_40() -> bool:
	return Global.get_attack_range_multiplier() >= 1.4

func reward_R92():
	_apply_spirit_attract("R92", 70.0)

func reward_SR92():
	_apply_spirit_attract("SR92", 110.0)

func reward_SSR92():
	_apply_spirit_attract("SSR92", 160.0)

func reward_UR92():
	_apply_spirit_attract("UR92", 240.0)

func reward_R93():
	_apply_spirit_regen("R93", 0.008)

func reward_SR93():
	_apply_spirit_regen("SR93", 0.01)

func reward_SSR93():
	_apply_spirit_regen("SSR93", 0.014)

func reward_UR93():
	_apply_spirit_regen("UR93", 0.02)

func reward_R94():
	_apply_spirit_heart("R94", 0.08)

func reward_SR94():
	_apply_spirit_heart("SR94", 0.11)

func reward_SSR94():
	_apply_spirit_heart("SSR94", 0.15)

func reward_R95():
	_apply_deep_meditation("R95", 0.25)

func reward_SR95():
	_apply_deep_meditation("SR95", 0.33)

func reward_SSR95():
	_apply_deep_meditation("SSR95", 0.45)

func reward_UR95():
	_apply_deep_meditation("UR95", 1.20)

func reward_R96():
	_apply_battle_insight("R96", 0.03, 0.12)

func reward_SR96():
	_apply_battle_insight("SR96", 0.04, 0.20)

func reward_SSR96():
	_apply_battle_insight("SSR96", 0.05, 0.30)

func reward_UR96():
	_apply_battle_insight("UR96", 0.10, 0.80)

func reward_R97():
	_apply_flanking_battle("R97", 0.10, 0.12)

func reward_SR97():
	_apply_flanking_battle("SR97", 0.15, 0.20)

func reward_SSR97():
	_apply_flanking_battle("SSR97", 0.22, 0.30)

func reward_R98():
	_apply_preparation("R98", 3, 0.10)

func reward_SR98():
	_apply_preparation("SR98", 4, 0.20)

func reward_SSR98():
	_apply_preparation("SSR98", 6, 0.25)

func reward_SSR99():
	_apply_emblem_excitation("SSR99")

func reward_UR99():
	_apply_emblem_awakening("UR99")

func reward_R100():
	_apply_zongheng("R100", 0.05, 0.03, 0.04)

func reward_SR100():
	_apply_zongheng("SR100", 0.07, 0.05, 0.06)

func reward_SSR100():
	_apply_zongheng("SSR100", 0.10, 0.08, 0.09)

func reward_R101():
	_apply_long_wind("R101", 0.04, 0.04)

func reward_SR101():
	_apply_long_wind("SR101", 0.06, 0.06)

func reward_SSR101():
	_apply_long_wind("SSR101", 0.09, 0.09)

func reward_UR102():
	_apply_lingshi_overflow("UR102")

func reward_R103():
	_apply_daqiao_bugong("R103", 0.05, 0.05, 0.06)

func reward_SR103():
	_apply_daqiao_bugong("SR103", 0.07, 0.07, 0.09)

func reward_SSR103():
	_apply_daqiao_bugong("SSR103", 0.10, 0.10, 0.13)

# ================= UR红色领悟 =================

# 生生不息：生命恢复+6%，最大体力-5%
func reward_UR55():
	PC.selected_rewards.append("UR55")
	PC.pc_hp_regen += 6.0
	var hp_reduce = int(PC.pc_max_hp * 0.05)
	PC.pc_max_hp -= hp_reduce
	PC.pc_start_max_hp -= hp_reduce
	if PC.pc_hp > PC.pc_max_hp:
		PC.pc_hp = PC.pc_max_hp
	_level_up_action()

# 最终壁垒：护甲+60，最大体力+24%，最终伤害-12%
func reward_UR56():
	PC.selected_rewards.append("UR56")
	PC.pc_armor += 60
	var hp_bonus = int(PC.pc_max_hp * 0.24)
	PC.pc_max_hp += hp_bonus
	PC.pc_start_max_hp += hp_bonus
	PC.pc_hp += hp_bonus
	PC.final_damage_bonus -= 0.12
	_level_up_action()

# 深仁厚泽：生命恢复+5%，生命恢复间隔从5秒降低至4秒
func reward_UR57():
	PC.selected_rewards.append("UR57")
	PC.pc_hp_regen += 5.0
	PC.hp_regen_interval = 4.0
	_level_up_action()

func reward_RZhuazhuajuchui():
	PC.main_skill_zhuazhuajuchui += 1
	ZHUAZHUAJUCHUI_SCRIPT.main_skill_zhuazhuajuchui_damage += 0.04
	PC.pc_max_hp += int(round(float(PC.pc_start_max_hp) * 0.015))
	PC.final_damage_bonus += 0.015
	_level_up_action()

func reward_SRZhuazhuajuchui():
	PC.main_skill_zhuazhuajuchui += 1
	ZHUAZHUAJUCHUI_SCRIPT.main_skill_zhuazhuajuchui_damage += 0.05
	PC.pc_max_hp += int(round(float(PC.pc_start_max_hp) * 0.0175))
	PC.final_damage_bonus += 0.0175
	_level_up_action()

func reward_SSRZhuazhuajuchui():
	PC.main_skill_zhuazhuajuchui += 1
	ZHUAZHUAJUCHUI_SCRIPT.main_skill_zhuazhuajuchui_damage += 0.06
	PC.pc_max_hp += int(round(float(PC.pc_start_max_hp) * 0.02))
	PC.final_damage_bonus += 0.02
	_level_up_action()

func reward_URZhuazhuajuchui():
	PC.main_skill_zhuazhuajuchui += 1
	ZHUAZHUAJUCHUI_SCRIPT.main_skill_zhuazhuajuchui_damage += 0.08
	PC.pc_max_hp += int(round(float(PC.pc_start_max_hp) * 0.025))
	PC.final_damage_bonus += 0.025
	_level_up_action()

func reward_Zhuazhuajuchui1():
	PC.selected_rewards.append("Zhuazhuajuchui1")
	PC.faze_deep_level += 2
	PC.faze_blood_level += 2
	_level_up_action()

func reward_Zhuazhuajuchui2():
	PC.selected_rewards.append("Zhuazhuajuchui2")
	PC.faze_deep_level += 2
	PC.faze_blood_level += 2
	_level_up_action()

func reward_Zhuazhuajuchui3():
	PC.selected_rewards.append("Zhuazhuajuchui3")
	PC.faze_deep_level += 2
	PC.faze_blood_level += 2
	_level_up_action()

func reward_Zhuazhuajuchui4():
	PC.selected_rewards.append("Zhuazhuajuchui4")
	PC.faze_deep_level += 2
	PC.faze_blood_level += 2
	_level_up_action()

func reward_Zhuazhuajuchui11():
	PC.selected_rewards.append("Zhuazhuajuchui11")
	PC.faze_deep_level += 2
	PC.faze_blood_level += 2
	_level_up_action()

func reward_Zhuazhuajuchui22():
	PC.selected_rewards.append("Zhuazhuajuchui22")
	PC.faze_deep_level += 2
	PC.faze_blood_level += 2
	_level_up_action()

func reward_Zhuazhuajuchui33():
	PC.selected_rewards.append("Zhuazhuajuchui33")
	PC.faze_deep_level += 2
	PC.faze_blood_level += 2
	_level_up_action()

func reward_RSoulSickle():
	PC.main_skill_soul_sickle += 1
	PC.add_attack_percent_bonus(0.04)
	PC.main_skill_soul_sickle_damage += 0.06
	_level_up_action()

func reward_SRSoulSickle():
	PC.main_skill_soul_sickle += 1
	PC.add_attack_percent_bonus(0.045)
	PC.main_skill_soul_sickle_damage += 0.07
	_level_up_action()

func reward_SSRSoulSickle():
	PC.main_skill_soul_sickle += 1
	PC.add_attack_percent_bonus(0.05)
	PC.main_skill_soul_sickle_damage += 0.08
	_level_up_action()

func reward_URSoulSickle():
	PC.main_skill_soul_sickle += 1
	PC.add_attack_percent_bonus(0.06)
	PC.main_skill_soul_sickle_damage += 0.10
	_level_up_action()

func reward_SoulSickle1():
	PC.selected_rewards.append("SoulSickle1")
	PC.main_skill_soul_sickle_damage += 0.10
	PC.faze_shehun_level += 2
	PC.faze_deep_level += 2
	PC.faze_heal_level += 2
	_level_up_action()

func reward_SoulSickle2():
	PC.selected_rewards.append("SoulSickle2")
	PC.faze_shehun_level += 2
	PC.faze_deep_level += 2
	_level_up_action()

func reward_SoulSickle3():
	PC.selected_rewards.append("SoulSickle3")
	PC.main_skill_soul_sickle_damage -= 0.15
	PC.faze_shehun_level += 2
	PC.faze_deep_level += 2
	_level_up_action()

func reward_SoulSickle4():
	PC.selected_rewards.append("SoulSickle4")
	PC.main_skill_soul_sickle_damage += 0.10
	PC.faze_shehun_level += 2
	PC.faze_deep_level += 2
	_level_up_action()

func reward_SoulSickle11():
	PC.selected_rewards.append("SoulSickle11")
	PC.main_skill_soul_sickle_damage += 0.10
	PC.faze_shehun_level += 2
	PC.faze_deep_level += 2
	PC.faze_heal_level += 2
	_level_up_action()

func reward_SoulSickle22():
	PC.selected_rewards.append("SoulSickle22")
	PC.main_skill_soul_sickle_damage += 0.20
	PC.faze_shehun_level += 2
	PC.faze_deep_level += 2
	_level_up_action()

func reward_SoulSickle33():
	PC.selected_rewards.append("SoulSickle33")
	PC.faze_shehun_level += 2
	PC.faze_deep_level += 2
	_level_up_action()

func reward_RThunderGun():
	PC.main_skill_thunder_gun += 1
	PC.add_attack_percent_bonus(0.04)
	PC.main_skill_thunder_gun_damage += 0.06
	_level_up_action()

func reward_SRThunderGun():
	PC.main_skill_thunder_gun += 1
	PC.add_attack_percent_bonus(0.045)
	PC.main_skill_thunder_gun_damage += 0.07
	_level_up_action()

func reward_SSRThunderGun():
	PC.main_skill_thunder_gun += 1
	PC.add_attack_percent_bonus(0.05)
	PC.main_skill_thunder_gun_damage += 0.08
	_level_up_action()

func reward_URThunderGun():
	PC.main_skill_thunder_gun += 1
	PC.add_attack_percent_bonus(0.06)
	PC.main_skill_thunder_gun_damage += 0.10
	_level_up_action()

func reward_ThunderGun1():
	PC.selected_rewards.append("ThunderGun1")
	PC.faze_thunder_level += 2
	PC.faze_shehun_level += 2
	_level_up_action()

func reward_ThunderGun2():
	PC.selected_rewards.append("ThunderGun2")
	PC.faze_thunder_level += 2
	PC.faze_shehun_level += 2
	_level_up_action()

func reward_ThunderGun3():
	PC.selected_rewards.append("ThunderGun3")
	PC.faze_thunder_level += 2
	PC.faze_shehun_level += 2
	_level_up_action()

func reward_ThunderGun4():
	PC.selected_rewards.append("ThunderGun4")
	PC.faze_thunder_level += 2
	PC.faze_shehun_level += 2
	_level_up_action()

func reward_ThunderGun11():
	PC.selected_rewards.append("ThunderGun11")
	PC.faze_thunder_level += 2
	PC.faze_shehun_level += 2
	_level_up_action()

func reward_ThunderGun22():
	PC.selected_rewards.append("ThunderGun22")
	PC.faze_thunder_level += 2
	PC.faze_shehun_level += 2
	_level_up_action()

func reward_ThunderGun33():
	PC.selected_rewards.append("ThunderGun33")
	PC.faze_thunder_level += 2
	PC.faze_shehun_level += 2
	_level_up_action()
