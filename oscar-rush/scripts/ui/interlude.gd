class_name Interlude
extends Prologue
## 幕间小电影（2026-10-19 作者："每一关结束，要不要搞一个像开头一样的小电影？短一点都可以"）。
## 用序章（prologue.gd）那一套胶片：齿孔带、棕褐色、闪烁划痕、放映机的"咔"，只是换几格画面、停得短。
##   boss1  打完第一关 Boss、进商店前（约 7 秒）：锅炉房 → 第二关放胶片盘的机房  "锅炉熄了。再往上走，电话还在响。"
##   boss2  打完第二关 Boss、进商店前（约 7 秒）：放胶片盘的机房 → 第三关的电视墙  "胶片烧完了。再往里，一整面墙的电视还亮着。"
##   finale 结局"剧终"之后、结算之前：整盘带子倒回去，Boss3 的屋子、电视墙、机房、锅炉房一格格飞快闪回，
##          最后停在家（门廊的灯亮着）"门廊的灯，一直亮着。"——和序章最后一句"去看看门廊的灯还亮不亮"首尾呼应，
##          不重复结局里"老电视开机"的那一下
## 任意键 = 下一格，Esc / 手柄 Start = 整段跳过（只跳过这段，不回主菜单）。"继续游戏"从下一关开头接着打时不经过这里。
## 用法：要去 X 的地方改成去 Interlude.route(种类, X)：有这一段就返回幕间场景（放完再去 X），没有就原样返回 X。

const SCENE := "res://scenes/interlude.tscn"
## Boss 房的场景 → 幕间种类
const BY_SCENE := {
	"res://scenes/boss1.tscn": "boss1",
	"res://scenes/boss2.tscn": "boss2",
}
const KINDS := {
	"boss1": {"roll": 0.6, "shots": [
		{"kind": "junk", "gain": 2.3, "caption": "", "hold": 1.6},
		{"kind": "reels", "gain": 1.5, "caption": "The boilers are cold. Up ahead, phones still ring.", "hold": 3.2},
	]},
	"boss2": {"roll": 0.6, "shots": [
		{"kind": "reels", "gain": 1.5, "caption": "", "hold": 1.6},
		{"kind": "wall", "gain": 1.15, "caption": "The film burned out. Past it, a wall of TVs, still on.", "hold": 3.2},
	]},
	"finale": {"roll": 0.22, "rewind": true, "shots": [
		{"kind": "tv", "gain": 1.25, "caption": "", "hold": 0.35},
		{"kind": "wall", "gain": 1.15, "caption": "", "hold": 0.3},
		{"kind": "reels", "gain": 1.5, "caption": "", "hold": 0.3},
		{"kind": "junk", "gain": 2.3, "caption": "", "hold": 0.3},
		{"kind": "home", "gain": 1.0, "caption": "The porch light was on the whole time.", "hold": 4.6},
	]},
}

## 放哪一段、放完去哪（route 设）
static var kind := "boss1"
static var target := "res://scenes/title.tscn"


## 要去 to 的时候改走这个：from 是 Boss 房的场景路径或者种类名（"finale"）
static func route(from: String, to: String) -> String:
	var k: String = BY_SCENE.get(from, from)
	if not KINDS.has(k):
		return to
	kind = k
	target = to
	return SCENE


func _ready() -> void:
	# 自测：直接开这个场景时 -- --ikind=boss1 / boss2 / finale 选一段
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ikind="):
			kind = a.trim_prefix("--ikind=")
	var d: Dictionary = KINDS.get(kind, KINDS["boss1"])
	shots = d["shots"]
	roll_time = d["roll"]
	super._ready()
	for n in ["l3_mid_0", "l3_screens_0"]:
		_tex[n] = load("res://art/levels/%s.png" % n)
	# 不放 3、2、1 片头：直接从放映机灯亮那一下开始
	_t = T_LEADER + LEADER_NUM * 3.0 - 0.01
	_hint.text = tr("Any key: next    Esc: skip")


func _hold_len() -> float:
	if _shot < 0 or _shot >= shots.size():
		return HOLD
	return float(shots[_shot].get("hold", HOLD))


func _process(delta: float) -> void:
	super._process(delta)
	# 倒带那段：每跳一格加一声快速的"嗒"，画面上一个 << 角标
	if KINDS.get(kind, {}).get("rewind", false):
		_rewind_fx()


var _last_rw := -1


func _rewind_fx() -> void:
	if _shot != _last_rw and _shot >= 0:
		_last_rw = _shot
		if _shot < shots.size() - 1:
			Game.sfx("hdd_click", -6.0, 1.6)
		else:
			Game.sfx("tvclick", -4.0, 0.5)     # 倒到头：停在家
	_top.queue_redraw()


func _draw_top() -> void:
	super._draw_top()
	if KINDS.get(kind, {}).get("rewind", false) and _shot < shots.size() - 1 and _phase != "end":
		# 右上角一个一闪一闪的 <<（在上面的齿孔带下面一点，不碰跳过提示：提示靠右在 y 18，这个放左上）
		if int(_t * 6.0) % 2 == 0:
			var x := 14.0
			var y := BAND + 6.0
			for k in 2:
				for i in 4:
					_top.draw_rect(Rect2(x + k * 7 + i, y + 3 - i, 1, i * 2 + 1), Color(1.0, 0.95, 0.85, 0.8))


func _input(event: InputEvent) -> void:
	if _done:
		return
	var is_btn := event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton \
			or event is InputEventScreenTouch
	if not is_btn:
		return
	get_viewport().set_input_as_handled()
	if not event.is_pressed() or event.is_echo() or _t < 0.2:
		return
	var skip_all: bool = (event is InputEventKey and event.keycode == KEY_ESCAPE) \
			or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START)
	if skip_all:
		_start_end()          # 幕间里 Esc 只是跳过这一段，照常往下走
	else:
		_next()


func _finish() -> void:
	_done = true
	print("interlude %s: done at %.1fs -> %s" % [kind, _t, target])
	var tree := get_tree()
	Game.flash(Color.BLACK, 1.0, 60.0)
	tree.scene_changed.connect(func() -> void: Game.flash(Color.BLACK, 1.0, 1.0), CONNECT_ONE_SHOT)
	tree.change_scene_to_file.call_deferred(target)
