extends SceneTree
## 怪的地形压力测试（夜间打磨，碰撞会话）：把每种怪挨个放到关卡里随机的地面上（斜坡、平台边、窄缝、矮天花板下），
## 主角（无敌）站在旁边逗它 6 秒，抓：
##   in_wall  怪的碰撞框和实心地形重叠连续好几帧（卡进墙里 / 地里 / 天花板里）
##   out      跑出关卡范围（穿墙、掉出地图）
##   jitter   1 秒里左右掉头超过 8 次（原地抖）
##   fell     掉下去 60 像素以上（走下平台边。地面怪一般该在边上掉头；飞的不算）
## 每种怪放 TRIALS_PER_KIND 次。关卡原来的怪和遭遇战都停掉，出口锁住。只在最后打印汇总。
## 用法（工程目录下）：
##   LEVEL=res://scenes/test_level.tscn BOUNDS=0,0,1006,426 SET=encounter TRIALS_PER_KIND=6 SEED=1 \
##     Godot --headless --fixed-fps 120 --log-file <scratchpad>/mob.log --path . -s tools/qa/mob_fuzz.gd
## SET=encounter 用遭遇战里所有种类（第一、二关的小怪和精英）；SET=l3 用第三关所有怪。

const RUN_FRAMES := 720
const GAP_FRAMES := 90
const WALL_FRAMES := 6
## 运行时再 load：-s 脚本编译时还没有自动加载（Game、Run），直接引用会编译失败
var ENC: Script
var L3: Script
var L3MOB: Script

var LEVEL := ""
var SET := "encounter"
var PER := 6
var _rng := RandomNumberGenerator.new()
var _bounds := Rect2()
var _f := 0
var _lvl: Node
var _p: CharacterBody2D
var _kinds: Array = []
var _k := 0
var _rep := 0
var _e: Node2D
var _t := 0
var _gap := 0
var _start := Vector2.ZERO
var _wall := 0
var _flips: Array[int] = []
var _last_dir := 0
var _flagged := {}
var _issues := {}
var _spawned := 0


func _initialize() -> void:
	LEVEL = OS.get_environment("LEVEL")
	SET = OS.get_environment("SET") if OS.get_environment("SET") != "" else "encounter"
	PER = int(OS.get_environment("TRIALS_PER_KIND")) if OS.get_environment("TRIALS_PER_KIND") != "" else 6
	_rng.seed = int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 1
	var v := OS.get_environment("BOUNDS").split_floats(",")
	_bounds = Rect2(v[0], v[1], v[2], v[3])


func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 3:
		root.get_node("Game").set("invincible", true)
		# 第二关第一次进来会先跳去气动管开场：先告诉它"已经从管子里出来了"
		if LEVEL.ends_with("level2.tscn"):
			load("res://scripts/levels/level2.gd").set("tube_landing", true)
		change_scene_to_file(LEVEL)
		return false
	if current_scene == null or get_nodes_in_group("player").is_empty():
		return false
	if _lvl == null:
		_setup()
		return false
	if current_scene != _lvl:
		print("SCENE CHANGED")
		_report()
		return true
	_p.set("_invuln", 99.0)
	if _gap > 0:
		_gap -= 1
		return false
	if _e == null:
		if _k >= _kinds.size():
			_report()
			return true
		_spawn_next()
		return false
	_t += 1
	if not is_instance_valid(_e) or _e.get("dead"):
		_end_trial()
		return false
	_check()
	if _t >= RUN_FRAMES:
		_end_trial()
	return false


func _setup() -> void:
	_lvl = current_scene
	_p = get_nodes_in_group("player")[0]
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
	ENC = load("res://scripts/levels/encounter.gd")
	L3 = load("res://scripts/levels/level3_mobs.gd")
	L3MOB = load("res://scripts/enemies/l3/l3_mob.gd")
	if SET == "l3":
		for k in L3.MOBS:
			_kinds.append(k)
	else:
		for k in ENC.TYPES:
			if ResourceLoader.exists(ENC.TYPES[k]):
				_kinds.append(k)
	_kinds.sort()
	print("MOBFUZZ ", LEVEL, " kinds=", _kinds.size())


func _make(kind: String) -> Node2D:
	if SET == "l3":
		return L3MOB.make(kind, "color")
	var e: Node2D = (load(ENC.TYPES[kind]) as GDScript).new()
	e.set("respawn_time", 0.0)
	return e


## 随机找一块地面放怪，主角放在它旁边 30~70 像素
func _spawn_next() -> void:
	var kind: String = _kinds[_k]
	var space := _p.get_world_2d().direct_space_state
	var feet := Vector2.ZERO
	for attempt in 80:
		var x := _rng.randf_range(_bounds.position.x + 16, _bounds.end.x - 16)
		var y := _rng.randf_range(_bounds.position.y + 16, _bounds.end.y - 8)
		if _solid_at(space, Vector2(x, y)):
			continue
		var q := PhysicsRayQueryParameters2D.create(Vector2(x, y), Vector2(x, _bounds.end.y + 40), 1)
		var hit := space.intersect_ray(q)
		if hit.is_empty() or hit["normal"].y > -0.7:
			continue
		feet = hit["position"] - Vector2(0, 0.5)
		if _solid_at(space, feet - Vector2(0, 1)) or not _solid_at(space, feet + Vector2(0, 1.5)):
			continue
		break
	_e = _make(kind)
	_e.position = feet
	_lvl.add_child(_e)
	_spawned += 1
	# 放下去就嵌在地形里的点（太矮的地方放了个高个子）不算怪的问题，换一次
	if _overlaps(_e):
		_e.queue_free()
		_e = null
		return
	if SET == "l3":
		L3MOB.arena = _bounds
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	_p.global_position = feet + Vector2(side * _rng.randf_range(30, 70), -2)
	_p.velocity = Vector2.ZERO
	_p.reset_physics_interpolation()
	_start = feet
	_t = 0
	_wall = 0
	_flips.clear()
	_last_dir = 0


func _end_trial() -> void:
	if is_instance_valid(_e):
		if not _e.get("dead") and _e.has_method("hurt"):
			_e.call("hurt", 9999999.0, Vector2.RIGHT, true)
		_e.process_mode = Node.PROCESS_MODE_DISABLED
		_e.visible = false
		if _e is CollisionObject2D:
			(_e as CollisionObject2D).collision_layer = 0
	_e = null
	_gap = GAP_FRAMES
	_rep += 1
	if _rep >= PER:
		_rep = 0
		_k += 1


func _body_shape(e: Node) -> CollisionShape2D:
	for c in e.get_children():
		if c is CollisionShape2D and not (c as CollisionShape2D).disabled:
			return c
	return null


func _overlaps(e: Node2D) -> bool:
	var cs := _body_shape(e)
	if cs == null:
		return false
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = cs.shape
	q.transform = cs.global_transform
	q.collision_mask = 1
	q.margin = -0.8
	q.exclude = [(e as CollisionObject2D).get_rid()] if e is CollisionObject2D else []
	# 单向平台（只挡从上面落下来的）横着穿过去是正常的，不算卡墙
	for r in e.get_world_2d().direct_space_state.intersect_shape(q, 4):
		var col := r["collider"] as CollisionObject2D
		if col == null:
			return true
		var owner_shape = col.shape_owner_get_owner(col.shape_find_owner(r["shape"]))
		if owner_shape is CollisionShape2D and (owner_shape as CollisionShape2D).one_way_collision:
			continue
		if owner_shape is CollisionPolygon2D and (owner_shape as CollisionPolygon2D).one_way_collision:
			continue
		return true
	return false


func _check() -> void:
	var pos := _e.global_position
	var kind: String = _kinds[_k]
	if not _bounds.grow(8).has_point(pos):
		_add(kind, "out", pos)
		_end_trial()
		return
	if _t > 30 and _overlaps(_e):
		_wall += 1
		if _wall == WALL_FRAMES:
			_add(kind, "in_wall", pos)
	else:
		_wall = 0
	var d := int(signf(float(_e.get("dir")) if _e.get("dir") != null else _e.get("velocity").x))
	if d != 0 and _last_dir != 0 and d != _last_dir:
		_flips.append(_t)
	if d != 0:
		_last_dir = d
	while not _flips.is_empty() and _flips[0] < _t - 120:
		_flips.pop_front()
	if _flips.size() > 8:
		_add(kind, "jitter", pos)
		_flips.clear()
	if pos.y > _start.y + 60.0 and not _e.get("flying"):
		_add(kind, "fell", pos)
		_start = pos


func _add(kind: String, what: String, pos: Vector2) -> void:
	var key := "%s|%s|%d,%d" % [kind, what, int(_start.x / 16) * 16, int(_start.y / 16) * 16]
	if _issues.has(key):
		_issues[key]["n"] += 1
		return
	_issues[key] = {"kind": kind, "what": what, "pos": pos.round(), "start": _start.round(), "n": 1}


func _report() -> void:
	var counts := {}
	for k in _issues:
		var it: Dictionary = _issues[k]
		counts[it["what"]] = counts.get(it["what"], 0) + 1
	print("MOBFUZZ DONE ", LEVEL, " set=", SET, " spawned=", _spawned, " issues=", counts)
	var keys := _issues.keys()
	keys.sort()
	for k in keys:
		var it: Dictionary = _issues[k]
		print("  ", it["kind"], " ", it["what"], " at ", it["pos"], " (placed ", it["start"], ") x", it["n"])


## 这一点是不是在实心地形里面（射线从实心里面出发会打到多边形内部的拼接边，落点就错了）
func _solid_at(space: PhysicsDirectSpaceState2D, pt: Vector2) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = pt
	q.collision_mask = 1
	return not space.intersect_point(q, 1).is_empty()
