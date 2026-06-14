extends Node

# 用于存储不同稀有度下C类派系的动态权重
# 结构: { "rarity_name": { "faction_name": weight_value, ... }, ... }
var rarity_faction_weights: Dictionary = {}

# Summon派系每升一级权重衰减控制：选择过Summon后停止衰减
var summon_decay_frozen: bool = false

# 定义游戏中存在的稀有度等级
const RARITY_LEVELS: Array[String] = ["normal_white", "pro_green", "rare_blue", "super_rare_darkorchid", "super2_rare_orange", "unbelievable_gold"]

# 所有武器派系（权重A：新武器 / 权重B：武器升级），平分权重
const WEAPON_FACTIONS: Array[String] = [
	"Branch", "Moyan", "Riyan", "Ringfire", "Thunderbreak", "Swordqi",
	"Thunder", "Bloodwave", "Bloodboardsword", "Lightbullet", "Water",
	"Qiankun", "Xuanwu", "Xunfeng", "Genshan", "Duize", "Qigong",
	"Holylight", "Ice", "Dragonwind"
]

# C类派系（权重C：其他升级），on_faction_selected 对这些派系生效
const C_FACTIONS: Array[String] = ["Normal", "Live", "Debuff", "Summon", "Lucky", "Six"]

# C类各派系的基础权重（直接用于 get_level_up_weights 归一化）
const C_BASE_WEIGHTS: Dictionary = {
	"Normal": 65.0,
	"Live": 30.0,
	"Debuff": 15.0,
	"Summon": 20.0,
	"Lucky": 20.0,
	"Six": 30.0
}

# 需要修习树解锁的武器派系 → 对应的 Global 解锁变量名
const STUDY_UNLOCK_MAP: Dictionary = {
	"Qiankun": "study_unlock_qiankun",
	"Dragonwind": "study_unlock_dragonwind",
	"Bloodwave": "study_unlock_bloodwave",
	"Water": "study_unlock_water",
	"Moyan": "study_unlock_baoyan",
	"Genshan": "study_unlock_genshan",
	"Thunderbreak": "study_unlock_thunder_break",
	"Holylight": "study_unlock_holylight",
	"Xuanwu": "study_unlock_xuanwu",
}

const HERO_UNLOCK_MAP: Dictionary = {
	"Lightbullet": "unlock_noam",
	"Ice": "unlock_kansel",
}

func _init():
	print("PlayerRewardWeights initialized.")
	reset_all_weights()

# 检查某武器派系是否已通过修习树解锁（不在映射表中的武器默认已解锁）
func is_faction_study_unlocked(faction: String) -> bool:
	if HERO_UNLOCK_MAP.has(faction):
		return Global.get(HERO_UNLOCK_MAP[faction]) == true
	if not STUDY_UNLOCK_MAP.has(faction):
		return true
	return Global.get(STUDY_UNLOCK_MAP[faction]) == true

# 返回当前修习树已解锁的武器派系列表（未解锁的武器不参与权重计算）
func get_available_weapon_factions() -> Array[String]:
	var available: Array[String] = []
	for faction in WEAPON_FACTIONS:
		if is_faction_study_unlocked(faction):
			available.append(faction)
	return available

# 重置所有稀有度的C类派系权重到基础值
func reset_all_weights():
	rarity_faction_weights.clear()
	for rarity in RARITY_LEVELS:
		rarity_faction_weights[rarity] = C_BASE_WEIGHTS.duplicate(true)
	summon_decay_frozen = false

# 获取特定稀有度下特定C类派系的权重
func get_faction_weight(rarity: String, faction: String) -> float:
	var weight: float = 0.0
	if rarity_faction_weights.has(rarity) and rarity_faction_weights[rarity].has(faction):
		weight = rarity_faction_weights[rarity][faction]
	elif C_BASE_WEIGHTS.has(faction):
		weight = C_BASE_WEIGHTS[faction]
	# 修习树领悟篇：六识系出现概率提升（提升权重百分比）
	if faction == "Six" and Global.study_six_chance_bonus > 0.0:
		weight *= (1.0 + Global.study_six_chance_bonus)
	return weight

# 更新特定稀有度下特定C类派系的权重
func set_faction_weight(rarity: String, faction: String, new_weight: float):
	if rarity_faction_weights.has(rarity) and rarity_faction_weights[rarity].has(faction):
		rarity_faction_weights[rarity][faction] = new_weight

# 玩家选择派系时调用：仅对C类非Normal派系生效
# 选中派系权重 *1.2 + 1（上限：相比基础值最多提高3）
func on_faction_selected(selected_faction: String):
	if not C_BASE_WEIGHTS.has(selected_faction):
		return
	# 选择了Summon派系奖励后停止权重衰减
	if selected_faction == "Summon":
		summon_decay_frozen = true
	for rarity in RARITY_LEVELS:
		if not rarity_faction_weights.has(rarity):
			continue
		var weights: Dictionary = rarity_faction_weights[rarity]
		if not weights.has(selected_faction):
			continue
		if selected_faction == "Normal":
			continue
		var base_weight: float = C_BASE_WEIGHTS.get(selected_faction, 1.0)
		var new_weight: float = weights[selected_faction] * 1.2 + 1
		weights[selected_faction] = min(new_weight, base_weight + 3)

# 每次升级后调用：Summon派系权重-1，减到0为止；如果已选择过Summon则不再衰减
func apply_summon_level_up_decay() -> void:
	if summon_decay_frozen:
		return
	for rarity in RARITY_LEVELS:
		if not rarity_faction_weights.has(rarity):
			continue
		var weights: Dictionary = rarity_faction_weights[rarity]
		if weights.has("Summon"):
			weights["Summon"] = max(0.0, weights["Summon"] - 1.0)

# 获取玩家当前拥有的武器派系列表（仅统计已解锁的武器）
func get_owned_weapon_factions() -> Array[String]:
	var owned: Array[String] = []
	var sr = PC.selected_rewards
	for faction in WEAPON_FACTIONS:
		if not is_faction_study_unlocked(faction):
			continue
		# 检查 selected_rewards 中是否有该派系（注意大小写需与 reward 函数 append 的一致）
		var check_key: String = faction
		# 部分派系在 selected_rewards 中的 key 与 WEAPON_FACTIONS 中的大小写不同
		if sr.has(check_key):
			owned.append(faction)
	return owned

# 计算本次升级奖励各派系的动态权重
# 权重A（新武器）：未拥有的武器平分总权重
# 权重B（武器升级）：已拥有的武器平分总权重
# 权重C（其他升级）：以动态权重归一化到 other_total
func get_level_up_weights(rarity: String) -> Dictionary:
	var result: Dictionary = {}

	var owned_weapons: Array[String] = get_owned_weapon_factions()
	var weapon_count: int = owned_weapons.size()

	# 各大类总权重
	var new_weapon_total: float
	var weapon_upgrade_total: float
	var other_total: float

	if rarity == "darkorchid":
		if weapon_count <= 1:
			new_weapon_total = 100.0
			weapon_upgrade_total = 0.0
			other_total = 0.0
		else:
			new_weapon_total = 60.0
			weapon_upgrade_total = 5.0
			other_total = 35.0
	elif rarity == "red":
		# red级别：去掉武器强化（权重B），全部权重分配给C类其他升级
		new_weapon_total = 0.0
		weapon_upgrade_total = 0.0
		other_total = 100.0
	else:
		new_weapon_total = 0.0
		# 根据武器数量动态调整武器升级权重
		if weapon_count <= 1:
			weapon_upgrade_total = 5.0
		elif weapon_count == 2:
			weapon_upgrade_total = 11.0
		elif weapon_count == 3:
			weapon_upgrade_total = 17.5
		elif weapon_count == 4:
			weapon_upgrade_total = 23.5
		else:
			weapon_upgrade_total = 31
		# 铸匠之魂：武器升级概率提升（加算）
		if PC.lingwu_weapon_upgrade_bonus > 0:
			var bonus = weapon_upgrade_total * PC.lingwu_weapon_upgrade_bonus
			weapon_upgrade_total += bonus
		# 宝器之魂：天命升级概率提升（加算，影响Lucky权重）
		# 唤灵之魂：召唤升级概率提升（加算，影响Summon权重）
		other_total = 100.0 - weapon_upgrade_total

	# 权重B：已有武器平分武器升级总权重
	if weapon_count > 0:
		var per_owned: float = weapon_upgrade_total / float(weapon_count)
		for faction in owned_weapons:
			result[faction] = per_owned

	# 权重A：未拥有且已解锁的武器平分新武器总权重
	var available_factions: Array[String] = get_available_weapon_factions()
	var unowned_weapons: Array[String] = []
	for faction in available_factions:
		if not owned_weapons.has(faction):
			unowned_weapons.append(faction)
	if not unowned_weapons.is_empty():
		var per_unowned: float = new_weapon_total / float(unowned_weapons.size())
		for faction in unowned_weapons:
			result[faction] = per_unowned

	# 权重C：直接使用动态权重归一化到 other_total
	# red级别：Normal权重 *2.5，Six权重归零
	# 宝器之魂/唤灵之魂：对应C类权重提升
	var c_sum: float = 0.0
	for faction in C_FACTIONS:
		var weight: float = get_faction_weight(rarity, faction)
		if rarity == "red" and faction == "Normal":
			weight *= 2.5
		if rarity == "red" and faction == "Six":
			weight = 0.0
		# 宝器之魂：Lucky权重提升
		if faction == "Lucky" and PC.lingwu_lucky_upgrade_bonus > 0:
			weight *= (1.0 + PC.lingwu_lucky_upgrade_bonus)
		# 唤灵之魂：Summon权重提升
		if faction == "Summon" and PC.lingwu_summon_upgrade_bonus > 0:
			weight *= (1.0 + PC.lingwu_summon_upgrade_bonus)
		# 存续之魂：Live权重提升
		if faction == "Live" and PC.lingwu_live_upgrade_bonus > 0:
			weight *= (1.0 + PC.lingwu_live_upgrade_bonus)
		c_sum += weight
	if c_sum > 0.0:
		for faction in C_FACTIONS:
			var weight: float = get_faction_weight(rarity, faction)
			if rarity == "red" and faction == "Normal":
				weight *= 2.5
			if rarity == "red" and faction == "Six":
				weight = 0.0
			if faction == "Lucky" and PC.lingwu_lucky_upgrade_bonus > 0:
				weight *= (1.0 + PC.lingwu_lucky_upgrade_bonus)
			if faction == "Summon" and PC.lingwu_summon_upgrade_bonus > 0:
				weight *= (1.0 + PC.lingwu_summon_upgrade_bonus)
			if faction == "Live" and PC.lingwu_live_upgrade_bonus > 0:
				weight *= (1.0 + PC.lingwu_live_upgrade_bonus)
			result[faction] = weight / c_sum * other_total

	return result
