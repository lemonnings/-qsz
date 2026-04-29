extends CanvasLayer

@onready var start_sprite: Sprite2D = $Control/Sprite2D
@onready var start_text: RichTextLabel = $RichTextLabel
@onready var subtitle_bg: ColorRect = $SubtitleBg

const START_TEXTURES = [
	preload("res://AssetBundle/Sprites/image/start1.png"),
	preload("res://AssetBundle/Sprites/image/start2.png"),
	preload("res://AssetBundle/Sprites/image/start3.png"),
	preload("res://AssetBundle/Sprites/image/start4.png"),
	preload("res://AssetBundle/Sprites/image/start1.png"),
	preload("res://AssetBundle/Sprites/image/start5.png"),
	preload("res://AssetBundle/Sprites/image/start6.png"),
	preload("res://AssetBundle/Sprites/image/start7.png"),
	preload("res://AssetBundle/Sprites/image/start7.png"),
]

const START_SUBTITLES = [
	"桃源镇，天衍宗门下属地。因得仙宗庇佑，镇子风调雨顺，日子安稳太平。",
	"忽有一日，镇外的龙门山上出现一道墨色裂隙，裂隙以肉眼可见的速度不断扩大。",
	"不久之后，一个镇民们从未见过的巨型建筑砸落到了龙门山上……",
	"随着裂隙继续扩大，黑压压的异兽如潮水般涌出，煞气冲天。",
	"可没过多久，那裂隙便逐渐消失，仿佛从未出现过……",
	"有镇民欲前去查探，谁知刚行至镇外桃林，便被一股奇力推了回来，无法前进分毫。",
	"察觉到龙门山被幻境封锁，天衍宗派遣弟子前去调查，但他们同样被奇力推回。",
	"这等奇事引起天衍宗重视，派出八部长老及精英弟子前去调查。",
	"大长老乾在一番探测后，发现幻境构造精妙绝伦，已远非宗门阵道造诣所能及……",
]

## 打字速度：每字符间隔（秒）
const TYPE_SPEED := 0.07

## 文字显示完成后自动翻页等待时间（秒）
const AUTO_NEXT_DELAY := 12.0

var current_page: int = 0
var is_animating: bool = false
var is_typing: bool = false
var type_full_text: String = ""
var type_current_index: int = 0
var page_tween: Tween
var auto_next_timer: SceneTreeTimer = null
var _auto_next_id: int = 0 ## 计时器唯一标识，用于失效旧回调
var scale_tween: Tween
## sprite的初始缩放基准（从场景读取）
var _base_scale: Vector2

func _ready() -> void:
	current_page = 0
	_base_scale = start_sprite.scale
	# 预先加载第一张图，白屏渐变时图片已就位
	start_sprite.texture = START_TEXTURES[0]
	start_sprite.modulate.a = 1.0
	start_text.text = ""
	subtitle_bg.visible = false
	# 将所有子节点设为透明，再整体渐入（白屏渐变效果）
	for child in get_children():
		if child is CanvasItem:
			child.modulate.a = 0.0
	var tw = create_tween()
	tw.set_parallel(true)
	for child in get_children():
		if child is CanvasItem:
			tw.tween_property(child, "modulate:a", 1.0, 1)
	tw.set_parallel(false)
	tw.tween_callback(func():
		subtitle_bg.visible = true
		_start_scale_anim()
		_start_typing(START_SUBTITLES[0])
	)

func _load_page(page: int) -> void:
	current_page = page
	start_sprite.texture = START_TEXTURES[page]
	# scale已在渐出时重置（_next_page中），此处直接从0淡入
	start_sprite.modulate.a = 0.0
	start_text.text = ""
	subtitle_bg.modulate.a = 0.0
	subtitle_bg.visible = true
	# 图片与字幕背景同时淡入，淡入完成后开始打字和缩放动画
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(start_sprite, "modulate:a", 1.0, 0.4)
	tw.tween_property(subtitle_bg, "modulate:a", 1.0, 0.4)
	tw.set_parallel(false)
	tw.tween_callback(func():
		_start_scale_anim()
		_start_typing(START_SUBTITLES[page])
	)

func _start_scale_anim() -> void:
	## 缩放从基准大小缓慢放大到1.08倍，持续15秒
	if scale_tween and scale_tween.is_running():
		scale_tween.kill()
	start_sprite.scale = _base_scale
	scale_tween = create_tween()
	scale_tween.set_ease(Tween.EASE_OUT)
	scale_tween.set_trans(Tween.TRANS_SINE)
	scale_tween.tween_property(start_sprite, "scale", _base_scale * 1.08, 15.0)

func _start_typing(text: String) -> void:
	type_full_text = text
	type_current_index = 0
	is_typing = true
	if start_text:
		start_text.text = ""
		start_text.visible_characters = -1
	_type_next_char()

func _type_next_char() -> void:
	if not is_typing:
		return
	if type_current_index >= type_full_text.length():
		is_typing = false
		# 打字完成，启动4秒自动翻页计时器
		_start_auto_next_timer()
		return
	type_current_index += 1
	if start_text:
		start_text.text = type_full_text.substr(0, type_current_index)
	await get_tree().create_timer(TYPE_SPEED).timeout
	_type_next_char()

func _skip_typing() -> void:
	## 直接显示完整字幕，并启动自动翻页计时器
	is_typing = false
	if start_text:
		start_text.text = type_full_text
	_start_auto_next_timer()

func _start_auto_next_timer() -> void:
	## 启动自动翻页计时器，旧计时器通过id校验自动失效
	_auto_next_id += 1
	var my_id = _auto_next_id
	auto_next_timer = get_tree().create_timer(AUTO_NEXT_DELAY)
	auto_next_timer.timeout.connect(func():
		# 只有当前id匹配才执行，防止旧计时器触发翻页
		if my_id == _auto_next_id and not is_typing and not is_animating:
			_next_page()
	)

func _cancel_auto_next_timer() -> void:
	## 递增id使所有旧计时器回调失效
	_auto_next_id += 1
	auto_next_timer = null

func _input(event: InputEvent) -> void:
	if is_animating:
		return
	var is_click = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	var is_tap = (event is InputEventScreenTouch and event.pressed)
	if not (is_click or is_tap):
		return
	get_viewport().set_input_as_handled()
	if is_typing:
		# 先按一次：跳过打字直接显示完整字幕（内部会重启计时器）
		_skip_typing()
	else:
		# 已显示完毕，取消自动计时器，立即翻页
		_cancel_auto_next_timer()
		_next_page()

func _next_page() -> void:
	var next = current_page + 1
	if next >= START_TEXTURES.size():
		# 所有页播完，跳转到主城
		_go_to_main_town()
		return
	is_animating = true
	# 立即停止上一页的缩放动画，防止它继续修改scale
	if scale_tween and scale_tween.is_running():
		scale_tween.kill()
	# 图片与字幕背景同时渐出 → 完全透明时重置scale → 换图 → 渐入 → 打字
	if page_tween:
		page_tween.kill()
	page_tween = create_tween()
	page_tween.set_parallel(true)
	page_tween.tween_property(start_sprite, "modulate:a", 0.0, 0.3)
	page_tween.tween_property(subtitle_bg, "modulate:a", 0.0, 0.3)
	page_tween.set_parallel(false)
	page_tween.tween_callback(func():
		# 完全透明后重置scale，玩家看不到
		start_sprite.scale = _base_scale
		if start_text:
			start_text.text = ""
		is_animating = false
		_load_page(next)
	)

func _go_to_main_town() -> void:
	is_animating = true
	# 全屏渐黑后跳转
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 9999
	add_child(overlay)
	var tw = create_tween()
	tw.tween_property(overlay, "color:a", 1.0, 0.5)
	tw.tween_callback(func():
		SceneChange.change_scene("res://Scenes/main_town.tscn", true)
	)
