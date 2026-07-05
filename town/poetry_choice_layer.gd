extends CanvasLayer

@export var tips: Panel # 提示

@export var copy_button: Button # 复制当前备战码
@export var use_other_button: Button # 使用他人的备战码
@export var line_edit: LineEdit # 输入框
@export var ok_button: Button
@export var exit_button: Button

@export var weapon12Panel: Panel
@export var weapon3Panel: Panel
@export var weapon3Panel2: Panel
@export var weapon3Panel3: Panel

@export var weapon12Choice: OptionButton # +12的武器选择
@export var weapon12ChoiceAdvance1: OptionButton # +12的武器选择进阶选项1
@export var weapon12ChoiceAdvance2: OptionButton # +12的武器选择进阶选项2
@export var weapon12ChoiceAdvance3: OptionButton # +12的武器选择进阶选项3
@export var weapon12ChoiceAdvance4: OptionButton # +12的武器选择进阶选项4

@export var weapon3Choice: OptionButton # +3的武器选择1
@export var weapon3Choice2: OptionButton # +3的武器选择2
@export var weapon3Choice3: OptionButton # +3的武器选择3
@export var weapon3ChoiceAdvance: OptionButton # +3的武器进阶选项
@export var weapon3Choice2Advance: OptionButton # +3的武器进阶选项
@export var weapon3Choice3Advance: OptionButton # +3的武器进阶选项

const BASE62 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
const VERSION = 1
const TOOLTIP_POSITION_OFFSET := Vector2(20, 20)
const TIP_DEFAULT_DURATION := 0.5
const TIP_SUCCESS_DURATION := 0.6
const LOCAL_WEAPON_NAMES := {
	"Zhuazhuajuchui": "爪爪巨锤",
	"RZhuazhuajuchui": "爪爪巨锤+",
	"SRZhuazhuajuchui": "爪爪巨锤+",
	"SSRZhuazhuajuchui": "爪爪巨锤+",
	"URZhuazhuajuchui": "爪爪巨锤+",
	"Zhuazhuajuchui1": "震击",
	"Zhuazhuajuchui2": "震慑",
	"Zhuazhuajuchui3": "震撼",
	"Zhuazhuajuchui4": "震爆",
	"Zhuazhuajuchui11": "震击-震爆",
	"Zhuazhuajuchui22": "震慑-震击",
	"Zhuazhuajuchui33": "震撼-震爆",
}
const LOCAL_ADVANCEMENTS := {
	"Zhuazhuajuchui": [
		{"id": "Zhuazhuajuchui1", "precondition": "check_Zhuazhuajuchui_condition", "requires": ["Zhuazhuajuchui"]},
		{"id": "Zhuazhuajuchui2", "precondition": "check_Zhuazhuajuchui_condition", "requires": ["Zhuazhuajuchui"]},
		{"id": "Zhuazhuajuchui3", "precondition": "check_Zhuazhuajuchui_condition", "requires": ["Zhuazhuajuchui"]},
		{"id": "Zhuazhuajuchui4", "precondition": "check_Zhuazhuajuchui_condition", "requires": ["Zhuazhuajuchui"]},
		{"id": "Zhuazhuajuchui11", "precondition": "check_Zhuazhuajuchui1", "requires": ["Zhuazhuajuchui1", "Zhuazhuajuchui4"]},
		{"id": "Zhuazhuajuchui22", "precondition": "check_Zhuazhuajuchui2", "requires": ["Zhuazhuajuchui2", "Zhuazhuajuchui1"]},
		{"id": "Zhuazhuajuchui33", "precondition": "check_Zhuazhuajuchui3", "requires": ["Zhuazhuajuchui3", "Zhuazhuajuchui4"]},
	],
}

var available_weapons = []
var updating_ui = false

var weapon_dropdowns = []
var adv_dropdowns_12 = []
var adv_dropdowns_3 = []
var last_valid_advs_12_indices = []

var target_stage_path = ""
var target_stage_id = ""
var main_town_ref = null

# 提示框相关
var _tooltip_panel: Panel = null
var _tooltip_canvas: CanvasLayer = null
var _tooltip_name_label: Label = null
var _tooltip_desc_label: RichTextLabel = null
var _tooltip_font: Font = null
var _tooltip_request_id: int = 0
var _tooltip_dropdown: OptionButton = null # 当前悬浮的下拉框
var _tooltip_tween: Tween = null # 渐入渐出动画

func show_layer(stage_path: String, stage_id: String, main_town):
	target_stage_path = stage_path
	target_stage_id = stage_id
	main_town_ref = main_town
	if is_instance_valid(main_town_ref) and main_town_ref.levelChangeLayer != null and main_town_ref.levelChangeLayer.has_method("suppress_stage_tooltips"):
		main_town_ref.levelChangeLayer.suppress_stage_tooltips(true)
	
	# 恢复上次出战的备战码（静默模式，不弹提示）
	if line_edit and Global.poetry_last_code != "":
		_on_use_other_code(Global.poetry_last_code, true)
	
	self.visible = true
	$Panel.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property($Panel, "modulate:a", 1.0, 0.3)

func _on_exit_pressed():
	_hide_tooltip()
	if is_instance_valid(main_town_ref) and main_town_ref.levelChangeLayer != null and main_town_ref.levelChangeLayer.has_method("suppress_stage_tooltips"):
		main_town_ref.levelChangeLayer.suppress_stage_tooltips(false)
	var tween = create_tween()
	tween.tween_property($Panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): self.visible = false)

func _is_selection_complete() -> bool:
	for dd in weapon_dropdowns:
		if not dd or dd.selected <= 0: return false
	for dd in adv_dropdowns_12:
		if not dd or dd.selected <= 0: return false
	for dd in adv_dropdowns_3:
		if not dd or dd.selected <= 0: return false
	return true

func _on_ok_pressed():
	if not _is_selection_complete():
		_show_tips("需要完整的选择所有武器及进阶后才能进入诗想难度关卡！")
		return
		
	_hide_tooltip()
	_save_poetry_loadout()
	
	# 保存备战码到 Global，下次进入自动填入
	if line_edit and line_edit.text.strip_edges().length() == 13:
		Global.poetry_last_code = line_edit.text.strip_edges()
	
	var tween = create_tween()
	tween.tween_property($Panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		self.visible = false
		if is_instance_valid(main_town_ref) and main_town_ref.levelChangeLayer != null and main_town_ref.levelChangeLayer.has_method("suppress_stage_tooltips"):
			main_town_ref.levelChangeLayer.suppress_stage_tooltips(false)
		if is_instance_valid(main_town_ref):
			main_town_ref._do_enter_stage(target_stage_path, target_stage_id, Global.STAGE_DIFFICULTY_POETRY)
	)

func _save_poetry_loadout():
	var w12_id = weapon12Choice.get_item_metadata(weapon12Choice.selected)
	var adv12_ids = []
	for dd in adv_dropdowns_12:
		adv12_ids.append(dd.get_item_metadata(dd.selected) if dd and dd.selected > 0 else "")
	var w3_ids = []
	var adv3_ids = []
	for i in range(3):
		var w_dd = weapon_dropdowns[i + 1]
		var adv_dd = adv_dropdowns_3[i]
		w3_ids.append(w_dd.get_item_metadata(w_dd.selected) if w_dd and w_dd.selected > 0 else "")
		adv3_ids.append(adv_dd.get_item_metadata(adv_dd.selected) if adv_dd and adv_dd.selected > 0 else "")
	PC.poetry_loadout = {
		"w12_id": w12_id,
		"adv12_ids": adv12_ids,
		"w3_ids": w3_ids,
		"adv3_ids": adv3_ids,
	}

func _ready():
	if copy_button: copy_button.pressed.connect(_on_copy_pressed)
	if use_other_button: use_other_button.pressed.connect(_on_use_other_pressed)
	
	if ok_button: ok_button.pressed.connect(_on_ok_pressed)
	if exit_button: exit_button.pressed.connect(_on_exit_pressed)
	self.visible = false
	
	weapon_dropdowns = [weapon12Choice, weapon3Choice, weapon3Choice2, weapon3Choice3]
	adv_dropdowns_12 = [weapon12ChoiceAdvance1, weapon12ChoiceAdvance2, weapon12ChoiceAdvance3, weapon12ChoiceAdvance4]
	adv_dropdowns_3 = [weapon3ChoiceAdvance, weapon3Choice2Advance, weapon3Choice3Advance]
	
	# Add TextureRects to panels for weapon icons
	for panel in [weapon12Panel, weapon3Panel, weapon3Panel2, weapon3Panel3]:
		if panel:
			var icon_rect = TextureRect.new()
			icon_rect.name = "WeaponIcon"
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.anchor_left = 0
			icon_rect.anchor_top = 0
			icon_rect.anchor_right = 1
			icon_rect.anchor_bottom = 1
			icon_rect.offset_left = 5
			icon_rect.offset_top = 5
			icon_rect.offset_right = -5
			icon_rect.offset_bottom = -5
			panel.add_child(icon_rect)
			
	_init_available_weapons()
	
	for i in range(weapon_dropdowns.size()):
		if weapon_dropdowns[i]:
			weapon_dropdowns[i].item_selected.connect(_on_weapon_selected.bind(i))
	
	for i in range(adv_dropdowns_12.size()):
		if adv_dropdowns_12[i]:
			adv_dropdowns_12[i].item_selected.connect(_on_adv_selected_12.bind(i))
		
	for i in range(adv_dropdowns_3.size()):
		if adv_dropdowns_3[i]:
			adv_dropdowns_3[i].item_selected.connect(_on_adv_selected_3.bind(i))
	
	# 提示框初始化
	_tooltip_font = load("res://AssetBundle/Uranus_Pixel_11Px.ttf")
	_create_tooltip_panel()
	var all_dropdowns = []
	all_dropdowns.append_array(weapon_dropdowns)
	all_dropdowns.append_array(adv_dropdowns_12)
	all_dropdowns.append_array(adv_dropdowns_3)
	for dd in all_dropdowns:
		if dd:
			var popup: PopupMenu = dd.get_popup()
			popup.popup_hide.connect(_hide_tooltip)
	# 保存所有下拉框引用给 _input 悬停检测用
	_all_dropdowns.clear()
	for dd in all_dropdowns:
		if dd:
			_all_dropdowns.append(dd)
	
	_update_all_dropdowns()

func _init_available_weapons():
	available_weapons.clear()
	for w_id in WeapDataExport.WEAPON_IDS:
		if is_weapon_unlocked(w_id):
			available_weapons.append(w_id)

func is_weapon_unlocked(w_id: String) -> bool:
	var id_map = {
		"Qiankun": "qiankun", "DragonWind": "dragonwind", "Bloodwave": "bloodwave",
		"Water": "water", "Moyan": "baoyan", "Genshan": "genshan",
		"ThunderBreak": "thunder_break", "HolyLight": "holylight", "Xuanwu": "xuanwu"
	}
	var check_id = id_map.get(w_id, "")
	if check_id != "":
		return SettingStudyTreeUp.is_weapon_unlocked(check_id)
	return true

func _on_weapon_selected(_index: int, dropdown_idx: int):
	if updating_ui: return
	
	# 切换武器时，清空对应的进阶选项
	if dropdown_idx == 0:
		for dd in adv_dropdowns_12:
			if dd: dd.select(0)
	else:
		if adv_dropdowns_3[dropdown_idx - 1]:
			adv_dropdowns_3[dropdown_idx - 1].select(0)
		
	_update_all_dropdowns()

func _on_adv_selected_12(_index: int, dropdown_idx: int):
	if updating_ui: return
	# 校验规则：如果修改或取消了某个进阶项，导致当前已选的其他进阶项前置条件不满足，则提示并还原
	if not _validate_adv_selection(adv_dropdowns_12, weapon12Choice):
		_show_tips("前置条件不足，请先取消相关的后续进阶")
		# 还原到上一次有效选择，而非强制归零
		var prev_idx = last_valid_advs_12_indices[dropdown_idx] if dropdown_idx < last_valid_advs_12_indices.size() else 0
		adv_dropdowns_12[dropdown_idx].select(prev_idx)
		_update_all_dropdowns()
		return
	_update_all_dropdowns()

func _on_adv_selected_3(_index: int, dropdown_idx: int):
	if updating_ui: return
	_update_all_dropdowns()

func _validate_adv_selection(dropdowns: Array, w_dd: OptionButton) -> bool:
	var selected_advs = []
	if w_dd and w_dd.selected > 0:
		var w_id = w_dd.get_item_metadata(w_dd.selected)
		selected_advs.append(w_id)
		# 同时添加faction名，确保requires中引用faction名的进阶也能匹配
		var faction_key = _get_weapon_faction(w_id)
		if faction_key != "" and not faction_key in selected_advs:
			selected_advs.append(faction_key)
		
	for dd in dropdowns:
		if dd and dd.selected > 0:
			selected_advs.append(dd.get_item_metadata(dd.selected))
	
	for adv_id in selected_advs:
		var requires = _get_adv_requires(adv_id)
		for req in requires:
			if not req in selected_advs:
				return false
	return true

func _get_adv_requires(adv_id: String) -> Array:
	for fac in LOCAL_ADVANCEMENTS:
		for adv in LOCAL_ADVANCEMENTS[fac]:
			if adv["id"] == adv_id:
				return adv.get("requires", [])
	for fac in WeapDataExport.ADVANCEMENTS:
		for adv in WeapDataExport.ADVANCEMENTS[fac]:
			if adv["id"] == adv_id:
				return adv.get("requires", [])
	return []

func _get_weapon_display_name(reward_id: String) -> String:
	return str(LOCAL_WEAPON_NAMES.get(reward_id, WeapDataExport.WEAPON_NAMES.get(reward_id, reward_id)))

func _get_weapon_faction(weapon_id: String) -> String:
	if weapon_id == "Zhuazhuajuchui":
		return "Zhuazhuajuchui"
	return str(WeapDataExport.WEAP_TO_FACTION.get(weapon_id, ""))

func _get_advancements_for_faction(faction: String) -> Array:
	if LOCAL_ADVANCEMENTS.has(faction):
		return LOCAL_ADVANCEMENTS[faction]
	return WeapDataExport.ADVANCEMENTS.get(faction, [])

func _update_all_dropdowns():
	updating_ui = true
	
	var selected_weapons = []
	for dd in weapon_dropdowns:
		if dd and dd.selected > 0:
			selected_weapons.append(dd.get_item_metadata(dd.selected))
			
	for i in range(weapon_dropdowns.size()):
		if weapon_dropdowns[i]:
			_populate_weapon_dropdown(weapon_dropdowns[i], selected_weapons)
		
	if weapon_dropdowns[0]:
		_populate_adv_dropdowns(weapon_dropdowns[0], adv_dropdowns_12)
	
	for i in range(3):
		if weapon_dropdowns[i + 1] and adv_dropdowns_3[i]:
			_populate_adv_dropdowns(weapon_dropdowns[i + 1], [adv_dropdowns_3[i]])
		
	_generate_code()
	_update_weapon_icons()
	
	last_valid_advs_12_indices.clear()
	for dd in adv_dropdowns_12:
		last_valid_advs_12_indices.append(dd.selected if dd else 0)
		
	updating_ui = false

func _update_weapon_icons():
	var panels = [weapon12Panel, weapon3Panel, weapon3Panel2, weapon3Panel3]
	for i in range(4):
		var panel = panels[i]
		var dd = weapon_dropdowns[i]
		if panel and dd:
			var icon_rect = panel.get_node_or_null("WeaponIcon")
			if icon_rect:
				var w_id = ""
				if dd.selected > 0:
					w_id = dd.get_item_metadata(dd.selected)
				if w_id != "":
					var reward = LvUp.get_reward_by_id(w_id)
					var icon_name = reward.icon if reward != null else ""
					if icon_name != "" and LvUp.has_method("get_icon_path"):
						var icon_path = LvUp.get_icon_path(icon_name)
						if icon_path != "" and ResourceLoader.exists(icon_path):
							icon_rect.texture = load(icon_path)
						else:
							icon_rect.texture = null
					else:
						icon_rect.texture = null
				else:
					icon_rect.texture = null

func _populate_weapon_dropdown(dropdown: OptionButton, selected_weapons: Array):
	var current_sel = ""
	if dropdown.selected > 0:
		current_sel = dropdown.get_item_metadata(dropdown.selected)
		
	dropdown.clear()
	dropdown.add_item("---")
	dropdown.set_item_metadata(0, "")
	
	var idx = 1
	var to_select = 0
	for w_id in available_weapons:
		if w_id in selected_weapons and w_id != current_sel:
			continue
		dropdown.add_item(_get_weapon_display_name(w_id))
		dropdown.set_item_metadata(idx, w_id)
		if w_id == current_sel:
			to_select = idx
		idx += 1
		
	dropdown.select(to_select)

func _populate_adv_dropdowns(weapon_dropdown: OptionButton, adv_dropdowns: Array):
	var w_id = ""
	if weapon_dropdown.selected > 0:
		w_id = weapon_dropdown.get_item_metadata(weapon_dropdown.selected)
		
	var faction = _get_weapon_faction(w_id)
	var available_advs = []
	if faction != "":
		available_advs = _get_advancements_for_faction(faction)
		
	var current_selections = []
	if w_id != "":
		current_selections.append(w_id)
		# 同时添加faction名，确保requires中引用faction名的进阶也能匹配
		var faction_key = _get_weapon_faction(w_id)
		if faction_key != "" and not faction_key in current_selections:
			current_selections.append(faction_key)
		
	for dd in adv_dropdowns:
		if dd and dd.selected > 0:
			current_selections.append(dd.get_item_metadata(dd.selected))
			
	for dd in adv_dropdowns:
		if not dd: continue
		var current_sel = ""
		if dd.selected > 0:
			current_sel = dd.get_item_metadata(dd.selected)
			
		dd.clear()
		dd.add_item("---")
		dd.set_item_metadata(0, "")
		
		var idx = 1
		var to_select = 0
		for adv in available_advs:
			var adv_id = adv["id"]
			if adv_id in current_selections and adv_id != current_sel:
				continue
				
			# Check requirements to display
			var can_add = true
			if adv_id != current_sel:
				for req in adv.get("requires", []):
					if not req in current_selections:
						can_add = false
						break
			if not can_add: continue
				
			dd.add_item(_get_weapon_display_name(adv_id))
			dd.set_item_metadata(idx, adv_id)
			if adv_id == current_sel:
				to_select = idx
			idx += 1
			
		dd.select(to_select)

func _generate_code():
	if not _is_selection_complete():
		if line_edit:
			line_edit.text = ""
		return
		
	var code = ""
	code += _encode_char(VERSION)
	
	var content = ""
	# W12
	content += _encode_weapon(weapon12Choice)
	for dd in adv_dropdowns_12: content += _encode_adv(dd, weapon12Choice)
	
	# W3
	for i in range(3):
		content += _encode_weapon(weapon_dropdowns[i + 1])
		content += _encode_adv(adv_dropdowns_3[i], weapon_dropdowns[i + 1])
		
	var sum = 0
	for c in content:
		sum += c.unicode_at(0)
	var checksum = sum % 62
	
	code += _encode_char(checksum) + content
	if line_edit:
		line_edit.text = code

func _encode_char(val: int) -> String:
	if val < 0 or val >= 62: return "_"
	return BASE62[val]

func _decode_char(c: String) -> int:
	return BASE62.find(c)

func _encode_weapon(dd: OptionButton) -> String:
	if not dd or dd.selected <= 0: return "_"
	var w_id = dd.get_item_metadata(dd.selected)
	var idx = WeapDataExport.WEAPON_IDS.find(w_id)
	return _encode_char(idx)

func _encode_adv(dd: OptionButton, w_dd: OptionButton) -> String:
	if not dd or not w_dd or dd.selected <= 0 or w_dd.selected <= 0: return "_"
	var adv_id = dd.get_item_metadata(dd.selected)
	var w_id = w_dd.get_item_metadata(w_dd.selected)
	var faction = _get_weapon_faction(w_id)
	var advancements := _get_advancements_for_faction(faction)
	if advancements.is_empty(): return "_"
	
	var idx = 0
	for adv in advancements:
		if adv["id"] == adv_id:
			return _encode_char(idx)
		idx += 1
	return "_"

func _on_copy_pressed():
	if line_edit:
		DisplayServer.clipboard_set(line_edit.text)
	_show_tips("已复制备战码", TIP_SUCCESS_DURATION)

func _on_use_other_pressed():
	if not line_edit: return
	var code = line_edit.text.strip_edges()
	_on_use_other_code(code, false)

func _on_use_other_code(code: String, silent: bool = false) -> bool:
	if code.length() != 13:
		if not silent:
			_show_tips("备战码格式错误或不完整")
		return false
		
	var version = _decode_char(code[0])
	var checksum = _decode_char(code[1])
	var content = code.substr(2)
	
	var sum = 0
	for c in content:
		sum += c.unicode_at(0)
	if sum % 62 != checksum:
		if not silent:
			_show_tips("备战码校验失败，可能被篡改")
		return false
		
	# Validate weapons
	var w12_idx = _decode_char(content[0])
	var w3_1_idx = _decode_char(content[5])
	var w3_2_idx = _decode_char(content[7])
	var w3_3_idx = _decode_char(content[9])
	
	var needed_weapons = []
	for idx in [w12_idx, w3_1_idx, w3_2_idx, w3_3_idx]:
		if idx >= 0 and idx < WeapDataExport.WEAPON_IDS.size():
			var w_id = WeapDataExport.WEAPON_IDS[idx]
			if not w_id in available_weapons:
				if not silent:
					_show_tips("备战码包含未解锁的武器: " + _get_weapon_display_name(w_id), TIP_SUCCESS_DURATION)
				return false
			if w_id in needed_weapons:
				if not silent:
					_show_tips("备战码包含重复武器")
				return false
			needed_weapons.append(w_id)
			
	# Apply
	updating_ui = true
	if weapon12Choice: _apply_weapon(weapon12Choice, w12_idx)
	for i in range(4):
		if adv_dropdowns_12[i]: _apply_adv(adv_dropdowns_12[i], weapon12Choice, _decode_char(content[1 + i]))
	
	if weapon3Choice: _apply_weapon(weapon3Choice, w3_1_idx)
	if weapon3ChoiceAdvance: _apply_adv(weapon3ChoiceAdvance, weapon3Choice, _decode_char(content[6]))
	
	if weapon3Choice2: _apply_weapon(weapon3Choice2, w3_2_idx)
	if weapon3Choice2Advance: _apply_adv(weapon3Choice2Advance, weapon3Choice2, _decode_char(content[8]))
	
	if weapon3Choice3: _apply_weapon(weapon3Choice3, w3_3_idx)
	if weapon3Choice3Advance: _apply_adv(weapon3Choice3Advance, weapon3Choice3, _decode_char(content[10]))
	
	updating_ui = false
	_update_all_dropdowns()
	if line_edit:
		line_edit.text = code
	if not silent:
		_show_tips("备战码应用成功", TIP_SUCCESS_DURATION)
	return true

func _show_tips(message: String, duration: float = TIP_DEFAULT_DURATION) -> void:
	if tips and tips.has_method("start_animation"):
		tips.start_animation(message, duration)

func _apply_weapon(dd: OptionButton, idx: int):
	dd.clear()
	dd.add_item("---")
	dd.set_item_metadata(0, "")
	if idx >= 0 and idx < WeapDataExport.WEAPON_IDS.size():
		var w_id = WeapDataExport.WEAPON_IDS[idx]
		dd.add_item(_get_weapon_display_name(w_id))
		dd.set_item_metadata(1, w_id)
		dd.select(1)
	else:
		dd.select(0)

func _apply_adv(dd: OptionButton, w_dd: OptionButton, idx: int):
	dd.clear()
	dd.add_item("---")
	dd.set_item_metadata(0, "")
	if w_dd and w_dd.selected > 0 and idx >= 0:
		var w_id = w_dd.get_item_metadata(w_dd.selected)
		var faction = _get_weapon_faction(w_id)
		var advs = _get_advancements_for_faction(faction)
		if not advs.is_empty():
			if idx < advs.size():
				var adv_id = advs[idx]["id"]
				dd.add_item(_get_weapon_display_name(adv_id))
				dd.set_item_metadata(1, adv_id)
				dd.select(1)
				return
	dd.select(0)

# ============== 提示框相关 ==============

# 通过 _process 轮询检测鼠标在 popup 选项上的悬停
# 因为 PopupMenu 在 Godot 4 中是独立 Window，_input 收不到 popup 上的鼠标事件
var _all_dropdowns: Array[OptionButton] = []
var _active_popup: PopupMenu = null
var _active_dropdown: OptionButton = null
var _last_hovered_item_idx: int = -1

func _process(_delta: float) -> void:
	if not visible:
		return
	# 检测是否有 popup 可见
	var any_popup_visible = false
	for dd in _all_dropdowns:
		if is_instance_valid(dd) and dd.get_popup().visible:
			any_popup_visible = true
			break
	if any_popup_visible:
		_check_popup_hover()

func _get_window_to_viewport_scale() -> Vector2:
	var vp_size = get_viewport().get_visible_rect().size
	var win_size = Vector2(DisplayServer.window_get_size())
	return Vector2(
		win_size.x / vp_size.x if vp_size.x > 0 else 1.0,
		win_size.y / vp_size.y if vp_size.y > 0 else 1.0
	)

func _check_popup_hover() -> void:
	var viewport = get_viewport()
	var mouse_vp = viewport.get_mouse_position()
	
	for dd in _all_dropdowns:
		if not is_instance_valid(dd):
			continue
		var popup = dd.get_popup()
		if not popup:
			continue
		if popup.visible:
			var popup_rect := _get_popup_rect_containing_mouse(popup, mouse_vp)
			if not popup_rect.has_point(mouse_vp):
				continue
			var popup_vp_pos = popup_rect.position
			var popup_vp_size = popup_rect.size
			if popup_rect.has_point(mouse_vp):
				_active_popup = popup
				_active_dropdown = dd
				var relative_y = mouse_vp.y - popup_vp_pos.y
				var item_count = popup.item_count
				if item_count > 0:
					var item_height = popup_vp_size.y / float(item_count)
					var hovered_idx = int(relative_y / item_height)
					hovered_idx = clampi(hovered_idx, 0, item_count - 1)
					if popup.is_item_separator(hovered_idx):
						_hide_tooltip()
						_last_hovered_item_idx = -1
						return
					if hovered_idx != _last_hovered_item_idx:
						_last_hovered_item_idx = hovered_idx
						_on_popup_item_hovered(hovered_idx, dd)
					return
				_hide_tooltip()
				_last_hovered_item_idx = -1
				return
	
	if _active_popup:
		_hide_tooltip()
		_active_popup = null
		_active_dropdown = null
		_last_hovered_item_idx = -1

func _get_popup_rect_containing_mouse(popup: PopupMenu, mouse_vp: Vector2) -> Rect2:
	var raw_rect := Rect2(Vector2(popup.position), Vector2(popup.size))
	if raw_rect.has_point(mouse_vp):
		return raw_rect
	var scale := _get_window_to_viewport_scale()
	var scaled_rect := Rect2(raw_rect.position / scale, raw_rect.size / scale)
	if scaled_rect.has_point(mouse_vp):
		return scaled_rect
	return raw_rect

func _on_popup_item_hovered(item_index: int, dropdown: OptionButton) -> void:
	# index 0 通常是 "---" 占位符
	if item_index <= 0:
		_hide_tooltip()
		return
	var item_meta = dropdown.get_item_metadata(item_index)
	if item_meta == null or item_meta == "":
		_hide_tooltip()
		return
	
	var reward = LvUp.get_reward_by_id(str(item_meta))
	if reward == null:
		_hide_tooltip()
		return
	
	_tooltip_dropdown = dropdown
	_tooltip_request_id += 1
	
	_tooltip_name_label.text = reward.reward_name
	var detail_text = reward.detail
	var lines = detail_text.split("\n")
	var filtered_lines = []
	for line in lines:
		if line.begins_with("[color=YELLOW]"):
			continue
		filtered_lines.append(line)
	_tooltip_desc_label.text = "\n".join(filtered_lines)
	
	# 不再 await，直接显示
	_tooltip_panel.modulate.a = 0.0
	_show_tooltip_near_popup()

func _show_tooltip_near_popup() -> void:
	if _tooltip_panel == null or _tooltip_dropdown == null:
		return
	
	var content_size = _tooltip_desc_label.get_combined_minimum_size()
	var panel_width = maxf(300, content_size.x + 20)
	var panel_height = _tooltip_name_label.get_combined_minimum_size().y + 8 + content_size.y + 16 + 16
	_tooltip_panel.size = Vector2(panel_width, panel_height)
	_tooltip_desc_label.size = Vector2(panel_width - 20, content_size.y)
	
	var dropdown_rect := _tooltip_dropdown.get_global_rect()
	var tip_pos = Vector2(dropdown_rect.position.x + dropdown_rect.size.x + 12, dropdown_rect.position.y)

	# 确保不超出 viewport
	var viewport_size = get_viewport().get_visible_rect().size
	if tip_pos.x + panel_width > viewport_size.x:
		tip_pos.x = dropdown_rect.position.x - panel_width - 12
	if tip_pos.y + panel_height > viewport_size.y:
		tip_pos.y = viewport_size.y - panel_height - 10
	if tip_pos.x < 0:
		tip_pos.x = 10
	if tip_pos.y < 0:
		tip_pos.y = 10
	
	tip_pos += TOOLTIP_POSITION_OFFSET
	_tooltip_panel.position = tip_pos
	_tooltip_panel.visible = true
	# 渐入动画，打断上一次
	if _tooltip_tween and _tooltip_tween.is_valid():
		_tooltip_tween.kill()
	_tooltip_tween = create_tween()
	_tooltip_tween.tween_property(_tooltip_panel, "modulate:a", 1.0, 0.15)

func _create_tooltip_panel() -> void:
	_tooltip_panel = Panel.new()
	_tooltip_panel.name = "DropdownTooltipPanel"
	_tooltip_panel.visible = false
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.88)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.border_color = Color(0.6, 0.5, 0.3, 0.8)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	_tooltip_panel.add_theme_stylebox_override("panel", style)
	
	# 使用独立CanvasLayer，挂到 root viewport 下，layer=100确保在最上层
	_tooltip_canvas = CanvasLayer.new()
	_tooltip_canvas.name = "DropdownTooltipCanvasLayer"
	_tooltip_canvas.layer = 100
	_tooltip_canvas.add_child(_tooltip_panel)
	get_tree().root.call_deferred("add_child", _tooltip_canvas)
	
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
	vbox.position = Vector2(10, 8)
	_tooltip_panel.add_child(vbox)
	
	_tooltip_name_label = Label.new()
	_tooltip_name_label.name = "NameLabel"
	_setup_tooltip_label_style(_tooltip_name_label, Color(1.0, 0.85, 0.0))
	vbox.add_child(_tooltip_name_label)
	
	var sep := HSeparator.new()
	vbox.add_child(sep)
	
	_tooltip_desc_label = RichTextLabel.new()
	_tooltip_desc_label.name = "DescLabel"
	_tooltip_desc_label.bbcode_enabled = true
	_tooltip_desc_label.custom_minimum_size = Vector2(280, 0)
	_tooltip_desc_label.fit_content = true
	_tooltip_desc_label.scroll_active = false
	if _tooltip_font:
		_tooltip_desc_label.add_theme_font_override("normal_font", _tooltip_font)
	_tooltip_desc_label.add_theme_font_size_override("normal_font_size", 22)
	_tooltip_desc_label.add_theme_color_override("default_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(_tooltip_desc_label)

func _setup_tooltip_label_style(label: Label, font_color: Color = Color.WHITE) -> void:
	if _tooltip_font:
		label.add_theme_font_override("font", _tooltip_font)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)

func _hide_tooltip() -> void:
	_tooltip_request_id += 1
	_tooltip_dropdown = null
	_last_hovered_item_idx = -1
	if _tooltip_panel and _tooltip_panel.visible:
		# 渐出动画，打断上一次
		if _tooltip_tween and _tooltip_tween.is_valid():
			_tooltip_tween.kill()
		_tooltip_tween = create_tween()
		_tooltip_tween.tween_property(_tooltip_panel, "modulate:a", 0.0, 0.12)
		_tooltip_tween.tween_callback(func(): _tooltip_panel.visible = false)

func _exit_tree() -> void:
	# 清理挂到 root viewport 的 CanvasLayer，避免内存泄漏
	if _tooltip_canvas and is_instance_valid(_tooltip_canvas):
		_tooltip_canvas.queue_free()
		_tooltip_canvas = null
