extends CanvasLayer

signal exit_requested

const SETTING_MONSTER_SCRIPT = preload("res://Script/config/setting_moster.gd")
const SHOP_LEVEL_CAP := 8
const SHOP_HEADER_FONT_SIZE := 39
const TOOLTIP_FONT_SIZE := 24
const RARITY_ORDER := ["white", "blue", "purple", "gold", "red"]
const RARITY_NAMES := {
	"white": "白",
	"blue": "蓝",
	"purple": "紫",
	"gold": "金",
	"red": "红"
}
const SHOP_RARITY_DISPLAY_NAMES := {
	"white": "普通品级",
	"blue": "稀有品级",
	"purple": "史诗品级",
	"gold": "传说品级",
	"red": "神话品级"
}
const RARITY_COLORS := {
	"white": Color(1, 1, 1, 1),
	"blue": Color(0.45, 0.75, 1.0, 1),
	"purple": Color(0.82, 0.52, 1.0, 1),
	"gold": Color(1.0, 0.87, 0.36, 1),
	"red": Color(1.0, 0.45, 0.45, 1)
}
const LINGSHI_PACK_QUANTITY := {
	"white": 10,
	"blue": 20,
	"purple": 40,
	"gold": 80,
	"red": 160
}
const OFFER_TABLES := {
	"white": [
		{"kind": "lingshi", "weight": 30},
		{"kind": "common_material", "weight": 10},
		{"kind": "tier1_pill", "weight": 20},
		{"kind": "basic_element", "weight": 10},
		{"kind": "lower_special", "weight": 20},
		{"kind": "boss_material", "weight": 10}
	],
	"blue": [
		{"kind": "lingshi", "weight": 30},
		{"kind": "common_material", "weight": 10},
		{"kind": "tier2_pill", "weight": 20},
		{"kind": "basic_element", "weight": 10},
		{"kind": "lower_special", "weight": 20},
		{"kind": "boss_material", "weight": 10}
	],
	"purple": [
		{"kind": "lingshi", "weight": 30},
		{"kind": "common_material", "weight": 10},
		{"kind": "tier3_pill", "weight": 20},
		{"kind": "ether", "weight": 10},
		{"kind": "middle_special", "weight": 20},
		{"kind": "boss_material", "weight": 10}
	],
	"gold": [
		{"kind": "lingshi", "weight": 30},
		{"kind": "common_material", "weight": 10},
		{"kind": "tier4_pill", "weight": 20},
		{"kind": "ether", "weight": 10},
		{"kind": "middle_special", "weight": 20},
		{"kind": "boss_material", "weight": 10}
	],
	"red": [
		{"kind": "lingshi", "weight": 25},
		{"kind": "tier5_pill", "weight": 25},
		{"kind": "upper_special", "weight": 25},
		{"kind": "boss_material", "weight": 25}
	]
}
const BASIC_MONSTER_DROP_METHODS := [
	"slime_blue",
	"taohua_yao",
	"frog",
	"lantern",
	"paper",
	"bat",
	"slime_grey",
	"ghost",
	"armor_stone",
	"stone_man",
	"slime_green",
	"shen",
	"frog_new",
	"ball"
]
const BASIC_ELEMENT_IDS := ["item_009", "item_010", "item_017", "item_015", "item_014"]
const ELEMENT_YUAN_IDS := ["item_018", "item_019", "item_020", "item_021", "item_022"]
const ETHER_IDS := ["item_031", "item_032", "item_033", "item_034", "item_035"]
const BOSS_MATERIAL_IDS := ["item_097", "item_098", "item_099", "item_100", "item_101"]
const TIER1_PILLS := ["item_047", "item_048", "item_049", "item_050", "item_051", "item_052", "item_053", "item_054"]
const TIER2_PILLS := ["item_036", "item_037", "item_038", "item_039", "item_055", "item_056", "item_057", "item_058"]
const TIER3_PILLS := ["item_060", "item_061", "item_062", "item_063", "item_064", "item_065", "item_066", "item_067"]
const TIER4_PILLS := ["item_068", "item_069", "item_070", "item_071", "item_072", "item_073", "item_074", "item_075"]
const TIER5_PILLS := ["item_076", "item_077", "item_078", "item_079", "item_080", "item_081", "item_082", "item_083"]
const LOWER_SPECIAL_PILLS := ["item_085", "item_088", "item_091", "item_094"]
const MIDDLE_SPECIAL_PILLS := ["item_086", "item_089", "item_092", "item_095"]
const UPPER_SPECIAL_PILLS := ["item_087", "item_090", "item_093", "item_096"]
const SHOP_UPGRADE_COSTS := {
	1: [{"item_id": Global.LINGSHI_ITEM_ID, "count": 100}],
	2: [
		{"item_id": "item_018", "count": 15},
		{"item_id": "item_019", "count": 15},
		{"item_id": "item_020", "count": 15},
		{"item_id": "item_021", "count": 15},
		{"item_id": "item_022", "count": 15},
		{"item_id": Global.LINGSHI_ITEM_ID, "count": 200}
	],
	3: [
		{"item_id": "item_018", "count": 45},
		{"item_id": "item_019", "count": 45},
		{"item_id": "item_020", "count": 45},
		{"item_id": "item_021", "count": 45},
		{"item_id": "item_022", "count": 45},
		{"item_id": "item_011", "count": 50},
		{"item_id": Global.LINGSHI_ITEM_ID, "count": 400}
	],
	4: [
		{"item_id": "item_031", "count": 5},
		{"item_id": "item_032", "count": 5},
		{"item_id": "item_033", "count": 5},
		{"item_id": "item_034", "count": 5},
		{"item_id": "item_035", "count": 5},
		{"item_id": "item_011", "count": 100},
		{"item_id": Global.LINGSHI_ITEM_ID, "count": 800}
	]
}

@export var item1: Panel
@export var item2: Panel
@export var item3: Panel
@export var item4: Panel
@export var item5: Panel
@export var item6: Panel

@export var item1_name: RichTextLabel
@export var item2_name: RichTextLabel
@export var item3_name: RichTextLabel
@export var item4_name: RichTextLabel
@export var item5_name: RichTextLabel
@export var item6_name: RichTextLabel

@export var item1_price: RichTextLabel
@export var item2_price: RichTextLabel
@export var item3_price: RichTextLabel
@export var item4_price: RichTextLabel
@export var item5_price: RichTextLabel
@export var item6_price: RichTextLabel

@export var refresh_num: RichTextLabel
@export var shop_level_up_button: Button

@export var tips: Panel

var _item_panels: Array[Panel] = []
var _detail_labels: Array[RichTextLabel] = []
var _price_labels: Array[RichTextLabel] = []
var _icon_nodes: Array[TextureRect] = []
var _shop_items: Array[Dictionary] = []
var _common_material_pool: Array[String] = []
var _shop_level_label: RichTextLabel
var _offer_tooltip_panel: Panel
var _upgrade_info_panel: Panel
var _exit_button: Button
var _tooltip_font: Font = null
var _setting_monster = SETTING_MONSTER_SCRIPT.new()
# 这个标记只表示“本次打开商店后，是否还没做过自动刷新”。
# 关闭商店后会重置为 true，因此下一次重新打开商店时仍会自动刷新一次。
var _need_auto_refresh_on_open: bool = true

func _ready() -> void:
	randomize()
	visible = false
	layer = 21
	if ResourceLoader.exists("res://AssetBundle/Uranus_Pixel_11Px.ttf"):
		_tooltip_font = load("res://AssetBundle/Uranus_Pixel_11Px.ttf")
	_cache_nodes()
	_create_extra_controls()
	_connect_interactions()
	_build_common_material_pool()
	_ensure_shop_state()
	_refresh_display()

func open_shop() -> void:
	_ensure_shop_state()
	_load_shop_items_from_save()
	_hide_offer_tooltip()
	_hide_upgrade_info()
	var recycle_message := _recycle_obsolete_pills()
	var did_auto_refresh := false
	# 这里只判断“本次开店是不是第一次处理自动刷新”，而不是判断整个存档的人生第一次进商店。
	# 这样玩家每次重新打开商店时，都会稳定地自动刷新一次。
	if _need_auto_refresh_on_open or _shop_items.size() != _item_panels.size():
		_generate_shop_items()
		_need_auto_refresh_on_open = false
		did_auto_refresh = true
	_refresh_display()
	_save_shop_items_to_save()
	_refresh_external_ui()
	Global.save_game()
	if not recycle_message.is_empty():
		_show_tips(recycle_message, 1.2)
	elif did_auto_refresh:
		_show_tips("本次进入货摊，已自动刷新一次。", 0.7)

func _cache_nodes() -> void:
	_item_panels = [item1, item2, item3, item4, item5, item6]
	_detail_labels = [
		get_node("item1_detail"),
		get_node("item1_detail2"),
		get_node("item1_detail3"),
		get_node("item1_detail4"),
		get_node("item1_detail5"),
		get_node("item1_detail6")
	]
	_price_labels = [item1_price, item2_price, item3_price, item4_price, item5_price, item6_price]
	_shop_level_label = get_node("shop_level")
	_shop_level_label.bbcode_enabled = true
	_shop_level_label.add_theme_font_size_override("normal_font_size", 22)
	_shop_level_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shop_level_label.scroll_active = false
	for panel in _item_panels:
		_icon_nodes.append(_ensure_icon_node(panel))

func _create_extra_controls() -> void:
	_offer_tooltip_panel = _create_bag_style_panel("OfferTooltipPanel", true)
	add_child(_offer_tooltip_panel)

	_upgrade_info_panel = _create_bag_style_panel("UpgradeInfoPanel", false)
	add_child(_upgrade_info_panel)

	_exit_button = Button.new()
	_exit_button.name = "ExitButton"
	_exit_button.text = "返回"
	_exit_button.position = Vector2(1118, 93)
	_exit_button.size = Vector2(112, 54)
	_exit_button.focus_mode = Control.FOCUS_NONE
	_exit_button.theme = shop_level_up_button.theme
	add_child(_exit_button)

func _setup_label_style(label: Label, font_color: Color = Color.WHITE) -> void:
	if _tooltip_font:
		label.add_theme_font_override("font", _tooltip_font)
	label.add_theme_font_size_override("font_size", TOOLTIP_FONT_SIZE)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)

func _create_bag_style_panel(panel_name: String, include_icon: bool) -> Panel:
	var panel := Panel.new()
	panel.name = panel_name
	panel.visible = false
	panel.z_index = 100
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
	vbox.position = Vector2(10, 8)
	panel.add_child(vbox)

	var header_hbox := HBoxContainer.new()
	header_hbox.name = "Header"
	vbox.add_child(header_hbox)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(32, 32)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.visible = include_icon
	header_hbox.add_child(icon)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	_setup_label_style(name_label)
	header_hbox.add_child(name_label)

	var type_label := Label.new()
	type_label.name = "TypeLabel"
	_setup_label_style(type_label, Color(0.7, 0.7, 0.7))
	vbox.add_child(type_label)

	var separator := HSeparator.new()
	vbox.add_child(separator)

	var desc_label := Label.new()
	desc_label.name = "DescLabel"
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(220, 0)
	_setup_label_style(desc_label)
	vbox.add_child(desc_label)

	var separator2 := HSeparator.new()
	vbox.add_child(separator2)

	var price_label := Label.new()
	price_label.name = "PriceLabel"
	price_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_setup_label_style(price_label, Color(1.0, 0.85, 0.0))
	vbox.add_child(price_label)

	var hint_label := Label.new()
	hint_label.name = "UseHintLabel"
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_setup_label_style(hint_label, Color(1.0, 1.0, 0.0))
	hint_label.visible = false
	vbox.add_child(hint_label)

	return panel

func _get_info_panel_nodes(panel: Panel) -> Dictionary:
	var vbox := panel.get_node("VBox") as VBoxContainer
	var header := vbox.get_node("Header") as HBoxContainer
	return {
		"vbox": vbox,
		"icon": header.get_node("Icon") as TextureRect,
		"name_label": header.get_node("NameLabel") as Label,
		"type_label": vbox.get_node("TypeLabel") as Label,
		"desc_label": vbox.get_node("DescLabel") as Label,
		"price_label": vbox.get_node("PriceLabel") as Label,
		"hint_label": vbox.get_node("UseHintLabel") as Label
	}

func _reset_info_panel_layout(panel: Panel, desc_min_width: float) -> Dictionary:
	var nodes := _get_info_panel_nodes(panel)
	var vbox := nodes["vbox"] as VBoxContainer
	var desc_label := nodes["desc_label"] as Label
	# 第一次悬浮时，如果提示框还没真正参与过布局计算，自动换行标签的高度有时会被算错。
	# 这里先把面板放到屏幕外，并给说明文字一个明确宽度，再去计算最终尺寸，就能避免首帧高度异常。
	panel.size = Vector2.ZERO
	panel.custom_minimum_size = Vector2.ZERO
	panel.global_position = Vector2(-10000, -10000)
	panel.visible = true
	vbox.size = Vector2.ZERO
	desc_label.size = Vector2(desc_min_width, 0)
	desc_label.custom_minimum_size = Vector2(desc_min_width, 0)
	return nodes

func _finalize_info_panel_layout(panel: Panel) -> void:
	var nodes := _get_info_panel_nodes(panel)
	var vbox := nodes["vbox"] as VBoxContainer
	await get_tree().process_frame
	await get_tree().process_frame
	var content_size := vbox.get_combined_minimum_size()
	var panel_size := content_size + Vector2(20, 16)
	panel.custom_minimum_size = panel_size
	panel.size = panel_size

func _connect_interactions() -> void:
	for i in range(_item_panels.size()):
		var panel := _item_panels[i]
		# 物品依然可以点击，但鼠标保持普通箭头样式，不再显示小手。
		panel.mouse_default_cursor_shape = Control.CURSOR_ARROW
		panel.gui_input.connect(_on_item_panel_gui_input.bind(i))
		panel.mouse_entered.connect(_on_item_panel_mouse_entered.bind(i))
		panel.mouse_exited.connect(_on_item_panel_mouse_exited)

	refresh_num.mouse_filter = Control.MOUSE_FILTER_STOP
	refresh_num.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	refresh_num.gui_input.connect(_on_refresh_gui_input)
	refresh_num.mouse_entered.connect(_on_refresh_mouse_entered)

	shop_level_up_button.pressed.connect(_on_shop_level_up_pressed)
	shop_level_up_button.mouse_entered.connect(_on_shop_level_up_mouse_entered)
	shop_level_up_button.mouse_exited.connect(_on_shop_level_up_mouse_exited)
	_exit_button.pressed.connect(_on_exit_button_pressed)

func _ensure_icon_node(panel: Panel) -> TextureRect:
	var icon_node := panel.get_node_or_null("Icon") as TextureRect
	if icon_node == null:
		icon_node = TextureRect.new()
		icon_node.name = "Icon"
		icon_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_node.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_node.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_node.offset_left = 6
		icon_node.offset_top = 6
		icon_node.offset_right = -6
		icon_node.offset_bottom = -6
		panel.add_child(icon_node)
	return icon_node

func _ensure_shop_state() -> void:
	Global.shop_level = clampi(Global.shop_level, 1, SHOP_LEVEL_CAP)
	Global.shop_battle_refresh_count = clampi(Global.shop_battle_refresh_count, 0, Global.refresh_max_num)
	Global.shop_lingshi_unit_price = max(Global.shop_lingshi_unit_price, 50)

func _load_shop_items_from_save() -> void:
	_shop_items.clear()
	if typeof(Global.shop_saved_items) != TYPE_ARRAY:
		return
	for offer_data in Global.shop_saved_items:
		if typeof(offer_data) == TYPE_DICTIONARY:
			_shop_items.append((offer_data as Dictionary).duplicate(true))

func _save_shop_items_to_save() -> void:
	Global.shop_saved_items = _shop_items.duplicate(true)

func _build_common_material_pool() -> void:
	var unique_ids := {}
	for method_name in BASIC_MONSTER_DROP_METHODS:
		if not _setting_monster.has_method(method_name):
			continue
		var drop_data = _setting_monster.call(method_name, "itemdrop")
		if typeof(drop_data) != TYPE_DICTIONARY:
			continue
		for item_id in drop_data.keys():
			if _is_common_material_item(item_id):
				unique_ids[item_id] = true
	_common_material_pool.clear()
	for item_id in unique_ids.keys():
		_common_material_pool.append(item_id)
	_common_material_pool.sort()
	if _common_material_pool.is_empty():
		_common_material_pool = ["item_002", "item_003", "item_011", "item_044", "item_045", "item_046"]

func _is_common_material_item(item_id: String) -> bool:
	var item_data = ItemManager.get_item_all_data(item_id)
	if item_data.is_empty():
		return false
	return str(item_data.get("item_type", "")) == "material" and str(item_data.get("item_rare", "")) == "common"

func _generate_shop_items() -> void:
	_shop_items.clear()
	for _i in range(_item_panels.size()):
		_shop_items.append(_generate_single_offer())

func _generate_single_offer() -> Dictionary:
	var rarity := _roll_weighted_key(_get_rarity_weights(Global.shop_level), RARITY_ORDER)
	var table: Array = OFFER_TABLES.get(rarity, OFFER_TABLES["white"])
	var kind := _roll_weighted_offer_kind(table)
	return _build_offer_by_kind(rarity, kind)

func _get_rarity_weights(level: int) -> Dictionary:
	var diff: int = max(level - 1, 0)
	return {
		"white": max(0, 70 - diff * 10),
		"blue": 25 + diff * 4,
		"purple": 5 + diff * 3,
		"gold": diff * 2,
		"red": diff
	}

func _roll_weighted_key(weights: Dictionary, order: Array) -> String:
	var total := 0.0
	for key in order:
		total += float(weights.get(key, 0))
	if total <= 0.0:
		return str(order[0])
	var roll := randf() * total
	var cursor := 0.0
	for key in order:
		cursor += float(weights.get(key, 0))
		if roll <= cursor:
			return str(key)
	return str(order[order.size() - 1])

func _roll_weighted_offer_kind(table: Array) -> String:
	var total := 0
	for entry in table:
		total += int(entry.get("weight", 0))
	if total <= 0:
		return "lingshi"
	var roll := randi_range(1, total)
	var cursor := 0
	for entry in table:
		cursor += int(entry.get("weight", 0))
		if roll <= cursor:
			return str(entry.get("kind", "lingshi"))
	return str(table[0].get("kind", "lingshi"))

func _build_offer_by_kind(rarity: String, kind: String) -> Dictionary:
	match kind:
		"lingshi":
			return _build_lingshi_offer(rarity)
		"common_material":
			var quantity_map = {"white": 10, "blue": 15, "purple": 20, "gold": 25}
			var unit_price_map = {"white": 0.5, "blue": 0.4, "purple": 0.4, "gold": 0.4}
			return _build_item_offer(rarity, _pick_random(_common_material_pool), quantity_map.get(rarity, 10), unit_price_map.get(rarity, 0.5))
		"tier1_pill":
			return _build_item_offer(rarity, _pick_random(TIER1_PILLS), 1, 10)
		"tier2_pill":
			return _build_item_offer(rarity, _pick_random(TIER2_PILLS), 1, 20)
		"tier3_pill":
			return _build_item_offer(rarity, _pick_random(TIER3_PILLS), 1, 40)
		"tier4_pill":
			return _build_item_offer(rarity, _pick_random(TIER4_PILLS), 1, 80)
		"tier5_pill":
			return _build_item_offer(rarity, _pick_random(TIER5_PILLS), 1, 160)
		"basic_element":
			var quantity_map = {"white": 1, "blue": 2}
			var unit_price_map = {"white": 5, "blue": 4}
			return _build_item_offer(rarity, _pick_random(BASIC_ELEMENT_IDS), quantity_map.get(rarity, 1), unit_price_map.get(rarity, 5))
		"lower_special":
			var quantity_map = {"white": 2, "blue": 3}
			var unit_price_map = {"white": 30, "blue": 25}
			return _build_item_offer(rarity, _pick_random(LOWER_SPECIAL_PILLS), quantity_map.get(rarity, 2), unit_price_map.get(rarity, 30))
		"middle_special":
			var quantity_map = {"purple": 1, "gold": 2}
			var unit_price_map = {"purple": 60, "gold": 50}
			return _build_item_offer(rarity, _pick_random(MIDDLE_SPECIAL_PILLS), quantity_map.get(rarity, 1), unit_price_map.get(rarity, 60))
		"upper_special":
			return _build_item_offer(rarity, _pick_random(UPPER_SPECIAL_PILLS), 1, 120)
		"ether":
			var quantity_map = {"purple": 1, "gold": 2}
			return _build_item_offer(rarity, _pick_random(ETHER_IDS), quantity_map.get(rarity, 1), 15)
		"boss_material":
			var quantity_map = {"white": 1, "blue": 1, "purple": 2, "gold": 2, "red": 3}
			var unit_price_map = {"white": 80, "blue": 60, "purple": 60, "gold": 50, "red": 40}
			return _build_item_offer(rarity, _pick_random(BOSS_MATERIAL_IDS), quantity_map.get(rarity, 1), unit_price_map.get(rarity, 80))
		_:
			return _build_lingshi_offer(rarity)

func _build_lingshi_offer(rarity: String) -> Dictionary:
	var quantity := int(LINGSHI_PACK_QUANTITY.get(rarity, 10))
	return {
		"rarity": rarity,
		"product_type": "lingshi_pack",
		"item_id": Global.LINGSHI_ITEM_ID,
		"quantity": quantity,
		"cost_resource": "point",
		"cost": quantity * Global.shop_lingshi_unit_price,
		"sold": false
	}

func _build_item_offer(rarity: String, item_id: String, quantity: int, unit_price: float) -> Dictionary:
	return {
		"rarity": rarity,
		"product_type": "inventory_item",
		"item_id": item_id,
		"quantity": quantity,
		"unit_price": unit_price,
		"cost_resource": "lingshi",
		"cost": int(round(quantity * unit_price)),
		"sold": false
	}

func _pick_random(list_data: Array) -> String:
	if list_data.is_empty():
		return ""
	return str(list_data[randi() % list_data.size()])

func _sync_dynamic_offer_data() -> void:
	for i in range(_shop_items.size()):
		var offer = _shop_items[i]
		if offer.get("product_type", "") == "lingshi_pack":
			offer["cost"] = int(offer.get("quantity", 0)) * Global.shop_lingshi_unit_price
			_shop_items[i] = offer

func _refresh_display() -> void:
	_ensure_shop_state()
	_sync_dynamic_offer_data()
	_update_shop_header()
	_update_refresh_label()
	for i in range(_item_panels.size()):
		var panel := _item_panels[i]
		var detail_label := _detail_labels[i]
		var price_label := _price_labels[i]
		var icon_node := _icon_nodes[i]
		if i >= _shop_items.size():
			detail_label.text = "未上架"
			price_label.text = ""
			icon_node.texture = null
			continue
		var offer := _shop_items[i]
		var rarity := str(offer.get("rarity", "white"))
		var color: Color = RARITY_COLORS.get(rarity, Color.WHITE)
		detail_label.modulate = color
		price_label.modulate = color
		panel.modulate = Color(1, 1, 1, 1)
		icon_node.modulate = Color(1, 1, 1, 1)
		if bool(offer.get("sold", false)):
			detail_label.text = "已售罄"
			price_label.text = ""
			icon_node.texture = load(str(ItemManager.get_item_property(str(offer.get("item_id", "")), "item_icon"))) if ItemManager.get_item_property(str(offer.get("item_id", "")), "item_icon") != null else null
			icon_node.modulate = Color(0.35, 0.35, 0.35, 0.8)
			panel.modulate = Color(0.75, 0.75, 0.75, 1)
			continue
		var item_id := str(offer.get("item_id", ""))
		var item_name := str(ItemManager.get_item_property(item_id, "item_name"))
		var item_icon = ItemManager.get_item_property(item_id, "item_icon")
		icon_node.texture = load(str(item_icon)) if item_icon != null else null
		detail_label.text = item_name + " ×" + str(offer.get("quantity", 0))
		price_label.text = _format_offer_price(offer)

func _update_shop_header() -> void:
	_shop_level_label.text = _build_shop_header_text()
	if Global.shop_level >= SHOP_LEVEL_CAP:
		shop_level_up_button.text = "货摊升级\n已满级"
		shop_level_up_button.disabled = true
		return
	shop_level_up_button.disabled = false
	var next_level: int = Global.shop_level + 1
	var costs: Array = SHOP_UPGRADE_COSTS.get(Global.shop_level, [])
	if costs.is_empty():
		shop_level_up_button.text = "货摊升级\n暂未开放"
	else:
		shop_level_up_button.text = "货摊升级\nLv.%d → Lv.%d" % [Global.shop_level, next_level]

func _update_refresh_label() -> void:
	var battle_refresh := Global.shop_battle_refresh_count
	var shipping_refresh := Global.get_item_count("item_059")
	refresh_num.text = "刷新（%d）" % (battle_refresh + shipping_refresh)

func _build_shop_header_text() -> String:
	return "[font_size=%d]货摊级别：%d[/font_size]\n\n%s" % [SHOP_HEADER_FONT_SIZE, Global.shop_level, _format_probability_text(Global.shop_level)]

func _format_probability_text(level: int) -> String:
	var weights := _get_rarity_weights(level)
	var parts: Array[String] = []
	for key in RARITY_ORDER:
		parts.append("%s：%d%%" % [SHOP_RARITY_DISPLAY_NAMES.get(key, str(key)), int(weights.get(key, 0))])
	return "\n".join(parts)

func _build_upgrade_info_text() -> String:
	if Global.shop_level >= SHOP_LEVEL_CAP:
		return "当前货摊已开放全部品级概率。\n\n" + _format_probability_text(Global.shop_level)
	var next_level := Global.shop_level + 1
	var costs: Array = SHOP_UPGRADE_COSTS.get(Global.shop_level, [])
	if costs.is_empty():
		return "当前仅开放到 Lv.5。\n\n提升后概率：\n" + _format_probability_text(next_level)
	return "提升后概率：\n" + _format_probability_text(next_level)

func _format_costs(costs: Array) -> String:
	var parts: Array[String] = []
	for cost in costs:
		var item_id := str(cost.get("item_id", ""))
		var item_name := str(ItemManager.get_item_property(item_id, "item_name"))
		parts.append(item_name + "×" + str(cost.get("count", 0)))
	return "、".join(parts)

func _format_offer_price(offer: Dictionary) -> String:
	var cost := int(offer.get("cost", 0))
	if str(offer.get("cost_resource", "lingshi")) == "point":
		return str(cost) + " 真气"
	return str(cost) + " 灵石"

func _get_item_type_display_name(item_id: String) -> String:
	var item_type := str(ItemManager.get_item_property(item_id, "item_type"))
	match item_type:
		"consumable":
			return "[消耗品]"
		"material":
			return "[材料]"
		"special":
			return "[特殊]"
		"equip":
			return "[装备]"
		"immediate":
			return "[即时]"
		_:
			return "[货物]"

func _get_rare_color(rare: String) -> Color:
	match rare:
		"common":
			return Color(1.0, 1.0, 1.0)
		"rare":
			return Color(0.2, 0.5, 1.0)
		"epic":
			return Color(0.7, 0.3, 0.9)
		"legendary":
			return Color(1.0, 0.8, 0.0)
		"artifact":
			return Color(1.0, 0.2, 0.2)
		_:
			return Color(1.0, 1.0, 1.0)

func _build_offer_detail_text(offer: Dictionary) -> String:
	var item_id := str(offer.get("item_id", ""))
	var quantity := int(offer.get("quantity", 0))
	var item_detail := str(ItemManager.get_item_property(item_id, "item_detail"))
	var item_source := str(ItemManager.get_item_property(item_id, "item_source"))
	var detail_lines: Array[String] = ["数量：%d" % quantity]
	if not item_detail.is_empty():
		detail_lines.append(item_detail)
	var detail_text := "\n".join(detail_lines)
	if not item_source.is_empty():
		detail_text += "\n\n[来源] " + item_source
	if str(offer.get("product_type", "")) == "lingshi_pack":
		detail_text += "\n\n当前灵石单价：%d 真气/个\n每买 10 个灵石，下次单价 +1。" % Global.shop_lingshi_unit_price
	return detail_text

func _show_offer_tooltip(index: int) -> void:
	if index < 0 or index >= _shop_items.size():
		_hide_offer_tooltip()
		return
	var offer := _shop_items[index]
	var item_id := str(offer.get("item_id", ""))
	var item_name := str(ItemManager.get_item_property(item_id, "item_name"))
	var item_icon := str(ItemManager.get_item_property(item_id, "item_icon"))
	var nodes := _reset_info_panel_layout(_offer_tooltip_panel, 240.0)
	var icon := nodes["icon"] as TextureRect
	var name_label := nodes["name_label"] as Label
	var type_label := nodes["type_label"] as Label
	var desc_label := nodes["desc_label"] as Label
	var price_label := nodes["price_label"] as Label
	var hint_label := nodes["hint_label"] as Label
	icon.visible = true
	icon.modulate = Color(1, 1, 1, 1)
	icon.texture = load(item_icon) if not item_icon.is_empty() and ResourceLoader.exists(item_icon) else null
	if bool(offer.get("sold", false)):
		name_label.text = "  " + item_name
		name_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		type_label.text = "[已售罄]"
		desc_label.text = "该商品已被买走，等待下次刷新。"
		price_label.text = "售价: --"
		hint_label.visible = false
	else:
		var rarity := str(offer.get("rarity", "white"))
		var item_rare := str(ItemManager.get_item_property(item_id, "item_rare"))
		name_label.text = "  " + item_name
		name_label.add_theme_color_override("font_color", _get_rare_color(item_rare))
		type_label.text = "【%s】 %s" % [SHOP_RARITY_DISPLAY_NAMES.get(rarity, rarity), _get_item_type_display_name(item_id)]
		desc_label.text = _build_offer_detail_text(offer)
		price_label.text = "售价: " + _format_offer_price(offer)
		hint_label.text = "\n点击购买商品"
		hint_label.visible = true
	await _finalize_info_panel_layout(_offer_tooltip_panel)
	var hovered_panel := _item_panels[index]
	var tooltip_pos := hovered_panel.global_position + Vector2(hovered_panel.size.x + 10, 0)
	var viewport_size := get_viewport().get_visible_rect().size
	if tooltip_pos.x + _offer_tooltip_panel.size.x > viewport_size.x:
		tooltip_pos.x = hovered_panel.global_position.x - _offer_tooltip_panel.size.x - 10
	if tooltip_pos.y + _offer_tooltip_panel.size.y > viewport_size.y:
		tooltip_pos.y = viewport_size.y - _offer_tooltip_panel.size.y - 10
	_offer_tooltip_panel.global_position = tooltip_pos
	_offer_tooltip_panel.visible = true

func _hide_offer_tooltip() -> void:
	if _offer_tooltip_panel != null:
		_offer_tooltip_panel.visible = false

func _show_upgrade_info() -> void:
	var nodes := _reset_info_panel_layout(_upgrade_info_panel, 260.0)
	var icon := nodes["icon"] as TextureRect
	var name_label := nodes["name_label"] as Label
	var type_label := nodes["type_label"] as Label
	var desc_label := nodes["desc_label"] as Label
	var price_label := nodes["price_label"] as Label
	var hint_label := nodes["hint_label"] as Label
	icon.visible = false
	icon.texture = null
	name_label.text = "货摊升级"
	name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	if Global.shop_level >= SHOP_LEVEL_CAP:
		type_label.text = "当前等级：Lv.%d" % Global.shop_level
		desc_label.text = _build_upgrade_info_text()
		price_label.text = "状态: 已达最高级"
		hint_label.visible = false
	else:
		var next_level := Global.shop_level + 1
		var costs: Array = SHOP_UPGRADE_COSTS.get(Global.shop_level, [])
		type_label.text = "Lv.%d → Lv.%d" % [Global.shop_level, next_level]
		desc_label.text = _build_upgrade_info_text()
		if costs.is_empty():
			price_label.text = "状态: 暂未开放"
			hint_label.visible = false
		else:
			price_label.text = "材料: " + _format_costs(costs)
			hint_label.text = "\n点击升级货摊"
			hint_label.visible = true
	await _finalize_info_panel_layout(_upgrade_info_panel)
	var panel_pos := shop_level_up_button.global_position + Vector2(shop_level_up_button.size.x - _upgrade_info_panel.size.x, shop_level_up_button.size.y + 10)
	var viewport_size := get_viewport().get_visible_rect().size
	if panel_pos.x < 10:
		panel_pos.x = 10
	elif panel_pos.x + _upgrade_info_panel.size.x > viewport_size.x:
		panel_pos.x = viewport_size.x - _upgrade_info_panel.size.x - 10
	if panel_pos.y + _upgrade_info_panel.size.y > viewport_size.y:
		panel_pos.y = shop_level_up_button.global_position.y - _upgrade_info_panel.size.y - 10
	panel_pos.y = max(panel_pos.y, 10.0)
	_upgrade_info_panel.global_position = panel_pos
	_upgrade_info_panel.visible = true

func _hide_upgrade_info() -> void:
	if _upgrade_info_panel != null:
		_upgrade_info_panel.visible = false

func _on_item_panel_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_try_buy_offer(index)

func _on_item_panel_mouse_entered(index: int) -> void:
	_show_offer_tooltip(index)

func _on_item_panel_mouse_exited() -> void:
	_hide_offer_tooltip()

func _try_buy_offer(index: int) -> void:
	if index < 0 or index >= _shop_items.size():
		return
	var offer := _shop_items[index]
	if bool(offer.get("sold", false)):
		_show_tips("这个商品已经卖空了。", 0.5)
		return
	if str(offer.get("product_type", "")) == "lingshi_pack":
		offer["cost"] = int(offer.get("quantity", 0)) * Global.shop_lingshi_unit_price
		_shop_items[index] = offer
	var cost := int(offer.get("cost", 0))
	var item_id := str(offer.get("item_id", ""))
	var quantity := int(offer.get("quantity", 0))
	if str(offer.get("cost_resource", "")) == "point":
		if Global.total_points < cost:
			_show_tips("真气不足，需要 %d 真气，当前只有 %d。" % [cost, Global.total_points], 0.5)
			return
		Global.total_points -= cost
	else:
		if not Global.consume_item_count(Global.LINGSHI_ITEM_ID, cost):
			_show_tips("灵石不足，需要 %d 灵石。" % cost, 0.5)
			return
	Global.add_item_count(item_id, quantity)
	offer["sold"] = true
	_shop_items[index] = offer
	if str(offer.get("product_type", "")) == "lingshi_pack":
		Global.shop_lingshi_unit_price += int(quantity / 10.0)
	_refresh_display()
	_save_shop_items_to_save()
	_refresh_external_ui()
	_hide_offer_tooltip()
	Global.save_game()
	_show_tips("购入 %s ×%d，花费 %s。" % [str(ItemManager.get_item_property(item_id, "item_name")), quantity, _format_offer_price(offer)], 0.6)

func _on_refresh_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_try_refresh_shop()

func _on_refresh_mouse_entered() -> void:
	_show_tips("刷新货摊\n通关累计：%d\n进货单：%d\n优先消耗通关次数。" % [Global.shop_battle_refresh_count, Global.get_item_count("item_059")], 0.8)

func _try_refresh_shop() -> void:
	var battle_refresh := Global.shop_battle_refresh_count
	var shipping_refresh := Global.get_item_count("item_059")
	if battle_refresh + shipping_refresh <= 0:
		_show_tips("刷新次数不足，通关或准备进货单后再来。", 0.5)
		return
	var consume_message := ""
	if battle_refresh > 0:
		Global.shop_battle_refresh_count -= 1
		consume_message = "消耗了 1 次通关刷新。"
	else:
		Global.consume_item_count("item_059", 1)
		consume_message = "消耗了 1 张进货单。"
	_generate_shop_items()
	_refresh_display()
	_save_shop_items_to_save()
	_refresh_external_ui()
	_hide_offer_tooltip()
	Global.save_game()
	_show_tips("货摊已刷新。" + consume_message, 0.6)

func _on_shop_level_up_mouse_entered() -> void:
	_show_upgrade_info()

func _on_shop_level_up_mouse_exited() -> void:
	_hide_upgrade_info()

func _on_shop_level_up_pressed() -> void:
	_hide_upgrade_info()
	if Global.shop_level >= SHOP_LEVEL_CAP:
		_show_tips("货摊已经达到最高等级。", 0.5)
		return
	var costs: Array = SHOP_UPGRADE_COSTS.get(Global.shop_level, [])
	if costs.is_empty():
		_show_tips("后续货摊等级暂未开放。", 0.5)
		return
	var lack_parts: Array[String] = []
	for cost in costs:
		var item_id := str(cost.get("item_id", ""))
		var need := int(cost.get("count", 0))
		var own := Global.get_item_count(item_id)
		if own < need:
			lack_parts.append(str(ItemManager.get_item_property(item_id, "item_name")) + "缺少" + str(need - own))
	if not lack_parts.is_empty():
		_show_tips("升级材料不足：" + "、".join(lack_parts), 0.6)
		return
	for cost in costs:
		Global.consume_item_count(str(cost.get("item_id", "")), int(cost.get("count", 0)))
	Global.shop_level += 1
	Global.shop_level = clampi(Global.shop_level, 1, SHOP_LEVEL_CAP)
	_refresh_display()
	_refresh_external_ui()
	Global.save_game()
	_show_tips("货摊升级成功！当前等级：Lv.%d" % Global.shop_level, 0.6)

func _recycle_obsolete_pills() -> String:
	var recycled_lines: Array[String] = []
	var total_lingshi := 0
	var inventory_keys: Array = Global.player_inventory.keys().duplicate()
	for key in inventory_keys:
		var item_id := str(key)
		var unit_price := _get_recycle_unit_price(item_id)
		if unit_price <= 0:
			continue
		var max_uses := _get_item_max_uses(item_id)
		if max_uses <= 0:
			continue
		var used := int(Global.pill_used_counts.get(item_id, 0))
		if used < max_uses:
			continue
		var count := int(Global.player_inventory.get(item_id, 0))
		if count <= 0:
			continue
		Global.player_inventory.erase(item_id)
		var gain := count * unit_price
		total_lingshi += gain
		recycled_lines.append(str(ItemManager.get_item_property(item_id, "item_name")) + "×" + str(count) + "（+" + str(gain) + "灵石）")
	if total_lingshi <= 0:
		return ""
	Global.add_item_count(Global.LINGSHI_ITEM_ID, total_lingshi)
	Global.save_game()
	return "丹药回收：\n" + "\n".join(recycled_lines) + "\n共获得 " + str(total_lingshi) + " 灵石"

func _get_item_max_uses(item_id: String) -> int:
	var cfg: Dictionary = ItemManager.pill_config.get(item_id, {})
	if cfg.is_empty():
		return 0
	if cfg.has("tier"):
		return Global.get_special_pill_max_uses(str(cfg.get("tier", "")))
	return int(cfg.get("max_uses", 0))

func _get_recycle_unit_price(item_id: String) -> int:
	if TIER1_PILLS.has(item_id):
		return 8
	if TIER2_PILLS.has(item_id):
		return 16
	if TIER3_PILLS.has(item_id):
		return 32
	if TIER4_PILLS.has(item_id):
		return 64
	if TIER5_PILLS.has(item_id):
		return 128
	if LOWER_SPECIAL_PILLS.has(item_id):
		return 24
	if MIDDLE_SPECIAL_PILLS.has(item_id):
		return 48
	if UPPER_SPECIAL_PILLS.has(item_id):
		return 96
	return 0

func _refresh_external_ui() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	if scene.has_method("refresh_point"):
		scene.refresh_point()
	var bag_layer = scene.get_node_or_null("BagLayer")
	if bag_layer != null:
		if bag_layer.has_method("refresh_bag"):
			bag_layer.refresh_bag()
		elif bag_layer.has_method("refresh_character_display"):
			bag_layer.refresh_character_display()

func _show_tips(message: String, duration: float = 0.5) -> void:
	if tips != null and tips.has_method("start_animation"):
		tips.start_animation(message, duration)

func prepare_for_close() -> void:
	# 商店关闭后，下一次重新打开时需要再次执行一次自动刷新判定。
	_need_auto_refresh_on_open = true
	_hide_offer_tooltip()
	_hide_upgrade_info()

func _on_exit_button_pressed() -> void:
	prepare_for_close()
	exit_requested.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		prepare_for_close()
		exit_requested.emit()
		get_viewport().set_input_as_handled()
