extends Node

# 用于存储不同稀有度下C类派系的动态权重
# 结构: { "rarity_name": { "faction_name": weight_value, ... }, ... }
var rarity_faction_weights: Dictionary = {}

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
	"Normal": 20.0,
	"Live": 15.0,
	"Debuff": 15.0,
	"Summon": 15.0,
	"Lucky": 12.0,
	"Six": 10.0
}

func _init():
	print("PlayerRewardWeights initialized.")
	reset_all_weights()

# 重置所有稀有度的C类派系权重到基础值
func reset_all_weights():
	rarity_faction_weights.clear()
	for rarity in RARITY_LEVELS:
		rarity_faction_weights[rarity] = C_BASE_WEIGHTS.duplicate(true)

# 获取特定稀有度下特定C类派系的权重
func get_faction_weight(rarity: String, faction: String) -> float:
	if rarity_faction_weights.has(rarity) and rarity_faction_weights[rarity].has(faction):
		return rarity_faction_weights[rarity][faction]
	if C_BASE_WEIGHTS.has(faction):
		return C_BASE_WEIGHTS[faction]
	return 0.0

# 更新特定稀有度下特定C类派系的权重
func set_faction_weight(rarity: String, faction: String, new_weight: float):
	if rarity_faction_weights.has(rarity) and rarity_faction_weights[rarity].has(faction):
		rarity_faction_weights[rarity][faction] = new_weight

# 玩家选择派系时调用：仅对C类非Normal派系生效
# 选中派系权重 *1.2 + 1（上限：相比基础值最多提高3）
func on_faction_selected(selected_faction: String):
	if not C_BASE_WEIGHTS.has(selected_faction):
		return
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

# 获取玩家当前拥有的武器派系列表
func get_owned_weapon_factions() -> Array[String]:
	var owned: Array[String] = []
	var sr = PC.selected_rewards
	if sr.has("Branch"): owned.append("Branch")
	if sr.has("Moyan"): owned.append("Moyan")
	if sr.has("Riyan"): owned.append("Riyan")
	if sr.has("Ringfire"): owned.append("Ringfire")
	if sr.has("Thunderbreak"): owned.append("Thunderbreak")
	if sr.has("Swordqi"): owned.append("Swordqi")
	if sr.has("Thunder"): owned.append("Thunder")
	if sr.has("Bloodwave"): owned.append("Bloodwave")
	if sr.has("Bloodboardsword"): owned.append("Bloodboardsword")
	if sr.has("Lightbullet"): owned.append("Lightbullet")
	if sr.has("Water"): owned.append("Water")
	if sr.has("Qiankun"): owned.append("Qiankun")
	if sr.has("Xuanwu"): owned.append("Xuanwu")
	if sr.has("Xunfeng"): owned.append("Xunfeng")
	if sr.has("Genshan"): owned.append("Genshan")
	if sr.has("Duize"): owned.append("Duize")
	if sr.has("Qigong"): owned.append("Qigong")
	if sr.has("Holylight"): owned.append("Holylight")
	if sr.has("Ice"): owned.append("Ice")
	if sr.has("Dragonwind"): owned.append("Dragonwind")
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
			weapon_upgrade_total = 8.0
		elif weapon_count == 2:
			weapon_upgrade_total = 12.0
		elif weapon_count == 3:
			weapon_upgrade_total = 20.0
		elif weapon_count == 4:
			weapon_upgrade_total = 30.0
		else:
			weapon_upgrade_total = 42.0
		other_total = 100.0 - weapon_upgrade_total

	# 权重B：已有武器平分武器升级总权重
	if weapon_count > 0:
		var per_owned: float = weapon_upgrade_total / float(weapon_count)
		for faction in owned_weapons:
			result[faction] = per_owned

	# 权重A：未拥有的武器平分新武器总权重
	var unowned_weapons: Array[String] = []
	for faction in WEAPON_FACTIONS:
		if not owned_weapons.has(faction):
			unowned_weapons.append(faction)
	if not unowned_weapons.is_empty():
		var per_unowned: float = new_weapon_total / float(unowned_weapons.size())
		for faction in unowned_weapons:
			result[faction] = per_unowned

	# 权重C：直接使用动态权重归一化到 other_total
	# red级别：Normal权重 *2.5，Six权重归零
	var c_sum: float = 0.0
	for faction in C_FACTIONS:
		var weight: float = get_faction_weight(rarity, faction)
		if rarity == "red" and faction == "Normal":
			weight *= 2.5
		if rarity == "red" and faction == "Six":
			weight = 0.0
		c_sum += weight
	if c_sum > 0.0:
		for faction in C_FACTIONS:
			var weight: float = get_faction_weight(rarity, faction)
			if rarity == "red" and faction == "Normal":
				weight *= 2.5
			if rarity == "red" and faction == "Six":
				weight = 0.0
			result[faction] = weight / c_sum * other_total

	return result
