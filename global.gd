extends Node

const CONFIG_PATH = "user://game_config.cfg"

# 合成界面状态 - 用于禁用缩放等操作
var in_synthesis: bool = false

# Buff配置管理器（需要在项目设置中设置为自动加载）
var SettingBuff = preload("res://Script/config/setting_buff.gd").new()

# 纹章配置管理器
var SettingEmblem = preload("res://Script/config/setting_emblem.gd").new()

# 音频管理器
var AudioManager = preload("res://Script/system/audio_manager.gd").new()

# 设置管理器
var SettingsManager = preload("res://Script/system/settings_manager.gd").new()

# 柔光滤镜管理器
var SoftGlowManager = preload("res://Script/system/soft_glow_manager.gd").new()

# 主动技能管理器
var ActiveSkillManager = preload("res://Script/config/active_skill_manager.gd").new()

# 装备管理器
var EquipmentManager = preload("res://Script/config/equipment_manager.gd").new()

@export var total_points: int = 1000

@export var max_main_skill_num: int = 3

# 纹章相关字段
@export var emblem_slots_max: int = 4 # 纹章数量上限

# 果实回复效果
@export var fruit_heal_multi: float = 1
@export var fruit_heal_multi_used_count: int = 0 # 回春露已使用次数（最多10次）

# 抽卡有关
@export var lunky_level: int = 1
@export var red_p: float = 3.5
@export var gold_p: float = 10
@export var purple_p: float = 18
@export var blue_p: float = 25
@export var green_p: float = 30

# 刷新次数
@export var refresh_max_num: int = 3

# 修炼解锁进度Cultivation
@export var cultivation_unlock_progress: int = 0

# 装备系统相关
@export var max_carry_equipment_slots: int = 2 # 当前解锁的随身法宝槽位数量（初始2个，最大5个）

# 修炼等级变量
@export var cultivation_poxu_level: int = 0 # 破虚 - 提升攻击力
@export var cultivation_xuanyuan_level: int = 0 # 玄元 - 提升生命值
@export var cultivation_liuguang_level: int = 0 # 流光 - 提升攻速
@export var cultivation_hualing_level: int = 0 # 化灵 - 提升灵气获取
@export var cultivation_fengrui_level: int = 0 # 锋锐 - 提升暴击率
@export var cultivation_huti_level: int = 0 # 护体 - 提升减伤率
@export var cultivation_zhuifeng_level: int = 0 # 追风 - 提升移速
@export var cultivation_liejin_level: int = 0 # 烈劲 - 提升暴击伤害

# 修炼等级上限
@export var cultivation_poxu_level_max: int = 50 # 破虚 - 提升攻击力
@export var cultivation_xuanyuan_level_max: int = 50 # 玄元 - 提升生命值
@export var cultivation_liuguang_level_max: int = 25 # 流光 - 提升攻速
@export var cultivation_hualing_level_max: int = 50 # 化灵 - 提升灵气获取
@export var cultivation_fengrui_level_max: int = 25 # 锋锐 - 提升暴击率
@export var cultivation_huti_level_max: int = 25 # 护体 - 提升减伤率
@export var cultivation_zhuifeng_level_max: int = 25 # 追风 - 提升移速
@export var cultivation_liejin_level_max: int = 50 # 烈劲 - 提升暴击伤害

# 玩家修习技能数据 - 按玩家名存储
@export var player_study_data: Dictionary = {
	"yiqiu": {
		"study_level": 0, # 当前修习阶段
		"learned_skills": [], # 已学习的技能列表
		"skill_levels": {} # 技能等级
	}
}

@export var player_active_skill_data: Dictionary = {
	"dodge": {
		"level": 1, # 习得等级；闪避：等级1，向移动方向位移一小段距离并无敌0.3秒，冷却6秒；等级2,4,6,8,10,12,14，无敌时间+0.1秒；等级3，5，7，9，11，13，15，冷却时间-0.5秒秒
		"learned": [] # 特殊效果
	},
	"random_strike": {
		"level": 1, # 习得等级；乱击：等级1，向随机方向每0.1秒射出1发剑气，造成50%攻击的伤害，共10发，冷却20秒；等级2,5,8,11,14，伤害比率+5%；等级3，6，9，12，15，射出子弹+1，等级4，7，10，13，冷却时间-1秒秒
		"learned": [] # 特殊效果
	}
}


@export var player_now_active_skill: Dictionary = {
	"space": {
		"name": "dodge"
	},
	"q": {
		"name": "random_strike"
	},
	"e": {
		"name": ""
	}
}

# 世界等级（难度级）
@export var world_level_multiple: float = 1
@export var world_level_reward_multiple: float = 1
@export var world_level: int = 1

@export var in_menu: bool = true
@export var in_town: bool = false

@export var is_level_up: bool = false

@export var main_menu_instance: PackedScene = null

# 鼠标动画通过autoload管理

signal player_hit(attacker: Node2D)
signal player_lv_up
signal lucky_level_up
signal setup_summons
signal level_up_selection_complete
signal monster_damage
signal monster_mechanism_gained
signal boss_defeated
signal skill_attack_speed_updated

# 对话相关
signal start_dialog(dialog_file_path: String) # Signal to start a dialog sequence

# bgm切换
signal boss_bgm
signal normal_bgm

# 影机相关
signal zoom_camera
signal reset_camera

# Boss血条控制信号
signal boss_hp_bar_show
signal boss_hp_bar_hide
signal boss_hp_bar_initialize(max_hp: float, current_hp: float, bar_num: int)
signal boss_hp_bar_take_damage(damage: float)

# Buff系统信号
signal buff_added(buff_id: String, duration: float, stack: int)
signal buff_removed(buff_id: String)
signal buff_updated(buff_id: String, remaining_time: float, stack: int)
signal buff_stack_changed(buff_id: String, new_stack: int)

# 纹章系统信号
signal emblem_added(emblem_id: String, stack: int)
signal emblem_removed(emblem_id: String)
signal emblem_stack_changed(emblem_id: String, new_stack: int)

# 攻击相关
signal skill_cooldown_complete
signal skill_cooldown_complete_branch
signal skill_cooldown_complete_moyan
signal skill_cooldown_complete_riyan
signal skill_cooldown_complete_ringFire

# 其他攻击方式相关
signal riyan_damage_triggered
signal ringFire_damage_triggered

# 剑气相关
signal createSwordWave
signal _fire_ring_bullets

# 掉落
signal drop_out_item(item_id: String, quantity: int, position: Vector2)

# 对话键
signal press_f
signal press_g
signal press_h

# 玩家背包
var player_inventory = {}

# 合成书获取进度 - 记录每个合成篇章是否已解锁
# 格式: {"recipe_id": bool}
@export var recipe_unlock_progress = {
	"recipe_001": true,
	"recipe_002": false,
	"recipe_003": false,
	"recipe_004": false,
	"recipe_noam": false
}

# DPS计数器相关
var dps_damage_records = [] # 存储过去30秒的伤害记录
@export var current_dps: float = 0.0 # 当前DPS值
var dps_timer: Timer # DPS计算定时器


func _ready() -> void:
	Global.monster_damage.connect(_on_monster_damage)
	
	# 初始化buff配置管理器
	add_child(SettingBuff)
	
	# 初始化纹章配置管理器
	add_child(SettingEmblem)
	
	# 初始化音频管理器
	add_child(AudioManager)
	
	# 初始化柔光滤镜管理器
	add_child(SoftGlowManager)
	
	# 初始化设置管理器
	add_child(SettingsManager)
	
	# 初始化装备管理器
	add_child(EquipmentManager)
	
	# 初始化主动技能管理器
	add_child(ActiveSkillManager)
	
	# 初始化DPS计时器
	dps_timer = Timer.new()
	dps_timer.wait_time = 1.0 # 每秒计算一次DPS
	dps_timer.timeout.connect(_calculate_dps)
	dps_timer.autostart = false
	add_child(dps_timer)
	
	# 游戏启动时立即加载鼠标动画
	MouseAnimation.start_mouse_animation()

func _input(event: InputEvent) -> void:
	# 全局快捷键：F1打开音频设置
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			show_audio_settings()

# 显示音频设置UI的全局函数
func show_audio_settings() -> void:
	var current_scene = get_tree().current_scene
	if current_scene:
		# 检查是否已经有音频设置UI打开
		var existing_ui = current_scene.get_node_or_null("AudioSettingsUI")
		if existing_ui:
			existing_ui.queue_free()
		else:
			var audio_ui = AudioSettingsUI.show_audio_settings(current_scene)
			audio_ui.name = "AudioSettingsUI"


func save_game() -> void:
	var config = ConfigFile.new()
	var data = {
		"total_points": total_points,
		"world_level": world_level,
		"world_level_multiple": world_level_multiple,
		"world_level_reward_multiple": world_level_reward_multiple,
		"lunky_level": lunky_level,
		"red_p": red_p,
		"gold_p": gold_p,
		"purple_p": purple_p,
		"blue_p": blue_p,
		"green_p": green_p,
		"player_inventory": player_inventory,
		"max_main_skill_num": max_main_skill_num,
		"refresh_max_num": refresh_max_num,
		"recipe_unlock_progress": recipe_unlock_progress,
		"cultivation_unlock_progress": cultivation_unlock_progress,
		"cultivation_poxu_level": cultivation_poxu_level,
		"cultivation_xuanyuan_level": cultivation_xuanyuan_level,
		"cultivation_liuguang_level": cultivation_liuguang_level,
		"cultivation_hualing_level": cultivation_hualing_level,
		"cultivation_fengrui_level": cultivation_fengrui_level,
		"cultivation_huti_level": cultivation_huti_level,
		"cultivation_zhuifeng_level": cultivation_zhuifeng_level,
		"cultivation_liejin_level": cultivation_liejin_level,
		"fruit_heal_multi": fruit_heal_multi,
		"fruit_heal_multi_used_count": fruit_heal_multi_used_count,
		# 修炼等级上限
		"cultivation_poxu_level_max": cultivation_poxu_level_max,
		"cultivation_xuanyuan_level_max": cultivation_xuanyuan_level_max,
		"cultivation_liuguang_level_max": cultivation_liuguang_level_max,
		"cultivation_hualing_level_max": cultivation_hualing_level_max,
		"cultivation_fengrui_level_max": cultivation_fengrui_level_max,
		"cultivation_huti_level_max": cultivation_huti_level_max,
		"cultivation_zhuifeng_level_max": cultivation_zhuifeng_level_max,
		"cultivation_liejin_level_max": cultivation_liejin_level_max,
		# 玩家修习技能数据
		"player_study_data": player_study_data,
		# 纹章系统
		"emblem_slots_max": emblem_slots_max,
		# 装备系统
		"max_carry_equipment_slots": max_carry_equipment_slots,
		"equipment_data": EquipmentManager.save_equipment_data(),
		# 音频设置
		"master_volume": AudioManager.get_master_volume(),
		"bgm_volume": AudioManager.get_bgm_volume(),
		"sfx_volume": AudioManager.get_sfx_volume()
		
	}
	for key in data:
		config.set_value("save", key, data[key])
	
	var err = config.save(CONFIG_PATH)
	if err == OK:
		print("save success")
	else:
		push_error("save error")
	
	# 同时保存音频设置到专用文件
	AudioManager.save_audio_settings()
		

func load_game() -> void:
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	
	if err != OK:
		#print("no save data, use defalut value")
		return
	
	total_points = config.get_value("save", "total_points", total_points)
	world_level = config.get_value("save", "world_level", world_level)
	world_level_multiple = config.get_value("save", "world_level_multiple", world_level_multiple)
	world_level_reward_multiple = config.get_value("save", "world_level_reward_multiple", world_level_reward_multiple)
	lunky_level = config.get_value("save", "lunky_level", lunky_level)
	red_p = config.get_value("save", "red_p", red_p)
	gold_p = config.get_value("save", "gold_p", gold_p)
	purple_p = config.get_value("save", "purple_p", purple_p)
	blue_p = config.get_value("save", "blue_p", blue_p)
	green_p = config.get_value("save", "green_p", green_p)
	player_inventory = config.get_value("save", "player_inventory", player_inventory)
	max_main_skill_num = config.get_value("save", "max_main_skill_num", max_main_skill_num)
	refresh_max_num = config.get_value("save", "refresh_max_num", refresh_max_num)
	recipe_unlock_progress = config.get_value("save", "recipe_unlock_progress", recipe_unlock_progress)
	cultivation_unlock_progress = config.get_value("save", "cultivation_unlock_progress", cultivation_unlock_progress)
	cultivation_poxu_level = config.get_value("save", "cultivation_poxu_level", cultivation_poxu_level)
	cultivation_xuanyuan_level = config.get_value("save", "cultivation_xuanyuan_level", cultivation_xuanyuan_level)
	cultivation_liuguang_level = config.get_value("save", "cultivation_liuguang_level", cultivation_liuguang_level)
	cultivation_hualing_level = config.get_value("save", "cultivation_hualing_level", cultivation_hualing_level)
	cultivation_fengrui_level = config.get_value("save", "cultivation_fengrui_level", cultivation_fengrui_level)
	cultivation_huti_level = config.get_value("save", "cultivation_huti_level", cultivation_huti_level)
	cultivation_zhuifeng_level = config.get_value("save", "cultivation_zhuifeng_level", cultivation_zhuifeng_level)
	cultivation_liejin_level = config.get_value("save", "cultivation_liejin_level", cultivation_liejin_level)
	emblem_slots_max = config.get_value("save", "emblem_slots_max", emblem_slots_max)
	fruit_heal_multi = config.get_value("save", "fruit_heal_multi", fruit_heal_multi)
	fruit_heal_multi_used_count = config.get_value("save", "fruit_heal_multi_used_count", fruit_heal_multi_used_count)
	# 加载修炼等级上限
	cultivation_poxu_level_max = config.get_value("save", "cultivation_poxu_level_max", cultivation_poxu_level_max)
	cultivation_xuanyuan_level_max = config.get_value("save", "cultivation_xuanyuan_level_max", cultivation_xuanyuan_level_max)
	cultivation_liuguang_level_max = config.get_value("save", "cultivation_liuguang_level_max", cultivation_liuguang_level_max)
	cultivation_hualing_level_max = config.get_value("save", "cultivation_hualing_level_max", cultivation_hualing_level_max)
	cultivation_fengrui_level_max = config.get_value("save", "cultivation_fengrui_level_max", cultivation_fengrui_level_max)
	cultivation_huti_level_max = config.get_value("save", "cultivation_huti_level_max", cultivation_huti_level_max)
	cultivation_zhuifeng_level_max = config.get_value("save", "cultivation_zhuifeng_level_max", cultivation_zhuifeng_level_max)
	cultivation_liejin_level_max = config.get_value("save", "cultivation_liejin_level_max", cultivation_liejin_level_max)
	
	
	# 加载玩家修习技能数据，确保兼容性
	var loaded_study_data = config.get_value("save", "player_study_data", player_study_data)
	# 为现有存档添加zhenqi_points字段的兼容性处理
	for player_name in loaded_study_data.keys():
		if not loaded_study_data[player_name].has("zhenqi_points"):
			loaded_study_data[player_name]["zhenqi_points"] = 100 # 默认真气点数
	player_study_data = loaded_study_data
	
	# 加载装备系统数据
	max_carry_equipment_slots = config.get_value("save", "max_carry_equipment_slots", 2)
	var equipment_data = config.get_value("save", "equipment_data", {})
	if EquipmentManager:
		EquipmentManager.load_equipment_data(equipment_data)
	
	# 加载音频设置
	var master_vol = config.get_value("save", "master_volume", 1.0)
	var bgm_vol = config.get_value("save", "bgm_volume", 1.0)
	var sfx_vol = config.get_value("save", "sfx_volume", 1.0)
	
	# 应用音频设置
	if AudioManager:
		AudioManager.set_master_volume(master_vol)
		AudioManager.set_bgm_volume(bgm_vol)
		AudioManager.set_sfx_volume(sfx_vol)
	
var hit_scene = null

func play_hit_anime(position: Vector2, is_crit: bool = false, anime: int = 1):
	if anime == 0:
		return
	if hit_scene == null:
		hit_scene = ResourceLoader.load("res://Scenes/global/hit.tscn")
	var hit_instantiate = hit_scene.instantiate()
	hit_instantiate.position = position + Vector2(-1, 5)
	get_tree().current_scene.add_child(hit_instantiate)
	
	# 设置音效使用SFX总线
	if hit_instantiate.gun_hit_crit_sound:
		hit_instantiate.gun_hit_crit_sound.bus = "SFX"
	if hit_instantiate.gun_hit_sound:
		hit_instantiate.gun_hit_sound.bus = "SFX"
	
	if is_crit:
		hit_instantiate.gun_hit_crit_anime.play("hit") # Assuming crit animation name is also "hit"
		hit_instantiate.gun_hit_crit_sound.play(0.0)
		hit_instantiate.emit_signal("critical_hit_played") # Emit signal if you need to react to this elsewhere
	else:
		hit_instantiate.gun_hit_anime.play("hit")
		hit_instantiate.gun_hit_sound.play(0.0)
	await get_tree().create_timer(0.2).timeout
	if hit_instantiate != null:
		hit_instantiate.queue_free()


func _on_monster_damage(damage_type_int: int, damage_value: float, world_position: Vector2):
	var damage_label_scene = preload("res://Scenes/global/damage.tscn")
	var damage_label_instance = damage_label_scene.instantiate()
	add_child(damage_label_instance)
	damage_label_instance.z_index = 100
	damage_label_instance.show_damage_number(damage_type_int, damage_value, world_position)
	damage_label_instance.global_position = world_position
	
	# 记录伤害到DPS计数器
	record_damage_for_dps(damage_value)

# 记录伤害用于DPS计算
func record_damage_for_dps(damage: float) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	dps_damage_records.append({"damage": damage, "time": current_time})

# 计算DPS（每秒调用一次）
func _calculate_dps() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	var total_damage = 0.0
	
	# 移除30秒前的记录并计算总伤害
	for i in range(dps_damage_records.size() - 1, -1, -1):
		var record = dps_damage_records[i]
		if current_time - record["time"] > 30.0:
			dps_damage_records.remove_at(i)
		else:
			total_damage += record["damage"]
	
	# 计算DPS（过去30秒的总伤害除以30）
	current_dps = total_damage / 30.0
	print(current_dps)

# 重置DPS计数器（游戏开始时调用）
func reset_dps_counter() -> void:
	dps_damage_records.clear()
	current_dps = 0.0
	dps_timer.start()

# 停止DPS计数器（游戏结束时调用）
func stop_dps_counter() -> void:
	dps_timer.stop()

# 获取当前DPS值
func get_current_dps() -> float:
	return current_dps
