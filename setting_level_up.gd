extends Node
# 定义奖励数据结构
class Reward:
	var prerequisites: Array[String] = []
	var max_acquisitions: int = -1 
	var id: String
	var icon: Rect2
	var text: String
	var rare: String 
	var faction: String
	var weight: float 
	var on_selected: Callable
	
signal player_lv_up_over
signal lucky_level_up


func _get_all_normal_white_rewards() -> Array:
	var all_rewards: Array = []
	var reward_data = [
		{id="N01", icon=Rect2(64, 224, 32, 32), text="[font_size=26]血气 I[/font_size]\n\nHP上限+4%", on_selected=self.reward_N01, max_acquisitions=-1, faction="normal", weight=1.0}, # HP上限提升 -> normal
		{id="N02", icon=Rect2(32, 224, 32, 32), text="[font_size=26]破阵 I[/font_size]\n\n攻击+2.5%\n攻击速度+1%", on_selected=self.reward_N02, max_acquisitions=-1, faction="normal", weight=1.0}, # 攻击提升 -> normal
		{id="N03", icon=Rect2(32, 224, 32, 32), text="[font_size=26]惊鸿 I[/font_size]\n\n攻击速度+4%", on_selected=self.reward_N03, max_acquisitions=-1, faction="normal", weight=1.0}, # 攻击速度提升 -> normal
		{id="N04", icon=Rect2(160, 224, 32, 32), text="[font_size=26]踏风 I[/font_size]\n\n移动速度+4%\n暴击率+0.5%", on_selected=self.reward_N04, max_acquisitions=-1, faction="normal", weight=1.0}, # 移动速度、暴击率提升 -> normal
		{id="N05", icon=Rect2(32, 224, 32, 32), text="[font_size=26]沉静 I[/font_size]\n\n攻击速度+6.5%\n移动速度-2%", on_selected=self.reward_N05, max_acquisitions=-1, faction="normal", weight=0.8}, # 攻速提升，移速降低 -> normal
		{id="N06", icon=Rect2(64, 224, 32, 32), text="[font_size=26]炼体 I[/font_size]\n\nHP上限+6.5%\n移动速度-2%", on_selected=self.reward_N06, max_acquisitions=-1, faction="live", weight=0.8}, # HP上限提升，移速降低 -> normal
		{id="N07", icon=Rect2(160, 224, 32, 32), text="[font_size=26]健步 I[/font_size]\n\n移动速度+6.5%\n攻击-1.2%\n暴击伤害+1%", on_selected=self.reward_N07, max_acquisitions=-1, faction="normal", weight=0.7}, # 移速提升，攻击降低，暴击伤害提升 -> normal
		{id="N08", icon=Rect2(32, 224, 32, 32), text="[font_size=26]蛮力 I[/font_size]\n\n攻击+4%\n攻击速度-1.5%", on_selected=self.reward_N08, max_acquisitions=-1, faction="normal", weight=0.7}, # 攻击提升，攻速降低 -> normal
		{id="N09_CritChance", icon=Rect2(480, 224, 32, 32), text="[font_size=26]精准 I[/font_size]\n\n暴击率+4%%\n攻击速度+1%", on_selected=self.reward_N09_CritChance, max_acquisitions=-1, faction="wild", weight=1.0}, # 暴击率提升 -> normal
		{id="N10_CritDamage", icon=Rect2(480, 224, 32, 32), text="[font_size=26]致命 I][/font_size]\n\n暴击伤害+10%%\n攻击速度+1%", on_selected=self.reward_N10_CritDamage, max_acquisitions=-1, faction="wild", weight=1.0}, # 暴击伤害提升 -> normal
		{id="N11_CritChanceDamage_AtkDown", icon=Rect2(384, 224, 32, 32), text="[font_size=26]优雅 I[/font_size]\n\n暴击率2.5%，暴击伤害+6.25%\n攻击-1.2%", on_selected=self.reward_N11_CritChanceDamage_AtkDown, max_acquisitions=-1, faction="wild", weight=0.6}, # 暴击率、暴击伤害提升，攻击降低 -> normal
		{id="N12_DamageReduction", icon=Rect2(224, 224, 32, 32), text="[font_size=26]铁骨 I[/font_size]\n\n减伤率+2%", on_selected=self.reward_N12_DamageReduction, max_acquisitions=-1, faction="live", weight=1.0}, # 减伤率提升 -> live
		{id="N13", icon=Rect2(448, 256, 32, 32), text="[font_size=26]强运 I[/font_size]\n\n天命+2", on_selected=self.reward_N13, max_acquisitions=-1, faction="lukcy", weight=1.0} # 减伤率提升 -> live
	]

	for r_data in reward_data:
		var reward = Reward.new()
		reward.id = r_data.id
		reward.icon = r_data.icon
		reward.text = r_data.text
		reward.on_selected = r_data.on_selected
		reward.faction = r_data.faction
		reward.weight = r_data.weight
		#reward.rare = r_data.rare
		reward.max_acquisitions = r_data.max_acquisitions
		all_rewards.append(reward)
	return all_rewards

func _level_up_action() :
	global_level_up()
	
	get_tree().set_pause(false)
	Global.is_level_up = false
	Global.emit_signal("level_up_selection_complete")

func _get_all_rewards_by_rarity(rarity_name: String) -> Array:
	match rarity_name:
		"normal_white":
			return _get_all_normal_white_rewards()
		"pro_green":
			return _get_all_pro_green_rewards()
		"rare_blue":
			return _get_all_rare_blue_rewards()
		"super_rare_purple":
			return _get_all_super_rare_purple_rewards()
		"super2_rare_orange":
			return _get_all_super2_rare_orange_rewards()
		"unbelievable_gold":
			return _get_all_unbelievable_gold_rewards()
		_: 
			print_debug("Error: Unknown rarity_name '" + rarity_name + "' in _get_all_rewards_by_rarity")
			return []

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
		return "normal"

	var random_roll = randf() * total_weight
	for wf in weighted_factions:
		if random_roll < wf.cumulative_weight:
			return wf.name
	
	return weighted_factions[-1].name
	
func _select_reward_by_weight(available_rewards: Array) -> Reward:
	if available_rewards.is_empty():
		return null

	var total_reward_weight = 0.0
	var weighted_rewards_list = []
	for reward_item in available_rewards:
		if reward_item.weight > 0:
			total_reward_weight += reward_item.weight
			weighted_rewards_list.append({"reward": reward_item, "cumulative_weight": total_reward_weight})

	if weighted_rewards_list.is_empty():
		return null
		
	var random_roll = randf() * total_reward_weight
	for wr in weighted_rewards_list:
		if random_roll < wr.cumulative_weight:
			if wr.reward.faction != "normal": 
				PlayerRewardWeights.update_faction_weights_on_selection(wr.reward.rare, wr.reward.faction, 1.0)
			return wr.reward
	
	return weighted_rewards_list[-1].reward 
	
func select_reward(rarity_name: String) -> Reward:
	var max_rerolls = 10
	for i in range(max_rerolls):
		var selected_faction = _select_faction_for_rarity(rarity_name)
		print_debug("Selected faction for rarity '" + rarity_name + "': " + selected_faction)

		var all_rewards_for_rarity = _get_all_rewards_by_rarity(rarity_name)
		var faction_specific_rewards: Array = []

		for r in all_rewards_for_rarity:
			if r.faction == selected_faction:
				faction_specific_rewards.append(r)

		var chosen_reward = _select_reward_by_weight(faction_specific_rewards)
	
		if chosen_reward != null and chosen_reward.prerequisites.size() > 0:
			var prerequisites_met = true
			
			for prereq_id in chosen_reward.prerequisites:
				if not PC.selected_rewards.has(prereq_id):
					prerequisites_met = false
					print_debug("Rerolling reward '" + chosen_reward.id + "' due to unmet prerequisite: '" + prereq_id + "'")
					break
		
			if prerequisites_met:
				if chosen_reward.max_acquisitions == -1 or PC.get_reward_acquisition_count(chosen_reward.id) < chosen_reward.max_acquisitions:
					return chosen_reward
				else:
					print_debug("Rerolling reward '" + chosen_reward.id + "' because it has reached its max acquisition limit: " + str(PC.get_reward_acquisition_count(chosen_reward.id)) + "/" + str(chosen_reward.max_acquisitions))
					continue 
		elif chosen_reward == null:
			continue
		else :
			return chosen_reward
	
	print_debug("Max rerolls reached for rarity '" + rarity_name + "'. Returning null or first available.")
	var all_rewards_for_rarity_fallback = _get_all_rewards_by_rarity(rarity_name)
	return all_rewards_for_rarity_fallback[0]

func normal_white() -> Reward:
	return select_reward("normal_white")

	
func _get_all_pro_green_rewards() -> Array:
	var reward_data = [
		{"id": "G01", "icon": Rect2(64, 224, 32, 32), "text": "[font_size=26][color=green]血气 II[/color][/font_size]\n\nHP上限+6%", "on_selected": self.reward_G01, "faction": "normal", "weight": 1.0, "max_acquisitions": -1}, # HP上限提升 -> normal
		{"id": "G02", "icon": Rect2(32, 224, 32, 32), "text": "[font_size=26][color=green]破阵 II[/color][/font_size]\n\n攻击+3.75%\n攻击速度+1%", "on_selected": self.reward_G02, "faction": "normal", "weight": 1.0, "max_acquisitions": -1}, # 攻击提升 -> normal
		{"id": "G03", "icon": Rect2(32, 224, 32, 32), "text": "[font_size=26][color=green]惊鸿 II[/color][/font_size]\n\n攻击速度+6%", "on_selected": self.reward_G03, "faction": "normal", "weight": 1.0, "max_acquisitions": -1}, # 攻击速度提升 -> normal
		{"id": "G04", "icon": Rect2(160, 224, 32, 32), "text": "[font_size=26][color=green]踏风 II[/color][/font_size]\n\n移动速度+6%\n暴击率+0.75%", "on_selected": self.reward_G04, "faction": "normal", "weight": 1.0, "max_acquisitions": -1}, # 移动速度、暴击率提升 -> normal
		{"id": "G05", "icon": Rect2(32, 224, 32, 32), "text": "[font_size=26][color=green]沉静 II[/color][/font_size]\n\n攻击速度+9.5%\n移动速度-3%", "on_selected": self.reward_G05, "faction": "normal", "weight": 1.0, "max_acquisitions": -1}, # 攻速提升，移速降低 -> normal
		{"id": "G06", "icon": Rect2(32, 224, 32, 32), "text": "[font_size=26][color=green]炼体 II[/color][/font_size]\n\nHP上限+9.5%\n移动速度-3%", "on_selected": self.reward_G06, "faction": "normal", "weight": 1.0, "max_acquisitions": -1}, # HP上限提升，移速降低 -> normal
		{"id": "G07", "icon": Rect2(160, 224, 32, 32), "text": "[font_size=26][color=green]健步 II[/color][/font_size]\n\n移动速度+9.5%\n攻击-1.6%\n暴击伤害+1.5%", "on_selected": self.reward_G07, "faction": "normal", "weight": 1.0, "max_acquisitions": -1}, # 移速提升，攻击降低，暴击伤害提升 -> normal
		{"id": "G08", "icon": Rect2(32, 224, 32, 32), "text": "[font_size=26][color=green]蛮力 II[/color][/font_size]\n\n攻击+5.75%\n攻击速度-3%", "on_selected": self.reward_G08, "faction": "normal", "weight": 1.0, "max_acquisitions": -1}, # 攻击提升，攻速降低 -> normal
		{"id": "G09", "icon": Rect2(128, 416, 32, 32), "text": "[font_size=26][color=green]剑意凝势 I[/color][/font_size]\n\n弹体大小+15%\n攻击速度+3%", "on_selected": self.reward_G09, "faction": "bullet", "weight": 1.0, "max_acquisitions": -1, "condition_func_name": "check_bullet_size_condition"}, # 弹体大小提升 -> bullet
		{"id": "G10", "icon": Rect2(96, 288, 32, 32), "text": "[font_size=26][color=green]行云剑意 I[/color][/font_size]\n\n开悟获得的每点5%移速可以提升1%的攻击与HP上限", "on_selected": self.reward_G10, "faction": "normal", "weight": 1.0, "max_acquisitions": -1, "condition_func_name": "check_G10_condition"}, # 移速转换攻击、HP -> normal
		{"id": "G11", "icon": Rect2(352, 256, 32, 32), "text": "[font_size=26][color=green]天命加护 I[/color][/font_size]\n\n开悟获得的每点额外天命可以提升1%的攻击与HP上限", "on_selected": self.reward_G11, "faction": "lukcy", "weight": 1.0, "max_acquisitions": -1, "condition_func_name": "check_G11_condition"}, # 天命转换攻击、HP -> lukcy
		{"id": "G12", "icon": Rect2(96, 288, 32, 32), "text": "[font_size=26][color=green]刃舞归元 I[/color][/font_size]\n\n开悟获得的每点4%攻速可以提升1%的攻击与HP上限", "on_selected": self.reward_G12, "faction": "normal", "weight": 1.0, "max_acquisitions": -1, "condition_func_name": "check_G12_condition"}, # 攻速转换攻击、HP -> normal
		{"id": "G13_CritChance", "icon": Rect2(480, 224, 32, 32), "text": "[font_size=26][color=green]精准 II[/color][/font_size]\n\n暴击率+6%\n攻击速度+1%", "on_selected": self.reward_G13_CritChance, "faction": "normal", "weight": 1.0, "max_acquisitions": -1}, # 暴击率提升 -> normal
		{"id": "G14_CritDamage", "icon": Rect2(480, 224, 32, 32), "text": "[font_size=26][color=green]致命 II[/color][/font_size]\n\n暴击伤害+15%\n攻击速度+1%", "on_selected": self.reward_G14_CritDamage, "faction": "normal", "weight": 1.0, "max_acquisitions": -1}, # 暴击伤害提升 -> normal
		{"id": "G15_CritChanceDamage_AtkDown", "icon": Rect2(384, 224, 32, 32), "text": "[font_size=26][color=green]优雅 II[/color][/font_size]\n\n暴击率+4%，暴击伤害+10%\n攻击-4%", "on_selected": self.reward_G15_CritChanceDamage_AtkDown, "faction": "normal", "weight": 1.0, "max_acquisitions": -1}, # 暴击率、暴击伤害提升，攻击降低 -> normal
		{"id": "G16_DamageReduction", "icon": Rect2(224, 224, 32, 32), "text": "[font_size=26][color=green]铁骨 II[/color][/font_size]\n\n减伤率+3%", "on_selected": self.reward_G16_DamageReduction, "faction": "live", "weight": 1.0, "max_acquisitions": -1}, # 减伤率提升 -> live
		{"id": "G17", "icon": Rect2(448, 256, 32, 32), "text": "[font_size=26][color=green]强运 II[/color][/font_size]\n\n天命+3", "on_selected": self.reward_G17, "max_acquisitions": -1, "faction": "lukcy", "weight": 1.0} 
	]
	var all_rewards = []
	for r_data in reward_data:
		var add_reward = true
		if r_data.has("condition_func_name"):
			var condition_func = Callable(self, r_data.condition_func_name)
			if condition_func.is_valid() and not condition_func.call():
				add_reward = false
		
		if add_reward:
			var reward = Reward.new()
			reward.id = r_data.id
			reward.icon = r_data.icon
			reward.text = r_data.text
			reward.rare = "pro_green"
			reward.faction = r_data.faction
			reward.weight = r_data.weight
			reward.on_selected = r_data.on_selected
			reward.max_acquisitions = r_data.max_acquisitions
			if r_data.has("prerequisites"):
				reward.prerequisites = r_data.prerequisites
			all_rewards.append(reward)
	return all_rewards

func check_G10_condition() -> bool:
	return not PC.selected_rewards.has("spdToAH1")

func check_G11_condition() -> bool:
	return not PC.selected_rewards.has("lukcyToAH1")

func check_G12_condition() -> bool:
	return not PC.selected_rewards.has("aSpdToAH1")


func pro_green() -> Reward:
	return select_reward("pro_green")
	
func _get_all_rare_blue_rewards() -> Array:
	var reward_data = [
		{"id": "R01", "icon": Rect2(64, 224, 32, 32), "text": "[font_size=26][color=deepskyblue]血气 III[/color][/font_size]\n\nHP上限+8%", "on_selected": self.reward_R01, "faction": "normal", "weight": 1.0, "max_acquisitions": -1}, # HP上限提升 -> normal
		{"id": "R02", "icon": Rect2(32, 224, 32, 32), "text": "[font_size=26][color=deepskyblue]破阵 III[/color][/font_size]\n\n攻击+5%\n攻击速度+1.5%", "on_selected": self.reward_R02, "faction": "normal", "weight": 1.0, "max_acquisitions": -1}, # 攻击提升 -> normal
		{"id": "R03", "icon": Rect2(32, 224, 32, 32), "text": "[font_size=26][color=deepskyblue]惊鸿 III[/color][/font_size]\n\n攻击速度+8%", "on_selected": self.reward_R03, "faction": "normal", "weight": 1.0, "max_acquisitions": -1}, # 攻击速度提升 -> normal
		{"id": "R04", "icon": Rect2(160, 224, 32, 32), "text": "[font_size=26][color=deepskyblue]踏风 III[/color][/font_size]\n\n移动速度+8%\n暴击率+1%", "on_selected": self.reward_R04, "faction": "normal", "weight": 1.0, "max_acquisitions": -1}, # 移动速度、暴击率提升 -> normal
		{"id": "R05", "icon": Rect2(32, 224, 32, 32), "text": "[font_size=26][color=deepskyblue]沉静 III[/color][/font_size]\n\n攻击速度+13%\n移动速度-4%", "on_selected": self.reward_R05, "faction": "normal", "weight": 1.0, "max_acquisitions": -1}, # 攻速提升，移速降低 -> normal
		{"id": "R06", "icon": Rect2(64, 224, 32, 32), "text": "[font_size=26][color=deepskyblue]炼体 III[/color][/font_size]\n\nHP上限+13%\n移动速度-4%", "on_selected": self.reward_R06, "faction": "normal", "weight": 1.0, "max_acquisitions": -1}, # HP上限提升，移速降低 -> normal
		{"id": "R07", "icon": Rect2(160, 224, 32, 32), "text": "[font_size=26][color=deepskyblue]健步 III[/color][/font_size]\n\n移动速度+13%\n攻击-2.4%\n暴击伤害+2%", "on_selected": self.reward_R07, "faction": "normal", "weight": 1.0, "max_acquisitions": -1}, # 移速提升，攻击降低，暴击伤害提升 -> normal
		{"id": "R08", "icon": Rect2(32, 224, 32, 32), "text": "[font_size=26][color=deepskyblue]蛮力 III[/color][/font_size]\n\n攻击+5.6%\n攻击速度-2.4%", "on_selected": self.reward_R08, "faction": "normal", "weight": 1.0, "max_acquisitions": -1}, # 攻击提升，攻速降低 -> normal
		{"id": "R09", "icon": Rect2(192, 288, 32, 32), "text": "[font_size=26][color=deepskyblue]回涌[/color][/font_size]\n\n升级时额外恢复25%HP", "on_selected": self.reward_R09, "faction": "live", "weight": 1.0, "max_acquisitions": -1, "condition_func_name": "check_R09_condition"}, # 升级回血 -> live
		{"id": "R10", "icon": Rect2(192, 288, 32, 32), "text": "[font_size=26][color=deepskyblue]及时包扎[/color][/font_size]\n\nHP恢复到上限\nHP上限+5%", "on_selected": self.reward_R10, "faction": "live", "weight": 1.0, "max_acquisitions": -1}, # HP恢复并提升上限 -> live
		{"id": "R11", "icon": Rect2(128, 416, 32, 32), "text": "[font_size=26][color=deepskyblue]剑意凝势 II[/color][/font_size]\n\n弹体大小+25%\n攻击速度+4%", "on_selected": self.reward_R11, "faction": "bullet", "weight": 1.0, "max_acquisitions": -1, "condition_func_name": "check_bullet_size_condition"}, # 子弹大小提升 -> bullet
		{"id": "blue_summon", "icon": Rect2(0, 320, 32, 32), "text": "[font_size=26][color=deepskyblue]剑灵[/color][/font_size]\n\n召唤一个随机方向攻击的剑灵\n伤害：54%攻击力\n发射频率：0.85秒", "on_selected": self.reward_blue_summon, "faction": "summon", "weight": 3.0, "max_acquisitions": -1, "condition_func_name": "check_blue_summon_condition"}, # 召唤剑灵 -> summon
		{"id": "blue_summon_damage_up", "icon": Rect2(32, 320, 32, 32), "text": "[font_size=26][color=deepskyblue]唤物强化 I[/color][/font_size]\n\n召唤物伤害+7.5%\n召唤物子弹大小+5%", "on_selected": self.reward_blue_summon_damage_up, "faction": "summon", "weight": 1.0, "max_acquisitions": -1}, # 召唤物伤害、子弹大小提升 -> summon
		{"id": "blue_summon_size_up", "icon": Rect2(64, 320, 32, 32), "text": "[font_size=26][color=deepskyblue]唤物巨大化 I[/color][/font_size]\n\n召唤物子弹大小+10%\n召唤物伤害+2.5%", "on_selected": self.reward_blue_summon_size_up, "faction": "summon", "weight": 1.0, "max_acquisitions": -1}, # 召唤物子弹大小、伤害提升 -> summon
		{"id": "R16", "icon": Rect2(96, 288, 32, 32), "text": "[font_size=26][color=deepskyblue]行云剑意 II[/color][/font_size]\n\n开悟获得的每点4%移速可以提升1%的攻击与HP上限", "on_selected": self.reward_R16, "faction": "normal", "weight": 1.0, "max_acquisitions": -1, "condition_func_name": "check_R16_condition"}, # 移速转换攻击、HP -> normal
		{"id": "R17", "icon": Rect2(352, 256, 32, 32), "text": "[font_size=26][color=deepskyblue]天命加护 II[/color][/font_size]\n\n开悟获得的每点额外天命可以提升1.25%的攻击与HP上限", "on_selected": self.reward_R17, "faction": "lukcy", "weight": 1.0, "max_acquisitions": -1, "condition_func_name": "check_R17_condition"}, # 天命转换攻击、HP -> lukcy
		{"id": "R18", "icon": Rect2(96, 288, 32, 32), "text": "[font_size=26][color=deepskyblue]刃舞归元 II[/color][/font_size]\n\n开悟获得的每点3%攻速可以提升1%的攻击与HP上限", "on_selected": self.reward_R18, "faction": "normal", "weight": 1.0, "max_acquisitions": -1, "condition_func_name": "check_R18_condition"}, # 攻速转换攻击、HP -> normal
		{"id": "R19_CritChance", "icon": Rect2(480, 224, 32, 32), "text": "[font_size=26][color=deepskyblue]精准 III[/color][/font_size]\n\n暴击率+8%\n攻击速度+1.5%", "on_selected": self.reward_R19_CritChance, "faction": "normal", "weight": 1.0, "max_acquisitions": -1}, # 暴击率提升 -> normal
		{"id": "R20_CritDamage", "icon": Rect2(480, 224, 32, 32), "text": "[font_size=26][color=deepskyblue]致命 III[/color][/font_size]\n\n暴击伤害+20%\n攻击速度+1.5%", "on_selected": self.reward_R20_CritDamage, "faction": "normal", "weight": 1.0, "max_acquisitions": -1}, # 暴击伤害提升 -> normal
		{"id": "R21_CritChanceDamage_AtkDown", "icon": Rect2(384, 224, 32, 32), "text": "[font_size=26][color=deepskyblue]优雅 III[/color][/font_size]\n\n暴击率+5%，暴击伤害+12.5%\n攻击-2.4%", "on_selected": self.reward_R21_CritChanceDamage_AtkDown, "faction": "normal", "weight": 1.0, "max_acquisitions": -1}, # 暴击率、暴击伤害提升，攻击降低 -> normal
		{"id": "R22_DamageReduction", "icon": Rect2(224, 224, 32, 32), "text": "[font_size=26][color=deepskyblue]铁骨 III[/color][/font_size]\n\n减伤率+4%", "on_selected": self.reward_R22_DamageReduction, "faction": "live", "weight": 1.0, "max_acquisitions": -1},
		{"id": "R23", "icon": Rect2(448, 256, 32, 32), "text": "[font_size=26][color=deepskyblue]强运 III[/color][/font_size]\n\n天命+4", "on_selected": self.reward_R23, "max_acquisitions": -1, "faction": "lukcy", "weight": 1.0} ,
		{"id": "R24", "icon": Rect2(320, 320, 32, 32), "text": "[font_size=26][color=deepskyblue]续剑伤害提高[/color][/font_size]\n\n续剑伤害提高15%", "on_selected": self.reward_rebound_atk_up_blue, "faction": "bullet", "weight": 1.0, "max_acquisitions": 1, "condition_func_name": "check_rebound_up_condition"}, # 弹体属性

	]
	var all_rewards = []
	for r_data in reward_data:
		var add_reward = true
		if r_data.has("condition_func_name"):
			var condition_func = Callable(self, r_data.condition_func_name)
			if condition_func.is_valid() and not condition_func.call():
				add_reward = false
		
		if add_reward:
			var reward = Reward.new()
			reward.id = r_data.id
			reward.icon = r_data.icon
			reward.text = r_data.text
			reward.rare = "rare_blue"
			reward.faction = r_data.faction
			reward.weight = r_data.weight
			reward.on_selected = r_data.on_selected
			reward.max_acquisitions = r_data.max_acquisitions
			if r_data.has("prerequisites"):
				reward.prerequisites = r_data.prerequisites
			all_rewards.append(reward)
	return all_rewards

func check_R09_condition() -> bool:
	return PC.selected_rewards.count("rebound_size_up") < 2

func check_blue_summon_condition() -> bool:
	return PC.summon_count < PC.summon_count_max

func check_R16_condition() -> bool:
	return not PC.selected_rewards.has("spdToAH2")

func check_R17_condition() -> bool:
	return not PC.selected_rewards.has("lukcyToAH2")

func check_R18_condition() -> bool:
	return not PC.selected_rewards.has("aSpdToAH2")


func rare_blue() -> Reward:
	return select_reward("rare_blue")
	
func _get_all_super_rare_purple_rewards() -> Array:
	var reward_data = [
		{"id": "SR01", "icon": Rect2(64, 224, 32, 32), "text": "[font_size=26][color=MEDIUM_PURPLE]血气 IX[/color][/font_size]\n\nHP上限+10%", "on_selected": self.reward_SR01, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "SR02", "icon": Rect2(32, 224, 32, 32), "text": "[font_size=26][color=MEDIUM_PURPLE]破阵 IX[/color][/font_size]\n\n攻击+5.5%\n攻击速度+2%", "on_selected": self.reward_SR02, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "SR03", "icon": Rect2(32, 224, 32, 32), "text": "[font_size=26][color=MEDIUM_PURPLE]惊鸿 IX[/color][/font_size]\n\n攻击速度+10%", "on_selected": self.reward_SR03, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "SR04", "icon": Rect2(160, 224, 32, 32), "text": "[font_size=26][color=MEDIUM_PURPLE]踏风 IX[/color][/font_size]\n\n移动速度+10%\n暴击率+1.5%", "on_selected": self.reward_SR04, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "SR05", "icon": Rect2(32, 224, 32, 32), "text": "[font_size=26][color=MEDIUM_PURPLE]沉静 IX[/color][/font_size]\n\n攻击速度+10%\n移动速度-4%", "on_selected": self.reward_SR05, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "SR06", "icon": Rect2(64, 224, 32, 32), "text": "[font_size=26][color=MEDIUM_PURPLE]炼体 IX[/color][/font_size]\n\nHP上限+16%\n移动速度-4%", "on_selected": self.reward_SR06, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "SR07", "icon": Rect2(160, 224, 32, 32), "text": "[font_size=26][color=MEDIUM_PURPLE]健步 IX[/color][/font_size]\n\n移动速度+16%\n攻击-2%\n暴击伤害+3%", "on_selected": self.reward_SR07, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "SR08", "icon": Rect2(32, 224, 32, 32), "text": "[font_size=26][color=MEDIUM_PURPLE]蛮力 IX[/color][/font_size]\n\n攻击+8%\n攻击速度-3%", "on_selected": self.reward_SR08, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "SR09", "icon": Rect2(448, 256, 32, 32), "text": "[font_size=26][color=MEDIUM_PURPLE]天命拉满 I[/color][/font_size]\n\n天命+5\n\n[i][color=#ddd]每点天命可以提升约2%高阶开悟获得概率[/color][/i]", "on_selected": self.reward_SR09, "faction": "lukcy", "weight": 1.0, "max_acquisitions": -1}, # 天命值相关
		{"id": "rebound", "icon": Rect2(320, 320, 32, 32), "text": "[font_size=26][color=MEDIUM_PURPLE]续剑[/color][/font_size]\n\n弹体击中敌人后会继续弹射一次\n\n[i][color=#ddd]弹体大小为原50%，伤害为原30%[/color][/i]", "on_selected": self.reward_rebound, "faction": "bullet", "weight": 1.0, "max_acquisitions": 1, "condition_func_name": "check_rebound_condition"}, # 弹体反弹
		{"id": "rebound_size_up", "icon": Rect2(320, 320, 32, 32), "text": "[font_size=26][color=MEDIUM_PURPLE]续剑大小提高[/color][/font_size]\n\n续剑大小提高10%\n续剑伤害提高6%", "on_selected": self.reward_rebound_size_up, "faction": "bullet", "weight": 1.0, "max_acquisitions": 1, "condition_func_name": "check_rebound_up_condition"}, # 弹体属性
		{"id": "rebound_atk_up", "icon": Rect2(320, 320, 32, 32), "text": "[font_size=26][color=MEDIUM_PURPLE]续剑伤害提高[/color][/font_size]\n\n续剑伤害提高15%\n攻击+4%", "on_selected": self.reward_rebound_atk_up, "faction": "bullet", "weight": 1.0, "max_acquisitions": 1, "condition_func_name": "check_rebound_up_condition"}, # 弹体属性
		{"id": "rebound_num_up", "icon": Rect2(320, 320, 32, 32), "text": "[font_size=26][color=MEDIUM_PURPLE]续剑分裂[/color][/font_size]\n\n续剑的弹体有概率多分裂出一发\n续剑伤害降低20%", "on_selected": self.reward_rebound_num_up, "faction": "bullet", "weight": 1.0, "max_acquisitions": 1, "condition_func_name": "check_rebound_up_condition"}, # 弹体分裂
		{"id": "ring_bullet_count_up_purple", "icon": Rect2(192, 384, 32, 32), "text": "[font_size=26][color=MEDIUM_PURPLE]环形剑气数量提升[/color][/font_size]\n\n环刃数量+2", "on_selected": self.reward_ring_bullet_count_up_purple, "faction": "craft", "weight": 1.0, "max_acquisitions": -1, "condition_func_name": "check_ring_bullet_count_up_purple_condition"}, # 环形伤害
		{"id": "ring_bullet_size_up_purple", "icon": Rect2(192, 384, 32, 32), "text": "[font_size=26][color=MEDIUM_PURPLE]环形剑气大小提升[/color][/font_size]\n\n环刃大小+15%\n环刃伤害+5%", "on_selected": self.reward_ring_bullet_size_up_purple, "faction": "craft", "weight": 1.0, "max_acquisitions": -1, "condition_func_name": "check_ring_bullet_size_up_purple_condition"}, # 环形伤害
		{"id": "SR12", "icon": Rect2(128, 416, 32, 32), "text": "[font_size=26][color=MEDIUM_PURPLE]剑意凝势 III[/color][/font_size]\n\n弹体大小+30%\n攻击速度+5%", "on_selected": self.reward_SR12, "faction": "normal", "weight": 1.0, "max_acquisitions": -1, "condition_func_name": "check_bullet_size_condition"},
		{"id": "purple_summon", "icon": Rect2(0, 320, 32, 32), "text": "[font_size=26][color=MEDIUM_PURPLE]浮灵刃[/color][/font_size]\n\n召唤向角色面向发射剑气的剑灵\n伤害：30%攻击*2\n发射频率：0.8秒", "on_selected": self.reward_purple_summon, "faction": "summon", "weight": 3.0, "max_acquisitions": -1, "condition_func_name": "check_purple_summon_condition"}, # 召唤物
		{"id": "purple_summon_damage_up", "icon": Rect2(64, 320, 32, 32), "text": "[font_size=26][color=MEDIUM_PURPLE]唤物强化 II[/color][/font_size]\n\n召唤物伤害+10%\n召唤物弹体大小+5%", "on_selected": self.reward_purple_summon_damage_up, "faction": "summon", "weight": 1.0, "max_acquisitions": -1}, # 召唤物属性
		{"id": "purple_summon_size_up", "icon": Rect2(64, 320, 32, 32), "text": "[font_size=26][color=MEDIUM_PURPLE]唤物巨大化 II[/color][/font_size]\n\n召唤物弹体大小+15%\n召唤物伤害+5%", "on_selected": self.reward_purple_summon_size_up, "faction": "summon", "weight": 1.0, "max_acquisitions": -1}, # 召唤物属性
		{"id": "SR20", "icon": Rect2(96, 288, 32, 32), "text": "[font_size=26][color=MEDIUM_PURPLE]行云剑意 III[/color][/font_size]\n\n开悟获得的每点3%移速可以提升1%的攻击与HP上限", "on_selected": self.reward_SR20, "faction": "normal", "weight": 1.0, "max_acquisitions": -1, "condition_func_name": "check_SR20_condition"},
		{"id": "SR21", "icon": Rect2(352, 256, 32, 32), "text": "[font_size=26][color=MEDIUM_PURPLE]天命加护 III[/color][/font_size]\n\n开悟获得的每点额外天命可以提升1.5%的攻击与HP上限", "on_selected": self.reward_SR21, "faction": "lukcy", "weight": 1.0, "max_acquisitions": -1, "condition_func_name": "check_SR21_condition"}, # 天命值相关
		{"id": "SR22", "icon": Rect2(96, 288, 32, 32), "text": "[font_size=26][color=MEDIUM_PURPLE]刃舞归元 III[/color][/font_size]\n\n开悟获得的每点2%攻速可以提升1%的攻击与HP上限", "on_selected": self.reward_SR22, "faction": "normal", "weight": 1.0, "max_acquisitions": -1, "condition_func_name": "check_SR22_condition"},
		{"id": "SR23_CritChance", "icon": Rect2(480, 224, 32, 32), "text": "[font_size=26][color=MEDIUM_PURPLE]精准 IX[/color][/font_size]\n\n暴击率+10%\n攻击速度+2%", "on_selected": self.reward_SR23_CritChance, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "SR24_CritDamage", "icon": Rect2(480, 224, 32, 32), "text": "[font_size=26][color=MEDIUM_PURPLE]致命 IX[/color][/font_size]\n\n暴击伤害+25%\n攻击速度+2%", "on_selected": self.reward_SR24_CritDamage, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "SR25_CritChanceDamage_AtkDown", "icon": Rect2(384, 224, 32, 32), "text": "[font_size=26][color=MEDIUM_PURPLE]优雅 IX[/color][/font_size]\n\n暴击率+6.5%，暴击伤害+16%\n攻击-5%", "on_selected": self.reward_SR25_CritChanceDamage_AtkDown, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "SR26_DamageReduction", "icon": Rect2(224, 224, 32, 32), "text": "[font_size=26][color=MEDIUM_PURPLE]铁骨 IV[/color][/font_size]\n\n减伤率+5%", "on_selected": self.reward_SR26_DamageReduction, "faction": "live", "weight": 1.0, "max_acquisitions": -1} # 生存反击
	]
	var all_rewards = []
	for r_data in reward_data:
		var add_reward = true
		if r_data.has("condition_func_name"):
			var condition_func = Callable(self, r_data.condition_func_name)
			if condition_func.is_valid() and not condition_func.call():
				add_reward = false
		
		if add_reward:
			var reward = Reward.new()
			reward.id = r_data.id
			reward.icon = r_data.icon
			reward.text = r_data.text
			reward.rare = "super_rare_purple"
			reward.faction = r_data.faction
			reward.weight = r_data.weight
			reward.on_selected = r_data.on_selected
			if r_data.has("max_acquisitions"):
				reward.max_acquisitions = r_data.max_acquisitions
			else:
				reward.max_acquisitions = -1
			if r_data.has("prerequisites"):
				reward.prerequisites = r_data.prerequisites
			all_rewards.append(reward)
	return all_rewards

func check_rebound_condition() -> bool:
	return not PC.selected_rewards.has("rebound")

func check_rebound_up_condition() -> bool:
	return PC.selected_rewards.has("rebound")

func check_ring_bullet_count_up_purple_condition() -> bool:
	return PC.selected_rewards.has("ring_bullet") and PC.selected_rewards.count("ring_bullet_count_up_purple") < 4

func check_ring_bullet_size_up_purple_condition() -> bool:
	return PC.selected_rewards.has("ring_bullet") and PC.selected_rewards.count("ring_bullet_size_up_purple") < 2

func check_purple_summon_condition() -> bool:
	return PC.summon_count < PC.summon_count_max

func check_SR20_condition() -> bool:
	return not PC.selected_rewards.has("spdToAH3")

func check_SR21_condition() -> bool:
	return not PC.selected_rewards.has("lukcyToAH3")

func check_SR22_condition() -> bool:
	return not PC.selected_rewards.has("aSpdToAH3")


func super_rare_purple() -> Reward:
	return select_reward("super_rare_purple")
	
func _get_all_super2_rare_orange_rewards() -> Array:
	var reward_data = [
		{"id": "SSR01", "icon": Rect2(64, 224, 32, 32), "text": "[font_size=26][color=orange]血气 X[/color][/font_size]\n\nHP上限+13%", "on_selected": self.reward_SSR01, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "SSR02", "icon": Rect2(32, 224, 32, 32), "text": "[font_size=26][color=orange]破阵 X[/color][/font_size]\n\n攻击+7.2%\n攻击速度+2.5%", "on_selected": self.reward_SSR02, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "SSR03", "icon": Rect2(32, 224, 32, 32), "text": "[font_size=26][color=orange]惊鸿 X[/color][/font_size]\n\n攻击速度+13%", "on_selected": self.reward_SSR03, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "SSR04", "icon": Rect2(160, 224, 32, 32), "text": "[font_size=26][color=orange]踏风 X[/color][/font_size]\n\n移动速度+13%\n暴击率+2%", "on_selected": self.reward_SSR04, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "SSR05", "icon": Rect2(32, 224, 32, 32), "text": "[font_size=26][color=orange]沉静 X[/color][/font_size]\n\n攻击速度+20%\n移动速度-5%", "on_selected": self.reward_SSR05, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "SSR06", "icon": Rect2(64, 224, 32, 32), "text": "[font_size=26][color=orange]炼体 X[/color][/font_size]\n\nHP上限+20%\n移动速度-5%", "on_selected": self.reward_SSR06, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "SSR07", "icon": Rect2(160, 224, 32, 32), "text": "[font_size=26][color=orange]健步 X[/color][/font_size]\n\n移动速度+20%\n攻击-2.5%\n暴击伤害+4%", "on_selected": self.reward_SSR07, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "SSR08", "icon": Rect2(32, 224, 32, 32), "text": "[font_size=26][color=orange]蛮力 X[/color][/font_size]\n\n攻击+11%\n攻击速度-3.5%", "on_selected": self.reward_SSR08, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "SSR09", "icon": Rect2(448, 256, 32, 32), "text": "[font_size=26][color=orange]天命拉满 II[/color][/font_size]\n\n天命+6\n\n[i][color=#ddd]每点天命可以提升约2%高阶开悟获得概率[/color][/i]", "on_selected": self.reward_SSR09, "faction": "lukcy", "weight": 1.0, "max_acquisitions": -1}, # 天命值相关
		{"id": "threeway", "icon": Rect2(384, 320, 32, 32), "text": "[font_size=26][color=orange]三向剑气[/color][/font_size]\n\n同时发射三向的弹体\n攻击-25%\n攻击速度-25%\n弹体大小-15%", "on_selected": self.reward_threeway, "faction": "bullet", "weight": 3.0, "max_acquisitions": 1, "condition_func_name": "check_threeway_condition"}, # 弹体分裂
		{"id": "ring_bullet", "icon": Rect2(192, 384, 32, 32), "text": "[font_size=26][color=orange]环刃[/color][/font_size]\n\n开启环刃\n按椭圆形状均匀散布多发剑气\n剑气大小为正常的70%\n伤害：100%攻击\n发射频率：2.5秒", "on_selected": self.reward_ring_bullet, "faction": "craft", "weight": 1.0, "max_acquisitions": 1, "condition_func_name": "check_ring_bullet_condition"}, # 环形伤害
		{"id": "ring_bullet_damage_up", "icon": Rect2(192, 384, 32, 32), "text": "[font_size=26][color=orange]环刃伤害提升[/color][/font_size]\n\n环刃伤害+30%", "on_selected": self.reward_ring_bullet_damage_up, "faction": "craft", "weight": 1.0, "max_acquisitions": -1, "condition_func_name": "check_ring_bullet_damage_up_condition"}, # 环形伤害
		{"id": "SSR12", "icon": Rect2(128, 416, 32, 32), "text": "[font_size=26][color=orange]剑意凝势 IX[/color][/font_size]\n\n弹体大小+35%\n攻击速度+6%", "on_selected": self.reward_SSR12, "faction": "normal", "weight": 1.0, "max_acquisitions": -1, "condition_func_name": "check_bullet_size_condition"},
		{"id": "orange_summon", "icon": Rect2(0, 320, 32, 32), "text": "[font_size=26][color=orange]追魂刃[/color][/font_size]\n\n召唤一个追踪射击的剑灵\n寻找场景中怪物进行攻击\n伤害：60%攻击\n发射频率：0.65秒", "on_selected": self.reward_orange_summon, "faction": "summon", "weight": 3.0, "max_acquisitions": -1, "condition_func_name": "check_orange_summon_condition"}, # 召唤物
		{"id": "orange_summon_damage_up", "icon": Rect2(64, 320, 32, 32), "text": "[font_size=26][color=orange]唤物强化 III[/color][/font_size]\n\n召唤物伤害+15%\n召唤物发射间隔缩短5%", "on_selected": self.reward_orange_summon_damage_up, "faction": "summon", "weight": 1.0, "max_acquisitions": -1}, # 召唤物属性
		{"id": "orange_summon_interval_down", "icon": Rect2(64, 320, 32, 32), "text": "[font_size=26][color=orange]唤物注能 I[/color][/font_size]\n\n召唤物发射间隔缩短12.5%\n召唤物伤害+6%", "on_selected": self.reward_orange_summon_interval_down, "faction": "summon", "weight": 1.0, "max_acquisitions": -1}, # 召唤物属性
		{"id": "SSR17", "icon": Rect2(224, 288, 32, 32), "text": "[font_size=26][color=orange]破血狂攻 I[/color][/font_size]\n\n牺牲当前20%最大HP上限，其中的12%转化为攻击", "on_selected": self.reward_SSR17, "faction": "live", "weight": 1.0, "max_acquisitions": -1}, # 生存反击
		{"id": "orange_summon_max_add", "icon": Rect2(480, 288, 32, 32), "text": "[font_size=26][color=orange]唤物扩充 I[/color][/font_size]\n\n召唤物上限+1", "on_selected": self.reward_orange_summon_max_add, "faction": "summon", "weight": 1.0, "max_acquisitions": -1}, # 召唤物数量
		{"id": "SSR19_CritChance", "icon": Rect2(480, 224, 32, 32), "text": "[font_size=26][color=orange]精准 X[/color][/font_size]\n\n暴击率+13%\n攻击速度+2.5%", "on_selected": self.reward_SSR19_CritChance, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "SSR20_CritDamage", "icon": Rect2(480, 224, 32, 32), "text": "[font_size=26][color=orange]致命 X[/color][/font_size]\n\n暴击伤害+32.5%\n攻击速度+2.5%", "on_selected": self.reward_SSR20_CritDamage, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "SSR21_CritChanceDamage_AtkDown", "icon": Rect2(384, 224, 32, 32), "text": "[font_size=26][color=orange]优雅 X[/color][/font_size]\n\n暴击率+8.5%，暴击伤害+21%\n攻击-6%", "on_selected": self.reward_SSR21_CritChanceDamage_AtkDown, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "SSR22_DamageReduction", "icon": Rect2(224, 224, 32, 32), "text": "[font_size=26][color=orange]铁骨 V[/color][/font_size]\n\n减伤率+6%", "on_selected": self.reward_SSR22_DamageReduction, "faction": "live", "weight": 1.0, "max_acquisitions": -1} ,# 生存反击
		{"id": "SSR23", "icon": Rect2(320, 320, 32, 32), "text": "[font_size=26][color=orange]续剑大小提高[/color][/font_size]\n\n续剑大小提高12%\n续剑伤害提高9%", "on_selected": self.reward_rebound_size_up_orange, "faction": "bullet", "weight": 1.0, "max_acquisitions": 1, "condition_func_name": "check_rebound_up_condition"}, # 弹体属性
		{"id": "SSR24", "icon": Rect2(320, 320, 32, 32), "text": "[font_size=26][color=orange]续剑伤害提高[/color][/font_size]\n\n续剑伤害提高18%\n攻击+5%", "on_selected": self.reward_rebound_atk_up_orange, "faction": "bullet", "weight": 1.0, "max_acquisitions": 1, "condition_func_name": "check_rebound_up_condition"}	
	]
	var all_rewards = []
	for r_data in reward_data:
		var add_reward = true
		if r_data.has("condition_func_name"):
			var condition_func = Callable(self, r_data.condition_func_name)
			if condition_func.is_valid() and not condition_func.call():
				add_reward = false
		
		if add_reward:
			var reward = Reward.new()
			reward.id = r_data.id
			reward.icon = r_data.icon
			reward.text = r_data.text
			reward.rare = "super2_rare_orange"
			reward.faction = r_data.faction
			reward.weight = r_data.weight
			reward.on_selected = r_data.on_selected
			if r_data.has("max_acquisitions"):
				reward.max_acquisitions = r_data.max_acquisitions
			else:
				reward.max_acquisitions = -1 
			if r_data.has("prerequisites"):
				reward.prerequisites = r_data.prerequisites
			all_rewards.append(reward)
	return all_rewards

func check_threeway_condition() -> bool:
	return not PC.selected_rewards.has("threeway")

func check_ring_bullet_condition() -> bool:
	return not PC.selected_rewards.has("ring_bullet")

func check_ring_bullet_damage_up_condition() -> bool:
	return PC.selected_rewards.has("ring_bullet") and PC.selected_rewards.count("ring_bullet_damage_up") < 5

func check_orange_summon_condition() -> bool:
	return PC.summon_count < PC.summon_count_max


func super2_rare_orange() -> Reward:
	return select_reward("super2_rare_orange")
	
func _get_all_unbelievable_gold_rewards() -> Array:
	var reward_data = [
		{"id": "UR01", "icon": Rect2(64, 224, 32, 32), "text": "[font_size=26][color=gold]血气 XI[/color][/font_size]\n\nHP上限+16%", "on_selected": self.reward_UR01, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "UR02", "icon": Rect2(32, 224, 32, 32), "text": "[font_size=26][color=gold]破阵 XI[/color][/font_size]\n\n攻击+9%\n攻击速度+3%", "on_selected": self.reward_UR02, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "UR03", "icon": Rect2(32, 224, 32, 32), "text": "[font_size=26][color=gold]惊鸿 XI[/color][/font_size]\n\n攻击速度+16%", "on_selected": self.reward_UR03, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "UR04", "icon": Rect2(160, 224, 32, 32), "text": "[font_size=26][color=gold]踏风 XI[/color][/font_size]\n\n移动速度+16%\n暴击率+2.5%", "on_selected": self.reward_UR04, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "UR05", "icon": Rect2(32, 224, 32, 32), "text": "[font_size=26][color=gold]沉静 XI[/color][/font_size]\n\n攻击速度+25%\n移动速度-6%", "on_selected": self.reward_UR05, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "UR06", "icon": Rect2(64, 224, 32, 32), "text": "[font_size=26][color=gold]炼体 XI[/color][/font_size]\n\nHP上限+25%\n移动速度-6%", "on_selected": self.reward_UR06, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "UR07", "icon": Rect2(160, 224, 32, 32), "text": "[font_size=26][color=gold]健步 XI[/color][/font_size]\n\n移动速度+25%\n攻击-3%\n暴击伤害+5%", "on_selected": self.reward_UR07, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "UR08", "icon": Rect2(32, 224, 32, 32), "text": "[font_size=26][color=gold]蛮力 XI[/color][/font_size]\n\n攻击+14%\n攻击速度-4.5%", "on_selected": self.reward_UR08, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "UR09", "icon": Rect2(448, 256, 32, 32), "text": "[font_size=26][color=gold]天命拉满 III[/color][/font_size]\n\n天命+7\n\n[i][color=#ddd]每点天命可以提升约2%高阶开悟获得概率[/color][/i]", "on_selected": self.reward_UR09, "faction": "lukcy", "weight": 1.0, "max_acquisitions": -1}, # 天命值相关
		{"id": "fiveway", "icon": Rect2(384, 320, 32, 32), "text": "[font_size=26][color=gold]五向剑气[/color][/font_size]\n\n同时发射五个方向的剑气\n攻击-10%\n攻击速度-15%\n弹体大小-20%\n\n[i][color=#ddd]剑气覆盖，无处可逃[/color][/i]", "on_selected": self.reward_fiveway, "faction": "bullet", "weight": 3.0, "max_acquisitions": 1, "condition_func_name": "check_fiveway_condition"}, # 弹体分裂
		{"id": "ring_bullet_count_up_gold", "icon": Rect2(192, 384, 32, 32), "text": "[font_size=26][color=gold]环刃数量提升[/color][/font_size]\n\n环刃数量+4", "on_selected": self.reward_ring_bullet_count_up_gold, "faction": "craft", "weight": 1.0, "max_acquisitions": 2, "condition_func_name": "check_ring_bullet_count_up_gold_condition"}, # 环形伤害
		{"id": "UR12", "icon": Rect2(128, 416, 32, 32), "text": "[font_size=26][color=gold]剑意凝势 X[/color][/font_size]\n\n弹体大小+40%\n攻击速度+7%", "on_selected": self.reward_UR12, "faction": "normal", "weight": 1.0, "max_acquisitions": -1, "condition_func_name": "check_bullet_size_condition"},
		{"id": "gold_summon", "icon": Rect2(0, 320, 32, 32), "text": "[font_size=26][color=gold]双极魔刃[/color][/font_size]\n\n召唤一个自动索敌的剑灵，一次发射双发子弹\n伤害：36%攻击*2\n发射频率：0.5秒", "on_selected": self.reward_gold_summon, "faction": "summon", "weight": 3.0, "max_acquisitions": -1, "condition_func_name": "check_gold_summon_condition"}, # 召唤物
		{"id": "gold_summon_damage_up", "icon": Rect2(64, 320, 32, 32), "text": "[font_size=26][color=gold]唤物强化 IX[/color][/font_size]\n\n召唤物伤害+15%\n发射间隔缩短7.5%", "on_selected": self.reward_gold_summon_damage_up, "faction": "summon", "weight": 1.0, "max_acquisitions": -1}, # 召唤物属性
		{"id": "gold_summon_interval_down", "icon": Rect2(64, 320, 32, 32), "text": "[font_size=26][color=gold]唤物注能 II[/color][/font_size]\n\n召唤物发射间隔缩短15%\n召唤物伤害+7.5%", "on_selected": self.reward_gold_summon_interval_down, "faction": "summon", "weight": 1.0, "max_acquisitions": -1}, # 召唤物属性
		{"id": "UR16", "icon": Rect2(224, 288, 32, 32), "text": "[font_size=26][color=gold]破血狂攻 II[/color][/font_size]\n\n牺牲当前25%最大HP上限，其中的15%转化为攻击", "on_selected": self.reward_UR17, "faction": "live", "weight": 1.0, "max_acquisitions": -1}, # 生存反击
		{"id": "gold_summon_max_add", "icon": Rect2(480, 288, 32, 32), "text": "[font_size=26][color=gold]唤物扩充 II[/color][/font_size]\n\n召唤物上限+2", "on_selected": self.reward_gold_summon_max_add, "faction": "summon", "weight": 1.0, "max_acquisitions": -1}, # 召唤物数量
		{"id": "UR18_CritChance", "icon": Rect2(480, 224, 32, 32), "text": "[font_size=26][color=gold]精准 XI[/color][/font_size]\n\n暴击率+16%\n攻击速度+3%", "on_selected": self.reward_UR19_CritChance, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "UR19_CritDamage", "icon": Rect2(480, 224, 32, 32), "text": "[font_size=26][color=gold]致命 XI[/color][/font_size]\n\n暴击伤害+40%\n攻击速度+3%", "on_selected": self.reward_UR20_CritDamage, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "UR20_CritChanceDamage_AtkDown", "icon": Rect2(384, 224, 32, 32), "text": "[font_size=26][color=gold]优雅 XI[/color][/font_size]\n\n暴击率+10%，暴击伤害+25%\n攻击-7%", "on_selected": self.reward_UR21_CritChanceDamage_AtkDown, "faction": "normal", "weight": 1.0, "max_acquisitions": -1},
		{"id": "UR21_DamageReduction", "icon": Rect2(224, 224, 32, 32), "text": "[font_size=26][color=gold]铁骨 VI[/color][/font_size]\n\n减伤率+7%", "on_selected": self.reward_UR22_DamageReduction, "faction": "live", "weight": 1.0, "max_acquisitions": -1}, # 生存反击
		{"id": "UR22", "icon": Rect2(320, 320, 32, 32), "text": "[font_size=26][color=gold]续剑伤害提高[/color][/font_size]\n\n续剑伤害提高20%\n攻击+6%", "on_selected": self.reward_rebound_atk_up_gold, "faction": "bullet", "weight": 1.0, "max_acquisitions": 1, "condition_func_name": "check_rebound_up_condition"}	
	]
	var all_rewards = []
	for r_data in reward_data:
		var add_reward = true
		if r_data.has("condition_func_name"):
			var condition_func = Callable(self, r_data.condition_func_name)
			if condition_func.is_valid() and not condition_func.call():
				add_reward = false
		
		if add_reward:
			var reward = Reward.new()
			reward.id = r_data.id
			reward.icon = r_data.icon
			reward.text = r_data.text
			reward.rare = "unbelievable_gold"
			reward.faction = r_data.faction
			reward.weight = r_data.weight
			reward.on_selected = r_data.on_selected
			if r_data.has("max_acquisitions"):
				reward.max_acquisitions = r_data.max_acquisitions
			else:
				reward.max_acquisitions = -1
			if r_data.has("prerequisites"):
				reward.prerequisites = r_data.prerequisites
			all_rewards.append(reward)
	return all_rewards

func check_fiveway_condition() -> bool:
	return PC.selected_rewards.has("threeway") and not PC.selected_rewards.has("fiveway")

func check_ring_bullet_count_up_gold_condition() -> bool:
	return PC.selected_rewards.has("ring_bullet") and PC.selected_rewards.count("ring_bullet_count_up_gold") < 2

func check_gold_summon_condition() -> bool:
	return PC.summon_count < PC.summon_count_max

func check_bullet_size_condition() -> bool:
	return PC.bullet_size <= 2.0


func unbelievable_gold() -> Reward:
	return select_reward("unbelievable_gold")

	
func reward_N01():
	PC.pc_max_hp = int(PC.pc_max_hp * 1.04)
	_level_up_action()
	
func reward_N02():
	PC.pc_atk = int(PC.pc_atk * 1.025)
	PC.pc_atk_speed += 0.01
	_level_up_action()
	
func reward_N03():
	PC.pc_atk_speed += 0.04
	_level_up_action()

func reward_N04(): # 踏风 I
	PC.pc_speed += 0.04
	PC.crit_chance += 0.005 # 暴击率+0.5%
	_level_up_action()


func reward_N05(): # 沉静 I
	PC.pc_atk_speed += 0.065
	PC.pc_speed -= 0.02
	_level_up_action()

func reward_N06(): # 炼体 I
	PC.pc_max_hp = int(PC.pc_max_hp * 1.065)
	PC.pc_speed -= 0.02
	_level_up_action()

func reward_N07(): # 健步 I
	PC.pc_speed += 0.065
	PC.pc_atk = int(PC.pc_atk * 0.988) # 攻击-1.2%
	PC.crit_damage_multiplier += 0.01 # 暴击伤害+1%
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

func reward_N12_DamageReduction():
	PC.damage_reduction_rate = min(PC.damage_reduction_rate + 0.02, 0.7) # 减伤率+2%
	_level_up_action()
	
func reward_N13():
	PC.now_lunky_level += 2
	Global.emit_signal("lucky_level_up", 2)
	_level_up_action()

func reward_G01():
	PC.pc_max_hp = int(PC.pc_max_hp * 1.06)
	_level_up_action()

func reward_G02():
	PC.pc_atk = int(PC.pc_atk * 1.0375)
	PC.pc_atk_speed += 0.01
	_level_up_action()

func reward_G03():
	PC.pc_atk_speed += 0.06
	_level_up_action()

func reward_G04(): # 踏风 II
	PC.pc_speed += 0.06
	PC.crit_chance += 0.0075 # 暴击率+0.75%
	_level_up_action()


func reward_G05(): # 沉静 II
	PC.pc_atk_speed += 0.095
	PC.pc_speed -= 0.03
	_level_up_action()

func reward_G06(): # 炼体 II
	PC.pc_max_hp = int(PC.pc_max_hp * 1.095)
	PC.pc_speed -= 0.03
	_level_up_action()

func reward_G07(): # 健步 II
	PC.pc_speed += 0.095
	PC.pc_atk = int(PC.pc_atk * 0.984) # 攻击-1.6%
	PC.crit_damage_multiplier += 0.015 # 暴击伤害+1.5%
	_level_up_action()


func reward_G08():
	PC.pc_atk = int(PC.pc_atk * 1.0575)
	PC.pc_atk_speed -= 0.03
	_level_up_action()

func reward_G09():
	PC.bullet_size += 0.15
	PC.pc_atk_speed += 0.03
	_level_up_action()

func reward_G10():
	PC.selected_rewards.append("spdToAH1")
	_level_up_action()

func reward_G11():
	PC.selected_rewards.append("lukcyToAH1")
	_level_up_action()

func reward_G12():
	PC.selected_rewards.append("aSpdToAH1")
	_level_up_action()

func reward_G13_CritChance():
	PC.crit_chance += 0.06 # 暴击率+6%
	PC.pc_atk_speed += 0.01
	_level_up_action()

func reward_G14_CritDamage():
	PC.crit_damage_multiplier += 0.15 # 暴击伤害+15%
	PC.pc_atk_speed += 0.01
	_level_up_action()

func reward_G15_CritChanceDamage_AtkDown():
	PC.crit_chance += 0.04 # 暴击率+4%
	PC.crit_damage_multiplier += 0.10 # 暴击伤害+10%
	PC.pc_atk = PC.pc_atk * 0.96 # 攻击-4%
	_level_up_action()

func reward_R22_DamageReduction():
	PC.damage_reduction_rate = min(PC.damage_reduction_rate + 0.04, 0.7) # 减伤率+4%
	_level_up_action()

func reward_R23():
	PC.now_lunky_level += 4
	Global.emit_signal("lucky_level_up", 4)
	_level_up_action()

func reward_G16_DamageReduction():
	PC.damage_reduction_rate = min(PC.damage_reduction_rate + 0.03, 0.7) # 减伤率+3%
	_level_up_action()

func reward_G17():
	PC.now_lunky_level += 3
	Global.emit_signal("lucky_level_up", 3)
	_level_up_action()


func reward_R01():
	PC.pc_max_hp = int(PC.pc_max_hp * 1.08)
	_level_up_action()

func reward_R02():
	PC.pc_atk = int(PC.pc_atk * 1.05)
	PC.pc_atk_speed += 0.015
	_level_up_action()

func reward_R03():
	PC.pc_atk_speed += 0.08
	_level_up_action()

func reward_R04(): # 踏风 III
	PC.pc_speed += 0.064
	PC.crit_chance += 0.01 # 暴击率+1%
	_level_up_action()



func reward_R05(): # 沉静 III
	PC.pc_atk_speed += 0.13
	PC.pc_speed -= 0.04
	_level_up_action()

func reward_R06(): # 炼体 III
	PC.pc_max_hp = int(PC.pc_max_hp * 1.13)
	PC.pc_speed -= 0.04
	_level_up_action()

func reward_R07(): # 健步 III
	PC.pc_speed += 0.13
	PC.pc_atk = int(PC.pc_atk * 0.976) # 攻击-2.4%
	PC.crit_damage_multiplier += 0.02 # 暴击伤害+2%
	_level_up_action()


func reward_R08():
	PC.pc_atk = int(PC.pc_atk * 1.056)
	PC.pc_atk_speed -= 0.024
	_level_up_action()

func reward_R09():
	PC.selected_rewards.append("hpRecover")
	PC.pc_hp = PC.pc_max_hp
	_level_up_action()

func reward_R10():
	PC.pc_max_hp = int(PC.pc_max_hp * 1.05)
	PC.pc_hp = PC.pc_max_hp
	_level_up_action()

func reward_R11():
	PC.bullet_size += 0.25
	PC.pc_atk_speed += 0.04
	_level_up_action()
	
func reward_R16():
	PC.selected_rewards.append("spdToAH2")
	_level_up_action()

func reward_R17():
	PC.selected_rewards.append("lukcyToAH2")
	_level_up_action()

func reward_R18():
	PC.selected_rewards.append("aSpdToAH2")
	_level_up_action()

func reward_R19_CritChance():
	PC.crit_chance += 0.08 # 暴击率+8%
	PC.pc_atk_speed += 0.015
	_level_up_action()

func reward_R20_CritDamage():
	PC.crit_damage_multiplier += 0.20 # 暴击伤害+20%
	PC.pc_atk_speed += 0.015
	_level_up_action()

func reward_R21_CritChanceDamage_AtkDown():
	PC.crit_chance += 0.05 # 暴击率+5%
	PC.crit_damage_multiplier += 0.125 # 暴击伤害+12.5%
	PC.pc_atk = int(PC.pc_atk * 0.976) # 攻击-2.4%
	_level_up_action()


func reward_SR01():
	PC.pc_max_hp = int(PC.pc_max_hp * 1.10)
	_level_up_action()

func reward_SR02():
	PC.pc_atk = int(PC.pc_atk * 1.055)
	PC.pc_atk_speed += 0.02
	_level_up_action()

func reward_SR03():
	PC.pc_atk_speed += 0.10
	_level_up_action()

func reward_SR04(): # 踏风 IX
	PC.pc_speed += 0.10
	PC.crit_chance += 0.015 # 暴击率+1.5%
	_level_up_action()



func reward_SR05(): # 沉静 IX
	PC.pc_atk_speed += 0.10
	PC.pc_speed -= 0.04
	_level_up_action()

func reward_SR06(): # 炼体 IX
	PC.pc_max_hp = int(PC.pc_max_hp * 1.16)
	PC.pc_speed -= 0.04
	_level_up_action()

func reward_SR07(): # 健步 IX
	PC.pc_speed += 0.16
	PC.pc_atk = int(PC.pc_atk * 0.98) # 攻击-2%
	PC.crit_damage_multiplier += 0.03 # 暴击伤害+3%
	_level_up_action()



func reward_SR08():
	PC.pc_atk = int(PC.pc_atk * 1.08)
	PC.pc_atk_speed -= 0.03
	_level_up_action()

func reward_SR09():
	PC.now_lunky_level += 5
	Global.emit_signal("lucky_level_up", 5)
	_level_up_action()

func reward_SR20():
	PC.selected_rewards.append("spdToAH3")
	_level_up_action()

func reward_SR21():
	PC.selected_rewards.append("lukcyToAH3")
	_level_up_action()

func reward_SR23_CritChance():
	PC.crit_chance += 0.10
	PC.pc_atk_speed += 0.02
	_level_up_action()

func reward_SR24_CritDamage():
	PC.crit_damage_multiplier += 0.25
	PC.pc_atk_speed += 0.02
	_level_up_action()

func reward_SR25_CritChanceDamage_AtkDown():
	PC.crit_chance += 0.06
	PC.crit_damage_multiplier += 0.15
	PC.pc_atk = int(PC.pc_atk * 0.976) # 攻击-2.4%
	_level_up_action()

func reward_SR26_DamageReduction():
	PC.damage_reduction_rate = min(PC.damage_reduction_rate + 0.05, 0.7) # 减伤率+5%
	_level_up_action()

func reward_SR22():
	PC.selected_rewards.append("aSpdToAH3")
	_level_up_action()

func reward_rebound():
	PC.selected_rewards.append("rebound")
	Global.emit_signal("buff_added", "rebound", -1, 1)
	_level_up_action()

func reward_rebound_size_up():
	PC.rebound_size_multiplier *= 1.1  # 反弹子弹大小提升15%
	PC.rebound_damage_multiplier = PC.rebound_damage_multiplier * 1.06
	_level_up_action()

func reward_rebound_size_up_orange():
	PC.rebound_size_multiplier *= 1.12  # 反弹子弹大小提升15%
	PC.rebound_damage_multiplier = PC.rebound_damage_multiplier * 1.09
	_level_up_action()
	
func reward_rebound_atk_up_blue():
	PC.rebound_damage_multiplier = PC.rebound_damage_multiplier * 1.15
	_level_up_action()

func reward_rebound_atk_up_orange():
	PC.rebound_damage_multiplier = PC.rebound_damage_multiplier * 1.18
	PC.pc_atk = int(PC.pc_atk * 1.05)
	_level_up_action()

func reward_rebound_atk_up_gold():
	PC.rebound_damage_multiplier = PC.rebound_damage_multiplier * 1.2
	PC.pc_atk = int(PC.pc_atk * 1.06)
	_level_up_action()

func reward_rebound_atk_up():
	PC.rebound_damage_multiplier = PC.rebound_damage_multiplier * 1.15
	PC.pc_atk = int(PC.pc_atk * 1.04)
	_level_up_action()

func reward_rebound_num_up():
	PC.selected_rewards.append("rebound_num_up")
	PC.rebound_damage_multiplier = PC.rebound_damage_multiplier * 0.8
	_level_up_action()

func reward_SR12():
	PC.bullet_size += 0.2
	PC.pc_atk_speed += 0.05
	_level_up_action()

	
func reward_SSR01():
	PC.pc_max_hp = int(PC.pc_max_hp * 1.13)
	PC.pc_hp = PC.pc_max_hp
	_level_up_action()

func reward_SSR02():
	PC.pc_atk = int(PC.pc_atk * 1.072)
	PC.pc_atk_speed += 0.025
	_level_up_action()

func reward_SSR03():
	PC.pc_atk_speed += 0.13
	_level_up_action()

func reward_SSR04(): # 踏风 X
	PC.pc_speed += 0.13 # 移动速度+13%
	PC.crit_chance += 0.02 # 暴击率+2%
	_level_up_action()



func reward_SSR05(): # 沉静 X
	PC.pc_atk_speed += 0.20
	PC.pc_speed -= 0.05
	_level_up_action()

func reward_SSR06(): # 炼体 X
	PC.pc_max_hp = int(PC.pc_max_hp * 1.20)
	PC.pc_hp = PC.pc_max_hp
	PC.pc_speed -= 0.05
	_level_up_action()

func reward_SSR07(): # 健步 X
	PC.pc_speed += 0.20
	PC.pc_atk = int(PC.pc_atk * 0.975) # 攻击-2.5%
	PC.crit_damage_multiplier += 0.04 # 暴击伤害+4%
	_level_up_action()



func reward_SSR08():
	PC.pc_atk = int(PC.pc_atk * 1.11)
	PC.pc_atk_speed -= 0.035
	_level_up_action()

func reward_SSR09():
	PC.now_lunky_level += 6
	Global.emit_signal("lucky_level_up", 6)
	_level_up_action()

func reward_threeway():
	PC.selected_rewards.append("threeway")
	Global.emit_signal("buff_added", "three_way", -1, 1)
	PC.pc_atk = int(PC.pc_atk * 0.75)
	PC.pc_atk_speed -= 0.25
	global_level_up()
	PC.bullet_size -= 0.15
	_level_up_action()

func reward_SSR12():
	PC.bullet_size += 0.35
	PC.pc_atk_speed += 0.06
	_level_up_action()

func reward_SSR17():
	var minusHP = int(PC.pc_max_hp * 0.2)
	PC.pc_max_hp -= minusHP
	PC.pc_atk += int(minusHP * 0.12)
	_level_up_action()

func reward_SSR19_CritChance():
	PC.crit_chance += 0.13
	PC.pc_atk_speed += 0.025
	_level_up_action()

func reward_SSR20_CritDamage():
	PC.crit_damage_multiplier += 0.325
	PC.pc_atk_speed += 0.025
	_level_up_action()

func reward_SSR21_CritChanceDamage_AtkDown():
	PC.crit_chance += 0.085
	PC.crit_damage_multiplier += 0.21
	PC.pc_atk = int(PC.pc_atk * 0.94) # 攻击-6%
	_level_up_action()

func reward_SSR22_DamageReduction():
	PC.damage_reduction_rate = min(PC.damage_reduction_rate + 0.06, 0.7) # 减伤率+6%
	_level_up_action()


func reward_UR01():
	PC.pc_max_hp = int(PC.pc_max_hp * 1.15)
	PC.pc_hp = PC.pc_max_hp
	_level_up_action()

func reward_UR02():
	PC.pc_atk = int(PC.pc_atk * 1.10)
	PC.pc_atk_speed += 0.03
	_level_up_action()

func reward_UR03():
	PC.pc_atk_speed += 0.15
	_level_up_action()

func reward_UR04(): # 踏风 XI
	PC.pc_speed += 0.15
	PC.crit_chance += 0.025 # 暴击率+2.5%
	_level_up_action()

func reward_UR05(): # 沉静 XI
	PC.pc_atk_speed += 0.15
	PC.pc_speed -= 0.06
	_level_up_action()

func reward_UR06(): # 炼体 XI
	PC.pc_max_hp = int(PC.pc_max_hp * 1.25)
	PC.pc_hp = PC.pc_max_hp
	PC.pc_speed -= 0.06
	_level_up_action()

func reward_UR07(): # 健步 XI
	PC.pc_speed += 0.25
	PC.pc_atk = int(PC.pc_atk * 0.96) # 攻击-4%
	PC.crit_damage_multiplier += 0.05 # 暴击伤害+5%
	_level_up_action()

func reward_UR08():
	PC.pc_atk = int(PC.pc_atk * 1.15)
	PC.pc_atk_speed -= 0.045
	_level_up_action()

func reward_UR09():
	PC.now_lunky_level += 7
	Global.emit_signal("lucky_level_up", 7)
	_level_up_action()

func reward_UR12():
	PC.bullet_size += 0.3
	PC.pc_atk_speed += 0.07
	_level_up_action()

func reward_UR17():
	var minusHP = int(PC.pc_max_hp * 0.25)
	PC.pc_max_hp -= minusHP
	PC.pc_atk += int(minusHP * 0.15)
	_level_up_action()

func reward_fiveway():
	PC.selected_rewards.append("fiveway")
	Global.emit_signal("buff_removed", "three_way")
	Global.emit_signal("buff_added", "five_way", -1, 1)
	PC.pc_atk = int(PC.pc_atk * 0.9)
	PC.pc_atk_speed -= 0.15
	PC.bullet_size -= 0.2
	_level_up_action()

func reward_UR22_DamageReduction():
	PC.damage_reduction_rate = min(PC.damage_reduction_rate + 0.06, 0.7) # 减伤率+6%
	_level_up_action()

# 环形子弹相关奖励函数
func reward_ring_bullet():
	PC.selected_rewards.append("ring_bullet")
	_level_up_action()

func reward_ring_bullet_damage_up():
	PC.selected_rewards.append("ring_bullet_damage_up")
	PC.ring_bullet_damage_multiplier *= 1.3
	_level_up_action()

func reward_ring_bullet_count_up_purple():
	PC.selected_rewards.append("ring_bullet_count_up_purple")
	PC.ring_bullet_count += 2
	_level_up_action()

func reward_ring_bullet_size_up_purple():
	PC.selected_rewards.append("ring_bullet_size_up_purple")
	PC.ring_bullet_size_multiplier *= 1.15
	PC.ring_bullet_damage_multiplier += 0.05
	_level_up_action()

func reward_ring_bullet_count_up_gold():
	PC.selected_rewards.append("ring_bullet_count_up_gold")
	PC.ring_bullet_count += 4
	_level_up_action()

func reward_ring_bullet_interval_down():
	PC.selected_rewards.append("ring_bullet_interval_down")
	PC.ring_bullet_interval *= 0.75
	_level_up_action()

# 蓝色召唤物相关奖励函数
func reward_blue_summon():
	PC.summon_count += 1
	PC.selected_rewards.append("blue_summon")
	# 通知battle场景添加召唤物
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(0)
	_level_up_action()

func reward_blue_summon_damage_up():
	PC.summon_damage_multiplier += 0.075
	PC.summon_bullet_size_multiplier += 0.05
	# 更新召唤物属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()

func reward_blue_summon_size_up():
	PC.summon_bullet_size_multiplier += 0.1
	PC.summon_damage_multiplier += 0.025
	# 更新召唤物属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()

# 紫色召唤物相关奖励函数
func reward_purple_summon():
	PC.summon_count += 1
	PC.selected_rewards.append("purple_summon")
	PC.new_summon = "purple"
	# 通知battle场景添加召唤物
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(1)
	_level_up_action()

func reward_purple_summon_damage_up():
	PC.summon_damage_multiplier += 0.1
	PC.summon_bullet_size_multiplier += 0.075
	_level_up_action()

func reward_purple_summon_size_up():
	PC.summon_bullet_size_multiplier += 0.15
	PC.summon_damage_multiplier += 0.05
	# # 更新召唤物属性
	# var battle_scene = get_tree().get_first_node_in_group("player")
	# if battle_scene and battle_scene.has_method("update_summons_properties"):
	# 	battle_scene.update_summons_properties()
	_level_up_action()

# 橙色召唤物相关奖励函数
func reward_orange_summon():
	PC.summon_count += 1
	PC.selected_rewards.append("orange_summon")
	PC.new_summon = "orange"
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(2)
	_level_up_action()

func reward_orange_summon_damage_up():
	PC.summon_damage_multiplier += 0.15
	PC.summon_interval_multiplier *= 0.95
	# 更新召唤物属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()

func reward_orange_summon_interval_down():
	PC.summon_damage_multiplier += 0.06
	PC.summon_interval_multiplier *= 0.875
	# 更新召唤物属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()

# 金色召唤物相关奖励函数
func reward_gold_summon():
	PC.summon_count += 1
	PC.selected_rewards.append("gold_summon")
	PC.new_summon = "gold"
	# 通知battle场景添加召唤物
	var battle_scene = PC.player_instance
	if battle_scene and battle_scene.has_method("add_summon"):
		battle_scene.add_summon(3)
	_level_up_action()

func reward_gold_summon_damage_up():
	PC.summon_damage_multiplier += 0.15
	PC.summon_interval_multiplier *= 0.925
	# 更新召唤物属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()

func reward_gold_summon_interval_down():
	PC.summon_damage_multiplier += 0.075
	PC.summon_interval_multiplier *= 0.85
	# 更新召唤物属性
	var battle_scene = get_tree().get_first_node_in_group("player")
	if battle_scene and battle_scene.has_method("update_summons_properties"):
		battle_scene.update_summons_properties()
	_level_up_action()

func reward_orange_summon_max_add():
	PC.summon_count_max += 1
	_level_up_action()
	
func reward_gold_summon_max_add():
	PC.summon_count_max += 2
	_level_up_action()

func reward_UR19_CritChance():
	PC.crit_chance += 0.15
	PC.pc_atk_speed += 0.03
	_level_up_action()

func reward_UR20_CritDamage():
	PC.crit_damage_multiplier += 0.35 
	PC.pc_atk_speed += 0.03
	_level_up_action()

func reward_UR21_CritChanceDamage_AtkDown():
	PC.crit_chance += 0.08 
	PC.crit_damage_multiplier += 0.21 
	PC.pc_atk = int(PC.pc_atk * 0.97)
	_level_up_action()

func global_level_up():
	PC.pc_atk = int((PC.pc_atk+1) * 1.025)
	PC.pc_max_hp = int((PC.pc_max_hp+2) * 1.01)
	if PC.selected_rewards.has("aSpdToAH1") and PC.last_atk_speed != PC.pc_atk_speed:
		var changeNum = PC.pc_atk_speed - PC.last_atk_speed
		PC.pc_atk = int(PC.pc_atk * (1 + (changeNum / 4)))
		PC.pc_max_hp = int(PC.pc_max_hp * (1 + (changeNum / 4)))

	if PC.selected_rewards.has("lukcyToAH1") and PC.last_lunky_level != PC.now_lunky_level:
		var changeNum = PC.now_lunky_level - PC.last_lunky_level
		PC.pc_atk = int(PC.pc_atk * (1 + (changeNum / 100)))
		PC.pc_max_hp = int(PC.pc_max_hp * (1 + (changeNum / 100)))

	if PC.selected_rewards.has("spdToAH1") and PC.last_speed != PC.pc_speed:
		var changeNum = PC.pc_speed - PC.last_speed
		PC.pc_atk = int(PC.pc_atk * (1 + (changeNum / 5)))
		PC.pc_max_hp = int(PC.pc_max_hp * (1 + (changeNum / 5)))

	if PC.selected_rewards.has("aSpdToAH2") and PC.last_atk_speed != PC.pc_atk_speed:
		var changeNum = PC.pc_atk_speed - PC.last_atk_speed
		PC.pc_atk = int(PC.pc_atk * (1 + (changeNum / 3)))
		PC.pc_max_hp = int(PC.pc_max_hp * (1 + (changeNum / 3)))

	if PC.selected_rewards.has("lukcyToAH2") and PC.last_lunky_level != PC.now_lunky_level:
		var changeNum = PC.now_lunky_level - PC.last_lunky_level
		PC.pc_atk = int(PC.pc_atk * (1 + 0.0125 * changeNum))
		PC.pc_max_hp = int(PC.pc_max_hp * (1 + 0.0125 * changeNum))

	if PC.selected_rewards.has("spdToAH2") and PC.last_speed != PC.pc_speed:
		var changeNum = PC.pc_speed - PC.last_speed
		PC.pc_atk = int(PC.pc_atk * (1 + (changeNum / 4)))
		PC.pc_max_hp = int(PC.pc_max_hp * (1 + (changeNum / 4)))

	if PC.selected_rewards.has("aSpdToAH3") and PC.last_atk_speed != PC.pc_atk_speed:
		var changeNum = PC.pc_atk_speed - PC.last_atk_speed
		PC.pc_atk = int(PC.pc_atk * (1 + (changeNum / 2)))
		PC.pc_max_hp = int(PC.pc_max_hp * (1 + (changeNum / 2)))

	if PC.selected_rewards.has("lukcyToAH3") and PC.last_lunky_level != PC.now_lunky_level:
		var changeNum = PC.now_lunky_level - PC.last_lunky_level
		PC.pc_atk = int(PC.pc_atk * (1 + 0.015 * changeNum))
		PC.pc_max_hp = int(PC.pc_max_hp * (1 + 0.015 * changeNum))

	if PC.selected_rewards.has("spdToAH3") and PC.last_speed != PC.pc_speed:
		var changeNum = PC.pc_speed - PC.last_speed
		PC.pc_atk = int(PC.pc_atk * (1 + (changeNum / 3)))
		PC.pc_max_hp = int(PC.pc_max_hp * (1 + (changeNum / 3)))

	PC.last_lunky_level = PC.now_lunky_level
	PC.last_speed = PC.pc_speed
	PC.last_atk_speed = PC.pc_atk_speed
	var recoverUp = PC.selected_rewards.count("hpRecover")
	var recoverNum = (0.4 + recoverUp * 0.2) * PC.pc_max_hp
	if PC.pc_hp + recoverNum > PC.pc_max_hp:
		PC.pc_hp = PC.pc_max_hp
	else:
		PC.pc_hp += int(recoverNum)
