extends CanvasLayer

@export var detail: RichTextLabel

@export var rui: Button
@export var qi: Button
@export var li: Button
@export var cu: Button
@export var yan: Button

@export var tips: Panel

@onready var tree_control: Control = $tree_control

@export var back: Button

@export var exit: Button

const CORE_ITEM_IDS = {
	"rui": "item_097",
	"qi": "item_099",
	"li": "item_100",
	"cu": "item_098",
	"yan": "item_101"
}

const BUTTON_DETAIL_TEMPLATES = {
	"rui": "武器篇\n[font_size=55][color=yellow]锐之魔核：",
	"qi": "技能篇\n[font_size=55][color=yellow]启之魔核：",
	"li": "领悟强化\n[font_size=55][color=yellow]砺之魔核：",
	"cu": "团队强化\n[font_size=55][color=yellow]簇之魔核：",
	"yan": "特殊强化\n[font_size=55][color=yellow]衍之魔核："
}

const STUDY_LAYER_PATH = "tree_control/study_layer"
const STUDY_TREE_PATH = "tree_control/study_layer/ClipPolygon/ClipRect/DragContainer/StudyTreeWeapon"

const TYPE_CORE_NAMES = {
	"weapon": "锐之魔核",
	"skill": "启之魔核",
	"learn": "砺之魔核",
	"team": "蔟之魔核",
	"special": "衍之魔核"
}

const TYPE_CORE_ITEM_IDS = {
	"weapon": "item_097",
	"skill": "item_099",
	"learn": "item_100",
	"team": "item_098",
	"special": "item_101"
}

const TOOLTIP_FONT_SIZE := 20
const HOLD_DURATION := 1.0

var _tooltip_canvas: CanvasLayer
var _tooltip_panel: Panel
var _tooltip_vbox: VBoxContainer
var _tooltip_name_label: Label
var _tooltip_current_label: Label
var _tooltip_next_label: Label
var _tooltip_cost_label: Label
var _tooltip_sep_current: HSeparator
var _tooltip_sep_next: HSeparator
var _tooltip_sep_cost: HSeparator
var _tooltip_precondition_label: Label
var _tooltip_sep_precondition: HSeparator
var _tooltip_font: Font
var _hovered_study_btn: Button = null
var _tooltip_request_id: int = 0

var _holding_btn: Button = null
var _hold_timer: float = 0.0
var _ring: Control = null
var _upgrade_done: bool = false

var _study_btns_connected: bool = false
var _btn_level_labels: Dictionary = {}


class RingProgress:
	extends Control

	var progress: float = 0.0
	var _particles: GPUParticles2D = null

	const CORNER_RADIUS := 8.0
	const BORDER_WIDTH := 3.0
	const BORDER_COLOR := Color(1.0, 1.0, 1.0, 0.9)
	const ARC_SEGMENTS := 6

	func _ready():
		_setup_particles()

	func _setup_particles():
		_particles = GPUParticles2D.new()
		_particles.emitting = false
		_particles.amount = 24
		_particles.lifetime = 0.7
		_particles.position = size / 2

		var mat = ParticleProcessMaterial.new()
		mat.direction = Vector3(0, 0, 0)
		mat.spread = 0.0
		mat.initial_velocity_min = 0.0
		mat.initial_velocity_max = 0.0
		mat.radial_velocity_min = 60.0
		mat.radial_velocity_max = 140.0
		mat.gravity = Vector3(0, 0, 0)
		mat.scale_min = 2.0
		mat.scale_max = 5.0
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		mat.emission_ring_radius = 48.0
		mat.emission_ring_inner_radius = 44.0
		mat.emission_ring_height = 0.0
		mat.emission_ring_axis = Vector3(0, 0, 1)

		var gradient = Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
		gradient.colors = PackedColorArray([
			Color(1.0, 1.0, 1.0, 1.0),
			Color(0.6, 0.6, 0.6, 0.6),
			Color(0.1, 0.1, 0.1, 0.0)
		])
		var color_ramp = GradientTexture1D.new()
		color_ramp.gradient = gradient
		mat.color_ramp = color_ramp

		var scale_curve = CurveTexture.new()
		var curve = Curve.new()
		curve.add_point(Vector2(0.0, 1.0))
		curve.add_point(Vector2(1.0, 0.0))
		scale_curve.curve = curve
		mat.scale_curve = scale_curve

		_particles.process_material = mat

		var img = Image.create(3, 3, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_particles.texture = ImageTexture.create_from_image(img)

		add_child(_particles)

	func _get_perimeter_points() -> PackedVector2Array:
		var pts := PackedVector2Array()
		var w = size.x
		var h = size.y
		var r = CORNER_RADIUS
		var m = BORDER_WIDTH / 2.0
		var left = m
		var right = w - m
		var top = m
		var bot = h - m
		var mx = w / 2.0

		pts.append(Vector2(mx, top))

		# Top-right corner
		var c = Vector2(right - r, top + r)
		for i in range(ARC_SEGMENTS + 1):
			var angle = - PI / 2 + (PI / 2) * float(i) / ARC_SEGMENTS
			pts.append(c + Vector2(cos(angle), sin(angle)) * r)

		# Bottom-right corner
		c = Vector2(right - r, bot - r)
		for i in range(ARC_SEGMENTS + 1):
			var angle = 0.0 + (PI / 2) * float(i) / ARC_SEGMENTS
			pts.append(c + Vector2(cos(angle), sin(angle)) * r)

		# Bottom-left corner
		c = Vector2(left + r, bot - r)
		for i in range(ARC_SEGMENTS + 1):
			var angle = PI / 2 + (PI / 2) * float(i) / ARC_SEGMENTS
			pts.append(c + Vector2(cos(angle), sin(angle)) * r)

		# Top-left corner
		c = Vector2(left + r, top + r)
		for i in range(ARC_SEGMENTS + 1):
			var angle = PI + (PI / 2) * float(i) / ARC_SEGMENTS
			pts.append(c + Vector2(cos(angle), sin(angle)) * r)

		pts.append(Vector2(mx, top))
		return pts

	func _draw():
		if progress <= 0.0:
			return

		var points = _get_perimeter_points()
		if points.size() < 2:
			return

		var lengths := [0.0]
		var total := 0.0
		for i in range(1, points.size()):
			total += points[i].distance_to(points[i - 1])
			lengths.append(total)

		if total <= 0:
			return

		var target_len = total * progress

		for i in range(1, points.size()):
			if lengths[i - 1] >= target_len:
				break
			var seg_end: Vector2
			if lengths[i] <= target_len:
				seg_end = points[i]
			else:
				var seg_len = lengths[i] - lengths[i - 1]
				var t_ratio = (target_len - lengths[i - 1]) / seg_len if seg_len > 0 else 0.0
				seg_end = points[i - 1].lerp(points[i], t_ratio)
			draw_line(points[i - 1], seg_end, BORDER_COLOR, BORDER_WIDTH, false)
			if lengths[i] > target_len:
				break

	func set_progress(val: float):
		progress = clamp(val, 0.0, 1.0)
		if _particles:
			_particles.emitting = progress > 0.0
		queue_redraw()


func _ready():
	StudyTreeConfig.load_data()

	if ResourceLoader.exists("res://AssetBundle/Uranus_Pixel_11Px.ttf"):
		_tooltip_font = load("res://AssetBundle/Uranus_Pixel_11Px.ttf")

	for btn in [rui, qi, li, cu, yan]:
		if btn:
			btn.modulate = Color(1, 1, 1, 0)

	var study_area = get_node_or_null(STUDY_LAYER_PATH)
	if study_area:
		study_area.visible = false
	if back:
		back.visible = false

	_connect_button_signals(rui, "rui")
	_connect_button_signals(qi, "qi")
	_connect_button_signals(li, "li")
	_connect_button_signals(cu, "cu")
	_connect_button_signals(yan, "yan")

	if exit:
		exit.pressed.connect(_on_exit_pressed)
	if rui:
		rui.pressed.connect(_on_rui_pressed)
	if back:
		back.pressed.connect(_on_back_pressed)

	_create_study_tooltip()


func _process(delta: float) -> void:
	if _holding_btn and not _upgrade_done:
		_hold_timer += delta
		var p = clamp(_hold_timer / HOLD_DURATION, 0.0, 1.0)
		if _ring:
			_ring.set_progress(p)
			_ring.global_position = _holding_btn.global_position
		if _hold_timer >= HOLD_DURATION:
			_upgrade_done = true
			_try_upgrade(_holding_btn)


# ===== 五行按钮信号 =====

func _connect_button_signals(btn: Button, name_str: String):
	if not btn:
		return
	btn.mouse_entered.connect(_on_button_mouse_entered.bind(name_str))
	btn.mouse_exited.connect(_on_button_mouse_exited.bind(name_str))


func _on_button_mouse_entered(name_str: String):
	var btn = get(name_str) as Button
	if btn and btn.is_inside_tree():
		var tween = create_tween()
		tween.tween_property(btn, "modulate:a", 1.0, 0.2)
	var item_id = CORE_ITEM_IDS[name_str]
	var count = Global.player_inventory.get(item_id, 0)
	detail.text = BUTTON_DETAIL_TEMPLATES[name_str] + str(count) + "[/color][/font_size]"


func _on_button_mouse_exited(name_str: String):
	var btn = get(name_str) as Button
	if btn and btn.is_inside_tree():
		var tween = create_tween()
		tween.tween_property(btn, "modulate:a", 0.0, 0.2)


# ===== 页面切换 =====

func _on_rui_pressed():
	tree_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel = get_node_or_null("Control/Panel")
	if panel:
		panel.play("detail")

	for btn in [rui, qi, li, cu, yan]:
		if btn:
			btn.visible = false

	var study_detail_panel = get_node_or_null("study_detail")
	if study_detail_panel:
		study_detail_panel.visible = false

	var study_area = get_node_or_null(STUDY_LAYER_PATH)
	if study_area:
		study_area.visible = true
		study_area.modulate = Color(1, 1, 1, 0)
		var tw = create_tween()
		tw.tween_property(study_area, "modulate:a", 1.0, 0.3)

	if back:
		back.visible = true
		back.modulate = Color(1, 1, 1, 0)
		var tw = create_tween()
		tw.tween_property(back, "modulate:a", 1.0, 0.3)

	if not _study_btns_connected:
		_connect_study_tree_buttons()


func _on_back_pressed():
	_hide_study_tooltip()
	_cancel_hold()

	tree_control.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel = get_node_or_null("Control/Panel")
	if panel:
		panel.stop()
		panel.animation = &"default"
		panel.frame = panel.sprite_frames.get_frame_count(&"default") - 1

	var study_area = get_node_or_null(STUDY_LAYER_PATH)
	if study_area:
		study_area.visible = false
	if back:
		back.visible = false

	for btn in [rui, qi, li, cu, yan]:
		if btn:
			btn.visible = true
			btn.modulate = Color(1, 1, 1, 0)


func _on_exit_pressed():
	_hide_study_tooltip()
	_cancel_hold()

	var tw = create_tween()
	tw.set_parallel(true)
	for child in get_children():
		if child.has_method("set_modulate"):
			tw.tween_property(child, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		visible = false
		for child in get_children():
			if child.has_method("set_modulate"):
				child.modulate.a = 1.0
	).set_delay(0.2)


# ===== 天赋树提示框创建 =====

func _create_study_tooltip() -> void:
	_tooltip_canvas = CanvasLayer.new()
	_tooltip_canvas.name = "StudyTooltipCanvas"
	_tooltip_canvas.layer = 100
	add_child(_tooltip_canvas)

	_tooltip_panel = Panel.new()
	_tooltip_panel.name = "StudyTooltipPanel"
	_tooltip_panel.visible = false
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_tooltip_panel.add_theme_stylebox_override("panel", style)
	_tooltip_canvas.add_child(_tooltip_panel)

	_tooltip_vbox = VBoxContainer.new()
	_tooltip_vbox.name = "VBox"
	_tooltip_vbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_tooltip_vbox.position = Vector2(10, 8)
	_tooltip_panel.add_child(_tooltip_vbox)

	_tooltip_name_label = Label.new()
	_setup_label_style(_tooltip_name_label)
	_tooltip_vbox.add_child(_tooltip_name_label)

	_tooltip_sep_current = HSeparator.new()
	_tooltip_vbox.add_child(_tooltip_sep_current)

	_tooltip_current_label = Label.new()
	_tooltip_current_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_current_label.custom_minimum_size = Vector2(200, 0)
	_setup_label_style(_tooltip_current_label)
	_tooltip_vbox.add_child(_tooltip_current_label)

	_tooltip_sep_next = HSeparator.new()
	_tooltip_vbox.add_child(_tooltip_sep_next)

	_tooltip_next_label = Label.new()
	_tooltip_next_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_next_label.custom_minimum_size = Vector2(200, 0)
	_setup_label_style(_tooltip_next_label)
	_tooltip_vbox.add_child(_tooltip_next_label)

	_tooltip_sep_cost = HSeparator.new()
	_tooltip_vbox.add_child(_tooltip_sep_cost)

	_tooltip_cost_label = Label.new()
	_setup_label_style(_tooltip_cost_label, Color(1.0, 0.85, 0.0))
	_tooltip_vbox.add_child(_tooltip_cost_label)

	_tooltip_sep_precondition = HSeparator.new()
	_tooltip_vbox.add_child(_tooltip_sep_precondition)

	_tooltip_precondition_label = Label.new()
	_setup_label_style(_tooltip_precondition_label, Color(0.7, 0.7, 0.7))
	_tooltip_vbox.add_child(_tooltip_precondition_label)

	_ring = RingProgress.new()
	_ring.name = "RingProgress"
	_ring.size = Vector2(108, 108)
	_ring.visible = false
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_canvas.add_child(_ring)


func _setup_label_style(label: Label, font_color: Color = Color.WHITE) -> void:
	if _tooltip_font:
		label.add_theme_font_override("font", _tooltip_font)
	label.add_theme_font_size_override("font_size", TOOLTIP_FONT_SIZE)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


# ===== 天赋树按钮信号 =====

func _connect_study_tree_buttons() -> void:
	var study_tree = get_node_or_null(STUDY_TREE_PATH)
	if not study_tree:
		return
	for child in study_tree.get_children():
		if child is Button:
			child.mouse_entered.connect(_on_study_btn_entered.bind(child))
			child.mouse_exited.connect(_on_study_btn_exited.bind(child))
			child.button_down.connect(_on_study_btn_down.bind(child))
			child.button_up.connect(_on_study_btn_up.bind(child))
			_create_level_label(child)
	_study_btns_connected = true


func _create_level_label(btn: Button) -> void:
	var entry = StudyTreeConfig.get_entry(btn.name)
	if entry.is_empty():
		return
	var lbl = Label.new()
	lbl.name = "LevelLabel"
	if _tooltip_font:
		lbl.add_theme_font_override("font", _tooltip_font)
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.offset_right = -6
	lbl.offset_bottom = -4
	btn.add_child(lbl)
	_btn_level_labels[btn.name] = lbl
	_update_level_label(btn)


func _update_level_label(btn: Button) -> void:
	var entry = StudyTreeConfig.get_entry(btn.name)
	if entry.is_empty():
		return
	var id: String = entry["id"]
	var max_level := int(entry.get("max_level", "1"))
	var current_level: int = Global.player_study_tree.get(id, 0)
	var lbl = _btn_level_labels.get(btn.name)
	if lbl:
		lbl.text = "%d/%d" % [current_level, max_level]
		if current_level >= max_level:
			lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
		else:
			lbl.add_theme_color_override("font_color", Color.WHITE)


func _on_study_btn_entered(btn: Button) -> void:
	_hovered_study_btn = btn
	_show_study_tooltip(btn)


func _on_study_btn_exited(btn: Button) -> void:
	if _hovered_study_btn == btn:
		_hovered_study_btn = null
	_hide_study_tooltip()
	_cancel_hold()


func _on_study_btn_down(btn: Button) -> void:
	var entry = StudyTreeConfig.get_entry(btn.name)
	if entry.is_empty():
		return
	var id: String = entry["id"]
	var max_level := int(entry.get("max_level", "1"))
	var current_level: int = Global.player_study_tree.get(id, 0)
	if current_level >= max_level:
		return

	# 递归检查前置条件
	var fail_reason = _check_precondition(id)
	if fail_reason != "":
		if tips:
			tips.start_animation(fail_reason, 0.5)
		return

	# 检查魔核是否足够
	var cast := int(entry.get("cast", "1"))
	var type: String = entry.get("type", "weapon")
	var core_item_id = TYPE_CORE_ITEM_IDS.get(type, "")
	var core_count = Global.player_inventory.get(core_item_id, 0)
	if core_count < cast:
		var core_name = TYPE_CORE_NAMES.get(type, type)
		if tips:
			tips.start_animation("%s不足" % core_name, 0.5)
		return

	_holding_btn = btn
	_hold_timer = 0.0
	_upgrade_done = false
	if _ring:
		_ring.visible = true
		_ring.set_progress(0.0)
		_ring.global_position = btn.global_position


func _on_study_btn_up(_btn: Button) -> void:
	_cancel_hold()


func _cancel_hold() -> void:
	_holding_btn = null
	_hold_timer = 0.0
	_upgrade_done = false
	if _ring:
		_ring.set_progress(0.0)
		_ring.visible = false


# ===== 提示框显示 =====

func _show_study_tooltip(btn: Button) -> void:
	var entry = StudyTreeConfig.get_entry(btn.name)
	if entry.is_empty() or entry.get("name", "") == "":
		_tooltip_panel.visible = false
		return

	var id: String = entry["id"]
	var display_name: String = entry["name"]
	var description: String = entry.get("description", "")
	var max_level := int(entry.get("max_level", "1"))
	var cast := int(entry.get("cast", "1"))
	var type: String = entry.get("type", "weapon")
	var v1: String = entry.get("value1", "")
	var v2: String = entry.get("value2", "")
	var v3: String = entry.get("value3", "")

	var current_level: int = Global.player_study_tree.get(id, 0)
	var is_maxed := current_level >= max_level

	_tooltip_name_label.text = "[font_size=29]%s  Lv.%d/%d [/font_size]" % [display_name, current_level, max_level]

	if max_level == 1:
		if current_level == 0:
			_tooltip_current_label.visible = false
			_tooltip_sep_current.visible = false
			_tooltip_next_label.text = "下一等级：" + description
			_tooltip_next_label.visible = true
			_tooltip_sep_next.visible = true
		else:
			_tooltip_current_label.text = "当前等级：" + description
			_tooltip_current_label.visible = true
			_tooltip_sep_current.visible = true
			_tooltip_next_label.text = "此项修习已至极境"
			_tooltip_next_label.visible = true
			_tooltip_sep_next.visible = true
	else:
		_tooltip_current_label.text = "当前等级：" + _replace_placeholders(description, v1, v2, v3, current_level)
		_tooltip_current_label.visible = true
		_tooltip_sep_current.visible = true
		if is_maxed:
			_tooltip_next_label.text = "此项修习已至极境"
		else:
			_tooltip_next_label.text = "下一等级：" + _replace_placeholders(description, v1, v2, v3, current_level + 1)
		_tooltip_next_label.visible = true
		_tooltip_sep_next.visible = true

	if is_maxed:
		_tooltip_cost_label.visible = false
		_tooltip_sep_cost.visible = false
	else:
		var core_name = TYPE_CORE_NAMES.get(type, type)
		var core_item_id = TYPE_CORE_ITEM_IDS.get(type, "")
		var core_count = Global.player_inventory.get(core_item_id, 0)
		_tooltip_cost_label.text = "消耗 %s %d 个（当前持有：%d）" % [core_name, cast, core_count]
		_tooltip_cost_label.visible = true
		_tooltip_sep_cost.visible = true

	# 前置条件
	var precondition_id: String = entry.get("precondition", "")
	var precondition_level_str: String = entry.get("precondition_level", "")
	if precondition_id != "" and precondition_level_str != "":
		var pre_entry = StudyTreeConfig.get_entry(precondition_id)
		var pre_name = pre_entry.get("name", precondition_id) if not pre_entry.is_empty() else precondition_id
		_tooltip_precondition_label.text = "前置条件：%s 达到%s级" % [pre_name, precondition_level_str]
		_tooltip_precondition_label.visible = true
		_tooltip_sep_precondition.visible = true
	else:
		_tooltip_precondition_label.visible = false
		_tooltip_sep_precondition.visible = false

	_tooltip_panel.size = Vector2.ZERO
	_tooltip_panel.custom_minimum_size = Vector2.ZERO
	_tooltip_panel.global_position = Vector2(-10000, -10000)
	_tooltip_panel.visible = true

	_tooltip_request_id += 1
	var request_id = _tooltip_request_id

	await get_tree().process_frame
	await get_tree().process_frame

	if request_id != _tooltip_request_id:
		return
	if _hovered_study_btn != btn:
		return

	var content_size = _tooltip_vbox.get_combined_minimum_size()
	var panel_size = content_size + Vector2(20, 16)
	_tooltip_panel.custom_minimum_size = panel_size
	_tooltip_panel.size = panel_size
	_position_tooltip(btn)
	# 渐入动画 0.2秒
	_tooltip_panel.modulate.a = 0.0
	var fade_in_tween = create_tween()
	fade_in_tween.tween_property(_tooltip_panel, "modulate:a", 1.0, 0.2)


func _position_tooltip(btn: Button) -> void:
	var btn_pos = btn.global_position
	var tooltip_pos = btn_pos + Vector2(btn.size.x + 10, 0)
	var vp_size = get_viewport().get_visible_rect().size
	if tooltip_pos.x + _tooltip_panel.size.x > vp_size.x:
		tooltip_pos.x = btn_pos.x - _tooltip_panel.size.x - 10
	if tooltip_pos.y + _tooltip_panel.size.y > vp_size.y:
		tooltip_pos.y = vp_size.y - _tooltip_panel.size.y - 10
	if tooltip_pos.y < 0:
		tooltip_pos.y = 0
	_tooltip_panel.global_position = tooltip_pos


func _hide_study_tooltip() -> void:
	_tooltip_request_id += 1
	if _tooltip_panel and _tooltip_panel.visible:
		var fade_out_tween = create_tween()
		fade_out_tween.tween_property(_tooltip_panel, "modulate:a", 0.0, 0.2)
		fade_out_tween.tween_callback(func(): _tooltip_panel.visible = false)


func _replace_placeholders(text: String, v1: String, v2: String, v3: String, level: int) -> String:
	var result = text
	result = result.replace("$$", str(int(v1) * level) if v1 != "" else "0")
	result = result.replace("##", str(int(v2) * level) if v2 != "" else "0")
	result = result.replace("@@", str(int(v3) * level) if v3 != "" else "0")
	return result


# ===== 升级逻辑 =====

func _try_upgrade(btn: Button) -> void:
	var entry = StudyTreeConfig.get_entry(btn.name)
	if entry.is_empty():
		return

	var id: String = entry["id"]
	var max_level := int(entry.get("max_level", "1"))
	var cast := int(entry.get("cast", "1"))
	var type: String = entry.get("type", "weapon")
	var current_level: int = Global.player_study_tree.get(id, 0)

	if current_level >= max_level:
		return

	var core_item_id = TYPE_CORE_ITEM_IDS.get(type, "")
	var core_count = Global.player_inventory.get(core_item_id, 0)

	if core_count < cast:
		var core_name = TYPE_CORE_NAMES.get(type, type)
		if tips:
			tips.start_animation("%s不足" % core_name, 0.5)
		return

	Global.player_inventory[core_item_id] = core_count - cast
	Global.player_study_tree[id] = current_level + 1
	Global.save_game()

	_cancel_hold()
	_update_level_label(btn)
	_show_study_tooltip(btn)

	var display_name: String = entry.get("name", id)
	if tips:
		tips.start_animation("%s 修习成功" % display_name, 0.5)


# ===== 前置条件递归检查 =====

func _check_precondition(id: String, _visited: Dictionary = {}) -> String:
	var fails: Array = []
	_collect_precondition_fails(id, _visited, fails)
	if fails.is_empty():
		return ""
	return "需" + "、".join(fails)


func _collect_precondition_fails(id: String, _visited: Dictionary, fails: Array) -> void:
	if _visited.has(id):
		return
	_visited[id] = true

	var entry = StudyTreeConfig.get_entry(id)
	if entry.is_empty():
		return

	var pre_id: String = entry.get("precondition", "")
	var pre_level_str: String = entry.get("precondition_level", "")
	if pre_id == "" or pre_level_str == "":
		return

	# 先递归检查更深层的前置条件
	_collect_precondition_fails(pre_id, _visited, fails)

	var pre_level := int(pre_level_str)
	var pre_current: int = Global.player_study_tree.get(pre_id, 0)
	if pre_current < pre_level:
		var pre_entry = StudyTreeConfig.get_entry(pre_id)
		var pre_name = pre_entry.get("name", pre_id) if not pre_entry.is_empty() else pre_id
		fails.append("%s%d级" % [pre_name, pre_level])
