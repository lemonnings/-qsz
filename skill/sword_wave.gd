extends Area2D

# 子节点引用
var sword_wave_sprite: Sprite2D
var collision_shape: CollisionShape2D

# 定时器
var lifetime_timer: Timer
var damage_timer: Timer

var SWORD_WAVE_WIDTH = 0.8 * PC.bullet_size # 剑痕的宽度，可能作为Y轴的缩放值或绝对像素值

func _ready():
	# 获取子节点引用，请确保 swordWave.tscn 场景中包含名为 Sprite2D 和 CollisionShape2D 的子节点
	sword_wave_sprite = get_node_or_null("Sprite2D")
	collision_shape = get_node_or_null("CollisionShape2D")

	if not sword_wave_sprite:
		printerr("SwordWave: Sprite2D node not found!")
	if not collision_shape:
		printerr("SwordWave: CollisionShape2D node not found!")

	# 初始化生命周期定时器
	lifetime_timer = Timer.new()
	if PC.selected_rewards.has("SplitSwordQi21"):
		lifetime_timer.wait_time = 4.0
	else:
		lifetime_timer.wait_time = 3.0
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_timer_timeout)
	add_child(lifetime_timer)

	# 初始化伤害判定定时器
	damage_timer = Timer.new()
	damage_timer.wait_time = 0.25 # 每0.5秒检测一次伤害
	# damage_timer.one_shot = false # 默认就是 false，会重复触发
	damage_timer.timeout.connect(_on_damage_timer_timeout)
	add_child(damage_timer)

	# 注意：全局信号连接已从此脚本中移除。
	# 创建剑痕实例的逻辑应由一个管理器节点处理，该节点监听 Global.createSwordWave 信号，
	# 然后实例化此场景并调用 setup_wave 方法。

# 此方法应在剑痕场景实例化后，由创建者调用以完成初始化
func setup_wave(wave_target_position: Vector2):
	#print("SwordWave instance setup_wave called with target: ", wave_target_position)

	if PC.player_instance == null:
		printerr("SwordWave Error: PC.player_instance is null. Cannot create sword wave.")
		queue_free() # 无法获取玩家位置，直接销毁自身
		return

	var player_pos = PC.player_instance.global_position
	var distance = player_pos.distance_to(wave_target_position)

	# 设置剑痕的全局位置（玩家和目标点的中点）和朝向
	global_position = player_pos.lerp(wave_target_position, 0.5)
	look_at(wave_target_position)

	# 配置剑痕精灵的缩放
	if sword_wave_sprite:
		# 假设Sprite2D的原始尺寸适合通过scale.x设置长度，scale.y设置宽度
		# 如果Sprite2D的原始高度不是1，SWORD_WAVE_WIDTH可能需要调整或用作像素尺寸
		sword_wave_sprite.scale.x = (distance / 37.5) + 0.8
		if PC.selected_rewards.has("SplitSwordQi21"):
			sword_wave_sprite.scale.y = SWORD_WAVE_WIDTH * 1.25
		else:
			sword_wave_sprite.scale.y = SWORD_WAVE_WIDTH
	else:
		printerr("SwordWave Warning: sword_wave_sprite is null during setup_wave.")

	# 配置碰撞形状的大小
	if collision_shape and collision_shape.shape is RectangleShape2D:
		collision_shape.shape.size = Vector2(distance, SWORD_WAVE_WIDTH * 3.8)
	elif collision_shape:
		printerr("SwordWave Warning: collision_shape is not a RectangleShape2D or is null during setup_wave.")
	else:
		printerr("SwordWave Warning: collision_shape is null during setup_wave.")

	# 启动定时器
	lifetime_timer.start()
	damage_timer.start()

	# 设置初始透明度并开始渐变动画
	modulate.a = 0.0 # 确保从完全透明开始
	var tween = create_tween()
	# 阶段1: 0.5秒内，透明度从0到1
	tween.tween_property(self, "modulate:a", 0.5, 0.15)
	# 阶段2: 保持1.5秒
	tween.tween_interval(2.35)
	# 阶段3: 1秒内，透明度从1到0
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	# 总持续时间 0.5 + 1.5 + 1.0 = 3.0秒，与 lifetime_timer 匹配

func _on_lifetime_timer_timeout():
	queue_free()

func _on_damage_timer_timeout():
	# 检查节点是否仍然有效，以防在处理过程中被释放
	if not is_instance_valid(self):
		return

	var bodies = get_overlapping_areas()
	for body in bodies:	
		if PC.selected_rewards.has("SplitSwordQi23") and body.has_signal("debuff_applied"):
			body.emit_signal("debuff_applied", "slow")
		# 确保body也有效，并且是敌人且有受伤方法
		if body.is_in_group("enemies") and body.has_method("take_damage"):
			# 确保 PC.pc_atk 是有效的攻击力数值
			var damage = 0.1 * PC.pc_atk 
			body.take_damage(damage, false, false, "sword_wave") # 参数: 伤害值, 是否暴击, 是否召唤物伤害, 伤害类型

# _physics_process 通常用于每帧更新，如果剑痕创建后是静态的，则此函数可以为空或移除
# func _physics_process(delta):
# 	pass
