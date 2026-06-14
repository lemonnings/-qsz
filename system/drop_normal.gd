extends Area2D

const HEAL_AURA_ITEM_ID := "item_001"
const HEAL_AURA_ATTRACT_HP_RATIO := 0.9

@export var attract_distance: float = 40.0
@export var attract_speed: float = 320.0
@export var pickup_distance: float = 2.0

var item_id: String
var quantity: int
var _is_picking_up: bool = false

func _ready():
	# 连接 body_entered 信号
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _is_picking_up or Global.victory_collecting:
		return

	var player := _get_nearest_player()
	if player == null:
		return
	if not _can_attract_to_player(player):
		return

	var distance := global_position.distance_to(player.global_position)
	if distance > attract_distance:
		return
	if distance <= pickup_distance:
		_pick_up(player, false)
		return

	global_position = global_position.move_toward(player.global_position, attract_speed * delta)

func _on_body_entered(body):
	_pick_up(body, true)

func _pick_up(body, force_direct_pickup: bool) -> void:
	if _is_picking_up:
		return
	# 检查碰撞的是否为玩家
	if body.is_in_group("player"):
		var item_type = ItemManager.get_item_property(item_id, "item_type")
		var can_pick_up := false
		if item_type == "immediate":
			var item_func_name = ItemManager.item_function.get(item_id)
			if item_func_name != null and ItemManager.has_method(item_func_name):
				if item_id == HEAL_AURA_ITEM_ID and force_direct_pickup:
					can_pick_up = ItemManager.call(item_func_name, body, item_id, true)
				else:
					can_pick_up = ItemManager.call(item_func_name, body, item_id)
			else:
				can_pick_up = true
		else:
			can_pick_up = ItemManager.on_item_picked_up(body, item_id)

		if can_pick_up:
			_is_picking_up = true
			set_deferred("monitoring", false)
			var tween = create_tween().set_parallel(true)
			tween.tween_property(self , "position:y", position.y - 50, 0.4)
			tween.tween_property(self , "modulate:a", 0, 0.4)
			await tween.finished
			queue_free()

func _get_nearest_player() -> Node2D:
	if PC.player_instance is Node2D and is_instance_valid(PC.player_instance):
		return PC.player_instance
	var nearest_player: Node2D = null
	var nearest_distance_sq := INF
	for player in get_tree().get_nodes_in_group("player"):
		if not (player is Node2D) or not is_instance_valid(player):
			continue
		var distance_sq := global_position.distance_squared_to(player.global_position)
		if distance_sq < nearest_distance_sq:
			nearest_distance_sq = distance_sq
			nearest_player = player
	return nearest_player

func _can_attract_to_player(_player: Node2D) -> bool:
	if item_id != HEAL_AURA_ITEM_ID:
		return true
	if PC.pc_max_hp <= 0:
		return false
	return float(PC.pc_hp) / float(PC.pc_max_hp) <= HEAL_AURA_ATTRACT_HP_RATIO
