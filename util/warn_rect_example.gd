extends Node2D

# WarnRectUtil 使用示例
# 展示如何在boss脚本中使用矩形AOE预警工具

var WarnRectUtil = preload("res://Script/util/warn_rect_util.gd")

func _ready():
	# 示例：在boss脚本中使用
	example_boss_rect_skill()

func example_boss_rect_skill():
	"""示例：boss释放矩形AOE技能"""
	# 创建预警矩形
	var warning_rect = WarnRectUtil.new()
	add_child(warning_rect)
	
	# 连接信号
	warning_rect.warning_finished.connect(_on_warning_finished)
	warning_rect.damage_dealt.connect(_on_damage_dealt)
	
	# 开始预警
	# 参数：起始位置, 目标点, 宽度, 预警时间, 伤害, 动画播放器
	var laser_anim = get_node("LaserAnimationPlayer")  # 获取动画播放器
	warning_rect.start_warning(
		Vector2(200, 300),  # 起始位置
		Vector2(600, 300),  # 目标点（水平激光）
		80.0,               # 宽度
		2.5,                # 预警时间2.5秒
		90.0,               # 伤害值
		laser_anim          # 动画播放器
	)

func example_diagonal_laser():
	"""示例：对角线激光攻击"""
	var warning_diagonal = WarnRectUtil.new()
	add_child(warning_diagonal)
	
	warning_diagonal.warning_finished.connect(_on_warning_finished)
	warning_diagonal.damage_dealt.connect(_on_damage_dealt)
	
	# 对角线激光
	var diagonal_anim = get_node("DiagonalLaserAnimationPlayer")
	warning_diagonal.start_warning(
		Vector2(100, 100),  # 起始位置
		Vector2(700, 500),  # 目标点（对角线）
		60.0,               # 较窄的激光
		3.0,                # 预警时间3秒
		120.0,              # 高伤害
		diagonal_anim
	)

func example_player_targeted_beam():
	"""示例：指向玩家的光束攻击"""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var warning_beam = WarnRectUtil.new()
	add_child(warning_beam)
	
	warning_beam.warning_finished.connect(_on_warning_finished)
	warning_beam.damage_dealt.connect(_on_damage_dealt)
	
	# 从boss位置指向玩家的光束
	var boss_pos = Vector2(400, 200)  # boss位置
	var player_pos = player.global_position
	var beam_anim = get_node("BeamAnimationPlayer")
	
	warning_beam.start_warning(
		boss_pos,           # 起始位置（boss）
		player_pos,         # 目标点（玩家）
		100.0,              # 光束宽度
		2.0,                # 快速预警
		150.0,              # 高伤害
		beam_anim
	)

func example_multiple_laser_pattern():
	"""示例：多重激光阵列"""
	# 创建十字形激光阵列
	var center = Vector2(400, 300)
	var laser_patterns = [
		# 水平激光
		{"start": Vector2(100, 300), "end": Vector2(700, 300)},
		# 垂直激光
		{"start": Vector2(400, 100), "end": Vector2(400, 500)},
		# 对角线激光1
		{"start": Vector2(200, 200), "end": Vector2(600, 400)},
		# 对角线激光2
		{"start": Vector2(600, 200), "end": Vector2(200, 400)}
	]
	
	for i in range(laser_patterns.size()):
		var pattern = laser_patterns[i]
		var warning = WarnRectUtil.new()
		add_child(warning)
		
		warning.warning_finished.connect(_on_warning_finished)
		warning.damage_dealt.connect(_on_damage_dealt)
		
		# 延迟启动，创造连续效果
		await get_tree().create_timer(i * 0.3).timeout
		
		var cross_laser_anim = get_node("CrossLaserAnimationPlayer")
		warning.start_warning(
			pattern["start"],
			pattern["end"],
			50.0,               # 较细的激光
			1.8,                # 快速预警
			80.0,               # 中等伤害
			cross_laser_anim
		)

func example_sweeping_laser():
	"""示例：扫射激光"""
	# 创建从左到右的扫射效果
	var sweep_positions = [
		Vector2(100, 250),
		Vector2(200, 250),
		Vector2(300, 250),
		Vector2(400, 250),
		Vector2(500, 250)
	]
	
	for i in range(sweep_positions.size()):
		var pos = sweep_positions[i]
		var warning = WarnRectUtil.new()
		add_child(warning)
		
		warning.warning_finished.connect(_on_warning_finished)
		warning.damage_dealt.connect(_on_damage_dealt)
		
		# 短暂延迟创造扫射效果
		await get_tree().create_timer(i * 0.2).timeout
		
		var sweep_anim = get_node("SweepLaserAnimationPlayer")
		warning.start_warning(
			pos,                    # 起始位置
			pos + Vector2(0, 300),  # 垂直向下
			40.0,                   # 细激光
			1.0,                    # 快速预警
			60.0,                   # 伤害
			sweep_anim
		)

func _on_warning_finished():
	"""预警结束回调"""
	print("矩形AOE预警结束")
	# 这里可以添加音效、震屏等效果

func _on_damage_dealt(damage_amount: float):
	"""造成伤害回调"""
	print("对玩家造成伤害: ", damage_amount)
	# 这里可以添加伤害数字显示、音效等

# 在boss脚本中的实际使用方法：
# 
# func boss_skill_laser_beam():
#     """boss技能：激光光束"""
#     var warning = WarnRectUtil.new()
#     add_child(warning)
#     
#     warning.warning_finished.connect(_on_laser_finished)
#     warning.damage_dealt.connect(_on_player_damaged)
#     
#     # 从boss位置发射激光到玩家位置
#     var boss_pos = global_position
#     var player_pos = get_tree().get_first_node_in_group("player").global_position
#     var laser_anim = get_node("LaserAnimationPlayer")
#     
#     warning.start_warning(
#         boss_pos,
#         player_pos,
#         120.0,    # 激光宽度
#         3.0,      # 预警时间
#         200.0,    # 高伤害
#         laser_anim
#     )
