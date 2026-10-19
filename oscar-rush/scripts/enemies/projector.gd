class_name CinemaProjector
extends EliteBase
## 放映机（第二关精英怪，放在胶片天桥的两场换卷战里）：老式 35mm 电影放映机，上下两个片盘一直在转，
## 左边伸出镜头筒，红灯在镜头上方，铸铁底座下面长了腿。慢慢走，和主角保持一段距离。
## 两招轮着放，都先冒红色"!"：
## - 光柱扫射：预警时光斑要扫的整条路在地上点成虚线；然后镜头往地上打一道暖白光柱，光斑贴着地面从近往远扫过去。光斑那一块烫（地面往上 14 格），
##   碰到伤 10；光柱半空那一段只是光，不伤人。跳过去或者飞过去就躲开了。
## - 放映：镜头往前方投出一个光框（像银幕上的画面），1 秒后从光框里"走出"两只小怪（胶片盘，没有就用爬虫）。
##   小怪算进所在遭遇战的这一波里，要打完才清场。身边已经有 3 只它放出来的小怪时，改放光柱。
## 光柱、光框、镜头的光晕都用代码画（unshaded 半透明多边形），在黑暗里很显眼。
## 贴图 projector.png（草图/精英怪/l2_projector.py 导出），帧号 = 姿势 × 4 + 片盘相位：
## 姿势 0 站着、1 和 2 走、3 预警（镜头缩回、腿撑开）、4 放光（镜头伸出、镜片亮、灯箱缝发红）。

enum State { IDLE, WALK, BEAM_WARN, BEAM, SCREEN_WARN, SCREEN, RECOVER }

## 招与招之间歇多久。精英怪的出招间隔不乘 interval_mult()（照钢琴：情绪高时间隔太短，招看不清）
const IDLE_TIME := Vector2(0.6, 1.0)   # 10-18 作者嫌停顿太长：2.2~2.8 → 0.6~1.0，连收招一共空 1.1~1.5 秒
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
## 回扫那种扫到头停多久再扫回来
const BEAM_TURN := 0.35
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
const RECOVER_TIME := 0.5
## 镜头在原图（朝左）里相对脚底中点的位置：镜片中心
const LENS := Vector2(-21.0, -31.5)
const BEAM_COLOR := Color(1.0, 0.93, 0.78)
## —— 夜间打磨（总机台/留声机会话加的，10-17）——
## 血打空以后先演这么久：灯泡一闪一闪、片盘越转越慢、片子"啪"地断掉，然后炸成废铁
const DIE_TIME := 1.0
## 挨打时贴图往后顿 1 格多久（精英怪不吃击退，没有这一下打上去像打在墙上）
const JOLT_TIME := 0.07
## 不吃光照的那层叠图多不透明（暗处也看得出机身的样子，和总机台、留声机一样）
const FILL_ALPHA := 0.4

var state := State.IDLE
var _state_t := 0.0
var _idle_time := 1.2
## 下一招：0 光柱，1 放映
var _next_attack := 0
var _attack_dir := -1
## 光斑现在的 x、扫到哪为止
var _spot_x := 0.0
var _spot_end := 0.0
## 回扫（10-18 加）：第 2、4、6……次光柱扫到头停 BEAM_TURN 秒再扫回来。出招变密以后同一招要放好几次，加个变化
var _beams := 0
var _back := false
var _turn := -1.0
var _spot_start := 0.0
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
var _fill: Sprite2D
## 死亡演出进行了多久，-1 = 没在死
var _dying := -1.0
var _jolt := 0.0
var _reel_phase := 0.0
var _snapped := false


func _setup() -> void:
	reveal_moves = ["BEAM_WARN", "SCREEN_WARN"]   # 露底（EliteBase，布谷鸟钟会话加的一行）：这几招都亮过就加伤
	elite_name = "CINEMA PROJECTOR"
	intro_title = "NOW SHOWING"
	intro_frame = 16
	texture_path = "res://art/enemies/projector.png"
	hframes = 20
	frame_size = Vector2i(44, 55)
	body_rect = Rect2(-15, -52, 30, 52)
	led_pixel = Vector2i(9, 19)
	max_hp = 2400.0   # 10-18：1200 → 2400，出招变密以后每招都能放 3 轮以上
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
	# 暗处亮层：叠一层不吃光照的同一张图，半透明
	_fill = Sprite2D.new()
	_fill.texture = _sprite.texture
	_fill.hframes = hframes
	_fill.centered = false
	var fill_mat := CanvasItemMaterial.new()
	fill_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_fill.material = fill_mat
	add_child(_fill)
	move_child(_fill, _sprite.get_index() + 1)


## 遭遇战把精英怪放在天花板下面 14 格，放映机有 52 格高，场子矮的话身子会插进天花板，
## 物理会把它推到天花板上面去。出生时卡在墙里就往下挪，挪到不卡为止（最多 80 格）
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
	if _dying >= 0.0:
		_tick_dying(delta)
		move_and_slide()
		_update_light()
		_beam.queue_redraw()
		return
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
			if _turn >= 0.0:
				# 回扫：扫到头先停一下（光柱还亮着、光斑原地烧），再往回扫
				_turn += delta
				if _turn >= BEAM_TURN:
					_turn = -1.0
					_back = false
					_spot_end = _spot_start
					Game.sfx("jet", -12.0, 1.2)
			else:
				_spot_x = move_toward(_spot_x, _spot_end, BEAM_SPEED * delta)
			_burn_spot(delta)
			_beam_hit()
			if _spot_x == _spot_end and _turn < 0.0:
				if _back:
					_turn = 0.0
				else:
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
		_spot_start = _spot_x
		_spot_end = _lens().x + _attack_dir * minf(BEAM_MAX, _wall_dist(BEAM_MAX) - HOT_HALF)
		_beams += 1
		_back = _beams % 2 == 0
		_turn = -1.0
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
	# 原图朝左：朝左时镜头在左边（LENS.x 是负的），朝右时镜像过去
	var d := _attack_dir if state != State.IDLE and state != State.WALK else dir
	return global_position.round() + Vector2(LENS.x * -d, LENS.y)


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
		var x := _screen_x + (i * 2 - 1) * 6.0
		# 夹在场子里面（闸门只有 8 像素宽，光框贴着门时出怪点可能落到门外，打不到、清不了场）
		if enc:
			x = clampf(x, float(enc.get("left")) + 16.0, float(enc.get("right")) - 16.0)
		e.position = Vector2(roundf(x), _floor - 2.0)
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
	# 挨打：往背离主角的方向顿 1 格
	_jolt = maxf(_jolt - get_physics_process_delta_time(), 0.0)
	if _jolt > 0.0:
		_sprite.position.x -= dir
	_sprite.modulate = Color.WHITE
	if _dying >= 0.0:
		# 越抖越厉害，开头闪白；红灯一跳一跳地灭
		var k := _dying / DIE_TIME
		var amp := 1.0 + 2.0 * k
		_sprite.position.x += amp if int(_dying * 32.0) % 2 == 0 else -amp
		_sprite.modulate = Color.WHITE.lerp(Color(2.0, 2.0, 2.0), clampf(1.0 - k * 4.0, 0.0, 1.0))
		_led.visible = _led.visible and k < 0.6 and int(_dying * (8.0 + 16.0 * k)) % 2 == 0


## 叠图跟着贴图走（放在 _process 里：出场动画会在 _update_visual 之后再改帧和位置）
func _process(_delta: float) -> void:
	if _fill == null:
		return
	_fill.frame = _sprite.frame
	_fill.flip_h = _sprite.flip_h
	_fill.offset = _sprite.offset
	_fill.position = _sprite.position
	# 死前那一段亮层加厚，灯一闪一灭在暗处也看得清
	_fill.modulate = Color(_sprite.modulate.lerp(Color(3, 3, 3), _flash), 0.75 if _dying >= 0.0 else FILL_ALPHA)


func is_targetable() -> bool:
	return super.is_targetable() and _dying < 0.0


func _on_hurt(_damage: float, full: bool) -> void:
	_jolt = JOLT_TIME
	if full:
		Game.sfx("clang", -14.0, 1.5, 0.1)


## 血打空了：先演一段（DIE_TIME），然后才真的死（EliteBase 的大爆炸、顿帧、扣情绪都在那一刻）。
## 期间不动、不伤人、不再挨打；光柱、银幕马上收掉（放出来的小怪留着，算在这一波里）。
func _die() -> void:
	if _dying >= 0.0:
		return
	_dying = 0.0
	_snapped = false
	_reel_phase = 0.0
	velocity.x = 0.0
	_contact.set_deferred("monitoring", false)
	if state == State.BEAM or state == State.SCREEN or state == State.BEAM_WARN or state == State.SCREEN_WARN:
		_enter(State.RECOVER)
	Game.sfx("tvoff", -6.0, 0.7)
	Game.hitstop(0.08)
	Game.add_shake(2.0)


func _tick_dying(delta: float) -> void:
	_dying += delta
	_state_t += delta
	velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	var k := _dying / DIE_TIME
	# 片盘越转越慢；灯箱前半段一闪一闪（姿势 4 是放光）
	_reel_phase += delta / lerpf(REEL_FRAME_TIME, REEL_FRAME_TIME * 6.0, k)
	var pose := 4 if k < 0.55 and int(_dying / lerpf(0.04, 0.12, k)) % 2 == 0 else 0
	set_frame(pose * 4 + int(_reel_phase) % 4)
	# 片子"啪"地断掉
	if not _snapped and k >= 0.5:
		_snapped = true
		Game.sfx("crack", -6.0, 1.6)
		Game.sparks(get_parent(), _lens(), BEAM_COLOR, 8, 70.0)
	if randf() < 0.2:
		Game.sparks(get_parent(), global_position + Vector2(randf_range(-12.0, 12.0), randf_range(-48.0, -24.0)),
				Color(1.0, 0.85, 0.6), 2, 35.0)
	if _dying >= DIE_TIME:
		EliteFx.scrap_burst(get_parent(), Rect2(global_position + body_rect.position, body_rect.size), 20)
		super._die()


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
			# 夜间打磨加的：光斑要扫过的整条路先在地上淡淡点出来（虚线），一个亮点顺着扫的方向跑，看得出往哪边扫、扫多远
			var x_from := minf(_spot_x, _spot_end)
			var x_to := maxf(_spot_x, _spot_end)
			var span := maxf(x_to - x_from, 1.0)
			var run := fmod(_state_t * 260.0, span)
			if _back:
				# 回扫：亮点跑到头再跑回来，看得出会扫回来
				run = fmod(_state_t * 360.0, span * 2.0)
				run = run if run < span else span * 2.0 - run
			var head := _spot_x + _attack_dir * run
			for x in range(int(x_from), int(x_to), 6):
				var near_head := absf(x - head) < 8.0
				_beam.draw_rect(Rect2(x, _floor - 1.0, 3, 1), Color(BEAM_COLOR, 0.55 if near_head else 0.18))
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
	# 外层淡、内层亮：外层镜头口 7 格高，落到地上 30 格宽；内层 3 格高、12 格宽
	_cone(Vector2(x0, lens.y - 3.0), Vector2(x0, lens.y + 4.0),
			Vector2(spot + s * (HOT_HALF + 6.0), _floor), Vector2(spot - s * (HOT_HALF + 6.0), _floor), Color(BEAM_COLOR, 0.14 * a))
	_cone(Vector2(x0, lens.y - 1.0), Vector2(x0, lens.y + 2.0),
			Vector2(spot + s * (HOT_HALF - 3.0), _floor), Vector2(spot - s * (HOT_HALF - 3.0), _floor), Color(BEAM_COLOR, 0.26 * a))
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
	_dying = -1.0
	_enter(State.IDLE)
