class_name FilmEditor
extends EliteBase
## 剪辑师（第二关精英怪，第一场换卷战，胶片天桥）：驼背高个子，褐色长大褂，帽兜上压着遮光帽檐，
## 肩上搭着两条胶片，手里一把和半个人一样长的大剪刀。在天桥上追着主角走，两招轮着放，都先冒红色"!"：
## - 剪刀冲：压低身子把剪刀张开举起来（0.7 秒，身子一闪一闪发红），然后张着剪刀贴地往前冲
##   （每秒 260，冲过主角 60 像素、撞到闸门或冲满 300 就停），停下"咔嚓"合一下。
##   冲的时候剪刀那一截（身前 44 像素、地面往上 8～26）伤 12，身子碰到伤 10。要跳起来飞过去，或者站到它背后。
## - 跳剪：像胶片被剪掉了一段——人一闪一闪（白色片框线），然后整个消失 0.35 秒，主角身后 46 像素的地上
##   出现红色的剪辑标记（像剪辑台上的"><"记号）闪 0.5 秒，它从标记那里冒出来，剪刀举过头顶往前剪下去：
##   身前 40 像素、地面往上 0～40 伤 14。看到标记就往前跑开。身后是墙（闸门）就落在主角前面。
## 消失的时候打不到。闪烁、标记、速度线、剪下去的白光都是代码画的（unshaded，暗处看得清）。
## 贴图 film_editor.png（草图/精英怪/l2_robed_elites.py 导出），6 帧：
## 0、1 走；2 冲刺预警（压低、剪刀张开举起来）；3 冲刺（往前扑，剪刀张开朝前）；4 剪（合上）；5 跳剪落下（举过头顶）。

enum State { CHASE, CHARGE_WARN, CHARGE, SNIP, CUT_WARN, CUT_GONE, CUT_DROP, CUT_SNIP, RECOVER }

const WALK_SPEED := 30.0
const FRAME_TIME := 0.22
const STOP := 40.0
const IDLE_TIME := Vector2(1.8, 2.4)
## 剪刀冲
const CHARGE_WARN := 0.7
const CHARGE_SPEED := 260.0
const CHARGE_MAX := 300.0
const OVERSHOOT := 60.0
const SHEARS := Rect2(-44, -26, 44, 18)
const CHARGE_DAMAGE := 12.0
const SNIP_TIME := 0.3
const SNIP_RECT := Rect2(-44, -22, 46, 10)
## 跳剪
const CUT_WARN := 0.6
const GONE_TIME := 0.35
const MARK_TIME := 0.5
const BEHIND := 46.0
const DROP_TIME := 0.22
const CUT_RECT := Rect2(-40, -40, 44, 40)
const CUT_DAMAGE := 14.0
const RECOVER_TIME := 0.7
const MARK := Color(1.0, 0.25, 0.2)
const FLASH := Color(1.0, 0.95, 0.85)

var state := State.CHASE
var _state_t := 0.0
var _idle := 1.2
var _next_attack := 0
var _attack_dir := -1
var _start_x := 0.0
var _stop_x := 0.0
var _mark := Vector2.ZERO
var _hit_done := false
var _trail: Array[Vector2] = []
var _fx2: Node2D


func _setup() -> void:
	elite_name = "FILM EDITOR"
	intro_title = "FINAL CUT"
	intro_frame = 2
	texture_path = "res://art/enemies/film_editor.png"
	hframes = 6
	frame_size = Vector2i(88, 48)
	body_rect = Rect2(-11, -42, 22, 42)
	led_pixel = Vector2i(40, 11)
	led_by_frame = {1: Vector2i(40, 10), 2: Vector2i(40, 15), 3: Vector2i(37, 17), 4: Vector2i(37, 17)}
	max_hp = 1200.0
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


func is_targetable() -> bool:
	return super.is_targetable() and state != State.CUT_GONE


func hurt(damage: float, from_dir: Vector2, full: bool) -> void:
	# 跳剪消失的时候打不到
	if state == State.CUT_GONE:
		return
	super.hurt(damage, from_dir, full)


func _tick(delta: float) -> void:
	_state_t += delta
	match state:
		State.CHASE:
			_chase(delta)
			if _state_t >= _idle and is_on_floor():
				_start_attack()
		State.CHARGE_WARN:
			_brake(delta)
			set_frame(2)
			if _state_t >= CHARGE_WARN:
				_start_x = global_position.x
				var p := nearest_player()
				var px := p.global_position.x if p else global_position.x + _attack_dir * 200.0
				_stop_x = px + _attack_dir * OVERSHOOT
				_trail.clear()
				_enter(State.CHARGE)
				Game.sfx("jet", -6.0, 1.3)
				Game.sfx("scrape", -6.0, 1.0)
		State.CHARGE:
			set_frame(3)
			velocity.x = _attack_dir * CHARGE_SPEED * speed_mult()
			if int(_state_t / 0.04) != int((_state_t - delta) / 0.04):
				_trail.append(global_position.round())
				if _trail.size() > 6:
					_trail.pop_front()
			_hit_rect(SHEARS, CHARGE_DAMAGE)
			var gone := absf(global_position.x - _start_x)
			if (global_position.x - _stop_x) * _attack_dir >= 0.0 or gone >= CHARGE_MAX or is_on_wall() \
					or (_state_t > 0.1 and not _ground_at(_attack_dir)):
				velocity.x = 0.0
				_enter(State.SNIP)
				Game.sfx("crack", -4.0, 1.8)
				Game.add_shake(2.0)
				Game.dust(get_parent(), global_position, 4, -_attack_dir)
		State.SNIP:
			_brake(delta)
			set_frame(4)
			if not _hit_done:
				_hit_rect(SNIP_RECT, CHARGE_DAMAGE)
			if _state_t >= SNIP_TIME:
				_trail.clear()
				_enter(State.RECOVER)
		State.CUT_WARN:
			_brake(delta)
			set_frame(0)
			if _state_t >= CUT_WARN:
				_pick_mark()
				_enter(State.CUT_GONE)
				_set_solid(false)
				Game.sfx("tvoff", -6.0, 1.4)
				Game.sparks(get_parent(), aim_point(), FLASH, 8, 60.0)
		State.CUT_GONE:
			velocity.x = 0.0
			if _state_t >= MARK_TIME:
				global_position = _mark
				reset_physics_interpolation()
				var p := nearest_player()
				if p:
					dir = 1 if p.global_position.x > global_position.x else -1
				_attack_dir = dir
				_set_solid(true)
				_enter(State.CUT_DROP)
				Game.sfx("tvon", -6.0, 1.6)
				Game.sparks(get_parent(), aim_point(), FLASH, 10, 70.0)
		State.CUT_DROP:
			velocity.x = 0.0
			set_frame(5)
			if _state_t >= DROP_TIME:
				_enter(State.CUT_SNIP)
				Game.sfx("crack", -4.0, 1.5)
				Game.add_shake(3.0)
		State.CUT_SNIP:
			velocity.x = 0.0
			set_frame(4)
			if not _hit_done:
				_hit_rect(CUT_RECT, CUT_DAMAGE)
			if _state_t >= SNIP_TIME:
				_enter(State.RECOVER)
		State.RECOVER:
			_brake(delta)
			set_frame(0)
			if _state_t >= RECOVER_TIME:
				_enter(State.CHASE)
	move_and_slide()
	_fx2.queue_redraw()


func _enter(s: State) -> void:
	state = s
	_state_t = 0.0
	_hit_done = false
	if s == State.CHASE:
		_idle = randf_range(IDLE_TIME.x, IDLE_TIME.y)


func _start_attack() -> void:
	var p := nearest_player()
	if p:
		dir = 1 if p.global_position.x > global_position.x else -1
	_attack_dir = dir
	velocity.x = 0.0
	if _next_attack == 0:
		warn(CHARGE_WARN)
		_enter(State.CHARGE_WARN)
		Game.sfx("charge", -8.0, 1.1)
	else:
		warn(CUT_WARN)
		_enter(State.CUT_WARN)
		Game.sfx("static", -10.0, 1.2)
	_next_attack = (_next_attack + 1) % 2


func _chase(delta: float) -> void:
	var p := nearest_player()
	var side := 0.0
	if p:
		var dx := p.global_position.x - global_position.x
		if absf(dx) > 2.0:
			dir = 1 if dx > 0.0 else -1
		if absf(dx) > STOP:
			side = dir
	if side != 0.0 and (not _ground_at(side) or _wall_at(side)):
		side = 0.0
	if not is_knocked():
		velocity.x = move_toward(velocity.x, side * WALK_SPEED * speed_mult(), 400.0 * delta)
	set_frame(int(_time / FRAME_TIME) % 2 if absf(velocity.x) > 2.0 else 0)


func _brake(delta: float) -> void:
	if not is_knocked():
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)


## 跳剪的落点：主角身后 BEHIND 像素的地面；那边是墙或者没地就换到主角前面
func _pick_mark() -> void:
	var p := nearest_player()
	if p == null:
		_mark = global_position
		return
	var side := signf(p.global_position.x - global_position.x)
	if side == 0.0:
		side = float(_attack_dir)
	for s in [side, -side]:
		var x: float = p.global_position.x + s * BEHIND
		var from := p.global_position + Vector2(0, -10)
		var wall := PhysicsRayQueryParameters2D.create(from, Vector2(x + s * 12.0, from.y), 1)
		if not get_world_2d().direct_space_state.intersect_ray(wall).is_empty():
			continue
		var q := PhysicsRayQueryParameters2D.create(Vector2(x, p.global_position.y - 20.0), Vector2(x, p.global_position.y + 60.0), 1)
		var hit := get_world_2d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			_mark = (hit.position as Vector2).round()
			return
	_mark = global_position


## 消失的时候：不挡人、碰到不伤人（贴图和红灯在 _update_visual 里藏；整个节点不能藏，不然标记也画不出来）
func _set_solid(on: bool) -> void:
	_shape.set_deferred("disabled", not on)
	_contact.set_deferred("monitoring", on)


## 打一个相对脚底的框（原图朝左，朝右时镜像）里的主角和地上的马灯
func _hit_rect(r: Rect2, dmg: float) -> void:
	var o := global_position.round()
	var rr := Rect2(o.x + (r.position.x if _attack_dir < 0 else -r.end.x), o.y + r.position.y, r.size.x, r.size.y)
	for n in get_tree().get_nodes_in_group("player"):
		var p := n as Player
		if p and rr.intersects(Rect2(p.global_position + Vector2(-3, -16), Vector2(6, 16))):
			if p.hurt(o, dmg * damage_mult()):
				_hit_done = true
	for n in get_tree().get_nodes_in_group("crystal"):
		var c := n as Crystal
		if c and c.carrier == null and rr.intersects(Rect2(c.global_position + Vector2(-2.5, -8), Vector2(5, 8))):
			c.take_hit(o, dmg * damage_mult())


func _ground_at(side: float) -> bool:
	var from := global_position + Vector2(side * 14.0, -2)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 10), 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _wall_at(side: float) -> bool:
	var from := global_position + Vector2(0, -10)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(side * 16.0, 0), 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


## 预警：冲刺前一闪一闪发红、抖；跳剪前人一闪一闪（隔帧消失）
func _update_visual() -> void:
	super._update_visual()
	_sprite.modulate = Color.WHITE
	if state == State.CHARGE_WARN:
		var k := _state_t / CHARGE_WARN
		_sprite.position.x += 1.0 if int(_state_t * 30.0) % 2 == 0 else -1.0
		var pulse := 0.5 + 0.5 * sin(_state_t * (14.0 + 20.0 * k))
		_sprite.modulate = Color.WHITE.lerp(Color(1.8, 0.75, 0.6), pulse * (0.4 + 0.6 * k))
	elif state == State.CUT_WARN:
		var k := _state_t / CUT_WARN
		_sprite.visible = int(_state_t * (10.0 + 20.0 * k)) % 2 == 0
	elif state == State.CUT_GONE:
		_sprite.visible = false
		_led.visible = false
	else:
		_sprite.visible = true


func _draw_fx2() -> void:
	if dead or in_intro():
		return
	var o := global_position.round()
	match state:
		State.CUT_WARN:
			# 白色片框线：身子两边两道竖线、上下两道横线，一闪一闪，像胶片的一格要被剪掉
			if int(_state_t * 16.0) % 2 == 0:
				var r := Rect2(o.x - 16.0, o.y - 48.0, 32, 48)
				var c := Color(FLASH, 0.7)
				_fx2.draw_rect(Rect2(r.position, Vector2(1, r.size.y)), c)
				_fx2.draw_rect(Rect2(r.position + Vector2(r.size.x - 1, 0), Vector2(1, r.size.y)), c)
				_fx2.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), c)
				_fx2.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), c)
		State.CUT_GONE:
			# 剪辑标记：地上一对"><"，越到后面闪得越快
			var k := _state_t / MARK_TIME
			if int(_state_t / (0.1 - 0.06 * k)) % 2 == 0:
				var m := _mark
				var c := Color(MARK, 0.95)
				for i in 4:
					_fx2.draw_rect(Rect2(m + Vector2(-9 + i, -8 + i), Vector2(1, 1)), c)
					_fx2.draw_rect(Rect2(m + Vector2(-9 + i, -1 - i), Vector2(1, 1)), c)
					_fx2.draw_rect(Rect2(m + Vector2(8 - i, -8 + i), Vector2(1, 1)), c)
					_fx2.draw_rect(Rect2(m + Vector2(8 - i, -1 - i), Vector2(1, 1)), c)
				_fx2.draw_rect(Rect2(m + Vector2(-12, -1), Vector2(24, 1)), Color(MARK, 0.6))
				# 落点上方一道竖的虚线：人会从这里冒出来
				for y in range(4, 46, 4):
					_fx2.draw_rect(Rect2(m + Vector2(0, -y), Vector2(1, 2)), Color(MARK, 0.4 + 0.4 * k))
		State.CHARGE:
			# 身后几道速度线
			for i in _trail.size():
				var p: Vector2 = _trail[i]
				var a := 0.12 + 0.08 * i
				for y in [-30.0, -20.0, -10.0]:
					_fx2.draw_rect(Rect2(p + Vector2(-_attack_dir * 14.0 - 6.0, y), Vector2(6, 1)), Color(FLASH, a))
		State.SNIP, State.CUT_SNIP:
			# 剪下去的一道白光
			if _state_t < 0.12:
				var r := SNIP_RECT if state == State.SNIP else CUT_RECT
				var x0 := o.x + (r.position.x if _attack_dir < 0 else -r.end.x)
				if state == State.SNIP:
					_fx2.draw_rect(Rect2(x0, o.y - 18.0, r.size.x, 1), Color(FLASH, 0.9))
				else:
					for i in 20:
						var t := float(i) / 19.0
						var px := o.x + _attack_dir * (6.0 + 34.0 * t)
						var py := o.y - 44.0 + 42.0 * t * t
						_fx2.draw_rect(Rect2(Vector2(px, py).round(), Vector2(2, 1)), Color(FLASH, 0.9))


func _on_respawn() -> void:
	_set_solid(true)
	_enter(State.CHASE)
