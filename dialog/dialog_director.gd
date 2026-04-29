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
##   { "type": "face",        "char": Node2D, "facing": "right"|"left" }
##   { "type": "shake",       "duration": float, "intensity": float }
##   { "type": "callback",    "func": Callable }

signal sequence_completed


func run(steps: Array[Dictionary]) -> void:
	var i := 0
	while i < steps.size():
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
				await _process_step(merged)
				i = j
				continue
		await _process_step(step)
		i += 1
	sequence_completed.emit()


func _process_step(step: Dictionary) -> void:
	match step.get("type", ""):
		"move":
			await _do_move(step)
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
	await char_node.speech_completed


## 全屏 normal_dialog（通过内联数据）
func _do_speak_normal(step: Dictionary) -> void:
	var normal_node: Control = step.get("normal_dialog")
	var lines: Array = step.get("lines", [])
	if not normal_node or lines.is_empty():
		return
	if not normal_node.has_signal("dialog_completed") or not normal_node.has_method("start_dialog_from_data"):
		return
	normal_node.start_dialog_from_data(lines)
	await normal_node.dialog_completed


## 震屏效果
func _do_shake(step: Dictionary) -> void:
	var duration: float = step.get("duration", 0.3)
	var intensity: float = step.get("intensity", 5.0)

	var camera: Camera2D = get_viewport().get_camera_2d()
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
