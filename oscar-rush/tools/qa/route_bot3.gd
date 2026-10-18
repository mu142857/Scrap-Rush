extends SceneTree
## 第三关通关机器人（夜间打磨，碰撞会话）：只用按键，从出生点走到家门口，证明整关走得通、不会卡死。
## 路线：第一排走到最右的洞（3764）爬上去 → 第二排右半段走到 3137 的洞 → 第三排走到 2639 的洞 → 第四排走到家门口。
## 第三关是迷宫：有的排被整墙分成几段（Level3Data 的 seg），只能按洞走。洞里有电线，按住跳往上爬。
## 打架不是这里要测的：开着门的遭遇战里出来的怪直接打死；路上的小怪离得近也打死。主角无敌。
## 用法：Godot --headless --fixed-fps 120 --log-file <scratchpad>/bot3.log --path . -s tools/qa/route_bot3.gd

## ["walk", 目标 x, 地面 y] 走到这一层的 x；["climb", 洞中心 x, 上面一层的地面 y, 洞右边沿 x] 在洞底按住跳爬上去、往右迈出洞口
const ROUTE := [
	["walk", 140.0, 1152.0],
	["walk", 3764.0, 1152.0],
	["climb", 3764.0, 882.0, 3775.0],
	# 第二排在 2900~2916 有一堵整墙，分成两段（Level3Data 的 seg）：这一段只能从 3137 的洞上第三排
	["walk", 3137.0, 882.0],
	["climb", 3137.0, 612.0, 3148.0],
	["walk", 2639.0, 612.0],
	["climb", 2639.0, 342.0, 2650.0],
	["walk", 4420.0, 342.0],
]
var STEP_TIMEOUT := int(OS.get_environment("STEP_TIMEOUT")) * 120 if OS.get_environment("STEP_TIMEOUT") != "" else 120 * 300

var _f := 0
var _lvl_id := 0
var _p: CharacterBody2D
var _encs: Array = []
var _i := 0
var _t := 0
var _held := {}
var _xs: Array[float] = []
var _climbing := false
var _cleared := 0
var _seen := {}


func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 3:
		root.get_node("Game").set("invincible", true)
		change_scene_to_file("res://scenes/level3.tscn")
		return false
	if _lvl_id != 0 and (current_scene == null or current_scene.get_instance_id() != _lvl_id):
		_release_all()
		print("BOT reached next scene: ", current_scene.scene_file_path if current_scene else "(switching)", " at ", snappedf(_f / 120.0, 0.1), "s; encounters started on the way: ", _seen.size(), ", cleared: ", _cleared)
		return true
	if current_scene == null or get_nodes_in_group("player").is_empty():
		return false
	if _lvl_id == 0:
		_lvl_id = current_scene.get_instance_id()
		_p = get_nodes_in_group("player")[0]
		for c in current_scene.get_children():
			if c.has_method("_spawn_wave"):
				_encs.append(c)
		# 调试用：START_STEP=2 START_POS=3764,1150 直接从某一步、某个位置开始
		if OS.get_environment("START_STEP") != "":
			_i = int(OS.get_environment("START_STEP"))
			var v := OS.get_environment("START_POS").split_floats(",")
			_p.global_position = Vector2(v[0], v[1])
		print("BOT start ", _p.global_position.round(), " step ", _i, " encounters in level=", _encs.size())
		return false
	_p.set("_invuln", 99.0)
	_kill()
	_t += 1
	if _t > STEP_TIMEOUT - 120 and _t <= STEP_TIMEOUT and _t % 4 == 0:
		for i in _p.get_slide_collision_count():
			var c := _p.get_slide_collision(i)
			print("    touch ", c.get_collider(), " ", c.get_collider().get_parent().name if c.get_collider() is Node and c.get_collider().get_parent() else "", " n=", c.get_normal().snapped(Vector2(0.01, 0.01)))
	if _t == STEP_TIMEOUT:
		for e in get_nodes_in_group("enemy"):
			var d := (e as Node2D).global_position - _p.global_position
			if absf(d.x) < 30.0 and absf(d.y) < 40.0:
				print("  ENEMY near: ", e.get("mob_name") if e.get("mob_name") else e.get_script().resource_path.get_file(), " at ", (e as Node2D).global_position.round(), " pm=", e.process_mode, " dead=", e.get("dead"), " layer=", e.get("collision_layer"))
		for enc in _encs:
			if is_instance_valid(enc) and enc.get("started") and not enc.get("cleared"):
				print("  OPEN encounter ", enc.get("left"), "..", enc.get("right"), " wave ", enc.get("_wave"), " alive ", (enc.get("_alive") as Array).size(), " queue ", (enc.get("_queue") as Array).size())
	if _t > STEP_TIMEOUT - 120 and _t <= STEP_TIMEOUT and _t % 4 == 0:
		print("  frame pos=", _p.global_position, " vel=", _p.velocity, " floor=", _p.is_on_floor(), " ceil=", _p.is_on_ceiling(), " wall=", _p.is_on_wall(), " jet=", _p.call("is_jetting"), " jump_hold=", _p.get("_jump_hold"), " fuel=", _p.get("fuel"))
	if _t > STEP_TIMEOUT:
		_release_all()
		print("BOT STUCK at step ", _i, " ", ROUTE[_i], " pos ", _p.global_position, " floor=", _p.is_on_floor(), " vel=", _p.velocity, " wall=", _p.is_on_wall(), " ceil=", _p.is_on_ceiling(), " jet=", _p.call("is_jetting"), " held=", _held, " stun=", _p.get("_stun"), " pm=", _p.process_mode)
		for i in _p.get_slide_collision_count():
			var c := _p.get_slide_collision(i)
			print("  touching ", c.get_collider(), " normal ", c.get_normal(), " at ", c.get_position())
		return true
	_drive()
	return false


func _kill() -> void:
	for enc in _encs:
		if is_instance_valid(enc) and enc.get("started") and not enc.get("cleared"):
			_seen[enc.get_instance_id()] = true
			for e in enc.get("_alive"):
				if is_instance_valid(e) and e.get("dead") == false and e.has_method("hurt"):
					e.call("hurt", 9999999.0, Vector2.RIGHT, true)
	for e in get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.get("dead") == false and e.has_method("hurt") and e.process_mode != Node.PROCESS_MODE_DISABLED:
			if (e as Node2D).global_position.distance_to(_p.global_position) < 60.0:
				e.call("hurt", 9999999.0, Vector2.RIGHT, true)
	var n := 0
	for enc in _encs:
		if is_instance_valid(enc) and enc.get("cleared") and _seen.has(enc.get_instance_id()):
			n += 1
	_cleared = n


func _next_step(msg: String) -> void:
	print("BOT ok step ", _i, " ", msg, " at ", _p.global_position.round(), " t=", snappedf(_f / 120.0, 0.1), "s")
	_i += 1
	_t = 0
	_climbing = false
	_xs.clear()
	_release_all()


func _drive() -> void:
	if _i >= ROUTE.size():
		_hold("right", true)
		return
	for enc in _encs:
		if is_instance_valid(enc) and enc.get("started") and not enc.get("cleared"):
			_release_all()
			return
	var step: Array = ROUTE[_i]
	var pos := _p.global_position
	if step[0] == "walk":
		var tx: float = step[1]
		var ty: float = step[2]
		var dx := tx - pos.x
		if absf(dx) < 6.0 and absf(pos.y - ty) < 4.0 and _p.is_on_floor():
			_next_step("walk to x=%d" % int(tx))
			return
		_hold("left", dx < -3.0)
		_hold("right", dx > 3.0)
		_xs.append(pos.x)
		if _xs.size() > 24:
			_xs.pop_front()
		var blocked := absf(dx) > 6.0 and _xs.size() == 24 and absf(_xs[0] - pos.x) < 1.0
		if _p.is_on_floor():
			_hold("jump", blocked and _t % 16 < 8)
		else:
			_hold("jump", blocked)
		return
	# climb：先对准洞中心，按住跳一路爬上去，到了上一层地面以上就往右迈出洞口
	var cx: float = step[1]
	var upper: float = step[2]
	var edge: float = step[3]
	if not _climbing:
		var dx := cx - pos.x
		_hold("left", dx < -1.5)
		_hold("right", dx > 1.5)
		if absf(dx) <= 1.5:
			_climbing = true
		return
	# 已经迈出洞口了：不再按跳，落地就算这一步完成
	if pos.x > edge + 6.0:
		_hold("jump", false)
		_hold("right", absf(pos.y - upper) >= 4.0 or not _p.is_on_floor())
		if absf(pos.y - upper) < 4.0 and _p.is_on_floor():
			_next_step("climb to floor %d" % int(upper))
		return
	if pos.y > upper - 8.0:
		_hold("left", false)
		_hold("right", false)
		_hold("jump", true)
		return
	# 每帧只定一次跳的状态（同一帧先按再松会被当成又按了一次，一直起跳、喷气）
	_hold("jump", pos.x <= edge + 6.0)
	_hold("right", true)
	if pos.x > edge + 6.0 and absf(pos.y - upper) < 4.0 and _p.is_on_floor():
		_next_step("climb to floor %d" % int(upper))


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
