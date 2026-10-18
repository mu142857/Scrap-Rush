extends SceneTree
## 马灯的地形压力测试（夜间打磨，碰撞会话）：把马灯放在关卡里随机的地面上，模拟被怪撞（take_hit，随机左右）几下，
## 3 秒后看它：
##   out      跑出关卡范围（掉进坑、掉出地图）→ 这盏灯就找不回来了
##   in_wall  嵌在实心地形里
##   floating 没落地（卡在半空的什么东西上）
## 用法（工程目录下）：
##   LEVEL=res://scenes/level2.tscn BOUNDS=0,0,3700,600 TRIALS=150 SEED=1 \
##     Godot --headless --fixed-fps 120 --log-file <scratchpad>/lantern.log --path . -s tools/qa/lantern_fuzz.gd

const SETTLE := 360

var LEVEL := ""
var TRIALS := 100
var _rng := RandomNumberGenerator.new()
var _bounds := Rect2()
var _f := 0
var _lvl: Node
var _c: CharacterBody2D
var _p: Node2D
var _trial := -1
var _t := 0
var _hits := 0
var _start := Vector2.ZERO
var _issues := {}


func _initialize() -> void:
	LEVEL = OS.get_environment("LEVEL")
	TRIALS = int(OS.get_environment("TRIALS")) if OS.get_environment("TRIALS") != "" else 100
	_rng.seed = int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 1
	var v := OS.get_environment("BOUNDS").split_floats(",")
	_bounds = Rect2(v[0], v[1], v[2], v[3])


func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 3:
		root.get_node("Game").set("invincible", true)
		if LEVEL.ends_with("level2.tscn"):
			load("res://scripts/levels/level2.gd").set("tube_landing", true)
		change_scene_to_file(LEVEL)
		return false
	if current_scene == null or get_nodes_in_group("player").is_empty() or get_nodes_in_group("crystal").is_empty():
		return false
	if _lvl == null:
		_lvl = current_scene
		if "_leaving" in _lvl:
			_lvl.set("_leaving", true)
		for n in get_nodes_in_group("enemy"):
			n.process_mode = Node.PROCESS_MODE_DISABLED
			n.visible = false
			if n is CollisionObject2D:
				(n as CollisionObject2D).collision_layer = 0
		for c in _lvl.get_children():
			if c.has_method("_spawn_wave"):
				c.process_mode = Node.PROCESS_MODE_DISABLED
		_p = get_nodes_in_group("player")[0]
		_c = get_nodes_in_group("crystal")[0]
		if _c.get("carrier") != null:
			_c.call("drop")
		_next()
		return false
	if current_scene != _lvl:
		print("SCENE CHANGED")
		_report()
		return true
	# 主角挪到远处，免得把灯捡起来
	_p.global_position = Vector2(_bounds.position.x + 4, _bounds.position.y + 4)
	_p.velocity = Vector2.ZERO
	_t += 1
	if _hits < 3 and _t % 40 == 0:
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		_c.set("_invuln", 0.0)
		_c.call("take_hit", _c.global_position + Vector2(-side * 10, 0), 0.0)
		_hits += 1
	if not _bounds.grow(8).has_point(_c.global_position):
		_add("out", _c.global_position)
		_next()
		return false
	if _t >= SETTLE:
		if _embedded():
			_add("in_wall", _c.global_position)
		elif not _c.is_on_floor():
			_add("floating", _c.global_position)
		_next()
		if _trial >= TRIALS:
			_report()
			return true
	return false


func _next() -> void:
	_trial += 1
	_t = 0
	_hits = 0
	var space := _c.get_world_2d().direct_space_state
	for attempt in 80:
		var x := _rng.randf_range(_bounds.position.x + 8, _bounds.end.x - 8)
		var y := _rng.randf_range(_bounds.position.y + 8, _bounds.end.y - 8)
		var pq := PhysicsPointQueryParameters2D.new()
		pq.position = Vector2(x, y)
		pq.collision_mask = 1
		if not space.intersect_point(pq, 1).is_empty():
			continue
		var q := PhysicsRayQueryParameters2D.create(Vector2(x, y), Vector2(x, _bounds.end.y + 40), _c.collision_mask)
		var hit := space.intersect_ray(q)
		if hit.is_empty() or hit["normal"].y > -0.7:
			continue
		_start = hit["position"] - Vector2(0, 1)
		_c.global_position = _start
		_c.velocity = Vector2.ZERO
		_c.reset_physics_interpolation()
		return


func _embedded() -> bool:
	for ch in _c.get_children():
		if ch is CollisionShape2D:
			var q := PhysicsShapeQueryParameters2D.new()
			q.shape = ch.shape
			q.transform = ch.global_transform
			q.collision_mask = 1
			q.margin = -0.6
			return not _c.get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()
	return false


func _add(what: String, pos: Vector2) -> void:
	var key := "%s|%d,%d" % [what, int(_start.x / 16) * 16, int(_start.y / 16) * 16]
	if not _issues.has(key):
		_issues[key] = {"what": what, "pos": pos.round(), "start": _start.round(), "n": 0}
	_issues[key]["n"] += 1


func _report() -> void:
	var counts := {}
	for k in _issues:
		counts[_issues[k]["what"]] = counts.get(_issues[k]["what"], 0) + 1
	print("LANTERN ", LEVEL, " trials=", _trial, " issues=", counts)
	var keys := _issues.keys()
	keys.sort()
	for k in keys:
		var it: Dictionary = _issues[k]
		print("  ", it["what"], " at ", it["pos"], " (dropped ", it["start"], ") x", it["n"])
