extends Node
## 玩家设置：音量、全屏、像素完美、震屏强度、语言（Lang，scripts/autoload/lang.gd）。存在 user://settings.cfg，下次打开还在
## （网页版的 user:// 存在浏览器的 IndexedDB 里，同样能留住）。
## 界面在 scripts/ui/settings_menu.gd，开始界面和暂停菜单都用它。
##
## 物理插值（project.godot 里打开）：物理 120 帧、屏幕 60/120/144 帧不同步时，主角会一顿一顿地微抖。
## 只给在物理帧里移动的主角和马灯打开（Player、Crystal 一进场景树就设成 ON），其他节点（镜头、视差背景、
## UI、在 _process 里挪的东西）都关着，免得它们反过来变卡。镜头读主角插值后的位置（GameCamera._pos）。
## 瞬移主角或马灯以后要调一下 reset_physics_interpolation()，不然会拖出一帧残影。
##
## 声音分三条总线：Master ← Music、SFX。
## 没指定总线的 AudioStreamPlayer（Game.sfx 和各处自己 new 的）一进场景树就自动改到 SFX，
## 所以各处代码不用改。以后加音乐时，播放器设 bus = "Music" 就归音乐音量管。

signal changed

const PATH := "user://settings.cfg"
## 测试脚本设环境变量 SCRAP_SETTINGS_PATH=别的文件，就不会改到玩家（作者）真正的设置
var _path := PATH
## 音量 0~10 档
const STEPS := 10
## 震屏强度可选的几档：关 / 轻 / 强。默认"轻"（作者 2026-10-17 嫌晃得厉害）
const SHAKE_LEVELS: Array[float] = [0.0, 0.6, 1.0]

var master := 8
var music := 8
## 各区域的环境声（Ambience 总线，scripts/audio/ambience.gd）
## 默认 4：作者 10-18 早上嫌环境声吵，从 8 降到 4
var ambience := 4
var sfx := 8
var fullscreen := true
var pixel_perfect := false
var shake_index := 1
## ""= 跟随系统语言，"en" / "zh" = 玩家在设置里选过
var language := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("SCRAP_SETTINGS_PATH") != "":
		_path = OS.get_environment("SCRAP_SETTINGS_PATH")
	get_tree().root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_make_buses()
	_add_menu_keys()
	get_tree().node_added.connect(_on_node_added)
	# 网页版一开始不能自己进全屏（浏览器要玩家先按一下），默认按窗口算
	if OS.has_feature("web"):
		fullscreen = false
	var had_file := _load()
	Lang.apply(language)
	_apply_audio()
	_apply_pixel_perfect()
	# 没存过设置就照 project.godot 的默认（全屏）；网页版不在启动时切全屏
	if had_file and not OS.has_feature("web"):
		_apply_fullscreen()


func shake_scale() -> float:
	return SHAKE_LEVELS[shake_index]


func set_value(key: String, value: Variant) -> void:
	set(key, value)
	match key:
		"master", "music", "sfx", "ambience":
			_apply_audio()
		"fullscreen":
			_apply_fullscreen()
		"pixel_perfect":
			_apply_pixel_perfect()
		"language":
			Lang.apply(language)
	save()
	changed.emit()


## F11 / Alt+Enter 切过全屏以后同步一下，存起来
func sync_fullscreen() -> void:
	fullscreen = DisplayServer.window_get_mode() >= DisplayServer.WINDOW_MODE_FULLSCREEN
	save()
	changed.emit()


func save() -> void:
	var c := ConfigFile.new()
	for key in ["master", "music", "sfx", "ambience", "fullscreen", "pixel_perfect", "shake_index", "language"]:
		c.set_value("settings", key, get(key))
	c.save(_path)


func _load() -> bool:
	var c := ConfigFile.new()
	if c.load(_path) != OK:
		return false
	master = clampi(c.get_value("settings", "master", master), 0, STEPS)
	music = clampi(c.get_value("settings", "music", music), 0, STEPS)
	sfx = clampi(c.get_value("settings", "sfx", sfx), 0, STEPS)
	ambience = clampi(c.get_value("settings", "ambience", ambience), 0, STEPS)
	fullscreen = c.get_value("settings", "fullscreen", fullscreen)
	pixel_perfect = c.get_value("settings", "pixel_perfect", pixel_perfect)
	shake_index = clampi(c.get_value("settings", "shake_index", shake_index), 0, SHAKE_LEVELS.size() - 1)
	language = str(c.get_value("settings", "language", language))
	return true


## UI 总线：菜单的音效（ui_*）走这条，暂停时不被闷掉；音量跟"音效"那一档
func _make_buses() -> void:
	for bus_name in ["Music", "SFX", "UI", "Ambience"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, "Master")
	# 暂停时把游戏声和音乐"闷"一下（低通），一听就知道停了。平时关着
	for bus_name in ["Music", "SFX", "Ambience"]:
		var i := AudioServer.get_bus_index(bus_name)
		if AudioServer.get_bus_effect_count(i) == 0:
			var lp := AudioEffectLowPassFilter.new()
			lp.cutoff_hz = 700.0
			AudioServer.add_bus_effect(i, lp)
			AudioServer.set_bus_effect_enabled(i, 0, false)
	# 环境声的空间感：第 1 格一个混响，各区域的大小、湿声由 Ambience._apply_room 调（10-18 背景音乐接入时加的）
	var amb := AudioServer.get_bus_index("Ambience")
	if AudioServer.get_bus_effect_count(amb) == 1:
		var rv := AudioEffectReverb.new()
		rv.wet = 0.0
		rv.dry = 1.0
		AudioServer.add_bus_effect(amb, rv)


## 暂停菜单开 / 关时调
func set_muffled(on: bool) -> void:
	for bus_name in ["Music", "SFX", "Ambience"]:
		var i := AudioServer.get_bus_index(bus_name)
		if i >= 0 and AudioServer.get_bus_effect_count(i) > 0:
			AudioServer.set_bus_effect_enabled(i, 0, on)


func _on_node_added(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D:
		if node.bus == &"Master":
			node.bus = &"SFX"
	elif node is Player or node is Crystal:
		node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON


func _apply_audio() -> void:
	_set_bus("Master", master)
	_set_bus("Music", music)
	_set_bus("SFX", sfx)
	_set_bus("UI", sfx)
	_set_bus("Ambience", ambience)


func _set_bus(bus_name: String, step: int) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, step <= 0)
	# 平方曲线：耳朵听起来每档差不多
	var lin := pow(float(step) / STEPS, 2.0)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(lin, 0.0001)))


func _apply_fullscreen() -> void:
	var full := DisplayServer.window_get_mode() >= DisplayServer.WINDOW_MODE_FULLSCREEN
	if full == fullscreen:
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


## 像素完美：只按整数倍放大，四周留黑边，像素大小一致
func _apply_pixel_perfect() -> void:
	get_tree().root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if pixel_perfect \
		else Window.CONTENT_SCALE_STRETCH_FRACTIONAL


## 菜单导航：W/S/A/D、左摇杆、C 也能用（默认的 ui_* 只有方向键、回车、空格和十字键）；
## 手柄 B 返回
func _add_menu_keys() -> void:
	var keys := {
		"ui_up": [KEY_W],
		"ui_down": [KEY_S],
		"ui_left": [KEY_A],
		"ui_right": [KEY_D],
		"ui_accept": [KEY_C],
	}
	for action in keys:
		for code in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			if not InputMap.action_has_event(action, ev):
				InputMap.action_add_event(action, ev)
	for pair in [["ui_up", JOY_AXIS_LEFT_Y, -1.0], ["ui_down", JOY_AXIS_LEFT_Y, 1.0],
			["ui_left", JOY_AXIS_LEFT_X, -1.0], ["ui_right", JOY_AXIS_LEFT_X, 1.0]]:
		var m := InputEventJoypadMotion.new()
		m.axis = pair[1]
		m.axis_value = pair[2]
		m.device = -1
		if not InputMap.action_has_event(pair[0], m):
			InputMap.action_add_event(pair[0], m)
	# 手柄：A 确认、B 返回，十字键上下左右（项目的 ui_* 默认里没有手柄按钮）
	for pair in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B],
			["ui_up", JOY_BUTTON_DPAD_UP], ["ui_down", JOY_BUTTON_DPAD_DOWN],
			["ui_left", JOY_BUTTON_DPAD_LEFT], ["ui_right", JOY_BUTTON_DPAD_RIGHT]]:
		var b := InputEventJoypadButton.new()
		b.button_index = pair[1]
		b.device = -1
		if not InputMap.action_has_event(pair[0], b):
			InputMap.action_add_event(pair[0], b)
