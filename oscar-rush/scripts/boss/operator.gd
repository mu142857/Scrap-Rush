class_name Operator
extends StaticBody2D
## 第二关 Boss「总机 THE OPERATOR」：一台成了精的巨型电话交换台。
## 它接通了这颗星球上所有人的声音，一句都没还回去；它想要录像带里那家人的声音。
## 打败它，冒出一句句别人没打完的最后一通电话。这一关的主题是"声音"。
##
## 招式（抽签不放回，和锅炉一样；10-19 按作者"没压迫感、弹幕太多、帅的招少"重做，零碎弹幕全删了，招不再叠着出）：
##   吊车压顶（招牌）：滑车飞快追到你头顶，地上闪红影 0.6 秒，整台顺着缆绳砸下来，砸在第一块挡住它的面上
##     （长凳、桌子或地面）；砸完往两边推一道贴地的铃声地波，要跳。一/二/三阶段砸 1/2/3 下（三阶段地波两道）
##   接线墙：一排插线从天车上一根根垂下来点亮（0.85 秒），然后整排一起通电，只留一两道空档，站进去；
##     二阶段起通电时整排往一边抽过去（跟着空档走），三阶段打两轮
##   听筒流星锤：听筒连着线甩出来，荡半圈，最低点贴着地面扫过去（预警 0.75 秒画出弧线）；跑出半径或者跳过去；三阶段来回两趟
##   总机过载（三阶段）：铜地板一块接一块通电，同时电火花一根根先标落点、再从天车劈下来
## 会动：开打时上半截（插孔板）离开桌子，吊在天花板的天车轨道上，追着你滑（一阶段就追得很紧，越往后越快、吊得越低）。
## 转阶段：屋里灯全灭、所有电话一起响、震屏，灯红着亮回来（boss2_room.gd）；它清场、停 1.6 秒。三阶段通体发亮、转盘疯转。
## 原点在桌腿脚底中间（停在桌上时），朝左。图层坐标见 tools/draw_boss2.py。

signal hp_changed(hp: float, max_hp: float)
signal phase_changed(phase: int)
signal defeated

const BASE_HP := 6200.0  # 10-18 作者嫌太简单：3800 → 5600；10-19 重做招式（零碎弹幕删了、自动瞄准不再被小球分心，打得更快）再补到 6200：站桩 7 把武器 50~65 秒
const CONTACT_DAMAGE := 10.0
const CANVAS_ORIGIN := Vector2(48, 111)
const DIAL := Vector2(48, 40) - CANVAS_ORIGIN
const DIAL_R := 12.0
const BELLS := [Vector2(23, 9) - CANVAS_ORIGIN, Vector2(73, 9) - CANVAS_ORIGIN]
const HORN := Vector2(6, 52) - CANVAS_ORIGIN
const JACKS := Rect2(Vector2(20, 24) - CANVAS_ORIGIN, Vector2(56, 36))
const LED_COLOR := Color(1.0, 0.28, 0.18)
const SPARK := Color(0.65, 0.85, 1.0)
const BRASS := Color8(181, 142, 96)
const HOT_TINT := Color(1.35, 1.0, 0.75)
## 两个吊环（缆绳挂这里）
const HOOKS := [Vector2(30, 7) - CANVAS_ORIGIN, Vector2(66, 7) - CANVAS_ORIGIN]
## 插孔板的底边（相对原点）：砸下来时就是这条边落地
const HEAD_BOTTOM := 63.0 - 111.0
## 吊着时原点的高度（插孔板底边离地约 70）。10-18 作者选的：130 → 140，吊低 10 像素，站长凳上的蒸汽锤更好够到
const HOVER_Y := 140.0
## 吊着追人的速度（10-19 重做：作者"没有压迫感"，38/50/64 → 55/72/92，追得紧）
const TRACK_SPEED := [55.0, 72.0, 92.0]
## 二阶段起吊得更低一点，压着人（蒸汽锤站长凳也更好够）
const HOVER_DROP := [0.0, 6.0, 10.0]
const SLAM_DAMAGE := 14.0
## 砸线落地后在地上停多久（见 _drop）
const SLAM_REST := 1.2

var arena := Rect2(0, 0, 320, 180)
var floor_y := 164.0
var bullet_parent: Node
## 房间里会通电的铜地板
var plates: Array = []
## 单向平台 Vector3(x0, x1, 顶面 y)：砸下来时落在第一块挡住它的面上
var platforms: Array = []
var rail_y := 16.0

var max_hp := BASE_HP
var hp := BASE_HP
var phase := 1
var active := false
var dead := false

var _time := 0.0
var _flash := 0.0
var _hot := 0.0
## 受击时插孔板往后顿一格（夜间打磨，照第二关精英的手感）
var _recoil := 0.0
var _recoil_dir := 1.0
## 换阶段后先停一下再出下一招
var _pause_t := 0.0
## 铃声招预警时，第一圈缺口方向的淡色弧
var _gap_hint_t := 0.0
var _gap_hint_a := 0.0
## 双人以上：这一招盯的玩家（每招轮换）
var _focus: Player = null
var _focus_i := -1
var _dial_angle := 0.0
var _dial_spin := 0.0
var _bell_shake := [0.0, 0.0]
var _lights_on := 1.0
var _breathe := 0
var _last_pattern := ""
## 正在放的招（"" = 招和招之间；三阶段叠招时是后一招）。只给 tools/qa/elite_regression.gd 量节奏用
var _pattern := ""
## 二阶段隔一招叠一次（数到单数时叠）
var _combo := 0
var _bag: Array[String] = []
var _bag_phase := 0
var _warn_t := 0.0
var _warn_pos := Vector2.ZERO
## "dock" 停在桌上，"hover" 吊着追人，"hold" 吊着不动，"move" 正在被补间拉着走
var _mode := "dock"
var _track_mult := 1.0
var _shadow_t := 0.0
var _shadow_x := 0.0
var _shadow_y := 164.0
var _cable_shake := 0.0
var _cables_cut := false
var _contact_damage := CONTACT_DAMAGE

var _parts: Node2D
var _body: Sprite2D
var _deco: Node2D
var _led_light: PointLight2D
var _contact: Area2D
var _flash_mat: ShaderMaterial
var _warn: Node2D


func _ready() -> void:
	add_to_group("enemy")
	Bestiary.watch(self, "boss_operator", Rect2(-48, -96, 96, 96))   # 怪物图鉴：第一次出现在画面里就记一笔
	collision_layer = 4
	collision_mask = 0
	max_hp = BASE_HP * (1.0 + 0.5 * (Run.players.size() - 1))
	hp = max_hp
	if bullet_parent == null:
		bullet_parent = get_parent()

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(64, 50)
	shape.shape = rect
	shape.position = Vector2(0, -75)
	add_child(shape)
	_contact = Area2D.new()
	_contact.collision_layer = 0
	_contact.collision_mask = 2 | 8
	var cs := CollisionShape2D.new()
	var crect := RectangleShape2D.new()
	crect.size = Vector2(60, 50)
	cs.shape = crect
	cs.position = Vector2(0, -75)
	_contact.add_child(cs)
	add_child(_contact)

	_flash_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = EnemyBase.FLASH_SHADER
	_flash_mat.shader = sh

	_parts = Node2D.new()
	add_child(_parts)
	_body = Sprite2D.new()
	_body.texture = load("res://art/boss/operator_head.png")
	_body.centered = false
	_body.offset = -CANVAS_ORIGIN
	_body.material = _flash_mat
	_body.light_mask = 2
	_parts.add_child(_body)

	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	# 转盘、铃铛、信号小灯：都由代码画，不吃压暗（黑暗里也认得出这台机器的"脸"）
	_deco = Node2D.new()
	_deco.material = unshaded
	_deco.draw.connect(_draw_deco)
	_parts.add_child(_deco)

	_led_light = PointLight2D.new()
	_led_light.texture = Game.light_texture()
	_led_light.color = LED_COLOR
	_led_light.energy = 0.0
	_led_light.texture_scale = 0.8
	_led_light.position = DIAL
	_led_light.range_item_cull_mask = 1
	_parts.add_child(_led_light)

	var key := PointLight2D.new()
	key.texture = Game.light_texture()
	key.color = Color(1.0, 0.85, 0.65)
	key.energy = 2.0
	key.texture_scale = 3.8
	key.position = Vector2(-44, -64)
	key.range_item_cull_mask = 2
	add_child(key)

	_warn = Node2D.new()
	_warn.material = unshaded
	_warn.z_index = 20
	_warn.draw.connect(_draw_warn)
	add_child(_warn)


# —— 对外 ——

func aim_point() -> Vector2:
	return global_position + DIAL + _parts.position


func is_targetable() -> bool:
	return active and not dead


func wake() -> void:
	for i in 3:
		if not is_inside_tree():
			return
		_led_light.energy = 1.0
		if is_inside_tree(): await get_tree().create_timer(0.08, false).timeout
		_led_light.energy = 0.0
		if is_inside_tree(): await get_tree().create_timer(0.06, false).timeout
	_led_light.energy = 1.0
	_ring_bell(0)
	_ring_bell(1)
	Game.sfx("bell", -2.0)
	_dial_spin = 14.0
	Game.add_shake(4.0)
	if is_inside_tree(): await get_tree().create_timer(0.5, false).timeout
	# 上半截离开桌子，顺着缆绳被拉上天车
	Game.sfx("scrape", -4.0, 0.7)
	Game.sfx("clang", -8.0, 1.3)
	Game.sparks(get_parent(), global_position + Vector2(0, HEAD_BOTTOM), BRASS, 10, 70.0)
	_mode = "move"
	var tw := create_tween()
	tw.tween_property(self, "position:y", HOVER_Y, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	# 快速开场时 start_fight 可能已经先到了（_mode 已是 hover），别把它改回去
	if _mode == "move":
		_mode = "hold"


func start_fight() -> void:
	active = true
	_mode = "hover"
	_fight_loop()


func hurt(damage: float, from_dir: Vector2, full: bool) -> void:
	if dead:
		return
	_flash = 1.0
	if not active:
		return
	# 挨打有分量：插孔板往后顿一格、缆绳抖一下；蓄满的再加一声金属响
	_recoil = 0.06
	_recoil_dir = signf(from_dir.x) if from_dir.x != 0.0 else 1.0
	_cable_shake = maxf(_cable_shake, 0.1)
	if full:
		Game.sfx("clang", -12.0, 1.7, 0.1)
	hp = maxf(hp - damage, 0.0)
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_die()
		return
	var new_phase := 1 if hp > max_hp * 0.66 else (2 if hp > max_hp * 0.33 else 3)
	if new_phase != phase:
		phase = new_phase
		phase_changed.emit(phase)
		_phase_roar()



## 离开场景树（重来、切场景、整关重载）：标成"已结束"，所有出招循环都会看 dead 自己停下；
## 每个 await get_tree() 前面也先看还在不在树里。不然 get_tree() 变成空值，协程空转、无限刷错（夜间质检，网页版会卡死）
func _exit_tree() -> void:
	dead = true
	active = false

# —— 每帧 ——

func _physics_process(delta: float) -> void:
	_time += delta
	_flash = maxf(_flash - delta * 7.0, 0.0)
	_flash_mat.set_shader_parameter("flash", _flash)
	_warn_t -= delta
	_shadow_t -= delta
	_cable_shake = maxf(_cable_shake - delta, 0.0)
	_recoil -= delta
	_pause_t -= delta
	_gap_hint_t -= delta
	_parts.position.x = _recoil_dir if _recoil > 0.0 else 0.0
	_warn.queue_redraw()
	if active and not dead and _mode == "hover":
		var tx := clampf(_target().x, arena.position.x + 56.0, arena.end.x - 56.0)
		position.x = move_toward(position.x, tx, TRACK_SPEED[phase - 1] * _track_mult * delta)
		position.y = move_toward(position.y, HOVER_Y + HOVER_DROP[phase - 1], 60.0 * delta)
	for i in 2:
		_bell_shake[i] = maxf(_bell_shake[i] - delta * 2.5, 0.0)
	_dial_spin = move_toward(_dial_spin, 0.0, delta * 6.0)
	_dial_angle += _dial_spin * delta
	var period := 0.55 if phase < 3 else 0.2
	var b := int(_time / period) % 2
	if b != _breathe:
		_breathe = b
		_parts.position.y = -b
	_hot = move_toward(_hot, 1.0 if (phase == 3 and not dead) else 0.0, delta)
	var tint := Color.WHITE.lerp(HOT_TINT, _hot * (0.6 + 0.4 * sin(_time * 8.0)))
	_body.modulate = Color(0.55, 0.55, 0.6) if dead else tint
	_deco.queue_redraw()
	if active and not dead:
		for body in _contact.get_overlapping_bodies():
			if body is Player:
				(body as Player).hurt(global_position + Vector2(0, -75), _contact_damage)
			elif body is Crystal:
				(body as Crystal).take_hit(global_position + Vector2(0, -75), _contact_damage)


# —— 出招 ——

func _wait(t: float) -> void:
	if is_inside_tree(): await get_tree().create_timer(t, false).timeout


## 招和招之间空多久（10-19 重做：0.8/0.6/0.45 → 0.85/0.65/0.5，招少了、每招更重，空档留够看清下一招）
func _gap() -> float:
	return [0.85, 0.65, 0.5][phase - 1]


## 10-19 重做（作者："没有压迫感、比第一关简单、弹幕太多躲不过、帅的技能没几个"）：
## 去掉零碎弹幕（铃声子弹环、拨号追踪小球、二三阶段两招叠着出），换成四招，每招看得懂、躲得开、有分量：
##   drop  吊车压顶（招牌）：追到头顶 → 红影 0.6 秒 → 砸下来，砸地往两边推一道铃声地波（要跳）；一/二/三阶段砸 1/2/3 下
##   lash  接线墙：一排插线从天车上一根根垂下来点亮（0.85 秒），然后整排一起通电，只留空档；二阶段起通电时整排往一边抽过去
##   flail 听筒流星锤：听筒连着线甩出来，贴着地面荡过半圈（0.75 秒预警画出弧线），跳过去；三阶段来回两趟
##   overload 总机过载（三阶段）：铜地板轮流通电 + 电火花一根根先标落点再劈下来
func _pool() -> Array[String]:
	var pool: Array[String] = ["drop", "lash", "flail"]
	if phase >= 3:
		pool.append("overload")
	return pool


## 抽签不放回；换阶段时新招先出（和锅炉一样）
func _next_pattern() -> String:
	if _bag_phase != phase:
		_bag_phase = phase
		_bag.assign(_pool())
		_bag.shuffle()
		if phase >= 3 and _bag.has("overload"):
			_bag.erase("overload")
			_bag.append("overload")
	if _bag.is_empty():
		_bag.assign(_pool())
		_bag.shuffle()
		if _bag.size() > 1 and _bag.back() == _last_pattern:
			_bag.reverse()
	var pick: String = _bag.pop_back()
	_last_pattern = pick
	return pick


func _fight_loop() -> void:
	await _wait(0.6)
	while active and not dead:
		# 刚换阶段：停一下，让玩家看清它变了
		while _pause_t > 0.0 and not dead:
			if is_inside_tree(): await get_tree().physics_frame
		var pick := _next_pattern()
		_pick_focus()
		await _run(pick)
		_pattern = ""
		if dead:
			return
		await _wait(_gap())


func _run(pick: String) -> void:
	_pattern = pick
	match pick:
		"drop":
			await _drop()
		"lash":
			await _lash()
		"flail":
			await _flail()
		"overload":
			await _overload()


func _warn_at(pos: Vector2, t := 0.6) -> void:
	_warn_pos = pos
	_warn_t = t
	Game.sfx("charge", -16.0, 2.0)


func _ring_bell(i: int) -> void:
	_bell_shake[i] = 1.0


## 接线墙：一排插线从天车上一根根垂下来（红虚线，从近到远依次亮，一共 LASH_WARN 秒），然后整排一起通电 LASH_LIVE 秒。
## 线和线之间隔 LASH_STEP，里面挑一两根不放，就是空档；主角站的那一格一定有线（站着不动躲不掉）。
## 二阶段起通电时整排往一边抽过去 LASH_SWEEP 像素（空档跟着走，跟上就行）；三阶段打两轮，第二轮空档换位置
const LASH_WARN := 0.85
const LASH_LIVE := 0.6
const LASH_STEP := 40.0
const LASH_SWEEP := 26.0
func _lash() -> void:
	var rounds := 2 if phase >= 3 else 1
	for r in rounds:
		if dead:
			return
		var x0 := arena.position.x + 20.0
		var xs: Array[float] = []
		var x := x0
		while x < arena.end.x - 14.0:
			xs.append(x)
			x += LASH_STEP
		# 主角在哪一格：那一格的线一定在；空档挑离主角一两格远的地方，一或两根
		var px := _target().x
		var near_i := 0
		for i in xs.size():
			if absf(xs[i] - px) < absf(xs[near_i] - px):
				near_i = i
		var options: Array[int] = []
		for i in xs.size():
			if absi(i - near_i) >= 1 and absi(i - near_i) <= 3:
				options.append(i)
		options.shuffle()
		var gaps: Array[int] = [options[0]]
		if phase == 1 and options.size() > 1:
			gaps.append(options[1])
		var sweep := 0.0
		if phase >= 2:
			sweep = LASH_SWEEP * (1.0 if randf() < 0.5 else -1.0)
		_warn_at(JACKS.position + Vector2(JACKS.size.x / 2.0, -6), LASH_WARN)
		Game.sfx("dial", -6.0, 0.6)
		_lights_on = 1.0
		var order: Array[int] = []
		for i in xs.size():
			order.append(i)
		order.sort_custom(func(a, b): return absf(xs[a] - position.x) < absf(xs[b] - position.x))
		for k in order.size():
			var i: int = order[k]
			if gaps.has(i):
				continue
			var c := LashCord.new()
			c.x = xs[i]
			c.top = rail_y + 4.0
			c.bottom = floor_y
			c.lo = arena.position.x + 10.0
			c.hi = arena.end.x - 10.0
			c.delay = LASH_WARN * float(k) / order.size() * 0.7
			c.warn_time = LASH_WARN
			c.live_time = LASH_LIVE
			c.sweep = sweep
			bullet_parent.add_child(c)
		_dial_spin = 16.0
		await _wait(LASH_WARN + 0.05)
		if dead:
			return
		Game.sfx("buzz", -2.0, 0.7)
		Game.sfx("busy", -10.0, 1.1)
		Game.add_shake(4.0)
		_ring_bell(0)
		_ring_bell(1)
		await _wait(LASH_LIVE + (0.35 if r < rounds - 1 else 0.2))


## 听筒流星锤：听筒连着线从插孔板上甩出来，绕着吊点荡半圈（一头到另一头），最低点贴着地面扫过去。
## 预警 FLAIL_WARN：听筒垂下来一晃一晃发红，地上和空中画出它要走的弧线（虚线）。三阶段荡完马上荡回来
const FLAIL_WARN := 0.75
const FLAIL_SWING := 0.95
func _flail() -> void:
	_mode = "hold"
	var f := Flail.new()
	f.boss = self
	f.pivot_off = HORN + Vector2(0, 6)
	f.radius = (floor_y - 7.0) - (position.y + f.pivot_off.y)
	var tx := _target().x
	f.from_left = tx > position.x
	f.warn_time = FLAIL_WARN
	f.swing_time = FLAIL_SWING
	f.swings = 2 if phase >= 3 else 1
	f.lo = arena.position.x + 8.0
	f.hi = arena.end.x - 8.0
	bullet_parent.add_child(f)
	_warn_at(HORN + Vector2(0, -10), FLAIL_WARN)
	Game.sfx("dial", -4.0, 0.8)
	Game.sfx("charge", -10.0, 0.6)
	await _wait(FLAIL_WARN + FLAIL_SWING * f.swings + 0.35)
	_mode = "hover"


## 总机过载（三阶段）：插孔板上的灯全亮、转盘疯转；铜地板一块接一块通电，同时电火花一根根先在地上标落点、再从天车劈下来
const SPARK_COUNT := 5
func _overload() -> void:
	_warn_at(DIAL + Vector2(0, -18), 0.8)
	Game.sfx("busy", -4.0, 1.3)
	Game.sfx("buzz", -6.0, 1.4)
	_dial_spin = 24.0
	_lights_on = 1.0
	Game.add_shake(3.0)
	var order := plates.duplicate()
	order.shuffle()
	for i in order.size():
		if is_instance_valid(order[i]):
			order[i].call("charge", 0.3 + i * 0.9)
	for k in SPARK_COUNT:
		if dead:
			return
		await _wait(0.45)
		var px := _target().x + randf_range(-30.0, 30.0)
		var s := SparkPillar.new()
		s.x = clampf(px, arena.position.x + 14.0, arena.end.x - 14.0)
		s.top = rail_y + 4.0
		s.bottom = floor_y
		bullet_parent.add_child(s)
	await _wait(1.2)


## 砸线：滑车加速追到头顶 → 停住，地上闪红影 0.6 秒、缆绳抖 → 砸下来 → 停一下 → 收回去
func _drop() -> void:
	var slams: int = [1, 2, 3][phase - 1]
	for i in slams:
		if dead:
			return
		_mode = "hover"
		_track_mult = 3.2
		await _wait(0.75 if i == 0 else 0.45)
		if dead:
			return
		_mode = "hold"
		_track_mult = 1.0
		_shadow_x = position.x
		_shadow_y = _landing_y(position.x)
		_shadow_t = 0.6
		_cable_shake = 0.6
		Game.sfx("scrape", -6.0, 1.4)
		await _wait(0.6)
		if dead:
			return
		_mode = "move"
		_contact_damage = SLAM_DAMAGE
		var tw := create_tween()
		tw.tween_property(self, "position:y", _shadow_y - HEAD_BOTTOM, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
		_slam_impact(_shadow_y)
		# 砸完在地上停一会儿：拿蒸汽锤的人平时够不着吊着的它，这是锤子的输出窗口。
		# 10-18 试用：0.9/0.7/0.5 → 每阶段都 1.2 秒（等作者试玩再定要不要留）。砸的那一下才是重伤，停着的时候只算普通碰撞
		await _wait(0.15)
		_contact_damage = CONTACT_DAMAGE
		await _wait(SLAM_REST - 0.15)
		if dead:
			return
		Game.sfx("scrape", -8.0, 0.8)
		var up := create_tween()
		up.tween_property(self, "position:y", HOVER_Y + HOVER_DROP[phase - 1], 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await up.finished
	_mode = "hover"


## 砸在哪个面上：插孔板底边下面第一块挡住它的平台，没有就是地面
func _landing_y(x: float) -> float:
	var top := global_position.y + _parts.position.y + HEAD_BOTTOM
	var best := floor_y
	for p in platforms:
		if p.x < x + 26.0 and p.y > x - 26.0 and p.z > top and p.z < best:
			best = p.z
	return best


func _slam_impact(y: float) -> void:
	Game.sfx("clang", 0.0, 0.8)
	Game.sfx("boom", -6.0, 1.2)
	Game.add_shake(7.0)
	Game.hitstop(0.05)
	Game.sparks(get_parent(), Vector2(position.x - 26, y), BRASS, 8, 90.0, Vector2.LEFT)
	Game.sparks(get_parent(), Vector2(position.x + 26, y), BRASS, 8, 90.0, Vector2.RIGHT)
	_ring_bell(0)
	_ring_bell(1)
	# 砸在地上，或者砸在长凳、桌子上（震动顺着凳腿传到地面）：顺着地板往两边炸出声波，要跳过去。
	# 夜间打磨：子弹能从长凳底下往上打了，长凳底下不能再是"站着就能赢"的安全区
	Game.dust(get_parent(), Vector2(position.x, floor_y), 8)
	# 砸在地上时声波从插孔板两边出发；砸在凳子上时从正下方出发（躲在凳子底下正中也逃不掉）
	# 10-19 重做：不再撒一串子弹，改成一道贴地的铃声地波往两边推（高 10，跳过去），三阶段跟着第二道
	var start := 30.0 if absf(y - floor_y) < 1.0 else 2.0
	for dir in [-1, 1]:
		for k in (2 if phase == 3 else 1):
			var w := FloorRing.new()
			w.position = Vector2(position.x + dir * start, floor_y)
			w.dir = dir
			w.delay = k * 0.35
			w.lo = arena.position.x + 8.0
			w.hi = arena.end.x - 8.0
			bullet_parent.add_child(w)


## 这一招盯的那个玩家的位置。单人就是他；双人以上每招轮着换人（_pick_focus），
## 不然它吊在谁头上谁就一直是"最近的"，另一个人整场没压力（夜间打磨，双人测试发现）。盯的人没了就退回最近的。
func _target() -> Vector2:
	if is_instance_valid(_focus) and _focus.is_inside_tree():
		return _focus.global_position
	var best := INF
	var out := Vector2(arena.position.x + 60.0, floor_y)
	for n in get_tree().get_nodes_in_group("player"):
		var p := n as Player
		var d := p.global_position.distance_to(global_position)
		if d < best:
			best = d
			out = p.global_position
	return out


## 下一招盯谁：按玩家顺序轮着来（单人永远是他）
func _pick_focus() -> void:
	var ps := get_tree().get_nodes_in_group("player")
	if ps.size() <= 1:
		_focus = null
		return
	_focus_i = (_focus_i + 1) % ps.size()
	_focus = ps[_focus_i] as Player


func _phase_roar() -> void:
	_ring_bell(0)
	_ring_bell(1)
	Game.sfx("bell", 0.0, 0.8)
	Game.sfx("busy", -8.0, 1.2)
	Game.add_shake(6.0)
	Game.flash(Color(1.0, 0.85, 0.5), 0.25, 0.5)
	_dial_spin = 20.0
	# 换阶段：清掉它场上的子弹，下一招推迟 0.8 秒。
	# 10-18 作者"子弹会中途消失"：不再直接删，迸一点火花再没（BossBullet.fizzle，声音小球是 _pop）
	_clear_bullets()
	# 10-19 重做：转阶段有一段演出（灯全灭、所有电话一起响，见 boss2_room.gd），停得久一点
	_pause_t = 1.6


func _clear_bullets() -> void:
	for b in get_tree().get_nodes_in_group("boss_bullet"):
		if b.has_method("fizzle"):
			b.fizzle()
		elif b.has_method("_pop"):
			b.call("_pop")
		else:
			b.queue_free()


func _die() -> void:
	dead = true
	Bestiary.count_kill("boss_operator")   # 怪物图鉴：击杀数
	active = false
	_warn_t = 0.0
	_shadow_t = 0.0
	_contact_damage = CONTACT_DAMAGE
	remove_from_group("enemy")
	_clear_bullets()
	# 夜间打磨：死的时候正在通电、正在预警的铜地板也一起断电（不然打赢以后还会被电一下）
	for pl in plates:
		if is_instance_valid(pl) and pl.has_method("shut_off"):
			pl.call("shut_off")
	defeated.emit()
	Game.hitstop(0.25)
	if is_inside_tree(): await get_tree().create_timer(0.3, true, false, true).timeout
	Engine.time_scale = 0.35
	for i in 9:
		if not is_inside_tree():
			return
		var p := global_position + Vector2(randf_range(-30, 30), randf_range(-100, -50))
		Game.sparks(get_parent(), p, [SPARK, BRASS, Color(1, 0.9, 0.7)][i % 3], 16, 140.0)
		Game.sfx("buzz", -4.0, randf_range(0.8, 1.3))
		Game.sfx("boom", -8.0, randf_range(0.9, 1.3))
		Game.add_shake(5.0)
		Game.flash(Color(0.8, 0.9, 1.0), 0.22, 0.25)
		_flash = 1.0
		_dial_spin = 18.0
		_ring_bell(i % 2)
		if is_inside_tree(): await get_tree().create_timer(0.18, true, false, true).timeout
	Engine.time_scale = 1.0
	# 缆绳崩断，整台砸到地上
	_cables_cut = true
	_mode = "move"
	Game.sfx("clang", -2.0, 1.6)
	var land := _landing_y(position.x)
	var fall := create_tween()
	fall.tween_property(self, "position:y", land - HEAD_BOTTOM, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fall.finished
	Game.sfx("boom", -2.0, 0.8)
	Game.add_shake(8.0)
	Game.dust(get_parent(), Vector2(position.x, land), 10)
	EliteFx.scrap_burst(get_parent(), Rect2(global_position + Vector2(-30.0, HEAD_BOTTOM - 40.0), Vector2(60.0, 40.0)), 14,
		[Color8(181, 142, 96), Color8(117, 88, 53), Color8(81, 25, 9)])
	# 信号小灯一盏盏灭掉，红灯熄，最后一声铃
	_led_light.energy = 0.0
	var tw := create_tween()
	tw.tween_property(self, "_lights_on", 0.0, 1.5)
	Game.sfx("bell", -6.0, 0.6)


# —— 画 ——

func _draw_deco() -> void:
	# 天车缆绳：从两个吊环直直拉到天花板轨道，轨道上一个小滑车；砸之前缆绳抖
	if not _cables_cut:
		var rail := rail_y - global_position.y - _parts.position.y
		for h in HOOKS:
			var hp: Vector2 = h
			var wob := roundf(sin(_time * 60.0) * _cable_shake * 2.0)
			for y in range(int(rail) + 3, int(hp.y)):
				var t := float(y - rail) / maxf(hp.y - rail, 1.0)
				var x := hp.x + roundf(wob * sin(t * PI))
				_deco.draw_rect(Rect2(x, y, 1, 1), Color8(70, 62, 52))
			_deco.draw_rect(Rect2(hp.x - 3, rail - 1, 7, 3), Color8(56, 56, 56))
			_deco.draw_rect(Rect2(hp.x - 2, rail - 2, 2, 2), Color8(99, 99, 99))
			_deco.draw_rect(Rect2(hp.x + 1, rail - 2, 2, 2), Color8(99, 99, 99))
	# 转盘：黄铜外圈 + 黑底 + 十个指孔，一直跟着 _dial_angle 转
	var c := DIAL.round()
	var r := int(DIAL_R)
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var d := Vector2(x, y).length()
			if d <= r + 0.3:
				var col := Color8(181, 142, 96) if d > r - 1.7 else Color8(30, 22, 18)
				if d <= 3.3:
					col = Color8(140, 118, 80)
				_deco.draw_rect(Rect2(c + Vector2(x, y), Vector2.ONE), col)
	for k in 10:
		var a := _dial_angle + TAU * k / 12.0 - PI * 0.75
		var p := (c + Vector2.from_angle(a) * (r - 4.5)).round()
		_deco.draw_rect(Rect2(p - Vector2.ONE, Vector2(2, 2)), Color8(96, 66, 42))
		_deco.draw_rect(Rect2(p - Vector2.ONE, Vector2.ONE), Color8(147, 111, 68))
	# 指挡（停住指头的那根小铜钩）
	_deco.draw_rect(Rect2(c + Vector2(r - 3, 3), Vector2(3, 1)), Color8(200, 170, 110))
	# 中心红灯
	var on := _led_light.energy > 0.0
	var blink := 1.0 if phase < 3 else (0.5 + 0.5 * sin(_time * 30.0))
	var led := LED_COLOR.lerp(Color.WHITE, _flash * 0.6) * blink if on else Color(0.3, 0.08, 0.06)
	_deco.draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), Color(led.r, led.g, led.b, 1.0))
	# 两只铃铛：黄铜半球，响的时候左右抖
	for i in 2:
		var bc: Vector2 = BELLS[i]
		var shake := roundf(sin(_time * 70.0) * 1.5 * _bell_shake[i])
		for y in range(-5, 3):
			var half := int(sqrt(maxf(25.0 - (y + 1) * (y + 1), 0.0)))
			for x in range(-half, half + 1):
				var col := Color8(181, 142, 96)
				if x < -half + 2 and y < 0:
					col = Color8(214, 186, 132)
				elif x > half - 2 or y > 0:
					col = Color8(117, 88, 53)
				_deco.draw_rect(Rect2(bc + Vector2(x + shake, y), Vector2.ONE), col)
		_deco.draw_rect(Rect2(bc + Vector2(-1 + shake, 3), Vector2(2, 1)), Color8(96, 66, 42))
	# 插孔上方的信号小灯：一闪一闪，像有电话打进来
	if _lights_on > 0.0:
		for row in 4:
			for col_i in 7:
				var seed := row * 7 + col_i
				var lit := sin(_time * (2.0 + seed % 5) + seed * 1.7) > 0.55
				if not lit:
					continue
				var p := JACKS.position + Vector2(3 + col_i * 8, 2 + row * 9)
				var amber := Color(1.0, 0.75, 0.3, _lights_on)
				_deco.draw_rect(Rect2(p, Vector2.ONE), amber)


func _draw_warn() -> void:
	if _gap_hint_t > 0.0:
		# 第一圈声波的缺口方向：从左铃铛往外一小段淡色弧
		var c: Vector2 = BELLS[0] + _parts.position
		for k in range(-2, 3):
			var a := _gap_hint_a + k * 0.05
			for rr in [10.0, 13.0, 16.0]:
				_warn.draw_rect(Rect2((c + Vector2.from_angle(a) * rr).round(), Vector2.ONE), Color(1.0, 0.9, 0.6, 0.5))
	if _shadow_t > 0.0 and int(_shadow_t * 16.0) % 2 == 0:
		# 砸线落点：落地那一面上一道闪烁的红影，宽度就是插孔板的宽度
		var y := _shadow_y - global_position.y
		var x0 := _shadow_x - global_position.x - 30.0
		_warn.draw_rect(Rect2(x0, y - 2, 60, 2), Color(1.0, 0.25, 0.2, 0.85))
		for k in range(0, 60, 6):
			_warn.draw_rect(Rect2(x0 + k + 2, y - 5, 2, 2), Color(1.0, 0.3, 0.25, 0.6))
	if _warn_t <= 0.0 or int(_warn_t * 14.0) % 2 == 0:
		return
	var p := _warn_pos.round()
	var col := Color(1.0, 0.25, 0.2)
	_warn.draw_rect(Rect2(p + Vector2(-1, -9), Vector2(3, 6)), col)
	_warn.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(3, 2)), col)
	_warn.draw_rect(Rect2(p + Vector2(0, -9), Vector2(1, 6)), Color(1, 0.75, 0.6))


## 接线墙的一根插线：从天车上垂到地面。先 delay 秒后开始从上往下画红虚线（预警），warn_time 一到整根通电 live_time 秒
## （黄铜线 + 蓝白电弧在抖），挨着线（左右 HIT 以内）就挨电；sweep 不是 0 时通电期间整根往一边平移过去（抽过场地）
class LashCord:
	extends Node2D

	const HIT := 5.0
	const DAMAGE := 12.0
	var x := 0.0
	var top := 16.0
	var bottom := 164.0
	var lo := 0.0
	var hi := 320.0
	var delay := 0.0
	var warn_time := 0.85
	var live_time := 0.6
	var sweep := 0.0
	var _t := 0.0
	var _hit := {}

	func _ready() -> void:
		z_index = 9
		add_to_group("boss_bullet")
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded

	func _cur_x() -> float:
		var lt := clampf((_t - warn_time) / maxf(live_time, 0.01), 0.0, 1.0)
		return clampf(x + sweep * lt, lo, hi)

	func _physics_process(delta: float) -> void:
		_t += delta
		if _t >= warn_time and _t < warn_time + live_time:
			var cx := _cur_x()
			for n in get_tree().get_nodes_in_group("player"):
				var p := n as Player
				if p == null or _hit.has(p):
					continue
				if absf(p.global_position.x - cx) < HIT + 3.0 and p.global_position.y - 16.0 < bottom and p.global_position.y > top:
					_hit[p] = true
					p.hurt(Vector2(cx, p.global_position.y - 8.0), DAMAGE * EnemyBase.damage_mult())
			for n in get_tree().get_nodes_in_group("crystal"):
				var c := n as Crystal
				if c and c.carrier == null and not _hit.has(c) and absf(c.global_position.x - cx) < HIT + 2.0:
					_hit[c] = true
					c.take_hit(Vector2(cx, c.global_position.y - 4.0), DAMAGE * EnemyBase.damage_mult())
		if _t >= warn_time + live_time:
			queue_free()
			return
		queue_redraw()

	## 被清场（换阶段、Boss 死了）：淡掉
	func fizzle(_push := Vector2.ZERO) -> void:
		queue_free()

	func _draw() -> void:
		if _t < delay:
			return
		var cx := roundf(_cur_x())
		if _t < warn_time:
			# 预警：从上往下长出来的红虚线（越接近通电闪得越快），地上一个插头的红框
			var k := clampf((_t - delay) / maxf(warn_time - delay, 0.01) * 1.6, 0.0, 1.0)
			var y1 := top + (bottom - top) * k
			var fast := _t > warn_time - 0.3
			if fast and int(_t / 0.05) % 2 == 1:
				return
			for y in range(int(top), int(y1), 5):
				draw_rect(Rect2(cx, y, 1, 3), Color(1.0, 0.3, 0.2, 0.85))
			if k >= 1.0:
				draw_rect(Rect2(cx - 2, bottom - 3, 5, 3), Color(1.0, 0.3, 0.2, 0.9))
			return
		# 通电：黄铜线 + 两边抖动的蓝白电弧；底下插头冒火星
		for y in range(int(top), int(bottom), 2):
			draw_rect(Rect2(cx, y, 1, 2), Color8(181, 142, 96))
			if randf() < 0.3:
				draw_rect(Rect2(cx + randi_range(-3, 3), y, 1, 1), Color(0.75, 0.9, 1.0))
		draw_rect(Rect2(cx - 1, top, 3, 2), Color8(214, 186, 132))
		draw_rect(Rect2(cx - 2, bottom - 4, 5, 4), Color8(214, 186, 132))
		draw_rect(Rect2(cx - 3, top, 7, bottom - top), Color(0.6, 0.85, 1.0, 0.12))


## 听筒流星锤：吊点在总机的听筒口（跟着总机走），一根线拴着一只黑听筒。
## 预警：听筒垂在吊点正下方一晃一晃、发红，沿着要荡的那半圈画红色虚线（地上最低那段画实一点）。
## 然后从一头（水平）荡到另一头（水平），最低点贴着地面；三阶段荡到头马上荡回来。只有听筒伤人（伤 14，每趟每人一下）
class Flail:
	extends Node2D

	const DAMAGE := 14.0
	const HEAD := Vector2(9, 5)
	var boss: Node2D
	var pivot_off := Vector2.ZERO
	var radius := 60.0
	var from_left := true
	var warn_time := 0.75
	var swing_time := 0.95
	var swings := 1
	var lo := 0.0
	var hi := 320.0
	var _t := 0.0
	var _hit := {}
	var _swing_i := -1
	var _whoosh := false

	func _ready() -> void:
		z_index = 9
		top_level = true
		add_to_group("boss_bullet")
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded

	func _pivot() -> Vector2:
		return (boss.global_position + pivot_off) if is_instance_valid(boss) else global_position

	## 现在听筒在哪（角度：0 = 正下方，-PI/2 = 左边水平，PI/2 = 右边水平）
	func _angle() -> float:
		var st := _t - warn_time
		if st < 0.0:
			return sin(_t * 9.0) * 0.12
		var i := int(st / swing_time)
		var k := fmod(st, swing_time) / swing_time
		k = 0.5 - 0.5 * cos(k * PI)        # 两头慢、中间快（像真的摆）
		var a0 := -PI / 2.0 if from_left else PI / 2.0
		if i % 2 == 1:
			a0 = -a0
		return lerpf(a0, -a0, k)

	func _head() -> Vector2:
		var a := _angle()
		return _pivot() + Vector2(sin(a), cos(a)) * radius

	func _physics_process(delta: float) -> void:
		_t += delta
		if not is_instance_valid(boss) or boss.get("dead") == true:
			queue_free()
			return
		var st := _t - warn_time
		if st >= swing_time * swings:
			queue_free()
			return
		if st >= 0.0:
			var i := int(st / swing_time)
			if i != _swing_i:
				_swing_i = i
				_hit.clear()
				Game.sfx("jet", -8.0, 1.2)
				Game.sfx("scrape", -10.0, 1.4)
			var h := _head()
			if not _whoosh and absf(_angle()) < 0.3:
				_whoosh = true
				Game.add_shake(2.0)
				Game.dust(get_parent(), Vector2(h.x, h.y + HEAD.y / 2.0 + 1.0), 4)
			if absf(_angle()) > 0.6:
				_whoosh = false
			var r := Rect2(h - HEAD / 2.0, HEAD)
			for n in get_tree().get_nodes_in_group("player"):
				var p := n as Player
				if p and not _hit.has(p) and r.intersects(Rect2(p.global_position + Vector2(-3, -16), Vector2(6, 16))):
					_hit[p] = true
					p.hurt(h, DAMAGE * EnemyBase.damage_mult())
			for n in get_tree().get_nodes_in_group("crystal"):
				var c := n as Crystal
				if c and c.carrier == null and not _hit.has(c) and r.intersects(Rect2(c.global_position + Vector2(-2.5, -8), Vector2(5, 8))):
					_hit[c] = true
					c.take_hit(h, DAMAGE * EnemyBase.damage_mult())
		queue_redraw()

	func fizzle(_push := Vector2.ZERO) -> void:
		queue_free()

	func _draw() -> void:
		var pv := _pivot()
		var h := _head()
		var st := _t - warn_time
		if st < 0.0:
			# 预警：要荡的半圈画成红虚线，越接近越快闪；地面那一段实一点
			if int(_t / (0.05 if _t > warn_time - 0.3 else 0.1)) % 2 == 0:
				for k in 25:
					var a := -PI / 2.0 + PI * k / 24.0
					var q := (pv + Vector2(sin(a), cos(a)) * radius).round()
					if q.x < lo or q.x > hi:
						continue
					var low := absf(a) < 0.5
					draw_rect(Rect2(q, Vector2(2 if low else 1, 1)), Color(1.0, 0.3, 0.2, 0.9 if low else 0.55))
		# 线：从吊点到听筒，一格一个点
		var n := int(pv.distance_to(h))
		for i in range(0, n, 2):
			var q := pv.lerp(h, float(i) / maxf(n, 1)).round()
			draw_rect(Rect2(q, Vector2.ONE), Color8(70, 62, 52))
		# 听筒：黑色哑铃形（两头大中间细），预警时发红
		var hot := st < 0.0 and int(_t / 0.08) % 2 == 0
		var body := Color(0.85, 0.25, 0.2) if hot else Color8(30, 26, 26)
		var hc := h.round()
		draw_rect(Rect2(hc + Vector2(-4, -2), Vector2(3, 4)), body)
		draw_rect(Rect2(hc + Vector2(2, -2), Vector2(3, 4)), body)
		draw_rect(Rect2(hc + Vector2(-1, -1), Vector2(3, 2)), body)
		draw_rect(Rect2(hc + Vector2(-4, -2), Vector2(2, 1)), Color8(96, 90, 84))
		draw_rect(Rect2(hc + Vector2(2, -2), Vector2(2, 1)), Color8(96, 90, 84))
		# 荡的时候身后拖两道残影
		if st >= 0.0:
			for k in [1, 2]:
				var back: float = _t - 0.03 * k
				var save := _t
				_t = back
				var q := _head().round()
				_t = save
				draw_rect(Rect2(q + Vector2(-3, -1), Vector2(7, 2)), Color(0.9, 0.85, 0.75, 0.3 / k))


## 铃声地波：砸地以后贴着地面往一边推的一道声波（三道竖着的弧 ")))"，高 HEIGHT），推满 DIST 或到场边就散。
## 脚在波里（离地 HEIGHT 以内）的人和地上的马灯伤一下。要跳过去
class FloorRing:
	extends Node2D

	const SPEED := 140.0
	const HEIGHT := 10.0
	const DIST := 170.0
	const DAMAGE := 12.0
	var dir := 1
	var delay := 0.0
	var lo := 0.0
	var hi := 320.0
	var _t := 0.0
	var _gone := 0.0
	var _hit := {}

	func _ready() -> void:
		z_index = 8
		add_to_group("boss_bullet")
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded

	func _physics_process(delta: float) -> void:
		_t += delta
		if _t < delay:
			return
		position.x += dir * SPEED * delta
		_gone += SPEED * delta
		if _gone >= DIST or position.x < lo or position.x > hi:
			queue_free()
			return
		var r := Rect2(position + Vector2(-5, -HEIGHT), Vector2(10, HEIGHT))
		for n in get_tree().get_nodes_in_group("player"):
			var p := n as Player
			if p and not _hit.has(p) and r.intersects(Rect2(p.global_position + Vector2(-3, -16), Vector2(6, 16))):
				_hit[p] = true
				p.hurt(position + Vector2(-dir * 6, 0), DAMAGE * EnemyBase.damage_mult())
		for n in get_tree().get_nodes_in_group("crystal"):
			var c := n as Crystal
			if c and c.carrier == null and not _hit.has(c) and r.intersects(Rect2(c.global_position + Vector2(-2.5, -8), Vector2(5, 8))):
				_hit[c] = true
				c.take_hit(position + Vector2(-dir * 6, 0), DAMAGE * EnemyBase.damage_mult())
		queue_redraw()

	func fizzle(_push := Vector2.ZERO) -> void:
		queue_free()

	func _draw() -> void:
		if _t < delay:
			return
		var a := clampf(1.0 - _gone / DIST, 0.3, 1.0)
		# 三道竖着的弧，前面那道最亮
		for k in 3:
			var xo := -dir * k * 3
			var col := Color(1.0, 0.85, 0.5, a * (1.0 - k * 0.3))
			for y in int(HEIGHT):
				var bend := roundf(2.0 * sin(PI * (y + 0.5) / HEIGHT)) * dir
				draw_rect(Rect2(xo + bend, -y - 1, 1, 1), col)
		draw_rect(Rect2(-dir * 8 - 1, -1, 3, 1), Color(0.8, 0.75, 0.65, 0.5 * a))


## 电火花（过载）：地上先标一个落点（蓝白框 + 往下的箭头 WARN 秒），然后从天车到地面劈下一道电光（宽 WIDTH）BLAST 秒。
## 落点那一列（从天花板到地面，长凳上也算）挨电
class SparkPillar:
	extends Node2D

	const WARN := 0.75
	const BLAST := 0.25
	const WIDTH := 12.0
	const DAMAGE := 12.0
	var x := 0.0
	var top := 16.0
	var bottom := 164.0
	var _t := 0.0
	var _boomed := false
	var _hit := {}

	func _ready() -> void:
		z_index = 9
		add_to_group("boss_bullet")
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded

	func _physics_process(delta: float) -> void:
		_t += delta
		if not _boomed and _t >= WARN:
			_boomed = true
			Game.sfx("buzz", -4.0, randf_range(1.1, 1.4))
			Game.sfx("crack", -8.0, 1.6)
			Game.add_shake(2.5)
			Game.sparks(get_parent(), Vector2(x, bottom - 2), Color(0.75, 0.9, 1.0), 8, 90.0, Vector2.UP)
		if _boomed and _t < WARN + BLAST:
			for n in get_tree().get_nodes_in_group("player"):
				var p := n as Player
				if p and not _hit.has(p) and absf(p.global_position.x - x) < WIDTH / 2.0 + 3.0:
					_hit[p] = true
					p.hurt(Vector2(x, p.global_position.y - 8.0), DAMAGE * EnemyBase.damage_mult())
		if _t >= WARN + BLAST:
			queue_free()
			return
		queue_redraw()

	func fizzle(_push := Vector2.ZERO) -> void:
		queue_free()

	func _draw() -> void:
		var cx := roundf(x)
		if not _boomed:
			if int(_t / (0.05 if _t > WARN - 0.3 else 0.1)) % 2 == 1:
				return
			var c := Color(0.6, 0.85, 1.0, 0.9)
			var h := WIDTH / 2.0
			draw_rect(Rect2(cx - h, bottom - 1, WIDTH + 1, 1), c)
			draw_rect(Rect2(cx - h, bottom - 4, 1, 3), c)
			draw_rect(Rect2(cx + h, bottom - 4, 1, 3), c)
			for i in 3:
				draw_rect(Rect2(cx - i, bottom - 10 + i, i * 2 + 1, 1), c)
			for y in range(int(top), int(bottom) - 12, 8):
				draw_rect(Rect2(cx, y, 1, 2), Color(0.6, 0.85, 1.0, 0.35))
			return
		# 劈下来：中间白、两边蓝的一道锯齿电光，越来越淡
		var a := 1.0 - (_t - WARN) / BLAST
		var px := cx
		for y in range(int(top), int(bottom)):
			px += randi_range(-1, 1)
			px = clampf(px, cx - 3, cx + 3)
			draw_rect(Rect2(px - 1, y, 3, 1), Color(0.6, 0.85, 1.0, 0.7 * a))
			draw_rect(Rect2(px, y, 1, 1), Color(1, 1, 1, a))


## 会通电的铜地板（占线）：charge(delay) 以后先蓝光预警 0.9 秒，再通电 1.2 秒，站在上面就挨电
class ElectricPlate:
	extends Node2D

	const WARN := 0.9
	const LIVE := 1.2
	const DAMAGE := 10.0
	var x0 := 0.0
	var x1 := 80.0
	var floor_y := 164.0
	var _t := -1.0

	func _ready() -> void:
		z_index = 7
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded

	func charge(delay := 0.0) -> void:
		_t = -delay

	## 立刻断电（Boss 死了）
	func shut_off() -> void:
		_t = -100.0
		queue_redraw()

	func _physics_process(delta: float) -> void:
		if _t < -50.0:
			return
		var was := _t
		_t += delta
		if was < WARN and _t >= WARN:
			Game.sfx("buzz", -4.0, 0.8)
			Game.add_shake(2.0)
		if _t >= WARN and _t < WARN + LIVE:
			for n in get_tree().get_nodes_in_group("player"):
				var p := n as Player
				if p.is_on_floor() and absf(p.global_position.y - floor_y) < 3.0 \
						and p.global_position.x >= x0 and p.global_position.x <= x1:
					p.hurt(Vector2(p.global_position.x, floor_y + 6), DAMAGE * EnemyBase.damage_mult())
		if _t >= WARN + LIVE:
			_t = -100.0
		queue_redraw()

	func _draw() -> void:
		if _t < 0.0:
			return
		if _t < WARN:
			# 预警：铜板上一排蓝点闪，越来越快
			if int(_t / (0.06 if _t > WARN * 0.5 else 0.12)) % 2 == 0:
				for x in range(int(x0) + 2, int(x1) - 1, 4):
					draw_rect(Rect2(x, floor_y - 1, 2, 1), Color(0.55, 0.8, 1.0, 0.9))
			return
		# 通电：整块铜板发白，上面一串串电弧跳
		draw_rect(Rect2(x0 + 1, floor_y - 1, x1 - x0 - 2, 2), Color(0.8, 0.92, 1.0, 0.9))
		for i in 10:
			var x := randf_range(x0 + 2, x1 - 2)
			var h := randi_range(3, 9)
			var px := x
			for y in h:
				px += randf_range(-1.2, 1.2)
				draw_rect(Rect2(roundf(px), floor_y - 2 - y, 1, 1), Color(0.7, 0.88, 1.0))
