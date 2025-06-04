extends Node

# Buff类型枚举
enum BuffType {
	PERMANENT,  # 永久buff
	TEMPORARY   # 临时buff
}

# Buff数据结构
class BuffData:
	var id: String
	var name: String
	var icon_path: String
	var type: BuffType
	var max_stack: int = 1
	var description: String = ""
	
	func _init(buff_id: String, buff_name: String, buff_icon_path: String, buff_type: BuffType, buff_max_stack: int = 1, buff_description: String = ""):
		id = buff_id
		name = buff_name
		icon_path = buff_icon_path
		type = buff_type
		max_stack = buff_max_stack
		description = buff_description

# Buff配置字典
var buff_configs: Dictionary = {}

func _ready():
	# 初始化buff配置
	_init_buff_configs()

func _init_buff_configs():
	buff_configs["attack_boost"] = BuffData.new(
		"attack_boost",
		"攻击力提升",
		"res://AssetBundle/Sprites/Ghostpixxells_pixelfood/07_bread.png",
		BuffType.TEMPORARY,
		5,
		"增加玩家的攻击力，每层提升10%攻击力。持续时间内可叠加多层效果。"
	)
	buff_configs["rebound"] = BuffData.new(
		"rebound",
		"续剑",
		"res://AssetBundle/Sprites/Ghostpixxells_pixelfood/07_bread.png",
		BuffType.PERMANENT,
		1,
		"剑气击中敌人后会反弹"
	)
	
	buff_configs["three_way"] = BuffData.new(
		"three_way",
		"三向剑气",
		"res://AssetBundle/Sprites/Ghostpixxells_pixelfood/07_bread.png",
		BuffType.PERMANENT,
		1,
		"剑气会对前方三个方向射出"
	)
	
	buff_configs["five_way"] = BuffData.new(
		"five_way",
		"五向剑气",
		"res://AssetBundle/Sprites/Ghostpixxells_pixelfood/07_bread.png",
		BuffType.PERMANENT,
		1,
		"剑气会对前方五个方向射出"
	)

func get_buff_data(buff_id: String) -> BuffData:
	if buff_configs.has(buff_id):
		return buff_configs[buff_id]
	else:
		print("Warning: Buff ID '" + buff_id + "' not found in configs")
		return null

func get_all_buff_ids() -> Array:
	return buff_configs.keys()
