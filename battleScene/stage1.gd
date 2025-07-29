extends Node2D

#@export var joystick_left : VirtualJoystick

@export var slime_scene: PackedScene
@export var bat_scene: PackedScene
@export var frog_scene: PackedScene
@export var boss_robot_scene: PackedScene

@export var warning_scene: Control

var MIN_SPAWN_INTERVAL : float = 2.25
var next_spawn_interval : float = 4
var SPAWN_INTERVAL_DECREMENT : float = 0.05
var SLIME_MAX_SPAWN_INCREASE_THRESHOLD : int = 8
var SLIME_MIN_SPAWN_INCREASE_THRESHOLD : int = 10
var BAT_MAX_SPAWN_INCREASE_THRESHOLD : int = 10
var BAT_MIN_SPAWN_INCREASE_THRESHOLD : int = 15
var FROG_MIN_SPAWN_INCREASE_THRESHOLD : int = 15
var FROG_MAX_SPAWN_INCREASE_THRESHOLD : int = 20
var slime_min_spawn : int = 2
var slime_max_spawn : int = 4
var slime_upper_limit : int = 12
var bat_min_spawn : int = 1
var bat_max_spawn : int = 2
var bat_upper_limit : int = 8
var frog_min_spawn : int = 1
var frog_max_spawn : int = 1
var frog_upper_limit : int = 4

@export var monster_spawn_timer: Timer # Added new unified timer

@export var point: int
var monster_move_direction: int
var map_mechanism_num: float
var map_mechanism_num_max: float

var spawn_count : int = 0

var current_monster_count: int = 0
var max_monster_limit: int = 12
const MAX_MONSTER_CAP: int = 60
const MONSTER_LIMIT_INCREASE_INTERVAL: float = 6.0 # seconds
var monster_limit_increase_timer: float = 0.0

@export var layer_ui: CanvasLayer
@export var hp_bar: ProgressBar
@export var exp_bar: ProgressBar
@export var map_mechanism_bar: ProgressBar
@export var hp_num: Label
@export var score_label: Label
@export var gameover_label: Label
@export var victory_label: Label
@export var attr_label: RichTextLabel

@export var buff_box: HBoxContainer
var buff_manager: BuffManager

@export var now_time: Label
@export var current_multi: Label
@export var now_lv: Label
@export var exit_button: Button

@export var skill1: TextureButton
@export var skill2: TextureButton
@export var skill3: TextureButton
@export var skill4: TextureButton
@export var skill5: TextureButton
var skill1_remain_time :float
var skill2_remain_time :float
var skill3_remain_time :float
var skill4_remain_time :float
var skill5_remain_time :float

@export var lv_up_change: Node2D
@export var lv_up_change_b1: Button
@export var lv_up_change_b2: Button
@export var lv_up_change_b3: Button

# 升级管理器
var level_up_manager: LevelUpManager

# 主要是第一个场景的基本ui和出怪逻辑，包含了升级逻辑
func _ready() -> void:
	PC.player_instance = $Player
	# 连接技能攻速更新信号
	Global.connect("skill_attack_speed_updated", Callable(self, "update_skill_cooldowns"))
	Global.emit_signal("reset_camera")
	map_mechanism_num = 0
	map_mechanism_num_max = 10800
	
	# 重置DPS计数器
	Global.reset_dps_counter()
	
	# 初始化升级管理器
	level_up_manager = LevelUpManager.new()
	add_child(level_up_manager)
	var skill_nodes_array: Array[TextureButton] = [skill1, skill2, skill3, skill4]
	level_up_manager.initialize($CanvasLayer, lv_up_change, lv_up_change_b1, lv_up_change_b2, lv_up_change_b3, layer_ui, skill_nodes_array)
	
	Global.connect("player_lv_up", Callable(self, "_on_level_up"))
	Global.connect("level_up_selection_complete", Callable(self, "_check_and_process_pending_level_ups"))
	Global.connect("monster_mechanism_gained", Callable(self, "_on_monster_mechanism_gained"))
	Global.connect("boss_defeated", Callable(self, "_on_boss_defeated"))
	
	# 初始化buff管理器
	buff_manager = BuffManager.new()
	add_child(buff_manager)
	buff_manager.setup_buff_container(buff_box)
	
	skill1.visible = true
	skill1.update_skill(1, $Player.fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/slash.png")

	# Initialize and start the new monster spawn timer
	monster_spawn_timer = Timer.new()
	add_child(monster_spawn_timer)
	monster_spawn_timer.wait_time = 0.1 # Start almost immediately for the first spawn
	monster_spawn_timer.one_shot = false # Make it recurring
	monster_spawn_timer.connect("timeout", Callable(self, "_on_monster_spawn_timer_timeout"))
	monster_spawn_timer.start()
	
	# 测试添加一些buff（可以删除这部分）
	_test_buffs()
	
	# 初始化技能冷却时间显示
	update_skill_cooldowns()


func _process(delta: float) -> void:
	# 格式化分数显示
	var formatted_point: String
	if point >= 10000000:
		formatted_point = "%.2fm" % (point / 1000000.0)
	elif point >= 100000:
		formatted_point = "%.2fk" % (point / 1000.0)
	else:
		formatted_point = str(point)
	
	if PC.has_branch and PC.first_has_branch:
		skill2.visible = true
		skill2.update_skill(2, $Player.branch_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/branch.png")
		PC.first_has_branch = false

	if PC.has_moyan and PC.first_has_moyan:
		skill3.visible = true
		skill3.update_skill(3, $Player.moyan_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/moyan.png")
		PC.first_has_moyan = false

	if PC.has_riyan and PC.first_has_riyan:
		skill4.visible = true
		skill4.update_skill(4, $Player.riyan_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/riyan.png")
		PC.first_has_riyan = false

	if PC.has_ringFire and PC.first_has_ringFire:
		skill5.visible = true
		skill5.update_skill(5, $Player.ringFire_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/ringFire.png")
		PC.first_has_ringFire = false
	
	score_label.text = formatted_point
	
	# 更新DPS显示
	var current_dps = Global.get_current_dps()
	var formatted_dps = "%.1f" % current_dps
	current_multi.text = "DPS: " + formatted_dps
	
var boss_event_triggered: bool = false # 新增标志位，防止重复触发

# 更新技能冷却时间显示
func update_skill_cooldowns() -> void:
	# 更新主攻击技能
	if skill1.visible:
		skill1.update_skill(1, $Player.fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/slash.png")
	
	# 更新分支技能
	if PC.has_branch and skill2.visible:
		skill2.update_skill(2, $Player.branch_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/branch.png")
	
	# 更新魔焰技能
	if PC.has_moyan and skill3.visible:
		skill3.update_skill(3, $Player.moyan_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/moyan.png")
	
	# 更新日焰技能
	if PC.has_riyan and skill4.visible:
		skill4.update_skill(4, $Player.riyan_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/riyan.png")
	
	# 更新环形火焰技能
	if PC.has_ringFire and skill5.visible:
		skill5.update_skill(5, $Player.ringFire_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/ringFire.png")


func _physics_process(_delta: float) -> void:
	monster_limit_increase_timer += _delta
	if monster_limit_increase_timer >= MONSTER_LIMIT_INCREASE_INTERVAL:
		monster_limit_increase_timer = 0.0
		if max_monster_limit < MAX_MONSTER_CAP:
			max_monster_limit += 1

	if not boss_event_triggered:
		map_mechanism_num += _delta * 30
		# 随着时间增长，提高怪物的属性
	#print(PC.current_time,' ',slime_spawn_timer.wait_time,' ',bat_spawn_timer.wait_time,' ',frog_spawn_timer.wait_time)
	if PC.current_time < 0.3:
		PC.current_time = PC.current_time + 0.00024
	elif PC.current_time > 0.6 and PC.current_time <= 6.4:
		PC.current_time = PC.current_time + 0.00048
	else:
		PC.current_time = PC.current_time + 0.001
	
	if map_mechanism_num >= map_mechanism_num_max and not boss_event_triggered:
		boss_event_triggered = true
		_trigger_boss_event()
		return
	
	PC.real_time += _delta
	
	# 更新时间显示 (MM:ss 格式)
	if now_time:
		var minutes = int(PC.real_time) / 60
		var seconds = int(PC.real_time) % 60
		now_time.text = "%02d : %02d" % [minutes, seconds]
	
	if PC.pc_exp >= level_up_manager.get_required_lv_up_value(PC.pc_lv):
		level_up_manager.add_pending_level_up()
		PC.pc_lv += 1
		PC.pc_exp = clamp((PC.pc_exp - level_up_manager.get_required_lv_up_value(PC.pc_lv)), 0, level_up_manager.get_required_lv_up_value(PC.pc_lv))
		Global.emit_signal("player_lv_up")
		
	var target_value_hp = (float(PC.pc_hp) / PC.pc_max_hp) * 100
	if hp_bar.value != target_value_hp:
		if abs(target_value_hp - hp_bar.value) > 2:
			var tween = create_tween()
			tween.tween_property(hp_bar, "value", target_value_hp, 0.15)
		else:
			hp_bar.value = target_value_hp
		
	if PC.pc_hp <= 0:
		hp_num.text = '0 / ' + str(PC.pc_max_hp)
	else:
		hp_num.text = str(PC.pc_hp) + ' / ' + str(PC.pc_max_hp)
		
	if Global.is_level_up == false:
		lv_up_change.visible = false
		# 基础，黄酒，米酒，花果酒，枸杞酒，羊羔酒，锦江春，琼浆100/200/300/450/600/800/1000gil，进货价初始为30%，米饭150gil，进货价初始为33%，
		# 小料：太岁冻30gil，果味灯油50gil，
		# 小吃，蛙肉串80gil



		# 酒馆属性：知名度，每次狩猎后结算可以获得，每日经营也可以获得少量，可以解锁新的客人类型，并按比例提升菜单售价，每10点+1%
		# 客人：分几个类型，居民，纯消费，提供100%正常菜单额度，点1~2份饮品+1~2分餐食，佣兵会倾向于点2~3份饮品类+1份餐食类，冒险者会倾向于点餐食类，他们偶尔会讨论战斗技巧，提升对对应种类怪的伤害
		# 流动小贩会出售饰品，药剂师会提供强化药剂，铁匠可以帮忙以优惠的价格升级饰品或者厨具，大商人会额外给一份等值小费，贤者会给予一个只有在下次狩猎日有效的buff
		# 进货商可以减免一种商品的10%进货价
		
	var target_value = (float(PC.pc_exp) / level_up_manager.get_required_lv_up_value(PC.pc_lv)) * 100
	if exp_bar.value != target_value:
		if abs(target_value - exp_bar.value) > 2:
			var tween = create_tween()
			tween.tween_property(exp_bar, "value", target_value, 0.15)
		else:
			exp_bar.value = target_value
			
	if not boss_event_triggered:
		map_mechanism_bar.value = (map_mechanism_num / map_mechanism_num_max) * 100
	else:
		map_mechanism_bar.value = 100 # 例如设为满
	
	now_lv.text = "Lv."+str(PC.pc_lv)
	

func _trigger_boss_event() -> void:
	print("Boss event triggered!")
		# 每个人10岁都会觉醒一个天赋，坎塞尔拿到了一套厨具，开始他以为只是跟大部分人一样决定了他未来的职业
		# 但是直到后面得一次魔物入侵中，他用菜刀杀掉了一个魔物，发现菜刀不仅在一段时间内变得更锋利，而且魔物的一部分力量也被自身永久吸收了
		# 这个镇子是在边疆地带，经常有驻扎士兵和冒险者来这边，一边干掉魔物一边发展酒馆
		# 选择区域探索，每个区域有3个boss和1个隐藏Boss，
		# 每个boss击败后有概率收服，添加为酒馆服务员，3个boss都击败后，在狂暴模式下会出现隐藏boss

		# 外溢能量pp，在结束一局后可以转换为加点
		# t1 atk point+ hp max30(t2 40 t3 60 t4 100) total60->t2 
		# t2 atks spd cri% otherEquip
		# t3 exp% bulletSize criatk% max25 （t3 40 t4 60) total 60->t3
		# t4  atk% hp% point+ lky otherEquip max20(t4 40) total 60->t4
		# t5 finaldmg% def% otherEquip max20
		
		# 厨刀 可以飞射出去
		# 斩骨斧 近战武器
		# 釜 近战范围砸地
		# 匕 勺子，环绕
		# 笊篱 长柄漏勺 远程爆炸
		# 碾轮 直线范围
		# 漏勺 散射
		# 壶 类似树枝，分裂
		# 鼎 日炎
		# 每天可以选择作为经营日 狩猎日
		# 经营获得的gil可以强化厨具，提升厨具的基本atk%，解锁局内lv上限，从15->20->25
		# gil可以向旅行商人或者佣兵冒险者购买各种饰品和圣器，找镇里铁匠强化圣器，给服务员薪资礼物
		# 饰品只要获得就可以永久增加属性，圣器为战前启用初始2个，通过饰品解锁到最多同时5个
	#slime_spawn_timer.wait_time += 2.0
	#bat_spawn_timer.wait_time += 3.0
	#frog_spawn_timer.wait_time += 4.0
	
	 # 停止计时器，防止在warning期间继续生成小怪
	#slime_spawn_timer.stop() # Removed
	#bat_spawn_timer.stop() # Removed
	#frog_spawn_timer.stop() # Removed
	monster_spawn_timer.stop() # Stop the new timer
	
	# 获取场景中的warning节点
	var warning_node = get_node_or_null("CanvasLayer/Warning")
	if warning_node == null:
		print("ERROR: warning_tip node not found in scene!")
		return
	
	# 设置warning节点不受暂停影响
	warning_node.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 设置warning节点初始状态为不可见
	warning_node.visible = false
	warning_node.modulate = Color(1, 1, 1, 0)
	
	# 获取音频节点并播放
	var warning_audio = warning_node.get_node_or_null("warning") as AudioStreamPlayer
	if warning_audio:
		warning_audio.play()
	
	# 显示节点并开始动画
	warning_node.visible = true
	
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 设置tween不受暂停影响
	tween.set_process_mode(1)
	# 渐入动画
	tween.tween_property(warning_node, "modulate:a", 1.0, 0.5)
	# 持续显示2秒
	tween.tween_interval(2.0)
	# 渐出动画
	tween.tween_property(warning_node, "modulate:a", 0.0, 0.5)
	
	# 动画结束后隐藏节点
	tween.tween_callback(func(): warning_node.visible = false)
	
	_on_warning_finished()


func _on_warning_finished() -> void:
	# 重新启动计时器 (如果需要的话，或者根据游戏逻辑决定是否重启)
	# slime_spawn_timer.start() # Removed
	# bat_spawn_timer.start() # Removed
	# frog_spawn_timer.start() # Removed
	# monster_spawn_timer.start() # Restart the new timer if needed after boss, or handle differently
	await get_tree().create_timer(3).timeout
	
	Global.emit_signal("boss_bgm", 1)
	
	# 添加Boss
	var boss_node = boss_robot_scene.instantiate()
	
	# 逐步缩放相机，每0.2秒-0.1，总共10次达到-1
	for i in range(7):
		Global.emit_signal("zoom_camera", -0.08)
		await get_tree().create_timer(0.2).timeout

	boss_node.position = Vector2(-370, randf_range(185, 259))
	get_tree().current_scene.add_child(boss_node)


func _on_level_up_selection_complete() -> void:
	# 委托给升级管理器处理
	level_up_manager._on_level_up_selection_complete(get_viewport())

func _on_monster_spawn_timer_timeout() -> void:
	spawn_count += 1

	# Decrease next spawn interval
	next_spawn_interval = max(MIN_SPAWN_INTERVAL, next_spawn_interval - SPAWN_INTERVAL_DECREMENT)
	monster_spawn_timer.wait_time = next_spawn_interval

	# Adjust monster spawn limits based on spawn_count
	if spawn_count % SLIME_MAX_SPAWN_INCREASE_THRESHOLD == 0:
		slime_max_spawn = min(slime_max_spawn + 1, slime_upper_limit)
	if spawn_count % SLIME_MIN_SPAWN_INCREASE_THRESHOLD == 0:
		slime_min_spawn = min(slime_min_spawn + 1, slime_max_spawn) # Ensure min doesn't exceed max
	if spawn_count % BAT_MAX_SPAWN_INCREASE_THRESHOLD == 0:
		bat_max_spawn = min(bat_max_spawn + 1, bat_upper_limit)
	if spawn_count % BAT_MIN_SPAWN_INCREASE_THRESHOLD == 0:
		bat_min_spawn = min(bat_min_spawn + 1, bat_max_spawn)
	if spawn_count % FROG_MIN_SPAWN_INCREASE_THRESHOLD == 0:
		frog_min_spawn = min(frog_min_spawn + 1, frog_max_spawn)
	if spawn_count % FROG_MAX_SPAWN_INCREASE_THRESHOLD == 0:
		frog_max_spawn = min(frog_max_spawn + 1, frog_upper_limit)
		
	if current_monster_count >= max_monster_limit:
		return

	# Spawn monsters
	var num_slimes_to_spawn = randi_range(slime_min_spawn, slime_max_spawn)
	_spawn_slime(num_slimes_to_spawn)

	var num_bats_to_spawn = randi_range(bat_min_spawn, bat_max_spawn)
	_spawn_bat(num_bats_to_spawn)

	var num_frogs_to_spawn = randi_range(frog_min_spawn, frog_max_spawn)
	_spawn_frog(num_frogs_to_spawn)


func _spawn_slime(count: int) -> void:
	for _i in range(count):
		if current_monster_count >= max_monster_limit:
			return
		var slime_node = slime_scene.instantiate()
		
		# Determine spawn edge (0: top, 1: bottom, 2: left, 3: right)
		# hero最多4张，初始一张0，cd 30s 200以太，使用后需要等1分钟才能部署第3张，消耗400以太，cd 2分钟，第4张800以太
		# atk24.375-》48.75
		# 维德尼尔：攻击15 HP60 攻速0.8，skill1 攻击附带一枚羽毛，追踪一个单位造成30/38~70%%atk，skill2 消耗200以太，在12秒内，攻速+100%，并额外提升0/5~25%攻击
		# 被动 使用skill2后抽1张牌，skill2同时提升6%~30%暴击率
		# 5条进攻线路，初始有5排空间，商店解锁第6,7排，每个格子有6点容量
		# 右侧专有的能源区可以放向日葵，相当于一个容量18的格子，初始pp效率每秒+10
		# 向日葵，提升效率5+总体提升3%，消耗100pp，容量3
		# 豌豆射手，每次攻击消耗3以太，造成10伤害 攻速1，容量2，建造消耗150pp
		var spawn_edge = randi_range(0, 3)
		var spawn_position = Vector2.ZERO
		
		match spawn_edge:
			0: # Top
				spawn_position = Vector2(randf_range(-400, 400), -300)
				slime_node.move_direction = randi_range(2,8) # Move towards player (downwards bias)
			1: # Bottom
				spawn_position = Vector2(randf_range(-400, 400), 300)
				slime_node.move_direction = randi_range(2,8) # Move towards player (upwards bias)
			2: # Left
				spawn_position = Vector2(-400, randf_range(15, 259))
				if randf() < 0.1:
					slime_node.move_direction = 0 # Move right (away from player)
				else:
					slime_node.move_direction = randi_range(2,8) # Move towards player (rightwards bias)
			3: # Right
				spawn_position = Vector2(400, randf_range(15, 259))
				if randf() < 0.1:
					slime_node.move_direction = 1 # Move left (away from player)
				else:
					slime_node.move_direction = randi_range(2,8) # Move towards player (leftwards bias)
			# 各类型的牌基本实现
			# 向日葵
			# 豌豆射手
			# 菜问
			# 指挥官 200pp 一次性，提升周围2格范围内攻速20%，造成15伤害 攻速1，容量3
			# 基地建设 固有，0pp，获得1张向日葵
			# 振奋 50pp 给战斗单位添加4层振奋buff，每层提升10%攻击，每5秒损失1层
			# 整备预备 300pp 蓄能50：减少pp消耗 抽2张牌，每抽到1张单位牌回复50pp
			# 定点轰炸 150pp 随机选择地图上的1个目标，对其周围1格敌人造成15atk，重复10次
			# 卫护所 大型建筑，200pp，会对前一格每15秒产生一个容量2的卫护兵，攻击12 攻速1.2 hp50
			# 聚居地 大型建筑，100pp，对周围一格范围内的所有地块添加3点容量
			# 法师塔 大型建筑，150pp，atk25 aspd2 投射，范围全图 每次攻击消耗5pp
			# 高台 小型建筑，50pp，容量3，放置在该格的战斗单位变为投射并额外提升30%atk
			# 防御基底 大型建筑，50pp
			# 过载 50pp，提升100%pp获得，持续10秒，10秒后损失30%当前pp

		slime_node.position = spawn_position
		get_tree().current_scene.add_child(slime_node)
		current_monster_count += 1
		slime_node.connect("tree_exiting", Callable(self, "_on_monster_defeated"))

func _spawn_frog(count: int) -> void:
	for _i in range(count):
		if current_monster_count >= max_monster_limit:
			return
		var frog_node = frog_scene.instantiate()
		# Frog always spawns from left or right and moves towards player
		
		var spawn_side = randi_range(0,1) # 0 for left, 1 for right
		if spawn_side == 0:
			frog_node.position = Vector2(-400, randf_range(15, 259))
		else:
			frog_node.position = Vector2(400, randf_range(15, 259))
		# Frog move_direction is handled within its own script, typically towards player


		get_tree().current_scene.add_child(frog_node)
		current_monster_count += 1
		frog_node.connect("tree_exiting", Callable(self, "_on_monster_defeated"))

func _spawn_bat(count: int) -> void:
	for _i in range(count):
		if current_monster_count >= max_monster_limit:
			return
		var bat_node = bat_scene.instantiate()

		var spawn_edge = randi_range(0, 3)
		var spawn_position = Vector2.ZERO

		match spawn_edge:
			0: # Top
				spawn_position = Vector2(randf_range(-400, 400), -300)
				bat_node.move_direction = randi_range(2,8) # Move towards player (downwards bias)
			1: # Bottom
				spawn_position = Vector2(randf_range(-400, 400), 300)
				bat_node.move_direction = randi_range(2,8) # Move towards player (upwards bias)
			2: # Left
				spawn_position = Vector2(-400, randf_range(15, 244))
				if randf() < 0.1:
					bat_node.move_direction = 0 # Move right (away from player)
				else:
					bat_node.move_direction = randi_range(2,8) # Move towards player (rightwards bias)
			3: # Right
				spawn_position = Vector2(400, randf_range(15, 244))
				if randf() < 0.1:
					bat_node.move_direction = 1 # Move left (away from player)
				else:
					bat_node.move_direction = randi_range(2,8) # Move towards player (leftwards bias)

		bat_node.position = spawn_position
		get_tree().current_scene.add_child(bat_node)
		current_monster_count += 1
		bat_node.connect("tree_exiting", Callable(self, "_on_monster_defeated"))

func _on_monster_defeated():
	current_monster_count -= 1
	# 确保计数器不会变为负数
	current_monster_count = max(0, current_monster_count)
	
func show_game_over():
	gameover_label.visible = true
	# 等待2秒后返回主城
	await get_tree().create_timer(2).timeout
	Global.emit_signal("normal_bgm")
	# 返回主城
	SceneChange.change_scene("res://Scenes/main_town.tscn", true)

func _on_boss_defeated(get_point : int):
	if not PC.is_game_over:
		# 播放胜利音效
		$Victory.play()
		# 调用player_action.gd中的show_victory()函数
		victory_label.visible = true
		get_tree().current_scene.point += get_point
		Global.total_points += get_point
		Global.save_game()
		await get_tree().create_timer(4).timeout
		
		Global.emit_signal("normal_bgm")
		# 返回主菜单
		if Global.main_menu_instance != null:
			# 设置菜单状态
			Global.in_menu = true
			SceneChange.change_scene("res://Scenes/main_menu.tscn", true)


func _on_level_up(main_skill_name: String = '', refresh_id: int = 0):
	# 委托给升级管理器处理
	level_up_manager.handle_level_up(main_skill_name, refresh_id, get_tree(), get_viewport())
	

func _check_and_process_pending_level_ups():
	# 委托给升级管理器处理
	level_up_manager.check_and_process_pending_level_ups(get_tree(), get_viewport())


func _on_attr_button_focus_entered() -> void:
	attr_label.visible = true
	attr_label.text = "攻击：" + str(PC.pc_atk) + "  额外攻速：" + str(PC.pc_atk_speed) + "\n额外移速：" + str(PC.pc_speed) + "  弹体大小：" + str(PC.bullet_size) + "\n天命：" + str(PC.now_lunky_level) + "  减伤：" + str(PC.damage_reduction_rate)+ "\n暴击率：" + str(PC.crit_chance) + "  暴击伤害：" + str(PC.crit_damage_multiplier) + "\n环形剑气攻击/数量/大小/射速：" + str(PC.ring_bullet_damage_multiplier) + "/"+ str(PC.ring_bullet_count) + "/"+ str(PC.ring_bullet_size_multiplier) + "/"+ str(PC.ring_bullet_interval) + "/" + "\n召唤物数量/最大数量/攻击/弹体大小/射速：" + str(PC.summon_count)+ "/" + str(PC.summon_count_max)+ "/" + str(PC.summon_damage_multiplier)+ "/" + str(PC.summon_bullet_size_multiplier)+ "/" + str(PC.summon_interval_multiplier)+ "/" + "\n开悟获取：" + str(PC.selected_rewards)


func _on_attr_button_focus_exited() -> void:
	attr_label.visible = false


func _on_monster_mechanism_gained(mechanism_value: int) -> void:
	map_mechanism_num += mechanism_value

# 测试buff功能的函数（可以删除）
func _test_buffs():
	pass
	# # 等待一帧确保buff管理器完全初始化
	# await get_tree().process_frame
	
	# # 添加一些测试buff
	# buff_manager.add_buff("attack_boost", 15.0, 3)  # 攻击力提升，15秒，3层
	# buff_manager.add_buff("speed_boost", 8.0, 1)   # 移动速度提升，8秒，1层
	# buff_manager.add_buff("health_regen", 0.0, 1)  # 生命回复，永久buff
	
	# # 5秒后添加更多buff
	# await get_tree().create_timer(5.0).timeout
	# buff_manager.add_buff("crit_chance", 12.0, 5)  # 暴击率提升，12秒，5层
	# buff_manager.add_buff("damage_reduction", 6.0, 1)  # 伤害减免，6秒，1层
	
	# # 10秒后移除一个buff
	# await get_tree().create_timer(5.0).timeout
	# buff_manager.remove_buff("speed_boost")


func _on_skill_icon_1_mouse_entered() -> void:
	var skill1Text = "[font_size=32]剑气  LV. " + str(PC.main_skill_swordQi) +"[/font_size]" 
	skill1Text = skill1Text +  "\n基本伤害倍率： " + str((PC.main_skill_swordQi_damage * 100))  + "%"
	skill1Text = skill1Text +  "\n基本攻击速度：" + str(("%.2f" % ($Player.fire_speed.wait_time))) + "秒/次"
	skill1Text = skill1Text +  "\n附加效果："
	if PC.selected_rewards.has("SplitSwordQi1"):
		skill1Text = skill1Text +  "\n分光剑气"
	if PC.selected_rewards.has("SplitSwordQi2"):
		skill1Text = skill1Text +  "\n无上剑痕"
	if PC.selected_rewards.has("SplitSwordQi3"):
		skill1Text = skill1Text +  "\n穿云剑气"
	if PC.selected_rewards.has("SplitSwordQi4"):
		skill1Text = skill1Text +  "\n追踪剑气"
	if PC.selected_rewards.has("SplitSwordQi11"):
		skill1Text = skill1Text +  "\n分光剑气-逆"
	if PC.selected_rewards.has("SplitSwordQi12"):
		skill1Text = skill1Text +  "\n分光剑气-裂"
	if PC.selected_rewards.has("SplitSwordQi13"):
		skill1Text = skill1Text +  "\n分光剑气-环"
	if PC.selected_rewards.has("SplitSwordQi21"):
		skill1Text = skill1Text +  "\n无上剑痕-精"
	if PC.selected_rewards.has("SplitSwordQi22"):
		skill1Text = skill1Text +  "\n无上剑痕-复"
	if PC.selected_rewards.has("SplitSwordQi23"):
		skill1Text = skill1Text +  "\n无上剑痕-囚"
	if PC.selected_rewards.has("SplitSwordQi31"):
		skill1Text = skill1Text +  "\n穿云剑气-透"
	if PC.selected_rewards.has("SplitSwordQi32"):
		skill1Text = skill1Text +  "\n穿云剑气-利"
	if PC.selected_rewards.has("SplitSwordQi33"):
		skill1Text = skill1Text +  "\n穿云剑气-伤"

	$CanvasLayer/SkillLabel1.text = skill1Text
	$CanvasLayer/SkillLabel1.visible = true


func _on_skill_icon_1_mouse_exited() -> void:
	$CanvasLayer/SkillLabel1.visible = false


func _on_refresh_button_pressed() -> void:
	# 委托给升级管理器处理
	level_up_manager.handle_refresh_button(1, get_tree(), get_viewport())


func _on_refresh_button_2_pressed() -> void:
	# 委托给升级管理器处理
	level_up_manager.handle_refresh_button(2, get_tree(), get_viewport())


func _on_refresh_button_3_pressed() -> void:
	# 委托给升级管理器处理
	level_up_manager.handle_refresh_button(3, get_tree(), get_viewport())
