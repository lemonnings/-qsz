extends CanvasLayer

signal exit_requested

const SETTING_MONSTER_SCRIPT = preload("res://Script/config/setting_moster.gd")
const SHOP_LEVEL_CAP := 8
const SHOP_HEADER_FONT_SIZE := 39
const TOOLTIP_FONT_SIZE := 24
const RARITY_ORDER := ["white", "blue", "purple", "gold", "red"]
const RARITY_NAMES := {
	"white": "普通",
	"blue": "稀有",
	"purple": "史诗",
	"gold": "传说",
	"red": "神话"
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
const LINGSHI_PRICE_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const ZHENQI_PRICE_COLOR := Color(0.68, 0.88, 1.0, 1.0)

const SOLD_OUT_TEXT_COLOR := Color(0.72, 0.72, 0.72, 1.0)
# 你已经确认单个商品格子的判定尺寸就是 88×88。
# 这里单独提成常量，后面鼠标悬浮判定会直接用它，避免写死魔法数字。
const ITEM_HITBOX_SIZE := Vector2(88, 88)

# 每个商品格子下面都会放一个独立的像素光效控件。
# 这次把它做成“从中心往外炸开”的放射束效果，尽量接近你截图里那种光芒四射的感觉。
class QualityGlow:
	extends Control

	const PIXEL_SIZE := 4.0
	const GLOW_SCALE := 0.8

	var glow_rarity: String = ""
	var glow_alpha_scale := 1.0
	var _time := 0.0
	# 这几个数组会在品质变化时重建一次：
	# - `_ray_directions` 负责记录每一根主光束的朝向
	# - `_ray_length_factors` 负责记录每一根光束自己的长度倍率
	# - `_ray_thickness_factors` 负责记录每一根光束自己的粗细倍率
	# 这样既能做到“看起来有点随机”，又不会每一帧抖动。
	var _ray_directions: Array[Vector2] = []
	var _ray_length_factors: Array[float] = []
	var _ray_thickness_factors: Array[float] = []



	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		# 放射束会比原来长很多，所以要把绘制区域放大，避免边缘被裁掉。
		offset_left = -96
		offset_top = -96
		offset_right = 96
		offset_bottom = 96
		clip_contents = false
		if not glow_rarity.is_empty():
			_rebuild_ray_layout()
		queue_redraw()

	func set_glow_rarity(new_rarity: String) -> void:
		glow_rarity = new_rarity
		visible = not glow_rarity.is_empty()
		_rebuild_ray_layout()
		queue_redraw()


	func set_glow_alpha_scale(new_alpha_scale: float) -> void:
		glow_alpha_scale = clampf(new_alpha_scale, 0.0, 1.0)
		queue_redraw()

	func _process(delta: float) -> void:
		_time += delta
		if not glow_rarity.is_empty():
			queue_redraw()

	func _draw() -> void:
		if glow_rarity.is_empty():
			return
		if _ray_directions.is_empty():
			_rebuild_ray_layout()
		var style := _get_glow_style(glow_rarity)
		# 所有品质统一带一个“呼吸”节奏：
		# - 尺寸在 0.9 ~ 1.0 之间变化
		# - 透明度在 0.5 ~ 1.0 之间变化
		var breath_progress: float = (sin(_time * 2.4) + 1.0) * 0.5
		var size_scale: float = lerpf(0.9, 1.0, breath_progress)
		var pulse: float = lerpf(0.5, 1.0, breath_progress)
		var visual_scale: float = size_scale * GLOW_SCALE

		var rotation := 0.0
		if glow_rarity == "gold":
			# 金色保留更亮的闪烁感，但基础呼吸仍然存在。
			pulse *= clampf(0.96 + sin(_time * 7.6) * 0.14 + sin(_time * 13.8) * 0.06, 0.76, 1.18)
		elif glow_rarity == "red":
			# 红色保留慢速旋转，再叠一层更张扬的闪烁。
			pulse *= clampf(0.94 + sin(_time * 4.2) * 0.16 + sin(_time * 8.4) * 0.05, 0.74, 1.2)
			rotation = _time * 0.36
		var center := size * 0.5
		_draw_center_bloom(center, style, pulse, visual_scale)
		# 这里两层都沿用同一组方向：
		# - 主层负责“炸开”的大光束
		# - 次层只是同方向的短一点、淡一点的补光
		# 这样视觉上仍然是 4/5/6 根主射线，不会变成一圈过度规整的小刺。
		_draw_ray_group(center, style["ray_color"], float(style.get("main_length", 80.0)) * visual_scale, float(style.get("main_width", 14.0)) * visual_scale, float(style.get("main_alpha", 0.25)) * pulse, rotation, 7, 1.0)
		_draw_ray_group(center, style["ray_color"], float(style.get("sub_length", 58.0)) * visual_scale, float(style.get("sub_width", 8.0)) * visual_scale, float(style.get("sub_alpha", 0.16)) * pulse, rotation, 5, 0.82)
		_draw_tip_sparks(center, style, rotation, visual_scale, pulse)




	func _draw_center_bloom(center: Vector2, style: Dictionary, pulse: float, size_scale: float) -> void:
		var core_color: Color = style["core_color"]
		var bloom_color: Color = style["bloom_color"]
		var core_alpha := float(style.get("core_alpha", 0.3)) * pulse * glow_alpha_scale
		var bloom_alpha := float(style.get("bloom_alpha", 0.18)) * pulse * glow_alpha_scale
		var bloom_size := float(style.get("bloom_size", 44.0)) * size_scale
		var core_size := float(style.get("core_size", 20.0)) * size_scale
		_draw_center_square(center, bloom_size, bloom_color, bloom_alpha)
		_draw_center_square(center, bloom_size * 0.68, core_color, core_alpha * 0.92)
		_draw_center_square(center, core_size, Color(1, 1, 1, 1), core_alpha)


	func _draw_center_square(center: Vector2, side_length: float, base_color: Color, alpha_scale: float) -> void:
		var color := base_color
		color.a *= alpha_scale
		if color.a <= 0.01:
			return
		var side: float = float(max(_snap_scalar(side_length), PIXEL_SIZE))
		var top_left := _snap_to_pixel(center - Vector2.ONE * side * 0.5)

		draw_rect(Rect2(top_left, Vector2.ONE * side), color)

	func _draw_ray_group(center: Vector2, base_color: Color, beam_length: float, beam_width: float, beam_alpha: float, rotation: float, segment_count: int, group_length_scale: float) -> void:
		for ray_index in range(_ray_directions.size()):
			var direction: Vector2 = _ray_directions[ray_index]
			var base_length_factor: float = _get_ray_length_factor(ray_index)
			var ray_length_factor: float = base_length_factor * group_length_scale
			var ray_thickness_factor: float = _get_ray_thickness_factor(ray_index)
			var varied_beam_length: float = beam_length * ray_length_factor
			# 基础粗细先整体缩到原来的 75%，
			# 再乘上每根光束自己的粗细倍率。
			var scaled_beam_width: float = beam_width * 0.75 * ray_thickness_factor
			var tail_length_factor: float = float(max(0.82, ray_length_factor * 0.92))
			for segment in range(segment_count):
				var t: float = float(segment) / float(max(float(segment_count - 1), 1.0))
				var distance := lerpf(PIXEL_SIZE * 2.0, varied_beam_length, t)
				var length := lerpf(beam_width * 5.6 * ray_length_factor, beam_width * 1.3 * tail_length_factor, t)
				var thickness := lerpf(scaled_beam_width, float(max(PIXEL_SIZE, scaled_beam_width * 0.38)), t)
				var alpha_scale := beam_alpha * pow(1.0 - t, 0.45)
				_draw_ray_segment(center, direction, distance, length, thickness, base_color, alpha_scale, rotation)

	func _draw_tip_sparks(center: Vector2, style: Dictionary, rotation: float, visual_scale: float, pulse: float) -> void:
		# 在每根主光束的末端再补一个小亮点，
		# 让光效看起来更像“炸开”的感觉。
		var spark_color: Color = style.get("spark_color", Color(1.0, 1.0, 1.0, 1.0))
		var spark_alpha: float = float(style.get("spark_alpha", 0.08)) * pulse * glow_alpha_scale
		if spark_alpha <= 0.01:
			return
		var spark_distance: float = float(style.get("spark_length", 70.0)) * visual_scale
		var spark_size: float = float(style.get("spark_size", 6.0)) * visual_scale
		for ray_index in range(_ray_directions.size()):
			var direction := _ray_directions[ray_index].normalized().rotated(rotation)
			var distance := spark_distance * _get_ray_length_factor(ray_index)
			var spark_center := _snap_to_pixel(center + direction * distance)
			_draw_center_square(spark_center, spark_size, spark_color, spark_alpha)

	func _draw_ray_segment(center: Vector2, direction: Vector2, distance: float, length: float, thickness: float, base_color: Color, alpha_scale: float, rotation: float) -> void:


		var color := base_color
		color.a *= alpha_scale * glow_alpha_scale
		if color.a <= 0.01:
			return
		var dir := direction.normalized().rotated(rotation)
		var perp := Vector2(-dir.y, dir.x)
		var ray_center := _snap_to_pixel(center + dir * distance)
		var half_length: Vector2 = dir * float(max(_snap_scalar(length) * 0.5, PIXEL_SIZE * 0.5))
		var half_thickness: Vector2 = perp * float(max(_snap_scalar(thickness) * 0.5, PIXEL_SIZE * 0.5))

		var points := PackedVector2Array([
			_snap_to_pixel(ray_center - half_length - half_thickness),
			_snap_to_pixel(ray_center - half_length + half_thickness),
			_snap_to_pixel(ray_center + half_length + half_thickness),
			_snap_to_pixel(ray_center + half_length - half_thickness)
		])
		draw_colored_polygon(points, color)




	func _rebuild_ray_layout() -> void:
		_ray_directions.clear()
		_ray_length_factors.clear()
		_ray_thickness_factors.clear()
		if glow_rarity.is_empty():
			return
		var ray_count: int = _get_rarity_ray_count(glow_rarity)
		var rng := RandomNumberGenerator.new()
		rng.seed = _get_layout_seed(glow_rarity)
		# 最小夹角仍然保持大于 30 度，
		# 但把基础随机离散度再拉大一点，让整圈看起来更不规整。
		var angle_list: Array[float] = _build_irregular_ray_angles(ray_count, 32.0, rng)

		for angle_deg in angle_list:
			_ray_directions.append(Vector2.RIGHT.rotated(deg_to_rad(angle_deg)))
		_ray_length_factors = _build_ray_length_factors(ray_count, rng)
		# 粗细倍率直接根据长度倍率计算，不需要再额外传随机数。
		_ray_thickness_factors = _build_ray_thickness_factors(_ray_length_factors)


	func _get_rarity_ray_count(rarity: String) -> int:
		match rarity:
			"white":
				return 4
			"blue":
				return 5
			"red":
				return 7
			_:
				return 6

	func _get_layout_seed(rarity: String) -> int:
		var base_seed: int = int(get_instance_id()) * 131
		match rarity:
			"white":
				return base_seed + 17
			"blue":
				return base_seed + 29
			"purple":
				return base_seed + 43
			"gold":
				return base_seed + 59
			"red":
				return base_seed + 71
			_:
				return base_seed + 11

	func _build_irregular_ray_angles(ray_count: int, min_gap_deg: float, rng: RandomNumberGenerator) -> Array[float]:
		var weights: Array[float] = []
		var weight_total := 0.0
		var extra_total: float = 360.0 - min_gap_deg * float(ray_count)
		for _index in range(ray_count):
			# 权重越大，分到的夹角就越大。
			# 这次把范围再放宽一些，让角度差异更明显，
			# 视觉上就不会那么“像均匀平分出来的”。
			var weight: float = rng.randf_range(0.18, 2.35)

			weights.append(weight)
			weight_total += weight
		var current_angle: float = rng.randf_range(-180.0, 180.0)
		var angles: Array[float] = []
		for index in range(ray_count):
			angles.append(current_angle)
			current_angle += min_gap_deg + extra_total * (weights[index] / weight_total)
		return angles

	func _build_ray_length_factors(ray_count: int, rng: RandomNumberGenerator) -> Array[float]:
		var factors: Array[float] = []
		for _index in range(ray_count):
			# 每根光束给一个自己的长度倍率，避免整圈看起来像复制粘贴。
			factors.append(rng.randf_range(0.62, 1.08))
		return factors

	func _build_ray_thickness_factors(length_factors: Array[float]) -> Array[float]:
		var factors: Array[float] = []
		for length_factor in length_factors:
			# 粗细现在完全跟着长度走：
			# - 最长的保持当前粗细不变（倍率 1.0）
			# - 最短的缩到当前的一半（倍率 0.5）
			# 这样“长度变短，粗细也同步变细”的关系会更明显。
			var length_ratio: float = inverse_lerp(0.62, 1.08, float(length_factor))
			var thickness_factor: float = lerpf(0.5, 1.0, length_ratio)
			factors.append(thickness_factor)
		return factors

	func _get_ray_length_factor(ray_index: int) -> float:
		if _ray_length_factors.is_empty():
			return 1.0
		return float(_ray_length_factors[ray_index % _ray_length_factors.size()])

	func _get_ray_thickness_factor(ray_index: int) -> float:
		if _ray_thickness_factors.is_empty():
			return 1.0
		return float(_ray_thickness_factors[ray_index % _ray_thickness_factors.size()])

	func _snap_scalar(value: float) -> float:
		return round(value / PIXEL_SIZE) * PIXEL_SIZE

	func _snap_to_pixel(value: Vector2) -> Vector2:
		return Vector2(_snap_scalar(value.x), _snap_scalar(value.y))

	func _get_glow_style(rarity: String) -> Dictionary:
		match rarity:
			"white":
				return {
					"core_color": Color(1.0, 1.0, 1.0, 1.0),
					"bloom_color": Color(0.95, 0.97, 1.0, 1.0),
					"ray_color": Color(0.96, 0.98, 1.0, 1.0),
					"spark_color": Color(1.0, 1.0, 1.0, 1.0),
					"core_alpha": 0.24,
					"bloom_alpha": 0.12,
					"main_alpha": 0.1,
					"sub_alpha": 0.05,
					"spark_alpha": 0.06,
					"bloom_size": 34.0,
					"core_size": 16.0,
					"main_length": 58.0,
					"sub_length": 42.0,
					"main_width": 10.0,
					"sub_width": 6.0,
					"spark_length": 62.0,
					"spark_size": 6.0
				}
			"blue":
				return {
					"core_color": Color(0.78, 0.92, 1.0, 1.0),
					"bloom_color": Color(0.55, 0.8, 1.0, 1.0),
					"ray_color": Color(0.48, 0.78, 1.0, 1.0),
					"spark_color": Color(0.9, 0.96, 1.0, 1.0),
					"core_alpha": 0.32,
					"bloom_alpha": 0.18,
					"main_alpha": 0.18,
					"sub_alpha": 0.1,
					"spark_alpha": 0.1,
					"bloom_size": 42.0,
					"core_size": 18.0,
					"main_length": 74.0,
					"sub_length": 54.0,
					"main_width": 12.0,
					"sub_width": 7.0,
					"spark_length": 78.0,
					"spark_size": 7.0
				}
			"purple":
				return {
					"core_color": Color(0.96, 0.84, 1.0, 1.0),
					"bloom_color": Color(0.84, 0.58, 1.0, 1.0),
					"ray_color": Color(0.74, 0.42, 1.0, 1.0),
					"spark_color": Color(0.98, 0.9, 1.0, 1.0),
					"core_alpha": 0.38,
					"bloom_alpha": 0.22,
					"main_alpha": 0.24,
					"sub_alpha": 0.14,
					"spark_alpha": 0.12,
					"bloom_size": 48.0,
					"core_size": 20.0,
					"main_length": 86.0,
					"sub_length": 64.0,
					"main_width": 14.0,
					"sub_width": 8.0,
					"spark_length": 90.0,
					"spark_size": 8.0
				}
			"gold":
				return {
					"core_color": Color(1.0, 0.96, 0.72, 1.0),
					"bloom_color": Color(1.0, 0.88, 0.42, 1.0),
					"ray_color": Color(1.0, 0.8, 0.2, 1.0),
					"spark_color": Color(1.0, 0.98, 0.82, 1.0),
					"core_alpha": 0.46,
					"bloom_alpha": 0.28,
					"main_alpha": 0.34,
					"sub_alpha": 0.2,
					"spark_alpha": 0.18,
					"bloom_size": 56.0,
					"core_size": 22.0,
					"main_length": 102.0,
					"sub_length": 74.0,
					"main_width": 16.0,
					"sub_width": 10.0,
					"spark_length": 108.0,
					"spark_size": 9.0
				}
			"red":
				return {
					"core_color": Color(1.0, 0.84, 0.84, 1.0),
					"bloom_color": Color(1.0, 0.52, 0.52, 1.0),
					"ray_color": Color(1.0, 0.24, 0.24, 1.0),
					"spark_color": Color(1.0, 0.9, 0.9, 1.0),
					"core_alpha": 0.52,
					"bloom_alpha": 0.32,
					"main_alpha": 0.4,
					"sub_alpha": 0.24,
					"spark_alpha": 0.2,
					"bloom_size": 60.0,
					"core_size": 24.0,
					"main_length": 112.0,
					"sub_length": 82.0,
					"main_width": 18.0,
					"sub_width": 10.0,
					"spark_length": 118.0,
					"spark_size": 10.0
				}
			_:
				return _get_glow_style("white")



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

@export var now_ls: RichTextLabel
@export var refresh_num: RichTextLabel
@export var shop_level_up_button: Button

@export var recycle_button: Button

@export var tips: Panel

var _now_ls_label: RichTextLabel


var _item_panels: Array[Panel] = []
var _detail_labels: Array[RichTextLabel] = []
var _name_labels: Array[RichTextLabel] = []
var _price_labels: Array[RichTextLabel] = []
var _icon_nodes: Array[TextureRect] = []
var _glow_nodes: Array = []
var _shop_items: Array[Dictionary] = []

var _common_material_pool: Array[String] = []
var _shop_level_label: RichTextLabel
var _offer_tooltip_panel: Panel
var _upgrade_info_panel: Panel
var _exit_button: Button
var _tooltip_font: Font = null
var _setting_monster = SETTING_MONSTER_SCRIPT.new()
# 记录当前鼠标停留的是哪一个商品格子。
# 这里仍然保留索引，是因为 `mouse_exited` 之后我们会延后一帧再判断。
# 这样可以避免“刚离开时 UI 还没更新完”带来的误判。
# 但最终是否继续显示提示框，只以商品格子本体是否还被鼠标覆盖为准。
var _hovered_offer_index := -1
# 这个编号专门用来处理提示框的异步显示。
# 因为 `_show_offer_tooltip()` 里会等待两帧布局，
# 如果鼠标先离开了，旧的显示流程不能在稍后“复活”出来。
# 所以每次进入/离开商品时，都更新一次编号；
# 只有最新编号对应的那次显示请求，才允许真正把提示框显示出来。
var _offer_tooltip_request_id := 0


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
	var did_auto_refresh := false
	# 丹药回收现在改成手动点击 `recycle_button` 执行，
	# 所以进入商店时只刷新界面和按钮状态，不再自动回收。
	# 只有当前存档第一次进入货摊时才自动刷新。
	# 之后再次进入时，继续显示上次保存下来的货物；除非玩家手动点击刷新。
	if not Global.shop_first_entered:
		_generate_shop_items()
		Global.shop_first_entered = true
		did_auto_refresh = true
	_refresh_display()
	_save_shop_items_to_save()
	_refresh_external_ui()
	Global.save_game()


func _cache_nodes() -> void:
	# 这几个商品格子和文字节点，原先很多都是直接挂在当前层上的。
	# 现在层级调整过以后，导出槽可能还没完全重新绑定，
	# 所以这里统一做“导出优先，名字兜底”的兼容处理。
	if item1 == null:
		item1 = find_child("item1", true, false) as Panel
	if item2 == null:
		item2 = find_child("item2", true, false) as Panel
	if item3 == null:
		item3 = find_child("item3", true, false) as Panel
	if item4 == null:
		item4 = find_child("item4", true, false) as Panel
	if item5 == null:
		item5 = find_child("item5", true, false) as Panel
	if item6 == null:
		item6 = find_child("item6", true, false) as Panel
	if item1_name == null:
		item1_name = find_child("item1_name", true, false) as RichTextLabel
	if item2_name == null:
		item2_name = find_child("item2_name", true, false) as RichTextLabel
	if item3_name == null:
		item3_name = find_child("item3_name", true, false) as RichTextLabel
	if item4_name == null:
		item4_name = find_child("item4_name", true, false) as RichTextLabel
	if item5_name == null:
		item5_name = find_child("item5_name", true, false) as RichTextLabel
	if item6_name == null:
		item6_name = find_child("item6_name", true, false) as RichTextLabel
	if item1_price == null:
		item1_price = find_child("item1_price", true, false) as RichTextLabel
	if item2_price == null:
		item2_price = find_child("item2_price", true, false) as RichTextLabel
	if item3_price == null:
		item3_price = find_child("item3_price", true, false) as RichTextLabel
	if item4_price == null:
		item4_price = find_child("item4_price", true, false) as RichTextLabel
	if item5_price == null:
		item5_price = find_child("item5_price", true, false) as RichTextLabel
	if item6_price == null:
		item6_price = find_child("item6_price", true, false) as RichTextLabel
	_item_panels = [item1, item2, item3, item4, item5, item6]
	if now_ls == null:
		now_ls = find_child("now_ls", true, false) as RichTextLabel
	if refresh_num == null:
		refresh_num = find_child("refresh_num", true, false) as RichTextLabel
	if recycle_button == null:
		recycle_button = find_child("recycle_button", true, false) as Button
	_now_ls_label = now_ls
	_detail_labels = [
		find_child("item1_detail", true, false) as RichTextLabel,
		find_child("item1_detail2", true, false) as RichTextLabel,
		find_child("item1_detail3", true, false) as RichTextLabel,
		find_child("item1_detail4", true, false) as RichTextLabel,
		find_child("item1_detail5", true, false) as RichTextLabel,
		find_child("item1_detail6", true, false) as RichTextLabel
	]
	_name_labels = [item1_name, item2_name, item3_name, item4_name, item5_name, item6_name]
	_price_labels = [item1_price, item2_price, item3_price, item4_price, item5_price, item6_price]
	# `shop_level` 之前是当前层的直接子节点。
	# 如果后来把它挪进别的容器，原来的 `get_node("shop_level")` 就会拿不到。
	# 这里改成递归查找，让层级变化后也能自动接上。
	_shop_level_label = find_child("shop_level", true, false) as RichTextLabel
	if _shop_level_label != null:
		_shop_level_label.bbcode_enabled = true
		_shop_level_label.add_theme_font_size_override("normal_font_size", 22)
		_shop_level_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_shop_level_label.scroll_active = false
	else:
		# 如果这里还能为空，通常就说明节点名字改了，或者节点类型不再是 RichTextLabel。
		push_warning("shop_layer.gd: 没有找到名为 shop_level 的 RichTextLabel，请检查节点名称、类型或层级是否变动。")
	_glow_nodes.clear()
	_icon_nodes.clear()
	for panel in _item_panels:
		if panel == null:
			_glow_nodes.append(null)
			_icon_nodes.append(null)
			continue
		_glow_nodes.append(_ensure_glow_node(panel))
		_icon_nodes.append(_ensure_icon_node(panel))
	_configure_item_hit_areas_and_labels()


func _create_extra_controls() -> void:
	_offer_tooltip_panel = _create_bag_style_panel("OfferTooltipPanel", true)
	add_child(_offer_tooltip_panel)

	_upgrade_info_panel = _create_bag_style_panel("UpgradeInfoPanel", false)
	add_child(_upgrade_info_panel)

	_exit_button = Button.new()
	_exit_button.name = "ExitButton"
	_exit_button.text = "返回"
	_exit_button.position = Vector2(1148, 53)
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
		if panel == null:
			continue
		# 物品依然可以点击，但鼠标保持普通箭头样式，不再显示小手。
		panel.mouse_default_cursor_shape = Control.CURSOR_ARROW
		panel.gui_input.connect(_on_item_panel_gui_input.bind(i))
		panel.mouse_entered.connect(_on_item_panel_mouse_entered.bind(i))
		panel.mouse_exited.connect(_on_item_panel_mouse_exited.bind(i))

	if refresh_num != null:
		refresh_num.mouse_filter = Control.MOUSE_FILTER_STOP
		refresh_num.mouse_default_cursor_shape = Control.CURSOR_ARROW
		refresh_num.gui_input.connect(_on_refresh_gui_input)

	if shop_level_up_button != null:
		shop_level_up_button.pressed.connect(_on_shop_level_up_pressed)
		shop_level_up_button.mouse_entered.connect(_on_shop_level_up_mouse_entered)
		shop_level_up_button.mouse_exited.connect(_on_shop_level_up_mouse_exited)
	if recycle_button != null:
		recycle_button.focus_mode = Control.FOCUS_NONE
		recycle_button.mouse_default_cursor_shape = Control.CURSOR_ARROW
		recycle_button.pressed.connect(_on_recycle_button_pressed)
	if _exit_button != null:
		_exit_button.pressed.connect(_on_exit_button_pressed)


func _ensure_glow_node(panel: Panel):
	var glow_node = panel.get_node_or_null("QualityGlow")
	if glow_node == null:
		glow_node = QualityGlow.new()
		glow_node.name = "QualityGlow"
		panel.add_child(glow_node)
	# 光效必须压在图标下面，不能盖住图标本体，所以始终放到最底层子节点。
	panel.move_child(glow_node, 0)
	return glow_node


func _ensure_icon_node(panel: Panel) -> TextureRect:


	var icon_node := panel.get_node_or_null("Icon") as TextureRect
	if icon_node == null:
		icon_node = TextureRect.new()
		icon_node.name = "Icon"
		panel.add_child(icon_node)
	# 不管图标节点是不是场景里原本就存在，都统一设置为不拦截鼠标。
	# 这样鼠标放在图标、名称或价格区域时，都能命中整块商品并弹出详情。
	icon_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_node.visible = true
	icon_node.z_index = 1
	icon_node.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# 图标整体缩小 20%，但格子本身大小不变。
	# 这里直接把锚点收成 10% ~ 90%，这样图标始终保持在格子中心，
	# 同时无论面板尺寸是多少，视觉上都会是稳定的 80% 大小。
	icon_node.anchor_left = 0.1
	icon_node.anchor_top = 0.1
	icon_node.anchor_right = 0.9
	icon_node.anchor_bottom = 0.9
	icon_node.offset_left = 0
	icon_node.offset_top = 0
	icon_node.offset_right = 0
	icon_node.offset_bottom = 0
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
	_update_recycle_button_state()
	for i in range(_item_panels.size()):
		var panel := _item_panels[i]
		var detail_label := _detail_labels[i]
		var price_label := _price_labels[i]
		var icon_node := _icon_nodes[i]
		var glow_node = _glow_nodes[i] if i < _glow_nodes.size() else null
		# 图标和格子本体是最核心的显示节点。
		# 只要它们还在，就先把商品图标刷新出来；
		# 即使某个文字标签暂时没接上，也不要让整格商品空白。
		if panel == null or icon_node == null:
			continue
		if i >= _shop_items.size():
			if detail_label != null:
				detail_label.text = "未上架"
			if price_label != null:
				price_label.text = ""
			_apply_name_color_to_slot(i, Color.WHITE)
			if price_label != null:
				price_label.modulate = LINGSHI_PRICE_COLOR
			icon_node.texture = null
			panel.modulate = Color(1, 1, 1, 1)
			icon_node.modulate = Color(1, 1, 1, 1)
			if glow_node != null:
				glow_node.set_glow_rarity("")
				glow_node.set_glow_alpha_scale(0.0)
			continue
		var offer := _shop_items[i]
		var rarity := str(offer.get("rarity", "white"))
		var item_id := str(offer.get("item_id", ""))
		var item_name := str(ItemManager.get_item_property(item_id, "item_name"))
		var item_icon_path := str(ItemManager.get_item_property(item_id, "item_icon"))
		var name_color := _get_rare_color(str(ItemManager.get_item_property(item_id, "item_rare")))
		var price_color := _get_offer_price_color(offer)
		var icon_texture = load(item_icon_path) if not item_icon_path.is_empty() and ResourceLoader.exists(item_icon_path) else null
		panel.modulate = Color(1, 1, 1, 1)
		icon_node.visible = true
		icon_node.modulate = Color(1, 1, 1, 1)
		icon_node.texture = icon_texture
		_apply_name_color_to_slot(i, name_color)
		if price_label != null:
			price_label.modulate = price_color
		if glow_node != null:
			glow_node.set_glow_rarity(rarity)
			glow_node.set_glow_alpha_scale(1.0)
		if bool(offer.get("sold", false)):
			if detail_label != null:
				detail_label.text = "已售罄"
			if price_label != null:
				price_label.text = ""
			_apply_name_color_to_slot(i, SOLD_OUT_TEXT_COLOR)
			if price_label != null:
				price_label.modulate = SOLD_OUT_TEXT_COLOR
			icon_node.modulate = Color(0.35, 0.35, 0.35, 0.8)
			panel.modulate = Color(0.75, 0.75, 0.75, 1)
			if glow_node != null:
				glow_node.set_glow_alpha_scale(0.45)
			continue
		if detail_label != null:
			detail_label.text = item_name + " ×" + str(offer.get("quantity", 0))
		if price_label != null:
			price_label.text = _format_offer_price(offer)


func _update_shop_header() -> void:
	# 这里也要做一次保护。
	# 原因很简单：就算初始化时没找到 `shop_level`，刷新界面时也不能继续对空对象写入文本。
	if _shop_level_label != null:
		_shop_level_label.text = _build_shop_header_text()
	_update_now_ls_label()
	if Global.shop_level >= SHOP_LEVEL_CAP:
		shop_level_up_button.text = "货摊已满级"
		shop_level_up_button.disabled = true
		return
	shop_level_up_button.disabled = false
	var costs: Array = SHOP_UPGRADE_COSTS.get(Global.shop_level, [])
	if costs.is_empty():
		shop_level_up_button.text = "后续等级未开放"
	else:
		shop_level_up_button.text = "货摊升级"

func _update_now_ls_label() -> void:
	if _now_ls_label == null:
		_now_ls_label = find_child("now_ls", true, false) as RichTextLabel
	if _now_ls_label == null:
		return
	# 这里的“真气”沿用商店购买灵石包时使用的 point 资源，也就是 `Global.total_points`。
	_now_ls_label.text = "灵石 %d   真气 %d" % [Global.lingshi, Global.total_points]


func _update_refresh_label() -> void:
	if refresh_num == null:
		refresh_num = find_child("refresh_num", true, false) as RichTextLabel
		if refresh_num == null:
			return
	var battle_refresh := Global.shop_battle_refresh_count
	var shipping_refresh := Global.get_item_count("item_059")
	refresh_num.text = "刷新（%d）" % (battle_refresh + shipping_refresh)

func _update_recycle_button_state() -> void:
	if recycle_button == null:
		recycle_button = find_child("recycle_button", true, false) as Button
	if recycle_button == null:
		return
	var has_recyclable := _has_recyclable_obsolete_pills()
	recycle_button.disabled = not has_recyclable
	# 按钮文字保持不变，只通过置灰提示当前有没有可回收内容。
	recycle_button.modulate = Color(1, 1, 1, 1) if has_recyclable else Color(0.7, 0.7, 0.7, 1)

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

func _get_offer_price_color(offer: Dictionary) -> Color:
	if str(offer.get("cost_resource", "lingshi")) == "point":
		return ZHENQI_PRICE_COLOR
	return LINGSHI_PRICE_COLOR

func _apply_name_color_to_slot(index: int, color: Color) -> void:
	if index >= 0 and index < _detail_labels.size() and _detail_labels[index] != null:
		_detail_labels[index].modulate = color
	# 场景里如果还保留了单独的名字标签，也同步给它上色。
	# 这样无论当前用的是旧布局还是新布局，名字颜色规则都会一致。
	if index >= 0 and index < _name_labels.size() and _name_labels[index] != null:
		_name_labels[index].modulate = color

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
		detail_text += "\n\n[来源] \n" + item_source
	return detail_text

func _show_offer_tooltip(index: int, request_id: int) -> void:
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
		name_label.add_theme_color_override("font_color", SOLD_OUT_TEXT_COLOR)
		type_label.text = "[已售罄]"
		desc_label.text = "该商品已被买走，等待下次刷新。"
		price_label.text = "卖完啦！"
		price_label.add_theme_color_override("font_color", SOLD_OUT_TEXT_COLOR)
		hint_label.visible = false
	else:
		var rarity := str(offer.get("rarity", "white"))
		var item_rare := str(ItemManager.get_item_property(item_id, "item_rare"))
		name_label.text = "  " + item_name
		name_label.add_theme_color_override("font_color", _get_rare_color(item_rare))
		type_label.text = "%s" % [_get_item_type_display_name(item_id)]
		desc_label.text = _build_offer_detail_text(offer)
		price_label.text = "售价: " + _format_offer_price(offer)
		price_label.add_theme_color_override("font_color", _get_offer_price_color(offer))
		hint_label.text = "\n双击购买商品"
		hint_label.visible = true

	await _finalize_info_panel_layout(_offer_tooltip_panel)
	# 这里必须再次确认：
	# - 这次显示请求仍然是最新的一次；
	# - 鼠标此时还停留在同一个商品格子上。
	# 否则说明玩家已经移开了，或者已经切到别的商品，
	# 旧的异步流程就不能再把提示框显示出来。
	if request_id != _offer_tooltip_request_id:
		return
	if _hovered_offer_index != index:
		return
	if index < 0 or index >= _item_panels.size():
		return
	var hovered_panel := _item_panels[index]
	if hovered_panel == null:
		return
	var tooltip_pos := hovered_panel.global_position + Vector2(hovered_panel.size.x + 10, 0)
	var viewport_size := get_viewport().get_visible_rect().size
	if tooltip_pos.x + _offer_tooltip_panel.size.x > viewport_size.x:
		tooltip_pos.x = hovered_panel.global_position.x - _offer_tooltip_panel.size.x - 10
	if tooltip_pos.y + _offer_tooltip_panel.size.y > viewport_size.y:
		tooltip_pos.y = viewport_size.y - _offer_tooltip_panel.size.y - 10
	_offer_tooltip_panel.global_position = tooltip_pos
	_offer_tooltip_panel.visible = true

func _hide_offer_tooltip() -> void:
	# 每次隐藏时都顺手让旧请求失效。
	# 这样即使之前某次 `_show_offer_tooltip()` 还在 await，
	# 它恢复执行后也会因为编号过期而直接退出。
	_offer_tooltip_request_id += 1
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
		# 只有左键双击才会购买，单击现在只负责选中/查看，不再直接触发购买。
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed and mouse_event.double_click:
			_try_buy_offer(index)


func _on_item_panel_mouse_entered(index: int) -> void:
	_hovered_offer_index = index
	_offer_tooltip_request_id += 1
	var request_id := _offer_tooltip_request_id
	_show_offer_tooltip(index, request_id)

func _on_item_panel_mouse_exited(index: int) -> void:
	# 不直接立刻关闭，而是延后一拍再检查一次。
	# 原因很简单：鼠标刚离开时，Godot 的界面事件和绘制更新可能还在同一帧里。
	# 延后一拍后再判断，会更稳定。
	call_deferred("_handle_item_panel_mouse_exit", index)

func _handle_item_panel_mouse_exit(index: int) -> void:
	if _hovered_offer_index != index:
		return
	# 这里按你的需求改成“只认 item 格子本体”。
	# 也就是说：
	# 1. 鼠标在提示框上，不算还停留在商品上。
	# 2. 鼠标在格子外扩的红光/特效上，也不算还停留在商品上。
	# 3. 只有鼠标还在商品 panel 的矩形里，提示框才继续显示。
	if _is_mouse_over_offer_panel(index):
		return
	_hovered_offer_index = -1
	_hide_offer_tooltip()

func _is_mouse_over_offer_panel(index: int) -> bool:
	if index < 0 or index >= _item_panels.size():
		return false
	var panel := _item_panels[index]
	if panel == null:
		return false
	var mouse_pos := get_viewport().get_mouse_position()
	# 这里故意不用 `panel.get_global_rect()`。
	# 原因是场景里的 `Panel` 实际矩形有可能比你肉眼看到的格子更大，
	# 那样就会出现“看起来已经离开格子了，但代码还判定在格子里”的问题。
	# 现在直接以你确认过的商品格子尺寸 `88×88` 作为唯一命中范围：
	# - 左上角：沿用当前 panel 的全局位置
	# - 大小：固定 88×88
	# 这样提示框的消失就会严格跟着格子本体走。
	var item_rect := Rect2(panel.global_position, ITEM_HITBOX_SIZE)
	return item_rect.has_point(mouse_pos)

func _try_buy_offer(index: int) -> void:
	if index < 0 or index >= _shop_items.size():
		return
	var offer := _shop_items[index]
	if bool(offer.get("sold", false)):
		_show_tips("商品已告罄", 0.5)
		return
	if str(offer.get("product_type", "")) == "lingshi_pack":
		offer["cost"] = int(offer.get("quantity", 0)) * Global.shop_lingshi_unit_price
		_shop_items[index] = offer
	var cost := int(offer.get("cost", 0))
	var item_id := str(offer.get("item_id", ""))
	var quantity := int(offer.get("quantity", 0))
	if str(offer.get("cost_resource", "")) == "point":
		if Global.total_points < cost:
			_show_tips("真气不足，需要 %d 真气，当前 %d。" % [cost, Global.total_points], 0.5)
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

func _configure_item_hit_areas_and_labels() -> void:
	if _item_panels.is_empty() or _detail_labels.is_empty() or _price_labels.is_empty():
		return
	# 这里回到之前的做法：只处理“谁来接鼠标事件”，不再统一改位置和尺寸。
	# 这样就不会把场景里原本摆好的名字、价格位置重新覆盖掉。
	for i in range(_item_panels.size()):
		var panel := _item_panels[i]
		var detail_label := _detail_labels[i]
		var price_label := _price_labels[i]
		if panel == null:
			continue
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		if detail_label != null:
			detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if price_label != null:
			price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i < _icon_nodes.size() and _icon_nodes[i] != null:
			_icon_nodes[i].mouse_filter = Control.MOUSE_FILTER_IGNORE
	for extra_name_label in [item1_name, item2_name, item3_name, item4_name, item5_name, item6_name]:
		if extra_name_label != null:
			extra_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _try_refresh_shop() -> void:
	var battle_refresh := Global.shop_battle_refresh_count
	var shipping_refresh := Global.get_item_count("item_059")
	if battle_refresh + shipping_refresh <= 0:
		_show_tips("刷新次数不足，通关或准备进货单后再来。", 0.5)
		return
	var consume_message := ""
	if battle_refresh > 0:
		Global.shop_battle_refresh_count -= 1
		consume_message = "消耗了 1 次进货次数。"
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

func _on_recycle_button_pressed() -> void:
	var recycle_message := _recycle_obsolete_pills()
	_refresh_display()
	_refresh_external_ui()
	if recycle_message.is_empty():
		_show_tips("当前没有可回收的溢出丹药。", 0.5)
		return
	Global.save_game()
	_show_tips(recycle_message, 1.2)

func _has_recyclable_obsolete_pills() -> bool:
	return not _get_recyclable_pill_entries().is_empty()

func _get_recyclable_pill_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
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
		entries.append({
			"item_id": item_id,
			"count": count,
			"gain": count * unit_price,
			"item_name": str(ItemManager.get_item_property(item_id, "item_name"))
		})
	return entries

func _recycle_obsolete_pills() -> String:
	var recycle_entries := _get_recyclable_pill_entries()
	if recycle_entries.is_empty():
		return ""
	var recycled_lines: Array[String] = []
	var total_lingshi := 0
	for entry in recycle_entries:
		var item_id := str(entry.get("item_id", ""))
		var count := int(entry.get("count", 0))
		var gain := int(entry.get("gain", 0))
		if count <= 0 or gain <= 0:
			continue
		Global.player_inventory.erase(item_id)
		total_lingshi += gain
		recycled_lines.append(str(entry.get("item_name", item_id)) + "×" + str(count) + "（+" + str(gain) + "灵石）")
	if total_lingshi <= 0:
		return ""
	Global.add_item_count(Global.LINGSHI_ITEM_ID, total_lingshi)
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
	# 关闭商店时只做界面收尾，不再修改货摊的刷新状态。
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
