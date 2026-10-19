class_name Telegrapher
extends EliteBase
## 电报员（第二关 E2 继电器机房的精英怪，"人加机器"）：披着暗绿长袍、戴绿色遮光帽檐的电报员，推着一辆电报车
## （木箱、两只辐条轮、黄铜电报键、纸带卷，车头一根小电线杆）。和主角保持中距离（远了推车靠近、近了往后退）。
## 招式都先冒红色"!"：
## - 摩斯连发：头顶亮起一排红色电码（点和划，3～4 个），先照节奏一个个闪一遍、"嘀嘀嗒"响一遍——这就是预警，
##   然后照同一个节奏拍电报键，朝主角打出去：点是快的小电火花（伤 8），划是慢的长电弧（伤 10）。
##   看着头顶的码就知道下一发是快的还是慢的、什么时候来。撞墙就碎。
## - 急电：手举过头顶抡一圈电线，往天花板一甩，电线从车头的电线杆拉上天花板、横着架过主角头顶；
##   地上亮三个红标记（主角脚下和左右各 30 像素），标记上方一列虚点。0.8 秒后电报沿线跑过去，
##   从近到远一个接一个往下劈（每道宽 8，伤 12）。走出标记那一列就躲开了。
## - 推车撞（近身）：主角贴到车前 36 像素以内，身子往后一仰、车往回一拉（0.4 秒），再猛地往前撞 24 像素（伤 14）。
## 电码、电火花、电弧、电线、标记、落雷都是代码画的（不吃压暗，暗处看得清）。
## 贴图 telegrapher.png（草图/精英怪/l2_telegrapher.py 导出，45×34，10 帧）：
## 0~3 推车走，4 拍电报前摇（手在键上方），5 拍下去（键头冒火星），6 急电前摇（电线举过头顶），7 甩线，
## 8 推车撞前摇（后仰、车往回拉），9 撞（前探、车往前推）。

enum { WALK, MORSE_WARN, MORSE, RELAY_WARN, RELAY, RAM_WARN, RAM, RECOVER }

const WALK_SPEED := 20.0
const WALK_FRAME_TIME := 0.15
## 离主角远于 FAR 就往前推车，近于 NEAR 就往后退（脸一直朝着主角）
const FAR := 120.0
const NEAR := 70.0
const SEE_DIST := 260.0
## 招与招之间歇多久（照放映机：精英的出招间隔不乘 interval_mult，情绪高时招太密看不清）
const ATTACK_GAP := 1.0  # 10-18 作者：招和招之间停太久
# —— 摩斯连发 ——
const CODES := ["...", "-.-", ".-.", "..-", "-..", ".--", "--.", ".-..", "..-.", "-.-."]
## 一个点、一个划占多长时间（预演和真打一样的节奏）
const DOT_TIME := 0.18
const DASH_TIME := 0.34
## 预演完到开打之间空一拍
const MORSE_BEAT := 0.35
## 电报键头（原图朝左，相对脚底中间），子弹从这里出去
const KEY_POS := Vector2(-16, -18)
const DOT_SPEED := 150.0
const DASH_SPEED := 100.0
const DOT_DAMAGE := 8.0
const DASH_DAMAGE := 10.0
## 头顶电码牌的中心（原图朝左，相对脚底中间）
const TICKER_POS := Vector2(9, -42)
# —— 急电 ——
const RELAY_WARN_TIME := 0.8
const RELAY_STEP := 0.22
const RELAY_SPREAD := 30.0
const RELAY_REACH := 160.0
const RELAY_DAMAGE := 12.0
## 车头电线杆顶上的绝缘子（原图朝左，相对脚底中间），电线从这里拉出去
const POLE_TOP := Vector2(-18, -28)
# —— 推车撞 ——
const RAM_RANGE := 36.0
const RAM_HEIGHT := 20.0
const RAM_WARN_TIME := 0.4
const RAM_TIME := 0.18
const RAM_DIST := 24.0
const RAM_COOLDOWN := 2.0
const RAM_RECOVER := 0.6
## 撞的判定（朝左时）：车头前面那一截，地面往上 14
const RAM_RECT := Rect2(-26, -14, 12, 14)
const RAM_DAMAGE := 14.0

## _unstick 往下最多探多远（照 chief_operator）
const UNSTICK_REACH := 80.0

var _state := WALK
var _timer := 0.0
var _cool := 1.0
var _ram_cd := 0.0
var _next_relay := false
## 这一次的电码和每个符号的开始时间（从预演开始算）
var _code := ""
var _beats: Array[float] = []
var _morse_t := 0.0
var _fired := 0
var _ticker: Node2D
var _relay: RelayLine


func _setup() -> void:
	reveal_moves = ["MORSE_WARN", "RELAY_WARN"]   # 露底（EliteBase）：这几招都亮过就加伤；贴身才出的近身招不算
	elite_name = "TELEGRAPHER"
	intro_title = "URGENT. STOP."
	intro_frame = 5
	fill_alpha = 0.35
	death_time = 1.1
	death_frame = 5
	texture_path = "res://art/enemies/telegrapher.png"
	hframes = 10
	frame_size = Vector2i(45, 34)
	body_rect = Rect2(-19, -31, 38, 31)
	contact_rect = Rect2(-17, -26, 35, 26)
	led_pixel = Vector2i(25, 10)
	max_hp = 2400.0  # 10-18 作者：血不够，三把武器 20～35 秒
	contact_damage = 10.0


func _after_ready() -> void:
	_ticker = Node2D.new()
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_ticker.material = unshaded
	_ticker.z_index = 10
	_ticker.draw.connect(_draw_ticker)
	add_child(_ticker)
	_unstick()


## 出生时卡在实心里就挪出来（照 chief_operator.gd，碰撞会话 10-18：旧写法只会一路往下挪，脚压进斜坡、
## 身子插进柱子时会穿过地板掉出地图）。先原地、往上一点（脚压进地面、斜坡），再左右挪（插进柱子、墙），
## 最后才往下（头顶卡进天花板），往下最多挪到原来脚底下那块地面
func _unstick() -> void:
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = _shape.shape
	q.collision_mask = 1
	q.exclude = [get_rid()]
	var space := get_world_2d().direct_space_state
	var floor_d := UNSTICK_REACH
	var ray := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -1), global_position + Vector2(0, UNSTICK_REACH + 2.0), 1)
	var hit := space.intersect_ray(ray)
	if not hit.is_empty():
		floor_d = (hit.position as Vector2).y - global_position.y
	var tries: Array[Vector2] = []
	for dy in [0.0, -1.0, -2.0, -3.0, -4.0, -6.0, -8.0]:
		tries.append(Vector2(0, dy))
	for dx in [2.0, 4.0, 6.0, 8.0, 12.0, 16.0]:
		for dy in [0.0, -2.0, -4.0]:
			tries.append(Vector2(dx, dy))
			tries.append(Vector2(-dx, dy))
	var d := 2.0
	while d <= floor_d:
		tries.append(Vector2(0, d))
		d += 2.0
	for t in tries:
		q.transform = Transform2D(0.0, global_position + t + _shape.position)
		if space.intersect_shape(q, 1).is_empty():
			global_position += t
			return
	# 都不行：留在原地，交给物理把它挤出来


func _tick(delta: float) -> void:
	_timer -= delta
	_ram_cd -= delta
	var p := nearest_player(SEE_DIST)
	match _state:
		WALK:
			_cool -= delta
			_walk(p)
			if p and is_on_floor():
				if _ram_cd <= 0.0 and _in_ram_range(p):
					_start(RAM_WARN, RAM_WARN_TIME)
					warn(RAM_WARN_TIME)
				elif _cool <= 0.0:
					p = pick_focus(p)  # 双人时每招轮着盯一个人，整招不换
					if _next_relay:
						_start_relay(p)
					else:
						_start_morse()
					_next_relay = not _next_relay
		MORSE_WARN, MORSE:
			_brake(delta)
			_tick_morse(delta, focus_player())
		RELAY_WARN:
			_brake(delta)
			set_frame(6)
			if _timer <= 0.0:
				_start(RELAY, RELAY_STEP * 3.0 + 0.3)
				Game.sfx("jet", -12.0, 1.8)
		RELAY:
			_brake(delta)
			set_frame(7)
			if _timer <= 0.0:
				_finish_attack(0.4)
		RAM_WARN:
			_brake(delta)
			set_frame(8)
			if _timer <= 0.0:
				_start(RAM, RAM_TIME)
				Game.sfx("jet", -8.0, 0.9)
				Game.dust(get_parent(), global_position, 4, -dir)
		RAM:
			set_frame(9)
			var blocked := is_on_wall() or not ground_ahead(24.0)
			velocity.x = 0.0 if blocked else dir * RAM_DIST / RAM_TIME
			_hit_rect(RAM_RECT, RAM_DAMAGE * damage_mult())
			if _timer <= 0.0:
				velocity.x = 0.0
				_ram_cd = RAM_COOLDOWN
				Game.add_shake(2.0)
				Game.sfx("clang", -10.0, 1.4)
				_start(RECOVER, RAM_RECOVER)
		RECOVER:
			_brake(delta)
			set_frame(0)
			if _timer <= 0.0:
				_state = WALK
	move_and_slide()
	_ticker.queue_redraw()


func _start(s: int, t: float) -> void:
	_state = s
	_timer = t
	velocity.x = 0.0


func _finish_attack(rest: float) -> void:
	_cool = ATTACK_GAP
	_start(RECOVER, rest)


## 和主角保持中距离：远了往前推车，近了往后退，脸一直朝着主角；台子边、墙边不走
func _walk(p: Player) -> void:
	var move := 0.0
	if p:
		var dx := p.global_position.x - global_position.x
		if absf(dx) > 2.0:
			dir = 1 if dx > 0.0 else -1
		if absf(dx) > FAR:
			move = dir
		elif absf(dx) < NEAR:
			move = -dir
	if move != 0.0 and (not is_on_floor() or not _ground_at(signf(move), 24.0) or _wall_at(signf(move))):
		move = 0.0
	velocity.x = move * WALK_SPEED * speed_mult()
	set_frame(int(_time / WALK_FRAME_TIME) % 4 if move != 0.0 else 0)


func _in_ram_range(p: Player) -> bool:
	var d := p.global_position - global_position
	return d.x * dir >= 0.0 and absf(d.x) <= RAM_RANGE and absf(d.y) <= RAM_HEIGHT


# ---------------------------------------------------------------- 摩斯连发
func _start_morse() -> void:
	_code = CODES[randi() % CODES.size()]
	_beats.clear()
	var t := 0.0
	for c in _code:
		_beats.append(t)
		t += DOT_TIME if c == "." else DASH_TIME
	_morse_t = 0.0
	_fired = 0
	_start(MORSE_WARN, t + MORSE_BEAT)
	warn(t + MORSE_BEAT)


## 预演：照节奏一个个亮、"嘀嗒"响；空一拍；再照同一个节奏一发一发打出去
func _tick_morse(delta: float, p: Player) -> void:
	var was := _morse_t
	_morse_t += delta
	var length := _beats[-1] + (DOT_TIME if _code[-1] == "." else DASH_TIME)
	var fire_at := length + MORSE_BEAT
	for i in _code.length():
		var b := _beats[i]
		if was < b and _morse_t >= b:
			Game.sfx("ready", -12.0, 2.6 if _code[i] == "." else 1.9)
		if was < fire_at + b and _morse_t >= fire_at + b:
			_fire(i, p)
	if _state == MORSE_WARN and _morse_t >= fire_at:
		_state = MORSE
	# 拍下去的那 0.08 秒是第 5 帧，其余是手悬在键上方的第 4 帧
	var tapping := false
	for i in _fired:
		if _morse_t - (fire_at + _beats[i]) < 0.08:
			tapping = true
	set_frame(5 if tapping else 4)
	if _morse_t >= fire_at + length + 0.15:
		_finish_attack(0.3)


func _fire(i: int, p: Player) -> void:
	_fired = i + 1
	var from := global_position + Vector2(KEY_POS.x * -dir, KEY_POS.y)
	var aim := Vector2(dir, 0.0)
	if p and is_instance_valid(p):
		aim = (p.global_position + Vector2(0, -8) - from).normalized()
	var s := MorseShot.new()
	s.dash = _code[i] == "-"
	s.position = from
	s.velocity = aim * (DASH_SPEED if s.dash else DOT_SPEED)
	s.damage = (DASH_DAMAGE if s.dash else DOT_DAMAGE) * damage_mult()
	get_parent().add_child(s)
	Game.sfx("shoot", -10.0, 2.2 if not s.dash else 1.4, 0.05)


## 头顶的电码牌：一块暗底，点 2×2、划 5×2。预演时正在响的那个白亮、响过的红、没响的暗红；
## 开打以后打出去的熄掉
func _draw_ticker() -> void:
	if (_state != MORSE_WARN and _state != MORSE) or dead:
		return
	var widths: Array[int] = []
	var total := 0
	for c in _code:
		widths.append(2 if c == "." else 5)
		total += widths[-1]
	total += 2 * (_code.length() - 1)
	var center := Vector2(TICKER_POS.x * -dir, TICKER_POS.y) + (global_position.round() - global_position)
	var x := roundf(center.x - total / 2.0)
	var y := center.y
	_ticker.draw_rect(Rect2(x - 2, y - 2, total + 4, 6), Color(0.05, 0.03, 0.03, 0.85))
	var length := _beats[-1] + (DOT_TIME if _code[-1] == "." else DASH_TIME)
	var fire_at := length + MORSE_BEAT
	for i in _code.length():
		var col := Color(0.45, 0.1, 0.07)
		if _state == MORSE_WARN:
			if _morse_t >= _beats[i]:
				var end := _beats[i] + (DOT_TIME if _code[i] == "." else DASH_TIME) * 0.7
				col = Color(1.0, 0.92, 0.85) if _morse_t < end else LED_COLOR
		else:
			col = LED_COLOR if _morse_t < fire_at + _beats[i] else Color(0.25, 0.07, 0.05)
		_ticker.draw_rect(Rect2(x, y, widths[i], 2), col)
		x += widths[i] + 2


# ---------------------------------------------------------------- 急电
func _start_relay(p: Player) -> void:
	_start(RELAY_WARN, RELAY_WARN_TIME)
	warn(RELAY_WARN_TIME)
	Game.sfx("jump", -10.0, 0.7)
	var px := clampf(p.global_position.x, global_position.x - RELAY_REACH, global_position.x + RELAY_REACH)
	var xs: Array[float] = []
	for k in [-1, 0, 1]:
		xs.append(px + k * RELAY_SPREAD)
	# 从近到远劈
	xs.sort_custom(func(a, b): return absf(a - global_position.x) < absf(b - global_position.x))
	_relay = RelayLine.new()
	_relay.pole = global_position + Vector2(POLE_TOP.x * -dir, POLE_TOP.y)
	_relay.damage = RELAY_DAMAGE * damage_mult()
	_relay.delay = RELAY_WARN_TIME
	_relay.step = RELAY_STEP
	get_parent().add_child(_relay)
	_relay.setup(xs, p.global_position.y)


func _brake(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)


## 朝左时的判定框 r（朝右时镜像），碰到的主角、地上的马灯都挨打
func _hit_rect(r: Rect2, dmg: float) -> void:
	if dir > 0:
		r.position.x = -r.position.x - r.size.x
	var shape := RectangleShape2D.new()
	shape.size = r.size
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.transform = Transform2D(0.0, global_position + r.get_center())
	q.collision_mask = 2 | 8
	for hit in get_world_2d().direct_space_state.intersect_shape(q, 8):
		var b: Object = hit["collider"]
		if b is Player:
			(b as Player).hurt(global_position, dmg)
		elif b is Crystal:
			(b as Crystal).take_hit(global_position, dmg)


## side 方向脚下有没有地（往后退也要看）
func _ground_at(side: float, dist: float) -> bool:
	var from := global_position + Vector2(side * dist, -2)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 10), 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


## side 方向紧贴着墙（往后退时 is_on_wall 分不清是哪边）
func _wall_at(side: float) -> bool:
	var from := global_position + Vector2(0, -8)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(side * (body_rect.size.x / 2.0 + 3.0), 0), 1)
	q.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _on_die() -> void:
	if is_instance_valid(_relay):
		_relay.queue_free()
	_relay = null


func _on_respawn() -> void:
	_state = WALK
	_cool = 1.0


## 电码打出去的一发：点是 3×3 的电火花（快），划是一根 12 长的电弧（慢），顺着飞的方向画；
## 碰到人或马灯伤一下就没，撞墙就碎，最多飞 2.5 秒
class MorseShot:
	extends Area2D

	const LIFE := 2.5
	const CORE := Color(1.0, 0.97, 0.85)
	const GLOW := Color(1.0, 0.55, 0.3)

	var velocity := Vector2.ZERO
	var dash := false
	var damage := 8.0
	var _t := 0.0
	var _done := false

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 1 | 2 | 8
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(10, 3) if dash else Vector2(3, 3)
		cs.shape = r
		cs.rotation = velocity.angle()
		add_child(cs)
		body_entered.connect(_on_body)
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded
		var glow := PointLight2D.new()
		glow.texture = Game.light_texture()
		glow.color = GLOW
		glow.energy = 0.7
		glow.texture_scale = 0.3 if not dash else 0.45
		add_child(glow)

	func _physics_process(delta: float) -> void:
		_t += delta
		if _t >= LIFE:
			queue_free()
			return
		global_position += velocity * delta
		queue_redraw()

	func _on_body(b: Node) -> void:
		if _done:
			return
		_done = true
		if b is Player:
			(b as Player).hurt(global_position, damage)
		elif b is Crystal:
			(b as Crystal).take_hit(global_position, damage)
		Game.sparks(get_parent(), global_position, GLOW, 4, 60.0)
		Game.sfx("hit", -18.0, 2.4, 0.2)
		queue_free()

	func _draw() -> void:
		var o := global_position.round() - global_position
		var flick := int(_t * 30.0) % 2 == 0
		if not dash:
			draw_rect(Rect2(o + Vector2(-1, -1), Vector2(3, 3)), GLOW)
			draw_rect(Rect2(o, Vector2.ONE), CORE)
			if flick:
				draw_rect(Rect2(o + Vector2(-2, 0), Vector2(1, 1)), GLOW)
			return
		# 划：沿飞行方向一格一格点出来，中间亮芯，两头暗；整根一抖一抖（电弧）
		var d := velocity.normalized()
		for k in range(-6, 6):
			var p := (o + d * k).round()
			var jit := Vector2(0, (1 if (k + int(_t * 30.0)) % 3 == 0 else 0))
			draw_rect(Rect2(p + jit, Vector2.ONE), CORE if absi(k) < 4 else GLOW)
			if absi(k) < 5:
				draw_rect(Rect2(p + jit + Vector2(0, -1), Vector2.ONE), Color(GLOW, 0.8))


## 急电：车头电线杆 → 天花板 → 横着架过三个落点的一根电线；三个落点地上亮红标记、上方一列虚点。
## delay 秒后一个电报脉冲沿线跑过去，按顺序（从近到远）每隔 step 秒往下劈一道（宽 8，0.15 秒），劈到的人挨打。
## 挂在关卡上，世界坐标，不吃压暗。
class RelayLine:
	extends Node2D

	const BOLT_W := 8.0
	const BOLT_TIME := 0.15
	const WIRE := Color(0.62, 0.5, 0.32)
	const PULSE := Color(1.0, 0.95, 0.8)

	var pole := Vector2.ZERO
	var damage := 12.0
	var delay := 0.8
	var step := 0.22
	var _t := 0.0
	## 每个落点：{x, floor, ceil, hit_at, hit}
	var _spots: Array = []
	var _wire_y := 0.0

	func setup(xs: Array[float], ground_hint: float) -> void:
		var space := get_world_2d().direct_space_state
		for i in xs.size():
			var x: float = xs[i]
			# 地面：从主角脚那一层往下找；天花板：从地面往上找，找不到就用 100 高
			var q := PhysicsRayQueryParameters2D.create(Vector2(x, ground_hint - 30.0), Vector2(x, ground_hint + 120.0), 1)
			var hit := space.intersect_ray(q)
			var floor_y: float = (hit["position"] as Vector2).y if not hit.is_empty() else ground_hint
			var q2 := PhysicsRayQueryParameters2D.create(Vector2(x, floor_y - 4.0), Vector2(x, floor_y - 140.0), 1)
			var hit2 := space.intersect_ray(q2)
			var c: float = (hit2["position"] as Vector2).y + 1.0 if not hit2.is_empty() else floor_y - 100.0
			_spots.append({"x": roundf(x), "floor": roundf(floor_y), "ceil": c, "hit_at": delay + i * step, "hit": false})
		# 电线架在天花板下面 3 格（几个落点里最低的那块天花板）
		var low := -INF
		for s in _spots:
			low = maxf(low, s["ceil"])
		_wire_y = roundf(minf(low + 3.0, pole.y - 8.0))

	func _ready() -> void:
		top_level = true
		global_position = Vector2.ZERO
		z_index = 8
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded

	func _physics_process(delta: float) -> void:
		_t += delta
		for s in _spots:
			if not s["hit"] and _t >= s["hit_at"]:
				s["hit"] = true
				_strike(s)
		if _t >= delay + step * _spots.size() + BOLT_TIME + 0.1:
			queue_free()
			return
		queue_redraw()

	func _strike(s: Dictionary) -> void:
		var top: float = _wire_y
		var bottom: float = s["floor"]
		var shape := RectangleShape2D.new()
		shape.size = Vector2(BOLT_W, bottom - top)
		var q := PhysicsShapeQueryParameters2D.new()
		q.shape = shape
		q.transform = Transform2D(0.0, Vector2(s["x"], (top + bottom) / 2.0))
		q.collision_mask = 2 | 8
		for hit in get_world_2d().direct_space_state.intersect_shape(q, 8):
			var b: Object = hit["collider"]
			if b is Player:
				(b as Player).hurt(Vector2(s["x"], bottom), damage)
			elif b is Crystal:
				(b as Crystal).take_hit(Vector2(s["x"], bottom), damage)
		Game.sfx("crack", -6.0, 1.6, 0.1)
		Game.add_shake(1.5)
		Game.sparks(get_parent(), Vector2(s["x"], bottom - 1.0), PULSE, 6, 80.0, Vector2.UP)

	func _draw() -> void:
		if _spots.is_empty():
			return
		var red := EnemyBase.LED_COLOR
		var blink := int(_t * 10.0) % 2 == 0
		var first: Dictionary = _spots[0]
		var last: Dictionary = _spots[-1]
		var x0 := minf(minf(first["x"], last["x"]), pole.x)
		var x1 := maxf(maxf(first["x"], last["x"]), pole.x)
		# 电线：从电线杆竖着上去，再横着架过去（甩出去的头 0.15 秒线往上长）
		var grow := clampf(_t / 0.15, 0.0, 1.0)
		var pole_px := pole.round()
		var up_to := roundf(lerpf(pole_px.y, _wire_y, grow))
		draw_rect(Rect2(pole_px.x, up_to, 1, pole_px.y - up_to), WIRE)
		if grow >= 1.0:
			var far_x: float = last["x"] if absf(last["x"] - pole.x) > absf(first["x"] - pole.x) else first["x"]
			var a := minf(pole_px.x, far_x)
			var b := maxf(pole_px.x, far_x)
			draw_rect(Rect2(a, _wire_y, b - a + 1, 1), WIRE)
			# 线上每个落点一颗小绝缘子
			for s in _spots:
				draw_rect(Rect2(s["x"] - 1, _wire_y, 3, 2), Color(0.3, 0.55, 0.36))
		# 落点：地上一道红线、上方一列虚点（快劈的时候虚点变实、变亮）
		for s in _spots:
			if s["hit"] and _t > s["hit_at"] + BOLT_TIME:
				continue
			var left: float = s["hit_at"] - _t
			var fx: float = s["x"]
			var fy: float = s["floor"]
			if left > 0.0:
				var col := red if blink or left < 0.25 else red.darkened(0.45)
				draw_rect(Rect2(fx - 4, fy - 1, 9, 1), Color(col, 0.9))
				draw_rect(Rect2(fx, fy - 3, 1, 2), col)
				var gap := 2 if left < 0.25 else 4
				var y := fy - 6.0
				while y > _wire_y + 2.0:
					draw_rect(Rect2(fx, y, 1, 1), Color(col, 0.5 if left > 0.25 else 0.8))
					y -= gap
			else:
				_draw_bolt(fx, _wire_y + 1.0, fy, s["hit_at"])
		# 电报脉冲：沿线从电线杆跑到最远的落点
		var run := (_t - delay + step) / (step * _spots.size())
		if run > 0.0 and run < 1.0:
			var far_x2: float = last["x"]
			var px := roundf(lerpf(pole.x, far_x2, run))
			draw_rect(Rect2(px - 1, _wire_y - 1, 3, 3), PULSE)

	## 一道竖的落雷：锯齿的亮芯（每 3 格左右错一格），两边一圈暗橙，宽 8 的范围里偶尔迸一点
	func _draw_bolt(x: float, top: float, bottom: float, seed_t: float) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(seed_t * 1000.0) + int(_t * 60.0)
		var cx := x
		var y := top
		while y < bottom:
			var seg := minf(3.0, bottom - y)
			draw_rect(Rect2(cx - 1, y, 3, seg), Color(1.0, 0.55, 0.3, 0.8))
			draw_rect(Rect2(cx, y, 1, seg), PULSE)
			y += seg
			cx = clampf(cx + rng.randi_range(-1, 1), x - 3, x + 3)
		draw_rect(Rect2(x - 4, bottom - 1, 9, 1), PULSE)
