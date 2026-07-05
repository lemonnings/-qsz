extends CanvasLayer

const ZHUAZHUAJUCHUI_SCRIPT = preload("res://Script/skill/zhuazhuajuchui.gd")

@export var continue_button: Button
@export var dps_button: Button
@export var setting_button: Button
@export var exit_button: Button

@export var tips_panel: Panel
@export var ok_button: Button
@export var return_button: Button
@export var dps_panel: Panel
@export var dps_return_button: Button

var main_panel: Panel
var setting_layer_ref: Panel # 由 battle_canvas_layer 传入
var dps_title_label: RichTextLabel
var dps_container: GridContainer
var dps_panel_example: Panel
var dps_detail_example: RichTextLabel
var dps_change_button: Button
var _show_heal_shield_stats: bool = false
var _base_layer: int = 30
var _tree_was_paused_before_pause_menu: bool = false
var _in_menu_before_pause_menu: bool = false
var attr_frame_panel: Panel = null
var attr_container: Container = null
var attr_panel_example: Panel = null
var attr_left_button: Button = null
var attr_right_button: Button = null
var attr_tooltip_panel: Panel = null
var attr_tooltip_title: Label = null
var attr_tooltip_value: Label = null
var attr_tooltip_desc: RichTextLabel = null
var attr_tooltip_tween: Tween = null
var attr_tooltip_hover_id: int = 0
var attr_entries: Array[Dictionary] = []
var attr_panels: Array[Panel] = []
var attr_hovered_panel: Panel = null
var attr_page: int = 0
var weapon_frame_panel: Panel = null
var weapon_container: Container = null
var weapon_panel_example: Panel = null
var lingwu_container: FlowContainer = null
var lingwu_panel_example: Panel = null
var weapon_left_button: Button = null
var weapon_right_button: Button = null
var weapon_pages: Array[Dictionary] = []
var lingwu_pages: Array[Array] = []
var weapon_panel_page: int = 0
var lingwu_panels: Array[Panel] = []
var lingwu_hovered_panel: Panel = null
var weapon_discard_button: Button = null
var weapon_discard_page_data: Dictionary = {}
var weapon_discard_hold_elapsed: float = 0.0
var weapon_discard_hold_active: bool = false
var weapon_discard_hold_completed: bool = false

const FADE_DURATION: float = 0.15
const PAGE_FADE_DURATION: float = 0.08
const WEAPON_DISCARD_HOLD_SECONDS: float = 1.0
const PAUSE_MENU_LAYER: int = 9999
const DPS_PANEL_LAYER: int = 9999
const DPS_PANEL_Z_INDEX: int = 4096
const SETTING_PANEL_Z_INDEX: int = 4097
const DPS_ENTRY_WEAPON_ICON_SIZE: Vector2 = Vector2(72.0, 72.0)
const ATTRS_PER_PAGE: int = 13
const ATTR_TOOLTIP_WIDTH: float = 260.0
const LINGWU_FALLBACK_PER_PAGE: int = 5
const WEAPON_PANEL_ORDER: Array[Dictionary] = [
	{"faction": "swordqi", "reward_id": "SwordQi", "level": "main_skill_swordQi"},
	{"faction": "branch", "reward_id": "Branch", "level": "main_skill_branch"},
	{"faction": "moyan", "reward_id": "Moyan", "level": "main_skill_moyan"},
	{"faction": "ringfire", "reward_id": "RingFire", "level": "main_skill_ringFire"},
	{"faction": "riyan", "reward_id": "Riyan", "level": "main_skill_riyan"},
	{"faction": "thunder", "reward_id": "Thunder", "level": "main_skill_thunder"},
	{"faction": "bloodwave", "reward_id": "Bloodwave", "level": "main_skill_bloodwave"},
	{"faction": "bloodboardsword", "reward_id": "BloodBoardSword", "level": "main_skill_bloodboardsword"},
	{"faction": "ice", "reward_id": "Ice", "level": "main_skill_ice"},
	{"faction": "thunderbreak", "reward_id": "ThunderBreak", "level": "main_skill_thunder_break"},
	{"faction": "lightbullet", "reward_id": "LightBullet", "level": "main_skill_light_bullet"},
	{"faction": "water", "reward_id": "Water", "level": "main_skill_water"},
	{"faction": "qiankun", "reward_id": "Qiankun", "level": "main_skill_qiankun"},
	{"faction": "xuanwu", "reward_id": "Xuanwu", "level": "main_skill_xuanwu"},
	{"faction": "xunfeng", "reward_id": "Xunfeng", "level": "main_skill_xunfeng"},
	{"faction": "genshan", "reward_id": "Genshan", "level": "main_skill_genshan"},
	{"faction": "duize", "reward_id": "Duize", "level": "main_skill_duize"},
	{"faction": "holylight", "reward_id": "HolyLight", "level": "main_skill_holylight"},
	{"faction": "dragonwind", "reward_id": "DragonWind", "level": "main_skill_dragonwind"},
	{"faction": "qigong", "reward_id": "Qigong", "level": "main_skill_qigong"},
	{"faction": "zhuazhuajuchui", "reward_id": "Zhuazhuajuchui", "level": "main_skill_zhuazhuajuchui"},
	{"faction": "yujian", "reward_id": "Yujian", "level": "main_skill_yujian"}
]

func _ready() -> void:
	main_panel = continue_button.get_parent()
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	continue_button.pressed.connect(_on_continue_pressed)
	if dps_button:
		dps_button.pressed.connect(_on_dps_pressed)
	setting_button.pressed.connect(_on_setting_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	ok_button.pressed.connect(_on_ok_pressed)
	return_button.pressed.connect(_on_return_pressed)
	if dps_return_button:
		dps_return_button.pressed.connect(_on_dps_return_pressed)
	
	visible = false
	tips_panel.visible = false
	_init_dps_panel()
	_init_attr_panel()
	_init_weapon_panel()

func _process(_delta: float) -> void:
	_update_attr_hover_by_mouse()
	_update_lingwu_hover_by_mouse()
	_process_weapon_discard_hold(_delta)

func _init_dps_panel() -> void:
	if not dps_panel:
		return
	_base_layer = layer
	dps_panel.z_as_relative = false
	dps_panel.z_index = DPS_PANEL_Z_INDEX
	dps_panel.visible = false
	dps_title_label = dps_panel.get_node_or_null("RichTextLabel") as RichTextLabel
	dps_container = dps_panel.get_node_or_null("DPSContainer") as GridContainer
	dps_detail_example = dps_panel.get_node_or_null("dps_detail") as RichTextLabel
	if dps_detail_example:
		dps_detail_example.visible = false
	dps_change_button = dps_panel.get_node_or_null("change") as Button
	if dps_change_button:
		dps_change_button.pressed.connect(_on_dps_change_pressed)
	if dps_container:
		dps_panel_example = dps_container.get_node_or_null("PanelExample") as Panel
		if dps_panel_example:
			dps_panel_example.visible = false

func _init_attr_panel() -> void:
	attr_frame_panel = get_node_or_null("Panel4") as Panel
	attr_container = get_node_or_null("AttrContainer") as Container
	if attr_container == null:
		attr_container = get_node_or_null("VBoxContainer") as Container
	if attr_container:
		attr_panel_example = attr_container.get_node_or_null("Attr") as Panel
		if attr_panel_example == null:
			attr_panel_example = attr_container.get_node_or_null("Panel") as Panel
		if attr_panel_example:
			attr_panel_example.visible = false
	attr_left_button = get_node_or_null("Panel4/left") as Button
	if attr_left_button == null:
		attr_left_button = get_node_or_null("Panel4/Left") as Button
	if attr_left_button == null:
		attr_left_button = get_node_or_null("left") as Button
	if attr_left_button == null:
		attr_left_button = get_node_or_null("Left") as Button
	if attr_left_button == null:
		attr_left_button = find_child("left", true, false) as Button
	if attr_left_button == null:
		attr_left_button = find_child("Left", true, false) as Button
	attr_right_button = get_node_or_null("Panel4/right") as Button
	if attr_right_button == null:
		attr_right_button = get_node_or_null("Panel4/Right") as Button
	if attr_right_button == null:
		attr_right_button = get_node_or_null("right") as Button
	if attr_right_button == null:
		attr_right_button = get_node_or_null("Right") as Button
	if attr_right_button == null:
		attr_right_button = find_child("right", true, false) as Button
	if attr_right_button == null:
		attr_right_button = find_child("Right", true, false) as Button
	if attr_left_button and not attr_left_button.pressed.is_connected(_on_attr_left_pressed):
		attr_left_button.pressed.connect(_on_attr_left_pressed)
	if attr_right_button and not attr_right_button.pressed.is_connected(_on_attr_right_pressed):
		attr_right_button.pressed.connect(_on_attr_right_pressed)
	_create_attr_tooltip()

func _init_weapon_panel() -> void:
	weapon_frame_panel = get_node_or_null("Panel5") as Panel
	weapon_container = get_node_or_null("WeaponContainer") as Container
	if weapon_container:
		weapon_panel_example = weapon_container.get_node_or_null("Weapon") as Panel
		if weapon_panel_example:
			weapon_panel_example.visible = false
	lingwu_container = get_node_or_null("LingwuContainer") as FlowContainer
	if lingwu_container:
		lingwu_panel_example = lingwu_container.get_node_or_null("Lingwu") as Panel
		if lingwu_panel_example:
			lingwu_panel_example.visible = false
		lingwu_container.visible = false
	weapon_left_button = get_node_or_null("Panel5/left") as Button
	weapon_right_button = get_node_or_null("Panel5/right") as Button
	if weapon_left_button and not weapon_left_button.pressed.is_connected(_on_weapon_left_pressed):
		weapon_left_button.pressed.connect(_on_weapon_left_pressed)
	if weapon_right_button and not weapon_right_button.pressed.is_connected(_on_weapon_right_pressed):
		weapon_right_button.pressed.connect(_on_weapon_right_pressed)
	_set_weapon_panel_visible(false)

func _set_attr_panel_visible(is_visible: bool) -> void:
	if attr_frame_panel != null:
		attr_frame_panel.visible = is_visible
	if attr_container != null:
		attr_container.visible = is_visible
	if not is_visible:
		attr_hovered_panel = null
		if attr_left_button != null:
			attr_left_button.visible = false
		if attr_right_button != null:
			attr_right_button.visible = false
		_hide_attr_tooltip()
	elif attr_entries.size() > 0:
		var max_page: int = _get_attr_max_page()
		if attr_left_button != null:
			attr_left_button.visible = attr_page > 0
		if attr_right_button != null:
			attr_right_button.visible = attr_page < max_page

func _set_weapon_panel_visible(is_visible: bool) -> void:
	if weapon_frame_panel != null:
		weapon_frame_panel.visible = is_visible
	if weapon_container != null:
		weapon_container.visible = is_visible
	if lingwu_container != null:
		lingwu_container.visible = false
	if not is_visible:
		lingwu_hovered_panel = null
		_cancel_weapon_discard_hold()
		if weapon_left_button != null:
			weapon_left_button.visible = false
		if weapon_right_button != null:
			weapon_right_button.visible = false
		_hide_attr_tooltip()
		return
	_update_weapon_nav_buttons()

func _set_side_panels_visible(is_visible: bool) -> void:
	_set_attr_panel_visible(is_visible)
	_set_weapon_panel_visible(is_visible)

func _set_side_panels_modulate_alpha(alpha: float) -> void:
	for node in _get_side_panel_nodes():
		if node != null:
			node.modulate.a = alpha

func _get_side_panel_nodes() -> Array[CanvasItem]:
	var nodes: Array[CanvasItem] = []
	for node in [attr_frame_panel, attr_container, weapon_frame_panel, weapon_container, lingwu_container]:
		if node != null and node is CanvasItem:
			nodes.append(node as CanvasItem)
	return nodes

func _tween_side_panels_alpha(tween: Tween, alpha: float, duration: float) -> void:
	for node in _get_side_panel_nodes():
		tween.parallel().tween_property(node, "modulate:a", alpha, duration)

func _fade_out_side_panels() -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween_side_panels_alpha(tween, 0.0, FADE_DURATION)
	await tween.finished
	_set_side_panels_visible(false)

func _fade_in_side_panels() -> void:
	_set_side_panels_modulate_alpha(0.0)
	_set_side_panels_visible(true)
	_render_attr_page(false)
	_render_weapon_panel_page(false)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween_side_panels_alpha(tween, 1.0, FADE_DURATION)

func _create_attr_tooltip() -> void:
	attr_tooltip_panel = Panel.new()
	attr_tooltip_panel.name = "AttrTooltipPanel"
	attr_tooltip_panel.visible = false
	attr_tooltip_panel.z_index = 1000
	attr_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	attr_tooltip_panel.add_theme_stylebox_override("panel", style)
	add_child(attr_tooltip_panel)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
	vbox.position = Vector2(10, 8)
	attr_tooltip_panel.add_child(vbox)
	attr_tooltip_title = Label.new()
	attr_tooltip_title.name = "NameLabel"
	_setup_attr_tooltip_label(attr_tooltip_title)
	vbox.add_child(attr_tooltip_title)
	var sep1: HSeparator = HSeparator.new()
	vbox.add_child(sep1)
	attr_tooltip_value = Label.new()
	attr_tooltip_value.name = "ValueLabel"
	_setup_attr_tooltip_label(attr_tooltip_value, Color(1.0, 0.85, 0.0))
	vbox.add_child(attr_tooltip_value)
	var sep2: HSeparator = HSeparator.new()
	vbox.add_child(sep2)
	attr_tooltip_desc = RichTextLabel.new()
	attr_tooltip_desc.name = "DescLabel"
	attr_tooltip_desc.bbcode_enabled = true
	attr_tooltip_desc.fit_content = true
	attr_tooltip_desc.scroll_active = false
	attr_tooltip_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	attr_tooltip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	attr_tooltip_desc.custom_minimum_size = Vector2(ATTR_TOOLTIP_WIDTH, 0)
	_setup_attr_tooltip_rich_label(attr_tooltip_desc)
	vbox.add_child(attr_tooltip_desc)

func _setup_attr_tooltip_label(label: Label, font_color: Color = Color.WHITE) -> void:
	var font: Font = load("res://AssetBundle/Uranus_Pixel_11Px.ttf") as Font
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)

func _setup_attr_tooltip_rich_label(label: RichTextLabel, font_color: Color = Color.WHITE) -> void:
	var font: Font = load("res://AssetBundle/Uranus_Pixel_11Px.ttf") as Font
	if font:
		label.add_theme_font_override("normal_font", font)
	label.add_theme_font_size_override("normal_font_size", 24)
	label.add_theme_color_override("default_color", font_color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)

## 由 battle_canvas_layer 调用，传入设定面板引用并连接其关闭按钮
func setup(p_setting_layer: Panel) -> void:
	setting_layer_ref = p_setting_layer
	setting_layer_ref.process_mode = Node.PROCESS_MODE_ALWAYS
	if setting_layer_ref.get_parent() != self:
		setting_layer_ref.reparent(self , true)
	setting_layer_ref.z_as_relative = false
	setting_layer_ref.z_index = SETTING_PANEL_Z_INDEX
	setting_layer_ref.visible = false
	var exit_btn = p_setting_layer.get_node_or_null("Exit2")
	if exit_btn:
		exit_btn.pressed.connect(_close_setting)
	# 初始化设定面板UI控件的信号连接
	_setup_settings_ui(p_setting_layer)


## 初始化设定UI控件，连接信号到 SettingsManager
func _setup_settings_ui(panel: Panel) -> void:
	# 声音设置
	var main_volume = panel.get_node_or_null("shengyin2/MainVolume") as HSlider
	var bgm_volume = panel.get_node_or_null("shengyin2/BGMVolume") as HSlider
	var se_volume = panel.get_node_or_null("shengyin2/SEVolume") as HSlider
	var bg_volume = panel.get_node_or_null("shengyin2/BGVolume") as HSlider

	if main_volume:
		main_volume.min_value = 0.0
		main_volume.max_value = 1.0
		main_volume.step = 0.01
		main_volume.value = Global.audio_manager.get_master_volume()
		main_volume.value_changed.connect(func(v): Global.audio_manager.set_master_volume(v); Global.save_game())
	if bgm_volume:
		bgm_volume.min_value = 0.0
		bgm_volume.max_value = 1.0
		bgm_volume.step = 0.01
		bgm_volume.value = Global.audio_manager.get_bgm_volume()
		bgm_volume.value_changed.connect(func(v): Global.audio_manager.set_bgm_volume(v); Global.save_game())
	if se_volume:
		se_volume.min_value = 0.0
		se_volume.max_value = 1.0
		se_volume.step = 0.01
		se_volume.value = Global.audio_manager.get_sfx_volume()
		se_volume.value_changed.connect(func(v): Global.audio_manager.set_sfx_volume(v); Global.save_game())
	if bg_volume:
		bg_volume.min_value = 0.0
		bg_volume.max_value = 1.0
		bg_volume.step = 0.01
		bg_volume.value = Global.audio_manager.get_bg_volume()
		bg_volume.value_changed.connect(func(v): Global.audio_manager.set_bg_volume(v); Global.save_game())

	# 画面设置
	var picture_root_path := _setup_picture_panel_for_device(panel)
	var screen_resolution = panel.get_node_or_null(picture_root_path + "/ScreenResolution") as OptionButton
	var full_screen = panel.get_node_or_null(picture_root_path + "/FullScreen") as CheckButton
	var vignetting = panel.get_node_or_null(picture_root_path + "/Vignetting") as CheckButton
	var noborder = panel.get_node_or_null(picture_root_path + "/Noborder") as CheckButton

	if screen_resolution:
		screen_resolution.selected = Global.settings_manager.get_current_resolution_index()
		screen_resolution.item_selected.connect(func(idx): Global.settings_manager.set_resolution(idx); Global.save_game())
	if full_screen:
		full_screen.button_pressed = Global.settings_manager.is_fullscreen_enabled()
		full_screen.toggled.connect(func(p): Global.settings_manager.set_fullscreen(p); Global.save_game())
	if vignetting:
		vignetting.button_pressed = Global.settings_manager.is_vignetting_enabled()
		vignetting.toggled.connect(func(p): Global.settings_manager.set_vignetting(p); Global.save_game())
	if noborder:
		noborder.button_pressed = Global.settings_manager.is_noborder_enabled()
		noborder.toggled.connect(func(p): Global.settings_manager.set_noborder(p); Global.save_game())

	# 游戏设置
	var particle = panel.get_node_or_null("youxi/Particle") as CheckButton
	var damage_show = panel.get_node_or_null("youxi/DamageShow") as CheckButton
	var damage_type_item = panel.get_node_or_null("youxi/DamageTypeItem") as OptionButton
	var moretip = panel.get_node_or_null("youxi/moretip") as CheckButton
	var player_hp_bar = panel.get_node_or_null("youxi/playerhpbar") as CheckButton
	var drop_visible = panel.get_node_or_null("youxi/dropvisible") as CheckButton
	var drop_mater = panel.get_node_or_null("youxi/dropmater") as CheckButton
	var time_slow_button = panel.get_node_or_null("youxi/TimeSlow") as CheckButton
	var super_test_button = panel.get_node_or_null("youxi/SuperTest") as CheckButton

	if particle:
		particle.set_pressed_no_signal(Global.settings_manager.is_particle_enabled())
		particle.toggled.connect(func(p): Global.settings_manager.set_particle(p); Global.save_game())
	if moretip:
		moretip.set_pressed_no_signal(Global.moretip)
		moretip.toggled.connect(func(p): Global.set_moretip_enabled(p); Global.save_game())
	if damage_show:
		damage_show.set_pressed_no_signal(Global.settings_manager.is_damage_show_enabled())
		damage_show.toggled.connect(func(p):
			Global.settings_manager.set_damage_show(p)
			if damage_type_item: damage_type_item.disabled = not p
			Global.save_game()
		)
	if damage_type_item:
		damage_type_item.clear()
		damage_type_item.add_item("原始数字")
		damage_type_item.add_item("中式缩写（万/亿）")
		damage_type_item.add_item("英式缩写（k/m/b）")
		damage_type_item.selected = Global.damage_show_type
		damage_type_item.disabled = not Global.settings_manager.is_damage_show_enabled()
		damage_type_item.item_selected.connect(func(idx): Global.damage_show_type = idx; Global.save_game())
	if player_hp_bar:
		player_hp_bar.set_pressed_no_signal(Global.settings_manager.is_player_hp_bar_enabled())
		player_hp_bar.toggled.connect(func(p):
			Global.settings_manager.set_player_hp_bar(p)
			Global.save_game()
		)
	if drop_visible:
		drop_visible.set_pressed_no_signal(Global.settings_manager.is_drop_visible_enabled())
		drop_visible.toggled.connect(func(p):
			Global.settings_manager.set_drop_visible(p)
			Global.save_game()
		)
	if drop_mater:
		drop_mater.set_pressed_no_signal(Global.settings_manager.is_drop_mater_enabled())
		drop_mater.toggled.connect(func(p):
			Global.settings_manager.set_drop_mater(p)
			Global.save_game()
		)
	if time_slow_button:
		time_slow_button.set_pressed_no_signal(Global.time_slow_enabled)
		time_slow_button.toggled.connect(func(p): Global.time_slow_enabled = p; Global.save_game())
	if super_test_button:
		super_test_button.set_pressed_no_signal(Global.is_test)
		super_test_button.toggled.connect(func(p): Global.is_test = p; Global.save_game())

func _setup_picture_panel_for_device(panel: Panel) -> String:
	var desktop_panel := panel.get_node_or_null("huamian2") as Control
	var mobile_panel := panel.get_node_or_null("huamian_mobile") as Control
	var use_mobile := Global.is_mobile_input_mode()
	if desktop_panel:
		desktop_panel.visible = not use_mobile
	if mobile_panel:
		mobile_panel.visible = use_mobile
	return "huamian_mobile" if use_mobile and mobile_panel != null else "huamian2"

# ==================== 打开 / 关闭暂停菜单 ====================

func can_open_pause_menu() -> bool:
	var qi_vortex_shop_open := _is_qi_vortex_shop_open()
	var level_up_open := Global.is_level_up
	if get_tree().paused and not qi_vortex_shop_open and not level_up_open:
		return false
	if Global.in_menu and not qi_vortex_shop_open and not level_up_open:
		return false
	if Global.in_town:
		return false
	if PC.is_game_over or Global.victory_collecting:
		return false
	if SceneChange and SceneChange.has_method("is_scene_transition_active") and SceneChange.is_scene_transition_active():
		return false
	var current_scene: Node = get_tree().current_scene
	if current_scene != null and current_scene.scene_file_path == "res://Scenes/global/loading.tscn":
		return false
	return true

func _is_qi_vortex_shop_open() -> bool:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return false
	var manager: Node = current_scene.get("qi_vortex_shop_manager") if _object_has_property(current_scene, "qi_vortex_shop_manager") else null
	if manager != null and is_instance_valid(manager) and manager.has_method("is_open"):
		return manager.call("is_open") == true
	return false

func _object_has_property(object: Object, property_name: String) -> bool:
	for property_info: Dictionary in object.get_property_list():
		if str(property_info.get("name", "")) == property_name:
			return true
	return false

func open() -> void:
	if not can_open_pause_menu():
		return
	_tree_was_paused_before_pause_menu = get_tree().paused
	_in_menu_before_pause_menu = Global.in_menu
	layer = PAUSE_MENU_LAYER
	visible = true
	main_panel.visible = true
	_set_side_panels_modulate_alpha(0.0)
	_set_attr_panel_visible(true)
	_refresh_attr_panel()
	_set_weapon_panel_visible(true)
	_refresh_weapon_panel()
	main_panel.modulate = Color(1, 1, 1, 0)
	tips_panel.visible = false
	# 暂停技能节点计时（武器冷却等）
	_pause_skill_nodes(true)
	# 暂停玩家武器Timer
	if PC.player_instance and is_instance_valid(PC.player_instance) and PC.player_instance.has_method("pause_all_skill_cooldowns"):
		PC.player_instance.pause_all_skill_cooldowns(true)
	# 暂停敌人和玩家动画
	_pause_all_animations()
	get_tree().paused = true
	Global.in_menu = true
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(main_panel, "modulate:a", 1.0, FADE_DURATION)
	_tween_side_panels_alpha(tween, 1.0, FADE_DURATION)

func close() -> void:
	_hide_attr_tooltip()
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(main_panel, "modulate:a", 0.0, FADE_DURATION)
	_tween_side_panels_alpha(tween, 0.0, FADE_DURATION)
	await tween.finished
	_set_side_panels_visible(false)
	visible = false
	layer = _base_layer
	get_tree().paused = _tree_was_paused_before_pause_menu
	Global.in_menu = _in_menu_before_pause_menu
	if not _tree_was_paused_before_pause_menu:
		# 恢复技能节点暂停状态
		_pause_skill_nodes(false)
		# 恢复玩家武器Timer
		if PC.player_instance and is_instance_valid(PC.player_instance) and PC.player_instance.has_method("pause_all_skill_cooldowns"):
			PC.player_instance.pause_all_skill_cooldowns(false)
		# 恢复敌人和玩家动画
		_resume_all_animations()
	_tree_was_paused_before_pause_menu = false
	_in_menu_before_pause_menu = false

# ==================== 按钮回调 ====================

func _on_continue_pressed() -> void:
	close()

func _on_setting_pressed() -> void:
	if not setting_layer_ref:
		return
	_fade_out_side_panels()
	setting_layer_ref.modulate = Color(1, 1, 1, 0)
	setting_layer_ref.z_as_relative = false
	setting_layer_ref.z_index = SETTING_PANEL_Z_INDEX
	setting_layer_ref.move_to_front()
	setting_layer_ref.visible = true
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(setting_layer_ref, "modulate:a", 1.0, FADE_DURATION)

func _on_dps_pressed() -> void:
	if not dps_panel:
		return
	_fade_out_side_panels()
	_show_heal_shield_stats = false
	layer = DPS_PANEL_LAYER
	dps_panel.z_as_relative = false
	dps_panel.z_index = DPS_PANEL_Z_INDEX
	dps_panel.move_to_front()
	_refresh_dps_panel()
	main_panel.visible = false
	dps_panel.modulate = Color(1, 1, 1, 0)
	dps_panel.visible = true
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(dps_panel, "modulate:a", 1.0, FADE_DURATION)

func _on_dps_return_pressed() -> void:
	if not dps_panel:
		return
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(dps_panel, "modulate:a", 0.0, FADE_DURATION)
	await tween.finished
	dps_panel.visible = false
	_show_heal_shield_stats = false
	layer = PAUSE_MENU_LAYER
	main_panel.visible = true
	_fade_in_side_panels()

func _on_dps_change_pressed() -> void:
	_show_heal_shield_stats = not _show_heal_shield_stats
	_refresh_dps_panel()

func _on_attr_left_pressed() -> void:
	if attr_page <= 0:
		return
	attr_page -= 1
	_fade_attr_page_change()

func _on_attr_right_pressed() -> void:
	var max_page: int = _get_attr_max_page()
	if attr_page >= max_page:
		return
	attr_page += 1
	_fade_attr_page_change()

func _on_weapon_left_pressed() -> void:
	if weapon_panel_page <= 0:
		return
	weapon_panel_page -= 1
	_fade_weapon_page_change()

func _on_weapon_right_pressed() -> void:
	var max_page: int = _get_weapon_panel_max_page()
	if weapon_panel_page >= max_page:
		return
	weapon_panel_page += 1
	_fade_weapon_page_change()

func _refresh_attr_panel() -> void:
	if attr_container == null or attr_panel_example == null:
		return
	attr_entries = _build_attr_entries()
	attr_page = clampi(attr_page, 0, _get_attr_max_page())
	_render_attr_page(false)

func _refresh_weapon_panel() -> void:
	if weapon_container == null or weapon_panel_example == null or lingwu_container == null or lingwu_panel_example == null:
		return
	weapon_pages = _build_weapon_pages()
	lingwu_pages = _build_lingwu_pages()
	weapon_panel_page = clampi(weapon_panel_page, 0, _get_weapon_panel_max_page())
	_render_weapon_panel_page(false)

func _get_attr_max_page() -> int:
	if attr_entries.is_empty():
		return 0
	return int(ceil(float(attr_entries.size()) / float(ATTRS_PER_PAGE))) - 1

func _get_weapon_panel_max_page() -> int:
	var total_pages: int = weapon_pages.size() + lingwu_pages.size()
	if total_pages <= 0:
		return 0
	return total_pages - 1

func _render_attr_page(_animated: bool = false) -> void:
	if attr_container == null or attr_panel_example == null:
		return
	_hide_attr_tooltip()
	attr_hovered_panel = null
	attr_panels.clear()
	for child in attr_container.get_children():
		if child == attr_panel_example:
			continue
		child.queue_free()
	var start_index: int = attr_page * ATTRS_PER_PAGE
	for i in range(ATTRS_PER_PAGE):
		var entry_index: int = start_index + i
		if entry_index >= attr_entries.size():
			break
		_add_attr_entry(attr_entries[entry_index], i)
	var max_page: int = _get_attr_max_page()
	if attr_left_button:
		attr_left_button.visible = attr_page > 0
	if attr_right_button:
		attr_right_button.visible = attr_page < max_page

func _render_weapon_panel_page(_animated: bool = false) -> void:
	if weapon_container == null or weapon_panel_example == null or lingwu_container == null or lingwu_panel_example == null:
		return
	_hide_attr_tooltip()
	lingwu_hovered_panel = null
	lingwu_panels.clear()
	weapon_discard_button = null
	weapon_discard_page_data = {}
	_cancel_weapon_discard_hold()
	for child in weapon_container.get_children():
		if child == weapon_panel_example:
			continue
		child.queue_free()
	for child in lingwu_container.get_children():
		if child == lingwu_panel_example:
			continue
		child.queue_free()
	var lingwu_page_count: int = lingwu_pages.size()
	if weapon_panel_page < lingwu_page_count:
		weapon_container.visible = false
		lingwu_container.visible = true
		_add_lingwu_page(lingwu_pages[weapon_panel_page])
	else:
		weapon_container.visible = true
		lingwu_container.visible = false
		var weapon_page_index: int = weapon_panel_page - lingwu_page_count
		if weapon_page_index >= 0 and weapon_page_index < weapon_pages.size():
			_add_weapon_page(weapon_pages[weapon_page_index])
	_update_weapon_nav_buttons()

func _fade_attr_page_change() -> void:
	if attr_container == null:
		_render_attr_page(false)
		return
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(attr_container, "modulate:a", 0.0, PAGE_FADE_DURATION)
	await tween.finished
	_render_attr_page(false)
	tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(attr_container, "modulate:a", 1.0, PAGE_FADE_DURATION)

func _fade_weapon_page_change() -> void:
	var active_container: CanvasItem = _get_active_weapon_content_container()
	if active_container == null:
		_render_weapon_panel_page(false)
		return
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(active_container, "modulate:a", 0.0, PAGE_FADE_DURATION)
	await tween.finished
	_render_weapon_panel_page(false)
	var next_container: CanvasItem = _get_active_weapon_content_container()
	if next_container == null:
		return
	next_container.modulate.a = 0.0
	tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(next_container, "modulate:a", 1.0, PAGE_FADE_DURATION)

func _get_active_weapon_content_container() -> CanvasItem:
	if lingwu_container != null and lingwu_container.visible:
		return lingwu_container
	if weapon_container != null and weapon_container.visible:
		return weapon_container
	return null

func _update_weapon_nav_buttons() -> void:
	var max_page: int = _get_weapon_panel_max_page()
	var has_page: bool = weapon_pages.size() + lingwu_pages.size() > 0
	if weapon_left_button:
		weapon_left_button.visible = has_page and weapon_panel_page > 0
	if weapon_right_button:
		weapon_right_button.visible = has_page and weapon_panel_page < max_page

func _add_weapon_page(page_data: Dictionary) -> void:
	var panel: Panel = weapon_panel_example.duplicate() as Panel
	if panel == null:
		return
	panel.visible = true
	weapon_container.add_child(panel)
	var name_label: RichTextLabel = panel.get_node_or_null("Name") as RichTextLabel
	var value_label: RichTextLabel = panel.get_node_or_null("Value") as RichTextLabel
	var detail_label: RichTextLabel = panel.get_node_or_null("Detail") as RichTextLabel
	var sprite: Sprite2D = panel.get_node_or_null("Sprite2D") as Sprite2D
	if name_label:
		name_label.text = str(page_data.get("name", ""))
	if value_label:
		value_label.text = "Lv. %d\n伤害加成：%s" % [int(page_data.get("level", 0)), _format_percent_ratio(float(page_data.get("damage_bonus", 0.0)))]
	if detail_label:
		detail_label.text = str(page_data.get("detail", "暂无领悟项"))
		detail_label.scroll_active = true
	if sprite:
		var icon_path: String = str(page_data.get("icon_path", ""))
		sprite.texture = load(icon_path) if not icon_path.is_empty() and ResourceLoader.exists(icon_path) else null
	var discard_button := _get_weapon_discard_button(panel)
	if discard_button:
		_connect_weapon_discard_button(discard_button, page_data)

func _add_lingwu_page(page_items: Array) -> void:
	for i in range(page_items.size()):
		var item_data: Dictionary = page_items[i] as Dictionary
		var panel: Panel = lingwu_panel_example.duplicate() as Panel
		if panel == null:
			continue
		panel.visible = true
		panel.set_meta("lingwu_data", item_data)
		lingwu_container.add_child(panel)
		lingwu_panels.append(panel)
		var sprite: Sprite2D = panel.get_node_or_null("Sprite2D") as Sprite2D
		var count_label: RichTextLabel = panel.get_node_or_null("RichTextLabel") as RichTextLabel
		if sprite:
			var icon_path: String = str(item_data.get("icon_path", ""))
			sprite.texture = load(icon_path) if not icon_path.is_empty() and ResourceLoader.exists(icon_path) else null
			sprite.scale = sprite.scale * 0.9
		if count_label:
			var count: int = int(item_data.get("count", 1))
			count_label.text = str(count) if count > 1 else ""
		_apply_lingwu_border(panel, str(item_data.get("rarity", "")))

func _get_weapon_discard_button(panel: Panel) -> Button:
	var button := panel.get_node_or_null("discard") as Button
	if button:
		return button
	button = panel.get_node_or_null("Discard") as Button
	if button:
		return button
	return panel.get_node_or_null("Button") as Button

func _connect_weapon_discard_button(button: Button, page_data: Dictionary) -> void:
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = false
	button.set_meta("weapon_page_data", page_data)
	weapon_discard_button = button
	weapon_discard_page_data = page_data
	var button_down_callable := Callable(self, "_on_weapon_discard_button_down").bind(button)
	var button_up_callable := Callable(self, "_on_weapon_discard_button_up").bind(button)
	var gui_input_callable := Callable(self, "_on_weapon_discard_button_gui_input").bind(button)
	for conn in button.button_down.get_connections():
		if conn.callable.get_object() == self:
			button.button_down.disconnect(conn.callable)
	for conn in button.button_up.get_connections():
		if conn.callable.get_object() == self:
			button.button_up.disconnect(conn.callable)
	for conn in button.gui_input.get_connections():
		if conn.callable.get_object() == self:
			button.gui_input.disconnect(conn.callable)
	button.button_down.connect(button_down_callable)
	button.button_up.connect(button_up_callable)
	button.gui_input.connect(gui_input_callable)
	_get_or_create_weapon_discard_progress_bar(button).visible = false

func _on_weapon_discard_button_down(button: Button) -> void:
	_start_weapon_discard_hold(button)

func _on_weapon_discard_button_up(button: Button) -> void:
	if weapon_discard_button == button:
		_cancel_weapon_discard_hold()

func _on_weapon_discard_button_gui_input(event: InputEvent, button: Button) -> void:
	if event is InputEventMouseButton and not event.pressed and weapon_discard_button == button:
		_cancel_weapon_discard_hold()

func _get_or_create_weapon_discard_progress_bar(button: Button) -> ColorRect:
	var progress_bar := button.get_node_or_null("DiscardHoldProgress") as ColorRect
	if progress_bar != null:
		return progress_bar
	progress_bar = ColorRect.new()
	progress_bar.name = "DiscardHoldProgress"
	progress_bar.z_index = 40
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_bar.color = Color(0.95, 0.18, 0.12, 0.82)
	progress_bar.position = Vector2(0.0, max(button.size.y - 7.0, 0.0))
	progress_bar.size = Vector2(0.0, 7.0)
	button.add_child(progress_bar)
	return progress_bar

func _update_weapon_discard_progress_bar(ratio: float) -> void:
	if weapon_discard_button == null or not is_instance_valid(weapon_discard_button):
		return
	var progress_bar := _get_or_create_weapon_discard_progress_bar(weapon_discard_button)
	var clamped_ratio := clampf(ratio, 0.0, 1.0)
	progress_bar.visible = clamped_ratio > 0.0
	progress_bar.position = Vector2(0.0, max(weapon_discard_button.size.y - 7.0, 0.0))
	progress_bar.size = Vector2(max(weapon_discard_button.size.x, 1.0) * clamped_ratio, 7.0)

func _clear_weapon_discard_hold_progress() -> void:
	if weapon_discard_button == null or not is_instance_valid(weapon_discard_button):
		return
	var progress_bar := weapon_discard_button.get_node_or_null("DiscardHoldProgress") as ColorRect
	if progress_bar != null:
		progress_bar.visible = false
		progress_bar.size.x = 0.0

func _start_weapon_discard_hold(button: Button) -> void:
	if button == null or not is_instance_valid(button):
		return
	if not button.has_meta("weapon_page_data"):
		return
	var block_reason := _get_weapon_discard_block_reason()
	if not block_reason.is_empty():
		_show_weapon_discard_tip(block_reason)
		return
	_cancel_weapon_discard_hold()
	weapon_discard_button = button
	weapon_discard_page_data = button.get_meta("weapon_page_data") as Dictionary
	weapon_discard_hold_elapsed = 0.0
	weapon_discard_hold_active = true
	weapon_discard_hold_completed = false
	_update_weapon_discard_progress_bar(0.001)

func _cancel_weapon_discard_hold() -> void:
	if weapon_discard_hold_completed:
		return
	weapon_discard_hold_active = false
	weapon_discard_hold_elapsed = 0.0
	_clear_weapon_discard_hold_progress()

func _process_weapon_discard_hold(delta: float) -> void:
	if not weapon_discard_hold_active:
		return
	if weapon_discard_button == null or not is_instance_valid(weapon_discard_button):
		_cancel_weapon_discard_hold()
		return
	weapon_discard_hold_elapsed += delta
	var ratio := weapon_discard_hold_elapsed / WEAPON_DISCARD_HOLD_SECONDS
	_update_weapon_discard_progress_bar(ratio)
	if weapon_discard_hold_elapsed >= WEAPON_DISCARD_HOLD_SECONDS:
		_complete_weapon_discard_hold()

func _complete_weapon_discard_hold() -> void:
	weapon_discard_hold_completed = true
	weapon_discard_hold_active = false
	weapon_discard_hold_elapsed = 0.0
	_clear_weapon_discard_hold_progress()
	var block_reason := _get_weapon_discard_block_reason()
	if not block_reason.is_empty():
		_show_weapon_discard_tip(block_reason)
		weapon_discard_hold_completed = false
		return
	_discard_weapon_from_page_data(weapon_discard_page_data)
	weapon_discard_hold_completed = false

func _get_weapon_discard_block_reason() -> String:
	if _has_boss_event_triggered():
		return "Boss出现后无法销毁武器"
	if _get_owned_weapon_count() <= 1 or PC.current_weapon_num <= 1:
		return "最后一把武器无法销毁"
	return ""

func _has_boss_event_triggered() -> bool:
	var current_scene := get_tree().current_scene if get_tree() else null
	if current_scene == null:
		return false
	if "boss_event_triggered" in current_scene:
		return bool(current_scene.get("boss_event_triggered"))
	return get_tree().get_nodes_in_group("boss").size() > 0

func _get_owned_weapon_count() -> int:
	var count := 0
	for weapon_data in WEAPON_PANEL_ORDER:
		if not _get_owned_weapon_reward_id(weapon_data).is_empty():
			count += 1
	return count

func _show_weapon_discard_tip(message: String) -> void:
	var current_scene := get_tree().current_scene if get_tree() else null
	if current_scene != null:
		var canvas_layer := current_scene.get_node_or_null("CanvasLayer")
		if canvas_layer != null:
			if canvas_layer.has_method("_show_level_up_tip"):
				canvas_layer._show_level_up_tip(message)
				return
			var tip = canvas_layer.get("lv_up_tip")
			if tip != null and tip.has_method("start_animation"):
				tip.start_animation(message, 0.5)
				return
			var fallback_tip := canvas_layer.get_node_or_null("TipsLayer/Tip")
			if fallback_tip != null and fallback_tip.has_method("start_animation"):
				fallback_tip.start_animation(message, 0.5)
				return
		var scene_tip = current_scene.get("tip") if "tip" in current_scene else null
		if scene_tip != null and scene_tip.has_method("start_animation"):
			scene_tip.start_animation(message, 0.5)

func _discard_weapon_from_page_data(page_data: Dictionary) -> void:
	var faction := str(page_data.get("faction", ""))
	var level_prop := str(page_data.get("level_prop", ""))
	var reward_id := str(page_data.get("reward_id", ""))
	if faction.is_empty() or level_prop.is_empty():
		return
	var removed_any := _remove_selected_rewards_for_weapon(faction, reward_id)
	if not removed_any and not reward_id.is_empty():
		if PC.selected_rewards.has(reward_id):
			PC.selected_rewards.erase(reward_id)
			removed_any = true
	PC.set(level_prop, 0)
	var advance_prop := "%s_advance" % level_prop
	PC.set(advance_prop, 0)
	if reward_id == "Yujian":
		_reset_yujian_discard_state()
	if removed_any:
		PC.current_weapon_num = maxi(0, PC.current_weapon_num - 1)
	_refresh_weapon_panel()

func _reset_yujian_discard_state() -> void:
	if PC.yujian_applied_summon_damage_bonus != 0.0:
		PC.summon_damage_multiplier -= PC.yujian_applied_summon_damage_bonus
	PC.yujian_move_summon_damage_per_10 = 0.0
	PC.yujian_move_summon_damage_cap = 0.0
	PC.yujian_level_summon_damage_per_level = 0.0
	PC.yujian_applied_summon_damage_bonus = 0.0
	PC.yujian_interval_reduction_per_level = 0.0
	PC.yujian_applied_interval_multiplier = 1.0
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if player.has_method("sync_yujian_state"):
			player.sync_yujian_state()
		if player.has_method("update_summons_properties"):
			player.update_summons_properties()

func _remove_selected_rewards_for_weapon(faction: String, base_reward_id: String) -> bool:
	var removed_any := false
	var normalized_faction := faction.to_lower()
	for i in range(PC.selected_rewards.size() - 1, -1, -1):
		var selected_id := str(PC.selected_rewards[i])
		var reward = _get_reward_data(selected_id)
		if reward == null:
			if selected_id == base_reward_id:
				PC.selected_rewards.remove_at(i)
				removed_any = true
			continue
		if str(reward.faction).to_lower() == normalized_faction:
			PC.selected_rewards.remove_at(i)
			removed_any = true
	return removed_any

func _apply_lingwu_border(panel: Panel, rarity: String) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.02, 0.60)
	var border_color: Color = _get_lingwu_rarity_color(rarity)
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	panel.add_theme_stylebox_override("panel", style)

func _add_attr_entry(entry_data: Dictionary, row_index: int) -> void:
	var panel: Panel = attr_panel_example.duplicate() as Panel
	if panel == null:
		return
	panel.visible = true
	panel.set_meta("attr_data", entry_data)
	panel.set_meta("attr_row_index", row_index)
	attr_container.add_child(panel)
	attr_panels.append(panel)
	var name_label: RichTextLabel = _get_attr_name_label(panel)
	var value_label: RichTextLabel = _get_attr_value_label(panel)
	if name_label:
		name_label.text = str(entry_data.get("name", ""))
	if value_label:
		value_label.text = str(entry_data.get("value", ""))

func _get_attr_name_label(panel: Panel) -> RichTextLabel:
	var label: RichTextLabel = panel.get_node_or_null("Name") as RichTextLabel
	if label:
		return label
	label = panel.get_node_or_null("RichTextLabel") as RichTextLabel
	return label

func _get_attr_value_label(panel: Panel) -> RichTextLabel:
	var label: RichTextLabel = panel.get_node_or_null("Value") as RichTextLabel
	if label:
		return label
	label = panel.get_node_or_null("RichTextLabel2") as RichTextLabel
	return label

func _update_attr_hover_by_mouse() -> void:
	if not visible or attr_container == null or not attr_container.visible:
		if attr_hovered_panel != null:
			attr_hovered_panel = null
			_hide_attr_tooltip()
		return
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var hovered_panel: Panel = null
	for panel in attr_panels:
		if panel == null or not is_instance_valid(panel) or not panel.visible:
			continue
		if _get_attr_panel_global_rect(panel).has_point(mouse_pos):
			hovered_panel = panel
			break
	if hovered_panel == attr_hovered_panel:
		return
	attr_hovered_panel = hovered_panel
	if attr_hovered_panel == null or not attr_hovered_panel.has_meta("attr_data"):
		_hide_attr_tooltip()
		return
	_show_attr_tooltip(attr_hovered_panel, attr_hovered_panel.get_meta("attr_data") as Dictionary)

func _update_lingwu_hover_by_mouse() -> void:
	if not visible or lingwu_container == null or not lingwu_container.visible:
		if lingwu_hovered_panel != null:
			lingwu_hovered_panel = null
			_hide_attr_tooltip()
		return
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var hovered_panel: Panel = null
	for panel in lingwu_panels:
		if panel == null or not is_instance_valid(panel) or not panel.visible:
			continue
		if panel.get_global_rect().has_point(mouse_pos):
			hovered_panel = panel
			break
	if hovered_panel == lingwu_hovered_panel:
		return
	lingwu_hovered_panel = hovered_panel
	if lingwu_hovered_panel == null or not lingwu_hovered_panel.has_meta("lingwu_data"):
		_hide_attr_tooltip()
		return
	var item_data: Dictionary = lingwu_hovered_panel.get_meta("lingwu_data") as Dictionary
	_show_lingwu_tooltip(lingwu_hovered_panel, item_data)

func _get_attr_panel_global_rect(panel: Panel) -> Rect2:
	var row_index: int = int(panel.get_meta("attr_row_index", 0))
	var row_width: float = attr_panel_example.custom_minimum_size.x
	if row_width <= 0.0:
		row_width = 228.0
	var row_height: float = attr_panel_example.custom_minimum_size.y
	if row_height <= 0.0:
		row_height = 36.0
	var row_pitch: float = row_height + float(attr_container.get_theme_constant("separation"))
	var row_pos: Vector2 = attr_container.global_position + Vector2(0.0, float(row_index) * row_pitch)
	return Rect2(row_pos, Vector2(row_width, row_pitch))

func _show_attr_tooltip(panel: Panel, entry_data: Dictionary) -> void:
	if attr_tooltip_panel == null:
		return
	attr_tooltip_hover_id += 1
	var hover_id: int = attr_tooltip_hover_id
	_set_tooltip_value_section_visible(true)
	_set_tooltip_title_color(Color.WHITE)
	attr_tooltip_title.text = str(entry_data.get("name", ""))
	attr_tooltip_value.text = "当前数值：" + str(entry_data.get("value", ""))
	attr_tooltip_desc.text = str(entry_data.get("desc", ""))
	attr_tooltip_panel.size = Vector2.ZERO
	attr_tooltip_panel.custom_minimum_size = Vector2.ZERO
	attr_tooltip_panel.global_position = Vector2(-10000, -10000)
	attr_tooltip_panel.visible = true
	attr_tooltip_panel.modulate.a = 0.0
	_finalize_attr_tooltip_layout(panel, hover_id)

func _finalize_attr_tooltip_layout(panel: Panel, hover_id: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if hover_id != attr_tooltip_hover_id:
		return
	if attr_tooltip_panel == null or not attr_tooltip_panel.visible:
		return
	var vbox: VBoxContainer = attr_tooltip_panel.get_node("VBox") as VBoxContainer
	var content_size: Vector2 = vbox.get_combined_minimum_size()
	var panel_size: Vector2 = content_size + Vector2(20, 16)
	attr_tooltip_panel.custom_minimum_size = panel_size
	attr_tooltip_panel.size = panel_size
	_position_attr_tooltip(panel)
	if attr_tooltip_tween and attr_tooltip_tween.is_valid():
		attr_tooltip_tween.kill()
	attr_tooltip_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	attr_tooltip_tween.tween_property(attr_tooltip_panel, "modulate:a", 1.0, 0.15)

func _position_attr_tooltip(panel: Panel) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var panel_rect: Rect2 = _get_attr_panel_global_rect(panel)
	var target_pos: Vector2 = panel_rect.position + Vector2(panel_rect.size.x + 10.0, 0.0)
	if target_pos.x + attr_tooltip_panel.size.x > viewport_size.x:
		target_pos.x = panel_rect.position.x - attr_tooltip_panel.size.x - 10.0
	if target_pos.y + attr_tooltip_panel.size.y > viewport_size.y:
		target_pos.y = viewport_size.y - attr_tooltip_panel.size.y - 10.0
	target_pos.x = maxf(target_pos.x, 0.0)
	target_pos.y = maxf(target_pos.y, 0.0)
	attr_tooltip_panel.global_position = target_pos

func _show_lingwu_tooltip(panel: Panel, item_data: Dictionary) -> void:
	if attr_tooltip_panel == null:
		return
	attr_tooltip_hover_id += 1
	var hover_id: int = attr_tooltip_hover_id
	_set_tooltip_value_section_visible(false)
	_set_tooltip_title_color(_get_lingwu_rarity_color(str(item_data.get("rarity", ""))))
	attr_tooltip_title.text = str(item_data.get("name", ""))
	attr_tooltip_value.text = ""
	attr_tooltip_desc.text = str(item_data.get("detail", ""))
	attr_tooltip_panel.size = Vector2.ZERO
	attr_tooltip_panel.custom_minimum_size = Vector2.ZERO
	attr_tooltip_panel.global_position = Vector2(-10000, -10000)
	attr_tooltip_panel.visible = true
	attr_tooltip_panel.modulate.a = 0.0
	_finalize_lingwu_tooltip_layout(panel, hover_id)

func _finalize_lingwu_tooltip_layout(panel: Panel, hover_id: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if hover_id != attr_tooltip_hover_id:
		return
	if attr_tooltip_panel == null or not attr_tooltip_panel.visible:
		return
	var vbox: VBoxContainer = attr_tooltip_panel.get_node("VBox") as VBoxContainer
	var content_size: Vector2 = vbox.get_combined_minimum_size()
	var panel_size: Vector2 = content_size + Vector2(20, 16)
	attr_tooltip_panel.custom_minimum_size = panel_size
	attr_tooltip_panel.size = panel_size
	_position_lingwu_tooltip(panel)
	if attr_tooltip_tween and attr_tooltip_tween.is_valid():
		attr_tooltip_tween.kill()
	attr_tooltip_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	attr_tooltip_tween.tween_property(attr_tooltip_panel, "modulate:a", 1.0, 0.15)

func _position_lingwu_tooltip(panel: Panel) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var panel_rect: Rect2 = panel.get_global_rect()
	var target_pos: Vector2 = panel_rect.position + Vector2(panel_rect.size.x + 10.0, 0.0)
	if target_pos.x + attr_tooltip_panel.size.x > viewport_size.x:
		target_pos.x = panel_rect.position.x - attr_tooltip_panel.size.x - 10.0
	if target_pos.y + attr_tooltip_panel.size.y > viewport_size.y:
		target_pos.y = viewport_size.y - attr_tooltip_panel.size.y - 10.0
	target_pos.x = maxf(target_pos.x, 0.0)
	target_pos.y = maxf(target_pos.y, 0.0)
	attr_tooltip_panel.global_position = target_pos

func _set_tooltip_value_section_visible(is_visible: bool) -> void:
	if attr_tooltip_value:
		attr_tooltip_value.visible = is_visible
	if attr_tooltip_panel == null:
		return
	var vbox: VBoxContainer = attr_tooltip_panel.get_node_or_null("VBox") as VBoxContainer
	if vbox == null:
		return
	var children: Array[Node] = vbox.get_children()
	if children.size() > 3 and children[3] is HSeparator:
		(children[3] as HSeparator).visible = is_visible

func _set_tooltip_title_color(color: Color) -> void:
	if attr_tooltip_title:
		attr_tooltip_title.add_theme_color_override("font_color", color)

func _hide_attr_tooltip() -> void:
	if attr_tooltip_panel == null:
		return
	attr_tooltip_hover_id += 1
	if attr_tooltip_tween and attr_tooltip_tween.is_valid():
		attr_tooltip_tween.kill()
	if not attr_tooltip_panel.visible:
		return
	attr_tooltip_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	attr_tooltip_tween.tween_property(attr_tooltip_panel, "modulate:a", 0.0, 0.12)
	attr_tooltip_tween.tween_callback(func(): attr_tooltip_panel.visible = false)

func _build_attr_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	entries.append(_make_attr("等级", str(PC.pc_lv), "当前局内等级。经验达到需求后升级，并获得基础属性成长与领悟选择机会。"))
	entries.append(_make_attr("经验", "%d/%d" % [PC.pc_exp, _get_current_required_exp()], "当前经验与升到下一级所需经验。"))
	entries.append(_make_attr("攻击", str(PC.pc_atk), "基础伤害。当前攻击基准：" + str(PC.base_atk) + "。攻击加成会以攻击基准结算；攻击基准会随局外成长和升级提升，升级会提升5点攻击后再提升10%的攻击。"))
	entries.append(_make_attr("体力", "%d/%d" % [PC.pc_hp, PC.pc_max_hp], "当前体力与最大体力。体力降至0时本次探索失败，升级时会先提升20点最大体力，再提升2%的最大体力。"))
	entries.append(_make_attr("当前护盾", str(PC.get_total_shield()), "当前身上所有未过期护盾的总值。护盾会优先吸收伤害。"))
	entries.append(_make_attr("护甲", "%d" % int(PC.pc_armor), "受击时提供额外减伤。当前护甲减伤为 %s。" % _format_percent_ratio(_get_armor_reduction())))
	entries.append(_make_attr("生命恢复", _format_percent_value(PC.pc_hp_regen), "默认每5秒生效一次，按最大体力的百分比恢复体力。"))
	entries.append(_make_attr("攻击速度", _format_signed_percent(PC.get_total_attack_speed_bonus()), "提高多数武器与部分攻击循环的频率，超过80%后收益会递减。"))
	entries.append(_make_attr("移动速度", _format_signed_percent(PC.get_total_move_speed_bonus()), "影响玩家战斗中的移动速度，超过80%后收益会递减。"))
	entries.append(_make_attr("暴击率", _format_percent_ratio(PC.crit_chance), "攻击发生暴击的概率,暴击后伤害会乘以暴击伤害倍率。"))
	entries.append(_make_attr("暴击伤害", _format_percent_ratio(PC.crit_damage_multi), "暴击发生后的伤害倍率。"))
	entries.append(_make_attr("最终伤害", _format_signed_percent(_get_current_final_damage_bonus()), "当前实际最终伤害乘区，包含全局最终伤害与已生效的纹章最终伤害。"))
	entries.append(_make_attr("减伤率", _format_percent_ratio(PC.get_total_damage_reduction_rate()), "受到伤害后会先按此比例降低伤害。"))
	entries.append(_make_attr("天命", str(PC.now_lunky_level), "影响领悟与灵气漩涡中高阶选项概率。每点天命提升逆天（红色）0.02%概率、臻境（金色）0.25%概率、悟道（紫色）0.6%概率。"))
	entries.append(_make_attr("通明概率", _format_percent_value(PC.now_blue_p), "领悟抽选中蓝色品质的概率。"))
	entries.append(_make_attr("悟道概率", _format_percent_value(PC.now_darkorchid_p), "领悟抽选中紫色品质的概率。"))
	entries.append(_make_attr("臻境概率", _format_percent_value(PC.now_gold_p), "领悟抽选中金色品质的概率。"))
	entries.append(_make_attr("逆天概率", _format_percent_value(PC.now_red_p), "领悟抽选中红色品质的概率。"))
	entries.append(_make_attr("真气获取率", _format_signed_percent(PC.point_multi), "击杀敌人获得真气的倍率加成。"))
	entries.append(_make_attr("精魄获取率", _format_signed_percent(PC.spirit_multi), "击杀敌人获得精魄的倍率加成。"))
	entries.append(_make_attr("经验获取率", _format_signed_percent(Global.get_effective_exp_multiplier() - 1.0), "击杀敌人获得经验的实际倍率加成。超过100%的部分收益递减。"))
	entries.append(_make_attr("掉落率", _format_signed_percent(PC.drop_multi), "影响击杀敌人时掉落物品的概率，不包含治愈灵气的掉落概率。"))
	entries.append(_make_attr("治愈灵气掉落率", _format_signed_percent(Global.get_heal_aura_drop_bonus()), "治愈灵气出现概率加成。单独作用于治愈灵气掉落，不计入普通掉落率。"))
	entries.append(_make_attr("治愈灵气回复率", _format_signed_percent(_get_heal_aura_recovery_bonus()), "治愈灵气回复量加成。"))
	entries.append(_make_attr("体型大小", _format_percent_ratio(PC.body_size), "影响角色显示体型与受击判定。"))
	entries.append(_make_attr("攻击范围", _format_signed_percent(Global.get_attack_range_multiplier() - 1.0), "影响大部分武器、主动技能的范围。"))
	entries.append(_make_attr("击退幅度", _format_signed_percent(PC.get_knockback_multiplier() - 1.0), "影响玩家造成的击退距离。仙枝、气功波、爪爪巨锤、破坏圣锤等击退效果会受到该属性影响；风龙杖吸附不受影响。"))
	entries.append(_make_attr("治疗加成", _format_signed_percent(PC.heal_multi), "治疗量提升。"))
	entries.append(_make_attr("护盾加成", _format_signed_percent(PC.sheild_multi), "护盾获取量提升。"))
	entries.append(_make_attr("对小怪增伤", _format_signed_percent(PC.normal_monster_multi + Global.study_normal_monster_damage_bonus), "攻击普通敌人增伤。"))
	entries.append(_make_attr("对精英首领增伤", _format_signed_percent(PC.boss_multi + Global.study_elite_damage_bonus), "攻击精英与首领增伤。"))
	entries.append(_make_attr("技能冷却缩减", _format_signed_percent(Global.get_total_skill_cooldown_reduction()), "主动技能冷却降低。总冷却缩减上限为50%。"))
	entries.append(_make_attr("技能伤害", _format_signed_percent(PC.active_skill_multi), "主动技能伤害加成。"))
	entries.append(_make_attr("咏唱冷却加速", _format_signed_percent(PC.chant_cooldown_acceleration), "拥有咏唱时间的主动技能，冷却倒计时速度会加速。"))
	entries.append(_make_attr("咏唱时间缩减", _format_signed_percent(PC.chant_time_reduction), "咏唱技能读条时间会乘以 1 - 咏唱时间缩减。"))
	entries.append(_make_attr("精魄", "%d" % PC.spirit, "当前可消费精魄。实际精魄值保留小数，显示与消费使用向下取整后的整数。"))
	entries.append(_make_attr("精魄再生", _format_signed_percent(LvUp.spirit_regen_rate), "每10秒基于当前精魄获得额外精魄。总再生上限为6%，单次最多获得5000精魄。首领出现后不再生效。"))
	entries.append(_make_attr("刷新次数", str(PC.refresh_num), "领悟界面中可用于刷新所有未锁定选项的次数。初始 2 次，每升 2 级获取 1 次。"))
	entries.append(_make_attr("锁定次数", str(PC.lock_num), "领悟界面中可用于锁定某个选项栏位的次数。初始 1 次，每升 10 级获取 1 次。"))
	entries.append(_make_attr("禁用次数", str(PC.ban_num), "领悟界面中可用于禁用某一系列领悟的次数。初始 3 次，不随等级增长。长按禁用按钮 1 秒后生效，并刷新该栏位。"))
	entries.append(_make_attr("最大武器数量", str(Global.max_weapon_num), "本局最多可同时持有的武器数量。"))
	entries.append(_make_attr("纹章数量", "%d/%d" % [PC.current_emblems.size(), PC.emblem_slots_max], "当前持有的不同纹章数量。多个同名纹章会叠层，但只占一个栏位。"))
	entries.append(_make_attr("纹章效果提升", _format_signed_percent(Global.get_emblem_effect_multiplier() - 1.0), "提高纹章效果数值。实际纹章效果会乘以 1 + 纹章效果提升。"))
	entries.append(_make_attr("唤物上限", str(PC.summon_count_max), "当前最多能同时拥有的召唤物数量。"))
	entries.append(_make_attr("唤物伤害", _format_percent_ratio(_get_summon_damage_multiplier()), "召唤物造成伤害和部分召唤治疗会使用的总加成，包含唤灵系伤害、御灵法则、局内领悟与成就加成。"))
	entries.append(_make_attr("唤物攻速", _format_percent_ratio(_get_summon_attack_speed_multiplier()), "召唤物攻击速度倍率。内部会通过攻击间隔结算，间隔越低，攻速越高。"))
	entries.append(_make_attr("唤物弹体大小", _format_percent_ratio(PC.summon_bullet_size_multiplier), "召唤物子弹大小倍率，实际子弹大小还会受到攻击范围影响。"))
	entries.append(_make_attr("唤物射程", _format_percent_ratio(PC.summon_range_multiplier), "召唤物弹体可以飞行的最大距离倍率。"))
	entries.append(_make_attr("唤物穿透", str(PC.summon_penetration_count), "召唤物弹体可穿透敌人的数量。每穿过一个敌人，后续伤害降低50%。"))
	_add_weapon_category_attrs(entries)
	return entries

func _get_current_final_damage_bonus() -> float:
	var global_buff_bonus := BulletCalculator.get_global_buff_damage_multiplier() - 1.0
	return maxf(0.0, 1.0 + Faze.get_final_damage_additive_bonus() + global_buff_bonus) * Global.get_stage_boss_player_damage_multiplier() * PC.damage_deal_multiplier - 1.0

func _build_weapon_pages() -> Array[Dictionary]:
	var pages: Array[Dictionary] = []
	for weapon_data in WEAPON_PANEL_ORDER:
		var owned_id: String = _get_owned_weapon_reward_id(weapon_data)
		if owned_id.is_empty():
			continue
		var reward = _get_reward_data(owned_id)
		if reward == null:
			continue
		var faction: String = str(weapon_data.get("faction", ""))
		pages.append({
			"faction": faction,
			"reward_id": owned_id,
			"level_prop": str(weapon_data.get("level", "")),
			"name": reward.reward_name,
			"icon_path": LvUp.get_icon_path(reward.icon),
			"level": int(PC.get(str(weapon_data.get("level", "")))),
			"damage_bonus": _get_weapon_damage_bonus(faction),
			"detail": _build_weapon_advance_detail(faction)
		})
	return pages

func _build_lingwu_pages() -> Array[Array]:
	var ordered_items: Array = []
	var by_id: Dictionary = {}
	for raw_id in PC.selected_rewards:
		var reward_id: String = str(raw_id)
		var reward = _get_reward_data(reward_id)
		if reward == null or _is_reward_excluded_from_lingwu_panel(reward):
			continue
		if by_id.has(reward_id):
			by_id[reward_id]["count"] = int(by_id[reward_id].get("count", 1)) + 1
			continue
		var item: Dictionary = {
			"id": reward_id,
			"name": reward.reward_name,
			"detail": reward.detail,
			"rarity": reward.rarity,
			"icon_path": LvUp.get_icon_path(reward.icon),
			"count": 1
		}
		by_id[reward_id] = item
		ordered_items.append(item)
	var pages: Array[Array] = []
	var current_page: Array = []
	var per_page: int = _get_lingwu_items_per_page()
	for item in ordered_items:
		if current_page.size() >= per_page:
			pages.append(current_page)
			current_page = []
		current_page.append(item)
	if not current_page.is_empty() or pages.is_empty():
		pages.append(current_page)
	return pages

func _get_lingwu_items_per_page() -> int:
	if lingwu_container == null or lingwu_panel_example == null:
		return LINGWU_FALLBACK_PER_PAGE
	var container_size: Vector2 = lingwu_container.size
	if container_size.x <= 0.0 or container_size.y <= 0.0:
		container_size = lingwu_container.custom_minimum_size
	var item_size: Vector2 = lingwu_panel_example.custom_minimum_size
	if item_size.x <= 0.0 or item_size.y <= 0.0:
		item_size = lingwu_panel_example.size
	if container_size.x <= 0.0 or container_size.y <= 0.0 or item_size.x <= 0.0 or item_size.y <= 0.0:
		return LINGWU_FALLBACK_PER_PAGE
	var h_sep: int = lingwu_container.get_theme_constant("h_separation")
	var v_sep: int = lingwu_container.get_theme_constant("v_separation")
	var columns: int = maxi(1, int(floor((container_size.x + float(h_sep)) / (item_size.x + float(h_sep)))))
	var rows: int = maxi(1, int(floor((container_size.y + float(v_sep)) / (item_size.y + float(v_sep)))))
	return maxi(1, columns * rows)

func _get_owned_weapon_reward_id(weapon_data: Dictionary) -> String:
	var reward_id: String = str(weapon_data.get("reward_id", "")).to_lower()
	for raw_selected_id in PC.selected_rewards:
		if str(raw_selected_id).to_lower() == reward_id:
			return str(raw_selected_id)
	return ""

func _get_reward_data(reward_id: String):
	if LvUp != null and LvUp.has_method("get_reward_by_id"):
		return LvUp.get_reward_by_id(reward_id)
	return null

func _is_reward_excluded_from_lingwu_panel(reward) -> bool:
	if reward.if_advance:
		return true
	if reward.if_main_skill:
		return true
	return _is_weapon_base_reward(reward)

func _is_weapon_base_reward(reward) -> bool:
	if reward.if_main_skill:
		return false
	var reward_id := str(reward.id).to_lower()
	for weapon_data in WEAPON_PANEL_ORDER:
		if reward_id == str(weapon_data.get("reward_id", "")).to_lower():
			return true
	return false

func _build_weapon_advance_detail(faction: String) -> String:
	var lines: Array[String] = []
	for raw_id in PC.selected_rewards:
		var reward = _get_reward_data(str(raw_id))
		if reward == null:
			continue
		if reward.if_advance and _is_reward_for_weapon(reward, faction):
			lines.append("%s\n%s" % [reward.reward_name, reward.detail])
	if lines.is_empty():
		return "暂无领悟项"
	return "\n\n".join(lines)

func _is_reward_for_weapon(reward, faction: String) -> bool:
	return str(reward.faction).to_lower() == faction.to_lower()

func _get_weapon_damage_bonus(faction: String) -> float:
	var weapon_tag: String = _get_weapon_damage_bonus_tag(faction)
	var bonus: float = SettingStudyTreeUp.get_total_damage_bonus(weapon_tag)
	bonus += _get_skill_own_damage_bonus(weapon_tag)
	return bonus

func _get_weapon_damage_bonus_tag(faction: String) -> String:
	match faction.to_lower():
		"bloodwave":
			return "blood_wave"
		"bloodboardsword":
			return "blood_broadsword"
		"ice":
			return "ice_flower"
		"thunderbreak":
			return "thunder_break"
		"lightbullet":
			return "light_bullet"
	return faction.to_lower()

func _get_skill_own_damage_bonus(weapon_tag: String) -> float:
	match weapon_tag:
		"qigong":
			return Qigong.main_skill_qigong_damage
		"dragonwind":
			return maxf(0.0, DragonWind.dragonwind_final_damage_multi - 1.0)
	return 0.0

func _get_weapon_damage_multiplier(faction: String) -> float:
	match faction:
		"swordqi":
			return PC.main_skill_swordQi_damage
		"branch":
			return PC.main_skill_branch_damage
		"moyan":
			return PC.main_skill_moyan_damage
		"ringfire":
			return PC.main_skill_ringFire_damage
		"riyan":
			return PC.main_skill_riyan_damage
		"thunder":
			return PC.main_skill_thunder_damage
		"bloodwave":
			return BloodWave.main_skill_bloodwave_damage
		"bloodboardsword":
			return PC.main_skill_bloodboardsword_damage
		"ice":
			return IceFlower.main_skill_ice_damage
		"thunderbreak":
			return PC.main_skill_thunder_break_damage * PC.thunder_break_final_damage_multi
		"lightbullet":
			return PC.main_skill_light_bullet_damage * PC.light_bullet_final_damage_multi
		"water":
			return PC.main_skill_water_damage * PC.water_final_damage_multi
		"qiankun":
			return Qiankun.main_skill_qiankun_damage * Qiankun.qiankun_final_damage_multi
		"xuanwu":
			return Xuanwu.main_skill_xuanwu_damage * Xuanwu.xuanwu_final_damage_multi
		"xunfeng":
			return Xunfeng.main_skill_xunfeng_damage * Xunfeng.xunfeng_final_damage_multi
		"genshan":
			return Genshan.main_skill_genshan_damage * Genshan.genshan_final_damage_multi
		"duize":
			return Duize.main_skill_duize_damage * Duize.duize_final_damage_multi
		"holylight":
			return HolyLight.main_skill_holylight_damage
		"dragonwind":
			return PC.main_skill_dragonwind_damage
		"qigong":
			return Qigong.QIGONG_BASE_DAMAGE_MULTIPLIER + Qigong.main_skill_qigong_damage
		"zhuazhuajuchui":
			return ZHUAZHUAJUCHUI_SCRIPT.main_skill_zhuazhuajuchui_damage
		"yujian":
			return PC.summon_damage_multiplier
	return 0.0

func _get_lingwu_rarity_color(rarity: String) -> Color:
	var normalized: String = rarity.to_lower()
	match normalized:
		"skyblue":
			return Color(0.35, 0.78, 1.0, 1.0)
		"darkorchid":
			return Color(0.72, 0.32, 1.0, 1.0)
		"gold":
			return Color(1.0, 0.76, 0.18, 1.0)
		"red":
			return Color(1.0, 0.16, 0.12, 1.0)
	return Color(0.75, 0.75, 0.75, 1.0)

func _add_weapon_category_attrs(entries: Array[Dictionary]) -> void:
	var categories: Array[Dictionary] = [
		{"name": "初始武器伤害", "category": "main", "global": Global.study_main_weapon_damage_bonus},
		{"name": "刀剑系伤害", "category": "sword", "global": Global.study_sword_damage_bonus},
		{"name": "弹道系伤害", "category": "projectile", "global": Global.study_projectile_damage_bonus},
		{"name": "啸风系伤害", "category": "wind", "global": Global.study_wind_damage_bonus},
		{"name": "广域系伤害", "category": "wide", "global": Global.study_wide_damage_bonus},
		{"name": "生灵系伤害", "category": "life", "global": Global.study_life_damage_bonus},
		{"name": "破坏系伤害", "category": "destroy", "global": Global.study_destroy_damage_bonus},
		{"name": "炽炎系伤害", "category": "fire", "global": Global.study_fire_damage_bonus},
		{"name": "护佑系伤害", "category": "protect", "global": Global.study_protect_damage_bonus},
		{"name": "鸣雷系伤害", "category": "thunder", "global": Global.study_thunder_damage_bonus},
		{"name": "八卦系伤害", "category": "bagua", "global": Global.study_bagua_damage_bonus},
		{"name": "愈疗系伤害", "category": "heal", "global": Global.study_heal_damage_bonus},
		{"name": "宝器系伤害", "category": "treasure", "global": Global.study_treasure_damage_bonus},
		{"name": "沉渊系伤害", "category": "deep", "global": 0.0}
	]
	for category_data in categories:
		var category_id: String = str(category_data.get("category", ""))
		var law_bonus: float = _get_law_category_damage_bonus(category_id)
		var global_bonus: float = float(category_data.get("global", 0.0))
		var total_bonus: float = global_bonus + law_bonus
		var desc: String = "该武器系别的总伤害加成。"
		#desc += "\n修习/局外：" + _format_signed_percent(global_bonus)
		#desc += "\n法则：" + _format_signed_percent(law_bonus)
		#if category_id != "summon" and category_id != "active_skill":
			#desc += "\n成就提供的单武器加成会在具体武器结算时额外加入。"
		entries.append(_make_attr(str(category_data.get("name", "")), _format_signed_percent(total_bonus), desc))

func _get_law_category_damage_bonus(category: String) -> float:
	match category:
		"bagua":
			return Faze.get_bagua_weapon_damage_bonus()
		"wide":
			return PC.faze_wide_damage_bonus
		"fire":
			return Faze.get_fire_weapon_damage_multiplier(PC.faze_fire_level) - 1.0
		"life":
			return Faze.get_life_damage_multiplier(PC.faze_life_level) - 1.0
		"destroy":
			return Faze.get_destroy_damage_multiplier(PC.faze_destroy_level) - 1.0
		"wind":
			return Faze.get_wind_weapon_damage_multiplier(PC.faze_wind_level) - 1.0
		"thunder":
			return Faze.get_thunder_weapon_damage_multiplier(PC.faze_thunder_level) - 1.0
		"treasure":
			return Faze.get_treasure_weapon_damage_multiplier(PC.faze_treasure_level, PC.get_lucky_level()) - 1.0
		"deep":
			return Faze.get_deep_weapon_damage_bonus(PC.faze_deep_level)
	return 0.0

func _make_attr(attr_name: String, attr_value: String, attr_desc: String) -> Dictionary:
	return {
		"name": " " + attr_name,
		"value": attr_value + " ",
		"desc": attr_desc
	}

func _format_percent_ratio(value: float) -> String:
	return "%.1f%%" % (value * 100.0)

func _format_percent_value(value: float) -> String:
	return "%.1f%%" % value

func _format_signed_percent(value: float) -> String:
	var percent: float = value * 100.0
	if percent >= 0.0:
		return "%.1f%%" % percent
	return "%.1f%%" % percent

func _get_armor_reduction() -> float:
	return PC.pc_armor / (PC.pc_armor + 500.0) if PC.pc_armor > 0.0 else 0.0

func _get_total_move_speed_bonus() -> float:
	return PC.get_total_move_speed_bonus()

func _get_summon_damage_multiplier() -> float:
	return maxf(0.0, PC.summon_damage_multiplier + Global.study_summon_damage_bonus + Global.get_achievement_summon_damage_bonus())

func _get_summon_attack_speed_multiplier() -> float:
	if PC.summon_interval_multiplier <= 0.0:
		return 0.0
	return 1.0 / PC.summon_interval_multiplier

func _get_heal_aura_recovery_bonus() -> float:
	return Global.study_heal_aura_recovery_bonus + maxf(0.0, Global.fruit_heal_multi - 1.0)

func _get_current_required_exp() -> int:
	var parent_layer: Node = get_parent()
	if parent_layer != null and parent_layer.has_method("get_required_lv_up_value"):
		return int(parent_layer.call("get_required_lv_up_value", PC.pc_lv))
	var level_up_manager: Node = get_node_or_null("../LevelUpManager")
	if level_up_manager != null and level_up_manager.has_method("get_required_lv_up_value"):
		return int(level_up_manager.call("get_required_lv_up_value", PC.pc_lv))
	return 0

func _refresh_dps_panel() -> void:
	if not dps_panel:
		return
	if _show_heal_shield_stats:
		_refresh_heal_shield_panel()
		return
	var snapshot: Dictionary = Global.get_dps_detail_snapshot()
	var total_dps: float = float(snapshot.get("total_dps", 0.0))
	if dps_title_label:
		dps_title_label.text = "输出统计 - 总计 " + _format_dps_number(total_dps) + " /s"
	if dps_change_button:
		dps_change_button.text = "治疗护盾"
	_clear_dps_entries()
	if dps_container == null or dps_panel_example == null:
		return
	var sources: Array = snapshot.get("sources", [])
	for source in sources:
		if typeof(source) != TYPE_DICTIONARY:
			continue
		_add_dps_entry(source)

func _refresh_heal_shield_panel() -> void:
	var snapshot: Dictionary = Global.get_heal_shield_detail_snapshot()
	var total_rate: float = float(snapshot.get("total_rate", 0.0))
	if dps_title_label:
		dps_title_label.text = "治疗护盾统计 - 总计 " + _format_dps_number(total_rate) + " /s"
	if dps_change_button:
		dps_change_button.text = "输出统计"
	_clear_dps_entries()
	if dps_container == null or dps_panel_example == null:
		return
	var sources: Array = snapshot.get("sources", [])
	for source in sources:
		if typeof(source) != TYPE_DICTIONARY:
			continue
		_add_heal_shield_entry(source)

func _clear_dps_entries() -> void:
	if dps_container == null:
		return
	for child in dps_container.get_children():
		if child == dps_panel_example:
			continue
		child.queue_free()

func _add_dps_entry(source: Dictionary) -> void:
	var entry: Panel = dps_panel_example.duplicate() as Panel
	if entry == null:
		return
	entry.visible = true
	dps_container.add_child(entry)
	var sprite: Sprite2D = entry.get_node_or_null("sprite") as Sprite2D
	var detail: RichTextLabel = _create_dps_detail_for_entry(entry)
	var icon_path: String = str(source.get("icon", ""))
	if sprite:
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			var icon_texture: Texture2D = load(icon_path) as Texture2D
			sprite.texture = icon_texture
			_fit_dps_icon(sprite, icon_texture, str(source.get("category", "")))
		else:
			sprite.texture = null
			sprite.scale = Vector2.ONE
	var dps_value: float = float(source.get("dps", 0.0))
	var percent: float = float(source.get("percent", 0.0))
	if detail:
		_prepare_dps_detail_label(detail)
		detail.text = "%s\nDPS %s\n%.1f%%" % [
			str(source.get("name", "未知来源")),
			_format_dps_number(dps_value),
			percent
		]

func _add_heal_shield_entry(source: Dictionary) -> void:
	var entry: Panel = dps_panel_example.duplicate() as Panel
	if entry == null:
		return
	entry.visible = true
	dps_container.add_child(entry)
	var sprite: Sprite2D = entry.get_node_or_null("sprite") as Sprite2D
	var detail: RichTextLabel = _create_dps_detail_for_entry(entry)
	var icon_path: String = str(source.get("icon", ""))
	if sprite:
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			var icon_texture: Texture2D = load(icon_path) as Texture2D
			sprite.texture = icon_texture
			_fit_dps_icon(sprite, icon_texture, str(source.get("category", "")))
		else:
			sprite.texture = null
			sprite.scale = Vector2.ONE
	var rate_value: float = float(source.get("rate", 0.0))
	var heal_value: float = float(source.get("heal_rate", 0.0))
	var shield_value: float = float(source.get("shield_rate", 0.0))
	var percent: float = float(source.get("percent", 0.0))
	if detail:
		_prepare_dps_detail_label(detail)
		detail.text = "%s\n总计 %s/s\n治疗 %s 护盾 %s\n%.1f%%" % [
			str(source.get("name", "未知来源")),
			_format_dps_number(rate_value),
			_format_dps_number(heal_value),
			_format_dps_number(shield_value),
			percent
		]

func _create_dps_detail_for_entry(entry: Panel) -> RichTextLabel:
	var detail: RichTextLabel = entry.get_node_or_null("dps_detail") as RichTextLabel
	if detail != null:
		return detail
	if dps_detail_example != null:
		detail = dps_detail_example.duplicate() as RichTextLabel
	else:
		detail = RichTextLabel.new()
	if detail == null:
		return null
	detail.name = "dps_detail"
	entry.add_child(detail)
	detail.set_anchors_preset(Control.PRESET_TOP_LEFT)
	detail.position = Vector2(104.0, 16.0)
	detail.size = Vector2(170.0, 104.0)
	return detail

func _prepare_dps_detail_label(detail: RichTextLabel) -> void:
	detail.visible = true
	detail.modulate = Color(1, 1, 1, 1)
	detail.self_modulate = Color(1, 1, 1, 1)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.bbcode_enabled = false
	detail.fit_content = false
	detail.scroll_active = false
	detail.autowrap_mode = TextServer.AUTOWRAP_OFF
	if detail.size.x < 160.0:
		detail.size.x = 170.0
	if detail.size.y < 90.0:
		detail.size.y = 100.0

func _fit_dps_icon(sprite: Sprite2D, icon_texture: Texture2D, category: String) -> void:
	sprite.scale = Vector2.ONE
	if category != Global.DPS_DETAIL_CATEGORY_FAZE:
		return
	if icon_texture == null:
		return
	var texture_size: Vector2 = icon_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var scale_value: float = min(DPS_ENTRY_WEAPON_ICON_SIZE.x / texture_size.x, DPS_ENTRY_WEAPON_ICON_SIZE.y / texture_size.y)
	sprite.scale = Vector2(scale_value, scale_value)

func _format_dps_number(value: float) -> String:
	return str(int(round(value)))

func _close_setting() -> void:
	if not setting_layer_ref:
		return
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(setting_layer_ref, "modulate:a", 0.0, FADE_DURATION)
	await tween.finished
	setting_layer_ref.visible = false
	if visible and main_panel.visible and not dps_panel.visible and not tips_panel.visible:
		_fade_in_side_panels()

func _on_exit_pressed() -> void:
	_fade_out_side_panels()
	main_panel.visible = false
	tips_panel.modulate = Color(1, 1, 1, 0)
	tips_panel.visible = true
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(tips_panel, "modulate:a", 1.0, FADE_DURATION)

func _on_ok_pressed() -> void:
	get_tree().paused = false
	Global.in_menu = false
	Global.reset_game_speed()
	AchievementManager.record_stage_finished()
	Global.save_game()
	SceneChange.change_scene("res://Scenes/main_town.tscn", true)

func _on_return_pressed() -> void:
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(tips_panel, "modulate:a", 0.0, FADE_DURATION)
	await tween.finished
	tips_panel.visible = false
	main_panel.visible = true
	_fade_in_side_panels()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			if tips_panel.visible:
				_on_return_pressed()
			elif dps_panel and dps_panel.visible:
				_on_dps_return_pressed()
			elif setting_layer_ref and setting_layer_ref.visible:
				_close_setting()
			else:
				close()
			get_viewport().set_input_as_handled()
		elif can_open_pause_menu():
			open()
			get_viewport().set_input_as_handled()

# ==================== 暂停/恢复动画与技能计时 ====================

func _pause_skill_nodes(pause: bool) -> void:
	var parent_layer = get_parent()
	if not parent_layer:
		return
	# 递归查找所有含 set_game_paused 的 TextureButton（技能图标可能在子容器中）
	var skill_nodes = parent_layer.find_children("", "TextureButton", true, false)
	for child in skill_nodes:
		if child.has_method("set_game_paused"):
			child.set_game_paused(pause)

func _pause_all_animations() -> void:
	var tree = get_tree()
	if not tree:
		return
	# 暂停玩家动画
	for player in tree.get_nodes_in_group("player"):
		var sprite = player.get_node_or_null("AnimatedSprite2D")
		if sprite and sprite is AnimatedSprite2D:
			sprite.pause()
	# 通过 PC.player_instance 兜底
	if PC.player_instance and is_instance_valid(PC.player_instance):
		var sprite = PC.player_instance.get_node_or_null("AnimatedSprite2D")
		if sprite and sprite is AnimatedSprite2D and not sprite.is_playing():
			pass # 已经暂停
		elif sprite and sprite is AnimatedSprite2D:
			sprite.pause()
	# 暂停敌人动画
	for enemy in tree.get_nodes_in_group("enemies"):
		var sprite = enemy.get_node_or_null("AnimatedSprite2D")
		if sprite and sprite is AnimatedSprite2D:
			sprite.pause()

func _resume_all_animations() -> void:
	var tree = get_tree()
	if not tree:
		return
	# 恢复玩家动画
	for player in tree.get_nodes_in_group("player"):
		var sprite = player.get_node_or_null("AnimatedSprite2D")
		if sprite and sprite is AnimatedSprite2D:
			sprite.play()
	# 通过 PC.player_instance 兜底
	if PC.player_instance and is_instance_valid(PC.player_instance):
		var sprite = PC.player_instance.get_node_or_null("AnimatedSprite2D")
		if sprite and sprite is AnimatedSprite2D:
			sprite.play()
	# 恢复敌人动画
	for enemy in tree.get_nodes_in_group("enemies"):
		var sprite = enemy.get_node_or_null("AnimatedSprite2D")
		if sprite and sprite is AnimatedSprite2D:
			sprite.play()
