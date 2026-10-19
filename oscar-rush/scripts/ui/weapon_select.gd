extends Node2D
## 开局选武器（新开一局、进第一关之前）。10-18 作者要 7 把武器：上面一排小格（每把一个图标），下面一块大的说明面板。
## 武器从武器登记表来（WeaponRegistry，ready 的才摆）：名字、图标、说明、特性、三条数值都在登记表里，这里不再写死。
## 键盘（A/D、方向键，Space/C/回车确认）、手柄（十字键/摇杆，A 确认）、鼠标（指着就选、点一下确认）都能用。Esc / 右键返回选关页。
## 双人（合作）时各选各的：每人一个光标，小格角上画"1P""2P"小牌子；说明面板左右分开（三四个人时分成四块，只放名字和数值），
## 各自用自己的左右选、攻击/跳确认，确认后再按左右可以改；所有人都确认了才出发。武器存到 Run.players[i]["weapon"]。

const LEVEL_SCENE := "res://scenes/test_level.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"
const WARM := Color8(255, 211, 138)
const DIM := Color(0.55, 0.55, 0.6)
const TEXT := Color(0.82, 0.8, 0.78)
const ICONS := preload("res://art/shop/icons.png")
const TILE := 52.0
const TILE_GAP := 8.0
const TILE_Y := 50.0
const PANEL := Rect2(34, 112, 412, 128)

## 摆出来的武器（登记表里 ready 的，按登记表顺序）
var _ids: Array[String] = []
var _selected := 0
var _busy := false
var _ready_t := 0.25
var _tiles: Array[Control] = []
var _lift: Array[float] = []
var _pop := 0.0
var _ui: CanvasLayer
var _fade: ColorRect
var _time := 0.0
var _hint: Label
var _panel: Control
## 每块说明面板一组：[名字, 说明, 特性]（单人一组；合作每人一组）
var _texts: Array = []
## 合作：每个玩家的光标（第几格）、确认了没有
var _coop := false
var _sel: Array[int] = []
var _locked: Array[bool] = []


func _ready() -> void:
	_ids = WeaponRegistry.ids()
	var bg := Sprite2D.new()
	bg.texture = load("res://art/levels/scene1_far.png")
	bg.centered = false
	bg.position = Vector2(-60, -40)
	bg.modulate = Color(0.28, 0.27, 0.32)
	add_child(bg)

	_ui = CanvasLayer.new()
	add_child(_ui)
	var title := Label.new()
	var ts := Hud.small_text(WARM)
	ts.font_size = 22
	ts.outline_size = 4
	title.label_settings = ts
	title.text = "CHOOSE YOUR TOOL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 12)
	title.size = Vector2(480, 30)
	_ui.add_child(title)

	var x0 := roundf((480.0 - TILE * _ids.size() - TILE_GAP * (_ids.size() - 1)) / 2.0)
	for i in _ids.size():
		var c := Control.new()
		c.position = Vector2(x0 + i * (TILE + TILE_GAP), TILE_Y)
		c.size = Vector2(TILE, TILE)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.draw.connect(_draw_tile.bind(c, i))
		_ui.add_child(c)
		_tiles.append(c)
		_lift.append(0.0)

	_selected = maxi(_ids.find(Upgrades.weapon), 0)
	_coop = Run.players.size() >= 2
	if _coop:
		for e in Run.players:
			_sel.append(maxi(_ids.find(Upgrades.weapon_for(e["input"])), 0))
			_locked.append(false)

	_panel = Control.new()
	_panel.position = PANEL.position
	_panel.size = PANEL.size
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.draw.connect(_draw_panel)
	_ui.add_child(_panel)
	for k in _panel_count():
		_texts.append(_make_texts(_panel_rect(k)))
	_refresh_texts()

	var hint := Label.new()
	hint.label_settings = Hud.small_text(DIM)
	_hint = hint
	_update_hint()
	Controls.device_changed.connect(func(_p: bool) -> void: _update_hint())
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, 250)
	hint.size = Vector2(480, 12)
	_ui.add_child(hint)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.size = Vector2(480, 270)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.35)


## 底部按键提示：跟着输入设备（键盘 / 手柄）换键名
func _update_hint() -> void:
	if _coop:
		_hint.text = tr("Each player: LEFT/RIGHT choose, ATTACK lock in      %s  back") % Controls.label("back")
		return
	# 商店不卖武器了（10-18 作者），换武器靠打倒精英掉落（布谷鸟钟会话做的 weapon_pickup）
	_hint.text = tr("%s  choose      %s  start      %s  back      Elites may drop other tools") % [
		Controls.label("change"), Controls.label("confirm"), Controls.label("back")]


# —— 说明面板：单人一整块；两人左右两半；三四个人四小块（只放名字和数值）——

func _panel_count() -> int:
	return _sel.size() if _coop else 1


func _compact() -> bool:
	return _coop and _sel.size() > 2


## 第 k 块说明面板在面板里的位置（面板本地坐标）
func _panel_rect(k: int) -> Rect2:
	if not _coop:
		return Rect2(Vector2.ZERO, PANEL.size)
	var w := floorf((PANEL.size.x - 8.0) / 2.0)
	if not _compact():
		return Rect2((w + 8.0) * k, 0, w, PANEL.size.y)
	var h := floorf((PANEL.size.y - 6.0) / 2.0)
	return Rect2((w + 8.0) * (k % 2), (h + 6.0) * (k / 2), w, h)


## 第 k 块面板现在显示哪把武器（第几格）
func _shown(k: int) -> int:
	return _sel[k] if _coop else _selected


func _make_texts(r: Rect2) -> Array:
	var wide := not _coop
	var name := Label.new()
	var ns := Hud.small_text(WARM)
	ns.font_size = 16 if wide else 11
	ns.outline_size = 3 if wide else 2
	name.label_settings = ns
	name.position = r.position + (Vector2(84, 6) if wide else Vector2(44, 4))
	name.size = Vector2(r.size.x - name.position.x + r.position.x - 6, 20)
	_panel.add_child(name)
	var desc := Label.new()
	desc.label_settings = Hud.small_text(TEXT)
	desc.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY if Lang.is_zh() else TextServer.AUTOWRAP_WORD_SMART
	desc.position = r.position + (Vector2(84, 30) if wide else Vector2(8, 62))
	desc.size = Vector2(r.size.x - (90 if wide else 14), 28)
	_panel.add_child(desc)
	var trait_l := Label.new()
	trait_l.label_settings = Hud.small_text(WARM)
	trait_l.autowrap_mode = desc.autowrap_mode
	trait_l.position = r.position + (Vector2(84, 60) if wide else Vector2(8, 92))
	trait_l.size = Vector2(r.size.x - (90 if wide else 14), 24)
	_panel.add_child(trait_l)
	var stat_labels: Array[Label] = []
	for s in 3:
		var lab := Label.new()
		lab.label_settings = Hud.small_text(DIM)
		lab.text = ["POWER", "RATE", "REACH"][s]
		lab.size = Vector2(50, 10)
		_panel.add_child(lab)
		stat_labels.append(lab)
	return [name, desc, trait_l, stat_labels]


func _stats_origin(k: int) -> Vector2:
	var r := _panel_rect(k)
	if not _coop:
		return r.position + Vector2(84, 88)
	return r.position + Vector2(44, 22)


func _stat_step() -> float:
	return 12.0 if Lang.is_zh() else 10.0


func _refresh_texts() -> void:
	for k in _texts.size():
		var id := _ids[_shown(k)]
		var t: Array = _texts[k]
		(t[0] as Label).text = tr(WeaponRegistry.name_of(id))
		(t[1] as Label).text = tr(str(WeaponRegistry.value(id, "card", ""))).replace("\n", " ")
		(t[2] as Label).text = tr(str(WeaponRegistry.value(id, "trait", "")))
		var wrap := TextServer.AUTOWRAP_ARBITRARY if Lang.is_zh() else TextServer.AUTOWRAP_WORD_SMART
		(t[1] as Label).autowrap_mode = wrap
		(t[2] as Label).autowrap_mode = wrap
		(t[1] as Label).visible = not _compact()
		(t[2] as Label).visible = not _compact()
		var o := _stats_origin(k)
		for s in 3:
			(t[3][s] as Label).position = o + Vector2(0, s * _stat_step() - 2.0)
	_panel.queue_redraw()


func _color_of(k: int) -> Color:
	return Player.STRIP_COLORS.get(Run.players[k]["skin"], WARM)


## 这一格现在有没有人指着
func _is_on(i: int) -> bool:
	return _sel.has(i) if _coop else i == _selected


func _process(delta: float) -> void:
	_time += delta
	_ready_t -= delta
	for i in _tiles.size():
		var on := _is_on(i)
		# 选中的格子往上抬 3 像素（取整），不缩放：小数倍缩放会让像素一大一小（美术巡检第 4 条）
		var lift := (3.0 + _pop) if on else 0.0
		_lift[i] = lerpf(_lift[i], lift, 1.0 - exp(-14.0 * delta))
		_tiles[i].position.y = TILE_Y - roundf(_lift[i])
		_tiles[i].modulate = _tiles[i].modulate.lerp(Color.WHITE if on else Color(0.62, 0.62, 0.66), 1.0 - exp(-14.0 * delta))
		_tiles[i].queue_redraw()
	_panel.queue_redraw()
	if _busy or _ready_t > 0.0:
		return
	if _coop:
		_coop_input()
		return
	if _pressed("left"):
		_move(-1)
	elif _pressed("right"):
		_move(1)
	elif _pressed("confirm"):
		_choose()
	elif Input.is_action_just_pressed("ui_cancel"):
		_back()


## 合作：每个人只认自己那套键。确认了再按左右就是反悔重选
func _coop_input() -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		_back()
		return
	for k in _sel.size():
		var s: String = Run.players[k]["input"]
		var step := -1 if _scheme_pressed(s, "left") else (1 if _scheme_pressed(s, "right") else 0)
		if step != 0:
			_locked[k] = false
			_sel[k] = posmod(_sel[k] + step, _ids.size())
			Game.sfx("ui_move", -10.0)
			_refresh_texts()
		elif not _locked[k] and _scheme_pressed(s, "confirm"):
			_locked[k] = true
			Game.sfx("ui_confirm", -6.0, 1.0 + 0.12 * k)
			_tiles[_sel[k]].self_modulate = Color(1.5, 1.5, 1.5)
			create_tween().tween_property(_tiles[_sel[k]], "self_modulate", Color.WHITE, 0.2)
	if not _locked.has(false):
		_choose()


func _scheme_pressed(s: String, what: String) -> bool:
	var acts: Array = [s + "_attack", s + "_jump"] if what == "confirm" else [s + "_" + what]
	for a in acts:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a):
			return true
	return false


## 所有人的按键都认：ui_*（含手柄）+ 每个输入方案自己的左右、攻击、跳
func _pressed(what: String) -> bool:
	var ui := {"left": "ui_left", "right": "ui_right", "confirm": "ui_accept"}
	if Input.is_action_just_pressed(ui[what]):
		return true
	var schemes: Array[String] = ["solo"]
	for p in Run.players:
		if not schemes.has(p["input"]):
			schemes.append(p["input"])
	for s in schemes:
		var acts: Array = [s + "_attack", s + "_jump"] if what == "confirm" else [s + "_" + what]
		for a in acts:
			if InputMap.has_action(a) and Input.is_action_just_pressed(a):
				return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	# 鼠标右键 = 返回上一步（和 Esc、手柄 B 一样；合作时也认，返回不分是谁）
	if not _busy and _ready_t <= 0.0 and event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		_back()
		return
	# 合作时鼠标不知道算谁的，不认
	if _busy or _ready_t > 0.0 or _coop:
		return
	if event is InputEventMouseMotion:
		var i := _tile_at(get_viewport().get_mouse_position())
		if i >= 0 and i != _selected:
			_selected = i
			Game.sfx("ui_move", -10.0)
			_refresh_texts()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _tile_at(get_viewport().get_mouse_position())
		if i >= 0:
			_selected = i
			_refresh_texts()
			_choose()


func _tile_at(pos: Vector2) -> int:
	for i in _tiles.size():
		if Rect2(_tiles[i].position, _tiles[i].size).has_point(pos):
			return i
	return -1


func _move(step: int) -> void:
	_selected = posmod(_selected + step, _ids.size())
	Game.sfx("ui_move", -10.0)
	_refresh_texts()


func _choose() -> void:
	_busy = true
	if _coop:
		for k in _sel.size():
			Upgrades.set_weapon_for(Run.players[k]["input"], _ids[_sel[k]])
	else:
		Upgrades.weapon = _ids[_selected]
	Game.sfx("ui_confirm", -4.0)
	var tw := create_tween().set_parallel(true)
	for i in _tiles.size():
		if not _is_on(i):
			tw.tween_property(_tiles[i], "modulate:a", 0.0, 0.25)
			continue
		# 确认：选中的格子再往上弹几像素、闪一下白，不缩放（美术巡检第三轮）
		_tiles[i].self_modulate = Color(1.8, 1.8, 1.8)
		tw.tween_property(_tiles[i], "self_modulate", Color.WHITE, 0.3)
	_pop = 4.0
	await tw.finished
	await get_tree().create_timer(0.25).timeout
	# 开始菜单"选择关卡"选了别的关，就进那一关（Game.start_scene，游戏细节讨论会话加的）
	SceneFade.go(get_tree(), Game.take_start_scene(LEVEL_SCENE))


func _back() -> void:
	_busy = true
	Game.sfx("ui_back", -6.0)
	# 返回上一步是选关页，不是开始菜单（title_screen.gd 的 return_to_levels；用 load 取，不写类名）
	(load("res://scripts/ui/title_screen.gd") as GDScript).set("return_to_levels", true)
	SceneFade.go(get_tree(), TITLE_SCENE, 0.4)


# —— 画 ——

func _icon_src(id: String) -> Rect2:
	var i := maxi(ShopStand.ICON_NAMES.find(str(WeaponRegistry.value(id, "icon", "part"))), 0)
	return Rect2(i * 16, 0, 16, 16)


func _frame(c: CanvasItem, r: Rect2, edge: Color) -> void:
	c.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), edge)
	c.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), edge)
	c.draw_rect(Rect2(r.position, Vector2(1, r.size.y)), edge)
	c.draw_rect(Rect2(r.position + Vector2(r.size.x - 1, 0), Vector2(1, r.size.y)), edge)


func _draw_tile(c: Control, i: int) -> void:
	var on := _is_on(i)
	var r := Rect2(Vector2.ZERO, c.size)
	c.draw_rect(r, Color(0.06, 0.055, 0.07, 0.92))
	# 合作：边框用第一个指着它的人的颜色
	var mark := _color_of(_sel.find(i)) if _coop and on else WARM
	_frame(c, r, mark if on else Color(0.35, 0.33, 0.33))
	if on:
		# 选中的格子：四个角往外闪的小角标
		var k := 2.0 + roundf(absf(sin(_time * 5.0)) * 2.0)
		for p in [Vector2(-k, -k), Vector2(r.size.x + k - 4, -k), Vector2(-k, r.size.y + k - 4), Vector2(r.size.x + k - 4, r.size.y + k - 4)]:
			c.draw_rect(Rect2(p, Vector2(4, 1)), mark)
			c.draw_rect(Rect2(p + Vector2(0 if p.x < 0 else 3, 0), Vector2(1, 4)), mark)
	# 图标：货架那张图集里的一格，放大 2 倍
	var bob := roundf(sin(_time * 3.0 + i) * 1.0) if on else 0.0
	c.draw_texture_rect_region(ICONS, Rect2((r.size.x - 32.0) / 2.0, 12 + bob, 32, 32), _icon_src(_ids[i]))
	if _coop:
		_draw_tags(c, i)


## 格子里的"1P""2P"小牌子：左上、右上角，第 3、4 个人往下排一行。
## 没确认：空心框 + 那个人的颜色；确认了：实心框 + 深色字 + 一个像素小勾（不用文字，中英文一样宽）
func _draw_tags(c: Control, i: int) -> void:
	var font := Hud.font()
	var slot := 0
	for k in _sel.size():
		if _sel[k] != i:
			continue
		var col := _color_of(k)
		var text: String = tr("%dP") % (k + 1)
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var w := roundf(tw) + (12.0 if _locked[k] else 5.0)
		var x := 2.0 if slot % 2 == 0 else c.size.x - 2.0 - w
		var y := 2.0 + (slot / 2) * (c.size.y - 17.0)
		if _locked[k]:
			c.draw_rect(Rect2(x, y, w, 13), col)
			c.draw_string(font, Vector2(x + 2, y + 11), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.06, 0.055, 0.07))
			var t := Vector2(x + w - 8, y + 5)
			for q in [Vector2(0, 2), Vector2(1, 3), Vector2(2, 2), Vector2(3, 1), Vector2(4, 0)]:
				c.draw_rect(Rect2(t + q, Vector2.ONE), Color(0.06, 0.055, 0.07))
				c.draw_rect(Rect2(t + q + Vector2(0, 1), Vector2.ONE), Color(0.06, 0.055, 0.07))
		else:
			var a := 0.65 + 0.35 * absf(sin(_time * 4.0 + k))
			var oc := Color(col, a)
			_frame(c, Rect2(x, y, w, 13), oc)
			c.draw_string(font, Vector2(x + 2, y + 11), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, oc)
		slot += 1


func _draw_panel() -> void:
	for k in _panel_count():
		var r := _panel_rect(k)
		_panel.draw_rect(r, Color(0.06, 0.055, 0.07, 0.92))
		var edge := _color_of(k) if _coop else Color(0.35, 0.33, 0.33)
		if _coop and _locked[k]:
			edge = edge.lerp(Color.WHITE, 0.3)
		_frame(_panel, r, edge)
		var id := _ids[_shown(k)]
		# 大图标：单人 4 倍、合作 2 倍
		var big := 64.0 if not _coop else 32.0
		var at := r.position + (Vector2(10, 10) if not _coop else Vector2(6, 4))
		var bob := roundf(sin(_time * 3.0) * 1.0)
		_panel.draw_texture_rect_region(ICONS, Rect2(at + Vector2(0, bob), Vector2(big, big)), _icon_src(id))
		# 三条 1~5 格的数值条
		var stats: Array = WeaponRegistry.value(id, "stats", [1, 1, 1])
		var o := _stats_origin(k) + Vector2(48, 2)
		var cell := 11.0 if not _coop else 9.0
		for s in 3:
			for j in 5:
				var col := WARM if j < int(stats[s]) else Color(0.22, 0.21, 0.23)
				_panel.draw_rect(Rect2(o + Vector2(j * cell, s * _stat_step()), Vector2(cell - 2.0, 4)), col)
