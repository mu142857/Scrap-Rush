class_name ConfirmBox
extends Control
## 小确认框（10-18：有存档时选"开始"，先问"新开一局会覆盖第 N 关的存档，确定吗？"）。
## 叠在当前界面上：半透明压暗，中间一张 UiStyle 卡片，一行字，下面"取消 / 确定"两个按钮，默认停在"取消"。
## 左右换、确认键选当前的；Esc / B / 右键 = 取消；鼠标指着就选、点一下选。
## 用法：var box := ConfirmBox.make(文字); 加到 UI 层; var ok: bool = await box.answered（选完自己 queue_free）。

signal answered(ok: bool)

const BOX := Rect2(90, 92, 300, 86)
const BTN_W := 90.0
const BTN_H := 18.0
const BTN_Y := 148.0

var text := ""
var _sel := 0   # 0 取消、1 确定
var _time := 0.0
var _draw_layer: Control
var _btn_labels: Array[Label] = []
var _ready_for_input := false
var _done := false


static func make(what: String) -> ConfirmBox:
	var b := ConfirmBox.new()
	b.text = what
	return b


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(480, 270)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.size = size
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_draw_layer = Control.new()
	_draw_layer.size = size
	_draw_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_layer.draw.connect(_draw_box)
	add_child(_draw_layer)
	var msg := Label.new()
	msg.label_settings = Hud.small_text(UiStyle.TEXT)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.position = BOX.position + Vector2(12, 14)
	msg.size = Vector2(BOX.size.x - 24, 34)
	msg.text = text
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(msg)
	for i in 2:
		var l := Label.new()
		l.label_settings = Hud.small_text(UiStyle.WARM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.text = tr("CANCEL") if i == 0 else tr("CONFIRM")
		var r := _btn_rect(i)
		l.position = r.position
		l.size = r.size
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		_btn_labels.append(l)
	await get_tree().process_frame
	_ready_for_input = true


func _btn_rect(i: int) -> Rect2:
	var x := 240.0 - BTN_W - 8.0 if i == 0 else 248.0
	return Rect2(x, BTN_Y, BTN_W, BTN_H)


func _process(delta: float) -> void:
	_time += delta
	for i in 2:
		_btn_labels[i].modulate = Color.WHITE if i == _sel else UiStyle.DIM_MOD
	_draw_layer.queue_redraw()


func _draw_box() -> void:
	UiStyle.panel(_draw_layer, BOX, false, _time)
	for i in 2:
		UiStyle.panel(_draw_layer, _btn_rect(i), i == _sel, _time)


func _input(event: InputEvent) -> void:
	if not _ready_for_input or _done:
		return
	var handled := true
	if event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_right", true):
		_sel = 1 - _sel
		Game.sfx("ui_move", -10.0)
	elif event.is_action_pressed("ui_accept"):
		_finish(_sel == 1)
	elif event.is_action_pressed("ui_cancel") \
			or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE) \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		_finish(false)
	elif event is InputEventMouseMotion:
		for i in 2:
			if _btn_rect(i).grow(2).has_point(get_global_mouse_position()) and i != _sel:
				_sel = i
				Game.sfx("ui_move", -12.0)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in 2:
			if _btn_rect(i).grow(2).has_point(get_global_mouse_position()):
				_finish(i == 1)
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _finish(ok: bool) -> void:
	_done = true
	Game.sfx("ui_confirm" if ok else "ui_back", -8.0)
	answered.emit(ok)
	queue_free()
