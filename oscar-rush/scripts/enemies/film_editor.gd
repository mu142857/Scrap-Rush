class_name FilmEditor
extends EliteBase
## 剪辑师（第二关精英怪，第一场换卷战，胶片天桥）：驼背高个子，褐色长大褂，帽兜上压着遮光帽檐，
## 肩上搭着两条胶片，手里一把和半个人一样长的大剪刀。在天桥上追着主角走，两招轮着放，都先冒红色"!"：
## - 剪刀冲：压低身子把剪刀张开举起来（0.7 秒，身子一闪一闪发红），然后张着剪刀贴地往前冲
##   （每秒 260，冲过主角 60 像素、撞到闸门或冲满 300 就停），停下"咔嚓"合一下。
##   冲的时候剪刀那一截（身前 44 像素、地面往上 8～26）伤 12，身子碰到伤 10。要跳起来飞过去，或者站到它背后。
## - 跳剪：像胶片被剪掉了一段——人一闪一闪（白色片框线），然后整个消失 0.35 秒，主角身后 46 像素的地上
##   出现红色的剪辑标记（像剪辑台上的"><"记号）闪 0.5 秒，它从标记那里冒出来，剪刀举过头顶往前剪下去：
##   身前 54 像素、地面往上 0～40 伤 14（站着不动一定挨；标记亮起后往前跑开十来格就躲过）。身后是墙（闸门）就落在主角前面。
## 消失的时候打不到。闪烁、标记、速度线、剪下去的白光都是代码画的（unshaded，暗处看得清）。
## 高机动的追击者：追人走得快（每秒 50），离主角远了（130 以外）会一个大跨步扑过去（每 2.2 秒最多一次，不伤人，
## 只是拉近）。
## 是活人，不是机器（作者 10-17："加一些不是机器的，是有生命的"）：长鼻子从帽檐下伸出来，
## 两只暖白的眼睛由代码画（会眨、会看人）；站着时慢慢呼吸；主角绕到身后先扭头再转身；
## 挨打往后一仰、踉跄一步（出招时只抖一下）；血打空先瘫倒、剪刀掉在地上，再散掉。
## 贴图 film_editor.png（草图/精英怪/l2_robed_elites.py 导出），6 帧：
## 0、1 走（也是呼吸的两帧）；2 冲刺预警（压低、剪刀张开举起来）；3 冲刺 / 大跨步（往前扑，剪刀张开朝前）；
## 4 剪（合上）；5 跳剪落下（举过头顶）；6 挨打后仰；7 倒下。

enum State { CHASE, CHARGE_WARN, CHARGE, SNIP, CUT_WARN, CUT_GONE, CUT_DROP, CUT_SNIP, RECOVER }

const WALK_SPEED := 50.0
## 大跨步：离主角这么远就扑过去拉近
const LEAP_DIST := 130.0
const LEAP_VEL := Vector2(170.0, -230.0)
const LEAP_COOLDOWN := 2.2
const FRAME_TIME := 0.22
const STOP := 40.0
## 10-18 作者："技能之间的停顿太长"：两招之间的停顿（RECOVER + IDLE）压到 1.0~1.4 秒，打死前每招至少 3 轮。预警没动
const IDLE_TIME := Vector2(0.7, 1.0)
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
const CUT_RECT := Rect2(-54, -40, 58, 40)
const CUT_DAMAGE := 14.0
const RECOVER_TIME := 0.35
const MARK := Color(1.0, 0.25, 0.2)
const FLASH := Color(1.0, 0.95, 0.85)
const EYE_COLOR := Color(1.0, 0.86, 0.62)
const BREATH_TIME := 0.7
const WALK_CYCLE: Array[int] = [8, 1, 9, 1]
const FLINCH_TIME := 0.28
const TURN_TIME := 0.18
const COLLAPSE_TIME := 0.9

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
var _flinch := 0.0
var _turn_t := 0.0
var _blink := 0.0
var _blink_cd := 2.0
var _look := Vector2.ZERO
var _dying := false
var _die_t := 0.0
var _leap_cd := 1.0
var _leaping := false


func _setup() -> void:
	elite_name = "FILM EDITOR"
	intro_title = "FINAL CUT"
	intro_frame = 2
	texture_path = "res://art/enemies/film_editor.png"
	hframes = 10
	frame_size = Vector2i(88, 48)
	body_rect = Rect2(-11, -42, 22, 42)
	# led_pixel 是前面那只眼睛（眼睛由 _draw_led 画成两只会眨的暖白眼睛，不是机器的红灯）
	led_pixel = Vector2i(39, 11)
	led_by_frame = {1: Vector2i(39, 10), 2: Vector2i(39, 15), 3: Vector2i(36, 17), 4: Vector2i(36, 17),
			6: Vector2i(41, 11), 7: Vector2i(39, 27), 8: Vector2i(38, 11), 9: Vector2i(38, 11)}
	# 10-18：三把武器原来 11~17 秒就打死（真实时间）；血加到 20~35 秒、每招 3 轮以上
	max_hp = 2300.0
	contact_damage = 10.0
	# 活人：倒下扬灰（不撒废铁），倒地的闷响，溅出来的是褐色大褂碎片和胶片和灰
	death_scrap = false
	death_sfx = "land"
	death_sfx_pitch = 0.55
	death_spark_colors = [Color8(96, 78, 62), Color8(150, 112, 72)]
	death_boom_sfx = "boom"
	death_boom_pitch = 0.45
	death_spark_colors_big = [Color8(150, 112, 72), Color8(96, 78, 62)]
	# 暗处亮层用 EliteBase 自带的（预警时还会一闪一闪发红）
	fill_alpha = 0.32


func _after_ready() -> void:
	_unstick()
	var glow := _led.get_child(0) as PointLight2D
	glow.color = EYE_COLOR
	glow.texture_scale = 0.35
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
	# 往下最多挪到原来脚底下那块地面（不能穿过地板，碰撞会话 10-18 报过整只掉出地图）
	var floor_d := 80.0
	var ray := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -1), global_position + Vector2(0, 82), 1)
	var hit := space.intersect_ray(ray)
	if not hit.is_empty():
		floor_d = (hit.position as Vector2).y - global_position.y
	# 先原地、往上一点（脚压进了地面、斜坡），再左右挪（身子侧面插进柱子、墙），最后往下（头顶卡进天花板）
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


func is_targetable() -> bool:
	return super.is_targetable() and state != State.CUT_GONE and not _dying


func hurt(damage: float, from_dir: Vector2, full: bool) -> void:
	# 跳剪消失的时候打不到
	if state == State.CUT_GONE:
		return
	super.hurt(damage, from_dir, full)


func _tick(delta: float) -> void:
	if _dying:
		_collapse(delta)
		return
	_state_t += delta
	_alive_tick(delta)
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
			# 碰撞关掉了，不清掉速度的话重力会让它从地板穿下去
			velocity = Vector2.ZERO
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
	if _flinch > 0.0 and state in [State.CHASE, State.RECOVER] and not _leaping:
		set_frame(6)
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
	# 大跨步在空中：保持往前，落地扬一点灰
	if _leaping:
		set_frame(3)
		if is_on_floor() and velocity.y >= 0.0:
			_leaping = false
			Game.dust(get_parent(), global_position, 4)
			Game.sfx("land", -10.0, 0.8, 0.1)
		return
	var p := nearest_player()
	var side := 0.0
	if p:
		var dx := p.global_position.x - global_position.x
		_face(p)
		if absf(dx) > STOP and signf(dx) == float(dir):
			side = dir
		# 离得远：一个大跨步扑过去（前面有地、没顶墙才扑）
		if absf(dx) > LEAP_DIST and _leap_cd <= 0.0 and is_on_floor() and _turn_t <= 0.0 \
				and _ground_at(dir) and not _wall_at(dir):
			_leap_cd = LEAP_COOLDOWN
			_leaping = true
			velocity = Vector2(dir * LEAP_VEL.x * speed_mult(), LEAP_VEL.y)
			Game.sfx("jump", -8.0, 0.7, 0.1)
			Game.dust(get_parent(), global_position, 3, -dir)
			return
	if side != 0.0 and (not _ground_at(side) or _wall_at(side)):
		side = 0.0
	if not is_knocked():
		velocity.x = move_toward(velocity.x, side * WALK_SPEED * speed_mult(), 400.0 * delta)
	# 站着的时候慢慢呼吸（0、1 两帧）；走的时候驼着背大步走：8、1、9、1（10-18 夜间打磨）
	if absf(velocity.x) > 2.0:
		set_frame(WALK_CYCLE[int(_time / FRAME_TIME) % 4])
	else:
		set_frame(int(_time / BREATH_TIME) % 2)


## 面朝主角。追的时候主角绕到身后，先扭头看一眼（TURN_TIME）再转身；出招时直接转
func _face(p: Node2D) -> void:
	if absf(p.global_position.x - global_position.x) <= 2.0:
		return
	var want := 1 if p.global_position.x > global_position.x else -1
	if want == dir:
		_turn_t = 0.0
	elif _turn_t <= 0.0:
		_turn_t = TURN_TIME


## 活物的小动作：眨眼、眼睛跟着主角、扭头、挨打后仰的计时
func _alive_tick(delta: float) -> void:
	_flinch = maxf(_flinch - delta, 0.0)
	_leap_cd -= delta
	_blink = maxf(_blink - delta, 0.0)
	_blink_cd -= delta
	if _blink_cd <= 0.0:
		_blink = 0.12
		_blink_cd = randf_range(2.0, 4.5)
	var p := nearest_player()
	_look = Vector2.ZERO
	if p and p.global_position.y < global_position.y - 40.0:
		_look.y = -1.0
	if _turn_t > 0.0:
		_turn_t -= delta
		_look.x = -dir
		if _turn_t <= 0.0:
			dir = -dir


## 倒下：先后仰，再瘫在地上（剪刀掉在身前），然后才走 EliteBase 的死亡
func _collapse(delta: float) -> void:
	_die_t += delta
	velocity.x = 0.0
	set_frame(6 if _die_t < 0.22 else 7)
	_blink = 1.0 if _die_t > 0.5 else 0.0
	if _die_t >= 0.22 and _die_t - delta < 0.22:
		Game.sfx("land", -6.0, 0.6)
		Game.sfx("clang", -10.0, 1.4)
		Game.dust(get_parent(), global_position, 8)
		Game.add_shake(2.0)
	move_and_slide()
	if _die_t >= COLLAPSE_TIME:
		super._die()


func _die() -> void:
	if _dying:
		return
	_dying = true
	_die_t = 0.0
	_leaping = false
	_set_solid(true)
	_trail.clear()
	state = State.RECOVER
	_contact.set_deferred("monitoring", false)
	Game.sfx("hurt", -6.0, 0.6)


func _on_hurt(_damage: float, full: bool) -> void:
	if _dying:
		return
	if full or _flinch <= 0.0:
		_flinch = FLINCH_TIME
		if state in [State.CHASE, State.RECOVER] and not _leaping and not is_knocked():
			velocity.x = -dir * (60.0 if full else 30.0)
			_knock = 0.12


## 两只暖白的眼睛（代替机器的红灯）：会眨眼，会往主角那边、往身后看。_led 在前面那只眼睛的位置
func _draw_led() -> void:
	if _blink > 0.0 or not _led.visible:
		return
	var c := EYE_COLOR.lerp(Color.WHITE, _flash)
	var lk := _look.round()
	_led.draw_rect(Rect2(lk, Vector2.ONE), c)
	_led.draw_rect(Rect2(lk + Vector2(-2 * dir, 0), Vector2.ONE), Color(c, 0.75))


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
	if _flinch > FLINCH_TIME - 0.1 and not _dying and state != State.CHARGE_WARN:
		_sprite.position.x += 1.0 if int(_time * 30.0) % 2 == 0 else -1.0


func _draw_fx2() -> void:
	if dead or in_intro() or _dying:
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
						var px := o.x + _attack_dir * (6.0 + 48.0 * t)
						var py := o.y - 44.0 + 42.0 * t * t
						_fx2.draw_rect(Rect2(Vector2(px, py).round(), Vector2(2, 1)), Color(FLASH, 0.9))


func _on_respawn() -> void:
	_set_solid(true)
	_enter(State.CHASE)
