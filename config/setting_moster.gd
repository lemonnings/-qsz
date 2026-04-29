extends Node


func _get_current_stage_multiplier() -> float:
	# 当前没有进入正式关卡时，倍率默认回到 1.0。
	# 这样在主城、菜单或直接打开脚本时，不会因为缺少上下文导致数值异常。
	if typeof(Global) == TYPE_NIL:
		return 1.0
	return max(Global.get_current_stage_stat_multiplier(), 1.0)

# 浅层100%、深层50%、核心/诗想225%
func _get_difficulty_point_multiplier() -> float:
	if typeof(Global) == TYPE_NIL:
		return 1.0
	match Global.validate_stage_difficulty_id(Global.current_stage_difficulty):
		Global.STAGE_DIFFICULTY_DEEP:
			return 0.5
		Global.STAGE_DIFFICULTY_CORE, Global.STAGE_DIFFICULTY_POETRY:
			return 2.25
		_:
			return 1.0

func _calc_stage_scaled_value(base_value: float) -> float:
	# 怪物基础值现在只吃“当前关卡难度倍率”。
	# 这样配置更直观，你看到多少基础值，就能直接推算出进图后的结果。
	return base_value * _get_current_stage_multiplier()

func _calc_atk(base_atk: float) -> float:
	var t = PC.real_time
	return base_atk + (0.75 * t) * pow(1.015, PC.pc_lv - 1) * _get_current_stage_multiplier()

# 计算新武器带来的怪物血量加成
func _get_new_weapon_hp_multiplier() -> float:
	var count = PC.new_weapon_obtained_count
	var multiplier = 1.0
	if count >= 1:
		multiplier *= 1.85
	if count >= 2:
		multiplier *= 1.65
	if count >= 3:
		multiplier *= 1.3
	if count >= 4:
		multiplier *= 1.15
	if count >= 5:
		multiplier *= 1.1
	return multiplier

func _calc_hp(base_hp: float) -> float:
	var t = float(PC.real_time)
	var lv_bonus = pow(1.1, PC.pc_lv - 1) # 玩家每升1级，怪物血量提升10%
	var new_weapon_bonus = _get_new_weapon_hp_multiplier() # 新武器带来的血量加成
	
	var first_part = base_hp + t / 8.0
	var linear_part = 5.0 * t / 45000.0
	var quadratic_part = t * t / 500000.0
	var second_part = 1.0 + linear_part + quadratic_part
	
	var first_jump_time = 90.0
	var second_jump_time = 180.0
	var third_jump_time = 270.0
	var fourth_jump_time = 360.0
	var fifth_jump_time = 450.0
	var sixth_jump_time = 540.0
	
	var first_jump_multiplier = 1.35
	var second_jump_multiplier = 1.8
	var third_jump_multiplier = 2.4
	var fourth_jump_multiplier = 3.2
	var fifth_jump_multiplier = 4
	var sixth_jump_multiplier = 5
	
	var jump_multiplier = 1.0
	if t < first_jump_time:
		jump_multiplier = 1.0
	elif t < second_jump_time:
		jump_multiplier = first_jump_multiplier
	elif t < third_jump_time:
		jump_multiplier = second_jump_multiplier
	elif t < fourth_jump_time:
		jump_multiplier = third_jump_multiplier
	elif t < fifth_jump_time:
		jump_multiplier = fourth_jump_multiplier
	elif t < sixth_jump_time:
		jump_multiplier = fifth_jump_multiplier
	else:
		jump_multiplier = sixth_jump_multiplier
	
	return first_part * second_part * jump_multiplier * lv_bonus * new_weapon_bonus * _get_current_stage_multiplier()


func _finalize_monster_data(data: Dictionary, query: String):
	# 所有怪物的 mechanism 统一翻倍
	if data.has("mechanism"):
		data["mechanism"] = int(data.get("mechanism", 0)) * 1
	return data.get(query, null)

# ============== 关卡1 桃林(PEACH_GROVE) ==============

func slime_blue(query: String): # 蓝色史莱姆 / 普通怪1
	var data = {
		"atk": _calc_atk(200),
		"hp": _calc_hp(30),
		"speed": 42,
		"exp": 350,
		"point": 10 * _get_difficulty_point_multiplier() * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 10,
		"itemdrop": {"item_001": 0.012 * Global.get_effective_drop_multiplier(), "item_002": 0.015 * Global.get_effective_drop_multiplier(), "item_009": 0.006 * Global.get_effective_drop_multiplier(), "item_007": 0.012 * Global.get_effective_drop_multiplier(), "item_004": 0.002 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func taohua_yao(query: String): # 桃花妖 / 普通怪2
	var data = {
		"atk": _calc_atk(220),
		"hp": _calc_hp(33),
		"speed": 36,
		"exp": 450,
		"point": 15 * _get_difficulty_point_multiplier() * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 12,
		"itemdrop": {"item_001": 0.012 * Global.get_effective_drop_multiplier(), "item_003": 0.03 * Global.get_effective_drop_multiplier(), "item_014": 0.012 * Global.get_effective_drop_multiplier(), "item_007": 0.012 * Global.get_effective_drop_multiplier(), "item_004": 0.002 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func frog(query: String): # 幼体树精 / 远程怪
	var data = {
		"atk": _calc_atk(180),
		"hp": _calc_hp(27),
		"speed": 35,
		"exp": 500,
		"point": 20 * _get_difficulty_point_multiplier() * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 14,
		"itemdrop": {"item_001": 0.012 * Global.get_effective_drop_multiplier(), "item_023": 0.05 * Global.get_effective_drop_multiplier(), "item_010": 0.015 * Global.get_effective_drop_multiplier(), "item_007": 0.012 * Global.get_effective_drop_multiplier(), "item_004": 0.002 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

# ============== 关卡2 废墟(RUIN) ==============

func lantern(query: String): # 灯笼怪 / 普通怪2
	var data = {
		"atk": _calc_atk(350),
		"hp": _calc_hp(45),
		"speed": 38,
		"exp": 450,
		"point": 14 * _get_difficulty_point_multiplier() * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 12,
		"itemdrop": {"item_001": 0.012 * Global.get_effective_drop_multiplier(), "item_011": 0.015 * Global.get_effective_drop_multiplier(), "item_015": 0.006 * Global.get_effective_drop_multiplier(), "item_007": 0.012 * Global.get_effective_drop_multiplier(), "item_004": 0.002 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func paper(query: String): # 宣纸精 / 普通怪1
	var data = {
		"atk": _calc_atk(360),
		"hp": _calc_hp(50),
		"speed": 42,
		"exp": 500,
		"point": 13 * _get_difficulty_point_multiplier() * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 14,
		"itemdrop": {"item_001": 0.012 * Global.get_effective_drop_multiplier(), "item_011": 0.015 * Global.get_effective_drop_multiplier(), "item_017": 0.006 * Global.get_effective_drop_multiplier(), "item_007": 0.012 * Global.get_effective_drop_multiplier(), "item_004": 0.002 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func bat(query: String): # 草药怪 / 远程怪
	var data = {
		"atk": _calc_atk(320),
		"hp": _calc_hp(41),
		"speed": 36,
		"exp": 600,
		"point": 15 * _get_difficulty_point_multiplier() * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 16,
		"itemdrop": {"item_001": 0.012 * Global.get_effective_drop_multiplier(), "item_045": 0.05 * Global.get_effective_drop_multiplier(), "item_010": 0.015 * Global.get_effective_drop_multiplier(), "item_007": 0.012 * Global.get_effective_drop_multiplier(), "item_004": 0.002 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func slime_grey(query: String): # 灰色史莱姆 / 特殊怪
	var data = {
		"atk": _calc_atk(360),
		"hp": _calc_hp(50),
		"speed": 36,
		"exp": 550,
		"point": 16 * _get_difficulty_point_multiplier() * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 16,
		"itemdrop": {"item_001": 0.012 * Global.get_effective_drop_multiplier(), "item_002": 0.05 * Global.get_effective_drop_multiplier(), "item_009": 0.015 * Global.get_effective_drop_multiplier(), "item_007": 0.012 * Global.get_effective_drop_multiplier(), "item_004": 0.002 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

# ============== 关卡3 洞窟(CAVE) ==============

func ghost(query: String): # 鬼魂 / 远程怪
	var data = {
		"atk": _calc_atk(500),
		"hp": _calc_hp(80),
		"speed": 45,
		"exp": 500,
		"point": 18 * _get_difficulty_point_multiplier() * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 12,
		"itemdrop": {"item_001": 0.012 * Global.get_effective_drop_multiplier(), "item_003": 0.02 * Global.get_effective_drop_multiplier(), "item_017": 0.0075 * Global.get_effective_drop_multiplier(), "item_007": 0.012 * Global.get_effective_drop_multiplier(), "item_004": 0.002 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func armor_stone(query: String): # 甲石 / 普通怪1
	var data = {
		"atk": _calc_atk(550),
		"hp": _calc_hp(88),
		"speed": 32,
		"exp": 400,
		"point": 19 * _get_difficulty_point_multiplier() * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 14,
		"itemdrop": {"item_001": 0.012 * Global.get_effective_drop_multiplier(), "item_044": 0.02 * Global.get_effective_drop_multiplier(), "item_014": 0.0075 * Global.get_effective_drop_multiplier(), "item_007": 0.012 * Global.get_effective_drop_multiplier(), "item_004": 0.002 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func stone_man(query: String): # 石人 / 特殊怪
	var data = {
		"atk": _calc_atk(550),
		"hp": _calc_hp(80),
		"speed": 28,
		"exp": 550,
		"point": 22 * _get_difficulty_point_multiplier() * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 16,
		"itemdrop": {"item_001": 0.012 * Global.get_effective_drop_multiplier(), "item_044": 0.05 * Global.get_effective_drop_multiplier(), "item_014": 0.015 * Global.get_effective_drop_multiplier(), "item_007": 0.012 * Global.get_effective_drop_multiplier(), "item_004": 0.002 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func slime_green(query: String): # 绿色史莱姆 / 普通怪2
	var data = {
		"atk": _calc_atk(500),
		"hp": _calc_hp(72),
		"speed": 42,
		"exp": 550,
		"point": 16 * _get_difficulty_point_multiplier() * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 16,
		"itemdrop": {"item_001": 0.012 * Global.get_effective_drop_multiplier(), "item_002": 0.05 * Global.get_effective_drop_multiplier(), "item_009": 0.015 * Global.get_effective_drop_multiplier(), "item_007": 0.012 * Global.get_effective_drop_multiplier(), "item_004": 0.002 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

# ============== 关卡4 森林(FOREST) ==============

func shen(query: String): # 参精怪 / 普通怪1
	var data = {
		"atk": _calc_atk(800),
		"hp": _calc_hp(140),
		"speed": 42,
		"exp": 450,
		"point": 24 * _get_difficulty_point_multiplier() * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 12,
		"itemdrop": {"item_001": 0.012 * Global.get_effective_drop_multiplier(), "item_045": 0.02 * Global.get_effective_drop_multiplier(), "item_015": 0.0075 * Global.get_effective_drop_multiplier(), "item_007": 0.012 * Global.get_effective_drop_multiplier(), "item_004": 0.002 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func frog_new(query: String): # 新蛙 / 远程怪
	var data = {
		"atk": _calc_atk(700),
		"hp": _calc_hp(130),
		"speed": 35,
		"exp": 600,
		"point": 22 * _get_difficulty_point_multiplier() * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 14,
		"itemdrop": {"item_001": 0.012 * Global.get_effective_drop_multiplier(), "item_003": 0.02 * Global.get_effective_drop_multiplier(), "item_010": 0.0075 * Global.get_effective_drop_multiplier(), "item_007": 0.012 * Global.get_effective_drop_multiplier(), "item_004": 0.002 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func ball(query: String): # 弹跳兽 / 特殊怪
	var data = {
		"atk": _calc_atk(800),
		"hp": _calc_hp(140),
		"speed": 50,
		"exp": 500,
		"point": 26 * _get_difficulty_point_multiplier() * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03)),
		"mechanism": 16,
		"itemdrop": {"item_001": 0.012 * Global.get_effective_drop_multiplier(), "item_046": 0.05 * Global.get_effective_drop_multiplier(), "item_010": 0.015 * Global.get_effective_drop_multiplier(), "item_007": 0.012 * Global.get_effective_drop_multiplier(), "item_004": 0.002 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)


# ============== Boss通用魔核+凝灵碎片掉落 ==============
# 返回包含5种魔核概率掉落和凝灵碎片固定掉落的itemdrop字典
# 调用方需在此之外额外执行"固定1个随机魔核"的强制掉落
func get_boss_extra_drop() -> Dictionary:
	var difficulty = Global.current_stage_difficulty
	var wlv = max(1, Global.world_level) # 世界等级，从1开始
	var extra_round = max(0, wlv - 1) # 从第二关开始的额外加成轮次

	# 五种魔核ID
	var magic_core_ids = ["item_097", "item_098", "item_099", "item_100", "item_101"]

	# 计算每种魔核的额外掉落概率（扣除固定1个后，剩余期望平分给5种）
	# 浅层期望: 2 + 0.3*extra_round，深层: 2.75 + 0.45*extra_round，核心: 3.5 + 0.6*extra_round
	var total_expected: float
	match difficulty:
		Global.STAGE_DIFFICULTY_DEEP:
			total_expected = 1.75 + 0.35 * extra_round
		Global.STAGE_DIFFICULTY_CORE, Global.STAGE_DIFFICULTY_POETRY:
			total_expected = 3 + 0.45 * extra_round
		_: # shallow
			total_expected = 1 + 0.25 * extra_round

	# 固定掉落1个，剩余期望由5种魔核概率掉落覆盖
	var extra_expected = max(0.0, total_expected - 1.0)
	var each_chance = clampf(extra_expected / 5.0, 0.0, 1.0) * Global.get_effective_drop_multiplier()
	
	# 桃林浅层：新手教学关，魔核概率降为50%
	var is_peach_shallow = (difficulty == Global.STAGE_DIFFICULTY_SHALLOW and Global.current_stage_id == "peach_grove")
	if is_peach_shallow:
		each_chance *= 0.5

	# 凝灵碎片固定数量
	var lingjing_count: int
	if is_peach_shallow:
		lingjing_count = 1
	else:
		match difficulty:
			Global.STAGE_DIFFICULTY_DEEP:
				lingjing_count = 3
			Global.STAGE_DIFFICULTY_CORE, Global.STAGE_DIFFICULTY_POETRY:
				lingjing_count = 4
			_:
				lingjing_count = 2

	var drop_table: Dictionary = {}
	for core_id in magic_core_ids:
		drop_table[core_id] = {"chance": each_chance, "quantity": 1}
	# 凝灵碎片固定掉落（chance=2.0保证必定触发）
	drop_table["item_102"] = {"chance": 2.0, "quantity": lingjing_count}
	return drop_table
