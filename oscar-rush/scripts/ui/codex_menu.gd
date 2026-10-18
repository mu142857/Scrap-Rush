class_name CodexMenu
extends Control
## 图鉴（开始菜单右上角的书本图标）。一本书三册，最上面一排是册的页签：
##   怪物图鉴（bestiary_menu.gd，embedded 模式嵌进来）、武器图鉴（codex_weapons.gd）、变异与升级（codex_mutations.gd）。
## - 换册：Tab / Shift+Tab、数字键 1~3、手柄 LT/RT、鼠标点页签
## - 册里面：方向键 / WASD / 十字键选；怪物图鉴里 Q/E、LB/RB 换排序，R / Y 反过来排，F / X 筛选精英和 Boss
## - 返回：Esc、手柄 B、右键、点右上角"返回"
## 开始界面用法（游戏细节讨论会话接的）：var page = load("res://scripts/ui/codex_menu.gd").new();
## page.start_chapter = 0; 加到 UI 层; await page.closed（关掉时自己 queue_free）。
## 单独跑 scenes/codex.tscn 时，关掉回开始界面。

signal closed

const WARM := UiStyle.WARM
const DIM := UiStyle.DIM
const CHAPTERS := ["BESTIARY", "WEAPON GUIDE", "MUTATIONS & GEAR"]
const CH_X := 14.0
const CH_Y := 8.0
const CH_W := [84.0, 84.0, 120.0]
const CH_H := 17.0
const CH_GAP := 5.0
const BACK_BTN := Rect2(424, 10, 44, 15)
const TRIGGER_ON := 0.6

## 0 怪物、1 武器、2 变异与升级；add_child 之前设
var start_chapter := 0

var _chapter := 0
var _pages: Array[Control] = []
var _ready_for_input := false
var _time := 0.0
var _frame: Control
var _tab_labels: Array[Label] = []
var _back: Label
var _hint: Label
var _trig := [false, false]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(480, 270)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var back := ColorRect.new()
	back.color = Color(0.02, 0.02, 0.035, 0.95)
	back.size = Vector2(480, 270)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	_frame = Control.new()
	_frame.size = Vector2(480, 270)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.draw.connect(_draw_frame)
	add_child(_frame)

	var monsters := BestiaryMenu.new()
	monsters.embedded = true
	_pages.append(monsters)
	_pages.append(CodexWeapons.new())
	_pages.append(CodexMutations.new())
	for p in _pages:
		p.visible = false
		add_child(p)

	for i in CHAPTERS.size():
		var r := _tab_rect(i)
		var l := Label.new()
		l.label_settings = Hud.small_text(DIM)
		l.text = tr(CHAPTERS[i])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position = r.position + Vector2(0, 2)
		l.size = Vector2(r.size.x, 13)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		_tab_labels.append(l)
	_back = Label.new()
	_back.label_settings = Hud.small_text(DIM)
	_back.text = tr("BACK")
	_back.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_back.position = BACK_BTN.position + Vector2(0, 1)
	_back.size = Vector2(BACK_BTN.size.x, 13)
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_back)
	_hint = Label.new()
	_hint.label_settings = Hud.small_text(DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(0, 251)
	_hint.size = Vector2(480, 13)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	Controls.device_changed.connect(func(_pad: bool) -> void: _show_hint())
	_show_chapter(start_chapter)
	await get_tree().process_frame
	await get_tree().process_frame
	_ready_for_input = true


func _tab_rect(i: int) -> Rect2:
	var x := CH_X
	for j in i:
		x += CH_W[j] + CH_GAP
	return Rect2(x, CH_Y, CH_W[i], CH_H)


func _process(delta: float) -> void:
	_time += delta


func _show_chapter(i: int) -> void:
	_chapter = posmod(i, CHAPTERS.size())
	for j in _pages.size():
		_pages[j].visible = j == _chapter
		_pages[j].process_mode = Node.PROCESS_MODE_INHERIT if j == _chapter else Node.PROCESS_MODE_DISABLED
		_tab_labels[j].label_settings.font_color = WARM if j == _chapter else DIM
	_frame.queue_redraw()
	_show_hint()


func _show_hint() -> void:
	var pad := Controls.using_pad
	var move := Controls.label("select") if pad else "WASD"
	var chapter := "LT/RT" if pad else "Tab"
	if _chapter == 0:
		_hint.text = tr("%s move  %s sort  %s reverse  %s filter  %s chapter  %s back") % [move, "LB/RB" if pad else "Q/E",
			"Y" if pad else "R", "X" if pad else "F", chapter, Controls.label("back")]
	else:
		_hint.text = tr("%s move    %s chapter    %s back") % [move, chapter, Controls.label("back")]


func _draw_frame() -> void:
	for i in CHAPTERS.size():
		var r := _tab_rect(i)
		UiStyle.panel(_frame, r, false, 0.0)
		if i == _chapter:
			_frame.draw_rect(Rect2(r.position.x, r.end.y - 2, r.size.x, 2), WARM)
	UiStyle.panel(_frame, BACK_BTN, false, 0.0)


# ---------------------------------------------------------------- 输入

func _input(event: InputEvent) -> void:
	if not _ready_for_input:
		return
	var handled := true
	var ck := _chapter_key(event)   # 只算一次：扳机按下的那一下要记状态
	if event is InputEventMouseMotion:
		var m := get_local_mouse_position()
		_back.label_settings.font_color = WARM if BACK_BTN.has_point(m) else DIM
		_pages[_chapter].handle(event)
		handled = false
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_close()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and _clicked_chrome(get_local_mouse_position()):
		pass
	elif ck != 0:
		_show_chapter(_chapter + ck)
		Game.sfx("ui_move", -10.0)
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode in [KEY_1, KEY_2, KEY_3]:
		var to: int = [KEY_1, KEY_2, KEY_3].find(event.physical_keycode)
		if to != _chapter:
			_show_chapter(to)
			Game.sfx("ui_move", -10.0)
	elif event.is_action_pressed("ui_cancel") \
			or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE):
		_close()
	elif _pages[_chapter].handle(event):
		pass
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


## 点到页签或"返回"：处理掉返回 true
func _clicked_chrome(m: Vector2) -> bool:
	if BACK_BTN.has_point(m):
		_close()
		return true
	for i in CHAPTERS.size():
		if _tab_rect(i).has_point(m):
			if i != _chapter:
				_show_chapter(i)
				Game.sfx("ui_move", -10.0)
			return true
	return false


## 换册键：Tab / Shift+Tab、手柄 LT/RT（扳机是摇杆轴，按下去那一下才算）。返回 -1 / 1 / 0
func _chapter_key(event: InputEvent) -> int:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB:
		return -1 if event.shift_pressed else 1
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
		var k := 0 if event.axis == JOY_AXIS_TRIGGER_LEFT else 1
		var down: bool = event.axis_value > TRIGGER_ON
		var was: bool = _trig[k]
		_trig[k] = down if (down or event.axis_value < 0.3) else was
		if down and not was:
			return -1 if k == 0 else 1
	return 0


func _close() -> void:
	if not _ready_for_input:
		return
	_ready_for_input = false
	Game.sfx("ui_back", -8.0)
	closed.emit()
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file("res://scenes/title.tscn")
	else:
		queue_free()
