extends Node
class_name Faze

static var bullet_hit_count: int = 0
static var barrage_offset_angle: float = 0.0
static var barrage_running: bool = false
static var faze_rain_bullet_scene: PackedScene = preload("res://Scenes/player/faze_rain_bullet.tscn")
static var faze_sword_scene: PackedScene = preload("res://Scenes/player/faze_sword.tscn")
static var faze_heal_bullet_scene: PackedScene = preload("res://Scenes/player/faze_heal_bullet.tscn")
static var faze_thunder_scene: PackedScene = preload("res://Scenes/player/faze_thunder.tscn")
static var faze_destory_scene: PackedScene = preload("res://Scenes/player/faze_destory.tscn")
static var faze_light_scene: PackedScene = preload("res://Scenes/player/faze_light.tscn")
static var manager_instance: Faze
static var _bagua_hit_progress_msec_by_target: Dictionary = {}
static var _bagua_hit_progress_last_cleanup_msec: int = 0

const BARRAGE_BULLETS_PER_WAVE := 45
const BARRAGE_BULLETS_PER_FRAME := 999
const BARRAGE_ACTIVE_SOFT_CAP := 999
const BARRAGE_WAVE_INTERVAL: float = 0.12
const BARRAGE_TRIGGER_ANGLE_OFFSET_STEP: float = 4.0
const BAGUA_HIT_PROGRESS_TARGET_COOLDOWN_MSEC: int = 1000
const BAGUA_HIT_PROGRESS_RECORD_TTL_MSEC: int = 5000

var bath_blood_thud_scene: PackedScene = preload("res://Scenes/player/faze_bath_blood_thud.tscn")
var player: Node2D
var electrified_interval: float = 4.0
var electrified_hit_cooldown: float = 2.0
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
var _blood_thud_trigger_frame: int = -1
var _last_blood_independent_dr_multiplier: float = 1.0
# 生灵法则 9阶：神圣光辉计时器
var life_sacred_light_timer: float = 0.0
var life_sacred_light_interval: float = 20.0

func setup(p_player: Node2D) -> void:
	player = p_player
	_reset_bagua_hit_progress_records()
	_last_blood_independent_dr_multiplier = 1.0
	Global.connect("player_hit", Callable(self , "_on_player_hit"))
	Global.connect("player_healed", Callable(self , "_on_player_healed"))
	Global.connect("player_shield_damaged", Callable(self , "_on_player_shield_damaged"))
	# 生灵法则：监听升级信号，升级时触发神圣光辉
	Global.connect("player_lv_up", Callable(self , "_on_life_level_up_trigger"))
	manager_instance = self
	
	# 初始化时检查一次法则加成，确保初始等级（如调试时）能生效
	check_and_apply_law_bonuses()

func _process(delta: float) -> void:
	if PC.is_game_over:
		return
	# Only dynamic checks here if needed, static bonuses updated via check_and_apply_law_bonuses
	if PC.faze_shield_level >= 11:
		_update_shield_dynamic_dr()
	_update_wind_huanfeng()
	# 22阶御灵法则：召唤物数量动态加成
	if PC.faze_summon_level >= 22:
		_update_summon_count_bonus()
	# 生灵法则 9阶：每隔一段时间触发神圣光辉，29阶缩短触发间隔。
	if PC.faze_life_level >= 9 and _can_trigger_life_sacred_light():
		life_sacred_light_interval = _get_life_sacred_light_interval()
		life_sacred_light_timer += delta
		if life_sacred_light_timer >= life_sacred_light_interval:
			life_sacred_light_timer -= life_sacred_light_interval
			_trigger_sacred_light()
	elif PC.faze_life_level < 9:
		life_sacred_light_timer = 0.0
		
	if PC.faze_blood_level < 4:
		_update_blood_independent_damage_reduction()
		return
	_update_blood_independent_damage_reduction()
	electrified_timer += delta
	if electrified_timer >= electrified_interval:
		electrified_timer -= electrified_interval
		_trigger_electrified("auto")

func _on_life_level_up_trigger() -> void:
	if PC.faze_life_level < 9:
		return
	if not _can_trigger_life_sacred_light():
		return
	# 升级时重置计时器并立即触发一次
	life_sacred_light_timer = 0.0
	_trigger_sacred_light()

func _can_trigger_life_sacred_light() -> bool:
	return not PC.is_game_over and not Global.in_menu and not Global.in_town

func _get_life_sacred_light_interval() -> float:
	return 4.0 if PC.faze_life_level >= 29 else 20.0

func _trigger_sacred_light() -> void:
	if not faze_light_scene:
		return
	if not player or not is_instance_valid(player):
		return
	life_sacred_light_interval = _get_life_sacred_light_interval()
	FazeLight.fire_skill(faze_light_scene, player.global_position, get_tree())

func _on_player_hit(damage_val: float, shield_val: float, attacker: Node2D, world_position: Vector2, source_name: String) -> void:
	if PC.is_game_over:
		return
	if PC.faze_blood_level < 4:
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
	if PC.faze_heal_level < 9:
		return
	if PC.is_game_over:
		return
	if not PC.player_instance or not is_instance_valid(PC.player_instance):
		return
	
	var tree = PC.player_instance.get_tree()
	if tree == null or tree.current_scene == null:
		return
	var player_pos = PC.player_instance.global_position
	var nearest_enemy = _find_nearest_heal_bullet_target(tree, player_pos)
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
	
	# Tier 16: 弹体伤害*150%
	if PC.faze_heal_level >= 16:
		final_damage *= 1.5
		
	# Tier 22: 弹体伤害累计*600%（替换16阶的*150%为*600%）
	if PC.faze_heal_level >= 22:
		final_damage *= 4.0 # 16阶*1.5 -> 替换为*6.0，所以*4.0
		
	var is_crit = false
	if PC.faze_heal_level >= 22:
		if randf() < PC.crit_chance:
			is_crit = true
			final_damage *= PC.crit_damage_multi

	SEManager.play("36")
	var bullet = faze_heal_bullet_scene.instantiate()
	tree.current_scene.add_child(bullet)
	bullet.global_position = player_pos
	bullet.setup(nearest_enemy, final_damage, is_crit)

func _find_nearest_heal_bullet_target(tree: SceneTree, from_position: Vector2) -> Node2D:
	var targets: Array = []
	targets.append_array(tree.get_nodes_in_group("enemies"))
	targets.append_array(tree.get_nodes_in_group("boss"))
	var checked := {}
	var nearest_target: Node2D = null
	var min_dist = INF

	for candidate in targets:
		if not _is_valid_heal_bullet_target(candidate):
			continue
		var candidate_id = candidate.get_instance_id()
		if checked.has(candidate_id):
			continue
		checked[candidate_id] = true
		var target_node := candidate as Node2D
		var dist = from_position.distance_to(target_node.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest_target = target_node

	return nearest_target

func _is_valid_heal_bullet_target(candidate: Node) -> bool:
	if not is_instance_valid(candidate):
		return false
	if not (candidate is Node2D):
		return false
	if not candidate.has_method("take_damage"):
		return false
	if candidate.get("is_dead") == true:
		return false
	return candidate.is_in_group("enemies") or candidate.is_in_group("boss")

func _trigger_electrified(source: String = "unknown") -> void:
	assert(player != null, "faze.gd: player is null")
	var current_frame := Engine.get_process_frames()
	if _blood_thud_trigger_frame == current_frame:
		return
	_blood_thud_trigger_frame = current_frame
	SEManager.play("34")
	var level = PC.faze_blood_level
	var damage_multiplier = _get_blood_electrified_damage_multiplier(level)
	var elite_bonus = _get_blood_electrified_elite_bonus(level)
	var bleed_chance = _get_blood_bleed_chance(level)
	var range_scale = _get_blood_electrified_range_scale(level)
	var shield_ratio = _get_blood_shield_ratio(level)
	var damage = PC.pc_atk * damage_multiplier
	var shield_amount = int(ceil(float(PC.pc_max_hp) * shield_ratio))
	var thud_instance = null
	if Global.faze_bath_blood_thud_pool:
		thud_instance = Global.faze_bath_blood_thud_pool.acquire(get_tree().current_scene)
	else:
		thud_instance = bath_blood_thud_scene.instantiate()
		get_tree().current_scene.add_child(thud_instance)
	thud_instance.setup_thud(player.global_position, damage, bleed_chance, range_scale, elite_bonus)
	PC.add_shield(shield_amount, 4.0, "faze_bath_blood_thud")

func _get_blood_electrified_damage_multiplier(level: int) -> float:
	if level >= 29:
		return 8.0
	if level >= 22:
		return 4.0
	if level >= 9:
		return 2.0
	return 1.0

func _get_blood_electrified_elite_bonus(level: int) -> float:
	if level >= 29:
		return 16.0
	if level >= 9:
		return 2.0
	return 0.0

func _get_blood_bleed_chance(level: int) -> float:
	if level >= 16:
		return 1.0
	return 0.0

func _get_blood_electrified_range_scale(level: int) -> float:
	if level >= 22:
		return 4.5 # 范围提升350%
	if level >= 16:
		return 2.0 # 范围提升100%
	if level >= 4:
		return 1.35 # 基础 +35%
	return 1.0

func _get_blood_shield_ratio(level: int) -> float:
	if level >= 29:
		return 0.10
	if level >= 9:
		return 0.03
	return 0.025

func _update_blood_debuff_bonus() -> void:
	var level = PC.faze_blood_level
	if level == last_blood_level:
		return
	last_blood_level = level
	var bleed_elite_bonus = 0.0
	if level >= 29:
		bleed_elite_bonus = 16.0
	elif level >= 16:
		bleed_elite_bonus = 5.0
	EnemyDebuffManager.set_debuff_elite_boss_bonus("bleed", bleed_elite_bonus)

func _update_blood_independent_damage_reduction() -> void:
	const SOURCE_ID := "faze_blood_missing_hp"
	var multiplier := get_blood_missing_hp_independent_damage_multiplier()
	if is_equal_approx(multiplier, _last_blood_independent_dr_multiplier):
		return
	_last_blood_independent_dr_multiplier = multiplier
	if multiplier >= 0.999:
		PC.remove_independent_damage_reduction_source(SOURCE_ID)
	else:
		PC.add_independent_damage_reduction_source(SOURCE_ID, multiplier)

static func get_blood_missing_hp_independent_damage_reduction_per_step(level: int) -> float:
	if level >= 29:
		return 0.06
	if level >= 22:
		return 0.03
	return 0.0

static func get_blood_missing_hp_independent_damage_multiplier() -> float:
	var per_step := get_blood_missing_hp_independent_damage_reduction_per_step(PC.faze_blood_level)
	if per_step <= 0.0 or PC.pc_max_hp <= 0:
		return 1.0
	var hp_ratio := clampf(float(PC.pc_hp) / float(PC.pc_max_hp), 0.0, 1.0)
	var missing_steps := int(floor((1.0 - hp_ratio) / 0.10))
	var reduction := clampf(float(missing_steps) * per_step, 0.0, 0.95)
	return 1.0 - reduction

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
	
	# 4阶：召唤物伤害与治疗+25%，触发间隔-10%
	if level >= 4:
		PC.faze_summon_damage_bonus += 0.25
		PC.faze_summon_interval_reduction += 0.1
		
	# 9阶：最大召唤物容量+1，召唤物弹体大小+25%
	if level >= 9:
		PC.faze_summon_extra_capacity += 1
		PC.faze_summon_bullet_size_bonus += 0.25
	# 16阶：召唤1个不占容量的双极魔剑，召唤物伤害与治疗+50%
	if level >= 16:
		PC.faze_summon_damage_bonus += 0.50
	# 29阶：召唤1个不占容量的陨灭剑灵，召唤物伤害与治疗+100%，触发间隔-30%
	if level >= 29:
		PC.faze_summon_damage_bonus += 1.0
		PC.faze_summon_interval_reduction += 0.3
	_update_summon_bonus_implementation()

var _last_applied_summon_damage: float = 0.0
var _last_applied_summon_interval: float = 0.0
var _last_applied_summon_cap: int = 0
var _last_applied_summon_size: float = 0.0
var _last_applied_summon_atk_bonus: int = 0
var _last_applied_summon_atk_speed_bonus: float = 0.0

func _update_summon_bonus_implementation() -> void:
	var level = PC.faze_summon_level
	
	var damage_bonus = 0.0
	var interval_reduction = 0.0
	var extra_cap = 0
	var size_bonus = 0.0
	
	if level >= 4:
		damage_bonus += 0.25
		interval_reduction += 0.1
	if level >= 9:
		extra_cap += 1
		size_bonus += 0.25
	if level >= 16:
		damage_bonus += 0.50
	if level >= 29:
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
	
	# Summon special units (法则专属，不占召唤物容量)
	# 使用 PC 标志位 + 场景检测双重判断：
	# - 标志位为 false：首次需要生成
	# - 标志位为 true 但场景中不存在：召唤物被销毁，需要重新生成
	if level >= 16:
		if not PC.has_summoned_bipolar_sword or not _has_special_summon(3):
			if PC.has_summoned_bipolar_sword:
				# 召唤物丢失，重新生成
				print("[御灵法则] 双极魔剑丢失，重新召唤")
			_summon_bipolar_sword()
			PC.has_summoned_bipolar_sword = true
	if level >= 29:
		if not PC.has_summoned_sword_spirit or not _has_special_summon(10):
			if PC.has_summoned_sword_spirit:
				print("[御灵法则] 陨灭剑灵丢失，重新召唤")
			_summon_sword_spirit()
			PC.has_summoned_sword_spirit = true
	
	# 22阶：每个召唤物使角色攻击力+10%，攻速+10%（动态更新）
	_update_summon_count_bonus()

func _summon_bipolar_sword() -> void:
	_spawn_special_summon(3) # 3 is GOLD_ENHANCED (based on enum in summon.gd: BLUE_RANDOM=0... GOLD_ENHANCED=3)

func _summon_sword_spirit() -> void:
	# SummonType.SWORD_SPIRIT (10)
	_spawn_special_summon(10)

func _spawn_special_summon(type_int: int) -> void:
	SEManager.play("33")
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

# 22阶：每个召唤物使角色攻击力+10%，攻速+10%（动态，随召唤物数量变化）
func _update_summon_count_bonus() -> void:
	var level = PC.faze_summon_level
	var count = PC.summon_count
	
	var target_atk_bonus = 0
	var target_atk_speed_bonus = 0.0
	
	if level >= 22:
		target_atk_bonus = int(count * PC.base_atk * 0.10)
		target_atk_speed_bonus = float(count) * 0.10
	
	# 应用攻击力差值
	var delta_atk = target_atk_bonus - _last_applied_summon_atk_bonus
	PC.pc_atk += delta_atk
	_last_applied_summon_atk_bonus = target_atk_bonus
	
	# 应用攻速差值
	var delta_atk_speed = target_atk_speed_bonus - _last_applied_summon_atk_speed_bonus
	PC.attack_speed_bonus += delta_atk_speed
	_last_applied_summon_atk_speed_bonus = target_atk_speed_bonus

var _last_applied_shield_hp_bonus: float = 0.0
var _last_applied_shield_gain_bonus: float = 0.0
var _last_applied_damage_reduction: float = 0.0

func _update_shield_law_bonus() -> void:
	var level = PC.faze_shield_level
	if level == last_shield_level:
		# Check dynamic damage reduction based on current shield
		if level >= 11:
			_update_shield_dynamic_dr()
		return
	last_shield_level = level
	
	var hp_bonus = 0.0
	var gain_bonus = 0.0
	var heal_conversion = 0.0
	
	# 4阶：护盾获取加成提升20%，最大体力提升10%
	if level >= 4:
		gain_bonus += 0.20
		hp_bonus += 0.10
		
	# 7阶：最大体力再次提升25%，护盾因时间结束消失后，其30%会转为生命回复
	if level >= 7:
		hp_bonus += 0.25
		heal_conversion = 0.30
			
	# 11阶：最大体力再次提升35%，每存在相当于最大体力3%的护盾，获得额外 1%的减伤率，最高20%
	if level >= 11:
		hp_bonus += 0.35
		
	# 15阶：护盾获取加成再次提升50%，护盾因时间结束消失后，其60%会转为生命回复
	if level >= 15:
		gain_bonus += 0.50
		heal_conversion = 0.60
		
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
	if level >= 11:
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
		PC.move_speed_bonus += base_move_bonus - last_wind_base_move_speed_bonus
		last_wind_base_move_speed_bonus = base_move_bonus
	# 9阶：啸风类攻击速度+30%；16阶：再次+40%
	var base_atk_speed_bonus = Faze.get_wind_base_atk_speed_bonus(level)
	if base_atk_speed_bonus != last_wind_base_atk_speed_bonus:
		PC.attack_speed_bonus += base_atk_speed_bonus - last_wind_base_atk_speed_bonus
		last_wind_base_atk_speed_bonus = base_atk_speed_bonus
	var max_stacks = Faze.get_wind_huanfeng_max_stacks(level)
	PC.wind_huanfeng_max_stacks = max_stacks
	last_wind_level = level
	if max_stacks > 0 and wind_huanfeng_expiries.size() > max_stacks:
		wind_huanfeng_expiries.sort()
		while wind_huanfeng_expiries.size() > max_stacks:
			wind_huanfeng_expiries.pop_front()
	if level < 9:
		_clear_wind_huanfeng()

func _add_wind_huanfeng_stack(hit_target: Node = null) -> void:
	if PC.faze_wind_level < 9:
		return
	var max_stacks = Faze.get_wind_huanfeng_max_stacks(PC.faze_wind_level)
	if max_stacks <= 0:
		return
	var now = Time.get_ticks_msec() / 1000.0
	var gain_count: int = 1
	if PC.faze_wind_level >= 22 and hit_target != null and is_instance_valid(hit_target) and hit_target.is_in_group("boss"):
		gain_count += 2
	for _i in range(gain_count):
		if wind_huanfeng_expiries.size() >= max_stacks:
			wind_huanfeng_expiries.sort()
			wind_huanfeng_expiries.pop_front()
		wind_huanfeng_expiries.append(now + PC.wind_huanfeng_duration)
	_update_wind_huanfeng()

func _update_wind_huanfeng() -> void:
	if PC.faze_wind_level < 9:
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
	PC.attack_speed_bonus += delta_atk
	last_wind_stack_atk_speed_bonus = target_bonus
	var delta_move = target_bonus - last_wind_stack_move_speed_bonus
	PC.move_speed_bonus += delta_move
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
		PC.attack_speed_bonus -= last_wind_stack_atk_speed_bonus
		last_wind_stack_atk_speed_bonus = 0.0
	if last_wind_stack_move_speed_bonus != 0.0:
		PC.move_speed_bonus -= last_wind_stack_move_speed_bonus
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
	var target_global_attack_range_bonus := 0.0
	
	# 4阶：广域类武器伤害及伤害范围提升15%
	if level >= 4:
		PC.faze_wide_range_bonus += 0.15
		PC.faze_wide_damage_bonus += 0.15
	
	# 9阶：角色的伤害范围提升15%，并且广域类武器的伤害范围加成每提高1%，伤害提高1%
	if level >= 9:
		target_global_attack_range_bonus += 0.15
		PC.faze_wide_range_to_damage_ratio = 1.0
	
	# 16阶：广域类武器的伤害提升45%，广域类武器伤害范围提升20%
	if level >= 16:
		PC.faze_wide_damage_bonus += 0.45
		PC.faze_wide_range_bonus += 0.20
	
	# 22阶：角色的伤害范围提升25%，广域类武器的范围加成每提高1%，伤害提升量由1%提升到2%
	if level >= 22:
		target_global_attack_range_bonus += 0.25
		PC.faze_wide_range_to_damage_ratio = 2.0
	
	# 29阶：广域类武器伤害及伤害范围再次提升65%
	if level >= 29:
		PC.faze_wide_range_bonus += 0.65
		PC.faze_wide_damage_bonus += 0.65

	var attack_range_delta := target_global_attack_range_bonus - PC.faze_wide_global_attack_range_bonus
	if not is_equal_approx(attack_range_delta, 0.0):
		PC.add_attack_range(attack_range_delta)
	PC.faze_wide_global_attack_range_bonus = target_global_attack_range_bonus

func _update_bagua_bonus() -> void:
	var level = PC.faze_bagua_level
	if level == last_bagua_level:
		return
	last_bagua_level = level
	
	PC.faze_bagua_damage_bonus = 0.0
	PC.faze_bagua_gain_multiplier = 1.0
	
	# 4阶：基础推衍系统开启（具体逻辑在add_bagua_progress中）
	
	# 11阶：推衍度获得*2，八卦类武器伤害提升10%
	if level >= 11:
		PC.faze_bagua_gain_multiplier *= 2.0
		PC.faze_bagua_damage_bonus += 0.10
		
	# 18阶：推衍度获得提升至3倍，八卦类武器伤害再次提升20%
	if level >= 18:
		PC.faze_bagua_gain_multiplier *= 1.5 # Total 3x (2 * 1.5)
		PC.faze_bagua_damage_bonus += 0.20
		
	# 25阶：推衍度获得提升至5倍，八卦类武器伤害再次提升30%
	if level >= 25:
		PC.faze_bagua_gain_multiplier *= (5.0 / 3.0) # Total 5x
		PC.faze_bagua_damage_bonus += 0.30
		
	# 33阶：推衍度获得提升至10倍，八卦类武器伤害再次提升45%
	if level >= 33:
		PC.faze_bagua_gain_multiplier *= (10.0 / 5.0) # Total 10x
		PC.faze_bagua_damage_bonus += 0.45

# 增加八卦推衍度
static func add_bagua_progress(amount: int, target_multiplier: int = 1) -> void:
	if PC.faze_bagua_level < 4:
		return
		
	var final_amount = amount * maxi(1, target_multiplier)
		
	final_amount = int(final_amount * PC.faze_bagua_gain_multiplier)
	
	PC.faze_bagua_progress += final_amount
	
	# 检查是否升级
	while PC.faze_bagua_progress >= PC.faze_bagua_next_threshold:
		PC.faze_bagua_progress -= PC.faze_bagua_next_threshold
		PC.faze_bagua_completed_layers += 1
		PC.faze_bagua_next_threshold += 10
		PC.exp_multi += 0.03
		SEManager.play("38")
		
	# 更新Buff显示
	_update_bagua_buff_display()

static func add_bagua_hit_progress(target: Node, was_alive_before_hit: bool, hit_amount: int = 1, kill_amount: int = 5) -> void:
	if not was_alive_before_hit:
		return
	if not is_instance_valid(target):
		return
	var target_multiplier := 1
	if target.is_in_group("boss"):
		target_multiplier = 5
	elif target.is_in_group("elite"):
		target_multiplier = 2
	if _can_add_bagua_hit_progress(target):
		add_bagua_progress(hit_amount, target_multiplier)
	if target.get("hp") <= 0:
		if target.has_meta("bagua_kill_progress_rewarded"):
			return
		target.set_meta("bagua_kill_progress_rewarded", true)
		add_bagua_progress(kill_amount, target_multiplier)

static func _can_add_bagua_hit_progress(target: Node) -> bool:
	var now_msec: int = Time.get_ticks_msec()
	_cleanup_bagua_hit_progress_records(now_msec)
	var target_id: int = target.get_instance_id()
	var last_msec: int = int(_bagua_hit_progress_msec_by_target.get(target_id, -BAGUA_HIT_PROGRESS_TARGET_COOLDOWN_MSEC))
	if now_msec - last_msec < BAGUA_HIT_PROGRESS_TARGET_COOLDOWN_MSEC:
		return false
	_bagua_hit_progress_msec_by_target[target_id] = now_msec
	return true

static func _cleanup_bagua_hit_progress_records(now_msec: int) -> void:
	if now_msec - _bagua_hit_progress_last_cleanup_msec < BAGUA_HIT_PROGRESS_RECORD_TTL_MSEC:
		return
	_bagua_hit_progress_last_cleanup_msec = now_msec
	for target_id in _bagua_hit_progress_msec_by_target.keys():
		var last_msec: int = int(_bagua_hit_progress_msec_by_target[target_id])
		if now_msec - last_msec >= BAGUA_HIT_PROGRESS_RECORD_TTL_MSEC:
			_bagua_hit_progress_msec_by_target.erase(target_id)

static func _reset_bagua_hit_progress_records() -> void:
	_bagua_hit_progress_msec_by_target.clear()
	_bagua_hit_progress_last_cleanup_msec = Time.get_ticks_msec()

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

static func on_wind_weapon_hit(hit_target: Node = null) -> void:
	if manager_instance:
		manager_instance._add_wind_huanfeng_stack(hit_target)

static func get_bagua_damage_multiplier() -> float:
	return 1.0 + get_bagua_weapon_damage_bonus()

static func get_bagua_weapon_damage_bonus() -> float:
	return PC.faze_bagua_damage_bonus + float(PC.faze_bagua_completed_layers) * 0.01

static func get_wide_damage_multiplier(base_range_bonus: float) -> float:
	# 基础伤害加成
	var multiplier = 1.0 + PC.faze_wide_damage_bonus
	
	# 范围转伤害
	# 总范围加成 = 基础范围加成 + 法则范围加成
	var total_range_bonus = base_range_bonus + PC.faze_wide_range_bonus
	
	# 转化率 (1%范围 -> 1%或2%伤害)
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
	if level >= 29:
		bonus += 1.0
	return 1.0 + bonus

static func get_destroy_crit_chance_bonus(level: int) -> float:
	var bonus = 0.0
	if level >= 4:
		bonus += 0.15
	if level >= 22:
		bonus += 0.25
	return bonus

static func get_destroy_crit_damage_bonus(level: int) -> float:
	return 0.0

static func get_destroy_crit_fluctuation_multiplier(level: int) -> float:
	if level >= 22:
		return randf_range(0.6, 2.2) # -40% ~ +120%
	if level >= 16:
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

# ============ 破坏法则 - 引爆 ============

static func get_destroy_detonation_chance(level: int) -> float:
	if level >= 22:
		return 0.16
	if level >= 16:
		return 0.12
	if level >= 9:
		return 0.09
	return 0.0

static func get_destroy_detonation_damage_multiplier(level: int) -> float:
	# 9阶：75%攻击，16阶：160%攻击，29阶：800%攻击
	if level >= 29:
		return 8.0
	if level >= 16:
		return 1.6
	if level >= 9:
		return 0.75
	return 0.0

# 破坏类武器击中敌人时调用
static func on_destroy_weapon_hit(enemy: Node, is_crit: bool, is_kill: bool = false) -> void:
	if PC.faze_destroy_level < 9:
		return
	if not is_instance_valid(enemy):
		return
	
	# 只有暴击或击杀时才可能触发引爆
	if not is_crit and not is_kill:
		return
	
	var chance = get_destroy_detonation_chance(PC.faze_destroy_level)
	if randf() >= chance:
		return
	
	_trigger_destory_detonation(enemy.global_position)

static func _trigger_destory_detonation(target_pos: Vector2) -> void:
	if not manager_instance:
		return
	SEManager.play("31")
	var level = PC.faze_destroy_level
	var damage = PC.pc_atk * get_destroy_detonation_damage_multiplier(level)
	
	var detonation = Global.faze_destory_pool.acquire(manager_instance.get_tree().current_scene)
	detonation.setup_detonation(target_pos, damage, true, level)

static func get_life_damage_multiplier(level: int) -> float:
	var bonus = 0.0
	if level >= 4:
		bonus += 0.25 # 4阶：+25%
	# 9阶、16阶无武器伤害加成
	if level >= 22:
		bonus += 0.60 # 22阶：再次+60%
	if level >= 29:
		bonus += 1.20 # 29阶：再次+120%
	return 1.0 + bonus

static func get_life_range_multiplier(level: int) -> float:
	return 1.0

static func get_life_exp_multiplier(level: int) -> float:
	# 4阶：+20%（16阶：+75%，22阶：+120%，29阶：+120%保持）
	if level >= 22:
		return 2.2
	if level >= 16:
		return 1.75
	if level >= 4:
		return 1.2
	return 1.0

static func get_exp_multiplier() -> float:
	var multiplier = Global.get_effective_exp_multiplier()
	multiplier = multiplier * get_life_exp_multiplier(PC.faze_life_level)
	multiplier = multiplier * get_chaos_exp_multiplier(get_current_chaos_level())
	return multiplier

static func get_life_attack_interval_multiplier(level: int) -> float:
	return 1.0

static func get_fire_weapon_damage_multiplier(level: int) -> float:
	var bonus = 0.0
	if level >= 4:
		bonus += 0.3
	if level >= 16:
		bonus += 0.6
	if level >= 29:
		bonus += 1.2
	return 1.0 + bonus

static func get_burn_damage_multiplier(level: int) -> float:
	var bonus = 0.0
	if level >= 4:
		bonus += 0.5
	if level >= 9:
		bonus += 0.5
	if level >= 22:
		bonus += 1.2
	if level >= 29:
		bonus += 1.2
	return 1.0 + bonus

static func get_burn_range_multiplier(level: int) -> float:
	var bonus = 0.0
	if level >= 9:
		bonus += 0.5
	if level >= 22:
		bonus += 0.5
	return 1.0 + bonus

static func get_fire_elite_boss_multiplier(level: int) -> float:
	# 16阶：燃烧效果对精英、首领造成5倍伤害
	# 22阶：燃烧效果对精英、首领造成10倍伤害
	# 29阶：燃烧效果对精英、首领造成20倍伤害
	if level >= 29:
		return 20.0
	if level >= 22:
		return 10.0
	if level >= 16:
		return 5.0
	return 1.0

static func get_burn_duration_bonus(level: int) -> float:
	# 9阶：燃烧持续时间 +1 秒
	if level >= 9:
		return 1.0
	return 0.0

static func get_treasure_lucky_bonus(level: int) -> int:
	var bonus = 0
	if level >= 4:
		bonus += 4
	if level >= 9:
		bonus += 6
	if level >= 16:
		bonus += 9
	if level >= 22:
		bonus += 14
	if level >= 29:
		bonus += 20
	return bonus

static func get_treasure_weapon_damage_multiplier(level: int, lucky: int) -> float:
	var bonus = 0.0
	if level >= 4:
		bonus += 0.15
	if level >= 9:
		bonus += float(lucky) * 0.02
	if level >= 22:
		bonus += 0.35
	if level >= 29:
		bonus += 1.0
	return 1.0 + bonus

static func get_treasure_elite_boss_multiplier(level: int, lucky: int) -> float:
	if level < 29:
		return 1.0
	return 1.0 + float(lucky) * 0.06

static func get_treasure_extra_refresh_count(level: int, player_level: int) -> int:
	if level >= 22:
		return 1
	if level >= 9 and player_level % 2 == 0:
		return 1
	return 0

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
	if level >= 16:
		bonus += 0.50
	if level >= 22:
		bonus += 0.75
	if level >= 29:
		bonus += 1.10
	if level >= 16:
		bonus += float(PC.wind_huanfeng_stacks) * 0.002
	return 1.0 + bonus

static func get_wind_base_move_speed_bonus(level: int) -> float:
	var bonus = 0.0
	if level >= 4:
		bonus += 0.10
	return bonus

static func get_wind_base_atk_speed_bonus(level: int) -> float:
	var bonus = 0.0
	if level >= 9:
		bonus += 0.30
	if level >= 16:
		bonus += 0.40
	return bonus

static func get_wind_huanfeng_max_stacks(level: int) -> int:
	if level >= 22:
		return 300
	if level >= 9:
		return 200
	return 0

static func get_wind_huanfeng_speed_bonus_per_stack(level: int) -> float:
	if level >= 9:
		return 0.0015
	return 0.0

static func get_wind_elite_boss_multiplier(level: int, stacks: int) -> float:
	if level < 29:
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
	return 1.0 + get_chaos_final_damage_bonus(level)

static func get_chaos_final_damage_bonus(level: int) -> float:
	var bonus = 0.0
	if level >= 3:
		bonus += 0.15
	if level >= 5:
		bonus += 0.30
	if level >= 8:
		bonus += 0.60
	if level >= 11:
		bonus += 1.20
	return bonus

static func get_chaos_exp_multiplier(level: int) -> float:
	var bonus = 0.0
	if level >= 3:
		bonus += 0.15
	if level >= 5:
		bonus += 0.30
	if level >= 8:
		bonus += 0.60
	if level >= 11:
		bonus += 1.20
	return 1.0 + bonus

static func get_chaos_point_multiplier(level: int) -> float:
	var bonus = 0.0
	if level >= 3:
		bonus += 0.15
	if level >= 5:
		bonus += 0.25
	if level >= 8:
		bonus += 0.40
	if level >= 11:
		bonus += 0.80
	return 1.0 + bonus

static func get_final_damage_additive_bonus() -> float:
	var additive_bonus := PC.final_damage_bonus
	additive_bonus += get_chaos_final_damage_bonus(get_current_chaos_level())
	additive_bonus += Global.study_final_damage_bonus
	additive_bonus += Global.get_poetry_player_final_damage_multiplier() - 1.0
	return additive_bonus

static func get_final_damage_multiplier() -> float:
	return maxf(0.0, 1.0 + get_final_damage_additive_bonus()) * Global.get_stage_boss_player_damage_multiplier()

static func get_point_multiplier() -> float:
	return max(0.0, 1.0 + PC.point_multi) * get_chaos_point_multiplier(get_current_chaos_level())

static func get_current_chaos_level() -> int:
	var chaos_level := _calculate_chaos_level()
	PC.faze_chaos_level = chaos_level
	return chaos_level

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
		PC.faze_deep_level,
		PC.faze_skill_level,
		PC.faze_sixsense_level,
		PC.faze_wind_level,
	]
	var chaos_level = 0
	for level in levels:
		if level >= 6:
			chaos_level += 1
		if level >= 10:
			chaos_level += 1
	if chaos_level < 0:
		chaos_level = 0
	return chaos_level

func _update_treasure_bonus() -> void:
	var bonus = Faze.get_treasure_lucky_bonus(PC.faze_treasure_level)
	var level = PC.faze_treasure_level
	
	# 16阶：宝器类武器攻击速度+25%
	var atk_speed_bonus = 0.25 if level >= 16 else 0.0
	if atk_speed_bonus != last_treasure_atk_speed_bonus:
		PC.attack_speed_bonus += atk_speed_bonus - last_treasure_atk_speed_bonus
		last_treasure_atk_speed_bonus = atk_speed_bonus
	
	if bonus == last_treasure_lucky_bonus:
		return
	var delta = bonus - last_treasure_lucky_bonus
	last_treasure_lucky_bonus = bonus
	PC.now_lunky_level += delta
	PC._recalculate_reward_rarity_chances()
	Global.emit_signal("lucky_level_up", delta)

static func get_deep_weapon_damage_bonus(level: int) -> float:
	var bonus := 0.0
	if level >= 4:
		bonus += 0.20
	if level >= 16:
		bonus += 0.45
	if level >= 22:
		bonus += 0.60
	if level >= 29:
		bonus += 0.90
	return bonus

static func get_deep_knockback_multiplier(level: int) -> float:
	var multiplier := 1.0
	if level >= 4:
		multiplier += 0.20
	if level >= 16:
		multiplier += 0.25
	if level >= 29:
		multiplier += 0.75
	return multiplier

static func get_deep_displacement_damage_ratio_per_knockback(level: int) -> float:
	if level >= 22:
		return 0.06
	if level >= 9:
		return 0.025
	return 0.0

static func get_deep_boss_displacement_extra_multiplier(level: int) -> float:
	if level >= 29:
		return 10.0
	if level >= 22:
		return 3.0
	if level >= 9:
		return 1.5
	return 0.0

static func apply_deep_displacement_damage(target: Node, base_damage: float, knockback_amount: float, _damage_type: String) -> void:
	if target == null or not is_instance_valid(target):
		return
	if PC.faze_deep_level < 9:
		return
	if not target.has_method("take_damage"):
		return
	var ratio := get_deep_displacement_damage_ratio_per_knockback(PC.faze_deep_level)
	if ratio <= 0.0:
		return
	var extra_damage := base_damage * knockback_amount * ratio
	if target.is_in_group("boss"):
		extra_damage *= 1.0 + get_deep_boss_displacement_extra_multiplier(PC.faze_deep_level)
	if extra_damage <= 0.0:
		return
	target.take_damage(int(round(extra_damage)), false, false, "faze_deep")

func _update_chaos_bonus() -> void:
	Faze.get_current_chaos_level()

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
	PC.final_damage_bonus += delta_final_damage
	PC.sixsense_applied_final_damage = target_final_damage_bonus
	
	var base_atk_speed = PC.sixsense_base_atk_speed
	var target_atk_speed_bonus = base_atk_speed * (multiplier - 1.0)
	var delta_atk_speed = target_atk_speed_bonus - PC.sixsense_applied_atk_speed
	PC.attack_speed_bonus += delta_atk_speed
	PC.sixsense_applied_atk_speed = target_atk_speed_bonus
	
	var base_damage_reduction = PC.sixsense_base_damage_reduction
	var target_damage_reduction_bonus = base_damage_reduction * (multiplier - 1.0)
	var delta_damage_reduction = target_damage_reduction_bonus - PC.sixsense_applied_damage_reduction
	PC.damage_reduction_rate += delta_damage_reduction
	PC.sixsense_applied_damage_reduction = target_damage_reduction_bonus
	
	var base_atk = PC.sixsense_base_atk
	var target_atk_bonus = base_atk * PC.base_atk * (multiplier - 1.0)
	var delta_atk = target_atk_bonus - PC.sixsense_applied_atk
	PC.pc_atk += int(round(delta_atk))
	PC.sixsense_applied_atk = target_atk_bonus

static func get_bullet_damage_multiplier(level: int) -> float:
	var bonus = 0.0
	if level >= 4:
		bonus += 0.12
	if level >= 18:
		bonus += 0.38
	if level >= 24:
		bonus += 0.60
	if level >= 31:
		bonus += 0.90
	return 1.0 + bonus

static func get_bullet_range_multiplier(level: int) -> float:
	var bonus = 0.0
	if level >= 4:
		bonus += 0.20
	if level >= 18:
		bonus += 0.30
	return 1.0 + bonus

static func get_sword_attack_speed_multiplier(level: int) -> float:
	var bonus = 0.0
	if level >= 4:
		bonus += 0.2
	if level >= 16:
		bonus += 0.3
	if level >= 29:
		bonus += 0.6
	return 1.0 + bonus

static func get_sword_crit_damage_multiplier(level: int) -> float:
	var bonus = 0.0
	if level >= 4:
		bonus += 0.1
	if level >= 16:
		bonus += 0.3
	return PC.crit_damage_multi + bonus

static func get_coldlight_damage_multiplier(level: int) -> float:
	if level >= 29:
		return 3.0
	if level >= 9:
		return 1.44
	return 0.0

static func on_sword_weapon_hit(enemy: Node) -> void:
	if PC.faze_sword_level < 9:
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
	
	if stack >= 3:
		SEManager.play("35")
		var damage_multiplier = get_coldlight_damage_multiplier(PC.faze_sword_level)
		var damage = PC.pc_atk * damage_multiplier
		var is_crit = false
		if PC.faze_sword_level >= 22:
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
	if PC.faze_bullet_level < 11:
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
	if barrage_running:
		return
	barrage_running = true
	var level: int = PC.faze_bullet_level
	var wave_count: int = _get_barrage_wave_count(level)
	var damage_multiplier: float = _get_barrage_damage_multiplier(level)
	var damage: float = PC.pc_atk * damage_multiplier
	var tree := PC.player_instance.get_tree()
	if tree != null:
		await _wait_until_battle_running(tree)
	if not PC.is_game_over and is_instance_valid(PC.player_instance):
		await _spawn_barrage_waves(damage, barrage_offset_angle, wave_count)
		barrage_offset_angle = fmod(barrage_offset_angle + BARRAGE_TRIGGER_ANGLE_OFFSET_STEP, 360.0)
	barrage_running = false
	if bullet_hit_count >= 100:
		bullet_hit_count -= 100
		_sync_barrage_charge_buff()
		_start_barrage()

func _spawn_barrage_waves(damage: float, angle_offset: float, wave_count: int) -> void:
	if not is_instance_valid(PC.player_instance):
		return
	var tree := PC.player_instance.get_tree()
	if tree == null:
		return
	var resolved_wave_count: int = maxi(1, wave_count)
	var wave_angle_step: float = 360.0 / float(BARRAGE_BULLETS_PER_WAVE * resolved_wave_count)
	for wave_index in range(resolved_wave_count):
		await _wait_until_battle_running(tree)
		if PC.is_game_over or not is_instance_valid(PC.player_instance):
			return
		var origin: Vector2 = PC.player_instance.global_position
		var current_angle_offset: float = angle_offset + float(wave_index) * wave_angle_step
		_spawn_barrage_wave(origin, damage, current_angle_offset, BARRAGE_BULLETS_PER_WAVE)
		if wave_index < resolved_wave_count - 1:
			await tree.create_timer(BARRAGE_WAVE_INTERVAL).timeout

func _spawn_barrage_wave(origin: Vector2, damage: float, angle_offset: float, bullet_count: int = BARRAGE_BULLETS_PER_WAVE) -> void:
	if not is_instance_valid(PC.player_instance):
		return
	var tree := PC.player_instance.get_tree()
	if tree == null:
		return
	var scene = tree.current_scene
	if scene == null:
		return
	var wave_hit_counts := {}
	for i in range(bullet_count):
		if PC.is_game_over or not is_instance_valid(PC.player_instance):
			return
		if scene == null or not is_instance_valid(scene):
			return
		var angle_deg = angle_offset + float(i) * 360.0 / float(maxi(1, bullet_count))
		var dir = Vector2.RIGHT.rotated(deg_to_rad(angle_deg))
		var bullet = Global.rain_bullet_pool.acquire(scene)
		bullet.setup_barrage_bullet(origin, dir, damage, {
			"shared_wave_hit_counts": wave_hit_counts,
			"shared_wave_hit_limit": 3
		})

func _wait_until_battle_running(tree: SceneTree) -> void:
	while tree != null and (tree.paused or Global.is_level_up) and not PC.is_game_over:
		await tree.create_timer(0.05, true, false, true).timeout

static func _get_barrage_total_bullets(level: int) -> int:
	return BARRAGE_BULLETS_PER_WAVE * _get_barrage_wave_count(level)

static func _get_barrage_wave_count(level: int) -> int:
	if level >= 31:
		return 6
	if level >= 24:
		return 4
	if level >= 18:
		return 3
	return 2

static func _get_barrage_damage_multiplier(level: int) -> float:
	if level >= 31:
		return 4.0
	if level >= 24:
		return 1.2
	if level >= 18:
		return 0.75
	return 0.45

static func get_barrage_debug_stats() -> Dictionary:
	return {
		"running": barrage_running,
		"charge": bullet_hit_count,
		"waves": _get_barrage_wave_count(PC.faze_bullet_level),
		"bullets_per_wave": BARRAGE_BULLETS_PER_WAVE,
		"total_bullets": _get_barrage_total_bullets(PC.faze_bullet_level),
		"per_frame": BARRAGE_BULLETS_PER_FRAME,
		"active_cap": BARRAGE_ACTIVE_SOFT_CAP,
	}

static func _sync_barrage_charge_buff() -> void:
	if PC.faze_bullet_level < 11:
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
	if level >= 22:
		bonus += 1.2
	return 1.0 + bonus

static func get_thunder_electrified_damage_multiplier(level: int) -> float:
	var bonus = 0.0
	if level >= 4:
		bonus += 0.4
	return 1.0 + bonus

static func get_thunder_damage_vs_electrified_bonus(level: int) -> float:
	return 0.0

static func get_thunder_electrified_elite_bonus(level: int) -> float:
	return 0.0

static func get_heal_shield_bonus(level: int) -> float:
	var bonus = 0.0
	if level >= 4:
		bonus += 0.20
	if level >= 9:
		bonus += 0.10
	if level >= 16:
		bonus += 0.25
	if level >= 22:
		bonus += 0.30
	return bonus

# ============ 鸣雷法则 - 鸣雷劈向目标 ============

static func get_thunder_strike_trigger_chance(level: int) -> float:
	# 9阶：5%，16阶：15%，22阶：35%
	if level >= 22:
		return 0.35
	if level >= 16:
		return 0.15
	if level >= 9:
		return 0.05
	return 0.0

static func get_thunder_strike_base_damage(level: int) -> float:
	# 9阶：70%攻击，16阶：150%攻击
	var base = 0.70
	if level >= 16:
		base = 1.50
	return base

static func get_thunder_strike_elite_bonus(level: int) -> float:
	# 16阶：额外400%，22阶：额外900%
	if level >= 22:
		return 9.0
	if level >= 16:
		return 4.0
	return 0.0

# 鸣雷系武器击中敌人时调用
static func on_thunder_weapon_hit(enemy: Node) -> void:
	if PC.faze_thunder_level < 9:
		return
	if not is_instance_valid(enemy):
		return
	
	var chance = get_thunder_strike_trigger_chance(PC.faze_thunder_level)
	if randf() >= chance:
		return
	
	_trigger_thunder_strike(enemy.global_position, enemy)

# 感电触发时调用
static func on_electrified_trigger(enemy: Node) -> void:
	if PC.faze_thunder_level < 9:
		return
	if not is_instance_valid(enemy):
		return
	
	var chance = get_thunder_strike_trigger_chance(PC.faze_thunder_level)
	if randf() >= chance:
		return
	
	_trigger_thunder_strike(enemy.global_position, enemy)

static func _trigger_thunder_strike(target_pos: Vector2, target_enemy: Node) -> void:
	if not manager_instance:
		return
	SEManager.play("30")
	var level = PC.faze_thunder_level
	var base_damage = PC.pc_atk * get_thunder_strike_base_damage(level)
	var elite_bonus = get_thunder_strike_elite_bonus(level)
	
	# 从对象池获取鸣雷实例
	var thunder = Global.faze_thunder_pool.acquire(manager_instance.get_tree().current_scene)
	thunder.setup_thunder_strike(target_pos, base_damage, elite_bonus)
