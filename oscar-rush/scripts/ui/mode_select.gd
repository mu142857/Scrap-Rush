class_name ModeSelect
extends Control
## 开始菜单按"开始"以后的第一步：单人还是合作（作者 10-18 定的流程：开始 → 单人 / 合作 → 选难度 → 选武器）。
## 叠在开始界面上，样式照选择关卡（LevelSelect）：两张卡并排，UiStyle 卡片，选中的往上抬 3 像素加角标。
##   单人：一个船员放大 3 倍；合作：四个船员各放大 2 倍。下面一行说明。
## 左右选，确认，Esc / B 返回；鼠标指着就选、点一下确认。
## 选好发 chosen(SOLO / COOP)，返回发 chosen(BACK)。之后的事（合作的加入界面、选关卡）开始界面自己接。

signal chosen(mode: int)

const BACK := 0
const SOLO := 1
const COOP := 2

const CARD_W := 150.0
const CARD_H := 150.0
const CARD_Y := 58.0
const CARD_GAP := 20.0
## [模式, 名字, 说明]
const MODES := [
	[SOLO, "SOLO", "One player. Carry the lantern home."],
	[COOP, "CO-OP", "2-4 players, one screen. Keyboard halves or gamepads."],
]
## 船员图：一张 7 帧横排，前 4 帧是待机
const FRAMES := 7

var _selected := 0
var _time := 0.0
var _lift := [0.0, 0.0]
var _cards: Control
var _hint: Label
var _labels: Array = []
var _bodies: Array[Texture2D] = []
var _strips: Array[Texture2D] = []
var _ready_for_input := false
var _done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(480, 270)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var back := ColorRect.new()
	back.color = Color(0.02, 0.02, 0.035, 0.95)
	back.size = Vector2(480, 270)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	for skin in Run.SKINS:
		_bodies.append(load("res://art/chars/%s_body.png" % skin))
		_strips.append(load("res://art/chars/%s_strip.png" % skin))
	_label(tr("CHOOSE A MODE"), 0, 22, 480, 22, UiStyle.WARM, 3)
	_cards = Control.new()
	_cards.size = Vector2(480, 270)
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards.draw.connect(_draw_cards)
	add_child(_cards)
	for i in MODES.size():
		var x := _card_x(i)
		var name := _label(tr(MODES[i][1]), x, CARD_Y + 92, CARD_W, 22, UiStyle.WARM, 3)
		var info := _label(tr(MODES[i][2]), x + 4, CARD_Y + 118, CARD_W - 8, 11, UiStyle.TEXT, 2, true)
		_labels.append([name, info])
	_hint = _label("", 0, 246, 480, 11, UiStyle.DIM, 2)
	Controls.device_changed.connect(_on_device_changed)
	_refresh_hint()
	await get_tree().process_frame
	_ready_for_input = true


## wrap：自动换行（两行高）。要在加进场景之前开，不然 Label 已经按一整行撑宽、缩不回来
func _label(text: String, x: float, y: float, w: float, font_size: int, color: Color, outline: int, wrap := false) -> Label:
	var l := Label.new()
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # 中文也按词折，标点不会落到行首
	var st := Hud.small_text(color)
	st.font_size = font_size
	st.outline_size = outline
	l.label_settings = st
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(x, y)
	l.size = Vector2(w, (font_size + 6) * (2 if wrap else 1))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _card_x(i: int) -> float:
	return roundf((480.0 - CARD_W * 2.0 - CARD_GAP) * 0.5 + i * (CARD_W + CARD_GAP))


func _on_device_changed(_pad: bool) -> void:
	_refresh_hint()


func _refresh_hint() -> void:
	_hint.text = tr("%s choose    %s confirm    %s back") % [Controls.label("change"), Controls.label("confirm"), Controls.label("back")]


func _process(delta: float) -> void:
	_time += delta
	for i in MODES.size():
		_lift[i] = lerpf(_lift[i], 3.0 if i == _selected else 0.0, 1.0 - exp(-14.0 * delta))
		var dy := -roundf(_lift[i])
		var row: Array = _labels[i]
		row[0].position.y = CARD_Y + 92 + dy
		row[1].position.y = CARD_Y + 118 + dy
		for l in row:
			l.modulate = Color.WHITE if i == _selected else UiStyle.DIM_MOD
	_cards.queue_redraw()


func _draw_cards() -> void:
	var frame := int(_time / Player.IDLE_FRAME_TIME) % 4
	for i in MODES.size():
		var on := i == _selected
		var r := Rect2(_card_x(i), CARD_Y - roundf(_lift[i]), CARD_W, CARD_H)
		UiStyle.panel(_cards, r, on, _time)
		var tint := Color.WHITE if on else UiStyle.DIM_MOD
		var foot := r.position.y + 84.0
		if MODES[i][0] == SOLO:
			_draw_crew(0, Vector2(r.position.x + CARD_W * 0.5, foot), 3, frame, tint)
		else:
			# 四个船员排开，各自的待机错开一帧，不像复制粘贴的
			for k in 4:
				_draw_crew(k, Vector2(r.position.x + CARD_W * 0.5 + (k - 1.5) * 32.0, foot), 2, (frame + k) % 4, tint)


## 一个船员：脚底中点在 at，放大 scale 倍（整数倍，像素是方的）
func _draw_crew(skin: int, at: Vector2, scale: int, frame: int, tint: Color) -> void:
	var body := _bodies[skin]
	var fw := body.get_width() / FRAMES
	var fh := body.get_height()
	var dst := Rect2(roundf(at.x - fw * scale * 0.5), at.y - fh * scale, fw * scale, fh * scale)
	var src := Rect2(frame * fw, 0, fw, fh)
	# 船员图本来是给关卡里打光用的，偏暗；菜单里没有灯，提亮一点
	_cards.draw_texture_rect_region(body, dst, src, tint * Color(1.35, 1.35, 1.35))
	_cards.draw_texture_rect_region(_strips[skin], dst, src, tint * Color(1.6, 1.6, 1.6))


func _input(event: InputEvent) -> void:
	if not _ready_for_input or _done:
		return
	var handled := true
	if event.is_action_pressed("ui_left", true):
		_move(-1)
	elif event.is_action_pressed("ui_right", true):
		_move(1)
	elif event.is_action_pressed("ui_accept"):
		_confirm()
	elif event.is_action_pressed("ui_cancel") \
			or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE):
		_finish(BACK)
	elif event is InputEventMouseMotion:
		var i := _card_at()
		if i >= 0 and i != _selected:
			_selected = i
			Game.sfx("ui_move", -12.0)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _card_at()
		if i >= 0:
			_selected = i
			_confirm()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_finish(BACK)
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _card_at() -> int:
	var p := get_global_mouse_position()
	for i in MODES.size():
		if Rect2(_card_x(i), CARD_Y - 4, CARD_W, CARD_H + 4).has_point(p):
			return i
	return -1


func _move(step: int) -> void:
	_selected = posmod(_selected + step, MODES.size())
	Game.sfx("ui_move", -10.0)


func _confirm() -> void:
	Game.sfx("ui_confirm", -4.0)
	_finish(MODES[_selected][0])


func _finish(mode: int) -> void:
	_done = true
	if mode == BACK:
		Game.sfx("ui_back", -8.0)
	chosen.emit(mode)
	queue_free()
