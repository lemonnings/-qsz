extends Node

# 用于存储不同稀有度下各派系的动态权重
# 结构: { "rarity_name": { "faction_name": weight_value, ... }, ... }
var rarity_faction_weights: Dictionary = {}

# 默认的初始权重，根据新的分类体系
var INITIAL_FACTION_WEIGHTS: Dictionary = {
	"Normal": 3.0, # 通用，通用型、基础属性提升
	"Six": 0.5,
	"Lucky": 1.0,
	"Craft": 2.5,
	"Live": 2.5,
	"Summon": 2.5,
	"Branch": 1.5, # 树枝
	"Moyan": 1.5, # 魔焰
	"Riyan": 1.5, # 日炎
	"Ringfire": 1.5, # 环火
	"Thunderbreak": 1.5, # 雷破
	"Swordqi": 1.5, # 剑气
	"Thunder": 1.5,
	"Bloodwave": 1.5,
	"Bloodboardsword": 1.5,
	"Lightbullet": 1.5,
	"Water": 1.5,
	"Qiankun": 1.5,
	"Xuanwu": 1.5,
	"Xunfeng": 1.5,
	"Genshan": 1.5,
	"Duize": 1.5,
	"Qigong": 1.5,
	"Holylight": 1.5,
	"Ice": 1.5,
	"Dragonwind": 1.5
}

# 定义游戏中存在的稀有度等级
const RARITY_LEVELS: Array[String] = ["normal_white", "pro_green", "rare_blue", "super_rare_darkorchid", "super2_rare_orange", "unbelievable_gold"]

# 所有武器派系（权重A：新武器 / 权重B：武器升级）
const WEAPON_FACTIONS: Array[String] = [
	"Branch", "Moyan", "Riyan", "Ringfire", "Thunderbreak", "Swordqi",
	"Thunder", "Bloodwave", "Bloodboardsword", "Lightbullet", "Water",
	"Qiankun", "Xuanwu", "Xunfeng", "Genshan", "Duize", "Qigong",
	"Holylight", "Ice", "Dragonwind"
]

# 非武器升级派系（权重C：其他升级），on_faction_selected 仅对这些派系生效
const OTHER_FACTIONS: Array[String] = ["Normal", "Live", "Craft", "Summon", "Lucky", "Six"]

# 权重C 各派系的基础比例权重（用于 get_level_up_weights 归一化）
const C_BASE_WEIGHTS: Dictionary = {
	"Normal": 25.0,
	"Live": 15.0,
	"Debuff": 15.0,
	"Summon": 15.0,
	"Lucky": 15.0,
	"Six": 10.0
}

func _init():
	print("PlayerRewardWeights initialized.")
	reset_all_weights()

# 重置所有稀有度的所有派系权重到初始值
func reset_all_weights():
	rarity_faction_weights.clear()
	for rarity in RARITY_LEVELS:
		rarity_faction_weights[rarity] = INITIAL_FACTION_WEIGHTS.duplicate(true)
	
# 获取特定稀有度下特定派系的权重
func get_faction_weight(rarity: String, faction: String) -> float:
	if rarity_faction_weights.has(rarity) and rarity_faction_weights[rarity].has(faction):
		return rarity_faction_weights[rarity][faction]
	elif INITIAL_FACTION_WEIGHTS.has(faction): # 如果特定稀有度没有，尝试返回初始默认值
		return INITIAL_FACTION_WEIGHTS[faction]
	printerr("Attempted to get weight for unknown rarity/faction: %s / %s" % [rarity, faction])
	return 1.0 # 返回一个默认安全值

# 更新特定稀有度下特定派系的权重 (直接设置新权重)
func set_faction_weight(rarity: String, faction: String, new_weight: float):
	if rarity_faction_weights.has(rarity):
		if rarity_faction_weights[rarity].has(faction) or faction == "normal": # 允许更新已知派系或公共派系
			rarity_faction_weights[rarity][faction] = new_weight
		else:
			printerr("Attempted to set weight for unknown faction '%s' in rarity '%s'" % [faction, rarity])
	else:
		printerr("Attempted to set weight for unknown rarity: %s" % rarity)

# 玩家选择派系时调用：仅对权重C的非Normal派系（Live/Craft/Summon/Lucky/Six）生效
# 选中派系权重 *1.2（上限：相比初始值最多提高5），
# 其余派系权重 *0.9（上限：相比初始值最多降低2），Normal 及武器派系不受影响
func on_faction_selected(selected_faction: String):
	if not INITIAL_FACTION_WEIGHTS.has(selected_faction):
		printerr("on_faction_selected: unknown faction '%s'" % selected_faction)
		return
	for rarity in RARITY_LEVELS:
		if not rarity_faction_weights.has(rarity):
			continue
		var weights: Dictionary = rarity_faction_weights[rarity]
		for faction in weights.keys():
			if faction == "Normal":
				continue # Normal 不受任何影响
			# 仅对权重C的非武器派系（Live/Craft/Summon/Lucky/Six）应用动态调整
			if not OTHER_FACTIONS.has(faction):
				continue
			var initial_weight: float = INITIAL_FACTION_WEIGHTS.get(faction, 1.0)
			if faction == selected_faction:
				var new_weight: float = weights[faction] * 1.2
				weights[faction] = min(new_weight, initial_weight + 5)
			else:
				var new_weight: float = weights[faction] * 0.9
				weights[faction] = max(new_weight, initial_weight - 2)

# 获取玩家当前拥有的武器派系列表
# 判断依据：PC.selected_rewards 中是否含有对应武器名（与 reward_Branch/reward_Swordqi 等函数一致）
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

# 计算本次升级奖励各派系的动态权重，供 _select_faction_for_rarity 使用
# 权重A（新武器）：
#   - 紫色（darkorchid）：总权重50，未拥有的武器平分
#   - 其他稀有度：武器数 < 4 时总权重30，>= 4 时总权重10；未拥有的武器平分
# 权重B（武器升级）：
#   - 紫色（darkorchid）：总权重15；玩家拥有的武器平分
#   - 其他稀有度：总权重30；玩家拥有的武器平分
# 权重C（其他升级）：
#   - 紫色（darkorchid）：总权重15
#   - 其他稀有度：武器数 < 4 时总权重40，>= 4 时总权重60
#   以 C_BASE_WEIGHTS 为基准比例，结合 on_faction_selected 动态调整因子后归一化
func get_level_up_weights(rarity: String) -> Dictionary:
	var result: Dictionary = {}

	var owned_weapons: Array[String] = get_owned_weapon_factions()
	var weapon_count: int = owned_weapons.size()

	# 各大类总权重
	var new_weapon_total: float
	var weapon_upgrade_total: float
	var other_total: float

	if rarity == "darkorchid":
		# 紫色稀有度：新武器权重大幅提升至50%，升级与其他各占25%
		new_weapon_total = 50.0
		weapon_upgrade_total = 25.0
		other_total = 25.0
	else:
		new_weapon_total = 10.0 if weapon_count >= 4 else 30.0
		weapon_upgrade_total = 30.0
		other_total = 60.0 if weapon_count >= 4 else 40.0

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

	# 权重C：以 C_BASE_WEIGHTS 为基准，结合 rarity_faction_weights 动态因子后归一化到 other_total
	var c_adjusted: Dictionary = {}
	var c_sum: float = 0.0
	for faction in C_BASE_WEIGHTS:
		var base_w: float = C_BASE_WEIGHTS[faction]
		var initial_w: float = INITIAL_FACTION_WEIGHTS.get(faction, 1.0)
		var dynamic_w: float = get_faction_weight(rarity, faction)
		var adjusted: float = base_w * (dynamic_w / initial_w) if initial_w > 0.0 else base_w
		c_adjusted[faction] = adjusted
		c_sum += adjusted
	if c_sum > 0.0:
		for faction in c_adjusted:
			result[faction] = c_adjusted[faction] / c_sum * other_total

	return result
