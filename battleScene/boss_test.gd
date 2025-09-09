extends Node2D

@export var slime_scene: PackedScene
@export var boss_scene: PackedScene

@export var slime_spawn_timer: Timer

@export var point: int
var monster_move_direction: int

@export var hp_bar: ProgressBar
@export var exp_bar: ProgressBar
@export var hp_num: Label
@export var score_label: Label
@export var gameover_label: Label
@export var attr_label: RichTextLabel
var pending_level_ups: int = 0

@export var lv_up_change: Node2D
@export var lv_up_change_b1: Button
@export var lv_up_change_b2: Button
@export var lv_up_change_b3: Button

# 主要是第一个场景的基本ui和出怪逻辑，包含了升级逻辑
func _ready() -> void:
	PC.player_instance = $Player
	Global.connect("player_lv_up", Callable(self, "_on_level_up"))
	Global.connect("level_up_selection_complete", Callable(self, "_check_and_process_pending_level_ups"))
	var boss_node = boss_scene.instantiate()
	boss_node.position = Vector2(370, randf_range(165, 244))
	get_tree().current_scene.add_child(boss_node)

func _process(delta: float) -> void:
	
	# 计算时间出怪
	slime_spawn_timer.wait_time -= 0.06 * delta
	slime_spawn_timer.wait_time = clamp(slime_spawn_timer.wait_time, 0.3, 2.2)
	
	score_label.text = "Point  " + str(point)
	
func _physics_process(_delta: float) -> void:
	# 随着时间增长，提高怪物的属性
	if PC.current_time < 0.3:
		PC.current_time = PC.current_time + 0.00034
	elif PC.current_time >= 0.3 and PC.current_time <= 1.2:
		PC.current_time = PC.current_time + 0.001
	elif PC.current_time > 1.2 and PC.current_time <= 4:
		PC.current_time = PC.current_time + 0.003
	elif PC.current_time > 4 and PC.current_time <= 12:
		PC.current_time = PC.current_time + 0.009
	elif PC.current_time > 12 and PC.current_time <= 48:
		PC.current_time = PC.current_time + 0.027
	elif PC.current_time > 48 and PC.current_time <= 192:
		PC.current_time = PC.current_time + 0.081
	else:
		PC.current_time = PC.current_time + 0.486
	# print(PC.current_time)
	
	if PC.pc_exp >= get_required_lv_up_value(PC.pc_lv):
		pending_level_ups += 1
		PC.pc_lv += 1
		PC.pc_exp = clamp((PC.pc_exp - get_required_lv_up_value(PC.pc_lv)), 0, get_required_lv_up_value(PC.pc_lv))
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
		
	var target_value = (float(PC.pc_exp) / get_required_lv_up_value(PC.pc_lv)) * 100
	if exp_bar.value != target_value:
		if abs(target_value - exp_bar.value) > 2:
			var tween = create_tween()
			tween.tween_property(exp_bar, "value", target_value, 0.15)
		else:
			exp_bar.value = target_value


func _spawn_slime() -> void:
	var slime_node = slime_scene.instantiate()
	monster_move_direction = randi_range(0, 1)
	slime_node.move_direction = monster_move_direction
	if monster_move_direction == 0:
		slime_node.position = Vector2(-370, randf_range(165, 244))
	if monster_move_direction == 1:
		slime_node.position = Vector2(370, randf_range(165, 244))
	get_tree().current_scene.add_child(slime_node)


func show_game_over():
	gameover_label.visible = true



func get_required_lv_up_value(level: int) -> float:
	var value: float = 1000
	for i in range(level):
		value = (value + 300) * 1.09
	return value

func _on_level_up():
	pending_level_ups -= 1
	await get_tree().create_timer(0.15).timeout
	Global.is_level_up = true
	get_tree().set_pause(true)
	lv_up_change.visible = true
	PC.last_speed = PC.pc_speed
	PC.last_atk_speed = PC.pc_atk_speed
	PC.last_lunky_level = PC.now_lunky_level
	# 确定刷出来的三个升级奖励的等级
	var r1_rand = randf_range(0, 100)
	var r2_rand = randf_range(0, 100)
	var r3_rand = randf_range(0, 100)
	var reward1 = get_reward_level(r1_rand)
	var reward2 = get_reward_level(r2_rand)
	var reward3 = get_reward_level(r3_rand)
	var lvcb1: Sprite2D = lv_up_change_b1.get_node("Pic")
	lvcb1.region_rect = reward1.icon
	var lvcbd1: RichTextLabel = lv_up_change_b1.get_node("Detail")
	lvcbd1.text = reward1.text
	var callbackB1: Callable = reward1.on_selected
	var connect_array = lv_up_change_b1.pressed.get_connections()
	if !connect_array.is_empty():
		lv_up_change_b1.pressed.disconnect(connect_array[0].get("callable"))
	lv_up_change_b1.pressed.connect(callbackB1)
	
	var lvcb2: Sprite2D = lv_up_change_b2.get_node("Pic")
	lvcb2.region_rect = reward2.icon
	var lvcbd2: RichTextLabel = lv_up_change_b2.get_node("Detail")
	lvcbd2.text = reward2.text
	var callbackB2: Callable = reward2.on_selected
	var connect_array2 = lv_up_change_b2.pressed.get_connections()
	if !connect_array2.is_empty():
		lv_up_change_b2.pressed.disconnect(connect_array2[0].get("callable"))
	lv_up_change_b2.pressed.connect(callbackB2)
	
	var lvcb3: Sprite2D = lv_up_change_b3.get_node("Pic")
	lvcb3.region_rect = reward3.icon
	var lvcbd3: RichTextLabel = lv_up_change_b3.get_node("Detail")
	lvcbd3.text = reward3.text
	var callbackB3: Callable = reward3.on_selected
	var connect_array3 = lv_up_change_b3.pressed.get_connections()
	if !connect_array3.is_empty():
		lv_up_change_b3.pressed.disconnect(connect_array3[0].get("callable"))
	lv_up_change_b3.pressed.connect(callbackB3)


func _check_and_process_pending_level_ups():
	if pending_level_ups > 0:
		_on_level_up()

func get_reward_level(rand_num: float) -> LvUp.Reward:
	if rand_num <= PC.now_gold_p:
		return LvUp.unbelievable_gold()
	elif rand_num <= PC.now_orange_p + PC.now_gold_p:
		return LvUp.super2_rare_orange()
	elif rand_num <= PC.now_purple_p + PC.now_orange_p + PC.now_gold_p:
		return LvUp.super_rare_purple()
	elif rand_num <= PC.now_blue_p + PC.now_purple_p + PC.now_orange_p + PC.now_gold_p:
		return LvUp.rare_blue()
	elif rand_num <= PC.now_green_p + PC.now_blue_p + PC.now_purple_p + PC.now_orange_p + PC.now_gold_p:
		return LvUp.pro_green()
	return LvUp.normal_white()

func _on_attr_button_focus_entered() -> void:
	attr_label.visible = true
	attr_label.text = "攻击：" + str(PC.pc_atk) + "  额外攻速：" + str(PC.pc_atk_speed) + "\n额外移速：" + str(PC.pc_speed) + "  弹体大小：" + str(PC.bullet_size) + "\n天命：" + str(PC.now_lunky_level) + "  减伤：" + str(PC.damage_reduction_rate)+ "\n暴击率：" + str(PC.crit_chance) + "  暴击伤害：" + str(PC.crit_damage_multi) + "\n环形剑气攻击/数量/大小/射速：" + str(PC.ring_bullet_damage_multiplier) + "/"+ str(PC.ring_bullet_count) + "/"+ str(PC.ring_bullet_size_multiplier) + "/"+ str(PC.ring_bullet_interval) + "/" + "\n召唤物数量/最大数量/攻击/弹体大小/射速：" + str(PC.summon_count)+ "/" + str(PC.summon_count_max)+ "/" + str(PC.summon_damage_multiplier)+ "/" + str(PC.summon_bullet_size_multiplier)+ "/" + str(PC.summon_interval_multiplier)+ "/" + "\n开悟获取：" + str(PC.selected_rewards)


func _on_attr_button_focus_exited() -> void:
	attr_label.visible = false
