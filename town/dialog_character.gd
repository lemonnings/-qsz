extends Node2D

## 一段发言完成信号（面板渐出后触发，用于对话流程编排）
signal speech_completed

## 独立对话框面板场景
const DIALOG_PANEL_SCENE = preload("res://Scenes/global/dialog_panel.tscn")

## 角色精灵引用（由 init 传入）
var character: AnimatedSprite2D

## 对话框面板实例（从 dialog_panel.tscn 实例化）
var dialog_panel: Panel = null

## 头顶表情气泡
@onready var emote: AnimatedSprite2D = $emote

## 气泡对话框 CanvasLayer（屏幕空间渲染，不受 Camera2D zoom 影响）
var _bubble_layer: CanvasLayer = null

## 打字速度（秒/字符），参考 dialog_manager.gd 的 text_display_speed = 0.03
@export var type_speed: float = 0.03

## 气泡面板额外缩放倍数（叠加在 Camera2D zoom 之上）
@export var bubble_scale_mult: float = 3.0

# ── 内部状态 ──────────────────────────────────
var _is_typing: bool = false
var _is_text_complete: bool = false
var _current_text_tween: Tween = null
var _panel_tween: Tween = null
var _is_panel_active: bool = false

## 暂存 init() 传入的发言人名称，dialog_panel 就绪后应用
var _pending_name: String = ""

## 当前 speak 传入的自定义偏移（_process 持续更新位置时复用）
var _current_offset_px: Vector2 = Vector2.INF


func _ready():
	# 默认隐藏所有角色精灵（除 emote 外）
	for child in get_children():
		if child is AnimatedSprite2D and child != emote:
			child.visible = false

	emote.visible = false

	# 创建 CanvasLayer 承载气泡对话框（屏幕空间渲染，不受 Camera2D 影响）
	_bubble_layer = CanvasLayer.new()
	_bubble_layer.name = "BubbleLayer"
	_bubble_layer.layer = 128
	add_child(_bubble_layer)

	# 实例化独立 dialog_panel 并挂到 CanvasLayer
	dialog_panel = DIALOG_PANEL_SCENE.instantiate()
	dialog_panel.visible = false
	_bubble_layer.add_child(dialog_panel)

	# 等待 dialog_panel 的 @onready 变量就绪后再应用暂存名称
	await dialog_panel.ready
	if _pending_name != "":
		dialog_panel.set_speaker_name(_pending_name)
		_pending_name = ""


## 每帧跟随角色位置更新气泡面板（角色移动 / 相机移动时保持跟随）
func _process(_delta: float) -> void:
	if _is_panel_active and dialog_panel and dialog_panel.visible:
		_update_panel_position(_current_offset_px)


## 更新气泡对话框在屏幕上的位置，使其跟随角色
## custom_offset_px: 可选，世界空间像素偏移，不传则自动居中在 sprite 上方 20px
func _update_panel_position(custom_offset_px := Vector2.INF):
	if not dialog_panel:
		return
	var _vp = get_viewport()
	var cam: Camera2D = _vp.get_camera_2d() if _vp else null
	var z: float = bubble_scale_mult
	var screen_pos: Vector2 = global_position

	if cam:
		screen_pos = cam.get_canvas_transform() * global_position
		z = cam.zoom.x * bubble_scale_mult

	# 应用缩放（直接改 size / font_size，不用 scale，避免像素模糊）
	dialog_panel.apply_zoom(z)

	# 计算偏移
	var panel_w: float = dialog_panel.size.x # 已被 apply_zoom 放大
	var panel_h: float = dialog_panel.size.y

	if custom_offset_px != Vector2.INF:
		# 传了自定义偏移（世界像素），转屏幕像素
		var cam_zoom := cam.zoom.x if cam else 1.0
		dialog_panel.position = screen_pos + custom_offset_px * cam_zoom
	else:
		# 默认：以角色为中心，在当前 sprite 上方 5 像素
		var sprite_top_y: float = 0.0
		if character and character.sprite_frames:
			var frame_tex = character.sprite_frames.get_frame_texture(character.animation, character.frame)
			if frame_tex:
				sprite_top_y = - frame_tex.get_height() * abs(character.scale.y) * 0.5
		# 屏幕空间偏移：水平居中（左移半个面板宽），垂直在 sprite 上方 5px
		var cam_zoom := cam.zoom.x if cam else 1.0
		var offset_screen_x: float = - panel_w * 0.5 + 7
		var offset_screen_y: float = (sprite_top_y - 1) * cam_zoom - panel_h
		dialog_panel.position = screen_pos + Vector2(offset_screen_x, offset_screen_y)


## ── 初始化 ────────────────────────────────────
## 指定角色精灵和发言人名称
func init(sprite: AnimatedSprite2D, name_text: String):
	for child in get_children():
		if child is AnimatedSprite2D and child != emote:
			child.visible = false

	character = sprite
	character.visible = true

	if dialog_panel and dialog_panel.speaker_name_label:
		dialog_panel.set_speaker_name(name_text)
	else:
		_pending_name = name_text


## ── 发言 ──────────────────────────────────────
## 流程：0.2s 渐入面板（不显示文本）→ 打字机效果显示文本
## 点击行为：打字中 → 显示全文 | 文本显示完毕 → 渐出面板
## offset_px: 可选，世界空间像素偏移；不传则自动居中在 sprite 上方 20px
func speak(dialog_text: String, offset_px := Vector2.INF):
	# 如果已有气泡正在显示，先渐出再显示新的
	if _is_panel_active and dialog_panel and dialog_panel.visible:
		var tw = create_tween()
		tw.tween_property(dialog_panel, "modulate:a", 0.0, 0.1)
		await tw.finished

	_reset_state()
	_is_panel_active = true

	# 记录偏移，_process 持续跟随时复用
	_current_offset_px = offset_px
	# 更新屏幕显示位置
	_update_panel_position(offset_px)

	# 清空文本、重置进度（由 dialog_panel.set_text 完成）
	dialog_panel.set_text("")
	dialog_panel.visible = true
	dialog_panel.modulate.a = 0.0

	# ① 渐入面板（不显示文本）
	_panel_tween = create_tween()
	_panel_tween.tween_property(dialog_panel, "modulate:a", 1.0, 0.2)
	await _panel_tween.finished

	# ② 打字机效果
	_start_typewriter(dialog_text)

	# ③ 等待打字完成 → 等待 text.length * 0.2 秒 → 自动渐隐
	_start_auto_dismiss(dialog_text)


## ── 弹出表情气泡 ──────────────────────────────
## emote_type : 动画名称（angry / doubt / happy / idea / sleep / slient / speechless / surprise）
## duration  : 持续显示时间（秒），结束后自动渐出
func show_emote(emote_type: String, duration: float):
	if emote.visible:
		emote.visible = false
		emote.modulate.a = 1.0
	emote.stop()

	# 动态计算 emote 位置：基于角色精灵的视觉顶部
	_update_emote_position()

	emote.visible = true
	emote.modulate.a = 0.0
	emote.play(emote_type)

	var tween_in = create_tween()
	tween_in.tween_property(emote, "modulate:a", 1.0, 0.2)
	await tween_in.finished

	if duration > 0:
		await get_tree().create_timer(duration).timeout

	var tween_out = create_tween()
	tween_out.tween_property(emote, "modulate:a", 0.0, 0.2)
	await tween_out.finished

	emote.visible = false
	emote.stop()
	emote.modulate.a = 1.0


## 根据角色精灵的当前帧尺寸动态计算 emote 的位置和缩放────────────
## 将 emote 放置在角色精灵视觉顶部以上，避免被角色遮挡
## emote 缩放以角色 scale=2.5 为基准，等比补偿保持视觉大小一致
const _EMOTE_BASE_SCALE := 0.55
const _EMOTE_REF_CHAR_SCALE := 2.5

func _update_emote_position() -> void:
	if not character or not character.sprite_frames:
		return
	var anim_name = character.animation
	if not character.sprite_frames.has_animation(anim_name):
		return
	var frame_idx = character.frame
	var tex = character.sprite_frames.get_frame_texture(anim_name, frame_idx)
	if not tex:
		return

	var tex_h = tex.get_size().y
	# 居中精灵的视觉顶部 y = position.y + offset.y - (tex_h / 2) * |scale.y|
	var top_y = character.position.y + character.offset.y - (tex_h / 2.0) * abs(character.scale.y)
	# emote 放置在精灵顶部再向上偏移
	emote.position = Vector2(character.position.x, top_y + 20)

	# emote 缩放补偿：以 2.2 倍角色缩放为基准，保持 emote 视觉大小一致
	var char_scale_abs = abs(scale.y) # DialogCharacter 节点的缩放
	if char_scale_abs > 0:
		var compensation = _EMOTE_REF_CHAR_SCALE / char_scale_abs
		emote.scale = Vector2(_EMOTE_BASE_SCALE * compensation, _EMOTE_BASE_SCALE * compensation)


## ── 内部方法 ──────────────────────────────────

## 启动打字机效果
func _start_typewriter(text: String):
	_is_typing = true
	_is_text_complete = false

	dialog_panel.set_text(text)

	if _current_text_tween and _current_text_tween.is_valid():
		_current_text_tween.kill()

	_current_text_tween = create_tween()
	var duration = text.length() * type_speed
	# 打字机 tween 目标为 dialog_panel.dialog_label 的 visible_characters
	_current_text_tween.tween_property(dialog_panel.dialog_label, "visible_characters", text.length(), duration)
	_current_text_tween.tween_callback(func():
		_is_typing = false
		_is_text_complete = true
		_current_text_tween = null
	)


## 跳过打字，直接显示完整文本
func _skip_typewriter():
	if _current_text_tween and _current_text_tween.is_valid():
		_current_text_tween.kill()
		_current_text_tween = null

	dialog_panel.dialog_label.visible_characters = dialog_panel.dialog_label.text.length()
	_is_typing = false
	_is_text_complete = true


## 渐出对话框面板
func _fade_out_panel():
	_is_text_complete = false
	_is_panel_active = false

	_panel_tween = create_tween()
	_panel_tween.tween_property(dialog_panel, "modulate:a", 0.0, 0.2)
	await _panel_tween.finished
	dialog_panel.visible = false
	dialog_panel.modulate.a = 1.0
	speech_completed.emit()


## 打字完成后等待 text.length * 0.2 秒，自动渐隐气泡对话框
func _start_auto_dismiss(text: String) -> void:
	# 等待打字完成（跳过打字、或自然打完均可）
	while not _is_text_complete:
		await get_tree().process_frame

	# 等待阅读时间（每字 0.2 秒）
	await get_tree().create_timer(text.length() * 0.2).timeout

	# 如果面板仍处于活动状态且没有被新的 speak 中断，则自动渐隐
	if _is_panel_active and _is_text_complete and dialog_panel and dialog_panel.visible:
		_fade_out_panel()


## 重置所有内部状态（准备下一次 speak）
func _reset_state():
	_is_typing = false
	_is_text_complete = false
	_is_panel_active = false
	_current_offset_px = Vector2.INF

	if _current_text_tween and _current_text_tween.is_valid():
		_current_text_tween.kill()
		_current_text_tween = null

	if _panel_tween and _panel_tween.is_valid():
		_panel_tween.kill()
		_panel_tween = null


## ── 输入处理 ──────────────────────────────────
func _is_visible_control_under_mouse(control: Control) -> bool:
	return control.is_visible_in_tree() and control.get_global_rect().has_point(control.get_global_mouse_position())


func _is_story_skip_mouse_event(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed):
		return false

	var scene = get_tree().current_scene
	if scene == null:
		return false

	var skip_layer = scene.get_node_or_null("skipLayer")
	if skip_layer != null and skip_layer.get("visible") == true:
		return true

	var skip_button = scene.get("skip_button")
	if skip_button is Control and _is_visible_control_under_mouse(skip_button):
		return true

	var skip_button_layer = scene.get_node_or_null("skip_button_layer")
	if skip_button_layer == null:
		return false

	var child_skip_button = skip_button_layer.get_node_or_null("skip")
	return child_skip_button is Control and _is_visible_control_under_mouse(child_skip_button)


func _unhandled_input(event: InputEvent):
	if not _is_panel_active:
		return
	if not (event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed):
		return
	if _is_story_skip_mouse_event(event):
		return

	if _is_typing:
		_skip_typewriter()
	elif _is_text_complete:
		_fade_out_panel()
