extends CanvasLayer

signal achievement_pressed
signal guide_pressed

@onready var setting: Panel = $Panel
@onready var setting_button: Button = $Setting
@onready var bag_button: Button = $Bag
@onready var skill_button: Button = $Skill
@onready var jc_button: Button = $JC
@onready var guide_button: Button = get_node_or_null("Guide") as Button
@onready var main_volume: HSlider = $Panel/shengyin2/MainVolume
@onready var bgm_volume: HSlider = $Panel/shengyin2/BGMVolume
@onready var se_volume: HSlider = $Panel/shengyin2/SEVolume
@onready var bg_volume: HSlider = $Panel/shengyin2/BGVolume
@onready var particle: CheckButton = $Panel/youxi/Particle
@onready var damage_show: CheckButton = $Panel/youxi/DamageShow
@onready var moretip: CheckButton = $Panel/youxi/moretip

@onready var time_slow_button: CheckButton = $Panel/youxi/TimeSlow
@onready var super_test_button: CheckButton = $Panel/youxi/SuperTest

@onready var damage_type_item: OptionButton = $Panel/youxi/DamageTypeItem
@onready var exit_button: Button = $Panel/Exit2
@onready var dark_overlay: Control = get_node_or_null("../CanvasLayer/DarkOverlay")
@onready var bag_layer: CanvasLayer = get_node_or_null("../BagLayer")
@onready var skill_setting_layer: CanvasLayer = get_node_or_null("../SkillSettingLayer")

var setting_tween: Tween
var dark_overlay_tween: Tween
var bag_tween: Tween
var skill_tween: Tween
var achievement_layer_open: bool = false
var town_panel_open: bool = false
var setting_button_manually_locked: bool = false
var screen_resolution: OptionButton
var full_screen: CheckButton
var vignetting: CheckButton
var noborder: CheckButton

const CAMERA_ZOOM_LOCK_SETTING := "settings"
const CAMERA_ZOOM_LOCK_BAG := "bag"
const CAMERA_ZOOM_LOCK_SKILL := "skill"

func _ready() -> void:
	setting.visible = false
	_setup_picture_panel_for_device()
	_update_entry_button_labels_for_device()
	setup_settings_ui()
	setting_button.pressed.connect(_on_setting_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	bag_button.pressed.connect(_on_bag_pressed)
	skill_button.pressed.connect(_on_skill_pressed)
	jc_button.pressed.connect(_on_jc_pressed)
	if guide_button != null:
		guide_button.pressed.connect(_on_guide_pressed)
	if not Global.input_device_mode_changed.is_connected(_on_input_device_mode_changed):
		Global.input_device_mode_changed.connect(_on_input_device_mode_changed)
	refresh_entry_buttons_enabled()

func _on_jc_pressed() -> void:
	if _is_entry_ui_open():
		return
	achievement_pressed.emit()

func _on_guide_pressed() -> void:
	if _is_entry_ui_open():
		return
	guide_pressed.emit()

func lock_setting_button() -> void:
	setting_button_manually_locked = true
	refresh_entry_buttons_enabled()

func unlock_setting_button() -> void:
	setting_button_manually_locked = false
	refresh_entry_buttons_enabled()

func set_achievement_layer_open(open: bool) -> void:
	achievement_layer_open = open
	refresh_entry_buttons_enabled()

func set_town_panel_open(open: bool) -> void:
	town_panel_open = open
	refresh_entry_buttons_enabled()

func refresh_entry_buttons_enabled() -> void:
	_update_entry_button_labels_for_device()
	var entry_ui_open := _is_entry_ui_open()
	for button in [setting_button, bag_button, skill_button, jc_button, guide_button]:
		if button == null:
			continue
		button.visible = not entry_ui_open
		var enabled := not entry_ui_open
		if button == setting_button and setting_button_manually_locked:
			enabled = false
		button.disabled = not enabled
		button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE

func _is_entry_ui_open() -> bool:
	return (
		setting.visible
		or (bag_layer != null and bag_layer.visible)
		or (skill_setting_layer != null and skill_setting_layer.visible)
		or achievement_layer_open
		or town_panel_open
	)

func close_setting_panel() -> void:
	if not setting.visible:
		return
	_on_exit_pressed()

func is_entry_ui_open() -> bool:
	return _is_entry_ui_open()

func try_open_setting() -> bool:
	if _is_entry_ui_open():
		return false
	if PC:
		PC.movement_disabled = true
	Global.lock_camera_zoom(CAMERA_ZOOM_LOCK_SETTING)
	show_dark_overlay()
	show_setting_panel()
	return true

func try_open_bag() -> bool:
	if bag_layer == null or _is_entry_ui_open():
		return false
	if PC:
		PC.movement_disabled = true
	show_dark_overlay()
	show_bag_layer()
	return true

func try_open_skill_config() -> bool:
	if skill_setting_layer == null or _is_entry_ui_open():
		return false
	if PC:
		PC.movement_disabled = true
	show_dark_overlay()
	show_skill_layer()
	return true

func close_current_entry_ui() -> bool:
	if setting.visible:
		_on_exit_pressed()
		return true
	if bag_layer != null and bag_layer.visible:
		if bag_layer.has_method("_on_exit_pressed"):
			bag_layer.call("_on_exit_pressed")
		else:
			hide_dark_overlay()
			bag_layer.visible = false
			Global.unlock_camera_zoom(CAMERA_ZOOM_LOCK_BAG)
			refresh_entry_buttons_enabled()
			if PC:
				PC.movement_disabled = false
		return true
	if skill_setting_layer != null and skill_setting_layer.visible:
		hide_dark_overlay()
		hide_skill_layer()
		if PC:
			PC.movement_disabled = false
		return true
	return false

func setup_settings_ui() -> void:
	main_volume.min_value = 0.0
	main_volume.max_value = 1.0
	main_volume.step = 0.01
	main_volume.value = Global.audio_manager.get_master_volume()
	main_volume.value_changed.connect(_on_main_volume_changed)

	bgm_volume.min_value = 0.0
	bgm_volume.max_value = 1.0
	bgm_volume.step = 0.01
	bgm_volume.value = Global.audio_manager.get_bgm_volume()
	bgm_volume.value_changed.connect(_on_bgm_volume_changed)

	se_volume.min_value = 0.0
	se_volume.max_value = 1.0
	se_volume.step = 0.01
	se_volume.value = Global.audio_manager.get_sfx_volume()
	se_volume.value_changed.connect(_on_se_volume_changed)

	bg_volume.min_value = 0.0
	bg_volume.max_value = 1.0
	bg_volume.step = 0.01
	bg_volume.value = Global.audio_manager.get_bg_volume()
	bg_volume.value_changed.connect(_on_bg_volume_changed)

	screen_resolution.selected = Global.settings_manager.get_current_resolution_index()
	screen_resolution.item_selected.connect(_on_resolution_selected)

	full_screen.button_pressed = Global.settings_manager.is_fullscreen_enabled()
	full_screen.toggled.connect(_on_fullscreen_toggled)

	vignetting.button_pressed = Global.settings_manager.is_vignetting_enabled()
	vignetting.toggled.connect(_on_vignetting_toggled)

	noborder.button_pressed = Global.settings_manager.is_noborder_enabled()
	noborder.toggled.connect(_on_noborder_toggled)

	particle.set_pressed_no_signal(Global.settings_manager.is_particle_enabled())
	particle.toggled.connect(_on_particle_toggled)

	moretip.set_pressed_no_signal(Global.moretip)
	moretip.toggled.connect(_on_moretip_toggled)

	damage_show.set_pressed_no_signal(Global.settings_manager.is_damage_show_enabled())
	damage_show.toggled.connect(_on_damage_show_toggled)

	damage_type_item.clear()
	damage_type_item.add_item("原始数字")
	damage_type_item.add_item("中式缩写（万/亿）")
	damage_type_item.add_item("英式缩写（k/m/b）")
	damage_type_item.selected = Global.damage_show_type
	damage_type_item.item_selected.connect(_on_damage_type_selected)
	# 根据伤害跳字开关状态设置格式选项的禁用状态
	damage_type_item.disabled = not Global.settings_manager.is_damage_show_enabled()

	time_slow_button.set_pressed_no_signal(Global.time_slow_enabled)
	time_slow_button.toggled.connect(_on_time_slow_toggled)

	super_test_button.set_pressed_no_signal(Global.is_test)
	super_test_button.toggled.connect(_on_super_test_toggled)

func _setup_picture_panel_for_device() -> void:
	var desktop_panel := setting.get_node_or_null("huamian2") as Control
	var mobile_panel := setting.get_node_or_null("huamian_mobile") as Control
	var use_mobile := Global.is_mobile_input_mode()
	if desktop_panel:
		desktop_panel.visible = not use_mobile
	if mobile_panel:
		mobile_panel.visible = use_mobile

	var picture_root: Control = mobile_panel if use_mobile and mobile_panel != null else desktop_panel
	if picture_root == null:
		return
	screen_resolution = picture_root.get_node_or_null("ScreenResolution") as OptionButton
	full_screen = picture_root.get_node_or_null("FullScreen") as CheckButton
	vignetting = picture_root.get_node_or_null("Vignetting") as CheckButton
	noborder = picture_root.get_node_or_null("Noborder") as CheckButton

func _update_entry_button_labels_for_device() -> void:
	var show_labels := not Global.is_mobile_input_mode()
	for button in [setting_button, bag_button, skill_button, jc_button, guide_button]:
		if button == null:
			continue
		var label := button.get_node_or_null("RichTextLabel") as Control
		if label:
			label.visible = show_labels

func _on_input_device_mode_changed(_mode: String) -> void:
	_update_entry_button_labels_for_device()
	_setup_picture_panel_for_device()

func _on_main_volume_changed(value: float) -> void:
	Global.audio_manager.set_master_volume(value)
	Global.save_game()

func _on_bgm_volume_changed(value: float) -> void:
	Global.audio_manager.set_bgm_volume(value)
	Global.save_game()

func _on_se_volume_changed(value: float) -> void:
	Global.audio_manager.set_sfx_volume(value)
	Global.save_game()

func _on_resolution_selected(index: int) -> void:
	Global.settings_manager.set_resolution(index)
	Global.save_game()

func _on_fullscreen_toggled(pressed: bool) -> void:
	Global.settings_manager.set_fullscreen(pressed)
	Global.save_game()

func _on_vignetting_toggled(pressed: bool) -> void:
	Global.settings_manager.set_vignetting(pressed)
	Global.save_game()

func _on_noborder_toggled(pressed: bool) -> void:
	Global.settings_manager.set_noborder(pressed)
	Global.save_game()

func _on_particle_toggled(pressed: bool) -> void:
	Global.settings_manager.set_particle(pressed)
	Global.save_game()

func _on_moretip_toggled(pressed: bool) -> void:
	Global.set_moretip_enabled(pressed)
	Global.save_game()

func _on_damage_show_toggled(pressed: bool) -> void:
	Global.settings_manager.set_damage_show(pressed)
	# 禁用伤害跳字时，同时禁用伤害显示格式选项
	damage_type_item.disabled = not pressed
	Global.save_game()

func _on_damage_type_selected(index: int) -> void:
	Global.damage_show_type = index
	Global.save_game()

func _on_time_slow_toggled(pressed: bool) -> void:
	Global.time_slow_enabled = pressed
	Global.save_game()

func _on_super_test_toggled(pressed: bool) -> void:
	Global.is_test = pressed
	Global.save_game()

func _on_bg_volume_changed(value: float) -> void:
	Global.audio_manager.set_bg_volume(value)
	Global.save_game()

func _on_setting_pressed() -> void:
	try_open_setting()

func _on_exit_pressed() -> void:
	if not setting.visible:
		return
	if PC:
		PC.movement_disabled = false
	hide_dark_overlay()
	hide_setting_panel()

func _on_bag_pressed() -> void:
	try_open_bag()

func _on_skill_pressed() -> void:
	try_open_skill_config()

func show_dark_overlay() -> void:
	if dark_overlay == null:
		return
	dark_overlay_tween = reset_tween(dark_overlay_tween)
	dark_overlay.visible = true
	dark_overlay.modulate.a = 0.0
	dark_overlay_tween.tween_property(dark_overlay, "modulate:a", 1.0, 0.15)

func hide_dark_overlay() -> void:
	if dark_overlay == null:
		return
	dark_overlay_tween = reset_tween(dark_overlay_tween)
	dark_overlay_tween.tween_property(dark_overlay, "modulate:a", 0.0, 0.2)
	dark_overlay_tween.tween_callback(func():
		dark_overlay.visible = false
		dark_overlay.modulate.a = 0.0
	).set_delay(0.2)

func show_setting_panel() -> void:
	setting_tween = reset_tween(setting_tween)
	setting_tween.set_parallel(true)
	setting.visible = true
	refresh_entry_buttons_enabled()
	setting.modulate.a = 0.0
	for child in setting.get_children():
		child.modulate.a = 0.0
		setting_tween.tween_property(child, "modulate:a", 1.0, 0.15).set_delay(0.15)
	setting_tween.tween_property(setting, "modulate:a", 1.0, 0.15)

func hide_setting_panel() -> void:
	setting_tween = reset_tween(setting_tween)
	setting_tween.set_parallel(true)
	for child in setting.get_children():
		setting_tween.tween_property(child, "modulate:a", 0.0, 0.2)
	setting_tween.tween_property(setting, "modulate:a", 0.0, 0.2)
	setting_tween.tween_callback(reset_setting_visuals).set_delay(0.2)

func reset_setting_visuals() -> void:
	setting.visible = false
	setting.modulate.a = 1.0
	for child in setting.get_children():
		child.modulate.a = 1.0
	Global.unlock_camera_zoom(CAMERA_ZOOM_LOCK_SETTING)
	refresh_entry_buttons_enabled()

func show_bag_layer() -> void:
	bag_tween = reset_tween(bag_tween)
	bag_tween.set_parallel(true)
	bag_layer.visible = true
	refresh_entry_buttons_enabled()
	Global.lock_camera_zoom(CAMERA_ZOOM_LOCK_BAG)
	for child in bag_layer.get_children():
		child.modulate.a = 0.0
		bag_tween.tween_property(child, "modulate:a", 1.0, 0.15).set_delay(0.15)

func show_skill_layer() -> void:
	skill_tween = reset_tween(skill_tween)
	skill_tween.set_parallel(true)
	skill_setting_layer.visible = true
	refresh_entry_buttons_enabled()
	Global.lock_camera_zoom(CAMERA_ZOOM_LOCK_SKILL)
	if skill_setting_layer.has_method("open_layer"):
		skill_setting_layer.open_layer()
	for child in skill_setting_layer.get_children():
		child.modulate.a = 0.0
		skill_tween.tween_property(child, "modulate:a", 1.0, 0.15).set_delay(0.15)

func hide_skill_layer() -> void:
	if skill_setting_layer == null or not skill_setting_layer.visible:
		Global.unlock_camera_zoom(CAMERA_ZOOM_LOCK_SKILL)
		return
	skill_tween = reset_tween(skill_tween)
	skill_tween.set_parallel(true)
	for child in skill_setting_layer.get_children():
		skill_tween.tween_property(child, "modulate:a", 0.0, 0.2)
	skill_tween.tween_callback(func():
		skill_setting_layer.visible = false
		for child in skill_setting_layer.get_children():
			child.modulate.a = 1.0
		Global.unlock_camera_zoom(CAMERA_ZOOM_LOCK_SKILL)
		refresh_entry_buttons_enabled()
	).set_delay(0.2)

func reset_tween(tween: Tween) -> Tween:
	if tween and tween.is_running():
		tween.kill()
	return create_tween()
