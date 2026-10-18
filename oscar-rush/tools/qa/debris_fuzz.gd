extends SceneTree
## 击杀碎片和溅射会不会卡进墙、浮在半空、掉出地图、删不掉（夜间打磨，碰撞会话，10-18）。
## 在关卡里随机挑地面上的点（一半挑贴着墙、站在台子边上的点，怪最常死在那儿），
## 照小怪被打死那样调 HitFx.kill（碎铁 + 机油 / 血溅），再调一次精英的 EliteFx.scrap_burst，
## 等它们落定以后看每一块碎片、每一滴溅最后停在哪儿：
##   embedded = 停在实心墙 / 地里面；floating = 停在半空（脚下 3 像素内没东西）；out = 出了关卡范围；
##   leak = 该删的时候还在（碎片超过 3 秒、溅斑超过 7 秒）。
## 用法：LEVEL=res://scenes/level3.tscn BOUNDS=0,0,4994,1200 TRIALS=80 SEED=1 Godot --headless --fixed-fps 120 --log-file <scratchpad>/debris.log --path . -s tools/qa/debris_fuzz.gd
var LEVEL := ""
var _bounds := Rect2()
var TRIALS := 60
var _f := 0
var _lvl: Node
var _trial := 0
var _t := 0
var _HF: GDScript
var _EF: GDScript
var _seen := {}
var _stats := {}
var _examples := {}
var _dots_checked := 0
var _drain := 0
var _dot_seen := {}


func _initialize() -> void:
	LEVEL = OS.get_environment("LEVEL")
	var v := OS.get_environment("BOUNDS").split_floats(",")
	_bounds = Rect2(v[0], v[1], v[2], v[3])
	if OS.get_environment("TRIALS") != "":
		TRIALS = int(OS.get_environment("TRIALS"))
	seed(int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 1)
	for k in ["hit_chunk", "elite_chunk", "dot"]:
		_stats[k] = {"n": 0, "embedded": 0, "floating": 0, "out": 0, "leak": 0, "fell": 0}


func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 3:
		if LEVEL.ends_with("level2.tscn"):
			load("res://scripts/levels/level2.gd").set("tube_landing", true)
		change_scene_to_file(LEVEL)
		return false
	if current_scene == null or get_nodes_in_group("player").is_empty():
		return false
	if _lvl == null:
		_lvl = current_scene
		_HF = load("res://scripts/combat/hit_fx.gd")
		_EF = load("res://scripts/enemies/elite_fx.gd")
		root.get_node("Game").set("invincible", true)
		# 怪别来打扰：关卡里原有的怪全部停住
		for e in get_nodes_in_group("enemy"):
			(e as Node).process_mode = Node.PROCESS_MODE_DISABLED
		return false
	_t += 1
	_watch()
	if _trial < TRIALS:
		# 每 0.25 秒一场击杀
		if _t % 30 == 1:
			_kill_somewhere()
			_trial += 1
		return false
	# 都打完了：等 8 秒，让该删的都删掉，再看还剩什么
	_drain += 1
	if _drain < 120 * 8:
		return false
	_report()
	return true


func _space() -> PhysicsDirectSpaceState2D:
	return (_lvl as Node2D).get_world_2d().direct_space_state if _lvl is Node2D else root.get_world_2d().direct_space_state


func _solid_at(p: Vector2) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = p
	q.collision_mask = 1
	return not _space().intersect_point(q, 1).is_empty()


## 往下找地（单向平台也算）
func _floor_below(p: Vector2, depth: float) -> float:
	var q := PhysicsRayQueryParameters2D.create(p, p + Vector2(0, depth), 1 | 64)
	q.hit_from_inside = false
	var hit := _space().intersect_ray(q)
	return (hit["position"] as Vector2).y if not hit.is_empty() else INF


func _kill_somewhere() -> void:
	for _try in 200:
		var p := Vector2(randf_range(_bounds.position.x + 4, _bounds.end.x - 4), randf_range(_bounds.position.y + 4, _bounds.end.y - 4))
		if _solid_at(p):
			continue
		var fy := _floor_below(p, 600.0)
		if fy == INF:
			continue
		var foot := Vector2(p.x, fy - 0.5)
		var dir := Vector2(1.0 if randf() < 0.5 else -1.0, randf_range(-0.4, 0.2))
		# 一半挑贴着墙或站在台边的点：往墙那边、往台外那边打
		if randf() < 0.5:
			var near := _near_edge(foot)
			if near == 0.0:
				continue
			dir.x = near
		var body := Node2D.new()
		body.global_position = foot
		_lvl.add_child(body)
		var hit_at := foot + Vector2(0, -8)
		_HF.call("kill", _lvl, body, hit_at, dir, randf())
		if randf() < 0.5:
			_EF.call("scrap_burst", _lvl, Rect2(foot + Vector2(-8, -16), Vector2(16, 16)), 8)
		body.queue_free()
		return


## 往左右 40 像素内有墙或台边：返回那个方向（-1 / 1），没有返回 0
func _near_edge(foot: Vector2) -> float:
	for s in [-1.0, 1.0]:
		for dx in range(4, 44, 4):
			var x: float = foot.x + s * dx
			if _solid_at(Vector2(x, foot.y - 6.0)):
				return s
			if _floor_below(Vector2(x, foot.y - 2.0), 12.0) == INF:
				return s
	return 0.0


func _watch() -> void:
	for c in _lvl.get_children():
		if c.get("ground_y") != null and c.get("_bounces") != null:
			# HitFx.Chunk（小怪碎铁、蒸汽锤碎石）：弹两下停住，或者快到寿命还在飞
			var id := c.get_instance_id()
			if _seen.has(id):
				if _t - int(_seen[id]) > 120 * 3:
					_seen[id] = 1 << 40
					_bump("hit_chunk", "leak", (c as Node2D).global_position)
				continue
			var t: float = c.get("_t")
			if int(c.get("_bounces")) >= 2:
				_seen[id] = _t
				_judge("hit_chunk", (c as Node2D).global_position + Vector2(0.5, 0.5))
			elif t > 1.05:
				# 到寿命还在飞（飞出台边往下掉）：不算停在半空；但在实心里面算卡墙
				_seen[id] = _t
				var p := (c as Node2D).global_position + Vector2(0.5, 0.5)
				_bump("hit_chunk", "fell", p)
				if _solid_at(p):
					_bump("hit_chunk", "embedded", p)
		elif c.get("_rest") != null and c.get("_bounced") != null:
			# EliteFx.Chunk（精英碎块）：落地 _rest 开始计
			var id := c.get_instance_id()
			if _seen.has(id):
				if _t - int(_seen[id]) > 120 * 3:
					_seen[id] = 1 << 40
					_bump("elite_chunk", "leak", (c as Node2D).global_position)
				continue
			if not _seen.has(-id):
				_seen[-id] = _t
			if float(c.get("_rest")) >= 0.0:
				_seen[id] = _t
				_judge("elite_chunk", (c as Node2D).global_position + Vector2(0.5, -0.5))
			elif _t - int(_seen[-id]) > 120 * 3 + 60:
				_seen[id] = _t
				_bump("elite_chunk", "leak", (c as Node2D).global_position)
		elif c.get("_landed") != null and c.get("_ground") != null:
			_watch_dots(c)


## Splatter：落地的那一帧检查一次（用每滴的落地时刻 _age 重新从 0 开始认"刚落地"）
func _watch_dots(s: Node) -> void:
	var pos: PackedVector2Array = s.get("_pos")
	var landed: Array = s.get("_landed")
	var age: PackedFloat32Array = s.get("_age")
	for i in pos.size():
		# 顿帧时 delta 是 0，同一滴会连着几帧看起来"刚落地"：按位置去重
		if landed[i] and age[i] <= 1.0 / 120.0 + 0.0001:
			if _dot_seen.has(pos[i]):
				continue
			_dot_seen[pos[i]] = true
			_judge("dot", pos[i] + Vector2(0.5, 0.5))
		elif not landed[i] and age[i] > 1.6 - 1.0 / 120.0 - 0.0001:
			if _dot_seen.has(pos[i]):
				continue
			_dot_seen[pos[i]] = true
			# 飞满 1.6 秒没落地（底下没找到地）：就在那儿消失了；在实心里消失也算卡墙
			_bump("dot", "fell", pos[i])
			if _solid_at(pos[i]):
				_bump("dot", "embedded", pos[i])
		elif landed[i] and age[i] > 7.0 and not _dot_seen.has(-pos[i]):
			_dot_seen[-pos[i]] = true
			_bump("dot", "leak", pos[i])


func _judge(kind: String, p: Vector2) -> void:
	_stats[kind]["n"] += 1
	if not _bounds.grow(2).has_point(p):
		_bump(kind, "out", p)
	elif _solid_at(p):
		_bump(kind, "embedded", p)
	elif _floor_below(p, 3.0) == INF:
		_bump(kind, "floating", p)


func _bump(kind: String, what: String, p: Vector2) -> void:
	_stats[kind][what] += 1
	var key: String = kind + "/" + what
	if not _examples.has(key):
		_examples[key] = []
	if (_examples[key] as Array).size() < 4:
		(_examples[key] as Array).append(p.snapped(Vector2(0.1, 0.1)))


func _report() -> void:
	var left := 0
	for c in _lvl.get_children():
		if (c.get("ground_y") != null and c.get("_bounces") != null) or (c.get("_rest") != null and c.get("_bounced") != null):
			left += 1
	var dots_left := 0
	for c in _lvl.get_children():
		if c.get("_landed") != null and c.get("_ground") != null:
			dots_left += (c.get("_pos") as PackedVector2Array).size()
	for k in _stats:
		var s: Dictionary = _stats[k]
		print("DEBRIS ", LEVEL.get_file(), " ", k, ": n=", s["n"], " embedded=", s["embedded"], " floating=", s["floating"],
				" out=", s["out"], " fell_unlanded=", s["fell"], " leak=", s["leak"])
	for key in _examples:
		print("   e.g. ", key, " ", _examples[key])
	print("DEBRIS DONE ", LEVEL.get_file(), " kills=", _trial, " chunks_left_after_8s=", left, " dots_left_after_8s=", dots_left)
