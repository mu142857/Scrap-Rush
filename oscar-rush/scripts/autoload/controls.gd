extends Node
## 输入方案。每个玩家拿一个"前缀"，前缀下面固定五个动作：
##   <前缀>_left / _right / _jump / _attack / _crystal
## 前缀有：
##   solo      单人：和 1P 同一套键（A D W C V），另外方向键和空格也认，任何手柄也认
##   kb_left   键盘左半边 1P：左手 A D 移动、W 跳，拇指 C 攻击、V 马灯
##   kb_right  键盘右半边 2P：右手 J L 移动、I 跳，拇指 M 攻击、N 马灯（和 1P 左右对称）；
##             也可以用方向键加 . /
##   pad0~pad3 第 n 个手柄
## 单人不用 J/K/L，免得练出来的手感和双人时 2P 的位置打架。
## 动作在启动时用代码注册，不写在 project.godot 里，方便按设备号生成。

const ACTIONS: Array[String] = ["left", "right", "jump", "attack", "crystal"]
const PAD_COUNT := 4
const DEADZONE := 0.35

const KB_SOLO := {
	"left": [KEY_A, KEY_LEFT],
	"right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_W, KEY_UP, KEY_SPACE],
	"attack": [KEY_C],
	"crystal": [KEY_V],
}
const KB_LEFT := {
	"left": [KEY_A],
	"right": [KEY_D],
	"jump": [KEY_W],
	"attack": [KEY_C],
	"crystal": [KEY_V],
}
const KB_RIGHT := {
	"left": [KEY_J, KEY_LEFT],
	"right": [KEY_L, KEY_RIGHT],
	"jump": [KEY_I, KEY_UP],
	"attack": [KEY_M, KEY_PERIOD],
	"crystal": [KEY_N, KEY_SLASH],
}

## 给界面显示用的按键名
const KEY_NAMES := {
	"solo": {"move": "A/D", "jump": "W", "attack": "C", "crystal": "V"},
	"kb_left": {"move": "A/D", "jump": "W", "attack": "C", "crystal": "V"},
	"kb_right": {"move": "J/L", "jump": "I", "attack": "M", "crystal": "N"},
}


func _ready() -> void:
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
	if KEY_NAMES.has(scheme):
		return KEY_NAMES[scheme][what]
	return {"move": "Stick", "jump": "A", "attack": "X", "crystal": "Y"}[what]


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
