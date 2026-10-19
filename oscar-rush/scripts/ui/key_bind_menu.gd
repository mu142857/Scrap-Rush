class_name KeyBindMenu
extends Control
## 按键设置（设置里的"按键"一行打开；10-18 作者要的改键）。键位规矩、存档都在 Controls（scripts/autoload/controls.gd）。
## 两列：键盘（单人）、手柄。行：左、右、跳、攻击 / 蓄力、放下 / 捡起马灯、下 / 穿过平台，最后一行暂停（固定）。
## 手柄的左、右、下固定用摇杆 / 十字键（显示成灰的，不能改）。下面两行：恢复默认、返回。
## 操作：上下选行，左右换列；确认 → "按下新的键"，按一下就改（键盘列只认键盘、手柄列只认手柄按钮）；
## 等的时候 Esc（或手柄 Start）取消，5 秒不按也取消。鼠标点格子就改，右键返回。
## 新键已经被别的动作用了：两个交换，下面一行写"和 xx 交换了"；Esc、F11、手柄 Start 这些不让占。
## 双人分键盘的左右两套不能改，最下面一行写着。

signal closed

const WARM := Color8(255, 211, 138)
const DIM := Color(0.55, 0.55, 0.6)
const LIT := Color(1, 1, 1)
const TEXT := Color(0.82, 0.82, 0.86)
const TOP := 56.0
const STEP := 16.0
const NAME_X := 70.0
const COL_X: Array[float] = [236.0, 336.0]
const COL_W := 92.0
const WAIT_TIME := 5.0
## [动作, 名字]
const ROWS := [
	["left", "Move left"], ["right", "Move right"], ["jump", "Jump"], ["attack", "Attack / charge"],
	["crystal", "Drop / pick up lantern"], ["down", "Down / drop through"], ["pause", "Pause"],
	["reset", "RESET TO DEFAULTS"], ["back", "BACK"],
]
const NAMES := {"left": "Move left", "right": "Move right", "jump": "Jump", "attack": "Attack / charge",
	"crystal": "Drop / pick up lantern", "down": "Down / drop through"}

var _row := 0
var _col := 0
var _waiting := false
var _wait_t := 0.0
var _time := 0.0
var _labels: Array[Label] = []
var _cells: Array = []        # 每行 [键盘格, 手柄格]（Label，没有的是 null）
var _msg: Label
var _hint: Label
var _draw_layer: Control
var _ready_for_input := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(480, 270)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var back := ColorRect.new()
	back.color = Color(0.02, 0.02, 0.035, 0.97)
	back.size = size
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	_draw_layer = Control.new()
	_draw_layer.size = size
	_draw_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_layer.draw.connect(_draw_sel)
	add_child(_draw_layer)
	_label(tr("CONTROLS"), 0, 18, 480, 22, WARM, 3, HORIZONTAL_ALIGNMENT_CENTER)
	_label(tr("KEYBOARD"), COL_X[0], TOP - 16, COL_W, 11, DIM, 2, HORIZONTAL_ALIGNMENT_CENTER)
	_label(tr("GAMEPAD"), COL_X[1], TOP - 16, COL_W, 11, DIM, 2, HORIZONTAL_ALIGNMENT_CENTER)
	for i in ROWS.size():
		var y := _row_y(i)
		var is_btn := i >= ROWS.size() - 2
		_labels.append(_label("", NAME_X if not is_btn else 0.0, y, 160 if not is_btn else 480, 11, DIM, 2,
				HORIZONTAL_ALIGNMENT_LEFT if not is_btn else HORIZONTAL_ALIGNMENT_CENTER))
		if is_btn:
			_cells.append([null, null])
		else:
			_cells.append([_label("", COL_X[0], y, COL_W, 11, TEXT, 2, HORIZONTAL_ALIGNMENT_CENTER),
				_label("", COL_X[1], y, COL_W, 11, TEXT, 2, HORIZONTAL_ALIGNMENT_CENTER)])
	_msg = _label("", 0, 214, 480, 11, WARM, 2, HORIZONTAL_ALIGNMENT_CENTER)
	_label(tr("Co-op keyboard halves keep their own keys:  A D W C V S  /  J L I M N K"), 0, 230, 480, 11, DIM, 2,
			HORIZONTAL_ALIGNMENT_CENTER)
	_hint = _label("", 0, 248, 480, 11, DIM, 2, HORIZONTAL_ALIGNMENT_CENTER)
	Controls.device_changed.connect(func(_p: bool) -> void: _refresh())
	_refresh()
	await get_tree().process_frame
	_ready_for_input = true


func _row_y(i: int) -> float:
	return TOP + i * STEP + (8.0 if i >= ROWS.size() - 2 else 0.0)


func _label(text: String, x: float, y: float, w: float, font_size: int, color: Color, outline: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	var st := Hud.small_text(color)
	st.font_size = font_size
	st.outline_size = outline
	l.label_settings = st
	l.text = text
	l.horizontal_alignment = align
	l.position = Vector2(x, y)
	l.size = Vector2(w, font_size + 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


## 这一格能不能改
func _editable(i: int, col: int) -> bool:
	var a: String = ROWS[i][0]
	return (a in Controls.REBIND_KB) if col == 0 else (a in Controls.REBIND_PAD)


func _cell_text(i: int, col: int) -> String:
	var a: String = ROWS[i][0]
	if a == "pause":
		# 网页版暂停是 P（Esc 在浏览器全屏时被拿去退出全屏；P、Backspace 在 shell.html 里转成 Esc，等于保留键）
		return ("P" if Lang.web_keys() else "Esc") if col == 0 else "Start"
	if col == 0:
		var keys: Array = Controls.solo_keys(a)
		var t := Controls.key_label(keys[0])
		# 副键（方向键、空格）小一点写在后面
		var extra := []
		for k in keys.slice(1):
			extra.append(Controls.key_label(k))
		return t if extra.is_empty() else t + " / " + " / ".join(extra)
	if a in Controls.REBIND_PAD:
		var t2 := Controls.pad_label(Controls.pad_button(a))
		for b in Controls.PAD_EXTRA.get(a, []):
			var used := false
			for o in Controls.REBIND_PAD:
				if Controls.pad_button(o) == b:
					used = true
			if not used:
				t2 += " / " + Controls.pad_label(b)
		if a == "attack":
			t2 += " / RT"
		return t2
	return tr("Stick / D-pad")


func _refresh() -> void:
	for i in ROWS.size():
		var on := i == _row
		var a: String = ROWS[i][0]
		var name: String = ROWS[i][1]
		_labels[i].text = ("> " if on else "  ") + tr(name)
		_labels[i].label_settings.font_color = LIT if on else DIM
		for col in 2:
			var l: Label = _cells[i][col]
			if l == null:
				continue
			if _waiting and on and col == _col:
				l.text = tr("Press a key...") if col == 0 else tr("Press a button...")
				l.label_settings.font_color = WARM
			else:
				l.text = _cell_text(i, col)
				var c := TEXT if _editable(i, col) else DIM
				l.label_settings.font_color = c if not (on and col == _col) else (LIT if _editable(i, col) else DIM)
	if _waiting:
		_hint.text = tr("Press the new key    Esc / Start  cancel")
	else:
		_hint.text = tr("%s select    %s column    %s change    %s back") % [Controls.label("select"), Controls.label("change"),
				Controls.label("confirm"), Controls.label("back")]
	_draw_layer.queue_redraw()


## 选中的格子画一个细框（和别的菜单一样的角标）
func _draw_sel() -> void:
	if _row >= ROWS.size() - 2:
		return
	var r := Rect2(COL_X[_col] - 2, _row_y(_row) - 2, COL_W + 4, 15)
	UiStyle.corners(_draw_layer, r, _time, WARM if _editable(_row, _col) else DIM, 3.0)


func _process(delta: float) -> void:
	_time += delta
	if _waiting:
		_wait_t -= delta
		if _wait_t <= 0.0:
			_stop_wait("")
	_draw_layer.queue_redraw()


func _input(event: InputEvent) -> void:
	if not _ready_for_input:
		return
	if _waiting:
		_wait_input(event)
		get_viewport().set_input_as_handled()
		return
	var handled := true
	if event.is_action_pressed("ui_up", true):
		_move(-1)
	elif event.is_action_pressed("ui_down", true):
		_move(1)
	elif event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_right", true):
		if _row < ROWS.size() - 2:
			_col = 1 - _col
			Game.sfx("ui_move", -10.0)
			_refresh()
	elif event.is_action_pressed("ui_accept"):
		_activate()
	elif event.is_action_pressed("ui_cancel") \
			or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE) \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		_close()
	elif event is InputEventMouseMotion:
		var hit := _hit()
		if hit.x >= 0 and (hit.x != _row or (hit.y >= 0 and hit.y != _col)):
			_row = hit.x
			if hit.y >= 0:
				_col = hit.y
			Game.sfx("ui_move", -12.0)
			_refresh()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := _hit()
		if hit.x >= 0:
			_row = hit.x
			if hit.y >= 0:
				_col = hit.y
			_activate()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


## 鼠标指着哪一行、哪一列（列 -1 = 不在格子上）
func _hit() -> Vector2i:
	var p := get_local_mouse_position()
	for i in ROWS.size():
		var y := _row_y(i)
		if p.y < y - 2 or p.y > y + 13:
			continue
		if i >= ROWS.size() - 2:
			return Vector2i(i, -1) if absf(p.x - 240.0) < 90.0 else Vector2i(-1, -1)
		for col in 2:
			if p.x >= COL_X[col] - 2 and p.x <= COL_X[col] + COL_W + 2:
				return Vector2i(i, col)
		if p.x >= NAME_X and p.x < COL_X[0]:
			return Vector2i(i, -1)
	return Vector2i(-1, -1)


func _move(step: int) -> void:
	_row = posmod(_row + step, ROWS.size())
	Game.sfx("ui_move", -10.0)
	_refresh()


func _activate() -> void:
	var a: String = ROWS[_row][0]
	match a:
		"back":
			_close()
		"reset":
			Controls.reset_bindings()
			Settings.save()
			Game.sfx("ui_confirm", -8.0)
			_msg.text = tr("All keys are back to default.")
			_refresh()
		_:
			if not _editable(_row, _col):
				Game.sfx("ui_back", -8.0, 0.8)
				_msg.text = tr("This one can't be changed.") if a == "pause" else tr("Gamepad movement always uses the stick and D-pad.")
				return
			_waiting = true
			_wait_t = WAIT_TIME
			_msg.text = ""
			Game.sfx("ui_confirm", -10.0)
			_refresh()


func _wait_input(event: InputEvent) -> void:
	var a: String = ROWS[_row][0]
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			_stop_wait(tr("Cancelled."))
			return
		if _col != 0:
			return
		var r: Dictionary = Controls.rebind_key(a, event.physical_keycode)
		_after(r, a)
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START:
			_stop_wait(tr("Cancelled."))
			return
		if _col != 1:
			return
		var r2: Dictionary = Controls.rebind_pad(a, event.button_index)
		_after(r2, a)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_stop_wait(tr("Cancelled."))


func _after(r: Dictionary, action: String) -> void:
	if not bool(r["ok"]):
		Game.sfx("ui_back", -8.0, 0.8)
		_stop_wait(tr("That one is kept for pause, fullscreen and menus."))
		return
	Settings.save()
	Game.sfx("ui_confirm", -6.0)
	var sw: String = r["swapped"]
	if sw != "":
		_stop_wait(tr('Swapped with "%s".') % tr(NAMES[sw]))
	else:
		_stop_wait(tr('"%s" set.') % tr(NAMES[action]))


func _stop_wait(msg: String) -> void:
	_waiting = false
	_msg.text = msg
	# 刚按下的那个键（比如改成了空格）别漏给底下的菜单当"确认"：等一帧再收输入
	_ready_for_input = false
	_refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	_ready_for_input = true


func _close() -> void:
	_ready_for_input = false
	Game.sfx("ui_back", -8.0)
	closed.emit()
	queue_free()
