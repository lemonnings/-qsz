extends Area2D

# 召唤物类型枚举
enum SummonType {
	BLUE_RANDOM,     # 蓝色：随机方向射击
	PURPLE_DIRECTED, # 紫色：定向射击（角色上下30px）
	ORANGE_TRACKING, # 橙色：追踪射击
	GOLD_ENHANCED,    # 金色：强化追踪射击
	HEAL_PURPLE, # 治疗-紫色
	HEAL_GOLD, # 治疗-金色
	HEAL_RED, # 治疗-红色
	AUX_PURPLE, # 辅助-紫色
	AUX_GOLD, # 辅助-金色
	AUX_RED # 辅助-红色
}

@export var summon_type: SummonType
@export var bullet_scene: PackedScene
@export var damage_multiplier: float = 1  # 基础伤害倍数
@export var fire_interval: float = 1     # 发射间隔
@export var bullet_speed_multiplier: float = 1.0  # 子弹速度倍数
@export var bullets_per_shot: int = 1      # 每次发射子弹数量

# 辅助/治疗相关的临时加成记录，便于召唤物移除时回退
var applied_atk_bonus: int = 0
var applied_speed_bonus: float = 0.0
var applied_summon_enhance_bonus: float = 0.0
var applied_damage_reduction_bonus: float = 0.0
var heal_ratio: float = 0.0

var last_shot_time: float = 0.0
var player_node: Node2D
var enemies_in_scene: Array = []

var move_target_position: Vector2
var move_timer: float = 0.0
const MOVE_INTERVAL: float = 0.8 # 每0.5秒更新一次目标位置

@export var sprite: Sprite2D
@export var fire_timer: Timer

func _ready() -> void:
	# 获取玩家节点引用
	player_node = get_tree().current_scene.get_node("Player")
	
	# 设置发射定时器
	fire_timer.wait_time = fire_interval * PC.summon_interval_multiplier
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	fire_timer.start()

func setup_appearance() -> void:
	# 根据召唤物类型设置不同的外观
	match summon_type:
		SummonType.BLUE_RANDOM:
			sprite.modulate = Color.BLUE
		SummonType.PURPLE_DIRECTED:
			sprite.modulate = Color.PURPLE
			#sprite.scale = Vector2(1.1, 1.1)
		SummonType.ORANGE_TRACKING:
			sprite.modulate = Color.ORANGE
			#sprite.scale = Vector2(1.2, 1.2)
		SummonType.GOLD_ENHANCED:
			sprite.modulate = Color.GOLD
			#sprite.scale = Vector2(1.3, 1.3)
		SummonType.HEAL_PURPLE, SummonType.AUX_PURPLE:
			sprite.modulate = Color.PURPLE
		SummonType.HEAL_GOLD, SummonType.AUX_GOLD:
			sprite.modulate = Color.GOLD
		SummonType.HEAL_RED, SummonType.AUX_RED:
			sprite.modulate = Color.RED

func _process(delta: float) -> void:
	move_timer += delta
	# 跟随玩家移动（保持一定距离）
	if player_node:
		if move_timer >= MOVE_INTERVAL:
			move_timer = 0.0
			# 每隔一段时间更新目标位置
			var random_offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
			move_target_position = player_node.position + random_offset
		
		# 平滑移动到目标位置
		if move_target_position != Vector2.ZERO:
			position = position.lerp(move_target_position, delta * 2.0 / MOVE_INTERVAL) # 调整插值速度以在MOVE_INTERVAL内到达
	
	# 更新敌人列表
	update_enemies_list()

func update_enemies_list() -> void:
	# 获取场景中的所有敌人
	enemies_in_scene.clear()
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy and is_instance_valid(enemy):
			enemies_in_scene.append(enemy)

func _on_fire_timer_timeout() -> void:
	# 根据召唤物类型执行不同的攻击逻辑
	match summon_type:
		SummonType.BLUE_RANDOM:
			fire_random_bullet()
		SummonType.PURPLE_DIRECTED:
			fire_directed_bullets()
		SummonType.ORANGE_TRACKING:
			fire_tracking_bullet()
		SummonType.GOLD_ENHANCED:
			fire_enhanced_tracking_bullets()
		SummonType.HEAL_PURPLE:
			fire_heal_bullet(Color.PURPLE)
		SummonType.HEAL_GOLD:
			fire_heal_bullet(Color.GOLD)
		SummonType.HEAL_RED:
			fire_heal_bullet(Color.RED)
		SummonType.AUX_PURPLE:
			fire_aux_bullet(Color.PURPLE)
		SummonType.AUX_GOLD:
			fire_aux_bullet(Color.GOLD)
		SummonType.AUX_RED:
			fire_aux_bullet(Color.RED)

func fire_random_bullet() -> void:
	# 蓝色召唤物：向左侧或右侧30度发射
	var side = randi() % 2  # 0为左侧，1为右侧
	var base_angle = PI if side == 0 else 0  # 左侧180度，右侧0度
	var random_offset = randf_range(-PI/6, PI/6)  # ±30度范围
	var final_angle = base_angle + random_offset
	var direction = Vector2(cos(final_angle), sin(final_angle))
	create_bullet(direction, damage_multiplier)

func fire_directed_bullets() -> void:
	if not player_node:
		print("Player node not found in fire_directed_bullets")
		return

	var horizontal_dir = 1.0 if player_node.sprite_direction_right else -1.0
	var bullet_direction = Vector2(horizontal_dir, 0).normalized() # Purely horizontal direction

	# Calculate spawn positions relative to the player
	var spawn_offset_y = 20.0
	var player_global_pos = player_node.global_position

	var spawn_pos_up = player_global_pos + Vector2(0, -spawn_offset_y)
	var spawn_pos_down = player_global_pos + Vector2(0, spawn_offset_y)

	# Create bullets at specified positions, moving horizontally
	create_bullet(bullet_direction, 0.35, 1.0, spawn_pos_up)
	create_bullet(bullet_direction, 0.35, 1.0, spawn_pos_down)


func fire_tracking_bullet() -> void:
	# 橙色召唤物：追踪最近的敌人
	var target_enemy = find_nearest_enemy()
	if target_enemy:
		var direction = (target_enemy.position - position).normalized()
		create_bullet(direction, 0.4, 1.5)  # 子弹速度提升100%


func fire_enhanced_tracking_bullets() -> void:
	# 金色召唤物：发射2发追踪子弹
	var target_enemy = find_nearest_enemy()
	if target_enemy:
		var base_direction = (target_enemy.position - position).normalized()
		
		# 发射两发稍微偏移的子弹
		var angle_offset = 0.02  # 约11.5度
		var direction1 = base_direction.rotated(-angle_offset)
		var direction2 = base_direction.rotated(angle_offset)
		
		create_bullet(direction1, 0.45, 1.5)
		create_bullet(direction2, 0.45, 1.5)

func find_nearest_enemy() -> Node2D:
	# 寻找最近的敌人
	var nearest_enemy = null
	var nearest_distance = INF
	
	for enemy in enemies_in_scene:
		if enemy and is_instance_valid(enemy):
			var distance = position.distance_to(enemy.position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_enemy = enemy
	
	return nearest_enemy

# 治疗型召唤：按间隔为角色回复生命，回复量为攻击力的一定比例
func fire_heal_bullet(color: Color) -> void:
	if PC.is_game_over:
		return
	# 计算治疗量：攻击力 * heal_ratio，并受召唤物增伤（用于“增强其他召唤物的治疗/伤害提升”）影响
	var heal_amount: int = int(PC.pc_atk * heal_ratio * (1.0 + PC.summon_damage_multiplier))
	PC.pc_hp += heal_amount
	# 上限处理，确保生命值不超过最大生命值
	if PC.pc_hp > PC.pc_max_hp:
		PC.pc_hp = PC.pc_max_hp
	# 可选：更新面板显示由其他系统负责，这里只负责数值

# 辅助型召唤：主要提供持续增益，定时器触发时无需额外行为
# 保持函数存在以符合调用结构（_on_fire_timer_timeout），避免复杂逻辑集中在一处
func fire_aux_bullet(color: Color) -> void:
	# 辅助效果在 set_summon_type 中一次性应用，这里不做额外处理
	pass

func create_bullet(direction: Vector2, base_damage: float, speed_mult: float = 1.0, spawn_position_override: Variant = null) -> void:
	if PC.is_game_over:
		return
	# 创建召唤物子弹
	if not bullet_scene:
		bullet_scene = load("res://Scenes/bullet.tscn")
	
	var bullet = bullet_scene.instantiate()
	bullet.if_summon = true
	if spawn_position_override != null and spawn_position_override is Vector2:
		bullet.position = spawn_position_override
	else:
		bullet.position = position
	bullet.direction = direction
	bullet.rotation = direction.angle()
	
	# 设置子弹属性
	var final_damage = PC.pc_atk * base_damage * (1.0 + PC.summon_damage_multiplier)
	bullet.summon_damage = final_damage
	bullet.is_summon_bullet = true
	bullet.penetration_count = 1  # 设置穿透次数
	
	# 设置子弹大小
	var bullet_size = PC.bullet_size * PC.summon_bullet_size_multiplier
	bullet.set_bullet_scale(Vector2(bullet_size, bullet_size))
	
	# 设置子弹速度
	if bullet.has_method("set_speed"):
		bullet.set_speed(bullet.bullet_speed * speed_mult)
	elif "bullet_speed" in bullet:
		bullet.bullet_speed *= speed_mult
	
	# 添加到场景
	get_tree().current_scene.add_child(bullet)


# 更新发射间隔（当玩家获得相关升级时调用）
func update_fire_interval() -> void:
	if not fire_timer:
		return
		
	var new_wait_time = fire_interval * PC.summon_interval_multiplier
	
	if fire_timer.is_stopped():
		fire_timer.wait_time = new_wait_time
		return
		
	var old_time_left = fire_timer.time_left
	if old_time_left <= 0.01:
		fire_timer.wait_time = new_wait_time
		return
		
	fire_timer.start(old_time_left)
	fire_timer.set_meta("pending_wait_time", new_wait_time)
	if not fire_timer.timeout.is_connected(_apply_pending_wait_time):
		fire_timer.timeout.connect(_apply_pending_wait_time)

func _apply_pending_wait_time() -> void:
	if fire_timer and fire_timer.has_meta("pending_wait_time"):
		fire_timer.wait_time = fire_timer.get_meta("pending_wait_time")
		fire_timer.remove_meta("pending_wait_time")


func set_summon_type(type: SummonType) -> void:
	# 设置召唤物类型
	summon_type = type
	setup_appearance()
	
	# 根据类型设置属性
	match type:
		SummonType.BLUE_RANDOM:
			damage_multiplier = 0.36
			fire_interval = 0.85
			bullets_per_shot = 1
		SummonType.PURPLE_DIRECTED:
			damage_multiplier = 0.2
			fire_interval = 0.8
			bullets_per_shot = 2
		SummonType.ORANGE_TRACKING:
			damage_multiplier = 0.4
			fire_interval = 0.65
			bullets_per_shot = 1
			bullet_speed_multiplier = 2.0
		SummonType.GOLD_ENHANCED:
			damage_multiplier = 0.24
			fire_interval = 0.75
			bullets_per_shot = 2
			bullet_speed_multiplier = 2.0
		# --- 治疗类 ---
		SummonType.HEAL_PURPLE:
			# SR21 愈灵：10%攻击，间隔2s
			heal_ratio = 0.10
			fire_interval = 2.0
		SummonType.HEAL_GOLD:
			# SSR21 护灵：20%攻击，间隔1.5s
			heal_ratio = 0.20
			fire_interval = 1.5
		SummonType.HEAL_RED:
			# UR21 生灵：18%攻击，间隔1.2s，并提供5%减伤
			heal_ratio = 0.18
			fire_interval = 1.2
			applied_damage_reduction_bonus = 0.05
			PC.damage_reduction_rate = min(PC.damage_reduction_rate + applied_damage_reduction_bonus, 0.9)
		# --- 辅助类（提供攻击与移速，并增强其他召唤物伤害/治疗） ---
		SummonType.AUX_PURPLE:
			# SR22 谐灵：+5%攻击力与移速；其他召唤物提升10%
			applied_speed_bonus = 0.05
			PC.pc_speed += applied_speed_bonus
			applied_atk_bonus = int(PC.pc_start_atk * 0.05)
			PC.pc_atk += applied_atk_bonus
			applied_summon_enhance_bonus = 0.10
			PC.summon_damage_multiplier += applied_summon_enhance_bonus
			# 辅助为持续效果，无需发射行为，设置一个较长的间隔以降低无意义调用频率
			fire_interval = 2.0
		SummonType.AUX_GOLD:
			# SSR22 灵律：+6%攻击力与移速；其他召唤物提升13%
			applied_speed_bonus = 0.06
			PC.pc_speed += applied_speed_bonus
			applied_atk_bonus = int(PC.pc_start_atk * 0.06)
			PC.pc_atk += applied_atk_bonus
			applied_summon_enhance_bonus = 0.13
			PC.summon_damage_multiplier += applied_summon_enhance_bonus
			fire_interval = 1.8
		SummonType.AUX_RED:
			# UR22 灵枢：+8%攻击力与移速；其他召唤物提升20%
			applied_speed_bonus = 0.08
			PC.pc_speed += applied_speed_bonus
			applied_atk_bonus = int(PC.pc_start_atk * 0.08)
			PC.pc_atk += applied_atk_bonus
			applied_summon_enhance_bonus = 0.20
			PC.summon_damage_multiplier += applied_summon_enhance_bonus
			fire_interval = 1.5
	
	# 更新定时器
	if fire_timer:
		fire_timer.wait_time = fire_interval * PC.summon_interval_multiplier

# 节点移除时回退辅助与治疗带来的持续加成
func _exit_tree() -> void:
	# 回退 AUX 持续增益
	if applied_speed_bonus != 0.0:
		PC.pc_speed -= applied_speed_bonus
		applied_speed_bonus = 0.0
	if applied_atk_bonus != 0:
		PC.pc_atk -= applied_atk_bonus
		applied_atk_bonus = 0
	if applied_summon_enhance_bonus != 0.0:
		PC.summon_damage_multiplier -= applied_summon_enhance_bonus
		applied_summon_enhance_bonus = 0.0
	# 回退治疗红色召唤的减伤
	if applied_damage_reduction_bonus != 0.0:
		PC.damage_reduction_rate = max(PC.damage_reduction_rate - applied_damage_reduction_bonus, 0.0)
		applied_damage_reduction_bonus = 0.0
