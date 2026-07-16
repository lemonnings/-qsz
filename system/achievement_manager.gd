extends Node

signal achievement_unlocked(achievement_id: String, achievement_data: Dictionary)

const ACHIEVEMENT_POP_UP_SCENE := preload("res://Scenes/town/achievement_pop_up.tscn")
const ACHIEVEMENT_ICON_DIR := "res://AssetBundle/Sprites/achievement"
const DEFAULT_ACHIEVEMENT_ICON_PATH := "res://AssetBundle/Sprites/town/成就.png"
const RARITY_POINTS := {
	"white": 1,
	"blue": 2,
	"purple": 3,
	"gold": 4,
	"red": 5,
}

const RARITY_COLORS := {
	"white": Color(0.92, 0.92, 0.92, 1.0),
	"blue": Color(0.35, 0.62, 1.0, 1.0),
	"purple": Color(0.72, 0.38, 1.0, 1.0),
	"gold": Color(1.0, 0.78, 0.22, 1.0),
	"red": Color(1.0, 0.32, 0.28, 1.0),
}

const STAGE_NAMES := {
	"peach_grove": "桃林",
	"ruin": "古迹",
	"cave": "深窟",
	"forest": "密林",
	"difu": "九幽冥府",
}

const HERO_NAMES := {
	"moning": "墨宁",
	"yiqiu": "言秋",
	"noam": "诺姆",
	"kansel": "坎塞尔",
	"xueming": "雪铭",
}

const DEFAULT_START_WEAPONS := ["SwordQi", "Qigong"]

const MAIN_WEAPON_IDS := [
	"SwordQi",
	"Branch",
	"Moyan",
	"Riyan",
	"RingFire",
	"Thunder",
	"Bloodwave",
	"BloodBoardSword",
	"Ice",
	"ThunderBreak",
	"LightBullet",
	"Qigong",
	"Water",
	"Qiankun",
	"Xuanwu",
	"Xunfeng",
	"Genshan",
	"Duize",
	"DragonWind",
	"HolyLight",
	"Zhuazhuajuchui",
	"SoulSickle",
]

const WEAPON_LEVEL_PROPS := {
	"SwordQi": "main_skill_swordQi",
	"Branch": "main_skill_branch",
	"Moyan": "main_skill_moyan",
	"Riyan": "main_skill_riyan",
	"RingFire": "main_skill_ringFire",
	"Thunder": "main_skill_thunder",
	"Bloodwave": "main_skill_bloodwave",
	"BloodBoardSword": "main_skill_bloodboardsword",
	"Ice": "main_skill_ice",
	"ThunderBreak": "main_skill_thunder_break",
	"LightBullet": "main_skill_light_bullet",
	"Qigong": "main_skill_qigong",
	"Water": "main_skill_water",
	"Qiankun": "main_skill_qiankun",
	"Xuanwu": "main_skill_xuanwu",
	"Xunfeng": "main_skill_xunfeng",
	"Genshan": "main_skill_genshan",
	"Duize": "main_skill_duize",
	"DragonWind": "main_skill_dragonwind",
	"HolyLight": "main_skill_holylight",
	"Zhuazhuajuchui": "main_skill_zhuazhuajuchui",
	"SoulSickle": "main_skill_soul_sickle",
}

const START_WEAPON_UNLOCKS := {
	"ach_002": ["LightBullet"],
	"ach_003": ["Ice"],
	"ach_004": ["Zhuazhuajuchui"],
	"ach_020": ["Xunfeng"],
	"ach_021": ["Genshan"],
	"ach_022": ["Bloodwave"],
	"ach_023": ["Xuanwu"],
	"ach_024": ["Water"],
	"ach_025": ["HolyLight"],
	"ach_026": ["Branch"],
	"ach_027": ["Thunder"],
	"ach_028": ["ThunderBreak"],
	"ach_029": ["Moyan"],
	"ach_030": ["Qiankun"],
	"ach_031": ["BloodBoardSword"],
	"ach_165": ["Zhuazhuajuchui"],
}

const LAW_DAMAGE_CATEGORIES := {
	"bullet": "projectile",
	"bagua": "bagua",
	"sword": "sword",
	"wide": "wide",
	"destroy": "destroy",
	"life": "life",
	"wind": "wind",
	"summon": "summon",
	"fire": "fire",
	"treasure": "treasure",
	"blood": "blood",
	"heal": "heal",
	"thunder": "thunder",
	"shield": "protect",
	"deep": "deep",
	"shehun": "shehun",
}

var definitions: Array[Dictionary] = []
var definitions_by_id: Dictionary = {}

var unlocked_achievements: Dictionary = {}
var pending_unlocked_achievements: Array[String] = []
var hero_clear_counts: Dictionary = {}
var hero_pair_clear_counts: Dictionary = {}
var shop_lingshi_spent: int = 0
var highest_single_damage: float = 0.0
var run_stats: Dictionary = {}

var _is_batch_unlocking: bool = false
var _save_after_batch: bool = false
var _signals_connected: bool = false
var _popup_layer: CanvasLayer
var _popup_queue: Array[Dictionary] = []
var _popup_is_playing: bool = false
var _active_popup: Node
var _popup_is_closing: bool = false
var _is_debug_unlocking_sequential: bool = false
var _bonus_summary_cache: Dictionary = {}
var _bonus_summary_cache_valid: bool = false
var _achievement_points_cache: int = 0
var _achievement_points_cache_valid: bool = false

func _init() -> void:
	_build_definitions()
	reset_run_stats()

func _ready() -> void:
	if definitions.is_empty():
		_build_definitions()
	if run_stats.is_empty():
		reset_run_stats()
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_connect_runtime_signals")

func _connect_runtime_signals() -> void:
	if _signals_connected:
		return
	_signals_connected = true
	if Global.has_signal("player_hit"):
		Global.player_hit.connect(_on_player_hit)
	if Global.has_signal("player_hit_ignore_invincible"):
		Global.player_hit_ignore_invincible.connect(_on_player_hit)
	if Global.has_signal("monster_damage"):
		Global.monster_damage.connect(_on_monster_damage)
	if Global.active_skill_manager != null and Global.active_skill_manager.has_signal("skill_used"):
		Global.active_skill_manager.skill_used.connect(record_active_skill_used)

func _build_definitions() -> void:
	definitions.clear()
	definitions_by_id.clear()
	_add_stage_clear_achievements()
	_add_character_clear_achievements()
	_add_law_achievements()
	_add_run_and_meta_achievements()
	for achievement in definitions:
		definitions_by_id[achievement["id"]] = achievement
	_invalidate_bonus_cache()

func _add_stage_clear_achievements() -> void:
	_add_achievement("ach_001", "小试牛刀", "blue", "首次通关桃林", "stage_clear", {"stage": "peach_grove"})
	_add_achievement("ach_002", "异世来客", "blue", "首次通关古迹", "stage_clear", {"stage": "ruin", "unlock_heroes": ["noam"], "unlock_weapons": ["LightBullet"], "unlock_text": "解锁角色：诺姆，武器：光弹术"})
	_add_achievement("ach_003", "众擎易举", "blue", "首次通关深窟", "stage_clear", {"stage": "cave", "unlock_heroes": ["kansel"], "unlock_weapons": ["Ice"], "unlock_text": "解锁角色：坎塞尔，武器：冰刺术"})
	_add_achievement("ach_004", "幕后之人", "blue", "首次通关密林", "stage_clear", {"stage": "forest", "unlock_heroes": ["xueming"], "unlock_weapons": ["Zhuazhuajuchui"], "unlock_text": "解锁角色：雪铭，武器：爪爪巨锤", "bonus": {"drop": 0.02}, "bonus_text": "掉落率 +2%"})
	_add_achievement("ach_158", "九幽冥府", "gold", "首次通关九幽冥府", "stage_clear", {"stage": "difu", "unlock_weapons": ["SoulSickle"], "unlock_text": "解锁武器：噬魂镰", "bonus": {}})
	_add_achievement("ach_005", "破境·壹", "blue", "通关一次深层难度", "difficulty_clear", {"difficulty": "deep", "bonus": {"point": 0.005}, "bonus_text": "真气获取率 +0.5%"})
	var core_names := ["贰", "叁", "肆", "伍", "陆", "柒", "捌", "玖", "拾", "拾壹"]
	var core_rarities := ["purple", "gold", "gold", "gold", "gold", "gold", "gold", "gold", "gold", "red"]
	var core_bonus := [0.01, 0.01, 0.01, 0.015, 0.015, 0.015, 0.015, 0.015, 0.015, 0.015]
	for i in range(10):
		var depth := i + 1
		_add_achievement("ach_%03d" % (6 + i), "破境·%s" % core_names[i], core_rarities[i], "通关一次核心难度%d" % depth, "core_clear", {"depth": depth, "bonus": {"point": core_bonus[i]}, "bonus_text": "真气获取率 +%s" % _format_percent(core_bonus[i])})
	for stage_id in ["peach_grove", "ruin", "cave", "forest"]:
		var index := ["peach_grove", "ruin", "cave", "forest"].find(stage_id)
		_add_achievement("ach_%03d" % (16 + index), "诗想·%s" % STAGE_NAMES[stage_id], "red", "诗想难度%s通关" % STAGE_NAMES[stage_id], "poetry_clear", {"stage": stage_id, "bonus": {"point": 0.04, "drop": 0.01}, "bonus_text": "真气获取率 +4%，掉落率 +1%"})

func _add_character_clear_achievements() -> void:
	_add_achievement("ach_020", "破晓·壹", "blue", "墨宁出战累计成功通关5次", "hero_clear_count", {"hero": "moning", "count": 5, "unlock_weapons": ["Xunfeng"], "unlock_text": "初始武器增加：巽风诀"})
	_add_achievement("ach_021", "破晓·贰", "purple", "墨宁出战累计成功通关10次", "hero_clear_count", {"hero": "moning", "count": 10, "unlock_weapons": ["Genshan"], "unlock_text": "初始武器增加：艮山诀"})
	_add_achievement("ach_022", "晓秋·壹", "gold", "墨宁、言秋出战累计成功通关20次", "hero_pair_clear_count", {"heroes": ["moning", "yiqiu"], "count": 20, "unlock_weapons": ["Bloodwave"], "unlock_text": "初始武器增加：血气波"})
	_add_achievement("ach_023", "晓秋·贰", "gold", "墨宁、言秋出战累计成功通关30次", "hero_pair_clear_count", {"heroes": ["moning", "yiqiu"], "count": 30, "unlock_weapons": ["Xuanwu"], "unlock_text": "初始武器增加：玄武盾"})
	_add_achievement("ach_024", "稚旅·壹", "blue", "诺姆出战累计成功通关5次", "hero_clear_count", {"hero": "noam", "count": 5, "unlock_weapons": ["Water"], "unlock_text": "初始武器增加：坎水诀"})
	_add_achievement("ach_025", "稚旅·贰", "purple", "诺姆出战累计成功通关10次", "hero_clear_count", {"hero": "noam", "count": 10, "unlock_weapons": ["HolyLight"], "unlock_text": "初始武器增加：圣光术"})
	_add_achievement("ach_026", "星灵·壹", "gold", "诺姆、坎塞尔出战累计成功通关20次", "hero_pair_clear_count", {"heroes": ["noam", "kansel"], "count": 20, "unlock_weapons": ["Branch"], "unlock_text": "初始武器增加：仙枝"})
	_add_achievement("ach_027", "星灵·贰", "gold", "诺姆、坎塞尔出战累计成功通关30次", "hero_pair_clear_count", {"heroes": ["noam", "kansel"], "count": 30, "unlock_weapons": ["Thunder"], "unlock_text": "初始武器增加：震雷诀"})
	_add_achievement("ach_028", "燃冰·壹", "blue", "坎塞尔出战累计成功通关5次", "hero_clear_count", {"hero": "kansel", "count": 5, "unlock_weapons": ["ThunderBreak"], "unlock_text": "初始武器增加：天雷破"})
	_add_achievement("ach_029", "燃冰·贰", "purple", "坎塞尔出战累计成功通关10次", "hero_clear_count", {"hero": "kansel", "count": 10, "unlock_weapons": ["Moyan"], "unlock_text": "初始武器增加：爆炎诀"})
	_add_achievement("ach_030", "意秋·壹", "blue", "言秋出战累计成功通关5次", "hero_clear_count", {"hero": "yiqiu", "count": 5, "unlock_weapons": ["Qiankun"], "unlock_text": "初始武器增加：乾坤双剑"})
	_add_achievement("ach_031", "意秋·贰", "purple", "言秋出战累计成功通关10次", "hero_clear_count", {"hero": "yiqiu", "count": 10, "unlock_weapons": ["BloodBoardSword"], "unlock_text": "初始武器增加：饮血刀"})
	_add_achievement("ach_165", "壮壮·壹", "blue", "雪铭出战累计成功通关5次", "hero_clear_count", {"hero": "xueming", "count": 5, "unlock_weapons": ["Zhuazhuajuchui"], "unlock_text": "初始武器增加：爪爪巨锤"})
	_add_achievement("ach_166", "壮壮·贰", "purple", "雪铭出战累计成功通关10次", "hero_clear_count", {"hero": "xueming", "count": 10, "bonus": {"atk": 2}, "bonus_text": "初始攻击 +2"})

func _add_law_achievements() -> void:
	_add_law("ach_032", "弹雨法则·极", "gold", "faze_bullet_level", 24, "bullet", 0.02, "弹雨类武器伤害 +2%")
	_add_law("ach_033", "弹雨法则·终", "red", "faze_bullet_level", 31, "bullet", 0.03, "弹雨类武器伤害 +3%")
	_add_law("ach_034", "八卦法则·极", "gold", "faze_bagua_level", 25, "bagua", 0.02, "八卦类武器伤害 +2%")
	_add_law("ach_035", "八卦法则·终", "red", "faze_bagua_level", 33, "bagua", 0.03, "八卦类武器伤害 +3%")
	_add_law("ach_036", "刀剑法则·极", "gold", "faze_sword_level", 22, "sword", 0.02, "刀剑类武器伤害 +2%")
	_add_law("ach_037", "刀剑法则·终", "red", "faze_sword_level", 29, "sword", 0.03, "刀剑类武器伤害 +3%")
	_add_law("ach_038", "广域法则·极", "gold", "faze_wide_level", 22, "wide", 0.02, "广域类武器伤害 +2%")
	_add_law("ach_039", "广域法则·终", "red", "faze_wide_level", 29, "wide", 0.03, "广域类武器伤害 +3%")
	_add_law("ach_040", "破坏法则·极", "gold", "faze_destroy_level", 22, "destroy", 0.02, "破坏类武器伤害 +2%")
	_add_law("ach_041", "破坏法则·终", "red", "faze_destroy_level", 29, "destroy", 0.03, "破坏类武器伤害 +3%")
	_add_law("ach_042", "生灵法则·极", "gold", "faze_life_level", 22, "life", 0.02, "生灵类武器伤害 +2%")
	_add_law("ach_043", "生灵法则·终", "red", "faze_life_level", 29, "life", 0.03, "生灵类武器伤害 +3%")
	_add_law("ach_044", "啸风法则·极", "gold", "faze_wind_level", 22, "wind", 0.02, "啸风类武器伤害 +2%")
	_add_law("ach_045", "啸风法则·终", "red", "faze_wind_level", 29, "wind", 0.03, "啸风类武器伤害 +3%")
	_add_law("ach_046", "御灵法则·极", "gold", "faze_summon_level", 22, "summon", 0.03, "召唤物伤害 +3%")
	_add_law("ach_047", "御灵法则·终", "red", "faze_summon_level", 29, "summon", 0.05, "召唤物伤害 +5%")
	_add_law("ach_048", "炽焰法则·极", "gold", "faze_fire_level", 22, "fire", 0.02, "炽焰类武器伤害 +2%")
	_add_law("ach_049", "炽焰法则·终", "red", "faze_fire_level", 29, "fire", 0.03, "炽焰类武器伤害 +3%")
	_add_law("ach_050", "宝器法则·极", "gold", "faze_treasure_level", 22, "treasure", 0.02, "宝器类武器伤害 +2%")
	_add_law("ach_051", "宝器法则·终", "red", "faze_treasure_level", 29, "treasure", 0.03, "宝器类武器伤害 +3%")
	_add_law("ach_052", "浴血法则·极", "gold", "faze_blood_level", 22, "blood", 0.05, "浴血类武器伤害 +5%")
	_add_law("ach_053", "愈疗法则·极", "gold", "faze_heal_level", 22, "heal", 0.05, "愈疗类武器伤害 +5%")
	_add_law("ach_054", "鸣雷法则·极", "gold", "faze_thunder_level", 22, "thunder", 0.05, "鸣雷类武器伤害 +5%")
	_add_law("ach_055", "护佑法则·极", "gold", "faze_shield_level", 15, "shield", 0.05, "护佑类武器伤害 +5%")
	_add_law("ach_156", "摄魂法则·极", "gold", "faze_shehun_level", 22, "shehun", 0.02, "摄魂类武器伤害 +2%")
	_add_law("ach_157", "摄魂法则·终", "red", "faze_shehun_level", 29, "shehun", 0.03, "摄魂类武器伤害 +3%")
	_add_law("ach_159", "沉渊法则·极", "gold", "faze_deep_level", 22, "deep", 0.02, "沉渊类武器伤害 +2%")
	_add_law("ach_160", "沉渊法则·终", "red", "faze_deep_level", 29, "deep", 0.03, "沉渊类武器伤害 +3%")
	_add_achievement("ach_056", "混沌法则·极", "gold", "混沌法则层数达到12", "law_level", {"prop": "faze_chaos_level", "value": 12, "bonus": {"point": 0.02}, "bonus_text": "真气获取率 +2%"})
	_add_achievement("ach_057", "六识法则·极", "red", "六识法则层数达到6", "law_level", {"prop": "faze_sixsense_level", "value": 6, "bonus": {"point": 0.03}, "bonus_text": "真气获取率 +3%"})

func _add_run_and_meta_achievements() -> void:
	_add_achievement("ach_058", "一器破万法", "red", "只用一把武器通关", "victory_stat", {"key": "weapon_count", "op": "<=", "value": 1, "bonus": {"initial_lock": 1}, "bonus_text": "初始锁定次数 +1"})
	_add_achievement("ach_059", "十步", "gold", "10秒内击杀首领", "victory_flag", {"key": "ten_step_boss_killed", "bonus": {"initial_lucky": 1}, "bonus_text": "初始天命 +1"})
	_add_threshold_group(60, "皮糙肉厚", ["壹", "贰", "叁", "肆", "伍"], ["white", "blue", "purple", "gold", "red"], "单局中累计受到伤害超过%d", [7500, 15000, 30000, 60000, 120000], "run_stat", "damage_taken", [ {"armor": 1}, {"armor": 2}, {"armor": 2}, {"armor": 3}, {"armor": 3}], ["护甲 +1", "护甲 +2", "护甲 +2", "护甲 +3", "护甲 +3"])
	_add_achievement("ach_065", "散财", "red", "单局在灵气漩涡中进行35次消费", "run_stat", {"key": "qi_vortex_purchases", "value": 35, "bonus": {"initial_refresh": 1}, "bonus_text": "初始刷新次数 +1"})
	_add_achievement("ach_066", "腰缠万贯", "red", "持有精魄数量大于80000", "runtime_stat", {"key": "spirit", "value": 80000, "bonus": {"initial_refresh": 1}, "bonus_text": "初始刷新次数 +1"})
	_add_achievement("ach_067", "天命加身", "gold", "天命大于200", "runtime_stat", {"key": "lucky", "value": 200, "bonus": {"initial_lucky": 1}, "bonus_text": "初始天命 +1"})
	_add_achievement("ach_068", "逆天改命", "gold", "持有5个以上的逆天领悟", "runtime_stat", {"key": "ur_rewards", "value": 5, "bonus": {"initial_lucky": 1}, "bonus_text": "初始天命 +1"})
	_add_achievement("ach_069", "疾风骤雨", "gold", "攻速达到160%", "runtime_stat", {"key": "atk_speed", "value": 1.6, "bonus": {"initial_lucky": 1}, "bonus_text": "初始天命 +1"})
	_add_achievement("ach_070", "缩地成寸", "gold", "移速达到130%", "runtime_stat", {"key": "move_speed", "value": 1.3, "bonus": {"initial_lucky": 1}, "bonus_text": "初始天命 +1"})
	_add_achievement("ach_071", "金刚不坏", "red", "减伤率达到70%", "runtime_stat", {"key": "damage_reduction", "value": 0.7, "bonus": {"initial_refresh": 1}, "bonus_text": "初始刷新次数 +1"})
	_add_achievement("ach_072", "琉璃护体", "red", "持有护盾的值超过当前血量的80%", "runtime_stat", {"key": "shield_ratio", "value": 0.8, "bonus": {"initial_refresh": 1}, "bonus_text": "初始刷新次数 +1"})
	_add_achievement("ach_073", "纹章收集", "gold", "通关时持有5个以上的纹章", "victory_stat", {"key": "emblem_count", "value": 5, "bonus": {"initial_lucky": 1}, "bonus_text": "初始天命 +1"})
	_add_achievement("ach_074", "万纹归宗", "red", "通关时纹章总级别超过25", "victory_stat", {"key": "emblem_total_level", "value": 25, "bonus": {"initial_refresh": 1}, "bonus_text": "初始刷新次数 +1"})
	_add_achievement("ach_075", "大道", "red", "通关时持有法则总层数超过100层", "victory_stat", {"key": "total_law_level", "value": 100, "bonus": {"initial_lock": 1}, "bonus_text": "初始锁定次数 +1"})
	_add_achievement("ach_076", "万军辟易", "gold", "敌人数量加成大于60%", "runtime_stat", {"key": "enemy_count_bonus", "value": 0.6, "bonus": {"initial_lucky": 1}, "bonus_text": "初始天命 +1"})
	_add_achievement("ach_077", "生生不息", "gold", "生命恢复超过10%", "runtime_stat", {"key": "hp_regen", "value": 10.0, "bonus": {"initial_lucky": 1}, "bonus_text": "初始天命 +1"})
	_add_achievement("ach_164", "天道", "red", "集齐三块天道碎片", "runtime_stat", {"key": "tiandao_fragments", "value": 3, "bonus": {"initial_lucky": 1}, "bonus_text": "初始天命 +1"})
	_add_threshold_group(161, "奇思妙想", ["壹", "贰", "叁"], ["blue", "purple", "gold"], "单局刷新次数超过%d次", [66, 88, 108], "run_stat", "level_up_refreshes", [ {"point": 0.01}, {"point": 0.015}, {"point": 0.02}], ["真气获取率 +1%", "真气获取率 +1.5%", "真气获取率 +2%"])
	_add_threshold_group(78, "惊鸿一击", ["壹", "贰", "叁", "肆", "伍"], ["white", "blue", "purple", "gold", "red"], "单次最高伤害达到%s", [1000000, 5000000, 30000000, 150000000, 400000000], "persistent_stat", "highest_single_damage", [ {"atk": 1}, {"atk": 2}, {"atk": 3}, {"atk": 4}, {"atk": 5}], ["初始攻击 +1", "初始攻击 +2", "初始攻击 +3", "初始攻击 +4", "初始攻击 +5"])
	_add_threshold_group(83, "降敌之道", ["壹", "贰", "叁", "肆", "伍"], ["white", "blue", "purple", "gold", "red"], "单局杀敌数量达到%d", [2000, 3500, 5000, 6500, 8000], "victory_stat", "kill_count", [ {"atk": 1}, {"atk": 2}, {"atk": 3}, {"atk": 4}, {"atk": 5}], ["初始攻击 +1", "初始攻击 +2", "初始攻击 +3", "初始攻击 +4", "初始攻击 +5"])
	_add_threshold_group(88, "苦修", ["壹", "贰", "叁", "肆", "伍", "陆", "柒"], ["white", "blue", "purple", "purple", "gold", "gold", "red"], "单项修炼提升到%d", [30, 50, 70, 90, 110, 130, 150], "meta_stat", "max_cultivation_level", [ {"hp": 10}, {"hp": 20}, {"hp": 30}, {"hp": 40}, {"hp": 50}, {"hp": 60}, {"hp": 70}], ["初始体力 +10", "初始体力 +20", "初始体力 +30", "初始体力 +40", "初始体力 +50", "初始体力 +60", "初始体力 +70"])
	_add_threshold_group(95, "天赋觉醒", ["壹", "贰", "叁", "肆", "伍"], ["white", "blue", "purple", "gold", "red"], "累计点过%d个天赋", [10, 25, 50, 75, 100], "meta_stat", "talent_points", [ {"hp": 10}, {"hp": 20}, {"hp": 30}, {"hp": 40}, {"hp": 50}], ["初始体力 +10", "初始体力 +20", "初始体力 +30", "初始体力 +40", "初始体力 +50"])
	_add_threshold_group(100, "商贾之道", ["壹", "贰", "叁", "肆", "伍", "陆", "柒"], ["white", "blue", "purple", "purple", "gold", "gold", "red"], "神秘商店达到%d级", [2, 3, 4, 5, 6, 7, 8], "meta_stat", "shop_level", [ {"point": 0.01}, {"point": 0.01}, {"point": 0.01}, {"point": 0.01}, {"point": 0.015}, {"point": 0.015}, {"point": 0.015}], ["真气获取率 +1%", "真气获取率 +1%", "真气获取率 +1%", "真气获取率 +1%", "真气获取率 +1.5%", "真气获取率 +1.5%", "真气获取率 +1.5%"])
	_add_achievement("ach_107", "慧眼识珠", "purple", "神秘商店刷新出一次红色级别的物品", "event_flag", {"flag": "red_shop_seen"})
	_add_threshold_group(108, "挥金如土", ["壹", "贰", "叁", "肆", "伍"], ["white", "blue", "purple", "gold", "red"], "在神秘商店累计花销%d灵石", [500, 2000, 5000, 10000, 20000], "persistent_stat", "shop_lingshi_spent")
	_add_threshold_group(113, "兵器谱", ["下", "中", "上"], ["blue", "purple", "gold"], "解锁武器%d个", [10, 14, 18], "meta_stat", "unlocked_weapon_count")
	_add_achievement("ach_116", "宗师", "gold", "单个武器达到18级", "runtime_stat", {"key": "max_weapon_level", "value": 18, "bonus": {"initial_ban": 1}, "bonus_text": "初始禁用次数 +1"})
	_add_threshold_group(117, "技能连携", ["下", "中", "上"], ["blue", "purple", "gold"], "单局内使用%d次主动技能", [40, 100, 200], "run_stat", "active_skill_uses", [ {"active_skill": 0.01}, {"active_skill": 0.01}, {"active_skill": 0.01}], ["主动技能伤害 +1%", "主动技能伤害 +1%", "主动技能伤害 +1%"])
	_add_threshold_group(120, "聚魄有道", ["下", "中", "上"], ["blue", "purple", "gold"], "通关时持有%d以上的精魄", [15000, 30000, 50000], "victory_stat", "spirit", [ {"point": 0.01}, {"point": 0.01}, {"point": 0.01}], ["真气获取率 +1%", "真气获取率 +1%", "真气获取率 +1%"])
	_add_threshold_group(123, "坚如磐石", ["下", "中", "上"], ["blue", "purple", "gold"], "护甲达到%d", [300, 600, 1000], "runtime_stat", "armor")
	_add_achievement("ach_126", "真意", "gold", "最终伤害超过200%", "runtime_stat", {"key": "final_damage", "value": 2, "bonus": {"initial_ban": 1}, "bonus_text": "初始禁用次数 +1"})
	_add_threshold_group(127, "功德圆满", ["壹", "贰", "叁", "肆", "伍", "陆"], ["white", "blue", "purple", "gold", "red", "red"], "成就数量达到%d个", [20, 40, 60, 80, 100, 120], "achievement_count", "completed_count", [ {"initial_lucky": 1}, {"initial_lucky": 1}, {"initial_lucky": 1}, {"initial_lucky": 1}, {"initial_lucky": 2}, {"initial_lucky": 2}], ["初始天命 +1", "初始天命 +1", "初始天命 +1", "初始天命 +1", "初始天命 +2", "初始天命 +2"])

func _add_law(id: String, name: String, rarity: String, prop: String, value: int, category: String, bonus_value: float, bonus_text: String) -> void:
	var bonus := {"weapon_damage": {LAW_DAMAGE_CATEGORIES.get(category, category): bonus_value}}
	_add_achievement(id, name, rarity, "%s层数达到%d" % [name.get_slice("·", 0), value], "law_level", {"prop": prop, "value": value, "bonus": bonus, "bonus_text": bonus_text})

func _add_threshold_group(start_index: int, base_name: String, suffixes: Array, rarities: Array, condition_template: String, values: Array, kind: String, key: String, bonuses: Array = [], bonus_texts: Array = []) -> void:
	for i in range(values.size()):
		var value = values[i]
		var condition_text := condition_template % value
		if base_name == "惊鸿一击":
			condition_text = condition_template % _format_damage_threshold(float(value))
		var data := {"key": key, "value": value}
		if i < bonuses.size():
			data["bonus"] = bonuses[i]
		if i < bonus_texts.size():
			data["bonus_text"] = bonus_texts[i]
		_add_achievement("ach_%03d" % (start_index + i), "%s·%s" % [base_name, suffixes[i]], rarities[i], condition_text, kind, data)

func _add_achievement(id: String, name: String, rarity: String, condition_text: String, kind: String, data: Dictionary) -> void:
	var achievement_data := data.duplicate(true)
	_apply_default_bonus_if_missing(achievement_data, rarity)
	definitions.append({
		"id": id,
		"name": name,
		"rarity": rarity,
		"condition_text": condition_text,
		"kind": kind,
		"data": achievement_data,
	})

func _apply_default_bonus_if_missing(data: Dictionary, rarity: String) -> void:
	if data.has("bonus"):
		return
	var is_high_rarity := rarity in ["purple", "gold", "red"]
	var id_seed := definitions.size()
	if id_seed % 2 == 0:
		var atk_bonus := 2 if is_high_rarity else 1
		data["bonus"] = {"atk": atk_bonus}
		data["bonus_text"] = "初始攻击 +%d" % atk_bonus
	else:
		var hp_bonus := 20 if is_high_rarity else 10
		data["bonus"] = {"hp": hp_bonus}
		data["bonus_text"] = "初始体力 +%d" % hp_bonus

func reset_run_stats() -> void:
	run_stats = {
		"damage_taken": 0.0,
		"active_skill_uses": 0,
		"level_up_refreshes": 0,
		"qi_vortex_purchases": 0,
		"red_shop_seen": false,
	}

func export_save_data() -> Dictionary:
	return {
		"unlocked_achievements": unlocked_achievements.duplicate(true),
		"pending_unlocked_achievements": pending_unlocked_achievements.duplicate(),
		"hero_clear_counts": hero_clear_counts.duplicate(true),
		"hero_pair_clear_counts": hero_pair_clear_counts.duplicate(true),
		"shop_lingshi_spent": shop_lingshi_spent,
		"highest_single_damage": highest_single_damage,
	}

func import_save_data(data: Dictionary) -> void:
	if definitions.is_empty():
		_build_definitions()
	unlocked_achievements = _sanitize_bool_dict(data.get("unlocked_achievements", {}))
	pending_unlocked_achievements = _sanitize_string_array(data.get("pending_unlocked_achievements", []))
	hero_clear_counts = _sanitize_int_dict(data.get("hero_clear_counts", {}))
	hero_pair_clear_counts = _sanitize_int_dict(data.get("hero_pair_clear_counts", {}))
	shop_lingshi_spent = int(data.get("shop_lingshi_spent", 0))
	highest_single_damage = float(data.get("highest_single_damage", 0.0))
	_invalidate_bonus_cache()
	_apply_unlock_side_effects()

func get_achievement_definitions() -> Array[Dictionary]:
	return definitions.duplicate(true)

func get_definition(achievement_id: String) -> Dictionary:
	return definitions_by_id.get(achievement_id, {})

func get_achievement_icon_path(achievement_data: Dictionary) -> String:
	var explicit_path := str(achievement_data.get("icon", ""))
	if explicit_path.is_empty():
		var data: Dictionary = achievement_data.get("data", {})
		explicit_path = str(data.get("icon", ""))
	if not explicit_path.is_empty() and ResourceLoader.exists(explicit_path):
		return explicit_path

	var achievement_name := str(achievement_data.get("name", "")).strip_edges()
	if not achievement_name.is_empty():
		var name_icon_path := "%s/%s.png" % [ACHIEVEMENT_ICON_DIR, achievement_name]
		if ResourceLoader.exists(name_icon_path):
			return name_icon_path

	if ResourceLoader.exists(DEFAULT_ACHIEVEMENT_ICON_PATH):
		return DEFAULT_ACHIEVEMENT_ICON_PATH
	return ""

func is_unlocked(achievement_id: String) -> bool:
	return unlocked_achievements.get(achievement_id, false) == true

func get_completed_count() -> int:
	return unlocked_achievements.size()

func get_total_count() -> int:
	return definitions.size()

func begin_unlock_batch() -> void:
	_is_batch_unlocking = true
	_save_after_batch = false

func end_unlock_batch(save_now: bool = true) -> void:
	_is_batch_unlocking = false
	if save_now and _save_after_batch:
		_save_after_batch = false
		Global.save_game()

func unlock(achievement_id: String, save_now: bool = true) -> bool:
	if is_unlocked(achievement_id):
		return false
	if not definitions_by_id.has(achievement_id):
		push_warning("AchievementManager: unknown achievement id %s" % achievement_id)
		return false
	unlocked_achievements[achievement_id] = true
	if not pending_unlocked_achievements.has(achievement_id):
		pending_unlocked_achievements.append(achievement_id)
	_invalidate_bonus_cache()
	_apply_single_unlock_side_effect(achievement_id)
	achievement_unlocked.emit(achievement_id, definitions_by_id[achievement_id])
	_check_achievement_count(false)
	if save_now:
		if _is_batch_unlocking:
			_save_after_batch = true
		else:
			Global.save_game()
	return true

func debug_unlock_next_achievement() -> bool:
	var did_unlock := false
	for definition in definitions:
		var achievement_id := str(definition.get("id", ""))
		if not is_unlocked(achievement_id):
			_is_debug_unlocking_sequential = true
			did_unlock = unlock(achievement_id, true)
			_is_debug_unlocking_sequential = false
			break
	_refresh_open_achievement_layer()
	return did_unlock

func debug_clear_all_achievements() -> void:
	unlocked_achievements.clear()
	pending_unlocked_achievements.clear()
	hero_clear_counts.clear()
	hero_pair_clear_counts.clear()
	shop_lingshi_spent = 0
	highest_single_damage = 0.0
	reset_run_stats()
	_invalidate_bonus_cache()
	var default_start_weapons: Array[String] = []
	for weapon_id in DEFAULT_START_WEAPONS:
		default_start_weapons.append(str(weapon_id))
	Global.available_start_weapons = default_start_weapons
	Global.selected_start_weapon = "SwordQi"
	Global.selected_start_weapons_by_hero.clear()
	Global.unlock_noam = Global.is_stage_cleared("ruin")
	Global.unlock_kansel = Global.is_stage_cleared("cave")
	Global.unlock_xueming = Global.is_stage_cleared("forest")
	Global.sync_available_start_weapons()
	_popup_queue.clear()
	_popup_is_playing = false
	_active_popup = null
	_popup_is_closing = false
	if is_instance_valid(_popup_layer):
		for child: Node in _popup_layer.get_children():
			child.queue_free()
	Global.save_game()
	_refresh_open_achievement_layer()

func _apply_unlock_side_effects() -> void:
	for achievement_id in unlocked_achievements.keys():
		_apply_single_unlock_side_effect(str(achievement_id))

func _apply_single_unlock_side_effect(achievement_id: String) -> void:
	var definition := get_definition(achievement_id)
	if definition.is_empty():
		return
	var data: Dictionary = definition.get("data", {})
	for hero_id in data.get("unlock_heroes", []):
		_unlock_hero(str(hero_id))
	if START_WEAPON_UNLOCKS.has(achievement_id):
		for weapon_id in START_WEAPON_UNLOCKS[achievement_id]:
			_add_start_weapon(str(weapon_id))
	Global.sync_available_start_weapons()

func _unlock_hero(hero_id: String) -> void:
	match hero_id:
		"noam":
			Global.unlock_noam = true
		"kansel":
			Global.unlock_kansel = true
		"xueming":
			Global.unlock_xueming = true

func _add_start_weapon(weapon_id: String) -> void:
	if weapon_id.is_empty():
		return
	var normalized_id := Global.normalize_start_weapon_id(weapon_id)
	if not Global.available_start_weapons.has(normalized_id):
		Global.available_start_weapons.append(normalized_id)

func get_unlocked_start_weapons() -> Array[String]:
	var weapons: Array[String] = []
	for achievement_id in unlocked_achievements.keys():
		var definition := get_definition(str(achievement_id))
		if definition.is_empty():
			continue
		if START_WEAPON_UNLOCKS.has(str(achievement_id)):
			for weapon_id in START_WEAPON_UNLOCKS[str(achievement_id)]:
				var normalized_id := Global.normalize_start_weapon_id(str(weapon_id))
				if not weapons.has(normalized_id):
					weapons.append(normalized_id)
	return weapons

func get_pending_and_clear() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for achievement_id in pending_unlocked_achievements:
		var definition := get_definition(achievement_id)
		if not definition.is_empty():
			result.append(definition)
	pending_unlocked_achievements.clear()
	Global.save_game()
	return result

func show_pending_popups() -> void:
	if not Global.in_town:
		return
	var pending := get_pending_and_clear()
	for achievement in pending:
		_enqueue_popup(achievement, false)

func _enqueue_popup(achievement_data: Dictionary, remove_pending: bool = true) -> void:
	if achievement_data.is_empty():
		return
	var achievement_id := str(achievement_data.get("id", ""))
	if remove_pending and not achievement_id.is_empty():
		pending_unlocked_achievements.erase(achievement_id)
	_popup_queue.append(achievement_data.duplicate(true))
	if not _popup_is_playing:
		call_deferred("_play_next_popup")

func _play_next_popup() -> void:
	if _popup_is_playing:
		return
	if _popup_queue.is_empty():
		_close_active_popup()
		return
	var layer: CanvasLayer = _get_popup_layer()
	if layer == null:
		_popup_is_playing = false
		return
	var popup_was_created := false
	if not is_instance_valid(_active_popup):
		_active_popup = ACHIEVEMENT_POP_UP_SCENE.instantiate()
		layer.add_child(_active_popup)
		popup_was_created = true
		_connect_popup_signals(_active_popup)
	var should_slide_in := popup_was_created or _popup_is_closing
	_popup_is_closing = false
	_popup_is_playing = true
	var achievement_data: Dictionary = _popup_queue.pop_front()
	if should_slide_in and _active_popup.has_method("show_achievement"):
		_active_popup.show_achievement(achievement_data, false)
	elif _active_popup.has_method("update_achievement"):
		_active_popup.update_achievement(achievement_data)
	elif _active_popup.has_method("show_achievement"):
		_active_popup.show_achievement(achievement_data, false)
	else:
		_on_popup_display_finished()

func _on_popup_display_finished() -> void:
	_popup_is_playing = false
	if not _popup_queue.is_empty():
		_play_next_popup()
	else:
		_close_active_popup()

func _on_popup_closed() -> void:
	_active_popup = null
	_popup_is_closing = false
	_popup_is_playing = false

func _connect_popup_signals(popup: Node) -> void:
	var display_callable := Callable(self , "_on_popup_display_finished")
	if popup.has_signal("display_finished") and not popup.is_connected("display_finished", display_callable):
		popup.connect("display_finished", display_callable)
	var finished_callable := Callable(self , "_on_popup_closed")
	if popup.has_signal("finished") and not popup.is_connected("finished", finished_callable):
		popup.connect("finished", finished_callable)

func _close_active_popup() -> void:
	if not is_instance_valid(_active_popup):
		_active_popup = null
		_popup_is_closing = false
		return
	if _popup_is_closing:
		return
	_popup_is_closing = true
	if _active_popup.has_method("close_popup"):
		_active_popup.close_popup()
	else:
		_active_popup.queue_free()
		_on_popup_closed()

func _refresh_open_achievement_layer() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var nodes := tree.get_nodes_in_group("achievement_layer")
	for node in nodes:
		if node != null and node.has_method("refresh"):
			node.refresh()

func _get_popup_layer() -> CanvasLayer:
	if is_instance_valid(_popup_layer):
		return _popup_layer
	_popup_layer = CanvasLayer.new()
	_popup_layer.name = "AchievementPopUpLayer"
	_popup_layer.layer = 120
	get_tree().root.add_child(_popup_layer)
	return _popup_layer

func record_stage_started() -> void:
	reset_run_stats()

func record_stage_result(snapshot: Dictionary) -> void:
	begin_unlock_batch()
	_record_hero_clear(snapshot)
	for definition in definitions:
		if is_unlocked(definition["id"]):
			continue
		if _is_definition_completed(definition, snapshot):
			unlock(definition["id"], false)
	_scan_law_level_achievements(false)
	_check_achievement_count(false)
	end_unlock_batch(true)

func record_stage_finished() -> void:
	begin_unlock_batch()
	_scan_non_victory_stage_achievements(false)
	_check_achievement_count(false)
	end_unlock_batch(true)

func _record_hero_clear(snapshot: Dictionary) -> void:
	var hero := str(snapshot.get("hero", PC.player_name))
	if hero.is_empty():
		return
	hero_clear_counts[hero] = int(hero_clear_counts.get(hero, 0)) + 1
	for pair in [["moning", "yiqiu"], ["noam", "kansel"]]:
		if pair.has(hero):
			var key := _hero_pair_key(pair)
			hero_pair_clear_counts[key] = int(hero_pair_clear_counts.get(key, 0)) + 1

func _hero_pair_key(heroes: Array) -> String:
	var sorted: Array[String] = []
	for hero in heroes:
		sorted.append(str(hero))
	sorted.sort()
	return "|".join(sorted)

func record_qi_vortex_purchase() -> void:
	run_stats["qi_vortex_purchases"] = int(run_stats.get("qi_vortex_purchases", 0)) + 1
	_scan_run_stats()

func record_level_up_refresh(count: int = 1) -> void:
	if count <= 0 or Global.in_town or PC.is_game_over:
		return
	run_stats["level_up_refreshes"] = int(run_stats.get("level_up_refreshes", 0)) + count
	_scan_run_stats()

func record_active_skill_used(_skill_id: String) -> void:
	if Global.in_town or PC.is_game_over:
		return
	run_stats["active_skill_uses"] = int(run_stats.get("active_skill_uses", 0)) + 1
	_scan_run_stats()

func record_shop_purchase(cost_resource: String, cost: int, _rarity: String = "") -> void:
	if cost_resource != "lingshi" or cost <= 0:
		return
	shop_lingshi_spent += cost
	_scan_persistent_stats()
	Global.save_game()

func record_shop_roll(offers: Array) -> void:
	for offer in offers:
		if typeof(offer) == TYPE_DICTIONARY and str((offer as Dictionary).get("rarity", "")) == "red":
			unlock("ach_107")
			return

func scan_meta_progress(save_now: bool = true) -> void:
	begin_unlock_batch()
	for definition in definitions:
		if is_unlocked(definition["id"]):
			continue
		var kind := str(definition.get("kind", ""))
		if kind in ["meta_stat", "achievement_count"]:
			if _is_definition_completed(definition, {}):
				unlock(definition["id"], false)
	_check_achievement_count(false)
	end_unlock_batch(save_now)

func scan_runtime_progress(save_now: bool = false) -> void:
	begin_unlock_batch()
	for definition in definitions:
		if is_unlocked(definition["id"]):
			continue
		var kind := str(definition.get("kind", ""))
		if kind == "runtime_stat":
			if _is_definition_completed(definition, {}):
				unlock(definition["id"], false)
	_check_achievement_count(false)
	end_unlock_batch(save_now)

func scan_runtime_keys(keys: Array[String], save_now: bool = false) -> void:
	var key_set := {}
	for key in keys:
		key_set[str(key)] = true
	if key_set.is_empty():
		return
	begin_unlock_batch()
	for definition in definitions:
		if is_unlocked(definition["id"]):
			continue
		if str(definition.get("kind", "")) != "runtime_stat":
			continue
		var data: Dictionary = definition.get("data", {})
		if key_set.has(str(data.get("key", ""))) and _is_definition_completed(definition, {}):
			unlock(definition["id"], false)
	_check_achievement_count(false)
	end_unlock_batch(save_now)

func _scan_law_level_achievements(save_now: bool = false) -> void:
	for definition in definitions:
		if is_unlocked(definition["id"]):
			continue
		if str(definition.get("kind", "")) == "law_level" and _is_definition_completed(definition, {}):
			unlock(definition["id"], save_now)

func _scan_non_victory_stage_achievements(save_now: bool = false) -> void:
	for definition in definitions:
		if is_unlocked(definition["id"]):
			continue
		var kind := str(definition.get("kind", ""))
		if kind in ["law_level", "run_stat", "runtime_stat", "persistent_stat"]:
			if _is_definition_completed(definition, {}):
				unlock(definition["id"], save_now)

func _scan_run_stats() -> void:
	begin_unlock_batch()
	for definition in definitions:
		if is_unlocked(definition["id"]):
			continue
		if str(definition.get("kind", "")) == "run_stat" and _is_definition_completed(definition, {}):
			unlock(definition["id"], false)
	_check_achievement_count(false)
	end_unlock_batch(false)

func _scan_persistent_stats() -> void:
	begin_unlock_batch()
	for definition in definitions:
		if is_unlocked(definition["id"]):
			continue
		if str(definition.get("kind", "")) == "persistent_stat" and _is_definition_completed(definition, {}):
			unlock(definition["id"], false)
	_check_achievement_count(false)
	end_unlock_batch(false)

func _on_player_hit(damage_val = 0.0, shield_val = 0.0, _attacker = null, _world_position = Vector2.ZERO, _source_name: String = "") -> void:
	if Global.in_town:
		return
	var damage_taken := _get_positive_number(damage_val) + _get_positive_number(shield_val)
	if damage_taken <= 0.0:
		return
	run_stats["damage_taken"] = float(run_stats.get("damage_taken", 0.0)) + damage_taken
	_scan_run_stats()

func _on_monster_damage(_popup_type = 0, damage_value = 0.0, _world_position = Vector2.ZERO, _weapon_name: String = "") -> void:
	var parsed_damage := _get_positive_number(damage_value)
	if parsed_damage <= highest_single_damage:
		return
	highest_single_damage = parsed_damage
	_scan_persistent_stats()

func _get_positive_number(value) -> float:
	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			return max(0.0, float(value))
		_:
			return 0.0

func _is_definition_completed(definition: Dictionary, snapshot: Dictionary) -> bool:
	var kind := str(definition.get("kind", ""))
	var data: Dictionary = definition.get("data", {})
	match kind:
		"stage_clear":
			return snapshot.get("stage_id", "") == data.get("stage", "")
		"difficulty_clear":
			return snapshot.get("difficulty", "") == data.get("difficulty", "")
		"core_clear":
			return snapshot.get("difficulty", "") == "core" and int(snapshot.get("core_depth", 0)) >= int(data.get("depth", 0))
		"poetry_clear":
			return snapshot.get("difficulty", "") == "poetry" and snapshot.get("stage_id", "") == data.get("stage", "")
		"hero_clear_count":
			return int(hero_clear_counts.get(str(data.get("hero", "")), 0)) >= int(data.get("count", 0))
		"hero_pair_clear_count":
			return int(hero_pair_clear_counts.get(_hero_pair_key(data.get("heroes", [])), 0)) >= int(data.get("count", 0))
		"law_level":
			return int(PC.get(str(data.get("prop", "")))) >= int(data.get("value", 0))
		"run_stat":
			return _get_run_stat_value(str(data.get("key", ""))) >= float(data.get("value", 0))
		"victory_stat":
			return _compare(float(snapshot.get(str(data.get("key", "")), 0.0)), str(data.get("op", ">=")), float(data.get("value", 0.0)))
		"victory_flag":
			return snapshot.get(str(data.get("key", "")), false) == true
		"runtime_stat":
			return _get_runtime_stat_value(str(data.get("key", ""))) >= float(data.get("value", 0.0))
		"persistent_stat":
			return _get_persistent_stat_value(str(data.get("key", ""))) >= float(data.get("value", 0.0))
		"meta_stat":
			return _get_meta_stat_value(str(data.get("key", ""))) >= float(data.get("value", 0.0))
		"event_flag":
			return run_stats.get(str(data.get("flag", "")), false) == true
		"achievement_count":
			return get_completed_count() >= int(data.get("value", 0))
		_:
			return false

func _compare(actual: float, op: String, expected: float) -> bool:
	match op:
		"<=":
			return actual <= expected
		"<":
			return actual < expected
		">":
			return actual > expected
		_:
			return actual >= expected

func _get_run_stat_value(key: String) -> float:
	return float(run_stats.get(key, 0.0))

func _get_persistent_stat_value(key: String) -> float:
	match key:
		"highest_single_damage":
			return highest_single_damage
		"shop_lingshi_spent":
			return float(shop_lingshi_spent)
		_:
			return 0.0

func _get_meta_stat_value(key: String) -> float:
	match key:
		"max_cultivation_level":
			return float(_get_max_cultivation_level())
		"talent_points":
			return float(_get_talent_points())
		"shop_level":
			return float(Global.shop_level)
		"unlocked_weapon_count":
			return float(get_unlocked_weapon_count())
		_:
			return 0.0

func _get_runtime_stat_value(key: String) -> float:
	match key:
		"spirit":
			return float(PC.spirit)
		"lucky":
			return float(PC.get_lucky_level())
		"ur_rewards":
			return float(_count_ur_rewards())
		"atk_speed":
			return PC.get_total_attack_speed_bonus()
		"move_speed":
			return _get_total_move_speed_bonus()
		"damage_reduction":
			return PC.damage_reduction_rate
		"shield_ratio":
			if PC.pc_hp <= 0:
				return 0.0
			return float(PC.get_total_shield()) / float(PC.pc_hp)
		"enemy_count_bonus":
			return _get_enemy_count_bonus()
		"hp_regen":
			return PC.pc_hp_regen
		"tiandao_fragments":
			return float(_count_tiandao_fragments())
		"max_weapon_level":
			return float(_get_max_weapon_level())
		"armor":
			return PC.pc_armor
		"final_damage":
			return 1.0 + Faze.get_final_damage_additive_bonus()
		_:
			return 0.0

func _get_total_move_speed_bonus() -> float:
	return PC.get_total_move_speed_bonus()

func _get_enemy_count_bonus() -> float:
	var bonus := 0.0
	for id in PC.selected_rewards:
		match str(id):
			"UR39":
				bonus += 0.09
			"SSR39":
				bonus += 0.07
			"SR39":
				bonus += 0.06
			"R39":
				bonus += 0.05
			"SSR48":
				bonus += 0.12
			"SR48":
				bonus += 0.10
			"R48":
				bonus += 0.08
			"SSR49":
				bonus += 0.15
			"SR49":
				bonus += 0.10
			"R49":
				bonus += 0.08
			"SSR50":
				bonus += 0.12
			"SR50":
				bonus += 0.10
			"R50":
				bonus += 0.08
			"SSR53":
				bonus += 0.12
			"SR53":
				bonus += 0.08
			"R53":
				bonus += 0.05
	return bonus

func _count_ur_rewards() -> int:
	var count := 0
	for reward_id in PC.selected_rewards:
		if str(reward_id).begins_with("UR"):
			count += 1
	return count

func _count_tiandao_fragments() -> int:
	var count := 0
	for reward_id in ["UR46", "UR47", "UR48"]:
		if PC.selected_rewards.has(reward_id):
			count += 1
	return count

func _get_max_weapon_level() -> int:
	if Global.current_stage_difficulty == Global.STAGE_DIFFICULTY_POETRY:
		return _get_poetry_max_weapon_level()
	var max_level := 0
	for weapon_id in WEAPON_LEVEL_PROPS.keys():
		max_level = maxi(max_level, int(PC.get(str(WEAPON_LEVEL_PROPS[weapon_id]))))
	return max_level

func _get_poetry_max_weapon_level() -> int:
	var loadout: Dictionary = PC.poetry_loadout
	if loadout.is_empty():
		return 0
	var max_level := 0
	if str(loadout.get("w12_id", "")) != "":
		max_level = maxi(max_level, 12)
	for weapon_id in loadout.get("w3_ids", []):
		if str(weapon_id) != "":
			max_level = maxi(max_level, 3)
	return max_level

func _get_max_cultivation_level() -> int:
	var levels := [
		Global.cultivation_poxu_level,
		Global.cultivation_xuanyuan_level,
		Global.cultivation_liuguang_level,
		Global.cultivation_hualing_level,
		Global.cultivation_fengrui_level,
		Global.cultivation_huti_level,
		Global.cultivation_zhuifeng_level,
		Global.cultivation_liejin_level,
	]
	var max_level := 0
	for level in levels:
		max_level = maxi(max_level, int(level))
	return max_level

func _get_talent_points() -> int:
	var total := 0
	for value in Global.player_study_tree.values():
		total += int(value)
	return total

func get_unlocked_weapon_count() -> int:
	if PlayerRewardWeights != null and PlayerRewardWeights.has_method("get_available_weapon_factions"):
		return PlayerRewardWeights.get_available_weapon_factions().size()
	return DEFAULT_START_WEAPONS.size()

func _check_achievement_count(save_now: bool = false) -> void:
	if _is_debug_unlocking_sequential:
		return
	for definition in definitions:
		if is_unlocked(definition["id"]):
			continue
		if str(definition.get("kind", "")) == "achievement_count" and _is_definition_completed(definition, {}):
			unlock(definition["id"], save_now)

func build_victory_snapshot(stage_id: String, difficulty: String, core_depth: int, boss_defeat_time: float, kill_count: int, highest_dps: float, lost_hp: float, point: int, spirit: int, ten_step_boss_killed: bool = false) -> Dictionary:
	return {
		"stage_id": stage_id,
		"difficulty": difficulty,
		"core_depth": core_depth,
		"boss_defeat_time": boss_defeat_time,
		"ten_step_boss_killed": ten_step_boss_killed,
		"kill_count": kill_count,
		"highest_dps": highest_dps,
		"lost_hp": lost_hp,
		"point": point,
		"spirit": spirit,
		"hero": PC.player_name,
		"weapon_count": PC.current_weapon_num,
		"emblem_count": PC.current_emblems.size(),
		"emblem_total_level": _sum_dictionary_values(PC.current_emblems),
		"total_law_level": _get_total_law_level(),
	}

func _sum_dictionary_values(data: Dictionary) -> int:
	var total := 0
	for value in data.values():
		total += int(value)
	return total

func _get_total_law_level() -> int:
	var props := [
		"faze_blood_level",
		"faze_sword_level",
		"faze_thunder_level",
		"faze_heal_level",
		"faze_summon_level",
		"faze_shield_level",
		"faze_fire_level",
		"faze_destroy_level",
		"faze_life_level",
		"faze_bullet_level",
		"faze_wide_level",
		"faze_bagua_level",
		"faze_treasure_level",
		"faze_chaos_level",
		"faze_skill_level",
		"faze_sixsense_level",
		"faze_wind_level",
		"faze_deep_level",
		"faze_shehun_level",
	]
	var total := 0
	for prop in props:
		total += int(PC.get(prop))
	return total

func get_bonus_summary() -> Dictionary:
	if _bonus_summary_cache_valid:
		return _bonus_summary_cache
	var summary := _empty_bonus_summary()
	var point_count := get_achievement_points()
	var per_point := [
		{"atk": 1.0},
		{"hp": 10.0},
		{"armor": 1.0},
		{"final_damage": 0.002},
		{"point": 0.004},
		{"exp": 0.002},
		{"spirit": 0.002},
		{"drop": 0.001},
	]
	for i in range(point_count):
		_merge_bonus(summary, per_point[i % per_point.size()])
	for achievement_id in unlocked_achievements.keys():
		var definition := get_definition(str(achievement_id))
		if definition.is_empty():
			continue
		var bonus: Dictionary = definition.get("data", {}).get("bonus", {})
		_merge_bonus(summary, bonus)
	_bonus_summary_cache = summary
	_bonus_summary_cache_valid = true
	return _bonus_summary_cache

func get_achievement_points() -> int:
	if _achievement_points_cache_valid:
		return _achievement_points_cache
	var total := 0
	for achievement_id in unlocked_achievements.keys():
		var definition := get_definition(str(achievement_id))
		total += int(RARITY_POINTS.get(str(definition.get("rarity", "white")), 0))
	_achievement_points_cache = total
	_achievement_points_cache_valid = true
	return _achievement_points_cache

func _invalidate_bonus_cache() -> void:
	_bonus_summary_cache.clear()
	_bonus_summary_cache_valid = false
	_achievement_points_cache = 0
	_achievement_points_cache_valid = false
	SettingStudyTreeUp.invalidate_total_damage_bonus_cache()

func _empty_bonus_summary() -> Dictionary:
	return {
		"atk": 0.0,
		"hp": 0.0,
		"armor": 0.0,
		"final_damage": 0.0,
		"point": 0.0,
		"exp": 0.0,
		"spirit": 0.0,
		"drop": 0.0,
		"active_skill": 0.0,
		"weapon_damage": {},
	}

func _merge_bonus(target: Dictionary, bonus: Dictionary) -> void:
	for key in bonus.keys():
		if key == "weapon_damage":
			var weapon_damage: Dictionary = bonus[key]
			for category in weapon_damage.keys():
				var current := float(target["weapon_damage"].get(category, 0.0))
				target["weapon_damage"][category] = current + float(weapon_damage[category])
		else:
			target[key] = float(target.get(key, 0.0)) + float(bonus[key])

func get_weapon_damage_bonus(category: String) -> float:
	var summary := get_bonus_summary()
	return float(summary.get("weapon_damage", {}).get(category, 0.0))

func get_category_damage_bonus_by_weapon_tag(weapon_tag: String) -> float:
	var summary := get_bonus_summary()
	var weapon_damage: Dictionary = summary.get("weapon_damage", {})
	var categories: Array = SettingStudyTreeUp.WEAPON_CATEGORY_MAP.get(weapon_tag, [])
	var bonus := 0.0
	for category in categories:
		bonus += float(weapon_damage.get(str(category), 0.0))
	if bool(categories.has("wide")):
		bonus += float(weapon_damage.get("blood", 0.0))
	if bool(categories.has("heal")):
		bonus += float(weapon_damage.get("heal", 0.0))
	if bool(categories.has("protect")):
		bonus += float(weapon_damage.get("protect", 0.0))
	return bonus

func get_summon_damage_bonus() -> float:
	return get_weapon_damage_bonus("summon")

func get_active_skill_damage_bonus() -> float:
	return float(get_bonus_summary().get("active_skill", 0.0))

func get_initial_refresh_bonus() -> int:
	return _get_initial_bonus("initial_refresh")

func get_initial_lock_bonus() -> int:
	return _get_initial_bonus("initial_lock")

func get_initial_ban_bonus() -> int:
	return _get_initial_bonus("initial_ban")

func get_initial_lucky_bonus() -> int:
	return _get_initial_bonus("initial_lucky")

func _get_initial_bonus(key: String) -> int:
	return int(round(float(get_bonus_summary().get(key, 0.0))))

func get_detail_text() -> String:
	var summary := get_bonus_summary()
	return "[color=yellow]完成度[/color]  %d / %d\n[color=yellow]成就点[/color]  %d\n[color=yellow]成就加成[/color]\n攻击 %d\n最大体力 %d\n护甲 %d\n最终伤害 %s\n主动技能伤害 %s\n真气获取率 %s\n经验获取率 %s\n精魄获取率 %s\n掉落率 %s" % [
		get_completed_count(),
		get_total_count(),
		get_achievement_points(),
		int(round(summary["atk"])),
		int(round(summary["hp"])),
		int(round(summary["armor"])),
		_format_percent(float(summary["final_damage"])),
		_format_percent(float(summary["active_skill"])),
		_format_percent(float(summary["point"])),
		_format_percent(float(summary["exp"])),
		_format_percent(float(summary["spirit"])),
		_format_percent(float(summary["drop"])),
	]

func get_unlock_text(achievement_id: String) -> String:
	var definition := get_definition(achievement_id)
	if definition.is_empty():
		return ""
	var data: Dictionary = definition.get("data", {})
	var parts: Array[String] = []
	var unlock_text := str(data.get("unlock_text", ""))
	if not unlock_text.is_empty():
		parts.append(unlock_text)
	var bonus_text := str(data.get("bonus_text", ""))
	if not bonus_text.is_empty():
		parts.append(bonus_text)
	return "\n".join(parts)

func _format_percent(value: float) -> String:
	var percent := value * 100.0
	if is_equal_approx(percent, round(percent)):
		return "%d%%" % int(round(percent))
	return "%.1f%%" % percent

func _format_damage_threshold(value: float) -> String:
	if value >= 1000000.0:
		return "%dm" % int(value / 1000000.0)
	if value >= 1000.0:
		return "%dk" % int(value / 1000.0)
	return str(int(value))

func _sanitize_bool_dict(value) -> Dictionary:
	var result := {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for key in value.keys():
		if value[key] == true:
			result[str(key)] = true
	return result

func _sanitize_int_dict(value) -> Dictionary:
	var result := {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for key in value.keys():
		result[str(key)] = int(value[key])
	return result

func _sanitize_string_array(value) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		var text := str(item)
		if not text.is_empty() and not result.has(text):
			result.append(text)
	return result
