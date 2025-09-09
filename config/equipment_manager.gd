extends Node

# 装备系统管理器
# 管理角色身上的装备，包括核心法宝和随身法宝

# 装备槽位类型
enum EquipSlotType {
	CORE_TREASURE,    # 核心法宝
	CARRY_TREASURE_1, # 随身法宝1
	CARRY_TREASURE_2, # 随身法宝2
	CARRY_TREASURE_3, # 随身法宝3
	CARRY_TREASURE_4, # 随身法宝4
	CARRY_TREASURE_5  # 随身法宝5
}

# 当前装备的物品ID
@export var equipped_items: Dictionary = {
	EquipSlotType.CORE_TREASURE: "",
	EquipSlotType.CARRY_TREASURE_1: "",
	EquipSlotType.CARRY_TREASURE_2: "",
	EquipSlotType.CARRY_TREASURE_3: "",
	EquipSlotType.CARRY_TREASURE_4: "",
	EquipSlotType.CARRY_TREASURE_5: ""
}

# 装备物品到指定槽位
func equip_item(item_id: String, slot_type: EquipSlotType) -> bool:
	# 检查物品是否存在且为装备类型
	var item_manager = get_node("/root/ItemManager")
	if not item_manager or not item_manager.items_data.has(item_id):
		push_error("装备物品不存在: " + item_id)
		return false
	
	var item_data = item_manager.items_data[item_id]
	if item_data["item_type"] != "equip":
		push_error("物品不是装备类型: " + item_id)
		return false
	
	# 检查槽位是否解锁
	if not is_slot_unlocked(slot_type):
		push_error("装备槽位未解锁: " + str(slot_type))
		return false
	
	# 卸下当前装备
	var old_item_id = equipped_items[slot_type]
	if old_item_id != "":
		unequip_item(slot_type)
	
	# 装备新物品
	equipped_items[slot_type] = item_id
	print("装备成功: " + item_id + " 到槽位 " + str(slot_type))
	return true

# 卸下指定槽位的装备
func unequip_item(slot_type: EquipSlotType) -> String:
	var item_id = equipped_items[slot_type]
	if item_id != "":
		equipped_items[slot_type] = ""
		print("卸下装备: " + item_id + " 从槽位 " + str(slot_type))
	return item_id

# 检查槽位是否解锁
func is_slot_unlocked(slot_type: EquipSlotType) -> bool:
	if slot_type == EquipSlotType.CORE_TREASURE:
		return true # 核心法宝始终解锁
	
	# 随身法宝根据解锁数量判断
	var unlocked_carry_slots = Global.max_carry_equipment_slots
	var carry_slot_index = slot_type - EquipSlotType.CARRY_TREASURE_1
	return carry_slot_index < unlocked_carry_slots

# 获取所有已装备的物品ID列表
func get_equipped_items() -> Array:
	var equipped_list = []
	for slot_type in equipped_items.keys():
		var item_id = equipped_items[slot_type]
		if item_id != "":
			equipped_list.append(item_id)
	return equipped_list

# 计算所有装备提供的属性加成
func calculate_total_equipment_stats() -> Dictionary:
	var total_stats = {
		"pc_atk": 0,
		"pc_atk_speed": 0.0,
		"crit_chance": 0.0,
		"crit_damage_multi": 0.0,
		"pc_final_atk": 0.0,
		"point_multi": 0.0,
		"exp_multi": 0.0,
		"drop_multi": 0.0,
		"bullet_size": 0.0,
		"damage_reduction_rate": 0.0,
		"pc_hp": 0,
		"pc_speed": 0.0,
		"tianming": 0.0
	}
	
	# 遍历所有已装备的物品
	for slot_type in equipped_items.keys():
		var item_id = equipped_items[slot_type]
		if item_id == "":
			continue
		
		var item_manager = get_node("/root/ItemManager")
		if not item_manager or not item_manager.items_data.has(item_id):
			continue
		
		var item_data = item_manager.items_data[item_id]
		if not item_data.has("equip_stats"):
			continue
		
		var equip_stats = item_data["equip_stats"]
		
		# 添加基础属性
		if equip_stats.has("base_stats"):
			for stat_name in equip_stats["base_stats"].keys():
				if total_stats.has(stat_name):
					total_stats[stat_name] += equip_stats["base_stats"][stat_name]["value"]
		
		# 添加随机属性
		if equip_stats.has("random_stats"):
			for stat_name in equip_stats["random_stats"].keys():
				if total_stats.has(stat_name):
					total_stats[stat_name] += equip_stats["random_stats"][stat_name]["value"]
	
	return total_stats

# 获取指定槽位的装备信息
func get_equipment_in_slot(slot_type: EquipSlotType) -> Dictionary:
	var item_id = equipped_items[slot_type]
	var item_manager = get_node("/root/ItemManager")
	if item_id == "" or not item_manager or not item_manager.items_data.has(item_id):
		return {}
	return item_manager.items_data[item_id]

# 强化装备
func enhance_equipment(slot_type: EquipSlotType) -> bool:
	var item_id = equipped_items[slot_type]
	if item_id == "":
		push_error("槽位没有装备: " + str(slot_type))
		return false
	
	var item_manager = get_node("/root/ItemManager")
	if not item_manager or not item_manager.items_data.has(item_id):
		push_error("装备数据不存在: " + item_id)
		return false
	
	var item_data = item_manager.items_data[item_id]
	if not item_data.has("equip_stats"):
		push_error("装备没有属性数据: " + item_id)
		return false
	
	# TODO: 实现强化逻辑，包括消耗材料、成功率等
	var current_level = item_data["equip_stats"]["enhance_level"]
	var max_level = 10 # 最大强化等级
	
	if current_level >= max_level:
		push_error("装备已达到最大强化等级: " + item_id)
		return false
	
	# 强化成功，提升等级
	item_data["equip_stats"]["enhance_level"] += 1
	print("装备强化成功: " + item_id + " 等级: " + str(item_data["equip_stats"]["enhance_level"]))
	return true

# 保存装备数据
func save_equipment_data() -> Dictionary:
	return {
		"equipped_items": equipped_items
	}

# 加载装备数据
func load_equipment_data(data: Dictionary) -> void:
	if data.has("equipped_items"):
		equipped_items = data["equipped_items"]