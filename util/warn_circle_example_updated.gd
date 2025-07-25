extends Node2D

# WarnCircleUtil 更新后的使用示例
# 展示两种释放模式的使用方法

var WarnCircleUtil = preload("res://util/warn_circle_util.gd")

func _ready():
	# 示例：在boss脚本中使用两种模式
	example_instant_damage_mode()
	await get_tree().create_timer(5.0).timeout
	example_persistent_area_mode()

func example_instant_damage_mode():
	"""示例：模式1 - 直接伤害判定模式（原有模式）"""
	print("演示模式1：直接伤害判定")
	
	# 创建预警圆形
	var warning_circle = WarnCircleUtil.new()
	add_child(warning_circle)
	
	# 连接信号
	warning_circle.warning_finished.connect(_on_instant_warning_finished)
	warning_circle.damage_dealt.connect(_on_damage_dealt)
	
	# 开始预警 - 使用默认的直接伤害模式
	var explosion_anim = get_node_or_null("ExplosionAnimationPlayer")
	warning_circle.start_warning(
		Vector2(300, 200),  # 位置
		1.0,                # 长宽比（圆形）
		100.0,              # 半径
		3.0,                # 预警时间
		80.0,               # 伤害值
		explosion_anim,     # 动画播放器
		WarnCircleUtil.ReleaseMode.INSTANT_DAMAGE,  # 模式1：直接伤害
		null,               # 区域精灵场景
		0.0,                # 持续时间
		"explosion_damage"  # 爆炸伤害效果
	)

func example_persistent_area_mode():
	"""示例：模式2 - 持续区域效果模式"""
	print("演示模式2：持续区域效果")
	
	# 创建预警圆形
	var warning_circle = WarnCircleUtil.new()
	add_child(warning_circle)
	
	# 连接信号
	warning_circle.warning_finished.connect(_on_persistent_warning_finished)
	warning_circle.area_entered.connect(_on_player_entered_area)
	warning_circle.area_exited.connect(_on_player_exited_area)
	warning_circle.area_effect_triggered.connect(_on_area_effect_triggered)
	
	# 加载区域精灵场景（需要预先创建）
	var area_sprite_scene = preload("res://effects/fire_area_sprite.tscn")  # 示例路径
	
	# 开始预警 - 使用持续区域模式
	var fire_anim = get_node_or_null("FireAnimationPlayer")
	warning_circle.start_warning(
		Vector2(500, 300),  # 位置
		1.0,                # 长宽比（圆形）
		120.0,              # 半径
		2.5,                # 预警时间
		0.0,                # 伤害值（持续区域模式下可以为0）
		fire_anim,          # 动画播放器
		WarnCircleUtil.ReleaseMode.PERSISTENT_AREA,  # 模式2：持续区域
		area_sprite_scene,  # 区域精灵场景
		8.0,                # 持续时间8秒
		"fire_damage"       # 火焰伤害效果
	)

func example_permanent_area():
	"""示例：永久持续区域"""
	var warning_circle = WarnCircleUtil.new()
	add_child(warning_circle)
	
	warning_circle.area_entered.connect(_on_permanent_area_entered)
	warning_circle.area_exited.connect(_on_permanent_area_exited)
	
	# 永久区域（area_duration = -1）
	var healing_sprite_scene = preload("res://effects/healing_area_sprite.tscn")
	warning_circle.start_warning(
		Vector2(400, 400),
		1.0,
		80.0,
		2.0,
		0.0,
		null,
		WarnCircleUtil.ReleaseMode.PERSISTENT_AREA,
		healing_sprite_scene,
		-1.0,               # 永久持续
		"healing_effect"    # 治疗效果
	)

func example_ellipse_persistent_area():
	"""示例：椭圆形持续区域"""
	var warning_circle = WarnCircleUtil.new()
	add_child(warning_circle)
	
	warning_circle.area_entered.connect(_on_ellipse_area_entered)
	
	# 椭圆形持续区域
	var poison_sprite_scene = preload("res://effects/poison_area_sprite.tscn")
	warning_circle.start_warning(
		Vector2(200, 300),
		2.0,                # 长宽比2:1（椭圆）
		100.0,
		3.0,
		0.0,
		null,
		WarnCircleUtil.ReleaseMode.PERSISTENT_AREA,
		poison_sprite_scene,
		5.0,                # 持续时间
		"poison_damage"     # 毒素伤害效果
	)

# 信号回调函数
func _on_instant_warning_finished():
	print("直接伤害模式预警结束")

func _on_persistent_warning_finished():
	print("持续区域模式预警结束，区域已生成")

func _on_damage_dealt(damage_amount: float):
	print("对玩家造成伤害: ", damage_amount)

func _on_player_entered_area(player_node: Node2D):
	print("玩家进入火焰区域！")
	# 在这里可以添加持续伤害、减速等效果
	# 例如：
	if player_node.has_method("apply_burn_effect"):
		player_node.apply_burn_effect()
	# 或者触发减速
	if player_node.has_method("apply_slow_effect"):
		player_node.apply_slow_effect(0.5)  # 减速50%

func _on_player_exited_area(player_node: Node2D):
	print("玩家离开火焰区域")
	# 移除效果
	if player_node.has_method("remove_burn_effect"):
		player_node.remove_burn_effect()
	if player_node.has_method("remove_slow_effect"):
		player_node.remove_slow_effect()

func _on_area_effect_triggered(player: Node2D, effect_type: String):
	"""处理区域效果触发"""
	print("触发区域效果: ", effect_type)
	
	match effect_type:
		"fire_damage":
			if player.has_method("take_damage"):
				player.take_damage(10.0)  # 火焰伤害
			if player.has_method("apply_burn_effect"):
				player.apply_burn_effect(2.0)  # 燃烧效果持续2秒
			
		"healing_effect":
			if player.has_method("heal"):
				player.heal(15.0)  # 治疗15点生命值
			if player.has_method("apply_regeneration"):
				player.apply_regeneration(5.0)  # 再生效果持续5秒
			
		"poison_damage":
			if player.has_method("take_damage"):
				player.take_damage(8.0)  # 毒素伤害
			if player.has_method("apply_poison"):
				player.apply_poison(3.0)  # 中毒效果持续3秒
			
		"explosion_damage":
			if player.has_method("take_damage"):
				player.take_damage(50.0)  # 爆炸伤害
			if player.has_method("apply_knockback"):
				player.apply_knockback(global_position, 300.0)  # 击退效果
			
		"slow_effect":
			if player.has_method("apply_slow"):
				player.apply_slow(0.5, 4.0)  # 减速50%，持续4秒
			
		"speed_boost":
			if player.has_method("apply_speed_boost"):
				player.apply_speed_boost(1.5, 6.0)  # 加速50%，持续6秒
			
		_:
			print("未知效果类型: ", effect_type)

func _on_permanent_area_entered(player_node: Node2D):
	print("玩家进入治疗区域")
	# 添加治疗效果
	if player_node.has_method("apply_healing_effect"):
		player_node.apply_healing_effect()

func _on_permanent_area_exited(player_node: Node2D):
	print("玩家离开治疗区域")
	# 移除治疗效果
	if player_node.has_method("remove_healing_effect"):
		player_node.remove_healing_effect()

func _on_ellipse_area_entered(player_node: Node2D):
	print("玩家进入毒雾区域")
	# 添加中毒效果
	if player_node.has_method("apply_poison_effect"):
		player_node.apply_poison_effect()

# 在boss脚本中的实际使用示例：
#
# func boss_skill_fire_trap():
#     """Boss技能：火焰陷阱"""
#     var warning = WarnCircleUtil.new()
#     add_child(warning)
#     
#     warning.area_entered.connect(_on_fire_trap_entered)
#     warning.area_exited.connect(_on_fire_trap_exited)
#     
#     var fire_sprite_scene = preload("res://effects/fire_trap_sprite.tscn")
#     var target_pos = get_player_position()  # 获取玩家位置
#     
#     warning.start_warning(
#         target_pos,
#         1.0,      # 圆形
#         150.0,    # 半径
#         2.0,      # 预警时间
#         0.0,      # 不造成直接伤害
#         null,
#         WarnCircleUtil.ReleaseMode.PERSISTENT_AREA,
#         fire_sprite_scene,
#         10.0      # 持续10秒
#     )
#
# func _on_fire_trap_entered(player: Node2D):
#     # 玩家进入火焰陷阱，开始持续伤害
#     start_continuous_damage(player, 20.0)  # 每秒20点伤害
#
# func _on_fire_trap_exited(player: Node2D):
#     # 玩家离开火焰陷阱，停止持续伤害
#     stop_continuous_damage(player)