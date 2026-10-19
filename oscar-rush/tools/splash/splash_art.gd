extends Node2D
## ⚠ 10-19 晚起 art/ui/boot_splash.png 改由 tools/splash/make_splash.py 画（作者挑的封面 A6 的 16:9 版）；这里是之前的空胶片版，留着备用。
## 启动画面（art/ui/boot_splash.png：Godot 的启动画面、网页加载页的底图、网页版"点击开始"那张，三处同一张）。
## 10-19 作者："加载界面不就一张吗？……你直接把电影无内容的胶卷放上去不就行了"：
## 黑底上横过一条空胶片，上下齿孔带，格子里是暗的胶片底色（和序章、制作人员页同一套颜色），中间那格亮一点、写游戏名。
## 网页加载页的进度条在胶片下面（shell.html 的 #status-bar，离底 14%），"点击开始"的字也在胶片下面（intro.gd 的 _prompt）。
## 重画：见 render_splash.gd

const BG := Color8(8, 8, 10)
const FILM_BASE := Color(0.085, 0.062, 0.046)
const FILM_BAND := Color(0.12, 0.088, 0.064)
const FILM_HOLE := Color(0.42, 0.35, 0.26)
const GAP_COLOR := Color(0.03, 0.022, 0.016)
## 胶片的上沿、下沿（游戏像素，画面 480×270）
const TOP := 62.0
const BOTTOM := 208.0
const BAND := 14.0
const HOLE := Vector2(8, 5)
const HOLE_STEP := 24.0
## 中间那格（写名字的），两边各露半格
const FRAME_W := 232.0
const GAP := 4.0


func _ready() -> void:
	_label("REWIND RUSH", 98.0, 33, Hud.WARM, 4)
	_label("LUDUM DARE 60  /  OLD TECH", 140.0, 11, Hud.DIM, 2)


func _label(text: String, y: float, size: int, color: Color, outline: int) -> void:
	var l := Label.new()
	var st := Hud.small_text(color)
	st.font_size = size
	st.outline_size = outline
	st.outline_color = FILM_BASE.darkened(0.5)
	l.label_settings = st
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, y)
	l.size = Vector2(480, size + 6)
	add_child(l)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 480, 270), BG)
	var inner := Rect2(0, TOP + BAND, 480, BOTTOM - TOP - BAND * 2.0)
	# 格子：中间一格居中，往两边每格 FRAME_W + GAP 排开；两边的格子暗一点，像放映机的光只打在中间
	var x0 := 240.0 - FRAME_W * 0.5
	for i in range(-2, 3):
		var fx := x0 + i * (FRAME_W + GAP)
		var k := 1.0 if i == 0 else 0.72
		draw_rect(Rect2(fx, inner.position.y, FRAME_W, inner.size.y), Color(FILM_BASE.r * k, FILM_BASE.g * k, FILM_BASE.b * k))
		draw_rect(Rect2(fx + FRAME_W, inner.position.y, GAP, inner.size.y), GAP_COLOR)
	# 中间那格一圈圈叠一点暖光（和制作人员页的光斑一样淡）
	var c := Vector2(240, inner.get_center().y)
	for r in 6:
		var hw := FRAME_W * 0.5 - 8.0 - r * 14.0
		var hh := inner.size.y * 0.5 - 6.0 - r * 8.0
		if hw > 0.0 and hh > 0.0:
			draw_rect(Rect2(c.x - hw, c.y - hh, hw * 2.0, hh * 2.0), Color(0.85, 0.6, 0.35, 0.025))
	# 几道划痕、几个灰点（固定的，不随机，每次重画都一样）
	for sc in [Vector3(171, 80, 26), Vector3(318, 118, 40), Vector3(92, 132, 18), Vector3(407, 90, 30)]:
		draw_rect(Rect2(sc.x, sc.y, 1, sc.z), Color(1.0, 0.95, 0.85, 0.08))
	for p in [Vector2(146, 170), Vector2(301, 92), Vector2(352, 176), Vector2(60, 104), Vector2(430, 160)]:
		draw_rect(Rect2(p, Vector2(2, 2)), Color(0.02, 0.012, 0.008, 0.6))
	# 上下齿孔带
	for y: float in [TOP, BOTTOM - BAND]:
		draw_rect(Rect2(0, y, 480, BAND), FILM_BAND)
		var hx := 8.0
		while hx < 480.0:
			draw_rect(Rect2(hx, y + roundf((BAND - HOLE.y) * 0.5), HOLE.x, HOLE.y), FILM_HOLE)
			hx += HOLE_STEP
