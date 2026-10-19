extends CanvasLayer
## （没有 class_name：10-18 隐藏关机制的活撤回了，这个文件没人用，留着不进全局类表。要用就 load("res://scripts/hidden/tape_fx.gd")）
## 隐藏关「第四盘·倒带」录像机三个键共用的画面效果（碰撞会话，10-18）：
##   tear(强度, 秒)：画面横着撕开几条、隔行压暗，像信号不好（暂停时一直轻轻抖，跳帧前 0.5 秒撕开，倒带时抖）
##   icon(符号, 秒)：右上角录像机角标：PAUSE "‖"、SKIP ">>|"、REWIND "<<"
## 一个房间只建一个：load(本文件).of(房间)。整个画面一个 ColorRect 读屏幕，强度为 0 时藏起来不花钱。

const PAUSE := 0
const SKIP := 1
const REWIND := 2

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float amount = 0.0;
uniform float seed = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
float h(float x) { return fract(sin(x * 91.7 + seed * 13.1) * 43758.5); }
void fragment() {
	vec2 uv = SCREEN_UV;
	float row = floor(uv.y * 90.0);
	// 只有一部分横条错位：条越多越乱
	float band = step(1.0 - amount * 0.45, h(floor(uv.y * 24.0)));
	float shift = (h(row) - 0.5) * 0.05 * amount * band;
	vec3 c = texture(screen_tex, vec2(uv.x + shift, uv.y)).rgb;
	c *= 1.0 - 0.14 * amount * step(0.5, fract(uv.y * 45.0 + seed));
	COLOR = vec4(mix(c, c * tint.rgb, clamp(amount, 0.0, 1.0) * 0.5), 1.0);
}
"""

var _rect: ColorRect
var _mat: ShaderMaterial
var _icon: TapeIcon
var _tear := 0.0
var _tear_t := 0.0
## 一直保持的最低抖动（暂停中一直轻轻抖）
var hold := 0.0
var _seed_t := 0.0


## 拿这个房间的 TapeFx，没有就建一个
static func of(room: Node) -> CanvasLayer:
	var me: Script = load("res://scripts/hidden/tape_fx.gd")
	for c in room.get_children():
		if c.get_script() == me:
			return c
	var fx: CanvasLayer = me.new()
	room.add_child(fx)
	return fx


func _ready() -> void:
	layer = 9
	add_to_group("tape_keep")
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_rect = ColorRect.new()
	_rect.material = _mat
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.visible = false
	add_child(_rect)
	_icon = TapeIcon.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_icon)


## 撕一下：strength 0~1，持续 time 秒（线性减弱）
func tear(strength: float, time: float) -> void:
	if strength >= _tear * (_tear_t / maxf(_tear_t, 0.001)):
		_tear = strength
		_tear_t = time
		_tear_left = time


var _tear_left := 0.0


## 右上角角标；time <= 0 就一直亮到 icon_off()
func icon(kind: int, time := 0.0, col := Color(1, 1, 1)) -> void:
	_icon.kind = kind
	_icon.left = time
	_icon.forever = time <= 0.0
	_icon.col = col
	_icon.visible = true
	_icon.queue_redraw()


func icon_off() -> void:
	_icon.visible = false


func _process(delta: float) -> void:
	if _tear_left > 0.0:
		_tear_left = maxf(_tear_left - delta, 0.0)
	var a := maxf(hold, _tear * (_tear_left / maxf(_tear_t, 0.001)))
	_rect.visible = a > 0.01
	if _rect.visible:
		_seed_t += delta
		# 一秒换 12 次花样：一格一格地跳，像录像带，不是平滑地流
		_mat.set_shader_parameter("seed", floorf(_seed_t * 12.0))
		_mat.set_shader_parameter("amount", a)
	if _icon.visible and not _icon.forever:
		_icon.left -= delta
		if _icon.left <= 0.0:
			_icon.visible = false


## 右上角的录像机角标，用色块画（不靠字体）
class TapeIcon extends Control:
	var kind := 0
	var left := 0.0
	var forever := false
	var col := Color(1, 1, 1)

	func _process(_d: float) -> void:
		if visible:
			queue_redraw()

	func _draw() -> void:
		# 一秒闪 2 下，像录像机屏幕上的字
		if int(Time.get_ticks_msec() / 250) % 4 == 3:
			return
		var w := get_viewport_rect().size.x
		var o := Vector2(w - 34, 10)
		var shadow := Color(0, 0, 0, 0.6)
		for pass_i in 2:
			var d := Vector2(1, 1) if pass_i == 0 else Vector2.ZERO
			var c := shadow if pass_i == 0 else col
			match kind:
				0:
					draw_rect(Rect2(o + d + Vector2(4, 0), Vector2(4, 12)), c)
					draw_rect(Rect2(o + d + Vector2(12, 0), Vector2(4, 12)), c)
				1:
					_tri(o + d, 1.0, c)
					_tri(o + d + Vector2(7, 0), 1.0, c)
					draw_rect(Rect2(o + d + Vector2(15, 0), Vector2(3, 12)), c)
				2:
					_tri(o + d + Vector2(7, 0), -1.0, c)
					_tri(o + d + Vector2(14, 0), -1.0, c)

	## 一个朝右（s=1）或朝左（s=-1）的三角，宽 7 高 12
	func _tri(at: Vector2, s: float, c: Color) -> void:
		var pts: PackedVector2Array
		if s > 0.0:
			pts = PackedVector2Array([at, at + Vector2(7, 6), at + Vector2(0, 12)])
		else:
			pts = PackedVector2Array([at + Vector2(0, 6), at + Vector2(-7, 0), at + Vector2(-7, 12)])
			pts = PackedVector2Array([at + Vector2(-7, 6), at, at + Vector2(0, 12)])
		draw_colored_polygon(pts, c)
