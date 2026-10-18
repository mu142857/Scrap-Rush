extends Node
## 精英怪 + Boss 自动回归（夜间打磨 10-17，总机台/留声机会话写的）。改了怪、武器、遭遇战以后跑一遍。
##
## 用法（无窗口；一定要带 --log-file，并且把同一个路径用 --log= 再告诉脚本一次——引擎不把 --log-file 传给脚本，
## 脚本靠它数脚本错误、看日志有没有疯涨）：
##   Godot --headless --fixed-fps 60 --path . --log-file /tmp/elite_qa.log res://tools/qa/elite_regression.tscn -- --log=/tmp/elite_qa.log
## 可选参数（放在 -- 后面）：
##   --only=switchboard,gramophone,boss2   只跑这几只（精英用种类名，第三关精英用 level3_mobs 里的名字，Boss 用 boss1/boss2/boss3）
##   --skip-bosses / --only-bosses          不跑 Boss / 只跑 Boss
##   --weapons=flash,rivet                  只用这几把武器（默认三把都用）
##   --out=/tmp/elite_qa.md                 结果另存一张 markdown 表
## 跑完打印一张表（每只一行），最后一行是总结；有不过的，进程退出码是 1。
##
## 每只精英：放进测试关最底下那座长桥（x 470~790，桥面 y 343），三把武器各打一次，再走一遍遭遇战：
##   - 落地：出生 8 秒内站到地上，出场动画放完
##   - 招式：打的过程中冒过至少 2 次红"!"（warn），走过至少 3 种状态
##   - 能打死：主角站在这把武器的射程上（闪光灯 70、铆钉枪 60、蒸汽锤 26 像素）用真的按键开火，100 秒内打空血
##   - 真死：血空以后 6 秒内 dead 变真（死亡演出放完）
##   - 清场：遭遇战（一波只有它）里它死了以后 8 秒内闸门升起
##   - 0 错：这一次跑的过程中日志里没有新的 SCRIPT ERROR / Parse Error；单次日志增长不超过 20 MB
##   - 节奏（只量不判，10-18 加）：每次打完打一行 [qa] 节奏：每种招式起了几次、两招之间的空档（平均 / 最长，秒）。
##     "空档" = 两次出招之间连续待在 MOVE/IDLE/WALK/RECOVER 之类状态里的时间（含收招），从出招的状态切过去才算一次出招。
## 每个 Boss：开它的 Boss 房，主角走过门口触发开场，三把武器各打一次，150 秒内打死，三个阶段都要经过，死后 15 秒内 dead 变真，0 错。
##   Boss2 配蒸汽锤时主角站在长凳上打（游戏里就是这么提示的；站地上够不着吊着的总机）。
## 主角全程无敌（Game.invincible），情绪每帧归零（伤害、节奏不随情绪变），只看能不能打、会不会坏。

const ARENA_L := 470.0
const ARENA_R := 790.0
const FLOOR_Y := 343.0
const RANGE := {"flash": 70.0, "rivet": 60.0, "hammer": 26.0}
## 新武器站多远打：登记表（WeaponRegistry）的 qa_range，没写就 60
const ELITE_TIME := 100.0
const BOSS_TIME := 150.0
const LOG_CASE_LIMIT := 20 * 1024 * 1024
const LOG_TOTAL_LIMIT := 200 * 1024 * 1024
const L1 := ["cuckoo", "sewing", "register", "piano", "vacuum", "roller"]
const L2 := ["switchboard", "gramophone", "projector", "watchman", "chief_operator", "film_editor", "telegrapher"]
const BOSSES := {"boss1": "res://scenes/boss1.tscn", "boss2": "res://scenes/boss2.tscn", "boss3": "res://scenes/boss3.tscn"}

var _only: Array = []
var _skip_bosses := false
var _only_bosses := false
## 默认用武器登记表里所有做好了的（10-18 起 7 把，游戏设计会话改）
var _weapons: Array = Array(WeaponRegistry.ids())
var _out := ""
var _log_path := ""
var _log_pos := 0
var _rows: Array = []
var _level: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--log="):
			_log_path = a.trim_prefix("--log=")
		elif a.begins_with("--only="):
			_only = a.trim_prefix("--only=").split(",")
		elif a == "--skip-bosses":
			_skip_bosses = true
		elif a == "--only-bosses":
			_only_bosses = true
		elif a.begins_with("--weapons="):
			_weapons = Array(a.trim_prefix("--weapons=").split(","))
		elif a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
	if _log_path == "":
		print("[qa] 没带 -- --log=<--log-file 的路径>：数不了脚本错误，也看不住日志增长。请加上再跑。")
	if Game.pause_menu:
		Game.pause_menu.queue_free()
		Game.pause_menu = null
	Game.invincible = true
	_log_pos = _log_size()
	await _run_all()
	_report()


# —— 跑 ——

func _run_all() -> void:
	var cases: Array = []
	if not _only_bosses:
		for k in L1:
			cases.append(["L1", k])
		for k in L2:
			cases.append(["L2", k])
		for k in L3Mob.DATA.MOBS:
			if L3Mob.DATA.MOBS[k]["kind"] == "elite":
				cases.append(["L3", k])
	if not _skip_bosses:
		for k in BOSSES:
			cases.append(["Boss", k])
	for c in cases:
		if not _only.is_empty() and not _only.has(c[1]):
			continue
		if c[0] == "Boss":
			await _run_boss(c[1])
		else:
			await _run_elite(c[0], c[1])
		if _log_size() > LOG_TOTAL_LIMIT:
			print("[qa] 日志超过 %d MB，停下" % (LOG_TOTAL_LIMIT / 1048576))
			break


func _run_elite(lv: String, kind: String) -> void:
	var row := {"lv": lv, "kind": kind, "ok": true, "notes": [], "warns": 0, "states": 0, "errors": 0}
	if lv != "L3" and not ResourceLoader.exists("res://scripts/enemies/%s.gd" % kind):
		row.ok = false
		row.notes.append("脚本不存在")
		_rows.append(row)
		return
	for w in _weapons:
		var r: Dictionary = await _fight_elite(lv, kind, w, false)
		row[w] = r
		row.warns = maxi(row.warns, r.warns)
		row.states = maxi(row.states, r.states)
		row.errors += r.errors
		if not r.ok:
			row.ok = false
			row.notes.append("%s：%s" % [w, r.why])
	var enc: Dictionary = await _fight_elite(lv, kind, "flash", true)
	row["enc"] = enc
	row.errors += enc.errors
	if not enc.ok:
		row.ok = false
		row.notes.append("遭遇战：%s" % enc.why)
	if row.warns < 2:
		row.ok = false
		row.notes.append("红\"!\"只冒了 %d 次" % row.warns)
	if row.states < 3:
		row.ok = false
		row.notes.append("只走过 %d 种状态" % row.states)
	_rows.append(row)
	print("[qa] %s %s：%s" % [lv, kind, "过" if row.ok else "不过 " + "；".join(row.notes)])


## 一次打：fresh 测试关 → 放精英（或一场只有它的遭遇战）→ 用 weapon 打死 → 看真死、清场、错误
func _fight_elite(lv: String, kind: String, weapon: String, with_encounter: bool) -> Dictionary:
	var r := {"ok": true, "why": "", "kill_t": -1.0, "death_t": -1.0, "warns": 0, "states": 0, "errors": 0}
	_reset_world()
	Upgrades.weapon = weapon
	_level = load("res://scenes/test_level.tscn").instantiate()
	add_child(_level)
	await get_tree().physics_frame
	for c in _level.get_children():
		if c is Encounter or c is Crawler:
			c.queue_free()
	L3Mob.arena = Rect2(0, 0, 1100, 500)
	var p: Player = _player()
	var enc: Encounter = null
	var e: Node2D = null
	if with_encounter:
		enc = Encounter.new()
		enc.left = ARENA_L - 15.0
		enc.right = ARENA_R + 12.0
		enc.ceil_y = 222.0
		enc.floor_left = FLOOR_Y
		enc.floor_right = FLOOR_Y
		enc.waves = [[kind]]
		enc.spawn_hook = func(k: String, x: float) -> Node2D:
			var m := _make_elite(lv, k)
			m.position = Vector2(x, 300.0)
			_level.add_child(m)
			return m
		_level.add_child(enc)
		p.global_position = Vector2((ARENA_L + ARENA_R) / 2.0, FLOOR_Y - 1.0)
	else:
		e = _make_elite(lv, kind)
		e.position = Vector2(740.0, 300.0)
		_level.add_child(e)
		p.global_position = Vector2(620.0, FLOOR_Y - 1.0)
	var t := 0.0
	var landed := false
	var last_warn := 0.0
	var states := {}
	var dt := 1.0 / Engine.physics_ticks_per_second   # 工程是 120 物理帧/秒（10-18 前按 60 算，时间全多算了一倍）
	var act := p._act("attack")
	var hold := 0.0
	var tempo := Tempo.new()
	while true:
		await get_tree().physics_frame
		t += dt
		Run.emotion = 0.0
		if e == null and enc != null:
			for a in enc._alive:
				if is_instance_valid(a):
					e = a
		if e == null or not is_instance_valid(e):
			if t > 12.0:
				r.ok = false
				r.why = "没生出来"
				break
			p.global_position = Vector2((ARENA_L + ARENA_R) / 2.0, FLOOR_Y - 1.0)
			continue
		var dead: bool = e.get("dead") == true
		if not landed and (e as CharacterBody2D).is_on_floor() and not e.call("in_intro"):
			landed = true
			if OS.get_cmdline_user_args().has("--verbose"):
				print("[qa]   %s %s 落地 @%s，主角 @%s" % [kind, weapon, e.global_position.round(), p.global_position.round()])
		if not landed and t > 8.0 + (12.0 if with_encounter else 0.0):
			r.ok = false
			r.why = "没落地或出场动画没放完"
			break
		var wt: float = e.get("_warn_t")
		if wt > last_warn + 0.05:
			r.warns += 1
		last_warn = wt
		var st = e.get("state")
		if st == null:
			st = e.get("_state")
		if st != null:
			states[str(st)] = true
			if not dead and landed:
				# 有 _pattern 的精英（第三关 l3_elite.gd：几招共用一个 WARN）按招名数；_pattern 空的时候照状态名
				var pat = e.get("_pattern")
				if pat is String and pat != "":
					tempo.feed(e, pat, dt)
				else:
					tempo.feed(e, st, dt)
		# 主角站到射程上、面朝它、按真的键开火
		if not dead:
			_aim_player(p, e.global_position.x, weapon, ARENA_L + 10.0, ARENA_R - 10.0)
			hold = _press_attack(act, weapon, t, hold, p)
		else:
			Input.action_release(act)
		var hp: float = e.get("hp")
		if hp <= 0.0 and r.kill_t < 0.0:
			r.kill_t = t
		if dead and r.death_t < 0.0:
			r.death_t = t - maxf(r.kill_t, 0.0)
			if not with_encounter:
				break
		if with_encounter and r.death_t >= 0.0:
			if enc.cleared:
				break
			if t - r.kill_t - r.death_t > 8.0:
				r.ok = false
				r.why = "死了 8 秒还没清场"
				break
		if r.kill_t >= 0.0 and r.death_t < 0.0 and t - r.kill_t > 6.0:
			r.ok = false
			r.why = "血空 6 秒还没真死"
			break
		if t > ELITE_TIME + (12.0 if with_encounter else 0.0) and r.kill_t < 0.0:
			r.ok = false
			r.why = "%.0f 秒没打死（剩 %.0f 血）" % [ELITE_TIME, hp]
			break
		if int(t * 60.0) % 120 == 0 and _log_size() - _log_pos > LOG_CASE_LIMIT:
			r.ok = false
			r.why = "日志疯涨"
			break
	Input.action_release(act)
	r.states = states.size()
	print("[qa] 节奏 %s %s%s：%s" % [kind, weapon, "（遭遇战）" if with_encounter else "", tempo.text()])
	_free_world()
	await get_tree().physics_frame
	r.errors = _new_errors()
	if r.errors > 0:
		r.ok = false
		r.why += ("；" if r.why != "" else "") + "%d 条脚本错误" % r.errors
	return r


func _run_boss(key: String) -> void:
	var row := {"lv": "Boss", "kind": key, "ok": true, "notes": [], "warns": 0, "states": 0, "errors": 0}
	for w in _weapons:
		var r: Dictionary = await _fight_boss(key, w)
		row[w] = r
		row.errors += r.errors
		row.states = maxi(row.states, r.phases)
		if not r.ok:
			row.ok = false
			row.notes.append("%s：%s" % [w, r.why])
	_rows.append(row)
	print("[qa] Boss %s：%s" % [key, "过" if row.ok else "不过 " + "；".join(row.notes)])


func _fight_boss(key: String, weapon: String) -> Dictionary:
	var r := {"ok": true, "why": "", "kill_t": -1.0, "death_t": -1.0, "phases": 1, "errors": 0}
	_reset_world()
	Upgrades.weapon = weapon
	_level = load(BOSSES[key]).instantiate()
	add_child(_level)
	await get_tree().physics_frame
	var boss: Node2D = _level.get("boss")
	var p: Player = _player()
	var arena: Rect2 = _level.get("arena") if _level.get("arena") is Rect2 else Rect2(0, 0, 320, 180)
	var act := p._act("attack")
	var t := 0.0
	var dt := 1.0 / Engine.physics_ticks_per_second   # 工程是 120 物理帧/秒（10-18 前按 60 算，时间全多算了一倍）
	var hold := 0.0
	var started := false
	var tempo := Tempo.new()
	p.global_position.x = 100.0
	while true:
		await get_tree().physics_frame
		t += dt
		Run.emotion = 0.0
		if not is_instance_valid(boss):
			r.ok = false
			r.why = "Boss 没了"
			break
		var active: bool = boss.get("active") == true
		var dead: bool = boss.get("dead") == true
		if active:
			started = true
		if not started:
			if p.global_position.x < 90.0:
				p.global_position.x = 100.0
			if t > 20.0:
				r.ok = false
				r.why = "20 秒没开打"
				break
			continue
		r.phases = maxi(r.phases, int(boss.get("phase")))
		if not dead and boss.get("_pattern") != null:
			tempo.feed_boss(str(boss.get("_pattern")), int(boss.get("phase")), dt)
		if not dead:
			_aim_player(p, boss.global_position.x, weapon, arena.position.x + 14.0, arena.end.x - 14.0)
			if key == "boss2" and weapon == "hammer":
				# 总机吊着，地面上的锤子够不着；游戏里提示锤子玩家站长凳（长凳 2：x 108~164，台面 124），这里照做
				p.global_position = Vector2(clampf(boss.global_position.x, 110.0, 162.0), 123.9)
				p.velocity = Vector2.ZERO
				p.facing = 1 if boss.global_position.x > p.global_position.x else -1
			hold = _press_attack(act, weapon, t, hold, p)
		else:
			Input.action_release(act)
		var hp: float = boss.get("hp")
		if hp <= 0.0 and r.kill_t < 0.0:
			r.kill_t = t
		if dead and r.death_t < 0.0 and r.kill_t >= 0.0:
			r.death_t = t - r.kill_t
			break
		if r.kill_t >= 0.0 and t - r.kill_t > 15.0:
			r.ok = false
			r.why = "血空 15 秒还没真死"
			break
		if t > BOSS_TIME and r.kill_t < 0.0:
			r.ok = false
			r.why = "%.0f 秒没打死（剩 %.0f / %.0f 血，到第 %d 阶段）" % [BOSS_TIME, hp, float(boss.get("max_hp")), r.phases]
			break
		if int(t * 60.0) % 120 == 0 and _log_size() - _log_pos > LOG_CASE_LIMIT:
			r.ok = false
			r.why = "日志疯涨"
			break
	Input.action_release(act)
	if tempo.starts.size() > 0:
		print("[qa] 节奏 %s %s：%s" % [key, weapon, tempo.text()])
	if r.ok and r.phases < 3:
		r.ok = false
		r.why = "只到第 %d 阶段" % r.phases
	_free_world()
	await get_tree().physics_frame
	r.errors = _new_errors()
	if r.errors > 0:
		r.ok = false
		r.why += ("；" if r.why != "" else "") + "%d 条脚本错误" % r.errors
	return r


# —— 小工具 ——

## 量节奏：每种招式起了几次、两招之间空了多久（见文件开头"节奏"）
class Tempo:
	const IDLE := ["MOVE", "IDLE", "WALK", "RECOVER", "CHASE", "APPROACH", "HOVER", "WAIT", "REST", "PACE", "INTRO", "NONE", "",
			"DRIVE", "SHUFFLE", "STUN"]
	var starts := {}
	## 无名 enum（enum { WALK, WARN, … }）从源码里读出来的名字表，按脚本缓存
	var _anon := {}
	var gaps: Array[float] = []
	var _prev := ""
	var _idle_t := -1.0

	func _name(e: Object, st) -> String:
		if st is String:
			return st
		var m: Dictionary = e.get_script().get_script_constant_map() if e.get_script() else {}
		for k in ["State", "S"]:
			if m.get(k) is Dictionary:
				for n in m[k]:
					if m[k][n] == st:
						return n
		# 无名 enum：常量表里只有一堆 int，认不出哪个是状态，从源码里找 enum { … }（布谷鸟钟会话 10-18 报的）
		if st is int:
			var names := _anon_names(e.get_script())
			if st >= 0 and st < names.size():
				return names[st]
		return str(st)

	## 脚本（连同父类）里的无名 enum：有好几个时取里面带 IDLE 表里名字的那个
	func _anon_names(sc: Script) -> Array:
		if sc == null:
			return []
		if _anon.has(sc):
			return _anon[sc]
		var best: Array = []
		var re := RegEx.create_from_string("(?m)^enum\\s*\\{([^}]*)\\}")
		var cur := sc
		while cur != null and best.is_empty():
			for hit in re.search_all(cur.source_code):
				var names: Array = []
				var body := RegEx.create_from_string("#[^\\n]*").sub(hit.get_string(1), "", true)
				for part in body.split(","):
					var n := part.strip_edges()
					if n == "":
						continue
					var eq := n.find("=")
					if eq >= 0:
						var v := int(n.substr(eq + 1).strip_edges())
						n = n.substr(0, eq).strip_edges()
						while names.size() < v:
							names.append("")
					names.append(n)
				if best.is_empty() or names.any(func(x): return IDLE.has(x)):
					best = names
			cur = cur.get_base_script()
		_anon[sc] = best
		return best

	func feed(e: Object, st, dt: float) -> void:
		_step(_name(e, st), dt)

	## Boss：_pattern 是正在放的招（空 = 招和招之间）
	func feed_boss(pattern: String, phase: int, dt: float) -> void:
		_step("" if pattern == "" else "%s@%d" % [pattern, phase], dt)

	var _t := 0.0

	func _step(n: String, dt: float) -> void:
		_t += dt
		if n != _prev and OS.get_cmdline_user_args().has("--tempo-log"):
			print("[qa]     %.2f %s → %s（time_scale %.2f）" % [_t, _prev, n, Engine.time_scale])
		var idle := IDLE.has(n.to_upper())
		if idle:
			if _idle_t >= 0.0:
				_idle_t += dt
		elif n != _prev:
			if _prev == "" or IDLE.has(_prev.to_upper()):
				starts[n] = starts.get(n, 0) + 1
				if _idle_t > 0.0:
					gaps.append(_idle_t)
			_idle_t = 0.0
		_prev = n

	func text() -> String:
		var parts: Array[String] = []
		var ks := starts.keys()
		ks.sort()
		for k in ks:
			parts.append("%s×%d" % [k, starts[k]])
		var avg := 0.0
		var mx := 0.0
		for g in gaps:
			avg += g
			mx = maxf(mx, g)
		if gaps.size() > 0:
			avg /= gaps.size()
		return "%s；空档 平均 %.1f / 最长 %.1f 秒（%d 次）" % [" ".join(parts), avg, mx, gaps.size()]

func _make_elite(lv: String, kind: String) -> Node2D:
	var e: Node2D
	if lv == "L3":
		e = L3Mob.make(kind, "color")
	else:
		e = (load("res://scripts/enemies/%s.gd" % kind) as GDScript).new()
	e.set("respawn_time", 0.0)
	return e


func _player() -> Player:
	for n in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(n) and n.is_inside_tree():
			return n as Player
	return null


## 主角站到目标左边（左边站不下就右边）这把武器的射程上，面朝目标
func _aim_player(p: Player, tx: float, weapon: String, lo: float, hi: float) -> void:
	var rng: float = RANGE.get(weapon, float(WeaponRegistry.value(weapon, "qa_range", 60.0)))
	var px := tx - rng
	if px < lo:
		px = tx + rng
	px = clampf(px, lo, hi)
	p.global_position.x = px
	p.velocity.x = 0.0
	if absf(tx - px) > 1.0:
		p.facing = 1 if tx > px else -1


## 按真的攻击键：闪光灯按住蓄满再松开，铆钉枪一直按住，蒸汽锤隔一会儿点一下。返回按住了多久
func _press_attack(act: String, weapon: String, t: float, hold: float, p: Player) -> float:
	var dt := 1.0 / Engine.physics_ticks_per_second   # 工程是 120 物理帧/秒（10-18 前按 60 算，时间全多算了一倍）
	match weapon:
		"rivet":
			Input.action_press(act)
			return hold + dt
		"hammer":
			if int(t / 0.25) != int((t - dt) / 0.25):
				Input.action_press(act)
			else:
				Input.action_release(act)
			return 0.0
	# 新武器：照登记表的 qa_press 按——hold 一直按住，tap 隔 0.15 秒点一下，charge 按住到 p.charge 满再松开一下
	if WeaponRegistry.handler_path(weapon) != "":
		match str(WeaponRegistry.value(weapon, "qa_press", "hold")):
			"tap":
				if int(t / 0.15) != int((t - dt) / 0.15):
					Input.action_press(act)
				else:
					Input.action_release(act)
				return 0.0
			"charge":
				if hold < 0.0:
					Input.action_release(act)
					return hold + dt
				Input.action_press(act)
				if float(p.get("charge")) >= 1.0:
					return -dt * 2.0
				return hold + dt
		Input.action_press(act)
		return hold + dt
	# 闪光灯
	if hold < 0.0:
		Input.action_release(act)
		return hold + dt
	Input.action_press(act)
	hold += dt
	if hold >= p.charge_time() + 0.05:
		Input.action_release(act)
		return -0.1
	return hold


func _reset_world() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	Run.emotion = 0.0
	if "crystal_hp" in Run:
		Run.crystal_hp = Run.crystal_max


func _free_world() -> void:
	if is_instance_valid(_level):
		_level.queue_free()
	_level = null
	Engine.time_scale = 1.0


func _log_size() -> int:
	if _log_path == "" or not FileAccess.file_exists(_log_path):
		return 0
	var f := FileAccess.open(_log_path, FileAccess.READ)
	return f.get_length() if f else 0


## 上次看过以后日志里新冒出来的脚本错误条数
func _new_errors() -> int:
	if _log_path == "" or not FileAccess.file_exists(_log_path):
		return 0
	var f := FileAccess.open(_log_path, FileAccess.READ)
	if f == null:
		return 0
	var size := f.get_length()
	if size <= _log_pos:
		_log_pos = size
		return 0
	f.seek(_log_pos)
	var text := f.get_buffer(mini(size - _log_pos, 8 * 1024 * 1024)).get_string_from_utf8()
	_log_pos = size
	return text.count("SCRIPT ERROR") + text.count("Parse Error")


# —— 表 ——

func _cell(r) -> String:
	if not (r is Dictionary):
		return "—"
	if not r.ok:
		return "✗ " + r.why
	return "%.0f 秒" % r.kill_t


func _report() -> void:
	var lines: Array[String] = []
	# 每把武器一列（列名用登记表的中文名，没有就用 id）
	var wnames := {"flash": "闪光灯", "rivet": "铆钉枪", "hammer": "蒸汽锤", "shotgun": "霰弹枪", "laser": "激光枪",
			"record": "唱片", "tongs": "电钳"}
	var head := "| 关 | 怪 | 结果 |"
	var sep := "|---|---|---|"
	for w in _weapons:
		head += " %s |" % wnames.get(w, w)
		sep += "---|"
	lines.append(head + " 遭遇战清场 | 红\"!\"次数 / 状态数（Boss：到第几阶段） | 死亡演出（秒） | 脚本错误 |")
	lines.append(sep + "---|---|---|---|")
	var bad := 0
	for row in _rows:
		if not row.ok:
			bad += 1
		var death := "—"
		var r0 = row.get("flash", row.get("rivet", row.get("hammer", null)))
		if r0 is Dictionary and r0.death_t >= 0.0:
			death = "%.1f" % r0.death_t
		var enc := "—"
		if row.has("enc"):
			enc = "✓ 清场" if row.enc.ok else "✗ " + row.enc.why
		var ws := "%d / %d" % [row.warns, row.states] if row.lv != "Boss" else "第 %d 阶段" % row.states
		var line := "| %s | %s | %s |" % [row.lv, row.kind, "过" if row.ok else "不过"]
		for w in _weapons:
			line += " %s |" % _cell(row.get(w))
		lines.append(line + " %s | %s | %s | %d |" % [enc, ws, death, row.errors])
	lines.append("")
	lines.append("共 %d 只，过 %d，不过 %d。" % [_rows.size(), _rows.size() - bad, bad])
	print("\n".join(lines))
	if _out != "":
		var f := FileAccess.open(_out, FileAccess.WRITE)
		if f:
			f.store_string("\n".join(lines) + "\n")
	get_tree().quit(1 if bad > 0 else 0)
