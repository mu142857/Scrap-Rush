extends SceneTree
## 主角能不能跳 / 飞出关着的闸门（碰撞会话，10-19；游戏设计改了下落手感：顶点悬停、下落变慢、跑跳距离 43 → 54）。
## 一关里每一场遭遇战：开打、门落下 1.5 秒后，主角在左 / 右闸门里侧，用两种打法往门外冲，各 5 秒：
##   贴门：站在门里 30 像素，按住朝门的方向 + 一直按跳（起跳、喷气、喷完滑翔）
##   助跑：从场子另一头跑过来，离门 60 像素时起跳并一直按住
## 每帧看主角是不是到了门外（越过门 2 像素），或者嵌进门里。主角无敌，怪不打。
## 用法：LEVEL=res://scenes/level3.tscn Godot --headless --fixed-fps 120 --log-file <scratchpad>/gj.log --path . -s tools/qa/gate_jump.gd
var LEVEL := ""
var _f := 0
var _lvl_id := 0
var _encs: Array = []
var _i := -1
var _enc: Node
var _t := 0.0
var _try := -1
var _try_t := 0.0
var _held := {}
var _escaped := 0
var _embedded := 0
var _tries := 0
var _jumped := false
## 这一次最高飞到哪（y 最小）、离门最近多少：证明真的跳了、喷了、冲到门上了
var _min_y := INF
var _min_gap := INF

## [门在哪边, 打法]
const TRIES := [["left", "hug"], ["left", "run"], ["right", "hug"], ["right", "run"]]
const TRY_TIME := 5.0


func _initialize() -> void:
	LEVEL = OS.get_environment("LEVEL")


func _physics_process(delta: float) -> bool:
	_f += 1
	if _f == 3:
		root.get_node("Game").set("invincible", true)
		if LEVEL.ends_with("level2.tscn"):
			load("res://scripts/levels/level2.gd").set("tube_landing", true)
		change_scene_to_file(LEVEL)
		return false
	if current_scene == null or get_nodes_in_group("player").is_empty():
		return false
	if _lvl_id == 0:
		_lvl_id = current_scene.get_instance_id()
		if "_leaving" in current_scene:
			current_scene.set("_leaving", true)
		for c in current_scene.get_children():
			if c.has_method("_spawn_wave"):
				_encs.append(c)
		print("GATEJUMP ", LEVEL, " encounters=", _encs.size())
		return false
	if current_scene.get_instance_id() != _lvl_id:
		print("SCENE CHANGED")
		return true
	var p: CharacterBody2D = get_nodes_in_group("player")[0]
	p.set("_invuln", 99.0)
	if _enc == null:
		_i += 1
		if _i >= _encs.size():
			_release_all()
			print("GATEJUMP DONE ", LEVEL.get_file(), " tries=", _tries, " escaped=", _escaped, " embedded=", _embedded)
			return true
		_enc = _encs[_i]
		if OS.get_environment("ONLY") != "" and str(_i) != OS.get_environment("ONLY"):
			_enc = null
			return false
		_t = 0.0
		_try = -1
		return false
	var l: float = _enc.get("left")
	var r: float = _enc.get("right")
	var fl: float = _enc.get("floor_left")
	var fr: float = _enc.get("floor_right")
	if not _enc.get("started"):
		p.global_position = Vector2((l + r) * 0.5, maxf(fl, fr) - 1.0)
		p.velocity = Vector2.ZERO
		return false
	_t += delta
	if _t < 1.5:
		return false
	# 换下一种打法：把人放到起点
	if _try < 0 or _try_t >= TRY_TIME:
		_release_all()
		_try += 1
		_try_t = 0.0
		_jumped = false
		if _try > 0:
			print("    try ", TRIES[_try - 1], " ", _desc(_enc), " highest y=", roundi(_min_y), " closest to gate=", snappedf(_min_gap, 0.1))
		_min_y = INF
		_min_gap = INF
		if _try >= TRIES.size():
			_enc.call("_finish")
			_enc = null
			return false
		var side: String = TRIES[_try][0]
		var how: String = TRIES[_try][1]
		var x: float
		if how == "hug":
			x = l + 30.0 if side == "left" else r - 30.0
		else:
			x = r - 20.0 if side == "left" else l + 20.0
		p.global_position = Vector2(x, _floor_at(x, minf(fl, fr) - 60.0, maxf(fl, fr) + 4.0) - 1.0)
		p.velocity = Vector2.ZERO
		p.set("fuel", 1.0)
		_tries += 1
		return false
	_try_t += delta
	var side2: String = TRIES[_try][0]
	var how2: String = TRIES[_try][1]
	var gx := l if side2 == "left" else r
	_hold("left", side2 == "left")
	_hold("right", side2 == "right")
	if how2 == "hug" or absf(p.global_position.x - gx) < 60.0:
		_jumped = true
	_hold("jump", _jumped)
	_min_y = minf(_min_y, p.global_position.y)
	_min_gap = minf(_min_gap, absf(p.global_position.x - gx))
	var out := p.global_position.x < l - 2.0 if side2 == "left" else p.global_position.x > r + 2.0
	if out:
		_escaped += 1
		print("  ESCAPED ", _desc(_enc), " via ", side2, " gate (", how2, ") at ", p.global_position.round(), " after ", snappedf(_try_t, 0.01), "s")
		_try_t = TRY_TIME
	elif _in_wall(p):
		_embedded += 1
		print("  EMBEDDED ", _desc(_enc), " near ", side2, " gate (", how2, ") at ", p.global_position.round(), " vel ", p.velocity.round(), " t=", snappedf(_try_t, 0.01), " in: ", _what_in(p))
		_try_t = TRY_TIME
	return false


func _floor_at(x: float, top: float, bottom: float) -> float:
	var q := PhysicsRayQueryParameters2D.create(Vector2(x, top), Vector2(x, bottom + 40.0), 1 | 64)
	var hit := root.get_world_2d().direct_space_state.intersect_ray(q) if current_scene == null else (current_scene as Node2D).get_world_2d().direct_space_state.intersect_ray(q)
	return (hit["position"] as Vector2).y if not hit.is_empty() else bottom


func _in_wall(p: CharacterBody2D) -> bool:
	for c in p.get_children():
		if c is CollisionShape2D:
			var q := PhysicsShapeQueryParameters2D.new()
			q.shape = c.shape
			q.transform = c.global_transform
			q.collision_mask = 1
			q.margin = -0.6
			# 单向平台不算：往上跳穿过它时人本来就和它重叠
			for r in p.get_world_2d().direct_space_state.intersect_shape(q, 8):
				if not _one_way_hit(r):
					return true
			return false
	return false


func _one_way_hit(r: Dictionary) -> bool:
	var co := r["collider"] as CollisionObject2D
	if co == null:
		return false
	var o = co.shape_owner_get_owner(co.shape_find_owner(int(r["shape"])))
	return o != null and o.get("one_way_collision") == true


func _what_in(p: CharacterBody2D) -> String:
	var out := []
	for c in p.get_children():
		if c is CollisionShape2D:
			var q := PhysicsShapeQueryParameters2D.new()
			q.shape = c.shape
			q.transform = c.global_transform
			q.collision_mask = 1
			q.margin = -0.6
			for r in p.get_world_2d().direct_space_state.intersect_shape(q, 4):
				var co: Node = r["collider"]
				out.append("%s(%s) at %s" % [co.name, co.get_parent().name if co.get_parent() else "", (co as Node2D).global_position.round() if co is Node2D else ""])
	return ", ".join(out)


func _desc(e: Node) -> String:
	return "[%d..%d floor %d/%d ceil %d]" % [e.get("left"), e.get("right"), e.get("floor_left"), e.get("floor_right"), e.get("ceil_y")]


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
