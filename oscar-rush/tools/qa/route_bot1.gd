extends SceneTree
## 第一关通关机器人（夜间打磨，碰撞会话）：只用按键（左右、跳、下），沿设计路线从出生点走到出口，
## 证明整关走得通、六场遭遇战都会触发并能打完、不会卡死。
## 打架不是这里要测的：遭遇战里出来的怪直接打死；主角无敌。
## 路线：上层往右 → 右端跳下 → 中层往左 → 左端跳下 → 底层往右（钢琴）→ 上柱子、上桥（压路机）→ 右边跳下 → 出口。
## 用法：Godot --headless --fixed-fps 120 --log-file <scratchpad>/bot1.log --path . -s tools/qa/route_bot1.gd

## [目标 x, 目标脚底 y, 说明]。走到目标 x 附近、而且在那一层（y 差不多）就算到了
const ROUTE := [
	[985.0, 113.0, "上层右端的灰铁台"],
	[1000.0, 208.0, "跳下到中层右端"],
	[60.0, 208.0, "中层走到左端缺口边上"],
	[20.0, 406.0, "跳下到底层"],
	[400.0, 414.0, "底层往右（钢琴那场）"],
	[436.0, 354.0, "左边柱子顶"],
	[620.0, 343.0, "桥上（压路机那场）"],
	[820.0, 354.0, "右边柱子顶"],
	[990.0, 414.0, "出口"],
]
const STEP_TIMEOUT := 120 * 60

var _f := 0
var _lvl: Node
var _lvl_id := 0
var _p: CharacterBody2D
var _i := 0
var _t := 0
var _held := {}
var _cleared := 0
var _started := 0
var _encs: Array = []
## 最近 24 帧的 x：按着方向却几乎没动 = 被挡住了（主角贴墙时会先把横向速度清零，is_on_wall 读不到）
var _xs: Array[float] = []


func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 3:
		root.get_node("Game").set("invincible", true)
		change_scene_to_file("res://scenes/test_level.tscn")
		return false
	# 换场景的判断要放在最前面：旧关卡释放以后 _lvl 和 null 比较会当成相等
	if _lvl_id != 0 and (current_scene == null or current_scene.get_instance_id() != _lvl_id):
		_release_all()
		print("BOT reached next scene: ", current_scene.scene_file_path if current_scene else "(switching)", " at ", snappedf(_f / 120.0, 0.1), "s; encounters cleared before leaving: ", _cleared, "/6")
		return true
	if current_scene == null:
		return false
	if _lvl_id == 0:
		if get_nodes_in_group("player").is_empty():
			return false
		_lvl = current_scene
		_lvl_id = current_scene.get_instance_id()
		_p = get_nodes_in_group("player")[0]
		for c in _lvl.get_children():
			if c.has_method("_spawn_wave"):
				_encs.append(c)
		print("BOT start ", _p.global_position.round(), " encounters=", _encs.size())
		return false
	_p.set("_invuln", 99.0)
	# 遭遇战里的怪：出来就打死（这里不测打架）
	for enc in _encs:
		if is_instance_valid(enc) and enc.get("started") and not enc.get("cleared"):
			for e in enc.get("_alive"):
				if is_instance_valid(e) and e.get("dead") == false and e.has_method("hurt"):
					e.call("hurt", 9999999.0, Vector2.RIGHT, true)
	_t += 1
	if _t > STEP_TIMEOUT:
		_release_all()
		print("BOT STUCK at step ", _i, " (", ROUTE[_i][2], ") pos ", _p.global_position.round(), " encounters started ", _count("started"), " cleared ", _count("cleared"))
		for e in _encs:
			if is_instance_valid(e) and e.get("started") and not e.get("cleared"):
				print("  open encounter [", e.get("left"), "..", e.get("right"), "] wave=", e.get("_wave"), "/", (e.get("waves") as Array).size(), " queue=", (e.get("_queue") as Array).size())
				for m in e.get("_alive"):
					if is_instance_valid(m):
						print("    alive: ", m.get_script().resource_path.get_file(), " at ", (m as Node2D).global_position.round(), " dead=", m.get("dead"), " hp=", m.get("hp"), " pm=", m.process_mode, " intro=", m.call("in_intro") if m.has_method("in_intro") else "-")
					else:
						print("    alive: <freed>")
		return true
	_drive()
	return false


func _count(what: String) -> int:
	var n := 0
	for e in _encs:
		if is_instance_valid(e) and e.get(what):
			n += 1
	return n


func _drive() -> void:
	if _i >= ROUTE.size():
		_cleared = _count("cleared")
		_hold("right", true)
		return
	var tx: float = ROUTE[_i][0]
	var ty: float = ROUTE[_i][1]
	var pos := _p.global_position
	var dx := tx - pos.x
	var on_level := absf(pos.y - ty) < 4.0 and _p.is_on_floor()
	if absf(dx) < 6.0 and on_level:
		print("BOT ok step ", _i, " ", ROUTE[_i][2], " at ", pos.round(), " t=", snappedf(_f / 120.0, 0.1), "s")
		_i += 1
		_t = 0
		_release_all()
		return
	# 遭遇战关着门、还在打：原地等
	for e in _encs:
		if is_instance_valid(e) and e.get("started") and not e.get("cleared"):
			_release_all()
			return
	_hold("left", dx < -3.0)
	_hold("right", dx > 3.0)
	# 目标比脚高：跳 + 一直按着飞；顶着墙也跳
	var need_up := ty < pos.y - 4.0
	_xs.append(pos.x)
	if _xs.size() > 24:
		_xs.pop_front()
	var blocked := absf(dx) > 6.0 and _xs.size() == 24 and absf(_xs[0] - pos.x) < 1.0
	# 跳是"按下那一帧"才起跳：站在地上就一下一下地点，空中一直按着飞
	if _p.is_on_floor() and (need_up or blocked):
		_hold("jump", _t % 16 < 8)
	else:
		_hold("jump", (need_up or blocked) and not _p.is_on_floor())


func _hold(a: String, on: bool) -> void:
	var act := "solo_" + a
	if on and not _held.get(a, false):
		Input.action_press(act)
	elif not on and _held.get(a, false):
		Input.action_release(act)
	_held[a] = on


func _release_all() -> void:
	for a in _held.keys():
		_hold(a, false)
