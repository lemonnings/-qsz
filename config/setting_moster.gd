extends Node
# 世界等级（难度级）对应血量，伤害为：
# lv1：*1 lv2：*1.75 lv3：*3 lv4：*5 lv5：*8 lv6：*12 lv7：*18 lv8：*26 lv9：*36 lv10：*50

func slime(query : String):
	var data = {
		"atk": 5 * Global.world_level_multiple * min(((1 + (PC.current_time/10))),3.5),
		"hp": 9 * Global.world_level_multiple * (1 + PC.current_time),
		"speed": 50,
		"exp": 400 * (1 + ((Global.world_level_reward_multiple - 1) / 10)) * min((1 + (PC.current_time) / 10), 12.5),
		"point": 150 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8)* (1 + (Global.point_add_level * 0.1)),
		"mechanism": 20 * min((1 + (PC.current_time) / 20), 4)
	}
	return data.get(query, null)


func bat(query : String):
	var data = {
		"atk": 7 * Global.world_level_multiple * min(((1 + (PC.current_time/10))), 3.5),
		"hp": 18 * Global.world_level_multiple * (1 + PC.current_time),
		"speed": 80,
		"exp": 600 * (1 + ((Global.world_level_reward_multiple - 1) / 10)) * min((1 + (PC.current_time) / 10), 12.5),
		"point": 300 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.point_add_level * 0.1)),
		"mechanism": 28 * min((1 + (PC.current_time) / 20), 4)
	}
	return data.get(query, null)


func frog(query : String):
	var data = {
		"atk": 5 * Global.world_level_multiple * min(((1 + (PC.current_time/10))), 3.5),
		"hp": 24 * Global.world_level_multiple * (1 + PC.current_time),
		"speed": 65,
		"exp": 700 * (1 + ((Global.world_level_reward_multiple - 1) / 10)) * min((1 + (PC.current_time) / 10), 12.5),
		"point": 350 * Global.world_level_reward_multiple * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.point_add_level * 0.1)),
		"mechanism": 36 * min((1 + (PC.current_time) / 20), 4)
	}
	return data.get(query, null)
