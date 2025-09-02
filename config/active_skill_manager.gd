extends Node

# 主动技能管理器
# 负责管理所有主动技能的使用、冷却和效果

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
	var cooldown_time: float
	var current_cooldown: float = 0.0
	var state: SkillState = SkillState.READY
	var is_unlocked: bool = false
	
	func _init(skill_id: String, skill_name: String, skill_desc: String, cd_time: float):
		id = skill_id
		name = skill_name
		description = skill_desc
		cooldown_time = cd_time

# 闪避技能数据
class DashSkill extends ActiveSkill:
	var dash_distance: float = 50.0
	var dash_speed_multiplier: float = 10.0
	var invincible_duration: float = 0.3
	
	func _init():
		super("dash", "闪避", "向前进方向快速冲刺，期间无敌", 10.0)
		is_unlocked = false  # 需要通过技能效果解锁

# 技能槽位配置
var skill_slots: Dictionary = {
	"shift": null,
	"space": null,
	"q": null,
	"e": null
}

# 已掌握的技能列表
var mastered_skills: Dictionary = {}

# 玩家引用
var player: CharacterBody2D = null

# 按键状态跟踪（用于实现just_pressed功能）
var key_states: Dictionary = {
	"shift": false,
	"space": false,
	"q": false,
	"e": false
}

# 信号
signal skill_used(skill_id: String)
signal skill_cooldown_started(skill_id: String, cooldown_time: float)
signal skill_cooldown_finished(skill_id: String)

func _ready():
	# 初始化默认技能
	init_default_skills()
	
	# 连接到全局信号（如果存在）
	if Global.has_signal("scene_changed"):
		Global.connect("scene_changed", Callable(self, "_on_scene_changed"))
	
	print("主动技能管理器已初始化")

func _process(delta):
	# 更新按键状态
	update_key_states()
	
	# 更新技能冷却
	update_skill_cooldowns(delta)
	
	# 检查输入（只在非城镇环境下）
	if not Global.in_town:
		check_skill_inputs()

func init_default_skills():
	"""初始化默认技能"""
	var dash_skill = DashSkill.new()
	# 只有解锁的技能才添加到已掌握列表
	if dash_skill.is_unlocked:
		mastered_skills[dash_skill.id] = dash_skill
		# 默认将闪避技能绑定到shift键
		skill_slots["shift"] = dash_skill.id

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
	"""检查技能输入"""
	# 使用直接按键检测，避免依赖输入映射
	if Input.is_key_pressed(KEY_SHIFT) and skill_slots.has("shift"):
		if not is_key_just_pressed("shift"):
			return
		use_skill(skill_slots["shift"])
		set_key_pressed("shift")
	elif Input.is_key_pressed(KEY_SPACE) and skill_slots.has("space"):
		if not is_key_just_pressed("space"):
			return
		use_skill(skill_slots["space"])
		set_key_pressed("space")
	elif Input.is_key_pressed(KEY_Q) and skill_slots.has("q"):
		if not is_key_just_pressed("q"):
			return
		use_skill(skill_slots["q"])
		set_key_pressed("q")
	elif Input.is_key_pressed(KEY_E) and skill_slots.has("e"):
		if not is_key_just_pressed("e"):
			return
		use_skill(skill_slots["e"])
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
		"dash":
			execute_dash_skill(skill as DashSkill)
		_:
			push_error("未知技能: " + skill.id)

func execute_dash_skill(dash_skill: DashSkill):
	"""执行闪避技能"""
	if not player:
		push_error("玩家节点未初始化")
		return
	
	# 获取冲刺方向
	var dash_direction = get_dash_direction()
	
	# 计算目标位置
	var target_position = player.global_position + dash_direction * dash_skill.dash_distance
	
	# 开始冲刺
	start_dash(target_position, dash_skill)

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
			return Vector2.RIGHT  # 默认向右

func start_dash(target_position: Vector2, dash_skill: DashSkill):
	"""开始冲刺"""
	# 设置无敌状态
	PC.invincible = true
	
	# 创建冲刺动画
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUART)
	
	# 计算冲刺时间
	var dash_time = dash_skill.dash_distance / (player.move_speed * dash_skill.dash_speed_multiplier)
	
	# 执行位移
	tween.tween_property(player, "global_position", target_position, dash_time)
	
	# 冲刺完成后的处理
	tween.tween_callback(func(): on_dash_complete(dash_skill))

func on_dash_complete(dash_skill: DashSkill):
	"""冲刺完成处理"""
	# 延迟结束无敌状态
	get_tree().create_timer(dash_skill.invincible_duration).timeout.connect(
		func(): PC.invincible = false
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

func set_skill_slot(slot_key: String, skill_id: String):
	"""设置技能槽位"""
	if not skill_slots.has(slot_key):
		push_error("无效的技能槽位: " + slot_key)
		return
	
	if skill_id and not mastered_skills.has(skill_id):
		push_error("技能不存在: " + skill_id)
		return
	
	skill_slots[slot_key] = skill_id

func get_skill_slot(slot_key: String) -> String:
	"""获取技能槽位绑定的技能ID"""
	return skill_slots.get(slot_key, "")

func is_key_just_pressed(key_name: String) -> bool:
	"""检查按键是否刚刚按下"""
	return not key_states.get(key_name, false)

func set_key_pressed(key_name: String):
	"""设置按键为已按下状态"""
	key_states[key_name] = true

func update_key_states():
	"""更新按键状态（在每帧检查按键释放）"""
	if not Input.is_key_pressed(KEY_SHIFT):
		key_states["shift"] = false
	if not Input.is_key_pressed(KEY_SPACE):
		key_states["space"] = false
	if not Input.is_key_pressed(KEY_Q):
		key_states["q"] = false
	if not Input.is_key_pressed(KEY_E):
		key_states["e"] = false

func _on_scene_changed():
	"""场景切换时的处理"""
	# 重置玩家引用
	player = null
	# 重置按键状态
	for key in key_states.keys():
		key_states[key] = false
	# 可以在这里添加其他场景切换相关的逻辑