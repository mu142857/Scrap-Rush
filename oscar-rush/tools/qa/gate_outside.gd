extends SceneTree
## 闸门外的怪会不会被拉回来（夜间打磨，碰撞会话；作者 10-18 早上第二关 E3 卡关）。第二关 E3 电话簿仓库（72..410）：
##   A 开打后，把一只场子里的怪挪到右闸门外的缝里（门和墙之间）→ 1 秒后应该被拉回场子
##   B 把一只怪挪到右闸门正中（门洞里），闸门已经落下 → 被物理挤到一边；挤到外面的话同样要被拉回来
##   C 总接线长站在离右闸门 30 像素的地方叫班 → 叫来的两个接线员最后都要在场子里
## 用法：Godot --headless --fixed-fps 120 --log-file <scratchpad>/out.log --path . -s tools/qa/gate_outside.gd
var _f := 0
var _enc: Node
var _step := 0
var _t := 0
var _target: Node2D
var _chief: Node2D


func _process(_d: float) -> bool:
	_f += 1
	if _f == 3:
		root.get_node("Game").set("invincible", true)
		load("res://scripts/levels/level2.gd").set("tube_landing", true)
		change_scene_to_file("res://scenes/level2.tscn")
		return false
	if current_scene == null or get_nodes_in_group("player").is_empty():
		return false
	if _enc == null:
		current_scene.set("_leaving", true)
		for c in current_scene.get_children():
			if c.has_method("_spawn_wave") and c.get("left") == 72.0 and c.get("right") == 410.0:
				_enc = c
		return false
	var p: Node2D = get_nodes_in_group("player")[0]
	p.set("_invuln", 99.0)
	p.global_position = Vector2(200, 249)
	if not _enc.get("started"):
		return false
	_t += 1
	var alive: Array = _enc.get("_alive")
	match _step:
		0:
			if _enc.get("_queue").is_empty() and alive.size() > 0 and _t > 60:
				_target = alive[0]
				_target.global_position = Vector2(425, 249)
				print("A moved ", _target.get_script().resource_path.get_file(), " outside right gate to ", _target.global_position.round())
				_step = 1
				_t = 0
		1:
			if _t == 240:
				var ok := is_instance_valid(_target) and _target.global_position.x < 410.0
				print("A after 2s: ", _target.global_position.round() if is_instance_valid(_target) else "gone", " inside=", ok)
				_target.global_position = Vector2(410, 249)
				print("B moved it into the right gate doorway (410)")
				_step = 2
				_t = 0
		2:
			if _t == 30:
				print("B after 0.25s: ", _target.global_position.round())
			if _t == 300:
				var ok := is_instance_valid(_target) and _target.global_position.x < 410.0
				print("B after 2.5s: ", _target.global_position.round() if is_instance_valid(_target) else "gone", " inside=", ok)
				# 照真实流程：打到 E3 时 E1、E2 早就打完了（总接线长找"自己那一场"是按 x 范围找第一场没打完的）
				for c in current_scene.get_children():
					if c.has_method("_spawn_wave") and c != _enc:
						c.set("cleared", true)
				_chief = load("res://scripts/enemies/chief_operator.gd").new()
				_chief.position = Vector2(380, 249)
				current_scene.add_child(_chief)
				alive.append(_chief)
				_step = 3
				_t = 0
		3:
			if _t == 60:
				_chief.global_position = Vector2(380, 249)
				_chief.call("_call_operators")
				var s: Array = _chief.get("_summoned")
				var xs := []
				for m in s: xs.append((m as Node2D).global_position.round())
				print("C chief at 380 called operators at ", xs)
			if false:
				var s2: Array = _chief.get("_summoned")
				if s2.size() > 1 and is_instance_valid(s2[1]):
					var m: CharacterBody2D = s2[1]
					print("   op2 t=%.2f pos=%s vel=%s floor=%s out_t=%s pulls=%s" % [(_t - 60) / 120.0, m.global_position.round(), m.velocity.round(), m.is_on_floor(), m.get_meta("_out_t", 0), m.get_meta("_out_pulls", 0)])
			if _t == 360:
				var s: Array = _chief.get("_summoned")
				var xs := []
				var all_in := true
				for m in s:
					if is_instance_valid(m):
						xs.append((m as Node2D).global_position.round())
						if (m as Node2D).global_position.x > 410.0: all_in = false
				print("C after 2.5s: ", xs, " all inside=", all_in)
				return true
	return _f > 6000
