class_name DialogBox
extends CanvasLayer
## 对话框：屏幕下方一条框，左边立绘（96×96，下沿贴着框底、上半截探出框外），右边名字和逐字出现的台词。
## 跳 / 攻击 / 回车 / 点屏幕：字没打完就一下打完，打完了就翻下一句；最后一句翻过去关掉并发 finished。
## 开着的时候默认暂停整棵树，主角和怪都停住；关掉后恢复。
##
## 用法：
##   var box := DialogBox.new()
##   add_child(box)
##   box.play(["第一句", {"text": "第二句", "name": "RED"}])
##   await box.finished
## 每句可以是字符串，也可以是 {text, name, portrait, skin}；没写的沿用 speaker / portrait。
## skin 是船员名（Run.SKINS），自动换成那个人的立绘，名字默认是 skin 的大写。
## 一句最多三行：中文约 25 字一行，英文约 45 个字母一行，再长就拆成两句。

signal finished

const RED_PORTRAIT := preload("res://art/chars/red_portrait.png")
## 船员立绘，键和 Run.SKINS 一样；还没有立绘的（bird）用 portrait
const PORTRAITS := {
	"red": RED_PORTRAIT,
	"robot": preload("res://art/chars/robot_portrait.png"),
	"dino": preload("res://art/chars/dino_portrait.png"),
}
## 立绘的额外帧：talk = 说话时和原图轮流换（机器人的表盘指针竖起来），blink = 眨眼。
## 只换眼睛 / 指针那几格，原图见 草图/立绘/blink_frames.py、robot_portrait.py --frame
const FRAMES := {
	"red": {"blink": preload("res://art/chars/red_portrait_blink.png")},
	"robot": {"talk": preload("res://art/chars/robot_portrait_talk.png"),
		"blink": preload("res://art/chars/robot_portrait_blink.png")},
	"dino": {"blink": preload("res://art/chars/dino_portrait_blink.png")},
}
const BLINK_TIME := 0.13
const CHARS_PER_SEC := 32.0
const BLIP_EVERY := 2
## 按住确认键时打字快几倍
const FAST_MULT := 4.0
## 按住确认键这么久跳过整段对话（看过的剧情不用再看一遍）。按住超过 SKIP_SHOW 秒才显示"按住跳过"和进度条
const SKIP_HOLD := 1.0
const SKIP_SHOW := 0.3
## 刚打开时先不收按键，免得触发对话的那一下跳键直接把第一句翻掉
const INPUT_DELAY := 0.2
const OPEN_TIME := 0.15
## 立绘的动作（全部按整格往下沉，不往上抬：立绘下沿是半身像的切口，抬起来就露馅了）
const ENTER_TIME := 0.3       # 入场：从下面升上来，落定时轻轻沉一格
const ENTER_DROP := 16.0
const SWAP_OUT := 0.08        # 换说话人：旧的沉下去淡出
const SWAP_IN := 0.16         #           新的升上来
const SWAP_DROP := 12.0
const NOD_TIME := 0.18        # 同一个人说下一句：点一下头
const TALK_CHARS := 2.5       # 说话时每打出这么多字，立绘上下错一格

const BOX := Rect2(8, 204, 464, 58)
const PORTRAIT_POS := Vector2(12, 165)
const TEXT_X := 114.0
const FILL := Color(0.03, 0.03, 0.045, 0.94)
const BORDER := Color8(140, 108, 72)
const TEXT_COLOR := Color(0.93, 0.9, 0.86)

var speaker := "RED"
var portrait: Texture2D = RED_PORTRAIT
## false 时不暂停，比如想让背景里的东西继续动
var pause_game := true

var _lines: Array = []
var _index := -1
var _shown := 0.0
var _blip_at := 0
var _open := 0.0
var _closing := false
var _hold := 0.0
## 对话开始以后确认键松开过没有：开对话时正按着跳 / 攻击（铆钉枪要一直按着开火）的，不算"按住跳过"
var _released := false
var _age := 0.0
var _time := 0.0
var _last_ticks := 0
var _was_paused := false

var _back: Control
var _front: Control
var _face: TextureRect
var _face_clip: Control
var _enter := 0.0
var _swap_t := -1.0
var _swap_tex: Texture2D
var _swap_name := ""
var _nod_t := -1.0
var _skin := ""
var _swap_skin := ""
var _base_tex: Texture2D
var _blink_t := -1.0
var _blink_next := 2.0
## 说话错格的节拍：按正常打字速度走，按住快进时立绘也不会跟着抖得飞快
var _talk_clock := 0.0
var _name: Label
var _text: Label
var _accept_actions: Array[String] = []


func _ready() -> void:
	# Hud 看这个组：对话框开着的时候把底下那行按键提示藏起来（夜间打磨，美术巡检提的）
	add_to_group("dialog_box")
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	for prefix in ["solo"] + Controls.all_schemes():
		for a in ["jump", "attack"]:
			_accept_actions.append("%s_%s" % [prefix, a])
	_accept_actions.append("ui_accept")

	_back = Control.new()
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.draw.connect(_draw_back)
	add_child(_back)

	# 立绘套一层裁切，沉下去的部分藏在框底边后面
	_face_clip = Control.new()
	_face_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face_clip.clip_contents = true
	_face_clip.size = Vector2(BOX.end.x, BOX.end.y - 1)
	add_child(_face_clip)
	_face = TextureRect.new()
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.texture = portrait
	_face_clip.add_child(_face)

	_front = Control.new()
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.draw.connect(_draw_front)
	add_child(_front)

	_name = Label.new()
	_name.label_settings = Hud.small_text(Hud.WARM)
	_name.position = Vector2(TEXT_X, BOX.position.y + 3)
	_name.size = Vector2(BOX.end.x - TEXT_X - 8, 12)
	add_child(_name)

	_text = Label.new()
	_text.label_settings = Hud.small_text(TEXT_COLOR)
	_text.label_settings.line_spacing = 2
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_text.position = Vector2(TEXT_X, BOX.position.y + 17)
	_text.size = Vector2(BOX.end.x - TEXT_X - 14, 38)
	add_child(_text)

	_last_ticks = Time.get_ticks_msec()
	_apply_open()
	visible = false


func play(lines: Array) -> void:
	_lines = lines
	_index = -1
	_closing = false
	_hold = 0.0
	_released = false
	_age = 0.0
	_enter = 0.0
	_swap_t = -1.0
	_nod_t = -1.0
	visible = true
	if pause_game:
		_was_paused = get_tree().paused
		get_tree().paused = true
	_next()


func _next() -> void:
	_index += 1
	if _index >= _lines.size():
		_closing = true
		return
	var line = _lines[_index]
	var d: Dictionary = line if line is Dictionary else {"text": str(line)}
	var skin: String = d.get("skin", "")
	var who: String = d.get("name", skin.to_upper() if skin != "" else speaker)
	var tex: Texture2D = d.get("portrait", PORTRAITS.get(skin, portrait))
	if _index == 0:
		_name.text = who
		_face.texture = tex
		_base_tex = tex
		_skin = skin
	elif tex != _base_tex:
		# 换人：旧立绘先沉下去，换图和名字在最低点做
		_swap_t = 0.0
		_swap_tex = tex
		_swap_name = who
		_swap_skin = skin
	else:
		_name.text = who
		_nod_t = 0.0
	_text.text = d.get("text", "")
	_shown = 0.0
	_talk_clock = 0.0
	_blip_at = 0
	_text.visible_characters = 0


## 打字声：每 BLIP_EVERY 个字轻轻"嗒"一下，音高跟着说话的人变（同一个人每次都一样）
func _blip() -> void:
	var n := _text.visible_characters
	if n < _blip_at + BLIP_EVERY:
		return
	_blip_at = n
	var ch := _text.text.substr(n - 1, 1)
	if ch.strip_edges() == "" or ch in ".,!?…。，！？、：:—-":
		return
	var pitch := 0.85 + float(absi(hash(_name.text)) % 40) / 100.0
	Game.sfx("dial", -16.0, pitch, 0.06)


func _accept_held() -> bool:
	for a in _accept_actions:
		if InputMap.has_action(a) and Input.is_action_pressed(a):
			return true
	return false


func _line_done() -> bool:
	return _text.visible_characters < 0 or _text.visible_characters >= _text.get_total_character_count()


func _input(event: InputEvent) -> void:
	if not visible or _closing or _age < INPUT_DELAY:
		return
	var pressed := false
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		pressed = event.pressed
	elif not event.is_echo():
		for a in _accept_actions:
			if event.is_action_pressed(a):
				pressed = true
				break
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if _line_done():
		_next()
	else:
		_text.visible_characters = -1


func _process(_delta: float) -> void:
	# 顿帧时 time_scale 是 0，自己按真实时间走
	var now := Time.get_ticks_msec()
	var dt := minf((now - _last_ticks) / 1000.0, 0.1)
	_last_ticks = now
	if not visible:
		return
	_age += dt
	_time += dt
	if _closing:
		_open = move_toward(_open, 0.0, dt / OPEN_TIME)
		if _open <= 0.0:
			visible = false
			if pause_game:
				get_tree().paused = _was_paused
			finished.emit()
	else:
		_open = move_toward(_open, 1.0, dt / OPEN_TIME)
		_enter = move_toward(_enter, 1.0, dt / ENTER_TIME)
		var held := _accept_held()
		if not held:
			_released = true
		_hold = _hold + dt if held and _released and _age > INPUT_DELAY else 0.0
		if _hold >= SKIP_HOLD:
			_hold = 0.0
			_closing = true
		_step_face(dt)
		# 换人时等新立绘升上来再开始打字
		if not _line_done() and _swap_t < 0.0:
			# 按住确认键（跳 / 攻击 / 回车 / 手柄 A）打字加速；松开恢复。按一下照旧是"直接打完这一句"
			_shown += dt * CHARS_PER_SEC * (FAST_MULT if _accept_held() else 1.0)
			_text.visible_characters = int(_shown)
			_talk_clock += dt * CHARS_PER_SEC
			_blip()
	_apply_open()
	_front.queue_redraw()


func _apply_open() -> void:
	var a := _open * _open * (3.0 - 2.0 * _open)
	_back.modulate.a = a
	_front.modulate.a = a
	_name.modulate.a = a
	_text.modulate.a = a
	_face.modulate.a = a * _face_alpha()
	_name.modulate.a = a * _face_alpha()
	_face.position = PORTRAIT_POS + Vector2(0, _face_drop())


func _step_face(dt: float) -> void:
	if _swap_t >= 0.0:
		var was_out := _swap_t < SWAP_OUT
		_swap_t += dt
		if was_out and _swap_t >= SWAP_OUT:
			_face.texture = _swap_tex
			_base_tex = _swap_tex
			_skin = _swap_skin
			_name.text = _swap_name
		if _swap_t >= SWAP_OUT + SWAP_IN:
			_swap_t = -1.0
	if _nod_t >= 0.0:
		_nod_t += dt
		if _nod_t >= NOD_TIME:
			_nod_t = -1.0
	# 眨眼：每隔 2~4 秒随机一次
	_blink_next -= dt
	if _blink_next <= 0.0:
		_blink_t = 0.0
		_blink_next = randf_range(2.0, 4.0)
	if _blink_t >= 0.0:
		_blink_t += dt
		if _blink_t >= BLINK_TIME:
			_blink_t = -1.0
	_pick_frame()


## 选这一刻用哪一帧：说话帧 > 眨眼帧 > 原图。换人途中只用原图
func _pick_frame() -> void:
	if _swap_t >= 0.0 or _base_tex == null:
		return
	var frames: Dictionary = FRAMES.get(_skin, {}) if _base_tex == PORTRAITS.get(_skin) else {}
	var tex := _base_tex
	if _talking() and frames.has("talk"):
		tex = frames["talk"]
	elif _blink_t >= 0.0 and frames.has("blink"):
		tex = frames["blink"]
	if _face.texture != tex:
		_face.texture = tex


## 正在说话、而且这一拍是"张嘴"那一拍（立绘错下一格、机器人指针竖起）
func _talking() -> bool:
	if _closing or _enter < 1.0 or _swap_t >= 0.0 or _nod_t >= 0.0 or _line_done():
		return false
	var ch := _text.text.substr(maxi(_text.visible_characters - 1, 0), 1)
	return int(_talk_clock / TALK_CHARS) % 2 == 1 and not (ch in " ，。、！？…,.!?—")


## 立绘往下沉多少格（只取 >= 0 的整数）
func _face_drop() -> float:
	var y := 0.0
	# 入场：缓出升上来，最后一小段沉一格再回来，像落定
	var e := 1.0 - pow(1.0 - _enter, 3.0)
	y += ENTER_DROP * (1.0 - e)
	if _enter > 0.78 and _enter < 0.95:
		y += 1.0
	if _closing:
		y += (1.0 - _open) * 8.0
	if _swap_t >= 0.0:
		if _swap_t < SWAP_OUT:
			var k := _swap_t / SWAP_OUT
			y += SWAP_DROP * k * k
		else:
			var k := clampf((_swap_t - SWAP_OUT) / SWAP_IN, 0.0, 1.0)
			y += SWAP_DROP * pow(1.0 - k, 3.0)
	elif _nod_t >= 0.0:
		y += roundf(2.0 * sin(_nod_t / NOD_TIME * PI))
	elif not _closing and _enter >= 1.0:
		if not _line_done():
			# 说话：每打出几个字上下错一格；遇到空格和标点停在原位
			if _talking():
				y += 1.0
		elif fmod(_time, 2.4) < 0.35:
			# 说完了等翻页：偶尔呼吸一下
			y += 1.0
	return roundf(y)


func _face_alpha() -> float:
	if _swap_t < 0.0:
		return 1.0
	if _swap_t < SWAP_OUT:
		return 1.0 - _swap_t / SWAP_OUT
	return clampf((_swap_t - SWAP_OUT) / (SWAP_IN * 0.5), 0.0, 1.0)


func _draw_back() -> void:
	var b := BOX
	_back.draw_rect(b.grow(1), Color(0.03, 0.03, 0.045))
	_back.draw_rect(b, FILL)
	_back.draw_rect(Rect2(b.position.x, b.position.y, b.size.x, 1), BORDER)
	_back.draw_rect(Rect2(b.position.x, b.position.y, 1, b.size.y), BORDER)
	_back.draw_rect(Rect2(b.end.x - 1, b.position.y, 1, b.size.y), BORDER)


## 底边画在立绘上面，盖住立绘下沿的切口
func _draw_front() -> void:
	var b := BOX
	_front.draw_rect(Rect2(b.position.x - 1, b.end.y, b.size.x + 2, 1), Color(0.03, 0.03, 0.045))
	_front.draw_rect(Rect2(b.position.x, b.end.y - 1, b.size.x, 1), BORDER)
	# 按住跳过：框右上角上方一行小字 + 一格一格长满的进度条
	if visible and not _closing and _hold > SKIP_SHOW:
		var k := clampf((_hold - SKIP_SHOW) / (SKIP_HOLD - SKIP_SHOW), 0.0, 1.0)
		var label := tr("HOLD TO SKIP")
		var font := Hud.font()
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var x := roundf(b.end.x - w - 46.0)
		_front.draw_string_outline(font, Vector2(x, b.position.y - 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 2, Color(0.03, 0.03, 0.045))
		_front.draw_string(font, Vector2(x, b.position.y - 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Hud.WARM)
		var bar := Rect2(b.end.x - 40.0, b.position.y - 10.0, 40.0, 4.0)
		_front.draw_rect(bar, Color(0.2, 0.2, 0.24))
		_front.draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * k), bar.size.y)), Hud.WARM)
	if not visible or _closing or not _line_done():
		return
	# 打完一句：右下角一个上下晃的小三角，提示可以翻页
	var bob := roundf(1.0 + sin(_time * 7.0))
	var tip := Vector2(b.end.x - 9, b.end.y - 7 + bob)
	for y in 3:
		for x in range(y, 5 - y):
			_front.draw_rect(Rect2(tip + Vector2(x - 2, y - 2), Vector2.ONE), Hud.WARM)
