class_name TubeRun
extends Node2D
## 第二关开场「气动管冲刺」（10-17 作者从三个开场方案里挑的 B）：
## 一开场就坐在黄铜胶囊里，沿交换局大厅上空三条平行的玻璃管高速往前冲，约 40 秒。
## - 上 / 下换管（跳键 = 上，下键 = 下；手柄 A / 十字键或摇杆上下）。换道很快，带一点弹簧惯性和"嗖"一声。
## - 关着的阀门（红圈）把一条管堵死，撞上扣马灯；漏电火花一闪一闪，亮着的时候碰到也扣。
##   障碍进画面之前，那条管的右端先闪红色"!"，看得清、来得及。
## - 管里的齿轮零件顺手吃（商店的钱，全程 4 个，每段一个；第二关还有藏起来的 3 个和 6 场遭遇战各掉 1 个，别把商店的钱冲乱）；踩上黄色箭头加速 2 秒（加速期间不出障碍）。
## - 前 10 秒教换道，之后两条管一起堵、加火花，后段更密，最后一段加速冲刺。
## - 中途有存档点（CHECKPOINT）：马灯碎了从存档点重来，没到存档点就从管道起点重来。
## - 终点：管子往下一折，胶囊砸穿接线员大厅的天花板，直接落进埋伏（level2.gd 的落地演出，落地就开打）。
## - 双人：每人一只胶囊，前后错开，各换各的道，马灯共用一盏（Run 的血量）。
## 速度感：远景、中景两张循环背景按 0.15 / 0.45 倍速卷，管壁上的铜箍和前景的钢梁按 1 / 1.6 倍速闪过，加速时出速度线。
## 单独打开：Godot --path . scenes/level2_tube.tscn；调试：-- --tubeauto（自动驾驶）、--tubeat=<距离>（从中途开始）

const L2 := preload("res://scripts/levels/level2.gd")
const LEVEL_SCENE := "res://scenes/level2.tscn"
const FAR_TEX := preload("res://art/levels/level2_tube_far.png")
const MID_TEX := preload("res://art/levels/level2_tube_mid.png")
## 管里的风（草图/第二关/level2_sfx.py 合成的 2 秒循环），音量、音高跟着速度走
const WIND := preload("res://sfx/level2_tube_wind.wav")
## 开场动画：胶片很快地卷过去、卡住、烧白，接着就是管道冲刺（只在第一次进来时播）
const INTRO := preload("res://scripts/levels/level2_intro.gd")

const LANES: Array[float] = [104.0, 140.0, 176.0]
const TUBE_R := 9.0
const CAP_X := 150.0
const BASE_SPEED := 250.0
const BOOST_SPEED := 430.0
const HIT_SPEED := 140.0
const BOOST_TIME := 2.0
const COURSE_END := 11200.0
const CHECKPOINT_D := 5600.0
const HIT_DAMAGE := 6.0
const INVULN := 1.2
## 障碍离胶囊多远开始在管子右端闪"!"
const WARN_AHEAD := 520.0
## 换道的弹簧：越硬越快，阻尼小一点会稍微冲过头再回来
const SPRING := 900.0
const DAMP := 38.0
const SPARK_PERIOD := 1.2
const SPARK_ON := 0.55

## 从存档点重来时从这里开始（换关时清零）
static var resume_d := 0.0

var dist := 0.0
var speed := BASE_SPEED
var hud: Hud
var caps: Array[Cap] = []
## 赛道：{d, kind: valve/spark/part/boost/tip/cp, lane, phase, done}
var course: Array = []
var _time := 0.0
var _boost_t := 0.0
var _slow_t := 0.0
var _ending := false
var _retrying := false
var _auto := false
var _far: Sprite2D
var _mid: Sprite2D
var _track: Track
var _cam: Camera2D
var _switches := 0
var _hits := 0
var _near := 0
var _wind: AudioStreamPlayer
var _debug_start := false
var _dmg_mul := 1.0
var _human := false
const HUMAN_SIGHT := 520.0
var _react := 0.3
var _log_t := 0.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--players=") and Run.players.size() == 1:
			var n := clampi(arg.trim_prefix("--players=").to_int(), 1, 4)
			var schemes := ["kb_left", "kb_right", "pad0", "pad1"]
			Run.players.clear()
			for i in n:
				Run.players.append({"input": schemes[i], "skin": Run.SKINS[i]})
			Run.reset_run()
		if arg == "--tubeauto":
			_auto = true
		if arg.begins_with("--tubereact="):
			_react = arg.trim_prefix("--tubereact=").to_float()
		if arg == "--tubehuman":
			_auto = true
			_human = true               # 调试：像人一样的自动驾驶，只看得到画面里 + "!" 预警的距离，反应慢 0.3 秒
		if arg == "--tubehard":
			_dmg_mul = 10.0             # 调试：撞一下扣十倍，测马灯碎了以后从存档点重来
		if arg.begins_with("--tubeat="):
			resume_d = arg.trim_prefix("--tubeat=").to_float()
			_debug_start = true
	# 要在 start_level 之前看：它会把"正在重来"的标记清掉
	var play_intro: bool = INTRO.wanted()
	Run.start_level()
	Run.crystal_broken.connect(_on_crystal_broken)
	dist = resume_d
	_build_course()

	_far = _bg(FAR_TEX, -20)
	_mid = _bg(MID_TEX, -19)
	_track = Track.new()
	_track.run = self
	add_child(_track)

	for i in Run.players.size():
		var c := Cap.new()
		c.input = Run.players[i]["input"]
		c.skin = Run.players[i]["skin"]
		c.x = CAP_X - i * 26.0
		c.lane = 1
		c.y = LANES[1]
		caps.append(c)

	_cam = Camera2D.new()
	_cam.position = Vector2(240, 135)
	add_child(_cam)
	_cam.make_current()

	hud = Hud.new()
	add_child(hud)
	hud.show_hint = false

	_wind = AudioStreamPlayer.new()
	_wind.stream = TubeRun.looped(WIND)
	_wind.volume_db = -60.0
	add_child(_wind)
	_wind.play()
	Game.sfx("suction", -6.0, 0.9)
	# 开场不打"冲进气动管"横幅：它正好压在中间那条管上，玩家这时候正在学换道（10-18 夜间打磨）
	if resume_d > 0.0 and not _debug_start:
		hud.show_banner("CHECKPOINT", 0.8)
	if play_intro:
		add_child(INTRO.new())


func _bg(tex: Texture2D, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, 480, 270)
	s.z_index = z
	add_child(s)
	return s


## 赛道（距离按像素算；底速每秒 250，全程约 40 秒）
func _build_course() -> void:
	var c := course
	var v := func(d: float, lanes: Array) -> void:
		for l in lanes:
			c.append({"d": d, "kind": "valve", "lane": l})
	var sp := func(d: float, lane: int, phase := 0.0) -> void:
		c.append({"d": d, "kind": "spark", "lane": lane, "phase": phase})
	var parts := func(d: float, lane: int, n := 3) -> void:
		for k in n:
			c.append({"d": d + k * 40.0, "kind": "part", "lane": lane})
	# ---- 0~10 秒：教换道。一次只堵一条管，空得很开
	c.append({"d": 260.0, "kind": "tip", "lane": 1})
	v.call(1000.0, [1])
	parts.call(1450.0, 0, 1)
	v.call(1900.0, [0])
	v.call(2600.0, [2])
	# ---- 10~22 秒：两条管一起堵，开始有火花
	v.call(3150.0, [0, 1])
	v.call(3650.0, [1, 2])
	sp.call(4000.0, 1, 0.0)
	v.call(4350.0, [0, 2])
	sp.call(4750.0, 0, 0.3)
	sp.call(4750.0, 2, 0.9)
	c.append({"d": 4950.0, "kind": "boost", "lane": 1})
	parts.call(5250.0, 1, 1)
	c.append({"d": CHECKPOINT_D, "kind": "cp", "lane": 1})
	# ---- 22~34 秒：更密（10-18 夜间打磨：像人一样反应 0.5 秒的自动驾驶也一下没撞到，太松了）。
	#      隔 260~280 像素一堵墙，常有"连换两次道"（2 → 0、0 → 2），火花穿插；底速也从 250 慢慢加到 300
	v.call(6000.0, [0, 1])
	v.call(6280.0, [1, 2])
	sp.call(6560.0, 0, 0.0)
	v.call(6560.0, [2])
	v.call(6840.0, [0, 2])
	sp.call(7100.0, 1, 0.4)
	v.call(7100.0, [0])
	v.call(7360.0, [1, 2])
	v.call(7640.0, [0, 1])
	parts.call(7680.0, 2, 1)
	sp.call(7900.0, 2, 0.7)
	v.call(7900.0, [0])
	v.call(8200.0, [0, 2])
	v.call(8460.0, [0, 1])
	v.call(8720.0, [1, 2])
	v.call(9050.0, [0, 2])
	# ---- 最后一段：加速冲刺，零件一串，只零星堵一下
	c.append({"d": 9350.0, "kind": "boost", "lane": 1})
	parts.call(9700.0, 1, 1)
	v.call(10650.0, [0, 2])         # 等加速结束再堵（10-18：原来 10400 落在加速里，预警只剩 1.2 秒）
	c.sort_custom(func(a, b): return a["d"] < b["d"])
	for e in c:
		e["done"] = e["d"] < resume_d


func _physics_process(delta: float) -> void:
	_time += delta
	# 过了存档点以后底速慢慢加快，到 9000 处是 300
	var target := BASE_SPEED + 50.0 * clampf((dist - CHECKPOINT_D) / (9000.0 - CHECKPOINT_D), 0.0, 1.0)
	if _boost_t > 0.0:
		_boost_t -= delta
		target = BOOST_SPEED
	if _slow_t > 0.0:
		_slow_t -= delta
		target = HIT_SPEED
	speed = lerpf(speed, target, 1.0 - exp(-4.0 * delta))
	if not _ending:
		dist += speed * delta

	for i in caps.size():
		var cap := caps[i]
		if not _ending:
			if _auto:
				_autopilot(cap)
			else:
				_read_input(cap)
		var ty := LANES[cap.lane]
		cap.vy += (SPRING * (ty - cap.y) - DAMP * cap.vy) * delta
		cap.y += cap.vy * delta
		cap.invuln = maxf(cap.invuln - delta, 0.0)

	if not _ending:
		_collide()
		if dist >= COURSE_END:
			_finish()

	if _wind:
		var k := clampf((speed - 140.0) / (BOOST_SPEED - 140.0), 0.0, 1.0)
		var target_db := -60.0 if _ending else lerpf(-22.0, -11.0, k)
		_wind.volume_db = move_toward(_wind.volume_db, target_db, delta * 40.0)
		_wind.pitch_scale = lerpf(0.85, 1.35, k)
	_far.region_rect.position.x = dist * 0.15
	_mid.region_rect.position.x = dist * 0.45
	_cam.offset = Game.shake_offset(1.0)
	_track.queue_redraw()
	if _auto:
		_log_t += delta
		if _log_t >= 2.0:
			_log_t = 0.0
			print("[tube] t=%.1f dist=%.0f speed=%.0f lanes=%s hits=%d hp=%.0f parts=%d" % [_time, dist, speed,
				caps.map(func(c): return c.lane), _hits, Run.crystal_hp, Run.parts])


func _read_input(cap: Cap) -> void:
	var up := Input.is_action_just_pressed(cap.input + "_jump")
	var down := Input.is_action_just_pressed(cap.input + "_down")
	# 手柄摇杆往上 / 十字键上（Controls 没有"上"这个动作，这里直接读）
	var pads: Array = Input.get_connected_joypads() if cap.input == "solo" else []
	if cap.input.begins_with("pad"):
		pads = [cap.input.trim_prefix("pad").to_int()]
	var stick_up := false
	for d in pads:
		if Input.get_joy_axis(d, JOY_AXIS_LEFT_Y) < -0.6 or Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_UP):
			stick_up = true
	if stick_up and not cap.stick_up:
		up = true
	cap.stick_up = stick_up
	if up:
		_switch(cap, -1)
	elif down:
		_switch(cap, 1)


func _switch(cap: Cap, dir: int) -> void:
	var to := clampi(cap.lane + dir, 0, LANES.size() - 1)
	if to == cap.lane:
		cap.vy += dir * 60.0          # 撞到最边上那条管的管壁，弹一下
		Game.sfx("clang", -18.0, 1.8, 0.1)
		return
	cap.lane = to
	cap.vy += dir * 120.0
	cap.switch_t = _time
	_switches += 1
	Game.sfx("scrape", -12.0, 2.2, 0.1)


## 自动驾驶（调试）：往前看 700 像素，挑最晚撞到东西的那条管，顺路吃零件
func _autopilot(cap: Cap) -> void:
	if _human and cap.react_t > 0.0:
		cap.react_t -= get_physics_process_delta_time()
		if cap.react_t <= 0.0 and cap.react_dir != 0:
			_switch(cap, cap.react_dir)
			cap.react_dir = 0
		return
	if absf(cap.y - LANES[cap.lane]) > 3.0:
		return
	var sight := HUMAN_SIGHT if _human else 900.0
	var best := cap.lane
	var best_score := -INF
	for l in LANES.size():
		var clear := sight
		var bonus := 0.0
		for e in course:
			if e["done"] or e["lane"] != l:
				continue
			# 按这只胶囊自己的位置算（双人时后面那只落后 26 像素）
			var ahead: float = e["d"] - (dist - (CAP_X - cap.x))
			if ahead < -10.0 or ahead > sight:
				continue
			if e["kind"] in ["valve", "spark"]:
				clear = minf(clear, ahead)
			elif e["kind"] == "part" and ahead < 400.0:
				bonus += 30.0
		var score := clear + bonus - absf(l - cap.lane) * 40.0
		if score > best_score:
			best_score = score
			best = l
	if best != cap.lane:
		if _human:
			cap.react_dir = signi(best - cap.lane)
			cap.react_t = _react
		else:
			_switch(cap, signi(best - cap.lane))


func _collide() -> void:
	for e in course:
		if e["done"]:
			continue
		var ahead: float = e["d"] - dist
		if ahead > 20.0:
			break
		match e["kind"]:
			"tip":
				e["done"] = true
				hud.get("_coach").call("_want", "tube")
			"cp":
				e["done"] = true
				resume_d = CHECKPOINT_D
				hud.show_banner("CHECKPOINT", 0.8)
				Game.sfx("ready", -8.0)
			_:
				for cap in caps:
					var dx: float = e["d"] - (dist - (CAP_X - cap.x))
					_near_miss(e, cap, dx)
					if absf(dx) > 9.0 or absf(cap.y - LANES[e["lane"]]) > 9.0:
						continue
					_touch(e, cap)
				if ahead < -30.0:
					e["done"] = true


## 擦边：刚换进旁边那条管（0.6 秒内），阀门或亮着的火花就贴着胶囊擦过去 →
## 胶囊边蹦一串火花、"嗖"一声、画面轻轻一抖。只奖励，不扣不加别的（10-18 夜间打磨，管道冲刺的爽感）
func _near_miss(e: Dictionary, cap: Cap, dx: float) -> void:
	if not (e["kind"] == "valve" or (e["kind"] == "spark" and spark_on(e))) or e.get("broken", false):
		return
	if absf(dx) > 3.0 or absi(int(e["lane"]) - cap.lane) != 1 or _time - cap.switch_t > 0.6:
		return
	var key := "nm%d" % caps.find(cap)
	if e.get(key, false):
		return
	e[key] = true
	_near += 1
	var side := signf(LANES[e["lane"]] - cap.y)
	Game.sparks(self, Vector2(cap.x, cap.y + side * 6.0), Color8(255, 220, 150), 7, 70.0, Vector2(-1, side * 0.4))
	Game.sfx("scrape", -9.0, 2.8, 0.1)
	Game.add_shake(1.5)


func _touch(e: Dictionary, cap: Cap) -> void:
	match e["kind"]:
		"part":
			e["done"] = true
			Run.add_part(1)
			Game.sfx("ding", -10.0, 1.6, 0.1)
		"boost":
			e["done"] = true
			_boost_t = BOOST_TIME
			Game.sfx("whistle", -6.0, 1.5)
			Game.add_shake(2.0)
		"valve", "spark":
			if e["kind"] == "spark" and not spark_on(e):
				return
			if cap.invuln > 0.0:
				return
			if e["kind"] == "valve":
				e["done"] = true            # 撞开了，不会卡住
				e["broken"] = true
			cap.invuln = INVULN
			_hits += 1
			if _auto:
				print("[tube] hit cap x=%.0f lane=%d y=%.1f by %s lane %d at d=%.0f dist=%.0f" % [cap.x, cap.lane, cap.y, e["kind"], e["lane"], e["d"], dist])
			_slow_t = 0.5
			Run.damage_crystal(HIT_DAMAGE * _dmg_mul)
			Game.sfx("crack", -4.0, 0.9)
			Game.flash(Color(1, 0.3, 0.2), 0.18, 0.35)
			Game.add_shake(5.0)
			Game.sparks(self, Vector2(cap.x + 8.0, cap.y), Color8(255, 190, 120), 10, 90.0)


## 把一段 wav 设成首尾循环（导入设置默认不循环；复制一份，不改共享资源）
static func looped(src: AudioStreamWAV) -> AudioStreamWAV:
	var st := src.duplicate() as AudioStreamWAV
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	# 循环终点按采样数算：导入时默认压成 QOA，字节数不等于采样数，所以用时长 × 采样率
	st.loop_end = int(round(st.get_length() * st.mix_rate))
	return st


func spark_on(e: Dictionary) -> bool:
	return fmod(_time + float(e.get("phase", 0.0)), SPARK_PERIOD) < SPARK_ON


## 终点：管子往下一折，胶囊冲出画面往下掉 → 切到第二关，砸穿接线员大厅的天花板
func _finish() -> void:
	_ending = true
	print("[tube] finished t=%.1f hits=%d near_misses=%d hp=%.0f parts=%d" % [_time, _hits, _near, Run.crystal_hp, Run.parts])
	resume_d = 0.0
	Game.sfx("boom", -6.0, 0.8)
	Game.add_shake(6.0)
	for cap in caps:
		var tw := create_tween()
		tw.tween_property(cap, "x", 430.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(cap, "drop", 160.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# 调试 --tubeendretry：终点往下掉的途中试暂停、按重来，都应该没反应
	if OS.get_cmdline_user_args().has("--tubeendretry"):
		print("[tube] at end: pause can_open=%s" % Game.pause_menu.can_open())
		_retry()
		print("[tube] at end: after retry retrying=%s" % _retrying)
	await get_tree().create_timer(0.35, false).timeout
	L2.tube_landing = true
	SceneFade.go(get_tree(), LEVEL_SCENE, 0.25, 0.05, 0.25)


## 暂停菜单的"重开本关"（有这个函数菜单才显示）：从管道起点重来，不用中途存档点
func _retry() -> void:
	# 终点已经往下掉、正在切到第二关：不许重来
	if _retrying or _ending:
		return
	_retrying = true
	resume_d = 0.0
	Engine.time_scale = 1.0
	get_tree().paused = false
	Run.retry_level()
	get_tree().reload_current_scene()


func _on_crystal_broken() -> void:
	if _retrying or _ending:
		return
	_retrying = true
	print("[tube] crystal broken at dist=%.0f, resume from %.0f" % [dist, resume_d])
	hud.show_banner("THE TAPE IS RUINED")
	Game.flash(Color(0.9, 0.9, 0.95), 0.5, 1.2)
	Game.add_shake(5.0)
	get_tree().paused = true
	await get_tree().create_timer(1.4, true, false, true).timeout
	get_tree().paused = false
	Run.retry_level()
	get_tree().reload_current_scene()


## 一只胶囊（一个玩家）
class Cap extends RefCounted:
	var input := "solo"
	var skin := "red"
	var lane := 1
	var x := 150.0
	var y := 140.0
	var vy := 0.0
	var invuln := 0.0
	var stick_up := false
	## 上一次换道的时间（擦边判定用）
	var switch_t := -10.0
	## 调试用"像人一样"的自动驾驶：看到以后过多久才换
	var react_t := 0.0
	var react_dir := 0
	## 终点往下掉的距离
	var drop := 0.0


## 管子、障碍、胶囊、前景都在这里画（每帧重画；比一堆节点省）
class Track extends Node2D:
	const GLASS := Color8(50, 46, 43)
	const GLASS_LO := Color8(30, 28, 27)
	const GLASS_HI := Color8(120, 114, 104)
	const EDGE := Color8(136, 128, 118)
	const RING := Color8(105, 95, 62)
	const RING_HI := Color8(150, 132, 84)
	const VALVE := Color8(170, 52, 40)
	const VALVE_HI := Color8(230, 110, 80)
	const SPARK := Color8(255, 230, 150)
	const PART := Color8(220, 180, 90)
	const SKIN_COL := {"red": Color8(200, 40, 40), "robot": Color8(190, 140, 70), "bird": Color8(70, 120, 220), "dino": Color8(80, 170, 70)}
	var run: TubeRun

	func _draw() -> void:
		var d := run.dist
		# 三条玻璃管（后半边）+ 铜箍按 1 倍速闪过
		for ly in TubeRun.LANES:
			draw_rect(Rect2(0, ly - TubeRun.TUBE_R, 480, TubeRun.TUBE_R * 2.0), GLASS)
			draw_rect(Rect2(0, ly + 3, 480, TubeRun.TUBE_R - 3), GLASS_LO)
			draw_rect(Rect2(0, ly - TubeRun.TUBE_R, 480, 1), EDGE)
			draw_rect(Rect2(0, ly + TubeRun.TUBE_R - 1, 480, 1), EDGE)
			var off := fposmod(d, 96.0)
			var x := -off
			while x < 480.0:
				draw_rect(Rect2(roundf(x), ly - TubeRun.TUBE_R - 1, 3, TubeRun.TUBE_R * 2.0 + 2), RING)
				draw_rect(Rect2(roundf(x), ly - TubeRun.TUBE_R - 1, 1, TubeRun.TUBE_R * 2.0 + 2), RING_HI)
				x += 96.0
		# 管与管之间的支架
		var off2 := fposmod(d, 240.0)
		var sx := -off2
		while sx < 480.0:
			draw_rect(Rect2(roundf(sx) + 20, TubeRun.LANES[0] + TubeRun.TUBE_R, 4, TubeRun.LANES[2] - TubeRun.LANES[0] - TubeRun.TUBE_R * 2.0), Color8(60, 55, 50))
			sx += 240.0
		# 障碍、零件、加速板
		for e in run.course:
			var ex: float = TubeRun.CAP_X + (e["d"] - d)
			var ly: float = TubeRun.LANES[e["lane"]]
			if e.get("broken", false):
				if ex > -20.0 and ex < 500.0:
					draw_rect(Rect2(roundf(ex) - 2, ly - 9, 4, 3), VALVE)       # 撞开的阀门残片
					draw_rect(Rect2(roundf(ex) - 2, ly + 6, 4, 3), VALVE)
				continue
			if e["done"] and e["kind"] != "valve":
				continue
			if ex > 480.0:
				# 还没进画面：管子右端闪"!"预警
				if e["kind"] in ["valve", "spark"] and ex - 480.0 < TubeRun.WARN_AHEAD - 330.0 and int(run._time * 8.0) % 2 == 0:
					draw_rect(Rect2(452, ly - TubeRun.TUBE_R, 28, TubeRun.TUBE_R * 2.0), Color(0.9, 0.25, 0.15, 0.35))
					draw_rect(Rect2(468, ly - 7, 4, 9), VALVE_HI)
					draw_rect(Rect2(468, ly + 4, 4, 3), VALVE_HI)
				continue
			if ex < -20.0:
				continue
			match e["kind"]:
				"valve":
					draw_rect(Rect2(roundf(ex) - 4, ly - 11, 8, 22), VALVE)
					draw_rect(Rect2(roundf(ex) - 4, ly - 11, 8, 2), VALVE_HI)
					draw_rect(Rect2(roundf(ex) - 1, ly - 7, 2, 14), Color8(90, 30, 24))
					draw_rect(Rect2(roundf(ex) - 6, ly - 14, 12, 3), Color8(100, 96, 90))   # 阀门手轮
				"spark":
					var on := run.spark_on(e)
					draw_rect(Rect2(roundf(ex) - 3, ly - 11, 6, 3), Color8(100, 96, 90))
					draw_rect(Rect2(roundf(ex) - 3, ly + 8, 6, 3), Color8(100, 96, 90))
					if on:
						var j := int(run._time * 30.0) % 3
						for k in 5:
							draw_rect(Rect2(roundf(ex) - 1 + ((k + j) % 3) - 1, ly - 8 + k * 3, 2, 3), SPARK)
					elif int(run._time * 12.0) % 4 == 0:
						draw_rect(Rect2(roundf(ex), ly - 8, 1, 1), SPARK)
						draw_rect(Rect2(roundf(ex) - 1, ly + 7, 1, 1), SPARK)
				"part":
					draw_rect(Rect2(roundf(ex) - 2, ly - 2, 5, 5), PART)
					draw_rect(Rect2(roundf(ex) - 1, ly - 1, 3, 3), Color8(120, 90, 40))
					draw_rect(Rect2(roundf(ex), ly - 3, 1, 1), PART)
					draw_rect(Rect2(roundf(ex), ly + 3, 1, 1), PART)
				"boost":
					for k in 3:
						var ax := roundf(ex) + k * 6
						PixelDraw.line(self, Vector2(ax, ly - 5), Vector2(ax + 4, ly), PART)
						PixelDraw.line(self, Vector2(ax, ly + 5), Vector2(ax + 4, ly), PART)
		# 胶囊（马灯在里面，外面一圈暖光）
		for cap in run.caps:
			var hc := Vector2(roundf(cap.x), roundf(cap.y + cap.drop))
			PixelDraw.disc(self, hc, 26.0, Color(1.0, 0.8, 0.5, 0.05))
			PixelDraw.disc(self, hc, 16.0, Color(1.0, 0.8, 0.5, 0.07))
		for cap in run.caps:
			if cap.invuln > 0.0 and int(cap.invuln * 12.0) % 2 == 0:
				continue
			var cy := roundf(cap.y + cap.drop)
			var cx := roundf(cap.x)
			var tilt := clampf(cap.vy / 200.0, -1.0, 1.0)
			draw_rect(Rect2(cx - 8, cy - 5, 16, 10), Color8(134, 117, 63))
			draw_rect(Rect2(cx - 8, cy - 5, 16, 1), Color8(170, 150, 92))
			draw_rect(Rect2(cx - 8, cy + 4, 16, 1), Color8(80, 66, 34))
			draw_rect(Rect2(cx + 6, cy - 4 + roundf(tilt), 3, 8), Color8(100, 96, 90))     # 鼻子
			draw_rect(Rect2(cx - 3, cy - 3, 7, 5), Color8(30, 28, 30))                      # 舷窗
			draw_rect(Rect2(cx - 1, cy - 3, 3, 5), SKIN_COL.get(cap.skin, Color8(200, 40, 40)))
			draw_rect(Rect2(cx + 2, cy - 1, 1, 2), Color8(250, 220, 150))                  # 马灯
			if run.speed > 300.0:
				for k in 3:
					draw_rect(Rect2(cx - 18 - k * 9, cy - 3 + k * 3, 6 + k * 2, 1), Color8(220, 210, 190, 120))
		# 玻璃管前半边的高光（压在胶囊上面，像隔着玻璃）
		for ly in TubeRun.LANES:
			draw_rect(Rect2(0, ly - TubeRun.TUBE_R + 2, 480, 1), Color(GLASS_HI, 0.55))
		# 前景钢梁按 1.6 倍速擦过（很暗的剪影）。三条道那一段只留很淡的影子，不挡障碍（10-18 新玩家报告：
		# 原来整根黑的，正好挡住阀门时那一下看不见）；道的上下各留一截实的，加一块铆着的连接板
		var off3 := fposmod(d * 1.6, 700.0)
		var gx := roundf(480.0 - off3)
		var band0 := TubeRun.LANES[0] - TubeRun.TUBE_R - 6.0
		var band1 := TubeRun.LANES[TubeRun.LANES.size() - 1] + TubeRun.TUBE_R + 6.0
		for seg in [Vector2(0, band0), Vector2(band1, 270)]:
			draw_rect(Rect2(gx, seg.x, 18, seg.y - seg.x), Color8(12, 10, 10))
			draw_rect(Rect2(gx + 18, seg.x, 2, seg.y - seg.x), Color8(28, 24, 22))
		draw_rect(Rect2(gx - 3, band0 - 6, 24, 6), Color8(22, 19, 17))
		draw_rect(Rect2(gx - 3, band1, 24, 6), Color8(22, 19, 17))
		for k in 3:
			draw_rect(Rect2(gx + k * 8, band0 - 4, 1, 1), Color8(60, 52, 44))
			draw_rect(Rect2(gx + k * 8, band1 + 2, 1, 1), Color8(60, 52, 44))
		draw_rect(Rect2(gx, band0, 18, band1 - band0), Color(0.05, 0.04, 0.04, 0.22))
		if run.speed > 300.0:
			# 加速：满屏的速度线
			for k in 14:
				var yy := fposmod(k * 37.0 + run._time * 13.0, 270.0)
				var xx := fposmod(-run._time * 1400.0 + k * 97.0, 560.0) - 40.0
				draw_rect(Rect2(roundf(xx), roundf(yy), 22, 1), Color(1, 0.95, 0.85, 0.25))
