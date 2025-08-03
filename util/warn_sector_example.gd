extends Node2D

# WarnSectorUtil 使用示例
# 展示如何在boss脚本中使用扇形AOE预警工具

var WarnSectorUtil = preload("res://Script/util/warn_sector_util.gd")

func _ready():
	# 示例：在boss脚本中使用
	example_boss_sector_skill()

func example_boss_sector_skill():
	"""示例：boss释放扇形AOE技能"""
	# 创建预警扇形
	var warning_sector = WarnSectorUtil.new()
	add_child(warning_sector)
	
	# 连接信号
	warning_sector.warning_finished.connect(_on_warning_finished)
	warning_sector.damage_dealt.connect(_on_damage_dealt)
	
	# 开始预警
	# 参数：起始位置, 目标点, 扇形角度, 预警时间, 伤害, 动画播放器
	var flame_breath_anim = get_node("FlameBreathAnimationPlayer")  # 获取动画播放器
	warning_sector.start_warning(
		Vector2(300, 200),  # 起始位置（boss位置）
		Vector2(500, 300),  # 目标点（决定喷射方向）
		90.0,               # 扇形角度90度
		3.0,                # 预警时间3秒
		100.0,              # 伤害值
		flame_breath_anim   # 动画播放器
	)

func example_player_targeted_cone():
	"""示例：指向玩家的锥形攻击"""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var warning_cone = WarnSectorUtil.new()
	add_child(warning_cone)
	
	warning_cone.warning_finished.connect(_on_warning_finished)
	warning_cone.damage_dealt.connect(_on_damage_dealt)
	
	# 从boss位置指向玩家的锥形攻击
	var boss_pos = Vector2(400, 200)  # boss位置
	var player_pos = player.global_position
	var cone_attack_anim = get_node("ConeAttackAnimationPlayer")
	
	warning_cone.start_warning(
		boss_pos,           # 起始位置（boss）
		player_pos,         # 目标点（玩家）
		60.0,               # 锥形角度60度
		2.5,                # 预警时间
		120.0,              # 高伤害
		cone_attack_anim
	)

func example_wide_sweep_attack():
	"""示例：大范围扫击攻击"""
	var warning_sweep = WarnSectorUtil.new()
	add_child(warning_sweep)
	
	warning_sweep.warning_finished.connect(_on_warning_finished)
	warning_sweep.damage_dealt.connect(_on_damage_dealt)
	
	# 大范围扫击
	var sweep_anim = get_node("SweepAttackAnimationPlayer")
	warning_sweep.start_warning(
		Vector2(400, 300),  # 中心位置
		Vector2(600, 300),  # 扫击方向
		120.0,              # 大角度扫击
		4.0,                # 较长预警时间
		150.0,              # 高伤害
		sweep_anim
	)

func example_multi_direction_blast():
	"""示例：多方向爆发攻击"""
	# 创建四个方向的扇形攻击
	var directions = [
		Vector2(1, 0),    # 右
		Vector2(0, 1),    # 下
		Vector2(-1, 0),   # 左
		Vector2(0, -1)    # 上
	]
	
	var center_pos = Vector2(400, 300)
	
	for i in range(directions.size()):
		var direction = directions[i]
		var warning = WarnSectorUtil.new()
		add_child(warning)
		
		warning.warning_finished.connect(_on_warning_finished)
		warning.damage_dealt.connect(_on_damage_dealt)
		
		# 延迟启动，创造连续爆发效果
		await get_tree().create_timer(i * 0.5).timeout
		
		var target_point = center_pos + direction * 200
		var blast_anim = get_node("BlastAnimationPlayer")
		
		warning.start_warning(
			center_pos,         # 中心位置
			target_point,       # 方向目标点
			80.0,               # 扇形角度
			2.0,                # 预警时间
			90.0,               # 伤害
			blast_anim
		)

func example_rotating_beam():
	"""示例：旋转光束攻击"""
	# 创建旋转的扇形光束
	var center_pos = Vector2(400, 300)
	var rotation_count = 8  # 8个方向
	
	for i in range(rotation_count):
		var angle = (i * 2 * PI) / rotation_count
		var direction = Vector2(cos(angle), sin(angle))
		var target_point = center_pos + direction * 150
		
		var warning = WarnSectorUtil.new()
		add_child(warning)
		
		warning.warning_finished.connect(_on_warning_finished)
		warning.damage_dealt.connect(_on_damage_dealt)
		
		# 短暂延迟创造旋转效果
		await get_tree().create_timer(i * 0.2).timeout
		
		var rotating_beam_anim = get_node("RotatingBeamAnimationPlayer")
		warning.start_warning(
			center_pos,
			target_point,
			45.0,               # 较窄的光束
			1.5,                # 快速预警
			70.0,               # 伤害
			rotating_beam_anim
		)

func example_breath_attack_combo():
	"""示例：连续喷射攻击组合"""
	# 三连喷射，角度逐渐变大
	var breath_angles = [30.0, 60.0, 90.0]
	var boss_pos = Vector2(200, 300)
	var target_pos = Vector2(600, 300)
	
	for i in range(breath_angles.size()):
		var angle = breath_angles[i]
		var warning = WarnSectorUtil.new()
		add_child(warning)
		
		warning.warning_finished.connect(_on_warning_finished)
		warning.damage_dealt.connect(_on_damage_dealt)
		
		# 延迟启动
		await get_tree().create_timer(i * 1.0).timeout
		
		var breath_combo_anim = get_node("BreathComboAnimationPlayer")
		warning.start_warning(
			boss_pos,
			target_pos,
			angle,              # 逐渐增大的角度
			2.0,                # 预警时间
			80.0 + i * 20.0,    # 逐渐增大的伤害
			breath_combo_anim
		)

func example_narrow_precision_strike():
	"""示例：精确窄角度打击"""
	var warning_precision = WarnSectorUtil.new()
	add_child(warning_precision)
	
	warning_precision.warning_finished.connect(_on_warning_finished)
	warning_precision.damage_dealt.connect(_on_damage_dealt)
	
	# 窄角度高精度攻击
	var precision_anim = get_node("PrecisionStrikeAnimationPlayer")
	warning_precision.start_warning(
		Vector2(300, 200),  # 起始位置
		Vector2(500, 400),  # 目标点
		20.0,               # 很窄的角度
		2.0,                # 预警时间
		200.0,              # 高伤害
		precision_anim
	)

func _on_warning_finished():
	"""预警结束回调"""
	print("扇形AOE预警结束")
	# 这里可以添加音效、震屏等效果

func _on_damage_dealt(damage_amount: float):
	"""造成伤害回调"""
	print("对玩家造成伤害: ", damage_amount)
	# 这里可以添加伤害数字显示、音效等

# 在boss脚本中的实际使用方法：
# 
# func boss_skill_dragon_breath():
#     """boss技能：龙息攻击"""
#     var warning = WarnSectorUtil.new()
#     add_child(warning)
#     
#     warning.warning_finished.connect(_on_breath_finished)
#     warning.damage_dealt.connect(_on_player_damaged)
#     
#     # 朝向玩家的龙息攻击
#     var boss_pos = global_position
#     var player_pos = get_tree().get_first_node_in_group("player").global_position
#     var dragon_breath_anim = get_node("DragonBreathAnimationPlayer")
#     
#     warning.start_warning(
#         boss_pos,
#         player_pos,
#         75.0,     # 龙息角度
#         3.5,      # 预警时间
#         180.0,    # 高伤害
#         dragon_breath_anim
#     )
