extends Node

# 单例名称在 Project Settings -> Autoload 中应配置为 DpsManager

# 伤害记录的时间窗口（秒），计算这个窗口内的平均DPS
const WINDOW_SIZE: float = 30.0

# 整体伤害记录
var total_damage_records: Array = []
var current_total_dps: float = 0.0

# 每种武器的伤害记录字典：{ weapon_name: [{"damage": amount, "time": timestamp}, ...] }
var weapon_damage_records: Dictionary = {}
# 每种武器的当前DPS字典：{ weapon_name: current_dps }
var weapon_dps: Dictionary = {}

var dps_timer: Timer

func _ready() -> void:
	dps_timer = Timer.new()
	dps_timer.wait_time = 1.0 # 每秒计算一次
	dps_timer.timeout.connect(_calculate_dps)
	dps_timer.autostart = false
	add_child(dps_timer)

# 重置统计数据
func reset_dps_counter() -> void:
	total_damage_records.clear()
	weapon_damage_records.clear()
	current_total_dps = 0.0
	weapon_dps.clear()
	dps_timer.start()

func stop_dps_counter() -> void:
	dps_timer.stop()

# 记录整体与单武器伤害
# weapon_name 如果为空（"总体"、"未知"等），就只记录到整体中（或记录为"未知"武器）
func record_damage(damage: float, weapon_name: String = "") -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	var record = {"damage": damage, "time": current_time}
	
	# 记录总体伤害
	total_damage_records.append(record)
	
	# 记录各武器伤害
	if weapon_name != "":
		if not weapon_damage_records.has(weapon_name):
			weapon_damage_records[weapon_name] = []
		weapon_damage_records[weapon_name].append(record)

func _calculate_dps() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	var cutoff_time = current_time - WINDOW_SIZE
	
	# 1. 计算总DPS
	var sum_total = 0.0
	for i in range(total_damage_records.size() - 1, -1, -1):
		var record = total_damage_records[i]
		if record["time"] < cutoff_time:
			total_damage_records.remove_at(i)
		else:
			sum_total += record["damage"]
	current_total_dps = sum_total / WINDOW_SIZE
	
	# 2. 计算各武器DPS
	for w_name in weapon_damage_records.keys():
		var records = weapon_damage_records[w_name]
		var sum_weapon = 0.0
		for i in range(records.size() - 1, -1, -1):
			var record = records[i]
			if record["time"] < cutoff_time:
				records.remove_at(i)
			else:
				sum_weapon += record["damage"]
		weapon_dps[w_name] = sum_weapon / WINDOW_SIZE

func get_current_total_dps() -> float:
	return current_total_dps

func get_weapon_dps(weapon_name: String) -> float:
	if weapon_dps.has(weapon_name):
		return weapon_dps[weapon_name]
	return 0.0
	
func get_all_weapons_dps() -> Dictionary:
	return weapon_dps
