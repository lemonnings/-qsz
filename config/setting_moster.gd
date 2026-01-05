extends Node

func slime(query : String):
	var data = {
		"atk": 5 * Global.world_level_multiple * min(((1 + (PC.current_time/10))),3.5),
		"hp": (18 * Global.world_level_multiple * (1 + PC.current_time)) + Global.current_dps * 0.04,
		"speed": 42,
		"exp": 300 * (1 + ((Global.world_level_reward_multiple - 1) / 10)) * min((1 + (PC.current_time) / 10), 12.5),
		"point": 10 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8)* (1 + (Global.cultivation_hualing_level * 0.05)),
		"mechanism": 5 * min((1 + (PC.current_time) / 20), 4),
		"itemdrop" : {"item_001": 0.02 * (1 + (PC.drop_multi)), "item_002": 0.075 * (1 + (PC.drop_multi)), "item_003": 0.008 * (1 + (PC.drop_multi)), "item_034": 0.005 * (1 + (PC.drop_multi))}
	}
	return data.get(query, null)


func bat(query : String): # 草药怪
	var data = {
		"atk": 7 * Global.world_level_multiple * min(((1 + (PC.current_time/10))), 3.5),
		"hp": (44 * Global.world_level_multiple * (1 + PC.current_time)) + Global.current_dps * 0.05,
		"speed": 36,
		"exp": 450 * (1 + ((Global.world_level_reward_multiple - 1) / 10)) * min((1 + (PC.current_time) / 10), 12.5),
		"point": 15 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.05)),
		"mechanism": 10 * min((1 + (PC.current_time) / 20), 4),
		"itemdrop" : {"item_001": 0.02 * (1 + (PC.drop_multi)), "item_010": 0.075 * (1 + (PC.drop_multi)), "item_024": 0.008 * (1 + (PC.drop_multi)), "item_032": 0.005 * (1 + (PC.drop_multi))}
	}
	return data.get(query, null)


func frog(query : String): # 幼体树精
	var data = {
		"atk": 5 * Global.world_level_multiple * min(((1 + (PC.current_time/10))), 3.5),
		"hp": (28 * Global.world_level_multiple * (1 + PC.current_time)) + Global.current_dps * 0.045,
		"speed": 35,
		"exp": 450 * (1 + ((Global.world_level_reward_multiple - 1) / 10)) * min((1 + (PC.current_time) / 10), 12.5),
		"point": 20 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.05)),
		"mechanism": 12 * min((1 + (PC.current_time) / 20), 4),
		"itemdrop" : {"item_001": 0.02 * (1 + (PC.drop_multi)), "item_023": 0.075 * (1 + (PC.drop_multi)), "item_009": 0.008 * (1 + (PC.drop_multi)), "item_031": 0.005 * (1 + (PC.drop_multi))}
	}
	return data.get(query, null)

func bigSlime(query : String):
	var data = {
		"atk": 7 * Global.world_level_multiple * min(((1 + (PC.current_time/10))),3.5),
		"hp": (64 * Global.world_level_multiple * (1 + PC.current_time)) + Global.current_dps * 0.09,
		"speed": 40,
		"exp": 750 * (1 + ((Global.world_level_reward_multiple - 1) / 10)) * min((1 + (PC.current_time) / 10), 12.5),
		"point": 25 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8)* (1 + (Global.cultivation_hualing_level * 0.05)),
		"mechanism": 25 * min((1 + (PC.current_time) / 20), 4),
		"itemdrop" : {"item_001": 0.02 * (1 + (PC.drop_multi)), "item_002": 0.075 * (1 + (PC.drop_multi)), "item_003": 0.008 * (1 + (PC.drop_multi)), "item_034": 0.005 * (1 + (PC.drop_multi))}
	}
	return data.get(query, null)
