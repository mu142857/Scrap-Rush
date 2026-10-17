extends Node
## 遭遇战自动检查（无窗口也能跑）：把主角依次传送进每个场子，看闸门落下、怪一波波掉下来，
## 每波掉齐以后用脚本把它们打死，最后看闸门升起、掉零件、捡到零件。结果打在日志里。
## 用法：Godot --headless --path . res://scenes/encounter_check.tscn

var level: Node2D
var _encs: Array = []
var _i := 0
var _t := 0.0
var _phase := "go"
var _last_wave := -2


func _ready() -> void:
	level = load("res://scenes/test_level.tscn").instantiate()
	add_child(level)
	Run.crystal_max = 100000.0
	Run.crystal_hp = 100000.0
	for c in level.get_children():
		if c is Encounter:
			_encs.append(c)
	print("[enc] 共 %d 场" % _encs.size())


func _physics_process(delta: float) -> void:
	_t += delta
	if _i >= _encs.size():
		print("[enc] 全部打完，零件 = %d" % Run.parts)
		get_tree().quit()
		return
	var e: Encounter = _encs[_i]
	var p: Node2D = get_tree().get_nodes_in_group("player")[0]
	match _phase:
		"go":
			p.global_position = Vector2((e.left + e.right) / 2.0, e.ceil_y + 10.0)
			(p as CharacterBody2D).velocity = Vector2.ZERO
			_phase = "wait_start"
			_t = 0.0
		"wait_start":
			if e.started:
				var gates := e.get_children().filter(func(c): return c is StaticBody2D)
				print("[enc] #%d 开打 t=%.2f  闸门 %d 扇，碰撞=%s" % [_i, _t, gates.size(),
					gates.map(func(g): return not (g.get_child(0) as CollisionShape2D).disabled)])
				_phase = "fight"
				_t = 0.0
			elif _t > 3.0:
				print("[enc] #%d 没触发！主角在 %s" % [_i, p.global_position])
				_i += 1
				_phase = "go"
		"fight":
			if e._wave != _last_wave and e._queue.is_empty() and e._wave >= 0:
				_last_wave = e._wave
				var kinds := []
				for a in e._alive:
					kinds.append("%s@%s" % [a.get_script().resource_path.get_file().get_basename(), a.global_position.round()])
				print("[enc] #%d 第 %d 波掉齐：%s" % [_i, e._wave + 1, kinds])
			# 掉齐 0.6 秒以后全部打死
			if e._queue.is_empty() and not e._alive.is_empty() and _t > 0.6:
				for a in e._alive:
					if is_instance_valid(a) and not a.get("dead"):
						a.call("hurt", 99999.0, Vector2.RIGHT, true)
				_t = 0.0
			if e.cleared:
				_phase = "loot"
				_t = 0.0
			elif _t > 20.0:
				print("[enc] #%d 卡住了：wave=%d alive=%d queue=%d" % [_i, e._wave, e._alive.size(), e._queue.size()])
				_i += 1
				_phase = "go"
		"loot":
			if _t > 1.2:
				var parts := level.get_children().filter(func(c): return c is Encounter.Part)
				var before := Run.parts
				for part in parts:
					p.global_position = (part as Node2D).global_position + Vector2(0, 6)
				_phase = "after_loot"
				_t = 0.0
				print("[enc] #%d 清场，闸门升起；地上零件 %d 个，零件落在 %s" % [_i, parts.size(),
					parts.map(func(x): return x.global_position.round())])
		"after_loot":
			if _t > 0.3:
				print("[enc] #%d 捡完零件，Run.parts = %d，情绪 = %.0f" % [_i, Run.parts, Run.emotion])
				_i += 1
				_last_wave = -2
				_phase = "go"
