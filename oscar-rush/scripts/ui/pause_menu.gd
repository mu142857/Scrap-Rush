class_name PauseMenu
extends CanvasLayer
## 暂停菜单。挂在 Game 下面，换场景也一直在。开始界面以外的场景里按 Esc 或手柄 Start 打开；
## 窗口失去焦点（切出去、网页切标签页）也自动打开。
## 里面有：继续、重开本关（场景有 _retry() 才显示，商店就没有）、设置、回到开始界面。
## 重开和回开始界面要按两下确认，免得手滑丢了进度。
## 别的东西已经把树暂停了（对话框、水晶碎了那 1.6 秒）时不打开，免得把它们的暂停搅乱。
## 菜单的动画和计时都不受 time_scale 影响，顿帧（time_scale = 0）、慢动作时打开也照常。
## 顺手管鼠标：关卡里鼠标 1.5 秒不动就藏起来，一动或打开菜单就出来。

const TITLE_SCENE := "res://scenes/title.tscn"
const WARM := Color8(255, 211, 138)
const DIM := Color(0.55, 0.55, 0.6)
const LIT := Color(1, 1, 1)
const TOP := 100.0
const STEP := 20.0

var is_open := false

var _root: Control
var _labels: Array[Label] = []
var _hint: Label
var _options: Array[String] = []
var _selected := 0
## 等第二下确认的那一项（"RESTART" / "TITLE"），没有就是空
var _confirming := ""
var _settings: SettingsMenu
var _frame: Control
var _info: Label
## 场景 → 显示的关卡名（text.csv 里有中文）
const LEVEL_NAMES := {
	"res://scenes/test_level.tscn": "LEVEL 1", "res://scenes/boss1.tscn": "LEVEL 1 BOSS",
	"res://scenes/level2_tube.tscn": "LEVEL 2", "res://scenes/level2.tscn": "LEVEL 2", "res://scenes/boss2.tscn": "LEVEL 2 BOSS",
	"res://scenes/level3.tscn": "LEVEL 3", "res://scenes/boss3.tscn": "LEVEL 3 BOSS", "res://scenes/shop.tscn": "SHOP",
}
const WEAPON_NAMES := {"flash": "FLASH LAMP", "rivet": "RIVET GUN", "hammer": "STEAM HAMMER"}
const MUTATION_NAMES := {"rage": "RAGE", "slave": "SLAVE FLASH", "echo": "TAPE ECHO", "dynamo": "DYNAMO"}
var _busy := false
var _mouse_idle := 0.0


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.size = Vector2(480, 270)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)
	var back := ColorRect.new()
	back.color = Color(0.02, 0.02, 0.035, 0.93)
	back.size = Vector2(480, 270)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(back)
	# 选项外面一张 UiStyle 卡片（和设置、选武器、商店同一套外框）
	_frame = Control.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.size = Vector2(480, 270)
	_frame.draw.connect(func() -> void:
		var step := Lang.menu_step(STEP)
		var h := (_options.size() - 1) * step + 42.0
		UiStyle.panel(_frame, Rect2(240.0 - 140.0, TOP - 11.0, 280.0, roundf(h)), false, 0.0))
	_root.add_child(_frame)
	_label("PAUSED", 48.0, 22, WARM, 3)
	# 现在的状态：哪一关、拿的什么家伙、变异、零件（监督会话 10-17 夜里提的）
	_info = _label("", 76.0, 11, Color(0.75, 0.73, 0.72), 2)
	_hint = _label("", 240.0, 11, DIM, 2)
	Controls.device_changed.connect(_on_device_changed)
	_hint.size.y = 30.0


func _label(text: String, y: float, font_size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	var s := Hud.small_text(color)
	s.font_size = font_size
	s.outline_size = outline
	l.label_settings = s
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, y)
	l.size = Vector2(480, font_size + 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	return l


## 现在能不能打开：开始界面不行，别人已经暂停了也不行
func can_open() -> bool:
	if is_open or _busy:
		return false
	var cur := get_tree().current_scene
	if cur == null or cur.scene_file_path == TITLE_SCENE or cur.scene_file_path == "":
		return false
	# 切场景的黑幕（SceneFade）还在的时候不开：不然菜单开着、底下换了场景，"重开本关"会重开到新场景去
	for c in get_tree().root.get_children():
		if c is SceneFade:
			return false
	# 关卡已经在走出口 / 气动管冲到终点、黑幕还没起来的那半秒也不开（level2.gd 的 _leaving、tube_run.gd 的 _ending）
	if cur.get("_leaving") == true or cur.get("_ending") == true:
		return false
	return not get_tree().paused


func open() -> void:
	if not can_open():
		return
	is_open = true
	Settings.set_muffled(true)
	get_tree().paused = true
	Game.sfx("ui_back", -10.0)
	for l in _labels:
		l.queue_free()
	_labels.clear()
	_options = ["RESUME"]
	if get_tree().current_scene.has_method("_retry"):
		_options.append("RESTART")
	_options += ["SETTINGS", "TITLE"]
	for i in _options.size():
		_labels.append(_label("", TOP + i * Lang.menu_step(STEP), 22, DIM, 3))
	_selected = 0
	_confirming = ""
	_refresh()
	_frame.queue_redraw()
	_info.text = _status_line()
	_root.visible = true
	_root.modulate.a = 0.0
	_root.create_tween().set_ignore_time_scale(true).tween_property(_root, "modulate:a", 1.0, 0.12)


func _status_line() -> String:
	var parts: Array[String] = []
	var scene := get_tree().current_scene.scene_file_path
	if LEVEL_NAMES.has(scene):
		parts.append(tr(LEVEL_NAMES[scene]))
	parts.append(tr(WEAPON_NAMES.get(Upgrades.weapon, Upgrades.weapon.to_upper())))
	if Upgrades.mutation != "":
		parts.append(tr(MUTATION_NAMES.get(Upgrades.mutation, Upgrades.mutation.to_upper())))
	parts.append(tr("PARTS %d") % Run.parts)
	return "   ·   ".join(parts)


func _text(option: String) -> String:
	match option:
		"RESUME":
			return "RESUME"
		"RESTART":
			return "RESTART LEVEL"
		"SETTINGS":
			return "SETTINGS"
		"TITLE":
			return "QUIT TO TITLE"
	return option


func _on_device_changed(_pad: bool) -> void:
	if is_open:
		_refresh()


func _refresh() -> void:
	for i in _options.size():
		var on := i == _selected
		var t := tr(_text(_options[i]))
		if _confirming == _options[i]:
			t = tr("SURE? PRESS AGAIN")
		_labels[i].text = ("> %s <" % t) if on else t
		_labels[i].position.y = TOP + i * Lang.menu_step(STEP)
		_labels[i].label_settings.font_color = (WARM if _confirming == _options[i] else LIT) if on else DIM
	var h := ""
	match _options[_selected]:
		"RESTART":
			h = "Back to the start of this level. Lantern and parts reset to how you came in."
		"TITLE":
			h = "This run's progress will be lost."
	var keys := tr("%s select    %s confirm    %s resume") % [Controls.label("select"), Controls.label("confirm"), Controls.label("pause")]
	_hint.text = keys if h == "" else tr(h) + "\n" + keys
	# 两行时往上提，别和关卡底部那行按键提示（y≈258）叠在一起
	_hint.position.y = 240.0 if h == "" else 226.0


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_mouse_idle = 0.0
	if not is_open:
		if _is_pause_button(event) and can_open():
			open()
			get_viewport().set_input_as_handled()
		return
	if _busy or _settings != null:
		return
	get_viewport().set_input_as_handled()
	if _is_pause_button(event) or event.is_action_pressed("ui_cancel"):
		_resume()
	elif event.is_action_pressed("ui_up", true):
		_move(-1)
	elif event.is_action_pressed("ui_down", true):
		_move(1)
	elif event.is_action_pressed("ui_accept"):
		_confirm()
	elif event is InputEventMouseMotion:
		var i := _option_at()
		if i >= 0 and i != _selected:
			_selected = i
			_confirming = ""
			Game.sfx("ui_move", -12.0)
			_refresh()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _option_at()
		if i >= 0:
			if i != _selected:
				_confirming = ""
			_selected = i
			_confirm()


func _process(delta: float) -> void:
	_mouse_idle += delta
	var cur := get_tree().current_scene
	var in_level := cur != null and cur.scene_file_path != TITLE_SCENE and cur.scene_file_path != ""
	var hide_cursor := in_level and not is_open and _mouse_idle > 1.5
	var mode := Input.MOUSE_MODE_HIDDEN if hide_cursor else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != mode:
		Input.mouse_mode = mode


func _is_pause_button(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE
	if event is InputEventJoypadButton:
		return event.pressed and event.button_index == JOY_BUTTON_START
	return false


## 切出窗口就停，回来不自动继续（让玩家自己准备好再按）。
## 录像（--write-movie）和带调试参数的自动测试、截图不自动停，不然窗口一失焦就录不到画面。
## 手动关掉：命令行加 `-- --no-autopause`（其实 -- 后面带任何参数都会关），或者设环境变量 SCRAP_NO_AUTOPAUSE=1。
## 失焦可能正赶上场景在加载，这时往树里加音效节点会报错，所以推到这一帧末尾再打开。
func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_FOCUS_OUT:
		return
	if Engine.get_write_movie_path() != "" or not OS.get_cmdline_user_args().is_empty() \
			or OS.get_environment("SCRAP_NO_AUTOPAUSE") == "1":
		return
	_open_if_still_possible.call_deferred()


func _open_if_still_possible() -> void:
	if can_open():
		open()


func _option_at() -> int:
	var p := _root.get_global_mouse_position()
	var i := floori((p.y - TOP + 2.0) / Lang.menu_step(STEP))
	return i if i >= 0 and i < _options.size() and absf(p.x - 240.0) < 100.0 else -1


func _move(step: int) -> void:
	_selected = posmod(_selected + step, _options.size())
	_confirming = ""
	Game.sfx("ui_move", -10.0)
	_refresh()


func _confirm() -> void:
	var option := _options[_selected]
	if (option == "RESTART" or option == "TITLE") and _confirming != option:
		_confirming = option
		Game.sfx("ui_move", -6.0, 0.8)
		_refresh()
		return
	match option:
		"RESUME":
			_resume()
		"RESTART":
			Game.sfx("ui_confirm", -6.0)
			await _close()
			var cur := get_tree().current_scene
			get_tree().paused = false
			if cur and cur.has_method("_retry"):
				# "重开本关"就是从本关开头来（按 R / 马灯碎了才回最近的存档点）
				Run.forget_checkpoint()
				cur.call("_retry")
		"SETTINGS":
			Game.sfx("ui_confirm", -8.0)
			_settings = SettingsMenu.new()
			add_child(_settings)
			_root.visible = false
			await _settings.closed
			_settings = null
			# 设置里可能换了语言
			_refresh()
			_root.visible = true
		"TITLE":
			Game.sfx("ui_back", -6.0)
			await _close()
			Game.flash(Color.BLACK, 1.0, 0.6)
			Engine.time_scale = 1.0
			get_tree().paused = false
			get_tree().change_scene_to_file(TITLE_SCENE)


func _resume() -> void:
	Game.sfx("ui_confirm", -10.0)
	await _close()
	# 晚一点再放开，免得确认键这一下被关卡当成跳跃 / 攻击
	await get_tree().create_timer(0.08, true, false, true).timeout
	if not is_open:
		get_tree().paused = false


func _close() -> void:
	_busy = true
	var tw := _root.create_tween().set_ignore_time_scale(true)
	tw.tween_property(_root, "modulate:a", 0.0, 0.1)
	await tw.finished
	_root.visible = false
	is_open = false
	Settings.set_muffled(false)
	_busy = false
