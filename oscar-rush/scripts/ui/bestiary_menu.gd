class_name BestiaryMenu
extends Control
## 怪物图鉴界面（开始菜单的 BESTIARY）。数据和收集记录在 bestiary.gd。
## 一个大列表放下全部怪（作者 10-18："第一关第二关加起来都没第三关多，按关卡分页不对，像泰拉瑞亚那样排"）。
## 上面一排是排序：编号（默认，第一关小怪 → 精英 → Boss1 → 第二关……）、生命值、击杀数、类型、首次遇见；
## 右边一个筛选：全部 / 只看精英和 Boss。每格左上角是第几关（I / II / III），左下角是图鉴编号。
## 遇到过的点亮；没遇到的照样在列表里（剪影），名字是"???"。
## - 键盘：方向键 / WASD 选，Q/E（或 PageUp/PageDown）换排序，R 反过来排，F 筛选，Esc 返回
## - 手柄：十字键 / 摇杆选，右摇杆滚，LB/RB 换排序，Y 反过来，X 筛选，B 返回
## - 鼠标：指到哪只选哪只，点排序页签换排序（再点一下反过来），点筛选按钮，滚轮 / 触控板 / 拖动滚，右键或点右上角"返回"
## - 开发者开关：调试版里按 F9 全部点亮（不写存档）。也可以设环境变量 SCRAP_BESTIARY_ALL=1
## 开始界面用法：var page := BestiaryMenu.new(); 加到 UI 层; await page.closed（关掉时自己 queue_free）。
## 单独跑 scenes/bestiary.tscn 时，关掉会回开始界面。
## 总图鉴（codex_menu.gd）里当"怪物图鉴"这一册用：add_child 之前设 embedded = true，
## 这时不画底色、标题、返回、按键提示，也不自己收输入，由 CodexMenu 调 handle(event)；返回键留给 CodexMenu。

signal closed

const WARM := UiStyle.WARM
const TEXT := UiStyle.TEXT
const DIM := UiStyle.DIM
## 精英、Boss 的格子边：暗一点的金色
const GOLD := Color8(176, 132, 74)
## 没遇到的怪：剪影的颜色（比卡片底亮一点，能看出轮廓）
const SIL := Color(0.22, 0.22, 0.28)
## 卡片后面垫的关卡背景：点亮的压暗（不抢怪），没点亮的更暗、再按 BG_MOSAIC 倍打成马赛克
const BG_LIT := Color(0.42, 0.4, 0.45)
const BG_DARK := Color(0.2, 0.2, 0.24)
const BG_MOSAIC := 4
## 基础数据的小图标（7×7，X 是有色的格）：红心 = 生命值、剑 = 碰到伤多少、鞋 = 走多快、闪电 = 几招
const ICON_HEART := [".XX.XX.", "XXXXXXX", "XXXXXXX", ".XXXXX.", "..XXX..", "...X...", "......."]
const ICON_SWORD := ["......X", ".....X.", "....X..", "X..X...", ".XX....", ".XX....", "X..X..."]
const ICON_SHOE := ["..XX...", "..XX...", "..XXX..", "..XXXX.", ".XXXXXX", "XXXXXXX", "......."]
const ICON_BOLT := ["...XX..", "..XX...", ".XXXXX.", "...XX..", "..XX...", ".XX....", "......."]
const STAT_COLORS := [Color8(226, 84, 70), Color8(200, 205, 215), Color8(196, 150, 100), Color8(255, 211, 138)]
## 遇到过的怪：格子底换成亮一档的暖灰（第一、二关的怪本身很暗，要靠底色衬出来；没遇到的格子留黑底）
const LIT_FILL := Color(0.19, 0.175, 0.18)

## 排序页签（和 Bestiary.SORTS 一一对应）
const SORT_NAMES := ["No.", "HP", "KILLS", "TYPE", "FIRST SEEN"]
const TAB_X := 14.0
const TAB_Y := 32.0
const TAB_WS := [40.0, 40.0, 44.0, 40.0, 60.0]
const TAB_H := 15.0
const TAB_GAP := 4.0
## 筛选按钮：全部 / 只看精英和 Boss
const FILTER_BTN := Rect2(268, 32, 96, 15)
## 格子上的小字（3×5 像素）：编号的数字、关卡的罗马数字
const MINI_DIGITS := [
	["XXX", "X.X", "X.X", "X.X", "XXX"], [".X.", "XX.", ".X.", ".X.", "XXX"], ["XXX", "..X", "XXX", "X..", "XXX"],
	["XXX", "..X", ".XX", "..X", "XXX"], ["X.X", "X.X", "XXX", "..X", "..X"], ["XXX", "X..", "XXX", "..X", "XXX"],
	["XXX", "X..", "XXX", "X.X", "XXX"], ["XXX", "..X", ".X.", ".X.", ".X."], ["XXX", "X.X", "XXX", "X.X", "XXX"],
	["XXX", "X.X", "XXX", "..X", "XXX"]]

## 左边的格子区、右边的详情卡
const GRID := Rect2(14, 54, 240, 188)
const DETAIL := Rect2(268, 54, 200, 188)
const GAP := 4.0
## 一行几格、一格多大
const COLS := 5
const TILE := 44.0
## 待机动画一帧多久
const ANIM := 0.18
const BACK_BTN := Rect2(424, 10, 44, 15)
## 能滚的页最后多留的一截（写"到底了"）
const FOOTER := 18.0
## 滚轮一格、手柄右摇杆满推一秒滚多少像素
const WHEEL_STEP := 24.0
const STICK_SPEED := 260.0

const SIL_SHADER := "shader_type canvas_item;
uniform vec4 sil : source_color;
void fragment() { COLOR = vec4(sil.rgb, texture(TEXTURE, UV).a * COLOR.a); }"

## 上次的排序、筛选（关掉再开还是那样）
static var _last_sort := 0
static var _last_reverse := false
static var _last_big := false

var embedded := false

var _sort := 0
var _reverse := false
var _only_big := false
var _sel := 0
## 格子区往下滚了多少像素（按像素滚，触控板、拖动都顺）
var _scroll_px := 0.0
## 拖动：0 没拖、1 拖格子、2 拖滚动条
var _drag := 0
var _drag_from := 0.0
var _drag_start := 0.0
var _list: Array = []
var _time := 0.0
var _ready_for_input := false
var _cache := {}

var _base: Control
var _tiles: Control
var _lit: Control
var _sil: Control
var _det_lit: Control
var _det_sil: Control
var _art_area := Rect2()
var _stat_y := 0.0

var _title: Label
var _tab_labels: Array[Label] = []
var _filter: Label
var _count: Label
var _marks: Control
var _name: Label
var _sub: Label
var _info: Label
var _desc: Label
var _hint: Label
var _back: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("bestiary_menu")
	size = Vector2(480, 270)
	mouse_filter = Control.MOUSE_FILTER_IGNORE if embedded else Control.MOUSE_FILTER_STOP
	if not embedded:
		var back := ColorRect.new()
		back.color = Color(0.02, 0.02, 0.035, 0.95)
		back.size = Vector2(480, 270)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(back)

	var sil_mat := ShaderMaterial.new()
	sil_mat.shader = Shader.new()
	sil_mat.shader.code = SIL_SHADER
	sil_mat.set_shader_parameter("sil", SIL)

	_base = _layer(self)
	_base.draw.connect(_draw_base)
	# 格子区：裁掉滚出去的格子（四周多留 5 格给选中的角标）
	var clip := Control.new()
	clip.position = GRID.position - Vector2(5, 5)
	clip.size = GRID.size + Vector2(10, 10)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	_tiles = _layer(clip)
	_tiles.draw.connect(_draw_tiles)
	_lit = _layer(clip)
	_lit.draw.connect(_draw_icons.bind(_lit, true))
	_sil = _layer(clip)
	_sil.material = sil_mat
	_sil.draw.connect(_draw_icons.bind(_sil, false))
	# 编号、关卡标记画在怪上面一层，不被大个子的怪挡住
	_marks = _layer(clip)
	_marks.draw.connect(_draw_marks)
	for l in [_tiles, _lit, _sil, _marks]:
		l.position = Vector2(5, 5)
	_det_lit = _layer(self)
	_det_lit.draw.connect(_draw_detail_art.bind(_det_lit, true))
	_det_sil = _layer(self)
	_det_sil.material = sil_mat
	_det_sil.draw.connect(_draw_detail_art.bind(_det_sil, false))

	_title = _label(0, 6, 480, 22, WARM, HORIZONTAL_ALIGNMENT_CENTER)
	_title.text = tr("BESTIARY")
	for i in SORT_NAMES.size():
		var r := _tab_rect(i)
		var l := _label(r.position.x, TAB_Y + 1, r.size.x, 11, DIM, HORIZONTAL_ALIGNMENT_CENTER)
		l.text = tr(SORT_NAMES[i])
		_tab_labels.append(l)
	_filter = _label(FILTER_BTN.position.x, TAB_Y + 1, FILTER_BTN.size.x, 11, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_count = _label(FILTER_BTN.end.x, TAB_Y + 1, DETAIL.end.x - FILTER_BTN.end.x, 11, DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_back = _label(BACK_BTN.position.x, BACK_BTN.position.y + 1, BACK_BTN.size.x, 11, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_back.text = tr("BACK")
	var w := DETAIL.size.x - 12
	_name = _label(DETAIL.position.x + 6, 0, w, 11, WARM, HORIZONTAL_ALIGNMENT_CENTER)
	_sub = _label(DETAIL.position.x + 6, 0, w, 11, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_info = _label(DETAIL.position.x + 6, 0, w, 11, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_desc = _label(DETAIL.position.x + 6, 0, w, 11, TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	_desc.label_settings.line_spacing = Lang.tight_line()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint = _label(0, 251, 480, 11, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	for l in [_title, _back, _hint]:
		l.visible = not embedded

	Controls.device_changed.connect(func(_pad: bool) -> void: _show_hint())
	_reverse = _last_reverse
	_only_big = _last_big
	_show_sort(_last_sort)
	await get_tree().process_frame
	_ready_for_input = true


## 开发者模式改了图鉴记录以后，让开着的图鉴界面马上刷新
static func refresh_open(tree: SceneTree) -> void:
	for n in tree.get_nodes_in_group("bestiary_menu"):
		n._show_sort(n._sort)


func _layer(parent: Control) -> Control:
	var c := Control.new()
	c.size = Vector2(480, 270)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


func _label(x: float, y: float, w: float, font_size: int, color: Color, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	var s := Hud.small_text(color)
	s.font_size = font_size
	s.outline_size = 3 if font_size > 11 else 2
	l.label_settings = s
	l.horizontal_alignment = align
	l.position = Vector2(x, y)
	l.size = Vector2(w, font_size + 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _process(delta: float) -> void:
	var before := int(_time / ANIM)
	_time += delta
	# 角标一直在跳；动画每 ANIM 秒才换一帧
	_tiles.queue_redraw()
	if _scrollable():
		_base.queue_redraw()
		# 手柄右摇杆上下：直接滚（左摇杆、十字键是选）
		var ry := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
		if absf(ry) > 0.25 and visible and _ready_for_input:
			_scroll_to(_scroll_px + ry * STICK_SPEED * delta)
	if int(_time / ANIM) != before:
		_lit.queue_redraw()
		_det_lit.queue_redraw()


# ---------------------------------------------------------------- 翻页、选择

func _tab_rect(i: int) -> Rect2:
	var x := TAB_X
	for j in i:
		x += TAB_WS[j] + TAB_GAP
	return Rect2(x, TAB_Y, TAB_WS[i], TAB_H)


## 换排序 / 反过来 / 筛选以后重排；选中的那只换了位置也跟着它
func _show_sort(i: int) -> void:
	var keep: Dictionary = _list[_sel] if _sel < _list.size() else {}
	_sort = posmod(i, SORT_NAMES.size())
	_last_sort = _sort
	_last_reverse = _reverse
	_last_big = _only_big
	Bestiary.flush()
	_list = Bestiary.listed(Bestiary.SORTS[_sort], _reverse, _only_big)
	for j in _tab_labels.size():
		_tab_labels[j].label_settings.font_color = WARM if j == _sort else DIM
	_filter.text = tr("ELITES & BOSSES") if _only_big else tr("ALL")
	_filter.label_settings.font_color = WARM if _only_big else DIM
	var seen := Bestiary.count_seen(_list)
	_count.text = tr("Seen %d / %d") % [seen, _list.size()]
	if Bestiary.reveal_all:
		_count.text = tr("DEV") + "  " + _count.text
	_count.label_settings.font_color = UiStyle.POOR if Bestiary.reveal_all else DIM
	var at := _list.find(keep) if not keep.is_empty() else -1
	_sel = maxi(at, 0)
	_scroll_px = 0.0
	_select(_sel)
	_show_hint()


func _select(i: int) -> void:
	if _list.is_empty():
		return
	_sel = clampi(i, 0, _list.size() - 1)
	# 选中的那格滚出可见区就跟着滚；选到最后一行时滚到底，露出"到底了"
	var cols := COLS
	var tile := TILE
	var row := _sel / cols
	var top := row * (tile + GAP)
	if row == _total_rows() - 1:
		_scroll_px = _max_scroll()
	elif top < _scroll_px:
		_scroll_px = top
	elif top + tile > _scroll_px + GRID.size.y:
		_scroll_px = top + tile - GRID.size.y
	_scroll_px = clampf(_scroll_px, 0.0, _max_scroll())
	_show_detail()
	_redraw_all()


func _move(dx: int, dy: int) -> void:
	var cols := COLS
	if dx != 0:
		# 一个大列表：左右走到头就停（一行的最后一格再往右，走到下一行开头）
		var to := clampi(_sel + dx, 0, _list.size() - 1)
		if to == _sel:
			return
		_select(to)
	else:
		var to := _sel + dy * cols
		if to < 0:
			return
		if to >= _list.size():
			# 往下没有正下方那只时，落到最后一只（同一行就不动）
			if (_list.size() - 1) / cols == _sel / cols:
				return
			to = _list.size() - 1
		_select(to)
	Game.sfx("ui_move", -12.0)


func _visible_rows() -> int:
	var tile := TILE
	return maxi(1, int((GRID.size.y + GAP) / (tile + GAP)))


func _total_rows() -> int:
	var cols := COLS
	return (_list.size() + cols - 1) / cols


## 格子能滚就在最后多留一截，写"到底了"
func _scrollable() -> bool:
	return _total_rows() > _visible_rows()


func _content_h() -> float:
	var tile := TILE
	return _total_rows() * (tile + GAP) - GAP + (FOOTER if _scrollable() else 0.0)


func _max_scroll() -> float:
	return maxf(0.0, _content_h() - GRID.size.y)


func _scroll_to(px: float) -> void:
	var to := clampf(px, 0.0, _max_scroll())
	if absf(to - _scroll_px) < 0.01:
		return
	_scroll_px = to
	_redraw_all()


## 这一格有没有露在格子区里（露一半也算）
func _row_visible(i: int) -> bool:
	var r := _tile_rect(i)
	return r.end.y > GRID.position.y and r.position.y < GRID.end.y


func _tile_rect(i: int) -> Rect2:
	var cols := COLS
	var tile := TILE
	var col := i % cols
	var row := i / cols
	return Rect2(GRID.position.x + col * (tile + GAP), GRID.position.y + row * (tile + GAP) - roundf(_scroll_px), tile, tile)


func _track() -> Rect2:
	return Rect2(GRID.end.x + 5, GRID.position.y, 2, GRID.size.y)


func _thumb() -> Rect2:
	var t := _track()
	var h := maxf(8.0, roundf(t.size.y * GRID.size.y / _content_h()))
	var y := t.position.y + roundf((t.size.y - h) * _scroll_px / maxf(1.0, _max_scroll()))
	return Rect2(t.position.x, y, 2, h)


## 拖滚动条：滑块中间跟着鼠标
func _drag_bar(y: float) -> void:
	var t := _track()
	var h := _thumb().size.y
	_scroll_to((y - t.position.y - h / 2.0) / maxf(1.0, t.size.y - h) * _max_scroll())


func _redraw_all() -> void:
	for c in [_base, _tiles, _lit, _sil, _marks, _det_lit, _det_sil]:
		c.queue_redraw()


# ---------------------------------------------------------------- 右边的详情

func _show_detail() -> void:
	var e: Dictionary = _list[_sel]
	var on := Bestiary.lit(e)
	var chapter: String = e["chapter"]
	_name.text = tr(e["name"]) if on else "???"
	_sub.text = tr(e["title"]) if on and e["kind"] == "elite" else ""
	# 出处：第几关、哪个屏幕、精英还是 Boss
	var parts: PackedStringArray = []
	if chapter == "boss":
		parts.append(tr(e["title"]))
	else:
		parts.append(tr("LEVEL " + chapter))
		if e.has("where"):
			parts.append(tr(e["where"]))
		if e["kind"] == "elite":
			parts.append(tr("ELITE"))
	if on:
		parts.append(tr("Killed %d") % Bestiary.kills(e["id"]))
	_info.text = ("#%03d" % e["no"] if int(e["no"]) > 0 else "#---") + "  " + "  -  ".join(parts)
	_info.label_settings.font_color = DIM
	if e.get("unreleased", false):
		_info.text = tr("Not in the game yet")
		_info.label_settings.font_color = UiStyle.POOR
	if not on:
		_desc.text = tr("Not encountered yet.")
		_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		var d := tr(e["desc"])
		if e.has("where") and e["kind"] != "elite":
			d = tr("Crawled out of the %s screen.") % tr(e["where"]) + _gap() + d
		elif e.has("where"):
			d = tr("Elite.") + _gap() + d
		_desc.text = d
		_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# 字从卡片底往上排：说明 → 出处 → 标语 → 名字，剩下的高度全给大图
	var x := DETAIL.position.x + 6
	_desc.size = Vector2(DETAIL.size.x - 12, 0)
	_desc.size.y = _desc.get_minimum_size().y
	_desc.position = Vector2(x, DETAIL.end.y - 5 - _desc.size.y)
	_stat_y = _desc.position.y - 13
	_info.position.y = _stat_y - 15
	var top := _info.position.y
	_sub.visible = _sub.text != ""
	if _sub.visible:
		_sub.position.y = top - 13
		top = _sub.position.y
	_name.position.y = top - 14
	_art_area = Rect2(DETAIL.position.x + 6, DETAIL.position.y + 8, DETAIL.size.x - 12, _name.position.y - DETAIL.position.y - 10)


## 两句话之间：英文空一格，中文不空
func _gap() -> String:
	return "" if TranslationServer.get_locale().begins_with("zh") else " "


func _show_hint() -> void:
	var pad := Controls.using_pad
	_hint.text = tr("%s move  %s sort  %s reverse  %s filter  %s back") % [
		Controls.label("select") if pad else "WASD", "LB/RB" if pad else "Q/E", "Y" if pad else "R", "X" if pad else "F",
		Controls.label("back")]


# ---------------------------------------------------------------- 画

func _draw_base() -> void:
	var c := _base
	# 排序页签：选中的下面一道暖黄；反过来排时页签右上角一个朝上的小三角，正着排朝下
	for i in SORT_NAMES.size():
		var r := _tab_rect(i)
		UiStyle.panel(c, r, false, 0.0)
		if i == _sort:
			c.draw_rect(Rect2(r.position.x, r.end.y - 2, r.size.x, 2), WARM)
			var tip := Vector2(r.end.x - 5, r.position.y + 3)
			for y in 3:
				var w := 5 - y * 2 if not _reverse else 1 + y * 2
				c.draw_rect(Rect2(tip.x - w / 2, tip.y + y, w, 1), WARM)
	UiStyle.panel(c, FILTER_BTN, _only_big, 0.0, GOLD)
	if not embedded:
		UiStyle.panel(c, BACK_BTN, false, 0.0)
	# 详情卡：选中的是精英 / Boss 就换金边
	var e: Dictionary = _list[_sel] if not _list.is_empty() else {}
	var big: bool = not e.is_empty() and e["kind"] != "mob" and Bestiary.lit(e)
	UiStyle.panel(c, DETAIL, big, 0.0, GOLD)
	if not e.is_empty():
		_draw_bg(c, e, _art_area.grow(2), Bestiary.lit(e))
		_draw_stats(c, e, Bestiary.lit(e))
	# 名字下面一道细线，把大图和字分开
	if not e.is_empty():
		var y := _name.position.y - 3
		c.draw_rect(Rect2(DETAIL.position.x + 20, y, DETAIL.size.x - 40, 1), UiStyle.BAR_OFF)
	# 滚动条：格子比一屏多的时候才画（可以拖）；下面还有就在格子区右下角闪一个小三角
	if _scrollable():
		c.draw_rect(_track(), UiStyle.BAR_OFF)
		c.draw_rect(_thumb(), WARM if _drag == 2 else DIM)
		if _scroll_px < _max_scroll() - 0.5 and fmod(_time, 1.0) < 0.7:
			var tip := Vector2(GRID.end.x + 6, GRID.end.y + 4)
			for y in 3:
				c.draw_rect(Rect2(tip.x - 2 + y, tip.y - 2 + y, 5 - y * 2, 1), WARM)


func _draw_tiles() -> void:
	var c := _tiles
	for i in _list.size():
		var r := _tile_rect(i)
		if not _row_visible(i):
			continue
		r.position -= GRID.position   # 格子层的原点在格子区左上角
		var e: Dictionary = _list[i]
		UiStyle.panel(c, r, i == _sel, _time, WARM, LIT_FILL if Bestiary.lit(e) else UiStyle.PANEL)
		_draw_bg(c, e, r.grow(-1), Bestiary.lit(e))
		if i != _sel and e["kind"] != "mob" and Bestiary.lit(e):
			_edge(c, r, GOLD)   # 精英、Boss：金边
	# 滚到底：最后一行下面写"到底了"
	if _scrollable():
		var y := _content_h() - FOOTER + GAP - roundf(_scroll_px)
		if y < GRID.size.y:
			c.draw_string(Hud.font(), Vector2(0, y + 12), tr("End of the list"), HORIZONTAL_ALIGNMENT_CENTER, GRID.size.x, 11, DIM)


## 关卡背景：从图集那一格中间裁一块和 dest 一样大的（1:1，像素不糊）；没点亮的取 1/4 大小再放大，成马赛克
func _draw_bg(c: CanvasItem, e: Dictionary, dest: Rect2, lit: bool) -> void:
	var tex := Bestiary.bg_texture()
	if tex == null:
		return
	var cell := Bestiary.bg_cell(e)
	var size := Vector2(minf(dest.size.x, cell.size.x), minf(dest.size.y, cell.size.y)).floor()
	var at := (dest.position + (dest.size - size) / 2.0).round()
	var src := Rect2(cell.position + ((cell.size - size) / 2.0).floor(), size)
	if not lit:
		src = Rect2(src.position + src.size * (0.5 - 0.5 / BG_MOSAIC), (src.size / BG_MOSAIC).ceil())
	c.draw_texture_rect_region(tex, Rect2(at, size), src, BG_LIT if lit else BG_DARK)


## 基础数据一行：红心 生命值、剑 碰撞伤害、鞋 速度（5 档小格）、闪电 招式数；没点亮的都是 ???
func _draw_stats(c: CanvasItem, e: Dictionary, lit: bool) -> void:
	var st := Bestiary.stats(e)
	var font := Hud.font()
	var chips: Array = []   # [图标, 颜色, 文字（"" = 画速度格）, 宽]
	chips.append([ICON_HEART, 0, str(st["hp"]) if lit else "???"])
	chips.append([ICON_SWORD, 1, str(st["atk"]) if lit else "???"])
	if int(st["spd"]) >= 0:
		chips.append([ICON_SHOE, 2, "" if lit else "???"])
	if int(st["moves"]) > 0:
		chips.append([ICON_BOLT, 3, (tr("%d moves") % st["moves"]) if lit else "???"])
	var total := 0.0
	for ch in chips:
		var w: float = 20.0 if ch[2] == "" else font.get_string_size(ch[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		ch.append(9.0 + w)
		total += ch[3]
	total += 9.0 * (chips.size() - 1)
	var x := roundf(DETAIL.get_center().x - total / 2.0)
	var y := _stat_y + 2
	for ch in chips:
		var col: Color = STAT_COLORS[ch[1]] if lit else UiStyle.DIM
		var rows: Array = ch[0]
		for ry in rows.size():
			var row: String = rows[ry]
			for rx in row.length():
				if row[rx] == "X":
					c.draw_rect(Rect2(x + rx, y + ry, 1, 1), col)
		if ch[2] == "":
			for k in 5:
				c.draw_rect(Rect2(x + 9 + k * 4, y + 3, 3, 2), WARM if k < int(st["spd"]) else UiStyle.BAR_OFF)
			if int(st["spd"]) == 0:
				c.draw_rect(Rect2(x + 9, y + 3, 19, 2), UiStyle.BAR_OFF)
		else:
			c.draw_string(font, Vector2(x + 9, y + 7), ch[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEXT if lit else DIM)
		x += ch[3] + 9.0


## 格子上的小字：左上角第几关（I / II / III，Boss 用金色），左下角图鉴编号（3×5 像素的数字，底下垫一块暗色）
func _draw_marks() -> void:
	var c := _marks
	for i in _list.size():
		if not _row_visible(i):
			continue
		var r := _tile_rect(i)
		r.position -= GRID.position
		var e: Dictionary = _list[i]
		var on := Bestiary.lit(e)
		var col := TEXT if on else UiStyle.DIM
		var lv: int = e["level"]
		var lv_col := GOLD.lerp(WARM, 0.4) if e["kind"] == "boss" and on else col
		c.draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(lv * 2 + 1, 7)), Color(0, 0, 0, 0.55))
		for k in lv:
			c.draw_rect(Rect2(r.position + Vector2(3 + k * 2, 3), Vector2(1, 5)), lv_col)
		var no: int = e["no"]
		var digits := ("%03d" % no) if no > 0 else "---"
		var at := r.position + Vector2(2, r.size.y - 9)
		c.draw_rect(Rect2(at, Vector2(digits.length() * 4 + 1, 7)), Color(0, 0, 0, 0.55))
		for d in digits.length():
			var ch := digits[d]
			var p := at + Vector2(1 + d * 4, 1)
			if ch == "-":
				c.draw_rect(Rect2(p + Vector2(0, 2), Vector2(3, 1)), col)
				continue
			var rows: Array = MINI_DIGITS[int(ch)]
			for y in 5:
				var row: String = rows[y]
				for x in 3:
					if row[x] == "X":
						c.draw_rect(Rect2(p + Vector2(x, y), Vector2.ONE), col)


func _edge(c: CanvasItem, r: Rect2, col: Color) -> void:
	c.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), col)
	c.draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), col)
	c.draw_rect(Rect2(r.position.x, r.position.y, 1, r.size.y), col)
	c.draw_rect(Rect2(r.end.x - 1, r.position.y, 1, r.size.y), col)


func _draw_icons(c: Control, lit: bool) -> void:
	for i in _list.size():
		var e: Dictionary = _list[i]
		if Bestiary.lit(e) != lit:
			continue
		var r := _tile_rect(i)
		if not _row_visible(i):
			continue
		r.position -= GRID.position
		var f := _frame(e) if i == _sel else int(e["frames"][0])
		_draw_mob(c, e, f, r.grow(-3), 2)


func _draw_detail_art(c: Control, lit: bool) -> void:
	if _list.is_empty():
		return
	var e: Dictionary = _list[_sel]
	if Bestiary.lit(e) != lit:
		return
	_draw_mob(c, e, _frame(e), _art_area.grow(-4), 4)


func _frame(e: Dictionary) -> int:
	var frames: Array = e["frames"]
	return int(frames[int(_time / ANIM) % frames.size()])


## 按整数倍放大画进 area（脚底贴着 area 底边往上留一点，居中）。太大放不下才缩小
func _draw_mob(c: CanvasItem, e: Dictionary, frame: int, area: Rect2, max_scale: int) -> void:
	var info := _art(e)
	if info.is_empty():
		return
	var box: Rect2i = info["box"]
	var fit := minf(area.size.x / box.size.x, area.size.y / box.size.y)
	var s := clampf(floorf(fit), 1.0, float(max_scale)) if fit >= 1.0 else fit
	var sz := (Vector2(box.size) * s).round()
	var at := (area.position + (area.size - sz) * Vector2(0.5, 0.5)).round()
	var fw: int = info["fw"]
	frame = clampi(frame, 0, int(e["hframes"]) - 1)
	for t: Texture2D in info["texs"]:
		c.draw_texture_rect_region(t, Rect2(at, sz), Rect2(frame * fw + box.position.x, box.position.y, box.size.x, box.size.y))


## 贴图、单帧宽度、所有待机帧合起来的不透明范围（只画这块，放大时不浪费地方，动画也不会抖）
func _art(e: Dictionary) -> Dictionary:
	var id: String = e["id"]
	if _cache.has(id):
		return _cache[id]
	# 第一、二关的小怪、精英：帧数和贴图以怪自己的脚本为准（Bestiary.stats 里读的），免得有人改了贴图、这里没跟上。
	# 第三关不用：第三关精英进场（_ready）才换成 l3_elite_art.gd 的大号图，_setup 读到的还是原图；图鉴里已经按大号图登记了
	if e["kind"] != "boss" and not e.has("layers") and not e.has("key"):
		var st := Bestiary.stats(e)
		if st.has("hframes"):
			e["hframes"] = st["hframes"]
		if st.has("tex") and ResourceLoader.exists(st["tex"]):
			e["tex"] = st["tex"]
	var paths: Array = e.get("layers", [e.get("tex", "")])
	var texs: Array[Texture2D] = []
	for p: String in paths:
		if ResourceLoader.exists(p):
			texs.append(load(p))
	if texs.is_empty():
		_cache[id] = {}
		return {}
	var hf: int = e["hframes"]
	var fw := texs[0].get_width() / hf
	var h := texs[0].get_height()
	var box := Rect2i()
	for t in texs:
		var img := t.get_image()
		if img == null:
			continue
		if img.is_compressed():
			img.decompress()
		for f in e["frames"]:
			var fi := clampi(int(f), 0, hf - 1)
			var used := img.get_region(Rect2i(fi * fw, 0, fw, h)).get_used_rect()
			if used.size == Vector2i.ZERO:
				continue
			box = used if box.size == Vector2i.ZERO else box.merge(used)
	if box.size == Vector2i.ZERO:
		box = Rect2i(0, 0, fw, h)
	var info := {"texs": texs, "fw": fw, "box": box}
	_cache[id] = info
	return info


# ---------------------------------------------------------------- 输入

func _input(event: InputEvent) -> void:
	if not embedded and handle(event):
		get_viewport().set_input_as_handled()


## 处理一个输入，用掉了返回 true。嵌在总图鉴里时，返回、右键、Esc 不在这里处理（交给 CodexMenu）
func handle(event: InputEvent) -> bool:
	if not _ready_for_input:
		return false
	var handled := true
	if event is InputEventMouseMotion:
		handled = false
		var m := get_local_mouse_position()
		if _drag == 1:
			# 按住格子上下拖（像手机那样），拖动过程中不改选中
			_scroll_to(_drag_start - (m.y - _drag_from))
		elif _drag == 2:
			_drag_bar(m.y)
		elif GRID.has_point(m):
			for i in _list.size():
				if i != _sel and _row_visible(i) and _tile_rect(i).has_point(m):
					_select(i)
					break
		_back.label_settings.font_color = WARM if BACK_BTN.has_point(m) else DIM
	elif event is InputEventPanGesture:
		# Mac 触控板两指滑动是 PanGesture，不是滚轮（作者 10-18 反馈"第三关的怪物无法向下滑动"）
		_scroll_to(_scroll_px + event.delta.y * 12.0)
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		handled = _drag != 0
		_drag = 0
		_base.queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		var m := get_local_mouse_position()
		match event.button_index:
			MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP:
				# 浏览器里一下滚很多格时只发一个事件，格数在 factor 里
				var k: float = event.factor if event.factor > 0.0 else 1.0
				_scroll_to(_scroll_px + WHEEL_STEP * k * (1.0 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1.0))
			MOUSE_BUTTON_RIGHT:
				if embedded:
					return false
				_close()
			MOUSE_BUTTON_LEFT:
				if BACK_BTN.has_point(m) and not embedded:
					_close()
				if _scrollable() and _track().grow_individual(3, 0, 6, 0).has_point(m):
					_drag = 2
					_drag_bar(m.y)
				elif GRID.has_point(m):
					_drag = 1
					_drag_from = m.y
					_drag_start = _scroll_px
				for i in SORT_NAMES.size():
					if _tab_rect(i).has_point(m):
						# 点别的排序换过去；再点一下当前的就反过来排
						if i == _sort:
							_reverse = not _reverse
						else:
							_reverse = false
						_show_sort(i)
						Game.sfx("ui_move", -10.0)
				if FILTER_BTN.has_point(m):
					_toggle_filter()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F9 \
			and (OS.is_debug_build() or OS.get_environment("SCRAP_BESTIARY_ALL") == "1"):
		Bestiary.reveal_all = not Bestiary.reveal_all
		_show_sort(_sort)
	elif _is_tab_key(event, -1):
		_reverse = false
		_show_sort(_sort - 1)
		Game.sfx("ui_move", -10.0)
	elif _is_tab_key(event, 1):
		_reverse = false
		_show_sort(_sort + 1)
		Game.sfx("ui_move", -10.0)
	elif _is_key(event, KEY_R, JOY_BUTTON_Y):
		_reverse = not _reverse
		_show_sort(_sort)
		Game.sfx("ui_move", -10.0)
	elif _is_key(event, KEY_F, JOY_BUTTON_X):
		_toggle_filter()
	elif event.is_action_pressed("ui_left", true):
		_move(-1, 0)
	elif event.is_action_pressed("ui_right", true):
		_move(1, 0)
	elif event.is_action_pressed("ui_up", true):
		_move(0, -1)
	elif event.is_action_pressed("ui_down", true):
		_move(0, 1)
	elif event.is_action_pressed("ui_cancel") \
			or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE):
		if embedded:
			return false
		_close()
	elif event.is_action_pressed("ui_accept"):
		pass   # 确认键在这一页没有用，吃掉免得漏到开始菜单
	else:
		handled = false
	return handled


func _toggle_filter() -> void:
	_only_big = not _only_big
	_show_sort(_sort)
	Game.sfx("ui_move", -10.0)


func _is_key(event: InputEvent, key: Key, pad: JoyButton) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return event.physical_keycode == key
	return event is InputEventJoypadButton and event.pressed and event.button_index == pad


## 换排序：Q/E、PageUp/PageDown、手柄 LB/RB（Tab 留给总图鉴换册）
func _is_tab_key(event: InputEvent, dir: int) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_Q, KEY_PAGEUP:
				return dir < 0
			KEY_E, KEY_PAGEDOWN:
				return dir > 0
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			return dir < 0
		if event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			return dir > 0
	return false


func _close() -> void:
	if not _ready_for_input:
		return
	_ready_for_input = false
	Game.sfx("ui_back", -8.0)
	closed.emit()
	# 单独跑图鉴场景时（scenes/bestiary.tscn），关掉回开始界面
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file("res://scenes/title.tscn")
	else:
		queue_free()
