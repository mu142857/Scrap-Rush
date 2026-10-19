extends Node
## 教学关自测（游戏剧情主题讨论会话）。
##   -- --tauto            从头走到尾：每一步按教学关的条件去做（打靶、放灯、拍开关、捡灯、打遭遇战、打精英、按下换武器），
##                         每一步打印一行；走出最后一扇门（换场景）就退出。卡住 20 秒打印位置退出。
##   -- --tauto --tmeasure 量跳高：站在地上按住跳 1.5 秒，提灯、空手各一次，打印最高离地多少（定阁楼高架的高度用）
## 主角无敌。精英出场护盾期间打不动，就隔一会儿再打。

var _lvl: Node
var _p: Player
var _f := 0
var _stuck := 0.0
var _last_step := -1
var _measure := false
var _m_phase := 0
var _m_best := 0.0
var _m_t := 0.0
var _fly_t := 0.0
var _blocked := 0.0
var _hold_t := 0.0
var _was_air := false
var _carry_tried := false


func _ready() -> void:
	_lvl = get_parent()
	_measure = OS.get_cmdline_user_args().has("--tmeasure")


func _act(a: String) -> String:
	return _p.input_prefix + "_" + a


func _release() -> void:
	for a in ["left", "right", "jump", "attack", "crystal", "down"]:
		Input.action_release(_act(a))


func _physics_process(delta: float) -> void:
	if _p == null:
		for n in get_tree().get_nodes_in_group("player"):
			_p = n as Player
		return
	_f += 1
	_p.set("_invuln", 0.5)
	Engine.time_scale = 1.0
	if _measure:
		_tick_measure(delta)
		return
	var step: int = _lvl.get("step")
	var sub: int = _lvl.get("_sub")
	if step != _last_step:
		print("tauto: step %d at frame %d, x=%d" % [step, _f, _p.global_position.x])
		_last_step = step
		_stuck = 0.0
	_stuck += delta
	if _stuck > 20.0:
		print("tauto: STUCK at step %d sub %d, player %s" % [step, sub, _p.global_position.round()])
		get_tree().quit()
		return
	_release()
	var rooms: Array = _lvl.get("_rooms")
	match step:
		0:
			_walk_right(true)
		1:
			for e in _lvl.get("_targets"):
				if is_instance_valid(e) and not e.get("dead"):
					e.call("hurt", 99999.0, Vector2.LEFT, true)
			_walk_right(true)
		2:
			var r: Dictionary = rooms[2]
			if sub < 2:
				_walk_right(false)
				if _p.global_position.x > r["ox"] + 120:
					Input.action_release(_act("right"))
			elif sub == 2:
				# 先提着灯试飞一次：应该飞不过去（被雪花弹回来），飞过去了就说明雪花太窄
				if not _carry_tried:
					_try_fly(r, true)
				elif _f % 20 == 0:
					Input.action_press(_act("crystal"))
			elif sub == 3:
				_try_fly(r, false)
			elif sub == 4:
				var c: Node2D = _lvl.get("_crystal")
				_p.global_position = c.global_position + Vector2(-6, -2)
				_p.velocity = Vector2.ZERO
				if _f % 20 == 0:
					Input.action_press(_act("crystal"))
			else:
				_walk_right(true)
		3, 4:
			for e in get_tree().get_nodes_in_group("enemy"):
				if e.has_method("in_intro") and e.call("in_intro"):
					continue
				if not e.get("dead") and _f % 30 == 0:
					e.call("hurt", 99999.0, Vector2.LEFT, true)
			var pk = _lvl.get("_pickup")
			if step == 4 and sub == 2 and is_instance_valid(pk):
				var dx: float = (pk as Node2D).global_position.x - _p.global_position.x
				if absf(dx) > 4.0:
					Input.action_press(_act("right" if dx > 0 else "left"))
				elif _f % 20 == 0 and _p.is_on_floor():
					Input.action_press(_act("down"))
			else:
				_walk_right(true)
		_:
			_walk_right(true)


## 从雪花左边跑起来，到雪花边上 10 像素起跳，一直按住跳和右
func _try_fly(r: Dictionary, carrying: bool) -> void:
	var edge: float = r["ox"] + _lvl.get("GAP_X")
	if _fly_t == 0.0:
		_p.global_position = Vector2(r["ox"] + 20, r["floor"] - 2)
		_p.velocity = Vector2.ZERO
		_was_air = false
	_fly_t += 1.0 / 60.0
	if _fly_t > 1.6:
		Input.action_press(_act("right"))
		if _p.global_position.x > edge - 10 or not _p.is_on_floor():
			Input.action_press(_act("jump"))
	if _fly_t > 1.6 and not _p.is_on_floor():
		_was_air = true
	if _was_air and _p.is_on_floor():
		var crossed: bool = _p.global_position.x > edge + float(_lvl.get("GAP"))
		print("tauto: flight carrying=%s -> %s (x=%d)" % [carrying, "CROSSED" if crossed else "bounced back", _p.global_position.x])
		_fly_t = 0.0
		_was_air = false
		if carrying:
			_carry_tried = true


func _walk_right(jump_when_blocked: bool) -> void:
	Input.action_press(_act("right"))
	if not jump_when_blocked:
		return
	# 被挡住（在地上走不动）就起跳，并且一直按住跳 1.2 秒（用上火箭靴），像真人一样
	if _p.is_on_floor() and absf(_p.velocity.x) < 5.0:
		_blocked += 1.0 / 60.0
	else:
		_blocked = 0.0
	if _blocked > 0.2:
		_hold_t = 1.2
		_blocked = 0.0
	if _hold_t > 0.0:
		_hold_t -= 1.0 / 60.0
		Input.action_press(_act("jump"))


func _tick_measure(delta: float) -> void:
	_m_t += delta
	var floor_y := 237.0
	match _m_phase:
		0:
			_p.global_position = Vector2(150, floor_y - 2)
			_m_phase = 1
			_m_t = 0.0
			_m_best = 0.0
		1:
			if _m_t > 2.0:
				Input.action_press(_act("jump"))
				_m_best = maxf(_m_best, floor_y - _p.global_position.y)
			if _m_t > 4.0:
				Input.action_release(_act("jump"))
				print("tmeasure: carrying=%s  max rise %.1f px" % [_p.crystal != null, _m_best])
				_m_phase = 2
				_m_t = 0.0
		2:
			# 量飞多远：在客厅地面上跑起来，起跳后一直按住跳，落回地面时离起跳点多远
			if _m_t < 0.05:
				_p.global_position = Vector2(456 + 40, floor_y - 2)
				_p.velocity = Vector2.ZERO
				_m_best = 0.0
			Input.action_press(_act("right"))
			if _m_t > 2.0 and _m_t < 2.5 and _p.global_position.x > 456 + 80 and _m_best == 0.0:
				_m_best = _p.global_position.x
				Input.action_press(_act("jump"))
			if _m_best > 0.0:
				Input.action_press(_act("jump"))
				if _m_t > 2.7 and _p.is_on_floor():
					Input.action_release(_act("jump"))
					Input.action_release(_act("right"))
					print("tmeasure: carrying=%s  flight distance %.1f px" % [_p.crystal != null, _p.global_position.x - _m_best])
					if _p.crystal != null:
						_p.crystal.drop()
						_m_phase = 0
					else:
						get_tree().quit()
			elif _m_t < 2.0:
				Input.action_release(_act("right"))


func _exit_tree() -> void:
	if not _measure:
		print("tauto: left the tutorial at frame %d (scene changed)" % _f)
	get_tree().quit()
