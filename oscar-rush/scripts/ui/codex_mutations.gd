class_name CodexMutations
extends Control
## 总图鉴的"变异与升级"一册（codex_menu.gd 里用）：上面一排 4 个变异，下面一排 4 个装备升级（格子里只放图标，英文名字太长放不下）。
## 右边是大图标、名字、价钱和规矩、效果说明（带实际数值）。都是商店里的东西，直接全部显示。
## 数值照 mutations.gd、upgrades.gd、player.gd 和策划案第十节"变异的实现和系数"（10-18 武器第三版后复核的表）。
## 改了系数记得改这里的说明（text.csv 的中文也要跟着改）。

const WARM := UiStyle.WARM
const TEXT := UiStyle.TEXT
const DIM := UiStyle.DIM
const LIT_FILL := Color(0.19, 0.175, 0.18)

## [id（同时是图标名）, 名字（和商店一样）, 效果说明（一句一条，各自翻译）]
const MUTATIONS := [
	["rage", "RAGE", ["Damage x1 when calm, up to x2 in panic. Shots turn redder the angrier you get.", "At full panic, every hit does double damage."]],
	["slave", "SLAVE FLASH", ["While the lantern sits on the ground, it fires a small orb at the nearest enemy within 150 each time you attack.", "Orb damage: Flash 40, Rivet 25 (every 4th rivet), Hammer 55."]],
	["echo", "TAPE ECHO", ["0.3 s after each attack, it plays again from where you stand, at 50% damage.", "The Rivet Gun echoes every 3rd rivet. Echoes never echo."]],
	["dynamo", "DYNAMO", ["Every 10 kills: lantern +5.", "The 10 notches under the lantern bar show your progress. More enemies, more healing."]],
]
const GEAR := [
	["charge", "QUICK CHARGE", ["Per level: the Flash Lamp charges 0.08 s faster, the Rivet Gun fires 0.01 s faster, the Steam Hammer cools down 0.2 s faster.", "Charge never drops below 0.35 s, cooldown never below 1.0 s."]],
	["fuel", "BIG TANK", ["Per level: +0.35 s of rocket boot fuel.", "Base fuel is 1.0 s, or 0.7 s while you carry the lantern."]],
	["plating", "PLATING", ["Blocks one hit on the lantern every 20 / 15 / 10 s (Lv1 / Lv2 / Lv3)."]],
	["damping", "DAMPER", ["Per level: emotion rises 20% slower over time.", "At Lv3 it climbs at 40% speed."]],
]

const COLS := 4
const TILE := Vector2(56, 56)
const TILE_GAP := 5.0
const ROW_Y := [68.0, 150.0]
const GRID_X := 14.0
const DETAIL := Rect2(268, 54, 200, 188)

var embedded := true
var _sel := 0
var _time := 0.0
var _ready_for_input := false

var _base: Control
var _headers: Array[Label] = []
var _name: Label
var _cost: Label
var _desc: Label


func _ready() -> void:
	size = Vector2(480, 270)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base = Control.new()
	_base.size = Vector2(480, 270)
	_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base.draw.connect(_draw_base)
	add_child(_base)
	var h1 := _label(GRID_X, ROW_Y[0] - 15, 240, WARM, HORIZONTAL_ALIGNMENT_LEFT)
	h1.text = tr("MUTATIONS") + "   " + tr("2 parts, one at a time")
	var h2 := _label(GRID_X, ROW_Y[1] - 15, 240, WARM, HORIZONTAL_ALIGNMENT_LEFT)
	h2.text = tr("GEAR") + "   " + tr("1 part a level, up to Lv3")
	_headers = [h1, h2]
	var x := DETAIL.position.x + 8
	var w := DETAIL.size.x - 16
	_name = _label(x, DETAIL.position.y + 78, w, WARM, HORIZONTAL_ALIGNMENT_CENTER)
	_cost = _label(x, DETAIL.position.y + 91, w, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_desc = _label(x, DETAIL.position.y + 110, w, TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.label_settings.line_spacing = -2
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


func _count() -> int:
	return MUTATIONS.size() + GEAR.size()


func _entry(i: int) -> Array:
	return MUTATIONS[i] if i < MUTATIONS.size() else GEAR[i - MUTATIONS.size()]


func _tile_rect(i: int) -> Rect2:
	var row := i / COLS
	var col := i % COLS
	return Rect2(GRID_X + col * (TILE.x + TILE_GAP), ROW_Y[row], TILE.x, TILE.y)


func _process(delta: float) -> void:
	_time += delta
	_base.queue_redraw()


func _select(i: int) -> void:
	_sel = clampi(i, 0, _count() - 1)
	var e := _entry(_sel)
	_name.text = tr(e[1])
	if _sel < MUTATIONS.size():
		_cost.text = tr("MUTATION") + "  -  " + tr("2 PARTS")
	else:
		_cost.text = tr("GEAR") + "  -  " + tr("1 PART PER LEVEL")
	_desc.text = "\n".join(PackedStringArray(e[2].map(func(line): return tr(line))))


## 总图鉴调：用掉了返回 true
func handle(event: InputEvent) -> bool:
	if not _ready_for_input:
		return false
	if event is InputEventMouseMotion:
		var m := get_local_mouse_position()
		for i in _count():
			if i != _sel and _tile_rect(i).has_point(m):
				_select(i)
		return false
	var to := _sel
	if event.is_action_pressed("ui_left", true):
		to = _sel - 1 if _sel % COLS > 0 else _sel
	elif event.is_action_pressed("ui_right", true):
		to = _sel + 1 if _sel % COLS < COLS - 1 else _sel
	elif event.is_action_pressed("ui_up", true):
		to = _sel - COLS if _sel >= COLS else _sel
	elif event.is_action_pressed("ui_down", true):
		to = _sel + COLS if _sel + COLS < _count() else _sel
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
	for i in _count():
		var r := _tile_rect(i)
		UiStyle.panel(c, r, i == _sel, _time, WARM, LIT_FILL)
		var idx := maxi(ShopStand.ICON_NAMES.find(_entry(i)[0]), 0)
		UiStyle.icon(c, ShopStand.ICONS, idx, r.position + Vector2(4, 4), 3)
	UiStyle.panel(c, DETAIL, true, 0.0)
	# 详情卡：大图标（4 倍），底下一圈暖光底
	var big := Rect2(DETAIL.get_center().x - 36, DETAIL.position.y + 6, 72, 68)
	c.draw_rect(big, LIT_FILL)
	var idx := maxi(ShopStand.ICON_NAMES.find(_entry(_sel)[0]), 0)
	var bob := roundf(sin(_time * 2.5)) if fmod(_time, 2.0) < 1.0 else 0.0
	UiStyle.icon(c, ShopStand.ICONS, idx, Vector2(big.position.x + 4, big.position.y + 2 + bob), 4)
	c.draw_rect(Rect2(DETAIL.position.x + 18, DETAIL.position.y + 106, DETAIL.size.x - 36, 1), UiStyle.BAR_OFF)
