extends SceneTree
## 怪会不会跑到闸门外面（夜间打磨，碰撞会话；作者 10-18 早上在第二关书架房看到接线员站在右闸门外，卡关）：
## 一关里的每一场遭遇战，主角站在左 / 右闸门里侧贴着门（把怪引到门边），每波怪落地后不打，让它们自己动 8 秒，
## 再看有没有怪在两扇闸门外面；然后全部打死进下一波。
## 用法：LEVEL=res://scenes/level2.tscn SIDE=right Godot --headless --fixed-fps 120 --log-file <scratchpad>/esc.log --path . -s tools/qa/gate_escape.gd
var LEVEL := ""
var SIDE := "right"
var _f := 0
var _lvl_id := 0
var _encs: Array = []
var _i := -1
var _enc: Node
var _t := 0.0
var _live := 0.0
var _bad := 0
var _checked := 0


func _initialize() -> void:
	LEVEL = OS.get_environment("LEVEL")
	SIDE = OS.get_environment("SIDE") if OS.get_environment("SIDE") != "" else "right"


func _process(delta: float) -> bool:
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
		print("ESCAPE ", LEVEL, " side=", SIDE, " encounters=", _encs.size())
		Engine.time_scale = 3.0
		return false
	if current_scene.get_instance_id() != _lvl_id:
		print("SCENE CHANGED")
		return true
	var p: Node2D = get_nodes_in_group("player")[0]
	p.set("_invuln", 99.0)
	if _enc == null or not is_instance_valid(_enc) or _enc.get("cleared"):
		_i += 1
		_t = 0.0
		if _i >= _encs.size():
			print("ESCAPE DONE checked=", _checked, " outside=", _bad)
			return true
		_enc = _encs[_i]
		return false
	_t += delta
	if _t > 120.0:
		print("  TIMEOUT ", _desc(_enc))
		_enc.set("cleared", true)
		return false
	var l: float = _enc.get("left")
	var r: float = _enc.get("right")
	var fl: float = maxf(_enc.get("floor_left"), _enc.get("floor_right"))
	var x := r - 14.0 if SIDE == "right" else l + 14.0
	if not _enc.get("started"):
		p.global_position = Vector2((l + r) * 0.5, fl - 1.0)
		p.velocity = Vector2.ZERO
		return false
	# 开打以后主角贴着闸门里侧站，把怪引过去
	p.global_position = Vector2(x, (_enc.get("floor_right") if SIDE == "right" else _enc.get("floor_left")) - 1.0)
	p.velocity = Vector2.ZERO
	var queue: Array = _enc.get("_queue")
	var alive: Array = _enc.get("_alive")
	if not queue.is_empty() or alive.is_empty():
		_live = 0.0
		return false
	_live += delta
	if _live < 8.0:
		return false
	for e in alive:
		if is_instance_valid(e) and not e.get("dead"):
			_checked += 1
			var ex := (e as Node2D).global_position.x
			if ex < l - 2.0 or ex > r + 2.0:
				_bad += 1
				print("  OUTSIDE ", _desc(_enc), " ", e.get_script().resource_path.get_file(), " at ", (e as Node2D).global_position.round())
			e.call("hurt", 9999999.0, Vector2.RIGHT, true)
	_live = 0.0
	return false


func _desc(enc: Node) -> String:
	return "[%d..%d ceil %d floor %d/%d]" % [enc.get("left"), enc.get("right"), enc.get("ceil_y"), enc.get("floor_left"), enc.get("floor_right")]
