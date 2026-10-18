class_name L3BootIntro
extends Control
## 第三关开场：老电脑开机（2026-10-18 作者："第三关可以是电脑开机画面……要做出电影感，高级感，流畅的动画"）。
## 和结局里老电视"自己重新开机"首尾呼应：都是显像管从一个亮点 → 一条横线 → 整屏。
##   0.00  黑。显像管上电"咚"一声，高压包细细地啸叫
##   0.15  正中一个亮点，越来越亮
##   0.45  亮点拉成一条横线（快进慢出）
##   0.75  横线上下张开成整屏，白闪一下退成 BIOS 的深蓝黑
##   1.05  BIOS 自检一行行跳出来：内存计数、检测磁带机、马灯、船员、家乡信号……每行硬盘"嗒"一声
##   2.75  读取录像带的进度条
##   3.50  镜头扎进屏幕：画面放大、红青串色越拉越开，碎成像素溶解，露出第三关
## 总长约 4.4 秒。10-18 起作为三关共用开场框架 LevelIntro（游戏细节讨论会话）的内容播：
##   黑边、跳过、整棵树暂停、只在一局第一次进关时播，都由框架管；
##   扎进屏幕碎完的那一刻调 intro.reveal()：镜头拉回、名字卡"第三关 · 屏幕世界"淡入（BIOS 的字已经碎光，不会叠字）。
## 框架上下各有 24 像素黑边，所以字都放在 y 40～240 之间。

signal _ended

const BG := Color(0.03, 0.04, 0.07)
const TEXT := Color(0.78, 0.86, 0.9)
const DIM := Color(0.45, 0.52, 0.6)
const AMBER := Color(1.0, 0.8, 0.45)
const GOOD := Color(0.55, 1.0, 0.6)
const WARN := Color(1.0, 0.45, 0.4)
const W := 480.0
const H := 270.0

const T_DOT := 0.15
const T_LINE := 0.45
const T_OPEN := 0.75
const T_BIOS := 1.05
const T_BAR := 2.75
const T_BAR_END := 3.45
const T_DIVE := 3.5
const DIVE_TIME := 0.9

## 自检的每一行：[出现时刻, 左半, 右半, 右半颜色]。左半在 _draw 里 tr()，右半有的是数字
const LINES := [
	[1.20, "Memory test", "", "mem"],
	[1.75, "Detecting tape drive", "1 found", "ok"],
	[1.95, "Detecting lantern", "lit", "ok"],
	[2.15, "Detecting crew", "4 aboard", "ok"],
	[2.35, "Hometown signal", "weak", "warn"],
	[2.55, "Loading tape #3", "HOME", "amber"],
]

static var _shader: Shader

var _t := 0.0
var _dive_at := T_DIVE
var _dive_len := DIVE_TIME
var _done := false
var _intro: LevelIntro
var _hum: AudioStreamPlayer
var _clicked := {}
var _canvas: Control
var _mat: ShaderMaterial

const DISSOLVE := """
shader_type canvas_item;
// 扎进屏幕时整块碎成方块消失：按屏幕上的方格算随机数，比阈值小的格子不画
uniform float dissolve = 0.0;
uniform float cell = 12.0;
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
void fragment() {
	vec2 c = floor(FRAGCOORD.xy / cell);
	// 中间先碎、边上后碎，像被吸进去
	vec2 uv = FRAGCOORD.xy * SCREEN_PIXEL_SIZE - 0.5;
	float edge = clamp(1.0 - length(uv) * 1.2, 0.0, 1.0);
	if (hash12(c) * 0.75 + edge * 0.25 < dissolve) {
		discard;
	}
	COLOR = COLOR;
}
"""


## LevelIntro 调：一直播到扎进屏幕碎完（或者被跳过）
func run(intro: LevelIntro) -> void:
	_intro = intro
	if not _done:
		await _ended


func _ready() -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.size = Vector2(W, H)
	_canvas.pivot_offset = Vector2(W, H) * 0.5
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _shader == null:
		_shader = Shader.new()
		_shader.code = DISSOLVE
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	_canvas.material = _mat
	_canvas.draw.connect(_draw_canvas)
	add_child(_canvas)
	_hum = AudioStreamPlayer.new()
	_hum.stream = Game.load_sound("boot_hum")
	_hum.volume_db = -14.0
	_hum.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_hum)


func _process(delta: float) -> void:
	if _done:
		return
	if _intro and _intro.skipped:
		_done = true
		_ended.emit()
		return
	var before := _t
	_t += delta
	_cues(before, _t)
	if _t >= _dive_at:
		var k := clampf((_t - _dive_at) / _dive_len, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		# 往屏幕里扎：放大（越来越快），同时碎掉
		_canvas.scale = Vector2.ONE * (1.0 + pow(k, 2.2) * 5.0)
		_mat.set_shader_parameter("dissolve", clampf((k - 0.25) / 0.75, 0.0, 1.0))
		_mat.set_shader_parameter("cell", 6.0 + 30.0 * e)
		if k >= 1.0 and not _done:
			_finish()
			return
	_canvas.queue_redraw()


func _finish() -> void:
	_done = true
	# 碎完了：撤掉自己的黑底，镜头拉回、名字卡淡入（框架管），嗡嗡声跟着淡掉
	visible = false
	if _intro:
		_intro.reveal()
	if _hum.playing:
		create_tween().tween_property(_hum, "volume_db", -40.0, 0.5)
	_ended.emit()


## 音效：到点放一次
func _cues(a: float, b: float) -> void:
	if _crossed(a, b, 0.05):
		Game.sfx("boot_crt", -4.0)
	if _crossed(a, b, T_OPEN):
		_hum.play()
	if _crossed(a, b, 1.70):
		Game.sfx("boot_beep", -12.0)
	for i in LINES.size():
		if i > 0 and _crossed(a, b, LINES[i][0]):
			Game.sfx("hdd_click", -8.0, randf_range(0.9, 1.15))
	for k in 6:
		if _crossed(a, b, T_BAR + k * 0.12):
			Game.sfx("hdd_click", -10.0, randf_range(0.8, 1.2))
	if _crossed(a, b, _dive_at):
		Game.sfx("tvon", -8.0, 1.3)


func _crossed(a: float, b: float, at: float) -> bool:
	return a < at and b >= at


func _draw_canvas() -> void:
	var c := _canvas
	c.draw_rect(Rect2(0, 0, W, H), Color.BLACK)
	var mid := Vector2(W, H) * 0.5
	if _t < T_DOT:
		return
	if _t < T_LINE:
		# 亮点：一个白芯，外面两圈越来越淡的光
		var k := (_t - T_DOT) / (T_LINE - T_DOT)
		var r := 1.0 + k * 2.0
		for g in [[r + 6.0, 0.08], [r + 3.0, 0.2], [r, 1.0]]:
			var rr: float = g[0]
			c.draw_rect(Rect2(mid.x - rr, mid.y - rr * 0.6, rr * 2.0, rr * 1.2).abs(), Color(0.85, 0.95, 1.0, g[1] * minf(1.0, k * 3.0)))
		return
	if _t < T_OPEN:
		# 拉成横线：快进慢出
		var k := (_t - T_LINE) / (T_OPEN - T_LINE)
		var e := 1.0 - pow(1.0 - k, 4.0)
		var hw := 3.0 + (W * 0.5 - 3.0) * e
		c.draw_rect(Rect2(mid.x - hw, mid.y - 4, hw * 2.0, 8), Color(0.7, 0.85, 1.0, 0.12))
		c.draw_rect(Rect2(mid.x - hw, mid.y - 2, hw * 2.0, 4), Color(0.8, 0.92, 1.0, 0.3))
		c.draw_rect(Rect2(mid.x - hw, mid.y - 1, hw * 2.0, 2), Color(0.95, 1.0, 1.0))
		return
	# 张开成整屏：白 → BIOS 底色
	var ko := clampf((_t - T_OPEN) / (T_BIOS - T_OPEN), 0.0, 1.0)
	var eo := 1.0 - pow(1.0 - ko, 3.0)
	var hh := 2.0 + (H * 0.5 - 2.0) * eo
	var bg := Color(0.9, 0.96, 1.0).lerp(BG, eo)
	c.draw_rect(Rect2(0, mid.y - hh, W, hh * 2.0), bg)
	if ko < 1.0:
		c.draw_rect(Rect2(0, mid.y - 1, W, 2), Color(1, 1, 1, 1.0 - eo))
	if _t >= T_BIOS:
		_draw_bios(c)
	_draw_crt(c)


func _draw_bios(c: Control) -> void:
	var font := Hud.font()
	var fs := 11
	# 串色：扎进屏幕时红、青两层越拉越开
	var ca := 0.0
	if _t >= _dive_at:
		ca = clampf((_t - _dive_at) / _dive_len, 0.0, 1.0) * 4.0
	var x0 := 26.0
	var y := 46.0
	# 抬头：厂牌 + 右上角一台小电视图标
	_text(c, font, Vector2(x0, y), "SCRAP-TEK 86   BIOS v1.986", AMBER, fs, ca)
	_text(c, font, Vector2(x0, y + 13), tr("Old Tech Inc. - all signals reserved"), DIM, fs, ca)
	_draw_logo(c, Vector2(W - 70, 40))
	y += 34.0
	for i in LINES.size():
		var at: float = LINES[i][0]
		if _t < at:
			break
		var left: String = tr(LINES[i][1])
		# 左半一个字一个字敲出来（很快）
		var n := clampi(int((_t - at) / 0.012), 0, left.length())
		_text(c, font, Vector2(x0, y), left.substr(0, n), TEXT, fs, ca)
		if n >= left.length():
			var dots_x := x0 + 180.0
			var right := ""
			var col := TEXT
			match LINES[i][3]:
				"mem":
					var kb := clampi(int((_t - at) / 0.45 * 640.0), 0, 640)
					right = "%dK" % kb
					if kb >= 640:
						right += "  " + tr("OK")
						col = GOOD
				"ok":
					right = tr(LINES[i][2])
					col = GOOD
				"warn":
					right = tr(LINES[i][2])
					col = WARN if int(_t * 4.0) % 2 == 0 else WARN.darkened(0.4)
				"amber":
					right = tr(LINES[i][2])
					col = AMBER
			_text(c, font, Vector2(dots_x - 30.0, y), ". . . . .", DIM, fs, ca)
			_text(c, font, Vector2(dots_x + 20.0, y), right, col, fs, ca)
		y += 15.0
	# 进度条
	if _t >= T_BAR:
		var k := clampf((_t - T_BAR) / (T_BAR_END - T_BAR), 0.0, 1.0)
		# 走走停停，像真在读盘
		var shown := floorf(k * 24.0 + sin(k * 9.0) * 1.5) / 24.0
		shown = clampf(shown, 0.0, 1.0)
		var bx := x0
		var by := H - 74.0
		var bw := W - x0 * 2.0
		c.draw_rect(Rect2(bx - 2, by - 2, bw + 4, 12), DIM, false, 1.0)
		var cells := 40
		for i in int(shown * cells):
			c.draw_rect(Rect2(bx + i * bw / cells + 1, by + 1, bw / cells - 2, 6), AMBER if i % 8 != 7 else AMBER.lightened(0.3))
		_text(c, font, Vector2(bx, by + 22), "%s  %d%%" % [tr("Rewinding to the last good frame"), int(shown * 100.0)], DIM, fs, ca)
	# 底下一行彩蛋 + 闪烁光标
	if _t >= 1.3:
		var cur := "_" if int(_t * 3.0) % 2 == 0 else ""
		_text(c, font, Vector2(x0, H - 34.0), tr("Press DEL to remember") + "  " + cur, DIM.darkened(0.25), fs, ca)


## 三层字：红、青往两边错开 ca 像素（串色），中间原色
func _text(c: Control, font: Font, pos: Vector2, s: String, col: Color, fs: int, ca: float) -> void:
	var off := maxf(ca, 0.6)
	c.draw_string(font, pos + Vector2(-off, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.2, 0.25, 0.45 * col.a))
	c.draw_string(font, pos + Vector2(off, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.2, 0.9, 1.0, 0.45 * col.a))
	c.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## 右上角的小电视图标：一台显像管电视，屏幕里一道横扫的亮线
func _draw_logo(c: Control, at: Vector2) -> void:
	c.draw_rect(Rect2(at, Vector2(44, 32)), AMBER.darkened(0.55))
	c.draw_rect(Rect2(at + Vector2(3, 3), Vector2(30, 24)), BG.lightened(0.08))
	var sy := fposmod(_t * 30.0, 22.0)
	c.draw_rect(Rect2(at + Vector2(4, 4 + sy), Vector2(28, 2)), Color(0.6, 0.9, 1.0, 0.6))
	c.draw_rect(Rect2(at + Vector2(36, 6), Vector2(5, 5)), AMBER.darkened(0.3))
	c.draw_rect(Rect2(at + Vector2(36, 14), Vector2(5, 5)), AMBER.darkened(0.3))
	c.draw_rect(Rect2(at + Vector2(37, 24), Vector2(3, 2)), Color(1.0, 0.3, 0.25))
	c.draw_line(at + Vector2(14, 0), at + Vector2(6, -9), DIM, 1.0)
	c.draw_line(at + Vector2(28, 0), at + Vector2(36, -8), DIM, 1.0)


## 显像管的质感：隔行扫描线、四角压暗的圆角、偶尔一条滚过去的亮带
func _draw_crt(c: Control) -> void:
	for yy in range(0, int(H), 2):
		c.draw_rect(Rect2(0, yy, W, 1), Color(0, 0, 0, 0.22))
	var band := fposmod(_t * 70.0, H + 60.0) - 30.0
	c.draw_rect(Rect2(0, band, W, 18), Color(0.7, 0.85, 1.0, 0.035))
	for i in 6:
		var a := 0.12 - i * 0.018
		c.draw_rect(Rect2(i * 2, i * 2, W - i * 4, H - i * 4), Color(0, 0, 0, a), false, 2.0)
	for corner in [Vector2(0, 0), Vector2(W, 0), Vector2(0, H), Vector2(W, H)]:
		var sx := 1.0 if corner.x == 0.0 else -1.0
		var sy := 1.0 if corner.y == 0.0 else -1.0
		for k in 7:
			c.draw_rect(Rect2(corner.x + (0.0 if sx > 0 else -(7 - k)), corner.y + (k if sy > 0 else -k - 1), 7 - k, 1), Color.BLACK)
