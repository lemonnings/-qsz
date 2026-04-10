extends Node

## 经验光点系统 - 处理经验光点的生成

var ExpOrbScene = preload("res://Scenes/global/exp_orb.tscn")

# 胜利吸收模式
var victory_attracting: bool = false
var victory_player: Node2D = null
var victory_speed: float = 150.0

func _ready() -> void:
	# 连接到全局信号
	if Global.has_signal("drop_exp_orb"):
		Global.drop_exp_orb.connect(_on_drop_exp_orb)
	else:
		printerr("Global signal 'drop_exp_orb' not found!")

func _process(delta: float) -> void:
	if not victory_attracting:
		return
	
	# 胜利模式：让所有经验光点加速飞向玩家
	var orbs = get_tree().get_nodes_in_group("exp_orb")
	for orb in orbs:
		if not is_instance_valid(orb):
			continue
		if orb.current_state == ExpOrb.State.RISE:
			orb.current_state = ExpOrb.State.TRACK

func start_victory_collect(player: Node2D, speed: float = 150.0) -> void:
	victory_attracting = true
	victory_player = player
	victory_speed = speed

func _on_drop_exp_orb(exp_value: int, drop_position: Vector2, is_elite: bool) -> void:
	# 普通敌人2个光点，精英3个
	var orb_count = 3 if is_elite else 2
	
	# 计算每个光点的经验值（平分）
	var exp_per_orb = int(ceil(float(exp_value) / float(orb_count)))
	
	# 获取当前场景
	var current_scene = get_tree().current_scene
	if not current_scene:
		printerr("Could not find current scene to add exp orb.")
		return
	
	for i in range(orb_count):
		var orb_instance = ExpOrbScene.instantiate()
		
		# 设置光点属性
		orb_instance.exp_value = exp_per_orb
		
		# 添加随机偏移，避免重叠
		var offset = Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
		
		# 先添加到场景树
		current_scene.add_child(orb_instance)
		# 然后设置全局位置（必须在添加到场景树后才能设置global_position）
		var spawn_pos = drop_position + offset
		orb_instance.global_position = spawn_pos
		# 同步更新rise_start_y，确保以怪物位置为起点向上飘rise_distance像素
		orb_instance.rise_start_y = spawn_pos.y
		orb_instance.rise_target_y = spawn_pos.y - orb_instance.rise_distance
