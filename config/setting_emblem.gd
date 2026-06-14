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
const START_WEAPON_MAP := {
	"Swordqi": {"skill_id": "swordqi", "display_name": "剑气诀"},
	"Qigong": {"skill_id": "qigong", "display_name": "气功波"},
	"Lightbullet": {"skill_id": "light bullet", "display_name": "光弹"},
	"Ice": {"skill_id": "ice", "display_name": "冰刺术"},
	"Xunfeng": {"skill_id": "xunfeng", "display_name": "巽风诀"},
	"Genshan": {"skill_id": "genshan", "display_name": "艮山诀"},
	"Bloodwave": {"skill_id": "bloodwave", "display_name": "血气波"},
	"Xuanwu": {"skill_id": "xuanwu", "display_name": "玄武盾"},
	"Water": {"skill_id": "water", "display_name": "坎水诀"},
	"Holylight": {"skill_id": "holylight", "display_name": "圣光术"},
	"Branch": {"skill_id": "branch", "display_name": "仙枝"},
	"Thunder": {"skill_id": "thunder", "display_name": "震雷诀"},
	"Thunderbreak": {"skill_id": "thunder_break", "display_name": "天雷破"},
	"Moyan": {"skill_id": "moyan", "display_name": "爆炎诀"},
	"Qiankun": {"skill_id": "qiankun", "display_name": "乾坤双剑"},
	"Bloodboardsword": {"skill_id": "bloodboardsword", "display_name": "饮血刀"},
}

func _ready():
	_initialize_emblem_configs()

func _initialize_emblem_configs():
	# 血气纹章
	emblem_configs["xueqi"] = EmblemData.new(
		"xueqi",
		"血气",
		"res://AssetBundle/Sprites/Sprite sheets/skillIcon/xueqi.png",
		5,
		"{base_weapon}攻击附带6*层数%当前HP的伤害，每秒最多触发1次。"
	)
	
	# 破阵纹章
	emblem_configs["pozhen"] = EmblemData.new(
		"pozhen",
		"破阵",
		"res://AssetBundle/Sprites/Sprite sheets/skillIcon/pozhen.png",
		5,
		"每1%的暴击率会提升0.25*层数%的暴击伤害。"
	)
	
	# 铁骨纹章
	emblem_configs["tiegu"] = EmblemData.new(
		"tiegu",
		"铁骨",
		"res://AssetBundle/Sprites/Sprite sheets/skillIcon/tiegu.png",
		5,
		"受到伤害后，反弹被角色减伤率而降低的75*层数%的伤害。"
	)
	
	# 惊鸿纹章
	emblem_configs["jinghong"] = EmblemData.new(
		"jinghong",
		"惊鸿",
		"res://AssetBundle/Sprites/Sprite sheets/skillIcon/jinghong.png",
		5,
		"{base_weapon}每攻击3次，额外攻击1次，该次攻击造成15*层数%的伤害。"
	)
	
	# 踏风纹章
	emblem_configs["tafeng"] = EmblemData.new(
		"tafeng",
		"踏风",
		"res://AssetBundle/Sprites/Sprite sheets/skillIcon/tafeng.png",
		5,
		"每10%的移动速度加成转化为0.5*层数%的冷却缩减，通过此纹章最多获得25%冷却缩减。"
	)
	
	# 沉静纹章
	emblem_configs["chenjing"] = EmblemData.new(
		"chenjing",
		"沉静",
		"res://AssetBundle/Sprites/Sprite sheets/skillIcon/chenjing.png",
		5,
		"1秒内没有移动，提升6*层数%的最终伤害。"
	)
	
	# 炼体纹章
	emblem_configs["lianti"] = EmblemData.new(
		"lianti",
		"炼体",
		"res://AssetBundle/Sprites/Sprite sheets/skillIcon/lianti.png",
		5,
		"每1%的减伤率额外提升0.2*层数%的最终伤害。"
	)
	
	# 健步纹章
	emblem_configs["jianbu"] = EmblemData.new(
		"jianbu",
		"健步",
		"res://AssetBundle/Sprites/Sprite sheets/skillIcon/jianbu.png",
		5,
		"领悟获得的每4%移速可以提升0.5*层数%的攻击与0.5*层数%的体力上限。"
	)
	
	# 加护纹章
	emblem_configs["jiahu"] = EmblemData.new(
		"jiahu",
		"加护",
		"res://AssetBundle/Sprites/Sprite sheets/skillIcon/jiahu.png",
		5,
		"领悟获得的每点额外天命可以提升0.3*层数%的攻击与0.3*层数%的体力上限。"
	)
	
	# 归元纹章
	emblem_configs["guiyuan"] = EmblemData.new(
		"guiyuan",
		"归元",
		"res://AssetBundle/Sprites/Sprite sheets/skillIcon/guiyuan.png",
		5,
		"领悟获得的每5%攻速可以提升0.3*层数%的攻击与0.3*层数%的体力上限。"
	)
	
	# 蛮力纹章
	emblem_configs["manli"] = EmblemData.new(
		"manli",
		"蛮力",
		"res://AssetBundle/Sprites/Sprite sheets/skillIcon/manli.png",
		5,
		"当移动速度加成<0%时，提升8*层数%的最终伤害。"
	)
	
	# 融会贯通纹章
	emblem_configs["ronghui"] = EmblemData.new(
		"ronghui",
		"融会贯通",
		"res://AssetBundle/Sprites/Sprite sheets/skillIcon/ronghuiguantong.png",
		5,
		"当前每拥有一个纹章，提升2*层数%最终伤害。"
	)

func _get_current_start_weapon_id() -> String:
	if typeof(PC) != TYPE_NIL and PC != null:
		return Global.get_selected_start_weapon()
	return "Swordqi"

func get_base_weapon_info(start_weapon_id: String = "") -> Dictionary:
	var resolved_start_weapon_id := start_weapon_id.strip_edges()
	if resolved_start_weapon_id.is_empty():
		resolved_start_weapon_id = _get_current_start_weapon_id()
	resolved_start_weapon_id = Global.normalize_start_weapon_id(resolved_start_weapon_id)
	if START_WEAPON_MAP.has(resolved_start_weapon_id):
		return START_WEAPON_MAP[resolved_start_weapon_id]
	return {}

func get_base_weapon_skill_id(start_weapon_id: String = "") -> String:
	var weapon_info := get_base_weapon_info(start_weapon_id)
	return str(weapon_info.get("skill_id", ""))

func get_base_weapon_display_name(start_weapon_id: String = "") -> String:
	var weapon_info := get_base_weapon_info(start_weapon_id)
	return str(weapon_info.get("display_name", "基础武器"))

func get_base_weapon_description(start_weapon_id: String = "") -> String:
	var weapon_info := get_base_weapon_info(start_weapon_id)
	if weapon_info.is_empty():
		return "基础武器"
	return "%s" % [
		get_base_weapon_display_name(start_weapon_id)
	]

func _resolve_emblem_description(emblem_id: String, description: String, player_name: String = "") -> String:
	match emblem_id:
		"xueqi", "jinghong":
			return description.replace("{base_weapon}", get_base_weapon_description(player_name))
		_:
			return description

# 获取纹章数据
func get_emblem_data(emblem_id: String) -> EmblemData:
	if not emblem_configs.has(emblem_id):
		return null
	var config: EmblemData = emblem_configs[emblem_id]
	return EmblemData.new(
		config.id,
		config.name,
		config.icon_path,
		config.max_stack,
		_resolve_emblem_description(config.id, config.description)
	)

# 获取所有纹章配置
func get_all_emblem_configs() -> Dictionary:
	var resolved_configs: Dictionary = {}
	for emblem_id in emblem_configs.keys():
		resolved_configs[emblem_id] = get_emblem_data(emblem_id)
	return resolved_configs

# 检查纹章是否存在
func has_emblem_config(emblem_id: String) -> bool:
	return emblem_configs.has(emblem_id)
