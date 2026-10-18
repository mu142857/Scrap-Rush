extends SceneTree
## 遭遇战闸门的边界情况（夜间打磨，碰撞会话）：两人模式，1P 走进第一关第一场遭遇战的场子触发关门，
## 2P 分别站在：左闸门正下方 / 左闸门外 30 像素 / 右闸门正下方 / 场子里。关门 1 秒后看 2P 在哪、有没有嵌在门里。
## 用法：Godot --headless --fixed-fps 120 --log-file <scratchpad>/gate.log --path . -s tools/qa/gate_coop.gd -- --players=2
var _f := 0
var _case := -1
var _t := 0
var _enc: Node
var CASES := []
var _results := []


func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 3:
		root.get_node("Game").set("invincible", true)
		change_scene_to_file("res://scenes/test_level.tscn")
		return false
	if current_scene == null or get_nodes_in_group("player").size() < 2:
		return false
	if _enc == null:
		for c in current_scene.get_children():
			if c.has_method("_spawn_wave") and c.get("left") == 230.0 and c.get("ceil_y") == 0.0:
				_enc = c
		var l: float = _enc.get("left")
		var r: float = _enc.get("right")
		CASES = [["under left gate", l], ["outside left 30", l - 30.0], ["under right gate", r], ["inside", l + 60.0]]
		_next()
		return false
	_t += 1
	var ps := get_nodes_in_group("player")
	if _t == 10:
		# 1P 走进场子中间，触发关门
		ps[0].global_position = Vector2((_enc.get("left") + _enc.get("right")) * 0.5, 117.0)
	if _t == 130:
		var p2: Node2D = ps[1]
		var l: float = _enc.get("left")
		var r: float = _enc.get("right")
		var inside := p2.global_position.x > l + 4.0 and p2.global_position.x < r - 4.0
		print("CASE ", CASES[_case][0], ": started=", _enc.get("started"), " p2 at ", p2.global_position.round(), " inside=", inside, " embedded=", _embedded(p2))
		_next()
		if _case >= CASES.size():
			return true
	return false


func _next() -> void:
	_case += 1
	if _case >= CASES.size():
		return
	_t = 0
	# 场子重置成没开打的样子
	_enc.set("started", false)
	_enc.set("cleared", false)
	for g in _enc.get("_gates"):
		g.get_child(0).set_deferred("disabled", true)
		g.visible = false
	for e in get_nodes_in_group("enemy"):
		e.process_mode = Node.PROCESS_MODE_DISABLED
		e.visible = false
	_enc.set("_queue", [])
	_enc.set("_alive", [])
	var ps := get_nodes_in_group("player")
	ps[0].global_position = Vector2(150, 117)
	ps[1].global_position = Vector2(CASES[_case][1], 117)
	for p in ps:
		p.velocity = Vector2.ZERO


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
