extends Node

func slime(query : String):
	var data = {
		"atk": 5 * Global.world_level_multiple * min(((1 + (PC.current_time/10))),3.5),
		"hp": 18 * Global.world_level_multiple * (1 + PC.current_time),
		"speed": 50,
		"exp": 1000 * (1 + ((Global.world_level_reward_multiple - 1) / 10)) * min((1 + (PC.current_time) / 10), 12.5),
		"point": 150 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8)* (1 + (Global.point_add_level * 0.1)),
		"mechanism": 5 * min((1 + (PC.current_time) / 20), 4),
		"itemdrop" : {"item_001": 0.02 * (1 + (PC.lucky * 0.025)), "item_004": 0.001 * (1 + (PC.lucky * 0.025))}
	}
	return data.get(query, null)


func bat(query : String):
	var data = {
		"atk": 7 * Global.world_level_multiple * min(((1 + (PC.current_time/10))), 3.5),
		"hp": 36 * Global.world_level_multiple * (1 + PC.current_time),
		"speed": 70,
		"exp": 150 * (1 + ((Global.world_level_reward_multiple - 1) / 10)) * min((1 + (PC.current_time) / 10), 12.5),
		"point": 300 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.point_add_level * 0.1)),
		"mechanism": 10 * min((1 + (PC.current_time) / 20), 4),
		"itemdrop" : {"item_001": 0.025 * (1 + (PC.lucky * 0.025)), "item_004": 0.001 * (1 + (PC.lucky * 0.025))}
	}
	return data.get(query, null)


func frog(query : String):
	var data = {
		"atk": 5 * Global.world_level_multiple * min(((1 + (PC.current_time/10))), 3.5),
		"hp": 32 * Global.world_level_multiple * (1 + PC.current_time),
		"speed": 60,
		"exp": 200 * (1 + ((Global.world_level_reward_multiple - 1) / 10)) * min((1 + (PC.current_time) / 10), 12.5),
		"point": 350 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.point_add_level * 0.1)),
		"mechanism": 12 * min((1 + (PC.current_time) / 20), 4),
		"itemdrop" : {"item_001": 0.03 * (1 + (PC.lucky * 0.025)), "item_004": 0.001 * (1 + (PC.lucky * 0.025))}
	}
	return data.get(query, null)

func bigSlime(query : String):
	var data = {
		"atk": 7 * Global.world_level_multiple * min(((1 + (PC.current_time/10))),3.5),
		"hp": 64 * Global.world_level_multiple * (1 + PC.current_time),
		"speed": 40,
		"exp": 300 * (1 + ((Global.world_level_reward_multiple - 1) / 10)) * min((1 + (PC.current_time) / 10), 12.5),
		"point": 450 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8)* (1 + (Global.point_add_level * 0.1)),
		"mechanism": 25 * min((1 + (PC.current_time) / 20), 4),
		"itemdrop" : {"item_001": 0.04 * (1 + (PC.lucky * 0.025)), "item_004": 0.002 * (1 + (PC.lucky * 0.025))}
	}
	return data.get(query, null)
