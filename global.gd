extends Node

const CONFIG_PATH = "user://game_config.cfg"

# Buff配置管理器（需要在项目设置中设置为自动加载）
var SettingBuff = preload("res://Script/config/setting_buff.gd").new()

@export var total_points : int = 1000

# 角色整备属性
@export var atk_level : int = 0
@export var hp_level : int = 0
@export var atk_speed_level : int = 0
@export var move_speed_level : int = 0
@export var point_add_level : int = 0
@export var bullet_size_level : int = 0
@export var crit_chance_level : int = 0 # 局外暴击率等级
@export var crit_damage_level : int = 0 # 局外暴击伤害等级
@export var damage_reduction_level : int = 0 # 局外减伤等级

# 跟升级抽卡有关的
@export var lunky_level : int = 1
@export var red_p : float = 3.5
@export var gold_p : float = 10
@export var purple_p : float = 18
@export var blue_p : float = 25
@export var green_p : float = 30

# 刷新次数
@export var refresh_max_num : int = 3 


# 世界等级（难度级）
@export var world_level_multiple : float = 1
@export var world_level_reward_multiple : float = 1
@export var world_level : int = 1

@export var in_menu : bool = true
@export var in_town : bool = false

@export var is_level_up : bool = false

@export var main_menu_instance: PackedScene = null

# 鼠标动画通过autoload管理

signal player_hit
signal player_lv_up
signal lucky_level_up
signal setup_summons
signal level_up_selection_complete
signal monster_damage
signal monster_mechanism_gained
signal boss_defeated

# 对话相关
signal start_dialog(dialog_file_path: String) # Signal to start a dialog sequence

# bgm切换
signal boss_bgm
signal normal_bgm

# 影机相关
signal zoom_camera
signal reset_camera

# 狂暴化警告
signal rampage_notice

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

# 玩家背包
var player_inventory = {}


func _ready() -> void:
	Global.monster_damage.connect(_on_monster_damage)
	
	# 初始化buff配置管理器
	add_child(SettingBuff)
	
	# 游戏启动时立即加载鼠标动画
	MouseAnimation.start_mouse_animation()


func save_game() -> void:
	var config = ConfigFile.new()
	var data = {
		"total_points": total_points,
		"world_level": world_level,
		"world_level_multiple": world_level_multiple,
		"world_level_reward_multiple": world_level_reward_multiple,
		"atk_level": atk_level,
		"hp_level": hp_level,
		"atk_speed_level": atk_speed_level,
		"move_speed_level": move_speed_level,
		"point_add_level": point_add_level,
		"bullet_size_level": bullet_size_level,
		"lunky_level": lunky_level,
		"red_p": red_p,
		"gold_p": gold_p,
		"purple_p": purple_p,
		"blue_p": blue_p,
		"green_p": green_p,
		"crit_chance_level": crit_chance_level,
		"crit_damage_level": crit_damage_level,
		"damage_reduction_level": damage_reduction_level
	}
	for key in data:
		config.set_value("save", key, data[key])
	
	var err = config.save(CONFIG_PATH)
	if err == OK:
		print("save success")
	else:
		push_error("save error")
		

func load_game() -> void:
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	
	if err != OK :
		#print("no save data, use defalut value")
		return 
	
	total_points = config.get_value("save", "total_points", total_points)
	atk_level = config.get_value("save", "atk_level", atk_level)
	hp_level = config.get_value("save", "hp_level", hp_level)
	atk_speed_level = config.get_value("save", "atk_speed_level", atk_speed_level)
	move_speed_level = config.get_value("save", "move_speed_level", move_speed_level)
	point_add_level = config.get_value("save", "point_add_level", point_add_level)
	bullet_size_level = config.get_value("save", "bullet_size_level", bullet_size_level)
	world_level = config.get_value("save", "world_level", world_level)
	world_level_multiple = config.get_value("save", "world_level_multiple", world_level_multiple)
	world_level_reward_multiple = config.get_value("save", "world_level_reward_multiple", world_level_reward_multiple)
	lunky_level = config.get_value("save", "lunky_level", lunky_level)
	red_p = config.get_value("save", "red_p", red_p)
	gold_p = config.get_value("save", "gold_p", gold_p)
	purple_p = config.get_value("save", "purple_p", purple_p)
	blue_p = config.get_value("save", "blue_p", blue_p)
	green_p = config.get_value("save", "green_p", green_p)
	crit_chance_level = config.get_value("save", "crit_chance_level", crit_chance_level)
	crit_damage_level = config.get_value("save", "crit_damage_level", crit_damage_level)
	damage_reduction_level = config.get_value("save", "damage_reduction_level", damage_reduction_level)
	
var hit_scene = null

func play_hit_anime(position : Vector2, is_crit: bool = false, anime: int = 1):
	if anime == 0:
		return
	if hit_scene == null:
		hit_scene = ResourceLoader.load("res://Scenes/global/hit.tscn")
	var hit_instantiate = hit_scene.instantiate()
	hit_instantiate.position = position + Vector2(-1,5)
	get_tree().current_scene.add_child(hit_instantiate)
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
