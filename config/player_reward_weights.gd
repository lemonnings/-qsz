extends Node

# 用于存储不同稀有度下各派系的动态权重
# 结构: { "rarity_name": { "faction_name": weight_value, ... }, ... }
var rarity_faction_weights: Dictionary = {}

# 默认的初始权重，根据新的分类体系
const INITIAL_FACTION_WEIGHTS: Dictionary = {
	"normal": 4.0,           # 通用，通用型、基础属性提升
	"branch": 2.0,           # 树枝
	"moyan": 2.0,           # 魔焰
	#"riyan": 2.0,           # 日炎
	"ringFire": 2.0,           # 环火
	"swordQi": 4.0,           # 剑气
	"summon": 2.0,           # 召唤，召唤物数量、召唤物属性提升等
	#"bullet": 1.0,           # 剑气，弹体大小、反弹、分裂（三向、五向）等
	"lucky": 1.0,           # 天命，与幸运值、特殊几率触发等相关的
	#"craft": 1.0,           # 技艺，与主动技能，环形伤害等特殊攻击方式相关的
	#"live": 1.0,           # 炼体，与生存能力，反击相关的
	# 可以根据需要添加更多细分或新的主要分类
}

# 定义游戏中存在的稀有度等级
const RARITY_LEVELS: Array[String] = ["normal_white", "pro_green", "rare_blue", "super_rare_purple", "super2_rare_orange", "unbelievable_gold"] # 示例稀有度

func _init():
	print("PlayerRewardWeights initialized.")
	reset_all_weights()

# 重置所有稀有度的所有派系权重到初始值
func reset_all_weights():
	rarity_faction_weights.clear()
	for rarity in RARITY_LEVELS:
		rarity_faction_weights[rarity] = INITIAL_FACTION_WEIGHTS.duplicate(true) # 深拷贝
	#
	## 随机选择summon、bullet或craft中的一个，将其权重设为5
	#var special_factions = ["summon", "bullet", "craft"]
	#var selected_faction = special_factions[randi() % special_factions.size()]
	#for rarity in RARITY_LEVELS:
		#rarity_faction_weights[rarity][selected_faction] = 5.0
	
	#print("Player reward weights reset to initial values with %s boosted to 5.0: " % selected_faction, rarity_faction_weights)

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
		if rarity_faction_weights[rarity].has(faction) or faction == "公共": # 允许更新已知派系或公共派系
			rarity_faction_weights[rarity][faction] = new_weight
		else:
			printerr("Attempted to set weight for unknown faction '%s' in rarity '%s'" % [faction, rarity])
	else:
		printerr("Attempted to set weight for unknown rarity: %s" % rarity)

func update_faction_weights_on_selection(rarity: String, selected_faction: String, _delta_increase: float):
	if selected_faction == "normal" or not rarity_faction_weights.has(rarity) or not rarity_faction_weights[rarity].has(selected_faction):
		# 公共派系不参与此动态调整，或者稀有度/派系不存在
		return

	var current_rarity_weights: Dictionary = rarity_faction_weights[rarity]

	# 1. 提升选中派系的权重
	current_rarity_weights[selected_faction] = current_rarity_weights[selected_faction] + 0.25

	# 2. 计算其他可调整派系的总权重（用于按比例分配降低量）
	var sum_other_faction_weights: float = 0.0
	var other_factions: Array[String] = []
	for faction_name in current_rarity_weights.keys():
		if faction_name != selected_faction and faction_name != "normal":
			sum_other_faction_weights += current_rarity_weights.get(faction_name, 1.0)
			other_factions.append(faction_name)

	if sum_other_faction_weights <= 0: # 防止除以零，或者没有其他派系可调整
		return

	# 3. 按比例降低其他派系的权重
	for other_faction_name in other_factions:
		current_rarity_weights[other_faction_name] = min(0.1, current_rarity_weights[other_faction_name] - 0.01)
	
