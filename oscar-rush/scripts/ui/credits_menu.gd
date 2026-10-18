class_name CreditsMenu
extends Control
## 制作人员（开始菜单的"制作人员"）。作者 10-18 要的：照 Linger 的片尾（Linger/linger_bilibili/Shared/credits_roll.gd）
## 做成电影片尾的样子：黑底，一页一页地出现，每页的字一行一行慢慢淡入，停一会儿再淡出，中间留一段黑。
## 背后有几点很淡的火星慢慢往上飘，环境声换成空旷的风加很远的炉火（Ambience.override = "credits"）。
## 署名照作者 10-18 凌晨定的全文（监督会话转来）：
##   1 木木：导演 程序 光影 特效      2 奥斯卡：策划 动画 场景设计 画风设计
##   3 梧桐：立绘                     4 本2兔、Rouri：音乐
##   5 工具与协作：Godot、Claude、小奥斯卡（作者："小奥斯卡算是一个工具，写到最后的claude那一页"）
##   6：制作于 2026 年 10 月，底下小字：制作工具、字体和 Godot 的授权。按 L / 手柄 Y / 点小字看授权全文
## 确认键 / 鼠标左键：跳到下一页；Esc / B / 右键：直接回开始菜单。放完自己回去。
## 每页名字上面放一段游戏里录的小动画（作者 10-18："显示名字的时候播放一些动画"）：SLIDES 的 clips，
## 素材是 art/credits/ 的精灵图（CreditsClip，tools/make_credits_clips.py 拼的），一段放完一圈换下一段，跟着字一起淡入淡出。
## 素材缺了就跳过那一段，一段都没有的页面照旧只有字。
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
const CLIP_GAP := 12.0     # 动画和底下的字之间空多少
const CLIP_EDGE := Color(0.22, 0.21, 0.2)  # 动画外面一圈细边

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
		"roles": ["Director / Programming / Lighting / VFX"]}], "clips": ["mumu_hammer", "mumu_lamp", "mumu_pressure"]},
	{"blocks": [{"head": "", "names": ["Oscar"], "color": "c8b83b",
		"roles": ["Game Design / Animation / Environment Design / Art Direction"]}], "hold": 5.0,
		"clips": ["oscar_run", "oscar_elite"]},
	{"blocks": [{"head": "", "names": ["Wutong"], "color": "e08638", "roles": ["Portraits"]}],
		"clips": ["wutong_portraits"]},
	{"blocks": [{"head": "", "names": ["Ben2tu", "Rouri"], "color": "3bbcc8", "roles": ["Music"]}],
		"clips": ["music_furnace"]},
	{"blocks": [
		{"head": "Tools & Collaboration", "names": ["Godot Engine"], "color": "d8d4cc", "roles": []},
		{"head": "", "names": ["Claude"], "color": "d8d4cc", "roles": ["Anthropic"]},
		{"head": "", "names": ["Little Oscar"], "color": "d8d4cc", "roles": ["pixel character model"]},
	]},
	{"big": "Made in October 2026", "sub": "for Ludum Dare 60  /  Old Tech", "color": "d8d4cc", "hold": 7.0,
		"clips": ["finale"],
		"then": [
			["Built with", "Godot Engine / Aseprite / Claude"],
			["Engine", "Godot Engine, MIT License"],
			["Font", "Uranus Pixel 11Px, GPL v2 + font exception"],
		]},
]

var _black: ColorRect
var _embers: Control
var _words: Control
var _lines: Array[Label] = []
var _reel: Reel
var _hint: Label
var _license_hint: Label
var _license: Control
var _skip := false
var _leaving := false
var _last := false
var _sparks: Array = []
var _time := 0.0


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
	_embers = Control.new()
	_embers.size = SCREEN
	_embers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_embers.modulate.a = 0.0
	_embers.draw.connect(_draw_embers)
	add_child(_embers)
	for i in 26:
		_sparks.append(_new_spark(true))
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
	_time += delta
	for s in _sparks:
		s["p"] += s["v"] * delta
		s["life"] -= delta
		if s["life"] <= 0.0 or s["p"].y < -4.0:
			s.merge(_new_spark(false), true)
	_embers.queue_redraw()


## 一点火星：从下面三分之一随机一处出来，慢慢往上飘、左右晃，忽明忽暗
func _new_spark(anywhere: bool) -> Dictionary:
	return {
		"p": Vector2(randf_range(10, SCREEN.x - 10), randf_range(20, SCREEN.y) if anywhere else randf_range(SCREEN.y * 0.6, SCREEN.y + 4)),
		"v": Vector2(randf_range(-2.0, 2.0), -randf_range(4.0, 11.0)),
		"life": randf_range(6.0, 16.0), "phase": randf() * TAU, "warm": randf(),
	}


func _draw_embers() -> void:
	for s in _sparks:
		var a := 0.18 + 0.22 * (0.5 + 0.5 * sin(_time * 2.3 + s["phase"]))
		a *= clampf(s["life"] / 2.0, 0.0, 1.0)
		var col := Color8(255, 160, 80).lerp(Color8(255, 220, 150), s["warm"])
		var p: Vector2 = s["p"]
		p.x += sin(_time * 0.7 + s["phase"]) * 3.0
		_embers.draw_rect(Rect2(p.round(), Vector2.ONE), Color(col, a))


func _play() -> void:
	await _fade(_black, 1.0, BLACK_IN)
	_fade(_embers, 1.0, 2.0)
	await _wait(FIRST_WAIT, false)
	_fade(_hint, 0.7, 1.0)
	for i in SLIDES.size():
		if _leaving:
			return
		_last = i == SLIDES.size() - 1
		await _show(SLIDES[i])
		if i == 0:
			_fade(_hint, 0.0, 1.0)
	_close(false)


func _show(slide: Dictionary) -> void:
	_build(slide)
	if _reel:
		_reel.create_tween().tween_property(_reel, "modulate:a", 1.0, LINE_IN)
	for i in _lines.size():
		var l := _lines[i]
		var tw := l.create_tween()
		tw.tween_interval(i * LINE_GAP)
		tw.tween_property(l, "modulate:a", 1.0, LINE_IN)
	await _wait((_lines.size() - 1) * LINE_GAP + LINE_IN, true)
	if _skip:
		for l in _lines:
			l.modulate.a = 1.0
		if _reel:
			_reel.modulate.a = 1.0
	await _wait(slide.get("hold", HOLD), true)
	await _fade(_words, 0.0, WORDS_OUT)
	await _wait(BETWEEN, false)


## 这一页的字：都先透明，_show 里一行一行淡出来
func _build(slide: Dictionary) -> void:
	for c in _words.get_children():
		c.queue_free()
	_lines.clear()
	_reel = Reel.make(slide.get("clips", []))
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
	var reel_h := (_reel.size.y + CLIP_GAP) if _reel else 0.0
	# 有小字的页，大字整体往上挪一点，给底下的小字留地方
	var top := roundf((SCREEN.y - height - reel_h) * 0.5 - (ROW[SMALL] * (foot.size() + 1) * 0.5 if not foot.is_empty() else 0.0))
	if _reel:
		_reel.position = Vector2(roundf((SCREEN.x - _reel.size.x) * 0.5), maxf(top, 6.0))
		_words.add_child(_reel)
		top = _reel.position.y + reel_h
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


## 一页的动画：几段 CreditsClip 叠在一起，一次只显示一段，放完一圈换下一段；外面一圈 1 像素的细边
class Reel extends Control:
	var _clips: Array[CreditsClip] = []
	var _at := 0

	## 一段素材都没有就返回 null
	static func make(names: Array) -> Reel:
		var clips: Array[CreditsClip] = []
		for n: String in names:
			var c := CreditsClip.make(n)
			if c:
				clips.append(c)
		if clips.is_empty():
			return null
		var r := Reel.new()
		r._clips = clips
		r.size = Vector2(CreditsClip.FRAME)
		return r

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		modulate.a = 0.0
		for i in _clips.size():
			_clips[i].visible = i == 0
			add_child(_clips[i])

	func _process(_delta: float) -> void:
		if _clips.size() > 1 and _clips[_at].loops() >= 1:
			_clips[_at].visible = false
			_at = (_at + 1) % _clips.size()
			_clips[_at].restart()
			_clips[_at].visible = true

	func _draw() -> void:
		draw_rect(Rect2(-1, -1, size.x + 2, 1), CLIP_EDGE)
		draw_rect(Rect2(-1, size.y, size.x + 2, 1), CLIP_EDGE)
		draw_rect(Rect2(-1, 0, 1, size.y), CLIP_EDGE)
		draw_rect(Rect2(size.x, 0, 1, size.y), CLIP_EDGE)
