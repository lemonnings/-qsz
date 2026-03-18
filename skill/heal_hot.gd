extends Area2D

@export var sprite : AnimatedSprite2D

var duration: float
var heal_interval: float = 2.0
var heal_base: float
var heal_percent: float
var timer: float = 0.0

func start(duration_time: float, base_heal: float, percent_heal: float):
	duration = duration_time
	heal_base = base_heal
	heal_percent = percent_heal
	
	if sprite:
		sprite.play("default")
		sprite.modulate = Color(0.2, 0.8, 0.2, 0.5)
	
	# 1. 特效在人物后面
	z_index = -1
	
	# 2. 屏幕闪烁一次浅色半透明绿光
	_create_screen_flash(Color(0.5, 1.0, 0.5, 0.3))
	
	# 添加Buff显示
	Global.emit_signal("buff_added", "heal_hot", duration, 1)
	
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
	
	if timer >= heal_interval:
		timer -= heal_interval
		perform_heal()
		
	if duration <= 0:
		Global.emit_signal("buff_removed", "heal_hot")
		queue_free()

func perform_heal():
	var max_hp = PC.pc_max_hp
	var heal_amount = int((max_hp * heal_percent + heal_base) * (1.0 + PC.heal_multi))
	
	var player = get_tree().get_first_node_in_group("player")
	
	PC.pc_hp = min(PC.pc_max_hp, PC.pc_hp + heal_amount)
	if player:
		Global.emit_signal("player_heal", heal_amount, player.global_position)
	else:
		Global.emit_signal("player_heal", heal_amount, global_position)
