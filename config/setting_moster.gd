extends Node

func slime(query : String):
	var data = {
		"atk": 5 * Global.world_level_multiple * min(((1 + (PC.current_time/10))),3.5),
		"hp": (18 * Global.world_level_multiple * (1 + PC.current_time)) + Global.current_dps * 0.04,
		"speed": 42,
		"exp": 300 * (1 + ((Global.world_level_reward_multiple - 1) / 10)) * min((1 + (PC.current_time) / 10), 12.5),
		"point": 10 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8)* (1 + (Global.cultivation_hualing_level * 0.05)),
		"mechanism": 5 * min((1 + (PC.current_time) / 20), 4),
		"itemdrop" : {"item_001": 0.02 * (1 + (Global.lunky_level * 0.025)), "item_004": 0.001 * (1 + (Global.lunky_level * 0.025))}
	}
	return data.get(query, null)


func bat(query : String):
	var data = {
		"atk": 7 * Global.world_level_multiple * min(((1 + (PC.current_time/10))), 3.5),
		"hp": (36 * Global.world_level_multiple * (1 + PC.current_time)) + Global.current_dps * 0.05,
		"speed": 60,
		"exp": 400 * (1 + ((Global.world_level_reward_multiple - 1) / 10)) * min((1 + (PC.current_time) / 10), 12.5),
		"point": 15 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.05)),
		"mechanism": 10 * min((1 + (PC.current_time) / 20), 4),
		"itemdrop" : {"item_001": 0.025 * (1 + (Global.lunky_level * 0.025)), "item_004": 0.001 * (1 + (Global.lunky_level * 0.025))}
	}
	return data.get(query, null)


func frog(query : String):
	var data = {
		"atk": 5 * Global.world_level_multiple * min(((1 + (PC.current_time/10))), 3.5),
		"hp": (30 * Global.world_level_multiple * (1 + PC.current_time)) + Global.current_dps * 0.045,
		"speed": 50,
		"exp": 600 * (1 + ((Global.world_level_reward_multiple - 1) / 10)) * min((1 + (PC.current_time) / 10), 12.5),
		"point": 20 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.05)),
		"mechanism": 12 * min((1 + (PC.current_time) / 20), 4),
		"itemdrop" : {"item_001": 0.03 * (1 + (Global.lunky_level * 0.025)), "item_004": 0.001 * (1 + (Global.lunky_level * 0.025))}
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
		"itemdrop" : {"item_001": 0.04 * (1 + (Global.lunky_level * 0.025)), "item_004": 0.002 * (1 + (Global.lunky_level * 0.025))}
	}
	return data.get(query, null)
