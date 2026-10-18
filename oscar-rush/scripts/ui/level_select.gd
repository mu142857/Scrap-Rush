class_name LevelSelect
extends Control
## 开始菜单的"选择关卡"（作者 2026-10-18 要的，打到过才解锁）。叠在开始界面上，和设置、制作人员页一样。
## 三张卡并排，样式照选武器界面（UiStyle 卡片、选中的往上抬 3 像素加角标）：
##   解锁了：关卡号、名字、"从这里开始"；没解锁：调暗、一把像素锁、"打到第二关解锁"。
## 左右选，确认开始，Esc / B 返回；鼠标指着就选、点一下确认；没解锁的点了卡片抖一下。
## 选好发 chosen(第几关)，返回发 chosen(0)。解锁看 Progress。

signal chosen(level: int)

const CARD_W := 132.0
const CARD_H := 150.0
const CARD_Y := 58.0
const CARD_GAP := 14.0
## [关卡号, 名字, 小字]
const LEVELS := [
	[1, "BOILER BAY", "LEVEL 1"],
	[2, "PICTURE HOUSE", "LEVEL 2"],
	[3, "SCREENS", "LEVEL 3"],
]
const LOCK := [
	"..###..",
	".#...#.",
	".#...#.",
	"#######",
	"###.###",
	"###.###",
	"#######",
]

var _selected := 0
var _time := 0.0
var _shake := [0.0, 0.0, 0.0]
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
	_label(tr("CHOOSE A LEVEL"), 0, 22, 480, 22, UiStyle.WARM, 3)
	_cards = Control.new()
	_cards.size = Vector2(480, 270)
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards.draw.connect(_draw_cards)
	add_child(_cards)
	for i in LEVELS.size():
		var x := _card_x(i)
		var lv: int = LEVELS[i][0]
		var open := Progress.unlocked(lv)
		var num := _label(str(lv), x, CARD_Y + 18, CARD_W, 33, UiStyle.WARM if open else UiStyle.DIM, 4)
		var name := _label(tr(LEVELS[i][1]), x, CARD_Y + 70, CARD_W, 11, UiStyle.WARM if open else UiStyle.DIM, 2)
		var sub := _label(tr(LEVELS[i][2]), x, CARD_Y + 86, CARD_W, 11, UiStyle.DIM, 2)
		var info := _label(tr("Start here") if open else tr("Reach level %d to unlock") % lv, x + 6, CARD_Y + 112, CARD_W - 12, 11,
				UiStyle.TEXT if open else UiStyle.DIM, 2, true)
		num.visible = open
		_labels.append([num, name, sub, info])
	_hint = _label("", 0, 246, 480, 11, UiStyle.DIM, 2)
	Controls.device_changed.connect(_on_device_changed)
	# 默认选打到过的最远一关
	_selected = Progress.reached() - 1
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
	return roundf((480.0 - CARD_W * 3.0 - CARD_GAP * 2.0) * 0.5 + i * (CARD_W + CARD_GAP))


func _on_device_changed(_pad: bool) -> void:
	_refresh_hint()


func _refresh_hint() -> void:
	_hint.text = tr("%s choose    %s start    %s back") % [Controls.label("change"), Controls.label("confirm"), Controls.label("back")]


func _process(delta: float) -> void:
	_time += delta
	for i in LEVELS.size():
		_lift[i] = lerpf(_lift[i], 3.0 if i == _selected else 0.0, 1.0 - exp(-14.0 * delta))
		_shake[i] = maxf(_shake[i] - delta, 0.0)
		var dx := roundf(sin(_shake[i] * 60.0) * 3.0 * (_shake[i] / 0.3))
		var dy := -roundf(_lift[i])
		var x := _card_x(i) + dx
		var row: Array = _labels[i]
		row[0].position = Vector2(x, CARD_Y + 18 + dy)
		row[1].position = Vector2(x, CARD_Y + 70 + dy)
		row[2].position = Vector2(x, CARD_Y + 86 + dy)
		row[3].position = Vector2(x + 6, CARD_Y + 112 + dy)
		for l in row:
			l.modulate = Color.WHITE if i == _selected else UiStyle.DIM_MOD
	_cards.queue_redraw()


func _draw_cards() -> void:
	for i in LEVELS.size():
		var lv: int = LEVELS[i][0]
		var open := Progress.unlocked(lv)
		var dx := roundf(sin(_shake[i] * 60.0) * 3.0 * (_shake[i] / 0.3))
		var r := Rect2(_card_x(i) + dx, CARD_Y - roundf(_lift[i]), CARD_W, CARD_H)
		var on := i == _selected
		var fill := UiStyle.PANEL if open else Color(0.04, 0.04, 0.05, 0.92)
		UiStyle.panel(_cards, r, on, _time, UiStyle.WARM if open else UiStyle.POOR, fill)
		if not open:
			# 一把像素锁，画在关卡号的位置，放大 3 倍
			var col := UiStyle.DIM if not on else Color(0.8, 0.78, 0.76)
			var ox := roundf(r.position.x + CARD_W * 0.5 - 10.5)
			var oy := r.position.y + 22.0
			for y in LOCK.size():
				var row: String = LOCK[y]
				for x in row.length():
					if row[x] == "#":
						_cards.draw_rect(Rect2(ox + x * 3, oy + y * 3, 3, 3), col)


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
		_finish(0)
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
	var lv: int = LEVELS[_selected][0]
	if not Progress.unlocked(lv):
		_shake[_selected] = 0.3
		Game.sfx("ui_back", -8.0, 0.8)
		return
	Game.sfx("ui_confirm", -4.0)
	_finish(lv)


func _finish(level: int) -> void:
	_done = true
	if level == 0:
		Game.sfx("ui_back", -8.0)
	chosen.emit(level)
	queue_free()
