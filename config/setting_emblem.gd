extends Node
class_name SettingEmblem

# 纹章数据类
class EmblemData:
	var id: String
	var name: String
	var icon_path: String
	var max_stack: int
	var description: String
	
	func _init(p_id: String, p_name: String, p_icon_path: String, p_max_stack: int, p_description: String):
		id = p_id
		name = p_name
		icon_path = p_icon_path
		max_stack = p_max_stack
		description = p_description

# 纹章配置字典
var emblem_configs: Dictionary = {}

func _ready():
	_initialize_emblem_configs()

func _initialize_emblem_configs():
	# 血气纹章
	emblem_configs["xueqi"] = EmblemData.new(
		"xueqi",
		"血气",
		"res://AssetBundle/Sprites/Ghostpixxells_pixelfood/07_bread.png",
		5,
		"基础武器攻击附带2*层数%当前HP的伤害。"
	)
	
	# 破阵纹章
	emblem_configs["pozhen"] = EmblemData.new(
		"pozhen",
		"破阵",
		"res://AssetBundle/Sprites/UI/buff_speed.png",
		5,
		"基础武器攻击有5*层数%概率直击，额外造成30%无视敌方减伤的伤害。"
	)
	
	# 铁骨纹章
	emblem_configs["tiegu"] = EmblemData.new(
		"tiegu",
		"铁骨",
		"res://AssetBundle/Sprites/UI/buff_health.png",
		5,
		"受到伤害后，反弹被角色减伤率而降低的25*层数%的伤害。"
	)
	
	# 惊鸿纹章
	emblem_configs["jinghong"] = EmblemData.new(
		"jinghong",
		"惊鸿",
		"res://AssetBundle/Sprites/UI/buff_crit.png",
		5,
		"基础武器每攻击3次，额外攻击1次，该次攻击造成15*层数%的伤害。"
	)
	
	# 踏风纹章
	emblem_configs["tafeng"] = EmblemData.new(
		"tafeng",
		"踏风",
		"res://AssetBundle/Sprites/UI/buff_shield.png",
		5,
		"每10%的移动速度加成转化为0.5*层数%的冷却缩减。"
	)
	
	# 沉静纹章
	emblem_configs["chenjing"] = EmblemData.new(
		"chenjing",
		"沉静",
		"res://AssetBundle/Sprites/Ghostpixxells_pixelfood/07_bread.png",
		5,
		"1秒内没有移动，提升6*层数%的最终伤害。"
	)
	
	# 炼体纹章
	emblem_configs["lianti"] = EmblemData.new(
		"lianti",
		"炼体",
		"res://AssetBundle/Sprites/Ghostpixxells_pixelfood/07_bread.png",
		5,
		"每1%的减伤率额外提升0.2*层数%的最终伤害。"
	)
	
	# 健步纹章
	emblem_configs["jianbu"] = EmblemData.new(
		"jianbu",
		"健步",
		"res://AssetBundle/Sprites/Ghostpixxells_pixelfood/07_bread.png",
		5,
		"当移动速度加成>20%时，提升4*层数%的最终伤害。"
	)
	
	# 蛮力纹章
	emblem_configs["manli"] = EmblemData.new(
		"manli",
		"蛮力",
		"res://AssetBundle/Sprites/Ghostpixxells_pixelfood/07_bread.png",
		5,
		"当移动速度加成<0%时，提升5*层数%的最终伤害。"
	)
	
	# 融会贯通纹章
	emblem_configs["ronghui"] = EmblemData.new(
		"ronghui",
		"融会贯通",
		"res://AssetBundle/Sprites/Ghostpixxells_pixelfood/07_bread.png",
		5,
		"当前每拥有一个纹章，提升0.8*层数%最终伤害。"
	)

# 获取纹章数据
func get_emblem_data(emblem_id: String) -> EmblemData:
	if emblem_configs.has(emblem_id):
		return emblem_configs[emblem_id]
	return null

# 获取所有纹章配置
func get_all_emblem_configs() -> Dictionary:
	return emblem_configs

# 检查纹章是否存在
func has_emblem_config(emblem_id: String) -> bool:
	return emblem_configs.has(emblem_id)