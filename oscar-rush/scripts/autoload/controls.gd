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

## 给界面显示用的按键名（双人分键盘的两套，不能改键）。单人的键名按当前键位现算（key_name）
const KEY_NAMES := {
	"kb_left": {"move": "A/D", "jump": "W", "attack": "C", "crystal": "V", "down": "S"},
	"kb_right": {"move": "J/L", "jump": "I", "attack": "M", "crystal": "N", "down": "K"},
}

# —— 改键（10-18 作者："我想加一个可以换键位的功能"；游戏细节讨论会话）——
## 能改的：单人键盘的六个动作（每个动作一个主键，KB_SOLO 里第一个；方向键、空格这些副键留着），
## 单人和所有手柄共用的三个按钮（跳、攻击、马灯；移动和"下"固定用摇杆 / 十字键）。
## 双人分键盘的左右两套（kb_left / kb_right）不能改，免得两个人的键互相打架。
## 规矩：
##   - 新键已经是别的动作的主键：两个交换（返回 swapped）。是别的动作的副键：那个副键让出来。
##   - Esc、F11、F8 和手柄的 Start、Back、Guide 留给暂停 / 全屏 / 开发者面板 / 设置，不让占（返回 reason）。
## 存在设置存档里（Settings 的 [keys] 段，跟着 SCRAP_SETTINGS_PATH 走），启动时读回。
## 改完发 device_changed，按键提示缓存了文字的地方会重画；其余提示每次都调 key_name，自动跟着变。
const REBIND_KB: Array[String] = ["left", "right", "jump", "attack", "crystal", "down"]
const REBIND_PAD: Array[String] = ["jump", "attack", "crystal"]
const PAD_DEFAULT := {"jump": JOY_BUTTON_A, "attack": JOY_BUTTON_X, "crystal": JOY_BUTTON_Y}
## 手柄的副键：马灯另外认 B，攻击另外认右扳机（扳机是轴，不在改键里）
const PAD_EXTRA := {"crystal": [JOY_BUTTON_B]}
const RESERVED_KEYS: Array[int] = [KEY_ESCAPE, KEY_F11, KEY_F8]
const RESERVED_PAD: Array[int] = [JOY_BUTTON_START, JOY_BUTTON_BACK, JOY_BUTTON_GUIDE]
const PAD_BUTTON_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS",
	JOY_BUTTON_DPAD_UP: "D-pad Up", JOY_BUTTON_DPAD_DOWN: "D-pad Down",
	JOY_BUTTON_DPAD_LEFT: "D-pad Left", JOY_BUTTON_DPAD_RIGHT: "D-pad Right",
	JOY_BUTTON_MISC1: "Share", JOY_BUTTON_PADDLE1: "P1", JOY_BUTTON_PADDLE2: "P2",
	JOY_BUTTON_PADDLE3: "P3", JOY_BUTTON_PADDLE4: "P4", JOY_BUTTON_TOUCHPAD: "Touchpad",
}

## 玩家改过的：动作 → 键（physical keycode）/ 手柄按钮。没改过的不在里面
var kb_custom := {}
var pad_custom := {}


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
	_bind_keys("kb_left", KB_LEFT)
	_bind_keys("kb_right", KB_RIGHT)
	_apply()


## 按现在的键位（默认 + 玩家改过的）重新注册单人和各个手柄的动作
func _apply() -> void:
	var solo_map := {}
	for a in ACTIONS:
		solo_map[a] = solo_keys(a)
	for a in ACTIONS:
		var action := "solo_" + a
		_ensure(action)
		InputMap.action_erase_events(action)
		for i in PAD_COUNT:
			_ensure("pad%d_%s" % [i, a])
			InputMap.action_erase_events("pad%d_%s" % [i, a])
	_bind_keys("solo", solo_map)
	_bind_pad("solo", -1)
	for i in PAD_COUNT:
		_bind_pad("pad%d" % i, i)


## 单人键盘某个动作的主键
func primary_key(action: String) -> int:
	return int(kb_custom.get(action, KB_SOLO[action][0]))


## 单人键盘某个动作认的所有键：主键 + 默认副键里没被别的动作拿去当主键的
func solo_keys(action: String) -> Array:
	var taken := {}
	for a in ACTIONS:
		if a != action:
			taken[primary_key(a)] = true
	var out := [primary_key(action)]
	for k in KB_SOLO[action].slice(1):
		if not taken.has(k) and not k in out:
			out.append(k)
	return out


func pad_button(action: String) -> int:
	return int(pad_custom.get(action, PAD_DEFAULT[action]))


## 改单人键盘的键。返回 {ok, swapped（换过去的动作，没有就是 ""）, reason（不让改的原因）}
func rebind_key(action: String, code: int) -> Dictionary:
	if code in RESERVED_KEYS:
		return {"ok": false, "swapped": "", "reason": "reserved"}
	var old := primary_key(action)
	var swapped := ""
	for a in REBIND_KB:
		if a != action and primary_key(a) == code:
			kb_custom[a] = old
			swapped = a
	kb_custom[action] = code
	_clean(kb_custom, func(a): return KB_SOLO[a][0])
	_changed()
	return {"ok": true, "swapped": swapped, "reason": ""}


## 改手柄按钮（单人的手柄和 pad0~3 一起变）
func rebind_pad(action: String, button: int) -> Dictionary:
	if button in RESERVED_PAD:
		return {"ok": false, "swapped": "", "reason": "reserved"}
	var old := pad_button(action)
	var swapped := ""
	for a in REBIND_PAD:
		if a != action and pad_button(a) == button:
			pad_custom[a] = old
			swapped = a
	pad_custom[action] = button
	_clean(pad_custom, func(a): return PAD_DEFAULT[a])
	_changed()
	return {"ok": true, "swapped": swapped, "reason": ""}


func reset_bindings() -> void:
	kb_custom.clear()
	pad_custom.clear()
	_changed()


## 和默认一样的就不记了，存档里只留真正改过的
func _clean(d: Dictionary, default: Callable) -> void:
	for a in d.keys():
		if int(d[a]) == int(default.call(a)):
			d.erase(a)


func _changed() -> void:
	_apply()
	device_changed.emit(using_pad)


## Settings 读档时调：{kb: {动作: 键}, pad: {动作: 按钮}}
func import_bindings(kb: Dictionary, pad: Dictionary) -> void:
	kb_custom.clear()
	pad_custom.clear()
	for a in kb:
		if a in REBIND_KB and not int(kb[a]) in RESERVED_KEYS:
			kb_custom[a] = int(kb[a])
	for a in pad:
		if a in REBIND_PAD and not int(pad[a]) in RESERVED_PAD:
			pad_custom[a] = int(pad[a])
	# 存档被手改坏、两个动作同一个键：后来的那个回默认
	var seen := {}
	for a in REBIND_KB:
		var k := primary_key(a)
		if seen.has(k):
			kb_custom.erase(a)
		seen[primary_key(a)] = true
	seen.clear()
	for a in REBIND_PAD:
		var b := pad_button(a)
		if seen.has(b):
			pad_custom.erase(a)
		seen[pad_button(a)] = true
	_apply()


## 键盘键的显示名（按键盘上印的字，物理键码转成当前布局的键名）
func key_label(code: int) -> String:
	var shown := code
	if DisplayServer.has_method("keyboard_get_label_from_physical") and DisplayServer.get_name() != "headless":
		var lab: int = DisplayServer.keyboard_get_label_from_physical(code)
		if lab != KEY_NONE:
			shown = lab
	var t := OS.get_keycode_string(shown)
	return t if t != "" else "?"


func pad_label(button: int) -> String:
	return tr(PAD_BUTTON_NAMES[button]) if PAD_BUTTON_NAMES.has(button) else tr("Button %d") % button


func all_schemes() -> Array[String]:
	var out: Array[String] = ["kb_left", "kb_right"]
	for i in PAD_COUNT:
		out.append("pad%d" % i)
	return out


func key_name(scheme: String, what: String) -> String:
	if (scheme == "solo" and using_pad) or scheme.begins_with("pad"):
		if what in REBIND_PAD:
			return pad_label(pad_button(what))
		return tr(PAD_NAMES[what])
	if scheme == "solo":
		if what == "move":
			return key_label(primary_key("left")) + "/" + key_label(primary_key("right"))
		return key_label(primary_key(what))
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
	_add_axis(prefix + "_attack", device, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	# 跳、攻击、马灯：按改过的键位（默认 A、X、Y）；副键（马灯的 B）没被别的动作拿去当主键才认
	var taken := {}
	for a in REBIND_PAD:
		taken[pad_button(a)] = a
	for a in REBIND_PAD:
		_add_button(prefix + "_" + a, device, pad_button(a))
		for extra in PAD_EXTRA.get(a, []):
			if not taken.has(extra):
				_add_button(prefix + "_" + a, device, extra)


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
