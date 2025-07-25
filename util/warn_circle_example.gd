extends Node2D

# WarnCircleUtil 使用示例
# 展示如何在boss脚本中使用圆形AOE预警工具

var WarnCircleUtil = preload("res://util/warn_circle_util.gd")

func _ready():
	# 示例：在boss脚本中使用
	example_boss_skill()

func example_boss_skill():
	"""示例：boss释放圆形AOE技能"""
	# 创建预警圆形
	var warning_circle = WarnCircleUtil.new()
	add_child(warning_circle)
	
	# 连接信号
	warning_circle.warning_finished.connect(_on_warning_finished)
	warning_circle.damage_dealt.connect(_on_damage_dealt)
	
	# 开始预警
	# 参数：位置, 长宽比, 半径, 预警时间, 伤害, 动画播放器
	var explosion_anim = get_node("ExplosionAnimationPlayer")  # 获取动画播放器
	warning_circle.start_warning(
		Vector2(400, 300),  # 生成位置
		1.0,                # 长宽比 (1.0 = 圆形)
		150.0,              # 半径
		3.0,                # 预警时间3秒
		75.0,               # 伤害值
		explosion_anim      # 动画播放器
	)

func example_boss_ellipse_skill():
	"""示例：boss释放椭圆形AOE技能"""
	var warning_ellipse = WarnCircleUtil.new()
	add_child(warning_ellipse)
	
	warning_ellipse.warning_finished.connect(_on_warning_finished)
	warning_ellipse.damage_dealt.connect(_on_damage_dealt)
	
	# 椭圆形AOE (长宽比2:1)
	var fire_wave_anim = get_node("FireWaveAnimationPlayer")  # 获取动画播放器
	warning_ellipse.start_warning(
		Vector2(500, 400),  # 生成位置
		2.0,                # 长宽比 (2.0 = 椭圆形，宽度是高度的2倍)
		200.0,              # 半径
		2.5,                # 预警时间2.5秒
		100.0,              # 伤害值
		fire_wave_anim      # 动画播放器
	)

func example_multiple_circles():
	"""示例：同时释放多个圆形AOE"""
	var positions = [
		Vector2(300, 200),
		Vector2(500, 200),
		Vector2(400, 350)
	]
	
	for pos in positions:
		var warning = WarnCircleUtil.new()
		add_child(warning)
		
		warning.warning_finished.connect(_on_warning_finished)
		warning.damage_dealt.connect(_on_damage_dealt)
		
		# 小范围快速AOE
		var small_explosion_anim = get_node("SmallExplosionAnimationPlayer")
		warning.start_warning(
			pos,
			1.0,    # 圆形
			80.0,   # 小半径
			1.5,    # 快速预警
			50.0,   # 中等伤害
			small_explosion_anim
		)

func _on_warning_finished():
	"""预警结束回调"""
	print("AOE预警结束")
	# 这里可以添加音效、震屏等效果

func _on_damage_dealt(damage_amount: float):
	"""造成伤害回调"""
	print("对玩家造成伤害: ", damage_amount)
	# 这里可以添加伤害数字显示、音效等

# 在boss脚本中的实际使用方法：
# 
# func boss_skill_fire_rain():
#     """boss技能：火雨"""
#     var warning = WarnCircleUtil.new()
#     add_child(warning)
#     
#     warning.warning_finished.connect(_on_fire_rain_finished)
#     warning.damage_dealt.connect(_on_player_damaged)
#     
#     # 在玩家当前位置生成大范围AOE
#     var player_pos = get_tree().get_first_node_in_group("player").global_position
#     var fire_explosion_anim = get_node("FireExplosionAnimationPlayer")
#     warning.start_warning(
#         player_pos,
#         1.0,      # 圆形
#         250.0,    # 大范围
#         4.0,      # 较长预警时间
#         120.0,    # 高伤害
#         fire_explosion_anim
#     )