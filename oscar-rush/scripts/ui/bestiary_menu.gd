class_name BestiaryMenu
extends Control
## 怪物图鉴界面（开始菜单的 BESTIARY）。数据和收集记录在 bestiary.gd。
## 四页：第一关、第二关、第三关、Boss。左边一格一只怪，右边是选中那只的大图、名字、出处和一两句打法。
## 遇到过的点亮；没遇到的只画剪影，名字是"???"。
## - 键盘：方向键 / WASD 选，Q/E（或 PageUp/PageDown、Tab）换页，Esc 返回；在最左、最右一格再往外按也会换页
## - 手柄：十字键 / 摇杆选，LB/RB 换页，B 返回
## - 鼠标：指到哪只选哪只，点上面的页签换页，滚轮滚动，右键或点右上角"返回"
## - 开发者开关：调试版里按 F9 全部点亮（不写存档）。也可以设环境变量 SCRAP_BESTIARY_ALL=1
## 开始界面用法：var page := BestiaryMenu.new(); 加到 UI 层; await page.closed（关掉时自己 queue_free）。
## 单独跑 scenes/bestiary.tscn 时，关掉会回开始界面。

signal closed

const WARM := UiStyle.WARM
const TEXT := UiStyle.TEXT
const DIM := UiStyle.DIM
## 精英、Boss 的格子边：暗一点的金色
const GOLD := Color8(176, 132, 74)
## 没遇到的怪：剪影的颜色（比卡片底亮一点，能看出轮廓）
const SIL := Color(0.2, 0.2, 0.26)

const TABS := ["1", "2", "3", "boss"]
const TAB_NAMES := ["LEVEL 1", "LEVEL 2", "LEVEL 3", "BOSS"]
const TAB_X := 14.0
const TAB_Y := 32.0
const TAB_W := 56.0
const TAB_H := 15.0
const TAB_GAP := 4.0

## 左边的格子区、右边的详情卡
const GRID := Rect2(14, 54, 240, 188)
const DETAIL := Rect2(268, 54, 200, 188)
const GAP := 4.0
## 每页：一行几格、一格多大。第三关一行正好是一个场景（四只小怪 + 一只精英）
const LAYOUT := {"1": [5, 44.0], "2": [5, 44.0], "3": [5, 44.0], "boss": [3, 76.0]}
## 待机动画一帧多久
const ANIM := 0.18
const BACK_BTN := Rect2(424, 10, 44, 15)

const SIL_SHADER := "shader_type canvas_item;
uniform vec4 sil : source_color;
void fragment() { COLOR = vec4(sil.rgb, texture(TEXTURE, UV).a * COLOR.a); }"

static var _last_tab := 0

var _tab := 0
var _sel := 0
var _row0 := 0
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

var _title: Label
var _tab_labels: Array[Label] = []
var _count: Label
var _name: Label
var _sub: Label
var _info: Label
var _desc: Label
var _hint: Label
var _back: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(480, 270)
	mouse_filter = Control.MOUSE_FILTER_STOP
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
	for l in [_tiles, _lit, _sil]:
		l.position = Vector2(5, 5)
	_det_lit = _layer(self)
	_det_lit.draw.connect(_draw_detail_art.bind(_det_lit, true))
	_det_sil = _layer(self)
	_det_sil.material = sil_mat
	_det_sil.draw.connect(_draw_detail_art.bind(_det_sil, false))

	_title = _label(0, 6, 480, 22, WARM, HORIZONTAL_ALIGNMENT_CENTER)
	_title.text = tr("BESTIARY")
	for i in TABS.size():
		var l := _label(TAB_X + i * (TAB_W + TAB_GAP), TAB_Y + 1, TAB_W, 11, DIM, HORIZONTAL_ALIGNMENT_CENTER)
		l.text = tr(TAB_NAMES[i])
		_tab_labels.append(l)
	_count = _label(DETAIL.position.x, TAB_Y + 1, DETAIL.size.x, 11, DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_back = _label(BACK_BTN.position.x, BACK_BTN.position.y + 1, BACK_BTN.size.x, 11, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_back.text = tr("BACK")
	var w := DETAIL.size.x - 12
	_name = _label(DETAIL.position.x + 6, 0, w, 11, WARM, HORIZONTAL_ALIGNMENT_CENTER)
	_sub = _label(DETAIL.position.x + 6, 0, w, 11, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_info = _label(DETAIL.position.x + 6, 0, w, 11, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_desc = _label(DETAIL.position.x + 6, 0, w, 11, TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	_desc.label_settings.line_spacing = -2
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint = _label(0, 251, 480, 11, DIM, HORIZONTAL_ALIGNMENT_CENTER)

	Controls.device_changed.connect(func(_pad: bool) -> void: _show_hint())
	_show_tab(_last_tab)
	await get_tree().process_frame
	_ready_for_input = true


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
	if int(_time / ANIM) != before:
		_lit.queue_redraw()
		_det_lit.queue_redraw()


# ---------------------------------------------------------------- 翻页、选择

func _show_tab(i: int) -> void:
	_tab = posmod(i, TABS.size())
	_last_tab = _tab
	_list = Bestiary.page(TABS[_tab])
	_sel = 0
	_row0 = 0
	for j in _tab_labels.size():
		_tab_labels[j].label_settings.font_color = WARM if j == _tab else DIM
	var seen := Bestiary.count_seen(_list)
	_count.text = tr("Seen %d / %d") % [seen, _list.size()]
	if Bestiary.reveal_all:
		_count.text = tr("DEV: all revealed") + "   " + _count.text
	_count.label_settings.font_color = UiStyle.POOR if Bestiary.reveal_all else DIM
	_select(0)
	_show_hint()


func _select(i: int) -> void:
	if _list.is_empty():
		return
	_sel = clampi(i, 0, _list.size() - 1)
	var cols: int = LAYOUT[TABS[_tab]][0]
	var row := _sel / cols
	var rows := _visible_rows()
	if row < _row0:
		_row0 = row
	elif row >= _row0 + rows:
		_row0 = row - rows + 1
	_show_detail()
	_redraw_all()


func _move(dx: int, dy: int) -> void:
	var cols: int = LAYOUT[TABS[_tab]][0]
	var col := _sel % cols
	if dx != 0:
		# 最左一格再往左、最右一格（或最后一只）再往右：换页
		if (dx < 0 and col == 0) or (dx > 0 and (col == cols - 1 or _sel == _list.size() - 1)):
			var going_left := dx < 0
			_show_tab(_tab + dx)
			if going_left:
				_select(_list.size() - 1)
			Game.sfx("ui_move", -10.0)
			return
		_select(_sel + dx)
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
	var tile: float = LAYOUT[TABS[_tab]][1]
	return maxi(1, int((GRID.size.y + GAP) / (tile + GAP)))


func _total_rows() -> int:
	var cols: int = LAYOUT[TABS[_tab]][0]
	return (_list.size() + cols - 1) / cols


func _scroll(rows: int) -> void:
	_row0 = clampi(_row0 + rows, 0, maxi(0, _total_rows() - _visible_rows()))
	_redraw_all()


func _tile_rect(i: int) -> Rect2:
	var cols: int = LAYOUT[TABS[_tab]][0]
	var tile: float = LAYOUT[TABS[_tab]][1]
	var col := i % cols
	var row := i / cols - _row0
	return Rect2(GRID.position.x + col * (tile + GAP), GRID.position.y + row * (tile + GAP), tile, tile)


func _redraw_all() -> void:
	for c in [_base, _tiles, _lit, _sil, _det_lit, _det_sil]:
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
	_info.text = "  -  ".join(parts)
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
			d = tr("Crawled out of the %s screen.") % tr(e["where"]) + " " + d
		elif e.has("where"):
			d = tr("Elite.") + " " + d
		_desc.text = d
		_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# 字从卡片底往上排：说明 → 出处 → 标语 → 名字，剩下的高度全给大图
	var x := DETAIL.position.x + 6
	_desc.size = Vector2(DETAIL.size.x - 12, 0)
	_desc.size.y = _desc.get_minimum_size().y
	_desc.position = Vector2(x, DETAIL.end.y - 5 - _desc.size.y)
	_info.position.y = _desc.position.y - 15
	var top := _info.position.y
	_sub.visible = _sub.text != ""
	if _sub.visible:
		_sub.position.y = top - 13
		top = _sub.position.y
	_name.position.y = top - 14
	_art_area = Rect2(DETAIL.position.x + 6, DETAIL.position.y + 8, DETAIL.size.x - 12, _name.position.y - DETAIL.position.y - 10)


func _show_hint() -> void:
	var pad := Controls.using_pad
	_hint.text = tr("%s move    %s page    %s back") % [
		Controls.label("select") if pad else "WASD", "LB/RB" if pad else "Q/E", Controls.label("back")]


# ---------------------------------------------------------------- 画

func _draw_base() -> void:
	var c := _base
	# 页签
	for i in TABS.size():
		var r := Rect2(TAB_X + i * (TAB_W + TAB_GAP), TAB_Y, TAB_W, TAB_H)
		UiStyle.panel(c, r, false, 0.0)
		if i == _tab:
			c.draw_rect(Rect2(r.position.x, r.end.y - 2, r.size.x, 2), WARM)
	UiStyle.panel(c, BACK_BTN, false, 0.0)
	# 详情卡：选中的是精英 / Boss 就换金边
	var e: Dictionary = _list[_sel] if not _list.is_empty() else {}
	var big: bool = not e.is_empty() and e["kind"] != "mob" and Bestiary.lit(e)
	UiStyle.panel(c, DETAIL, big, 0.0, GOLD)
	# 名字下面一道细线，把大图和字分开
	if not e.is_empty():
		var y := _name.position.y - 3
		c.draw_rect(Rect2(DETAIL.position.x + 20, y, DETAIL.size.x - 40, 1), UiStyle.BAR_OFF)
	# 滚动条：格子比一屏多的时候才画
	var total := _total_rows()
	var rows := _visible_rows()
	if total > rows:
		var track := Rect2(GRID.end.x + 5, GRID.position.y, 2, GRID.size.y)
		c.draw_rect(track, UiStyle.BAR_OFF)
		var h := maxf(6.0, roundf(track.size.y * rows / total))
		var y := track.position.y + roundf((track.size.y - h) * _row0 / maxf(1.0, total - rows))
		c.draw_rect(Rect2(track.position.x, y, 2, h), DIM)


func _draw_tiles() -> void:
	var c := _tiles
	for i in _list.size():
		var r := _tile_rect(i)
		if r.end.y < GRID.position.y - 6 or r.position.y > GRID.end.y + 6:
			continue
		r.position -= GRID.position   # 格子层的原点在格子区左上角
		var e: Dictionary = _list[i]
		UiStyle.panel(c, r, i == _sel, _time)
		if i != _sel and e["kind"] != "mob" and Bestiary.lit(e):
			_edge(c, r, GOLD)   # 精英、Boss：金边


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
		if r.end.y < GRID.position.y - 6 or r.position.y > GRID.end.y + 6:
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
	_draw_mob(c, e, _frame(e), _art_area, 4)


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
	if not _ready_for_input:
		return
	var handled := true
	if event is InputEventMouseMotion:
		handled = false
		var m := get_local_mouse_position()
		for i in _list.size():
			if i != _sel and _tile_rect(i).has_point(m) and GRID.has_point(m):
				_select(i)
				break
		_back.label_settings.font_color = WARM if BACK_BTN.has_point(m) else DIM
	elif event is InputEventMouseButton and event.pressed:
		var m := get_local_mouse_position()
		match event.button_index:
			MOUSE_BUTTON_WHEEL_DOWN:
				_scroll(1)
			MOUSE_BUTTON_WHEEL_UP:
				_scroll(-1)
			MOUSE_BUTTON_RIGHT:
				_close()
			MOUSE_BUTTON_LEFT:
				if BACK_BTN.has_point(m):
					_close()
				for i in TABS.size():
					if Rect2(TAB_X + i * (TAB_W + TAB_GAP), TAB_Y, TAB_W, TAB_H).has_point(m) and i != _tab:
						_show_tab(i)
						Game.sfx("ui_move", -10.0)
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F9 \
			and (OS.is_debug_build() or OS.get_environment("SCRAP_BESTIARY_ALL") == "1"):
		Bestiary.reveal_all = not Bestiary.reveal_all
		var keep := _sel
		_show_tab(_tab)
		_select(mini(keep, _list.size() - 1))
	elif _is_tab_key(event, -1):
		_show_tab(_tab - 1)
		Game.sfx("ui_move", -10.0)
	elif _is_tab_key(event, 1):
		_show_tab(_tab + 1)
		Game.sfx("ui_move", -10.0)
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
		_close()
	elif event.is_action_pressed("ui_accept"):
		pass   # 确认键在这一页没有用，吃掉免得漏到开始菜单
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


## 换页键：Q/E、PageUp/PageDown、Tab / Shift+Tab、手柄 LB/RB
func _is_tab_key(event: InputEvent, dir: int) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_Q, KEY_PAGEUP:
				return dir < 0
			KEY_E, KEY_PAGEDOWN:
				return dir > 0
			KEY_TAB:
				return (dir < 0) == event.shift_pressed
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
