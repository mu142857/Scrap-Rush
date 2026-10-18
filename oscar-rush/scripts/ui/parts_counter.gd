class_name PartsCounter
extends Control
## 零件数（商店的货币）：一个小齿轮图标加"x 3"。商店里放在左上角水晶血量下面；
## 关卡里 EmotionFx 也放一个（auto_hide：平时藏着，零件数一变亮 3 秒再淡掉）。
## 反馈（10-18 夜间打磨加）：
## - 变多：图标弹一下，旁边往上飘一个暖黄的"+1"；
## - 花掉：图标弹一下，飘一个红的"-N"；
## - 不够（deny）：数字变红、左右抖一下。

const ICONS := preload("res://art/shop/icons.png")
const WARM := Color8(255, 211, 138)
const POOR := Color8(220, 90, 70)
const SHOW_TIME := 3.0

## 平时藏着，零件数变了才亮几秒（关卡里用）
var auto_hide := false
var _label: Label
var _pop := 0.0
var _deny := 0.0
var _show_t := 0.0
var _last := 0
var _icon: TextureRect


func _ready() -> void:
	size = Vector2(60, 16)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var atlas := AtlasTexture.new()
	atlas.atlas = ICONS
	atlas.region = Rect2(0, 0, 16, 16)
	_icon = TextureRect.new()
	_icon.texture = atlas
	_icon.position = Vector2(-3, -3)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_label = Label.new()
	_label.label_settings = Hud.small_text(WARM)
	_label.position = Vector2(13, -1)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	Run.parts_changed.connect(_on_parts)
	_last = Run.parts
	_label.text = "x %d" % Run.parts
	if auto_hide:
		modulate.a = 0.0


func _on_parts(n: int) -> void:
	_label.text = "x %d" % n
	_pop = 1.0
	_show_t = SHOW_TIME
	var d := n - _last
	_last = n
	if d != 0:
		_float(("+%d" % d) if d > 0 else ("%d" % d), WARM if d > 0 else POOR)


## 买不起：数字变红、左右抖一下
func deny() -> void:
	_deny = 0.4
	_show_t = SHOW_TIME


func _float(text: String, col: Color) -> void:
	var l := Label.new()
	l.label_settings = Hud.small_text(col)
	l.text = text
	l.position = Vector2(34, -2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_method(func(k: float): l.position.y = roundf(-2.0 - 6.0 * k), 0.0, 1.0, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func _process(delta: float) -> void:
	_pop = maxf(_pop - delta * 5.0, 0.0)
	_deny = maxf(_deny - delta, 0.0)
	_show_t = maxf(_show_t - delta, 0.0)
	_icon.position.y = -3 - roundf(sin(_pop * PI) * 2.0)
	_label.label_settings.font_color = POOR if _deny > 0.0 else WARM
	_label.position.x = 13 + (float(int(_deny * 30.0) % 2 * 2 - 1) if _deny > 0.0 else 0.0)
	if auto_hide:
		modulate.a = clampf(_show_t / 0.5, 0.0, 1.0) if _show_t < 0.5 else 1.0
