class_name IntroOverlay
extends CanvasLayer
## 开场动画（Oscar 画的 开场动画.aseprite），叠在开始界面最上面播：
## 前半段是黑底，零件、木桶一层层盖满屏幕，喷一股蒸汽；从 OPEN_FRAME 起中间裂开往两边打开，
## 这时才撤掉黑底，透明的地方露出底下已经摆好的菜单。
## 开始界面在 _ready 里加它，游戏打开只播一次；播完或跳过发 finished，菜单这才能操作。
## 帧是 tools/export_art.py --intro 导出的 art/intro/00.png ……；按任意键、点鼠标、按手柄键跳过。

signal finished

const FRAME_DIR := "res://art/intro/%02d.png"
## 每帧多少秒，照原稿抄的。Oscar 改了帧数或时长，重导以后对着改这里
const DURATIONS: Array[float] = [
	0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1,
	0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1,
	0.1, 0.1, 0.5, 0.1, 0.1, 0.1, 0.1, 0.3,
]
## 第 22 帧喷出一大股蒸汽（原稿里停 0.5 秒的那帧）
const STEAM_FRAME := 22
## 从这帧起开始"打开"（第 18~22 帧整屏盖满，23 帧中间裂开），之前透明的地方是黑的
const OPEN_FRAME := 23

## 本次运行播过没有；从关卡回到开始界面不再播
static var played := false
## 开始界面还播不播奥斯卡的开场帧。10-18 起这段改到第一关开场播（Level1Opening + LevelIntro），
## 开始界面默认不播，打开游戏直接是菜单；网页版照样先停在"点击或按任意键"（浏览器要等这一下才放声音）。
## 作者想在开始界面也留着，把它改成 true
const FRAMES_ON_TITLE := false

# —— 开游戏的片头（10-18 作者："点击小三角运行游戏，这个也是有动画的"，奥斯卡那段挪到第一关以后开头太突兀）——
## 老电视开机（10-19 作者：开游戏的片头和新开一局的胶片序章重复了，都是 3、2、1 倒数；序章留着胶片，这里换成电视）：
## 黑屏中间先亮一个点 → 拉成一条横线 → 上下撑开成整屏，露出开始界面 → 雪花、扫描线、滚动的亮条慢慢退掉，
## 标题 SCRAP RUSH 像信号对上那样闪几下亮起来，菜单其余的字最后淡出来。约 2 秒，任意键、点击、Start 跳过。
## 开始界面在 add_child 之前把标题 Label 交给 title_node，其余要后出来的交给 rest_nodes
const T_DOT := 0.3         # 中间的亮点
const T_LINE := 0.2        # 拉成横线
const T_OPEN := 0.3        # 上下撑开
const T_STATIC := 1.1      # 雪花退掉
const TV_WHITE := Color(0.92, 0.95, 1.0)
## 标题闪亮起来的节奏：[到这个时刻（从撑开整屏算，秒）, 透明度]
const TITLE_FLICKER := [[0.0, 0.0], [0.12, 0.85], [0.18, 0.15], [0.3, 1.0], [0.38, 0.4], [0.5, 1.0]]

var title_node: CanvasItem
var rest_nodes: Array = []
var _film: Control
var _film_t := -1.0
var _last_digit := -1

var _frames: Array[Texture2D] = []
var _sprite: Sprite2D
var _black: ColorRect
var _index := 0
var _time := 0.0
var _done := false
## 网页版：先停在和加载页一样的画面上，写"点击或按任意键"，玩家按了才开始播。
## 浏览器要等玩家第一次点击 / 按键才放声音，不等的话开场的蒸汽声会被吞掉；这一下也让后面的全屏切换能用
var _waiting := false
var _prompt: Label
var _splash: Sprite2D


func _ready() -> void:
	played = true
	# 盖在开始界面的文字（第 20 层）上面
	layer = 40
	for i in DURATIONS.size():
		_frames.append(load(FRAME_DIR % i))
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.size = Vector2(480, 270)
	add_child(_black)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture = _frames[0]
	add_child(_sprite)
	# SCRAP_WEB_PROMPT=1：桌面版也走这一步（测试、截图用）
	if OS.has_feature("web") or OS.get_environment("SCRAP_WEB_PROMPT") == "1":
		_waiting = true
		_sprite.visible = false
		_splash = Sprite2D.new()
		_splash.texture = load("res://art/ui/boot_splash.png")
		_splash.centered = false
		_splash.scale = Vector2(0.5, 0.5)
		add_child(_splash)
		# 中文模式：图里画死的副标题 "LUDUM DARE 60 / OLD TECH" 用底色盖掉，换成会翻译的字，和开始界面那行一样
		if Lang.is_zh():
			var cover := ColorRect.new()
			cover.color = Color8(8, 8, 10)
			cover.position = Vector2(164, 125)
			cover.size = Vector2(152, 13)
			add_child(cover)
			var sub := Label.new()
			sub.label_settings = Hud.small_text(Color(0.55, 0.55, 0.6))
			sub.text = "LUDUM DARE 60  /  OLD TECH"
			sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sub.position = Vector2(0, 124)
			sub.size = Vector2(480, 14)
			add_child(sub)
		_prompt = Label.new()
		var st := Hud.small_text(Hud.WARM)
		_prompt.label_settings = st
		_prompt.text = "CLICK OR PRESS ANY KEY"
		_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_prompt.position = Vector2(0, 196)
		_prompt.size = Vector2(480, 17)
		add_child(_prompt)
	if not FRAMES_ON_TITLE:
		_sprite.visible = false
		_black.visible = false
		_film = Control.new()
		_film.size = Vector2(480, 270)
		_film.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_film.draw.connect(_draw_film)
		add_child(_film)
		# 网页版的"点击开始"那张图要在胶片上面
		if _splash:
			move_child(_film, 0)
		_hide_menu_text()
		if not _waiting:
			_film_t = 0.0


func _hide_menu_text() -> void:
	if title_node:
		title_node.modulate.a = 0.0
	for n in rest_nodes:
		if is_instance_valid(n):
			n.modulate.a = 0.0


func _process(delta: float) -> void:
	if _done:
		return
	if _waiting:
		_time += delta
		_prompt.visible = fmod(_time, 1.0) < 0.65
		return
	if not FRAMES_ON_TITLE:
		_film_step(delta)
		return
	_time += delta
	while _time >= DURATIONS[_index]:
		_time -= DURATIONS[_index]
		_index += 1
		if _index >= _frames.size():
			_finish()
			return
		_sprite.texture = _frames[_index]
		_black.visible = _index < OPEN_FRAME
		if _index == STEAM_FRAME:
			Game.sfx("vent", -4.0)


func _input(event: InputEvent) -> void:
	if _done:
		return
	var pressed := (event is InputEventKey or event is InputEventMouseButton \
			or event is InputEventJoypadButton) and event.is_pressed() and not event.is_echo()
	if pressed:
		# 跳过的这一下不能顺手把菜单的 START 也按了
		get_viewport().set_input_as_handled()
		if _waiting:
			_start()
			return
		_finish()


func _start() -> void:
	if not FRAMES_ON_TITLE:
		Game.sfx("ui_confirm", -10.0)
		_waiting = false
		_splash.queue_free()
		_prompt.queue_free()
		for c in get_children():
			if c is ColorRect or (c is Label and c != _prompt):
				if c != _black:
					c.queue_free()
		_film_t = 0.0
		return
	_waiting = false
	_time = 0.0
	_splash.queue_free()
	_prompt.queue_free()
	_sprite.visible = true
	Game.sfx("ui_confirm", -10.0)


## 片头的时间轴：亮点 → 横线 → 撑开整屏 → 雪花退掉（标题闪亮）
func _film_step(delta: float) -> void:
	if _film_t < 0.0:
		return
	_film_t += delta
	var t_line := T_DOT
	var t_open := t_line + T_LINE
	var t_screen := t_open + T_OPEN
	var t_end := t_screen + T_STATIC
	if _last_digit < 0:
		_last_digit = 0
		Game.sfx("tvclick", -6.0, 0.8)
	if _film_t >= t_line and _last_digit < 1:
		_last_digit = 1
		Game.sfx("tvon", -6.0, 0.9)
	if _film_t >= t_open and _last_digit < 2:
		_last_digit = 2
		Game.sfx("static", -16.0, 1.1)
	# 标题像信号对上：照 TITLE_FLICKER 闪几下亮起来
	if _film_t >= t_screen and title_node:
		var u := _film_t - t_screen
		var a := 1.0
		for k in TITLE_FLICKER:
			if u >= float(k[0]):
				a = float(k[1])
		title_node.modulate.a = a
	if _film_t >= t_end:
		_finish()
		return
	_film.queue_redraw()


func _draw_film() -> void:
	var t_line := T_DOT
	var t_open := t_line + T_LINE
	var t_screen := t_open + T_OPEN
	var full := Rect2(0, 0, 480, 270)
	var c := Vector2(240, 135)
	if _film_t < t_line:
		# 黑屏，中间一个亮点慢慢亮起来
		_film.draw_rect(full, Color.BLACK)
		var a := clampf(_film_t / T_DOT * 1.5, 0.0, 1.0)
		_film.draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), Color(TV_WHITE, a))
		_film.draw_rect(Rect2(c - Vector2(3, 0), Vector2(6, 1)), Color(TV_WHITE, a * 0.3))
		return
	if _film_t < t_open:
		# 拉成一条横线（2 像素高）
		var u := (_film_t - t_line) / T_LINE
		var hw := roundf(lerpf(1.0, 240.0, u * u * (3.0 - 2.0 * u)))
		_film.draw_rect(full, Color.BLACK)
		_film.draw_rect(Rect2(c.x - hw, c.y - 1, hw * 2.0, 2), TV_WHITE)
		_film.draw_rect(Rect2(c.x - hw, c.y - 3, hw * 2.0, 6), Color(TV_WHITE, 0.25))
		return
	var band := 135.0
	var glow := 0.0
	if _film_t < t_screen:
		# 上下撑开：带子外面还是黑的，带子里是开始界面，整片先蒙一层白、越开越淡
		var u := (_film_t - t_open) / T_OPEN
		band = roundf(lerpf(1.0, 135.0, 1.0 - (1.0 - u) * (1.0 - u)))
		glow = lerpf(0.9, 0.35, u)
		_film.draw_rect(Rect2(0, 0, 480, c.y - band), Color.BLACK)
		_film.draw_rect(Rect2(0, c.y + band, 480, 270.0 - c.y - band), Color.BLACK)
		_film.draw_rect(Rect2(0, c.y - band, 480, 2), TV_WHITE)
		_film.draw_rect(Rect2(0, c.y + band - 2.0, 480, 2), TV_WHITE)
	else:
		glow = 0.35 * maxf(0.0, 1.0 - (_film_t - t_screen) / (T_STATIC * 0.5))
	var k := 1.0 if _film_t < t_screen else maxf(0.0, 1.0 - (_film_t - t_screen) / T_STATIC)
	var area := Rect2(0, c.y - band, 480, band * 2.0)
	if glow > 0.0:
		_film.draw_rect(area, Color(TV_WHITE, glow))
	# 雪花（2×2 的点）、扫描线、往下滚的一条亮带，跟着信号对上慢慢退掉
	for i in int(260 * k):
		var p := Vector2(randi() % 240 * 2, area.position.y + randi() % maxi(int(area.size.y / 2.0), 1) * 2)
		_film.draw_rect(Rect2(p, Vector2(2, 2)), Color(TV_WHITE, (0.25 + randf() * 0.45) * k))
	var y := area.position.y
	while y < area.end.y:
		_film.draw_rect(Rect2(0, y, 480, 1), Color(0, 0, 0, 0.22 * k))
		y += 3.0
	var roll_y := fposmod(_film_t * 160.0, 300.0) - 15.0
	_film.draw_rect(Rect2(0, maxf(roll_y, area.position.y), 480, 12), Color(TV_WHITE, 0.08 * k))


func _finish() -> void:
	_done = true
	# 跳过或放完：标题和菜单的字都亮着（其余的字由开始界面淡出来）
	if title_node and is_instance_valid(title_node):
		title_node.modulate.a = 1.0
	finished.emit()
	queue_free()
