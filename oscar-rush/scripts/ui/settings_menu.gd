class_name SettingsMenu
extends Control
## 设置界面：开始界面和暂停菜单都把它 new 出来加到自己的 CanvasLayer 里，关掉时发 closed。
## 上下选、左右调、确认键切换；Esc / 手柄 B 返回。鼠标指着就选中，点一下就调。
## 值都在 Settings 自动加载里，改一下就存。另有一页按键说明（CONTROLS）。

signal closed

const WARM := Color8(255, 211, 138)
const DIM := Color(0.55, 0.55, 0.6)
const LIT := Color(1, 1, 1)
const DARK := Color(0.2, 0.2, 0.24)
## 十行（加了环境声）：行距 16，整体上移，底下给两行说明留地方
const TOP := 58.0
const STEP := 16.0
const LABEL_X := 118.0
const VALUE_X := 268.0
const VALUE_W := 96.0

## 每行：显示的名字、Settings 里的字段、类型
const ROWS := [
	["MASTER VOLUME", "master", "volume"],
	["MUSIC", "music", "volume"],
	["AMBIENCE", "ambience", "volume"],
	["SOUND FX", "sfx", "volume"],
	["FULLSCREEN", "fullscreen", "toggle"],
	["PIXEL PERFECT", "pixel_perfect", "toggle"],
	["SCREEN SHAKE", "shake_index", "shake"],
	["LANGUAGE", "language", "language"],
	["CONTROLS", "", "page"],
	["BACK", "", "back"],
]
const SHAKE_NAMES: Array[String] = ["OFF", "LIGHT", "STRONG"]
const ROW_HINTS := {
	"pixel_perfect": "Whole-number scaling for text and menus too. Black borders.",
	"fullscreen": "Also F11.",
	"shake_index": "How hard the screen shakes on hits.",
	"language": "Text language. Switches right away.",
	"ambience": "Machines, wind and fire in the background of each area.",
}
## 没有 Settings 字段的行（CONTROLS 这种）按种类找说明
const KIND_HINTS := {
	"page": "Every key and button.",
}

const CONTROLS_TEXT := """SOLO (keyboard)
Move  A / D  or  Left / Right       Jump  W / Up / Space
Attack  C  (hold or tap, by tool)   Lantern  V  (pick up / put down)
Drop through a platform  S / Down

GAMEPAD
Move  stick / D-pad    Jump  A    Attack  X / RT    Lantern  Y / B

CO-OP on one keyboard
Left half   A D move   W jump   C attack   V lantern   S down
Right half  J L move   I jump   M attack   N lantern   K down"""

var _selected := 0
var _labels: Array[Label] = []
var _values: Array[Label] = []
var _bars: Control
var _hint: Label
var _page: Control
var _on_page := false
var _ready_for_input := false
## 手柄按住连发：手柄的摇杆、十字键没有键盘那样的自动重复，调音量要一下一下拨。
## 按住超过 REPEAT_DELAY 秒后每 REPEAT_STEP 秒再触发一次
const REPEAT_DELAY := 0.35
const REPEAT_STEP := 0.09
var _pad_dir := Vector2i.ZERO
var _pad_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(480, 270)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var back := ColorRect.new()
	back.color = Color(0.02, 0.02, 0.035, 0.86)
	back.size = Vector2(480, 270)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	# 选项外面一张 UiStyle 卡片（和选武器、商店同一套外框）
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size = Vector2(480, 270)
	frame.draw.connect(func() -> void:
		if _labels.is_empty():
			return
		var bottom := _labels[-1].position.y + 20.0
		UiStyle.panel(frame, Rect2(LABEL_X - 14.0, TOP - 8.0, VALUE_X + VALUE_W + 28.0 - LABEL_X, bottom - TOP + 8.0), false, 0.0))
	add_child(frame)
	_label("SETTINGS", 0, 20.0, 480, 22, WARM, 3, HORIZONTAL_ALIGNMENT_CENTER)
	for i in ROWS.size():
		var y := TOP + i * STEP + (6.0 if i >= ROWS.size() - 2 else 0.0)
		_labels.append(_label(ROWS[i][0], LABEL_X, y, 150, 11, DIM, 2))
		_values.append(_label("", VALUE_X, y, VALUE_W, 11, DIM, 2, HORIZONTAL_ALIGNMENT_CENTER))
	_bars = Control.new()
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.size = Vector2(480, 270)
	_bars.draw.connect(_draw_bars)
	add_child(_bars)
	_hint = _label("", 0, 236.0, 480, 11, DIM, 2, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.size.y = 30.0
	_build_page()
	Settings.changed.connect(_refresh)
	# 用成员方法，不用 lambda：这个界面关掉释放后连接会自动断开
	Controls.device_changed.connect(_on_device_changed)
	_refresh()
	# 打开这一下的确认键别被当成第一下操作
	await get_tree().process_frame
	_ready_for_input = true


func _label(text: String, x: float, y: float, w: float, font_size: int, color: Color, outline: int,
		align := HORIZONTAL_ALIGNMENT_LEFT, parent: Node = null) -> Label:
	var l := Label.new()
	var s := Hud.small_text(color)
	s.font_size = font_size
	s.outline_size = outline
	l.label_settings = s
	l.text = text
	l.horizontal_alignment = align
	l.position = Vector2(x, y)
	l.size = Vector2(w, font_size + 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else self).add_child(l)
	return l


func _build_page() -> void:
	_page = Control.new()
	_page.size = Vector2(480, 270)
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.visible = false
	add_child(_page)
	var back := ColorRect.new()
	back.color = Color(0.02, 0.02, 0.035, 0.97)
	back.size = Vector2(480, 270)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(back)
	_label("CONTROLS", 0, 22.0, 480, 22, WARM, 3, HORIZONTAL_ALIGNMENT_CENTER, _page)
	var body := _label(CONTROLS_TEXT, 52.0, 56.0, 380, 11, Color(0.82, 0.82, 0.86), 2, HORIZONTAL_ALIGNMENT_LEFT, _page)
	body.size.y = 180.0
	_label("In game:  Esc / Start  pause      F11  fullscreen", 0, 226.0, 480, 11, WARM, 2, HORIZONTAL_ALIGNMENT_CENTER, _page)
	_label("Esc / B / confirm: back", 0, 248.0, 480, 11, DIM, 2, HORIZONTAL_ALIGNMENT_CENTER, _page)


func _on_device_changed(_pad: bool) -> void:
	_refresh()


func _refresh() -> void:
	for i in ROWS.size():
		var on := i == _selected
		var key: String = ROWS[i][1]
		var kind: String = ROWS[i][2]
		_labels[i].text = ("> " if on else "  ") + tr(ROWS[i][0])
		_labels[i].label_settings.font_color = LIT if on else DIM
		var v := ""
		match kind:
			"toggle":
				v = tr("ON") if Settings.get(key) else tr("OFF")
			"shake":
				v = tr(SHAKE_NAMES[Settings.shake_index])
			"language":
				v = Lang.NAMES[Lang.current()]
		if v != "" and on:
			v = "<  %s  >" % v
		_values[i].text = v
		_values[i].label_settings.font_color = (WARM if on else Color(0.75, 0.75, 0.8))
	var keys := tr("%s select    %s change    %s back") % [Controls.label("select"), Controls.label("change"), Controls.label("back")]
	var h: String = ROW_HINTS.get(ROWS[_selected][1], KIND_HINTS.get(ROWS[_selected][2], ""))
	_hint.text = keys if h == "" else tr(h) + "\n" + keys
	_hint.position.y = 246.0 if h == "" else 234.0
	_bars.queue_redraw()


## 音量画成 10 格小方块，位置取整，放大以后还是方的
func _draw_bars() -> void:
	for i in ROWS.size():
		if ROWS[i][2] != "volume":
			continue
		var on := i == _selected
		var step: int = Settings.get(ROWS[i][1])
		var y := TOP + i * STEP + 4.0
		var x0 := VALUE_X + (VALUE_W - (Settings.STEPS * 7 - 1)) * 0.5
		x0 = roundf(x0)
		for k in Settings.STEPS:
			var c := (WARM if on else Color(0.75, 0.75, 0.8)) if k < step else DARK
			_bars.draw_rect(Rect2(x0 + k * 7, y, 6, 7), c)
		if on:
			var arrow := Color(WARM, 0.9)
			_tri(Vector2(x0 - 7, y), -1, arrow)
			_tri(Vector2(x0 + Settings.STEPS * 7 + 2, y), 1, arrow)


## 一个 3×7 的小箭头，一格一格画
func _tri(at: Vector2, dir: int, c: Color) -> void:
	for row in 7:
		var w := 3 - absi(row - 3)
		for k in w:
			var x := at.x + (k if dir > 0 else 2 - k)
			_bars.draw_rect(Rect2(x, at.y + row, 1, 1), c)


func _process(delta: float) -> void:
	if not _ready_for_input or _on_page or not is_visible_in_tree():
		_pad_dir = Vector2i.ZERO
		return
	var dir := _pad_held()
	if dir != _pad_dir:
		_pad_dir = dir
		_pad_t = 0.0
		return
	if dir == Vector2i.ZERO:
		return
	_pad_t += delta
	if _pad_t >= REPEAT_DELAY:
		_pad_t -= REPEAT_STEP
		if dir.y != 0:
			_move(dir.y)
		elif dir.x != 0:
			_change(dir.x)


## 手柄现在按着哪个方向（只看手柄，键盘有自己的重复）
func _pad_held() -> Vector2i:
	for d in Input.get_connected_joypads():
		var x := Input.get_joy_axis(d, JOY_AXIS_LEFT_X)
		var y := Input.get_joy_axis(d, JOY_AXIS_LEFT_Y)
		if Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_UP) or y < -0.6:
			return Vector2i(0, -1)
		if Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_DOWN) or y > 0.6:
			return Vector2i(0, 1)
		if Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_LEFT) or x < -0.6:
			return Vector2i(-1, 0)
		if Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_RIGHT) or x > 0.6:
			return Vector2i(1, 0)
	return Vector2i.ZERO


func _input(event: InputEvent) -> void:
	if not _ready_for_input or not is_visible_in_tree():
		return
	if _on_page:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept") \
				or (event is InputEventMouseButton and event.pressed) \
				or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE):
			_on_page = false
			_page.visible = false
			Game.sfx("ui_back", -8.0)
		accept_event()
		return
	var handled := true
	if event.is_action_pressed("ui_up", true):
		_move(-1)
	elif event.is_action_pressed("ui_down", true):
		_move(1)
	elif event.is_action_pressed("ui_left", true):
		_change(-1)
	elif event.is_action_pressed("ui_right", true):
		_change(1)
	elif event.is_action_pressed("ui_accept"):
		_activate()
	elif event.is_action_pressed("ui_cancel") \
			or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE):
		_close()
	elif event is InputEventMouseMotion:
		var i := _row_at()
		if i >= 0 and i != _selected:
			_selected = i
			Game.sfx("ui_move", -12.0)
			_refresh()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var i := _row_at()
			if i >= 0:
				_selected = i
				var kind: String = ROWS[i][2]
				if kind == "volume" or kind == "shake" or kind == "language":
					_change(-1 if get_global_mouse_position().x < VALUE_X + VALUE_W * 0.5 else 1)
				else:
					_activate()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_change(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_change(-1)
	else:
		handled = false
	if handled:
		accept_event()
		get_viewport().set_input_as_handled()


## 鼠标指着第几行（get_global_mouse_position 已经是 480×270 的坐标），没指着返回 -1
func _row_at() -> int:
	var p := get_global_mouse_position()
	if p.x < LABEL_X - 10.0 or p.x > VALUE_X + VALUE_W + 10.0:
		return -1
	for i in ROWS.size():
		var y := TOP + i * STEP + (6.0 if i >= ROWS.size() - 2 else 0.0)
		if p.y >= y - 1.0 and p.y < y + STEP - 1.0:
			return i
	return -1


func _move(step: int) -> void:
	_selected = posmod(_selected + step, ROWS.size())
	Game.sfx("ui_move", -10.0)
	_refresh()


func _change(dir: int) -> void:
	var key: String = ROWS[_selected][1]
	match ROWS[_selected][2]:
		"volume":
			var v := clampi(int(Settings.get(key)) + dir, 0, Settings.STEPS)
			if v != Settings.get(key):
				Settings.set_value(key, v)
			# 调音效音量时响一下，听得出大小
			Game.sfx("ui_move", -4.0)
		"toggle":
			Settings.set_value(key, not Settings.get(key))
			Game.sfx("ui_confirm", -8.0)
		"shake":
			Settings.set_value(key, clampi(Settings.shake_index + dir, 0, Settings.SHAKE_LEVELS.size() - 1))
			Game.sfx("ui_move", -8.0)
			if Settings.shake_scale() > 0.0:
				Game.add_shake(4.0)
		"language":
			# 只有两种，左右都是换到另一种
			var i := Lang.LANGS.find(Lang.current())
			Settings.set_value("language", Lang.LANGS[posmod(i + dir, Lang.LANGS.size())])
			Game.sfx("ui_confirm", -8.0)


func _activate() -> void:
	match ROWS[_selected][2]:
		"toggle":
			_change(1)
		"shake":
			Settings.set_value("shake_index", (Settings.shake_index + 1) % Settings.SHAKE_LEVELS.size())
			Game.sfx("ui_move", -8.0)
		"volume", "language":
			_change(1)
		"page":
			_on_page = true
			_page.visible = true
			Game.sfx("ui_confirm", -8.0)
		"back":
			_close()


func _close() -> void:
	_ready_for_input = false
	Game.sfx("ui_back", -8.0)
	closed.emit()
	queue_free()
