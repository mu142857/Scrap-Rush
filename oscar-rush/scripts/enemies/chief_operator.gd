class_name ChiefOperator
extends EliteBase
## 总接线长（第二关精英怪，E3 电话簿仓库）：接线员们的头儿。高个子，深紫黑长袍拖地，尖帽兜上箍着黄铜耳机、
## 前面伸着话筒，背后插着五根电话线，像一把扇子，线头都是黄铜插头。慢慢飘着，和主角保持一段距离。
## 两招轮着放，都先冒红色"!"；血掉到 60% 和 30% 各叫一次班：
## - 拽线：手举过头攥着插头，一条红色虚线瞄着主角（跟 0.5 秒，再锁住 0.3 秒），然后插头顺着虚线飞出去。
##   插头钩到主角就把人顺着线拽回来（不伤人），拽到跟前（或拽满 0.7 秒）抡一下，伤 12。
##   锁住以后从虚线上跳开或者走开就躲掉了。钩不到就把线收回去。
## - 转线：背后的线全炸开（地上和身边一圈红色像素圈闪 0.7 秒），然后五根线绕着身子甩 1.1 秒，
##   半径 50 以内都挨 10。预警时走出红圈就安全。拽线和转线连着来：被拽过去以后下一招常常就是转线。
## - 叫班：两手举起来，身边掉下两个接线员（hooded_operator.gd），算进这一场遭遇战。
## 拽来的线、转着的线、瞄准虚线、红圈都是代码画的（unshaded，暗处也看得清）。
## 贴图 chief_operator.png（草图/精英怪/l2_robed_elites.py 导出），6 帧：
## 0、1 飘；2 拽线预警（手举过头）；3 拽线（手往前伸直）；4 转线（两手张开，背后的线炸开）；5 叫班（两手举起来）。

enum State { MOVE, HOOK_AIM, HOOK_LOCK, HOOK_FLY, HOOK_PULL, HOOK_SLAM, HOOK_BACK, SPIN_WARN, SPIN, CALL, RECOVER }

const MOVE_SPEED := 18.0
const FRAME_TIME := 0.3
const NEAR := 70.0
const FAR := 150.0
## 招与招之间歇多久（精英怪不乘 interval_mult，照钢琴：情绪高时招看不清）
const IDLE_TIME := Vector2(2.0, 2.6)
## 拽线
const AIM_TIME := 0.5
const LOCK_TIME := 0.3
const PLUG_SPEED := 380.0
const PLUG_RANGE := 210.0
const PULL_SPEED := 220.0
const PULL_TIME := 0.7
const SLAM_DIST := 30.0
const SLAM_DAMAGE := 12.0
## 拽线时手的位置（原图朝左，相对脚底中点）：举过头 / 往前伸直
const HAND_UP := Vector2(-12, -46)
const HAND_FWD := Vector2(-19, -29)
## 转线
const SPIN_WARN := 0.7
const SPIN_TIME := 1.1
const SPIN_R := 50.0
const SPIN_DAMAGE := 10.0
const CHEST := Vector2(0, -28)
## 叫班
const CALL_TIME := 0.8
const CALL_AT := [0.6, 0.3]
const RECOVER_TIME := 0.7
const CORD := Color(0.8, 0.74, 0.86)
const BRASS := Color(1.0, 0.8, 0.45)
const AIM := Color(1.0, 0.25, 0.2)

var state := State.MOVE
var _state_t := 0.0
var _idle := 1.4
var _next_attack := 0
var _attack_dir := -1
var _aim := Vector2.LEFT
var _plug := Vector2.ZERO
var _plug_from := Vector2.ZERO
var _hooked: Player = null
var _hit_done := false
var _calls_done := 0
var _call_pending := false
var _summoned: Array[Node] = []
var _fx2: Node2D


func _setup() -> void:
	elite_name = "CHIEF OPERATOR"
	intro_title = "HOLD THE LINE"
	intro_frame = 4
	texture_path = "res://art/enemies/chief_operator.png"
	hframes = 6
	frame_size = Vector2i(50, 53)
	body_rect = Rect2(-12, -48, 24, 48)
	led_pixel = Vector2i(20, 12)
	led_by_frame = {1: Vector2i(20, 11), 3: Vector2i(19, 12), 5: Vector2i(20, 11)}
	max_hp = 1300.0
	contact_damage = 10.0


func _after_ready() -> void:
	_unstick()
	_fx2 = Node2D.new()
	_fx2.top_level = true
	_fx2.z_index = 4
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_fx2.material = unshaded
	_fx2.draw.connect(_draw_fx2)
	add_child(_fx2)


## 出生时头顶卡在天花板里就往下挪（遭遇战有统一处理，保险一下）
func _unstick() -> void:
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = _shape.shape
	q.collision_mask = 1
	q.exclude = [get_rid()]
	var space := get_world_2d().direct_space_state
	for i in 40:
		q.transform = Transform2D(0.0, global_position + _shape.position)
		if space.intersect_shape(q, 1).is_empty():
			return
		global_position.y += 2.0


func _tick(delta: float) -> void:
	_state_t += delta
	if not is_knocked():
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	match state:
		State.MOVE:
			_move(delta)
			if _state_t >= _idle and is_on_floor():
				_start_attack()
		State.HOOK_AIM:
			set_frame(2)
			var p := nearest_player()
			if p:
				_face(p)
				_attack_dir = dir
				_aim_at(p.global_position + Vector2(0, -8))
			if _state_t >= AIM_TIME:
				_enter(State.HOOK_LOCK)
				Game.sfx("ready", -8.0, 1.7)
		State.HOOK_LOCK:
			set_frame(2)
			if _state_t >= LOCK_TIME:
				_plug_from = _hand(HAND_FWD)
				_plug = _plug_from
				_enter(State.HOOK_FLY)
				Game.sfx("whistle", -8.0, 1.9, 0.1)
				Game.sfx("scrape", -10.0, 1.3)
		State.HOOK_FLY:
			set_frame(3)
			_plug += _aim * PLUG_SPEED * delta
			var p := _player_at(_plug)
			if p:
				_hooked = p
				_enter(State.HOOK_PULL)
				Game.sfx("clang", -6.0, 1.6)
				Game.sparks(get_parent(), _plug, BRASS, 6, 60.0)
			elif _plug.distance_to(_plug_from) >= PLUG_RANGE or _in_wall(_plug):
				_enter(State.HOOK_BACK)
		State.HOOK_PULL:
			set_frame(3)
			if not is_instance_valid(_hooked):
				_enter(State.HOOK_BACK)
			else:
				var target := global_position + Vector2(_attack_dir * SLAM_DIST * 0.6, 0)
				var d := target.x - _hooked.global_position.x
				if absf(d) > 1.0:
					_hooked.move_and_collide(Vector2(signf(d) * minf(PULL_SPEED * delta, absf(d)), 0))
				_hooked.velocity.x = 0.0
				_plug = _hooked.global_position + Vector2(0, -8)
				if absf(_hooked.global_position.x - global_position.x) <= SLAM_DIST or _state_t >= PULL_TIME:
					_enter(State.HOOK_SLAM)
		State.HOOK_SLAM:
			set_frame(2 if _state_t < 0.12 else 3)
			if _state_t >= 0.12 and not _hit_done:
				_hit_done = true
				Game.sfx("crack", -6.0, 1.2)
				Game.add_shake(3.0)
				if is_instance_valid(_hooked) and absf(_hooked.global_position.x - global_position.x) <= SLAM_DIST + 14.0:
					_hooked.hurt(global_position, SLAM_DAMAGE * damage_mult())
			if _state_t >= 0.35:
				_hooked = null
				_enter(State.RECOVER)
		State.HOOK_BACK:
			set_frame(3)
			# 线收回来
			var k := clampf(_state_t / 0.3, 0.0, 1.0)
			_plug = _plug.lerp(_hand(HAND_FWD), k)
			if _state_t >= 0.3:
				_enter(State.RECOVER)
		State.SPIN_WARN:
			set_frame(4)
			if _state_t >= SPIN_WARN:
				_enter(State.SPIN)
				Game.sfx("whistle", -6.0, 1.3)
				Game.sfx("jet", -10.0, 1.6)
		State.SPIN:
			set_frame(4)
			if not _hit_done:
				for n in get_tree().get_nodes_in_group("player"):
					var p := n as Player
					if p and _chest().distance_to(p.global_position + Vector2(0, -8)) <= SPIN_R:
						if p.hurt(_chest(), SPIN_DAMAGE * damage_mult()):
							_hit_done = true
			if int(_state_t / 0.18) != int((_state_t - delta) / 0.18):
				Game.sfx("whistle", -16.0, 2.2, 0.1)
			if _state_t >= SPIN_TIME:
				_enter(State.RECOVER)
		State.CALL:
			set_frame(5)
			if _state_t >= 0.4 and not _hit_done:
				_hit_done = true
				_call_operators()
			if _state_t >= CALL_TIME:
				_enter(State.RECOVER)
		State.RECOVER:
			set_frame(0)
			if _state_t >= RECOVER_TIME:
				_enter(State.MOVE)
	move_and_slide()
	_fx2.queue_redraw()


func _enter(s: State) -> void:
	state = s
	_state_t = 0.0
	if s == State.MOVE:
		_idle = randf_range(IDLE_TIME.x, IDLE_TIME.y)
	if s in [State.HOOK_SLAM, State.SPIN, State.CALL]:
		_hit_done = false


func _start_attack() -> void:
	var p := nearest_player()
	if p:
		_face(p)
	_attack_dir = dir
	velocity.x = 0.0
	if _call_pending:
		_call_pending = false
		warn(0.6)
		_enter(State.CALL)
		Game.sfx("bell", -6.0, 0.8)
		return
	if _next_attack == 0:
		warn(AIM_TIME + LOCK_TIME)
		_enter(State.HOOK_AIM)
		Game.sfx("dial", -8.0, 0.9)
	else:
		warn(SPIN_WARN)
		_enter(State.SPIN_WARN)
		Game.sfx("charge", -10.0, 0.7)
	_next_attack = (_next_attack + 1) % 2


func _move(delta: float) -> void:
	var p := nearest_player()
	var side := 0.0
	if p:
		_face(p)
		var dx := p.global_position.x - global_position.x
		if absf(dx) > FAR:
			side = signf(dx)
		elif absf(dx) < NEAR:
			side = -signf(dx)
	if side != 0.0 and (not _ground_at(side) or _wall_at(side)):
		side = 0.0
	if not is_knocked():
		velocity.x = move_toward(velocity.x, side * MOVE_SPEED * speed_mult(), 300.0 * delta)
	set_frame(int(_time / FRAME_TIME) % 2)


func _face(p: Node2D) -> void:
	if absf(p.global_position.x - global_position.x) > 2.0:
		dir = 1 if p.global_position.x > global_position.x else -1


func _hand(h: Vector2) -> Vector2:
	return global_position.round() + Vector2(h.x * -_attack_dir, h.y)


func _chest() -> Vector2:
	return global_position.round() + CHEST


## 瞄准方向：只往自己朝的那边，上下最多 40°
func _aim_at(point: Vector2) -> void:
	var from := _hand(HAND_FWD)
	var d := point - from
	var a := clampf(atan2(d.y, absf(d.x)), -0.7, 0.7)
	_aim = Vector2(cos(a) * _attack_dir, sin(a))


func _player_at(pos: Vector2) -> Player:
	for n in get_tree().get_nodes_in_group("player"):
		var p := n as Player
		if p and Rect2(p.global_position + Vector2(-4, -17), Vector2(8, 18)).has_point(pos):
			return p
	return null


func _in_wall(pos: Vector2) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = pos
	q.collision_mask = 1
	return not get_world_2d().direct_space_state.intersect_point(q, 1).is_empty()


func _ground_at(side: float) -> bool:
	var from := global_position + Vector2(side * 14.0, -2)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 8), 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _wall_at(side: float) -> bool:
	var from := global_position + Vector2(0, -10)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(side * 16.0, 0), 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


## 血掉到 60%、30% 各叫一次班（下一招就是叫班）
func _on_hurt(_damage: float, _full: bool) -> void:
	if _calls_done < CALL_AT.size() and hp / max_hp <= CALL_AT[_calls_done]:
		_calls_done += 1
		_call_pending = true


## 叫两个接线员下来，算进这一场遭遇战（找不到遭遇战就直接加进关卡）
func _call_operators() -> void:
	for m in _summoned.duplicate():
		if not is_instance_valid(m) or m.get("dead"):
			_summoned.erase(m)
	var path := "res://scripts/enemies/hooded_operator.gd"
	if not ResourceLoader.exists(path):
		path = "res://scripts/enemies/crawler.gd"
	var enc := _encounter()
	for s in [-1.0, 1.0]:
		if _summoned.size() >= 2:
			break
		var x: float = global_position.x + s * 44.0
		if _in_wall(Vector2(x, global_position.y - 12.0)):
			x = global_position.x - s * 20.0
		var e: Node2D = (load(path) as GDScript).new()
		e.set("respawn_time", 0.0)
		e.position = Vector2(roundf(x), global_position.y - 30.0)
		get_parent().add_child(e)
		_summoned.append(e)
		if enc:
			var alive = enc.get("_alive")
			if alive is Array:
				alive.append(e)
		Game.sparks(get_parent(), Vector2(x, global_position.y - 30.0), BRASS, 8, 60.0)
	Game.sfx("ding", -6.0, 1.4)
	Game.add_shake(2.0)


func _encounter() -> Node:
	var parent := get_parent()
	if parent == null:
		return null
	for c in parent.get_children():
		if c is Encounter and not (c as Encounter).cleared:
			var e := c as Encounter
			if global_position.x >= e.left - 8.0 and global_position.x <= e.right + 8.0:
				return e
	return null


## 预警时机身抖一抖
func _update_visual() -> void:
	super._update_visual()
	if state in [State.HOOK_LOCK, State.SPIN_WARN]:
		_sprite.position.x += 1.0 if int(_state_t * 30.0) % 2 == 0 else -1.0


func _draw_fx2() -> void:
	if dead or in_intro():
		return
	match state:
		State.HOOK_AIM, State.HOOK_LOCK:
			# 红色虚线：瞄的时候淡，锁住以后一闪一闪
			var from := _hand(HAND_FWD)
			var on := state == State.HOOK_AIM or int(_state_t / 0.06) % 2 == 0
			var a := 0.45 if state == State.HOOK_AIM else (0.95 if on else 0.3)
			for i in range(0, int(PLUG_RANGE), 6):
				var p := (from + _aim * i).round()
				_fx2.draw_rect(Rect2(p, Vector2(3, 1)), Color(AIM, a))
			# 举着的插头一闪
			var h := _hand(HAND_UP)
			_fx2.draw_rect(Rect2(h + Vector2(-1, -2), Vector2(2, 2)), BRASS)
		State.HOOK_FLY, State.HOOK_PULL, State.HOOK_BACK:
			_draw_cord(_hand(HAND_FWD), _plug)
		State.SPIN_WARN:
			var k := _state_t / SPIN_WARN
			if int(_state_t / (0.1 - 0.05 * k)) % 2 == 0:
				_pixel_ring(_chest(), int(SPIN_R), Color(AIM, 0.75))
			# 背后的线一根根竖起来
			for i in 5:
				var ang := -PI / 2.0 + (i - 2) * 0.45 - _attack_dir * 0.4
				_draw_cord(_chest(), _chest() + Vector2(cos(ang), sin(ang)) * (18.0 + 8.0 * k))
		State.SPIN:
			var spin := _state_t * TAU * 1.6 * -_attack_dir
			for i in 5:
				var ang := spin + i * TAU / 5.0
				_draw_cord(_chest(), _chest() + Vector2(cos(ang), sin(ang)) * SPIN_R)
			# 甩出来的一圈淡淡的拖影
			_pixel_ring(_chest(), int(SPIN_R), Color(CORD, 0.25))


## 一根电话线：从 a 到 b，一格上一格下像螺旋线，线头一个黄铜插头
func _draw_cord(a: Vector2, b: Vector2) -> void:
	var d := b - a
	var n := int(d.length())
	if n < 1:
		return
	var nrm := Vector2(-d.y, d.x).normalized()
	for i in n:
		var w := 0.0 if i % 3 == 0 else (1.0 if i % 3 == 1 else -1.0)
		var p := (a + d * (float(i) / n) + nrm * w).round()
		_fx2.draw_rect(Rect2(p, Vector2.ONE), CORD)
	_fx2.draw_rect(Rect2(b.round() + Vector2(-1, -1), Vector2(3, 3)), BRASS)


## 一格一个点的像素圆（中点画圆法），半透明时不会叠出亮点
func _pixel_ring(c: Vector2, radius: int, col: Color) -> void:
	var pts := {}
	var x := radius
	var y := 0
	var err := 1 - radius
	while x >= y:
		for p in [Vector2i(x, y), Vector2i(y, x), Vector2i(-y, x), Vector2i(-x, y),
				Vector2i(-x, -y), Vector2i(-y, -x), Vector2i(y, -x), Vector2i(x, -y)]:
			pts[p] = true
		y += 1
		if err < 0:
			err += 2 * y + 1
		else:
			x -= 1
			err += 2 * (y - x) + 1
	for p in pts:
		_fx2.draw_rect(Rect2(c.round() + Vector2(p), Vector2.ONE), col)


func _on_respawn() -> void:
	_enter(State.MOVE)
