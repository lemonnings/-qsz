extends Node

# 物品数据字典
# item_id: 唯一ID
# item_name: 道具名
# item_stack_max: 最大堆叠数量
# item_type: 物品类型 ("immediate"（拾取后直接使用，例如血药）, "equip"（法宝）, "material"（材料），"consumable"（消耗品），"special"（特殊的不可使用的物品，如钥匙）
# item_icon: 图标路径 (String)
# item_price: 价格 (Int/Float)
# item_use_condition: 使用条件 (String)，为1个函数,一般都是空的，只有满足特殊条件才能使用的consumable才需要加上这个
# item_detail: 详情 (String) - 包含物品来源和描述
# item_rare: 品质 (String/Int, e.g., "common", "rare", "epic", "legend", "artifact" / 1, 2, 3) 对应白色 蓝色 紫色 橙色 红色
# item_color: 掉落时显示的颜色 (Color / String, e.g., Color(1,1,1) / "white")
# item_anime: 掉落时显示的动画 (String - 动画资源路径或名称)
# equip_stats: 装备属性 (仅装备类型物品需要)
#   - base_stats: 基础属性（固有的主词条）
#   - random_stats: 随机属性（副词条）
#   - enhance_level: 强化等级
#   属性字段包括：pc_atk(攻击), pc_atk_speed(攻速), crit_chance(暴击率), crit_damage_multi(暴击伤害), 
#   pc_final_atk(最终伤害), point_multi(真气获取), exp_multi(经验获取), drop_multi(掉落率),
#   attack_range(攻击范围), damage_reduction_rate(减伤率), pc_hp(HP), pc_speed(移速), tianming(天命)
#   每个属性包含：value(当前值), base_value(原始值)

var items_data = {
	"item_001": {
		"item_name": "回复精华",
		"item_stack_max": 10,
		"item_type": "immediate", # 立即生效
		"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/healths.png",
		"item_price": 50,
		"item_source": "怪物掉落",
		"item_use_condition": "",
		"item_detail": "恢复少量生命值。",
		"item_rare": "common", # 普通
		"item_anime": "res://assets/animations/item_pickup_common.tres"
	},
	"item_002": {
		"item_name": "凝胶",
		"item_stack_max": 9999,
		"item_type": "material",
		"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/slime.png",
		"item_price": 40,
		"item_source": "击败涎兽获取",
		"item_use_condition": "",
		"item_detail": "涎兽死后凝结的胶体，粘合性非常出色",
		"item_rare": "common", # 稀有
		"item_anime": "res://assets/animations/item_pickup_rare.tres"
	},
	"item_003": {
		"item_name": "灵液",
		"item_stack_max": 9999,
		"item_type": "material",
		"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/slime2.png",
		"item_price": 200, # 单个价格，或者表示其价值
		"item_source": "击败涎兽获取",
		"item_use_condition": "",
		"item_detail": "少数涎兽体内存在的具有奇效的液体",
		"item_rare": "common",
		"item_anime": "res://assets/animations/item_pickup_common.tres"
	},
	"item_004": {
		"item_name": "阴钥碎片",
		"item_stack_max": 99,
		"item_type": "material",
		"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/jiuyou.png",
		"item_price": 1000, # 单个价格，或者表示其价值
		"item_source": "击败森林，山脚下的敌人小概率获取",
		"item_use_condition": "",
		"item_detail": "九幽秘钥的碎片，蕴含着神秘的力量，收集满10个后可以合成一个完整的九幽秘钥",
		"item_rare": "epic", # 史诗
		"item_anime": "res://assets/animations/item_pickup_epic.tres"
	},
	"item_005": {
		"item_name": "阳钥碎片",
		"item_stack_max": 99,
		"item_type": "material",
		"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/kongmeng.png",
		"item_price": 1000, # 单个价格，或者表示其价值
		"item_source": "击败山腰，山顶的敌人低概率获取",
		"item_use_condition": "",
		"item_detail": "空濛秘钥的碎片，蕴含着神秘的力量，收集满10个后可以合成一个完整的空濛秘钥，用来开启空濛山的结界",
		"item_rare": "epic", # 史诗
		"item_anime": "res://assets/animations/item_pickup_epic.tres"
	},
	"item_007": {
		"item_name": "灵髓碎片",
		"item_stack_max": 9999,
		"item_type": "material",
		"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/julingsuipian.png",
		"item_price": 500,
		"item_source": "击败全地区敌人低概率获取",
		"item_use_condition": "",
		"item_detail": "幻境中的异界灵髓碎片，可以用来合成修仙界通用的灵石。",
		"item_rare": "epic", # 传说
		"item_anime": "res://assets/animations/item_pickup_legendary.tres"
		},
		"item_009": {
			"item_name": "水灵叶",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/shuilingye.png",
			"item_price": 40,
			"item_source": "击败水属性怪物获取",
			"item_use_condition": "",
			"item_detail": "蕴含微弱水灵力的叶片，可用于炼药与制符",
			"item_rare": "rare",
			"item_anime": "res://assets/animations/item_pickup_common.tres"
		},
		"item_010": {
			"item_name": "风灵草",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/fenglingcao.png",
			"item_price": 40,
			"item_source": "击败风属性怪物获取",
			"item_use_condition": "",
			"item_detail": "含有风息的灵草，轻盈柔韧，多用途基础材",
			"item_rare": "rare",
			"item_anime": "res://assets/animations/item_pickup_common.tres"
		},
		"item_011": {
			"item_name": "宣纸",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/xuanzhi.png",
			"item_price": 40,
			"item_source": "击败宣纸精获取",
			"item_use_condition": "",
			"item_detail": "适合书写与绘制符箓的纸张，纤维韧性良好",
			"item_rare": "common",
			"item_anime": "res://assets/animations/item_pickup_common.tres"
		},
		"item_012": {
			"item_name": "毒囊",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/dunang.png",
			"item_price": 40,
			"item_source": "击败蟾蜍获取",
			"item_use_condition": "",
			"item_detail": "怪物体内储毒的囊袋，炼毒或制药常用材",
			"item_rare": "common",
			"item_anime": "res://assets/animations/item_pickup_common.tres"
		},
		"item_013": {
			"item_name": "符纸",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/fuzhi.png",
			"item_price": 40,
			"item_source": "击败宣纸精获取",
			"item_use_condition": "",
			"item_detail": "特制纸片，耐灵力冲刷，刻绘符阵的常备材",
			"item_rare": "common",
			"item_anime": "res://assets/animations/item_pickup_common.tres"
		},
		"item_014": {
			"item_name": "土灵矿",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/tulingkuang.png",
			"item_price": 40,
			"item_source": "击败土属性怪物获取",
			"item_use_condition": "",
			"item_detail": "蕴含土灵气的矿石，冶炼与炼器的基础材料",
			"item_rare": "rare",
			"item_anime": "res://assets/animations/item_pickup_common.tres"
		},
		"item_015": {
			"item_name": "火灵晶",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/huolingjing.png",
			"item_price": 40,
			"item_source": "击败火属性怪物获取",
			"item_use_condition": "",
			"item_detail": "凝聚火灵的晶体，可为法器提供稳定热源",
			"item_rare": "rare",
			"item_anime": "res://assets/animations/item_pickup_common.tres"
		},
		"item_016": {
			"item_name": "硬壳",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/yingke.png",
			"item_price": 40,
			"item_source": "击败甲壳类怪物获取",
			"item_use_condition": "",
			"item_detail": "坚硬的外壳碎片，可用于强化护具与器胚",
			"item_rare": "common",
			"item_anime": "res://assets/animations/item_pickup_common.tres"
		},
		"item_017": {
			"item_name": "雷灵丝",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/leilingsi.png",
			"item_price": 40,
			"item_source": "击败雷属性怪物获取",
			"item_use_condition": "",
			"item_detail": "带有微弱电流的灵丝，导灵性出色",
			"item_rare": "rare",
			"item_anime": "res://assets/animations/item_pickup_common.tres"
		},
		"item_018": {
			"item_name": "元水",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/yuanshui2.png",
			"item_price": 40,
			"item_source": "通过合成获得",
			"item_use_condition": "",
			"item_detail": "纯净水属性材料，常作基础媒介",
			"item_rare": "rare",
			"item_anime": "res://assets/animations/item_pickup_common.tres"
		},
		"item_019": {
			"item_name": "元风",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/yuanfeng2.png",
			"item_price": 40,
			"item_source": "通过合成获得",
			"item_use_condition": "",
			"item_detail": "纯粹风属性材料，适合轻灵法阵",
			"item_rare": "rare",
			"item_anime": "res://assets/animations/item_pickup_common.tres"
		},
		"item_020": {
			"item_name": "元雷",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/yuanlei2.png",
			"item_price": 40,
			"item_source": "通过合成获得",
			"item_use_condition": "",
			"item_detail": "纯粹雷属性材料，增幅冲击术式",
			"item_rare": "rare",
			"item_anime": "res://assets/animations/item_pickup_common.tres"
		},
		"item_021": {
			"item_name": "元土",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/yuantu2.png",
			"item_price": 40,
			"item_source": "通过合成获得",
			"item_use_condition": "",
			"item_detail": "纯粹土属性材料，稳固器阵结构",
			"item_rare": "rare",
			"item_anime": "res://assets/animations/item_pickup_common.tres"
		},
		"item_022": {
			"item_name": "元火",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/yuanhuo2.png",
			"item_price": 40,
			"item_source": "通过合成获得",
			"item_use_condition": "",
			"item_detail": "纯粹火属性材料，提升燃性与爆发",
			"item_rare": "rare",
			"item_anime": "res://assets/animations/item_pickup_common.tres"
		},
		"item_023": {
			"item_name": "仙木",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/xianmu.png",
			"item_price": 200,
			"item_source": "击败幼体树精有概率获取",
			"item_use_condition": "",
			"item_detail": "蕴含仙灵气的木材，法器坯料的上佳选择",
			"item_rare": "common",
			"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_024": {
			"item_name": "参精",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/shenjing.png",
			"item_price": 200,
			"item_source": "击败草药精有概率获取",
			"item_use_condition": "",
			"item_detail": "人参的灵性精华，药效强劲",
			"item_rare": "common",
			"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_025": {
			"item_name": "灯油",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/dengyou.png",
			"item_price": 200,
			"item_source": "击败灯笼怪有概率获取",
			"item_use_condition": "",
			"item_detail": "纯净灯油，炼制灵灯或引火法阵的核心材料",
			"item_rare": "rare",
			"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_026": {
			"item_name": "蟾珠",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/chanzhu.png",
			"item_price": 200,
			"item_source": "击败蟾蜍低概率获取",
			"item_use_condition": "",
			"item_detail": "蟾妖腹中灵珠，可稳固毒性与水性术式",
			"item_rare": "rare",
			"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_027": {
			"item_name": "墨精",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/mojing.png",
			"item_price": 200,
			"item_source": "击败宣纸妖有概率获取",
			"item_use_condition": "",
			"item_detail": "上好墨汁精华，刻阵绘符必备",
			"item_rare": "rare",
			"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_028": {
			"item_name": "矿髓",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/kuangsui.png",
			"item_price": 200,
			"item_source": "击败矿灵低概率获取",
			"item_use_condition": "",
			"item_detail": "矿石内核髓质，炼器时提升稳定与强度",
			"item_rare": "rare",
			"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_029": {
			"item_name": "骨粉",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/gufen.png",
			"item_price": 200,
			"item_source": "击败亡灵或兽类获取",
			"item_use_condition": "",
			"item_detail": "研磨而成的骨粉，炼符与炼药的辅材",
			"item_rare": "rare",
			"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_030": {
			"item_name": "雾绢",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/wujuan.png",
			"item_price": 200,
			"item_source": "在雾林采集或击败雾魅低概率获取",
			"item_use_condition": "",
			"item_detail": "薄如雾的绢布，适合包裹灵材与导灵",
			"item_rare": "rare",
			"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_031": {
			"item_name": "水以太",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/shuiyitai.png",
			"item_price": 200,
			"item_source": "击败水属性敌人有低概率获得",
			"item_use_condition": "",
			"item_detail": "高纯度水属性以太，强化水系术式的核心材料",
			"item_rare": "epic", # 传说
				"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_032": {
			"item_name": "风以太",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/fengyitai.png",
			"item_price": 200,
			"item_source": "击败风属性敌人有低概率获得",
			"item_use_condition": "",
			"item_detail": "高纯度风属性以太，提升灵敏与速率",
			"item_rare": "epic", # 传说
				"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_033": {
			"item_name": "雷以太",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/leiyitai.png",
			"item_price": 200,
			"item_source": "击败雷属性敌人有低概率获得",
			"item_use_condition": "",
			"item_detail": "高纯度雷属性以太，增强穿透与爆发",
			"item_rare": "epic", # 传说
				"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_034": {
			"item_name": "土以太",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/tuyitai.png",
			"item_price": 200,
			"item_source": "击败土属性敌人有低概率获得",
			"item_use_condition": "",
			"item_detail": "高纯度土属性以太，提升稳定与防护",
			"item_rare": "epic", # 传说
				"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_035": {
			"item_name": "火以太",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/huoyitai.png",
			"item_price": 200,
			"item_source": "击败火属性敌人有低概率获得",
			"item_use_condition": "",
			"item_detail": "高纯度火属性以太，增强灼烧与爆裂",
			"item_rare": "epic", # 传说
				"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_036": {
			"item_name": "玄露丸",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/xuanludan.png",
			"item_price": 500,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "使玄元（提升HP）修炼上限提升4阶（最多8次）",
			"item_rare": "epic",
			"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_037": {
			"item_name": "化脉丸",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/huamaidan.png",
			"item_price": 500,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "使破虚（提升攻击）修炼上限提升4阶（最多8次）",
			"item_rare": "epic",
			"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_038": {
			"item_name": "汲灵丸",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/jilingdan.png",
			"item_price": 500,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "使化灵（提升灵气获取）修炼上限提升4阶（最多8次）",
			"item_rare": "epic",
			"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_039": {
			"item_name": "迅风丸",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/xunfengdan.png",
			"item_price": 500,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "使流光（提升攻速）修炼上限提升2阶（最多8次）",
			"item_rare": "epic",
			"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_040": {
			"item_name": "回春露",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/huichunlu.png",
			"item_price": 300,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "果实回复效果提升10%（最多10次）",
			"item_rare": "rare",
			"item_anime": "res://assets/animations/item_pickup_common.tres"
		},
		"item_041": {
			"item_name": "仙枝",
			"item_stack_max": 1,
			"item_type": "special",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/xianzhi.png",
			"item_price": 1000,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "获得后，可在战斗之中解锁武器-仙枝的领悟选项",
			"item_rare": "epic", # 传说
				"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_042": {
			"item_name": "柔水",
			"item_stack_max": 1,
			"item_type": "special",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/roushui.png",
			"item_price": 1000,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "获得后，可在战斗之中解锁武器-柔水的领悟选项",
			"item_rare": "epic", # 传说
				"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_043": {
			"item_name": "下篇契纸",
			"item_stack_max": 1,
			"item_type": "special",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/qizhi.png",
			"item_price": 1000,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "解锁合成篇·下篇",
			"item_rare": "epic", # 传说
				"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_044": {
			"item_name": "晶核",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/mojing.png",
			"item_price": 35,
			"item_source": "击败晶属性怪物获取",
			"item_use_condition": "",
			"item_detail": "晶质核心，内含稳定的灵气残留",
			"item_rare": "common",
			"item_anime": "res://assets/animations/item_pickup_common.tres"
		},
		"item_045": {
			"item_name": "草药",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/fenglingcao.png",
			"item_price": 20,
			"item_source": "采集或击败植物系怪物获取",
			"item_use_condition": "",
			"item_detail": "带有淡淡的灵力气息的野地草药",
			"item_rare": "common",
			"item_anime": "res://assets/animations/item_pickup_common.tres"
		},
		"item_046": {
			"item_name": "兽骨",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/gufen.png",
			"item_price": 40,
			"item_source": "击败兽类怪物获取",
			"item_use_condition": "",
			"item_detail": "坚韧的兽骨，可用于炼器与强化护具",
			"item_rare": "common",
			"item_anime": "res://assets/animations/item_pickup_common.tres"
		},
		# ============== 一阶丹药 ==============
		"item_047": {
			"item_name": "破阵散",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/huamaidan.png",
			"item_price": 200,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "使破虚（提升攻击）修炼上限提升2阶（最多10次）",
			"item_rare": "rare",
			"item_anime": "res://assets/animations/item_pickup_common.tres"
		},
		"item_048": {
			"item_name": "固元散",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/xuanludan.png",
			"item_price": 200,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "使玄元（提升HP）修炼上限提升2阶（最多10次）",
			"item_rare": "rare",
			"item_anime": "res://assets/animations/item_pickup_common.tres"
		},
		"item_049": {
			"item_name": "明光散",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/xunfengdan.png",
			"item_price": 200,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "使流光（提升攻速）修炼上限提升1阶（最多10次）",
			"item_rare": "rare",
			"item_anime": "res://assets/animations/item_pickup_common.tres"
		},
		"item_050": {
			"item_name": "引灵散",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/jilingdan.png",
			"item_price": 200,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "使化灵（提升灵气获取）修炼上限提升2阶（最多10次）",
			"item_rare": "rare",
			"item_anime": "res://assets/animations/item_pickup_common.tres"
		},
		"item_051": {
			"item_name": "磨锋散",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/huolingjing.png",
			"item_price": 200,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "使锋锐（提升暴击率）修炼上限提升1阶（最多10次）",
			"item_rare": "rare",
			"item_anime": "res://assets/animations/item_pickup_common.tres"
		},
		"item_052": {
			"item_name": "铁骨散",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/jiake.png",
			"item_price": 200,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "使护体（提升减伤率）修炼上限提升1阶（最多10次）",
			"item_rare": "rare",
			"item_anime": "res://assets/animations/item_pickup_common.tres"
		},
		"item_053": {
			"item_name": "疾步散",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/fenglingcao.png",
			"item_price": 200,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "使追风（提升移速）修炼上限提升1阶（最多10次）",
			"item_rare": "rare",
			"item_anime": "res://assets/animations/item_pickup_common.tres"
		},
		"item_054": {
			"item_name": "爆烈散",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/yuanhuo.png",
			"item_price": 200,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "使烈劲（提升暴击伤害）修炼上限提升2阶（最多10次）",
			"item_rare": "rare",
			"item_anime": "res://assets/animations/item_pickup_common.tres"
		},
		# ============== 二阶丹药（新增） ==============
		"item_055": {
			"item_name": "锐锋丸",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/huolingjing.png",
			"item_price": 500,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "使锋锐（提升暴击率）修炼上限提升2阶（最多8次）",
			"item_rare": "epic",
			"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_056": {
			"item_name": "金身丸",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/jiake.png",
			"item_price": 500,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "使护体（提升减伤率）修炼上限提升2阶（最多8次）",
			"item_rare": "epic",
			"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_057": {
			"item_name": "追风丸",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/xunfengdan.png",
			"item_price": 500,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "使追风（提升移速）修炼上限提升2阶（最多8次）",
			"item_rare": "epic",
			"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_058": {
			"item_name": "烈焰丸",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/yuanhuo.png",
			"item_price": 500,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "使烈劲（提升暴击伤害）修炼上限提升4阶（最多8次）",
			"item_rare": "epic",
			"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		# ============== 三阶丹药 ==============
		"item_060": {
			"item_name": "碎天丹",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/huamaidan.png",
			"item_price": 1000,
			"item_source": "暂无合成途径",
			"item_use_condition": "",
			"item_detail": "使破虚（提升攻击）修炼上限提升6阶（最多6次）",
			"item_rare": "epic",
			"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_061": {
			"item_name": "厚土丹",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/xuanludan.png",
			"item_price": 1000,
			"item_source": "暂无合成途径",
			"item_use_condition": "",
			"item_detail": "使玄元（提升HP）修炼上限提升6阶（最多6次）",
			"item_rare": "epic",
			"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_062": {
			"item_name": "迅影丹",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/xunfengdan.png",
			"item_price": 1000,
			"item_source": "暂无合成途径",
			"item_use_condition": "",
			"item_detail": "使流光（提升攻速）修炼上限提升3阶（最多6次）",
			"item_rare": "epic",
			"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_063": {
			"item_name": "凝灵丹",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/jilingdan.png",
			"item_price": 1000,
			"item_source": "暂无合成途径",
			"item_use_condition": "",
			"item_detail": "使化灵（提升灵气获取）修炼上限提升6阶（最多6次）",
			"item_rare": "epic",
			"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_064": {
			"item_name": "裂锋丹",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/huolingjing.png",
			"item_price": 1000,
			"item_source": "暂无合成途径",
			"item_use_condition": "",
			"item_detail": "使锋锐（提升暴击率）修炼上限提升3阶（最多6次）",
			"item_rare": "epic",
			"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_065": {
			"item_name": "玄甲丹",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/jiake.png",
			"item_price": 1000,
			"item_source": "暂无合成途径",
			"item_use_condition": "",
			"item_detail": "使护体（提升减伤率）修炼上限提升3阶（最多6次）",
			"item_rare": "epic",
			"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_066": {
			"item_name": "御风丹",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/fenglingcao.png",
			"item_price": 1000,
			"item_source": "暂无合成途径",
			"item_use_condition": "",
			"item_detail": "使追风（提升移速）修炼上限提升3阶（最多6次）",
			"item_rare": "epic",
			"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_067": {
			"item_name": "雷霆丹",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/yuanhuo.png",
			"item_price": 1000,
			"item_source": "暂无合成途径",
			"item_use_condition": "",
			"item_detail": "使烈劲（提升暴击伤害）修炼上限提升6阶（最多6次）",
			"item_rare": "epic",
			"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		# ============== 四阶丹药 ==============
		"item_068": {
			"item_name": "灭虚秘药",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/huamaidan.png",
			"item_price": 2000,
			"item_source": "暂无合成途径",
			"item_use_condition": "",
			"item_detail": "使破虚（提升攻击）修炼上限提升8阶（最多4次）",
			"item_rare": "legendary",
			"item_color": Color(1.0, 0.8, 0.0, 1),
			"item_anime": "res://assets/animations/item_pickup_legendary.tres"
		},
		"item_069": {
			"item_name": "不灭秘药",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/xuanludan.png",
			"item_price": 2000,
			"item_source": "暂无合成途径",
			"item_use_condition": "",
			"item_detail": "使玄元（提升HP）修炼上限提升8阶（最多4次）",
			"item_rare": "legendary",
			"item_color": Color(1.0, 0.8, 0.0, 1),
			"item_anime": "res://assets/animations/item_pickup_legendary.tres"
		},
		"item_070": {
			"item_name": "瞬光秘药",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/xunfengdan.png",
			"item_price": 2000,
			"item_source": "暂无合成途径",
			"item_use_condition": "",
			"item_detail": "使流光（提升攻速）修炼上限提升4阶（最多4次）",
			"item_rare": "legendary",
			"item_color": Color(1.0, 0.8, 0.0, 1),
			"item_anime": "res://assets/animations/item_pickup_legendary.tres"
		},
		"item_071": {
			"item_name": "通灵秘药",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/jilingdan.png",
			"item_price": 2000,
			"item_source": "暂无合成途径",
			"item_use_condition": "",
			"item_detail": "使化灵（提升灵气获取）修炼上限提升8阶（最多4次）",
			"item_rare": "legendary",
			"item_color": Color(1.0, 0.8, 0.0, 1),
			"item_anime": "res://assets/animations/item_pickup_legendary.tres"
		},
		"item_072": {
			"item_name": "断魂秘药",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/huolingjing.png",
			"item_price": 2000,
			"item_source": "暂无合成途径",
			"item_use_condition": "",
			"item_detail": "使锋锐（提升暴击率）修炼上限提升4阶（最多4次）",
			"item_rare": "legendary",
			"item_color": Color(1.0, 0.8, 0.0, 1),
			"item_anime": "res://assets/animations/item_pickup_legendary.tres"
		},
		"item_073": {
			"item_name": "金刚秘药",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/jiake.png",
			"item_price": 2000,
			"item_source": "暂无合成途径",
			"item_use_condition": "",
			"item_detail": "使护体（提升减伤率）修炼上限提升4阶（最多4次）",
			"item_rare": "legendary",
			"item_color": Color(1.0, 0.8, 0.0, 1),
			"item_anime": "res://assets/animations/item_pickup_legendary.tres"
		},
		"item_074": {
			"item_name": "疾影秘药",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/fenglingcao.png",
			"item_price": 2000,
			"item_source": "暂无合成途径",
			"item_use_condition": "",
			"item_detail": "使追风（提升移速）修炼上限提升4阶（最多4次）",
			"item_rare": "legendary",
			"item_color": Color(1.0, 0.8, 0.0, 1),
			"item_anime": "res://assets/animations/item_pickup_legendary.tres"
		},
		"item_075": {
			"item_name": "焚天秘药",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/yuanhuo.png",
			"item_price": 2000,
			"item_source": "暂无合成途径",
			"item_use_condition": "",
			"item_detail": "使烈劲（提升暴击伤害）修炼上限提升8阶（最多4次）",
			"item_rare": "legendary",
			"item_color": Color(1.0, 0.8, 0.0, 1),
			"item_anime": "res://assets/animations/item_pickup_legendary.tres"
		},
		# ============== 五阶丹药 ==============
		"item_076": {
			"item_name": "破虚神丹",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/huamaidan.png",
			"item_price": 5000,
			"item_source": "暂无合成途径",
			"item_use_condition": "",
			"item_detail": "使破虚（提升攻击）修炼上限提升10阶（最多3次）",
			"item_rare": "artifact",
			"item_color": Color(1.0, 0.2, 0.2, 1),
			"item_anime": "res://assets/animations/item_pickup_legendary.tres"
		},
		"item_077": {
			"item_name": "玄元神丹",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/xuanludan.png",
			"item_price": 5000,
			"item_source": "暂无合成途径",
			"item_use_condition": "",
			"item_detail": "使玄元（提升HP）修炼上限提升10阶（最多3次）",
			"item_rare": "artifact",
			"item_color": Color(1.0, 0.2, 0.2, 1),
			"item_anime": "res://assets/animations/item_pickup_legendary.tres"
		},
		"item_078": {
			"item_name": "流光神丹",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/xunfengdan.png",
			"item_price": 5000,
			"item_source": "暂无合成途径",
			"item_use_condition": "",
			"item_detail": "使流光（提升攻速）修炼上限提升5阶（最多3次）",
			"item_rare": "artifact",
			"item_color": Color(1.0, 0.2, 0.2, 1),
			"item_anime": "res://assets/animations/item_pickup_legendary.tres"
		},
		"item_079": {
			"item_name": "化灵神丹",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/jilingdan.png",
			"item_price": 5000,
			"item_source": "暂无合成途径",
			"item_use_condition": "",
			"item_detail": "使化灵（提升灵气获取）修炼上限提升10阶（最多3次）",
			"item_rare": "artifact",
			"item_color": Color(1.0, 0.2, 0.2, 1),
			"item_anime": "res://assets/animations/item_pickup_legendary.tres"
		},
		"item_080": {
			"item_name": "锋锐神丹",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/huolingjing.png",
			"item_price": 5000,
			"item_source": "暂无合成途径",
			"item_use_condition": "",
			"item_detail": "使锋锐（提升暴击率）修炼上限提升5阶（最多3次）",
			"item_rare": "artifact",
			"item_color": Color(1.0, 0.2, 0.2, 1),
			"item_anime": "res://assets/animations/item_pickup_legendary.tres"
		},
		"item_081": {
			"item_name": "护体神丹",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/jiake.png",
			"item_price": 5000,
			"item_source": "暂无合成途径",
			"item_use_condition": "",
			"item_detail": "使护体（提升减伤率）修炼上限提升5阶（最多3次）",
			"item_rare": "artifact",
			"item_color": Color(1.0, 0.2, 0.2, 1),
			"item_anime": "res://assets/animations/item_pickup_legendary.tres"
		},
		"item_082": {
			"item_name": "追风神丹",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/fenglingcao.png",
			"item_price": 5000,
			"item_source": "暂无合成途径",
			"item_use_condition": "",
			"item_detail": "使追风（提升移速）修炼上限提升5阶（最多3次）",
			"item_rare": "artifact",
			"item_color": Color(1.0, 0.2, 0.2, 1),
			"item_anime": "res://assets/animations/item_pickup_legendary.tres"
		},
		"item_083": {
			"item_name": "烈劲神丹",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/yuanhuo.png",
			"item_price": 5000,
			"item_source": "暂无合成途径",
			"item_use_condition": "",
			"item_detail": "使烈劲（提升暴击伤害）修炼上限提升10阶（最多3次）",
			"item_rare": "artifact",
			"item_color": Color(1.0, 0.2, 0.2, 1),
			"item_anime": "res://assets/animations/item_pickup_legendary.tres"
		},
		# ============== 特殊秘丹 ==============
		"item_085": {
			"item_name": "卫护玄丹",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/jiake.png",
			"item_price": 300,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "护盾率与治疗率各提升0.3%（最多50次）",
			"item_rare": "common",
			"item_anime": "res://assets/animations/item_pickup_common.tres"
		},
		"item_086": {
			"item_name": "卫护地丹",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/jiake.png",
			"item_price": 600,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "护盾率与治疗率各提升0.5%（最多20次）",
			"item_rare": "rare",
			"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_087": {
			"item_name": "卫护天丹",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/jiake.png",
			"item_price": 1000,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "护盾率与治疗率各提升0.75%（最多10次）",
			"item_rare": "epic",
			"item_anime": "res://assets/animations/item_pickup_epic.tres"
		},
		"item_088": {
			"item_name": "宝藏玄丹",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/jilingdan.png",
			"item_price": 300,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "经验获取率与掉落率各提升0.3%（最多50次）",
			"item_rare": "common",
			"item_anime": "res://assets/animations/item_pickup_common.tres"
		},
		"item_089": {
			"item_name": "宝藏地丹",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/jilingdan.png",
			"item_price": 600,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "经验获取率与掉落率各提升0.5%（最多20次）",
			"item_rare": "rare",
			"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_090": {
			"item_name": "宝藏天丹",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/jilingdan.png",
			"item_price": 1000,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "经验获取率与掉落率各提升0.75%（最多10次）",
			"item_rare": "epic",
			"item_anime": "res://assets/animations/item_pickup_epic.tres"
		},
		"item_091": {
			"item_name": "噬敌玄丹",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/huamaidan.png",
			"item_price": 300,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "对小怪伤害率与首领伤害率各提升0.3%（最多50次）",
			"item_rare": "common",
			"item_anime": "res://assets/animations/item_pickup_common.tres"
		},
		"item_092": {
			"item_name": "噬敌地丹",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/huamaidan.png",
			"item_price": 600,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "对小怪伤害率与首领伤害率各提升0.5%（最多20次）",
			"item_rare": "rare",
			"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_093": {
			"item_name": "噬敌天丹",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/huamaidan.png",
			"item_price": 1000,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "对小怪伤害率与首领伤害率各提升0.75%（最多10次）",
			"item_rare": "epic",
			"item_anime": "res://assets/animations/item_pickup_epic.tres"
		},
		"item_094": {
			"item_name": "形体玄丹",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/xunfengdan.png",
			"item_price": 300,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "体型大小降低0.3%，攻击范围提升0.3%（最多50次）",
			"item_rare": "common",
			"item_anime": "res://assets/animations/item_pickup_common.tres"
		},
		"item_095": {
			"item_name": "中级形体秘丹",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/xunfengdan.png",
			"item_price": 600,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "体型大小降低0.5%，攻击范围提升0.5%（最多20次）",
			"item_rare": "rare",
			"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_096": {
			"item_name": "上级形体秘丹",
			"item_stack_max": 99,
			"item_type": "consumable",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/xunfengdan.png",
			"item_price": 1000,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "体型大小降低0.75%，攻击范围提升0.75%（最多10次）",
			"item_rare": "epic",
			"item_anime": "res://assets/animations/item_pickup_epic.tres"
		},
		# ============== Boss材料 ==============
		"item_097": {
			"item_name": "锐之魔核",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/huamaidan.png",
			"item_price": 500,
			"item_source": "击败Boss获取",
			"item_use_condition": "",
			"item_detail": "蕴含锋锐魔性的核心材料，可用于武器强化相关内容。",
			"item_rare": "epic",
			"item_anime": "res://assets/animations/item_pickup_epic.tres"
		},
		"item_098": {
			"item_name": "簇之魔核",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/jiake.png",
			"item_price": 500,
			"item_source": "击败Boss获取",
			"item_use_condition": "",
			"item_detail": "聚拢群体力量的魔核，可用于团队强化相关内容。",
			"item_rare": "epic",
			"item_anime": "res://assets/animations/item_pickup_epic.tres"
		},
		"item_099": {
			"item_name": "启之魔核",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/jilingdan.png",
			"item_price": 500,
			"item_source": "击败Boss获取",
			"item_use_condition": "",
			"item_detail": "内藏启悟之力的魔核，可用于技能强化相关内容。",
			"item_rare": "epic",
			"item_anime": "res://assets/animations/item_pickup_epic.tres"
		},
		"item_100": {
			"item_name": "砺之魔核",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/mojing.png",
			"item_price": 500,
			"item_source": "击败Boss获取",
			"item_use_condition": "",
			"item_detail": "经过反复淬砺的魔核，可用于通用强化相关内容。",
			"item_rare": "epic",
			"item_anime": "res://assets/animations/item_pickup_epic.tres"
		},
		"item_101": {
			"item_name": "衍之魔核",
			"item_stack_max": 9999,
			"item_type": "material",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/qizhi.png",
			"item_price": 500,
			"item_source": "击败Boss获取",
			"item_use_condition": "",
			"item_detail": "具有衍化特性的魔核，可用于特殊强化相关内容。",
			"item_rare": "epic",
			"item_anime": "res://assets/animations/item_pickup_epic.tres"
		},
		# ============== 特殊物品 ==============
		"item_059": {

			"item_name": "进货单",
			"item_stack_max": 99,
			"item_type": "special",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/qizhi.png",
			"item_price": 300,
			"item_source": "合成获得",
			"item_use_condition": "",
			"item_detail": "记录着货物清单的纸条，可用于商店进货",
			"item_rare": "rare",
			"item_anime": "res://assets/animations/item_pickup_rare.tres"
		},
		"item_084": {
			"item_name": "灵石",
			"item_stack_max": 999999,
			"item_type": "special",
			"item_icon": "res://AssetBundle/Sprites/Sprite sheets/item_icon/juling.png",
			"item_price": 0,
			"item_source": "由灵髓碎片合成获得",
			"item_use_condition": "",
			"item_detail": "常用的通用货币，可由灵髓碎片炼化而成。",
			"item_rare": "legendary",
			"item_color": Color(1.0, 0.85, 0.2, 1),
			"item_anime": "res://assets/animations/item_pickup_legendary.tres"
		}
		# 更多物品可以添加到这里
	}

# 物品效果处理函数
var item_function = {
	"item_001": "_on_item_001_picked_up"
}

# 可使用物品列表
# 注意：立即生效的物品（如野果）不应该在这里，它们在拾取时直接生效
var usable_items = {
	"item_001": true,
	"item_036": true, # 玄露丹（二阶）
	"item_037": true, # 化脉丹（二阶）
	"item_038": true, # 汲灵丹（二阶）
	"item_039": true, # 迅风丹（二阶）
	"item_040": true, # 回春露
	"item_047": true, # 破阵散（一阶）
	"item_048": true, # 固元散（一阶）
	"item_049": true, # 明光散（一阶）
	"item_050": true, # 引灵散（一阶）
	"item_051": true, # 磨锋散（一阶）
	"item_052": true, # 铁骨散（一阶）
	"item_053": true, # 疾步散（一阶）
	"item_054": true, # 爆烈散（一阶）
	"item_055": true, # 锐锋丹（二阶）
	"item_056": true, # 金身丹（二阶）
	"item_057": true, # 追风丹（二阶）
	"item_058": true, # 烈焰丹（二阶）
	"item_060": true, # 碎天丸（三阶）
	"item_061": true, # 厚土丸（三阶）
	"item_062": true, # 迅影丸（三阶）
	"item_063": true, # 凝灵丸（三阶）
	"item_064": true, # 裂锋丸（三阶）
	"item_065": true, # 玄甲丸（三阶）
	"item_066": true, # 御风丸（三阶）
	"item_067": true, # 雷霆丸（三阶）
	"item_068": true, # 灭虚膏（四阶）
	"item_069": true, # 不灭膏（四阶）
	"item_070": true, # 瞬光膏（四阶）
	"item_071": true, # 通灵膏（四阶）
	"item_072": true, # 断魂膏（四阶）
	"item_073": true, # 金刚膏（四阶）
	"item_074": true, # 疾影膏（四阶）
	"item_075": true, # 焚天膏（四阶）
	"item_076": true, # 天罡破虚露（五阶）
	"item_077": true, # 天罡玄元露（五阶）
	"item_078": true, # 天罡流光露（五阶）
	"item_079": true, # 天罡化灵露（五阶）
	"item_080": true, # 天罡锋锐露（五阶）
	"item_081": true, # 天罡护体露（五阶）
	"item_082": true, # 天罡追风露（五阶）
	"item_083": true, # 天罡烈劲露（五阶）
	"item_085": true, # 下级卫护秘丹
	"item_086": true, # 中级卫护秘丹
	"item_087": true, # 上级卫护秘丹
	"item_088": true, # 下级宝藏秘丹
	"item_089": true, # 中级宝藏秘丹
	"item_090": true, # 上级宝藏秘丹
	"item_091": true, # 下级噬敌秘丹
	"item_092": true, # 中级噬敌秘丹
	"item_093": true, # 上级噬敌秘丹
	"item_094": true, # 下级形体秘丹
	"item_095": true, # 中级形体秘丹
	"item_096": true # 上级形体秘丹
}

# 丹药效果配置表：item_id -> {"var": 全局变量名, "bonus": 每次加成, "max_uses": 最大使用次数}
var pill_config = {
	# 一阶丹药（最多10次）
	"item_047": {"var": "cultivation_poxu_level_max", "bonus": 2, "max_uses": 10},
	"item_048": {"var": "cultivation_xuanyuan_level_max", "bonus": 2, "max_uses": 10},
	"item_049": {"var": "cultivation_liuguang_level_max", "bonus": 1, "max_uses": 10},
	"item_050": {"var": "cultivation_hualing_level_max", "bonus": 2, "max_uses": 10},
	"item_051": {"var": "cultivation_fengrui_level_max", "bonus": 1, "max_uses": 10},
	"item_052": {"var": "cultivation_huti_level_max", "bonus": 1, "max_uses": 10},
	"item_053": {"var": "cultivation_zhuifeng_level_max", "bonus": 1, "max_uses": 10},
	"item_054": {"var": "cultivation_liejin_level_max", "bonus": 2, "max_uses": 10},
	# 二阶丹药（最多8次）
	"item_037": {"var": "cultivation_poxu_level_max", "bonus": 4, "max_uses": 8},
	"item_036": {"var": "cultivation_xuanyuan_level_max", "bonus": 4, "max_uses": 8},
	"item_039": {"var": "cultivation_liuguang_level_max", "bonus": 2, "max_uses": 8},
	"item_038": {"var": "cultivation_hualing_level_max", "bonus": 4, "max_uses": 8},
	"item_055": {"var": "cultivation_fengrui_level_max", "bonus": 2, "max_uses": 8},
	"item_056": {"var": "cultivation_huti_level_max", "bonus": 2, "max_uses": 8},
	"item_057": {"var": "cultivation_zhuifeng_level_max", "bonus": 2, "max_uses": 8},
	"item_058": {"var": "cultivation_liejin_level_max", "bonus": 4, "max_uses": 8},
	# 三阶丹药（最多6次）
	"item_060": {"var": "cultivation_poxu_level_max", "bonus": 6, "max_uses": 6},
	"item_061": {"var": "cultivation_xuanyuan_level_max", "bonus": 6, "max_uses": 6},
	"item_062": {"var": "cultivation_liuguang_level_max", "bonus": 3, "max_uses": 6},
	"item_063": {"var": "cultivation_hualing_level_max", "bonus": 6, "max_uses": 6},
	"item_064": {"var": "cultivation_fengrui_level_max", "bonus": 3, "max_uses": 6},
	"item_065": {"var": "cultivation_huti_level_max", "bonus": 3, "max_uses": 6},
	"item_066": {"var": "cultivation_zhuifeng_level_max", "bonus": 3, "max_uses": 6},
	"item_067": {"var": "cultivation_liejin_level_max", "bonus": 6, "max_uses": 6},
	# 四阶丹药（最多4次）
	"item_068": {"var": "cultivation_poxu_level_max", "bonus": 8, "max_uses": 4},
	"item_069": {"var": "cultivation_xuanyuan_level_max", "bonus": 8, "max_uses": 4},
	"item_070": {"var": "cultivation_liuguang_level_max", "bonus": 4, "max_uses": 4},
	"item_071": {"var": "cultivation_hualing_level_max", "bonus": 8, "max_uses": 4},
	"item_072": {"var": "cultivation_fengrui_level_max", "bonus": 4, "max_uses": 4},
	"item_073": {"var": "cultivation_huti_level_max", "bonus": 4, "max_uses": 4},
	"item_074": {"var": "cultivation_zhuifeng_level_max", "bonus": 4, "max_uses": 4},
	"item_075": {"var": "cultivation_liejin_level_max", "bonus": 8, "max_uses": 4},
	# 五阶丹药（最多3次）
	"item_076": {"var": "cultivation_poxu_level_max", "bonus": 10, "max_uses": 3},
	"item_077": {"var": "cultivation_xuanyuan_level_max", "bonus": 10, "max_uses": 3},
	"item_078": {"var": "cultivation_liuguang_level_max", "bonus": 5, "max_uses": 3},
	"item_079": {"var": "cultivation_hualing_level_max", "bonus": 10, "max_uses": 3},
	"item_080": {"var": "cultivation_fengrui_level_max", "bonus": 5, "max_uses": 3},
	"item_081": {"var": "cultivation_huti_level_max", "bonus": 5, "max_uses": 3},
	"item_082": {"var": "cultivation_zhuifeng_level_max", "bonus": 5, "max_uses": 3},
	"item_083": {"var": "cultivation_liejin_level_max", "bonus": 10, "max_uses": 3},
	# 特殊秘丹（下级/中级/上级）
	"item_085": {"effects": {"sheild_multi": 0.003, "heal_multi": 0.003}, "tier": "lower"},
	"item_086": {"effects": {"sheild_multi": 0.005, "heal_multi": 0.005}, "tier": "middle"},
	"item_087": {"effects": {"sheild_multi": 0.0075, "heal_multi": 0.0075}, "tier": "upper"},
	"item_088": {"effects": {"exp_multi": 0.003, "drop_multi": 0.003}, "tier": "lower"},
	"item_089": {"effects": {"exp_multi": 0.005, "drop_multi": 0.005}, "tier": "middle"},
	"item_090": {"effects": {"exp_multi": 0.0075, "drop_multi": 0.0075}, "tier": "upper"},
	"item_091": {"effects": {"normal_monster_multi": 0.003, "boss_multi": 0.003}, "tier": "lower"},
	"item_092": {"effects": {"normal_monster_multi": 0.005, "boss_multi": 0.005}, "tier": "middle"},
	"item_093": {"effects": {"normal_monster_multi": 0.0075, "boss_multi": 0.0075}, "tier": "upper"},
	"item_094": {"effects": {"body_size": -0.003, "attack_range": 0.003}, "tier": "lower"},
	"item_095": {"effects": {"body_size": -0.005, "attack_range": 0.005}, "tier": "middle"},
	"item_096": {"effects": {"body_size": -0.0075, "attack_range": 0.0075}, "tier": "upper"}
}

# 根据物品ID获取该物品的所有数据
func get_item_all_data(item_id: String) -> Dictionary:
	if items_data.has(item_id):
		return items_data[item_id]
	else:
		printerr("Item not found: ", item_id)
		return {}

# 根据物品ID和属性名获取特定属性值
func get_item_property(item_id: String, property_name: String):
	if items_data.has(item_id):
		var item_info = items_data[item_id]
		if item_info.has(property_name):
			return item_info[property_name]
		else:
			printerr("Property not found for item '", item_id, "': ", property_name)
			return null
	else:
		printerr("Item not found: ", item_id)
		return null

# 野果拾取函数
func _on_item_001_picked_up(_player, _item_id := ""):
	if PC.is_game_over:
		return false
	# 只有满血时才能拾取
	#if PC.pc_hp != PC.pc_max_hp:
		#PC.pc_hp += PC.pc_max_hp * 0.2
		## 防止生命值超过上限
		#if PC.pc_hp > PC.pc_max_hp:
			#PC.pc_hp = PC.pc_max_hp
		#return true # 表示成功拾取
	#else:
		#return false # 表示无法拾取
	var base_heal = PC.pc_max_hp * 0.2
	var final_heal = base_heal * (1 + PC.heal_multi + Global.fruit_heal_multi)
	PC.pc_hp += int(final_heal)
	# 防止生命值超过上限
	if PC.pc_hp > PC.pc_max_hp:
		PC.pc_hp = PC.pc_max_hp

	
	return true # 表示成功拾取

func on_item_picked_up(_player, item_id: String) -> bool:
	return _add_to_inventory(item_id)


func _add_to_inventory(item_id: String) -> bool:
	if !Global.player_inventory.has(item_id):
		Global.player_inventory[item_id] = 1
	else:
		Global.player_inventory[item_id] += 1
	return true


# 使用物品（主要用于解锁配方）
func use_item(item_id: String, count: int = 1) -> Dictionary:
	var result = {
		"success": false,
		"message": "",
		"unlocked_recipes": []
	}
	
	# 检查物品是否存在
	if !items_data.has(item_id):
		result.message = "物品不存在"
		return result
	
	# 检查物品是否可使用
	if !usable_items.has(item_id) or !usable_items[item_id]:
		result.message = "该物品无法使用"
		return result
	
	# 检查背包中是否有足够的物品
	if !Global.player_inventory.has(item_id):
		result.message = "背包中没有该物品"
		return result
	
	if Global.player_inventory[item_id] < count:
		result.message = "物品数量不足"
		return result
	
	# 执行物品使用效果
	var use_success = _execute_item_use_effect(item_id, count)
	if !use_success:
		result.message = "使用失败，已达到最大使用次数"
		return result
	
	# 消耗物品（某些物品使用后不消耗，如装备）
	var item_type = get_item_property(item_id, "item_type")
	if item_type != "equip": # 装备类物品不消耗
		Global.player_inventory[item_id] -= count
		if Global.player_inventory[item_id] <= 0:
			Global.player_inventory.erase(item_id)
	
	# 尝试解锁配方
	# var unlocked_recipes = Global.unlock_recipes_by_item(item_id)
	# result.unlocked_recipes = unlocked_recipes
	
	result.success = true
	result.message = "物品使用成功"
	# if unlocked_recipes.size() > 0:
	# 	result.message += "，解锁了新配方！"
	
	return result

func _get_pill_max_uses(cfg: Dictionary) -> int:
	if cfg.has("tier"):
		return Global.get_special_pill_max_uses(str(cfg["tier"]))
	return int(cfg.get("max_uses", 0))

func _apply_effect_pill(cfg: Dictionary, actual: int) -> void:
	var effects: Dictionary = cfg.get("effects", {})
	for stat_name in effects.keys():
		var next_value = float(Global.get(stat_name)) + float(effects[stat_name]) * actual
		if stat_name == "attack_range" or stat_name == "body_size":
			next_value = max(0.01, next_value)
		Global.set(stat_name, next_value)
		if typeof(PC) != TYPE_NIL and PC != null:
			if stat_name == "attack_range" and PC.has_method("set_attack_range_value"):
				PC.set_attack_range_value(next_value)
			else:
				PC.set(stat_name, next_value)

# 执行物品使用效果
func _execute_item_use_effect(item_id: String, count: int) -> bool:
	# 丹药类：通过 pill_config 数据驱动处理
	if pill_config.has(item_id):
		var cfg = pill_config[item_id]
		var used = int(Global.pill_used_counts.get(item_id, 0))
		var max_uses = _get_pill_max_uses(cfg)
		var remaining = max_uses - used
		if remaining <= 0:
			return false
		var actual = min(count, remaining)
		if cfg.has("effects"):
			_apply_effect_pill(cfg, actual)
		else:
			Global.set(cfg["var"], Global.get(cfg["var"]) + cfg.bonus * actual)
		Global.pill_used_counts[item_id] = used + actual
		return true
	# 非丹药类物品
	match item_id:
		"item_008":
			return true
		"item_040": # 回春露 - 果实回复效果提升10%（最多10次）
			var remaining_uses = 10 - Global.fruit_heal_multi_used_count
			if remaining_uses <= 0:
				return false
			var actual_uses = min(count, remaining_uses)
			Global.fruit_heal_multi += 0.1 * actual_uses
			Global.fruit_heal_multi_used_count += actual_uses
			return true
		_:
			printerr("未知的物品使用效果: ", item_id)
			return false

# 检查物品是否可使用
func can_use_item(item_id: String) -> bool:
	if !items_data.has(item_id):
		return false
	return usable_items.has(item_id) and usable_items[item_id]

# 获取物品使用描述
func get_item_use_description(item_id: String) -> String:
	match item_id:
		_:
			return "未知效果"
