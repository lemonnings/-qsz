extends Area2D

@export var sprite : AnimatedSprite2D
@export var collision : CollisionShape2D

var duration: float
var interval: float = 0.5
var damage_ratio: float
var heal_ratio: float = 0.02
var timer: float = 0.0

@onready var player = get_tree().get_first_node_in_group("player")

func start(duration_time: float, dmg_ratio: float):
	duration = duration_time
	damage_ratio = dmg_ratio
	
	if sprite:
		sprite.play("default")
		sprite.modulate = Color(1.0, 0.7, 0.7, 0.8)
		
	_create_screen_flash(Color(1.0, 0.5, 0.5, 0.3))
	
	# 添加Buff显示
	Global.emit_signal("buff_added", "holy_fire", duration, 1)
	
	set_process(true)

func _create_screen_flash(color: Color):
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 10
	get_tree().root.add_child(canvas_layer)
	
	var color_rect = ColorRect.new()
	color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color_rect.color = color
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	canvas_layer.add_child(color_rect)
	
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, 0.5).from(color.a)
	tween.tween_callback(canvas_layer.queue_free)

func _process(delta):
	duration -= delta
	timer += delta
	
	if timer >= interval:
		timer -= interval
		check_collision()
		
	if duration <= 0:
		Global.emit_signal("buff_removed", "holy_fire")
		queue_free()

func check_collision():
	# 获取重叠的敌人
	var bodies = get_overlapping_bodies()
	var areas = get_overlapping_areas()
	var all_targets = []
	all_targets.append_array(bodies)
	all_targets.append_array(areas)
	
	var hit_enemy = false
	
	
	for target in all_targets:
		if target.is_in_group("enemies"):
			# 造成伤害
			var damage = PC.pc_atk * damage_ratio
			if target.has_method("take_damage"):
				target.take_damage(damage, false, false, "")
				hit_enemy = true
	
	if hit_enemy:
		var lost_hp = PC.pc_max_hp - PC.pc_hp
	
		# 计算治疗量
		var heal_amount = max(1.0, PC.pc_max_hp * heal_ratio)
		# 治疗加成
		heal_amount = int(heal_amount * (1.0 + PC.heal_multi))
		
		# 确保 player 引用有效
		if not player:
			player = get_tree().get_first_node_in_group("player")
			
		PC.pc_hp = min(PC.pc_max_hp, PC.pc_hp + heal_amount)
		if player:
			Global.emit_signal("player_heal", heal_amount, player.global_position)
		else:
			Global.emit_signal("player_heal", heal_amount, global_position)
