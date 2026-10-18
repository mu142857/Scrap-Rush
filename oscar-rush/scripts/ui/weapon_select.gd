extends Node2D
## 开局选武器（新开一局、进第一关之前）：三张卡并排，左右选、确认进第一关、Esc 回开始界面。
## 键盘（A/D、方向键，Space/C/回车确认）、手柄（十字键/摇杆，A 确认）、鼠标（指着就选、点一下确认）都能用。
## 多人时谁按都算，选的武器全队一样（Upgrades.weapon）。武器本身在 player.gd，商店里还能换另外两把。

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


## 底部按键提示：跟着输入设备（键盘 / 手柄）换键名
func _update_hint() -> void:
	_hint.text = tr("%s  choose      %s  start      %s  back      You can swap tools in the shop") % [
		Controls.label("change"), Controls.label("confirm"), Controls.label("back")]


func _process(delta: float) -> void:
	_time += delta
	_ready_t -= delta
	for i in _cards.size():
		var on := i == _selected
		# 选中的卡片往上抬 3 像素（取整），不缩放：小数倍缩放会让卡片上的像素字一大一小（美术巡检第 4 条）
		var lift := (3.0 + _pop) if on else 0.0
		_lift[i] = lerpf(_lift[i], lift, 1.0 - exp(-14.0 * delta))
		_cards[i].position.y = CARD_Y - roundf(_lift[i])
		_cards[i].modulate = _cards[i].modulate.lerp(Color.WHITE if on else Color(0.62, 0.62, 0.66), 1.0 - exp(-14.0 * delta))
		_cards[i].queue_redraw()
	if _busy or _ready_t > 0.0:
		return
	if _pressed("left"):
		_move(-1)
	elif _pressed("right"):
		_move(1)
	elif _pressed("confirm"):
		_choose()
	elif Input.is_action_just_pressed("ui_cancel"):
		_back()


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
	if _busy or _ready_t > 0.0:
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
	Upgrades.weapon = CARDS[_selected][0]
	Game.sfx("ui_confirm", -4.0)
	var tw := create_tween().set_parallel(true)
	for i in _cards.size():
		if i != _selected:
			tw.tween_property(_cards[i], "modulate:a", 0.0, 0.25)
	# 确认：选中的卡片再往上弹几像素、卡片底闪一下白，不缩放（美术巡检第三轮）
	_pop = 4.0
	_cards[_selected].self_modulate = Color(1.8, 1.8, 1.8)
	tw.tween_property(_cards[_selected], "self_modulate", Color.WHITE, 0.3)
	await tw.finished
	await get_tree().create_timer(0.25).timeout
	# 开始菜单"选择关卡"选了别的关，就进那一关（Game.start_scene，游戏细节讨论会话加的）
	SceneFade.go(get_tree(), Game.take_start_scene(LEVEL_SCENE))


func _back() -> void:
	_busy = true
	Game.sfx("ui_back", -6.0)
	SceneFade.go(get_tree(), TITLE_SCENE, 0.4)


func _draw_card(c: Control, i: int) -> void:
	var on := i == _selected
	var r := Rect2(Vector2.ZERO, c.size)
	c.draw_rect(r, Color(0.06, 0.055, 0.07, 0.92))
	var edge := WARM if on else Color(0.35, 0.33, 0.33)
	c.draw_rect(Rect2(0, 0, r.size.x, 1), edge)
	c.draw_rect(Rect2(0, r.size.y - 1, r.size.x, 1), edge)
	c.draw_rect(Rect2(0, 0, 1, r.size.y), edge)
	c.draw_rect(Rect2(r.size.x - 1, 0, 1, r.size.y), edge)
	if on:
		# 选中的卡：四个角往外闪的小角标
		var k := 2.0 + roundf(absf(sin(_time * 5.0)) * 2.0)
		for p in [Vector2(-k, -k), Vector2(r.size.x + k - 4, -k), Vector2(-k, r.size.y + k - 4), Vector2(r.size.x + k - 4, r.size.y + k - 4)]:
			c.draw_rect(Rect2(p, Vector2(4, 1)), WARM)
			c.draw_rect(Rect2(p + Vector2(0 if p.x < 0 else 3, 0), Vector2(1, 4)), WARM)
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
