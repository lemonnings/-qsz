extends Area2D

@export var sprite : AnimatedSprite2D

var duration: float
var shield_percent: float
var damage_reduction_bonus: float
var active: bool = false

func start(duration_time: float, shield_pct: float, dr_bonus: float):
	duration = duration_time
	shield_percent = shield_pct
	damage_reduction_bonus = dr_bonus
	active = true
	
	# 添加护盾
	var shield_base = PC.pc_max_hp * shield_percent + 1
	if PC.has_method("add_shield"):
		PC.add_shield(int(shield_base), duration)
	else:
		# 兼容性处理，如果 PC 没有 add_shield 方法（虽然现在应该有了）
		var shield_amount = shield_base * (1.0 + PC.sheild_multi)
		PC.pc_sheild.append({
			"value": int(shield_amount),
			"time_left": duration
		})
	
	# 增加减伤
	PC.damage_reduction_rate += damage_reduction_bonus
	
	if sprite:
		sprite.play("default")
		sprite.modulate = Color(0.2, 0.5, 1.0, 0.5)
		start_blink_effect()
	
	# 屏幕闪烁一次浅蓝色半透明
	_create_screen_flash(Color(0.5, 0.8, 1.0, 0.3))
	
	# 添加Buff显示
	Global.emit_signal("buff_added", "water_sheild", duration, 1)
	
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

func start_blink_effect():
	if not sprite: return
	
	var tween = create_tween().set_loops()
	# 1.5秒闪烁一次：从半透明变亮，再变回去
	# 假设初始 alpha 是 0.5
	# 变亮 (alpha 0.8)
	tween.tween_property(sprite, "modulate:a", 0.8, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 变暗 (alpha 0.2)
	tween.tween_property(sprite, "modulate:a", 0.2, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _process(delta):
	duration -= delta
	if duration <= 0:
		Global.emit_signal("buff_removed", "water_sheild")
		queue_free()

func _exit_tree():
	# 确保只在激活状态下移除加成
	if active:
		PC.damage_reduction_rate -= damage_reduction_bonus
		active = false
