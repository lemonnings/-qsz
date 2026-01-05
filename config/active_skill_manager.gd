extends Node

# 主动技能管理器
# 负责管理所有主动技能的使用、冷却和效果
# 使用 Global.player_now_active_skill 配置技能槽位
# 使用 Global.player_active_skill_data 存储技能数据

class_name ActiveSkillManager

# 技能状态枚举
enum SkillState {
	READY,
	COOLDOWN,
	ACTIVE
}

# 技能数据结构
class ActiveSkill:
	var id: String
	var name: String
	var description: String
	var base_cooldown_time: float
	var cooldown_time: float
	var current_cooldown: float = 0.0
	var state: SkillState = SkillState.READY
	var is_unlocked: bool = true
	
	func _init(skill_id: String, skill_name: String, skill_desc: String, cd_time: float):
		id = skill_id
		name = skill_name
		description = skill_desc
		base_cooldown_time = cd_time
		cooldown_time = cd_time

# 闪避技能数据
class DodgeSkill extends ActiveSkill:
	var dash_distance: float = 30.0
	var dash_speed_multiplier: float = 4.0
	var base_invincible_duration: float = 0.5
	var invincible_duration: float = 0.5
	
	func _init():
		super ("dodge", "闪避", "向移动方向位移一小段距离并无敌", 6.0)
		is_unlocked = true
	
	func update_from_level(level: int):
		"""根据等级更新技能属性"""
		# 等级2,4,6,8,10,12,14，无敌时间+0.1秒
		var invincible_bonus = 0.0
		for lv in [2, 4, 6, 8, 10, 12, 14]:
			if level >= lv:
				invincible_bonus += 0.1
		invincible_duration = base_invincible_duration + invincible_bonus
		
		# 等级3，5，7，9，11，13，15，冷却时间-0.5秒
		var cd_reduction = 0.0
		for lv in [3, 5, 7, 9, 11, 13, 15]:
			if level >= lv:
				cd_reduction += 0.5
		cooldown_time = max(1.0, base_cooldown_time - cd_reduction)

# 乱击技能数据
class RandomStrikeSkill extends ActiveSkill:
	var base_damage_ratio: float = 0.5 # 50%攻击力
	var damage_ratio: float = 0.5
	var base_bullet_count: int = 25
	var bullet_count: int = 10
	var fire_interval: float = 0.06 # 每0.1秒射出1发
	
	func _init():
		super ("random_strike", "乱击", "向随机方向射出剑气", 3.0)
		is_unlocked = true
	
	func update_from_level(level: int):
		"""根据等级更新技能属性"""
		# 等级2,5,8,11,14，伤害比率+5%
		var damage_bonus = 0.0
		for lv in [2, 5, 8, 11, 14]:
			if level >= lv:
				damage_bonus += 0.05
		damage_ratio = base_damage_ratio + damage_bonus
		
		# 等级3，6，9，12，15，射出子弹+2
		var bullet_bonus = 0
		for lv in [3, 6, 9, 12, 15]:
			if level >= lv:
				bullet_bonus += 2
		bullet_count = base_bullet_count + bullet_bonus
		
		# 等级4，7，10，13，冷却时间-1秒
		var cd_reduction = 0.0
		for lv in [4, 7, 10, 13]:
			if level >= lv:
				cd_reduction += 1.0
		cooldown_time = max(5.0, base_cooldown_time - cd_reduction)

# 已掌握的技能列表
var mastered_skills: Dictionary = {}

# 玩家引用
var player: CharacterBody2D = null

# 按键状态跟踪（用于实现just_pressed功能）
var key_states: Dictionary = {
	"space": false,
	"q": false,
	"e": false
}

# 乱击技能的协程控制
var random_strike_active: bool = false

# 信号
signal skill_used(skill_id: String)
signal skill_cooldown_started(skill_id: String, cooldown_time: float)
signal skill_cooldown_finished(skill_id: String)

func _ready():
	# 初始化技能
	init_skills()
	
	print("主动技能管理器已初始化")
	print("已掌握技能: ", mastered_skills.keys())
	print("技能槽位配置: ", Global.player_now_active_skill)

func _process(delta):
	# 游戏暂停时不处理
	if get_tree().paused:
		return
	
	# 更新按键状态
	update_key_states()
	
	# 更新技能冷却
	update_skill_cooldowns(delta)
	
	# 检查输入（只在非城镇、非菜单、非升级选择环境下）
	if not Global.in_town and not Global.in_menu and not Global.is_level_up:
		check_skill_inputs()

func init_skills():
	"""根据Global.player_active_skill_data初始化所有技能"""
	# 初始化闪避技能
	var dodge_skill = DodgeSkill.new()
	var dodge_level = Global.player_active_skill_data.get("dodge", {}).get("level", 1)
	dodge_skill.update_from_level(dodge_level)
	mastered_skills["dodge"] = dodge_skill
	
	# 初始化乱击技能
	var random_strike_skill = RandomStrikeSkill.new()
	var rs_level = Global.player_active_skill_data.get("random_strike", {}).get("level", 1)
	random_strike_skill.update_from_level(rs_level)
	mastered_skills["random_strike"] = random_strike_skill

func refresh_skill_levels():
	"""刷新技能等级（当技能升级时调用）"""
	for skill_id in mastered_skills.keys():
		var skill_data = Global.player_active_skill_data.get(skill_id, {})
		var level = skill_data.get("level", 1)
		var skill = mastered_skills[skill_id]
		if skill.has_method("update_from_level"):
			skill.update_from_level(level)

func update_skill_cooldowns(delta: float):
	"""更新所有技能的冷却时间"""
	for skill in mastered_skills.values():
		if skill.state == SkillState.COOLDOWN:
			skill.current_cooldown -= delta
			if skill.current_cooldown <= 0:
				skill.current_cooldown = 0
				skill.state = SkillState.READY
				skill_cooldown_finished.emit(skill.id)

func check_skill_inputs():
	"""检查技能输入 - 使用Global.player_now_active_skill配置"""
	# 空格键
	if Input.is_key_pressed(KEY_SPACE):
		if is_key_just_pressed("space"):
			var skill_name = Global.player_now_active_skill.get("space", {}).get("name", "")
			print("[主动技能] Space按下, 技能: ", skill_name)
			if skill_name != "":
				use_skill(skill_name)
			set_key_pressed("space")
	
	# Q键
	if Input.is_key_pressed(KEY_Q):
		if is_key_just_pressed("q"):
			var skill_name = Global.player_now_active_skill.get("q", {}).get("name", "")
			print("[主动技能] Q按下, 技能: ", skill_name)
			if skill_name != "":
				use_skill(skill_name)
			set_key_pressed("q")
	
	# E键
	if Input.is_key_pressed(KEY_E):
		if is_key_just_pressed("e"):
			var skill_name = Global.player_now_active_skill.get("e", {}).get("name", "")
			print("[主动技能] E按下, 技能: ", skill_name)
			if skill_name != "":
				use_skill(skill_name)
			set_key_pressed("e")

func use_skill(skill_id: String):
	"""使用技能"""
	if not skill_id:
		push_error("技能ID不能为空")
		return
	
	if not mastered_skills.has(skill_id):
		push_error("未找到技能: " + skill_id)
		return
	
	var skill = mastered_skills[skill_id]
	
	# 检查技能是否可用
	if skill.state != SkillState.READY:
		print("技能冷却中: ", skill_id)
		return
	
	# 执行技能效果
	execute_skill(skill)
	
	# 开始冷却
	start_skill_cooldown(skill)
	skill_used.emit(skill_id)

func execute_skill(skill: ActiveSkill):
	"""执行技能效果"""
	if not player:
		# 尝试获取玩家引用
		player = get_tree().get_first_node_in_group("player")
		if not player:
			push_error("未找到玩家节点")
			return
	
	match skill.id:
		"dodge":
			execute_dodge_skill(skill as DodgeSkill)
		"random_strike":
			execute_random_strike_skill(skill as RandomStrikeSkill)
		_:
			push_error("未知技能: " + skill.id)

func execute_dodge_skill(dodge_skill: DodgeSkill):
	"""执行闪避技能"""
	if not player:
		push_error("玩家节点未初始化")
		return
	
	# 获取冲刺方向
	var dash_direction = get_dash_direction()
	
	# 计算目标位置
	var target_position = player.global_position + dash_direction * dodge_skill.dash_distance
	
	# 开始冲刺
	start_dash(target_position, dodge_skill)

func execute_random_strike_skill(rs_skill: RandomStrikeSkill):
	"""执行乱击技能 - 向随机方向射出剑气"""
	if not player:
		push_error("玩家节点未初始化")
		return
	
	if random_strike_active:
		return # 已经在执行中
	
	# 开始乱击协程
	random_strike_active = true
	_execute_random_strike_bullets(rs_skill)

func _execute_random_strike_bullets(rs_skill: RandomStrikeSkill):
	"""射出乱击子弹"""
	var bullets_fired = 0
	var total_bullets = rs_skill.bullet_count
	var interval = rs_skill.fire_interval
	
	while bullets_fired < total_bullets:
		if not is_instance_valid(player):
			break
		
		# 游戏暂停时等待
		while get_tree().paused:
			await get_tree().process_frame
		
		# 生成随机方向
		var random_angle = randf() * TAU # 0 到 2*PI
		var direction = Vector2.from_angle(random_angle)
		
		# 创建剑气
		_spawn_random_strike_bullet(direction, rs_skill.damage_ratio)
		
		bullets_fired += 1
		
		# 等待间隔
		await get_tree().create_timer(interval).timeout
	
	random_strike_active = false

func _spawn_random_strike_bullet(direction: Vector2, damage_ratio: float):
	"""生成乱击剑气"""
	# 加载子弹场景
	var bullet_scene = preload("res://Scenes/bullet.tscn")
	var bullet = bullet_scene.instantiate()
	
	# 设置位置
	bullet.global_position = player.global_position
	
	# 计算伤害（基于伤害比率）
	var base_damage = PC.pc_atk * damage_ratio
	bullet.bullet_damage = base_damage
	
	# 标记为乱击子弹，不触发额外效果
	bullet.is_other_sword_wave = true
	bullet.parent_bullet = false
	
	# 添加到场景
	get_tree().current_scene.add_child(bullet)
	
	# 在add_child之后使用set_direction设置方向（会同时更新精灵旋转）
	bullet.set_direction(direction)
	
	# 为乱击子弹添加金色滤镜
	bullet.modulate = Color(1.0, 0.85, 0.4, 1.0) # 金色

func get_dash_direction() -> Vector2:
	"""获取冲刺方向"""
	# 获取当前移动输入（使用与player_action.gd相同的输入方式）
	var input_vector = Vector2.ZERO
	
	# 检查移动平台
	if OS.has_feature("mobile"):
		# 移动设备使用虚拟摇杆
		if player and player.has_node("virtual_joystick_manager"):
			var joystick_manager = player.get_node("virtual_joystick_manager")
			if joystick_manager.has_method("get_left_stick_output"):
				input_vector = joystick_manager.get_left_stick_output()
	else:
		# 桌面设备使用键盘
		input_vector = Input.get_vector("left", "right", "up", "down")
	
	# 如果有移动输入，使用移动方向
	if input_vector.length() > 0:
		return input_vector.normalized()
	
	# 如果没有移动输入，使用角色面向方向
	if player.has_method("get_facing_direction"):
		return player.get_facing_direction()
	else:
		# 默认使用sprite的朝向
		if player.has_node("AnimatedSprite2D"):
			var sprite = player.get_node("AnimatedSprite2D")
			return Vector2.RIGHT if not sprite.flip_h else Vector2.LEFT
		else:
			return Vector2.RIGHT # 默认向右

func start_dash(target_position: Vector2, dodge_skill: DodgeSkill):
	"""开始冲刺"""
	# 设置无敌状态
	PC.invincible = true
	
	# 设置玩家半虚化状态（无敌提示）
	_set_player_ghost_effect(true)
	
	# 计算冲刺时间
	var dash_time = dodge_skill.dash_distance / (player.move_speed * dodge_skill.dash_speed_multiplier)
	
	# 启动残影效果
	_start_afterimage_effect(dash_time)
	
	# 创建冲刺动画
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUART)
	
	# 执行位移
	tween.tween_property(player, "global_position", target_position, dash_time)
	
	# 冲刺完成后的处理
	tween.tween_callback(func(): on_dash_complete(dodge_skill))

func _set_player_ghost_effect(enabled: bool):
	"""设置玩家半虚化效果"""
	if not player:
		return
	
	var sprite = player.get_node_or_null("AnimatedSprite2D")
	if sprite:
		if enabled:
			# 半透明
			sprite.modulate = Color(1.0, 1.0, 1.0, 0.6)
		else:
			# 恢复正常
			sprite.modulate = Color(1, 1, 1, 1)

func _start_afterimage_effect(duration: float):
	"""启动残影效果"""
	if not player:
		return
	
	var sprite = player.get_node_or_null("AnimatedSprite2D")
	if not sprite:
		return
	
	# 残影数量和间隔
	var afterimage_count = 5
	var interval = duration / afterimage_count
	
	# 顺序创建残影
	for i in range(afterimage_count):
		if is_instance_valid(player) and is_instance_valid(sprite):
			_create_afterimage(sprite)
		await get_tree().create_timer(interval).timeout

func _create_afterimage(source_sprite: AnimatedSprite2D):
	"""创建单个残影"""
	# 创建残影精灵
	var afterimage = Sprite2D.new()
	afterimage.texture = source_sprite.sprite_frames.get_frame_texture(source_sprite.animation, source_sprite.frame)
	afterimage.global_position = player.global_position
	afterimage.scale = source_sprite.scale
	afterimage.flip_h = source_sprite.flip_h
	afterimage.z_index = player.z_index - 1
	
	# 设置残影颜色（淡红色半透明）
	afterimage.modulate = Color(1.0, 0.5, 0.5, 0.4)
	
	# 添加到场景
	get_tree().current_scene.add_child(afterimage)
	
	# 渐隐并消失
	var tween = create_tween()
	tween.tween_property(afterimage, "modulate:a", 0.0, 0.3)
	tween.tween_callback(afterimage.queue_free)

func on_dash_complete(dodge_skill: DodgeSkill):
	"""冲刺完成处理"""
	# 延迟结束无敌状态和虚化效果
	get_tree().create_timer(dodge_skill.invincible_duration).timeout.connect(
		func():
			PC.invincible = false
			_set_player_ghost_effect(false)
	)

func start_skill_cooldown(skill: ActiveSkill):
	"""开始技能冷却"""
	skill.state = SkillState.COOLDOWN
	skill.current_cooldown = skill.cooldown_time
	skill_cooldown_started.emit(skill.id, skill.cooldown_time)

# 城镇检测逻辑已移至Global.in_town变量

func get_skill_by_id(skill_id: String) -> ActiveSkill:
	"""根据ID获取技能"""
	return mastered_skills.get(skill_id, null)

func get_mastered_skills() -> Array[ActiveSkill]:
	"""获取所有已掌握的技能"""
	var skills: Array[ActiveSkill] = []
	for skill in mastered_skills.values():
		if skill.is_unlocked:
			skills.append(skill)
	return skills

func is_key_just_pressed(key_name: String) -> bool:
	"""检查按键是否刚刚按下"""
	return not key_states.get(key_name, false)

func set_key_pressed(key_name: String):
	"""设置按键为已按下状态"""
	key_states[key_name] = true

func update_key_states():
	"""更新按键状态（在每帧检查按键释放）"""
	if not Input.is_key_pressed(KEY_SPACE):
		key_states["space"] = false
	if not Input.is_key_pressed(KEY_Q):
		key_states["q"] = false
	if not Input.is_key_pressed(KEY_E):
		key_states["e"] = false

func reset_player_reference():
	"""重置玩家引用（场景切换时调用）"""
	player = null
	for key in key_states.keys():
		key_states[key] = false
	random_strike_active = false

func get_skill_cooldown_info(skill_id: String) -> Dictionary:
	"""获取技能冷却信息"""
	var skill = mastered_skills.get(skill_id, null)
	if skill:
		return {
			"cooldown_time": skill.cooldown_time,
			"current_cooldown": skill.current_cooldown,
			"is_ready": skill.state == SkillState.READY
		}
	return {}
