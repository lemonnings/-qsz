extends Node

# 全局奖励列表，从CSV加载
var all_rewards_list: Array[Reward] = []

# 定义奖励数据结构
class Reward: # Reward 类定义了单个奖励所包含的所有属性。
	var id: String
	var rarity: String # 稀有度，例如: white, green, skyblue, purple, gold, red 等。
	var reward_name: String # 技能/奖励的名称。
	var if_main_skill: bool # 布尔值，标记这是否是一个主要技能。
	var icon: String # 指向技能图标资源的路径字符串。
	var detail: String # 技能/奖励的详细描述文本。
	var max_acquisitions: int # 该奖励能被玩家获取的最大次数。
	var faction: String # 奖励所属的派系或类别。
	var weight: float # 用于随机抽取的权重值。
	var if_advance: bool # 布尔值，标记这是否是一个进阶技能（通常在特定等级，如每5级出现）。
	var precondition: String # 获取此奖励所需的前置奖励ID，多个ID用逗号分隔。
	var on_selected: String # 当奖励被选中时，需要调用的函数名称字符串。


signal player_lv_up_over
signal lucky_level_up

func _ready():
	# CSV文件路径，根据实际项目结构可能需要调整。
	_load_rewards_from_csv("res://Config/reward.csv")

# 从CSV文件加载奖励数据
func _load_rewards_from_csv(file_path: String):
	print("尝试从CSV读取奖励数据: ", file_path)
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
			var expected_headers = ["id", "rarity", "reward_name", "if_main_skill", "icon", "detail", "max_acquisitions", "faction", "weight", "if_advance", "precondition", "on_selected"]

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
			new_reward.icon = reward_data.get("icon", "") # 存储图标路径
			new_reward.detail = reward_data.get("detail", "")
			var max_acq_str = reward_data.get("max_acquisitions", "-1")
			new_reward.max_acquisitions = int(max_acq_str) if max_acq_str.is_valid_int() else -1
			new_reward.faction = reward_data.get("faction", "normal")
			var weight_str = reward_data.get("weight", "1.0")
			new_reward.weight = float(weight_str) if weight_str.is_valid_float() else 1.0
			new_reward.if_advance = reward_data.get("if_advance", "false").to_lower() == "true"
			new_reward.precondition = reward_data.get("precondition", "")
			new_reward.on_selected = reward_data.get("on_selected", "")

			all_rewards_list.append(new_reward)
			# print("已加载奖励: ", new_reward.name) # 用于调试，打印加载的奖励名称。
	
	file.close()
	print("成功从 ", file_path, " 加载 ", all_rewards_list.size(), " 个奖励")



func get_reward_level(rand_num: float, main_skill_name: String = '') -> Reward:
	print_debug("get_reward_level - main_skill_name: ", main_skill_name)
	var selected_reward: Reward
	if rand_num <= PC.now_red_p:
		selected_reward = select_reward('red', main_skill_name)
	elif rand_num <= PC.now_gold_p + PC.now_red_p:
		selected_reward = select_reward('gold', main_skill_name)
	elif rand_num <= PC.now_purple_p + PC.now_gold_p + PC.now_red_p:
		selected_reward = select_reward('purple', main_skill_name)
	elif rand_num <= PC.now_blue_p + PC.now_purple_p + PC.now_gold_p + PC.now_red_p:
		selected_reward = select_reward('skyblue', main_skill_name)
	elif rand_num <= PC.now_green_p + PC.now_blue_p + PC.now_purple_p + PC.now_gold_p + PC.now_red_p:
		selected_reward = select_reward('green', main_skill_name)
	else:
		selected_reward = select_reward('white', main_skill_name)

	if selected_reward != null:
		for i in range(all_rewards_list.size()):
			var reward: Reward = all_rewards_list[i]
			if reward.id == selected_reward.id:
				all_rewards_list.remove_at(i)
				break 
	return selected_reward


# 根据稀有度字符串从 all_rewards_list 中筛选奖励
func _get_rewards_by_rarity_str(rarity_str: String, main_skill_name: String) -> Array[Reward]:
	#print_debug("_get_rewards_by_rarity_str - rarity_str: ", rarity_str, ", main_skill_name: ", main_skill_name)
	var filtered_rewards: Array[Reward] = []
	
	for reward_item in all_rewards_list:
		if main_skill_name == '':
			# 普通升级：按稀有度筛选，排除进阶技能
			if rarity_str != '' and reward_item.rarity == rarity_str and (reward_item.if_main_skill == false or (reward_item.if_main_skill == true and reward_item.if_advance == false)):
				filtered_rewards.append(reward_item)
		else:
			# 主技能进阶升级（5的倍数）：只抽取if_advance=true且faction匹配的技能，忽略稀有度
			#print_debug("_get_rewards_by_rarity_str - checking for main_skill_name advance: reward_id: ", reward_item.id, ", if_advance: ", reward_item.if_advance, ", faction: ", reward_item.faction, ", main_skill_name: ", main_skill_name)
			if reward_item.if_advance == true and reward_item.faction == main_skill_name:
				filtered_rewards.append(reward_item)

	#print_debug("_get_rewards_by_rarity_str - returning filtered_rewards size: ", filtered_rewards.size())
	return filtered_rewards
	

func _level_up_action() :
	all_rewards_list = []
	_load_rewards_from_csv("res://Config/reward.csv")
	global_level_up()
	
	get_tree().set_pause(false)
	
	Global.is_level_up = false
	Global.emit_signal("level_up_selection_complete")
	
	
func _select_PC_main_skill_lv(main_skill_name: String) -> int:
	if main_skill_name == "swordQi":
		return PC.main_skill_swordQi
	return 0


# 返回待抽取的派系
func _select_faction_for_rarity(rarity_name: String) -> String:
	var factions = PlayerRewardWeights.INITIAL_FACTION_WEIGHTS.keys()
	var total_weight = 0.0
	var weighted_factions = []

	for faction_key in factions:
		var weight = PlayerRewardWeights.get_faction_weight(rarity_name, faction_key)
		if weight > 0:
			total_weight += weight
			weighted_factions.append({"name": faction_key, "cumulative_weight": total_weight})

	if weighted_factions.is_empty():
		return "normal" # 如果没有符合条件的派系，则回退到默认派系（例如 "normal"）。

	var random_roll = randf() * total_weight
	for wf in weighted_factions:
		if random_roll < wf.cumulative_weight:
			return wf.name
	
	return weighted_factions[-1].name # 正常情况下，如果 total_weight > 0，则不应执行到此行。

# 根据个体权重从奖励列表中选择一个奖励。
func _select_reward_by_weight(available_rewards: Array[Reward]) -> Reward:
	if available_rewards.is_empty():
		return null

	var total_reward_weight = 0.0
	var weighted_rewards_list = []
	for reward_item in available_rewards:
		if reward_item.weight > 0:
			total_reward_weight += reward_item.weight
			weighted_rewards_list.append({"reward": reward_item, "cumulative_weight": total_reward_weight})

	if weighted_rewards_list.is_empty():
		return null # 如果没有正权重的奖励，则返回null。

	var random_roll = randf() * total_reward_weight
	for wr in weighted_rewards_list:
		if random_roll < wr.cumulative_weight:
			# 如果选择的奖励派系不是 "normal"，则更新玩家的派系权重。
			if wr.reward.faction != "normal": # 假设 PlayerRewardWeights 是一个自动加载的单例。
				# PlayerRewardWeights.update_faction_weights_on_selection 的第一个参数应该是CSV中定义的稀有度字符串。
				PlayerRewardWeights.update_faction_weights_on_selection(wr.reward.rarity, wr.reward.faction, 1.0)
			return wr.reward

	
	return weighted_rewards_list[-1].reward # 回退机制，理想情况下不应执行到此。确保之前的逻辑覆盖所有情况。

# 主要的奖励选择函数：基于稀有度（CSV中的名称）、派系选择和个体权重来获取一个奖励。
func select_reward(csv_rarity_name: String, main_skill_name: String = '') -> Reward:
	#print_debug("select_reward - initial csv_rarity_name: ", csv_rarity_name, ", main_skill_name: ", main_skill_name)
	var max_rerolls = 100 # 设置最大重抽次数，防止无限循环。
	var is_main_skill_advance = false
	for i in range(max_rerolls):
		var selected_faction = _select_faction_for_rarity(csv_rarity_name) # _select_faction_for_rarity 也需要使用CSV中的稀有度名称。
		if main_skill_name != '':
			selected_faction = main_skill_name
			is_main_skill_advance = true
			csv_rarity_name = ''
			#print_debug("select_reward - main_skill_name is not empty. selected_faction: ", selected_faction, ", is_main_skill_advance: ", is_main_skill_advance, ", csv_rarity_name set to empty.")

		var all_rewards_for_rarity = _get_rewards_by_rarity_str(csv_rarity_name, main_skill_name)
		#print_debug("select_reward - all_rewards_for_rarity size: ", all_rewards_for_rarity.size())
		var faction_specific_rewards: Array[Reward] = []

		for r in all_rewards_for_rarity:
			if main_skill_name != '':
				# 主技能进阶升级：_get_rewards_by_rarity_str已经筛选了if_advance=true和faction匹配的奖励
				faction_specific_rewards.append(r)
			else:
				# 普通升级：按派系筛选
				if r.faction == selected_faction:
					faction_specific_rewards.append(r)
		#print_debug("select_reward - faction_specific_rewards size after loop: ", faction_specific_rewards.size())
				
		if faction_specific_rewards != null and faction_specific_rewards.size() != 0:
			var chosen_reward = _select_reward_by_weight(faction_specific_rewards)
	
			if chosen_reward != null:
				# 检查前置条件
				var prerequisites_met = true
				if not chosen_reward.precondition.is_empty():
					var prereq_func_names = chosen_reward.precondition.split(",") # 假设前置条件函数名以逗号分隔。
					for func_name_str in prereq_func_names:
						var func_name = func_name_str.strip_edges()
						# 检查 LvUp (self) 是否有这个方法
						if self.has_method(func_name):
							var callable_func = Callable(self, func_name)
							var condition_met = callable_func.call()
							if not condition_met:
								prerequisites_met = false
								print_debug("因未满足前置条件函数 '" + func_name + "' 而重抽奖励 '" + chosen_reward.id + "'")
								break
						else:
							print_debug("错误：找不到前置条件函数 '" + func_name + "' 用于奖励 '" + chosen_reward.id + "'")
							prerequisites_met = false # 如果找不到函数，也视为条件不满足
							break
				
				if prerequisites_met:
					# 检查最大获取次数
					if chosen_reward.max_acquisitions == -1 or PC.get_reward_acquisition_count(chosen_reward.id) < chosen_reward.max_acquisitions:
						return chosen_reward # 成功找到符合条件的奖励。
					else:
						print_debug("奖励 '" + chosen_reward.id + "' 已达最大获取次数: " + str(PC.get_reward_acquisition_count(chosen_reward.id)) + "/" + str(chosen_reward.max_acquisitions) + "，进行重抽。")
						# 继续下一次重抽尝试。
						continue
				else:
					# 前置条件未满足，继续下一次重抽尝试。
					continue
			else: # 如果在该派系下没有可选奖励，则重试。
				print_debug("在稀有度 '" + csv_rarity_name + "' 的派系 '" + selected_faction + "' 下未找到奖励。重抽派系。")
				continue
		elif main_skill_name!= '':
			var noReward = Reward.new()
			noReward.reward_name = "noReward"
			return noReward
	
	print_debug("稀有度 '" + csv_rarity_name + "' 已达到最大重抽次数。将返回null或该稀有度下首个可用的奖励。")
	# 如果达到最大重抽次数或未找到合适奖励时的回退逻辑。
	var all_rewards_for_rarity_fallback = _get_rewards_by_rarity_str(csv_rarity_name, main_skill_name)
	if not all_rewards_for_rarity_fallback.is_empty():
		# 尝试返回一个没有前置条件、或前置条件已满足、且未达到最大获取次数的奖励。
		for fallback_reward in all_rewards_for_rarity_fallback:
			var fb_prereq_met = true
			if not fallback_reward.precondition.is_empty():
				var prereq_func_names = fallback_reward.precondition.split(",") # 假设前置条件函数名以逗号分隔。
				for func_name_str in prereq_func_names:
					var func_name = func_name_str.strip_edges()
					if self.has_method(func_name):
						var callable_func = Callable(self, func_name)
						var condition_met = callable_func.call()
						if not condition_met:
							fb_prereq_met = false
							break
					else:
						fb_prereq_met = false # 如果找不到函数，也视为条件不满足
						break
			
			if fb_prereq_met and (fallback_reward.max_acquisitions == -1 or PC.get_reward_acquisition_count(fallback_reward.id) < fallback_reward.max_acquisitions):
				return fallback_reward
		# 如果在回退逻辑中仍然找不到完全符合条件的奖励 (for current csv_rarity_name)
		print_debug("在稀有度 '" + csv_rarity_name + "' 的回退逻辑中，未能找到完全符合条件的奖励。将尝试其他稀有度。")

	# 尝试从其他稀有度获取奖励
	print_debug("稀有度 '" + csv_rarity_name + "' 无可用奖励后，开始尝试查找其他稀有度的奖励。")
	# 定义实际使用的稀有度名称（与CSV文件中的稀有度名称一致）
	var actual_rarity_levels: Array[String] = ["white", "green", "skyblue", "purple", "gold", "red"]
	for other_rarity_name in actual_rarity_levels:
		if other_rarity_name == csv_rarity_name: # 跳过当前已尝试过的稀有度
			continue

		var rewards_from_other_rarity = _get_rewards_by_rarity_str(other_rarity_name, main_skill_name)
		
		if not rewards_from_other_rarity.is_empty():
			for potential_reward in rewards_from_other_rarity:
				# 检查前置条件 (使用与主循环相同的逻辑)
				var prereq_ok = true
				if not potential_reward.precondition.is_empty():
					var prereq_func_names = potential_reward.precondition.split(",")
					for func_name_str in prereq_func_names:
						var func_name = func_name_str.strip_edges()
						if self.has_method(func_name):
							var callable_func = Callable(self, func_name)
							if not callable_func.call():
								prereq_ok = false
								break
						else: # 前置条件函数未找到
							prereq_ok = false
							break
				
				if prereq_ok:
					# 检查最大获取次数
					if potential_reward.max_acquisitions == -1 or PC.get_reward_acquisition_count(potential_reward.id) < potential_reward.max_acquisitions:
						print_debug("原稀有度 '" + csv_rarity_name + "' 无合适奖励。从备选稀有度 '" + other_rarity_name + "' 选中奖励: " + potential_reward.id)
						return potential_reward # 成功找到符合条件的奖励

	print_debug("所有稀有度（包括 '" + csv_rarity_name + "' 的回退和其他稀有度）均尝试完毕，未找到任何可用奖励。")
	return null # 如果所有稀有度都尝试过后仍未找到，则返回null


func check_G10_condition() -> bool:
	return not PC.selected_rewards.has("spdToAH1")

func check_G11_condition() -> bool:
	return not PC.selected_rewards.has("lukcyToAH1")

func check_G12_condition() -> bool:
	return not PC.selected_rewards.has("aSpdToAH1")

# 检查“续剑大小提高”技能获取次数是否小于2
func check_R09_condition() -> bool:
	return PC.selected_rewards.count("rebound_size_up") < 2

# 检查当前召唤物数量是否小于最大召唤物数量
func check_blue_summon_condition() -> bool:
	return PC.summon_count < PC.summon_count_max

# 检查是否已选择 “spdToAH2” (移速转攻血 II)
func check_R16_condition() -> bool:
	return not PC.selected_rewards.has("spdToAH2")

# 检查是否已选择 “lukcyToAH2” (天命转攻血 II)
func check_R17_condition() -> bool:
	return not PC.selected_rewards.has("lukcyToAH2")

# 检查是否已选择 “aSpdToAH2” (攻速转攻血 II)
func check_R18_condition() -> bool:
	return not PC.selected_rewards.has("aSpdToAH2")

# 检查是否已选择 “rebound” (续剑) 技能
func check_rebound_condition() -> bool:
	return not PC.selected_rewards.has("rebound")

# 检查是否已选择 “rebound” (续剑) 技能 (用于升级续剑相关技能的前置条件)
func check_rebound_up_condition() -> bool:
	return PC.selected_rewards.has("rebound")

# 检查是否已选择 “ring_bullet” (环刃) 且 “ring_bullet_count_up_purple” (环刃数量提升·紫) 获取次数小于4
func check_ring_bullet_count_up_purple_condition() -> bool:
	return PC.selected_rewards.has("ring_bullet") and PC.selected_rewards.count("ring_bullet_count_up_purple") < 4

# 检查是否已选择 “ring_bullet” (环刃) 且 “ring_bullet_size_up_purple” (环刃大小提升·紫) 获取次数小于2
func check_ring_bullet_size_up_purple_condition() -> bool:
	return PC.selected_rewards.has("ring_bullet") and PC.selected_rewards.count("ring_bullet_size_up_purple") < 2

# 检查当前召唤物数量是否小于最大召唤物数量 (用于紫色召唤物技能)
func check_purple_summon_condition() -> bool:
	return PC.summon_count < PC.summon_count_max

# 检查是否已选择 “spdToAH3” (移速转攻血 III)
func check_SR20_condition() -> bool:
	return not PC.selected_rewards.has("spdToAH3")

# 检查是否已选择 “lukcyToAH3” (天命转攻血 III)
func check_SR21_condition() -> bool:
	return not PC.selected_rewards.has("lukcyToAH3")

# 检查是否已选择 “aSpdToAH3” (攻速转攻血 III)
func check_SR22_condition() -> bool:
	return not PC.selected_rewards.has("aSpdToAH3")


# 检查是否已选择 “threeway” (三向剑气) 技能
func check_threeway_condition() -> bool:
	return not PC.selected_rewards.has("threeway")

# 检查是否已选择 “ring_bullet” (环刃) 技能
func check_ring_bullet_condition() -> bool:
	return not PC.selected_rewards.has("ring_bullet")

# 检查是否已选择 “ring_bullet” (环刃) 且 “ring_bullet_damage_up” (环刃伤害提升) 获取次数小于5
func check_ring_bullet_damage_up_condition() -> bool:
	return PC.selected_rewards.has("ring_bullet") and PC.selected_rewards.count("ring_bullet_damage_up") < 5

# 检查当前召唤物数量是否小于最大召唤物数量 (用于金色召唤物技能)
func check_gold_summon_condition() -> bool:
	return PC.summon_count < PC.summon_count_max


# 检查是否已选择 “threeway” (三向剑气) 且未选择 “fiveway” (五向剑气)
func check_fiveway_condition() -> bool:
	return PC.selected_rewards.has("threeway") and not PC.selected_rewards.has("fiveway")

# 检查是否已选择 “ring_bullet” (环刃) 且 “ring_bullet_count_up_red” (环刃数量提升·红) 获取次数小于2
func check_ring_bullet_count_up_red_condition() -> bool:
	return PC.selected_rewards.has("ring_bullet") and PC.selected_rewards.count("ring_bullet_count_up_red") < 2

# 检查当前召唤物数量是否小于最大召唤物数量 (用于红色召唤物技能)
func check_red_summon_condition() -> bool:
	return PC.summon_count < PC.summon_count_max

# 检查子弹大小是否小于等于2.0 (通用子弹大小相关技能的前置条件)
func check_bullet_size_condition() -> bool:
	return PC.bullet_size <= 2.0


func check_SplitSwordQi1()-> bool:
	return PC.selected_rewards.has("SplitSwordQi1") 
	
func check_SplitSwordQi2()-> bool:
	return PC.selected_rewards.has("SplitSwordQi2") 
	
func check_SplitSwordQi3()-> bool:
	return PC.selected_rewards.has("SplitSwordQi3") 

# --- 以下为具体的奖励效果实现函数 --- 
# 这些函数由CSV中的 on_selected 字段引用，并通过 _execute_reward_on_selected 调用

# N01: 血气 I - HP上限+4%
func reward_N01():
	PC.pc_max_hp = int(PC.pc_max_hp * 1.04)
	_level_up_action()

# N02: 破阵 I - 攻击+2.5%, 攻击速度+1%
func reward_N02():
	PC.pc_atk = int(PC.pc_atk * 1.025)
	PC.pc_atk_speed += 0.01
	_level_up_action()

# N03: 惊鸿 I - 攻击速度+4%
func reward_N03():
	PC.pc_atk_speed += 0.04
	_level_up_action()

# N04: 踏风 I - 移动速度+4%, 暴击率+0.5%
func reward_N04(): 
	PC.pc_speed += 0.04
	PC.crit_chance += 0.005 
	_level_up_action()

# N05: 沉静 I - 攻击速度+6.5%, 移动速度-2%
func reward_N05(): 
	PC.pc_atk_speed += 0.065
	PC.pc_speed -= 0.02
	_level_up_action()

# N06: 炼体 I - HP上限+6.5%, 移动速度-2%
func reward_N06(): 
	PC.pc_max_hp = int(PC.pc_max_hp * 1.065)
	PC.pc_speed -= 0.02
	_level_up_action()

# N07: 健步 I - 移动速度+6.5%, 攻击-1.2%, 暴击伤害+1%
func reward_N07(): 
	PC.pc_speed += 0.065
	PC.pc_atk = int(PC.pc_atk * 0.988) 
	PC.crit_damage_multiplier += 0.01 
	_level_up_action()
	
	
func reward_N08():
	PC.pc_atk = int(PC.pc_atk * 1.04)
	PC.pc_atk_speed -= 0.015
	_level_up_action()

func reward_N09_CritChance():
	PC.crit_chance += 0.04 # 暴击率+4%
	PC.pc_atk_speed += 0.01
	_level_up_action()

func reward_N10_CritDamage():
	PC.crit_damage_multiplier += 0.10 # 暴击伤害+10%
	PC.pc_atk_speed += 0.01
	_level_up_action()

func reward_N11_CritChanceDamage_AtkDown():
	PC.crit_chance += 0.025 # 暴击率+2.5%
	PC.crit_damage_multiplier += 0.0625 # 暴击伤害+6.25%
	PC.pc_atk = int(PC.pc_atk * 0.988) # 攻击-1.2%
	_level_up_action()

# N12: 铁骨 I - 减伤率+2% (上限70%)
func reward_N12_DamageReduction():
	PC.damage_reduction_rate = min(PC.damage_reduction_rate + 0.02, 0.7) 
	_level_up_action()

# N13: 强运 I - 天命+2
func reward_N13():
	PC.now_lunky_level += 2
	Global.emit_signal("lucky_level_up", 2)
	_level_up_action()

# G01: 血气 II - HP上限+6%
func reward_G01():
	PC.pc_max_hp = int(PC.pc_max_hp * 1.06)
	_level_up_action()

# G02: 破阵 II - 攻击+3.75%, 攻击速度+1%
func reward_G02():
	PC.pc_atk = int(PC.pc_atk * 1.0375)
	PC.pc_atk_speed += 0.01
	_level_up_action()

# G03: 惊鸿 II - 攻击速度+6%
func reward_G03():
	PC.pc_atk_speed += 0.06
	_level_up_action()

# G04: 踏风 II - 移动速度+6%, 暴击率+0.75%
func reward_G04(): 
	PC.pc_speed += 0.06
	PC.crit_chance += 0.0075 
	_level_up_action()

# G05: 沉静 II - 攻击速度+9.5%, 移动速度-3%
func reward_G05(): 
	PC.pc_atk_speed += 0.095
	PC.pc_speed -= 0.03
	_level_up_action()

# G06: 炼体 II - HP上限+9.5%, 移动速度-3%
func reward_G06(): 
	PC.pc_max_hp = int(PC.pc_max_hp * 1.095)
	PC.pc_speed -= 0.03
	_level_up_action()

# G07: 健步 II - 移动速度+9.5%, 攻击-1.6%, 暴击伤害+1.5%
func reward_G07(): 
	PC.pc_speed += 0.095
	PC.pc_atk = int(PC.pc_atk * 0.984) 
	PC.crit_damage_multiplier += 0.015 
	_level_up_action()

# G08: 蛮力 II - 攻击+5.75%, 攻击速度-3%
func reward_G08():
	PC.pc_atk = int(PC.pc_atk * 1.0575)
	PC.pc_atk_speed -= 0.03
	_level_up_action()

# G09: 剑意凝势 I - 弹体大小+15%, 攻击速度+3%
func reward_G09():
	PC.bullet_size += 0.15
	PC.pc_atk_speed += 0.03
	_level_up_action()

# G10: 行云剑意 I - 记录选择，效果由其他地方计算 (移速转攻血)
func reward_G10():
	PC.selected_rewards.append("spdToAH1")
	_level_up_action()

# G11: 天命加护 I - 记录选择，效果由其他地方计算 (天命转攻血)
func reward_G11():
	PC.selected_rewards.append("lukcyToAH1")
	_level_up_action()

# G12: 刃舞归元 I - 记录选择，效果由其他地方计算 (攻速转攻血)
func reward_G12():
	PC.selected_rewards.append("aSpdToAH1")
	_level_up_action()

# G13: 精准 II - 暴击率+6%, 攻击速度+1%
func reward_G13_CritChance():
	PC.crit_chance += 0.06 
	PC.pc_atk_speed += 0.01
	_level_up_action()

# G14: 致命 II - 暴击伤害+15%, 攻击速度+1%
func reward_G14_CritDamage():
	PC.crit_damage_multiplier += 0.15 
	PC.pc_atk_speed += 0.01
	_level_up_action()

# G15: 优雅 II - 暴击率+4%, 暴击伤害+10%, 攻击-4%
func reward_G15_CritChanceDamage_AtkDown():
	PC.crit_chance += 0.04 
	PC.crit_damage_multiplier += 0.10 
	PC.pc_atk = PC.pc_atk * 0.96 
	_level_up_action()

# R22: 铁骨 III - 减伤率+4% (此函数名似乎与稀有度不符，应为G系列或R系列，根据CSV调整)
# R22: 铁骨 III - 减伤率+4% (此函数名可能需要根据CSV调整以匹配稀有度)
func reward_R22_DamageReduction():
	# 减伤率增加4%，最大不超过70%
	PC.damage_reduction_rate = min(PC.damage_reduction_rate + 0.04, 0.7) 
	_level_up_action()

# R23: 强运 III - 天命+4 (此函数名似乎与稀有度不符，应为G系列或R系列，根据CSV调整)
func reward_R23():
	# 天命等级增加4
	PC.now_lunky_level += 4
	Global.emit_signal("lucky_level_up", 4)
	_level_up_action()

# G16: 铁骨 II - 减伤率+3%
func reward_G16_DamageReduction():
	# 减伤率增加3%，最大不超过70%
	PC.damage_reduction_rate = min(PC.damage_reduction_rate + 0.03, 0.7) 
	_level_up_action()

# G17: 强运 II - 天命+3
func reward_G17():
	# 天命等级增加3
	PC.now_lunky_level += 3
	Global.emit_signal("lucky_level_up", 3)
	_level_up_action()

# R01: HP上限增加8%
func reward_R01():
	PC.pc_max_hp = int(PC.pc_max_hp * 1.08)
	_level_up_action()

# R02: 攻击增加5%，攻击速度增加1.5%
func reward_R02():
	PC.pc_atk = int(PC.pc_atk * 1.05)
	PC.pc_atk_speed += 0.015
	_level_up_action()

# R03: 攻击速度增加8%
func reward_R03():
	PC.pc_atk_speed += 0.08
	_level_up_action()

# R04: 踏风 III - 移动速度增加6.4%，暴击率增加1%
func reward_R04(): 
	PC.pc_speed += 0.064
	PC.crit_chance += 0.01 # 暴击率+1%
	_level_up_action()

# R05: 沉静 III - 攻击速度增加13%，移动速度减少4%
func reward_R05(): 
	PC.pc_atk_speed += 0.13
	PC.pc_speed -= 0.04
	_level_up_action()

# R06: 炼体 III - HP上限增加13%，移动速度减少4%
func reward_R06(): 
	PC.pc_max_hp = int(PC.pc_max_hp * 1.13)
	PC.pc_speed -= 0.04
	_level_up_action()

# R07: 健步 III - 移动速度增加13%，攻击减少2.4%，暴击伤害增加2%
func reward_R07(): 
	PC.pc_speed += 0.13
	PC.pc_atk = int(PC.pc_atk * 0.976) # 攻击-2.4%
	PC.crit_damage_multiplier += 0.02 # 暴击伤害+2%
	_level_up_action()

# R08: 攻击增加5.6%，攻击速度减少2.4%
func reward_R08():
	PC.pc_atk = int(PC.pc_atk * 1.056)
	PC.pc_atk_speed -= 0.024
	_level_up_action()

# R09: 回复全部HP，并添加 "hpRecover" 标记 (可能用于触发特殊效果或逻辑)
func reward_R09():
	PC.selected_rewards.append("hpRecover")
	PC.pc_hp = PC.pc_max_hp
	_level_up_action()

# R10: HP上限增加5%，并回复全部HP
func reward_R10():
	PC.pc_max_hp = int(PC.pc_max_hp * 1.05)
	PC.pc_hp = PC.pc_max_hp
	_level_up_action()

# R11: 弹体大小增加0.25，攻击速度增加4%
func reward_R11():
	PC.bullet_size += 0.25
	PC.pc_atk_speed += 0.04
	_level_up_action()

# R16: 添加 "spdToAH2" 标记 (可能与速度相关的攻击力/攻速转换有关)
func reward_R16():
	PC.selected_rewards.append("spdToAH2")
	_level_up_action()

# R17: 添加 "lukcyToAH2" 标记 (可能与幸运相关的攻击力/攻速转换有关)
func reward_R17():
	PC.selected_rewards.append("lukcyToAH2")
	_level_up_action()

# R18: 添加 "aSpdToAH2" 标记 (可能与攻击速度相关的攻击力/攻速转换有关)
func reward_R18():
	PC.selected_rewards.append("aSpdToAH2")
	_level_up_action()

# R19: 暴击率增加8%，攻击速度增加1.5%
func reward_R19_CritChance():
	PC.crit_chance += 0.08 # 暴击率+8%
	PC.pc_atk_speed += 0.015
	_level_up_action()

# R20: 暴击伤害增加20%，攻击速度增加1.5%
func reward_R20_CritDamage():
	PC.crit_damage_multiplier += 0.20 # 暴击伤害+20%
	PC.pc_atk_speed += 0.015
	_level_up_action()

# R21: 暴击率增加5%，暴击伤害增加12.5%，攻击减少2.4%
func reward_R21_CritChanceDamage_AtkDown():
	PC.crit_chance += 0.05 # 暴击率+5%
	PC.crit_damage_multiplier += 0.125 # 暴击伤害+12.5%
	PC.pc_atk = int(PC.pc_atk * 0.976) # 攻击-2.4%
	_level_up_action()

# SR01: HP上限增加10%
func reward_SR01():
	PC.pc_max_hp = int(PC.pc_max_hp * 1.10)
	_level_up_action()

# SR02: 攻击增加5.5%，攻击速度增加2%
func reward_SR02():
	PC.pc_atk = int(PC.pc_atk * 1.055)
	PC.pc_atk_speed += 0.02
	_level_up_action()

# SR03: 攻击速度增加10%
func reward_SR03():
	PC.pc_atk_speed += 0.10
	_level_up_action()

# SR04: 踏风 IX - 移动速度增加10%，暴击率增加1.5%
func reward_SR04(): 
	PC.pc_speed += 0.10
	PC.crit_chance += 0.015 # 暴击率+1.5%
	_level_up_action()

# SR05: 沉静 IX - 攻击速度增加10%，移动速度减少4%
func reward_SR05(): 
	PC.pc_atk_speed += 0.10
	PC.pc_speed -= 0.04
	_level_up_action()

# SR06: 炼体 IX - HP上限增加16%，移动速度减少4%
func reward_SR06(): 
	PC.pc_max_hp = int(PC.pc_max_hp * 1.16)
	PC.pc_speed -= 0.04
	_level_up_action()

# SR07: 健步 IX - 移动速度增加16%，攻击减少2%，暴击伤害增加3%
func reward_SR07(): 
	PC.pc_speed += 0.16
	PC.pc_atk = int(PC.pc_atk * 0.98) # 攻击-2%
	PC.crit_damage_multiplier += 0.03 # 暴击伤害+3%
	_level_up_action()

# SR08: 攻击增加8%，攻击速度减少3%
func reward_SR08():
	PC.pc_atk = int(PC.pc_atk * 1.08)
	PC.pc_atk_speed -= 0.03
	_level_up_action()

# SR09: 天命等级增加5
func reward_SR09():
	PC.now_lunky_level += 5
	Global.emit_signal("lucky_level_up", 5)
	_level_up_action()

# SR20: 添加 "spdToAH3" 标记 (可能与速度相关的攻击力/攻速转换有关，等级3)
func reward_SR20():
	PC.selected_rewards.append("spdToAH3")
	_level_up_action()

# SR21: 添加 "lukcyToAH3" 标记 (可能与幸运相关的攻击力/攻速转换有关，等级3)
func reward_SR21():
	PC.selected_rewards.append("lukcyToAH3")
	_level_up_action()

# SR23: 暴击率增加10%，攻击速度增加2%
func reward_SR23_CritChance():
	PC.crit_chance += 0.10
	PC.pc_atk_speed += 0.02
	_level_up_action()

# SR24: 暴击伤害增加25%，攻击速度增加2%
func reward_SR24_CritDamage():
	PC.crit_damage_multiplier += 0.25
	PC.pc_atk_speed += 0.02
	_level_up_action()

# SR25: 暴击率增加6%，暴击伤害增加15%，攻击减少2.4%
func reward_SR25_CritChanceDamage_AtkDown():
	PC.crit_chance += 0.06
	PC.crit_damage_multiplier += 0.15
	PC.pc_atk = int(PC.pc_atk * 0.976) # 攻击-2.4%
	_level_up_action()

# SR26: 减伤率增加5%，最大不超过70%
func reward_SR26_DamageReduction():
	PC.damage_reduction_rate = min(PC.damage_reduction_rate + 0.05, 0.7) # 减伤率+5%
	_level_up_action()

# SR22: 添加 "aSpdToAH3" 标记 (可能与攻击速度相关的攻击力/攻速转换有关，等级3)
func reward_SR22():
	PC.selected_rewards.append("aSpdToAH3")
	_level_up_action()

# 获得反弹能力
func reward_rebound():
	PC.selected_rewards.append("rebound")
	Global.emit_signal("buff_added", "rebound", -1, 1) # -1 表示永久，1表示层数或效果值
	_level_up_action()

# 反弹子弹变大 (通用)
func reward_rebound_size_up():
	PC.rebound_size_multiplier *= 1.1  # 反弹子弹大小提升10%
	PC.rebound_damage_multiplier = PC.rebound_damage_multiplier * 1.06 # 反弹伤害提升6%
	_level_up_action()

# 反弹子弹变大 (金色品质)
func reward_rebound_size_up_gold():
	PC.rebound_size_multiplier *= 1.12  # 反弹子弹大小提升12%
	PC.rebound_damage_multiplier = PC.rebound_damage_multiplier * 1.09 # 反弹伤害提升9%
	_level_up_action()

# 反弹攻击力提升 (蓝色品质)
func reward_rebound_atk_up_blue():
	PC.rebound_damage_multiplier = PC.rebound_damage_multiplier * 1.15 # 反弹伤害提升15%
	_level_up_action()

# 反弹攻击力提升 (金色品质)
func reward_rebound_atk_up_gold():
	PC.rebound_damage_multiplier = PC.rebound_damage_multiplier * 1.18 # 反弹伤害提升18%
	PC.pc_atk = int(PC.pc_atk * 1.05) # 自身攻击力提升5%
	_level_up_action()

# 反弹攻击力提升 (红色品质)
func reward_rebound_atk_up_red():
	PC.rebound_damage_multiplier = PC.rebound_damage_multiplier * 1.2 # 反弹伤害提升20%
	PC.pc_atk = int(PC.pc_atk * 1.06) # 自身攻击力提升6%
	_level_up_action()

# 反弹攻击力提升 (通用，可能是基础版本)
func reward_rebound_atk_up():
	PC.rebound_damage_multiplier = PC.rebound_damage_multiplier * 1.15 # 反弹伤害提升15%
	PC.pc_atk = int(PC.pc_atk * 1.04) # 自身攻击力提升4%
	_level_up_action()

# 增加反弹次数 (但降低单次反弹伤害作为平衡)
func reward_rebound_num_up():
	PC.selected_rewards.append("rebound_num_up") # 添加标记，具体反弹次数逻辑可能在别处处理
	PC.rebound_damage_multiplier = PC.rebound_damage_multiplier * 0.8 # 反弹伤害降低20%
	_level_up_action()

# SR12: 弹体大小增加0.2，攻击速度增加5%
func reward_SR12():
	PC.bullet_size += 0.2
	PC.pc_atk_speed += 0.05
	_level_up_action()

# SSR01: HP上限增加13%，并回复全部HP
func reward_SSR01():
	PC.pc_max_hp = int(PC.pc_max_hp * 1.13)
	PC.pc_hp = PC.pc_max_hp
	_level_up_action()

# SSR02: 攻击增加7.2%，攻击速度增加2.5%
func reward_SSR02():
	PC.pc_atk = int(PC.pc_atk * 1.072)
	PC.pc_atk_speed += 0.025
	_level_up_action()

# SSR03: 攻击速度增加13%
func reward_SSR03():
	PC.pc_atk_speed += 0.13
	_level_up_action()

# SSR04: 踏风 X - 移动速度增加13%，暴击率增加2%
func reward_SSR04(): 
	PC.pc_speed += 0.13 # 移动速度+13%
	PC.crit_chance += 0.02 # 暴击率+2%
	_level_up_action()

# SSR05: 沉静 X - 攻击速度增加20%，移动速度减少5%
func reward_SSR05(): 
	PC.pc_atk_speed += 0.20
	PC.pc_speed -= 0.05
	_level_up_action()

# SSR06: 炼体 X - HP上限增加20%，回复全部HP，移动速度减少5%
# SSR06: 炼体 X - HP上限增加20%，回复全部HP，移动速度减少5%
func reward_SSR06(): 
	PC.pc_max_hp = int(PC.pc_max_hp * 1.20)
	PC.pc_hp = PC.pc_max_hp
	PC.pc_speed -= 0.05
	_level_up_action()

# SSR07: 健步 X - 移动速度增加20%，攻击减少2.5%，暴击伤害增加4%
func reward_SSR07(): 
	PC.pc_speed += 0.20
	PC.pc_atk = int(PC.pc_atk * 0.975) # 攻击-2.5%
	PC.crit_damage_multiplier += 0.04 # 暴击伤害+4%
	_level_up_action()

# SSR08: 攻击增加11%，攻击速度减少3.5%
func reward_SSR08():
	PC.pc_atk = int(PC.pc_atk * 1.11)
	PC.pc_atk_speed -= 0.035
	_level_up_action()

# SSR09: 天命等级增加6
func reward_SSR09():
	PC.now_lunky_level += 6
	Global.emit_signal("lucky_level_up", 6)
	_level_up_action()

# 三向攻击 (获得三向射击能力，但降低攻击、攻速和子弹大小作为平衡)
func reward_threeway():
	PC.selected_rewards.append("threeway")
	Global.emit_signal("buff_added", "three_way", -1, 1)
	PC.pc_atk = int(PC.pc_atk * 0.75) # 攻击降低25%
	PC.pc_atk_speed -= 0.25 # 攻击速度降低25%
	# global_level_up() # 注意：这里调用了 global_level_up()，可能需要检查其逻辑和影响
	PC.bullet_size -= 0.15 # 子弹大小减少0.15
	_level_up_action()

# SSR12: 弹体大小增加0.35，攻击速度增加6%
func reward_SSR12():
	PC.bullet_size += 0.35
	PC.pc_atk_speed += 0.06
	_level_up_action()

# SSR17: 牺牲20%最大HP上限，转化为攻击力 (每点HP提供0.12攻击力)
func reward_SSR17():
	var minusHP = int(PC.pc_max_hp * 0.2)
	PC.pc_max_hp -= minusHP
	PC.pc_atk += int(minusHP * 0.12)
	_level_up_action()

# SSR19: 暴击率增加13%，攻击速度增加2.5%
func reward_SSR19_CritChance():
	PC.crit_chance += 0.13
	PC.pc_atk_speed += 0.025
	_level_up_action()

# SSR20: 暴击伤害增加32.5%，攻击速度增加2.5%
func reward_SSR20_CritDamage():
	PC.crit_damage_multiplier += 0.325
	PC.pc_atk_speed += 0.025
	_level_up_action()

# SSR21: 暴击率增加8.5%，暴击伤害增加21%，攻击减少6%
func reward_SSR21_CritChanceDamage_AtkDown():
	PC.crit_chance += 0.085
	PC.crit_damage_multiplier += 0.21
	PC.pc_atk = int(PC.pc_atk * 0.94) # 攻击-6%
	_level_up_action()

# SSR22: 减伤率增加6%，最大不超过70%
func reward_SSR22_DamageReduction():
	PC.damage_reduction_rate = min(PC.damage_reduction_rate + 0.06, 0.7) # 减伤率+6%
	_level_up_action()

# UR01: HP上限增加15%，并回复全部HP
func reward_UR01():
	PC.pc_max_hp = int(PC.pc_max_hp * 1.15)
	PC.pc_hp = PC.pc_max_hp
	_level_up_action()

# UR02: 攻击增加10%，攻击速度增加3%
func reward_UR02():
	PC.pc_atk = int(PC.pc_atk * 1.10)
	PC.pc_atk_speed += 0.03
	_level_up_action()

# UR03: 攻击速度增加15%
func reward_UR03():
	PC.pc_atk_speed += 0.15
	_level_up_action()

# UR04: 踏风 XI - 移动速度增加15%，暴击率增加2.5%
func reward_UR04(): 
	PC.pc_speed += 0.15
	PC.crit_chance += 0.025 # 暴击率+2.5%
	_level_up_action()

# UR05: 沉静 XI - 攻击速度增加15%，移动速度减少6%
func reward_UR05(): 
	PC.pc_atk_speed += 0.15
	PC.pc_speed -= 0.06
	PC.crit_damage_multiplier += 0.05 # 暴击伤害+5%
	_level_up_action()

# UR06: 炼体 XI - HP上限增加25%，回复全部HP，移动速度减少6%
func reward_UR06(): 
	PC.pc_max_hp = int(PC.pc_max_hp * 1.25)
	PC.pc_hp = PC.pc_max_hp
	PC.pc_speed -= 0.06
	_level_up_action()

# UR07: 健步 XI - 移动速度增加25%，攻击减少4%，暴击伤害增加5%
func reward_UR07(): 
	PC.pc_speed += 0.25
	PC.pc_atk = int(PC.pc_atk * 0.96) # 攻击-4%
	PC.crit_damage_multiplier += 0.05 # 暴击伤害+5%
	_level_up_action()

# UR08: 攻击增加15%，攻击速度减少4.5%
func reward_UR08():
	PC.pc_atk = int(PC.pc_atk * 1.15)
	PC.pc_atk_speed -= 0.045
	_level_up_action()

# UR09: 天命等级增加7
func reward_UR09():
	PC.now_lunky_level += 7
	Global.emit_signal("lucky_level_up", 7)
	_level_up_action()

# UR12: 弹体大小增加0.3，攻击速度增加7%
func reward_UR12():
	PC.bullet_size += 0.3
	PC.pc_atk_speed += 0.07
	_level_up_action()

# UR17: 牺牲25%最大HP上限，转化为攻击力 (每点HP提供0.15攻击力)
func reward_UR17():
	var minusHP = int(PC.pc_max_hp * 0.25)
	PC.pc_max_hp -= minusHP
	PC.pc_atk += int(minusHP * 0.15)
	_level_up_action()

# 五向攻击 (升级三向攻击，但进一步调整属性作为平衡)
func reward_fiveway():
	PC.selected_rewards.append("fiveway")
	Global.emit_signal("buff_removed", "three_way") # 移除三向攻击buff
	Global.emit_signal("buff_added", "five_way", -1, 1) # 添加五向攻击buff
	PC.pc_atk = int(PC.pc_atk * 0.9) # 攻击降低10% (相对于当前值，若之前有三向，则是在三向基础上再乘0.9)
	PC.pc_atk_speed -= 0.15 # 攻击速度降低15%
	PC.bullet_size -= 0.2 # 子弹大小减少0.2
	_level_up_action()

# UR22: 减伤率增加6%，最大不超过70%
func reward_UR22_DamageReduction():
	PC.damage_reduction_rate = min(PC.damage_reduction_rate + 0.06, 0.7) # 减伤率+6%
	_level_up_action()

# --- 环形子弹相关奖励函数 ---
# 获得环形子弹能力
func reward_ring_bullet():
	PC.selected_rewards.append("ring_bullet")
	_level_up_action()

# 环形子弹伤害提升30%
func reward_ring_bullet_damage_up():
	PC.selected_rewards.append("ring_bullet_damage_up")
	PC.ring_bullet_damage_multiplier *= 1.3
	_level_up_action()

# 环形子弹数量增加2 (紫色品质)
func reward_ring_bullet_count_up_purple():
	PC.selected_rewards.append("ring_bullet_count_up_purple")
	PC.ring_bullet_count += 2
	_level_up_action()

# 环形子弹大小提升15%，伤害提升5% (紫色品质)
func reward_ring_bullet_size_up_purple():
	PC.selected_rewards.append("ring_bullet_size_up_purple")
	PC.ring_bullet_size_multiplier *= 1.15
	PC.ring_bullet_damage_multiplier += 0.05 # 注意这里是加法，之前是乘法
	_level_up_action()

# 环形子弹数量增加4 (红色品质)
func reward_ring_bullet_count_up_red():
	PC.selected_rewards.append("ring_bullet_count_up_red")
	PC.ring_bullet_count += 4
	_level_up_action()

# 环形子弹发射间隔减少25% (即发射频率提高)
func reward_ring_bullet_interval_down():
	PC.selected_rewards.append("ring_bullet_interval_down")
	PC.ring_bullet_interval *= 0.75
	_level_up_action()

# --- 蓝色召唤物相关奖励函数 ---
# 获得一个蓝色召唤物
func reward_blue_summon():
	PC.summon_count += 1
	PC.selected_rewards.append("blue_summon")
	# 通知battle场景添加召唤物 (类型0代表蓝色召唤物)
	var battle_scene = PC.player_instance # 获取玩家实例，应确保这是正确的战斗场景引用
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(0) # 假设0是蓝色召唤物的类型ID
	_level_up_action()

# 蓝色召唤物伤害提升7.5%，子弹大小提升5%
func reward_blue_summon_damage_up():
	PC.summon_damage_multiplier += 0.075
	PC.summon_bullet_size_multiplier += 0.05
	# 更新当前所有召唤物的属性
	var battle_scene = get_tree().get_first_node_in_group("player") # 获取玩家节点，可能需要更精确的引用
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()

# 蓝色召唤物子弹大小提升10%，伤害提升2.5%
func reward_blue_summon_size_up():
	PC.summon_bullet_size_multiplier += 0.1
	PC.summon_damage_multiplier += 0.025
	# 更新当前所有召唤物的属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()

# --- 紫色召唤物相关奖励函数 ---
# 获得一个紫色召唤物
func reward_purple_summon():
	PC.summon_count += 1
	PC.selected_rewards.append("purple_summon")
	PC.new_summon = "purple" # 记录最新获得的召唤物类型
	# 通知battle场景添加召唤物 (类型1代表紫色召唤物)
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(1) # 假设1是紫色召唤物的类型ID
	_level_up_action()

# 紫色召唤物伤害提升10%，子弹大小提升7.5%
func reward_purple_summon_damage_up():
	PC.summon_damage_multiplier += 0.1
	PC.summon_bullet_size_multiplier += 0.075
	# 注意：这里可能也需要调用 update_summons_properties() 来使改动立即生效
	_level_up_action()

# 紫色召唤物子弹大小提升15%，伤害提升5%
func reward_purple_summon_size_up():
	PC.summon_bullet_size_multiplier += 0.15
	PC.summon_damage_multiplier += 0.05
	# 更新当前所有召唤物的属性 (此部分被注释掉了，根据需要取消注释)
	# var battle_scene = get_tree().get_first_node_in_group("player")
	# if battle_scene and battle_scene.has_method("update_summons_properties"):
	# 	battle_scene.update_summons_properties()
	_level_up_action()

# --- 橙色(金色)召唤物相关奖励函数 ---
# 获得一个橙色(金色)召唤物
func reward_gold_summon():
	PC.summon_count += 1
	PC.selected_rewards.append("gold_summon")
	PC.new_summon = "gold" # 记录最新获得的召唤物类型
	# 通知battle场景添加召唤物 (类型2代表橙色/金色召唤物)
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(2) # 假设2是橙色/金色召唤物的类型ID
	_level_up_action()

# 橙色(金色)召唤物伤害提升15%，攻击间隔减少5% (即攻击速度提升)
func reward_gold_summon_damage_up():
	PC.summon_damage_multiplier += 0.15
	PC.summon_interval_multiplier *= 0.95 # 攻击间隔变为原来的95%
	# 更新当前所有召唤物的属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()

# 橙色(金色)召唤物伤害提升6%，攻击间隔减少12.5%
func reward_gold_summon_interval_down():
	PC.summon_damage_multiplier += 0.06
	PC.summon_interval_multiplier *= 0.875 # 攻击间隔变为原来的87.5%
	# 更新当前所有召唤物的属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()

# --- 红色召唤物相关奖励函数 ---
# 获得一个红色召唤物
func reward_red_summon():
	PC.summon_count += 1
	PC.selected_rewards.append("red_summon")
	PC.new_summon = "red" # 记录最新获得的召唤物类型
	# 通知battle场景添加召唤物 (类型3代表红色召唤物)
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(3) # 假设3是红色召唤物的类型ID
	_level_up_action()

# 红色召唤物伤害提升15%，攻击间隔减少7.5%
func reward_red_summon_damage_up():
	PC.summon_damage_multiplier += 0.15
	PC.summon_interval_multiplier *= 0.925 # 攻击间隔变为原来的92.5%
	# 更新当前所有召唤物的属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()

# 红色召唤物伤害提升7.5%，攻击间隔减少15%
func reward_red_summon_interval_down():
	PC.summon_damage_multiplier += 0.075
	PC.summon_interval_multiplier *= 0.85 # 攻击间隔变为原来的85%
	# 更新当前所有召唤物的属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()

# 橙色(金色)召唤物最大数量上限增加1
func reward_gold_summon_max_add():
	PC.summon_count_max += 1
	_level_up_action()

# 红色召唤物最大数量上限增加2
func reward_red_summon_max_add():
	PC.summon_count_max += 2
	_level_up_action()

# UR19: 暴击率增加15%，攻击速度增加3%
func reward_UR19_CritChance():
	PC.crit_chance += 0.15
	PC.pc_atk_speed += 0.03
	_level_up_action()

# UR20: 暴击伤害增加35%，攻击速度增加3%
func reward_UR20_CritDamage():
	PC.crit_damage_multiplier += 0.35 
	PC.pc_atk_speed += 0.03
	_level_up_action()

# UR21: 暴击率增加8%，暴击伤害增加21%，攻击减少3%
func reward_UR21_CritChanceDamage_AtkDown():
	PC.crit_chance += 0.08 
	PC.crit_damage_multiplier += 0.21 
	PC.pc_atk = int(PC.pc_atk * 0.97) # 攻击力变为原来的97%
	_level_up_action()

# 剑气础升级

func WSwordQi():
	PC.main_skill_swordQi += 1
	PC.main_skill_swordQi_damage += 0.01
	_level_up_action()

func GSwordQi():
	PC.main_skill_swordQi += 1
	PC.main_skill_swordQi_damage += 0.02
	_level_up_action()
	
func BSwordQi():
	PC.main_skill_swordQi += 1
	PC.main_skill_swordQi_damage += 0.05
	_level_up_action()

func PSwordQi():
	PC.main_skill_swordQi += 1
	PC.main_skill_swordQi_damage += 0.08
	_level_up_action()

func GlSwordQi():
	PC.main_skill_swordQi += 1
	PC.main_skill_swordQi_damage += 0.13
	_level_up_action()

func RSwordQi():
	PC.main_skill_swordQi += 1
	PC.main_skill_swordQi_damage += 0.2
	_level_up_action()
	
func SplitSwordQi1():
	PC.selected_rewards.append("SplitSwordQi1")
	_level_up_action()
	
func SplitSwordQi2():
	PC.selected_rewards.append("SplitSwordQi2")
	_level_up_action()
	
func SplitSwordQi3():
	PC.selected_rewards.append("SplitSwordQi3")
	PC.swordQi_penetration_count += 2
	_level_up_action()
	
func SplitSwordQi4():
	PC.selected_rewards.append("SplitSwordQi4")
	_level_up_action()
	
func SplitSwordQi11():
	PC.selected_rewards.append("SplitSwordQi11")
	PC.swordQi_other_sword_wave_damage += 0.15
	_level_up_action()
	
func SplitSwordQi12():
	PC.selected_rewards.append("SplitSwordQi12")
	_level_up_action()
	
func SplitSwordQi13():
	PC.selected_rewards.append("SplitSwordQi13")
	_level_up_action()
	
func SplitSwordQi21():
	PC.selected_rewards.append("SplitSwordQi21")
	_level_up_action()
	
func SplitSwordQi22():
	PC.selected_rewards.append("SplitSwordQi22")
	_level_up_action()
	
func SplitSwordQi23():
	PC.selected_rewards.append("SplitSwordQi23")
	_level_up_action()
	
func SplitSwordQi31():
	PC.selected_rewards.append("SplitSwordQi31")
	PC.swordQi_penetration_count += 2
	_level_up_action()
	
func SplitSwordQi32():
	PC.selected_rewards.append("SplitSwordQi32")
	_level_up_action()
	
func SplitSwordQi33():
	PC.selected_rewards.append("SplitSwordQi33")
	_level_up_action()
	
# 全局升级效果处理函数 (当选择某些特定被动后，升级时会触发额外属性转换)
func global_level_up():
	# 基础属性成长：攻击+1再乘以1.025，HP上限+2再乘以1.01
	PC.pc_atk = int((PC.pc_atk+1) * 1.025)
	PC.pc_max_hp = int((PC.pc_max_hp+2) * 1.01)

	# --- 根据已选被动技能，处理属性转换 --- 
	# "aSpdToAH1": 攻击速度变化量的一部分转化为攻击和HP (等级1)
	if PC.selected_rewards.has("aSpdToAH1") and PC.last_atk_speed != PC.pc_atk_speed:
		var changeNum = PC.pc_atk_speed - PC.last_atk_speed # 计算攻速变化
		PC.pc_atk = int(PC.pc_atk * (1 + (changeNum / 4))) # 攻速变化的1/4转化为攻击力百分比提升
		PC.pc_max_hp = int(PC.pc_max_hp * (1 + (changeNum / 4))) # 攻速变化的1/4转化为HP上限百分比提升

	# "lukcyToAH1": 幸运等级变化量的一部分转化为攻击和HP (等级1)
	if PC.selected_rewards.has("lukcyToAH1") and PC.last_lunky_level != PC.now_lunky_level:
		var changeNum = PC.now_lunky_level - PC.last_lunky_level # 计算幸运等级变化
		PC.pc_atk = int(PC.pc_atk * (1 + (changeNum / 100))) # 每点幸运等级变化转化为1%攻击力提升
		PC.pc_max_hp = int(PC.pc_max_hp * (1 + (changeNum / 100))) # 每点幸运等级变化转化为1%HP上限提升

	# "spdToAH1": 移动速度变化量的一部分转化为攻击和HP (等级1)
	if PC.selected_rewards.has("spdToAH1") and PC.last_speed != PC.pc_speed:
		var changeNum = PC.pc_speed - PC.last_speed # 计算移速变化
		PC.pc_atk = int(PC.pc_atk * (1 + (changeNum / 5))) # 移速变化的1/5转化为攻击力百分比提升
		PC.pc_max_hp = int(PC.pc_max_hp * (1 + (changeNum / 5))) # 移速变化的1/5转化为HP上限百分比提升

	# "aSpdToAH2": 攻击速度变化量的一部分转化为攻击和HP (等级2)
	if PC.selected_rewards.has("aSpdToAH2") and PC.last_atk_speed != PC.pc_atk_speed:
		var changeNum = PC.pc_atk_speed - PC.last_atk_speed
		PC.pc_atk = int(PC.pc_atk * (1 + (changeNum / 3))) # 攻速变化的1/3转化为攻击力百分比提升
		PC.pc_max_hp = int(PC.pc_max_hp * (1 + (changeNum / 3))) # 攻速变化的1/3转化为HP上限百分比提升

	# "lukcyToAH2": 幸运等级变化量的一部分转化为攻击和HP (等级2)
	if PC.selected_rewards.has("lukcyToAH2") and PC.last_lunky_level != PC.now_lunky_level:
		var changeNum = PC.now_lunky_level - PC.last_lunky_level
		PC.pc_atk = int(PC.pc_atk * (1 + 0.0125 * changeNum)) # 每点幸运等级变化转化为1.25%攻击力提升
		PC.pc_max_hp = int(PC.pc_max_hp * (1 + 0.0125 * changeNum)) # 每点幸运等级变化转化为1.25%HP上限提升

	# "spdToAH2": 移动速度变化量的一部分转化为攻击和HP (等级2)
	if PC.selected_rewards.has("spdToAH2") and PC.last_speed != PC.pc_speed:
		var changeNum = PC.pc_speed - PC.last_speed
		PC.pc_atk = int(PC.pc_atk * (1 + (changeNum / 4))) # 移速变化的1/4转化为攻击力百分比提升
		PC.pc_max_hp = int(PC.pc_max_hp * (1 + (changeNum / 4))) # 移速变化的1/4转化为HP上限百分比提升

	# "aSpdToAH3": 攻击速度变化量的一部分转化为攻击和HP (等级3)
	if PC.selected_rewards.has("aSpdToAH3") and PC.last_atk_speed != PC.pc_atk_speed:
		var changeNum = PC.pc_atk_speed - PC.last_atk_speed
		PC.pc_atk = int(PC.pc_atk * (1 + (changeNum / 2))) # 攻速变化的1/2转化为攻击力百分比提升
		PC.pc_max_hp = int(PC.pc_max_hp * (1 + (changeNum / 2))) # 攻速变化的1/2转化为HP上限百分比提升

	# "lukcyToAH3": 幸运等级变化量的一部分转化为攻击和HP (等级3)
	if PC.selected_rewards.has("lukcyToAH3") and PC.last_lunky_level != PC.now_lunky_level:
		var changeNum = PC.now_lunky_level - PC.last_lunky_level
		PC.pc_atk = int(PC.pc_atk * (1 + 0.015 * changeNum)) # 每点幸运等级变化转化为1.5%攻击力提升
		PC.pc_max_hp = int(PC.pc_max_hp * (1 + 0.015 * changeNum)) # 每点幸运等级变化转化为1.5%HP上限提升

	# "spdToAH3": 移动速度变化量的一部分转化为攻击和HP (等级3)
	if PC.selected_rewards.has("spdToAH3") and PC.last_speed != PC.pc_speed:
		var changeNum = PC.pc_speed - PC.last_speed
		PC.pc_atk = int(PC.pc_atk * (1 + (changeNum / 3))) # 移速变化的1/3转化为攻击力百分比提升
		PC.pc_max_hp = int(PC.pc_max_hp * (1 + (changeNum / 3))) # 移速变化的1/3转化为HP上限百分比提升

	# 更新上次属性记录，用于下次比较变化
	PC.last_lunky_level = PC.now_lunky_level
	PC.last_speed = PC.pc_speed
	PC.last_atk_speed = PC.pc_atk_speed

	# 处理生命恢复效果 (基于 "hpRecover" 标记的数量)
	var recoverUp = PC.selected_rewards.count("hpRecover") # 获取 "hpRecover" 标记的数量
	var recoverNum = (0.4 + recoverUp * 0.2) * PC.pc_max_hp # 基础恢复40%HP，每多一个标记额外恢复20%HP
	if PC.pc_hp + recoverNum > PC.pc_max_hp: # 如果恢复后超过HP上限
		PC.pc_hp = PC.pc_max_hp # 则设置为HP上限
	else:
		PC.pc_hp += int(recoverNum) # 否则直接增加恢复量
