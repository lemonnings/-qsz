extends CanvasLayer

@onready var setting: Panel = $Panel
@onready var setting_button: Button = $Setting
@onready var bag_button: Button = $Bag
@onready var skill_button: Button = $Skill
@onready var main_volume: HSlider = $Panel/MainVolume
@onready var bgm_volume: HSlider = $Panel/BGMVolume
@onready var se_volume: HSlider = $Panel/SEVolume
@onready var bg_volume: HSlider = $Panel/BGVolume
@onready var screen_resolution: OptionButton = $Panel/ScreenResolution
@onready var full_screen: CheckButton = $Panel/FullScreen
@onready var vignetting: CheckButton = $Panel/Vignetting
@onready var particle: CheckButton = $Panel/Particle
@onready var damage_show: CheckButton = $Panel/DamageShow
@onready var damage_type_item: OptionButton = $Panel/DamageTypeItem
@onready var exit_button: Button = $Panel/Exit2
@onready var dark_overlay: Control = get_node("../CanvasLayer/DarkOverlay")
@onready var bag_layer: CanvasLayer = get_node("../BagLayer")
@onready var skill_setting_layer: CanvasLayer = get_node("../SkillSettingLayer")

var setting_tween: Tween
var dark_overlay_tween: Tween
var bag_tween: Tween
var skill_tween: Tween

func _ready() -> void:
	setting.visible = false
	setup_settings_ui()
	setting_button.pressed.connect(_on_setting_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	bag_button.pressed.connect(_on_bag_pressed)
	skill_button.pressed.connect(_on_skill_pressed)

func lock_setting_button() -> void:
	setting_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

func unlock_setting_button() -> void:
	setting_button.mouse_filter = Control.MOUSE_FILTER_STOP

func close_setting_panel() -> void:
	if not setting.visible:
		return
	_on_exit_pressed()

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

	screen_resolution.clear()
	screen_resolution.add_item("1024 × 576")
	screen_resolution.add_item("1366 × 768")
	screen_resolution.add_item("1920 × 1080")
	screen_resolution.add_item("2240 × 1260")
	screen_resolution.selected = Global.settings_manager.get_current_resolution_index()
	screen_resolution.item_selected.connect(_on_resolution_selected)

	full_screen.button_pressed = Global.settings_manager.is_fullscreen_enabled()
	full_screen.toggled.connect(_on_fullscreen_toggled)

	vignetting.button_pressed = Global.settings_manager.is_vignetting_enabled()
	vignetting.toggled.connect(_on_vignetting_toggled)

	particle.button_pressed = Global.settings_manager.is_particle_enabled()
	particle.toggled.connect(_on_particle_toggled)

	damage_show.button_pressed = Global.settings_manager.is_damage_show_enabled()
	damage_show.toggled.connect(_on_damage_show_toggled)

	damage_type_item.clear()
	damage_type_item.add_item("原始数字")
	damage_type_item.add_item("中式缩写（万/亿）")
	damage_type_item.add_item("英式缩写（k/m/b）")
	damage_type_item.selected = Global.damage_show_type
	damage_type_item.item_selected.connect(_on_damage_type_selected)
	# 根据伤害跳字开关状态设置格式选项的禁用状态
	damage_type_item.disabled = not Global.settings_manager.is_damage_show_enabled()

func _on_main_volume_changed(value: float) -> void:
	Global.audio_manager.set_master_volume(value)

func _on_bgm_volume_changed(value: float) -> void:
	Global.audio_manager.set_bgm_volume(value)

func _on_se_volume_changed(value: float) -> void:
	Global.audio_manager.set_sfx_volume(value)

func _on_resolution_selected(index: int) -> void:
	Global.settings_manager.set_resolution(index)

func _on_fullscreen_toggled(pressed: bool) -> void:
	Global.settings_manager.set_fullscreen(pressed)

func _on_vignetting_toggled(pressed: bool) -> void:
	Global.settings_manager.set_vignetting(pressed)

func _on_particle_toggled(pressed: bool) -> void:
	Global.settings_manager.set_particle(pressed)

func _on_damage_show_toggled(pressed: bool) -> void:
	Global.settings_manager.set_damage_show(pressed)
	# 禁用伤害跳字时，同时禁用伤害显示格式选项
	damage_type_item.disabled = not pressed

func _on_damage_type_selected(index: int) -> void:
	Global.damage_show_type = index

func _on_bg_volume_changed(value: float) -> void:
	Global.audio_manager.set_bg_volume(value)

func _on_setting_pressed() -> void:
	if setting.visible:
		return
	PC.movement_disabled = true
	show_dark_overlay()
	show_setting_panel()

func _on_exit_pressed() -> void:
	if not setting.visible:
		return
	PC.movement_disabled = false
	hide_dark_overlay()
	hide_setting_panel()

func _on_bag_pressed() -> void:
	if bag_layer.visible:
		return
	PC.movement_disabled = true
	show_dark_overlay()
	show_bag_layer()

func _on_skill_pressed() -> void:
	if skill_setting_layer.visible:
		return
	PC.movement_disabled = true
	show_dark_overlay()
	show_skill_layer()

func show_dark_overlay() -> void:
	dark_overlay_tween = reset_tween(dark_overlay_tween)
	dark_overlay.visible = true
	dark_overlay.modulate.a = 0.0
	dark_overlay_tween.tween_property(dark_overlay, "modulate:a", 1.0, 0.15)

func hide_dark_overlay() -> void:
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

func show_bag_layer() -> void:
	bag_tween = reset_tween(bag_tween)
	bag_tween.set_parallel(true)
	bag_layer.visible = true
	for child in bag_layer.get_children():
		child.modulate.a = 0.0
		bag_tween.tween_property(child, "modulate:a", 1.0, 0.15).set_delay(0.15)

func show_skill_layer() -> void:
	skill_tween = reset_tween(skill_tween)
	skill_tween.set_parallel(true)
	skill_setting_layer.visible = true
	if skill_setting_layer.has_method("open_layer"):
		skill_setting_layer.open_layer()
	for child in skill_setting_layer.get_children():
		child.modulate.a = 0.0
		skill_tween.tween_property(child, "modulate:a", 1.0, 0.15).set_delay(0.15)

func hide_skill_layer() -> void:
	skill_tween = reset_tween(skill_tween)
	skill_tween.set_parallel(true)
	for child in skill_setting_layer.get_children():
		skill_tween.tween_property(child, "modulate:a", 0.0, 0.2)
	skill_tween.tween_callback(func():
		skill_setting_layer.visible = false
		for child in skill_setting_layer.get_children():
			child.modulate.a = 1.0
	).set_delay(0.2)

func reset_tween(tween: Tween) -> Tween:
	if tween and tween.is_running():
		tween.kill()
	return create_tween()
