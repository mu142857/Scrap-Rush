extends SceneTree
## 快速下落、单向平台往下跳会不会穿地（碰撞会话，10-19；游戏设计加了"空中按住下 = 快速下落"，最快 460 像素/秒）。
## 两种情况，关卡里随机挑点：
##   drop：站在一块单向平台上，按"下"跳下去并一直按着（快速下落），看落在哪
##   dive：从某个点上方 40～220 像素的空中开始，一直按着"下"，看落在哪
## 每次都先用射线算好"应该落在哪"（往下第一块地面或平台的顶面；drop 时跳过脚下那块），
## 人停稳后比一比：落低了 = 穿过了地或平台；嵌进墙里、出了地图都算错。
## 用法：LEVEL=res://scenes/level3.tscn BOUNDS=0,0,4994,1200 TRIALS=150 SEED=1 Godot --headless --fixed-fps 120 --log-file <scratchpad>/fall.log --path . -s tools/qa/fall_check.gd
var LEVEL := ""
var _bounds := Rect2()
var TRIALS := 150
var _f := 0
var _lvl_id := 0
var _p: CharacterBody2D
var _trial := 0
var _phase := 0
var _t := 0
var _kind := ""
var _expect := 0.0
var _start := Vector2.ZERO
var _held := {}
var _stats := {"drop": [0, 0], "dive": [0, 0]}
var _bad := 0
var _skipped := 0
var _settle := 0
## 关卡载入后先等 3 秒再开始：第二关开场有"胶囊砸穿天花板"的落地演出，会把主角瞬移到 LANDING (250, 540)，
## 赶在演出里开测会被当成"穿地"（游戏设计 10-19 报的 seed 1、2 两个 bad 都是这个）
const WARMUP := 120 * 3
var _ready_f := 0


func _initialize() -> void:
	LEVEL = OS.get_environment("LEVEL")
	var v := OS.get_environment("BOUNDS").split_floats(",")
	_bounds = Rect2(v[0], v[1], v[2], v[3])
	if OS.get_environment("TRIALS") != "":
		TRIALS = int(OS.get_environment("TRIALS"))
	seed(int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 1)


func _physics_process(_d: float) -> bool:
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
		_p = get_nodes_in_group("player")[0]
		_ready_f = _f
		for e in get_nodes_in_group("enemy"):
			(e as Node).process_mode = Node.PROCESS_MODE_DISABLED
		# 遭遇战不让开打（不然门落下、怪出来）
		for c in current_scene.get_children():
			if c.has_method("_spawn_wave"):
				c.process_mode = Node.PROCESS_MODE_DISABLED
		return false
	if current_scene.get_instance_id() != _lvl_id:
		print("SCENE CHANGED (", _kind, " from ", _start.round(), ")")
		return true
	_p.set("_invuln", 99.0)
	if _f - _ready_f < WARMUP:
		return false
	match _phase:
		0:
			if _trial >= TRIALS:
				_release_all()
				print("FALL DONE ", LEVEL.get_file(), " drop ok/n=", _stats["drop"][0], "/", _stats["drop"][1],
						" dive ok/n=", _stats["dive"][0], "/", _stats["dive"][1], " bad=", _bad, " skipped=", _skipped)
				return true
			_release_all()
			if _setup():
				_trial += 1
				_phase = 1
				_t = 0
				_settle = 0
			else:
				_skipped += 1
		1:
			_t += 1
			if _kind == "drop":
				# 站稳 6 帧后按"下"，一直按着
				if _t == 6:
					_hold("down", true)
			elif _t == 1:
				_hold("down", true)
			if _t > 10 and _p.is_on_floor() and absf(_p.velocity.y) < 1.0:
				_settle += 1
			else:
				_settle = 0
			if _settle >= 4 or _t > 120 * 4:
				_judge()
				_phase = 0
	return false


func _space() -> PhysicsDirectSpaceState2D:
	return (current_scene as Node2D).get_world_2d().direct_space_state


## 找一个起点；成功返回 true
func _setup() -> bool:
	_kind = "drop" if randf() < 0.5 else "dive"
	for _try in 60:
		var x := randf_range(_bounds.position.x + 8, _bounds.end.x - 8)
		var y := randf_range(_bounds.position.y + 8, _bounds.end.y - 8)
		if _solid(Vector2(x, y), 1 | 64):
			continue
		var hit := _ray(Vector2(x, y), Vector2(x, _bounds.end.y + 40), 1 | 64, [])
		if hit.is_empty():
			continue
		var top: float = (hit["position"] as Vector2).y
		if _kind == "drop":
			if not _is_one_way(hit):
				continue
			var under := _ray(Vector2(x, top + 0.5), Vector2(x, _bounds.end.y + 40), 1 | 64, [hit["collider"]])
			if under.is_empty():
				continue
			_expect = (under["position"] as Vector2).y
			_start = Vector2(x, top - 0.5)
		else:
			var h := randf_range(40.0, 220.0)
			var sy := top - h
			# 起点到落点之间要是空的（单向平台从上往下落会接住，算"应该落的地方"）
			if sy < _bounds.position.y + 4 or _solid(Vector2(x, sy), 1 | 64) or _solid(Vector2(x, sy - 20), 1):
				continue
			var first := _ray(Vector2(x, sy), Vector2(x, top + 1), 1 | 64, [])
			_expect = (first["position"] as Vector2).y if not first.is_empty() else top
			# 起点离第一块平台至少 24 像素：太近的话刚按"下"人就落到平台上了，
			# 落地那一帧按"下"本来就是"从单向平台往下跳"（正常玩法），不算快速下落穿平台
			# （10-19 监督转来的第二关 (96, 221) 多掉 25 像素就是这个：起点只比 224 的平台高 3 像素）
			if _expect - sy < 24.0:
				continue
			_start = Vector2(x, sy)
		# 人站得下：起点不嵌墙
		_p.global_position = _start
		_p.velocity = Vector2.ZERO
		if _in_wall():
			continue
		_p.set("fuel", 1.0)
		return true
	return false


func _judge() -> void:
	_release_all()
	var pos := _p.global_position
	_stats[_kind][1] += 1
	var reason := ""
	if not _bounds.grow(4).has_point(pos):
		reason = "out of map"
	elif _in_wall():
		reason = "embedded"
	elif pos.y > _expect + 3.0:
		reason = "fell through (landed %d px lower than the first surface)" % int(pos.y - _expect)
	elif not _p.is_on_floor():
		reason = "not standing after 4 s"
	if reason == "":
		_stats[_kind][0] += 1
		return
	# 落高了（比预想的高）：多半是落在半路的斜坡、台边上，不算问题；只报落低、嵌墙、出图
	_bad += 1
	if _bad <= 12:
		print("  BAD ", _kind, " from ", _start.round(), " expected y=", roundi(_expect), " got ", pos.round(), ": ", reason)


func _ray(a: Vector2, b: Vector2, mask: int, exclude: Array) -> Dictionary:
	var q := PhysicsRayQueryParameters2D.create(a, b, mask)
	var ex: Array[RID] = []
	for o in exclude:
		ex.append((o as CollisionObject2D).get_rid())
	q.exclude = ex
	return _space().intersect_ray(q)


func _solid(p: Vector2, mask: int) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = p
	q.collision_mask = mask
	return not _space().intersect_point(q, 1).is_empty()


func _is_one_way(hit: Dictionary) -> bool:
	var co := hit["collider"] as CollisionObject2D
	if co == null:
		return false
	var o = co.shape_owner_get_owner(co.shape_find_owner(int(hit["shape"])))
	return o != null and o.get("one_way_collision") == true


func _in_wall() -> bool:
	for c in _p.get_children():
		if c is CollisionShape2D:
			var q := PhysicsShapeQueryParameters2D.new()
			q.shape = c.shape
			q.transform = c.global_transform
			q.collision_mask = 1
			q.margin = -0.6
			# 单向平台不算：人可以从下面穿上来
			for r in _space().intersect_shape(q, 8):
				var co := r["collider"] as CollisionObject2D
				var o = co.shape_owner_get_owner(co.shape_find_owner(int(r["shape"]))) if co else null
				if o == null or o.get("one_way_collision") != true:
					return true
			return false
	return false


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
