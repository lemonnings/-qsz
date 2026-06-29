extends Node

## 经验光点系统 - 处理经验光点的生成

const EXP_ORB_POOL_WARM_UP_COUNT := 256
const MAX_ACTIVE_EXP_ORBS := 80
const SOFT_ACTIVE_EXP_ORBS := 55
const MERGE_RADIUS := 120.0

var ExpOrbScene: PackedScene = preload("res://Scenes/global/exp_orb.tscn")
var exp_orb_pool: ObjectPool = null

# 胜利吸收模式
var victory_attracting: bool = false
var victory_player: Node2D = null
var victory_speed: float = 150.0

func _ready() -> void:
	exp_orb_pool = ObjectPool.new(ExpOrbScene, EXP_ORB_POOL_WARM_UP_COUNT)
	exp_orb_pool.name = "ExpOrbPool"
	add_child(exp_orb_pool)
	
	# 连接到全局信号
	if Global.has_signal("drop_exp_orb"):
		Global.drop_exp_orb.connect(_on_drop_exp_orb)
	else:
		printerr("Global signal 'drop_exp_orb' not found!")

func _process(_delta: float) -> void:
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
	if exp_value <= 0:
		return
	var current_scene = get_tree().current_scene
	if not current_scene:
		printerr("Could not find current scene to add exp orb.")
		return
	var active_count := exp_orb_pool.active_count if exp_orb_pool != null else get_tree().get_nodes_in_group("exp_orb").size()
	if active_count >= MAX_ACTIVE_EXP_ORBS:
		if _merge_exp_into_nearby_orb(exp_value, drop_position):
			return
		_spawn_exp_orb(exp_value, drop_position, current_scene)
		return

	# 普通敌人2个光点，精英3个
	var orb_count = 3 if is_elite else 2
	if active_count >= SOFT_ACTIVE_EXP_ORBS:
		orb_count = 1
	
	# 计算每个光点的经验值（精确平分余数，避免 ceil 拆分导致低经验怪额外涨经验）
	var base_exp_per_orb = int(float(exp_value) / float(orb_count))
	var exp_remainder = exp_value % orb_count
	
	for i in range(orb_count):
		var orb_exp = base_exp_per_orb + (1 if i < exp_remainder else 0)
		if orb_exp <= 0:
			continue
		
		# 添加随机偏移，避免重叠
		var offset = Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
		var spawn_pos = drop_position + offset
		_spawn_exp_orb(orb_exp, spawn_pos, current_scene)

func _spawn_exp_orb(exp_value: int, spawn_pos: Vector2, current_scene: Node) -> void:
	var orb_instance := exp_orb_pool.acquire(current_scene) as ExpOrb
	if orb_instance == null:
		PC.pc_exp += exp_value
		return
	orb_instance.setup(exp_value, spawn_pos)

func _merge_exp_into_nearby_orb(exp_value: int, drop_position: Vector2) -> bool:
	var nearest_orb: ExpOrb = null
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group("exp_orb"):
		var orb := node as ExpOrb
		if orb == null or not is_instance_valid(orb):
			continue
		if orb.current_state == ExpOrb.State.FADE:
			continue
		var distance := drop_position.distance_to(orb.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_orb = orb
	if nearest_orb != null and nearest_distance <= MERGE_RADIUS:
		nearest_orb.add_exp(exp_value)
		return true
	return false
