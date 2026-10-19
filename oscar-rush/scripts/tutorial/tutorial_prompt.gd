class_name TutorialPrompt
extends CanvasLayer
## 教学关的提示框：和新手提示（Coach）同一个样式（深色底、上下两道暖色细线、暖黄小字），放在屏幕上方 y 30，
## 一次只有一句；换句子时先淡出再淡入。arrow = true 时往左上角的马灯画一个会跳的小箭头（和 Coach 的"马灯"那条一样）。
## hold = true 时先收起来（精英出场卡在屏幕上方时）。

const WARM := Color8(255, 211, 138)
const GOOD := Color8(170, 236, 160)
const Y := 30.0
const H := 18.0
const FADE := 4.0

var hold := false
var _text := ""
var _next := ""
var _next_good := false
var _next_arrow := false
var _good := false
var _arrow := false
var _alpha := 0.0
var _t := 0.0
var _box: Control
var _label: Label


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	_box = Control.new()
	_box.position = Vector2(0, Y)
	_box.size = Vector2(480, H)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.draw.connect(_draw_box)
	add_child(_box)
	_label = Label.new()
	_label.label_settings = Hud.small_text(WARM)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size = Vector2(480, H)
	_box.add_child(_label)
	_box.modulate.a = 0.0


func show_text(text: String, good := false, arrow := false) -> void:
	if text == _text and _alpha > 0.0:
		return
	_next = text
	_next_good = good
	_next_arrow = arrow


func _process(delta: float) -> void:
	_t += delta
	# 要换句子：先淡出，淡到 0 再换
	if _next != _text:
		_alpha = move_toward(_alpha, 0.0, delta * FADE)
		if _alpha <= 0.0:
			_text = _next
			_good = _next_good
			_arrow = _next_arrow
			_label.text = _text
			_label.label_settings = Hud.small_text(GOOD if _good else WARM)
	elif _text != "" and not hold:
		_alpha = move_toward(_alpha, 1.0, delta * FADE)
	else:
		_alpha = move_toward(_alpha, 0.0, delta * FADE)
	_box.modulate.a = _alpha
	_box.queue_redraw()


func _draw_box() -> void:
	if _alpha <= 0.0 or _text == "":
		return
	var w := minf(_label.get_minimum_size().x + 16.0, 470.0)
	var r := Rect2((480.0 - w) / 2.0, 0, w, H)
	var col := GOOD if _good else WARM
	_box.draw_rect(r, Color(0.04, 0.035, 0.05, 0.82))
	_box.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(col, 0.6))
	_box.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), Color(col, 0.25))
	if _arrow:
		# 往左上角马灯血条画一个会跳的小箭头
		var bob := roundf(sin(_t * 6.0) * 2.0)
		var at := Vector2(82 + bob, -Y + 14)
		for i in 5:
			_box.draw_rect(Rect2(at + Vector2(i, -i), Vector2(1, i * 2 + 1)), WARM)
		_box.draw_rect(Rect2(at + Vector2(5, -1), Vector2(10, 3)), WARM)
