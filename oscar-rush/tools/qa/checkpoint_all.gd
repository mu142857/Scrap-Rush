extends SceneTree
## 每个存档点能不能站（夜间打磨，碰撞会话）：一关里的遭遇战挨个"打完"（_finish 存档），马上让马灯碎掉，
## 等场景重载、人被放到存档点，2 秒后看人：站在地上、没嵌在墙里、没掉出地图、遭遇战还是打完的样子（门开着）。
## 用法：LEVEL=res://scenes/level3.tscn BOUNDS=0,0,4994,1200 Godot --headless --fixed-fps 120 --log-file <scratchpad>/cp.log --path . -s tools/qa/checkpoint_all.gd
var LEVEL := ""
var _bounds := Rect2()
var _f := 0
var _scene_id := 0
var _reloads := 0
var _i := 0
var _n := -1
var _t := 0
var _phase := 0
var _bad := 0
var _ok := 0


func _initialize() -> void:
	LEVEL = OS.get_environment("LEVEL")
	var v := OS.get_environment("BOUNDS").split_floats(",")
	_bounds = Rect2(v[0], v[1], v[2], v[3])


func _encs() -> Array:
	var out := []
	for c in current_scene.get_children():
		if c.has_method("_spawn_wave"):
			out.append(c)
	return out


func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 3:
		if LEVEL.ends_with("level2.tscn"):
			load("res://scripts/levels/level2.gd").set("tube_landing", true)
		change_scene_to_file(LEVEL)
		return false
	if current_scene == null or get_nodes_in_group("player").is_empty():
		return false
	if current_scene.get_instance_id() != _scene_id:
		if _scene_id != 0:
			_reloads += 1
		_scene_id = current_scene.get_instance_id()
		_t = 0
		# 不能像别的测试那样把关卡的 _leaving 打开锁出口：第二关马灯碎了看到 _leaving 就不重来
	_t += 1
	var encs := _encs()
	if _n < 0:
		_n = encs.size()
		print("CHECKPOINTS ", LEVEL, " encounters=", _n)
	var p: CharacterBody2D = get_nodes_in_group("player")[0]
	match _phase:
		0:
			# 场景刚载入：打完第 _i 场（存档），然后让马灯碎
			if _t < 30:
				return false
			if _i >= _n:
				print("CHECKPOINTS DONE ok=", _ok, " bad=", _bad)
				return true
			var enc: Node = encs[_i]
			p.global_position = Vector2((enc.get("left") + enc.get("right")) * 0.5, maxf(enc.get("floor_left"), enc.get("floor_right")) - 1.0)
			p.velocity = Vector2.ZERO
			if not enc.get("started"):
				enc.call("_start")
			enc.call("_finish")
			root.get_node("Game").set("invincible", false)
			root.get_node("Run").set("crystal_locked", false)
			root.get_node("Run").call("damage_crystal", 999999.0)
			_phase = 1
		1:
			# 等重载后 2 秒
			if _reloads < _i + 1 or _t < 240:
				return false
			var enc2: Node = encs[_i]
			var pos := p.global_position
			var embedded := _embedded(p)
			var out := not _bounds.grow(4).has_point(pos)
			var floor_ok := p.is_on_floor()
			var cleared: bool = enc2.get("cleared")
			var desc := "[%d..%d floor %d]" % [enc2.get("left"), enc2.get("right"), enc2.get("floor_left")]
			if embedded or out or not floor_ok or not cleared:
				_bad += 1
				print("  BAD ", desc, " player at ", pos.round(), " floor=", floor_ok, " embedded=", embedded, " out=", out, " cleared=", cleared)
			else:
				_ok += 1
			_i += 1
			_phase = 0
			_t = 0
	return _f > 120 * 60 * 20


func _embedded(p: CharacterBody2D) -> bool:
	for c in p.get_children():
		if c is CollisionShape2D:
			var q := PhysicsShapeQueryParameters2D.new()
			q.shape = c.shape
			q.transform = c.global_transform
			q.collision_mask = 1
			q.margin = -0.6
			return not p.get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()
	return false
