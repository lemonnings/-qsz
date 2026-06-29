extends Node
class_name DialogDirector

## 对话流程编排器
##
## 将场景中的 dialog_character 与 normal_dialog 统一编排，
## 按步骤串行执行对话序列。每步格式：
##
##   { "type": "move",        "char": Node2D, "x": float, "duration": float,
##                             "facing": "right"|"left" }
##   { "type": "wait",        "duration": float }
##   { "type": "emote",       "char": Node2D, "anim": String, "duration": float }
##   { "type": "speak_char",  "char": Node2D, "text": String, "offset": Vector2 (可选) }
##   { "type": "speak_normal","normal_dialog": Control, "lines": Array[Dictionary] }
##       lines 字典字段说明：
##         speaker          : 发言人名称
##         speaker_position  : "left"|"right"|"both"（可选，默认按立绘状态自动推断）
##         speaker2          : 第二发言人名称，speaker_position="both" 时显示在右侧
##   { "type": "jump",        "char": Node2D, "to": Vector2, "duration": float (默认0.5),
##                             "height": float (默认50), "facing": "right"|"left" (可选) }
##   { "type": "face",        "char": Node2D, "facing": "right"|"left" }
##   { "type": "shake",       "duration": float, "intensity": float }
##   { "type": "callback",    "func": Callable }

signal sequence_completed

const INPUT_BLOCK_MSEC: int = 220

static var _input_block_until_msec: int = 0

var _cancelled: bool = false


static func block_story_input(duration_msec: int = INPUT_BLOCK_MSEC) -> void:
	var next_block_until_msec: int = Time.get_ticks_msec() + duration_msec
	_input_block_until_msec = maxi(_input_block_until_msec, next_block_until_msec)


static func is_story_input_blocked() -> bool:
	return Time.get_ticks_msec() < _input_block_until_msec


## 取消当前 run 循环，让所有 await 立即跳过
func cancel() -> void:
	_cancelled = true
	block_story_input()


func run(steps: Array[Dictionary]) -> void:
	_cancelled = false
	block_story_input()
	var i := 0
	while i < steps.size():
		if _cancelled:
			break
		var step: Dictionary = steps[i]
		# 检测连续的 speak_normal （同一节点）并合并 lines，避免整屏渐出/渐入闪烁
		if step.get("type") == "speak_normal":
			var normal_node = step.get("normal_dialog")
			var merged_lines: Array = step.get("lines", []).duplicate()
			var j := i + 1
			while j < steps.size() \
					and steps[j].get("type") == "speak_normal" \
					and steps[j].get("normal_dialog") == normal_node:
				merged_lines.append_array(steps[j].get("lines", []))
				j += 1
			if j > i + 1:
				# 合并后的单步验一次整屏渐变
				var merged: Dictionary = {"type": "speak_normal", "normal_dialog": normal_node, "lines": merged_lines}
				block_story_input()
				await _process_step(merged)
				block_story_input()
				i = j
				continue
		block_story_input()
		await _process_step(step)
		block_story_input()
		i += 1
	block_story_input()
	sequence_completed.emit()


func _process_step(step: Dictionary) -> void:
	match step.get("type", ""):
		"move":
			await _do_move(step)
		"jump":
			await _do_jump(step)
		"wait":
			await _do_wait(step)
		"emote":
			await _do_emote(step)
		"speak_char":
			await _do_speak_char(step)
		"speak_normal":
			await _do_speak_normal(step)
		"face":
			_do_face(step)
		"shake":
			await _do_shake(step)
		"callback":
			_do_callback(step)
		_:
			push_error("DialogDirector: 未知步骤类型 ", step.get("type"))


## 角色水平移动
##  - facing : "right" / "left"，控制 x 轴翻转
##  - 移动过程自动播放 run 动画，移动结束后恢复 idle
func _do_move(step: Dictionary) -> void:
	var char_node = step.get("char")
	var target_x: float = step.get("x", char_node.position.x)
	var duration: float = step.get("duration", 1.0)
	var facing: String = step.get("facing", "right")

	# 取 dialog_character 的 sprite (AnimatedSprite2D)
	var sprite: AnimatedSprite2D = char_node.get("character") if char_node.get("character") is AnimatedSprite2D else null

	# ── 朝向 ──
	if sprite:
		sprite.scale.x = abs(sprite.scale.x) * (-1 if facing == "left" else 1)

	# ── 播放行走动画 ──
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("run"):
		sprite.play("run")

	# ── 移动 ──
	var tween = create_tween()
	tween.tween_property(char_node, "position:x", target_x, duration)
	await tween.finished

	# ── 恢复待机动画 ──
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")


## 角色抛物线跳跃
##  - to       : 目标位置 Vector2
##  - from     : 起始位置（可选，默认为当前位置）
##  - duration : 跳跃持续时间（默认 0.5 秒）
##  - height   : 抛物线峰值高度（默认 50 像素）
##  - facing   : 可选朝向，未指定则根据移动方向自动判断
func _do_jump(step: Dictionary) -> void:
	var char_node = step.get("char")
	var target_pos: Vector2 = step.get("to", char_node.position)
	var from_pos: Vector2 = step.get("from", char_node.position)
	var duration: float = step.get("duration", 0.5)
	var height: float = step.get("height", 50.0)
	var facing: String = step.get("facing", "")

	var sprite: AnimatedSprite2D = char_node.get("character") if char_node.get("character") is AnimatedSprite2D else null

	# ── 朝向（未指定则根据方向自动判断）──
	if facing == "" and target_pos.x != from_pos.x:
		facing = "right" if target_pos.x > from_pos.x else "left"
	if facing != "" and sprite:
		sprite.scale.x = abs(sprite.scale.x) * (-1 if facing == "left" else 1)

	# ── 播放跳跃/行走动画 ──
	if sprite and sprite.sprite_frames:
		if sprite.sprite_frames.has_animation("run"):
			sprite.play("run")

	# ── 抛物线移动 ──
	char_node.position = from_pos
	var elapsed := 0.0

	while elapsed < duration:
		elapsed += get_process_delta_time()
		var t := clampf(elapsed / duration, 0.0, 1.0)

		# 线性插值 x/y 基础位置
		var current_x := lerpf(from_pos.x, target_pos.x, t)
		var current_y := lerpf(from_pos.y, target_pos.y, t)

		# 抛物线 y 偏移：t=0 → 0, t=0.5 → -height, t=1 → 0
		var arc_offset := -4.0 * height * t * (1.0 - t)

		char_node.position = Vector2(current_x, current_y + arc_offset)
		await get_tree().process_frame

	char_node.position = target_pos

	# ── 恢复待机动画 ──
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")


## 仅切换角色朝向（不移动）
func _do_face(step: Dictionary) -> void:
	var char_node = step.get("char")
	var facing: String = step.get("facing", "right")
	var sprite: AnimatedSprite2D = char_node.get("character") if char_node.get("character") is AnimatedSprite2D else null
	if sprite:
		sprite.scale.x = abs(sprite.scale.x) * (-1 if facing == "left" else 1)


## 等待
func _do_wait(step: Dictionary) -> void:
	var duration: float = step.get("duration", 1.0)
	await get_tree().create_timer(duration).timeout


## 角色表情气泡
func _do_emote(step: Dictionary) -> void:
	var char_node = step.get("char")
	var anim: String = step.get("anim", "happy")
	var duration: float = step.get("duration", 1.0)
	if char_node.has_signal("speech_completed") and char_node.has_method("show_emote"):
		await char_node.show_emote(anim, duration)


## 简短气泡发言
func _do_speak_char(step: Dictionary) -> void:
	var char_node = step.get("char")
	var text: String = step.get("text", "")
	if not char_node.has_signal("speech_completed") or not char_node.has_method("speak"):
		return
	var offset = step.get("offset", Vector2.INF)
	char_node.speak(text, offset)
	block_story_input(300)
	await char_node.speech_completed


## 全屏 normal_dialog（通过内联数据）
func _do_speak_normal(step: Dictionary) -> void:
	var normal_node: Control = step.get("normal_dialog")
	var lines: Array = step.get("lines", [])
	if not normal_node or lines.is_empty():
		return
	if not normal_node.has_signal("dialog_completed") or not normal_node.has_method("start_dialog_from_data"):
		return
	block_story_input(300)
	normal_node.start_dialog_from_data(lines)
	await normal_node.dialog_completed


## 震屏效果
func _do_shake(step: Dictionary) -> void:
	var duration: float = step.get("duration", 0.3)
	var intensity: float = step.get("intensity", 5.0)

	var vp = get_viewport()
	var camera: Camera2D = vp.get_camera_2d() if vp else null
	if not camera:
		return

	var original_offset: Vector2 = camera.offset
	var timer := get_tree().create_timer(duration)

	while timer.time_left > 0:
		camera.offset = original_offset + Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		await get_tree().process_frame

	camera.offset = original_offset


## 回调
func _do_callback(step: Dictionary) -> void:
	var fn: Callable = step.get("func", Callable())
	if fn.is_valid():
		fn.call()


## ── 公用方法 ───────────────────────────────────────────

## 上一次 keep_black=true 保留的覆盖层（供下次调用复用）
var _kept_overlay: CanvasLayer = null
var _kept_bg: ColorRect = null
var _kept_container: Control = null

## 黑屏字幕过渡效果（打字机效果）
## text       : 字幕文本
## wait_after : 文字全部出现后等待的秒数
## during_fn  : 黑屏期间执行的回调（用于切换角色显隐等）
## keep_black : 为 true 时保留黑屏不淡出（用于连续字幕衔接）
func show_subtitle(text: String, wait_after: float = 3.0, during_fn: Callable = Callable(), keep_black: bool = false) -> void:
	var overlay: CanvasLayer
	var container: Control
	var bg: ColorRect
	var reused := false

	# 复用上一次 keep_black 保留的覆盖层（黑屏已经显示，无需再次淡入）
	if _kept_overlay and is_instance_valid(_kept_overlay):
		overlay = _kept_overlay
		container = _kept_container
		bg = _kept_bg
		reused = true
		_kept_overlay = null
		_kept_bg = null
		_kept_container = null
	else:
		overlay = CanvasLayer.new()
		overlay.layer = 200
		add_child(overlay)

		container = Control.new()
		container.set_anchors_preset(Control.PRESET_FULL_RECT)
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(container)

		bg = ColorRect.new()
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.color = Color(0, 0, 0, 0)
		container.add_child(bg)

	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var font = preload("res://AssetBundle/Uranus_Pixel_11Px.ttf")
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	
	# Keep calculating size using LEFT to get the true unwrapped width
	var single_line_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 36)
	var max_w = get_viewport().get_visible_rect().size.x - 60.0
	
	# Calculate actual width and height needed
	var actual_w = min(single_line_size.x, max_w)
	var line_count = ceil(single_line_size.x / max_w) if single_line_size.x > max_w else 1.0
	var actual_h = line_count * 36.0 * 1.5 # Approximate height with line spacing
	
	label.custom_minimum_size = Vector2(actual_w, actual_h)
	
	container.add_child(label)
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	label.size = Vector2(actual_w, actual_h)
	# Force center positioning mathematically relative to the viewport center
	var vp_size = get_viewport().get_visible_rect().size
	label.position = (vp_size - label.size) / 2.0
	label.visible_characters = -1
	label.modulate.a = 0.0

	# 淡入黑屏（复用时跳过，已经是黑屏了）
	if not reused:
		var fade_in := create_tween()
		fade_in.tween_property(bg, "color:a", 1.0, 0.5)
		await fade_in.finished

	# 执行切换回调（显隐角色等）
	if during_fn.is_valid():
		during_fn.call()

	# 文字渐入效果
	var fade_text_in := create_tween()
	fade_text_in.tween_property(label, "modulate:a", 1.0, 0.5)
	await fade_text_in.finished

	# 等待阅读
	await get_tree().create_timer(wait_after).timeout

	# 淡出（或保留黑屏）
	if keep_black:
		# 只淡出文字，保留黑屏背景，存储引用供下次复用
		var fade_text := create_tween()
		fade_text.tween_property(label, "modulate:a", 0.0, 0.3)
		await fade_text.finished
		label.queue_free()
		_kept_overlay = overlay
		_kept_bg = bg
		_kept_container = container
	else:
		var fade_out := create_tween()
		fade_out.set_parallel(true)
		fade_out.tween_property(bg, "color:a", 0.0, 0.5)
		fade_out.tween_property(label, "modulate:a", 0.0, 0.5)
		await fade_out.finished
		overlay.queue_free()
