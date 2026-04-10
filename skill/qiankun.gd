extends Area2D
class_name Qiankun

@export var sprite_qian: AnimatedSprite2D
@export var sprite_kun: AnimatedSprite2D
@export var collision_shape: CollisionShape2D

var is_qian: bool = true
var damage: float = 0.0
var speed: float = 1000.0
var search_range: float = 240.0
var speed_per_enemy: float = 0.0
var damage_per_debuff: float = 0.0
var damage_per_enemy: float = 0.0
var crit_on_3_debuffs: bool = false

static var main_skill_qiankun_damage: float = 0.55
static var qiankun_final_damage_multi: float = 1.0
static var qiankun_speed: float = 300.0
static var qiankun_range: float = 240.0
static var qiankun_extra_damage_speed: bool = false
static var qiankun_extra_damage_range: bool = false
static var qiankun_speed_per_enemy: float = 0.0
static var qiankun_damage_per_debuff: float = 0.0
static var qiankun_damage_per_enemy: float = 0.0
static var qiankun_crit_on_3_debuffs: bool = false

static func reset_data() -> void:
	main_skill_qiankun_damage = 0.55
	qiankun_final_damage_multi = 1.0
	qiankun_speed = 300.0
	qiankun_range = 240.0
	qiankun_extra_damage_speed = false
	qiankun_extra_damage_range = false
	qiankun_speed_per_enemy = 0.0
	qiankun_damage_per_debuff = 0.0
	qiankun_damage_per_enemy = 0.0
	qiankun_crit_on_3_debuffs = false


enum State {IDLE, ATTACK, RETURN}
var state: State = State.IDLE
var player_ref: Node2D = null
var idle_offset: Vector2 = Vector2.ZERO
var return_speed_multiplier: float = 2.0 # 返回速度倍率

var destination: Vector2
var start_position: Vector2 # 记录攻击开始时的位置
var total_attack_distance: float = 0.0 # 攻击总距离
var moving: bool = false
var hit_targets: Dictionary = {} # {enemy_id: time_left}
var hit_cooldown: float = 0.5

# Static references to instances
static var qian_instance: Node2D = null
static var kun_instance: Node2D = null

static func fire_skill(scene: PackedScene, origin_pos: Vector2, tree: SceneTree) -> void:
	if not scene:
		return
		
	# 确保剑已初始化
	if not qian_instance or not is_instance_valid(qian_instance) or not kun_instance or not is_instance_valid(kun_instance):
		init_instances(scene, tree, origin_pos)
		
	# 更新属性
	if qian_instance and is_instance_valid(qian_instance) and qian_instance.has_method("update_stats"):
		qian_instance.update_stats()
		if qian_instance.has_method("launch"):
			qian_instance.launch()
			
	if kun_instance and is_instance_valid(kun_instance) and kun_instance.has_method("update_stats"):
		kun_instance.update_stats()
		if kun_instance.has_method("launch"):
			kun_instance.launch()

static func init_instances(scene: PackedScene, tree: SceneTree, origin_pos: Vector2) -> void:
	if Global.in_town:
		return
		
	# 清理旧实例
	if qian_instance and is_instance_valid(qian_instance):
		qian_instance.queue_free()
	if kun_instance and is_instance_valid(kun_instance):
		kun_instance.queue_free()
		
	# Spawn Qian
	qian_instance = scene.instantiate()
	tree.current_scene.add_child(qian_instance)
	qian_instance.setup(origin_pos, true)
	
	# Spawn Kun
	kun_instance = scene.instantiate()
	tree.current_scene.add_child(kun_instance)
	kun_instance.setup(origin_pos, false)


func _process(delta: float) -> void:
	# 尝试获取玩家引用，如果尚未获取
	if not player_ref:
		var tree = get_tree()
		if tree:
			player_ref = tree.get_first_node_in_group("player")
	
	# 如果仍然没有玩家引用，暂时不执行逻辑（除了冷却）
	if not player_ref:
		# 依然要处理冷却，防止内存泄漏
		var to_remove = []
		for id in hit_targets:
			hit_targets[id] -= delta
			if hit_targets[id] <= 0:
				to_remove.append(id)
		for id in to_remove:
			hit_targets.erase(id)
		return

	# 管理伤害冷却
	var to_remove = []
	for id in hit_targets:
		hit_targets[id] -= delta
		if hit_targets[id] <= 0:
			to_remove.append(id)
	for id in to_remove:
		hit_targets.erase(id)

	if state == State.IDLE:
		if player_ref:
			# 简单的插值跟随
			var target_pos = player_ref.global_position + idle_offset
			global_position = global_position.lerp(target_pos, 5.0 * delta)
			
			# 待机时的朝向
			# 假设贴图默认朝向：均为右上(-45度)
			# 目标：剑尖朝上(-90度)
			# 因此都需要逆时针旋转 45 度，即 rotation = -45
			var target_rot = deg_to_rad(-45)
				
			rotation = lerp_angle(rotation, target_rot, 10.0 * delta) # 增加插值速度确保能看到变化
			
	elif state == State.ATTACK:
		if moving:
			# 计算当前行程比例
			var current_dist = global_position.distance_to(start_position)
			var progress = 0.0
			if total_attack_distance > 0:
				progress = clamp(current_dist / total_attack_distance, 0.0, 1.0)
			
			# 动态速度计算
			var current_speed = speed
			if progress <= 0.9:
				current_speed = speed * lerp(0.35, 2.75, progress / 0.9)
			else:
				current_speed = speed * lerp(2.75, 0.35, (progress - 0.9) / 0.1)
			
			# 保证最小速度，避免完全停下导致无法到达终点
			current_speed = max(current_speed, speed * 0.35)
			
			var disp = destination - global_position
			var dist = disp.length()
			var step = current_speed * delta
			
			if dist <= step:
				global_position = destination
				moving = false
				# 攻击完成，返回待机
				state = State.RETURN
			else:
				global_position += disp.normalized() * step
				
	elif state == State.RETURN:
		if player_ref:
			var target_pos = player_ref.global_position + idle_offset
			var disp = target_pos - global_position
			var dist = disp.length()
			var step = speed * return_speed_multiplier * delta # 返回速度快一点
			
			if dist <= step:
				global_position = target_pos
				state = State.IDLE
				# 刚回到待机位置时，设置一个初始朝向，然后在 IDLE 状态下插值到目标朝向
				# rotation = 0 # 这一行删掉，不要强制重置为0
			else:
				global_position += disp.normalized() * step
				# 返回时朝向目标位置 (需要加上 PI/4 的贴图修正)
				# 贴图默认朝向左上 (-45度, -PI/4)
				# 飞行方向 angle
				# 目标 rotation = angle + PI/4
				var angle = disp.angle() + PI / 4
				rotation = lerp_angle(rotation, angle, 10.0 * delta)

func setup(pos: Vector2, _is_qian: bool) -> void:
	global_position = pos
	is_qian = _is_qian
	
	var tree = get_tree()
	if tree:
		player_ref = tree.get_first_node_in_group("player")
	
	# 设置待机偏移量
	if is_qian:
		idle_offset = Vector2(-25, -5) # 左上方
		rotation = deg_to_rad(-45) # 默认朝向调整
	else:
		idle_offset = Vector2(25, -5) # 右上方
		rotation = deg_to_rad(-45) # 默认朝向调整默认朝向右上
		
	update_stats()
	
	# 切换贴图
	if sprite_qian:
		sprite_qian.visible = is_qian
		if is_qian: sprite_qian.play("default")
	if sprite_kun:
		sprite_kun.visible = not is_qian
		if not is_qian: sprite_kun.play("default")
		
	state = State.IDLE

func update_stats() -> void:
	# 读取属性
	var damage_multiplier = main_skill_qiankun_damage
	speed = qiankun_speed
	search_range = qiankun_range
	var final_damage_multi = qiankun_final_damage_multi
	
	speed_per_enemy = qiankun_speed_per_enemy # 激发
	damage_per_debuff = qiankun_damage_per_debuff # 乘虚
	damage_per_enemy = qiankun_damage_per_enemy # 搜寻-激发
	crit_on_3_debuffs = qiankun_crit_on_3_debuffs # 搜寻-乘虚
	
	# Upgrades logic
	# Qiankun1: 飞速
	if PC.selected_rewards.has("Qiankun1"):
		speed *= 1.5
		
	# Qiankun2: 搜寻
	if PC.selected_rewards.has("Qiankun2"):
		search_range *= 1.5
		
	# Qiankun3: 激发（speed_per_enemy 已由 qiankun_speed_per_enemy 静态变量正确读取，值为0.02，无需重复覆盖）
		
	# Qiankun4: 乘虚
	if PC.selected_rewards.has("Qiankun4"):
		damage_per_debuff = 0.2
		
	# Qiankun11: 飞速-搜寻
	if PC.selected_rewards.has("Qiankun11"):
		pass
		
	# Qiankun22: 搜寻-激发
	if PC.selected_rewards.has("Qiankun22"):
		damage_per_enemy = 0.05
		
	# Qiankun33: 搜寻-乘虚
	if PC.selected_rewards.has("Qiankun33"):
		crit_on_3_debuffs = true
	
	# 八卦法则伤害加成
	var bagua_mult = Faze.get_bagua_damage_multiplier()
	damage_multiplier *= bagua_mult
		
	damage = PC.pc_atk * damage_multiplier * final_damage_multi

func launch() -> void:
	if state != State.IDLE and state != State.RETURN:
		# 如果正在攻击，可以选择忽略，或者重置攻击
		# 这里我们选择重置并立即开始新一轮攻击
		pass
		
	_launch_logic()

func _launch_logic() -> void:
	var tree = get_tree()
	if not tree:
		return
	var enemies = tree.get_nodes_in_group("enemies")
	var in_range = []
	for enemy in enemies:
		var d = global_position.distance_to(enemy.global_position)
		if d <= search_range:
			in_range.append({"node": enemy, "dist": d})
			
	# 按距离降序排列（最远的在先）
	in_range.sort_custom(func(a, b): return a.dist > b.dist)
	
	# 根据敌人数量应用动态加成
	if speed_per_enemy > 0:
		speed *= (1.0 + in_range.size() * speed_per_enemy)
	if damage_per_enemy > 0:
		damage *= (1.0 + in_range.size() * damage_per_enemy)
		
	var target: Node2D = null
	var is_same_target_potential = false
	
	if in_range.size() > 0:
		if is_qian:
			target = in_range[0].node
			# 乾剑取第一个（最远）
			if in_range.size() == 1:
				is_same_target_potential = true
		else:
			# 坤剑取第二个最远
			if in_range.size() > 1:
				target = in_range[1].node
			else:
				target = in_range[0].node # 回退到第一个
				is_same_target_potential = true
				
	if target:
		var dir = (target.global_position - global_position).normalized()
		
		if is_same_target_potential:
			# 随机偏差 -2 到 2 度
			var angle = deg_to_rad(randf_range(-2.0, 2.0))
			dir = dir.rotated(angle)
			
		destination = target.global_position + dir * 50.0
		# 计算飞行时的旋转角度
		# dir 是飞行方向向量
		# 贴图默认朝向左上 (-45度, -PI/4)
		# 如果 dir 是右 (0度)，我们需要让贴图顺时针旋转 45度 (PI/4) 才能指右?
		# 不，如果贴图是 -45度。
		# rotation = 0 -> 实际显示 -45度
		# 目标角度 target_angle (例如 0度)
		# 我们设置 rotation = target_angle - (-PI/4) = target_angle + PI/4
		# 比如 target=0(右), rotation = 45度。45度时，贴图从 -45 转到 0。对的。
		rotation = dir.angle() + PI / 4
	else:
		# 没有目标，向右飞
		destination = global_position + Vector2.RIGHT * search_range
		rotation = 0 + PI / 4
		
	start_position = global_position
	total_attack_distance = start_position.distance_to(destination)
	moving = true
	state = State.ATTACK
	
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies"):
		var id = area.get_instance_id()
		if hit_targets.has(id):
			return
			
		hit_targets[id] = hit_cooldown
		
		var final_damage = damage
		var is_crit = false
		if randf() < PC.crit_chance:
			is_crit = true
			
		# Apply damage_per_debuff
		if damage_per_debuff > 0 or crit_on_3_debuffs:
			if area.get("debuff_manager"):
				var count = 0
				if area.debuff_manager.get("active_debuffs") is Dictionary:
					count = area.debuff_manager.active_debuffs.size()
				elif area.debuff_manager.has_method("get_debuff_count"):
					count = area.debuff_manager.get_debuff_count()
					
				if damage_per_debuff > 0:
					final_damage *= (1.0 + count * damage_per_debuff)
				if crit_on_3_debuffs and count >= 3:
					is_crit = true # Force crit
					
		if is_crit:
			final_damage *= Faze.get_sword_crit_damage_multiplier(PC.faze_sword_level)
			
		# Apply final total damage multiplier
		if qiankun_final_damage_multi > 1.0:
			final_damage *= qiankun_final_damage_multi
			
		if area.has_method("take_damage"):
			area.take_damage(int(final_damage), is_crit, false, "qiankun")
			Faze.on_sword_weapon_hit(area)
			
			# 八卦法则推衍度
			Faze.add_bagua_progress(1, area.is_in_group("elite") or area.is_in_group("boss"))
			if not is_instance_valid(area) or area.hp <= 0:
				Faze.add_bagua_progress(5, area.is_in_group("elite") or area.is_in_group("boss"))
