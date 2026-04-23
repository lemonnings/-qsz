extends Node
class_name Faze

static var bullet_hit_count: int = 0
static var barrage_offset_angle: float = 0.0
static var barrage_running: bool = false
static var faze_rain_bullet_scene: PackedScene = preload("res://Scenes/player/faze_rain_bullet.tscn")
static var faze_sword_scene: PackedScene = preload("res://Scenes/player/faze_sword.tscn")
static var faze_heal_bullet_scene: PackedScene = preload("res://Scenes/player/faze_heal_bullet.tscn")
static var manager_instance: Faze

var bath_blood_thud_scene: PackedScene = preload("res://Scenes/player/faze_bath_blood_thud.tscn")
var player: Node2D
var electrified_interval: float = 3.0
var electrified_hit_cooldown: float = 1.5
var electrified_timer: float = 0.0
var last_hit_electrified_time: float = -100.0
var last_blood_level: int = 0
var last_thunder_level: int = 0
var last_heal_shield_bonus: float = 0.0
var last_summon_level: int = 0
var last_shield_level: int = 0
var last_wide_level: int = 0
var last_bagua_level: int = 0
var last_treasure_lucky_bonus: int = 0
var last_treasure_atk_speed_bonus: float = 0.0
var last_sixsense_multiplier: float = 1.0
var last_wind_level: int = 0
var last_wind_base_move_speed_bonus: float = 0.0
var last_wind_base_atk_speed_bonus: float = 0.0
var last_wind_stack_atk_speed_bonus: float = 0.0
var last_wind_stack_move_speed_bonus: float = 0.0
var wind_huanfeng_expiries: Array[float] = []

func setup(p_player: Node2D) -> void:
	player = p_player
	Global.connect("player_hit", Callable(self , "_on_player_hit"))
	Global.connect("player_healed", Callable(self , "_on_player_healed"))
	Global.connect("player_shield_damaged", Callable(self , "_on_player_shield_damaged"))
	manager_instance = self
	
	# 初始化时检查一次法则加成，确保初始等级（如调试时）能生效
	check_and_apply_law_bonuses()

func _process(delta: float) -> void:
	if PC.is_game_over:
		return
	# Only dynamic checks here if needed, static bonuses updated via check_and_apply_law_bonuses
	if PC.faze_shield_level >= 7:
		_update_shield_dynamic_dr()
	_update_wind_huanfeng()
		
	if PC.faze_blood_level < 3:
		return
	electrified_timer += delta
	if electrified_timer >= electrified_interval:
		electrified_timer -= electrified_interval
		_trigger_electrified("auto")

func _on_player_hit(damage_val: float, shield_val: float, attacker: Node2D, world_position: Vector2, source_name: String) -> void:
	if PC.is_game_over:
		return
	if PC.faze_blood_level < 3:
		return
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_hit_electrified_time < electrified_hit_cooldown:
		return
	last_hit_electrified_time = current_time
	_trigger_electrified("hit")

func _on_player_healed(amount: float) -> void:
	_fire_heal_bullet(amount, true) # true = 治疗来源

func _on_player_shield_damaged(amount: float) -> void:
	_fire_heal_bullet(amount, false) # false = 护盾损失来源

func _fire_heal_bullet(amount: float, is_heal: bool) -> void:
	if PC.faze_heal_level < 7:
		return
	if PC.is_game_over:
		return
	
	# Find nearest enemy
	var enemies = PC.player_instance.get_tree().get_nodes_in_group("enemies")
	if enemies.size() == 0:
		return
		
	var nearest_enemy = null
	var min_dist = INF
	var player_pos = PC.player_instance.global_position
	
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var dist = player_pos.distance_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest_enemy = enemy
			
	if nearest_enemy == null:
		return

	# Calculate damage
	# 治疗来源: 60% ATK + amount * 2400%
	# 护盾损失来源: 60% ATK + amount * 1600%
	var amount_multiplier = 24.0 if is_heal else 16.0
	var base_damage = float(PC.pc_atk) * 0.6 + amount * amount_multiplier
	var final_damage = base_damage
	
	# 等级乘算累加：每级提升10%（从6阶开始）
	# 公式：1.10^(level - 6)
	var level_multiplier = pow(1.10, PC.faze_heal_level - 6)
	final_damage *= level_multiplier
	
	# Tier 10: 弹体伤害*150%
	if PC.faze_heal_level >= 10:
		final_damage *= 1.5
		
	# Tier 13: 弹体伤害累计*600%（替换10阶的*150%为*600%）
	if PC.faze_heal_level >= 13:
		final_damage *= 4.0 # 10阶*1.5 -> 替换为*6.0，所以*4.0
		
	var is_crit = false
	if PC.faze_heal_level >= 13:
		if randf() < PC.crit_chance:
			is_crit = true
			final_damage *= PC.crit_damage_multi

	var bullet = faze_heal_bullet_scene.instantiate()
	PC.player_instance.get_tree().current_scene.add_child(bullet)
	bullet.global_position = player_pos
	bullet.setup(nearest_enemy, final_damage, is_crit)

func _trigger_electrified(source: String = "unknown") -> void:
	assert(player != null, "faze.gd: player is null")
	var level = PC.faze_blood_level
	var damage_multiplier = _get_blood_electrified_damage_multiplier(level)
	var elite_bonus = _get_blood_electrified_elite_bonus(level)
	var bleed_chance = _get_blood_bleed_chance(level)
	var range_scale = _get_blood_electrified_range_scale(level)
	print("Trigger electrified: level=", level, " range_scale=", range_scale, " trigger_source=", source)
	var shield_ratio = _get_blood_shield_ratio(level)
	var damage = PC.pc_atk * damage_multiplier
	var shield_amount = int(ceil(float(PC.pc_max_hp) * shield_ratio))
	var thud_instance = bath_blood_thud_scene.instantiate()
	get_tree().current_scene.add_child(thud_instance)
	thud_instance.setup_thud(player.global_position, damage, bleed_chance, range_scale, elite_bonus)
	PC.add_shield(shield_amount, 7.0)

func _get_blood_electrified_damage_multiplier(level: int) -> float:
	if level >= 14:
		return 5.0
	if level >= 7:
		return 2.0
	return 1.0

func _get_blood_electrified_elite_bonus(level: int) -> float:
	if level >= 7:
		return 1.0
	return 0.0

func _get_blood_bleed_chance(level: int) -> float:
	if level >= 10:
		return 1.0
	return 0.5

func _get_blood_electrified_range_scale(level: int) -> float:
	if level >= 14:
		return 3.4 # 极大幅提升
	if level >= 10:
		return 1.7 # 大幅提升
	if level >= 3:
		return 1.35 # 基础 +35%
	return 1.0

func _get_blood_shield_ratio(level: int) -> float:
	if level >= 14:
		return 0.07
	return 0.05

func _update_blood_debuff_bonus() -> void:
	var level = PC.faze_blood_level
	if level == last_blood_level:
		return
	last_blood_level = level
	var bleed_elite_bonus = 0.0
	if level >= 10:
		bleed_elite_bonus = 1.0
	EnemyDebuffManager.set_debuff_elite_boss_bonus("bleed", bleed_elite_bonus)

func _update_thunder_debuff_bonus() -> void:
	var level = PC.faze_thunder_level
	if level == last_thunder_level:
		return
	last_thunder_level = level
	var bonus = get_thunder_electrified_elite_bonus(level)
	EnemyDebuffManager.set_debuff_elite_boss_bonus("electrified", bonus)

func _update_heal_shield_bonus() -> void:
	var level = PC.faze_heal_level
	var current_bonus = get_heal_shield_bonus(level)
	
	if current_bonus != PC.faze_heal_shield_bonus:
		var diff = current_bonus - PC.faze_heal_shield_bonus
		PC.heal_multi += diff
		PC.sheild_multi += diff
		PC.faze_heal_shield_bonus = current_bonus

func _update_summon_bonus() -> void:
	var level = PC.faze_summon_level
	if level == last_summon_level:
		return
	last_summon_level = level
	
	# Reset
	PC.faze_summon_damage_bonus = 0.0
	PC.faze_summon_interval_reduction = 0.0
	PC.faze_summon_extra_capacity = 0
	PC.faze_summon_bullet_size_bonus = 0.0
	
	# 3阶：召唤物伤害+15%，触发间隔-10%
	if level >= 3:
		PC.faze_summon_damage_bonus += 0.15
		PC.faze_summon_interval_reduction += 0.1
		
	# 6阶：最大召唤物容量+1，召唤物弹体大小+20%
	if level >= 6:
		PC.faze_summon_extra_capacity += 1
		PC.faze_summon_bullet_size_bonus += 0.2
	if level >= 10:
		PC.faze_summon_damage_bonus += 0.40
	if level >= 14:
		PC.faze_summon_damage_bonus += 1.0
		PC.faze_summon_interval_reduction += 0.3
	_update_summon_bonus_implementation()

var _last_applied_summon_damage: float = 0.0
var _last_applied_summon_interval: float = 0.0
var _last_applied_summon_cap: int = 0
var _last_applied_summon_size: float = 0.0

func _update_summon_bonus_implementation() -> void:
	var level = PC.faze_summon_level
	
	var damage_bonus = 0.0
	var interval_reduction = 0.0
	var extra_cap = 0
	var size_bonus = 0.0
	
	if level >= 3:
		damage_bonus += 0.15
		interval_reduction += 0.1
	if level >= 6:
		extra_cap += 1
		size_bonus += 0.2
	if level >= 10:
		damage_bonus += 0.40
	if level >= 14:
		damage_bonus += 1.0
		interval_reduction += 0.3
		
	# Apply changes
	PC.summon_damage_multiplier = PC.summon_damage_multiplier - _last_applied_summon_damage + damage_bonus
	_last_applied_summon_damage = damage_bonus
	
	if _last_applied_summon_interval != 1.0: # Avoid div by zero
		PC.summon_interval_multiplier /= (1.0 - _last_applied_summon_interval)
	PC.summon_interval_multiplier *= (1.0 - interval_reduction)
	_last_applied_summon_interval = interval_reduction
	
	PC.summon_count_max = PC.summon_count_max - _last_applied_summon_cap + extra_cap
	_last_applied_summon_cap = extra_cap
	
	PC.summon_bullet_size_multiplier = PC.summon_bullet_size_multiplier - _last_applied_summon_size + size_bonus
	_last_applied_summon_size = size_bonus
	
	# Summon special units
	if level >= 10:
		if not _has_special_summon(3):
			_summon_bipolar_sword()
		PC.has_summoned_bipolar_sword = true
	if level >= 14:
		if not _has_special_summon(10):
			_summon_sword_spirit()
		PC.has_summoned_sword_spirit = true

func _summon_bipolar_sword() -> void:
	_spawn_special_summon(3) # 3 is GOLD_ENHANCED (based on enum in summon.gd: BLUE_RANDOM=0... GOLD_ENHANCED=3)

func _summon_sword_spirit() -> void:
	# SummonType.SWORD_SPIRIT (10)
	_spawn_special_summon(10)

func _spawn_special_summon(type_int: int) -> void:
	var summon_scene = preload("res://Scenes/summon.tscn")
	var summon = summon_scene.instantiate()
	summon.summon_type = type_int
	player.get_parent().add_child(summon) # Add to same parent as player (usually YSort/TileMap)
	summon.global_position = player.global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
	summon.set_summon_type(type_int)

func _has_special_summon(type_int: int) -> bool:
	if not player:
		return false
	var parent = player.get_parent()
	if not parent:
		return false
	for child in parent.get_children():
		if not child or not is_instance_valid(child):
			continue
		if not child.has_method("set_summon_type"):
			continue
		if child.get("summon_type") == type_int:
			return true
	return false

var _last_applied_shield_hp_bonus: float = 0.0
var _last_applied_shield_gain_bonus: float = 0.0
var _last_applied_damage_reduction: float = 0.0

func _update_shield_law_bonus() -> void:
	var level = PC.faze_shield_level
	if level == last_shield_level:
		# Check dynamic damage reduction based on current shield
		if level >= 7:
			_update_shield_dynamic_dr()
		return
	last_shield_level = level
	
	var hp_bonus = 0.0
	var gain_bonus = 0.0
	var heal_conversion = 0.0
	
	# 3阶：护盾获取加成提升20%，最大体力提升10%
	if level >= 3:
		gain_bonus += 0.20
		hp_bonus += 0.10
		
	# 5阶：最大体力再次提升25%，护盾因时间结束消失后，兣30%会转为生命回复
	if level >= 5:
		hp_bonus += 0.25
		heal_conversion = 0.30
			
	# 7阶：最大体力再次提升35%，每存在相当于最大体力3%的护盾，获得额外 1%的减伤率，最高20%
	if level >= 7:
		hp_bonus += 0.35
		
	# 10阶：护盾获取加成再次提升50%，护盾因时间结束消失后，其50%会转为生命回复
	if level >= 10:
		gain_bonus += 0.50
		heal_conversion = 0.50
		
	if PC.pc_max_hp > 0:
		var base_hp = float(PC.pc_max_hp) / (1.0 + _last_applied_shield_hp_bonus)
		PC.pc_max_hp = int(base_hp * (1.0 + hp_bonus))
		# Adjust current HP to maintain ratio or just clamp? Usually just clamp or keep same value.
		# If max hp increases, current hp usually stays same unless healed.
		if PC.pc_hp > PC.pc_max_hp:
			PC.pc_hp = PC.pc_max_hp
	_last_applied_shield_hp_bonus = hp_bonus
	
	# Apply Gain Bonus
	PC.sheild_multi = PC.sheild_multi - _last_applied_shield_gain_bonus + gain_bonus
	_last_applied_shield_gain_bonus = gain_bonus
	
	# Apply Conversion Ratio
	PC.faze_shield_heal_conversion_ratio = heal_conversion
	
	# Dynamic DR update is handled in _process per frame/timer
	if level >= 7:
		_update_shield_dynamic_dr()

func check_and_apply_law_bonuses() -> void:
	_update_blood_debuff_bonus()
	_update_thunder_debuff_bonus()
	_update_heal_shield_bonus()
	_update_summon_bonus()
	_update_shield_law_bonus()
	_update_wind_bonus()
	_update_wide_bonus()
	_update_bagua_bonus()
	_update_treasure_bonus()
	_update_chaos_bonus()
	_update_sixsense_bonus()

func _update_shield_dynamic_dr() -> void:
	if PC.pc_max_hp <= 0:
		return
		
	var current_shield = PC.get_total_shield()
	var ratio = float(current_shield) / float(PC.pc_max_hp)
	
	# 每3%护盾 -> 1%减伤
	var stacks = floor(ratio / 0.03)
	var dr_bonus = stacks * 0.01
	
	# Limit to 20%
	if dr_bonus > 0.20:
		dr_bonus = 0.20
		
	# Update PC
	PC.damage_reduction_rate = PC.damage_reduction_rate - _last_applied_damage_reduction + dr_bonus
	_last_applied_damage_reduction = dr_bonus
	
	# Clamp DR
	if PC.damage_reduction_rate > 0.9:
		PC.damage_reduction_rate = 0.9

func _update_wind_bonus() -> void:
	var level = PC.faze_wind_level
	var base_move_bonus = Faze.get_wind_base_move_speed_bonus(level)
	if base_move_bonus != last_wind_base_move_speed_bonus:
		PC.pc_speed += base_move_bonus - last_wind_base_move_speed_bonus
		last_wind_base_move_speed_bonus = base_move_bonus
	# 7阶：啸风类攻击速度+25%
	var base_atk_speed_bonus = 0.25 if level >= 7 else 0.0
	if base_atk_speed_bonus != last_wind_base_atk_speed_bonus:
		PC.pc_atk_speed += base_atk_speed_bonus - last_wind_base_atk_speed_bonus
		last_wind_base_atk_speed_bonus = base_atk_speed_bonus
	var max_stacks = Faze.get_wind_huanfeng_max_stacks(level)
	PC.wind_huanfeng_max_stacks = max_stacks
	last_wind_level = level
	if max_stacks > 0 and wind_huanfeng_expiries.size() > max_stacks:
		wind_huanfeng_expiries.sort()
		while wind_huanfeng_expiries.size() > max_stacks:
			wind_huanfeng_expiries.pop_front()
	if level < 7:
		_clear_wind_huanfeng()

func _add_wind_huanfeng_stack() -> void:
	if PC.faze_wind_level < 7:
		return
	var max_stacks = Faze.get_wind_huanfeng_max_stacks(PC.faze_wind_level)
	if max_stacks <= 0:
		return
	var now = Time.get_ticks_msec() / 1000.0
	if wind_huanfeng_expiries.size() >= max_stacks:
		wind_huanfeng_expiries.sort()
		wind_huanfeng_expiries.pop_front()
	wind_huanfeng_expiries.append(now + PC.wind_huanfeng_duration)
	_update_wind_huanfeng()

func _update_wind_huanfeng() -> void:
	if PC.faze_wind_level < 7:
		if wind_huanfeng_expiries.size() > 0:
			_clear_wind_huanfeng()
		return
	var now = Time.get_ticks_msec() / 1000.0
	for i in range(wind_huanfeng_expiries.size() - 1, -1, -1):
		if wind_huanfeng_expiries[i] <= now:
			wind_huanfeng_expiries.remove_at(i)
	var stacks = wind_huanfeng_expiries.size()
	var target_bonus = float(stacks) * Faze.get_wind_huanfeng_speed_bonus_per_stack(PC.faze_wind_level)
	var delta_atk = target_bonus - last_wind_stack_atk_speed_bonus
	PC.pc_atk_speed += delta_atk
	last_wind_stack_atk_speed_bonus = target_bonus
	var delta_move = target_bonus - last_wind_stack_move_speed_bonus
	PC.pc_speed += delta_move
	last_wind_stack_move_speed_bonus = target_bonus
	PC.wind_huanfeng_stacks = stacks
	PC.wind_huanfeng_max_stacks = Faze.get_wind_huanfeng_max_stacks(PC.faze_wind_level)
	if stacks > 0:
		var remaining = _get_wind_huanfeng_remaining_time(now)
		if BuffManager.has_buff("huanfeng"):
			Global.emit_signal("buff_updated", "huanfeng", remaining, stacks)
		else:
			Global.emit_signal("buff_added", "huanfeng", remaining, stacks)
	else:
		if BuffManager.has_buff("huanfeng"):
			BuffManager.remove_buff("huanfeng")

func _get_wind_huanfeng_remaining_time(now: float) -> float:
	var max_time = 0.0
	for expiry in wind_huanfeng_expiries:
		var remain = expiry - now
		if remain > max_time:
			max_time = remain
	return max_time

func _clear_wind_huanfeng() -> void:
	if last_wind_stack_atk_speed_bonus != 0.0:
		PC.pc_atk_speed -= last_wind_stack_atk_speed_bonus
		last_wind_stack_atk_speed_bonus = 0.0
	if last_wind_stack_move_speed_bonus != 0.0:
		PC.pc_speed -= last_wind_stack_move_speed_bonus
		last_wind_stack_move_speed_bonus = 0.0
	wind_huanfeng_expiries.clear()
	PC.wind_huanfeng_stacks = 0
	if BuffManager.has_buff("huanfeng"):
		BuffManager.remove_buff("huanfeng")

func _update_wide_bonus() -> void:
	var level = PC.faze_wide_level
	if level == last_wide_level:
		return
	last_wide_level = level
	
	PC.faze_wide_range_bonus = 0.0
	PC.faze_wide_damage_bonus = 0.0
	PC.faze_wide_range_to_damage_ratio = 0.0
	
	# 4阶：广域类武器伤害及范围提升20%
	if level >= 4:
		PC.faze_wide_range_bonus += 0.20
		PC.faze_wide_damage_bonus += 0.20
		
	# 7阶：广域类武器范围提升10%，并且广域类武器的范围加成每提高1%，伤害提高1%
	if level >= 7:
		PC.faze_wide_range_bonus += 0.10
		PC.faze_wide_range_to_damage_ratio = 1.0
		
	# 10阶：广域类武器的伤害提升45%，范围提升25%
	if level >= 10:
		PC.faze_wide_damage_bonus += 0.45
		PC.faze_wide_range_bonus += 0.25
		
	# 13阶：广域类武器的范围提升1%，伤害提升值提升到3%
	if level >= 13:
		PC.faze_wide_range_to_damage_ratio = 3.0
		
	# 16阶：广域类武器伤害及范围再次提升80%
	if level >= 16:
		PC.faze_wide_range_bonus += 0.80
		PC.faze_wide_damage_bonus += 0.80

func _update_bagua_bonus() -> void:
	var level = PC.faze_bagua_level
	if level == last_bagua_level:
		return
	last_bagua_level = level
	
	PC.faze_bagua_damage_bonus = 0.0
	PC.faze_bagua_gain_multiplier = 1.0
	
	# 4阶：基础推衍系统开启（具体逻辑在add_bagua_progress中）
	
	# 8阶：推衍度获得*2，八卦类武器伤害提升25%
	if level >= 8:
		PC.faze_bagua_gain_multiplier *= 2.0
		PC.faze_bagua_damage_bonus += 0.25
		
	# 12阶：推衍度获得提升至3倍，八卦类武器伤害再次提升35%
	if level >= 12:
		PC.faze_bagua_gain_multiplier *= 1.5 # Total 3x (2 * 1.5)
		PC.faze_bagua_damage_bonus += 0.35
		
	# 15阶：推衍度获得提升至5倍，八卦类武器伤害再次提升50%
	if level >= 15:
		PC.faze_bagua_gain_multiplier *= (5.0 / 3.0) # Total 5x
		PC.faze_bagua_damage_bonus += 0.50
		
	# 18阶：推衍度获得提升至10倍，八卦类武器伤害再次提升120%
	if level >= 18:
		PC.faze_bagua_gain_multiplier *= (10.0 / 5.0) # Total 10x
		PC.faze_bagua_damage_bonus += 1.20

# 增加八卦推衍度
static func add_bagua_progress(amount: int, is_elite_boss: bool = false) -> void:
	if PC.faze_bagua_level < 4:
		return
		
	var final_amount = amount
	if is_elite_boss:
		final_amount *= 2
		
	final_amount = int(final_amount * PC.faze_bagua_gain_multiplier)
	
	PC.faze_bagua_progress += final_amount
	
	# 检查是否升级
	while PC.faze_bagua_progress >= PC.faze_bagua_next_threshold:
		PC.faze_bagua_progress -= PC.faze_bagua_next_threshold
		PC.faze_bagua_completed_layers += 1
		PC.faze_bagua_next_threshold += 10
		PC.exp_multi += 0.04
		
	# 更新Buff显示
	_update_bagua_buff_display()

static func _update_bagua_buff_display() -> void:
	# 更新Buff描述
	BuffManager.update_bagua_progress_description()
	
	# 推衍度 Buff
	if PC.faze_bagua_progress > 0:
		if BuffManager.has_buff("bagua_progress"):
			Global.emit_signal("buff_stack_changed", "bagua_progress", PC.faze_bagua_progress)
		else:
			Global.emit_signal("buff_added", "bagua_progress", -1, PC.faze_bagua_progress)
	else:
		if BuffManager.has_buff("bagua_progress"):
			Global.emit_signal("buff_removed", "bagua_progress")
			
	# 推衍完成 Buff
	if PC.faze_bagua_completed_layers > 0:
		if BuffManager.has_buff("bagua_completed"):
			Global.emit_signal("buff_stack_changed", "bagua_completed", PC.faze_bagua_completed_layers)
		else:
			Global.emit_signal("buff_added", "bagua_completed", -1, PC.faze_bagua_completed_layers)

static func on_wind_weapon_hit() -> void:
	if manager_instance:
		manager_instance._add_wind_huanfeng_stack()

static func get_bagua_damage_multiplier() -> float:
	var multiplier = 1.0 + PC.faze_bagua_damage_bonus
	# 每层推衍完成提升4%
	multiplier += PC.faze_bagua_completed_layers * 0.04
	return multiplier

static func get_wide_damage_multiplier(base_range_bonus: float) -> float:
	# 基础伤害加成
	var multiplier = 1.0 + PC.faze_wide_damage_bonus
	
	# 范围转伤害
	# 总范围加成 = 基础范围加成 + 法则范围加成
	var total_range_bonus = base_range_bonus + PC.faze_wide_range_bonus
	
	# 转化率 (1%范围 -> 1%或3%伤害)
	# total_range_bonus is like 0.5 for 50%
	# ratio is 1.0 or 3.0
	# bonus = (total_range_bonus * 100) * (ratio / 100) = total_range_bonus * ratio
	var converted_damage = total_range_bonus * PC.faze_wide_range_to_damage_ratio
	
	multiplier += converted_damage
	return multiplier

static func get_wide_range_multiplier() -> float:
	return 1.0 + PC.faze_wide_range_bonus

static func get_destroy_damage_multiplier(level: int) -> float:
	var bonus = 0.0
	if level >= 7:
		bonus += 0.25
	if level >= 16:
		bonus += 1.5
	return 1.0 + bonus

static func get_destroy_crit_chance_bonus(level: int) -> float:
	var bonus = 0.0
	if level >= 4:
		bonus += 0.15
	if level >= 13:
		bonus += 0.25
	return bonus

static func get_destroy_crit_damage_bonus(level: int) -> float:
	if level >= 7:
		return 0.25
	return 0.0

static func get_destroy_crit_fluctuation_multiplier(level: int) -> float:
	if level >= 16:
		return randf_range(0.5, 4.0) # -50% ~ +300%
	if level >= 13:
		return randf_range(0.6, 2.2) # -40% ~ +120%
	if level >= 10:
		return randf_range(0.7, 1.9) # -30% ~ +90%
	return 1.0

static func apply_destroy_crit_overflow(base_chance: float, base_crit_multi: float, level: int) -> Dictionary:
	var final_chance = base_chance + get_destroy_crit_chance_bonus(level)
	var final_crit_multi = base_crit_multi + get_destroy_crit_damage_bonus(level)
	if final_chance > 1.0:
		var overflow = final_chance - 1.0
		final_chance = 1.0
		final_crit_multi += overflow
	return {
		"crit_chance": final_chance,
		"crit_multi": final_crit_multi
	}

static func get_life_damage_multiplier(level: int) -> float:
	var bonus = 0.0
	if level >= 4:
		bonus += 0.25
	if level >= 7:
		bonus += 0.35
	if level >= 10:
		bonus += 0.50
	if level >= 13:
		bonus += 0.70
	if level >= 16:
		bonus += 1.80
	return 1.0 + bonus

static func get_life_range_multiplier(level: int) -> float:
	var bonus = 0.0
	if level >= 7:
		bonus += 0.25
	return 1.0 + bonus

static func get_life_exp_multiplier(level: int) -> float:
	if level >= 16:
		return 3.0
	if level >= 10:
		return 1.8
	if level >= 7:
		return 1.4
	if level >= 4:
		return 1.2
	return 1.0

static func get_exp_multiplier() -> float:
	var multiplier = 1.0 + PC.exp_multi
	multiplier = multiplier * get_life_exp_multiplier(PC.faze_life_level)
	multiplier = multiplier * get_chaos_exp_multiplier(PC.faze_chaos_level)
	return multiplier

static func get_life_attack_interval_multiplier(level: int) -> float:
	if level >= 13:
		return 0.8
	return 1.0

static func get_fire_weapon_damage_multiplier(level: int) -> float:
	var bonus = 0.0
	if level >= 4:
		bonus += 0.3
	if level >= 8:
		bonus += 0.4
	if level >= 12:
		bonus += 0.6
	if level >= 16:
		bonus += 1.0
	return 1.0 + bonus

static func get_burn_damage_multiplier(level: int) -> float:
	var bonus = 0.0
	if level >= 4:
		bonus += 0.5
	if level >= 8:
		bonus += 0.4
	if level >= 12:
		bonus += 0.6
	if level >= 16:
		bonus += 1.0
	return 1.0 + bonus

static func get_burn_range_multiplier(level: int) -> float:
	var bonus = 0.0
	if level >= 8:
		bonus += 0.4
	if level >= 12:
		bonus += 0.6
	if level >= 16:
		bonus += 1.0
	return 1.0 + bonus

static func get_fire_elite_boss_multiplier(level: int) -> float:
	# 12阶：对精英、首领造成3倍伤害
	# 16阶：对精英、首领造成15倍伤害
	if level >= 16:
		return 15.0
	if level >= 12:
		return 3.0
	return 1.0

static func get_burn_duration_bonus(level: int) -> float:
	# 8阶：燃烧伤害持续时间+1秒
	if level >= 8:
		return 1.0
	return 0.0

static func get_treasure_lucky_bonus(level: int) -> int:
	var bonus = 0
	if level >= 4:
		bonus += 4
	if level >= 7:
		bonus += 6
	if level >= 10:
		bonus += 12
	if level >= 13:
		bonus += 8
	if level >= 16:
		bonus += 12
	return bonus

static func get_treasure_weapon_damage_multiplier(level: int, lucky: int) -> float:
	var bonus = 0.0
	if level >= 4:
		bonus += 0.15
	if level >= 7:
		bonus += float(lucky) * 0.03
	if level >= 13:
		bonus += 0.35
	if level >= 16:
		bonus += 1.0
	return 1.0 + bonus

static func get_treasure_elite_boss_multiplier(level: int, lucky: int) -> float:
	if level < 16:
		return 1.0
	return 1.0 + float(lucky) * 0.06

static func get_treasure_extra_refresh_count(level: int, lucky: int) -> int:
	if level < 13:
		return 0
	if lucky <= 0:
		return 0
	return int(lucky / 20.0)

static func get_skill_damage_multiplier(level: int) -> float:
	var bonus = 0.0
	if level >= 4:
		bonus += 0.20
	if level >= 8:
		bonus += 0.35
	if level >= 12:
		bonus += 0.60
	if level >= 16:
		bonus += 1.0
	return 1.0 + bonus

static func get_wind_weapon_damage_multiplier(level: int) -> float:
	var bonus = 0.0
	if level >= 4:
		bonus += 0.25
	if level >= 10:
		bonus += 0.25
	if level >= 13:
		bonus += 0.40
	if level >= 16:
		bonus += 0.90
	return 1.0 + bonus

static func get_wind_base_move_speed_bonus(level: int) -> float:
	var bonus = 0.0
	if level >= 4:
		bonus += 0.10
	if level >= 10:
		bonus += 0.25
	return bonus

static func get_wind_huanfeng_max_stacks(level: int) -> int:
	if level >= 13:
		return 300
	if level >= 7:
		return 200
	return 0

static func get_wind_huanfeng_speed_bonus_per_stack(level: int) -> float:
	if level >= 7:
		return 0.001
	return 0.0

static func get_wind_elite_boss_multiplier(level: int, stacks: int) -> float:
	if level < 16:
		return 1.0
	return 1.0 + float(stacks) * 0.005

static func get_sixsense_multiplier(level: int) -> float:
	if level >= 6:
		return 8.0
	if level >= 5:
		return 4.0
	if level >= 4:
		return 2.4
	if level >= 3:
		return 1.6
	if level >= 2:
		return 1.2
	return 1.0

static func get_chaos_final_damage_multiplier(level: int) -> float:
	var bonus = 0.0
	if level >= 2:
		bonus += 0.20
	if level >= 4:
		bonus += 0.40
	if level >= 6:
		bonus += 0.80
	if level >= 9:
		bonus += 1.60
	return 1.0 + bonus

static func get_chaos_exp_multiplier(level: int) -> float:
	var bonus = 0.0
	if level >= 2:
		bonus += 0.20
	if level >= 4:
		bonus += 0.40
	if level >= 6:
		bonus += 0.80
	if level >= 9:
		bonus += 1.60
	return 1.0 + bonus

static func get_chaos_point_multiplier(level: int) -> float:
	var bonus = 0.0
	if level >= 2:
		bonus += 0.10
	if level >= 4:
		bonus += 0.20
	if level >= 6:
		bonus += 0.40
	if level >= 9:
		bonus += 0.80
	return 1.0 + bonus

static func get_final_damage_multiplier() -> float:
	return (1.0 + PC.pc_final_atk) * get_chaos_final_damage_multiplier(PC.faze_chaos_level)

static func get_point_multiplier() -> float:
	return get_chaos_point_multiplier(PC.faze_chaos_level)

static func _calculate_chaos_level() -> int:
	var levels: Array = [
		PC.faze_blood_level,
		PC.faze_sword_level,
		PC.faze_thunder_level,
		PC.faze_heal_level,
		PC.faze_summon_level,
		PC.faze_shield_level,
		PC.faze_fire_level,
		PC.faze_destroy_level,
		PC.faze_life_level,
		PC.faze_bullet_level,
		PC.faze_wide_level,
		PC.faze_bagua_level,
		PC.faze_treasure_level,
		PC.faze_skill_level,
		PC.faze_sixsense_level,
		PC.faze_wind_level,
	]
	var chaos_level = 0
	for level in levels:
		if level >= 4:
			chaos_level += 1
		if level >= 7:
			chaos_level += 1
		if level >= 10:
			chaos_level -= 2
	if chaos_level < 0:
		chaos_level = 0
	return chaos_level

func _update_treasure_bonus() -> void:
	var bonus = Faze.get_treasure_lucky_bonus(PC.faze_treasure_level)
	var level = PC.faze_treasure_level
	
	# 10阶：宝器类武器攻击速度+25%
	var atk_speed_bonus = 0.25 if level >= 10 else 0.0
	if atk_speed_bonus != last_treasure_atk_speed_bonus:
		PC.pc_atk_speed += atk_speed_bonus - last_treasure_atk_speed_bonus
		last_treasure_atk_speed_bonus = atk_speed_bonus
	
	if bonus == last_treasure_lucky_bonus:
		return
	var delta = bonus - last_treasure_lucky_bonus
	last_treasure_lucky_bonus = bonus
	PC.now_lunky_level += delta
	PC.lucky += delta
	Global.emit_signal("lucky_level_up", delta)

func _update_chaos_bonus() -> void:
	var chaos_level = Faze._calculate_chaos_level()
	PC.faze_chaos_level = chaos_level

func _update_sixsense_bonus() -> void:
	var multiplier = Faze.get_sixsense_multiplier(PC.faze_sixsense_level)
	last_sixsense_multiplier = multiplier
	PC.sixsense_bonus_multiplier = multiplier
	
	var base_crit_chance = PC.sixsense_base_crit_chance
	var target_crit_chance_bonus = base_crit_chance * (multiplier - 1.0)
	var delta_crit_chance = target_crit_chance_bonus - PC.sixsense_applied_crit_chance
	PC.crit_chance += delta_crit_chance
	PC.sixsense_applied_crit_chance = target_crit_chance_bonus
	
	var base_crit_damage = PC.sixsense_base_crit_damage_multi
	var target_crit_damage_bonus = base_crit_damage * (multiplier - 1.0)
	var delta_crit_damage = target_crit_damage_bonus - PC.sixsense_applied_crit_damage_multi
	PC.crit_damage_multi += delta_crit_damage
	PC.sixsense_applied_crit_damage_multi = target_crit_damage_bonus
	
	var base_final_damage = PC.sixsense_base_final_damage
	var target_final_damage_bonus = base_final_damage * (multiplier - 1.0)
	var delta_final_damage = target_final_damage_bonus - PC.sixsense_applied_final_damage
	PC.pc_final_atk += delta_final_damage
	PC.sixsense_applied_final_damage = target_final_damage_bonus
	
	var base_atk_speed = PC.sixsense_base_atk_speed
	var target_atk_speed_bonus = base_atk_speed * (multiplier - 1.0)
	var delta_atk_speed = target_atk_speed_bonus - PC.sixsense_applied_atk_speed
	PC.pc_atk_speed += delta_atk_speed
	PC.sixsense_applied_atk_speed = target_atk_speed_bonus
	
	var base_damage_reduction = PC.sixsense_base_damage_reduction
	var target_damage_reduction_bonus = base_damage_reduction * (multiplier - 1.0)
	var delta_damage_reduction = target_damage_reduction_bonus - PC.sixsense_applied_damage_reduction
	PC.damage_reduction_rate += delta_damage_reduction
	PC.sixsense_applied_damage_reduction = target_damage_reduction_bonus
	
	var base_atk = PC.sixsense_base_atk
	var target_atk_bonus = base_atk * PC.pc_start_atk * (multiplier - 1.0)
	var delta_atk = target_atk_bonus - PC.sixsense_applied_atk
	PC.pc_atk += int(round(delta_atk))
	PC.sixsense_applied_atk = target_atk_bonus

static func get_bullet_damage_multiplier(level: int) -> float:
	var bonus = 0.0
	if level >= 4:
		bonus += 0.15
	if level >= 12:
		bonus += 0.35
	if level >= 15:
		bonus += 0.50
	if level >= 18:
		bonus += 1.20
	return 1.0 + bonus

static func get_bullet_range_multiplier(level: int) -> float:
	var bonus = 0.0
	if level >= 4:
		bonus += 0.20
	if level >= 12:
		bonus += 0.30
	return 1.0 + bonus

static func get_sword_attack_speed_multiplier(level: int) -> float:
	var bonus = 0.0
	if level >= 4:
		bonus += 0.2
	if level >= 10:
		bonus += 0.3
	if level >= 16:
		bonus += 0.6
	return 1.0 + bonus

static func get_sword_crit_damage_multiplier(level: int) -> float:
	var bonus = 0.0
	if level >= 4:
		bonus += 0.1
	if level >= 10:
		bonus += 0.3
	return PC.crit_damage_multi + bonus

static func get_coldlight_damage_multiplier(level: int) -> float:
	if level >= 16:
		return 5.0
	if level >= 7:
		return 2.4
	return 0.0

static func on_sword_weapon_hit(enemy: Node) -> void:
	if PC.faze_sword_level < 7:
		return
	assert(enemy != null, "faze.gd: enemy is null")
	var stack = 0
	var nodes: Array = []
	if enemy.has_meta("coldlight_stack"):
		stack = enemy.get_meta("coldlight_stack")
	else:
		enemy.set_meta("coldlight_stack", 0)
	if enemy.has_meta("coldlight_nodes"):
		nodes = enemy.get_meta("coldlight_nodes")
	else:
		enemy.set_meta("coldlight_nodes", [])
	
	stack += 1
	var effect = faze_sword_scene.instantiate()
	enemy.add_child(effect)
	effect.rotation = randf_range(0.0, TAU)
	effect.modulate.a = 0.0
	var fade_in = effect.create_tween()
	fade_in.tween_property(effect, "modulate:a", 1.0, 0.25)
	nodes.append(effect)
	
	if stack >= 5:
		var damage_multiplier = get_coldlight_damage_multiplier(PC.faze_sword_level)
		var damage = PC.pc_atk * damage_multiplier
		var is_crit = false
		if PC.faze_sword_level >= 13:
			if enemy.is_in_group("elite") or enemy.is_in_group("boss"):
				damage *= 1.5
			if randf() < PC.crit_chance:
				is_crit = true
				damage *= (PC.crit_damage_multi + 0.3)
		enemy.take_damage(int(damage), is_crit, false, "faze_sword_coldlight")
		for node in nodes:
			var fade_out = node.create_tween()
			fade_out.tween_property(node, "modulate:a", 0.0, 0.25)
			fade_out.tween_callback(Callable(node, "queue_free"))
		stack = 0
		nodes = []
	
	enemy.set_meta("coldlight_stack", stack)
	enemy.set_meta("coldlight_nodes", nodes)

# 怪物死亡时立即清除刀剑法则冷光图像效果
static func clear_sword_faze_effects(enemy: Node) -> void:
	if not enemy.has_meta("coldlight_nodes"):
		return
	var nodes: Array = enemy.get_meta("coldlight_nodes")
	for node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	enemy.set_meta("coldlight_stack", 0)
	enemy.set_meta("coldlight_nodes", [])

static func on_bullet_hit() -> void:
	if PC.faze_bullet_level < 8:
		return
	if PC.is_game_over:
		return
	bullet_hit_count += 1
	_sync_barrage_charge_buff()
	if barrage_running:
		return
	if bullet_hit_count >= 100:
		bullet_hit_count -= 100
		_sync_barrage_charge_buff()
		assert(manager_instance != null, "faze.gd: manager_instance is null")
		manager_instance._start_barrage()

func _start_barrage() -> void:
	assert(PC.player_instance != null, "faze.gd: player_instance is null")
	barrage_running = true
	var level = PC.faze_bullet_level
	var total_bullets = _get_barrage_total_bullets(level)
	var wave_count = int(total_bullets / 45.0)
	var damage_multiplier = _get_barrage_damage_multiplier(level)
	var damage = PC.pc_atk * damage_multiplier
	for i in range(wave_count):
		if not is_instance_valid(PC.player_instance):
			break
		var tree := PC.player_instance.get_tree()
		if tree == null:
			break
		_spawn_barrage_wave(PC.player_instance.global_position, damage, barrage_offset_angle)
		barrage_offset_angle += 4.0
		if i < wave_count - 1:
			# 升级/暂停期间不要继续计时，避免时停时仍然按时补发弹幕。
			await tree.create_timer(0.3, false).timeout
	barrage_running = false
	if bullet_hit_count >= 100:
		bullet_hit_count -= 100
		_sync_barrage_charge_buff()
		_start_barrage()

func _spawn_barrage_wave(origin: Vector2, damage: float, angle_offset: float) -> void:
	var scene = PC.player_instance.get_tree().current_scene
	for i in range(45):
		var angle_deg = angle_offset + float(i) * 8.0
		var dir = Vector2.RIGHT.rotated(deg_to_rad(angle_deg))
		var bullet = faze_rain_bullet_scene.instantiate()
		scene.add_child(bullet)
		bullet.setup_barrage_bullet(origin, dir, damage)

static func _get_barrage_total_bullets(level: int) -> int:
	if level >= 18:
		return 270
	if level >= 15:
		return 180
	if level >= 12:
		return 135
	return 90

static func _get_barrage_damage_multiplier(level: int) -> float:
	if level >= 18:
		return 5.0
	if level >= 15:
		return 1.8
	if level >= 12:
		return 0.9
	return 0.5

static func _sync_barrage_charge_buff() -> void:
	if PC.faze_bullet_level < 8:
		if BuffManager.has_buff("barrage_charge"):
			Global.emit_signal("buff_removed", "barrage_charge")
		return
	var charge_count = bullet_hit_count
	if charge_count > 0:
		if BuffManager.has_buff("barrage_charge"):
			Global.emit_signal("buff_stack_changed", "barrage_charge", charge_count)
		else:
			Global.emit_signal("buff_added", "barrage_charge", -1, charge_count)
	else:
		if BuffManager.has_buff("barrage_charge"):
			Global.emit_signal("buff_removed", "barrage_charge")

static func get_thunder_weapon_damage_multiplier(level: int) -> float:
	var bonus = 0.0
	if level >= 4:
		bonus += 0.2
	if level >= 13:
		bonus += 1.6
	return 1.0 + bonus

static func get_thunder_electrified_damage_multiplier(level: int) -> float:
	var bonus = 0.0
	if level >= 4:
		bonus += 0.4
	if level >= 10:
		bonus += 1.0
	return 1.0 + bonus

static func get_thunder_damage_vs_electrified_bonus(level: int) -> float:
	if level >= 7:
		return 0.6
	return 0.0

static func get_thunder_electrified_elite_bonus(level: int) -> float:
	if level >= 13:
		return 3.0
	if level >= 10:
		return 1.0
	return 0.0

static func get_heal_shield_bonus(level: int) -> float:
	var bonus = 0.0
	if level >= 4:
		bonus += 0.30
	if level >= 10:
		bonus += 0.35
	if level >= 13:
		bonus += 0.50
	return bonus
