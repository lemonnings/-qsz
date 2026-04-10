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
	var selected_reward: Reward
	if rand_num <= PC.now_red_p:
		selected_reward = select_reward('red', main_skill_name)
	elif rand_num <= PC.now_gold_p + PC.now_red_p:
		selected_reward = select_reward('gold', main_skill_name)
	elif rand_num <= PC.now_darkorchid_p + PC.now_gold_p + PC.now_red_p:
		selected_reward = select_reward('darkorchid', main_skill_name)
	else:
		selected_reward = select_reward('skyblue', main_skill_name)

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
			elif reward_item.if_advance == true:
				print("[DEBUG] 跳过进阶技能 %s: faction=%s (期望=%s)" % [reward_item.id, reward_item.faction, main_skill_name])

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
	
	# 更新法则属性加成
	if Faze.manager_instance:
		Faze.manager_instance.check_and_apply_law_bonuses()
	
	
func _select_PC_main_skill_lv(main_skill_name: String) -> int:
	if main_skill_name == "Swordqi":
		return PC.main_skill_swordQi
	elif main_skill_name == "Branch":
		return PC.main_skill_branch
	elif main_skill_name == "Moyan":
		return PC.main_skill_moyan
	elif main_skill_name == "Riyan":
		return PC.main_skill_riyan
	elif main_skill_name == "Ringfire":
		return PC.main_skill_ringFire
	elif main_skill_name == "Thunder":
		return PC.main_skill_thunder
	elif main_skill_name == "Bloodwave":
		return PC.main_skill_bloodwave
	elif main_skill_name == "Bloodboardsword":
		return PC.main_skill_bloodboardsword
	elif main_skill_name == "Ice":
		return PC.main_skill_ice
	elif main_skill_name == "Thunderbreak":
		return PC.main_skill_thunder_break
	elif main_skill_name == "Lightbullet":
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
	elif main_skill_name == "Holylight":
		return PC.main_skill_holylight
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
							var callable_func = Callable(self , func_name)
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
			# 进阶池为空时，返回NoAdvance默认强化选项
			return _get_no_advance_reward()
	
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
						var callable_func = Callable(self , func_name)
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
							var callable_func = Callable(self , func_name)
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

# 检查当前是否没有其他可进阶的技能（NoAdvance的前置条件）
func check_no_other_advance() -> bool:
	# 遍历所有奖励，检查是否还有可用的进阶技能
	for reward in all_rewards_list:
		if reward.if_advance and reward.id != "NoAdvance":
			return false
	return true

# 检查指定主技能的进阶池是否为空（用于升级界面判断是否需要填充精进）
func is_advance_pool_empty(main_skill_name: String) -> bool:
	var filtered_rewards: Array[Reward] = []
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

# 检查子弹大小是否小于等于2.0 (通用子弹大小相关技能的前置条件)
func check_bullet_size_condition() -> bool:
	return PC.bullet_size <= 2.0

func check_Branch_condition() -> bool:
	return PC.selected_rewards.has("Branch")
	
func check_Moyan_condition() -> bool:
	return PC.selected_rewards.has("Moyan")

func check_Swordqi_condition() -> bool:
	return PC.selected_rewards.has("Swordqi")
	
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
func check_not_have_Swordqi() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("Swordqi")

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

func check_not_have_Ringfire() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("Ringfire")

func check_not_have_Thunder() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("Thunder")

func check_not_have_Bloodwave() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("Bloodwave")

func check_not_have_Bloodboardsword() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("Bloodboardsword")

func check_not_have_Ice() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("Ice")

func check_not_have_Thunderbreak() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("Thunderbreak")

func check_not_have_Lightbullet() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("Lightbullet")

func check_not_have_Qigong() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("Qigong")

func check_not_have_Dragonwind() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("Dragonwind")

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

func check_not_have_Holylight() -> bool:
	if not _can_add_weapon():
		return false
	return not PC.selected_rewards.has("Holylight")


func check_Thunder_condition() -> bool:
	return PC.selected_rewards.has("Thunder")

func check_Bloodwave_condition() -> bool:
	return PC.selected_rewards.has("Bloodwave")

func check_Bloodboardsword_condition() -> bool:
	return PC.selected_rewards.has("Bloodboardsword")

func check_Thunder1() -> bool:
	return PC.selected_rewards.has("Thunder1")

func check_Thunder2() -> bool:
	return PC.selected_rewards.has("Thunder2")

func check_Thunder3() -> bool:
	return PC.selected_rewards.has("Thunder3")

func check_Branch1() -> bool:
	return PC.selected_rewards.has("Branch3") and PC.selected_rewards.has("Branch4")

func check_Branch12() -> bool:
	return PC.selected_rewards.has("Branch1") and PC.selected_rewards.has("Branch2")

func check_Branch3() -> bool:
	return PC.selected_rewards.has("Branch1") and PC.selected_rewards.has("Branch4")

func check_Branch2() -> bool:
	return PC.selected_rewards.has("Branch2") and PC.selected_rewards.has("Branch3")

func check_Bloodwave1() -> bool:
	return PC.selected_rewards.has("Bloodwave1")

func check_Bloodwave2() -> bool:
	return PC.selected_rewards.has("Bloodwave2")

func check_Bloodwave3() -> bool:
	return PC.selected_rewards.has("Bloodwave3")

func check_Bloodboardsword1() -> bool:
	return PC.selected_rewards.has("BloodBoardSword1")

func check_Bloodboardsword2() -> bool:
	return PC.selected_rewards.has("BloodBoardSword2")

func check_Bloodboardsword3() -> bool:
	return PC.selected_rewards.has("BloodBoardSword3")


func check_Ice_condition() -> bool:
	return PC.selected_rewards.has("Ice")

func check_Ice_condition1() -> bool:
	return PC.selected_rewards.has("Ice1")

func check_Ice_condition2() -> bool:
	return PC.selected_rewards.has("Ice2")

func check_Ice_condition3() -> bool:
	return PC.selected_rewards.has("Ice3")

func check_Ice_condition4() -> bool:
	return PC.selected_rewards.has("Ice4")

func check_Ice_condition5() -> bool:
	return PC.selected_rewards.has("Ice5")

func check_Thunderbreak_condition() -> bool:
	return PC.selected_rewards.has("Thunderbreak")

func check_Thunderbreak1() -> bool:
	return PC.selected_rewards.has("ThunderBreak1") and PC.selected_rewards.has("ThunderBreak2")

func check_Thunderbreak2() -> bool:
	return PC.selected_rewards.has("ThunderBreak2") and PC.selected_rewards.has("ThunderBreak4")

func check_Thunderbreak3() -> bool:
	return PC.selected_rewards.has("ThunderBreak1") and PC.selected_rewards.has("ThunderBreak3")


func reward_RQigong():
	PC.main_skill_qigong += 1
	PC.pc_atk_speed += 0.04
	Qigong.main_skill_qigong_damage += 0.04
	_level_up_action()

func reward_SRQigong():
	PC.main_skill_qigong += 1
	PC.pc_atk_speed += 0.045
	Qigong.main_skill_qigong_damage += 0.05
	_level_up_action()

func reward_SSRQigong():
	PC.main_skill_qigong += 1
	PC.pc_atk_speed += 0.05
	Qigong.main_skill_qigong_damage += 0.06
	_level_up_action()

func reward_URQigong():
	PC.main_skill_qigong += 1
	PC.pc_atk_speed += 0.06
	Qigong.main_skill_qigong_damage += 0.08
	_level_up_action()


func reward_Qigong1():
	PC.faze_wind_level += 1
	PC.faze_wide_level += 1
	PC.selected_rewards.append("Qigong1")
	_level_up_action()

func reward_Qigong2():
	PC.faze_wind_level += 1
	PC.faze_wide_level += 1
	PC.selected_rewards.append("Qigong2")
	_level_up_action()

func reward_Qigong3():
	PC.faze_wind_level += 1
	PC.faze_wide_level += 1
	PC.selected_rewards.append("Qigong3")
	_level_up_action()

func reward_Qigong4():
	PC.faze_wind_level += 1
	PC.faze_wide_level += 1
	PC.selected_rewards.append("Qigong4")
	_level_up_action()

func reward_Qigong5():
	PC.faze_wind_level += 1
	PC.faze_wide_level += 1
	PC.selected_rewards.append("Qigong5")
	_level_up_action()

func reward_Qigong11():
	PC.faze_wind_level += 1
	PC.faze_wide_level += 1
	PC.selected_rewards.append("Qigong11")
	_level_up_action()

func reward_Qigong22():
	PC.faze_wind_level += 1
	PC.faze_wide_level += 1
	PC.selected_rewards.append("Qigong22")
	_level_up_action()

func reward_Qigong33():
	PC.faze_wind_level += 1
	PC.faze_wide_level += 1
	PC.selected_rewards.append("Qigong33")
	_level_up_action()

func reward_Qigong44():
	PC.faze_wind_level += 1
	PC.faze_wide_level += 1
	PC.selected_rewards.append("Qigong44")
	_level_up_action()

func reward_Qigong55():
	PC.faze_wind_level += 1
	PC.faze_wide_level += 1
	PC.selected_rewards.append("Qigong55")
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

func check_Lightbullet_condition() -> bool:
	return PC.selected_rewards.has("Lightbullet")

func check_Lightbullet_condition1() -> bool:
	return PC.selected_rewards.has("LightBullet5") and PC.selected_rewards.has("LightBullet2")

func check_Lightbullet_condition2() -> bool:
	return PC.selected_rewards.has("LightBullet4") and PC.selected_rewards.has("LightBullet1")

func check_Lightbullet_condition3() -> bool:
	return PC.selected_rewards.has("LightBullet2") and PC.selected_rewards.has("LightBullet3")

func check_Lightbullet_condition4() -> bool:
	return PC.selected_rewards.has("LightBullet1") and PC.selected_rewards.has("LightBullet4")


func check_Water_condition() -> bool:
	return PC.selected_rewards.has("Water")

func check_Water_condition1() -> bool:
	return PC.selected_rewards.has("Water1") and PC.selected_rewards.has("Water2")

func check_Water_condition2() -> bool:
	return PC.selected_rewards.has("Water3") and PC.selected_rewards.has("Water4")

func check_Water_condition3() -> bool:
	return PC.selected_rewards.has("Water1") and PC.selected_rewards.has("Water4")


func check_Ringfire_condition() -> bool:
	return PC.selected_rewards.has("Ringfire")

func check_Ringfire_condition12() -> bool:
	return PC.selected_rewards.has("RingFire1") and PC.selected_rewards.has("RingFire2")

func check_Ringfire_condition14() -> bool:
	return PC.selected_rewards.has("RingFire1") and PC.selected_rewards.has("RingFire4")

func check_Ringfire_condition34() -> bool:
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

func check_Moyan12() -> bool:
	return PC.selected_rewards.has("Moyan1") and PC.selected_rewards.has("Moyan2")

func check_Moyan13() -> bool:
	return PC.selected_rewards.has("Moyan1") and PC.selected_rewards.has("Moyan3")

func check_Moyan23() -> bool:
	return PC.selected_rewards.has("Moyan3") and PC.selected_rewards.has("Moyan2")


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
	PC.pc_atk = int(PC.pc_atk + 8)
	PC.pc_atk_speed += 0.015
	EmblemManager.add_emblem("pozhen", 1)
	_level_up_action()

func reward_SR02():
	PC.pc_atk = int(PC.pc_atk + 10)
	PC.pc_atk_speed += 0.02
	EmblemManager.add_emblem("pozhen", 1)
	_level_up_action()

func reward_SSR02():
	PC.pc_atk = int(PC.pc_atk + 12)
	PC.pc_atk_speed += 0.025
	EmblemManager.add_emblem("pozhen", 1)
	_level_up_action()

func reward_UR02():
	PC.pc_atk = int(PC.pc_atk + 16)
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
	PC.pc_atk = int(PC.pc_atk + 12)
	PC.pc_speed -= 0.06
	EmblemManager.add_emblem("manli", 1)
	_level_up_action()

func reward_SR08():
	PC.pc_atk = int(PC.pc_atk + 16)
	PC.pc_speed -= 0.07
	EmblemManager.add_emblem("manli", 1)
	_level_up_action()

func reward_SSR08():
	PC.pc_atk = int(PC.pc_atk + 20)
	PC.pc_speed -= 0.08
	EmblemManager.add_emblem("manli", 1)
	_level_up_action()

func reward_UR08():
	PC.pc_atk = int(PC.pc_atk + 28)
	PC.pc_speed -= 0.1
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
	PC.pc_atk = int(PC.pc_atk + 8)
	EmblemManager.add_emblem("ronghui", 1)
	_level_up_action()

func reward_SR10():
	PC.pc_atk = int(PC.pc_atk + 10)
	EmblemManager.add_emblem("ronghui", 1)
	_level_up_action()

func reward_SSR10():
	PC.pc_atk = int(PC.pc_atk + 12)
	EmblemManager.add_emblem("ronghui", 1)
	_level_up_action()

func reward_UR10():
	PC.pc_atk = int(PC.pc_atk + 16)
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
	PC.damage_reduction_rate += 0.005
	var extra_hp_bonus = min(0.20, PC.damage_reduction_rate * 0.004)
	PC.pc_max_hp = int(PC.pc_max_hp * (1 + extra_hp_bonus))
	_level_up_action()

func reward_SR19():
	PC.pc_max_hp = int(PC.pc_max_hp * 1.11)
	PC.damage_reduction_rate += 0.01
	var extra_hp_bonus = min(0.20, PC.damage_reduction_rate * 0.004)
	PC.pc_max_hp = int(PC.pc_max_hp * (1 + extra_hp_bonus))
	_level_up_action()

func reward_SSR19():
	PC.pc_max_hp = int(PC.pc_max_hp * 1.12)
	PC.damage_reduction_rate += 0.015
	var extra_hp_bonus = min(0.20, PC.damage_reduction_rate * 0.004)
	PC.pc_max_hp = int(PC.pc_max_hp * (1 + extra_hp_bonus))
	_level_up_action()

func reward_UR19():
	PC.pc_max_hp = int(PC.pc_max_hp * 1.14)
	PC.damage_reduction_rate += 0.025
	var extra_hp_bonus = min(0.20, PC.damage_reduction_rate * 0.004)
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
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_destroy_level += 2
	PC.faze_bullet_level += 2
	# 初始化冷却时间
	var player = get_tree().get_first_node_in_group("player")
	if player and player.ice_flower_fire_speed:
		player.ice_flower_fire_speed.start()
	_level_up_action()

func reward_RIce():
	PC.main_skill_ice += 1
	PC.crit_chance += 0.02
	IceFlower.main_skill_ice_damage += 0.04
	_level_up_action()

func reward_SRIce():
	PC.main_skill_ice += 1
	PC.crit_chance += 0.022
	IceFlower.main_skill_ice_damage += 0.05
	_level_up_action()

func reward_SSRIce():
	PC.main_skill_ice += 1
	PC.crit_chance += 0.025
	IceFlower.main_skill_ice_damage += 0.06
	_level_up_action()

func reward_URIce():
	PC.main_skill_ice += 1
	PC.crit_chance += 0.03
	IceFlower.main_skill_ice_damage += 0.08
	_level_up_action()

func reward_Ice1():
	PC.faze_destroy_level += 1
	PC.faze_bullet_level += 1
	PC.selected_rewards.append("Ice1")
	_level_up_action()

func reward_Ice2():
	PC.faze_destroy_level += 1
	PC.faze_bullet_level += 1
	PC.selected_rewards.append("Ice2")
	_level_up_action()

func reward_Ice3():
	PC.faze_destroy_level += 1
	PC.faze_bullet_level += 1
	PC.selected_rewards.append("Ice3")
	_level_up_action()

func reward_Ice4():
	PC.faze_destroy_level += 1
	PC.faze_bullet_level += 1
	PC.selected_rewards.append("Ice4")
	_level_up_action()

func reward_Ice5():
	PC.faze_destroy_level += 1
	PC.faze_bullet_level += 1
	PC.selected_rewards.append("Ice5")
	_level_up_action()

func reward_Ice11():
	PC.faze_destroy_level += 1
	PC.faze_bullet_level += 1
	PC.selected_rewards.append("Ice11")
	_level_up_action()

func reward_Ice22():
	PC.faze_destroy_level += 1
	PC.faze_bullet_level += 1
	PC.selected_rewards.append("Ice22")
	_level_up_action()

func reward_Ice33():
	PC.faze_destroy_level += 1
	PC.faze_bullet_level += 1
	PC.selected_rewards.append("Ice33")
	_level_up_action()

func reward_Ice44():
	PC.faze_destroy_level += 1
	PC.faze_bullet_level += 1
	PC.selected_rewards.append("Ice44")
	_level_up_action()

func reward_Ice55():
	PC.faze_destroy_level += 1
	PC.faze_bullet_level += 1
	PC.selected_rewards.append("Ice55")
	_level_up_action()

# --- 天雷破相关奖励函数 ---
func reward_ThunderBreak():
	PC.selected_rewards.append("Thunderbreak")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_thunder_level += 2
	PC.faze_destroy_level += 2
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
	PC.thunder_break_final_damage_multi += 0.4
	PC.faze_thunder_level += 1
	PC.faze_destroy_level += 1
	PC.selected_rewards.append("ThunderBreak1")
	_level_up_action()

func reward_ThunderBreak2():
	PC.thunder_break_final_damage_multi += 0.3
	PC.faze_thunder_level += 1
	PC.faze_destroy_level += 1
	PC.selected_rewards.append("ThunderBreak2")
	_level_up_action()

func reward_ThunderBreak3():
	PC.thunder_break_final_damage_multi += 0.2
	PC.faze_thunder_level += 1
	PC.faze_destroy_level += 1
	PC.selected_rewards.append("ThunderBreak3")
	_level_up_action()

func reward_ThunderBreak4():
	PC.thunder_break_final_damage_multi += 0.2
	PC.faze_thunder_level += 1
	PC.faze_destroy_level += 1
	PC.selected_rewards.append("ThunderBreak4")
	_level_up_action()

func reward_ThunderBreak11():
	PC.thunder_break_final_damage_multi += 0.3
	PC.faze_thunder_level += 1
	PC.faze_destroy_level += 1
	PC.selected_rewards.append("ThunderBreak11")
	_level_up_action()

func reward_ThunderBreak22():
	PC.thunder_break_final_damage_multi += 0.4
	PC.faze_thunder_level += 1
	PC.faze_destroy_level += 1
	PC.selected_rewards.append("ThunderBreak22")
	_level_up_action()

func reward_ThunderBreak33():
	PC.thunder_break_final_damage_multi += 0.8
	PC.faze_thunder_level += 1
	PC.faze_destroy_level += 1
	PC.selected_rewards.append("ThunderBreak33")
	_level_up_action()


# --- 光弹相关奖励函数 ---
func reward_LightBullet():
	PC.selected_rewards.append("Lightbullet")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_bullet_level += 2
	PC.faze_life_level += 2
	_level_up_action()

func reward_RLightBullet():
	PC.main_skill_light_bullet += 1
	PC.pc_atk_speed += 0.04
	PC.light_bullet_final_damage_multi += 0.04
	_level_up_action()

func reward_SRLightBullet():
	PC.main_skill_light_bullet += 1
	PC.pc_atk_speed += 0.045
	PC.light_bullet_final_damage_multi += 0.045
	_level_up_action()

func reward_SSRLightBullet():
	PC.main_skill_light_bullet += 1
	PC.pc_atk_speed += 0.05
	PC.light_bullet_final_damage_multi += 0.05
	_level_up_action()

func reward_URLightBullet():
	PC.main_skill_light_bullet += 1
	PC.pc_atk_speed += 0.06
	PC.light_bullet_final_damage_multi += 0.06
	_level_up_action()

func reward_LightBullet1():
	PC.selected_rewards.append("LightBullet1")
	PC.faze_bullet_level += 1
	PC.faze_life_level += 1
	_level_up_action()

func reward_LightBullet2():
	PC.selected_rewards.append("LightBullet2")
	PC.faze_bullet_level += 1
	PC.faze_life_level += 1
	_level_up_action()

func reward_LightBullet3():
	PC.selected_rewards.append("LightBullet3")
	PC.faze_bullet_level += 1
	PC.faze_life_level += 1
	PC.main_skill_light_bullet_damage += 0.1
	_level_up_action()

func reward_LightBullet4():
	PC.selected_rewards.append("LightBullet4")
	PC.faze_bullet_level += 1
	PC.faze_life_level += 1
	_level_up_action()

func reward_LightBullet5():
	PC.selected_rewards.append("LightBullet5")
	PC.faze_bullet_level += 1
	PC.faze_life_level += 1
	PC.main_skill_light_bullet_damage += 0.1
	_level_up_action()

func reward_LightBullet11():
	PC.selected_rewards.append("LightBullet11")
	PC.faze_bullet_level += 1
	PC.faze_life_level += 1
	PC.main_skill_light_bullet_damage += 0.1
	_level_up_action()

func reward_LightBullet22():
	PC.selected_rewards.append("LightBullet22")
	PC.faze_bullet_level += 1
	PC.faze_life_level += 1
	_level_up_action()

func reward_LightBullet33():
	PC.selected_rewards.append("LightBullet33")
	PC.faze_bullet_level += 1
	PC.faze_life_level += 1
	_level_up_action()

func reward_LightBullet44():
	PC.selected_rewards.append("LightBullet44")
	PC.faze_bullet_level += 1
	PC.faze_life_level += 1
	_level_up_action()

# --- 坎水诀相关奖励函数 ---
func reward_Water():
	PC.selected_rewards.append("Water")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_heal_level += 2
	PC.faze_life_level += 2
	_level_up_action()

func reward_RWater():
	PC.main_skill_water += 1
	PC.heal_multi += 0.024
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.024)
	PC.water_final_damage_multi += 0.06
	_level_up_action()

func reward_SRWater():
	PC.main_skill_water += 1
	PC.heal_multi += 0.028
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.028)
	PC.water_final_damage_multi += 0.07
	_level_up_action()

func reward_SSRWater():
	PC.main_skill_water += 1
	PC.heal_multi += 0.032
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.032)
	PC.water_final_damage_multi += 0.08
	_level_up_action()

func reward_URWater():
	PC.main_skill_water += 1
	PC.heal_multi += 0.04
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.04)
	PC.water_final_damage_multi += 0.1
	_level_up_action()

func reward_Water1():
	PC.selected_rewards.append("Water1")
	PC.faze_heal_level += 1
	PC.faze_life_level += 1
	_level_up_action()

func reward_Water2():
	PC.selected_rewards.append("Water2")
	PC.main_skill_water_damage += 0.15
	PC.faze_heal_level += 1
	PC.faze_life_level += 1
	_level_up_action()

func reward_Water3():
	PC.selected_rewards.append("Water3")
	PC.main_skill_water_damage += 0.15
	PC.faze_heal_level += 1
	PC.faze_life_level += 1
	_level_up_action()

func reward_Water4():
	PC.selected_rewards.append("Water4")
	PC.main_skill_water_damage += 0.15
	PC.faze_heal_level += 1
	PC.faze_life_level += 1
	_level_up_action()

func reward_Water11():
	PC.selected_rewards.append("Water11")
	PC.main_skill_water_damage += 0.1
	PC.faze_heal_level += 1
	PC.faze_life_level += 1
	_level_up_action()

func reward_Water22():
	PC.selected_rewards.append("Water22")
	PC.main_skill_water_damage += 0.1
	PC.faze_heal_level += 1
	PC.faze_life_level += 1
	_level_up_action()

func reward_Water33():
	PC.selected_rewards.append("Water33")
	PC.main_skill_water_damage += 0.15
	PC.faze_heal_level += 1
	PC.faze_life_level += 1
	_level_up_action()

# --- 乾坤双剑相关奖励函数 ---
func reward_Qiankun():
	Qiankun.reset_data()
	PC.selected_rewards.append("Qiankun")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_sword_level += 2
	PC.faze_bagua_level += 2
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
	PC.pc_atk = int(PC.pc_atk + PC.pc_start_atk * 0.04)
	Qiankun.qiankun_final_damage_multi += 0.06
	_level_up_action()

func reward_SRQiankun():
	PC.main_skill_qiankun += 1
	PC.pc_atk = int(PC.pc_atk + PC.pc_start_atk * 0.045)
	Qiankun.qiankun_final_damage_multi += 0.07
	_level_up_action()

func reward_SSRQiankun():
	PC.main_skill_qiankun += 1
	PC.pc_atk = int(PC.pc_atk + PC.pc_start_atk * 0.05)
	Qiankun.qiankun_final_damage_multi += 0.08
	_level_up_action()

func reward_URQiankun():
	PC.main_skill_qiankun += 1
	PC.pc_atk = int(PC.pc_atk + PC.pc_start_atk * 0.06)
	Qiankun.qiankun_final_damage_multi += 0.1
	_level_up_action()

func reward_Qiankun1():
	PC.selected_rewards.append("Qiankun1")
	Qiankun.main_skill_qiankun_damage += 0.1
	Qiankun.qiankun_speed *= 1.25
	PC.faze_sword_level += 1
	PC.faze_bagua_level += 1
	_level_up_action()

func reward_Qiankun2():
	PC.selected_rewards.append("Qiankun2")
	Qiankun.main_skill_qiankun_damage += 0.1
	Qiankun.qiankun_range *= 1.5
	PC.faze_sword_level += 1
	PC.faze_bagua_level += 1
	_level_up_action()

func reward_Qiankun3():
	PC.selected_rewards.append("Qiankun3")
	Qiankun.main_skill_qiankun_damage += 0.1
	Qiankun.qiankun_speed_per_enemy = 0.02
	PC.faze_sword_level += 1
	PC.faze_bagua_level += 1
	_level_up_action()

func reward_Qiankun4():
	PC.selected_rewards.append("Qiankun4")
	Qiankun.main_skill_qiankun_damage += 0.1
	Qiankun.qiankun_damage_per_debuff = 0.3
	PC.faze_sword_level += 1
	PC.faze_bagua_level += 1
	_level_up_action()

func reward_Qiankun11():
	PC.selected_rewards.append("Qiankun11")
	Qiankun.main_skill_qiankun_damage += 0.1
	Qiankun.qiankun_speed *= 1.1
	Qiankun.qiankun_speed_per_enemy = 0.03
	PC.faze_sword_level += 1
	PC.faze_bagua_level += 1
	_level_up_action()

func reward_Qiankun22():
	PC.selected_rewards.append("Qiankun22")
	Qiankun.qiankun_range *= 1.2
	Qiankun.qiankun_damage_per_enemy = 0.03
	PC.faze_sword_level += 1
	PC.faze_bagua_level += 1
	_level_up_action()

func reward_Qiankun33():
	PC.selected_rewards.append("Qiankun33")
	Qiankun.main_skill_qiankun_damage += 0.1
	Qiankun.qiankun_crit_on_3_debuffs = true
	PC.faze_sword_level += 1
	PC.faze_bagua_level += 1
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
	PC.faze_summon_level += 1
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
	PC.faze_summon_level += 1
	PC.new_summon = "darkorchid" # 记录最新获得的召唤物类型
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
	PC.faze_summon_level += 1
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
	PC.faze_summon_level += 1
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
	PC.faze_summon_level += 1
	# 通知battle场景添加召唤物
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(4)
	_level_up_action()

func reward_SSR21():
	PC.summon_count += 1
	PC.selected_rewards.append("gold_heal_summon")
	PC.faze_summon_level += 1
	# 通知battle场景添加召唤物
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(5)
	_level_up_action()

func reward_UR21():
	PC.summon_count += 1
	PC.selected_rewards.append("red_heal_summon")
	PC.faze_summon_level += 1
	# 通知battle场景添加召唤物
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(6)
	_level_up_action()


func reward_SR22():
	PC.summon_count += 1
	PC.selected_rewards.append("darkorchid_aux_summon")
	PC.faze_summon_level += 1
	# 通知battle场景添加召唤物
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(7)
	_level_up_action()

func reward_SSR22():
	PC.summon_count += 1
	PC.selected_rewards.append("gold_aux_summon")
	PC.faze_summon_level += 1
	# 通知battle场景添加召唤物
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(8)
	_level_up_action()

func reward_UR22():
	PC.summon_count += 1
	PC.selected_rewards.append("red_aux_summon")
	PC.faze_summon_level += 1
	# 通知battle场景添加召唤物
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(9)
	_level_up_action()

func reward_Branch():
	PC.selected_rewards.append("Branch")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_treasure_level += 2
	PC.faze_bullet_level += 2
	_level_up_action()

func reward_Moyan():
	PC.selected_rewards.append("Moyan")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_fire_level += 2
	PC.faze_destroy_level += 2
	_level_up_action()

func reward_RingFire():
	PC.selected_rewards.append("Ringfire")
	PC.faze_fire_level += 2
	PC.faze_bagua_level += 2
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	_level_up_action()
	
func reward_Riyan():
	PC.selected_rewards.append("Riyan")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_fire_level += 2
	PC.faze_wide_level += 2
	_level_up_action()

func reward_Thunder():
	PC.selected_rewards.append("Thunder")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_thunder_level += 2
	PC.faze_bagua_level += 2
	_level_up_action()

func reward_Bloodwave():
	BloodWave.reset_data()
	PC.selected_rewards.append("Bloodwave")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_wide_level += 2
	PC.faze_blood_level += 2
	_level_up_action()

func reward_BloodBoardSword():
	PC.selected_rewards.append("Bloodboardsword")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_sword_level += 2
	PC.faze_blood_level += 2
	_level_up_action()

func reward_RSwordQi():
	PC.main_skill_swordQi += 1
	PC.main_skill_swordQi_damage += 0.04
	PC.pc_atk_speed += 0.04
	_level_up_action()

func reward_SRSwordQi():
	PC.main_skill_swordQi += 1
	PC.pc_atk_speed += 0.045
	PC.main_skill_swordQi_damage += 0.05
	_level_up_action()
	
func reward_SSRSwordQi():
	PC.main_skill_swordQi += 1
	PC.pc_atk_speed += 0.05
	PC.main_skill_swordQi_damage += 0.06
	_level_up_action()

func reward_URSwordQi():
	PC.main_skill_swordQi += 1
	PC.pc_atk_speed += 0.06
	PC.main_skill_swordQi_damage += 0.08
	_level_up_action()

	
func reward_SplitSwordQi1():
	PC.selected_rewards.append("SplitSwordQi1")
	PC.faze_sword_level += 1
	PC.faze_bullet_level += 1
	_level_up_action()
	
func reward_SplitSwordQi2():
	PC.selected_rewards.append("SplitSwordQi2")
	PC.main_skill_swordQi_damage += 0.1
	PC.faze_sword_level += 1
	PC.faze_bullet_level += 1
	_level_up_action()
	
func reward_SplitSwordQi3():
	PC.selected_rewards.append("SplitSwordQi3")
	PC.main_skill_swordQi_damage -= 0.05
	PC.swordQi_penetration_count += 1 # 原来是1次，现在变成3次
	PC.faze_sword_level += 1
	PC.faze_bullet_level += 1
	_level_up_action()

func reward_SplitSwordQi4():
	PC.selected_rewards.append("SplitSwordQi4")
	PC.main_skill_swordQi_damage += 0.15
	PC.faze_sword_level += 1
	PC.faze_bullet_level += 1
	_level_up_action()
	
func reward_SplitSwordQi11():
	PC.selected_rewards.append("SplitSwordQi11")
	PC.main_skill_swordQi_damage += 0.05
	PC.faze_sword_level += 1
	PC.faze_bullet_level += 1
	_level_up_action()
	
func reward_SplitSwordQi12():
	PC.selected_rewards.append("SplitSwordQi12")
	PC.main_skill_swordQi_damage += 0.05
	PC.faze_sword_level += 1
	PC.faze_bullet_level += 1
	_level_up_action()
	
func reward_SplitSwordQi13():
	PC.selected_rewards.append("SplitSwordQi13")
	PC.main_skill_swordQi_damage += 0.1
	PC.faze_sword_level += 1
	PC.faze_bullet_level += 1
	_level_up_action()
	
func reward_SplitSwordQi21():
	PC.selected_rewards.append("SplitSwordQi21")
	PC.main_skill_swordQi_damage += 0.1
	PC.faze_sword_level += 1
	PC.faze_bullet_level += 1
	_level_up_action()
	
func reward_SplitSwordQi22():
	PC.selected_rewards.append("SplitSwordQi22")
	PC.faze_sword_level += 1
	PC.faze_bullet_level += 1
	_level_up_action()
	
func reward_SplitSwordQi23():
	PC.selected_rewards.append("SplitSwordQi23")
	PC.faze_sword_level += 1
	PC.faze_bullet_level += 1
	_level_up_action()
	
func reward_SplitSwordQi31():
	PC.selected_rewards.append("SplitSwordQi31")
	PC.main_skill_swordQi_damage -= 0.05
	PC.swordQi_penetration_count += 1 # 使穿透次数达到5次
	PC.faze_sword_level += 1
	PC.faze_bullet_level += 1
	_level_up_action()
	
func reward_SplitSwordQi32():
	PC.selected_rewards.append("SplitSwordQi32")
	PC.faze_sword_level += 1
	PC.faze_bullet_level += 1
	_level_up_action()
	
func reward_SplitSwordQi33():
	PC.selected_rewards.append("SplitSwordQi33")
	PC.faze_sword_level += 1
	PC.faze_bullet_level += 1
	_level_up_action()
	

func reward_RBranch():
	PC.main_skill_branch += 1
	PC.pc_atk = int(PC.pc_atk * 1.024)
	PC.exp_multi += 0.024
	PC.main_skill_branch_damage += 0.06
	_level_up_action()

func reward_SRBranch():
	PC.main_skill_branch += 1
	PC.pc_atk = int(PC.pc_atk * 1.028)
	PC.exp_multi += 0.028
	PC.main_skill_branch_damage += 0.07
	_level_up_action()
	
func reward_SSRBranch():
	PC.main_skill_branch += 1
	PC.pc_atk = int(PC.pc_atk * 1.032)
	PC.exp_multi += 0.032
	PC.main_skill_branch_damage += 0.08
	_level_up_action()

func reward_URBranch():
	PC.main_skill_branch += 1
	PC.pc_atk = int(PC.pc_atk * 1.04)
	PC.exp_multi += 0.04
	PC.main_skill_branch_damage += 0.1
	_level_up_action()

func reward_Branch1():
	PC.selected_rewards.append("Branch1")
	PC.faze_treasure_level += 1
	PC.faze_bullet_level += 1
	_level_up_action()

func reward_Branch2():
	PC.selected_rewards.append("Branch2")
	PC.faze_treasure_level += 1
	PC.faze_bullet_level += 1
	_level_up_action()

func reward_Branch3():
	PC.selected_rewards.append("Branch3")
	PC.faze_treasure_level += 1
	PC.faze_bullet_level += 1
	_level_up_action()

func reward_Branch4():
	PC.selected_rewards.append("Branch4")
	PC.faze_treasure_level += 1
	PC.faze_bullet_level += 1
	_level_up_action()

func reward_Branch11():
	PC.selected_rewards.append("Branch11")
	PC.faze_treasure_level += 1
	PC.faze_bullet_level += 1
	_level_up_action()

func reward_Branch21():
	PC.selected_rewards.append("Branch21")
	PC.faze_treasure_level += 1
	PC.faze_bullet_level += 1
	_level_up_action()

func reward_Branch12():
	PC.selected_rewards.append("Branch12")
	PC.faze_treasure_level += 1
	PC.faze_bullet_level += 1
	_level_up_action()

func reward_Branch31():
	PC.selected_rewards.append("Branch31")
	PC.faze_treasure_level += 1
	PC.faze_bullet_level += 1
	_level_up_action()

func reward_Branch22():
	PC.selected_rewards.append("Branch22")
	PC.main_skill_branch_damage += 0.1
	PC.faze_treasure_level += 1
	PC.faze_bullet_level += 1
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

func reward_URMoyan():
	PC.main_skill_moyan += 1
	PC.crit_damage_multi += 0.06
	PC.main_skill_moyan_damage += 0.1
	_level_up_action()

func reward_Moyan1():
	PC.selected_rewards.append("Moyan1")
	PC.main_skill_moyan_damage += 0.1
	PC.faze_fire_level += 1
	PC.faze_destroy_level += 1
	_level_up_action()

func reward_Moyan2():
	PC.selected_rewards.append("Moyan2")
	PC.main_skill_moyan_damage += 0.1
	PC.faze_fire_level += 1
	PC.faze_destroy_level += 1
	_level_up_action()

func reward_Moyan3():
	PC.selected_rewards.append("Moyan3")
	PC.faze_fire_level += 1
	PC.faze_destroy_level += 1
	_level_up_action()

func reward_Moyan12():
	PC.selected_rewards.append("Moyan12")
	PC.faze_fire_level += 1
	PC.faze_destroy_level += 1
	_level_up_action()

func reward_Moyan13():
	PC.selected_rewards.append("Moyan13")
	PC.main_skill_moyan_damage += 0.1
	PC.faze_fire_level += 1
	PC.faze_destroy_level += 1
	_level_up_action()

func reward_Moyan23():
	PC.selected_rewards.append("Moyan23")
	PC.faze_fire_level += 1
	PC.faze_destroy_level += 1
	_level_up_action()


func reward_RRingFire():
	PC.main_skill_ringFire += 1
	PC.crit_chance += 0.02
	PC.main_skill_ringFire_damage += 0.06
	_level_up_action()

func reward_SRRingFire():
	PC.main_skill_ringFire += 1
	PC.crit_chance += 0.022
	PC.main_skill_ringFire_damage += 0.07
	_level_up_action()
	
func reward_SSRRingFire():
	PC.main_skill_ringFire += 1
	PC.crit_chance += 0.025
	PC.main_skill_ringFire_damage += 0.08
	_level_up_action()

func reward_URRingFire():
	PC.main_skill_ringFire += 1
	PC.crit_chance += 0.03
	PC.main_skill_ringFire_damage += 0.1
	_level_up_action()

func reward_RingFire1():
	PC.selected_rewards.append("RingFire1")
	PC.faze_fire_level += 1
	PC.faze_bagua_level += 1
	_level_up_action()

func reward_RingFire2():
	PC.selected_rewards.append("RingFire2")
	PC.faze_fire_level += 1
	PC.faze_bagua_level += 1
	_level_up_action()

func reward_RingFire3():
	PC.selected_rewards.append("RingFire3")
	PC.main_skill_ringFire_damage += 0.2
	PC.faze_fire_level += 1
	PC.faze_bagua_level += 1
	_level_up_action()

func reward_RingFire11():
	PC.selected_rewards.append("RingFire11")
	PC.faze_fire_level += 1
	PC.faze_bagua_level += 1
	_level_up_action()

func reward_RingFire4():
	PC.selected_rewards.append("RingFire4")
	PC.main_skill_ringFire_damage += 0.1
	PC.faze_fire_level += 1
	PC.faze_bagua_level += 1
	_level_up_action()

func reward_RingFire22():
	PC.selected_rewards.append("RingFire22")
	PC.faze_fire_level += 1
	PC.faze_bagua_level += 1
	_level_up_action()

func reward_RingFire33():
	PC.selected_rewards.append("RingFire33")
	PC.faze_fire_level += 1
	PC.faze_bagua_level += 1
	_level_up_action()

func reward_Rriyan():
	PC.main_skill_riyan += 1
	PC.pc_atk = int(PC.pc_atk * 1.02)
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.02)
	PC.main_skill_riyan_damage += 0.06
	_level_up_action()

func reward_SRriyan():
	PC.main_skill_riyan += 1
	PC.pc_atk = int(PC.pc_atk * 1.022)
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.022)
	PC.main_skill_riyan_damage += 0.07
	_level_up_action()
	
func reward_SSRriyan():
	PC.main_skill_riyan += 1
	PC.pc_atk = int(PC.pc_atk * 1.025)
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.025)
	PC.main_skill_riyan_damage += 0.08
	_level_up_action()

func reward_URriyan():
	PC.main_skill_riyan += 1
	PC.pc_atk = int(PC.pc_atk * 1.03)
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.03)
	PC.main_skill_riyan_damage += 0.1
	_level_up_action()

func reward_Riyan1():
	PC.selected_rewards.append("Riyan1")
	PC.main_skill_riyan_damage += 0.1
	PC.faze_fire_level += 1
	PC.faze_wide_level += 1
	_level_up_action()

func reward_Riyan2():
	PC.selected_rewards.append("Riyan2")
	PC.main_skill_riyan_damage += 0.1
	PC.faze_fire_level += 1
	PC.faze_wide_level += 1
	_level_up_action()

func reward_Riyan3():
	PC.selected_rewards.append("Riyan3")
	PC.main_skill_riyan_damage += 0.1
	PC.faze_fire_level += 1
	PC.faze_wide_level += 1
	_level_up_action()

func reward_Riyan4():
	PC.selected_rewards.append("Riyan4")
	PC.main_skill_riyan_damage += 0.1
	PC.faze_fire_level += 1
	PC.faze_wide_level += 1
	_level_up_action()

func reward_Riyan11():
	PC.selected_rewards.append("Riyan11")
	PC.main_skill_riyan_damage += 0.1
	PC.faze_fire_level += 1
	PC.faze_wide_level += 1
	_level_up_action()

func reward_Riyan22():
	PC.selected_rewards.append("Riyan22")
	PC.main_skill_riyan_damage += 0.15
	PC.faze_fire_level += 1
	PC.faze_wide_level += 1
	_level_up_action()

func reward_Riyan33():
	PC.selected_rewards.append("Riyan33")
	PC.main_skill_riyan_damage += 0.1
	PC.faze_fire_level += 1
	PC.faze_wide_level += 1
	_level_up_action()

func reward_RBloodwave():
	PC.main_skill_bloodwave += 1
	PC.pc_final_atk += 0.02
	BloodWave.main_skill_bloodwave_damage += 0.2
	_level_up_action()

func reward_SRBloodwave():
	PC.main_skill_bloodwave += 1
	PC.pc_final_atk += 0.022
	BloodWave.main_skill_bloodwave_damage += 0.22
	_level_up_action()

func reward_SSRBloodwave():
	PC.main_skill_bloodwave += 1
	PC.pc_final_atk += 0.025
	BloodWave.main_skill_bloodwave_damage += 0.24
	_level_up_action()

func reward_URBloodwave():
	PC.main_skill_bloodwave += 1
	PC.pc_final_atk += 0.03
	BloodWave.main_skill_bloodwave_damage += 0.28
	_level_up_action()

func reward_RBloodBoardSword():
	PC.main_skill_bloodboardsword += 1
	PC.pc_atk = int(PC.pc_atk * 1.04)
	PC.main_skill_bloodboardsword_damage += 0.06
	_level_up_action()

func reward_SRBloodBoardSword():
	PC.main_skill_bloodboardsword += 1
	PC.pc_atk = int(PC.pc_atk * 1.045)
	PC.main_skill_bloodboardsword_damage += 0.07
	_level_up_action()

func reward_SSRBloodBoardSword():
	PC.main_skill_bloodboardsword += 1
	PC.pc_atk = int(PC.pc_atk * 1.05)
	PC.main_skill_bloodboardsword_damage += 0.08
	_level_up_action()

func reward_URBloodBoardSword():
	PC.main_skill_bloodboardsword += 1
	PC.pc_atk = int(PC.pc_atk * 1.06)
	PC.main_skill_bloodboardsword_damage += 0.1
	_level_up_action()

func reward_BloodBoardSword1():
	PC.faze_blood_level += 1
	PC.faze_sword_level += 1
	PC.selected_rewards.append("BloodBoardSword1")
	_level_up_action()

func reward_BloodBoardSword2():
	PC.faze_blood_level += 1
	PC.faze_sword_level += 1
	PC.selected_rewards.append("BloodBoardSword2")
	_level_up_action()

func reward_BloodBoardSword3():
	PC.faze_blood_level += 1
	PC.faze_sword_level += 1
	PC.selected_rewards.append("BloodBoardSword3")
	_level_up_action()

func reward_BloodBoardSword4():
	PC.faze_blood_level += 1
	PC.faze_sword_level += 1
	PC.selected_rewards.append("BloodBoardSword4")
	_level_up_action()

func reward_BloodBoardSword11():
	PC.faze_blood_level += 1
	PC.faze_sword_level += 1
	PC.selected_rewards.append("BloodBoardSword11")
	_level_up_action()

func reward_BloodBoardSword22():
	PC.faze_blood_level += 1
	PC.faze_sword_level += 1
	PC.selected_rewards.append("BloodBoardSword22")
	_level_up_action()

func reward_BloodBoardSword33():
	PC.faze_blood_level += 1
	PC.faze_sword_level += 1
	PC.selected_rewards.append("BloodBoardSword33")
	_level_up_action()

func reward_RThunder():
	PC.main_skill_thunder += 1
	PC.pc_final_atk += 0.02
	PC.main_skill_thunder_damage += 0.2
	_level_up_action()

func reward_SRThunder():
	PC.main_skill_thunder += 1
	PC.pc_final_atk += 0.022
	PC.main_skill_thunder_damage += 0.22
	_level_up_action()

func reward_SSRThunder():
	PC.main_skill_thunder += 1
	PC.pc_final_atk += 0.025
	PC.main_skill_thunder_damage += 0.24
	_level_up_action()

func reward_URThunder():
	PC.main_skill_thunder += 1
	PC.pc_final_atk += 0.03
	PC.main_skill_thunder_damage += 0.28
	_level_up_action()

func reward_Thunder1():
	PC.faze_bagua_level += 1
	PC.faze_thunder_level += 1
	PC.selected_rewards.append("Thunder1")
	_level_up_action()

func reward_Thunder2():
	PC.faze_bagua_level += 1
	PC.faze_thunder_level += 1
	PC.selected_rewards.append("Thunder2")
	_level_up_action()

func reward_Thunder3():
	PC.faze_bagua_level += 1
	PC.faze_thunder_level += 1
	PC.selected_rewards.append("Thunder3")
	_level_up_action()

func reward_Thunder4():
	PC.faze_bagua_level += 1
	PC.faze_thunder_level += 1
	PC.selected_rewards.append("Thunder4")
	_level_up_action()

func reward_Thunder11():
	PC.faze_bagua_level += 1
	PC.faze_thunder_level += 1
	PC.selected_rewards.append("Thunder11")
	_level_up_action()

func reward_Thunder22():
	PC.faze_bagua_level += 1
	PC.faze_thunder_level += 1
	PC.selected_rewards.append("Thunder22")
	_level_up_action()

func reward_Thunder33():
	PC.faze_bagua_level += 1
	PC.faze_thunder_level += 1
	PC.selected_rewards.append("Thunder33")
	_level_up_action()

func reward_Bloodwave1():
	PC.faze_blood_level += 1
	PC.faze_wide_level += 1
	PC.selected_rewards.append("Bloodwave1")
	BloodWave.bloodwave_apply_bleed = true
	_level_up_action()

func reward_Bloodwave2():
	PC.faze_blood_level += 1
	PC.faze_wide_level += 1
	PC.selected_rewards.append("Bloodwave2")
	BloodWave.bloodwave_hp_cost_multi = 2.0
	BloodWave.bloodwave_extra_crit_chance += 0.3
	BloodWave.bloodwave_extra_crit_damage += 0.3
	_level_up_action()

func reward_Bloodwave3():
	PC.faze_blood_level += 1
	PC.faze_wide_level += 1
	PC.selected_rewards.append("Bloodwave3")
	BloodWave.bloodwave_missing_hp_damage_bonus = 0.01
	BloodWave.bloodwave_missing_hp_range_bonus = 0.02
	_level_up_action()

func reward_Bloodwave4():
	PC.faze_blood_level += 1
	PC.faze_wide_level += 1
	PC.selected_rewards.append("Bloodwave4")
	BloodWave.main_skill_bloodwave_damage += 0.1
	BloodWave.bloodwave_missing_hp_heal_bonus = 0.01
	_level_up_action()

func reward_Bloodwave11():
	PC.faze_blood_level += 1
	PC.faze_wide_level += 1
	PC.selected_rewards.append("Bloodwave11")
	BloodWave.bloodwave_missing_hp_damage_bonus = 0.015
	BloodWave.bloodwave_missing_hp_heal_bonus = 0.015
	_level_up_action()

func reward_Bloodwave22():
	PC.faze_blood_level += 1
	PC.faze_wide_level += 1
	PC.selected_rewards.append("Bloodwave22")
	BloodWave.main_skill_bloodwave_damage += 0.1
	BloodWave.bloodwave_low_hp_damage_bonus = 0.4
	BloodWave.bloodwave_low_hp_range_bonus = 0.4
	_level_up_action()

func reward_Bloodwave33():
	PC.faze_blood_level += 1
	PC.faze_wide_level += 1
	PC.selected_rewards.append("Bloodwave33")
	BloodWave.main_skill_bloodwave_damage += 0.1
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
	PC.faze_shield_level += 2
	PC.faze_treasure_level += 2
	_level_up_action()

func reward_RXuanwu():
	PC.main_skill_xuanwu += 1
	PC.pc_atk = int(PC.pc_atk * 1.024)
	PC.damage_reduction_rate += 0.01
	Xuanwu.xuanwu_final_damage_multi += 0.06
	_level_up_action()

func reward_SRXuanwu():
	PC.main_skill_xuanwu += 1
	PC.pc_atk = int(PC.pc_atk * 1.028)
	PC.damage_reduction_rate += 0.011
	Xuanwu.xuanwu_final_damage_multi += 0.07
	_level_up_action()

func reward_SSRXuanwu():
	PC.main_skill_xuanwu += 1
	PC.pc_atk = int(PC.pc_atk * 1.032)
	PC.damage_reduction_rate += 0.012
	Xuanwu.xuanwu_final_damage_multi += 0.08
	_level_up_action()

func reward_URXuanwu():
	PC.main_skill_xuanwu += 1
	PC.pc_atk = int(PC.pc_atk * 1.04)
	PC.damage_reduction_rate += 0.014
	Xuanwu.xuanwu_final_damage_multi += 0.1
	_level_up_action()

func reward_Xuanwu1():
	PC.selected_rewards.append("Xuanwu1")
	PC.faze_shield_level += 1
	PC.faze_treasure_level += 1
	Xuanwu.xuanwu_final_damage_multi += 0.15
	Xuanwu.xuanwu_shield_base += 2
	Xuanwu.xuanwu_shield_hp_ratio = 0.07
	_level_up_action()

func reward_Xuanwu2():
	PC.selected_rewards.append("Xuanwu2")
	PC.faze_shield_level += 1
	PC.faze_treasure_level += 1
	Xuanwu.xuanwu_final_damage_multi += 0.05
	Xuanwu.xuanwu_shield_bonus_damage = 3.0
	_level_up_action()

func reward_Xuanwu3():
	PC.selected_rewards.append("Xuanwu3")
	PC.faze_shield_level += 1
	PC.faze_treasure_level += 1
	Xuanwu.xuanwu_final_damage_multi += 0.15
	Xuanwu.xuanwu_shield_base += 4
	Xuanwu.xuanwu_slow_duration = 5.0
	_level_up_action()

func reward_Xuanwu4():
	PC.selected_rewards.append("Xuanwu4")
	PC.faze_shield_level += 1
	PC.faze_treasure_level += 1
	Xuanwu.xuanwu_width_scale = 1.2
	Xuanwu.xuanwu_vulnerable_duration = 5.0
	_level_up_action()

func reward_Xuanwu11():
	PC.selected_rewards.append("Xuanwu11")
	PC.faze_shield_level += 1
	PC.faze_treasure_level += 1
	Xuanwu.xuanwu_final_damage_multi += 0.1
	Xuanwu.xuanwu_shield_base += 4
	Xuanwu.xuanwu_shield_bonus_damage = 5.0
	_level_up_action()

func reward_Xuanwu22():
	PC.selected_rewards.append("Xuanwu22")
	PC.faze_shield_level += 1
	PC.faze_treasure_level += 1
	Xuanwu.xuanwu_final_damage_multi += 0.15
	Xuanwu.xuanwu_return_shield_bonus = 0.3
	_level_up_action()

func reward_Xuanwu33():
	PC.selected_rewards.append("Xuanwu33")
	PC.faze_shield_level += 1
	PC.faze_treasure_level += 1
	Xuanwu.xuanwu_final_damage_multi += 0.2
	Xuanwu.xuanwu_shield_base += 4
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

func check_Dragonwind_condition() -> bool:
	return PC.selected_rewards.has("Dragonwind")

func check_Dragonwind_condition1() -> bool:
	return PC.selected_rewards.has("DragonWind1") and PC.selected_rewards.has("DragonWind2")

func check_Dragonwind_condition2() -> bool:
	return PC.selected_rewards.has("DragonWind3") and PC.selected_rewards.has("DragonWind4")

func check_Dragonwind_condition3() -> bool:
	return PC.selected_rewards.has("DragonWind2") and PC.selected_rewards.has("DragonWind3")

func reward_Xunfeng():
	Xunfeng.reset_data()
	PC.selected_rewards.append("Xunfeng")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_bagua_level += 2
	PC.faze_wind_level += 2
	_level_up_action()

func reward_RXunfeng():
	PC.main_skill_xunfeng += 1
	PC.pc_speed += 0.024
	PC.pc_atk_speed += 0.024
	Xunfeng.xunfeng_final_damage_multi += 0.06
	_level_up_action()

func reward_SRXunfeng():
	PC.main_skill_xunfeng += 1
	PC.pc_speed += 0.028
	PC.pc_atk_speed += 0.028
	Xunfeng.xunfeng_final_damage_multi += 0.07
	_level_up_action()

func reward_SSRXunfeng():
	PC.main_skill_xunfeng += 1
	PC.pc_speed += 0.032
	PC.pc_atk_speed += 0.032
	Xunfeng.xunfeng_final_damage_multi += 0.08
	_level_up_action()

func reward_URXunfeng():
	PC.main_skill_xunfeng += 1
	PC.pc_speed += 0.04
	PC.pc_atk_speed += 0.04
	Xunfeng.xunfeng_final_damage_multi += 0.1
	_level_up_action()

func reward_Xunfeng1():
	PC.selected_rewards.append("Xunfeng1")
	Xunfeng.xunfeng_final_damage_multi += 0.1
	Xunfeng.xunfeng_size_scale *= 1.35
	Xunfeng.xunfeng_range *= 1.20
	PC.faze_bagua_level += 1
	PC.faze_wind_level += 1
	_level_up_action()

func reward_Xunfeng2():
	PC.selected_rewards.append("Xunfeng2")
	Xunfeng.xunfeng_final_damage_multi += 0.1
	Xunfeng.xunfeng_speed *= 1.20
	Xunfeng.xunfeng_cooldown *= 0.90
	PC.faze_bagua_level += 1
	PC.faze_wind_level += 1
	_level_up_action()

func reward_Xunfeng3():
	PC.selected_rewards.append("Xunfeng3")
	PC.faze_bagua_level += 1
	PC.faze_wind_level += 1
	# logic handled in player_action.gd
	_level_up_action()

func reward_Xunfeng4():
	PC.selected_rewards.append("Xunfeng4")
	Xunfeng.xunfeng_penetration_count = 999
	Xunfeng.xunfeng_pierce_decay = 0.50
	PC.faze_bagua_level += 1
	PC.faze_wind_level += 1
	_level_up_action()

func reward_Xunfeng11():
	PC.selected_rewards.append("Xunfeng11")
	Xunfeng.xunfeng_final_damage_multi += 0.1
	Xunfeng.xunfeng_size_scale *= 1.35
	Xunfeng.xunfeng_pierce_decay = 0.40
	PC.faze_bagua_level += 1
	PC.faze_wind_level += 1
	_level_up_action()

func reward_Xunfeng22():
	PC.selected_rewards.append("Xunfeng22")
	Xunfeng.xunfeng_final_damage_multi += 0.1
	Xunfeng.xunfeng_extra_blade_count_threshold = 2
	PC.faze_bagua_level += 1
	PC.faze_wind_level += 1
	_level_up_action()

func reward_Xunfeng33():
	PC.selected_rewards.append("Xunfeng33")
	PC.faze_bagua_level += 1
	PC.faze_wind_level += 1
	Xunfeng.xunfeng_extra_blade_damage_ratio = 0.9 # 60% * 1.5 = 90%? Or +50% additive? Assuming multiplicative boost to base ratio or additive. Description says "extra wind blade damage +50%". Base is 60%. If it means ratio becomes 60%+50%=110% or 60%*1.5=90%. Let's assume 60%*1.5=90%.
	# logic for left/right handled in player_action.gd
	_level_up_action()

func reward_DragonWind():
	DragonWind.reset_data()
	PC.selected_rewards.append("Dragonwind")
	PC.current_weapon_num += 1
	PC.new_weapon_obtained_count += 1
	PC.faze_treasure_level += 2
	PC.faze_wind_level += 2
	_level_up_action()

func reward_RDragonWind():
	PC.main_skill_dragonwind += 1
	PC.pc_atk_speed += 0.024
	PC.crit_chance += 0.012
	DragonWind.dragonwind_final_damage_multi += 0.06
	_level_up_action()

func reward_SRDragonWind():
	PC.main_skill_dragonwind += 1
	PC.pc_atk_speed += 0.028
	PC.crit_chance += 0.014
	DragonWind.dragonwind_final_damage_multi += 0.07
	_level_up_action()

func reward_SSRDragonWind():
	PC.main_skill_dragonwind += 1
	PC.pc_atk_speed += 0.032
	PC.crit_chance += 0.016
	DragonWind.dragonwind_final_damage_multi += 0.08
	_level_up_action()

func reward_URDragonWind():
	PC.main_skill_dragonwind += 1
	PC.pc_atk_speed += 0.04
	PC.crit_chance += 0.02
	DragonWind.dragonwind_final_damage_multi += 0.1
	_level_up_action()

func reward_DragonWind1():
	PC.selected_rewards.append("DragonWind1")
	DragonWind.dragonwind_final_damage_multi += 0.1
	DragonWind.dragonwind_pull_force *= 1.50
	PC.faze_treasure_level += 1
	PC.faze_wind_level += 1
	_level_up_action()

func reward_DragonWind2():
	PC.selected_rewards.append("DragonWind2")
	DragonWind.dragonwind_final_damage_multi += 0.1
	DragonWind.dragonwind_range_scale *= 1.4
	PC.faze_treasure_level += 1
	PC.faze_wind_level += 1
	_level_up_action()

func reward_DragonWind3():
	PC.selected_rewards.append("DragonWind3")
	DragonWind.dragonwind_final_damage_multi += 0.1
	DragonWind.dragonwind_center_bonus_ratio = 1.0
	PC.faze_treasure_level += 1
	PC.faze_wind_level += 1
	_level_up_action()

func reward_DragonWind4():
	PC.selected_rewards.append("DragonWind4")
	DragonWind.dragonwind_final_damage_multi += 0.15
	DragonWind.dragonwind_slow_duration = 5.0
	PC.faze_treasure_level += 1
	PC.faze_wind_level += 1
	_level_up_action()

func reward_DragonWind11():
	PC.selected_rewards.append("DragonWind11")
	DragonWind.dragonwind_final_damage_multi += 0.1
	DragonWind.dragonwind_pull_force *= 1.20
	DragonWind.dragonwind_range_scale *= 1.3
	PC.faze_treasure_level += 1
	PC.faze_wind_level += 1
	_level_up_action()

func reward_DragonWind22():
	PC.selected_rewards.append("DragonWind22")
	DragonWind.dragonwind_final_damage_multi += 0.1
	DragonWind.dragonwind_slow_damage_bonus = 0.50
	PC.faze_treasure_level += 1
	PC.faze_wind_level += 1
	_level_up_action()

func reward_DragonWind33():
	PC.selected_rewards.append("DragonWind33")
	DragonWind.dragonwind_center_bonus_ratio = 1.50
	DragonWind.dragonwind_boss_bonus_ratio = 1.0
	PC.faze_treasure_level += 1
	PC.faze_wind_level += 1
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
	PC.faze_bagua_level += 2
	PC.faze_shield_level += 2
	_level_up_action()

func reward_RGenshan():
	PC.main_skill_genshan += 1
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.024)
	PC.pc_final_atk += 0.01
	Genshan.genshan_final_damage_multi += 0.20
	_level_up_action()

func reward_SRGenshan():
	PC.main_skill_genshan += 1
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.028)
	PC.pc_final_atk += 0.011
	Genshan.genshan_final_damage_multi += 0.22
	_level_up_action()

func reward_SSRGenshan():
	PC.main_skill_genshan += 1
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.032)
	PC.pc_final_atk += 0.013
	Genshan.genshan_final_damage_multi += 0.24
	_level_up_action()

func reward_URGenshan():
	PC.main_skill_genshan += 1
	PC.pc_max_hp = int(PC.pc_max_hp + PC.pc_start_max_hp * 0.04)
	PC.pc_final_atk += 0.015
	Genshan.genshan_final_damage_multi += 0.28
	_level_up_action()

func reward_Genshan1():
	PC.selected_rewards.append("Genshan1")
	PC.faze_bagua_level += 1
	PC.faze_shield_level += 1
	# Logic handled in genshan.gd: Up/Down direction, total damage -30%
	_level_up_action()

func reward_Genshan2():
	PC.selected_rewards.append("Genshan2")
	Genshan.genshan_final_damage_multi += 0.10
	PC.faze_bagua_level += 1
	PC.faze_shield_level += 1
	# Logic handled in genshan.gd: Vulnerable debuff
	_level_up_action()

func reward_Genshan3():
	PC.selected_rewards.append("Genshan3")
	Genshan.genshan_final_damage_multi += 0.10
	PC.faze_bagua_level += 1
	PC.faze_shield_level += 1
	# Logic handled in genshan.gd: Extra damage to Elite/Boss/<30% HP
	_level_up_action()

func reward_Genshan4():
	PC.selected_rewards.append("Genshan4")
	Genshan.genshan_final_damage_multi += 0.15
	PC.faze_bagua_level += 1
	PC.faze_shield_level += 1
	# Logic handled in genshan.gd: Shield on hit
	_level_up_action()

func reward_Genshan11():
	PC.selected_rewards.append("Genshan11")
	Genshan.genshan_final_damage_multi += 0.15
	PC.faze_bagua_level += 1
	PC.faze_shield_level += 1
	# Logic handled in genshan.gd: Enhanced shield
	_level_up_action()

func reward_Genshan22():
	PC.selected_rewards.append("Genshan22")
	PC.faze_bagua_level += 1
	PC.faze_shield_level += 1
	# Logic handled in genshan.gd: Diagonal directions, total damage -30%
	_level_up_action()

func reward_Genshan33():
	PC.selected_rewards.append("Genshan33")
	Genshan.genshan_final_damage_multi += 0.1
	PC.faze_bagua_level += 1
	PC.faze_shield_level += 1
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
	PC.faze_bagua_level += 2
	PC.faze_wide_level += 2
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
	PC.faze_bagua_level += 1
	PC.faze_wide_level += 1
	Duize.duize_final_damage_multi += 0.15
	Duize.duize_slow_ratio = 0.30
	_level_up_action()

func reward_Duize2():
	PC.selected_rewards.append("Duize2")
	PC.faze_bagua_level += 1
	PC.faze_wide_level += 1
	Duize.duize_final_damage_multi += 0.1
	# Logic handled in duize.gd: Damage per debuff +30%
	_level_up_action()

func reward_Duize3():
	PC.selected_rewards.append("Duize3")
	PC.faze_bagua_level += 1
	PC.faze_wide_level += 1
	Duize.duize_final_damage_multi += 0.15
	Duize.duize_range *= 1.35
	_level_up_action()

func reward_Duize4():
	PC.selected_rewards.append("Duize4")
	PC.faze_bagua_level += 1
	PC.faze_wide_level += 1
	Duize.duize_final_damage_multi += 0.1
	# Logic handled in duize.gd: Apply Corrosion
	_level_up_action()

func reward_Duize11():
	PC.selected_rewards.append("Duize11")
	PC.faze_bagua_level += 1
	PC.faze_wide_level += 1
	Duize.duize_final_damage_multi += 0.1
	Duize.duize_slow_ratio = 0.35
	_level_up_action()

func reward_Duize22():
	PC.selected_rewards.append("Duize22")
	PC.faze_bagua_level += 1
	PC.faze_wide_level += 1
	Duize.duize_final_damage_multi += 0.15
	Duize.duize_range *= 1.35 # Extra +35%
	_level_up_action()

func reward_Duize33():
	PC.selected_rewards.append("Duize33")
	PC.faze_bagua_level += 1
	PC.faze_wide_level += 1
	Duize.duize_final_damage_multi += 0.1
	# Logic handled in duize.gd: Damage per debuff +70%
	_level_up_action()

func check_Holylight_condition() -> bool:
	return PC.selected_rewards.has("Holylight")

func check_Holylight_condition1() -> bool:
	return PC.selected_rewards.has("HolyLight1") and PC.selected_rewards.has("HolyLight2")

func check_Holylight_condition2() -> bool:
	return PC.selected_rewards.has("HolyLight3") and PC.selected_rewards.has("HolyLight4")

func check_Holylight_condition3() -> bool:
	return PC.selected_rewards.has("HolyLight2") and PC.selected_rewards.has("HolyLight4")

func reward_HolyLight():
	HolyLight.reset_data()
	PC.selected_rewards.append("Holylight")
	PC.faze_heal_level += 2
	PC.faze_life_level += 2
	PC.current_weapon_num += 1
	# 初始化冷却时间
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get("holy_light_fire_speed"):
		player.holy_light_fire_speed.start()
	_level_up_action()

func reward_RHolyLight():
	PC.main_skill_holylight += 1
	PC.pc_atk = int(PC.pc_atk * 1.024)
	PC.heal_multi += 0.024
	HolyLight.main_skill_holylight_damage += 0.06
	_level_up_action()

func reward_SRHolyLight():
	PC.main_skill_holylight += 1
	PC.pc_atk = int(PC.pc_atk * 1.028)
	PC.heal_multi += 0.028
	HolyLight.main_skill_holylight_damage += 0.07
	_level_up_action()

func reward_SSRHolyLight():
	PC.main_skill_holylight += 1
	PC.pc_atk = int(PC.pc_atk * 1.032)
	PC.heal_multi += 0.032
	HolyLight.main_skill_holylight_damage += 0.08
	_level_up_action()

func reward_URHolyLight():
	PC.main_skill_holylight += 1
	PC.pc_atk = int(PC.pc_atk * 1.04)
	PC.heal_multi += 0.04
	HolyLight.main_skill_holylight_damage += 0.1
	_level_up_action()

func reward_HolyLight1():
	PC.selected_rewards.append("HolyLight1")
	PC.faze_heal_level += 1
	PC.faze_life_level += 1
	HolyLight.main_skill_holylight_damage += 0.1
	HolyLight.holylight_range_scale *= 1.35
	_level_up_action()

func reward_HolyLight2():
	PC.selected_rewards.append("HolyLight2")
	PC.faze_heal_level += 1
	PC.faze_life_level += 1
	HolyLight.main_skill_holylight_damage += 0.1
	HolyLight.holylight_range_scale *= 1.15
	HolyLight.holylight_center_extra_damage += 1.0
	_level_up_action()

func reward_HolyLight3():
	PC.selected_rewards.append("HolyLight3")
	PC.faze_heal_level += 1
	PC.faze_life_level += 1
	HolyLight.main_skill_holylight_damage += 0.15
	HolyLight.holylight_heal_base = 5
	HolyLight.holylight_heal_ratio = 0.045
	_level_up_action()

func reward_HolyLight4():
	PC.selected_rewards.append("HolyLight4")
	PC.faze_heal_level += 1
	PC.faze_life_level += 1
	HolyLight.main_skill_holylight_damage += 0.1
	HolyLight.holylight_range_scale *= 1.05
	HolyLight.holylight_vulnerable_damage_bonus = 1.0
	_level_up_action()

func reward_HolyLight11():
	PC.selected_rewards.append("HolyLight11")
	PC.faze_heal_level += 1
	PC.faze_life_level += 1
	HolyLight.main_skill_holylight_damage += 0.1
	HolyLight.holylight_range_scale *= 1.25
	HolyLight.holylight_center_extra_damage = 2.0
	_level_up_action()

func reward_HolyLight22():
	PC.selected_rewards.append("HolyLight22")
	PC.faze_heal_level += 1
	PC.faze_life_level += 1
	HolyLight.main_skill_holylight_damage += 0.1
	HolyLight.holylight_heal_ratio = 0.06
	_level_up_action()

func reward_HolyLight33():
	PC.selected_rewards.append("HolyLight33")
	PC.faze_heal_level += 1
	PC.faze_life_level += 1
	HolyLight.main_skill_holylight_damage += 0.1
	HolyLight.holylight_range_scale *= 1.1
	HolyLight.holylight_vulnerable_crit = true
	_level_up_action()


# Qigong Functions

func check_Qigong_condition1() -> bool:
	return PC.selected_rewards.has("Qigong1")

func check_Qigong_condition2() -> bool:
	return PC.selected_rewards.has("Qigong2")

func check_Qigong_condition3() -> bool:
	return PC.selected_rewards.has("Qigong3")

func check_Qigong_condition4() -> bool:
	return PC.selected_rewards.has("Qigong4")

func check_Qigong_condition5() -> bool:
	return PC.selected_rewards.has("Qigong5")

func reward_Qigong():
	PC.selected_rewards.append("Qigong")
	PC.current_weapon_num += 1
	PC.faze_wind_level += 2
	PC.faze_wide_level += 2
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get("Qigong_fire_speed"):
		player.qigong_fire_speed.start()
	_level_up_action()


# 全局升级效果处理函数 (当选择某些特定被动后，升级时会触发额外属性转换)
func global_level_up():
	# 基础属性成长
	PC.pc_atk += 5
	PC.pc_start_atk += 5
	PC.pc_atk = int(PC.pc_atk * 1.1)
	PC.pc_start_atk = int(PC.pc_start_atk * 1.1)
	PC.pc_max_hp += 20
	PC.pc_start_max_hp += 20
	PC.pc_hp += 20 # 升级时也恢复一点HP
	# 每级额外提升2%生命上限
	var lv_hp_bonus = int(PC.pc_start_max_hp * 0.02)
	PC.pc_max_hp += lv_hp_bonus
	PC.pc_start_max_hp += lv_hp_bonus

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

func reward_Six1():
	PC.selected_rewards.append("Six1")
	PC.faze_sixsense_level += 1
	PC.crit_chance += 0.08
	PC.sixsense_base_crit_chance += 0.08
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
	PC.pc_final_atk += 0.06
	PC.sixsense_base_final_damage += 0.06
	_level_up_action()

func reward_Six4():
	PC.selected_rewards.append("Six4")
	PC.faze_sixsense_level += 1
	PC.pc_atk_speed += 0.08
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
	PC.pc_atk += 16
	PC.sixsense_base_atk += 5
	_level_up_action()

func check_have_debuff() -> bool:
	if PC.selected_rewards.has("Bloodwave1"): return true
	if PC.selected_rewards.has("Bloodboardsword"): return true
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
	if PC.selected_rewards.has("Bloodboardsword"): return true
	return false

func reward_R33():
	PC.selected_rewards.append("R33")
	_level_up_action()

func reward_SR33():
	PC.selected_rewards.append("SR33")
	_level_up_action()

func reward_SSR33():
	PC.selected_rewards.append("SSR33")
	_level_up_action()

func reward_UR33():
	PC.selected_rewards.append("UR33")
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

func reward_UR34():
	PC.selected_rewards.append("UR34")
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

func reward_UR35():
	PC.selected_rewards.append("UR35")
	_level_up_action()

func reward_R36():
	PC.selected_rewards.append("R36")
	_level_up_action()

func reward_SR36():
	PC.selected_rewards.append("SR36")
	_level_up_action()

func reward_SSR36():
	PC.selected_rewards.append("SSR36")
	_level_up_action()

func reward_UR36():
	PC.selected_rewards.append("UR36")
	_level_up_action()

func reward_R37():
	PC.selected_rewards.append("R37")
	_level_up_action()

func reward_SR37():
	PC.selected_rewards.append("SR37")
	_level_up_action()

func reward_SSR37():
	PC.selected_rewards.append("SSR37")
	_level_up_action()

func reward_UR37():
	PC.selected_rewards.append("UR37")
	_level_up_action()

func reward_R38():
	PC.selected_rewards.append("R38")
	_level_up_action()

func reward_SR38():
	PC.selected_rewards.append("SR38")
	_level_up_action()

func reward_SSR38():
	PC.selected_rewards.append("SSR38")
	_level_up_action()

func reward_UR38():
	PC.selected_rewards.append("UR38")
	_level_up_action()

func reward_R39():
	PC.selected_rewards.append("R39")
	PC.pc_final_atk += 0.07
	# 敌人数量增加逻辑需在刷怪脚本中处理
	_level_up_action()

func reward_SR39():
	PC.selected_rewards.append("SR39")
	PC.pc_final_atk += 0.08
	_level_up_action()

func reward_SSR39():
	PC.selected_rewards.append("SSR39")
	PC.pc_final_atk += 0.09
	_level_up_action()

func reward_UR39():
	PC.selected_rewards.append("UR39")
	PC.pc_final_atk += 0.11
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

func reward_UR40():
	PC.selected_rewards.append("UR40")
	_level_up_action()

func reward_R41():
	PC.selected_rewards.append("R41")
	PC.exp_multi += 0.20
	_level_up_action()

func reward_SR41():
	PC.selected_rewards.append("SR41")
	PC.exp_multi += 0.22
	_level_up_action()

func reward_SSR41():
	PC.selected_rewards.append("SSR41")
	PC.exp_multi += 0.24
	_level_up_action()

func reward_UR41():
	PC.selected_rewards.append("UR41")
	PC.exp_multi += 0.28
	_level_up_action()

func reward_NoAdvance():
	PC.pc_atk += 20
	PC.pc_start_atk += 20
	PC.pc_atk = int(PC.pc_atk * 1.05)
	PC.pc_start_atk = int(PC.pc_start_atk * 1.05)
	_level_up_action()
