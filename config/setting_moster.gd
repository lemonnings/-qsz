extends Node


func _get_current_stage_multiplier() -> float:
	# 当前没有进入正式关卡时，倍率默认回到 1.0。
	# 这样在主城、菜单或直接打开脚本时，不会因为缺少上下文导致数值异常。
	if typeof(Global) == TYPE_NIL:
		return 1.0
	return max(Global.get_current_stage_stat_multiplier(), 1.0)

func _calc_stage_scaled_value(base_value: float) -> float:
	# 怪物基础值现在只吃“当前关卡难度倍率”。
	# 这样配置更直观，你看到多少基础值，就能直接推算出进图后的结果。
	return base_value * _get_current_stage_multiplier()

func _calc_atk(base_atk: float) -> float:
	var t = PC.real_time
	return base_atk + (1.33 * t) * pow(1.02, PC.pc_lv - 1) * _get_current_stage_multiplier()

# 计算新武器带来的怪物血量加成
func _get_new_weapon_hp_multiplier() -> float:
	var count = PC.new_weapon_obtained_count
	var multiplier = 1.0
	if count >= 1:
		multiplier *= 1.65
	if count >= 2:
		multiplier *= 1.4
	if count >= 3:
		multiplier *= 1.3
	if count >= 4:
		multiplier *= 1.25
	if count >= 5:
		multiplier *= 1.2
	return multiplier

func _calc_hp(base_hp: float) -> float:
	var t = float(PC.real_time)
	var lv_bonus = pow(1.115, PC.pc_lv - 1) # 玩家每升1级，怪物血量提升11.5%
	var new_weapon_bonus = _get_new_weapon_hp_multiplier() # 新武器带来的血量加成
	
	var first_part = base_hp + t / 8.0
	var linear_part = 5.0 * t / 25000.0
	var quadratic_part = t * t / 300000.0
	var second_part = 1.0 + linear_part + quadratic_part
	
	var first_jump_time = 60.0
	var second_jump_time = 150.0
	var third_jump_time = 240.0
	var fourth_jump_time = 330.0
	
	var first_jump_multiplier = 1.5
	var second_jump_multiplier = 2.0
	var third_jump_multiplier = 2.6
	var fourth_jump_multiplier = 3.3
	
	var jump_multiplier = 1.0
	if t < first_jump_time:
		jump_multiplier = 1.0
	elif t < second_jump_time:
		jump_multiplier = first_jump_multiplier
	elif t < third_jump_time:
		jump_multiplier = second_jump_multiplier
	elif t < fourth_jump_time:
		jump_multiplier = third_jump_multiplier
	else:
		jump_multiplier = fourth_jump_multiplier
	
	return first_part * second_part * jump_multiplier * lv_bonus * new_weapon_bonus * _get_current_stage_multiplier() * 1.5


func _finalize_monster_data(data: Dictionary, query: String):
	# 所有怪物的 mechanism 统一翻倍。
	# 这里收口在一个函数里，后面如果你想再改成 ×1.5 或 ×3，
	# 只需要改这一处，不用逐个怪去找。
	if data.has("mechanism"):
		data["mechanism"] = int(data.get("mechanism", 0)) * 2
	return data.get(query, null)

# ============== 关卡1 桃林(PEACH_GROVE) ==============

func slime_blue(query: String): # 蓝色史莱姆 / 普通怪1
	var data = {
		"atk": _calc_atk(250),
		"hp": _calc_hp(30),
		"speed": 42,
		"exp": 350,
		"point": 10 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 6,
		"itemdrop": {"item_001": 0.015 * Global.get_effective_drop_multiplier(), "item_002": 0.015 * Global.get_effective_drop_multiplier(), "item_009": 0.006 * Global.get_effective_drop_multiplier(), "item_007": 0.005 * Global.get_effective_drop_multiplier(), "item_004": 0.005 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func taohua_yao(query: String): # 桃花妖 / 普通怪2
	var data = {
		"atk": _calc_atk(300),
		"hp": _calc_hp(33),
		"speed": 36,
		"exp": 450,
		"point": 15 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 7,
		"itemdrop": {"item_001": 0.015 * Global.get_effective_drop_multiplier(), "item_003": 0.03 * Global.get_effective_drop_multiplier(), "item_014": 0.012 * Global.get_effective_drop_multiplier(), "item_007": 0.005 * Global.get_effective_drop_multiplier(), "item_004": 0.005 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func frog(query: String): # 幼体树精 / 远程怪
	var data = {
		"atk": _calc_atk(225),
		"hp": _calc_hp(27),
		"speed": 35,
		"exp": 500,
		"point": 20 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 8,
		"itemdrop": {"item_001": 0.015 * Global.get_effective_drop_multiplier(), "item_023": 0.05 * Global.get_effective_drop_multiplier(), "item_010": 0.015 * Global.get_effective_drop_multiplier(), "item_007": 0.005 * Global.get_effective_drop_multiplier(), "item_004": 0.005 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

# ============== 关卡2 废墟(RUIN) ==============

func lantern(query: String): # 灯笼怪 / 普通怪2
	var data = {
		"atk": _calc_atk(400),
		"hp": _calc_hp(45),
		"speed": 38,
		"exp": 450,
		"point": 14 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 6,
		"itemdrop": {"item_001": 0.015 * Global.get_effective_drop_multiplier(), "item_011": 0.015 * Global.get_effective_drop_multiplier(), "item_015": 0.006 * Global.get_effective_drop_multiplier(), "item_007": 0.005 * Global.get_effective_drop_multiplier(), "item_004": 0.005 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func paper(query: String): # 宣纸精 / 普通怪1
	var data = {
		"atk": _calc_atk(480),
		"hp": _calc_hp(50),
		"speed": 42,
		"exp": 500,
		"point": 13 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 6,
		"itemdrop": {"item_001": 0.015 * Global.get_effective_drop_multiplier(), "item_011": 0.015 * Global.get_effective_drop_multiplier(), "item_017": 0.006 * Global.get_effective_drop_multiplier(), "item_007": 0.005 * Global.get_effective_drop_multiplier(), "item_004": 0.005 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func bat(query: String): # 草药怪 / 远程怪
	var data = {
		"atk": _calc_atk(320),
		"hp": _calc_hp(41),
		"speed": 36,
		"exp": 600,
		"point": 15 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 7,
		"itemdrop": {"item_001": 0.015 * Global.get_effective_drop_multiplier(), "item_045": 0.05 * Global.get_effective_drop_multiplier(), "item_010": 0.015 * Global.get_effective_drop_multiplier(), "item_007": 0.005 * Global.get_effective_drop_multiplier(), "item_004": 0.005 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func slime_grey(query: String): # 灰色史莱姆 / 特殊怪
	var data = {
		"atk": _calc_atk(420),
		"hp": _calc_hp(50),
		"speed": 36,
		"exp": 550,
		"point": 16 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 7,
		"itemdrop": {"item_001": 0.015 * Global.get_effective_drop_multiplier(), "item_002": 0.05 * Global.get_effective_drop_multiplier(), "item_009": 0.015 * Global.get_effective_drop_multiplier(), "item_007": 0.005 * Global.get_effective_drop_multiplier(), "item_004": 0.005 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

# ============== 关卡3 洞窟(CAVE) ==============

func ghost(query: String): # 鬼魂 / 远程怪
	var data = {
		"atk": _calc_atk(600),
		"hp": _calc_hp(72),
		"speed": 45,
		"exp": 500,
		"point": 18 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 7,
		"itemdrop": {"item_001": 0.015 * Global.get_effective_drop_multiplier(), "item_003": 0.02 * Global.get_effective_drop_multiplier(), "item_017": 0.0075 * Global.get_effective_drop_multiplier(), "item_007": 0.005 * Global.get_effective_drop_multiplier(), "item_004": 0.005 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func armor_stone(query: String): # 甲石 / 普通怪1
	var data = {
		"atk": _calc_atk(670),
		"hp": _calc_hp(90),
		"speed": 32,
		"exp": 400,
		"point": 19 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 7,
		"itemdrop": {"item_001": 0.015 * Global.get_effective_drop_multiplier(), "item_044": 0.02 * Global.get_effective_drop_multiplier(), "item_014": 0.0075 * Global.get_effective_drop_multiplier(), "item_007": 0.005 * Global.get_effective_drop_multiplier(), "item_004": 0.005 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func stone_man(query: String): # 石人 / 特殊怪
	var data = {
		"atk": _calc_atk(600),
		"hp": _calc_hp(113),
		"speed": 28,
		"exp": 550,
		"point": 22 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 8,
		"itemdrop": {"item_001": 0.015 * Global.get_effective_drop_multiplier(), "item_044": 0.05 * Global.get_effective_drop_multiplier(), "item_014": 0.015 * Global.get_effective_drop_multiplier(), "item_007": 0.005 * Global.get_effective_drop_multiplier(), "item_004": 0.005 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func slime_green(query: String): # 绿色史莱姆 / 普通怪2
	var data = {
		"atk": _calc_atk(600),
		"hp": _calc_hp(99),
		"speed": 42,
		"exp": 550,
		"point": 16 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 8,
		"itemdrop": {"item_001": 0.015 * Global.get_effective_drop_multiplier(), "item_002": 0.05 * Global.get_effective_drop_multiplier(), "item_009": 0.015 * Global.get_effective_drop_multiplier(), "item_007": 0.005 * Global.get_effective_drop_multiplier(), "item_004": 0.005 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

# ============== 关卡4 森林(FOREST) ==============

func shen(query: String): # 参精怪 / 普通怪1
	var data = {
		"atk": _calc_atk(900),
		"hp": _calc_hp(148),
		"speed": 42,
		"exp": 450,
		"point": 24 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 7,
		"itemdrop": {"item_001": 0.015 * Global.get_effective_drop_multiplier(), "item_045": 0.02 * Global.get_effective_drop_multiplier(), "item_015": 0.0075 * Global.get_effective_drop_multiplier(), "item_007": 0.005 * Global.get_effective_drop_multiplier(), "item_004": 0.005 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func frog_new(query: String): # 新蛙 / 远程怪
	var data = {
		"atk": _calc_atk(800),
		"hp": _calc_hp(118),
		"speed": 35,
		"exp": 600,
		"point": 22 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 7,
		"itemdrop": {"item_001": 0.015 * Global.get_effective_drop_multiplier(), "item_003": 0.02 * Global.get_effective_drop_multiplier(), "item_010": 0.0075 * Global.get_effective_drop_multiplier(), "item_007": 0.005 * Global.get_effective_drop_multiplier(), "item_004": 0.005 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func ball(query: String): # 弹跳兽 / 特殊怪
	var data = {
		"atk": _calc_atk(900),
		"hp": _calc_hp(185),
		"speed": 50,
		"exp": 500,
		"point": 26 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 8,
		"itemdrop": {"item_001": 0.015 * Global.get_effective_drop_multiplier(), "item_046": 0.05 * Global.get_effective_drop_multiplier(), "item_010": 0.015 * Global.get_effective_drop_multiplier(), "item_007": 0.005 * Global.get_effective_drop_multiplier(), "item_004": 0.005 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func peach_grove_boss(query: String):
	var data = {
		"itemdrop": {
			"item_097": {"chance": 0.5 * Global.get_effective_drop_multiplier(), "quantity": 1},
			"item_098": {"chance": 0.5 * Global.get_effective_drop_multiplier(), "quantity": 1},
			"item_009": {"chance": 0.2 * Global.get_effective_drop_multiplier(), "quantity": 2},
			"item_010": {"chance": 0.2 * Global.get_effective_drop_multiplier(), "quantity": 2},
			"item_015": {"chance": 0.2 * Global.get_effective_drop_multiplier(), "quantity": 2},
			"item_017": {"chance": 0.2 * Global.get_effective_drop_multiplier(), "quantity": 2},
			"item_014": {"chance": 0.2 * Global.get_effective_drop_multiplier(), "quantity": 2},
			"item_023": {"chance": 0.4 * Global.get_effective_drop_multiplier(), "quantity": 3},
			"item_003": {"chance": 0.4 * Global.get_effective_drop_multiplier(), "quantity": 3}
		}
	}
	return _finalize_monster_data(data, query)

func ruin_boss(query: String):
	var data = {
		"itemdrop": {
			"item_099": {"chance": 0.5 * Global.get_effective_drop_multiplier(), "quantity": 1},
			"item_100": {"chance": 0.5 * Global.get_effective_drop_multiplier(), "quantity": 1},
			"item_009": {"chance": 0.2 * Global.get_effective_drop_multiplier(), "quantity": 2},
			"item_010": {"chance": 0.2 * Global.get_effective_drop_multiplier(), "quantity": 2},
			"item_015": {"chance": 0.2 * Global.get_effective_drop_multiplier(), "quantity": 2},
			"item_017": {"chance": 0.2 * Global.get_effective_drop_multiplier(), "quantity": 2},
			"item_014": {"chance": 0.2 * Global.get_effective_drop_multiplier(), "quantity": 2},
			"item_044": {"chance": 0.4 * Global.get_effective_drop_multiplier(), "quantity": 3},
			"item_002": {"chance": 0.4 * Global.get_effective_drop_multiplier(), "quantity": 3}
		}
	}
	return _finalize_monster_data(data, query)

func cave_boss(query: String):
	var data = {
		"itemdrop": {
			"item_097": {"chance": 0.5 * Global.get_effective_drop_multiplier(), "quantity": 1},
			"item_101": {"chance": 0.5 * Global.get_effective_drop_multiplier(), "quantity": 1},
			"item_009": {"chance": 0.2 * Global.get_effective_drop_multiplier(), "quantity": 2},
			"item_010": {"chance": 0.2 * Global.get_effective_drop_multiplier(), "quantity": 2},
			"item_015": {"chance": 0.2 * Global.get_effective_drop_multiplier(), "quantity": 2},
			"item_017": {"chance": 0.2 * Global.get_effective_drop_multiplier(), "quantity": 2},
			"item_014": {"chance": 0.2 * Global.get_effective_drop_multiplier(), "quantity": 2},
			"item_011": {"chance": 0.4 * Global.get_effective_drop_multiplier(), "quantity": 3},
			"item_003": {"chance": 0.4 * Global.get_effective_drop_multiplier(), "quantity": 3}
		}
	}
	return _finalize_monster_data(data, query)
