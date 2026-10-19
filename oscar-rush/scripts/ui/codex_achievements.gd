class_name CodexAchievements
extends Control
## 总图鉴的第一册"成就"（codex_menu.gd 里用，10-18 作者要的）。立绘添加会话做的；成就本身在 achievements.gd。
## 左边 5×3 格徽章（拿到的是铜 / 银 / 金色，没拿到是灰色剪影），右边大徽章、名字、拿没拿到、怎么拿、进度条。
## 隐藏成就没拿到时名字和说明都显示 ???。

const WARM := UiStyle.WARM
const TEXT := UiStyle.TEXT
const DIM := UiStyle.DIM
const LIT_FILL := Color(0.19, 0.175, 0.18)

const COLS := 5
const TILE := Vector2(44, 44)
const TILE_GAP := 5.0
const GRID := Vector2(14, 54)
const DETAIL := Rect2(268, 54, 200, 188)

var embedded := true
var _sel := 0
var _time := 0.0
var _ready_for_input := false

var _base: Control
var _count: Label
var _name: Label
var _state: Label
var _desc: Label
var _prog: Label


func _ready() -> void:
	size = Vector2(480, 270)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base = Control.new()
	_base.size = size
	_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base.draw.connect(_draw_base)
	add_child(_base)
	_count = _label(GRID.x, 33, 240, WARM, HORIZONTAL_ALIGNMENT_LEFT)
	var x := DETAIL.position.x + 8
	var w := DETAIL.size.x - 16
	_name = _label(x, DETAIL.position.y + 80, w, WARM, HORIZONTAL_ALIGNMENT_CENTER)
	_state = _label(x, DETAIL.position.y + 93, w, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_desc = _label(x, DETAIL.position.y + 114, w, TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.label_settings.line_spacing = Lang.tight_line()
	_prog = _label(x, DETAIL.end.y - 30, w, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_select(0)
	await get_tree().process_frame
	_ready_for_input = true


func _label(x: float, y: float, w: float, color: Color, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.label_settings = Hud.small_text(color)
	l.horizontal_alignment = align
	l.position = Vector2(x, y)
	l.size = Vector2(w, 15)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _count_all() -> int:
	return Achievements.LIST.size()


func _tile_rect(i: int) -> Rect2:
	return Rect2(GRID.x + (i % COLS) * (TILE.x + TILE_GAP), GRID.y + (i / COLS) * (TILE.y + TILE_GAP), TILE.x, TILE.y)


func _process(delta: float) -> void:
	_time += delta
	_base.queue_redraw()


## 开着这一册时有成就刚解锁、或开发者模式全开 / 清空：重新填字
func refresh() -> void:
	_select(_sel)


func _select(i: int) -> void:
	_sel = clampi(i, 0, _count_all() - 1)
	var a: Array = Achievements.LIST[_sel]
	var done := Achievements.is_done(a[0])
	var hidden: bool = a[5] and not done
	_count.text = tr("ACHIEVEMENTS") + "   " + tr("%d / %d unlocked") % [Achievements.count_done(), _count_all()]
	_name.text = "???" if hidden else tr(a[1])
	_name.label_settings.font_color = WARM if done else DIM
	_state.text = tr("UNLOCKED") if done else tr("LOCKED")
	_desc.text = "???" if hidden else tr(a[2])
	var p := Achievements.progress(a[0])
	_prog.text = "" if p.is_empty() or done else "%d / %d" % [p[0], p[1]]


## 总图鉴调：用掉了返回 true
func handle(event: InputEvent) -> bool:
	if not _ready_for_input:
		return false
	if event is InputEventMouseMotion:
		var m := get_local_mouse_position()
		for i in _count_all():
			if i != _sel and _tile_rect(i).has_point(m):
				_select(i)
		return false
	var to := _sel
	if event.is_action_pressed("ui_left", true):
		to = _sel - 1 if _sel % COLS > 0 else _sel
	elif event.is_action_pressed("ui_right", true):
		to = _sel + 1 if _sel % COLS < COLS - 1 and _sel + 1 < _count_all() else _sel
	elif event.is_action_pressed("ui_up", true):
		to = _sel - COLS if _sel >= COLS else _sel
	elif event.is_action_pressed("ui_down", true):
		to = _sel + COLS if _sel + COLS < _count_all() else _sel
	elif event.is_action_pressed("ui_accept"):
		return true
	else:
		return false
	if to != _sel:
		_select(to)
		Game.sfx("ui_move", -12.0)
	return true


func _draw_base() -> void:
	var c := _base
	for i in _count_all():
		var r := _tile_rect(i)
		var id: String = Achievements.LIST[i][0]
		UiStyle.panel(c, r, i == _sel, _time, WARM, LIT_FILL)
		Achievements.draw_badge(c, id, r.position + Vector2(6, 6), 2, Achievements.is_done(id))
	UiStyle.panel(c, DETAIL, true, 0.0)
	# 大徽章（4 倍），拿到的上下轻轻浮一下
	var a: Array = Achievements.LIST[_sel]
	var done := Achievements.is_done(a[0])
	var big := Rect2(DETAIL.get_center().x - 36, DETAIL.position.y + 6, 72, 70)
	c.draw_rect(big, LIT_FILL)
	var bob := roundf(sin(_time * 2.5)) if done and fmod(_time, 2.0) < 1.0 else 0.0
	Achievements.draw_badge(c, a[0], Vector2(big.position.x + 4, big.position.y + 3 + bob), 4, done)
	c.draw_rect(Rect2(DETAIL.position.x + 18, DETAIL.position.y + 110, DETAIL.size.x - 36, 1), UiStyle.BAR_OFF)
	# 进度条（有进度、还没拿到）
	var p := Achievements.progress(a[0])
	if not p.is_empty() and not done and int(p[1]) > 0:
		var bar := Rect2(DETAIL.position.x + 24, DETAIL.end.y - 14, DETAIL.size.x - 48, 4)
		c.draw_rect(bar, UiStyle.BAR_OFF)
		c.draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * clampf(float(p[0]) / float(p[1]), 0.0, 1.0)), bar.size.y)), WARM)
