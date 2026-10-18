class_name CreditsMenu
extends Control
## 制作人员（开始菜单的"制作人员"）。作者 10-18 要的：照 Linger 的片尾（Linger/linger_bilibili/Shared/credits_roll.gd）
## 做成电影片尾的样子：黑底，一页一页地出现，每页的字一行一行慢慢淡入，停一会儿再淡出，胶片往前拉一格换下一页。
## 背景是老电影胶片（作者 10-18："一律采用本来就有的电影胶卷特效，就像第二个关卡开头一样"）：
## 整屏是放映出来的一格胶片，上下两条齿孔带，画面忽明忽暗、上下微抖、有划痕和灰点；
## 开头先放第二关开场的 3、2、1 片头（直接用 art/levels/level2_intro_leader.png，不多一张图），
## 每换一页，放映机把胶片往前拉一格（横着卷过去）。闪烁、抖动只作用在胶片上，字不跟着闪，保证清楚。
## 每格胶片里放一张游戏里现成的图（作者 10-18："只有胶片还是太单调了，配上一些画面，用本来就有的美术素材"）：
## SLIDES 的 picture，压成棕褐色（_sepia_shader）、跟着胶片一起闪，很慢地平移；怪物播它自己的待机帧。
## 全是现成的图（load 工程里已有的贴图）加画矩形，包体不变。
## 环境声换成空旷的风加很远的炉火（Ambience.override = "credits"）。
## 署名照作者 10-18 凌晨定的全文（监督会话转来）：
##   1 木木：导演 程序 光影 特效      2 奥斯卡：策划 动画 场景设计 画风设计
##   3 梧桐：立绘                     4 本2兔、Rouri：音乐
##   5 工具与协作：Godot、Claude、小奥斯卡（作者："小奥斯卡算是一个工具，写到最后的claude那一页"）
##   6：制作于 2026 年 10 月，底下小字：制作工具、字体和 Godot 的授权。按 L / 手柄 Y / 点小字看授权全文
## 确认键 / 鼠标左键：跳到下一页；Esc / B / 右键：直接回开始菜单。放完自己回去。
## 用法照旧：var page := CreditsMenu.new(); 加到 UI 层; await page.closed（关掉时自己 queue_free）。
## 名字的中英文写法照 Linger（NAMES）；本2兔、小奥斯卡 Linger 里没有，先这样写，等作者确认（见报告）。

signal closed

## 像素字是 11 像素一格：只有 11 / 22 / 33 号是清楚的
const SMALL := 11
const NAME := 22
const BIG := 33
const ROW := {11: 15.0, 22: 28.0, 33: 40.0}
const HEAD_COLOR := Color(0.62, 0.6, 0.58)
const ROLE_COLOR := Color(0.78, 0.76, 0.73)
const FOOT_COLOR := Color(0.46, 0.44, 0.42)
const SCREEN := Vector2(480, 270)

const BLACK_IN := 1.0      # 开始界面上盖下黑
const FIRST_WAIT := 0.8    # 黑了以后先空一会儿
const LINE_IN := 0.9       # 每一行淡入
const LINE_GAP := 0.35     # 下一行比上一行晚这么久
const HOLD := 4.5          # 字全出来以后停多久
const WORDS_OUT := 0.7
const BETWEEN := 0.8       # 两页之间留的黑
const BLOCK_GAP := 18.0    # 一页里两组之间空多少
const BOTTOM := 18.0       # 最后一页的小字离底边

## 胶片
const LEADER := preload("res://art/levels/level2_intro_leader.png")  # 第二关开场的倒数片头：6 列 × 3 行，每格 160×90
const LEADER_T := 0.9      # 3、2、1 各 0.3 秒
const BAND := 14.0         # 上下齿孔带的高
const GAP := 24.0          # 两格画面之间的黑条
const PITCH := 480.0 + GAP # 往前拉一格走多远
const HOLE := Vector2(8, 5)
const HOLE_STEP := 24.0
const ROLL := 0.55         # 拉一格用多久
const FILM_BASE := Color(0.085, 0.062, 0.046)   # 放映出来的画面底色：很暗的暖棕，字在上面清楚
const FILM_GLOW := Color(0.85, 0.6, 0.35, 0.03) # 中间亮一点（一圈圈叠，像放映机的光斑）
const FILM_BAND := Color(0.12, 0.088, 0.064)
const FILM_HOLE := Color(0.42, 0.35, 0.26)
const PICTURE_BRIGHT := 0.5  # 画面压暗到一半，字在上面清楚

## 每个名字在各语言里的写法（只有写法不同的才写）。照 Linger 的 credits_roll.gd / title.gd
const NAMES := {
	"Mumu": {"zh": "木木"},
	"Oscar": {"zh": "Zpbrqols"},
	"Little Oscar": {"zh": "小奥斯卡"},
	"Wutong": {"zh": "梧桐"},
	"Ben2tu": {"en": "本2兔", "zh": "本2兔"},
	"Rouri": {},
}

## 每页：blocks = 一组一组的 [小标题（可以空着）, 名字们, 职能们]，竖着排在屏幕中间；颜色是名字的颜色（Linger 里各人的颜色）。
## big：一行大字代替小标题和名字。then：底下一行一行的小字。hold：这页停多久（默认 HOLD）
const SLIDES := [
	{"blocks": [{"head": "", "names": ["Mumu"], "color": "39e47a",
		"roles": ["Director / Programming / Lighting / VFX"]}],
		# 第一关的背景层，前后层走得快慢不一样（视差）。原图很暗，gain 把它提亮
		"gain": 2.6,
		"picture": [
			{"tex": "res://art/levels/scene1_far.png", "pos": Vector2(-300, -160), "vel": Vector2(-3, 0)},
			{"tex": "res://art/levels/scene1_truss.png", "pos": Vector2(-300, -160), "vel": Vector2(-5, 0)},
			{"tex": "res://art/levels/scene1_machines.png", "pos": Vector2(-300, -160), "vel": Vector2(-7, 0)},
			{"tex": "res://art/levels/scene1_beams.png", "pos": Vector2(-300, -160), "vel": Vector2(-8, 0)},
			{"tex": "res://art/levels/scene1.png", "pos": Vector2(-300, -160), "vel": Vector2(-9, 0)},
		]},
	{"blocks": [{"head": "", "names": ["Oscar"], "color": "c8b83b",
		"roles": ["Game Design / Animation / Environment Design / Art Direction"]}], "hold": 5.0,
		# 他画的开场：机器垒满的那一格
		"gain": 1.9,
		"picture": [{"tex": "res://art/intro/14.png", "pos": Vector2(0, -4), "vel": Vector2(0, -2)}]},
	{"blocks": [{"head": "", "names": ["Wutong"], "color": "e08638", "roles": ["Portraits"]}], "dy": 52.0,
		# 她画的三张对话框立绘，偶尔眨一下眼；字往下挪，给立绘留地方
		"picture": [
			{"tex": "res://art/chars/red_portrait.png", "alt": "res://art/chars/red_portrait_blink.png", "blink": 2.9, "pos": Vector2(72, 8)},
			{"tex": "res://art/chars/robot_portrait.png", "alt": "res://art/chars/robot_portrait_blink.png", "blink": 3.7, "pos": Vector2(192, 8)},
			{"tex": "res://art/chars/dino_portrait.png", "alt": "res://art/chars/dino_portrait_blink.png", "blink": 3.3, "pos": Vector2(312, 8)},
		]},
	{"blocks": [{"head": "", "names": ["Ben2tu", "Rouri"], "color": "3bbcc8", "roles": ["Music"]}],
		# 第一关 Boss 的锅炉房，放大两倍慢慢横移
		"gain": 2.4,
		"picture": [
			{"tex": "res://art/boss/room_bg.png", "pos": Vector2(-120, -150), "vel": Vector2(-5, 0), "scale": 2},
			{"tex": "res://art/boss/room_fg.png", "pos": Vector2(-120, -150), "vel": Vector2(-5, 0), "scale": 2},
		]},
	{"blocks": [
		{"head": "Tools & Collaboration", "names": ["Godot Engine"], "color": "d8d4cc", "roles": []},
		{"head": "", "names": ["Claude"], "color": "d8d4cc", "roles": ["Anthropic"]},
		{"head": "", "names": ["Little Oscar"], "color": "d8d4cc", "roles": ["pixel character model"]},
	], "dy": -24.0,
		# 第一关的小怪排着队从底下走过去，播它们自己的待机帧
		"gain": 2.4,
		"picture": [
			{"tex": "res://art/enemies/crawler.png", "hf": 4, "frames": [0, 1, 2, 3], "pos": Vector2(-60, 204), "vel": Vector2(16, 0), "wrap": true, "scale": 2},
			{"tex": "res://art/enemies/kettle.png", "hf": 3, "frames": [0, 1, 2], "pos": Vector2(50, 192), "vel": Vector2(16, 0), "wrap": true, "scale": 2},
			{"tex": "res://art/enemies/flea.png", "hf": 4, "frames": [0, 1], "pos": Vector2(150, 200), "vel": Vector2(16, 0), "wrap": true, "scale": 2},
			{"tex": "res://art/enemies/shaver.png", "hf": 4, "frames": [0, 1], "pos": Vector2(250, 216), "vel": Vector2(16, 0), "wrap": true, "scale": 2},
			{"tex": "res://art/enemies/moth.png", "hf": 3, "frames": [0, 1], "pos": Vector2(360, 176), "vel": Vector2(16, 0), "wrap": true, "scale": 2},
		]},
	{"big": "Made in October 2026", "sub": "for Ludum Dare 60  /  Old Tech", "color": "d8d4cc", "hold": 7.0,
		# 结局的家
		"picture": [{"tex": "res://art/boss/hometown.png", "pos": Vector2(18, -2), "vel": Vector2(0, -0.4)}],
		"then": [
			["Built with", "Godot Engine / Aseprite / Claude"],
			["Engine", "Godot Engine, MIT License"],
			["Font", "Uranus Pixel 11Px, GPL v2 + font exception"],
		]},
]

var _black: ColorRect
var _film: Control
var _pics: Control        # 每格胶片里的画面（Picture），跟着胶片走
var _film_top: Control    # 盖在画面上的划痕、灰点、齿孔带
var _words: Control
var _lines: Array[Label] = []
var _hint: Label
var _license_hint: Label
var _license: Control
var _skip := false
var _leaving := false
var _last := false
var _roll := 0.0          # 胶片一共往前拉了多少像素
var _leader_t := -1.0     # 片头放到第几秒（< 0 是还没开始）
var _flick := 1.0
var _flick_t := 0.0
var _weave := 0.0
var _scratch: Array = []
var _dust: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = SCREEN
	mouse_filter = Control.MOUSE_FILTER_STOP
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.size = SCREEN
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.modulate.a = 0.0
	add_child(_black)
	_film = Control.new()
	_film.size = SCREEN
	_film.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_film.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_film.modulate.a = 0.0
	_film.draw.connect(_draw_film)
	add_child(_film)
	_pics = Control.new()
	_pics.size = SCREEN
	_pics.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_film.add_child(_pics)
	_film_top = Control.new()
	_film_top.size = SCREEN
	_film_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_film_top.draw.connect(_draw_film_top)
	_film.add_child(_film_top)
	_words = Control.new()
	_words.size = SCREEN
	_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_words)
	# 第一页时底下一行很淡的按键说明，过几秒自己淡掉
	_hint = _label(tr("%s next    %s back") % [Controls.label("confirm"), Controls.label("back")], SMALL, FOOT_COLOR,
			SCREEN.y - BOTTOM - ROW[SMALL], self)
	Ambience.override = "credits"
	_play()


func _exit_tree() -> void:
	Ambience.override = ""


func _process(delta: float) -> void:
	if _leader_t >= 0.0:
		_leader_t += delta
	# 老胶片：每 0.05~0.1 秒换一次亮度、上下抖一格、划痕和灰点（和第二关开场 level2_intro.gd 一样的做法，淡一些）
	_flick_t -= delta
	if _flick_t <= 0.0:
		_flick_t = randf_range(0.05, 0.1)
		_flick = 1.0 - randf() * 0.12
		if randf() < 0.05:
			_flick = 0.8
		_weave = 0.0 if randf() < 0.8 else (1.0 if randf() < 0.5 else -1.0)
		_scratch.clear()
		for i in randi() % 3:
			_scratch.append(Vector3(randi() % 480, BAND + randi() % 100, 40 + randi() % 140))
		_dust.clear()
		for i in randi() % 5:
			_dust.append(Vector2(randi() % 480, BAND + randi() % int(SCREEN.y - BAND * 2.0 - 2.0)))
	for pic: Picture in _pics.get_children():
		pic.position = Vector2(roundf(pic.frame * PITCH - _roll), BAND + _weave)
		pic.modulate = Color(_flick * pic.gain, _flick * pic.gain, _flick * pic.gain)
	_film.queue_redraw()
	_film_top.queue_redraw()


func _draw_film() -> void:
	var k := _flick
	var top := BAND + _weave
	var h := SCREEN.y - BAND * 2.0
	_film.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color.BLACK)
	# 屏幕上能看到的那一两格画面（第 n 格在 n * PITCH - _roll）
	var first := floori(_roll / PITCH)
	for n in range(first, first + 2):
		var x := roundf(n * PITCH - _roll)
		if x >= SCREEN.x or x + PITCH <= 0.0:
			continue
		_film.draw_rect(Rect2(x, top, SCREEN.x, h), Color(FILM_BASE.r * k, FILM_BASE.g * k, FILM_BASE.b * k))
		# 放映机的光斑：几层椭圆叠起来，每 6 像素一行（方方的台阶，保持像素感）
		var c := Vector2(x + SCREEN.x * 0.5, top + h * 0.5)
		for r in 4:
			var rx := 230.0 - r * 44.0
			var ry := 112.0 - r * 24.0
			var yy := -ry
			while yy < ry:
				var hw := roundf(rx * sqrt(maxf(0.0, 1.0 - pow((yy + 3.0) / ry, 2.0))))
				_film.draw_rect(Rect2(c.x - hw, roundf(c.y + yy), hw * 2.0, 6.0), FILM_GLOW)
				yy += 6.0
		# 第 0 格是片头：3、2、1，各 0.3 秒，每个数字 6 张扇形
		if n == 0 and _leader_t >= 0.0:
			var d := mini(int(_leader_t / 0.3), 2)
			var f := mini(int(fmod(minf(_leader_t, LEADER_T - 0.001), 0.3) / 0.3 * 6.0), 5)
			_film.draw_texture_rect_region(LEADER, Rect2(x, _weave * 3.0, SCREEN.x, SCREEN.y), Rect2(f * 160, d * 90, 160, 90),
					Color(k, k * 0.98, k * 0.94))


func _draw_film_top() -> void:
	var k := _flick
	# 划痕和灰点只在画面里
	for sc in _scratch:
		_film_top.draw_rect(Rect2(sc.x, sc.y + _weave, 1, sc.z), Color(1.0, 0.95, 0.85, 0.14))
	for p in _dust:
		_film_top.draw_rect(Rect2(p + Vector2(0, _weave), Vector2(2, 2)), Color(0.02, 0.012, 0.008, 0.55))
	# 上下齿孔带：齿孔跟着胶片走
	var band := Color(FILM_BAND.r * k, FILM_BAND.g * k, FILM_BAND.b * k)
	var hole := Color(FILM_HOLE.r * k, FILM_HOLE.g * k, FILM_HOLE.b * k)
	for y: float in [0.0, SCREEN.y - BAND]:
		_film_top.draw_rect(Rect2(0, y, SCREEN.x, BAND), band)
		var hx := -fposmod(_roll, HOLE_STEP) + 8.0
		while hx < SCREEN.x:
			_film_top.draw_rect(Rect2(roundf(hx), y + roundf((BAND - HOLE.y) * 0.5), HOLE.x, HOLE.y), hole)
			hx += HOLE_STEP


## 放映机把胶片往前拉一格：慢起慢停，中间快
func _advance() -> void:
	var from := _roll
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _roll = v, from, from + PITCH, ROLL).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


func _play() -> void:
	await _fade(_black, 1.0, BLACK_IN)
	await _fade(_film, 1.0, 0.4)
	_leader_t = 0.0
	await _wait(LEADER_T + 0.15, false)
	for i in SLIDES.size():
		if _leaving:
			return
		_last = i == SLIDES.size() - 1
		# 下一格胶片带着这页的画面卷进来，再出字
		_add_picture(SLIDES[i], i + 1)
		await _advance()
		for pic: Picture in _pics.get_children():
			if pic.frame < i + 1:
				pic.queue_free()
		await _wait(FIRST_WAIT * 0.5 if i == 0 else BETWEEN * 0.25, false)
		if i == 0:
			_fade(_hint, 0.7, 1.0)
		await _show(SLIDES[i])
		if i == 0:
			_fade(_hint, 0.0, 1.0)
	_close(false)


func _show(slide: Dictionary) -> void:
	_build(slide)
	for i in _lines.size():
		var l := _lines[i]
		var tw := l.create_tween()
		tw.tween_interval(i * LINE_GAP)
		tw.tween_property(l, "modulate:a", 1.0, LINE_IN)
	await _wait((_lines.size() - 1) * LINE_GAP + LINE_IN, true)
	if _skip:
		for l in _lines:
			l.modulate.a = 1.0
	await _wait(slide.get("hold", HOLD), true)
	await _fade(_words, 0.0, WORDS_OUT)
	await _wait(BETWEEN * 0.25, false)


func _add_picture(slide: Dictionary, frame: int) -> void:
	if not slide.has("picture"):
		return
	var pic := Picture.new()
	pic.frame = frame
	pic.items = slide["picture"]
	pic.gain = slide.get("gain", 1.0)
	pic.size = Vector2(SCREEN.x, SCREEN.y - BAND * 2.0)
	pic.position = Vector2(roundf(frame * PITCH - _roll), BAND)
	_pics.add_child(pic)


## 这一页的字：都先透明，_show 里一行一行淡出来
func _build(slide: Dictionary) -> void:
	for c in _words.get_children():
		c.queue_free()
	_lines.clear()
	_license_hint = null
	_words.modulate.a = 1.0
	var col := Color(slide.get("color", "d8d4cc"))
	var rows: Array = []   # [文字, 字号, 颜色] 或 null（组之间的空）
	if slide.has("big"):
		rows.append([tr(slide["big"]), BIG, col])
		rows.append([tr(slide["sub"]), SMALL, HEAD_COLOR])
	for b: Dictionary in slide.get("blocks", []):
		if not rows.is_empty():
			rows.append(null)
		if b["head"] != "":
			rows.append([tr(b["head"]), SMALL, HEAD_COLOR])
		rows.append([_names(b["names"]), NAME, Color(b["color"])])
		for r: String in b["roles"]:
			rows.append([tr(r), SMALL, ROLE_COLOR])
	var height := 0.0
	for r in rows:
		height += BLOCK_GAP if r == null else ROW[r[1]]
	var foot: Array = slide.get("then", [])
	# 有小字的页，大字整体往上挪一点，给底下的小字留地方
	var top := roundf((SCREEN.y - height) * 0.5 - (ROW[SMALL] * (foot.size() + 1) * 0.5 if not foot.is_empty() else 0.0))
	top += slide.get("dy", 0.0)
	var y := top
	for r in rows:
		if r == null:
			y += BLOCK_GAP
			continue
		_lines.append(_label(r[0], r[1], r[2], y))
		y += ROW[r[1]]
	y = SCREEN.y - BOTTOM - ROW[SMALL] * (foot.size() + 1)
	for f: Array in foot:
		_lines.append(_label(tr(f[0]) + "   " + tr(f[1]), SMALL, FOOT_COLOR, y))
		y += ROW[SMALL]
	if not foot.is_empty():
		_license_hint = _label(tr("%s full license text") % _license_key(), SMALL, HEAD_COLOR, y)
		_lines.append(_license_hint)


func _label(text: String, font_size: int, color: Color, y: float, parent: Node = null) -> Label:
	var l := Label.new()
	var st := Hud.small_text(color)
	st.font_size = font_size
	st.outline_size = 0
	st.shadow_color = Color(0, 0, 0, 0.85)
	st.shadow_offset = Vector2.ONE * (font_size / SMALL)
	l.label_settings = st
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, roundf(y))
	l.size = Vector2(SCREEN.x, ROW[font_size])
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.0
	(parent if parent else _words).add_child(l)
	return l


func _names(names: Array) -> String:
	var shown: PackedStringArray = []
	var lang := "zh" if Lang.is_zh() else "en"
	for who: String in names:
		shown.append(NAMES.get(who, {}).get(lang, who))
	return "   ".join(shown)


func _license_key() -> String:
	return "Y" if Controls.using_pad else "L"


func _fade(item: CanvasItem, to: float, time: float) -> void:
	var tw := item.create_tween()
	tw.tween_property(item, "modulate:a", to, time)
	await tw.finished


## 等 seconds 秒；skippable 时按确认 / 点一下就提前结束。看授权全文的时候不走
func _wait(seconds: float, skippable: bool) -> void:
	_skip = false
	var left := seconds
	while (left > 0.0 or is_instance_valid(_license)) and not _leaving:
		if skippable and _skip:
			break
		await get_tree().process_frame
		if not is_instance_valid(_license):
			left -= get_process_delta_time()
	if not skippable:
		_skip = false


func _input(event: InputEvent) -> void:
	if _leaving or is_instance_valid(_license):
		return
	var handled := true
	if event.is_action_pressed("ui_cancel") \
			or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE) \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		_close()
	elif _last and _license_hint != null and (
			(event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_L)
			or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y)
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
				and Rect2(_license_hint.position, _license_hint.size).grow(3).has_point(get_local_mouse_position()))):
		_open_license()
	elif event.is_action_pressed("ui_accept") \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		_skip = true
	elif event is InputEventMouseMotion and _license_hint != null:
		handled = false
		var over := Rect2(_license_hint.position, _license_hint.size).grow(3).has_point(get_local_mouse_position())
		_license_hint.label_settings.font_color = UiStyle.WARM if over else HEAD_COLOR
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _open_license() -> void:
	Game.sfx("ui_confirm", -8.0)
	_license = LicensePage.new()
	add_child(_license)


## sound = false：放完了自己回去，不响返回声
func _close(sound := true) -> void:
	if _leaving:
		return
	_leaving = true
	if sound:
		Game.sfx("ui_back", -8.0)
	Ambience.override = ""
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	await tw.finished
	closed.emit()
	queue_free()


## 授权全文：Godot 的 MIT 原文 + 引擎自带的第三方组件清单（Engine.get_copyright_info）+ 字体的 GPL 说明。
## 上下 / 滚轮滚动，Esc / B / 确认 / 点一下回到片尾。样式和设置界面一样（UiStyle 卡片）
class LicensePage extends Control:
	const LINE := 15.0
	const BODY := Rect2(36, 54, 408, 15.0 * 11)

	var _scroll := 0.0
	var _body: Label
	var _frame: Control
	var _ready_for_input := false

	func _ready() -> void:
		size = Vector2(480, 270)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var back := ColorRect.new()
		back.color = Color(0.02, 0.02, 0.035)
		back.size = size
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(back)
		_frame = Control.new()
		_frame.size = size
		_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frame.draw.connect(func() -> void:
			UiStyle.panel(_frame, BODY.grow(6), false, 0.0)
			if _scroll < _max_scroll() - 0.5:
				var tip := Vector2(BODY.end.x - 2, BODY.end.y + 2)
				for y in 3:
					for x in range(y, 5 - y):
						_frame.draw_rect(Rect2(tip + Vector2(x - 2, y - 2), Vector2.ONE), UiStyle.WARM))
		add_child(_frame)
		var title := UiStyle.label(tr("LICENSES"), UiStyle.WARM, Vector2(0, 18), 480, HORIZONTAL_ALIGNMENT_CENTER)
		title.label_settings.font_size = 22
		title.label_settings.outline_size = 3
		add_child(title)
		var clip := Control.new()
		clip.position = BODY.position
		clip.size = BODY.size
		clip.clip_contents = true
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(clip)
		_body = Label.new()
		_body.label_settings = Hud.small_text(UiStyle.TEXT)
		_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_body.text = _text()
		_body.size = Vector2(BODY.size.x, 0)
		clip.add_child(_body)
		_body.size.y = _body.get_minimum_size().y
		var hint := UiStyle.label(tr("%s scroll    %s back") % [Controls.label("scroll"), Controls.label("back")], UiStyle.DIM,
				Vector2(0, 246), 480, HORIZONTAL_ALIGNMENT_CENTER)
		add_child(hint)
		await get_tree().process_frame
		_ready_for_input = true

	func _text() -> String:
		var names: PackedStringArray = []
		for c in Engine.get_copyright_info():
			names.append(str(c["name"]))
		return "Godot Engine\n\n" + Engine.get_license_text() + "\n\n" \
			+ tr("Godot also includes these third-party components, each under its own license:") + "\n" \
			+ ", ".join(names) + "\n\n" \
			+ "Uranus Pixel 11Px / WenQuanYi Bitmap Song\n" \
			+ tr("GNU General Public License v2, with the font embedding exception: embedding the font in a document or game does not by itself make that work covered by the GPL.")

	func _max_scroll() -> float:
		return maxf(0.0, ceilf((_body.size.y - BODY.size.y) / LINE) * LINE)

	func _apply() -> void:
		_scroll = clampf(_scroll, 0.0, _max_scroll())
		_body.position.y = -roundf(_scroll)
		_frame.queue_redraw()

	func _input(event: InputEvent) -> void:
		if not _ready_for_input:
			return
		var handled := true
		if event.is_action_pressed("ui_down", true):
			_scroll += LINE
			_apply()
		elif event.is_action_pressed("ui_up", true):
			_scroll -= LINE
			_apply()
		elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP]:
			_scroll += LINE * (1.0 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1.0)
			_apply()
		elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept") \
				or (event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]) \
				or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ESCAPE, KEY_L]) \
				or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y):
			_ready_for_input = false
			Game.sfx("ui_back", -8.0)
			queue_free()
		else:
			handled = false
		if handled:
			get_viewport().set_input_as_handled()


## 一格胶片里的画面：items 是一张张现成的图，{tex, pos（左上角，相对这一格）, vel（每秒走几像素）, scale（整数倍）,
## hf + frames（横排的帧，按 6 帧/秒播）, wrap（走出去从另一边回来）, alt + blink（每隔 blink 秒换成 alt 闪一下，眨眼）}。
## 整格用棕褐色着色器压暗，像老电影；原图本来就暗的页面用 SLIDES 的 gain 提亮。
class Picture extends Control:
	static var _material: ShaderMaterial

	var frame := 0
	var gain := 1.0   # 画面原来就暗的提亮几倍（乘在 modulate 上，着色器里再压到 PICTURE_BRIGHT）
	var items: Array = []
	var _tex: Array = []
	var _alt: Array = []
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if _material == null:
			_material = ShaderMaterial.new()
			_material.shader = Shader.new()
			_material.shader.code = """
shader_type canvas_item;
uniform float bright = 0.5;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	COLOR = vec4(vec3(l * 1.08, l * 0.86, l * 0.6) * bright, c.a);
}
"""
			_material.set_shader_parameter("bright", PICTURE_BRIGHT)
		material = _material
		for it: Dictionary in items:
			_tex.append(load(it["tex"]))
			_alt.append(load(it["alt"]) if it.has("alt") else null)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		for i in items.size():
			var it: Dictionary = items[i]
			var tex: Texture2D = _tex[i]
			if _alt[i] != null and fmod(_t, it["blink"]) > it["blink"] - 0.15:
				tex = _alt[i]
			var k: int = it.get("scale", 1)
			var hf: int = it.get("hf", 1)
			var fw := tex.get_width() / hf
			var src := Rect2(0, 0, fw, tex.get_height())
			if hf > 1:
				var frames: Array = it.get("frames", [0])
				src.position.x = int(frames[int(_t * 6.0) % frames.size()]) * fw
			var p: Vector2 = it["pos"] + it.get("vel", Vector2.ZERO) * _t
			if it.get("wrap", false):
				p.x = fposmod(p.x + fw * k, size.x + fw * k * 2.0) - fw * k
			draw_texture_rect_region(tex, Rect2(p.round(), src.size * k), src)
