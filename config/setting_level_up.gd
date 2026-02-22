extends Node

# 全局奖励列表，从CSV加载
var all_rewards_list: Array[Reward] = []

# 定义奖励数据结构
class Reward: # Reward 类定义了单个奖励所包含的所有属性。
	var id: String
	var rarity: String # 稀有度，例如: white, green, skyblue, darkorchid, gold, red 等。
	var reward_name: String # 技能/奖励的名称。
	var if_main_skill: bool # 布尔值，标记这是否是一个主要技能。
	var icon: String # 指向技能图标资源的路径字符串。
	var detail: String # 技能/奖励的详细描述文本。
	var max_acquisitions: int # 该奖励能被玩家获取的最大次数。
	var faction: String # 奖励所属的派系或类别。
	var chinese_faction: String # 中文派系
	var weight: float # 用于随机抽取的权重值。
	var if_advance: bool # 布尔值，标记这是否是一个进阶技能（通常在特定等级，如每5级出现）。
	var precondition: String # 获取此奖励所需的前置奖励ID，多个ID用逗号分隔。
	var on_selected: String # 当奖励被选中时，需要调用的函数名称字符串。
	var tags: String # 标签，用于分类或筛选奖励。多个标签用逗号分隔。


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
			var expected_headers = ["id", "rarity", "reward_name", "if_main_skill", "icon", "detail", "max_acquisitions", "faction", "weight", "if_advance", "precondition", "tags", "chinese_faction"]

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
			var weight_str = reward_data.get("weight", "1.0")
			new_reward.weight = float(weight_str) if weight_str.is_valid_float() else 1.0
			new_reward.if_advance = reward_data.get("if_advance", "false").to_lower() == "true"
			new_reward.precondition = reward_data.get("precondition", "")
			# 读取CSV中的标签字段，多个标签以逗号分隔
			new_reward.tags = reward_data.get("tags", "")
			new_reward.on_selected = "reward_" + new_reward.id

			all_rewards_list.append(new_reward)
	
	file.close()
	print("成功从 ", file_path, " 加载 ", all_rewards_list.size(), " 个奖励")


func get_reward_level(rand_num: float, main_skill_name: String = '') -> Reward:
	print_debug("get_reward_level - main_skill_name: ", main_skill_name)
	var selected_reward: Reward
	if rand_num <= PC.now_red_p:
		selected_reward = select_reward('red', main_skill_name)
	elif rand_num <= PC.now_gold_p + PC.now_red_p:
		selected_reward = select_reward('gold', main_skill_name)
	elif rand_num <= PC.now_darkorchid_p + PC.now_gold_p + PC.now_red_p:
		selected_reward = select_reward('darkorchid', main_skill_name)
	else:
		selected_reward = select_reward('skyblue', main_skill_name)

	if selected_reward != null:
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

	return filtered_rewards
	

func _level_up_action():
	all_rewards_list = []
	_load_rewards_from_csv("res://Config/reward.csv")
	global_level_up()
	
	# 更新技能攻击速度（当攻速属性改变时）
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("update_skill_attack_speeds"):
		player.update_skill_attack_speeds()
		# 发射信号通知技能攻速更新
		Global.emit_signal("skill_attack_speed_updated")
	
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
			# 当奖励的tags包含"emblem"，且当前纹章数量已达上限时，直接跳过该奖励
			var is_emblem_reward := false
			if r.tags != "":
				var tag_list: Array = r.tags.split(",")
				for t in tag_list:
					if t == "emblem":
						is_emblem_reward = true
						break
			if is_emblem_reward and EmblemManager.get_emblem_count() >= PC.emblem_slots_max:
				print_debug("纹章已达上限，跳过奖励: " + r.id)
				continue
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
		elif main_skill_name != '':
			var noReward = Reward.new()
			noReward.reward_name = "noReward"
			return noReward
	
	print_debug("稀有度 '" + csv_rarity_name + "' 已达到最大重抽次数。将返回null或该稀有度下首个可用的奖励。")
	# 如果达到最大重抽次数或未找到合适奖励时的回退逻辑。
	var all_rewards_for_rarity_fallback = _get_rewards_by_rarity_str(csv_rarity_name, main_skill_name)
	if not all_rewards_for_rarity_fallback.is_empty():
		# 尝试返回一个没有前置条件、或前置条件已满足、且未达到最大获取次数的奖励。
		for fallback_reward in all_rewards_for_rarity_fallback:
			# 同样在回退逻辑中排除纹章奖励（已达上限时）
			var fb_is_emblem := false
			if fallback_reward.tags != "":
				var fb_tags: Array = fallback_reward.tags.split(",")
				for t in fb_tags:
					if t.strip_edges() == "emblem":
						fb_is_emblem = true
						break
			if fb_is_emblem and EmblemManager.get_emblem_count() >= PC.emblem_slots_max:
				print_debug("纹章已达上限，回退时跳过奖励: " + fallback_reward.id)
				continue
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
	var actual_rarity_levels: Array[String] = ["white", "green", "skyblue", "darkorchid", "gold", "red"]
	for other_rarity_name in actual_rarity_levels:
		if other_rarity_name == csv_rarity_name: # 跳过当前已尝试过的稀有度
			continue

		var rewards_from_other_rarity = _get_rewards_by_rarity_str(other_rarity_name, main_skill_name)
		
		if not rewards_from_other_rarity.is_empty():
			for potential_reward in rewards_from_other_rarity:
				# 其他稀有度回退同样排除纹章奖励（已达上限时）
				var other_is_emblem := false
				if potential_reward.tags != "":
					var other_tags: Array = potential_reward.tags.split(",")
					for t in other_tags:
						if t.strip_edges() == "emblem":
							other_is_emblem = true
							break
				if other_is_emblem and EmblemManager.get_emblem_count() >= PC.emblem_slots_max:
					print_debug("纹章已达上限，跨稀有度跳过奖励: " + potential_reward.id)
					continue
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
	
func check_SR27() -> bool:
	return PC.selected_rewards.has("ring_bullet")
	
func check_SR30() -> bool:
	return PC.selected_rewards.has("wave_bullet")

func check_not_have_SR27() -> bool:
	return not PC.selected_rewards.has("ring_bullet")
	
func check_not_have_SR30() -> bool:
	return not PC.selected_rewards.has("wave_bullet")

# 检查子弹大小是否小于等于2.0 (通用子弹大小相关技能的前置条件)
func check_bullet_size_condition() -> bool:
	return PC.bullet_size <= 2.0

func check_branch_condition() -> bool:
	return PC.selected_rewards.has("branch")
	
func check_moyan_condition() -> bool:
	return PC.selected_rewards.has("moyan")
	
func check_SplitSwordQi1() -> bool:
	return PC.selected_rewards.has("SplitSwordQi1")
	
func check_SplitSwordQi2() -> bool:
	return PC.selected_rewards.has("SplitSwordQi2")
	
func check_SplitSwordQi3() -> bool:
	return PC.selected_rewards.has("SplitSwordQi3")

func check_not_have_swordQi() -> bool:
	return not PC.selected_rewards.has("swordQi")
func check_not_have_branch() -> bool:
	return not PC.selected_rewards.has("branch")
func check_not_have_moyan() -> bool:
	return not PC.selected_rewards.has("moyan")
func check_not_have_riyan() -> bool:
	return not PC.selected_rewards.has("riyan")
func check_not_have_ringFire() -> bool:
	return not PC.selected_rewards.has("ringFire")
func check_not_have_thunder() -> bool:
	return not PC.selected_rewards.has("thunder")
func check_not_have_bloodwave() -> bool:
	return not PC.selected_rewards.has("bloodwave")

func check_thunder_condition() -> bool:
	return PC.selected_rewards.has("thunder")
func check_bloodwave_condition() -> bool:
	return PC.selected_rewards.has("bloodwave")

func check_bloodboardsword_condition() -> bool:
	return PC.selected_rewards.has("bloodboardsword")

func check_thunder1() -> bool:
	return PC.selected_rewards.has("Thunder1")

func check_thunder2() -> bool:
	return PC.selected_rewards.has("Thunder2")

func check_thunder3() -> bool:
	return PC.selected_rewards.has("Thunder3")
func check_bloodwave1() -> bool:
	return PC.selected_rewards.has("Bloodwave1")
func check_bloodwave2() -> bool:
	return PC.selected_rewards.has("Bloodwave2")
func check_bloodwave3() -> bool:
	return PC.selected_rewards.has("Bloodwave3")

func check_bloodboardsword1() -> bool:
	return PC.selected_rewards.has("BloodBoardSword1")

func check_bloodboardsword2() -> bool:
	return PC.selected_rewards.has("BloodBoardSword2")

func check_bloodboardsword3() -> bool:
	return PC.selected_rewards.has("BloodBoardSword3")

func check_not_have_bloodboardsword() -> bool:
	return not PC.selected_rewards.has("bloodboardsword")

func check_not_have_ice() -> bool:
	return not PC.selected_rewards.has("Ice")

func check_ice_condition() -> bool:
	return PC.selected_rewards.has("Ice")

func check_ice_condition1() -> bool:
	return PC.selected_rewards.has("Ice1")

func check_ice_condition2() -> bool:
	return PC.selected_rewards.has("Ice2")

func check_ice_condition3() -> bool:
	return PC.selected_rewards.has("Ice3")

func check_ice_condition4() -> bool:
	return PC.selected_rewards.has("Ice4")

func check_ice_condition5() -> bool:
	return PC.selected_rewards.has("Ice5")

func check_not_have_thunderbreak() -> bool:
	return not PC.selected_rewards.has("ThunderBreak")

func check_thunderbreak_condition() -> bool:
	return PC.selected_rewards.has("ThunderBreak")

func check_thunderbreak1() -> bool:
	return PC.selected_rewards.has("ThunderBreak1") and PC.selected_rewards.has("ThunderBreak2")

func check_thunderbreak2() -> bool:
	return PC.selected_rewards.has("ThunderBreak2") and PC.selected_rewards.has("ThunderBreak4")

func check_thunderbreak3() -> bool:
	return PC.selected_rewards.has("ThunderBreak1") and PC.selected_rewards.has("ThunderBreak3")

func check_not_have_lightbullet() -> bool:
	return not PC.selected_rewards.has("LightBullet")

# Qigong Rewards
func reward_qigong():
	PC.selected_rewards.append("qigong")
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get("qigong_fire_speed"):
		player.qigong_fire_speed.start()
	_level_up_action()

func reward_RQigong():
	PC.selected_rewards.append("RQigong")
	Qigong.main_skill_qigong_damage += 0.12
	_level_up_action()

func reward_SRQigong():
	PC.selected_rewards.append("SRQigong")
	Qigong.main_skill_qigong_damage += 0.13
	_level_up_action()

func reward_SSRQigong():
	PC.selected_rewards.append("SSRQigong")
	Qigong.main_skill_qigong_damage += 0.14
	_level_up_action()

func reward_URQigong():
	PC.selected_rewards.append("URQigong")
	Qigong.main_skill_qigong_damage += 0.16
	_level_up_action()

func reward_Qigong1():
	PC.selected_rewards.append("Qigong1")
	_level_up_action()

func reward_Qigong2():
	PC.selected_rewards.append("Qigong2")
	_level_up_action()

func reward_Qigong3():
	PC.selected_rewards.append("Qigong3")
	_level_up_action()

func reward_Qigong4():
	PC.selected_rewards.append("Qigong4")
	_level_up_action()

func reward_Qigong5():
	PC.selected_rewards.append("Qigong5")
	_level_up_action()

func reward_Qigong11():
	PC.selected_rewards.append("Qigong11")
	_level_up_action()

func reward_Qigong22():
	PC.selected_rewards.append("Qigong22")
	_level_up_action()

func reward_Qigong33():
	PC.selected_rewards.append("Qigong33")
	_level_up_action()

func reward_Qigong44():
	PC.selected_rewards.append("Qigong44")
	_level_up_action()

func reward_Qigong55():
	PC.selected_rewards.append("Qigong55")
	_level_up_action()

# Qigong Preconditions
func check_not_have_qigong() -> bool:
	return not PC.selected_rewards.has("qigong")

func check_qigong_condition() -> bool:
	return PC.selected_rewards.has("qigong")

func check_qigong1() -> bool:
	return PC.selected_rewards.has("Qigong1")

func check_qigong2() -> bool:
	return PC.selected_rewards.has("Qigong2")

func check_qigong3() -> bool:
	return PC.selected_rewards.has("Qigong3")

func check_qigong4() -> bool:
	return PC.selected_rewards.has("Qigong4")

func check_lightbullet_condition() -> bool:
	return PC.selected_rewards.has("LightBullet")

func check_lightbullet_condition1() -> bool:
	return PC.selected_rewards.has("LightBullet5") and PC.selected_rewards.has("LightBullet2")

func check_lightbullet_condition2() -> bool:
	return PC.selected_rewards.has("LightBullet4") and PC.selected_rewards.has("LightBullet1")

func check_lightbullet_condition3() -> bool:
	return PC.selected_rewards.has("LightBullet2") and PC.selected_rewards.has("LightBullet3")

func check_lightbullet_condition4() -> bool:
	return PC.selected_rewards.has("LightBullet1") and PC.selected_rewards.has("LightBullet4")

func check_not_have_water() -> bool:
	return not PC.selected_rewards.has("Water")

func check_water_condition() -> bool:
	return PC.selected_rewards.has("Water")

func check_water_condition1() -> bool:
	return PC.selected_rewards.has("Water1") and PC.selected_rewards.has("Water2")

func check_water_condition2() -> bool:
	return PC.selected_rewards.has("Water3") and PC.selected_rewards.has("Water4")

func check_water_condition3() -> bool:
	return PC.selected_rewards.has("Water1") and PC.selected_rewards.has("Water4")

func check_not_have_qiankun() -> bool:
	return not PC.selected_rewards.has("Qiankun")

func check_qiankun_condition() -> bool:
	return PC.selected_rewards.has("Qiankun")

func check_qiankun_condition1() -> bool:
	return PC.selected_rewards.has("Qiankun1") and PC.selected_rewards.has("Qiankun3")

func check_qiankun_condition2() -> bool:
	return PC.selected_rewards.has("Qiankun2") and PC.selected_rewards.has("Qiankun3")

func check_qiankun_condition3() -> bool:
	return PC.selected_rewards.has("Qiankun2") and PC.selected_rewards.has("Qiankun4")

func check_branch1() -> bool:
	return PC.selected_rewards.has("branch1")

func check_branch2() -> bool:
	return PC.selected_rewards.has("branch2")

func check_branch3() -> bool:
	return PC.selected_rewards.has("branch3")

func check_branch12() -> bool:
	return PC.selected_rewards.has("branch1") and PC.selected_rewards.has("branch2")

func check_summon_condition() -> bool:
	return PC.summon_count < PC.summon_count_max
	
func check_get_new_main_skill() -> bool:
	if PC.now_main_skill_num + 1 < Global.max_main_skill_num:
		return true
	else:
		return false

func check_moyan12() -> bool:
	return PC.selected_rewards.has("moyan1") and PC.selected_rewards.has("moyan2")

func check_moyan13() -> bool:
	return PC.selected_rewards.has("moyan1") and PC.selected_rewards.has("moyan3")

func check_moyan23() -> bool:
	return PC.selected_rewards.has("moyan3") and PC.selected_rewards.has("moyan2")


# --- 以下为具体的奖励效果实现函数 --- 

func reward_R01():
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.1)
	EmblemManager.add_emblem("xueqi", 1)
	_level_up_action()

func reward_SR01():
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.11)
	EmblemManager.add_emblem("xueqi", 1)
	_level_up_action()

func reward_SSR01():
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.12)
	EmblemManager.add_emblem("xueqi", 1)
	_level_up_action()

func reward_UR01():
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.14)
	EmblemManager.add_emblem("xueqi", 2)
	_level_up_action()

func reward_R02():
	PC.pc_atk = int(PC.pc_atk + 4)
	PC.pc_atk_speed += 0.015
	EmblemManager.add_emblem("pozhen", 1)
	_level_up_action()

func reward_SR02():
	PC.pc_atk = int(PC.pc_atk + 5)
	PC.pc_atk_speed += 0.02
	EmblemManager.add_emblem("pozhen", 1)
	_level_up_action()

func reward_SSR02():
	PC.pc_atk = int(PC.pc_atk + 6)
	PC.pc_atk_speed += 0.025
	EmblemManager.add_emblem("pozhen", 1)
	_level_up_action()

func reward_UR02():
	PC.pc_atk = int(PC.pc_atk + 8)
	PC.pc_atk_speed += 0.05
	EmblemManager.add_emblem("pozhen", 2)
	_level_up_action()

func reward_R03():
	PC.pc_atk_speed += 0.02
	EmblemManager.add_emblem("jinghong", 1)
	_level_up_action()

func reward_SR03():
	PC.pc_atk_speed += 0.04
	EmblemManager.add_emblem("jinghong", 1)
	_level_up_action()

func reward_SSR03():
	PC.pc_atk_speed += 0.07
	EmblemManager.add_emblem("jinghong", 1)
	_level_up_action()

func reward_UR03():
	PC.pc_atk_speed += 0.13
	EmblemManager.add_emblem("jinghong", 2)
	_level_up_action()

func reward_R04():
	PC.pc_speed += 0.07
	PC.crit_chance += 0.01
	EmblemManager.add_emblem("tafeng", 1)
	_level_up_action()

func reward_SR04():
	PC.pc_speed += 0.10
	PC.crit_chance += 0.015
	EmblemManager.add_emblem("tafeng", 1)
	_level_up_action()

func reward_SSR04():
	PC.pc_speed += 0.14
	PC.crit_chance += 0.02
	EmblemManager.add_emblem("tafeng", 1)
	_level_up_action()

func reward_UR04():
	PC.pc_speed += 0.22
	PC.crit_chance += 0.03
	EmblemManager.add_emblem("tafeng", 2)
	_level_up_action()

func reward_R05():
	PC.pc_atk_speed += 0.06
	PC.pc_speed -= 0.03
	EmblemManager.add_emblem("chenjing", 1)
	_level_up_action()

func reward_SR05():
	PC.pc_atk_speed += 0.08
	PC.pc_speed -= 0.035
	EmblemManager.add_emblem("chenjing", 1)
	_level_up_action()

func reward_SSR05():
	PC.pc_atk_speed += 0.11
	PC.pc_speed -= 0.04
	EmblemManager.add_emblem("chenjing", 1)
	_level_up_action()

func reward_UR05():
	PC.pc_atk_speed += 0.17
	PC.pc_speed -= 0.05
	EmblemManager.add_emblem("chenjing", 2)
	_level_up_action()
	
func reward_R06():
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.05)
	PC.damage_reduction_rate = min(PC.damage_reduction_rate + 0.01, 0.7)
	PC.pc_speed -= 0.03
	EmblemManager.add_emblem("lianti", 1)
	_level_up_action()

func reward_SR06():
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.07)
	PC.damage_reduction_rate = min(PC.damage_reduction_rate + 0.015, 0.7)
	PC.pc_speed -= 0.04
	EmblemManager.add_emblem("lianti", 1)
	_level_up_action()

func reward_SSR06():
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.10)
	PC.damage_reduction_rate = min(PC.damage_reduction_rate + 0.02, 0.7)
	PC.pc_speed -= 0.06
	EmblemManager.add_emblem("lianti", 1)
	_level_up_action()

func reward_UR06():
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.14)
	PC.damage_reduction_rate = min(PC.damage_reduction_rate + 0.04, 0.7)
	PC.pc_speed -= 0.06
	EmblemManager.add_emblem("lianti", 2)
	_level_up_action()

func reward_R07():
	PC.pc_speed += 0.12
	PC.pc_atk = int(PC.pc_atk - PC.pc_start_atk * 0.02)
	EmblemManager.add_emblem("jianbu", 1)
	_level_up_action()

func reward_SR07():
	PC.pc_speed += 0.15
	PC.pc_atk = int(PC.pc_atk - PC.pc_start_atk * 0.025)
	EmblemManager.add_emblem("jianbu", 1)
	_level_up_action()

func reward_SSR07():
	PC.pc_speed += 0.19
	PC.pc_atk = int(PC.pc_atk - PC.pc_start_atk * 0.03)
	EmblemManager.add_emblem("jianbu", 1)
	_level_up_action()

func reward_UR07():
	PC.pc_speed += 0.27
	PC.pc_atk = int(PC.pc_atk - PC.pc_start_atk * 0.04)
	EmblemManager.add_emblem("jianbu", 2)
	_level_up_action()

func reward_R08():
	PC.pc_atk = int(PC.pc_atk + 6)
	PC.pc_atk_speed -= 0.03
	EmblemManager.add_emblem("manli", 1)
	_level_up_action()

func reward_SR08():
	PC.pc_atk = int(PC.pc_atk + 8)
	PC.pc_atk_speed -= 0.03
	EmblemManager.add_emblem("manli", 1)
	_level_up_action()

func reward_SSR08():
	PC.pc_atk = int(PC.pc_atk + 10)
	PC.pc_atk_speed -= 0.035
	EmblemManager.add_emblem("manli", 1)
	_level_up_action()

func reward_UR08():
	PC.pc_atk = int(PC.pc_atk + 14)
	PC.pc_atk_speed -= 0.045
	EmblemManager.add_emblem("manli", 2)
	_level_up_action()

func reward_R09():
	PC.now_lunky_level += 4
	Global.emit_signal("lucky_level_up", 4)
	_level_up_action()

func reward_SR09():
	PC.now_lunky_level += 5
	Global.emit_signal("lucky_level_up", 5)
	_level_up_action()

func reward_SSR09():
	PC.now_lunky_level += 6
	Global.emit_signal("lucky_level_up", 6)
	_level_up_action()

func reward_UR09():
	PC.now_lunky_level += 8
	Global.emit_signal("lucky_level_up", 8)
	_level_up_action()

func reward_R10():
	PC.pc_atk = int(PC.pc_atk + 4)
	EmblemManager.add_emblem("ronghui", 1)
	_level_up_action()

func reward_SR10():
	PC.pc_atk = int(PC.pc_atk + 5)
	EmblemManager.add_emblem("ronghui", 1)
	_level_up_action()

func reward_SSR10():
	PC.pc_atk = int(PC.pc_atk + 6)
	EmblemManager.add_emblem("ronghui", 1)
	_level_up_action()

func reward_UR10():
	PC.pc_atk = int(PC.pc_atk + 8)
	EmblemManager.add_emblem("ronghui", 2)
	_level_up_action()


func reward_R11():
	PC.selected_rewards.append("R11")
	_level_up_action()

func reward_SR11():
	PC.selected_rewards.append("SR11")
	_level_up_action()

func reward_SSR11():
	PC.selected_rewards.append("SSR11")
	_level_up_action()

func reward_UR11():
	PC.selected_rewards.append("UR11")
	_level_up_action()

func reward_R12():
	PC.selected_rewards.append("R12")
	_level_up_action()

func reward_SR12():
	PC.selected_rewards.append("SR12")
	_level_up_action()

func reward_SSR12():
	PC.selected_rewards.append("SSR12")
	_level_up_action()

func reward_UR12():
	PC.selected_rewards.append("UR12")
	_level_up_action()

func reward_R13():
	PC.selected_rewards.append("R13")
	_level_up_action()

func reward_SR13():
	PC.selected_rewards.append("SR13")
	_level_up_action()

func reward_SSR13():
	PC.selected_rewards.append("SSR13")
	_level_up_action()

func reward_UR13():
	PC.selected_rewards.append("UR13")
	_level_up_action()

func reward_R14():
	PC.crit_chance += 0.04
	PC.pc_atk_speed += 0.04
	_level_up_action()

func reward_SR14():
	PC.crit_chance += 0.05
	PC.pc_atk_speed += 0.05
	_level_up_action()

func reward_SSR14():
	PC.crit_chance += 0.06
	PC.pc_atk_speed += 0.06
	_level_up_action()

func reward_UR14():
	PC.crit_chance += 0.08
	PC.pc_atk_speed += 0.08
	_level_up_action()

func reward_R15():
	PC.crit_damage_multi += 0.08
	PC.pc_atk_speed += 0.04
	_level_up_action()

func reward_SR15():
	PC.crit_damage_multi += 0.10
	PC.pc_atk_speed += 0.05
	_level_up_action()

func reward_SSR15():
	PC.crit_damage_multi += 0.12
	PC.pc_atk_speed += 0.06
	_level_up_action()

func reward_UR15():
	PC.crit_damage_multi += 0.16
	PC.pc_atk_speed += 0.08
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

func reward_UR16():
	PC.crit_chance += 0.011
	PC.crit_damage_multi += 0.2
	_level_up_action()

func reward_R17():
	PC.bullet_size += 0.1
	PC.pc_atk_speed += 0.08
	_level_up_action()

func reward_SR17():
	PC.bullet_size += 0.1
	PC.pc_atk_speed += 0.11
	_level_up_action()

func reward_SSR17():
	PC.bullet_size += 0.15
	PC.pc_atk_speed += 0.12
	_level_up_action()

func reward_UR17():
	PC.bullet_size += 0.15
	PC.pc_atk_speed += 0.16
	_level_up_action()

func reward_R18():
	var hp_sacrifice = int(PC.pc_max_hp * 0.16)
	PC.pc_max_hp -= hp_sacrifice
	PC.pc_atk = int(PC.pc_atk + hp_sacrifice * 0.2)
	if PC.pc_hp > PC.pc_max_hp:
		PC.pc_hp = PC.pc_max_hp
	_level_up_action()

func reward_SR18():
	var hp_sacrifice = int(PC.pc_max_hp * 0.18)
	PC.pc_max_hp -= hp_sacrifice
	PC.pc_atk = int(PC.pc_atk + hp_sacrifice * 0.22)
	if PC.pc_hp > PC.pc_max_hp:
		PC.pc_hp = PC.pc_max_hp
	_level_up_action()

func reward_SSR18():
	var hp_sacrifice = int(PC.pc_max_hp * 0.20)
	PC.pc_max_hp -= hp_sacrifice
	PC.pc_atk = int(PC.pc_atk + hp_sacrifice * 0.24)
	if PC.pc_hp > PC.pc_max_hp:
		PC.pc_hp = PC.pc_max_hp
	_level_up_action()

func reward_UR18():
	var hp_sacrifice = int(PC.pc_max_hp * 0.24)
	PC.pc_max_hp -= hp_sacrifice
	PC.pc_atk = int(PC.pc_atk + hp_sacrifice * 0.28)
	if PC.pc_hp > PC.pc_max_hp:
		PC.pc_hp = PC.pc_max_hp
	_level_up_action()

func reward_R19():
	PC.pc_max_hp = int(PC.pc_max_hp * 1.10)
	PC.damage_reduction += 0.005
	var extra_hp_bonus = min(0.20, PC.damage_reduction * 0.004)
	PC.pc_max_hp = int(PC.pc_max_hp * (1 + extra_hp_bonus))
	_level_up_action()

func reward_SR19():
	PC.pc_max_hp = int(PC.pc_max_hp * 1.11)
	PC.damage_reduction += 0.01
	var extra_hp_bonus = min(0.20, PC.damage_reduction * 0.004)
	PC.pc_max_hp = int(PC.pc_max_hp * (1 + extra_hp_bonus))
	_level_up_action()

func reward_SSR19():
	PC.pc_max_hp = int(PC.pc_max_hp * 1.12)
	PC.damage_reduction += 0.015
	var extra_hp_bonus = min(0.20, PC.damage_reduction * 0.004)
	PC.pc_max_hp = int(PC.pc_max_hp * (1 + extra_hp_bonus))
	_level_up_action()

func reward_UR19():
	PC.pc_max_hp = int(PC.pc_max_hp * 1.14)
	PC.damage_reduction += 0.025
	var extra_hp_bonus = min(0.20, PC.damage_reduction * 0.004)
	PC.pc_max_hp = int(PC.pc_max_hp * (1 + extra_hp_bonus))
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

func reward_Ice():
	IceFlower.reset_data()
	PC.selected_rewards.append("Ice")
	# 初始化冷却时间
	var player = get_tree().get_first_node_in_group("player")
	if player and player.ice_flower_fire_speed:
		player.ice_flower_fire_speed.start()
	_level_up_action()

func reward_RIce():
	PC.main_skill_ice += 1
	IceFlower.main_skill_ice_damage += 0.12
	_level_up_action()

func reward_SRIce():
	PC.main_skill_ice += 1
	IceFlower.main_skill_ice_damage += 0.13
	_level_up_action()

func reward_SSRIce():
	PC.main_skill_ice += 1
	IceFlower.main_skill_ice_damage += 0.14
	_level_up_action()

func reward_URIce():
	PC.main_skill_ice += 1
	IceFlower.main_skill_ice_damage += 0.16
	_level_up_action()

func reward_Ice1():
	PC.selected_rewards.append("Ice1")
	_level_up_action()

func reward_Ice2():
	PC.selected_rewards.append("Ice2")
	_level_up_action()

func reward_Ice3():
	PC.selected_rewards.append("Ice3")
	_level_up_action()

func reward_Ice4():
	PC.selected_rewards.append("Ice4")
	_level_up_action()

func reward_Ice5():
	PC.selected_rewards.append("Ice5")
	_level_up_action()

func reward_Ice11():
	PC.selected_rewards.append("Ice11")
	_level_up_action()

func reward_Ice22():
	PC.selected_rewards.append("Ice22")
	_level_up_action()

func reward_Ice33():
	PC.selected_rewards.append("Ice33")
	_level_up_action()

func reward_Ice44():
	PC.selected_rewards.append("Ice44")
	_level_up_action()

func reward_Ice55():
	PC.selected_rewards.append("Ice55")
	_level_up_action()

# --- 天雷破相关奖励函数 ---
func reward_ThunderBreak():
	PC.selected_rewards.append("ThunderBreak")
	# 初始化冷却时间
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get("thunder_break_fire_speed"):
		player.thunder_break_fire_speed.start()
	_level_up_action()

func reward_RThunderBreak():
	PC.main_skill_thunder_break += 1
	PC.thunder_break_final_damage_multi += 0.2
	_level_up_action()

func reward_SRThunderBreak():
	PC.main_skill_thunder_break += 1
	PC.thunder_break_final_damage_multi += 0.25
	_level_up_action()

func reward_SSRThunderBreak():
	PC.main_skill_thunder_break += 1
	PC.thunder_break_final_damage_multi += 0.3
	_level_up_action()

func reward_URThunderBreak():
	PC.main_skill_thunder_break += 1
	PC.thunder_break_final_damage_multi += 0.4
	_level_up_action()

func reward_ThunderBreak1():
	PC.thunder_break_final_damage_multi += 0.4
	PC.selected_rewards.append("ThunderBreak1")
	_level_up_action()

func reward_ThunderBreak2():
	PC.thunder_break_final_damage_multi += 0.3
	PC.selected_rewards.append("ThunderBreak2")
	_level_up_action()

func reward_ThunderBreak3():
	PC.thunder_break_final_damage_multi += 0.2
	PC.selected_rewards.append("ThunderBreak3")
	_level_up_action()

func reward_ThunderBreak4():
	PC.thunder_break_final_damage_multi += 0.2
	PC.selected_rewards.append("ThunderBreak4")
	_level_up_action()

func reward_ThunderBreak11():
	PC.thunder_break_final_damage_multi += 0.3
	PC.selected_rewards.append("ThunderBreak11")
	_level_up_action()

func reward_ThunderBreak22():
	PC.thunder_break_final_damage_multi += 0.4
	PC.selected_rewards.append("ThunderBreak22")
	_level_up_action()

func reward_ThunderBreak33():
	PC.thunder_break_final_damage_multi += 0.8
	PC.selected_rewards.append("ThunderBreak33")
	_level_up_action()


# --- 光弹相关奖励函数 ---
func reward_LightBullet():
	PC.selected_rewards.append("LightBullet")
	# 初始化冷却时间
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get("light_bullet_fire_speed"):
		player.light_bullet_fire_speed.start()
	_level_up_action()

func reward_RLightBullet():
	PC.main_skill_light_bullet += 1
	PC.light_bullet_final_damage_multi += 0.12
	_level_up_action()

func reward_SRLightBullet():
	PC.main_skill_light_bullet += 1
	PC.light_bullet_final_damage_multi += 0.13
	_level_up_action()

func reward_SSRLightBullet():
	PC.main_skill_light_bullet += 1
	PC.light_bullet_final_damage_multi += 0.14
	_level_up_action()

func reward_URLightBullet():
	PC.main_skill_light_bullet += 1
	PC.light_bullet_final_damage_multi += 0.16
	_level_up_action()

func reward_LightBullet1():
	PC.selected_rewards.append("LightBullet1")
	PC.main_skill_light_bullet_damage += 0.2
	_level_up_action()

func reward_LightBullet2():
	PC.selected_rewards.append("LightBullet2")
	PC.main_skill_light_bullet_damage += 0.2
	_level_up_action()

func reward_LightBullet3():
	PC.selected_rewards.append("LightBullet3")
	PC.main_skill_light_bullet_damage += 0.3
	_level_up_action()

func reward_LightBullet4():
	PC.selected_rewards.append("LightBullet4")
	PC.main_skill_light_bullet_damage += 0.2
	_level_up_action()

func reward_LightBullet5():
	PC.selected_rewards.append("LightBullet5")
	PC.main_skill_light_bullet_damage += 0.2
	_level_up_action()

func reward_LightBullet11():
	PC.selected_rewards.append("LightBullet11")
	PC.main_skill_light_bullet_damage += 0.3
	_level_up_action()

func reward_LightBullet22():
	PC.selected_rewards.append("LightBullet22")
	PC.main_skill_light_bullet_damage += 0.4
	_level_up_action()

func reward_LightBullet33():
	PC.selected_rewards.append("LightBullet33")
	PC.main_skill_light_bullet_damage += 0.5
	_level_up_action()

func reward_LightBullet44():
	PC.selected_rewards.append("LightBullet44")
	PC.main_skill_light_bullet_damage += 0.4
	_level_up_action()

# --- 坎水诀相关奖励函数 ---
func reward_Water():
	PC.selected_rewards.append("Water")
	# 初始化冷却时间
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get("water_fire_speed"):
		player.water_fire_speed.start()
	_level_up_action()

func reward_RWater():
	PC.main_skill_water += 1
	PC.water_final_damage_multi += 0.2
	PC.selected_rewards.append("RWater")
	_level_up_action()

func reward_SRWater():
	PC.main_skill_water += 1
	PC.water_final_damage_multi += 0.22
	PC.selected_rewards.append("SRWater")
	_level_up_action()

func reward_SSRWater():
	PC.main_skill_water += 1
	PC.water_final_damage_multi += 0.24
	PC.selected_rewards.append("SSRWater")
	_level_up_action()

func reward_URWater():
	PC.main_skill_water += 1
	PC.water_final_damage_multi += 0.28
	PC.selected_rewards.append("URWater")
	_level_up_action()

func reward_Water1():
	PC.selected_rewards.append("Water1")
	PC.main_skill_water_damage += 0.3
	_level_up_action()

func reward_Water2():
	PC.selected_rewards.append("Water2")
	PC.main_skill_water_damage += 0.5
	_level_up_action()

func reward_Water3():
	PC.selected_rewards.append("Water3")
	PC.main_skill_water_damage += 0.3
	_level_up_action()

func reward_Water4():
	PC.selected_rewards.append("Water4")
	PC.main_skill_water_damage += 0.2
	_level_up_action()

func reward_Water11():
	PC.selected_rewards.append("Water11")
	PC.main_skill_water_damage += 0.7
	_level_up_action()

func reward_Water22():
	PC.selected_rewards.append("Water22")
	PC.main_skill_water_damage += 0.3
	_level_up_action()

func reward_Water33():
	PC.selected_rewards.append("Water33")
	PC.main_skill_water_damage += 0.4
	_level_up_action()

# --- 乾坤双剑相关奖励函数 ---
func reward_Qiankun():
	Qiankun.reset_data()
	PC.selected_rewards.append("Qiankun")
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
	Qiankun.qiankun_final_damage_multi += 0.2
	PC.selected_rewards.append("RQiankun")
	_level_up_action()

func reward_SRQiankun():
	PC.main_skill_qiankun += 1
	Qiankun.qiankun_final_damage_multi += 0.22
	PC.selected_rewards.append("SRQiankun")
	_level_up_action()

func reward_SSRQiankun():
	PC.main_skill_qiankun += 1
	Qiankun.qiankun_final_damage_multi += 0.24
	PC.selected_rewards.append("SSRQiankun")
	_level_up_action()

func reward_URQiankun():
	PC.main_skill_qiankun += 1
	Qiankun.qiankun_final_damage_multi += 0.28
	PC.selected_rewards.append("URQiankun")
	_level_up_action()

func reward_Qiankun1():
	PC.selected_rewards.append("Qiankun1")
	Qiankun.main_skill_qiankun_damage += 0.3
	Qiankun.qiankun_speed *= 1.25
	_level_up_action()

func reward_Qiankun2():
	PC.selected_rewards.append("Qiankun2")
	Qiankun.main_skill_qiankun_damage += 0.5
	Qiankun.qiankun_range *= 1.5
	_level_up_action()

func reward_Qiankun3():
	PC.selected_rewards.append("Qiankun3")
	Qiankun.main_skill_qiankun_damage += 0.4
	Qiankun.qiankun_speed_per_enemy = 0.02
	_level_up_action()

func reward_Qiankun4():
	PC.selected_rewards.append("Qiankun4")
	Qiankun.main_skill_qiankun_damage += 0.3
	Qiankun.qiankun_damage_per_debuff = 0.3
	_level_up_action()

func reward_Qiankun11():
	PC.selected_rewards.append("Qiankun11")
	Qiankun.main_skill_qiankun_damage += 0.4
	Qiankun.qiankun_speed *= 1.1
	Qiankun.qiankun_speed_per_enemy = 0.03
	_level_up_action()

func reward_Qiankun22():
	PC.selected_rewards.append("Qiankun22")
	Qiankun.main_skill_qiankun_damage += 0.6
	Qiankun.qiankun_range *= 1.2
	Qiankun.qiankun_damage_per_enemy = 0.03
	_level_up_action()

func reward_Qiankun33():
	PC.selected_rewards.append("Qiankun33")
	Qiankun.main_skill_qiankun_damage += 0.7
	Qiankun.qiankun_crit_on_3_debuffs = true
	_level_up_action()

# --- 环形子弹相关奖励函数 ---
# 获得环形子弹能力
func reward_SR27():
	PC.selected_rewards.append("ring_bullet")
	_level_up_action()

func reward_R28():
	PC.pc_atk = int(PC.pc_atk + PC.pc_start_atk * 0.03)
	PC.ring_bullet_damage_multiplier *= 1.2
	PC.ring_bullet_interval *= 0.95
	_level_up_action()
	
func reward_SR28():
	PC.pc_atk = int(PC.pc_atk + PC.pc_start_atk * 0.045)
	PC.ring_bullet_damage_multiplier *= 1.26
	PC.ring_bullet_interval *= 0.94
	_level_up_action()
	
func reward_SSR28():
	PC.pc_atk = int(PC.pc_atk + PC.pc_start_atk * 0.06)
	PC.ring_bullet_damage_multiplier *= 1.34
	PC.ring_bullet_interval *= 0.93
	_level_up_action()
	
func reward_UR28():
	PC.pc_atk = int(PC.pc_atk + PC.pc_start_atk * 0.09)
	PC.ring_bullet_damage_multiplier *= 1.48
	PC.ring_bullet_interval *= 0.91
	_level_up_action()
	
func reward_R29():
	PC.pc_atk = int(PC.pc_atk + PC.pc_start_atk * 0.03)
	PC.ring_bullet_count += 2
	PC.ring_bullet_interval *= 0.95
	_level_up_action()
	
func reward_SR29():
	PC.pc_atk = int(PC.pc_atk + PC.pc_start_atk * 0.05)
	PC.ring_bullet_count += 3
	PC.ring_bullet_interval *= 0.92
	_level_up_action()
	
func reward_SSR29():
	PC.pc_atk = int(PC.pc_atk + PC.pc_start_atk * 0.08)
	PC.ring_bullet_count += 3
	PC.ring_bullet_interval *= 0.89
	_level_up_action()
	
func reward_UR29():
	PC.pc_atk = int(PC.pc_atk + PC.pc_start_atk * 0.09)
	PC.ring_bullet_count += 3
	PC.ring_bullet_interval *= 0.88
	_level_up_action()
	
func reward_SR30():
	PC.selected_rewards.append("wave_bullet")
	_level_up_action()

func reward_R31():
	PC.pc_atk = int(PC.pc_atk + PC.pc_start_atk * 0.03)
	PC.wave_bullet_damage_multiplier *= 1.2
	PC.wave_bullet_interval *= 0.95
	_level_up_action()
	

func reward_SR31():
	PC.pc_atk = int(PC.pc_atk + PC.pc_start_atk * 0.045)
	PC.wave_bullet_damage_multiplier *= 1.26
	PC.wave_bullet_interval *= 0.94
	_level_up_action()
	
func reward_SSR31():
	PC.pc_atk = int(PC.pc_atk + PC.pc_start_atk * 0.06)
	PC.wave_bullet_damage_multiplier *= 1.34
	PC.wave_bullet_interval *= 0.93
	_level_up_action()
	
func reward_UR31():
	PC.pc_atk = int(PC.pc_atk + PC.pc_start_atk * 0.09)
	PC.wave_bullet_damage_multiplier *= 1.48
	PC.wave_bullet_interval *= 0.91
	_level_up_action()
	
func reward_R32():
	PC.pc_atk = int(PC.pc_atk + PC.pc_start_atk * 0.03)
	PC.wave_bullet_count += 3
	PC.wave_bullet_interval *= 0.95
	_level_up_action()
	
func reward_SR32():
	PC.pc_atk = int(PC.pc_atk + PC.pc_start_atk * 0.05)
	PC.wave_bullet_count += 3
	PC.wave_bullet_interval *= 0.92
	_level_up_action()
	
func reward_SSR32():
	PC.pc_atk = int(PC.pc_atk + PC.pc_start_atk * 0.08)
	PC.wave_bullet_count += 3
	PC.wave_bullet_interval *= 0.89
	_level_up_action()
	
func reward_UR32():
	PC.pc_atk = int(PC.pc_atk + PC.pc_start_atk * 0.09)
	PC.wave_bullet_count += 4
	PC.wave_bullet_interval *= 0.88
	_level_up_action()
	
# --- 蓝色召唤物相关奖励函数 ---
# 获得一个蓝色召唤物
func reward_R20():
	PC.summon_count += 1
	PC.selected_rewards.append("blue_summon")
	# 通知battle场景添加召唤物 (类型0代表蓝色召唤物)
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(0) # 假设0是蓝色召唤物的类型ID
	_level_up_action()

# 召唤物伤害/治疗量+7% 召唤物弹体大小+6% 召唤物发射间隔缩短3%
func reward_R23():
	PC.summon_damage_multiplier += 0.07
	PC.summon_bullet_size_multiplier += 0.05
	PC.summon_interval_multiplier *= 0.97
	# 更新当前所有召唤物的属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()
	
func reward_SR23():
	PC.summon_damage_multiplier += 0.1
	PC.summon_bullet_size_multiplier += 0.08
	PC.summon_interval_multiplier *= 0.96
	# 更新当前所有召唤物的属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()

func reward_SSR23():
	PC.summon_damage_multiplier += 0.13
	PC.summon_bullet_size_multiplier += 0.1
	PC.summon_interval_multiplier *= 0.95
	# 更新当前所有召唤物的属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()

func reward_UR23():
	PC.summon_damage_multiplier += 0.19
	PC.summon_bullet_size_multiplier += 0.14
	PC.summon_interval_multiplier *= 0.93
	# 更新当前所有召唤物的属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()
	
# --- 紫色召唤物相关奖励函数 ---
# 获得一个紫色召唤物
func reward_SR20():
	PC.summon_count += 1
	PC.selected_rewards.append("darkorchid_summon")
	PC.new_summon = "darkorchidchidchidchid" # 记录最新获得的召唤物类型
	# 通知battle场景添加召唤物 (类型1代表紫色召唤物)
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(1) # 假设1是紫色召唤物的类型ID
	_level_up_action()

# 紫色召唤物伤害提升10%，子弹大小提升7.5%
func reward_R24():
	PC.summon_damage_multiplier += 0.1
	PC.summon_bullet_size_multiplier += 0.05
	# 更新当前所有召唤物的属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()

func reward_SR24():
	PC.summon_damage_multiplier += 0.15
	PC.summon_bullet_size_multiplier += 0.075
	# 更新当前所有召唤物的属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()

func reward_SSR24():
	PC.summon_damage_multiplier += 0.2
	PC.summon_bullet_size_multiplier += 0.1
	# 更新当前所有召唤物的属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()
	
func reward_UR24():
	PC.summon_damage_multiplier += 0.2
	PC.summon_bullet_size_multiplier += 0.1
	# 更新当前所有召唤物的属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()
	
func reward_R25():
	PC.summon_damage_multiplier += 0.07
	PC.summon_interval_multiplier *= 0.95
	# 更新当前所有召唤物的属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()

func reward_SR25():
	PC.summon_damage_multiplier += 0.11
	PC.summon_interval_multiplier *= 0.93
	# 更新当前所有召唤物的属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()
	
func reward_SSR25():
	PC.summon_damage_multiplier += 0.15
	PC.summon_interval_multiplier *= 0.91
	# 更新当前所有召唤物的属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()
	
func reward_UR25():
	PC.summon_damage_multiplier += 0.23
	PC.summon_interval_multiplier *= 0.87
	# 更新当前所有召唤物的属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()
	
# --- 橙色(金色)召唤物相关奖励函数 ---
# 获得一个橙色(金色)召唤物
func reward_SSR20():
	PC.summon_count += 1
	PC.selected_rewards.append("gold_summon")
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
	PC.new_summon = "red" # 记录最新获得的召唤物类型
	# 通知battle场景添加召唤物 (类型3代表红色召唤物)
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(3) # 假设3是红色召唤物的类型ID
	_level_up_action()

# 橙色(金色)召唤物最大数量上限增加1
func reward_SR26():
	PC.summon_count_max += 1
	PC.summon_damage_multiplier -= 0.15
	_level_up_action()

# 红色召唤物最大数量上限增加2
func reward_SSR26():
	PC.summon_count_max += 1
	PC.summon_damage_multiplier -= 0.05
	_level_up_action()

# 红色召唤物最大数量上限增加2
func reward_UR26():
	PC.summon_count_max += 2
	PC.summon_damage_multiplier -= 0.15
	_level_up_action()


func reward_SR21():
	PC.summon_count += 1
	PC.selected_rewards.append("darkorchid_heal_summon")
	# 通知battle场景添加召唤物
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(4)
	_level_up_action()

func reward_SSR21():
	PC.summon_count += 1
	PC.selected_rewards.append("gold_heal_summon")
	# 通知battle场景添加召唤物
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(5)
	_level_up_action()

func reward_UR21():
	PC.summon_count += 1
	PC.selected_rewards.append("red_heal_summon")
	# 通知battle场景添加召唤物
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(6)
	_level_up_action()


func reward_SR22():
	PC.summon_count += 1
	PC.selected_rewards.append("darkorchid_aux_summon")
	# 通知battle场景添加召唤物
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(7)
	_level_up_action()

func reward_SSR22():
	PC.summon_count += 1
	PC.selected_rewards.append("gold_aux_summon")
	# 通知battle场景添加召唤物
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(8)
	_level_up_action()

func reward_UR22():
	PC.summon_count += 1
	PC.selected_rewards.append("red_aux_summon")
	# 通知battle场景添加召唤物
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(9)
	_level_up_action()

func reward_Branch():
	PC.now_main_skill_num = PC.now_main_skill_num + 1
	PC.selected_rewards.append("Branch")
	_level_up_action()

func reward_Moyan():
	PC.now_main_skill_num = PC.now_main_skill_num + 1
	PC.selected_rewards.append("Moyan")
	_level_up_action()

func reward_RingFire():
	PC.now_main_skill_num = PC.now_main_skill_num + 1
	PC.selected_rewards.append("RingFire")
	_level_up_action()
	
func reward_Riyan():
	PC.now_main_skill_num = PC.now_main_skill_num + 1
	PC.selected_rewards.append("Riyan")
	_level_up_action()

func reward_Thunder():
	PC.now_main_skill_num = PC.now_main_skill_num + 1
	PC.selected_rewards.append("Thunder")
	_level_up_action()

func reward_Bloodwave():
	BloodWave.reset_data()
	PC.now_main_skill_num = PC.now_main_skill_num + 1
	PC.selected_rewards.append("Bloodwave")
	_level_up_action()

func reward_BloodBoardSword():
	PC.now_main_skill_num = PC.now_main_skill_num + 1
	PC.selected_rewards.append("BloodBoardSword")
	
	# 初始化冷却时间
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get("bloodboardsword_fire_speed"):
		player.bloodboardsword_fire_speed.start()
		
	_level_up_action()

func reward_RSwordQi():
	PC.main_skill_swordQi += 1
	PC.main_skill_swordQi_damage += 0.12
	_level_up_action()

func reward_SRSwordQi():
	PC.main_skill_swordQi += 1
	PC.main_skill_swordQi_damage += 0.13
	_level_up_action()
	
func reward_SSRSwordQi():
	PC.main_skill_swordQi += 1
	PC.main_skill_swordQi_damage += 0.14
	_level_up_action()

func reward_URSwordQi():
	PC.main_skill_swordQi += 1
	PC.main_skill_swordQi_damage += 0.16
	_level_up_action()

	
func reward_SplitSwordQi1():
	PC.selected_rewards.append("SplitSwordQi1")
	_level_up_action()
	
func reward_SplitSwordQi2():
	PC.selected_rewards.append("SplitSwordQi2")
	PC.main_skill_swordQi_damage += 0.2 # 剑气伤害+20%
	_level_up_action()
	
func reward_SplitSwordQi3():
	PC.selected_rewards.append("SplitSwordQi3")
	PC.swordQi_penetration_count += 2 # 原来是1次，现在变成3次
	_level_up_action()
	
func reward_SplitSwordQi11():
	PC.selected_rewards.append("SplitSwordQi11")
	PC.swordQi_other_sword_wave_damage += 0.15
	_level_up_action()
	
func reward_SplitSwordQi12():
	PC.selected_rewards.append("SplitSwordQi12")
	_level_up_action()
	
func reward_SplitSwordQi13():
	PC.selected_rewards.append("SplitSwordQi13")
	_level_up_action()
	
func reward_SplitSwordQi21():
	PC.selected_rewards.append("SplitSwordQi21")
	PC.main_skill_swordQi_damage += 0.3 # 剑气伤害+30%
	_level_up_action()
	
func reward_SplitSwordQi22():
	PC.selected_rewards.append("SplitSwordQi22")
	PC.main_skill_swordQi_damage += 0.2 # 剑气伤害+20%
	_level_up_action()
	
func reward_SplitSwordQi23():
	PC.selected_rewards.append("SplitSwordQi23")
	PC.main_skill_swordQi_damage += 0.3 # 剑气伤害+30%
	_level_up_action()
	
func reward_SplitSwordQi31():
	PC.selected_rewards.append("SplitSwordQi31")
	PC.swordQi_penetration_count += 2 # 使穿透次数达到5次
	_level_up_action()
	
func reward_SplitSwordQi32():
	PC.selected_rewards.append("SplitSwordQi32")
	_level_up_action()
	
func reward_SplitSwordQi33():
	PC.selected_rewards.append("SplitSwordQi33")
	PC.main_skill_swordQi_damage += 0.1 # 剑气伤害+10%
	_level_up_action()
	

func reward_RBranch():
	PC.main_skill_branch += 1
	PC.main_skill_branch_damage += 0.2
	_level_up_action()

func reward_SRBranch():
	PC.main_skill_branch += 1
	PC.main_skill_branch_damage += 0.25
	_level_up_action()
	
func reward_SSRBranch():
	PC.main_skill_branch += 1
	PC.main_skill_branch_damage += 0.3
	_level_up_action()

func reward_URBranch():
	PC.main_skill_branch += 1
	PC.main_skill_branch_damage += 0.4
	_level_up_action()

func reward_Branch1():
	PC.selected_rewards.append("branch1")
	_level_up_action()

func reward_Branch2():
	PC.selected_rewards.append("branch2")
	_level_up_action()

func reward_Branch3():
	PC.selected_rewards.append("branch3")
	_level_up_action()

func reward_Branch4():
	PC.selected_rewards.append("branch4")
	_level_up_action()

func reward_Branch11():
	PC.selected_rewards.append("branch11")
	_level_up_action()

func reward_Branch21():
	PC.selected_rewards.append("branch21")
	_level_up_action()

func reward_Branch12():
	PC.selected_rewards.append("branch12")
	PC.main_skill_branch_damage += 0.2 # 树枝伤害+20%
	_level_up_action()

func reward_Branch31():
	PC.selected_rewards.append("branch31")
	_level_up_action()

func reward_Branch22():
	PC.selected_rewards.append("branch22")
	_level_up_action()

func reward_Rmoyan():
	PC.main_skill_moyan += 1
	PC.main_skill_moyan_damage += 0.2
	_level_up_action()

func reward_SRmoyan():
	PC.main_skill_moyan += 1
	PC.main_skill_moyan_damage += 0.25
	_level_up_action()
	
func reward_SSRmoyan():
	PC.main_skill_moyan += 1
	PC.main_skill_moyan_damage += 0.3
	_level_up_action()

func reward_URmoyan():
	PC.main_skill_moyan += 1
	PC.main_skill_moyan_damage += 0.4
	_level_up_action()

func reward_Moyan1():
	PC.selected_rewards.append("moyan1")
	_level_up_action()

func reward_Moyan2():
	PC.selected_rewards.append("moyan2")
	_level_up_action()

func reward_Moyan3():
	PC.selected_rewards.append("moyan3")
	_level_up_action()

func reward_Moyan12():
	PC.selected_rewards.append("moyan12")
	_level_up_action()

func reward_Moyan13():
	PC.selected_rewards.append("moyan13")
	_level_up_action()

func reward_Moyan23():
	PC.selected_rewards.append("moyan23")
	_level_up_action()


func reward_RRingFire():
	PC.main_skill_ringFire += 1
	PC.main_skill_ringFire_damage += 0.2
	_level_up_action()

func reward_SRRingFire():
	PC.main_skill_ringFire += 1
	PC.main_skill_ringFire_damage += 0.25
	_level_up_action()
	
func reward_SSRRingFire():
	PC.main_skill_ringFire += 1
	PC.main_skill_ringFire_damage += 0.3
	_level_up_action()

func reward_URRingFire():
	PC.main_skill_ringFire += 1
	PC.main_skill_ringFire_damage += 0.4
	_level_up_action()

func reward_RingFire1():
	PC.selected_rewards.append("ringFire1")
	_level_up_action()

func reward_RingFire2():
	PC.selected_rewards.append("ringFire2")
	_level_up_action()

func reward_RingFire3():
	PC.selected_rewards.append("ringFire3")
	_level_up_action()

func reward_RingFire11():
	PC.selected_rewards.append("ringFire11")
	_level_up_action()

func reward_RingFire4():
	PC.selected_rewards.append("ringFire4")
	_level_up_action()

func reward_RingFire44():
	PC.selected_rewards.append("ringFire44")
	_level_up_action()

func reward_Rriyan():
	PC.main_skill_riyan += 1
	PC.main_skill_riyan_damage += 0.2
	_level_up_action()

func reward_SRriyan():
	PC.main_skill_riyan += 1
	PC.main_skill_riyan_damage += 0.25
	_level_up_action()
	
func reward_SSRriyan():
	PC.main_skill_riyan += 1
	PC.main_skill_riyan_damage += 0.3
	_level_up_action()

func reward_URriyan():
	PC.main_skill_riyan += 1
	PC.main_skill_riyan_damage += 0.4
	_level_up_action()

func reward_RBloodwave():
	PC.main_skill_bloodwave += 1
	BloodWave.main_skill_bloodwave_damage += 0.2
	PC.selected_rewards.append("RBloodwave")
	_level_up_action()

func reward_SRBloodwave():
	PC.main_skill_bloodwave += 1
	BloodWave.main_skill_bloodwave_damage += 0.25
	PC.selected_rewards.append("SRBloodwave")
	_level_up_action()

func reward_SSRBloodwave():
	PC.main_skill_bloodwave += 1
	BloodWave.main_skill_bloodwave_damage += 0.3
	PC.selected_rewards.append("SSRBloodwave")
	_level_up_action()

func reward_URBloodwave():
	PC.main_skill_bloodwave += 1
	BloodWave.main_skill_bloodwave_damage += 0.4
	PC.selected_rewards.append("URBloodwave")
	_level_up_action()

func reward_RBloodBoardSword():
	PC.main_skill_bloodboardsword += 1
	PC.selected_rewards.append("RBloodBoardSword")
	_level_up_action()

func reward_SRBloodBoardSword():
	PC.main_skill_bloodboardsword += 1
	PC.selected_rewards.append("SRBloodBoardSword")
	_level_up_action()

func reward_SSRBloodBoardSword():
	PC.main_skill_bloodboardsword += 1
	PC.selected_rewards.append("SSRBloodBoardSword")
	_level_up_action()

func reward_URBloodBoardSword():
	PC.main_skill_bloodboardsword += 1
	PC.selected_rewards.append("URBloodBoardSword")
	_level_up_action()

func reward_BloodBoardSword1():
	PC.selected_rewards.append("BloodBoardSword1")
	_level_up_action()

func reward_BloodBoardSword2():
	PC.selected_rewards.append("BloodBoardSword2")
	_level_up_action()

func reward_BloodBoardSword3():
	PC.selected_rewards.append("BloodBoardSword3")
	_level_up_action()

func reward_BloodBoardSword4():
	PC.selected_rewards.append("BloodBoardSword4")
	_level_up_action()

func reward_BloodBoardSword11():
	PC.selected_rewards.append("BloodBoardSword11")
	_level_up_action()

func reward_BloodBoardSword22():
	PC.selected_rewards.append("BloodBoardSword22")
	_level_up_action()

func reward_BloodBoardSword33():
	PC.selected_rewards.append("BloodBoardSword33")
	_level_up_action()

func reward_RThunder():
	PC.main_skill_thunder += 1
	PC.main_skill_thunder_damage += 0.2
	PC.selected_rewards.append("RThunder")
	_level_up_action()

func reward_SRThunder():
	PC.main_skill_thunder += 1
	PC.main_skill_thunder_damage += 0.25
	PC.selected_rewards.append("SRThunder")
	_level_up_action()

func reward_SSRThunder():
	PC.main_skill_thunder += 1
	PC.main_skill_thunder_damage += 0.3
	PC.selected_rewards.append("SSRThunder")
	_level_up_action()

func reward_URThunder():
	PC.main_skill_thunder += 1
	PC.main_skill_thunder_damage += 0.4
	PC.selected_rewards.append("URThunder")
	_level_up_action()

func reward_Thunder1():
	PC.selected_rewards.append("Thunder1")
	_level_up_action()

func reward_Thunder2():
	PC.selected_rewards.append("Thunder2")
	_level_up_action()

func reward_Thunder3():
	PC.selected_rewards.append("Thunder3")
	_level_up_action()

func reward_Thunder4():
	PC.selected_rewards.append("Thunder4")
	_level_up_action()

func reward_Thunder11():
	PC.selected_rewards.append("Thunder11")
	_level_up_action()

func reward_Thunder22():
	PC.selected_rewards.append("Thunder22")
	_level_up_action()

func reward_Thunder33():
	PC.selected_rewards.append("Thunder33")
	_level_up_action()

func reward_Bloodwave1():
	PC.selected_rewards.append("Bloodwave1")
	BloodWave.main_skill_bloodwave_damage += 0.4
	BloodWave.bloodwave_apply_bleed = true
	_level_up_action()

func reward_Bloodwave2():
	PC.selected_rewards.append("Bloodwave2")
	BloodWave.main_skill_bloodwave_damage += 0.6
	BloodWave.bloodwave_hp_cost_multi = 2.0
	BloodWave.bloodwave_extra_crit_chance += 0.3
	BloodWave.bloodwave_extra_crit_damage += 0.3
	_level_up_action()

func reward_Bloodwave3():
	PC.selected_rewards.append("Bloodwave3")
	BloodWave.main_skill_bloodwave_damage += 0.3
	BloodWave.bloodwave_missing_hp_damage_bonus = 0.01
	BloodWave.bloodwave_missing_hp_range_bonus = 0.02
	_level_up_action()

func reward_Bloodwave4():
	PC.selected_rewards.append("Bloodwave4")
	BloodWave.main_skill_bloodwave_damage += 0.5
	BloodWave.bloodwave_missing_hp_heal_bonus = 0.01
	_level_up_action()

func reward_Bloodwave11():
	PC.selected_rewards.append("Bloodwave11")
	BloodWave.main_skill_bloodwave_damage += 0.5
	BloodWave.bloodwave_missing_hp_damage_bonus = 0.015
	BloodWave.bloodwave_missing_hp_heal_bonus = 0.015
	_level_up_action()

func reward_Bloodwave22():
	PC.selected_rewards.append("Bloodwave22")
	BloodWave.main_skill_bloodwave_damage += 0.4
	BloodWave.bloodwave_low_hp_damage_bonus = 0.4
	BloodWave.bloodwave_low_hp_range_bonus = 0.4
	_level_up_action()

func reward_Bloodwave33():
	PC.selected_rewards.append("Bloodwave33")
	BloodWave.main_skill_bloodwave_damage += 0.6
	BloodWave.bloodwave_bleed_move_speed_bonus = 0.01
	_level_up_action()

func reward_Riyan1():
	PC.selected_rewards.append("riyan1")
	_level_up_action()

func reward_Riyan2():
	PC.selected_rewards.append("riyan2")
	_level_up_action()

func reward_Riyan3():
	PC.selected_rewards.append("riyan3")
	_level_up_action()

func reward_Riyan4():
	PC.selected_rewards.append("riyan4")
	_level_up_action()

func reward_Riyan11():
	PC.selected_rewards.append("riyan11")
	_level_up_action()

func reward_Riyan22():
	PC.selected_rewards.append("riyan22")
	_level_up_action()


# Xuanwu Functions

func check_not_have_xuanwu() -> bool:
	return not PC.selected_rewards.has("Xuanwu")

func check_xuanwu_condition() -> bool:
	return PC.selected_rewards.has("Xuanwu")

func check_xuanwu_condition1() -> bool:
	return PC.selected_rewards.has("Xuanwu1") and PC.selected_rewards.has("Xuanwu2")

func check_xuanwu_condition2() -> bool:
	return PC.selected_rewards.has("Xuanwu3") and PC.selected_rewards.has("Xuanwu4")

func check_xuanwu_condition3() -> bool:
	return PC.selected_rewards.has("Xuanwu1") and PC.selected_rewards.has("Xuanwu3")

func reward_Xuanwu():
	Xuanwu.reset_data()
	PC.selected_rewards.append("Xuanwu")
	PC.now_main_skill_num += 1
	_level_up_action()

func reward_RXuanwu():
	PC.main_skill_xuanwu += 1
	PC.selected_rewards.append("RXuanwu")
	Xuanwu.xuanwu_final_damage_multi += 0.2
	_level_up_action()

func reward_SRXuanwu():
	PC.main_skill_xuanwu += 1
	PC.selected_rewards.append("SRXuanwu")
	Xuanwu.xuanwu_final_damage_multi += 0.22
	_level_up_action()

func reward_SSRXuanwu():
	PC.main_skill_xuanwu += 1
	PC.selected_rewards.append("SSRXuanwu")
	Xuanwu.xuanwu_final_damage_multi += 0.24
	_level_up_action()

func reward_URXuanwu():
	PC.main_skill_xuanwu += 1
	PC.selected_rewards.append("URXuanwu")
	Xuanwu.xuanwu_final_damage_multi += 0.28
	_level_up_action()

func reward_Xuanwu1():
	PC.selected_rewards.append("Xuanwu1")
	Xuanwu.xuanwu_final_damage_multi += 0.6
	Xuanwu.xuanwu_shield_base += 2
	Xuanwu.xuanwu_shield_hp_ratio = 0.07
	_level_up_action()

func reward_Xuanwu2():
	PC.selected_rewards.append("Xuanwu2")
	Xuanwu.xuanwu_final_damage_multi += 0.5
	Xuanwu.xuanwu_shield_bonus_damage = 3.0
	_level_up_action()

func reward_Xuanwu3():
	PC.selected_rewards.append("Xuanwu3")
	Xuanwu.xuanwu_final_damage_multi += 0.7
	Xuanwu.xuanwu_shield_base += 4
	Xuanwu.xuanwu_slow_duration = 5.0
	_level_up_action()

func reward_Xuanwu4():
	PC.selected_rewards.append("Xuanwu4")
	Xuanwu.xuanwu_final_damage_multi += 0.3
	Xuanwu.xuanwu_width_scale = 1.2
	Xuanwu.xuanwu_vulnerable_duration = 5.0
	_level_up_action()

func reward_Xuanwu11():
	PC.selected_rewards.append("Xuanwu11")
	Xuanwu.xuanwu_final_damage_multi += 0.4
	Xuanwu.xuanwu_shield_base += 4
	Xuanwu.xuanwu_shield_bonus_damage = 5.0
	_level_up_action()

func reward_Xuanwu22():
	PC.selected_rewards.append("Xuanwu22")
	Xuanwu.xuanwu_final_damage_multi += 0.6
	Xuanwu.xuanwu_return_shield_bonus = 0.3
	_level_up_action()

func reward_Xuanwu33():
	PC.selected_rewards.append("Xuanwu33")
	Xuanwu.xuanwu_final_damage_multi += 0.7
	Xuanwu.xuanwu_shield_base += 4
	Xuanwu.xuanwu_width_scale += 0.3
	_level_up_action()


# Xunfeng Functions

func check_not_have_xunfeng() -> bool:
	return not PC.selected_rewards.has("Xunfeng")

func check_xunfeng_condition() -> bool:
	return PC.selected_rewards.has("Xunfeng")

func check_xunfeng_condition1() -> bool:
	return PC.selected_rewards.has("Xunfeng1") and PC.selected_rewards.has("Xunfeng4")

func check_xunfeng_condition2() -> bool:
	return PC.selected_rewards.has("Xunfeng2") and PC.selected_rewards.has("Xunfeng3")

func check_xunfeng_condition3() -> bool:
	return PC.selected_rewards.has("Xunfeng1") and PC.selected_rewards.has("Xunfeng3")

func reward_Xunfeng():
	Xunfeng.reset_data()
	PC.selected_rewards.append("Xunfeng")
	PC.now_main_skill_num += 1
	_level_up_action()

func reward_RXunfeng():
	PC.main_skill_xunfeng += 1
	PC.selected_rewards.append("RXunfeng")
	Xunfeng.xunfeng_final_damage_multi += 0.20
	_level_up_action()

func reward_SRXunfeng():
	PC.main_skill_xunfeng += 1
	PC.selected_rewards.append("SRXunfeng")
	Xunfeng.xunfeng_final_damage_multi += 0.22
	_level_up_action()

func reward_SSRXunfeng():
	PC.main_skill_xunfeng += 1
	PC.selected_rewards.append("SSRXunfeng")
	Xunfeng.xunfeng_final_damage_multi += 0.24
	_level_up_action()

func reward_URXunfeng():
	PC.main_skill_xunfeng += 1
	PC.selected_rewards.append("URXunfeng")
	Xunfeng.xunfeng_final_damage_multi += 0.28
	_level_up_action()

func reward_Xunfeng1():
	PC.selected_rewards.append("Xunfeng1")
	Xunfeng.xunfeng_final_damage_multi += 0.40
	Xunfeng.xunfeng_size_scale *= 1.35
	Xunfeng.xunfeng_range *= 1.20
	_level_up_action()

func reward_Xunfeng2():
	PC.selected_rewards.append("Xunfeng2")
	Xunfeng.xunfeng_final_damage_multi += 0.40
	Xunfeng.xunfeng_speed *= 1.20
	Xunfeng.xunfeng_cooldown *= 0.90
	_level_up_action()

func reward_Xunfeng3():
	PC.selected_rewards.append("Xunfeng3")
	Xunfeng.xunfeng_final_damage_multi += 0.30
	# logic handled in player_action.gd
	_level_up_action()

func reward_Xunfeng4():
	PC.selected_rewards.append("Xunfeng4")
	Xunfeng.xunfeng_final_damage_multi += 0.50
	Xunfeng.xunfeng_penetration_count = 999
	Xunfeng.xunfeng_pierce_decay = 0.50
	_level_up_action()

func reward_Xunfeng11():
	PC.selected_rewards.append("Xunfeng11")
	Xunfeng.xunfeng_final_damage_multi += 0.70
	Xunfeng.xunfeng_size_scale *= 1.35
	Xunfeng.xunfeng_pierce_decay = 0.40
	_level_up_action()

func reward_Xunfeng22():
	PC.selected_rewards.append("Xunfeng22")
	Xunfeng.xunfeng_final_damage_multi += 0.60
	Xunfeng.xunfeng_extra_blade_count_threshold = 2
	_level_up_action()

func reward_Xunfeng33():
	PC.selected_rewards.append("Xunfeng33")
	Xunfeng.xunfeng_final_damage_multi += 0.20
	Xunfeng.xunfeng_extra_blade_damage_ratio = 0.9 # 60% * 1.5 = 90%? Or +50% additive? Assuming multiplicative boost to base ratio or additive. Description says "extra wind blade damage +50%". Base is 60%. If it means ratio becomes 60%+50%=110% or 60%*1.5=90%. Let's assume 60%*1.5=90%.
	# logic for left/right handled in player_action.gd
	_level_up_action()


# Genshan Functions

func check_not_have_genshan() -> bool:
	return not PC.selected_rewards.has("Genshan")

func check_genshan_condition() -> bool:
	return PC.selected_rewards.has("Genshan")

func check_genshan_condition1() -> bool:
	return PC.selected_rewards.has("Genshan2") and PC.selected_rewards.has("Genshan4")

func check_genshan_condition2() -> bool:
	return PC.selected_rewards.has("Genshan1") and PC.selected_rewards.has("Genshan3")

func check_genshan_condition3() -> bool:
	return PC.selected_rewards.has("Genshan2") and PC.selected_rewards.has("Genshan3")

func reward_Genshan():
	Genshan.reset_data()
	PC.selected_rewards.append("Genshan")
	PC.now_main_skill_num += 1
	_level_up_action()

func reward_RGenshan():
	PC.main_skill_genshan += 1
	PC.selected_rewards.append("RGenshan")
	Genshan.genshan_final_damage_multi += 0.20
	_level_up_action()

func reward_SRGenshan():
	PC.main_skill_genshan += 1
	PC.selected_rewards.append("SRGenshan")
	Genshan.genshan_final_damage_multi += 0.22
	_level_up_action()

func reward_SSRGenshan():
	PC.main_skill_genshan += 1
	PC.selected_rewards.append("SSRGenshan")
	Genshan.genshan_final_damage_multi += 0.24
	_level_up_action()

func reward_URGenshan():
	PC.main_skill_genshan += 1
	PC.selected_rewards.append("URGenshan")
	Genshan.genshan_final_damage_multi += 0.28
	_level_up_action()

func reward_Genshan1():
	PC.selected_rewards.append("Genshan1")
	Genshan.genshan_final_damage_multi += 0.30
	# Logic handled in genshan.gd: Up/Down direction, total damage -30%
	_level_up_action()

func reward_Genshan2():
	PC.selected_rewards.append("Genshan2")
	Genshan.genshan_final_damage_multi += 0.60
	# Logic handled in genshan.gd: Vulnerable debuff
	_level_up_action()

func reward_Genshan3():
	PC.selected_rewards.append("Genshan3")
	Genshan.genshan_final_damage_multi += 0.40
	# Logic handled in genshan.gd: Extra damage to Elite/Boss/<30% HP
	_level_up_action()

func reward_Genshan4():
	PC.selected_rewards.append("Genshan4")
	Genshan.genshan_final_damage_multi += 0.50
	# Logic handled in genshan.gd: Shield on hit
	_level_up_action()

func reward_Genshan11():
	PC.selected_rewards.append("Genshan11")
	Genshan.genshan_final_damage_multi += 0.70
	# Logic handled in genshan.gd: Enhanced shield
	_level_up_action()

func reward_Genshan22():
	PC.selected_rewards.append("Genshan22")
	Genshan.genshan_final_damage_multi += 0.30
	# Logic handled in genshan.gd: Diagonal directions, total damage -30%
	_level_up_action()

func reward_Genshan33():
	PC.selected_rewards.append("Genshan33")
	Genshan.genshan_final_damage_multi += 0.50
	# Logic handled in genshan.gd: Extra damage to Vulnerable
	_level_up_action()


# Duize Functions

func check_not_have_duize() -> bool:
	return not PC.selected_rewards.has("Duize")

func check_duize_condition() -> bool:
	return PC.selected_rewards.has("Duize")

func check_duize_condition1() -> bool:
	return PC.selected_rewards.has("Duize1") and PC.selected_rewards.has("Duize4")

func check_duize_condition2() -> bool:
	return PC.selected_rewards.has("Duize1") and PC.selected_rewards.has("Duize3")

func check_duize_condition3() -> bool:
	return PC.selected_rewards.has("Duize2") and PC.selected_rewards.has("Duize4")

func reward_Duize():
	Duize.reset_data()
	PC.selected_rewards.append("Duize")
	PC.now_main_skill_num += 1
	_level_up_action()

func reward_RDuize():
	PC.main_skill_duize += 1
	PC.selected_rewards.append("RDuize")
	Duize.duize_final_damage_multi += 0.20
	_level_up_action()

func reward_SRDuize():
	PC.main_skill_duize += 1
	PC.selected_rewards.append("SRDuize")
	Duize.duize_final_damage_multi += 0.22
	_level_up_action()

func reward_SSRDuize():
	PC.main_skill_duize += 1
	PC.selected_rewards.append("SSRDuize")
	Duize.duize_final_damage_multi += 0.24
	_level_up_action()

func reward_URDuize():
	PC.main_skill_duize += 1
	PC.selected_rewards.append("URDuize")
	Duize.duize_final_damage_multi += 0.28
	_level_up_action()

func reward_Duize1():
	PC.selected_rewards.append("Duize1")
	Duize.duize_final_damage_multi += 0.50
	Duize.duize_slow_ratio = 0.30
	_level_up_action()

func reward_Duize2():
	PC.selected_rewards.append("Duize2")
	Duize.duize_final_damage_multi += 0.30
	# Logic handled in duize.gd: Damage per debuff +30%
	_level_up_action()

func reward_Duize3():
	PC.selected_rewards.append("Duize3")
	Duize.duize_final_damage_multi += 0.60
	Duize.duize_range *= 1.35
	_level_up_action()

func reward_Duize4():
	PC.selected_rewards.append("Duize4")
	Duize.duize_final_damage_multi += 0.30
	# Logic handled in duize.gd: Apply Corrosion
	_level_up_action()

func reward_Duize11():
	PC.selected_rewards.append("Duize11")
	Duize.duize_final_damage_multi += 0.50
	Duize.duize_slow_ratio = 0.35
	# Logic handled in duize.gd: Extra 30% damage to targets in range (or Corrosion enhanced?)
	# Description: "额外受到30%的伤害". This could mean damage taken debuff or direct damage bonus.
	# "兑泽诀范围内的敌人缓速效果提升至35%，额外受到30%的伤害" -> Likely damage taken debuff or just damage multiplier.
	# Given Duize4 is Corrosion (20% taken), Duize11 might be an enhancement or separate.
	# Let's assume it's a damage taken amplifier in the area.
	_level_up_action()

func reward_Duize22():
	PC.selected_rewards.append("Duize22")
	Duize.duize_final_damage_multi += 0.60
	Duize.duize_range *= 1.35 # Extra +35%
	_level_up_action()

func reward_Duize33():
	PC.selected_rewards.append("Duize33")
	Duize.duize_final_damage_multi += 0.40
	# Logic handled in duize.gd: Damage per debuff +70%
	_level_up_action()


# HolyLight Functions

func check_not_have_holylight() -> bool:
	return not PC.selected_rewards.has("HolyLight")

func check_holylight_condition() -> bool:
	return PC.selected_rewards.has("HolyLight")

func check_holylight_condition1() -> bool:
	return PC.selected_rewards.has("HolyLight1") and PC.selected_rewards.has("HolyLight2")

func check_holylight_condition2() -> bool:
	return PC.selected_rewards.has("HolyLight3") and PC.selected_rewards.has("HolyLight4")

func check_holylight_condition3() -> bool:
	return PC.selected_rewards.has("HolyLight2") and PC.selected_rewards.has("HolyLight4")

func reward_HolyLight():
	HolyLight.reset_data()
	PC.selected_rewards.append("HolyLight")
	PC.now_main_skill_num += 1
	# 初始化冷却时间
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get("holy_light_fire_speed"):
		player.holy_light_fire_speed.start()
	_level_up_action()

func reward_RHolyLight():
	PC.main_skill_holylight += 1
	PC.selected_rewards.append("RHolyLight")
	HolyLight.main_skill_holylight_damage += 0.20
	_level_up_action()

func reward_SRHolyLight():
	PC.main_skill_holylight += 1
	PC.selected_rewards.append("SRHolyLight")
	HolyLight.main_skill_holylight_damage += 0.22
	_level_up_action()

func reward_SSRHolyLight():
	PC.main_skill_holylight += 1
	PC.selected_rewards.append("SSRHolyLight")
	HolyLight.main_skill_holylight_damage += 0.24
	_level_up_action()

func reward_URHolyLight():
	PC.main_skill_holylight += 1
	PC.selected_rewards.append("URHolyLight")
	HolyLight.main_skill_holylight_damage += 0.28
	_level_up_action()

func reward_HolyLight1():
	PC.selected_rewards.append("HolyLight1")
	HolyLight.main_skill_holylight_damage += 0.30
	HolyLight.holylight_range_scale *= 1.35
	_level_up_action()

func reward_HolyLight2():
	PC.selected_rewards.append("HolyLight2")
	HolyLight.main_skill_holylight_damage += 0.50
	HolyLight.holylight_range_scale *= 1.15
	HolyLight.holylight_center_extra_damage += 1.0
	_level_up_action()

func reward_HolyLight3():
	PC.selected_rewards.append("HolyLight3")
	HolyLight.main_skill_holylight_damage += 0.40
	HolyLight.holylight_heal_base = 5
	HolyLight.holylight_heal_ratio = 0.045
	_level_up_action()

func reward_HolyLight4():
	PC.selected_rewards.append("HolyLight4")
	HolyLight.main_skill_holylight_damage += 0.50
	HolyLight.holylight_range_scale *= 1.05
	HolyLight.holylight_vulnerable_damage_bonus = 1.0
	_level_up_action()

func reward_HolyLight11():
	PC.selected_rewards.append("HolyLight11")
	HolyLight.main_skill_holylight_damage += 0.70
	HolyLight.holylight_range_scale *= 1.25
	HolyLight.holylight_center_extra_damage = 2.0
	_level_up_action()

func reward_HolyLight22():
	PC.selected_rewards.append("HolyLight22")
	HolyLight.main_skill_holylight_damage += 0.40
	HolyLight.holylight_heal_ratio = 0.06
	_level_up_action()

func reward_HolyLight33():
	PC.selected_rewards.append("HolyLight33")
	HolyLight.main_skill_holylight_damage += 0.60
	HolyLight.holylight_range_scale *= 1.1
	HolyLight.holylight_vulnerable_crit = true
	_level_up_action()


# Qigong Functions

func check_qigong_condition1() -> bool:
	return PC.selected_rewards.has("Qigong1")

func check_qigong_condition2() -> bool:
	return PC.selected_rewards.has("Qigong2")

func check_qigong_condition3() -> bool:
	return PC.selected_rewards.has("Qigong3")

func check_qigong_condition4() -> bool:
	return PC.selected_rewards.has("Qigong4")

func check_qigong_condition5() -> bool:
	return PC.selected_rewards.has("Qigong5")

func reward_Qigong():
	PC.selected_rewards.append("qigong")
	# 初始化冷却时间
	PC.now_main_skill_num = PC.now_main_skill_num + 1
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get("qigong_fire_speed"):
		player.qigong_fire_speed.start()
	_level_up_action()


# 全局升级效果处理函数 (当选择某些特定被动后，升级时会触发额外属性转换)
func global_level_up():
	# 基础属性成长
	PC.pc_atk += 2
	PC.pc_start_atk += 2
	PC.pc_max_hp += 2
	PC.pc_start_max_hp += 2
	PC.pc_hp += 2 # 升级时也恢复一点HP

	# R11系列: 行云 - 每4%移速提升攻击与HP上限
	var r11_count = PC.selected_rewards.count("R11")
	var sr11_count = PC.selected_rewards.count("SR11")
	var ssr11_count = PC.selected_rewards.count("SSR11")
	var ur11_count = PC.selected_rewards.count("UR11")
	if r11_count > 0 or sr11_count > 0 or ssr11_count > 0 or ur11_count > 0:
		var speed_bonus = (PC.pc_speed - 1.0) * 100
		var speed_groups = int(speed_bonus / 4)
		if speed_groups > 0:
			var total_bonus = 0.0
			total_bonus += r11_count * speed_groups * 0.01
			total_bonus += sr11_count * speed_groups * 0.012
			total_bonus += ssr11_count * speed_groups * 0.014
			total_bonus += ur11_count * speed_groups * 0.014
			PC.pc_atk = int(PC.pc_atk * 1)
			PC.pc_max_hp = int(PC.pc_max_hp * (1 + total_bonus))

	# R12系列: 加护 - 每点额外天命提升攻击与HP上限
	var r12_count = PC.selected_rewards.count("R12")
	var sr12_count = PC.selected_rewards.count("SR12")
	var ssr12_count = PC.selected_rewards.count("SSR12")
	var ur12_count = PC.selected_rewards.count("UR12")
	if r12_count > 0 or sr12_count > 0 or ssr12_count > 0 or ur12_count > 0:
		var extra_lucky = max(0, PC.now_lunky_level - PC.last_lunky_level)
		if extra_lucky > 0:
			var total_bonus = 0.0
			total_bonus += r12_count * extra_lucky * 0.01
			total_bonus += sr12_count * extra_lucky * 0.012
			total_bonus += ssr12_count * extra_lucky * 0.014
			total_bonus += ur12_count * extra_lucky * 0.014
			PC.pc_atk = int(PC.pc_atk * 1)
			PC.pc_max_hp = int(PC.pc_max_hp * (1 + total_bonus))

	# R13系列: 归元 - 每5%攻速提升攻击与HP上限
	var r13_count = PC.selected_rewards.count("R13")
	var sr13_count = PC.selected_rewards.count("SR13")
	var ssr13_count = PC.selected_rewards.count("SSR13")
	var ur13_count = PC.selected_rewards.count("UR13")
	if r13_count > 0 or sr13_count > 0 or ssr13_count > 0 or ur13_count > 0:
		var atk_speed_bonus = (PC.pc_atk_speed - 1.0) * 100
		var atk_speed_groups = int(atk_speed_bonus / 5)
		if atk_speed_groups > 0:
			var total_bonus = 0.0
			total_bonus += r13_count * atk_speed_groups * 0.01
			total_bonus += sr13_count * atk_speed_groups * 0.012
			total_bonus += ssr13_count * atk_speed_groups * 0.014
			total_bonus += ur13_count * atk_speed_groups * 0.014
			PC.pc_atk = int(PC.pc_atk * 1)
			PC.pc_max_hp = int(PC.pc_max_hp * (1 + total_bonus))

	# 更新上次属性记录，用于下次比较变化
	PC.last_lunky_level = PC.now_lunky_level
	PC.last_speed = PC.pc_speed
	PC.last_atk_speed = PC.pc_atk_speed

	# 处理生命恢复效果 (基于 "hpRecover" 标记的数量)
	var recoverUp = PC.selected_rewards.count("hpRecover") # 获取 "hpRecover" 标记的数量
	var recoverNum = (0.1 + recoverUp * 0.05) * PC.pc_max_hp # 基础恢复10%HP，每多一个标记额外恢复5%HP
	if PC.pc_hp + recoverNum > PC.pc_max_hp: # 如果恢复后超过HP上限
		PC.pc_hp = PC.pc_max_hp # 则设置为HP上限
	else:
		PC.pc_hp += int(recoverNum) # 否则直接增加恢复量
