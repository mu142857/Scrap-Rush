extends Node
## 输入方案。每个玩家拿一个"前缀"，前缀下面固定六个动作：
##   <前缀>_left / _right / _jump / _attack / _crystal / _down
##   down 只用来从单向平台上跳下去（S / ↓ / 2P 的 K / 手柄十字键下、摇杆往下）
## 前缀有：
##   solo      单人：和 1P 同一套键（A D W C V），另外方向键和空格也认，任何手柄也认
##   kb_left   键盘左半边 1P：左手 A D 移动、W 跳，拇指 C 攻击、V 马灯
##   kb_right  键盘右半边 2P：右手 J L 移动、I 跳，拇指 M 攻击、N 马灯（和 1P 左右对称）；
##             也可以用方向键加 . /
##   pad0~pad3 第 n 个手柄
## 单人不用 J/K/L，免得练出来的手感和双人时 2P 的位置打架。
## 动作在启动时用代码注册，不写在 project.godot 里，方便按设备号生成。

const ACTIONS: Array[String] = ["left", "right", "jump", "attack", "crystal", "down"]
const PAD_COUNT := 4
const DEADZONE := 0.35

const KB_SOLO := {
	"left": [KEY_A, KEY_LEFT],
	"right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_W, KEY_UP, KEY_SPACE],
	"attack": [KEY_C],
	"crystal": [KEY_V],
	"down": [KEY_S, KEY_DOWN],
}
const KB_LEFT := {
	"left": [KEY_A],
	"right": [KEY_D],
	"jump": [KEY_W],
	"attack": [KEY_C],
	"crystal": [KEY_V],
	"down": [KEY_S],
}
const KB_RIGHT := {
	"left": [KEY_J, KEY_LEFT],
	"right": [KEY_L, KEY_RIGHT],
	"jump": [KEY_I, KEY_UP],
	"attack": [KEY_M, KEY_PERIOD],
	"crystal": [KEY_N, KEY_SLASH],
	"down": [KEY_K, KEY_DOWN],
}

## 给界面显示用的按键名
const KEY_NAMES := {
	"solo": {"move": "A/D", "jump": "W", "attack": "C", "crystal": "V", "down": "S"},
	"kb_left": {"move": "A/D", "jump": "W", "attack": "C", "crystal": "V", "down": "S"},
	"kb_right": {"move": "J/L", "jump": "I", "attack": "M", "crystal": "N", "down": "K"},
}


## 按键提示跟着输入设备变（2026-10-17 夜间，游戏细节讨论会话）：
## 记住玩家最后用的是键盘还是手柄。单人方案（solo）的 key_name 用手柄时返回手柄键名，
## HUD、新手提示、商店、马灯提示这些调 key_name 的地方自动跟着变；菜单用 label()。
## 换设备时发 device_changed，缓存了提示文字的地方接一下这个信号重画。
signal device_changed(using_pad: bool)

var using_pad := false

const PAD_NAMES := {"move": "Stick", "jump": "A", "attack": "X", "crystal": "Y", "down": "Down"}
## 菜单里的键：键盘一套、手柄一套
const MENU_KB := {"confirm": "Space / C", "back": "Esc", "pause": "Esc", "select": "W/S", "change": "A/D",
	"scroll": "W/S", "page": "A/D"}
const MENU_PAD := {"confirm": "A", "back": "B", "pause": "Start", "select": "D-pad", "change": "Left/Right",
	"scroll": "Up/Down", "page": "Left/Right"}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.window_input.connect(_on_window_input)
	_bind_keys("solo", KB_SOLO)
	_bind_pad("solo", -1)
	_bind_keys("kb_left", KB_LEFT)
	_bind_keys("kb_right", KB_RIGHT)
	for i in PAD_COUNT:
		_bind_pad("pad%d" % i, i)


func all_schemes() -> Array[String]:
	var out: Array[String] = ["kb_left", "kb_right"]
	for i in PAD_COUNT:
		out.append("pad%d" % i)
	return out


func key_name(scheme: String, what: String) -> String:
	if scheme == "solo" and using_pad:
		return tr(PAD_NAMES[what])
	if KEY_NAMES.has(scheme):
		return KEY_NAMES[scheme][what]
	return tr(PAD_NAMES[what])


## 菜单和单人提示用的键名，跟着最后用的设备走：
## confirm / back / pause / select / change / scroll / page，以及 move / jump / attack / crystal / down
func label(what: String) -> String:
	if MENU_KB.has(what):
		return tr((MENU_PAD if using_pad else MENU_KB)[what])
	return key_name("solo", what)


## 用根窗口的 window_input：每个输入在分发给节点之前都先到这里，菜单把事件标成"已处理"也不影响
func _on_window_input(event: InputEvent) -> void:
	var pad := using_pad
	if event is InputEventJoypadButton and event.pressed:
		pad = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		pad = true
	elif (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
		pad = false
	if pad != using_pad:
		using_pad = pad
		device_changed.emit(using_pad)


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, DEADZONE)


func _bind_keys(prefix: String, map: Dictionary) -> void:
	for a in ACTIONS:
		var action := "%s_%s" % [prefix, a]
		_ensure(action)
		for code in map[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			ev.device = -1
			InputMap.action_add_event(action, ev)


func _bind_pad(prefix: String, device: int) -> void:
	for a in ACTIONS:
		_ensure("%s_%s" % [prefix, a])
	_add_axis(prefix + "_left", device, JOY_AXIS_LEFT_X, -1.0)
	_add_axis(prefix + "_right", device, JOY_AXIS_LEFT_X, 1.0)
	_add_button(prefix + "_left", device, JOY_BUTTON_DPAD_LEFT)
	_add_button(prefix + "_right", device, JOY_BUTTON_DPAD_RIGHT)
	_add_axis(prefix + "_down", device, JOY_AXIS_LEFT_Y, 1.0)
	_add_button(prefix + "_down", device, JOY_BUTTON_DPAD_DOWN)
	_add_button(prefix + "_jump", device, JOY_BUTTON_A)
	_add_button(prefix + "_attack", device, JOY_BUTTON_X)
	_add_axis(prefix + "_attack", device, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_button(prefix + "_crystal", device, JOY_BUTTON_Y)
	_add_button(prefix + "_crystal", device, JOY_BUTTON_B)


func _add_button(action: String, device: int, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.device = device
	InputMap.action_add_event(action, ev)


func _add_axis(action: String, device: int, axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	ev.device = device
	InputMap.action_add_event(action, ev)
