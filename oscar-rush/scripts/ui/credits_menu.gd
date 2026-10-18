class_name CreditsMenu
extends Control
## 制作人员和授权页（标题菜单的 CREDITS）。两页：
##   1. 制作人员 + 用到的第三方资源（中文像素字体的 GPLv2 + 字体嵌入例外、Godot 的 MIT）
##   2. 授权全文：Godot 的 MIT 原文 + 引擎里自带的第三方组件清单（Engine.get_copyright_info）
## 左右切页，上下滚动，Esc / B / 确认键返回。和设置界面同一套样式（UiStyle 卡片、暖黄标题）。
## 名字是 2026-10-17 夜里先填的，等作者确认（见 夜间打磨/游戏细节讨论_报告.md）。

signal closed

const WARM := Color8(255, 211, 138)
const TEXT := Color(0.82, 0.8, 0.78)
const DIM := Color(0.55, 0.55, 0.6)
## 11 号字一行 15 像素；框高正好 11 行，滚动一次一行，最底下不会切掉半行字
const LINE := 15.0
const BODY := Rect2(36, 54, 408, LINE * 11)
const SCROLL_STEP := LINE

## 制作人员：[小标题, 内容]。小标题会翻译，内容里的人名不翻
const CREW := [
	["GAME BY", "Aaron Mumu"],
	["ART", "Oscar Li  -  characters, level 1, intro animation"],
	["CODE, SOUND AND ADDITIONAL ART", "made together with Claude (Anthropic)"],
	["MADE FOR", "Ludum Dare 60  -  theme: Old Tech"],
]

var _page := 0
var _scroll := 0.0
var _clip: Control
var _body: Label
var _title: Label
var _hint: Label
var _ready_for_input := false
var _frame: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(480, 270)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var back := ColorRect.new()
	back.color = Color(0.02, 0.02, 0.035, 0.95)
	back.size = Vector2(480, 270)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	var frame := Control.new()
	frame.size = Vector2(480, 270)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.draw.connect(func() -> void:
		UiStyle.panel(frame, BODY.grow(6), false, 0.0)
		# 下面还有字：框右下角一个小三角
		if _scroll < _max_scroll() - 0.5:
			var tip := Vector2(BODY.end.x - 2, BODY.end.y + 2)
			for y in 3:
				for x in range(y, 5 - y):
					frame.draw_rect(Rect2(tip + Vector2(x - 2, y - 2), Vector2.ONE), WARM))
	add_child(frame)
	_frame = frame
	_title = _label(0, 18, 480, 22, WARM, 3, HORIZONTAL_ALIGNMENT_CENTER)
	_clip = Control.new()
	_clip.position = BODY.position
	_clip.size = BODY.size
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_body = Label.new()
	var st := Hud.small_text(TEXT)
	_body.label_settings = st
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size = Vector2(BODY.size.x, 10)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.add_child(_body)
	_hint = _label(0, 246, 480, 11, DIM, 2, HORIZONTAL_ALIGNMENT_CENTER)
	_show_page(0)
	Controls.device_changed.connect(_on_device_changed)
	await get_tree().process_frame
	_ready_for_input = true


func _label(x: float, y: float, w: float, font_size: int, color: Color, outline: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	var s := Hud.small_text(color)
	s.font_size = font_size
	s.outline_size = outline
	l.label_settings = s
	l.horizontal_alignment = align
	l.position = Vector2(x, y)
	l.size = Vector2(w, font_size + 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _show_page(i: int) -> void:
	_page = i
	_scroll = 0.0
	if i == 0:
		_title.text = tr("CREDITS")
		_body.text = _credits_text()
	else:
		_title.text = tr("LICENSES")
		_body.text = _license_text()
	# 自动换行的 Label：先定宽，再按宽度量出高度
	_body.size = Vector2(BODY.size.x, 0)
	_body.size.y = _body.get_minimum_size().y
	_apply_scroll()
	_show_hint()


func _on_device_changed(_pad: bool) -> void:
	_show_hint()


func _show_hint() -> void:
	_hint.text = tr("%s scroll    %s page    %s back") % [Controls.label("scroll"), Controls.label("page"), Controls.label("back")] + "    %d / 2" % (_page + 1)


func _credits_text() -> String:
	var lines: PackedStringArray = []
	for row in CREW:
		lines.append(tr(row[0]))
		lines.append("    " + tr(row[1]))
		lines.append("")
	lines.append(tr("THIRD-PARTY"))
	lines.append("    " + tr("Pixel font: Uranus Pixel 11Px, based on WenQuanYi Bitmap Song 11px."))
	lines.append("    " + tr("License: GNU GPL v2 with font embedding exception."))
	lines.append("    " + tr("Engine: Godot Engine, MIT License. Full text on the next page."))
	lines.append("")
	lines.append(tr("Thanks for playing."))
	return "\n".join(lines)


func _license_text() -> String:
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


func _apply_scroll() -> void:
	_scroll = clampf(_scroll, 0.0, _max_scroll())
	_body.position.y = -roundf(_scroll)
	if _frame:
		_frame.queue_redraw()


func _input(event: InputEvent) -> void:
	if not _ready_for_input:
		return
	var handled := true
	if event.is_action_pressed("ui_down", true):
		_scroll += SCROLL_STEP
		_apply_scroll()
	elif event.is_action_pressed("ui_up", true):
		_scroll -= SCROLL_STEP
		_apply_scroll()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		_show_page(1 - _page)
		Game.sfx("ui_move", -10.0)
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP]:
		_scroll += SCROLL_STEP * (1.0 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1.0)
		_apply_scroll()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept") \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE):
		_ready_for_input = false
		Game.sfx("ui_back", -8.0)
		closed.emit()
		queue_free()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()
