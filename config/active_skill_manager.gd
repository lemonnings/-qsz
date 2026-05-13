extends Node

# 主动技能管理器
# 负责管理所有主动技能的使用、冷却和效果
# 使用 Global.get_current_active_skills() 配置技能槽位
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
		super ("dodge", "闪避", "向移动方向位移一小段距离并带有短暂的无敌", 6.0)
		is_unlocked = true
	
	func update_from_level(level: int):
		"""根据等级更新技能属性"""
		# 等级2,4,6,8,10,12,14，无敌时间+0.1秒
		var invincible_bonus = 0.0
		for lv in [2, 4, 6, 8, 10, 12, 14]:
			if level >= lv:
				invincible_bonus += 0.1
		# 修习树技能篇：闪避无敌时间加成
		invincible_duration = base_invincible_duration + invincible_bonus + Global.study_shanbi_invincible_bonus
		
		# 等级3，5，7，9，11，13，15，冷却时间-0.5秒
		var cd_reduction = 0.0
		for lv in [3, 5, 7, 9, 11, 13, 15]:
			if level >= lv:
				cd_reduction += 0.5
		# 修习树技能篇：闪避冷却减少
		cooldown_time = max(1.0, base_cooldown_time - cd_reduction - Global.study_shanbi_cd_reduction)

# 乱击技能数据
class RandomStrikeSkill extends ActiveSkill:
	var base_damage_ratio: float = 0.5 # 50%攻击力
	var damage_ratio: float = 0.5
	var base_bullet_count: int = 25
	var bullet_count: int = 10
	var fire_interval: float = 0.06 # 每0.1秒射出1发
	
	func _init():
		super ("random_strike", "乱击", "向随机方向连续射出剑气", 3.0)
		is_unlocked = true
	
	func update_from_level(level: int):
		"""根据等级更新技能属性"""
		# 等级2,5,8,11,14，伤害比率+5%
		var damage_bonus = 0.0
		for lv in [2, 5, 8, 11, 14]:
			if level >= lv:
				damage_bonus += 0.05
		# 修习树技能篇：乱击伤害加成
		damage_ratio = (base_damage_ratio + damage_bonus) * (1.0 + Global.study_luanji_damage_bonus)
		
		# 等级3，6，9，12，15，射出子弹+2
		var bullet_bonus = 0
		for lv in [3, 6, 9, 12, 15]:
			if level >= lv:
				bullet_bonus += 2
		# 修习树技能篇：乱击剑气数量加成
		bullet_count = base_bullet_count + bullet_bonus + Global.study_luanji_count_bonus
		
		# 等级4，7，10，13，冷却时间-1秒
		var cd_reduction = 0.0
		for lv in [4, 7, 10, 13]:
			if level >= lv:
				cd_reduction += 1.0
		cooldown_time = max(5.0, base_cooldown_time - cd_reduction)

class MizongbuSkill extends ActiveSkill:
	var base_duration: float = 1.8
	var duration: float = 1.8
	var move_speed_bonus_ratio: float = 0.5
	var base_damage_reduction_ratio: float = 0.4
	var damage_reduction_ratio: float = 0.4
	var outgoing_damage_reduction_ratio: float = 0.5
	
	func _init():
		super ("mizongbu", "迷踪步", "短时间提升移速并提升减伤率，但同时造成的伤害也会降低", 9.5)
		is_unlocked = true
	
	func update_from_level(level: int):
		var dr_bonus = 0.0
		for lv in [2, 5, 8, 11, 14]:
			if level >= lv:
				dr_bonus += 0.04
		# 修习树技能篇：迷踪步减伤率加成
		damage_reduction_ratio = base_damage_reduction_ratio + dr_bonus + Global.study_mizongbu_dmgreduction_bonus
		
		var cd_reduction = 0.0
		for lv in [3, 6, 9, 12, 15]:
			if level >= lv:
				cd_reduction += 0.5
		cooldown_time = max(2.0, base_cooldown_time - cd_reduction)
		
		var duration_bonus = 0.0
		for lv in [4, 7, 10, 13]:
			if level >= lv:
				duration_bonus += 0.3
		# 修习树技能篇：迷踪步持续时间加成
		duration = base_duration + duration_bonus + Global.study_mizongbu_duration_bonus

# 疗愈技能数据
class HealHotSkill extends ActiveSkill:
	var base_duration: float = 12.0
	var duration: float = 12.0
	var base_heal_percent: float = 0.01
	var heal_percent: float = 0.01
	var base_heal_amount: float = 30.0
	var heal_amount: float = 30.0
	
	func _init():
		super ("heal_hot", "疗愈", "持续恢复自身体力", 30.0)
		is_unlocked = true
	
	func update_from_level(level: int):
		# 等级2,5,8,11,14，回复体力基数+10
		var heal_bonus = 0.0
		for lv in [2, 5, 8, 11, 14]:
			if level >= lv:
				heal_bonus += 10.0
		heal_amount = base_heal_amount + heal_bonus
		
		# 等级3，6，9，12，15，冷却时间-1秒
		var cd_reduction = 0.0
		for lv in [3, 6, 9, 12, 15]:
			if level >= lv:
				cd_reduction += 1.0
		# 修习树技能篇：疗愈冷却减少
		cooldown_time = max(5.0, base_cooldown_time - cd_reduction - Global.study_liaoyu_cd_reduction)
		
		# 等级4，7，10，13，持续时间+1秒
		var duration_bonus = 0.0
		for lv in [4, 7, 10, 13]:
			if level >= lv:
				duration_bonus += 1.0
		duration = base_duration + duration_bonus

# 水幕护体技能数据
class WaterShieldSkill extends ActiveSkill:
	var base_duration: float = 7.0
	var duration: float = 7.0
	var base_shield_percent: float = 0.1
	var shield_percent: float = 0.1
	var base_damage_reduction: float = 0.2
	var damage_reduction: float = 0.2
	
	func _init():
		super ("water_sheild", "水幕护体", "释放水幕，获得护盾并提升减伤", 15.0)
		is_unlocked = true
	
	func update_from_level(level: int):
		# 等级2,5,8,11,14，护盾最大体力比例+1%
		var shield_bonus = 0.0
		for lv in [2, 5, 8, 11, 14]:
			if level >= lv:
				shield_bonus += 0.01
		shield_percent = base_shield_percent + shield_bonus
		
		# 等级3，6，9，12，15，减伤率+3%
		var dr_bonus = 0.0
		for lv in [3, 6, 9, 12, 15]:
			if level >= lv:
				dr_bonus += 0.03
		damage_reduction = base_damage_reduction + dr_bonus
		
		# 等级4，7，10，13，冷却时间-0.5秒
		var cd_reduction = 0.0
		for lv in [4, 7, 10, 13]:
			if level >= lv:
				cd_reduction += 0.5
		# 修习树技能篇：水幕护体冷却减少
		cooldown_time = max(3.0, base_cooldown_time - cd_reduction - Global.study_shuimu_cd_reduction)

# 风雷破技能数据
class WindThunderSkill extends ActiveSkill:
	var base_damage_ratio: float = 2.75 # 275%攻击力
	var damage_ratio: float = 2.75
	var chant_time: float = 1.2
	
	func _init():
		super ("wind_thunder", "风雷破", "咏唱后向鼠标方向发射风雷弹，击中敌人造成范围爆炸", 12.0)
		is_unlocked = true
	
	func update_from_level(_level: int):
		# 修习树技能篇：风雷破伤害加成
		damage_ratio = base_damage_ratio * (1.0 + Global.study_fengleipo_damage_bonus)

# 玄冰技能数据
class MagicalIceSkill extends ActiveSkill:
	var base_damage_ratio: float = 3.6 # 360%攻击力
	var damage_ratio: float = 3.6
	var chant_time: float = 1.5
	var indicator_size: Vector2 = Vector2(90, 65) # 咏唱圆圈提示范围
	
	func _init():
		super ("magical_ice", "玄冰", "咏唱后对鼠标位置释放玄冰阵，造成范围伤害并减速敌人", 15.0)
		is_unlocked = true
	
	func update_from_level(_level: int):
		# 修习树技能篇：玄冰伤害加成
		damage_ratio = base_damage_ratio * (1.0 + Global.study_xuanbing_damage_bonus)

# 炽炎技能数据
class MagicalFireSkill extends ActiveSkill:
	var base_damage_ratio: float = 2.2 # 220%攻击力
	var damage_ratio: float = 2.2
	var chant_time: float = 1.2
	var indicator_size: Vector2 = Vector2(90, 65) # 咏唱圆圈提示范围（与玄冰一致）
	
	func _init():
		super ("magical_fire", "炽炎", "咏唱后对鼠标位置释放炽炎，造成范围伤害", 2.5)
		is_unlocked = true
	
	func update_from_level(_level: int):
		# 修习树技能篇：炽炎伤害加成
		damage_ratio = base_damage_ratio * (1.0 + Global.study_chiyan_enhance_damage_bonus)

# 魔纹阵技能数据
class MagicSkill extends ActiveSkill:
	var duration: float = 15.0
	var atk_speed_bonus: float = 0.25 # 攻速提升25%
	var chant_cd_acceleration: float = 1.0 # 咏唱技能冷却加速100%
	var chant_time_reduction: float = 0.5 # 咏唱时间缩短50%
	
	func _init():
		super ("magic", "魔纹阵", "在脚下展开魔纹阵，刷新其他技能冷却，范围内提升攻速并加速咏唱技能冷却", 40.0)
		is_unlocked = true
	
	func update_from_level(_level: int):
		# 修习树技能篇：魔纹阵冷却减少
		cooldown_time = max(8.0, base_cooldown_time - Global.study_mowenzhen_cd_reduction)

# 冒想技能数据
class MeditationSkill extends ActiveSkill:
	var chant_time: float = 3.0
	
	func _init():
		super ("meditation", "冒想", "咏唱后提升1级", 60.0)
		is_unlocked = true
	
	func update_from_level(_level: int):
		# 修习树技能篇：冥想冷却减少
		cooldown_time = max(12.0, base_cooldown_time - Global.study_mingxiang_cd_reduction)

# 神圣灼烧技能数据
class HolyFireSkill extends ActiveSkill:
	var base_duration: float = 5.0
	var duration: float = 5.0
	var base_damage_ratio: float = 0.3
	var damage_ratio: float = 0.3
	
	func _init():
		super ("holy_fire", "神圣灼烧", "持续对自身周围造成伤害并回血", 24.0)
		is_unlocked = true
	
	func update_from_level(level: int):
		# 等级2,5,8,11,14，伤害+4%
		var damage_bonus = 0.0
		for lv in [2, 5, 8, 11, 14]:
			if level >= lv:
				damage_bonus += 0.04
		# 修习树技能篇：神圣灼烧伤害加成
		damage_ratio = (base_damage_ratio + damage_bonus) * (1.0 + Global.study_shensheng_damage_bonus)
		
		# 等级3，6，9，12，15，持续时间+0.5秒
		var duration_bonus = 0.0
		for lv in [3, 6, 9, 12, 15]:
			if level >= lv:
				duration_bonus += 0.5
		# 修习树技能篇：神圣灼烧持续时间加成
		duration = base_duration + duration_bonus + Global.study_shensheng_duration_bonus
		
		# 等级4，7，10，13，冷却时间-1秒
		var cd_reduction = 0.0
		for lv in [4, 7, 10, 13]:
			if level >= lv:
				cd_reduction += 1.0
		cooldown_time = max(4.0, base_cooldown_time - cd_reduction)

# 趋桀变身技能数据
class BeastifySkill extends ActiveSkill:
	var base_duration: float = 15.0
	var duration: float = 21.0
	var base_buff_ratio: float = 0.2
	var atk_bonus_ratio: float = 0.2
	var atk_speed_bonus_ratio: float = 0.2
	var move_bonus_ratio: float = 0.2
	var base_claw_damage_ratio: float = 0.55
	var claw_damage_ratio: float = 0.55
	
	func _init():
		super ("beastify", "魔化", "短时间提升属性，变为趋桀形态，并将剑气改为爪击", 40.0)
		is_unlocked = true
	
	func update_from_level(level: int):
		var claw_bonus = 0.0
		for lv in [2, 5, 8, 11, 14]:
			if level >= lv:
				claw_bonus += 0.04
		claw_damage_ratio = base_claw_damage_ratio + claw_bonus
		
		var attr_bonus = 0.0
		for lv in [3, 6, 9, 12, 15]:
			if level >= lv:
				attr_bonus += 0.03
		atk_bonus_ratio = base_buff_ratio + attr_bonus
		# 修习树技能篇：兽化攻速加成
		atk_speed_bonus_ratio = base_buff_ratio + attr_bonus + Global.study_shouhua_atkspeed_bonus
		move_bonus_ratio = base_buff_ratio + attr_bonus
		
		var extra_duration = 0.0
		for lv in [4, 7, 10, 13]:
			if level >= lv:
				extra_duration += 1.0
		# 修习树技能篇：兽化持续时间加成
		duration = base_duration + extra_duration + Global.study_shouhua_duration_bonus

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

# 闪避反馈参数。
# 这里按你的要求做成：
# - 轻微震屏
# - 0.5 秒慢动作
# - 时间流速降到 0.2
# 数值都单独提出来，后面如果你试玩后想再微调，会比较方便。
const DODGE_SHAKE_INTENSITY: float = 2.2
const DODGE_SHAKE_DURATION: float = 0.18
const DODGE_SLOW_TIME_SCALE: float = 0.35
const DODGE_SLOW_DURATION: float = 0.35
# 用请求编号防止旧的慢动作恢复逻辑把新的状态覆盖掉。
# 虽然闪避本身有冷却，正常不太会重叠，
# 但这样写更稳，后面即使你调整冷却或做特殊连闪，也不容易出问题。
var dodge_slow_motion_request_id: int = 0

# 信号
signal skill_used(skill_id: String)
signal skill_cooldown_started(skill_id: String, cooldown_time: float)
signal skill_cooldown_finished(skill_id: String)


func _ready():
	# 初始化技能
	init_skills()
	# 连接升级信号，播放升级动画
	Global.connect("player_lv_up", Callable(self , "_on_player_level_up"))

func _process(delta):
	# 游戏暂停时不处理
	if get_tree().paused:
		return
	
	# 更新按键状态
	update_key_states()
	
	# 更新技能冷却
	update_skill_cooldowns(delta)
	
	# 检查输入（只在非城镇、非菜单、非升级选择、非game over环境下）
	if not Global.in_town and not Global.in_menu and not Global.is_level_up and not PC.is_game_over:
		check_skill_inputs()

func init_skills():
	"""根据Global.player_active_skill_data初始化所有技能"""
	# 初始化闪避技能
	var dodge_skill = DodgeSkill.new()
	var dodge_level = Global.player_active_skill_data.get("dodge", {}).get("level", 1)
	dodge_skill.update_from_level(dodge_level)
	mastered_skills["dodge"] = dodge_skill
	
	var mizongbu_skill = MizongbuSkill.new()
	var mz_level = Global.player_active_skill_data.get("mizongbu", {}).get("level", 1)
	mizongbu_skill.update_from_level(mz_level)
	mastered_skills["mizongbu"] = mizongbu_skill
	
	# 初始化乱击技能
	var random_strike_skill = RandomStrikeSkill.new()
	var rs_level = Global.player_active_skill_data.get("random_strike", {}).get("level", 1)
	random_strike_skill.update_from_level(rs_level)
	mastered_skills["random_strike"] = random_strike_skill
	
	# 初始化趋桀变身
	var beast_skill = BeastifySkill.new()
	var b_level = Global.player_active_skill_data.get("beastify", {}).get("level", 1)
	beast_skill.update_from_level(b_level)
	mastered_skills["beastify"] = beast_skill
	
	# 初始化新技能
	var heal_hot_skill = HealHotSkill.new()
	var hh_level = Global.player_active_skill_data.get("heal_hot", {}).get("level", 1)
	heal_hot_skill.update_from_level(hh_level)
	mastered_skills["heal_hot"] = heal_hot_skill

	var water_shield_skill = WaterShieldSkill.new()
	var ws_level = Global.player_active_skill_data.get("water_sheild", {}).get("level", 1)
	water_shield_skill.update_from_level(ws_level)
	mastered_skills["water_sheild"] = water_shield_skill

	var holy_fire_skill = HolyFireSkill.new()
	var hf_level = Global.player_active_skill_data.get("holy_fire", {}).get("level", 1)
	holy_fire_skill.update_from_level(hf_level)
	mastered_skills["holy_fire"] = holy_fire_skill

	var wind_thunder_skill = WindThunderSkill.new()
	var wt_level = Global.player_active_skill_data.get("wind_thunder", {}).get("level", 1)
	wind_thunder_skill.update_from_level(wt_level)
	mastered_skills["wind_thunder"] = wind_thunder_skill

	var magical_ice_skill = MagicalIceSkill.new()
	var mi_level = Global.player_active_skill_data.get("magical_ice", {}).get("level", 1)
	magical_ice_skill.update_from_level(mi_level)
	mastered_skills["magical_ice"] = magical_ice_skill

	var magical_fire_skill = MagicalFireSkill.new()
	var mf_level = Global.player_active_skill_data.get("magical_fire", {}).get("level", 1)
	magical_fire_skill.update_from_level(mf_level)
	mastered_skills["magical_fire"] = magical_fire_skill

	var magic_skill = MagicSkill.new()
	var mg_level = Global.player_active_skill_data.get("magic", {}).get("level", 1)
	magic_skill.update_from_level(mg_level)
	mastered_skills["magic"] = magic_skill

	var meditation_skill = MeditationSkill.new()
	var md_level = Global.player_active_skill_data.get("meditation", {}).get("level", 1)
	meditation_skill.update_from_level(md_level)
	mastered_skills["meditation"] = meditation_skill

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
			var cd_delta = delta
			# 咏唱技能冷却加速：拥有chant_time属性的技能受益
			if PC.chant_cooldown_acceleration > 0 and "chant_time" in skill:
				cd_delta = delta * (1.0 + PC.chant_cooldown_acceleration)
			skill.current_cooldown -= cd_delta
			if skill.current_cooldown <= 0:
				skill.current_cooldown = 0
				skill.state = SkillState.READY
				skill_cooldown_finished.emit(skill.id)

func check_skill_inputs():
	"""检查技能输入 - 使用Global.get_current_active_skills()配置"""
	var current_skills := Global.get_current_active_skills()
	# 空格键
	if Input.is_key_pressed(KEY_SPACE):
		if is_key_just_pressed("space"):
			var skill_name = current_skills.get("space", {}).get("name", "")
			if skill_name != "":
				use_skill(skill_name)
			set_key_pressed("space")
	
	# Q键
	if Input.is_key_pressed(KEY_Q):
		if is_key_just_pressed("q"):
			var skill_name = current_skills.get("q", {}).get("name", "")
			if skill_name != "":
				use_skill(skill_name)
			set_key_pressed("q")
	
	# E键
	if Input.is_key_pressed(KEY_E):
		if is_key_just_pressed("e"):
			var skill_name = current_skills.get("e", {}).get("name", "")
			if skill_name != "":
				use_skill(skill_name)
			set_key_pressed("e")

func use_skill(skill_id: String):
	"""使用技能"""
	if not skill_id:
		push_error("技能ID不能为空")
		return
	if Global.in_town or Global.in_menu or Global.is_level_up or PC.is_game_over:
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
		"mizongbu":
			execute_mizongbu_skill(skill as MizongbuSkill)
		"random_strike":
			execute_random_strike_skill(skill as RandomStrikeSkill)
		"beastify":
			execute_beastify_skill(skill as BeastifySkill)
		"heal_hot":
			execute_heal_hot_skill(skill as HealHotSkill)
		"water_sheild":
			execute_water_shield_skill(skill as WaterShieldSkill)
		"holy_fire":
			execute_holy_fire_skill(skill as HolyFireSkill)
		"wind_thunder":
			execute_wind_thunder_skill(skill as WindThunderSkill)
		"magical_ice":
			execute_magical_ice_skill(skill as MagicalIceSkill)
		"magical_fire":
			execute_magical_fire_skill(skill as MagicalFireSkill)
		"magic":
			execute_magic_skill(skill as MagicSkill)
		"meditation":
			execute_meditation_skill(skill as MeditationSkill)
		_:
			push_error("未知技能: " + skill.id)

func execute_heal_hot_skill(skill: HealHotSkill):
	"""执行疗愈技能"""
	var scene = load("res://Scenes/player/heal_hot.tscn")
	if scene:
		var instance = scene.instantiate()
		player.add_child(instance)
		instance.position = Vector2.ZERO
		if instance.has_method("start"):
			instance.start(skill.duration, skill.heal_amount, skill.heal_percent)

func execute_water_shield_skill(skill: WaterShieldSkill):
	"""执行水幕护体技能"""
	SEManager.play("21")
	var scene = load("res://Scenes/player/water_sheild.tscn")
	if scene:
		var instance = scene.instantiate()
		player.add_child(instance)
		instance.position = Vector2.ZERO
		if instance.has_method("start"):
			instance.start(skill.duration, skill.shield_percent, skill.damage_reduction)

func execute_holy_fire_skill(skill: HolyFireSkill):
	"""执行神圣灼烧技能"""
	SEManager.play("19")
	var scene = load("res://Scenes/player/holy_fire.tscn")
	if scene:
		var instance = scene.instantiate()
		player.add_child(instance)
		instance.position = Vector2.ZERO
		if instance.has_method("start"):
			instance.start(skill.duration, skill.damage_ratio)

func execute_wind_thunder_skill(skill: WindThunderSkill):
	"""执行风雷破技能：开始咏唱（可减速移动），咏唱完成后沿提示线方向发射风雷弹"""
	if not player:
		return
	# 咏唱期间允许移动但减速70%
	PC.is_chanting = true
	PC.chant_speed_reduction = 0.7
	# 发送咏唱开始信号，通知战斗UI显示咏唱条
	var icon_path = Global.player_active_skill_data.get("wind_thunder", {}).get("icon", "")
	var effective_chant = skill.chant_time * (1.0 - PC.chant_time_reduction) / max(Global.game_speed, 1.0)
	Global.emit_signal("player_chant_start", "风雷破", effective_chant, icon_path)
	# 创建直线型技能提示线
	var SkillIndicator = preload("res://Script/skill/skill_indicator.gd")
	var indicator = SkillIndicator.new()
	get_tree().current_scene.add_child(indicator)
	indicator.setup_line(player)
	# 哏唱等待（加速时哏唱时间缩短）
	await get_tree().create_timer(effective_chant, false).timeout
	# 咏唱结束，恢复正常移动
	PC.is_chanting = false
	PC.chant_speed_reduction = 0.0
	if not is_instance_valid(player):
		Global.emit_signal("player_chant_end")
		if is_instance_valid(indicator):
			indicator.queue_free()
		return
	Global.emit_signal("player_chant_end")
	# 获取提示线最终方向作为发射方向
	var fire_direction = Vector2.RIGHT
	if is_instance_valid(indicator):
		fire_direction = indicator.get_direction()
		# 冻结提示线并渐变消失
		indicator.freeze_and_fade(0.3)
	# 发射风雷弹
	var scene = load("res://Scenes/player/wind_thunder.tscn")
	if scene:
		var instance = scene.instantiate()
		get_tree().current_scene.add_child(instance)
		instance.global_position = player.global_position
		if instance.has_method("launch"):
			instance.launch(fire_direction, skill.damage_ratio)

func execute_magical_ice_skill(skill: MagicalIceSkill):
	"""执行玄冰技能：咏唱后对鼠标位置释放玄冰阵，造成范围伤害并减速敌人"""
	if not player:
		return
	# 咏唱期间允许移动但减速70%
	PC.is_chanting = true
	PC.chant_speed_reduction = 0.7
	# 发送哏唱开始信号，通知战斗UI显示哏唱条
	var icon_path = Global.player_active_skill_data.get("magical_ice", {}).get("icon", "")
	var effective_chant = skill.chant_time * (1.0 - PC.chant_time_reduction) / max(Global.game_speed, 1.0)
	Global.emit_signal("player_chant_start", "玄冰", effective_chant, icon_path)
	# 创建圆圈型技能提示（跟随鼠标位置）
	var SkillIndicator = preload("res://Script/skill/skill_indicator.gd")
	var indicator = SkillIndicator.new()
	get_tree().current_scene.add_child(indicator)
	indicator.setup_circle(player, skill.indicator_size, true)
	# 哏唱等待（加速时哏唱时间缩短）
	await get_tree().create_timer(effective_chant, false).timeout
	# 咏唱结束，恢复正常移动
	PC.is_chanting = false
	PC.chant_speed_reduction = 0.0
	if not is_instance_valid(player):
		Global.emit_signal("player_chant_end")
		if is_instance_valid(indicator):
			indicator.queue_free()
		return
	Global.emit_signal("player_chant_end")
	# 获取提示圈最终位置作为释放目标点
	var target_pos = player.get_global_mouse_position()
	if is_instance_valid(indicator):
		target_pos = indicator.get_target_position()
		indicator.freeze_and_fade(0.3)
	# 在目标位置释放玄冰阵
	var scene = load("res://Scenes/player/magical_ice.tscn")
	if scene:
		var instance = scene.instantiate()
		get_tree().current_scene.add_child(instance)
		instance.global_position = target_pos
		if instance.has_method("activate"):
			instance.activate(skill.damage_ratio)

func execute_magical_fire_skill(skill: MagicalFireSkill):
	"""执行炽炎技能：咏唱后对鼠标位置释放炽炎，造成范围伤害"""
	if not player:
		return
	# 咏唱期间允许移动但减速70%
	PC.is_chanting = true
	PC.chant_speed_reduction = 0.7
	# 发送咏唱开始信号，通知战斗UI显示咏唱条
	var icon_path = Global.player_active_skill_data.get("magical_fire", {}).get("icon", "")
	var effective_chant = skill.chant_time * (1.0 - PC.chant_time_reduction) / max(Global.game_speed, 1.0)
	Global.emit_signal("player_chant_start", "炽炎", effective_chant, icon_path)
	# 创建圆圈型技能提示（跟随鼠标位置）
	var SkillIndicator = preload("res://Script/skill/skill_indicator.gd")
	var indicator = SkillIndicator.new()
	get_tree().current_scene.add_child(indicator)
	indicator.setup_circle(player, skill.indicator_size, true)
	# 咏唱等待（加速时咏唱时间缩短）
	await get_tree().create_timer(effective_chant, false).timeout
	# 咏唱结束，恢复正常移动
	PC.is_chanting = false
	PC.chant_speed_reduction = 0.0
	if not is_instance_valid(player):
		Global.emit_signal("player_chant_end")
		if is_instance_valid(indicator):
			indicator.queue_free()
		return
	Global.emit_signal("player_chant_end")
	# 获取提示圈最终位置作为释放目标点
	var target_pos = player.get_global_mouse_position()
	if is_instance_valid(indicator):
		target_pos = indicator.get_target_position()
		indicator.freeze_and_fade(0.3)
	# 在目标位置释放炽炎
	var scene = load("res://Scenes/player/magical_fire.tscn")
	if scene:
		var instance = scene.instantiate()
		get_tree().current_scene.add_child(instance)
		instance.global_position = target_pos
		if instance.has_method("activate"):
			instance.activate(skill.damage_ratio)

func execute_magic_skill(skill: MagicSkill):
	"""执行魔纹阵技能：立即在脚下展开魔纹阵，刷新其他技能冷却"""
	if not player:
		return
	# 立即刷新所有其他主动技能的冷却
	for sid in mastered_skills.keys():
		if sid == "magic":
			continue
		var s = mastered_skills[sid]
		if s.state == SkillState.COOLDOWN:
			s.current_cooldown = 0
			s.state = SkillState.READY
			skill_cooldown_finished.emit(s.id)
	# 在玩家当前位置放置魔纹阵（静止不跟随玩家）
	var scene = load("res://Scenes/player/magic.tscn")
	if scene:
		var instance = scene.instantiate()
		get_tree().current_scene.add_child(instance)
		instance.global_position = player.global_position
		# 修习树技能篇：魔纹阵大小加成
		if Global.study_mowenzhen_size_bonus > 0:
			var size_scale = 1.0 + Global.study_mowenzhen_size_bonus
			instance.scale *= size_scale
		if instance.has_method("start"):
			instance.start(skill.duration, skill.atk_speed_bonus, skill.chant_cd_acceleration, skill.chant_time_reduction)

func execute_meditation_skill(skill: MeditationSkill):
	"""执行冒想技能：咏唱后提升1级"""
	if not player:
		return
	# 咏唱期间允许移动但减速70%
	PC.is_chanting = true
	PC.chant_speed_reduction = 0.7
	# 发送咏唱开始信号，通知战斗UI显示咏唱条
	var icon_path = Global.player_active_skill_data.get("meditation", {}).get("icon", "")
	var effective_chant = skill.chant_time * (1.0 - PC.chant_time_reduction) / max(Global.game_speed, 1.0)
	Global.emit_signal("player_chant_start", "冒想", effective_chant, icon_path)
	# 在玩家身上显示冒想动画（图层比角色低）
	var med_instance: Node = null
	var med_scene = load("res://Scenes/player/meditation.tscn")
	if med_scene and is_instance_valid(player):
		med_instance = med_scene.instantiate()
		player.add_child(med_instance)
		med_instance.position = Vector2.ZERO
		if med_instance.has_method("start"):
			med_instance.start()
	# 咏唱等待（加速时咏唱时间缩短）
	await get_tree().create_timer(effective_chant, false).timeout
	# 咏唱结束，移除冒想动画
	if is_instance_valid(med_instance):
		med_instance.queue_free()
	# 恢复正常移动
	PC.is_chanting = false
	PC.chant_speed_reduction = 0.0
	if not is_instance_valid(player):
		Global.emit_signal("player_chant_end")
		return
	Global.emit_signal("player_chant_end")
	# 咏唱完成，提升1级
	_trigger_meditation_level_up()

func _trigger_meditation_level_up():
	"""冒想技能触发升级"""
	# 找到 BattleCanvasLayer 并添加待处理升级
	for child in get_tree().current_scene.get_children():
		if child.has_method("add_pending_level_up"):
			child.add_pending_level_up()
			break
	PC.pc_lv += 1
	Global.emit_signal("player_lv_up")

func _on_player_level_up():
	"""玩家升级时播放升级动画"""
	if not player:
		player = get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		return
	var scene = load("res://Scenes/player/level_up.tscn")
	if scene:
		var instance = scene.instantiate()
		player.add_child(instance)
		instance.position = Vector2.ZERO

func execute_dodge_skill(dodge_skill: DodgeSkill):
	"""执行闪避技能"""
	if not player:
		push_error("玩家节点未初始化")
		return
	
	# 获取冲刺方向
	var dash_direction = get_dash_direction()
	
	# 计算目标位置
	var target_position = player.global_position + dash_direction * dodge_skill.dash_distance
	
	# 闪避手感增强：
	# 1. 先给一个轻微震屏，强化"蹬地闪开"的瞬间反馈。
	# 2. 再给 0.5 秒慢动作，时间流速降到 0.2。
	# 注意这里的慢动作恢复，后面会用"忽略 time_scale 的计时器"处理，
	# 否则 0.5 秒会被错误地拖长。
	_play_dodge_feedback()
	
	# 开始冲刺
	start_dash(target_position, dodge_skill)


func execute_random_strike_skill(rs_skill: RandomStrikeSkill):
	"""执行乱击技能 - 向随机方向射出剑气"""
	if random_strike_active:
		return # 已经在执行中
	
	# 开始乱击协程
	SEManager.play("61")
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
	# 修习树技能篇：应用技能总伤害加成
	var base_damage = PC.pc_atk * damage_ratio * (1.0 + Global.study_skill_damage_bonus)
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

func execute_beastify_skill(skill: BeastifySkill) -> void:
	if not player:
		push_error("玩家节点未初始化")
		return
	var scene = get_tree().current_scene
	if scene and scene is CanvasItem:
		var t = create_tween()
		t.tween_property(scene, "modulate", Color(1, 0, 0, 0.6), 0.35)
		t.tween_property(scene, "modulate", Color(1, 1, 1, 1), 0.1)
		t.tween_property(scene, "modulate", Color(1, 0, 0, 0.6), 0.1)
		t.tween_property(scene, "modulate", Color(1, 1, 1, 1), 0.1)
		t.tween_property(scene, "modulate", Color(1, 0, 0, 0.6), 0.1)
		t.tween_property(scene, "modulate", Color(1, 1, 1, 1), 0.1)
	await get_tree().create_timer(0.05).timeout
	if is_instance_valid(player) and player.has_method("start_beastify"):
		# 修习树技能篇：兽化爪击应用技能总伤害加成
		var final_claw_ratio = skill.claw_damage_ratio * (1.0 + Global.study_skill_damage_bonus)
		player.start_beastify(skill.duration, skill.atk_bonus_ratio, skill.atk_speed_bonus_ratio, skill.move_bonus_ratio, final_claw_ratio)
		Global.emit_signal("buff_added", "beastify", skill.duration, 1)

func execute_mizongbu_skill(skill: MizongbuSkill) -> void:
	if is_instance_valid(player) and player.has_method("start_mizongbu"):
		player.start_mizongbu(skill.duration, skill.move_speed_bonus_ratio, skill.damage_reduction_ratio, skill.outgoing_damage_reduction_ratio)

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
	SEManager.play("60")
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

func _play_dodge_feedback() -> void:
	GU.screen_shake(DODGE_SHAKE_INTENSITY, DODGE_SHAKE_DURATION)
	_start_dodge_slow_motion(DODGE_SLOW_TIME_SCALE, DODGE_SLOW_DURATION)

func _start_dodge_slow_motion(target_time_scale: float, duration: float) -> void:
	dodge_slow_motion_request_id += 1
	var request_id := dodge_slow_motion_request_id
	var original_time_scale := Engine.time_scale
	# 如果当前已经比 0.2 还慢，就保持更慢的那个值，避免反向把时间流速抬高。
	var applied_time_scale = min(original_time_scale, target_time_scale)
	Engine.time_scale = applied_time_scale
	_restore_dodge_time_scale(duration, request_id, original_time_scale)

func _restore_dodge_time_scale(duration: float, request_id: int, original_time_scale: float) -> void:
	# 这里显式忽略 `Engine.time_scale`。
	# 所以写 0.5 秒，就真的是现实时间里的 0.5 秒，
	# 不会因为时间流速降到 0.2 而被拉长成 2.5 秒。
	await get_tree().create_timer(duration, true, false, true).timeout
	if request_id != dodge_slow_motion_request_id:
		return
	Engine.time_scale = original_time_scale

func _set_player_ghost_effect(enabled: bool):
	"""设置玩家半虚化效果"""
	if not player:
		return
	
	var sprite = player.get("sprite") as AnimatedSprite2D
	if not sprite:
		sprite = player.get_node_or_null("AnimatedSprite2D")
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
	
	# 优先使用 player.sprite（当前激活的精灵变量）
	var sprite = player.get("sprite") as AnimatedSprite2D
	if not sprite:
		sprite = player.get_node_or_null("AnimatedSprite2D")
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
	
	# 保持与原精灵相同的翻转方向
	afterimage.flip_h = source_sprite.flip_h
	afterimage.z_index = player.z_index # 去掉 - 1 避免被背景层遮挡
	
	# 设置残影颜色（淡红色半透明）
	afterimage.modulate = Color(1.0, 0.5, 0.5, 0.4)
	
	# 优先添加到 player 同级节点以保证排序（如 YSort），否则回退到 current_scene
	if player.get_parent():
		player.get_parent().add_child(afterimage)
	else:
		get_tree().current_scene.add_child(afterimage)
		
	# 添加到场景后再设置绝对的坐标和缩放，防止偏移
	afterimage.global_position = source_sprite.global_position
	afterimage.global_scale = source_sprite.global_scale
	
	# 渐隐并消失
	var tween = create_tween()
	tween.tween_property(afterimage, "modulate:a", 0.0, 0.3)
	tween.tween_callback(afterimage.queue_free)

func on_dash_complete(dodge_skill: DodgeSkill):
	"""冲刺完成处理"""
	# 这里也改成忽略 time_scale。
	# 否则闪避期间如果正在慢动作，无敌时间会被额外拉长，
	# 造成技能数值和面板说明对不上。
	get_tree().create_timer(dodge_skill.invincible_duration, true, false, true).timeout.connect(
		func():
			PC.invincible = false
			_set_player_ghost_effect(false)
	)

func start_skill_cooldown(skill: ActiveSkill):
	"""开始技能冷却"""
	skill.state = SkillState.COOLDOWN
	var final_cooldown_time = skill.cooldown_time * (1.0 - Global.get_total_skill_cooldown_reduction())
	skill.current_cooldown = final_cooldown_time
	skill_cooldown_started.emit(skill.id, final_cooldown_time)

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
