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
const CHARS_PER_SEC := 32.0
## 刚打开时先不收按键，免得触发对话的那一下跳键直接把第一句翻掉
const INPUT_DELAY := 0.2
const OPEN_TIME := 0.15

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
var _open := 0.0
var _closing := false
var _age := 0.0
var _time := 0.0
var _last_ticks := 0
var _was_paused := false

var _back: Control
var _front: Control
var _face: TextureRect
var _name: Label
var _text: Label
var _accept_actions: Array[String] = []


func _ready() -> void:
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

	_face = TextureRect.new()
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.texture = portrait
	add_child(_face)

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
	_age = 0.0
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
	_name.text = d.get("name", skin.to_upper() if skin != "" else speaker)
	_face.texture = d.get("portrait", PORTRAITS.get(skin, portrait))
	_text.text = d.get("text", "")
	_shown = 0.0
	_text.visible_characters = 0


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
		if not _line_done():
			_shown += dt * CHARS_PER_SEC
			_text.visible_characters = int(_shown)
	_apply_open()
	_front.queue_redraw()


func _apply_open() -> void:
	var a := _open * _open * (3.0 - 2.0 * _open)
	_back.modulate.a = a
	_front.modulate.a = a
	_name.modulate.a = a
	_text.modulate.a = a
	_face.modulate.a = a
	# 立绘从下面升上来，取整保持像素对齐
	_face.position = PORTRAIT_POS + Vector2(0, roundf((1.0 - a) * 8.0))


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
	if not visible or _closing or not _line_done():
		return
	# 打完一句：右下角一个上下晃的小三角，提示可以翻页
	var bob := roundf(1.0 + sin(_time * 7.0))
	var tip := Vector2(b.end.x - 9, b.end.y - 7 + bob)
	for y in 3:
		for x in range(y, 5 - y):
			_front.draw_rect(Rect2(tip + Vector2(x - 2, y - 2), Vector2.ONE), Hud.WARM)
