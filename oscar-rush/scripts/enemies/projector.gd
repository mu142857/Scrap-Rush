class_name CinemaProjector
extends EliteBase
## 放映机（第二关精英怪，放在胶片天桥的两场换卷战里）：老式 35mm 电影放映机，上下两个片盘一直在转，
## 左边伸出镜头筒，红灯在镜头上方，铸铁底座下面长了腿。慢慢走，和主角保持一段距离。
## 两招轮着放，都先冒红色"!"：
## - 光柱扫射：镜头往地上打一道暖白光柱，光斑贴着地面从近往远扫过去。光斑那一块烫（地面往上 14 格），
##   碰到伤 10；光柱半空那一段只是光，不伤人。跳过去或者飞过去就躲开了。
## - 放映：镜头往前方投出一个光框（像银幕上的画面），1 秒后从光框里"走出"两只小怪（胶片盘，没有就用爬虫）。
##   小怪算进所在遭遇战的这一波里，要打完才清场。身边已经有 3 只它放出来的小怪时，改放光柱。
## 光柱、光框、镜头的光晕都用代码画（unshaded 半透明多边形），在黑暗里很显眼。
## 贴图 projector.png（草图/精英怪/l2_projector.py 导出），帧号 = 姿势 × 4 + 片盘相位：
## 姿势 0 站着、1 和 2 走、3 预警（镜头缩回、腿撑开）、4 放光（镜头伸出、镜片亮、灯箱缝发红）。

enum State { IDLE, WALK, BEAM_WARN, BEAM, SCREEN_WARN, SCREEN, RECOVER }

## 招与招之间歇多久。精英怪的出招间隔不乘 interval_mult()（照钢琴：情绪高时间隔太短，招看不清）
const IDLE_TIME := Vector2(2.2, 2.8)
const WALK_SPEED := 16.0
const WALK_FRAME_TIME := 0.25
## 离主角远于这个就往前走，近于 NEAR 就往后退（脸一直朝着主角）
const FAR := 170.0
const NEAR := 70.0
## 片盘转一格（30°）的时间；放光时转得快一倍
const REEL_FRAME_TIME := 0.12
## 光柱扫射
const BEAM_WARN := 0.8
const BEAM_START := 24.0
const BEAM_SPEED := 150.0
const BEAM_MAX := 300.0
const BEAM_FADE := 0.25
## 光斑烫人的那一块：光斑中心左右各 HOT_HALF，地面往上 HOT_H
const HOT_HALF := 9.0
const HOT_H := 14.0
const BEAM_DAMAGE := 10.0
## 放映
const SCREEN_WARN := 0.7
const SCREEN_DIST := 84.0
const SCREEN_SIZE := Vector2(26, 30)
const SCREEN_TIME := 1.0
const SCREEN_FADE := 0.4
const SCREEN_MINIONS := 2
const MAX_MINIONS := 3
const RECOVER_TIME := 0.9
## 镜头在原图（朝左）里相对脚底中点的位置：镜片中心
const LENS := Vector2(-21.0, -31.5)
const BEAM_COLOR := Color(1.0, 0.93, 0.78)

var state := State.IDLE
var _state_t := 0.0
var _idle_time := 1.2
## 下一招：0 光柱，1 放映
var _next_attack := 0
var _attack_dir := -1
## 光斑现在的 x、扫到哪为止
var _spot_x := 0.0
var _spot_end := 0.0
var _floor := 0.0
## 银幕光框的中心 x（脚底那一行）
var _screen_x := 0.0
var _spawned := false
var _minions: Array[Node] = []
var _smoke_t := 0.0
## 刚放完光柱（RECOVER 时把光柱淡出去）
var _fade_beam := false

var _beam: Node2D
var _spot_light: PointLight2D


func _setup() -> void:
	elite_name = "CINEMA PROJECTOR"
	intro_title = "NOW SHOWING"
	intro_frame = 16
	texture_path = "res://art/enemies/projector.png"
	hframes = 20
	frame_size = Vector2i(44, 55)
	body_rect = Rect2(-15, -52, 30, 52)
	led_pixel = Vector2i(9, 19)
	max_hp = 1200.0
	contact_damage = 10.0


func _after_ready() -> void:
	_unstick()
	# 光柱、光框、镜头光晕：世界坐标上画，不吃场景压暗
	_beam = Node2D.new()
	_beam.top_level = true
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_beam.material = unshaded
	_beam.z_index = 4
	_beam.draw.connect(_draw_beam)
	add_child(_beam)
	# 光斑 / 银幕把周围照亮一点
	_spot_light = PointLight2D.new()
	_spot_light.texture = Game.light_texture()
	_spot_light.color = BEAM_COLOR
	_spot_light.energy = 0.0
	_spot_light.texture_scale = 0.8
	_spot_light.top_level = true
	add_child(_spot_light)


## 遭遇战把精英怪放在天花板下面 14 格，放映机有 52 格高，场子矮的话身子会插进天花板，
## 物理会把它推到天花板上面去。出生时卡在墙里就往下挪，挪到不卡为止（最多 80 格）
func _unstick() -> void:
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = _shape.shape
	q.collision_mask = 1
	q.exclude = [get_rid()]
	var space := get_world_2d().direct_space_state
	for i in 41:
		q.transform = Transform2D(0.0, global_position + _shape.position)
		if space.intersect_shape(q, 1).is_empty():
			return
		global_position.y += 2.0


func _tick(delta: float) -> void:
	_state_t += delta
	if not is_knocked():
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	match state:
		State.IDLE, State.WALK:
			_face_player()
			_walk(delta)
			if _state_t >= _idle_time and is_on_floor():
				_start_attack()
		State.BEAM_WARN:
			_pose(3)
			if _state_t >= BEAM_WARN:
				_enter(State.BEAM)
				Game.sfx("tvon", -4.0, 0.7)
				Game.sfx("jet", -10.0, 1.4)
		State.BEAM:
			_pose(4)
			_spot_x = move_toward(_spot_x, _spot_end, BEAM_SPEED * delta)
			_burn_spot(delta)
			_beam_hit()
			if _spot_x == _spot_end:
				_enter(State.RECOVER)
		State.SCREEN_WARN:
			_pose(3)
			if _state_t >= SCREEN_WARN:
				_enter(State.SCREEN)
				Game.sfx("tvon", -4.0, 0.9)
				Game.sfx("static", -12.0, 1.0)
		State.SCREEN:
			_pose(4)
			if not _spawned and _state_t >= SCREEN_TIME:
				_spawned = true
				_spawn_minions()
			if _state_t >= SCREEN_TIME + SCREEN_FADE:
				_enter(State.RECOVER)
		State.RECOVER:
			_pose(0)
			if _state_t >= RECOVER_TIME:
				_enter(State.IDLE)
	move_and_slide()
	_update_light()
	_beam.queue_redraw()


func _enter(s: State) -> void:
	var was := state
	state = s
	_state_t = 0.0
	_fade_beam = s == State.RECOVER and was == State.BEAM
	if s == State.IDLE:
		_idle_time = randf_range(IDLE_TIME.x, IDLE_TIME.y)
	elif _fade_beam:
		Game.sfx("tvoff", -6.0, 0.8)


func _start_attack() -> void:
	velocity.x = 0.0
	_face_player()
	_attack_dir = dir
	_floor = global_position.y
	for m in _minions.duplicate():
		if not is_instance_valid(m) or m.get("dead"):
			_minions.erase(m)
	var attack := _next_attack
	if attack == 1 and _minions.size() >= MAX_MINIONS:
		attack = 0
	if attack == 1:
		_screen_x = _lens().x + _attack_dir * SCREEN_DIST
		# 前面有墙（闸门）就把光框收回到墙前
		var wall := _wall_dist(SCREEN_DIST + SCREEN_SIZE.x / 2.0 + 4.0)
		if wall < INF:
			_screen_x = _lens().x + _attack_dir * maxf(wall - SCREEN_SIZE.x / 2.0 - 4.0, 30.0)
		_spawned = false
		warn(SCREEN_WARN)
		_enter(State.SCREEN_WARN)
	else:
		_spot_x = _lens().x + _attack_dir * BEAM_START
		_spot_end = _lens().x + _attack_dir * minf(BEAM_MAX, _wall_dist(BEAM_MAX) - HOT_HALF)
		warn(BEAM_WARN)
		_enter(State.BEAM_WARN)
	Game.sfx("ready", -12.0, 0.6)
	_next_attack = (attack + 1) % 2


## 慢慢走：离主角远就靠过去，太近就往后退，中间站着。前面没地或者顶墙就不走
func _walk(_delta: float) -> void:
	var p := nearest_player()
	var side := 0.0
	if p:
		var dx := p.global_position.x - global_position.x
		if absf(dx) > FAR:
			side = signf(dx)
		elif absf(dx) < NEAR:
			side = -signf(dx)
	if side != 0.0 and (not _ground_at(side, 18.0) or _wall_ahead(side)):
		side = 0.0
	if not is_knocked():
		velocity.x = side * WALK_SPEED * speed_mult()
	state = State.WALK if side != 0.0 else State.IDLE
	if state == State.WALK:
		_pose(1 + int(_time / WALK_FRAME_TIME) % 2)
		if int(_time / (WALK_FRAME_TIME * 2.0)) != int((_time - get_physics_process_delta_time()) / (WALK_FRAME_TIME * 2.0)):
			Game.sfx("land", -18.0, 1.6, 0.1)
	else:
		_pose(0)


## 姿势 + 片盘相位（片盘一直在转，放光时转得快）
func _pose(p: int) -> void:
	var t := REEL_FRAME_TIME * (0.5 if p == 4 else 1.0)
	set_frame(p * 4 + int(_time / t) % 4)


## 镜片的世界坐标
func _lens() -> Vector2:
	return global_position.round() + Vector2(LENS.x * _attack_dir if state != State.IDLE and state != State.WALK
			else LENS.x * dir, LENS.y)


## 光斑那一块烫：主角、放在地上的马灯碰到就伤
func _beam_hit() -> void:
	var r := Rect2(_spot_x - HOT_HALF, _floor - HOT_H, HOT_HALF * 2.0, HOT_H)
	var dmg := BEAM_DAMAGE * damage_mult()
	for n in get_tree().get_nodes_in_group("player"):
		var p := n as Player
		# 主角的身子：6×16，原点在脚底中间
		if p and r.intersects(Rect2(p.global_position + Vector2(-3, -16), Vector2(6, 16))):
			p.hurt(Vector2(_spot_x - _attack_dir * 8.0, _floor), dmg)
	for n in get_tree().get_nodes_in_group("crystal"):
		var c := n as Crystal
		if c and c.carrier == null and r.intersects(Rect2(c.global_position + Vector2(-2.5, -8), Vector2(5, 8))):
			c.take_hit(Vector2(_spot_x - _attack_dir * 8.0, _floor), dmg)


## 光斑扫过的胶片冒烟、冒火星
func _burn_spot(delta: float) -> void:
	_smoke_t -= delta
	if _smoke_t > 0.0:
		return
	_smoke_t = 0.07
	Game.sparks(get_parent(), Vector2(_spot_x, _floor - 1.0), Color8(255, 200, 120), 2, 40.0, Vector2.UP)
	if randf() < 0.4:
		Game.sfx("embers", -20.0, 1.3, 0.2)


## 从银幕光框里走出小怪：胶片盘（没有就用爬虫），算进它所在遭遇战的这一波
func _spawn_minions() -> void:
	var path := "res://scripts/enemies/film_reel.gd"
	if not ResourceLoader.exists(path):
		path = "res://scripts/enemies/crawler.gd"
	var enc := _encounter()
	for i in SCREEN_MINIONS:
		var e: Node2D = (load(path) as GDScript).new()
		e.set("respawn_time", 0.0)
		e.set("dir", _attack_dir)
		e.position = Vector2(roundf(_screen_x + (i * 2 - 1) * 6.0), _floor - 2.0)
		get_parent().add_child(e)
		_minions.append(e)
		if enc:
			var alive = enc.get("_alive")
			if alive is Array:
				alive.append(e)
	Game.sparks(get_parent(), Vector2(_screen_x, _floor - SCREEN_SIZE.y / 2.0), BEAM_COLOR, 14, 70.0)
	Game.sfx("tvclick", -4.0, 0.8)
	Game.sfx("scrap", -10.0, 1.3)
	Game.add_shake(2.0)


## 父节点里正在打的那场遭遇战（自己站在它的场子里）
func _encounter() -> Node:
	var parent := get_parent()
	if parent == null:
		return null
	var best: Node = null
	for c in parent.get_children():
		if c is Encounter:
			var e := c as Encounter
			if e.cleared:
				continue
			if global_position.x >= e.left - 8.0 and global_position.x <= e.right + 8.0:
				return e
			if best == null:
				best = e
	return best


## 面朝 _attack_dir 往前 max_dist 以内有没有墙（闸门、墙），返回距离（从镜头算），没有就 INF
func _wall_dist(max_dist: float) -> float:
	var from := Vector2(_lens().x, _floor - 6.0)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(_attack_dir * max_dist, 0), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return INF
	return absf((hit.position as Vector2).x - from.x)


func _wall_ahead(side: float) -> bool:
	var from := global_position + Vector2(0, -8)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(side * 22.0, 0), 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _ground_at(side: float, dist: float) -> bool:
	var from := global_position + Vector2(side * dist, -2)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 8), 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _face_player() -> void:
	var p := nearest_player()
	if p and absf(p.global_position.x - global_position.x) > 2.0:
		dir = 1 if p.global_position.x > global_position.x else -1


## 光斑 / 银幕处的点光源：照亮周围的胶片和怪
func _update_light() -> void:
	var e := 0.0
	match state:
		State.BEAM:
			e = 1.1
			_spot_light.global_position = Vector2(_spot_x, _floor - 6.0)
		State.SCREEN:
			e = 0.9 * (1.0 - clampf((_state_t - SCREEN_TIME) / SCREEN_FADE, 0.0, 1.0))
			_spot_light.global_position = Vector2(_screen_x, _floor - SCREEN_SIZE.y / 2.0)
	_spot_light.energy = e


## 预警时机身抖一抖；镜头那里的光晕在 _draw_beam 里画
func _update_visual() -> void:
	super._update_visual()
	if state == State.BEAM_WARN or state == State.SCREEN_WARN:
		var k := _state_t / (BEAM_WARN if state == State.BEAM_WARN else SCREEN_WARN)
		var amp := 1.0 if k > 0.5 else 0.0
		_sprite.position.x += amp if int(_state_t * 30.0) % 2 == 0 else -amp


func _draw_beam() -> void:
	if dead or in_intro():
		return
	var lens := _lens()
	match state:
		State.BEAM_WARN:
			_draw_lens_glow(lens, _state_t / BEAM_WARN)
			# 起点的地面一闪一闪：光斑从这里开始扫
			if int(_state_t / 0.1) % 2 == 0:
				_beam.draw_rect(Rect2(roundf(_spot_x - HOT_HALF), _floor - 1.0, HOT_HALF * 2.0, 1), Color(BEAM_COLOR, 0.5))
		State.BEAM:
			_draw_cone(lens, _spot_x, 1.0)
		State.RECOVER:
			# 光柱收掉：越来越淡
			if _fade_beam and _state_t < BEAM_FADE:
				_draw_cone(lens, _spot_x, 1.0 - _state_t / BEAM_FADE)
		State.SCREEN_WARN:
			_draw_lens_glow(lens, _state_t / SCREEN_WARN)
		State.SCREEN:
			var a := 1.0 - clampf((_state_t - SCREEN_TIME) / SCREEN_FADE, 0.0, 1.0)
			_draw_screen(lens, a)


## 镜头处的光晕：预警时越来越亮，最后一下最亮
func _draw_lens_glow(lens: Vector2, k: float) -> void:
	var a := clampf(k, 0.0, 1.0)
	var r := roundf(1.0 + 3.0 * a)
	var x := lens.x
	_beam.draw_rect(Rect2(x - r, lens.y - r, r * 2.0 + 1.0, r * 2.0 + 1.0), Color(BEAM_COLOR, 0.12 + 0.18 * a))
	_beam.draw_rect(Rect2(x - 1.0, lens.y - 2.0, 3, 5), Color(BEAM_COLOR, 0.4 + 0.5 * a))


## 光柱：镜头到地面光斑的一个梯形，外层淡、内层亮；光斑那一块（烫人的范围）更亮，地上一条亮线
func _draw_cone(lens: Vector2, spot: float, a: float) -> void:
	var s := float(_attack_dir)
	var x0 := lens.x
	var flick := 0.9 + 0.1 * sin(_time * 40.0)
	a *= flick
	# 外层淡、内层亮：镜头口 5 格高，落到地上 22 格宽（内层 12 格）
	_cone(Vector2(x0, lens.y - 2.0), Vector2(x0, lens.y + 3.0),
			Vector2(spot + s * (HOT_HALF + 2.0), _floor), Vector2(spot - s * (HOT_HALF + 2.0), _floor), Color(BEAM_COLOR, 0.16 * a))
	_cone(Vector2(x0, lens.y - 1.0), Vector2(x0, lens.y + 2.0),
			Vector2(spot + s * (HOT_HALF - 3.0), _floor), Vector2(spot - s * (HOT_HALF - 3.0), _floor), Color(BEAM_COLOR, 0.2 * a))
	# 烫人的那一块：光柱贴地的最后一段亮一档
	var hot := Rect2(roundf(spot - HOT_HALF), _floor - HOT_H, HOT_HALF * 2.0, HOT_H)
	_beam.draw_rect(hot, Color(1.0, 0.85, 0.6, 0.16 * a))
	_beam.draw_rect(Rect2(hot.position.x - 2.0, _floor - 1.0, hot.size.x + 4.0, 1), Color(1.0, 0.97, 0.9, 0.9 * a))
	_beam.draw_rect(Rect2(hot.position.x, _floor - 2.0, hot.size.x, 1), Color(1.0, 0.85, 0.6, 0.5 * a))
	# 镜片本身最亮
	_beam.draw_rect(Rect2(x0 - (1.0 if s > 0 else 0.0), lens.y - 2.0, 1, 5), Color(1, 1, 1, 0.9 * a))


## 一束光：从镜头口（a 上沿、b 下沿）到远处的两个点（c 上沿那头、d 下沿那头）。
## 一列一列画 1 格宽的竖条，边是像素台阶，不会被 canvas_items 缩放画成平滑斜线。
## c、d 的 x 可以不一样（落到地上的光斑）：每一列的上沿沿 a→c、下沿沿 b→d 走；c 要是远的那头，超出 d 的列下沿就停在 d 的高度（地面）。
func _cone(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	var s := signf(c.x - a.x)
	var far := maxf(c.x, d.x) if s > 0.0 else minf(c.x, d.x)
	var n := int(absf(far - a.x))
	for i in n:
		var x := a.x + s * (float(i) + 0.5)
		var top := _edge_y(a, c, x, s)
		var bot := _edge_y(b, d, x, s)
		if is_nan(top):
			continue
		if is_nan(bot):
			bot = d.y
		var y0 := roundf(minf(top, bot))
		var y1 := roundf(maxf(top, bot))
		if y1 > y0:
			_beam.draw_rect(Rect2(floorf(x), y0, 1, y1 - y0), col)


## 从 p 到 q 这条边在 x 处的 y；x 超过了 q 那一头就是 NAN（那一列这条边不存在）
func _edge_y(p: Vector2, q: Vector2, x: float, s: float) -> float:
	if (x - q.x) * s > 0.0:
		return NAN
	if absf(q.x - p.x) < 0.5:
		return q.y
	return lerpf(p.y, q.y, (x - p.x) / (q.x - p.x))


## 银幕光框：镜头投到前方一个立在地上的亮框，画面一闪一闪，一条扫描线往下走；最后小怪从里面走出来
func _draw_screen(lens: Vector2, a: float) -> void:
	var s := float(_attack_dir)
	var x0 := lens.x
	var r := Rect2(roundf(_screen_x - SCREEN_SIZE.x / 2.0), _floor - SCREEN_SIZE.y, SCREEN_SIZE.x, SCREEN_SIZE.y)
	# 刚开始光框从一条线展开
	var open := clampf(_state_t / 0.15, 0.0, 1.0)
	var h := roundf(SCREEN_SIZE.y * open)
	r = Rect2(r.position.x, _floor - SCREEN_SIZE.y / 2.0 - h / 2.0, r.size.x, maxf(h, 1.0))
	var near_x := r.position.x if s > 0 else r.end.x
	_cone(Vector2(x0, lens.y - 2.0), Vector2(x0, lens.y + 3.0),
			Vector2(near_x, r.position.y), Vector2(near_x, r.end.y), Color(BEAM_COLOR, 0.14 * a))
	var flick := 0.8 + 0.2 * float(int(_time * 24.0) % 3 != 0)
	_beam.draw_rect(r, Color(BEAM_COLOR, 0.22 * a * flick))
	# 亮边框
	_beam.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(BEAM_COLOR, 0.85 * a))
	_beam.draw_rect(Rect2(r.position.x, r.end.y - 1.0, r.size.x, 1), Color(BEAM_COLOR, 0.85 * a))
	_beam.draw_rect(Rect2(r.position.x, r.position.y, 1, r.size.y), Color(BEAM_COLOR, 0.85 * a))
	_beam.draw_rect(Rect2(r.end.x - 1.0, r.position.y, 1, r.size.y), Color(BEAM_COLOR, 0.85 * a))
	if open < 1.0:
		return
	# 片头倒数那种圆圈加十字，快出怪时变成一团亮
	var c := r.get_center().round()
	var k := clampf(_state_t / SCREEN_TIME, 0.0, 1.0)
	if k < 1.0:
		var col := Color(BEAM_COLOR, 0.6 * a)
		_beam.draw_rect(Rect2(c.x - 6.0, c.y, 13, 1), col)
		_beam.draw_rect(Rect2(c.x, c.y - 6.0, 1, 13), col)
		for p in [Vector2(-4, -3), Vector2(-3, -4), Vector2(3, -4), Vector2(4, -3), Vector2(4, 3), Vector2(3, 4),
				Vector2(-3, 4), Vector2(-4, 3), Vector2(-5, -1), Vector2(-5, 1), Vector2(5, -1), Vector2(5, 1),
				Vector2(-1, -5), Vector2(1, -5), Vector2(-1, 5), Vector2(1, 5)]:
			_beam.draw_rect(Rect2(c + p, Vector2.ONE), col)
		# 扫描线一圈圈往下走
		var sy := r.position.y + 1.0 + float(int(_state_t * 60.0) % int(r.size.y - 2.0))
		_beam.draw_rect(Rect2(r.position.x + 1.0, sy, r.size.x - 2.0, 1), Color(1, 1, 1, 0.3 * a))
		# 最后 0.25 秒整个框越来越亮
		if k > 0.75:
			_beam.draw_rect(r.grow(-1.0), Color(1, 0.97, 0.9, 0.5 * (k - 0.75) / 0.25 * a))


func _on_die() -> void:
	_spot_light.energy = 0.0


func _on_respawn() -> void:
	_enter(State.IDLE)
