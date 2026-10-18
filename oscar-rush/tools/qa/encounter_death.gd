extends SceneTree
## 遭遇战里死亡的边界情况（夜间打磨，碰撞会话），第一关第一场遭遇战：
##   1 打到一半马灯碎了   → 重来后这场应该没打过：没开打、闸门不在、场上没有残留的怪
##   2 清场那一帧马灯碎了 → 重来后这场应该算打完（存了档）：闸门不落、人在存档点
##   3 存档点重来以后马上又碎 → 还是从同一个存档点来，这场还是打完的样子
## 用法：Godot --headless --fixed-fps 120 --log-file <scratchpad>/death.log --path . -s tools/qa/encounter_death.gd
var _f := 0
var _step := 0
var _t := 0
var _scene: Node


func _enc() -> Node:
	for c in current_scene.get_children():
		if c.has_method("_spawn_wave") and c.get("left") == 230.0 and c.get("ceil_y") == 0.0:
			return c
	return null


func _report(tag: String) -> void:
	var e := _enc()
	var gates_up := true
	for g in e.get("_gates"):
		if g.visible or not g.get_child(0).disabled:
			gates_up = false
	var stray := 0
	for m in get_nodes_in_group("enemy"):
		var p: Vector2 = (m as Node2D).global_position
		if p.x > 230 and p.x < 450 and p.y < 130 and not m.get("dead"):
			stray += 1
	var pl: Node2D = get_nodes_in_group("player")[0]
	print("%s: started=%s cleared=%s gates_open=%s monsters_in_arena=%d player=%s lantern=%d" % [tag, e.get("started"), e.get("cleared"), gates_up, stray, pl.global_position.round(), int(root.get_node("Run").get("crystal_hp"))])


func _break() -> void:
	root.get_node("Game").set("invincible", false)
	var run := root.get_node("Run")
	var before: float = run.get("crystal_hp")
	run.call("damage_crystal", 99999.0)
	print("  break: invincible=", root.get_node("Game").get("invincible"), " locked=", run.get("crystal_locked"), " hp ", before, " -> ", run.get("crystal_hp"))


var _reloads := 0
var _scene_id := 0


func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 3:
		change_scene_to_file("res://scenes/test_level.tscn")
		return false
	if current_scene == null or get_nodes_in_group("player").is_empty() or _enc() == null:
		return false
	if current_scene != _scene or _scene_id != current_scene.get_instance_id():
		# 旧场景释放以后，变量和 null 比较会当成相等，所以另外记一个 id
		if _scene_id != 0:
			_reloads += 1
		_scene_id = current_scene.get_instance_id()
		_scene = current_scene
		_t = 0
	_t += 1
	var p: Node2D = get_nodes_in_group("player")[0]
	# 每一步：死一次 → 等场景真的重载、再过 2 秒 → 报告
	match _step:
		0:
			p.global_position = Vector2(340, 117)
			if _t == 240:
				_report("1 before death (mid-fight)")
				_break()
				_step = 1
		1:
			if _reloads == 1 and _t == 240:
				_report("1 after retry")
				_step = 2
				_t = 0
		2:
			if _t < 120:
				p.global_position = Vector2(340, 117)
			if _t == 120:
				_enc().call("_finish")
				_break()
				_step = 3
		3:
			if _reloads == 2 and _t == 240:
				_report("2 after retry (died the frame it cleared)")
				_break()
				_step = 4
		4:
			if _reloads == 3 and _t == 240:
				_report("3 after dying again right after checkpoint")
				return true
	if false:
		print("  tick scene_id=", current_scene.get_instance_id(), " f=", _f, " step=", _step, " t=", _t, " reloads=", _reloads, " lantern=", root.get_node("Run").get("crystal_hp"), " paused=", paused)
	return _f > 12000
