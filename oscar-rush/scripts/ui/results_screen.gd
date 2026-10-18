extends Node2D
## 一局结束的结算画面：结局 THE END 之后、回到开始界面之前（boss3_room.gd 按任意键切过来）。
## 一行一行亮出来：用时、马灯碎了几次、收集的零件（花掉多少）、用的家伙、变异、最后剩的马灯。
## 和选武器、商店同一套样式（UiStyle 卡片、暖黄名字、一格一格的条）。按任意键：清掉这一局，回开始界面。
## 数据在 Game.run_stats 和 Run / Upgrades 里，回开始界面前才 reset。

const TITLE_SCENE := "res://scenes/title.tscn"
const CARD := Rect2(104, 58, 272, 150)
const ROW_Y0 := 72.0
const ROW_STEP := 21.0
const WEAPON_NAMES := {"flash": "FLASH LAMP", "rivet": "RIVET GUN", "hammer": "STEAM HAMMER"}
const MUTATION_NAMES := {"rage": "RAGE", "slave": "SLAVE FLASH", "echo": "TAPE ECHO", "dynamo": "DYNAMO"}

var _rows: Array[Array] = []
var _labels: Array[Label] = []
var _shown := 0
var _time := 0.0
var _hp_k := 0.0
var _bar: Control
var _hint: Label
var _can_leave := false
var _leaving := false
var _perfect := false
var _perfect_label: Label


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.035)
	bg.size = Vector2(480, 270)
	add_child(bg)
	var frame := Control.new()
	frame.size = Vector2(480, 270)
	frame.draw.connect(func() -> void: UiStyle.panel(frame, CARD, false, 0.0))
	add_child(frame)
	_label(tr("RUN SUMMARY"), 0, 24, 480, 22, UiStyle.WARM, 3, HORIZONTAL_ALIGNMENT_CENTER)
	var s: Dictionary = Game.run_stats
	var t := int(s.get("time", 0.0))
	var spent: int = s.get("spent", 0)
	var parts := Run.parts + spent
	_hp_k = clampf(Run.crystal_hp / maxf(Run.crystal_max, 1.0), 0.0, 1.0)
	_rows = [
		["TIME", "%d:%02d" % [t / 60, t % 60]],
		["LANTERN BROKEN", str(s.get("deaths", 0))],
		["PARTS COLLECTED", (str(parts) + "   " + tr("(spent %d)") % spent) if spent > 0 else str(parts)],
		["TOOL", tr(WEAPON_NAMES.get(Upgrades.weapon, Upgrades.weapon.to_upper()))],
		["MUTATION", tr(MUTATION_NAMES.get(Upgrades.mutation, "NONE")) if Upgrades.mutation != "" else tr("NONE")],
		["LANTERN LEFT", "%d%%" % roundi(_hp_k * 100.0)],
	]
	# 马灯 95% 以上通关：和结局里的"满血通关"同一个标准（boss3_room.gd 的 _perfect）
	_perfect = _hp_k >= 0.95
	for i in _rows.size():
		var y := ROW_Y0 + i * ROW_STEP
		var a := _label(tr(_rows[i][0]), CARD.position.x + 14, y, 140, 11, UiStyle.DIM, 2, HORIZONTAL_ALIGNMENT_LEFT)
		var b := _label(_rows[i][1], CARD.position.x + 130, y, CARD.size.x - 144, 11, UiStyle.WARM, 2, HORIZONTAL_ALIGNMENT_RIGHT)
		a.modulate.a = 0.0
		b.modulate.a = 0.0
		_labels.append_array([a, b])
	# 马灯血量：值的左边一条一格一格的小条
	_bar = Control.new()
	_bar.size = Vector2(480, 270)
	_bar.modulate.a = 0.0
	_bar.draw.connect(_draw_bar)
	add_child(_bar)
	_perfect_label = _label(tr("PERFECT RUN  -  THE LANTERN NEVER DIMMED"), 0, CARD.end.y + 6, 480, 11, UiStyle.WARM, 2, HORIZONTAL_ALIGNMENT_CENTER)
	_perfect_label.visible = false
	_hint = _label(tr("Press any key"), 0, 232, 480, 11, UiStyle.DIM, 2, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.visible = false


func _label(text: String, x: float, y: float, w: float, font_size: int, color: Color, outline: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	var st := Hud.small_text(color)
	st.font_size = font_size
	st.outline_size = outline
	l.label_settings = st
	l.text = text
	l.horizontal_alignment = align
	l.position = Vector2(x, y)
	l.size = Vector2(w, font_size + 6)
	add_child(l)
	return l


func _draw_bar() -> void:
	var cells := 10
	var lit := roundi(_hp_k * cells)
	var y := ROW_Y0 + (_rows.size() - 1) * ROW_STEP + 4.0
	var x0 := CARD.position.x + 150.0
	for k in cells:
		_bar.draw_rect(Rect2(x0 + k * 7, y, 6, 6), UiStyle.WARM if k < lit else UiStyle.BAR_OFF)


func _process(delta: float) -> void:
	_time += delta
	# 一行一行亮出来，每行"嗒"一下
	var want := mini(int((_time - 0.5) / 0.28) + 1, _rows.size()) if _time > 0.5 else 0
	while _shown < want:
		_labels[_shown * 2].modulate.a = 1.0
		_labels[_shown * 2 + 1].modulate.a = 1.0
		if _shown == _rows.size() - 1:
			_bar.modulate.a = 1.0
			if _perfect:
				_perfect_label.visible = true
				Game.sfx("ding", -8.0, 1.2)
		Game.sfx("ui_move", -8.0, 0.9 + _shown * 0.05)
		_shown += 1
	if _shown >= _rows.size() and _time > 0.5 + _rows.size() * 0.28 + 0.6:
		_can_leave = true
		_hint.visible = fmod(_time, 1.0) < 0.65


func _input(event: InputEvent) -> void:
	if _leaving:
		return
	var pressed := (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) \
		and event.is_pressed() and not event.is_echo()
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if not _can_leave:
		# 还在一行行出：按一下全部亮出来
		_time = 0.5 + _rows.size() * 0.28
		return
	_leaving = true
	Game.sfx("ui_confirm", -6.0)
	Run.reset_run()
	Game.reset_stats()
	SceneFade.go(get_tree(), TITLE_SCENE, 0.8)
