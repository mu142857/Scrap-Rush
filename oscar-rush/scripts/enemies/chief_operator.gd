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
## 是活人，不是机器（作者 10-17："加一些不是机器的，是有生命的"）：帽兜里一张老人的脸、一把白胡子，
## 两只暖白的眼睛由代码画（会眨、会往主角那边看）；站着时慢慢呼吸；主角绕到身后，先扭头看一眼再转身；
## 挨打往后一仰、踉跄一步（出招时只抖一下，不打断招式）；血打空先瘫倒在地，再散掉。
## 贴图 chief_operator.png（草图/精英怪/l2_robed_elites.py 导出），6 帧：
## 0、1 飘（也是呼吸的两帧）；2 拽线预警（手举过头）；3 拽线（手往前伸直）；4 转线（两手张开，背后的线炸开）；
## 5 叫班（两手举起来）；6 挨打后仰；7 倒下。

enum State { MOVE, HOOK_AIM, HOOK_LOCK, HOOK_FLY, HOOK_PULL, HOOK_SLAM, HOOK_BACK, SPIN_WARN, SPIN, CALL, RECOVER }

const MOVE_SPEED := 18.0
const FRAME_TIME := 0.3
const NEAR := 70.0
const FAR := 150.0
## 招与招之间歇多久（精英怪不乘 interval_mult，照钢琴：情绪高时招看不清）。
## 10-18 作者："技能之间的停顿太长，一辈子只能放出几次"：两招之间的停顿（RECOVER + IDLE）压到 1.0~1.3 秒，
## 打死之前每招至少完整放 3 轮。预警时长没动
const IDLE_TIME := Vector2(0.65, 0.95)
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
const RECOVER_TIME := 0.35
const CORD := Color(0.8, 0.74, 0.86)
const BRASS := Color(1.0, 0.8, 0.45)
const AIM := Color(1.0, 0.25, 0.2)
## 活物的部分：眼睛颜色、呼吸、挨打后仰、转身前扭头、倒下
const EYE_COLOR := Color(1.0, 0.86, 0.62)
const BREATH_TIME := 0.75
const WALK_CYCLE: Array[int] = [8, 1, 9, 1]
const FLINCH_TIME := 0.28
const TURN_TIME := 0.22
const COLLAPSE_TIME := 0.9

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
var _flinch := 0.0
var _turn_t := 0.0
var _blink := 0.0
var _blink_cd := 2.5
var _look := Vector2.ZERO
var _dying := false
var _die_t := 0.0


func _setup() -> void:
	elite_name = "CHIEF OPERATOR"
	intro_title = "HOLD THE LINE"
	intro_frame = 4
	texture_path = "res://art/enemies/chief_operator.png"
	hframes = 10
	frame_size = Vector2i(50, 53)
	body_rect = Rect2(-12, -48, 24, 48)
	# led_pixel 是前面那只眼睛（眼睛由 _draw_led 画成两只会眨的暖白眼睛，不是机器的红灯）
	led_pixel = Vector2i(19, 12)
	led_by_frame = {1: Vector2i(19, 11), 3: Vector2i(18, 12), 5: Vector2i(19, 11), 6: Vector2i(21, 12),
			7: Vector2i(19, 28), 8: Vector2i(18, 12), 9: Vector2i(18, 12)}
	# 10-18：停顿压短以后三把武器 13~17 秒就打死（真实时间），每招只放得出 2 轮；血加到 20~35 秒、每招 3 轮以上
	max_hp = 2400.0
	contact_damage = 10.0
	# 活人：倒下扬灰（不撒废铁），倒地的闷响，溅出来的是深紫的袍子碎片、黄铜插头、白胡子和灰
	death_scrap = false
	death_sfx = "land"
	death_sfx_pitch = 0.55
	death_spark_colors = [Color8(90, 76, 100), Color8(164, 128, 70)]
	death_boom_sfx = "boom"
	death_boom_pitch = 0.45
	death_spark_colors_big = [Color8(206, 204, 198), Color8(90, 76, 100)]
	# 暗处亮层用 EliteBase 自带的（预警时还会一闪一闪发红）
	fill_alpha = 0.32


func _after_ready() -> void:
	_unstick()
	# 眼睛的光：暖白、很弱，只是让暗处看得出眼神
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


func _tick(delta: float) -> void:
	if _dying:
		_collapse(delta)
		return
	_state_t += delta
	_alive_tick(delta)
	# 不走路的时候刹住（走路时 _move 自己管速度，这里再刹就把走路的加速抵掉了）
	if not is_knocked() and state != State.MOVE:
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
				_face(p, true)
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
	# 挨打后仰：不在出招的时候才换成后仰那一帧
	if _flinch > 0.0 and state in [State.MOVE, State.RECOVER]:
		set_frame(6)
	move_and_slide()
	_fx2.queue_redraw()


## 活物的小动作：眨眼、眼睛跟着主角、扭头、挨打后仰的计时
func _alive_tick(delta: float) -> void:
	_flinch = maxf(_flinch - delta, 0.0)
	_blink = maxf(_blink - delta, 0.0)
	_blink_cd -= delta
	if _blink_cd <= 0.0:
		_blink = 0.12
		_blink_cd = randf_range(2.0, 4.5)
	var p := nearest_player()
	_look = Vector2.ZERO
	if p:
		# 主角比头高很多就往上看一格
		if p.global_position.y < global_position.y - 44.0:
			_look.y = -1.0
	if _turn_t > 0.0:
		_turn_t -= delta
		_look.x = -dir                     # 眼睛先往身后看
		if _turn_t <= 0.0:
			dir = -dir


## 倒下：先后仰，再瘫在地上，然后才走 EliteBase 的死亡（爆开、降情绪）
func _collapse(delta: float) -> void:
	_die_t += delta
	velocity.x = 0.0
	set_frame(6 if _die_t < 0.22 else 7)
	_blink = 1.0 if _die_t > 0.5 else 0.0
	if _die_t >= 0.22 and _die_t - delta < 0.22:
		Game.sfx("land", -6.0, 0.6)
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
	state = State.RECOVER
	_hooked = null
	_contact.set_deferred("monitoring", false)
	Game.sfx("hurt", -6.0, 0.6)


func is_targetable() -> bool:
	return super.is_targetable() and not _dying


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
		_face(p, true)
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
	var standing := true
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
	if side != 0.0:
		standing = false
	if not is_knocked():
		velocity.x = move_toward(velocity.x, side * MOVE_SPEED * speed_mult(), 300.0 * delta)
	# 站着的时候慢慢呼吸（0、1 两帧）；走的时候迈步：左脚踩 8、抬起 1、右脚踩 9、抬起 1（10-18 夜间打磨）
	if standing:
		set_frame(int(_time / BREATH_TIME) % 2)
	else:
		set_frame(WALK_CYCLE[int(_time / FRAME_TIME) % 4])


## 面朝主角。走动时主角绕到身后，先扭头看一眼（TURN_TIME）再转身；出招时直接转
func _face(p: Node2D, instant := false) -> void:
	if absf(p.global_position.x - global_position.x) <= 2.0:
		return
	var want := 1 if p.global_position.x > global_position.x else -1
	if want == dir:
		_turn_t = 0.0
	elif instant:
		dir = want
		_turn_t = 0.0
	elif _turn_t <= 0.0:
		_turn_t = TURN_TIME


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
func _on_hurt(_damage: float, full: bool) -> void:
	if _dying:
		return
	# 挨打后仰：走动、歇着的时候换成后仰那一帧，往后踉跄一步；出招时只抖一下
	if full or _flinch <= 0.0:
		_flinch = FLINCH_TIME
		if state in [State.MOVE, State.RECOVER] and not is_knocked():
			velocity.x = -dir * (60.0 if full else 30.0)
			_knock = 0.12
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
		# 夹在场子里面，留出半个身宽：闸门只有 8 像素宽，站在门边叫班时门外那一点不在墙里，
		# 接线员会生在闸门外面打不到、场子清不了（10-18 作者试玩 E3 卡关，碰撞会话报的）
		if enc:
			x = clampf(x, enc.left + 16.0, enc.right - 16.0)
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
	# 先找 _alive 里有自己的那一场；找不到再按 x、y 范围找开打了没打完的（第二关 E1 和 E3 上下叠着，
	# x 范围重合，只按 x 会找到楼下那一场，碰撞会话 10-18 报的）
	var parent := get_parent()
	if parent == null:
		return null
	var fallback: Encounter = null
	for c in parent.get_children():
		var e := c as Encounter
		if e == null or e.cleared:
			continue
		if e._alive.has(self):
			return e
		var floor_y := maxf(e.floor_left, e.floor_right)
		if e.started and global_position.x >= e.left - 8.0 and global_position.x <= e.right + 8.0 \
				and global_position.y >= e.ceil_y - 8.0 and global_position.y <= floor_y + 8.0:
			fallback = e
	return fallback


## 两只暖白的眼睛（代替机器的红灯）：会眨眼，会往主角那边、往身后看。_led 在前面那只眼睛的位置
func _draw_led() -> void:
	if _blink > 0.0 or not _led.visible:
		return
	var c := EYE_COLOR.lerp(Color.WHITE, _flash)
	var lk := _look.round()
	_led.draw_rect(Rect2(lk, Vector2.ONE), c)
	_led.draw_rect(Rect2(lk + Vector2(-2 * dir, 0), Vector2.ONE), Color(c, 0.75))


## 预警时身子抖一抖；挨打（出招中）也抖一下
func _update_visual() -> void:
	super._update_visual()
	if state in [State.HOOK_LOCK, State.SPIN_WARN] or (_flinch > FLINCH_TIME - 0.1 and not _dying):
		_sprite.position.x += 1.0 if int(_time * 30.0) % 2 == 0 else -1.0


func _draw_fx2() -> void:
	if dead or in_intro() or _dying:
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
