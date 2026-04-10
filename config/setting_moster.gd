extends Node

func _calc_atk(base_atk: float) -> float:
	var t = PC.real_time
	return (6.67 * base_atk + t) / 7.5 * (1 + ((Global.world_level_multiple - 1) / 3)) * 10.0 * pow(1.02, PC.pc_lv - 1)

# 计算新武器带来的怪物血量加成
# 前4把新武器分别提升 30%/20%/15%/10%
func _get_new_weapon_hp_multiplier() -> float:
	var count = PC.new_weapon_obtained_count
	var multiplier = 1.0
	if count >= 1:
		multiplier *= 1.50
	if count >= 2:
		multiplier *= 1.35
	if count >= 3:
		multiplier *= 1.2
	if count >= 4:
		multiplier *= 1.15
	if count >= 5:
		multiplier *= 1.1
	return multiplier

func _calc_hp(base_hp: float) -> float:
	var t = PC.real_time
	var lv_bonus = pow(1.1, PC.pc_lv - 1) # 玩家每升1级，怪物血量提升10%
	var new_weapon_bonus = _get_new_weapon_hp_multiplier() # 新武器带来的血量加成
	return 1.45 * (base_hp + t / 3.0) * (1.0 + 5 * t / 8000.0 + t * t / 60000.0) * Global.world_level_multiple * lv_bonus * new_weapon_bonus

# ============== 关卡1 桃林(PEACH_GROVE) ==============
# slime_blue(5), taohua_yao(2), frog(1)
# ATK/HP 基准值(×1.0)

func slime_blue(query: String): # 蓝色史莱姆
	var data = {
		"atk": _calc_atk(13),
		"hp": _calc_hp(25),
		"speed": 42,
		"exp": 350,
		"point": 10 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 6,
		"itemdrop": {"item_001": 0.015 * (1 + (PC.drop_multi)), "item_002": 0.015 * (1 + (PC.drop_multi)), "item_009": 0.006 * (1 + (PC.drop_multi)), "item_007": 0.005 * (1 + (PC.drop_multi)), "item_004": 0.005 * (1 + (PC.drop_multi))}
	}
	return data.get(query, null)

func taohua_yao(query: String): # 桃花妖
	var data = {
		"atk": _calc_atk(18),
		"hp": _calc_hp(30),
		"speed": 36,
		"exp": 450,
		"point": 15 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 7,
		"itemdrop": {"item_001": 0.015 * (1 + (PC.drop_multi)), "item_003": 0.03 * (1 + (PC.drop_multi)), "item_014": 0.012 * (1 + (PC.drop_multi)), "item_007": 0.005 * (1 + (PC.drop_multi)), "item_004": 0.005 * (1 + (PC.drop_multi))}
	}
	return data.get(query, null)

func frog(query: String): # 幼体树精
	var data = {
		"atk": _calc_atk(10),
		"hp": _calc_hp(22),
		"speed": 35,
		"exp": 500,
		"point": 20 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 8,
		"itemdrop": {"item_001": 0.015 * (1 + (PC.drop_multi)), "item_023": 0.05 * (1 + (PC.drop_multi)), "item_010": 0.015 * (1 + (PC.drop_multi)), "item_007": 0.005 * (1 + (PC.drop_multi)), "item_004": 0.005 * (1 + (PC.drop_multi))}
	}
	return data.get(query, null)

# ============== 关卡2 废墟(RUIN) ==============
# lantern(4), paper(4), bat(1), slime_grey(1)
# ATK/HP 比关卡1提升50%(×1.5)

func lantern(query: String): # 灯笼怪
	var data = {
		"atk": _calc_atk(25),
		"hp": _calc_hp(45),
		"speed": 38,
		"exp": 450,
		"point": 14 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 6,
		"itemdrop": {"item_001": 0.015 * (1 + (PC.drop_multi)), "item_011": 0.015 * (1 + (PC.drop_multi)), "item_015": 0.006 * (1 + (PC.drop_multi)), "item_007": 0.005 * (1 + (PC.drop_multi)), "item_004": 0.005 * (1 + (PC.drop_multi))}
	}
	return data.get(query, null)

func paper(query: String): # 宣纸精
	var data = {
		"atk": _calc_atk(19),
		"hp": _calc_hp(38),
		"speed": 42,
		"exp": 500,
		"point": 13 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 6,
		"itemdrop": {"item_001": 0.015 * (1 + (PC.drop_multi)), "item_011": 0.015 * (1 + (PC.drop_multi)), "item_017": 0.006 * (1 + (PC.drop_multi)), "item_007": 0.005 * (1 + (PC.drop_multi)), "item_004": 0.005 * (1 + (PC.drop_multi))}
	}
	return data.get(query, null)

func bat(query: String): # 草药怪
	var data = {
		"atk": _calc_atk(19),
		"hp": _calc_hp(45),
		"speed": 36,
		"exp": 600,
		"point": 15 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 7,
		"itemdrop": {"item_001": 0.015 * (1 + (PC.drop_multi)), "item_045": 0.05 * (1 + (PC.drop_multi)), "item_010": 0.015 * (1 + (PC.drop_multi)), "item_007": 0.005 * (1 + (PC.drop_multi)), "item_004": 0.005 * (1 + (PC.drop_multi))}
	}
	return data.get(query, null)

func slime_grey(query: String): # 灰色史莱姆
	var data = {
		"atk": _calc_atk(23),
		"hp": _calc_hp(38),
		"speed": 36,
		"exp": 550,
		"point": 16 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 7,
		"itemdrop": {"item_001": 0.015 * (1 + (PC.drop_multi)), "item_002": 0.05 * (1 + (PC.drop_multi)), "item_009": 0.015 * (1 + (PC.drop_multi)), "item_007": 0.005 * (1 + (PC.drop_multi)), "item_004": 0.005 * (1 + (PC.drop_multi))}
	}
	return data.get(query, null)

# ============== 关卡3 洞窟(CAVE) ==============
# ghost(4), armor_stone(4), stone_man(1), slime_green(1)
# ATK/HP 比关卡1提升125%(×2.25)

func ghost(query: String): # 鬼魂
	var data = {
		"atk": _calc_atk(34),
		"hp": _calc_hp(56),
		"speed": 45,
		"exp": 500,
		"point": 18 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 7,
		"itemdrop": {"item_001": 0.015 * (1 + (PC.drop_multi)), "item_003": 0.02 * (1 + (PC.drop_multi)), "item_017": 0.0075 * (1 + (PC.drop_multi)), "item_007": 0.005 * (1 + (PC.drop_multi)), "item_004": 0.005 * (1 + (PC.drop_multi))}
	}
	return data.get(query, null)

func armor_stone(query: String): # 甲石
	var data = {
		"atk": _calc_atk(40),
		"hp": _calc_hp(68),
		"speed": 32,
		"exp": 400,
		"point": 19 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 7,
		"itemdrop": {"item_001": 0.015 * (1 + (PC.drop_multi)), "item_044": 0.02 * (1 + (PC.drop_multi)), "item_014": 0.0075 * (1 + (PC.drop_multi)), "item_007": 0.005 * (1 + (PC.drop_multi)), "item_004": 0.005 * (1 + (PC.drop_multi))}
	}
	return data.get(query, null)

func stone_man(query: String): # 石人
	var data = {
		"atk": _calc_atk(40),
		"hp": _calc_hp(68),
		"speed": 28,
		"exp": 550,
		"point": 22 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 8,
		"itemdrop": {"item_001": 0.015 * (1 + (PC.drop_multi)), "item_044": 0.05 * (1 + (PC.drop_multi)), "item_014": 0.015 * (1 + (PC.drop_multi)), "item_007": 0.005 * (1 + (PC.drop_multi)), "item_004": 0.005 * (1 + (PC.drop_multi))}
	}
	return data.get(query, null)

func slime_green(query: String): # 绿色史莱姆
	var data = {
		"atk": _calc_atk(34),
		"hp": _calc_hp(56),
		"speed": 42,
		"exp": 550,
		"point": 16 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 8,
		"itemdrop": {"item_001": 0.015 * (1 + (PC.drop_multi)), "item_002": 0.05 * (1 + (PC.drop_multi)), "item_009": 0.015 * (1 + (PC.drop_multi)), "item_007": 0.005 * (1 + (PC.drop_multi)), "item_004": 0.005 * (1 + (PC.drop_multi))}
	}
	return data.get(query, null)

# ============== 关卡4 森林(FOREST) ==============
# shen(6), frog_new(2), slime_green(3), ball(3)
# ATK/HP 比关卡1提升237.5%(×3.375)

func shen(query: String): # 参精怪
	var data = {
		"atk": _calc_atk(51),
		"hp": _calc_hp(84),
		"speed": 42,
		"exp": 450,
		"point": 24 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 7,
		"itemdrop": {"item_001": 0.015 * (1 + (PC.drop_multi)), "item_045": 0.02 * (1 + (PC.drop_multi)), "item_015": 0.0075 * (1 + (PC.drop_multi)), "item_007": 0.005 * (1 + (PC.drop_multi)), "item_004": 0.005 * (1 + (PC.drop_multi))}
	}
	return data.get(query, null)

func frog_new(query: String): # 新蛙
	var data = {
		"atk": _calc_atk(41),
		"hp": _calc_hp(74),
		"speed": 35,
		"exp": 600,
		"point": 22 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 7,
		"itemdrop": {"item_001": 0.015 * (1 + (PC.drop_multi)), "item_003": 0.02 * (1 + (PC.drop_multi)), "item_010": 0.0075 * (1 + (PC.drop_multi)), "item_007": 0.005 * (1 + (PC.drop_multi)), "item_004": 0.005 * (1 + (PC.drop_multi))}
	}
	return data.get(query, null)

func ball(query: String): # 弹跳兽
	var data = {
		"atk": _calc_atk(60),
		"hp": _calc_hp(101),
		"speed": 50,
		"exp": 500,
		"point": 26 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 8,
		"itemdrop": {"item_001": 0.015 * (1 + (PC.drop_multi)), "item_046": 0.05 * (1 + (PC.drop_multi)), "item_010": 0.015 * (1 + (PC.drop_multi)), "item_007": 0.005 * (1 + (PC.drop_multi)), "item_004": 0.005 * (1 + (PC.drop_multi))}
	}
	return data.get(query, null)
