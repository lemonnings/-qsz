extends Node

signal collection_changed

const CATEGORY_FRIEND := "friend"
const CATEGORY_ENEMY := "yao"
const CATEGORY_ITEM := "wu"
const CATEGORY_BATTLE := "battle"

const RARITY_POINTS := {
	"white": 2,
	"blue": 3,
	"purple": 4,
	"gold": 5,
	"red": 6,
}

const RARITY_COLORS := {
	"white": Color(0.92, 0.92, 0.92, 1.0),
	"blue": Color(0.35, 0.62, 1.0, 1.0),
	"purple": Color(0.72, 0.38, 1.0, 1.0),
	"gold": Color(1.0, 0.78, 0.22, 1.0),
	"red": Color(1.0, 0.32, 0.28, 1.0),
}

const DEFAULT_TOWN_ICON := "res://AssetBundle/Sprites/town/temp.png"
const DEFAULT_ENEMY_ICON := "res://AssetBundle/Sprites/town/temp.png"

const ENEMY_SCENE_PATH_OVERRIDES := {
	"boss_a": "res://Scenes/moster/boss_test1.tscn",
	"boss_b": "res://Scenes/moster/boss_cansel.tscn",
	"boss_stone": "res://Scenes/moster/boss_stone.tscn",
	"boss_stele": "res://Scenes/moster/boss_stele.tscn",
	"boss_panguan": "res://Scenes/moster/boss_panguan.tscn",
}

const STAGE_NAMES := {
	"peach_grove": "桃林",
	"ruin": "古迹",
	"cave": "深窟",
	"forest": "密林",
	"difu": "九幽冥府",
}

const ITEM_RARITY_MAP := {
	"common": "white",
	"rare": "blue",
	"epic": "purple",
	"legend": "gold",
	"legendary": "gold",
	"artifact": "red",
	"white": "white",
	"blue": "blue",
	"purple": "purple",
	"gold": "gold",
	"red": "red",
}

const REWARD_RARITY_MAP := {
	"white": "white",
	"skyblue": "blue",
	"blue": "blue",
	"darkorchid": "purple",
	"purple": "purple",
	"gold": "gold",
	"red": "red",
}

const LAW_NAME_TO_ID := {
	"浴血": "law_blood",
	"刀剑": "law_sword",
	"鸣雷": "law_thunder",
	"雷鸣": "law_thunder",
	"愈疗": "law_heal",
	"御灵": "law_summon",
	"护佑": "law_shield",
	"炽焰": "law_fire",
	"破坏": "law_destroy",
	"生灵": "law_life",
	"弹雨": "law_bullet",
	"啸风": "law_wind",
	"广域": "law_wide",
	"八卦": "law_bagua",
	"六识": "law_liushi",
	"宝器": "law_treasure",
	"沉渊": "law_deep",
	"摄魂": "law_shehun",
	"混沌": "law_chaos",
}

const CHAOS_SOURCE_LAW_IDS := [
	"law_blood",
	"law_sword",
	"law_thunder",
	"law_heal",
	"law_summon",
	"law_shield",
	"law_fire",
	"law_destroy",
	"law_life",
	"law_bullet",
	"law_wide",
	"law_bagua",
	"law_treasure",
	"law_deep",
	"law_shehun",
	"law_liushi",
	"law_wind",
]

const WEAPON_FACTIONS := [
	"BloodBoardSword",
	"Bloodwave",
	"Branch",
	"DragonWind",
	"Duize",
	"Genshan",
	"HolyLight",
	"Ice",
	"LightBullet",
	"Moyan",
	"Qiankun",
	"Qigong",
	"RingFire",
	"Riyan",
	"SoulSickle",
	"SwordQi",
	"Thunder",
	"ThunderBreak",
	"ThunderGun",
	"Water",
	"Xuanwu",
	"Xunfeng",
	"Yujian",
	"Zhuazhuajuchui",
]

const FRIEND_DEFINITIONS := [
	{"id": "friend_moning", "name": "墨宁", "age": "14岁", "icon": "res://AssetBundle/Sprites/town/moning.png", "display_texture": "res://AssetBundle/Sprites/new_character/moning_idle.png", "unlock": "global_bool:unlock_moning"},
	{"id": "friend_yiqiu", "name": "言秋", "age": "10岁", "icon": "res://AssetBundle/Sprites/town/yiqiu.png", "display_texture": "res://AssetBundle/Sprites/new_character/yanqiu_idle.png", "unlock": "global_bool:unlock_yiqiu"},
	{"id": "friend_noam", "name": "诺姆", "age": "11岁", "icon": "res://AssetBundle/Sprites/town/noam.png", "display_texture": "res://AssetBundle/Sprites/new_character/noam_idle.png", "unlock": "global_bool:unlock_noam"},
	{"id": "friend_kansel", "name": "坎塞尔", "age": "16岁", "icon": "res://AssetBundle/Sprites/town/kansel.png", "display_texture": "res://AssetBundle/Sprites/new_character/kansel_idle.png", "unlock": "global_bool:unlock_kansel"},
	{"id": "friend_xueming", "name": "雪铭", "age": "14岁", "icon": "res://AssetBundle/Sprites/town/xueming.png", "display_texture": "res://AssetBundle/Sprites/new_character/xueming_idle.png", "unlock": "global_bool:unlock_xueming"},
	{"id": "friend_qian", "name": "乾", "age": "811岁", "icon": DEFAULT_TOWN_ICON, "display_texture": "res://AssetBundle/Sprites/new_character/qian_idle.png", "unlock": "always"},
	{"id": "friend_kun", "name": "坤", "age": "809岁", "icon": DEFAULT_TOWN_ICON, "display_texture": "res://AssetBundle/Sprites/new_character/kun_idle.png", "unlock": "story:has_seen_story_2"},
	{"id": "friend_xun", "name": "巽", "age": "287岁", "icon": DEFAULT_TOWN_ICON, "display_texture": "res://AssetBundle/Sprites/new_character/xun_idle.png", "unlock": "always"},
	{"id": "friend_zhen", "name": "震", "age": "452岁", "icon": DEFAULT_TOWN_ICON, "display_texture": "res://AssetBundle/Sprites/new_character/zhen_idle.png", "unlock": "story:has_seen_story_3"},
	{"id": "friend_kan", "name": "坎", "age": "据本人说只有200多岁！", "icon": DEFAULT_TOWN_ICON, "display_texture": "res://AssetBundle/Sprites/new_character/kan_idle.png", "unlock": "story:has_seen_story_4"},
	{"id": "friend_bard", "name": "异国诗人", "age": "？？", "icon": DEFAULT_TOWN_ICON, "display_texture": "res://AssetBundle/Sprites/new_character/bard_idle.png", "unlock": "story:has_seen_story_6"},
]

const ENEMY_DEFINITIONS := [
	{"id": "enemy_slime_blue", "monster_id": "slime_blue", "name": "叶精", "rarity": "blue", "stages": ["peach_grove"], "skills": ["打击 - 接触造成伤害"]},
	{"id": "enemy_peach_yao", "monster_id": "peach_yao", "drop_id": "taohua_yao", "name": "桃花妖", "rarity": "blue", "stages": ["peach_grove"], "skills": ["打击 - 接触造成伤害"]},
	{"id": "enemy_frog", "monster_id": "frog", "name": "幼体树精", "rarity": "blue", "stages": ["peach_grove"], "skills": ["远程攻击 - 发射弹体造成伤害"]},
	{"id": "enemy_copper", "monster_id": "copper", "name": "铜兽", "rarity": "purple", "stages": ["peach_grove", "cave", "forest"], "skills": ["冲撞 - 接触造成伤害"]},
	{"id": "enemy_lantern", "monster_id": "lantern", "name": "灯笼精", "rarity": "blue", "stages": ["ruin", "difu"], "skills": ["打击 - 接触造成伤害"]},
	{"id": "enemy_paper", "monster_id": "paper", "name": "宣纸精", "rarity": "blue", "stages": ["ruin", "difu"], "skills": ["打击 - 接触造成伤害"]},
	{"id": "enemy_bat", "monster_id": "bat", "name": "草药精", "rarity": "blue", "stages": ["ruin"], "skills": ["远程攻击 - 发射弹体造成伤害"]},
	{"id": "enemy_slime_grey", "monster_id": "slime_grey", "name": "粘液怪", "rarity": "purple", "stages": ["ruin"], "skills": ["冲锋撞击 - 冲锋，接触造成伤害"]},
	{"id": "enemy_gu_insect", "monster_id": "gu_insect", "name": "蛊虫", "rarity": "purple", "stages": ["ruin", "cave", "forest"], "skills": ["蛊毒 - 对十字直线区域造成伤害"]},
	{"id": "enemy_ghost", "monster_id": "ghost", "name": "幽魂", "rarity": "purple", "stages": ["cave", "difu"], "skills": ["远程攻击 - 发射弹体造成伤害"]},
	{"id": "enemy_armor_stone", "monster_id": "armor_stone", "name": "甲石", "rarity": "blue", "stages": ["cave"], "skills": ["打击 - 接触造成伤害"]},
	{"id": "enemy_stone_man", "monster_id": "stone_man", "name": "小石头精", "rarity": "purple", "stages": ["cave"], "skills": ["冲锋重击 - 冲锋接触造成伤害"]},
	{"id": "enemy_slime", "monster_id": "slime", "drop_id": "slime_green", "name": "毒蛙", "rarity": "blue", "stages": ["cave", "forest"], "skills": ["打击 - 接触造成伤害"]},
	{"id": "enemy_shen", "monster_id": "shen", "name": "狂暴者", "rarity": "blue", "stages": ["forest"], "skills": ["打击 - 接触造成伤害"]},
	{"id": "enemy_frog_new", "monster_id": "frog_new", "name": "林蛙", "rarity": "blue", "stages": ["forest"], "skills": ["远程攻击 - 发射弹体造成伤害"]},
	{"id": "enemy_ball", "monster_id": "ball", "name": "荆棘精", "rarity": "purple", "stages": ["forest"], "skills": ["弹跳 - 造成范围伤害"]},
	{"id": "enemy_youling", "monster_id": "youling", "name": "冥魂", "rarity": "blue", "stages": ["difu"], "skills": ["打击 - 接触造成伤害"]},
	{"id": "boss_peach_grove", "monster_id": "boss_a", "name": "桃树精王", "rarity": "red", "stages": ["peach_grove"], "skills": ["核心机制 · 落花 - 首领开局会释放落花，之后每隔数次技能会再次释放。落花会从场地上方持续飘落，触碰到角色会受到伤害；重复释放后花瓣数量会提升，高难度下还会出现金色花瓣，碰到后不会受伤，并且会附加解毒状态。", "荆棘之刺 - 连续多次瞄准角色方向释放直线荆棘攻击", "分裂荆棘 - 连续多次瞄准角色方向释放三条分裂荆棘攻击", "荆棘遍布 - 以首领为中心，向八个方向释放荆棘攻击", "冲锋 - 锁定角色方向进行高速冲锋，冲锋前会显示预警", "花雨 - 首领向周围连续发射大量花瓣弹幕，触碰到会受到伤害", "盛放之棘 - 在角色附近连续生成多个落点预警，短暂延迟后爆发荆棘造成伤害", "剧毒之棘 - 在角色附近连续生成多个落点预警，爆发后留下持续伤害的毒圈；高难度下毒圈会永久存在，需要角色处于解毒状态中踩上去才能消除", "诗想难度特殊机制 · 落棘 - 首领释放部分技能时，会在角色两侧额外生成多枚盛放之棘"]},
	{"id": "boss_ruin", "monster_id": "boss_stone", "name": "石巨人", "rarity": "red", "stages": ["ruin"], "skills": ["核心机制 · 石甲 - 首领会根据不同难度，获得不同层数的石甲，每层石甲减少其受到伤害 10 %", "核心机制 · 巨石 - 首领的部分技能会生成巨石，巨石视作障碍物，可以反弹首领发射的光弹术，可被首领冲撞撞碎，被撞碎后，首领的石甲层数会减少 1 层。如果新的巨石与原有的巨石重叠，两个巨石均会破裂，并且附近大范围会变为泥沼持续伤害区域。", "滚石 - 召唤若干横向滚动的滚石，被撞到会受到中等伤害", "落石 - 对首领脚下及角色脚下生成巨石", "拍击 - 扇形连续攻击", "震地 - 首领连续多次对周围造成伤害，范围逐渐增大", "掀地 - 对大范围扇形造成伤害，并生成泥沼伤害区域", "冲锋 - 瞄准角色方向进行连续冲锋，撞到巨石后会减速并损失 1 层石甲", "石头发光？ - 准备进行环形光弹术攻击", "石头发光！ - 连续进行多轮环形光弹术攻击，巨石可以阻挡光弹术并将光弹术弹射出去", "落石预兆 - 首领会连续给予角色多层不同持续时间的落石预警异常状态，落石预警倒计时结束后，会在角色脚下生成警告圈，1 秒后会落下巨石"]},
	{"id": "boss_cave", "monster_id": "boss_b", "name": "神秘人", "rarity": "red", "stages": ["cave"], "skills": ["核心机制 · 冰火 - 当触碰到燃星或霜星后，会被赋予燃烧或缓速状态，身上有燃烧状态时，碰到霜星后会解除燃烧状态并恢复血量；身上有缓速状态时，碰到燃星后会解除缓速状态并恢复血量", "爆炎 - 在角色脚下生成火焰警告圈，爆炸后喷射出若干个燃星", "冰封 - 以首领为中心，大范围冰霜爆发，爆炸后喷射出若干个霜星", "环雷 - 以首领为中心释放巨大的环形雷电攻击，内圈安全", "炽焰十字 - 以首领为中心释放十字形火焰攻击", "霜牙交错 - 以首领为中心释放X字形冰霜攻击", "冰刺术 - 扇形生成多枚悬浮冰刺，短暂延迟后高速向外射出", "三连咏唱 - 进行咏唱，连续随机使用爆炎、冰封、环雷、炽焰十字、霜牙交错其中的三个，具体将会释放的技能会在首领头顶悬浮显示。诗想难度下，单轮咏唱会同时释放两个技能", "耀星 - 从场地边缘生成网格状不断推进的地火，具有方向箭头预警", "诗想难度特殊机制 · 星火蓄力/灵冰蓄力、核爆/玄冰 - 需要角色积累相等层数的相反状态来抵消秒杀攻击，如果首领进行了星火蓄力，会释放玄冰；如果首领进行了灵冰蓄力，会释放核爆；其中，星火蓄力和灵冰蓄力会分为I和II两档，档位越高，咏唱的核爆/玄冰的档位就会越高"]},
	{"id": "boss_forest", "monster_id": "boss_stele", "name": "被封印的石碑", "rarity": "red", "stages": ["forest"], "skills": ["核心机制 · 拘束 - 血量下降到特定比例（90%、55%、20%）时会生成紫色的拘束圈。踩入拘束圈范围内会获得大幅减伤但同时大幅降低输出。两个拘束圈过近会引发致命的联结爆炸。", "腐蚀风暴 - 长读条全屏攻击，读条结束时对玩家造成极高额伤害", "暗影置换 - 标记场上的一个拘束圈，短暂延迟后，首领瞬移至该拘束圈位置并引发大范围毁灭性爆炸，仅拘束圈附近的小范围区域是安全区", "暗影共鸣 - 首领自身和场上所有拘束圈附近造成大范围的爆炸，无视拘束圈的减伤效果", "暗影龙卷 - 连续在玩家脚下生成3个延迟生效的暗影龙卷风，踩中后会受到高额伤害并眩晕，高难度下无视拘束圈的减伤效果", "腐蚀射线 - 蓄力后向左右两侧发射腐蚀激光", "腐蚀下压 - 随机顺序释放的扇形大范围攻击预警", "腐蚀轮转 - 生成十字状的腐蚀射线，向顺时针或逆时针方向旋转，触碰到会受到伤害", "诗想难度特殊机制 · 暗影球 - 每过一段时间生成一个追踪角色的暗影球，如果被击中会受到高额伤害并大幅减速，在拘束圈内被击中不会受到伤害与减速效果"]},
	{"id": "boss_difu", "monster_id": "boss_panguan", "name": "诤", "rarity": "red", "stages": ["difu"], "skills": ["核心机制 · 剥夺 - 首领会随机剥夺角色的移动速度或攻击速度，并记录剥夺值。剥夺会持续一段时间，可通过答问成功解除。", "核心机制 · 答问 - 首领移动到场地中央并生成三个法阵，法阵数值分别为一、二、三。角色站入法阵后，会将法阵数值与当前剥夺数值相加作为答问结果", "核心机制 · 答问判定 - 答问题目会要求结果为奇数、偶数、三或四；答对会解除剥夺，答错会受到按当前体力比例计算的伤害", "墨珠 - 长时间咏唱期间，在首领或角色附近连续生成墨珠预警，预警结束后生成墨珠造成伤害", "泼墨·墨灵 - 咏唱后从场地上方连续生成多轮向下飞行的墨灵弹幕，每轮会留下可穿过的缺口", "泼墨·墨罚 - 连续多次瞄准角色方向释放长条墨痕攻击，范围较宽"]},
]

const STAGE_BOSS_GUIDE_IDS := {
	"peach_grove": "boss_peach_grove",
	"ruin": "boss_ruin",
	"cave": "boss_cave",
	"forest": "boss_forest",
	"difu": "boss_difu",
}

const LAW_DEFINITIONS := [
	{"id": "law_blood", "name": "浴血法则", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_blood.png", "detail": "浴血系武器：饮血刀，血气波，爪爪巨锤\n4阶：每 4 秒或受伤后，对周围敌人发出震击并获得护盾\n9阶：浴血系武器伤害提升，震击伤害提升\n16阶：震击范围提升，并附加流血\n22阶：浴血系武器伤害额外提升，血量降低时获得独立减伤率\n29阶：震击、护盾与流血效果大幅提升"},
	{"id": "law_sword", "name": "刀剑法则", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_sword.png", "detail": "刀剑系武器：剑气诀，饮血刀，乾坤双剑\n4阶：刀剑系武器攻击速度提升，暴击伤害提升\n9阶：刀剑系武器命中叠加寒光并引爆\n16阶：攻击速度和暴击伤害再次提升\n22阶：寒光可暴击且对精英、首领提升伤害\n29阶：刀剑系攻速和寒光伤害大幅提升"},
	{"id": "law_thunder", "name": "鸣雷法则", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_thunder.png", "detail": "鸣雷系武器：天雷破，震雷诀，雷魂枪\n4阶：鸣雷系武器伤害提升，感电伤害提升\n9阶：命中或感电触发时概率召唤鸣雷\n16阶：鸣雷伤害、概率和对精英首领伤害提升\n22阶：鸣雷系武器伤害与鸣雷效果大幅提升"},
	{"id": "law_heal", "name": "愈疗法则", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_heal.png", "detail": "愈疗系武器：坎水诀，圣光术\n4阶：治疗与护盾获取加成提升\n9阶：治疗或护盾受损后向敌人发射弹体\n16阶：治疗护盾加成再次提升，弹体伤害提升\n22阶：弹体伤害大幅提升，并允许暴击"},
	{"id": "law_summon", "name": "御灵法则", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_summon.png", "detail": "御灵系武器：御剑\n4阶：召唤物伤害与治疗提升，触发间隔降低\n9阶：最大召唤物容量提升，召唤物弹体变大\n16阶：召唤不占容量的双极魔剑\n22阶：每个召唤物提升角色攻击与攻击速度\n29阶：召唤陨灭剑灵，召唤物效果大幅提升"},
	{"id": "law_shield", "name": "护佑法则", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_sheild.png", "detail": "护佑系武器：玄武盾，艮山诀\n4阶：护盾获取加成与最大体力提升\n7阶：最大体力再次提升，护盾结束转化为生命回复\n11阶：最大体力提升，护盾存在时获得减伤率\n15阶：护盾获取和生命回复转化进一步提升"},
	{"id": "law_fire", "name": "炽焰法则", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_fire.png", "detail": "炽焰系武器：赤曜，离火诀，爆炎诀\n4阶：炽焰系武器和燃烧伤害提升\n9阶：燃烧伤害、范围和持续时间提升\n16阶：炽焰系武器伤害再次提升，燃烧对精英首领强化\n22阶：燃烧伤害与范围再次提升\n29阶：炽焰系武器和燃烧效果大幅提升"},
	{"id": "law_destroy", "name": "破坏法则", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_destory.png", "detail": "破坏系武器：冰刺术，爆炎诀，天雷破\n4阶：破坏系武器暴击率提升，溢出暴击率转暴击伤害\n9阶：暴击或击杀概率引爆目标\n16阶：暴击伤害波动，引爆概率和伤害提升\n22阶：暴击率和引爆概率再次提升\n29阶：破坏系武器伤害和引爆范围大幅提升"},
	{"id": "law_life", "name": "生灵法则", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_life.png", "detail": "生灵系武器：光弹术，坎水诀，圣光术\n4阶：生灵系武器伤害和经验获取提升\n9阶：定时或升级时降下神圣光辉\n16阶：神圣光辉伤害和范围提升，经验获取提升\n22阶：生灵系武器与光辉再次提升\n29阶：神圣光辉触发更快，伤害大幅提升"},
	{"id": "law_bullet", "name": "弹雨法则", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_bullet.png", "detail": "弹雨类武器：剑气诀，光弹术，仙枝，冰刺术\n4阶：弹雨类武器伤害和射程提升\n11阶：累计命中后发射弹幕\n18阶：弹雨类武器伤害、范围和弹幕提升\n24阶：弹幕波数和伤害继续提升\n31阶：弹雨类武器和弹幕大幅提升"},
	{"id": "law_wind", "name": "啸风法则", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_wind.png", "detail": "啸风类武器：气功波，巽风诀，风龙杖\n4阶：啸风类武器伤害和移动速度提升\n9阶：啸风类攻击速度提升，命中获得唤风\n16阶：啸风类伤害和攻击速度再次提升\n22阶：唤风上限提升，击中首领额外获得唤风\n29阶：唤风提升对精英、首领伤害"},
	{"id": "law_wide", "name": "广域法则", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_wide.png", "detail": "广域类武器：血气波，赤曜，兑泽诀，气功波\n4阶：广域类武器伤害和范围提升\n9阶：角色伤害范围提升，范围加成转化为伤害\n16阶：广域类武器伤害和范围再次提升\n22阶：角色范围提升，范围转伤害效率提升\n29阶：广域类武器伤害和范围大幅提升"},
	{"id": "law_bagua", "name": "八卦法则", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_bagua.png", "detail": "八卦类武器：乾坤双剑，离火诀，兑泽诀，坎水诀，震雷诀，巽风诀，艮山诀\n4阶：命中和击杀获得推衍度，满值获得推衍完成\n11阶：推衍度获得翻倍，八卦类武器伤害提升\n18阶：推衍度获得提升至 3 倍\n25阶：推衍度获得提升至 5 倍\n33阶：推衍度获得提升至 10 倍"},
	{"id": "law_liushi", "name": "六识法则", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_liushi.png", "detail": "2阶：六识系领悟加成属性提升至 1.2 倍\n3阶：提升至 1.6 倍\n4阶：提升至 2.4 倍\n5阶：提升至 4 倍\n6阶：提升至 8 倍"},
	{"id": "law_treasure", "name": "宝器法则", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_treasure.png", "detail": "宝器类武器：仙枝，风龙杖，玄武盾\n4阶：宝器类武器伤害提升，天命提升\n9阶：天命提升，每点天命提升宝器伤害，每升 2 级获得刷新次数\n16阶：宝器类武器攻速提升，天命提升\n22阶：宝器伤害和天命提升，每升 1 级获得刷新次数\n29阶：宝器伤害、天命和护甲大幅提升"},
	{"id": "law_deep", "name": "沉渊法则", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/buff_chenyuan.png", "detail": "沉渊系武器：爪爪巨锤，撼地诀，噬魂镰\n4阶：沉渊系武器伤害和击退提升\n9阶：强制位移后额外结算伤害\n16阶：伤害和击退再次提升\n22阶：位移结算伤害和对首领额外伤害提升\n29阶：沉渊系伤害、击退和首领额外伤害大幅提升"},
	{"id": "law_shehun", "name": "摄魂法则", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/buff_shehun.png", "detail": "摄魂类武器：噬魂镰，摄魂铃，雷魂枪\n4阶：摄魂类武器伤害和精魄获取提升\n8阶：精魄再生提升，每获得精魄可提升摄魂法则\n16阶：伤害、暴击率、精魄获取和再生提升\n22阶：敌人数量提升，精魄带来最终伤害和减伤\n29阶：摄魂类效果大幅提升"},
	{"id": "law_chaos", "name": "混沌法则", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_chaos.png", "detail": "混沌法则是基于其他法则层数决定的，已有法则数量达到 6 种后才会生效。每个达到 6、10 层的法则使混沌法则层数 +1，每个达到 12 层的法则使混沌层数 -2\n5阶：最终伤害、经验获得率、真气获取率提升\n8阶：相关属性大幅提升\n11阶：相关属性进一步提升"},
]

var collected_entries: Dictionary = {}
var definitions_by_category: Dictionary = {}
var definitions_by_id: Dictionary = {}
var _built_dynamic_definitions := false
var _debug_force_all_locked := false

func _ready() -> void:
	_rebuild_definitions()
	_sync_rule_based_friend_collection(false)

func export_save_data() -> Dictionary:
	_sync_rule_based_friend_collection(false)
	return {"collected_entries": collected_entries.duplicate(true)}

func import_save_data(data: Dictionary) -> void:
	collected_entries = _sanitize_bool_dict(data.get("collected_entries", {}))
	_sync_rule_based_friend_collection(false)
	collection_changed.emit()

func sync_rule_based_friend_collection(save_now: bool = false) -> void:
	_sync_rule_based_friend_collection(save_now)

func sync_current_battle_law_collection(save_now: bool = false) -> void:
	_rebuild_definitions()
	_sync_current_battle_law_collection(save_now)

func debug_unlock_all_entries() -> int:
	_rebuild_definitions()
	_debug_force_all_locked = false
	var changed := false
	for entry_id in definitions_by_id.keys():
		var id := str(entry_id)
		if id.is_empty():
			continue
		if collected_entries.get(id, false) != true:
			collected_entries[id] = true
			changed = true
	if changed:
		collection_changed.emit()
	if typeof(Global) != TYPE_NIL and Global != null and Global.has_method("save_game"):
		Global.save_game()
	return collected_entries.size()

func debug_clear_all_entries() -> int:
	_rebuild_definitions()
	_debug_force_all_locked = true
	var cleared_count := collected_entries.size()
	collected_entries.clear()
	collection_changed.emit()
	if typeof(Global) != TYPE_NIL and Global != null and Global.has_method("save_game"):
		Global.save_game()
	return cleared_count

func record_enemy_seen(monster_id: String, _stage_id: String = "", is_special_enemy: bool = false) -> bool:
	_rebuild_definitions()
	var normalized_id := monster_id.strip_edges()
	if normalized_id.is_empty():
		return false
	var guide_id := _get_enemy_guide_id(normalized_id)
	if guide_id.is_empty():
		return false
	if is_special_enemy:
		var definition: Dictionary = definitions_by_id.get(guide_id, {})
		if not definition.is_empty() and str(definition.get("rarity", "")) != "red":
			definition["rarity"] = "purple"
	return _collect(guide_id)

func record_boss_seen(stage_id: String) -> bool:
	_rebuild_definitions()
	var guide_id := str(STAGE_BOSS_GUIDE_IDS.get(stage_id, ""))
	if guide_id.is_empty():
		return false
	return _collect(guide_id)

func record_item_obtained(item_id: String) -> bool:
	_rebuild_definitions()
	var guide_id := "item_" + item_id.strip_edges()
	if not definitions_by_id.has(guide_id):
		return false
	return _collect(guide_id)

func record_battle_reward_taken(reward) -> bool:
	_rebuild_definitions()
	if reward == null:
		return false
	var reward_id := str(reward.id)
	if reward_id.is_empty():
		return false
	var guide_id := ""
	if _is_weapon_reward(reward):
		guide_id = "weapon_" + str(reward.faction)
	elif _is_regular_battle_reward(reward):
		guide_id = "reward_" + reward_id
	var entry_ids: Array[String] = []
	if not guide_id.is_empty() and definitions_by_id.has(guide_id):
		entry_ids.append(guide_id)
	for law_id in _get_related_law_ids_from_reward(reward):
		if not entry_ids.has(law_id):
			entry_ids.append(law_id)
	if _should_unlock_chaos_law(reward) and not entry_ids.has("law_chaos"):
		entry_ids.append("law_chaos")
	return _collect_entries(entry_ids)

func get_definitions(category: String) -> Array[Dictionary]:
	_rebuild_definitions()
	_sync_rule_based_friend_collection(false)
	if category == CATEGORY_BATTLE:
		_sync_current_battle_law_collection(false)
	var result: Array[Dictionary] = []
	for definition in definitions_by_category.get(category, []):
		result.append((definition as Dictionary).duplicate(true))
	return result

func get_definition(entry_id: String) -> Dictionary:
	_rebuild_definitions()
	var definition: Dictionary = definitions_by_id.get(entry_id, {})
	return definition.duplicate(true)

func is_collected(entry_id: String) -> bool:
	_sync_rule_based_friend_collection(false)
	return collected_entries.get(entry_id, false) == true

func get_category_progress(category: String) -> Dictionary:
	var definitions := get_definitions(category)
	var total := definitions.size()
	var collected := 0
	for definition in definitions:
		if is_collected(str(definition.get("id", ""))):
			collected += 1
	return {"collected": collected, "total": total}

func get_total_exploration_points() -> int:
	_rebuild_definitions()
	var total := 0
	for category in definitions_by_category.keys():
		for definition in definitions_by_category[category]:
			total += int(RARITY_POINTS.get(str(definition.get("rarity", "white")), 0))
	return total

func get_collected_exploration_points() -> int:
	_rebuild_definitions()
	_sync_rule_based_friend_collection(false)
	var total := 0
	for entry_id in definitions_by_id.keys():
		if not is_collected(str(entry_id)):
			continue
		var definition: Dictionary = definitions_by_id[entry_id]
		total += int(RARITY_POINTS.get(str(definition.get("rarity", "white")), 0))
	return total

func get_bonus_summary() -> Dictionary:
	var reward_count := int(floor(float(get_collected_exploration_points()) / 10.0))
	var summary := {
		"atk": 0.0,
		"hp": 0.0,
		"point": 0.0,
		"drop": 0.0,
	}
	for i in range(reward_count):
		match i % 4:
			0:
				summary["atk"] = float(summary["atk"]) + 1.0
			1:
				summary["hp"] = float(summary["hp"]) + 10.0
			2:
				summary["point"] = float(summary["point"]) + 0.003
			3:
				summary["drop"] = float(summary["drop"]) + 0.001
	return summary

func get_bonus_text() -> String:
	var summary := get_bonus_summary()
	return "攻击 +%d\n最大体力 +%d\n真气获取 +%.1f%%\n掉落率 +%.2f%%" % [
		int(round(float(summary.get("atk", 0.0)))),
		int(round(float(summary.get("hp", 0.0)))),
		float(summary.get("point", 0.0)) * 100.0,
		float(summary.get("drop", 0.0)) * 100.0,
	]

func get_rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(_normalize_rarity(rarity), Color.WHITE)

func _rebuild_definitions() -> void:
	if _built_dynamic_definitions:
		return
	definitions_by_category = {
		CATEGORY_FRIEND: [],
		CATEGORY_ENEMY: [],
		CATEGORY_ITEM: [],
		CATEGORY_BATTLE: [],
	}
	definitions_by_id.clear()
	_add_friend_definitions()
	_add_enemy_definitions()
	_add_item_definitions()
	_add_battle_definitions()
	_built_dynamic_definitions = true

func _add_definition(category: String, definition: Dictionary) -> void:
	var entry := definition.duplicate(true)
	entry["category"] = category
	var entry_id := str(entry.get("id", ""))
	if entry_id.is_empty():
		return
	if not definitions_by_category.has(category):
		definitions_by_category[category] = []
	definitions_by_category[category].append(entry)
	definitions_by_id[entry_id] = entry

func _add_friend_definitions() -> void:
	for definition in FRIEND_DEFINITIONS:
		var entry := (definition as Dictionary).duplicate(true)
		entry["rarity"] = "red"
		entry["detail_type"] = "friend"
		entry["icon"] = _existing_resource_or_default(str(entry.get("icon", "")), DEFAULT_TOWN_ICON)
		_add_definition(CATEGORY_FRIEND, entry)

func _add_enemy_definitions() -> void:
	for definition in ENEMY_DEFINITIONS:
		var entry := (definition as Dictionary).duplicate(true)
		entry["detail_type"] = "enemy"
		entry["icon"] = DEFAULT_ENEMY_ICON
		entry["scene_path"] = _get_enemy_scene_path(str(entry.get("monster_id", "")))
		entry["drops"] = _get_enemy_drop_names(str(entry.get("drop_id", entry.get("monster_id", ""))))
		_add_definition(CATEGORY_ENEMY, entry)

func _add_item_definitions() -> void:
	if typeof(ItemManager) == TYPE_NIL or ItemManager == null:
		return
	for item_id in ItemManager.items_data.keys():
		var id := str(item_id)
		if id == "item_001" or id == Global.LINGSHI_ITEM_ID:
			continue
		var item_data: Dictionary = ItemManager.get_item_all_data(id)
		var entry := {
			"id": "item_" + id,
			"source_id": id,
			"name": str(item_data.get("item_name", id)),
			"rarity": _normalize_item_rarity(item_data.get("item_rare", "common")),
			"icon": _get_item_icon_path(str(item_data.get("item_icon", ""))),
			"detail": str(item_data.get("item_detail", "")),
			"detail_type": "item",
		}
		_add_definition(CATEGORY_ITEM, entry)

func _add_battle_definitions() -> void:
	for law in LAW_DEFINITIONS:
		var entry := (law as Dictionary).duplicate(true)
		entry["rarity"] = "gold"
		entry["detail_type"] = "law"
		_add_definition(CATEGORY_BATTLE, entry)
	_add_weapon_definitions()
	_add_reward_definitions()

func _add_weapon_definitions() -> void:
	if typeof(LvUp) == TYPE_NIL or LvUp == null:
		return
	for faction in WEAPON_FACTIONS:
		var base_reward = _get_weapon_base_reward(faction)
		if base_reward == null:
			continue
		var detail_lines: Array[String] = []
		var base_detail := _strip_bbcode(str(base_reward.detail)).strip_edges()
		if not base_detail.is_empty():
			detail_lines.append(base_detail)
		for reward in LvUp.all_rewards_list:
			if str(reward.faction) != faction:
				continue
			if not bool(reward.if_advance):
				continue
			var advance_name := _strip_bbcode(str(reward.reward_name)).strip_edges()
			var advance_detail := _strip_bbcode(str(reward.detail)).strip_edges()
			if advance_detail.is_empty():
				continue
			var line := advance_detail
			if not advance_name.is_empty():
				line = "%s：%s" % [advance_name, advance_detail]
			if not detail_lines.has(line):
				detail_lines.append(line)
		var entry := {
			"id": "weapon_" + faction,
			"source_id": faction,
			"name": str(base_reward.reward_name),
			"rarity": "purple",
			"icon": LvUp.get_icon_path(str(base_reward.icon)),
			"detail": "\n".join(detail_lines),
			"detail_type": "weapon",
		}
		_add_definition(CATEGORY_BATTLE, entry)

func _add_reward_definitions() -> void:
	if typeof(LvUp) == TYPE_NIL or LvUp == null:
		return
	for reward in LvUp.all_rewards_list:
		if not _is_regular_battle_reward(reward):
			continue
		var entry := {
			"id": "reward_" + str(reward.id),
			"source_id": str(reward.id),
			"name": str(reward.reward_name),
			"rarity": _normalize_reward_rarity(str(reward.rarity)),
			"icon": LvUp.get_icon_path(str(reward.icon)),
			"detail": _strip_bbcode(str(reward.detail)),
			"detail_type": "reward",
		}
		_add_definition(CATEGORY_BATTLE, entry)

func _is_regular_battle_reward(reward) -> bool:
	if reward == null:
		return false
	if _is_weapon_reward(reward):
		return false
	if str(reward.id) == "NoAdvance":
		return true
	if WEAPON_FACTIONS.has(str(reward.faction)):
		return false
	return not bool(reward.if_advance)

func _is_weapon_reward(reward) -> bool:
	if reward == null:
		return false
	return WEAPON_FACTIONS.has(str(reward.faction))

func _is_weapon_base_reward(reward) -> bool:
	if reward == null:
		return false
	return _is_weapon_reward(reward) and not bool(reward.if_main_skill) and not bool(reward.if_advance)

func _get_weapon_base_reward(faction: String):
	for reward in LvUp.all_rewards_list:
		if str(reward.faction) == faction and _is_weapon_base_reward(reward):
			return reward
	return null

func _sync_current_battle_law_collection(save_now: bool = false) -> bool:
	if _debug_force_all_locked:
		return false
	var entry_ids: Array[String] = []
	var selected_law_levels := _get_selected_reward_law_levels(null)
	for law_id in selected_law_levels.keys():
		var law_entry_id := str(law_id)
		if definitions_by_id.has(law_entry_id) and not entry_ids.has(law_entry_id):
			entry_ids.append(law_entry_id)
	if _calculate_chaos_level_from_law_levels(selected_law_levels) > 0 and not entry_ids.has("law_chaos"):
		entry_ids.append("law_chaos")
	if _has_selected_chaos_reward(null) and not entry_ids.has("law_chaos"):
		entry_ids.append("law_chaos")
	return _collect_entries(entry_ids, save_now)

func _get_related_law_ids_from_reward(reward) -> Array[String]:
	var result: Array[String] = []
	var law_levels := _extract_law_levels_from_reward_detail(str(reward.detail))
	for law_id in law_levels.keys():
		var law_entry_id := str(law_id)
		if definitions_by_id.has(law_entry_id) and not result.has(law_entry_id):
			result.append(law_entry_id)
	return result

func _should_unlock_chaos_law(extra_reward) -> bool:
	var law_levels := _get_selected_reward_law_levels(extra_reward)
	if _calculate_chaos_level_from_law_levels(law_levels) > 0:
		return true
	return _has_selected_chaos_reward(extra_reward)

func _get_selected_reward_law_levels(extra_reward) -> Dictionary:
	var result: Dictionary = {}
	if typeof(PC) != TYPE_NIL and PC != null:
		for reward_id in PC.selected_rewards:
			var reward = _get_reward_by_id(str(reward_id))
			if reward != null:
				_add_reward_law_levels_to(result, reward)
	if extra_reward != null:
		_add_reward_law_levels_to(result, extra_reward)
	return result

func _add_reward_law_levels_to(result: Dictionary, reward) -> void:
	var law_levels := _extract_law_levels_from_reward_detail(str(reward.detail))
	for law_id in law_levels.keys():
		var law_entry_id := str(law_id)
		result[law_entry_id] = int(result.get(law_entry_id, 0)) + int(law_levels[law_entry_id])

func _extract_law_levels_from_reward_detail(detail: String) -> Dictionary:
	var result: Dictionary = {}
	var regex := RegEx.new()
	if regex.compile("【([^】]+)】\\s*([0-9]+)") != OK:
		return result
	for match_result in regex.search_all(detail):
		var law_name := match_result.get_string(1)
		var law_id := str(LAW_NAME_TO_ID.get(law_name, ""))
		if law_id.is_empty() or not definitions_by_id.has(law_id):
			continue
		var level := int(match_result.get_string(2))
		result[law_id] = int(result.get(law_id, 0)) + level
	return result

func _calculate_chaos_level_from_law_levels(law_levels: Dictionary) -> int:
	if _count_owned_chaos_source_laws(law_levels) < 6:
		return 0
	var chaos_level := 0
	for law_id in CHAOS_SOURCE_LAW_IDS:
		var level := int(law_levels.get(str(law_id), 0))
		if level >= 6:
			chaos_level += 1
		if level >= 10:
			chaos_level += 1
		if level >= 12:
			chaos_level -= 2
	return maxi(chaos_level, 0)

func _count_owned_chaos_source_laws(law_levels: Dictionary) -> int:
	var count := 0
	for law_id in CHAOS_SOURCE_LAW_IDS:
		if int(law_levels.get(str(law_id), 0)) > 0:
			count += 1
	return count

func _has_selected_chaos_reward(extra_reward) -> bool:
	if extra_reward != null and _is_chaos_reward(extra_reward):
		return true
	if typeof(PC) == TYPE_NIL or PC == null:
		return false
	for reward_id in PC.selected_rewards:
		var reward = _get_reward_by_id(str(reward_id))
		if reward != null and _is_chaos_reward(reward):
			return true
	return false

func _is_chaos_reward(reward) -> bool:
	if reward == null:
		return false
	return str(reward.reward_name).contains("混沌") or str(reward.detail).contains("混沌法则")

func _get_reward_by_id(reward_id: String):
	if typeof(LvUp) == TYPE_NIL or LvUp == null:
		return null
	for reward in LvUp.all_rewards_list:
		if str(reward.id) == reward_id:
			return reward
	return null

func _get_enemy_guide_id(monster_id: String) -> String:
	for definition in definitions_by_category.get(CATEGORY_ENEMY, []):
		if str(definition.get("monster_id", "")) == monster_id:
			return str(definition.get("id", ""))
	return ""

func _get_enemy_scene_path(monster_id: String) -> String:
	var override_path := str(ENEMY_SCENE_PATH_OVERRIDES.get(monster_id, ""))
	if not override_path.is_empty() and ResourceLoader.exists(override_path):
		return override_path
	var scene_path := "res://Scenes/moster/%s.tscn" % monster_id
	if ResourceLoader.exists(scene_path):
		return scene_path
	return ""

func _get_item_icon_path(icon_path: String) -> String:
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		return icon_path
	if icon_path.ends_with("/yingke.png"):
		var hard_shell_path := "res://AssetBundle/Sprites/Sprite sheets/item_icon/jiake.png"
		if ResourceLoader.exists(hard_shell_path):
			return hard_shell_path
	return icon_path

func _get_enemy_drop_names(monster_id: String) -> Array[String]:
	var names: Array[String] = []
	if typeof(SettingMoster) == TYPE_NIL or SettingMoster == null:
		return names
	if not SettingMoster.has_method(monster_id):
		return names
	var drop_data = SettingMoster.call(monster_id, "itemdrop")
	if typeof(drop_data) != TYPE_DICTIONARY:
		return names
	for item_id in drop_data.keys():
		var id := str(item_id)
		if id == "item_001" or id == Global.LINGSHI_ITEM_ID:
			continue
		var item_name := str(ItemManager.get_item_property(id, "item_name")) if ItemManager != null else id
		if not item_name.is_empty() and not names.has(item_name):
			names.append(item_name)
	return names

func _collect(entry_id: String) -> bool:
	return _collect_entries([entry_id])

func _collect_entries(entry_ids: Array[String], save_now: bool = true) -> bool:
	var changed := false
	for entry_id in entry_ids:
		if _mark_collected(str(entry_id)):
			changed = true
	if not changed:
		return false
	collection_changed.emit()
	if save_now and typeof(Global) != TYPE_NIL and Global != null and Global.has_method("save_game"):
		Global.save_game()
	return true

func _mark_collected(entry_id: String) -> bool:
	if entry_id.is_empty() or not definitions_by_id.has(entry_id) or collected_entries.get(entry_id, false) == true:
		return false
	collected_entries[entry_id] = true
	return true

func _sync_rule_based_friend_collection(save_now: bool = false) -> void:
	if not _built_dynamic_definitions or _debug_force_all_locked:
		return
	var changed := false
	for definition in definitions_by_category.get(CATEGORY_FRIEND, []):
		if _is_friend_rule_unlocked(str(definition.get("unlock", ""))):
			var entry_id := str(definition.get("id", ""))
			if not entry_id.is_empty() and collected_entries.get(entry_id, false) != true:
				collected_entries[entry_id] = true
				changed = true
	if changed:
		collection_changed.emit()
		if save_now and typeof(Global) != TYPE_NIL and Global != null and Global.has_method("save_game"):
			Global.save_game()

func _is_friend_rule_unlocked(rule: String) -> bool:
	if rule == "always":
		return true
	if rule.begins_with("global_bool:"):
		var prop := rule.substr("global_bool:".length())
		return bool(Global.get(prop))
	if rule.begins_with("story:"):
		var prop := rule.substr("story:".length())
		return bool(Global.get(prop))
	return false

func _normalize_item_rarity(value) -> String:
	if typeof(value) == TYPE_INT:
		match int(value):
			1:
				return "white"
			2:
				return "blue"
			3:
				return "purple"
			4:
				return "gold"
			5:
				return "red"
	return _normalize_rarity(str(value))

func _normalize_reward_rarity(value: String) -> String:
	return REWARD_RARITY_MAP.get(value.to_lower(), _normalize_rarity(value))

func _normalize_rarity(value: String) -> String:
	var normalized := value.to_lower().strip_edges()
	if ITEM_RARITY_MAP.has(normalized):
		return str(ITEM_RARITY_MAP[normalized])
	if REWARD_RARITY_MAP.has(normalized):
		return str(REWARD_RARITY_MAP[normalized])
	return "white"

func _existing_resource_or_default(path: String, default_path: String) -> String:
	if not path.is_empty() and ResourceLoader.exists(path):
		return path
	return default_path

func _strip_bbcode(text: String) -> String:
	var result := text
	var regex := RegEx.new()
	if regex.compile("\\[[^\\]]+\\]") == OK:
		result = regex.sub(result, "", true)
	return result.strip_edges()

func _sanitize_bool_dict(value) -> Dictionary:
	var result: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for key in value.keys():
		if value[key] == true:
			result[str(key)] = true
	return result
