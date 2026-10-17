extends Node2D
## 开始界面。
## 背景是第一关场景的一角（视差、压暗），镜头左右慢慢漂；四个船员站在地上，马灯放在旁边。
## 标题像老灯管通电一样闪几下亮起来，选项一条条淡出来（照 story_jam 的标题菜单）。
## 选 CO-OP 不换页面：四个船员先暗下去，谁在自己的设备上按跳跃，对应的船员就亮起来。
##
## 带调试参数（--autotest / --probe / --arc / --tour / --fx / --players）启动时直接进关卡，
## 免得这些测试脚本被开始界面挡住。

const LEVEL_SCENE := "res://scenes/weapon_select.tscn"  # 新开一局先选武器，选完才进第一关（weapon_select.gd）
## 开发用：命令行带 --boss 直接进第一关 Boss 房
const BOSS_SCENE := "res://scenes/boss1.tscn"
## 开发者模式在 scripts/debug/dev_mode.gd（全局，任何场景按 F8 开面板，再按数字跳关）。
const DEBUG_FLAGS: Array[String] = ["--autotest", "--probe", "--arc", "--tour", "--fx", "--players", "--enemy"]

# —— 背景：和 test_level 用同一套视差图层 ——
const SCENE_LAYERS := [
	[preload("res://art/levels/scene1_far.png"), 0.55, Color(0.72, 0.72, 0.8)],
	[preload("res://art/levels/scene1_beams.png"), 0.7, Color(0.8, 0.8, 0.86)],
	[preload("res://art/levels/scene1_machines.png"), 0.8, Color(0.88, 0.88, 0.92)],
	[preload("res://art/levels/scene1_truss.png"), 0.9, Color(0.95, 0.95, 0.97)],
	[preload("res://art/levels/scene1_near.png"), 1.0, Color.WHITE],
]
const BOUNDS := Rect2(0, 0, 1006, 426)
const DARKNESS := Color(0.3, 0.29, 0.35)
## 船员站的那段底层地面（x 347~422 是平的 414）
const FLOOR_Y := 414.0
const CREW_X: Array[float] = [366.0, 382.0, 398.0, 414.0]
const LANTERN_X := 352.0
## 开始界面镜头放大 2 倍（整数倍，像素还是方的），船员站在画面下方三分之一，
## 地面以下（关卡边界外）是黑的，说明文字就放在那片黑里
const CAM_ZOOM := 2.0
const CAM_CENTER := Vector2(386, 374)
const CAM_DRIFT := 8.0

# —— 文字 ——
const WARM := Color8(255, 211, 138)
const DIM := Color(0.55, 0.55, 0.6)
const LIT := Color(1, 1, 1)
const OPTION_TOP := 100.0
const OPTION_STEP := 19.0

var _options: Array[String] = ["START", "CO-OP", "SETTINGS", "QUIT"]
var _option_hints: Array[String] = [
	"One player. Carry the lantern home.",
	"2-4 players, one screen. Keyboard halves or gamepads.",
	"Volume, fullscreen, pixel scaling, screen shake, controls.",
	"",
]

var _cam: Camera2D
var _time := 0.0
var _crew: Array[Dictionary] = []
var _ui: CanvasLayer
var _title: Label
var _sub: Label
var _option_labels: Array[Label] = []
var _hint: Label
var _fade: ColorRect
var _selected := 0
var _ready_for_input := false
var _busy := false

# —— 多人加入 ——
var _lobby := false
var _lobby_root: Control
var _lobby_info: Label
## 每个船员位置上是谁："" 表示空着，否则是输入前缀（kb_left / kb_right / pad0 ……）
var _slots: Array[String] = ["", "", "", ""]
var _slot_labels: Array[Label] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--boss"):
			get_tree().change_scene_to_file.call_deferred(BOSS_SCENE)
			return
		for flag in DEBUG_FLAGS:
			if arg.begins_with(flag):
				get_tree().change_scene_to_file.call_deferred(LEVEL_SCENE)
				return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--titleshots="):
			var shots: Node = load("res://scripts/debug/title_shots.gd").new()
			shots.set("out_dir", arg.trim_prefix("--titleshots="))
			add_child(shots)
	# 网页版关不掉页面，不放 QUIT
	if OS.has_feature("web"):
		_options.resize(3)
		_option_hints.resize(3)
	_build_world()
	_build_ui()
	_animate_in()


## W/S、左摇杆、C 这些菜单键在 Settings 自动加载里统一加了


func _build_world() -> void:
	var bg := ParallaxScene.new()
	bg.layers = SCENE_LAYERS
	bg.bounds = BOUNDS
	add_child(bg)

	var dark := CanvasModulate.new()
	dark.color = DARKNESS
	add_child(dark)

	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(200, 20)
	shape.shape = rect
	shape.position = Vector2(LANTERN_X + 40, FLOOR_Y + 10)
	floor_body.add_child(shape)
	add_child(floor_body)

	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	for i in Run.SKINS.size():
		var skin := Run.SKINS[i]
		var root := Node2D.new()
		root.position = Vector2(CREW_X[i], FLOOR_Y)
		add_child(root)
		var body := _crew_sprite("res://art/chars/%s_body.png" % skin, root)
		var strip := _crew_sprite("res://art/chars/%s_strip.png" % skin, root)
		strip.material = unshaded
		var light := PointLight2D.new()
		light.texture = Game.light_texture()
		light.color = Player.STRIP_COLORS[skin]
		light.position = Vector2(0, -10)
		light.energy = 0.6
		root.add_child(light)
		_crew.append({"root": root, "body": body, "strip": strip, "light": light,
			"phase": randf() * 4.0, "on": 1.0, "target": 1.0})

	var lantern := Crystal.new()
	lantern.position = Vector2(LANTERN_X, FLOOR_Y - 2)
	add_child(lantern)

	_cam = Camera2D.new()
	_cam.position = CAM_CENTER
	_cam.zoom = Vector2(CAM_ZOOM, CAM_ZOOM)
	add_child(_cam)
	_cam.make_current()


func _crew_sprite(path: String, parent: Node2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.hframes = 7
	s.centered = false
	s.offset = Vector2(-8, -20)
	parent.add_child(s)
	return s


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 20
	add_child(_ui)

	_title = _label("SCRAP RUSH", 30.0, 33, WARM, 4)
	_sub = _label("LUDUM DARE 60  /  OLD TECH", 72.0, 11, DIM, 2)
	for i in _options.size():
		_option_labels.append(_label(_options[i], OPTION_TOP + i * OPTION_STEP, 22, DIM, 3))
	_hint = _label("", 246.0, 11, DIM, 2)
	for l in [_title, _sub, _hint] + _option_labels:
		l.modulate.a = 0.0

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_fade)


func _label(text: String, y: float, size: int, color: Color, outline: int, parent: Node = null) -> Label:
	var l := Label.new()
	var s := Hud.small_text(color)
	s.font_size = size
	s.outline_size = outline
	l.label_settings = s
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, y)
	l.size = Vector2(480, size + 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else _ui).add_child(l)
	return l


## 菜单一出来就是完整的，不再一条条显示。游戏刚打开时，开场动画（intro.gd）
## 叠在菜单上面播，播完露出菜单，这才能操作
func _animate_in() -> void:
	for l in [_title, _sub, _hint] + _option_labels:
		l.modulate.a = 1.0
	_refresh()
	if not IntroOverlay.played:
		var intro := IntroOverlay.new()
		add_child(intro)
		await intro.finished
	_ready_for_input = true


func _fade_in(c: CanvasItem, duration: float) -> void:
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, duration)
	await tw.finished


func _refresh() -> void:
	for i in _option_labels.size():
		var l := _option_labels[i]
		var on := i == _selected
		l.text = ("> %s <" % tr(_options[i])) if on else tr(_options[i])
		l.label_settings.font_color = LIT if on else DIM
		l.pivot_offset = l.size * 0.5
		if on:
			l.scale = Vector2(1.12, 1.12)
			l.create_tween().tween_property(l, "scale", Vector2.ONE, 0.18) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			l.scale = Vector2.ONE
	var keys := tr("W/S select    Space / C / A confirm    F11 fullscreen")
	var h := _option_hints[_selected]
	_hint.text = keys if h == "" else tr(h) + "\n" + keys
	_hint.position.y = 246.0 if h == "" else 234.0
	_hint.size.y = 30.0


func _process(delta: float) -> void:
	_time += delta
	_cam.position.x = CAM_CENTER.x + sin(_time * 0.12) * CAM_DRIFT
	_animate_crew(delta)
	if _busy:
		return
	if _lobby:
		_place_slot_labels()
		_lobby_input()
	elif _ready_for_input:
		_menu_input()


func _animate_crew(delta: float) -> void:
	for c in _crew:
		var f := int((_time + c["phase"]) / Player.IDLE_FRAME_TIME) % 4
		c["body"].frame = f
		c["strip"].frame = f
		c["on"] = move_toward(c["on"], c["target"], delta * 4.0)
		var on: float = c["on"]
		c["body"].modulate = Color(0.35, 0.35, 0.4).lerp(Color.WHITE, on)
		c["strip"].modulate = Color(0.25, 0.25, 0.3).lerp(Color(1.6, 1.6, 1.6), on)
		c["light"].energy = lerpf(0.05, 0.8, on)


func _menu_input() -> void:
	if Input.is_action_just_pressed("ui_up"):
		_move(-1)
	elif Input.is_action_just_pressed("ui_down"):
		_move(1)
	elif Input.is_action_just_pressed("ui_accept"):
		_confirm()


func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	# 跳关只在开发者模式（F8）里用数字键，开始界面本身不认数字键（作者 2026-10-17 定的）
	if _lobby:
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
			_leave_lobby()
		return
	if not _ready_for_input:
		return
	if event is InputEventMouseMotion:
		var i := _option_at()
		if i >= 0 and i != _selected:
			_selected = i
			Game.sfx("ui_move", -10.0)
			_refresh()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _option_at()
		if i >= 0:
			_selected = i
			_refresh()
			_confirm()


## 鼠标指着第几项（480×270 的坐标），没指着返回 -1
func _option_at() -> int:
	var pos := get_viewport().get_mouse_position()
	var i := floori((pos.y - OPTION_TOP + 2.0) / OPTION_STEP)
	return i if i >= 0 and i < _options.size() and absf(pos.x - 240.0) < 90.0 else -1


func _move(step: int) -> void:
	_selected = posmod(_selected + step, _options.size())
	Game.sfx("ui_move", -10.0)
	_refresh()


func _confirm() -> void:
	match _options[_selected]:
		"START":
			Run.players = [{"input": "solo", "skin": Run.SKINS[0]}]
			_start_game()
		"CO-OP":
			_enter_lobby()
		"SETTINGS":
			_open_settings()
		"QUIT":
			Game.sfx("ui_back", -6.0)
			_busy = true
			await _fade_to(1.0, 0.4)
			get_tree().quit()


func _open_settings() -> void:
	_busy = true
	Game.sfx("ui_confirm", -8.0)
	# 标题和选项先藏起来，免得从设置的半透明底下透出来叠在一起
	var hidden: Array[CanvasItem] = [_title, _sub, _hint]
	hidden.append_array(_option_labels)
	for c in hidden:
		c.visible = false
	var menu := SettingsMenu.new()
	_ui.add_child(menu)
	await menu.closed
	for c in hidden:
		c.visible = true
	# 关设置那一下的返回键 / 确认键别漏到菜单
	await get_tree().process_frame
	_busy = false
	_refresh()


func _start_game() -> void:
	_busy = true
	Game.sfx("ui_confirm", -4.0)
	Run.reset_run()
	var chosen := _option_labels[_selected]
	var tw := create_tween().set_parallel(true)
	for l in _option_labels:
		if l != chosen:
			tw.tween_property(l, "modulate:a", 0.0, 0.2)
	tw.tween_property(_hint, "modulate:a", 0.0, 0.2)
	tw.tween_property(chosen, "scale", Vector2(1.3, 1.3), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	await _fade_to(1.0, 0.5)
	get_tree().change_scene_to_file(LEVEL_SCENE)
	Game.flash(Color.BLACK, 1.0, 0.6)


func _fade_to(alpha: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", alpha, duration)
	await tw.finished


# —— 多人加入 ——

func _enter_lobby() -> void:
	_busy = true
	Game.sfx("ui_confirm", -6.0)
	var tw := create_tween().set_parallel(true)
	for l in _option_labels:
		tw.tween_property(l, "modulate:a", 0.0, 0.2)
	tw.tween_property(_hint, "modulate:a", 0.0, 0.2)
	await tw.finished
	_slots = ["", "", "", ""]
	for c in _crew:
		c["target"] = 0.0
	_lobby_root = Control.new()
	_lobby_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lobby_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_lobby_root)
	_label("Press JUMP to join", 94.0, 22, LIT, 3, _lobby_root)
	var keys := _label("Left keys  A D  W jump  C attack  V lantern\nRight keys  J L  I jump  M attack  N lantern\nGamepad  stick  A jump  X attack  Y lantern",
		120.0, 11, DIM, 2, _lobby_root)
	keys.size.y = 40.0
	_lobby_info = _label("", 236.0, 11, WARM, 2, _lobby_root)
	_lobby_info.size.y = 30.0
	_slot_labels.clear()
	for i in 4:
		var l := _label("", 0.0, 11, DIM, 2, _lobby_root)
		l.size = Vector2(40, 12)
		_slot_labels.append(l)
	_lobby_root.modulate.a = 0.0
	await _fade_in(_lobby_root, 0.25)
	_lobby = true
	_busy = false
	_refresh_lobby()


func _leave_lobby() -> void:
	_lobby = false
	_busy = true
	Game.sfx("ui_back", -6.0)
	for c in _crew:
		c["target"] = 1.0
	var tw := _lobby_root.create_tween()
	tw.tween_property(_lobby_root, "modulate:a", 0.0, 0.2)
	await tw.finished
	_lobby_root.queue_free()
	for l in _option_labels:
		l.modulate.a = 1.0
	_hint.modulate.a = 1.0
	_refresh()
	_busy = false


func _lobby_input() -> void:
	if Input.is_action_just_pressed("ui_cancel") and _joined_count() == 0:
		_leave_lobby()
		return
	for scheme in Controls.all_schemes():
		var slot := _slots.find(scheme)
		if slot < 0:
			if Input.is_action_just_pressed(scheme + "_jump"):
				var free := _slots.find("")
				if free >= 0:
					_slots[free] = scheme
					Game.sfx("join", -6.0)
					_squash(_crew[free])
					_refresh_lobby()
		else:
			if Input.is_action_just_pressed(scheme + "_crystal"):
				_slots[slot] = ""
				Game.sfx("leave", -8.0)
				_refresh_lobby()
			elif Input.is_action_just_pressed(scheme + "_attack") and _joined_count() >= 2:
				_start_coop()
				return


## 名牌跟着船员头顶走（镜头在漂，所以每帧换算一次世界坐标到屏幕坐标）
func _place_slot_labels() -> void:
	var xf := get_viewport().get_canvas_transform()
	for i in _slot_labels.size():
		var screen: Vector2 = xf * Vector2(CREW_X[i], FLOOR_Y - 26.0)
		_slot_labels[i].position = Vector2(roundf(screen.x - 20.0), roundf(screen.y))


func _squash(c: Dictionary) -> void:
	for key in ["body", "strip"]:
		var s: Sprite2D = c[key]
		s.scale = Vector2(1.25, 0.75)
		s.create_tween().tween_property(s, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _joined_count() -> int:
	return 4 - _slots.count("")


func _device_name(scheme: String) -> String:
	match scheme:
		"kb_left":
			return "KB-L"
		"kb_right":
			return "KB-R"
	return tr("PAD%d") % (scheme.trim_prefix("pad").to_int() + 1)


func _refresh_lobby() -> void:
	for i in 4:
		var joined := _slots[i] != ""
		_crew[i]["target"] = 1.0 if joined else 0.0
		var l := _slot_labels[i]
		l.text = _device_name(_slots[i]) if joined else "?"
		l.label_settings.font_color = Player.STRIP_COLORS[Run.SKINS[i]] if joined else DIM
	var n := _joined_count()
	if n == 0:
		_lobby_info.text = "Esc back"
	elif n == 1:
		_lobby_info.text = "Need one more player    (lantern key: leave)"
	else:
		_lobby_info.text = tr("%d players ready  -  any player press ATTACK to start\n(lantern key: leave)") % n


func _start_coop() -> void:
	_busy = true
	_lobby = false
	Run.players = []
	for i in 4:
		if _slots[i] != "":
			Run.players.append({"input": _slots[i], "skin": Run.SKINS[i]})
	Game.sfx("ui_confirm", -4.0)
	Run.reset_run()
	await _fade_to(1.0, 0.5)
	get_tree().change_scene_to_file(LEVEL_SCENE)
	Game.flash(Color.BLACK, 1.0, 0.6)
