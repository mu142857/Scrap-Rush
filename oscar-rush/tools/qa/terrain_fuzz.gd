extends SceneTree
## 地形压力测试（夜间打磨，碰撞会话）：主角在关卡里随机落点、随机走 / 跳 / 飞 / 按下 / 贴墙，抓：
##   in_wall    碰撞框和实心地形重叠连续好几帧（卡进墙里）
##   out_of_map 跑出关卡范围（穿墙、掉出地图）
##   stuck      乱按了 2 秒（其中至少按住跳 0.5 秒、左右都按过），人还待在 3 像素以内（卡在角落出不来）
## 怪、遭遇战、Boss 一开始全删掉，只测地形；主角无敌。
## 用法（工程目录下）：
##   LEVEL=res://scenes/test_level.tscn BOUNDS=0,0,1006,426 TRIALS=200 SEED=1 Godot --headless --fixed-fps 120 \
##     --log-file <scratchpad>/fuzz.log --path . -s tools/qa/terrain_fuzz.gd
## 只在最后打印汇总（每种问题按 8 像素格子去重），不逐帧输出。

const TRIAL_FRAMES := 480
const STUCK_WINDOW := 240
const WALL_FRAMES := 4
const ACTIONS := ["left", "right", "jump", "down"]

var LEVEL := ""
var TRIALS := 100
var _rng := RandomNumberGenerator.new()
var _f := 0
var _lvl: Node
var _bounds := Rect2()
var _trial := -1
var _tf := 0
var _seg := 0
var _held: Array = []
var _hist: Array[Vector2] = []
## 和 _hist 对齐：每帧按了什么（跳、左、右），判 stuck 时要真的试过往上和两边
var _inp: Array[int] = []
var _wall_run := 0
var _issues := {}
var _shape: RectangleShape2D
var _p: CharacterBody2D
var _start := Vector2.ZERO
var _done_trials := 0


func _initialize() -> void:
	LEVEL = OS.get_environment("LEVEL")
	TRIALS = int(OS.get_environment("TRIALS")) if OS.get_environment("TRIALS") != "" else 100
	_rng.seed = int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 1


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
	if _trial < 0 or _tf >= TRIAL_FRAMES:
		if _trial >= 0:
			_done_trials += 1
		_trial += 1
		if _trial % 10 == 0:
			print("  trial ", _trial, " frame ", _f, " t=", Time.get_ticks_msec() / 1000)
		if _trial >= TRIALS:
			_report()
			return true
		_new_trial()
		return false
	if current_scene != _lvl or not is_instance_valid(_p):
		print("SCENE CHANGED to ", current_scene.scene_file_path if current_scene else "null", " at trial ", _trial)
		_report()
		return true
	_tf += 1
	_drive()
	_check()
	return false


func _setup() -> void:
	_lvl = current_scene
	_p = get_nodes_in_group("player")[0]
	print("SCENE ", _lvl.scene_file_path, " player at ", _p.global_position.round())
	# 走到出口会切到下一关：把关卡自己的"正在离开"打开，出口就不再触发
	if "_leaving" in _lvl:
		_lvl.set("_leaving", true)
	# 怪不删（血条之类还引用着），定住、藏起来、关掉碰撞；遭遇战整个停掉
	for n in get_nodes_in_group("enemy"):
		n.process_mode = Node.PROCESS_MODE_DISABLED
		n.visible = false
		if n is CollisionObject2D:
			(n as CollisionObject2D).collision_layer = 0
	for c in _lvl.get_children():
		if c.has_method("_spawn_wave"):
			c.process_mode = Node.PROCESS_MODE_DISABLED
	_bounds = Rect2()
	for cam in _lvl.find_children("*", "Camera2D", true, false):
		if cam.get("bounds") is Rect2:
			_bounds = cam.get("bounds")
	# 镜头找不到时用环境变量 BOUNDS="x,y,w,h"（第一关 0,0,1006,426；第三关 0,0,4994,1200）
	var env := OS.get_environment("BOUNDS")
	if env != "":
		var v := env.split_floats(",")
		_bounds = Rect2(v[0], v[1], v[2], v[3])
	if _bounds.size == Vector2.ZERO:
		push_error("找不到关卡范围")
	for c in _p.get_children():
		if c is CollisionShape2D:
			_shape = (c as CollisionShape2D).shape


## 随机落点：关卡里随便挑一点往下找地面（实心或单向平台），脚下是空的才用
func _new_trial() -> void:
	_tf = 0
	_hist.clear()
	_inp.clear()
	_wall_run = 0
	var space := _p.get_world_2d().direct_space_state
	for attempt in 60:
		var x := _rng.randf_range(_bounds.position.x + 8, _bounds.end.x - 8)
		var y := _rng.randf_range(_bounds.position.y + 8, _bounds.end.y - 8)
		if _solid_at(space, Vector2(x, y)):
			continue
		var q := PhysicsRayQueryParameters2D.create(Vector2(x, y), Vector2(x, _bounds.end.y + 40), 1 | 64)
		var hit := space.intersect_ray(q)
		if hit.is_empty() or hit["normal"].y > -0.7:
			continue
		var feet: Vector2 = hit["position"] - Vector2(0, 0.5)
		if _solid_at(space, feet - Vector2(0, 1)):
			continue
		if _overlaps(feet) or _overlaps(Vector2(x, y)):
			continue
		_start = feet
		if OS.get_environment("DEBUG_HIT") != "":
			var col: Object = hit["collider"]
			print("  start ", feet.round(), " on ", col, " ", col.get_parent() if col is Node else "", " layer=", col.get("collision_layer"))
		_p.global_position = feet
		_p.velocity = Vector2.ZERO
		_p.set("fuel", 1.0)
		_p.reset_physics_interpolation()
		return
	_start = _p.global_position


func _drive() -> void:
	_seg -= 1
	if _seg > 0:
		return
	for a in _held:
		Input.action_release("solo_" + a)
	_held.clear()
	_seg = _rng.randi_range(12, 90)
	var dir := _rng.randi_range(0, 2)
	if dir == 1:
		_held.append("left")
	elif dir == 2:
		_held.append("right")
	if _rng.randf() < 0.55:
		_held.append("jump")
	if _rng.randf() < 0.12:
		_held.append("down")
	for a in _held:
		Input.action_press("solo_" + a)


func _overlaps(feet: Vector2) -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = _shape
	q.transform = Transform2D(0, feet + Vector2(0, -8))
	q.collision_mask = 1
	q.margin = -0.6
	# 单向平台（只挡从上面落下来的）从下面跳穿过去时重叠是正常的，不算卡墙
	for r in _p.get_world_2d().direct_space_state.intersect_shape(q, 4):
		var col := r["collider"] as CollisionObject2D
		if col == null:
			return true
		var owner_shape = col.shape_owner_get_owner(col.shape_find_owner(r["shape"]))
		if (owner_shape is CollisionShape2D or owner_shape is CollisionPolygon2D) and owner_shape.one_way_collision:
			continue
		return true
	return false


func _check() -> void:
	var pos := _p.global_position
	if not _bounds.grow(6).has_point(pos):
		_add("out_of_map", pos)
		_new_trial()
		return
	if _overlaps(pos):
		_wall_run += 1
		if _wall_run == WALL_FRAMES:
			_add("in_wall", pos)
	else:
		_wall_run = 0
	_hist.append(pos)
	_inp.append((1 if _held.has("jump") else 0) | (2 if _held.has("left") else 0) | (4 if _held.has("right") else 0))
	if _hist.size() > STUCK_WINDOW:
		_hist.pop_front()
		_inp.pop_front()
		var r := Rect2(_hist[0], Vector2.ZERO)
		for h in _hist:
			r = r.expand(h)
		var jumps := 0
		var sides := 0
		for i in _inp:
			jumps += i & 1
			sides |= i & 6
		if r.size.x < 3.0 and r.size.y < 3.0 and jumps >= 60 and sides == 6:
			_add("stuck", pos)
			_new_trial()


func _add(kind: String, pos: Vector2) -> void:
	var key := "%s@%d,%d" % [kind, int(pos.x / 8) * 8, int(pos.y / 8) * 8]
	if not _issues.has(key):
		_issues[key] = {"kind": kind, "pos": pos.round(), "start": _start.round(), "n": 0}
	_issues[key]["n"] += 1


func _report() -> void:
	var counts := {}
	for k in _issues:
		var it: Dictionary = _issues[k]
		counts[it["kind"]] = counts.get(it["kind"], 0) + it["n"]
	print("FUZZ ", LEVEL, " trials=", _done_trials, " frames=", _f, " counts=", counts)
	var keys := _issues.keys()
	keys.sort()
	for k in keys:
		var it: Dictionary = _issues[k]
		print("  ", it["kind"], " at ", it["pos"], " (start ", it["start"], ") x", it["n"])


## 这一点是不是在实心地形里面（射线从实心里面出发会打到多边形内部的拼接边，落点就错了）
func _solid_at(space: PhysicsDirectSpaceState2D, pt: Vector2) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = pt
	q.collision_mask = 1
	return not space.intersect_point(q, 1).is_empty()
