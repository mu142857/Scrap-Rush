class_name DifficultySelect
extends Control
## 选难度（作者 10-18："那干脆不能自选关卡了，选择关卡的换成选择难度"）。
## 流程：开始 → 单人 / 合作 → 选难度 → 选武器 → 第一关。叠在开始界面上，样式和单人 / 合作页（ModeSelect）一样：
## 三张卡并排，UiStyle 卡片，选中的往上抬 3 像素加角标。卡上画 1~3 格压力表，下面是名字和一句说明。
## 左右选，确认，Esc / B / 右键返回；鼠标指着就选、点一下确认。
## 选好发 chosen(EASY / NORMAL / HARD)，返回发 chosen(BACK)。难度怎么生效（倍率）归游戏设计会话，开始界面负责交给 Run。

signal chosen(level: int)

const BACK := -1
const EASY := 0
const NORMAL := 1
const HARD := 2

const CARD_W := 132.0
const CARD_H := 150.0
const CARD_Y := 58.0
const CARD_GAP := 14.0
## [难度, 名字, 说明, 卡的强调色]
const LEVELS := [
	[EASY, "EASY", "Enemies hit softer and the lantern lasts longer.", Color8(150, 200, 140)],
	[NORMAL, "NORMAL", "The game as it was made to be played.", Color8(255, 211, 138)],
	[HARD, "HARD", "Tougher machines, less room for mistakes.", Color8(230, 110, 80)],
]

## 上次选的（同一次打开游戏里记着，下次默认停在这里）
static var last := NORMAL

var _selected := NORMAL
var _time := 0.0
var _lift := [0.0, 0.0, 0.0]
var _cards: Control
var _hint: Label
var _labels: Array = []
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
	_label(tr("CHOOSE A DIFFICULTY"), 0, 22, 480, 22, UiStyle.WARM, 3)
	_cards = Control.new()
	_cards.size = Vector2(480, 270)
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards.draw.connect(_draw_cards)
	add_child(_cards)
	for i in LEVELS.size():
		var x := _card_x(i)
		var name := _label(tr(LEVELS[i][1]), x, CARD_Y + 74, CARD_W, 22, LEVELS[i][3], 3)
		var info := _label(tr(LEVELS[i][2]), x + 6, CARD_Y + 102, CARD_W - 12, 11, UiStyle.TEXT, 2, true)
		_labels.append([name, info])
	_hint = _label("", 0, 246, 480, 11, UiStyle.DIM, 2)
	_selected = last
	Controls.device_changed.connect(_on_device_changed)
	_refresh_hint()
	await get_tree().process_frame
	_ready_for_input = true


## wrap：自动换行（三行高）。要在加进场景之前开，不然 Label 已经按一整行撑宽、缩不回来
func _label(text: String, x: float, y: float, w: float, font_size: int, color: Color, outline: int, wrap := false) -> Label:
	var l := Label.new()
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var st := Hud.small_text(color)
	st.font_size = font_size
	st.outline_size = outline
	l.label_settings = st
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(x, y)
	l.size = Vector2(w, (font_size + 6) * (3 if wrap else 1))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _card_x(i: int) -> float:
	return roundf((480.0 - CARD_W * 3.0 - CARD_GAP * 2.0) * 0.5 + i * (CARD_W + CARD_GAP))


func _on_device_changed(_pad: bool) -> void:
	_refresh_hint()


func _refresh_hint() -> void:
	_hint.text = tr("%s choose    %s confirm    %s back") % [Controls.label("change"), Controls.label("confirm"), Controls.label("back")]


func _process(delta: float) -> void:
	_time += delta
	for i in LEVELS.size():
		_lift[i] = lerpf(_lift[i], 3.0 if i == _selected else 0.0, 1.0 - exp(-14.0 * delta))
		var dy := -roundf(_lift[i])
		var row: Array = _labels[i]
		row[0].position.y = CARD_Y + 74 + dy
		row[1].position.y = CARD_Y + 102 + dy
		for l in row:
			l.modulate = Color.WHITE if i == _selected else UiStyle.DIM_MOD
	_cards.queue_redraw()


## 每张卡上方一个像素压力表：三格，简单亮一格、普通两格、困难三格（困难的格子一闪一闪）
func _draw_cards() -> void:
	for i in LEVELS.size():
		var on := i == _selected
		var r := Rect2(_card_x(i), CARD_Y - roundf(_lift[i]), CARD_W, CARD_H)
		var col: Color = LEVELS[i][3]
		UiStyle.panel(_cards, r, on, _time, col)
		var tint := Color.WHITE if on else UiStyle.DIM_MOD
		var w := 18.0
		var gap := 6.0
		var x0 := roundf(r.position.x + (CARD_W - (w * 3.0 + gap * 2.0)) * 0.5)
		var y0 := r.position.y + 30.0
		for k in 3:
			var lit := k <= i
			var c := col if lit else UiStyle.BAR_OFF
			if lit and i == HARD and on:
				c = col.lerp(Color.WHITE, 0.25 + 0.25 * sin(_time * 8.0 + k))
			# 一格是一根竖着的"压力柱"，越往右越高
			var h := 14.0 + k * 8.0
			_cards.draw_rect(Rect2(x0 + k * (w + gap), y0 + 22.0 - h, w, h), c * tint)


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
			or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE) \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
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
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _card_at() -> int:
	var p := get_global_mouse_position()
	for i in LEVELS.size():
		if Rect2(_card_x(i), CARD_Y - 4, CARD_W, CARD_H + 4).has_point(p):
			return i
	return -1


func _move(step: int) -> void:
	_selected = posmod(_selected + step, LEVELS.size())
	Game.sfx("ui_move", -10.0)


func _confirm() -> void:
	Game.sfx("ui_confirm", -4.0)
	last = LEVELS[_selected][0]
	_finish(LEVELS[_selected][0])


func _finish(level: int) -> void:
	_done = true
	if level == BACK:
		Game.sfx("ui_back", -8.0)
	chosen.emit(level)
	queue_free()
