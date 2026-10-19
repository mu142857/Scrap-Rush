extends Node2D
## 开始界面。
## 背景是第一关场景的一角（视差、压暗），镜头左右慢慢漂；四个船员站在地上，马灯放在旁边。
## 标题像老灯管通电一样闪几下亮起来，选项一条条淡出来（照 story_jam 的标题菜单）。
## 作者 10-18 重排：中间只有三项 开始 / 制作人员 / 退出（网页版没有退出）；
## 右上角两个像素小图标：书（图鉴，CodexMenu）和齿轮（设置）。按上键从"开始"跳到图标，左右换，下键回来；
## 手柄 Select 直接开设置；鼠标指着就选。
## 开始 → 单人 / 合作（ModeSelect）→ 选难度（DifficultySelect）→ 选武器 → 第一关（10-18 作者：不再自选关卡）。
## 有存档时最上面多一项"继续"，默认选中。
## 合作不换页面：四个船员先暗下去，谁在自己的设备上按跳跃，对应的船员就亮起来，按攻击再去选难度。
## 每一步按返回都回到上一步。
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
## 菜单只剩三项，回到居中一列，船员回到画面正下方（10-17 夜里的位置）
const CAM_CENTER := Vector2(386, 374)
const CAM_DRIFT := 8.0

# —— 文字 ——
const WARM := Color8(255, 211, 138)
const DIM := Color(0.55, 0.55, 0.6)
const LIT := Color(1, 1, 1)
const OPTION_TOP := 104.0
## 副标题（三关：蒸汽·信号·雪花）的位置；中文模式多一行"倒带冲刺"，副标题往下挪 SUB_ZH_SHIFT
const SUB_Y := 72.0
const SUB_ZH_SHIFT := 13.0
const OPTION_STEP := 20.0

var _options: Array[String] = ["START", "TUTORIAL", "CREDITS", "QUIT"]
var _option_hints: Array[String] = [
	"You don't have to go alone.",
	"Every TV has something to teach you.",
	"For the friends we met along the way.",
	"",
]
## 教学关（剧情会话做的 scenes/tutorial.tscn）。脚本用 load 找、静态成员用 get / set / call 调，不写类名：
## 教学关脚本出问题时开始界面照样能编译。第一次新开一局（没看过教学）时，选完单人 / 合作先进教学，
## 走完或跳过回到这里、直接打开选难度（return_to_levels）；菜单里的"教学"随时重玩，走完回开始菜单
const TUTORIAL_SCENE := "res://scenes/tutorial.tscn"
const TUTORIAL_SCRIPT := "res://scripts/tutorial/tutorial_level.gd"
## "继续"（作者 10-18 同意）：有存档时才出现，放在"开始"上面、默认选中，从打到过的最远那关开头接着打。
## 存档归游戏设计会话：按 SAVE_PATHS 用 load 找它的脚本（不写类名，没做好时这里照样能编译），
## 要的接口是 has_save() -> bool 和 continue_run()（自己恢复 Run、切到那关开头；返回场景路径的话由这里切）。
## 存档还没有时退一步：Progress.reached() 打到过第二关以上就出"继续"，从那关开头开始，起始装备按 LEVEL_STARTS 给
const SAVE_PATHS: Array[String] = ["res://scripts/autoload/save_game.gd", "res://scripts/autoload/save.gd"]

# —— 右上角的两个图标：书（图鉴）、齿轮（设置） ——
## 图标是 10×10 的像素图，放大 2 倍画；左上角的位置
const ICON_SCALE := 2
const ICON_POS: Array[Vector2] = [Vector2(420, 10), Vector2(448, 10)]
const ICON_HINTS: Array[String] = ["Codex: monsters, weapons and mutations.",
	"Volume, fullscreen, pixel scaling, screen shake, controls."]
## # = 主色，o = 暗一档（书脊、齿轮中间的孔边），. = 空
const BOOK := [
	".########.",
	"#o#......#",
	"#o#.####.#",
	"#o#......#",
	"#o#.###..#",
	"#o#......#",
	"#o#.####.#",
	"#o#......#",
	"#o########",
	".ooooooooo",
]
## 齿轮：8 个齿都贴着外圈（上下左右 + 四个斜角），中间 2×2 的方孔（美术巡检 10-18：原来像菱形 / 眼睛）
const GEAR := [
	"....##....",
	".##.##.##.",
	".########.",
	"..##oo##..",
	"####..####",
	"####..####",
	"..##oo##..",
	".########.",
	".##.##.##.",
	"....##....",
]
const CODEX_PATH := "res://scripts/ui/codex_menu.gd"
const BESTIARY_PATH := "res://scripts/ui/bestiary_menu.gd"

var _cam: Camera2D
var _time := 0.0
var _crew: Array[Dictionary] = []
var _ui: CanvasLayer
var _title: Label
var _sub: Label
## 中文模式下大字下面那行"倒带冲刺"（挂在 _sub 下面）
var _name_zh: Label
var _option_labels: Array[Label] = []
var _hint: Label
var _fade: ColorRect
var _selected := 0
## 右上角哪个图标选中了：-1 = 没有（在中间的菜单里），0 = 书，1 = 齿轮
var _icon := -1
var _icons: Control
var _ready_for_input := false
var _busy := false

# —— 多人加入 ——
var _lobby := false
var _lobby_root: Control
var _lobby_info: Label
## 每个船员位置上是谁："" 表示空着，否则是输入前缀（kb_left / kb_right / pad0 ……）
var _slots: Array[String] = ["", "", "", ""]
## 选武器界面按返回时设上：回到标题后直接打开选关页（合作时加入界面先按 Run.players 恢复好、藏着），
## 不从开始菜单重来（10-18 质检 / 监督会话：返回要回上一步）
static var return_to_levels := false
var _slot_labels: Array[Label] = []
## 合作：加入界面按攻击以后去选关卡；选关卡按返回回到加入界面（人还在）
var _coop := false
## 有存档时选了"开始"并确认会覆盖；真开新局（_launch）时才删旧档
var _overwrite_ok := false


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
	if _has_continue():
		_options.insert(0, "CONTINUE")
		_option_hints.insert(0, _continue_hint())
	# 网页版关不掉页面，不放 QUIT
	if OS.has_feature("web"):
		var qi := _options.find("QUIT")
		_options.remove_at(qi)
		_option_hints.remove_at(qi)
	# 从哪儿回来的都一样干净：上一局在顿帧 / 慢动作 / 暂停中途退出时，这些全局状态不会自己复原
	Engine.time_scale = 1.0
	get_tree().paused = false
	Game.shake = 0.0
	_build_world()
	_build_ui()
	Controls.device_changed.connect(_on_device_changed)
	_animate_in()
	if return_to_levels:
		return_to_levels = false
		_resume_levels.call_deferred()


## 从选武器返回：直接回选难度页（静态变量名 return_to_levels 是原来回选关页时起的，weapon_select 在设它）。合作时把加入界面按已经加入的人恢复好再藏起来，选关页再返回就回到加入界面，人还在
func _resume_levels() -> void:
	_busy = true
	_hide_menu()
	_coop = Run.players.size() > 1
	if _coop:
		await _enter_lobby()
		for p in Run.players:
			var i := Run.SKINS.find(p["skin"])
			if i >= 0:
				_slots[i] = p["input"]
		_refresh_lobby()
		_lobby = false
		_lobby_root.visible = false
	_ready_for_input = true
	_open_difficulty()


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

	# 游戏名 10-19 改成 REWIND RUSH / 倒带冲刺（作者："Rewind Rush，就这个了"）。大字不管什么语言都是英文
	# （像素字体的中文放到 33 号不好看）；中文模式在大字下面加一行小字"倒带冲刺"，副标题往下挪一行，见 _process
	_title = _label("REWIND RUSH", 30.0, 33, WARM, 4)
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_sub = _label("STEAM · SIGNAL · STATIC", SUB_Y, 11, DIM, 2)
	# 挂在副标题下面：副标题藏起来、淡入淡出时它跟着走，不用另外进各个列表
	_name_zh = _label("REWIND RUSH", 0.0, 11, WARM.darkened(0.15), 2, _sub)
	_name_zh.position = Vector2(0, -SUB_ZH_SHIFT)
	for i in _options.size():
		_option_labels.append(_label(_options[i], OPTION_TOP + i * _step(), 22, DIM, 3))
	_hint = _label("", 246.0, 11, DIM, 2)
	_icons = Control.new()
	_icons.size = Vector2(480, 270)
	_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icons.draw.connect(_draw_icons)
	_ui.add_child(_icons)
	for l in [_title, _sub, _hint, _icons] + _option_labels:
		l.modulate.a = 0.0

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_fade)


## 右上角的书和齿轮。没选中是灰的；选中变暖黄，外面一圈一张一缩的角标（和卡片一样）
func _draw_icons() -> void:
	for i in 2:
		var on := i == _icon
		var main := WARM if on else DIM
		var shade := main.darkened(0.45)
		var pat: Array = BOOK if i == 0 else GEAR
		var at := ICON_POS[i]
		for y in pat.size():
			var row: String = pat[y]
			for x in row.length():
				var ch := row[x]
				if ch == ".":
					continue
				_icons.draw_rect(Rect2(at + Vector2(x, y) * ICON_SCALE, Vector2.ONE * ICON_SCALE), main if ch == "#" else shade)
		if on:
			UiStyle.corners(_icons, _icon_rect(i).grow(-1), _time, WARM, 3.0)


func _icon_rect(i: int) -> Rect2:
	return Rect2(ICON_POS[i], Vector2(10, 10) * ICON_SCALE).grow(3)


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
	for l in [_title, _sub, _hint, _icons] + _option_labels:
		l.modulate.a = 1.0
	_refresh()
	if not IntroOverlay.played:
		var intro := IntroOverlay.new()
		# 片头：标题像被放映出来那样闪亮，其余的字（副标题、选项、提示、右上角图标）等片头放完再淡出来
		intro.title_node = _title
		var rest: Array = [_sub, _hint, _icons]
		rest.append_array(_option_labels)
		intro.rest_nodes = rest
		add_child(intro)
		await intro.finished
		for n in rest:
			n.create_tween().tween_property(n, "modulate:a", 1.0, 0.35)
		# 跳过片头的那一下（空格 / 回车 / C）不能顺手把 START 也按了：菜单是轮询 just_pressed，
		# 不认 set_input_as_handled，所以等这一帧过去、而且确认键松开了再开放（质检会话 10-17 夜里报的）
		await get_tree().process_frame
		while Input.is_action_pressed("ui_accept"):
			await get_tree().process_frame
	_ready_for_input = true
	_headphones_note()


## 建议佩戴耳机（10-18 接背景音乐时作者要的）：打开游戏、开始界面第一次出现时，左上角一个像素耳机加一行小字，
## 慢慢浮出来、停 4 秒、淡掉。不挡操作（不吃鼠标），一次运行只出一次
static var _headphones_shown := false
const HEADPHONES := [
	"..####..",
	".#....#.",
	"#......#",
	"#......#",
	"##....##",
	"##....##",
	"##....##",
]


func _headphones_note() -> void:
	if _headphones_shown:
		return
	_headphones_shown = true
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = Vector2(10, 12)
	box.size = Vector2(200, 16)
	box.modulate.a = 0.0
	var icon := Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size = Vector2(8, 7)
	icon.position = Vector2(0, 2)
	icon.draw.connect(func() -> void:
		for y in HEADPHONES.size():
			var row: String = HEADPHONES[y]
			for x in row.length():
				if row[x] == "#":
					icon.draw_rect(Rect2(x, y, 1, 1), DIM))
	box.add_child(icon)
	var l := Label.new()
	l.label_settings = Hud.small_text(DIM)
	l.text = tr("Headphones recommended")
	l.position = Vector2(12, -1)
	l.size = Vector2(190, 12)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	_ui.add_child(box)
	var tw := box.create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(box, "modulate:a", 1.0, 0.8)
	tw.tween_interval(4.0)
	tw.tween_property(box, "modulate:a", 0.0, 1.2)
	tw.tween_callback(box.queue_free)


func _fade_in(c: CanvasItem, duration: float) -> void:
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, duration)
	await tw.finished


func _on_device_changed(_pad: bool) -> void:
	if not _lobby and not _busy:
		_refresh()


func _refresh() -> void:
	for i in _option_labels.size():
		var l := _option_labels[i]
		var on := i == _selected and _icon < 0
		l.text = ("> " + tr(_options[i])) if on else "  " + tr(_options[i])
		var y := OPTION_TOP + i * _step()
		l.label_settings.font_color = LIT if on else DIM
		l.scale = Vector2.ONE
		if on:
			# 选中时往上跳 2 像素再落回来（整像素），不缩放：小数倍缩放会让像素字一大一小（美术巡检第 4 条）
			l.position.y = y - 2.0
			l.create_tween().tween_property(l, "position:y", y, 0.12).set_delay(0.06)
		else:
			l.position.y = y
	var keys := (tr("%s select    %s confirm") % [Controls.label("select"), Controls.label("confirm")]) if Controls.using_pad \
		else (tr("%s select    %s confirm    F11 fullscreen") % [Controls.label("select"), Controls.label("confirm")])
	var h := _option_hints[_selected] if _icon < 0 else ICON_HINTS[_icon]
	_hint.text = keys if h == "" else tr(h) + "\n" + keys
	_hint.position.y = 246.0 if h == "" else 234.0
	_hint.size.y = 30.0


func _process(delta: float) -> void:
	_time += delta
	# 缩放对齐屏幕倍率，像素是方的（见 GameCamera.pixel_zoom）
	_cam.zoom = Vector2.ONE * GameCamera.pixel_zoom(get_viewport(), CAM_ZOOM)
	_cam.position.x = CAM_CENTER.x + sin(_time * 0.12) * CAM_DRIFT
	_animate_crew(delta)
	_icons.queue_redraw()
	# 设置里切了语言，这里跟着换（每帧看一眼，便宜）
	var zh := Lang.is_zh()
	_name_zh.visible = zh
	_sub.position.y = SUB_Y + (SUB_ZH_SHIFT if zh else 0.0)
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
	if _icon >= 0:
		# 在右上角：左右换图标，下键回菜单第一项
		if Input.is_action_just_pressed("ui_left") and _icon > 0:
			_focus_icon(_icon - 1)
		elif Input.is_action_just_pressed("ui_right") and _icon < 1:
			_focus_icon(_icon + 1)
		elif Input.is_action_just_pressed("ui_down"):
			_icon = -1
			_selected = 0
			Game.sfx("ui_move", -10.0)
			_refresh()
		elif Input.is_action_just_pressed("ui_accept"):
			_confirm_icon()
		return
	if Input.is_action_just_pressed("ui_up"):
		# 在第一项再往上：跳到右上角的书
		if _selected == 0:
			_focus_icon(0)
		else:
			_move(-1)
	elif Input.is_action_just_pressed("ui_down"):
		_move(1)
	elif Input.is_action_just_pressed("ui_accept"):
		_confirm()


func _focus_icon(i: int) -> void:
	_icon = i
	Game.sfx("ui_move", -10.0)
	_refresh()


func _confirm_icon() -> void:
	if _icon == 0:
		_open_codex()
	else:
		_open_settings()


func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	# 跳关只在开发者模式（F8）里用数字键，开始界面本身不认数字键（作者 2026-10-17 定的）
	if _lobby:
		# Esc、鼠标右键都是返回上一步（10-18 质检：合作加入界面右键不能返回）
		if (event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE) \
				or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
			_leave_lobby()
		return
	if not _ready_for_input:
		return
	# 手柄 Select：直接开设置
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_BACK:
		_open_settings()
		return
	if event is InputEventMouseMotion:
		var k := _icon_at()
		if k >= 0:
			if k != _icon:
				_focus_icon(k)
			return
		var i := _option_at()
		if i >= 0 and (i != _selected or _icon >= 0):
			_selected = i
			_icon = -1
			Game.sfx("ui_move", -10.0)
			_refresh()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var k := _icon_at()
		if k >= 0:
			_icon = k
			_refresh()
			_confirm_icon()
			return
		var i := _option_at()
		if i >= 0:
			_selected = i
			_icon = -1
			_refresh()
			_confirm()


## 鼠标指着第几项（480×270 的坐标），没指着返回 -1
func _option_at() -> int:
	var pos := get_viewport().get_mouse_position()
	var i := floori((pos.y - OPTION_TOP + 2.0) / _step())
	return i if i >= 0 and i < _options.size() and absf(pos.x - 240.0) < 90.0 else -1


func _icon_at() -> int:
	var pos := get_viewport().get_mouse_position()
	for k in 2:
		if _icon_rect(k).has_point(pos):
			return k
	return -1


func _move(step: int) -> void:
	_selected = posmod(_selected + step, _options.size())
	Game.sfx("ui_move", -10.0)
	_refresh()


func _confirm() -> void:
	match _options[_selected]:
		"CONTINUE":
			_continue_run()
		"START":
			_start_new()
		"TUTORIAL":
			Run.players = [{"input": "solo", "skin": Run.SKINS[0]}]
			_go_tutorial(false)
		"CREDITS":
			_open_credits()
		"QUIT":
			Game.sfx("ui_back", -6.0)
			_busy = true
			await _fade_to(1.0, 0.4)
			get_tree().quit()


func _step() -> float:
	return Lang.menu_step(OPTION_STEP)


## 开始 → 单人还是合作。sound = false：从下一步按返回回来的，不再响一声确认
func _open_mode(sound := true) -> void:
	_busy = true
	if sound:
		Game.sfx("ui_confirm", -8.0)
	_hide_menu()
	var page := ModeSelect.new()
	_ui.add_child(page)
	var mode: int = await page.chosen
	match mode:
		ModeSelect.SOLO:
			_coop = false
			Run.players = [{"input": "solo", "skin": Run.SKINS[0]}]
			_after_mode()
		ModeSelect.COOP:
			_coop = true
			_enter_lobby()
		_:
			_back_to_menu()


## 回到开始菜单本身（三项 + 图标）
func _back_to_menu() -> void:
	_overwrite_ok = false
	_show_menu(_menu_items())
	await get_tree().process_frame
	_busy = false
	_refresh()


## 单人 / 合作选好以后：选难度（10-18 起不再自选关卡，选关页 LevelSelect 不进流程，跳关用 F8 开发者面板）。
## 选好就新开一局、从第一关开始；返回时单人回到单人 / 合作，合作回到加入界面
func _open_difficulty() -> void:
	_busy = true
	var page := DifficultySelect.new()
	_ui.add_child(page)
	var difficulty: int = await page.chosen
	if difficulty != DifficultySelect.BACK:
		_launch(1, difficulty)
		return
	await get_tree().process_frame
	if _coop and is_instance_valid(_lobby_root):
		_lobby_root.visible = true
		_lobby = true
		_busy = false
		_refresh_lobby()
	else:
		_open_mode(false)


## 新开一局：从第 level 关开始，先进选武器。difficulty 交给 Run（倍率归游戏设计会话）
func _launch(level: int, difficulty := DifficultySelect.NORMAL) -> void:
	_busy = true
	_lobby = false
	# 真开局了：下次新开局再放序章
	_prologue_done = false
	# 新开一局、玩家确认过覆盖：旧档这时才删（在选难度、选武器之间反悔退出的话旧档还在）。进第一关会存新档
	if _overwrite_ok and Run.has_method("clear_save"):
		Run.call("clear_save")
	_overwrite_ok = false
	Run.reset_run()
	_set_difficulty(difficulty)
	Game.reset_stats()
	_apply_level_start(level)
	await _fade_to(1.0, 0.5)
	get_tree().change_scene_to_file(LEVEL_SCENE)
	Game.flash(Color.BLACK, 1.0, 0.6)


## 书：总的图鉴（立绘添加会话做的 CodexMenu，里面分怪物、武器、变异与升级三册）。
## 用 load 找，不写类名：还没做好时开始界面照样能编译。没有图鉴就先开单独的怪物图鉴，都没有显示"敬请期待"
func _open_codex() -> void:
	var path := CODEX_PATH if ResourceLoader.exists(CODEX_PATH) else BESTIARY_PATH
	if not ResourceLoader.exists(path):
		Game.sfx("ui_back", -8.0, 0.8)
		_hint.text = tr("COMING SOON")
		return
	_busy = true
	Game.sfx("ui_confirm", -8.0)
	var hidden := _hide_menu()
	var page: Control = (load(path) as GDScript).new()
	if "start_chapter" in page:
		page.set("start_chapter", 0)
	_ui.add_child(page)
	await page.closed
	_show_menu(hidden)
	await get_tree().process_frame
	_busy = false
	_refresh()


func _menu_items() -> Array[CanvasItem]:
	var items: Array[CanvasItem] = [_title, _sub, _hint, _icons]
	items.append_array(_option_labels)
	return items


func _hide_menu() -> Array[CanvasItem]:
	var hidden := _menu_items()
	hidden.append_array(_option_labels)
	for c in hidden:
		c.visible = false
	return hidden


func _show_menu(hidden: Array[CanvasItem]) -> void:
	for c in hidden:
		c.visible = true


func _open_credits() -> void:
	_busy = true
	Game.sfx("ui_confirm", -8.0)
	var hidden := _hide_menu()
	var page := CreditsMenu.new()
	_ui.add_child(page)
	await page.closed
	for c in hidden:
		c.visible = true
	await get_tree().process_frame
	_busy = false
	_refresh()


func _open_settings() -> void:
	_busy = true
	Game.sfx("ui_confirm", -8.0)
	# 标题和选项先藏起来，免得从设置的半透明底下透出来叠在一起
	var hidden := _hide_menu()
	var menu := SettingsMenu.new()
	_ui.add_child(menu)
	await menu.closed
	for c in hidden:
		c.visible = true
	# 关设置那一下的返回键 / 确认键别漏到菜单
	await get_tree().process_frame
	_busy = false
	_refresh()


## 胶片序章（剧情会话做的 scenes/prologue.tscn，约 22 秒，能跳过）：新开一局、选完单人 / 合作以后先放，
## 放完接原来的流程（第一次进教学，再回来选难度；看过教学就直接回来选难度）。脚本用 load 找，不写类名。
## 剧情会话定的是每次新开局都放；从选难度退回单人 / 合作再选一次不算新开局，不重放（_prologue_done，真开局时清掉）
const PROLOGUE_SCENE := "res://scenes/prologue.tscn"
const PROLOGUE_SCRIPT := "res://scripts/ui/prologue.gd"
static var _prologue_done := false


## 选完单人 / 合作以后：序章 → （第一次）教学 → 选难度
func _after_mode() -> void:
	if not _prologue_done and ResourceLoader.exists(PROLOGUE_SCENE) and ResourceLoader.exists(PROLOGUE_SCRIPT):
		_go_prologue()
		return
	if not _tutorial_done():
		_go_tutorial(true)
		return
	_open_difficulty()


func _go_prologue() -> void:
	_busy = true
	_lobby = false
	_prologue_done = true
	var next := "res://scenes/title.tscn"
	if not _tutorial_done():
		(load(TUTORIAL_SCRIPT) as GDScript).set("next_scene", "res://scenes/title.tscn")
		next = TUTORIAL_SCENE
	(load(PROLOGUE_SCRIPT) as GDScript).set("next_scene", next)
	# 序章（和教学）放完回到开始界面，直接打开选难度；合作的人还在
	return_to_levels = true
	Game.sfx("ui_confirm", -4.0)
	Run.reset_run()
	Game.reset_stats()
	await _fade_to(1.0, 0.5)
	get_tree().change_scene_to_file(PROLOGUE_SCENE)
	Game.flash(Color.BLACK, 1.0, 0.6)


## 看过（或跳过）教学没有；教学关脚本不在就当看过，不拦人
func _tutorial_done() -> bool:
	if not ResourceLoader.exists(TUTORIAL_SCRIPT) or not ResourceLoader.exists(TUTORIAL_SCENE):
		return true
	var sc := load(TUTORIAL_SCRIPT) as GDScript
	return sc == null or bool(sc.call("done"))


## 进教学关。then_difficulty：新开一局路上进的，走完回来直接开选难度（单人回单人 / 合作，合作的人还在）；
## 否则是菜单里的"教学"，走完回开始菜单。Run.players 先设好（合作就是加入的那几个人）
func _go_tutorial(then_difficulty: bool) -> void:
	_busy = true
	_lobby = false
	var sc := load(TUTORIAL_SCRIPT) as GDScript
	sc.set("next_scene", "res://scenes/title.tscn")
	return_to_levels = then_difficulty
	Game.sfx("ui_confirm", -4.0)
	Run.reset_run()
	Game.reset_stats()
	await _fade_to(1.0, 0.5)
	get_tree().change_scene_to_file(TUTORIAL_SCENE)
	Game.flash(Color.BLACK, 1.0, 0.6)


func _set_difficulty(d: int) -> void:
	if Run.has_method("set_difficulty"):
		Run.call("set_difficulty", d)
	elif "difficulty" in Run:
		Run.set("difficulty", d)


## 存档脚本（游戏设计会话做的）；没有就是 null
func _save_api() -> Object:
	if Run.has_method("has_save"):
		return Run
	for path in SAVE_PATHS:
		if ResourceLoader.exists(path):
			var sc := load(path) as GDScript
			if sc:
				return sc
	return null


func _has_continue() -> bool:
	var api := _save_api()
	if api and api.has_method("has_save"):
		return bool(api.call("has_save"))
	return Progress.reached() > 1


## 存档是第几关（Run.save_info；没有存档功能时用 Progress 兜底）
func _save_level() -> int:
	var api := _save_api()
	if api and api.has_method("save_info"):
		return int((api.call("save_info") as Dictionary).get("level", 1))
	return Progress.reached()


## "继续"下面那行说明："从这关开头接着打：第二关 · 困难 · 2 人"（Run.save_info）
func _continue_hint() -> String:
	var level := Progress.reached()
	var diff := DifficultySelect.last
	var players := 1
	var api := _save_api()
	if api and api.has_method("save_info"):
		var info: Dictionary = api.call("save_info")
		level = int(info.get("level", level))
		diff = int(info.get("difficulty", diff))
		players = int(info.get("players", 1))
	var names := ["EASY", "NORMAL", "HARD"]
	var detail := tr("LEVEL %d" % clampi(level, 1, 3)) + " · " + tr(names[clampi(diff, 0, 2)])
	if players > 1:
		detail += " · " + tr("%d PLAYERS") % players
	return tr("Pick up at the start of: %s") % detail


## 存档里用到、现在却没插上的手柄（pad0 → 第 1 个手柄）。没插的话那个人进游戏动不了，"继续"之前先提醒
func _missing_pads() -> Array[int]:
	var out: Array[int] = []
	if not Run.has_method("save_path"):
		return out
	var c := ConfigFile.new()
	if c.load(Run.call("save_path")) != OK:
		return out
	var connected := Input.get_connected_joypads()
	for e in c.get_value("run", "players", []):
		var inp := str(e.get("input", ""))
		if inp.begins_with("pad"):
			var dev := inp.trim_prefix("pad").to_int()
			if not dev in connected:
				out.append(dev)
	return out


## "开始"：有存档时先问"会覆盖第 N 关的存档，确定吗？"（默认取消），没存档直接往下走
func _start_new() -> void:
	if not _has_continue():
		_open_mode()
		return
	_busy = true
	Game.sfx("ui_confirm", -8.0)
	var box := ConfirmBox.make(tr("Starting a new game overwrites your level %d save. Are you sure?") % _save_level())
	_ui.add_child(box)
	var ok: bool = await box.answered
	await get_tree().process_frame
	if ok:
		_overwrite_ok = true
		_open_mode(false)
	else:
		# 选"取消"的那一下确认键别漏回菜单、又按一次"开始"：等它松开
		while Input.is_action_pressed("ui_accept"):
			await get_tree().process_frame
		await get_tree().process_frame
		_busy = false
		_refresh()


## "继续"：交给存档；还没有存档功能时从打到过的最远那关开头开始（单人、上次选的难度），先进选武器
func _continue_run() -> void:
	_busy = true
	Game.sfx("ui_confirm", -4.0)
	var pads := _missing_pads()
	if not pads.is_empty():
		Game.sfx("ui_back", -8.0, 0.8)
		_hint.text = tr("Connect gamepad %d to continue.") % (pads[0] + 1)
		_busy = false
		return
	var api := _save_api()
	if api and api.has_method("continue_run"):
		# Run.continue_run 恢复难度、人、武器、零件、升级、变异、马灯，返回那关开头的场景，切场景由这里管
		var to: Variant = api.call("continue_run")
		if to is String and to != "":
			SceneFade.go(get_tree(), to)
			return
		_busy = false
		return
	Run.players = [{"input": "solo", "skin": Run.SKINS[0]}]
	_launch(Progress.reached(), DifficultySelect.last)


## 选关直接开第二关、第三关时的起始状态（商店会话按零件经济定的，见它报告第 17 节）：
## 直接开会跳过前面的商店，所以把正常打过来时一般已经买到的装备等级直接给上；变异不送（玩家自己选），
## 零件留一点到下一个商店花。马灯按上限的比例给（双人时上限是 80）。
const LEVEL_STARTS := {
	2: {"scene": "res://scenes/level2.tscn", "gear": 1, "parts": 2, "hp": 0.90},
	3: {"scene": "res://scenes/level3.tscn", "gear": 2, "parts": 4, "hp": 0.85},
}
const GEAR_IDS: Array[String] = ["charge", "fuel", "plating", "damping"]


## 新开一局（先 Run.reset_run），从第 level 关开始时给上起始状态；第一关什么都不加
func _apply_level_start(level: int) -> void:
	if not LEVEL_STARTS.has(level):
		return
	var st: Dictionary = LEVEL_STARTS[level]
	for id in GEAR_IDS:
		Upgrades.levels[id] = int(st["gear"])
	Run.add_part(int(st["parts"]))
	Run.crystal_hp = Run.crystal_max * float(st["hp"])
	Run.crystal_changed.emit(Run.crystal_hp, Run.crystal_max)
	Game.start_scene = st["scene"]


func _fade_to(alpha: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", alpha, duration)
	await tw.finished


# —— 多人加入 ——

## 合作的加入界面：开始菜单的字已经藏起来了（_open_mode），这里只管船员和说明
func _enter_lobby() -> void:
	_busy = true
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
	# 回到上一步：单人 / 合作
	_open_mode(false)


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
		_lobby_info.text = tr("%d players ready  -  any player: press ATTACK to start\n(lantern key: leave)") % n


## 人齐了按攻击：记下谁是谁，去选难度（加入界面先藏着，选难度按返回会再出来）
func _start_coop() -> void:
	_busy = true
	_lobby = false
	Run.players = []
	for i in 4:
		if _slots[i] != "":
			Run.players.append({"input": _slots[i], "skin": Run.SKINS[i]})
	Game.sfx("ui_confirm", -4.0)
	_lobby_root.visible = false
	_after_mode()
