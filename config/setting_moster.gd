extends Node

func _calc_atk(base_atk: float) -> float:
	var t = PC.real_time
	return (6.67 * base_atk + t) / 7.5 * Global.world_level_multiple

func _calc_hp(base_hp: float) -> float:
	var t = PC.real_time
	return 1.6 * (base_hp + t / 3.0) * (1.0 + 26.0 * t / 4000.0 + t * t / 22000.0) * Global.world_level_multiple

# 关卡1 桃林
func taohua_yao(query: String): # 桃花妖
	var data = {
		"atk": _calc_atk(25),
		"hp": _calc_hp(600),
		"speed": 36,
		"exp": 500 * (1 + ((Global.world_level_reward_multiple - 1) / 10)) * min((1 + (PC.current_time) / 10), 12.5),
		"point": 15 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.05)),
		"mechanism": 10 * min((1 + (PC.current_time) / 20), 4),
		"itemdrop": {"item_001": 0.02 * (1 + (PC.drop_multi)), "item_010": 0.075 * (1 + (PC.drop_multi)), "item_024": 0.008 * (1 + (PC.drop_multi)), "item_032": 0.005 * (1 + (PC.drop_multi))}
	}
	return data.get(query, null)

func slime(query: String):
	var data = {
		"atk": _calc_atk(15),
		"hp": _calc_hp(40),
		"speed": 42,
		"exp": 300 * (1 + ((Global.world_level_reward_multiple - 1) / 10)) * min((1 + (PC.current_time) / 10), 12.5),
		"point": 10 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.05)),
		"mechanism": 5 * min((1 + (PC.current_time) / 20), 4),
		"itemdrop": {"item_001": 0.02 * (1 + (PC.drop_multi)), "item_002": 0.075 * (1 + (PC.drop_multi)), "item_003": 0.008 * (1 + (PC.drop_multi)), "item_034": 0.005 * (1 + (PC.drop_multi))}
	}
	return data.get(query, null)

func frog(query: String): # 幼体树精
	var data = {
		"atk": _calc_atk(15),
		"hp": _calc_hp(50),
		"speed": 35,
		"exp": 500 * (1 + ((Global.world_level_reward_multiple - 1) / 10)) * min((1 + (PC.current_time) / 10), 12.5),
		"point": 20 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.05)),
		"mechanism": 12 * min((1 + (PC.current_time) / 20), 4),
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
