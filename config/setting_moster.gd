extends Node

func _calc_atk(base_atk: float) -> float:
	var t = PC.real_time
	return (6.67 * base_atk + t) / 7.5 * (1 + ((Global.world_level_multiple - 1) / 3))

func _calc_hp(base_hp: float) -> float:
	var t = PC.real_time
	var lv_bonus = pow(1.11, PC.pc_lv - 1) # 玩家每升1级，怪物血量提升6%
	return 1.45 * (base_hp + t / 3.0) * (1.0 + 15.0 * t / 3500.0 + t * t / 26000.0) * Global.world_level_multiple * lv_bonus

# 关卡1 桃林
func taohua_yao(query: String): # 桃花妖
	var data = {
		"atk": _calc_atk(25),
		"hp": _calc_hp(32),
		"speed": 36,
		"exp": 500 * (1 + ((Global.world_level_reward_multiple - 1) / 10)) * min((1 + (PC.current_time) / 10), 12.5),
		"point": 15 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.05)),
		"mechanism": 7,
		"itemdrop": {"item_001": 0.02 * (1 + (PC.drop_multi)), "item_010": 0.075 * (1 + (PC.drop_multi)), "item_024": 0.008 * (1 + (PC.drop_multi)), "item_032": 0.005 * (1 + (PC.drop_multi))}
	}
	return data.get(query, null)

func slime(query: String):
	var data = {
		"atk": _calc_atk(15),
		"hp": _calc_hp(24),
		"speed": 42,
		"exp": 350 * (1 + ((Global.world_level_reward_multiple - 1) / 10)) * min((1 + (PC.current_time) / 10), 12.5),
		"point": 10 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.05)),
		"mechanism": 6,
		"itemdrop": {"item_001": 0.02 * (1 + (PC.drop_multi)), "item_002": 0.075 * (1 + (PC.drop_multi)), "item_003": 0.008 * (1 + (PC.drop_multi)), "item_034": 0.005 * (1 + (PC.drop_multi))}
	}
	return data.get(query, null)

func frog(query: String): # 幼体树精
	var data = {
		"atk": _calc_atk(12),
		"hp": _calc_hp(22),
		"speed": 35,
		"exp": 600 * (1 + ((Global.world_level_reward_multiple - 1) / 10)) * min((1 + (PC.current_time) / 10), 12.5),
		"point": 20 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.05)),
		"mechanism": 8,
		"itemdrop": {"item_001": 0.02 * (1 + (PC.drop_multi)), "item_023": 0.075 * (1 + (PC.drop_multi)), "item_009": 0.008 * (1 + (PC.drop_multi)), "item_031": 0.005 * (1 + (PC.drop_multi))}
	}
	return data.get(query, null)
	
# 关卡2 古迹
func slime_blue(query: String):
	var data = {
		"atk": _calc_atk(23),
		"hp": _calc_hp(80),
		"speed": 42,
		"exp": 300 * (1 + ((Global.world_level_reward_multiple - 1) / 10)) * min((1 + (PC.current_time) / 10), 12.5),
		"point": 10 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.05)),
		"mechanism": 5 * min((1 + (PC.current_time) / 20), 4),
		"itemdrop": {"item_001": 0.02 * (1 + (PC.drop_multi)), "item_002": 0.075 * (1 + (PC.drop_multi)), "item_003": 0.008 * (1 + (PC.drop_multi)), "item_034": 0.005 * (1 + (PC.drop_multi))}
	}
	return data.get(query, null)

func bat(query: String): # 草药怪
	var data = {
		"atk": _calc_atk(38),
		"hp": _calc_hp(110),
		"speed": 36,
		"exp": 500 * (1 + ((Global.world_level_reward_multiple - 1) / 10)) * min((1 + (PC.current_time) / 10), 12.5),
		"point": 15 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.05)),
		"mechanism": 10 * min((1 + (PC.current_time) / 20), 4),
		"itemdrop": {"item_001": 0.02 * (1 + (PC.drop_multi)), "item_010": 0.075 * (1 + (PC.drop_multi)), "item_024": 0.008 * (1 + (PC.drop_multi)), "item_032": 0.005 * (1 + (PC.drop_multi))}
	}
	return data.get(query, null)


func bigSlime(query: String):
	var data = {
		"atk": _calc_atk(7),
		"hp": _calc_hp(64),
		"speed": 40,
		"exp": 750 * (1 + ((Global.world_level_reward_multiple - 1) / 10)) * min((1 + (PC.current_time) / 10), 12.5),
		"point": 25 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.05)),
		"mechanism": 25 * min((1 + (PC.current_time) / 20), 4),
		"itemdrop": {"item_001": 0.02 * (1 + (PC.drop_multi)), "item_002": 0.075 * (1 + (PC.drop_multi)), "item_003": 0.008 * (1 + (PC.drop_multi)), "item_034": 0.005 * (1 + (PC.drop_multi))}
	}
	return data.get(query, null)
