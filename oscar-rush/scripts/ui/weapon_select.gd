extends Node2D
## 开局选武器（新开一局、进第一关之前）：三张卡并排，左右选、确认进第一关、Esc 回开始界面。
## 键盘（A/D、方向键，Space/C/回车确认）、手柄（十字键/摇杆，A 确认）、鼠标（指着就选、点一下确认）都能用。
## 双人（合作）时各选各的（作者 10-18）：每人一个光标，卡片左上、右上角里画"1P""2P"小牌子（作者：牌子挂在卡片外面像溢出，收进卡片里），各自用自己的左右选、攻击/跳确认，
## 确认后再按左右可以改；所有人都确认了才出发。武器存到 Run.players[i]["weapon"]（Upgrades.set_weapon_for）。
## 武器本身在 player.gd，商店里还能换另外两把。

const LEVEL_SCENE := "res://scenes/test_level.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"
const WARM := Color8(255, 211, 138)
const DIM := Color(0.55, 0.55, 0.6)
const ICONS := preload("res://art/shop/icons.png")
const ICON_NAMES: Array[String] = ["part", "charge", "fuel", "plating", "damping", "repair", "refresh",
		"hammer", "tongs", "horn", "rivet", "rage", "slave", "echo", "dynamo"]
const CARD_W := 136.0
const CARD_H := 168.0
const CARD_Y := 52.0
const CARD_GAP := 12.0
## [id, 名字, 图标, 说明, 威力, 射速, 射程（1~5）]
const CARDS := [
	["flash", "FLASH LAMP", "charge", "Hold to charge.\nFull shots pierce\na whole row.", 4, 2, 5],
	["rivet", "RIVET GUN", "rivet", "Hold to fire\nnonstop. Small hits,\nshort range.", 1, 5, 3],
	["hammer", "STEAM HAMMER", "hammer", "Tap: blast all\naround you. Wipes\nbullets. Slow.", 5, 1, 2],
]

var _selected := 0
var _busy := false
var _ready_t := 0.25
var _cards: Array[Control] = []
var _lift: Array[float] = [0.0, 0.0, 0.0]
var _pop := 0.0
var _ui: CanvasLayer
var _fade: ColorRect
var _time := 0.0
var _hint: Label
## 合作：每个玩家的光标（卡片下标）、确认了没有
var _coop := false
var _sel: Array[int] = []
var _locked: Array[bool] = []


func _ready() -> void:
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
	title.position = Vector2(0, 14)
	title.size = Vector2(480, 30)
	_ui.add_child(title)

	var x0 := (480.0 - CARD_W * 3 - CARD_GAP * 2) / 2.0
	for i in CARDS.size():
		var c := Control.new()
		c.position = Vector2(x0 + i * (CARD_W + CARD_GAP), CARD_Y)
		c.size = Vector2(CARD_W, CARD_H)
		c.pivot_offset = c.size / 2.0
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.draw.connect(_draw_card.bind(c, i))
		_ui.add_child(c)
		_cards.append(c)
		var name := Label.new()
		var ns := Hud.small_text(WARM)
		ns.font_size = 11
		name.label_settings = ns
		name.text = CARDS[i][1]
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.position = Vector2(0, 58)
		name.size = Vector2(CARD_W, 12)
		c.add_child(name)
		var desc := Label.new()
		desc.label_settings = Hud.small_text(Color(0.82, 0.8, 0.78))
		desc.text = CARDS[i][3]
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.position = Vector2(0, 76)
		desc.size = Vector2(CARD_W, 52)
		c.add_child(desc)
		for k in 3:
			var lab := Label.new()
			lab.label_settings = Hud.small_text(DIM)
			lab.text = ["POWER", "RATE", "REACH"][k]
			lab.position = Vector2(14, _stat_y(k))
			lab.size = Vector2(50, 10)
			c.add_child(lab)

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

	_selected = maxi(CARDS.map(func(c): return c[0]).find(Upgrades.weapon), 0)
	_coop = Run.players.size() >= 2
	if _coop:
		for e in Run.players:
			_sel.append(maxi(CARDS.map(func(c): return c[0]).find(Upgrades.weapon_for(e["input"])), 0))
			_locked.append(false)
		_update_hint()


## 底部按键提示：跟着输入设备（键盘 / 手柄）换键名
func _update_hint() -> void:
	if _coop:
		_hint.text = tr("Each player: LEFT/RIGHT choose, ATTACK lock in      %s  back") % Controls.label("back")
		return
	_hint.text = tr("%s  choose      %s  start      %s  back      You can swap tools in the shop") % [
		Controls.label("change"), Controls.label("confirm"), Controls.label("back")]


## 这张卡现在有没有人指着
func _is_on(i: int) -> bool:
	return _sel.has(i) if _coop else i == _selected


func _color_of(k: int) -> Color:
	return Player.STRIP_COLORS.get(Run.players[k]["skin"], WARM)


func _process(delta: float) -> void:
	_time += delta
	_ready_t -= delta
	for i in _cards.size():
		var on := _is_on(i)
		# 选中的卡片往上抬 3 像素（取整），不缩放：小数倍缩放会让卡片上的像素字一大一小（美术巡检第 4 条）
		var lift := (3.0 + _pop) if on else 0.0
		_lift[i] = lerpf(_lift[i], lift, 1.0 - exp(-14.0 * delta))
		_cards[i].position.y = CARD_Y - roundf(_lift[i])
		_cards[i].modulate = _cards[i].modulate.lerp(Color.WHITE if on else Color(0.62, 0.62, 0.66), 1.0 - exp(-14.0 * delta))
		_cards[i].queue_redraw()
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
			_sel[k] = posmod(_sel[k] + step, CARDS.size())
			Game.sfx("ui_move", -10.0)
		elif not _locked[k] and _scheme_pressed(s, "confirm"):
			_locked[k] = true
			Game.sfx("ui_confirm", -6.0, 1.0 + 0.12 * k)
			_cards[_sel[k]].self_modulate = Color(1.5, 1.5, 1.5)
			create_tween().tween_property(_cards[_sel[k]], "self_modulate", Color.WHITE, 0.2)
	if not _locked.has(false):
		_choose()


func _scheme_pressed(s: String, what: String) -> bool:
	var acts: Array = [s + "_attack", s + "_jump"] if what == "confirm" else [s + "_" + what]
	for a in acts:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a):
			return true
	return false


## 卡片里的"1P""2P"小牌子：画在卡片左上、右上角（图标两边空着），第 3、4 个人往下排一行。
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
		var w := roundf(tw) + (13.0 if _locked[k] else 6.0)
		var x := 4.0 if slot % 2 == 0 else c.size.x - 4.0 - w
		var y := 4.0 + (slot / 2) * 15.0
		if _locked[k]:
			c.draw_rect(Rect2(x, y, w, 13), col)
			c.draw_string(font, Vector2(x + 3, y + 11), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.06, 0.055, 0.07))
			# 小勾：5×4 像素
			var t := Vector2(x + w - 9, y + 5)
			for q in [Vector2(0, 2), Vector2(1, 3), Vector2(2, 2), Vector2(3, 1), Vector2(4, 0)]:
				c.draw_rect(Rect2(t + q, Vector2.ONE * 1.0), Color(0.06, 0.055, 0.07))
				c.draw_rect(Rect2(t + q + Vector2(0, 1), Vector2.ONE * 1.0), Color(0.06, 0.055, 0.07))
		else:
			var a := 0.65 + 0.35 * absf(sin(_time * 4.0 + k))
			var oc := Color(col, a)
			c.draw_rect(Rect2(x, y, w, 1), oc)
			c.draw_rect(Rect2(x, y + 12, w, 1), oc)
			c.draw_rect(Rect2(x, y, 1, 13), oc)
			c.draw_rect(Rect2(x + w - 1, y, 1, 13), oc)
			c.draw_string(font, Vector2(x + 3, y + 11), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, oc)
		slot += 1


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
	# 合作时鼠标不知道算谁的，不认
	if _busy or _ready_t > 0.0 or _coop:
		return
	if event is InputEventMouseMotion:
		var i := _card_at(get_viewport().get_mouse_position())
		if i >= 0 and i != _selected:
			_selected = i
			Game.sfx("ui_move", -10.0)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _card_at(get_viewport().get_mouse_position())
		if i >= 0:
			_selected = i
			_choose()


func _card_at(pos: Vector2) -> int:
	for i in _cards.size():
		if Rect2(_cards[i].position, _cards[i].size).has_point(pos):
			return i
	return -1


func _move(step: int) -> void:
	_selected = posmod(_selected + step, CARDS.size())
	Game.sfx("ui_move", -10.0)


func _choose() -> void:
	_busy = true
	if _coop:
		for k in _sel.size():
			Upgrades.set_weapon_for(Run.players[k]["input"], CARDS[_sel[k]][0])
	else:
		Upgrades.weapon = CARDS[_selected][0]
	Game.sfx("ui_confirm", -4.0)
	var tw := create_tween().set_parallel(true)
	for i in _cards.size():
		if not _is_on(i):
			tw.tween_property(_cards[i], "modulate:a", 0.0, 0.25)
			continue
		# 确认：选中的卡片再往上弹几像素、卡片底闪一下白，不缩放（美术巡检第三轮）
		_cards[i].self_modulate = Color(1.8, 1.8, 1.8)
		tw.tween_property(_cards[i], "self_modulate", Color.WHITE, 0.3)
	_pop = 4.0
	await tw.finished
	await get_tree().create_timer(0.25).timeout
	# 开始菜单"选择关卡"选了别的关，就进那一关（Game.start_scene，游戏细节讨论会话加的）
	SceneFade.go(get_tree(), Game.take_start_scene(LEVEL_SCENE))


func _back() -> void:
	_busy = true
	Game.sfx("ui_back", -6.0)
	SceneFade.go(get_tree(), TITLE_SCENE, 0.4)


func _draw_card(c: Control, i: int) -> void:
	var on := _is_on(i)
	var r := Rect2(Vector2.ZERO, c.size)
	c.draw_rect(r, Color(0.06, 0.055, 0.07, 0.92))
	# 合作：边框用第一个指着它的人的颜色
	var mark := _color_of(_sel.find(i)) if _coop and on else WARM
	var edge := mark if on else Color(0.35, 0.33, 0.33)
	c.draw_rect(Rect2(0, 0, r.size.x, 1), edge)
	c.draw_rect(Rect2(0, r.size.y - 1, r.size.x, 1), edge)
	c.draw_rect(Rect2(0, 0, 1, r.size.y), edge)
	c.draw_rect(Rect2(r.size.x - 1, 0, 1, r.size.y), edge)
	if on:
		# 选中的卡：四个角往外闪的小角标
		var k := 2.0 + roundf(absf(sin(_time * 5.0)) * 2.0)
		for p in [Vector2(-k, -k), Vector2(r.size.x + k - 4, -k), Vector2(-k, r.size.y + k - 4), Vector2(r.size.x + k - 4, r.size.y + k - 4)]:
			c.draw_rect(Rect2(p, Vector2(4, 1)), mark)
			c.draw_rect(Rect2(p + Vector2(0 if p.x < 0 else 3, 0), Vector2(1, 4)), mark)
	if _coop:
		_draw_tags(c, i)
	# 图标：货架那张图集里的一格，放大 3 倍
	var icon_i := maxi(ICON_NAMES.find(CARDS[i][2]), 0)
	var src := Rect2(icon_i * 16, 0, 16, 16)
	var bob := roundf(sin(_time * 3.0 + i) * 1.5) if on else 0.0
	c.draw_texture_rect_region(ICONS, Rect2((r.size.x - 48.0) / 2.0, 6 + bob, 48, 48), src)
	# 三条 1~5 格的数值条
	for k in 3:
		var v: int = CARDS[i][4 + k]
		for j in 5:
			var col := WARM if j < v else Color(0.22, 0.21, 0.23)
			c.draw_rect(Rect2(64 + j * 11, _stat_y(k) + 3.0, 9, 4), col)


## 卡片下面 威力 / 射速 / 射程 三行的 y：中文字满 11 像素高，行距 10 会上下贴住，拉到 12、整体上移 6
func _stat_y(k: int) -> float:
	return 128.0 + k * 12.0 if Lang.is_zh() else 134.0 + k * 10.0
