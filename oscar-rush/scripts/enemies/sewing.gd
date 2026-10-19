class_name SewingMachine
extends EliteBase
## 缝纫机（策划案第九节精英怪 2）：朝主角走。
## 招一"缝过来"：冒"!"、针抬起来，然后一路往前扎——扎一下、往前挪 10 像素，一共 5 下，
## 每下针尖有个 6 像素宽的判定。扎过的地面留下一道线，3 秒内主角踩在上面会变慢。
## 招二"抛线轴"：主角离得远（或连着缝了两回）时冒"!"，主角脚下先亮落点标记，
## 线轴往上弧线飞过去，落地砸一下，摊开一圈线（同样会变慢）。
## 帧：0、1 走路，2 针抬起，3 针扎到地上，4 线轴抛出去了，5 抛线轴前摇（线轴发亮）。
## 贴图由 草图/精英怪/export_clock_sew_cash.py 导出。

enum { WALK, STITCH_WARN, STITCH, SPOOL_WARN, RECOVER }

const WALK_SPEED := 18.0
const STOP_DIST := 26.0
const SEE_DIST := 260.0
const WALK_FRAME_TIME := 0.2
const ATTACK_INTERVAL := 0.8  # 10-18 作者：招和招之间停太久
# —— 缝过来 ——
## 主角在水平这么近、高度差 24 内才缝，远了就抛线轴
const STITCH_RANGE := 90.0
const STITCH_HEIGHT := 24.0
const STITCH_WARN_TIME := 0.55
const STITCHES := 5
const STITCH_STEP := 10.0
## 一针：先扎下去（判定开着），再抬起来往前挪
const STAB_DOWN := 0.12
const STAB_UP := 0.1
## 针尖的判定（朝左时）：6 像素宽，从地面往上 15 像素
const NEEDLE_RECT := Rect2(-16, -15, 6, 15)
const NEEDLE_X := 13.0
const STITCH_DAMAGE := 10.0
const STITCH_RECOVER := 0.7
# —— 抛线轴 ——
const SPOOL_WARN_TIME := 0.6
const SPOOL_FLIGHT := 0.9
const SPOOL_REACH := 150.0
const SPOOL_DAMAGE := 10.0
const SPOOL_RECOVER := 0.4
## 线轴在原图（朝左）里相对脚底中间的位置
const SPOOL_POS := Vector2(0, -28)
## 地上的线：主角踩着时每个物理帧水平速度乘这个
## 实测（主角每帧自己会把速度往回加，所以不是线性的）：0.6 时提灯 90 → 34（太粘），0.75 → 55（约六成），
## 0.8 → 69，0.85 就完全不减速了。10-17 夜间打磨从 0.6 调到 0.75
const THREAD_SLOW := 0.75
const THREAD_LIFE := 3.0

var _state := WALK
var _timer := 0.0
var _attack_t := 1.0
var _stitch_runs := 0
var _stab := 0
var _down := false
var _thread: ThreadLine
var _spool: Spool


func _setup() -> void:
	reveal_moves = ["STITCH_WARN", "SPOOL_WARN"]   # 露底（EliteBase）：这几招都亮过就加伤；贴身才出的近身招不算
	elite_name = "SEWING MACHINE"
	intro_title = "STITCHED UP"
	intro_frame = 3
	fill_alpha = 0.35
	death_time = 1.1
	death_frame = 3
	texture_path = "res://art/enemies/sewing.png"
	hframes = 6
	frame_size = Vector2i(43, 28)
	body_rect = Rect2(-18, -25, 36, 25)
	contact_rect = Rect2(-16, -22, 32, 22)
	led_pixel = Vector2i(6, 6)
	max_hp = 1230.0  # 10-18 作者：第一关太肉（没买科技，要比后两关脆），三把武器站桩 12～18 秒
	contact_damage = 10.0


func _tick(delta: float) -> void:
	_timer -= delta
	match _state:
		WALK:
			_attack_t -= delta
			var p := nearest_player(SEE_DIST)
			_walk(p)
			if p and _attack_t <= 0.0 and is_on_floor():
				_attack_t = ATTACK_INTERVAL * interval_mult()
				p = pick_focus(p)      # 双人时轮着盯一个人，整招不换
				if absf(p.global_position.x - global_position.x) > 2.0:
					dir = 1 if p.global_position.x > global_position.x else -1
				var d := p.global_position - global_position
				if absf(d.x) <= STITCH_RANGE and absf(d.y) <= STITCH_HEIGHT and _stitch_runs < 1:   # 10-18：缝一次抛一次轮着来（原来缝两次才抛一次，线轴一辈子抛不了几回）
					_stitch_runs += 1
					_state = STITCH_WARN
					_timer = STITCH_WARN_TIME
					warn(STITCH_WARN_TIME)
					Game.sfx("ready", -12.0, 1.4)
				else:
					_stitch_runs = 0
					_start_spool(p)
		STITCH_WARN:
			_brake(delta)
			set_frame(2)
			if _timer <= 0.0:
				_state = STITCH
				_stab = 0
				_thread = null
				_stab_down()
		STITCH:
			_stitch()
		SPOOL_WARN:
			_brake(delta)
			set_frame(5 if int(_timer / 0.07) % 2 == 0 else 0)
			if _timer <= 0.0:
				set_frame(4)
				_spool = null
				Game.sfx("jump", -8.0, 1.3)
				_state = RECOVER
				_timer = SPOOL_RECOVER
		RECOVER:
			_brake(delta)
			if frame != 4 or _timer < SPOOL_RECOVER - 0.25:
				set_frame(0)
			if _timer <= 0.0:
				_state = WALK
	move_and_slide()


func _walk(p: Player) -> void:
	var move := false
	if p:
		var dx := p.global_position.x - global_position.x
		if absf(dx) > 2.0:
			dir = 1 if dx > 0.0 else -1
		move = absf(dx) > STOP_DIST and is_on_floor() and not is_on_wall() and ground_ahead(20.0)
	velocity.x = dir * WALK_SPEED * speed_mult() if move else 0.0
	set_frame(int(_time / WALK_FRAME_TIME) % 2 if move else 0)


func _stab_down() -> void:
	_down = true
	_timer = STAB_DOWN
	velocity.x = 0.0
	var tip := Vector2(global_position.x + NEEDLE_X * dir, global_position.y)
	if _thread == null or not is_instance_valid(_thread):
		_thread = ThreadLine.new()
		get_parent().add_child(_thread)
	_thread.add_point(tip)
	Game.sfx("land", -12.0, 2.2, 0.1)
	Game.dust(get_parent(), tip, 1)


## 一针一针往前扎：扎下去 0.12 秒（判定开着），抬起来 0.1 秒往前挪 10 像素
func _stitch() -> void:
	if _down:
		set_frame(3)
		_hit_rect(NEEDLE_RECT, STITCH_DAMAGE * damage_mult())
		if _timer <= 0.0:
			_down = false
			_stab += 1
			if _stab >= STITCHES:
				_state = RECOVER
				_timer = STITCH_RECOVER
				return
			_timer = STAB_UP
	else:
		set_frame(2)
		var blocked := is_on_wall() or not ground_ahead(20.0)
		velocity.x = 0.0 if blocked else dir * STITCH_STEP / STAB_UP
		if _timer <= 0.0:
			_stab_down()


func _start_spool(p: Player) -> void:
	_state = SPOOL_WARN
	_timer = SPOOL_WARN_TIME
	velocity.x = 0.0
	var dx := p.global_position.x - global_position.x
	if absf(dx) > 2.0:
		dir = 1 if dx > 0.0 else -1
	warn(SPOOL_WARN_TIME)
	_spool = Spool.new()
	_spool.from = global_position + SPOOL_POS
	_spool.target = _landing(p)
	_spool.delay = SPOOL_WARN_TIME
	_spool.flight = SPOOL_FLIGHT
	_spool.damage = SPOOL_DAMAGE * damage_mult()
	get_parent().add_child(_spool)


## 落点：主角脚下那一列（水平最多 150），往下找地；找不到就用主角的脚底
func _landing(p: Player) -> Vector2:
	var x := clampf(p.global_position.x, global_position.x - SPOOL_REACH, global_position.x + SPOOL_REACH)
	var from := Vector2(x, p.global_position.y - 30.0)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 160), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	return (hit["position"] as Vector2).round() if not hit.is_empty() else p.global_position.round()


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


func _on_die() -> void:
	# 还没扔出去的线轴（落点标记已经亮了）跟着一起没
	if is_instance_valid(_spool) and _spool.waiting():
		_spool.queue_free()
	_spool = null


func _on_respawn() -> void:
	_state = WALK
	_attack_t = 1.0
	_stitch_runs = 0


## 地上的一道线：按扎针的点连起来，最后一针以后留 3 秒（最后 0.6 秒淡掉）。
## 主角站在上面（在地上）时，每个物理帧把他的水平速度乘 THREAD_SLOW；几道线叠在一起也只乘一次。
class ThreadLine:
	extends Node2D

	const COLOR := Color(0.86, 0.8, 0.68)
	const FADE := 0.6

	var life := SewingMachine.THREAD_LIFE
	var _pts: Array[Vector2] = []
	var _area: Area2D

	func _ready() -> void:
		top_level = true
		global_position = Vector2.ZERO
		z_index = 1
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded
		_area = Area2D.new()
		_area.collision_layer = 0
		_area.collision_mask = 2
		add_child(_area)

	## 加一个点（世界坐标，地面上）；和上一个点之间那段地面变成会减速的线
	func add_point(p: Vector2) -> void:
		var a := _pts[-1] if not _pts.is_empty() else p
		_pts.append(p)
		life = SewingMachine.THREAD_LIFE
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(absf(p.x - a.x) + 6.0, 4.0)
		cs.shape = r
		cs.position = Vector2((a.x + p.x) / 2.0, (a.y + p.y) / 2.0 - 2.0)
		_area.add_child(cs)
		queue_redraw()

	func _physics_process(delta: float) -> void:
		life -= delta
		if life <= 0.0:
			queue_free()
			return
		var f := Engine.get_physics_frames()
		for b in _area.get_overlapping_bodies():
			var pl := b as Player
			if pl and pl.is_on_floor() and pl.get_meta("thread_slow_frame", -1) != f:
				pl.set_meta("thread_slow_frame", f)
				pl.velocity.x *= SewingMachine.THREAD_SLOW
		if life < FADE:
			queue_redraw()

	func _draw() -> void:
		var col := Color(COLOR, 0.85 * clampf(life / FADE, 0.0, 1.0))
		if _pts.size() == 1:
			draw_rect(Rect2(_pts[0] + Vector2(-3, -1), Vector2(6, 1)), col)
			return
		# 虚线：亮 2 格、空 1 格，像缝出来的线迹；每个针眼往下扎一个点
		for i in range(1, _pts.size()):
			var a := _pts[i - 1].round()
			var b := _pts[i].round()
			var n := int(absf(b.x - a.x))
			for k in range(-3, n + 4):
				if posmod(k, 3) == 2:
					continue
				var t := clampf(float(k) / maxf(n, 1.0), 0.0, 1.0)
				var x := a.x + signf(b.x - a.x) * k
				draw_rect(Rect2(Vector2(x, roundf(lerpf(a.y, b.y, t)) - 1.0), Vector2.ONE), col)
		for p in _pts:
			draw_rect(Rect2(p.round() + Vector2(0, -2), Vector2.ONE), Color(col, col.a * 0.7))


## 抛出去的线轴：先等 delay 秒（这段时间只画落点标记），然后从 from 沿弧线飞 flight 秒正好落到 target，
## 落地砸一下（判定 20×10），摊开一圈 20 像素长的线。飞的途中碰到人也算。
class Spool:
	extends Area2D

	const GRAVITY := 520.0
	const IMPACT := Vector2(20, 10)

	var from := Vector2.ZERO
	var target := Vector2.ZERO
	var delay := 0.6
	var flight := 0.9
	var damage := 10.0
	var _t := 0.0
	var _v0 := Vector2.ZERO
	var _hit := false
	var _marker: Node2D

	func waiting() -> bool:
		return _t < delay

	func _ready() -> void:
		top_level = true
		global_position = from
		collision_layer = 0
		collision_mask = 2 | 8
		monitoring = false
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(4, 4)
		cs.shape = r
		add_child(cs)
		body_entered.connect(_on_body)
		visible = true
		# 飞着的线轴也是要躲的东西：不吃场景压暗
		var mat := CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = mat
		_v0 = (target - from - 0.5 * Vector2(0, GRAVITY) * flight * flight) / flight
		# 落点标记：不吃场景压暗，挂在世界坐标上
		_marker = Node2D.new()
		_marker.top_level = true
		_marker.global_position = target
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		_marker.material = unshaded
		_marker.draw.connect(_draw_marker)
		add_child(_marker)

	func _physics_process(delta: float) -> void:
		_t += delta
		_marker.queue_redraw()
		if waiting():
			return
		if not monitoring:
			monitoring = true
		var ft := _t - delay
		if ft >= flight:
			_land()
			return
		global_position = from + _v0 * ft + 0.5 * Vector2(0, GRAVITY) * ft * ft
		queue_redraw()

	func _on_body(b: Node) -> void:
		if _hit:
			return
		_hit = true
		if b is Player:
			(b as Player).hurt(global_position, damage)
		elif b is Crystal:
			(b as Crystal).take_hit(global_position, damage)

	func _land() -> void:
		var shape := RectangleShape2D.new()
		shape.size = IMPACT
		var q := PhysicsShapeQueryParameters2D.new()
		q.shape = shape
		q.transform = Transform2D(0.0, target + Vector2(0, -IMPACT.y / 2.0))
		q.collision_mask = 2 | 8
		for hit in get_world_2d().direct_space_state.intersect_shape(q, 8):
			var b: Object = hit["collider"]
			if b is Player:
				(b as Player).hurt(target, damage)
			elif b is Crystal:
				(b as Crystal).take_hit(target, damage)
		var line := ThreadLine.new()
		get_parent().add_child(line)
		line.add_point(target + Vector2(-10, 0))
		line.add_point(target + Vector2(10, 0))
		Game.dust(get_parent(), target, 4)
		Game.sfx("land", -6.0, 1.3, 0.1)
		Game.add_shake(1.5)
		queue_free()

	func _draw() -> void:
		if waiting():
			return
		# 线轴：锈色小轴，两头亮边，后面拖一小截线
		var o := global_position.round() - global_position
		var spin := int(_t * 14.0) % 2
		draw_rect(Rect2(o + Vector2(-1, -1), Vector2(3, 3)), Color8(0x8a, 0x5e, 0x44))
		draw_rect(Rect2(o + Vector2(-1, -1 + spin * 2), Vector2(3, 1)), Color8(0xc8, 0xbe, 0xae))
		draw_rect(Rect2(o + Vector2(0, 0), Vector2(1, 1)), ThreadLine.COLOR)

	func _draw_marker() -> void:
		var col := EnemyBase.LED_COLOR if int(_t * 10.0) % 2 == 0 else EnemyBase.LED_COLOR.darkened(0.45)
		_marker.draw_rect(Rect2(-6, -1, 13, 1), Color(col, 0.85))
		_marker.draw_rect(Rect2(0, -3, 1, 2), col)
		_marker.draw_rect(Rect2(-7, -1, 1, 1), Color(col, 0.35))
		_marker.draw_rect(Rect2(7, -1, 1, 1), Color(col, 0.35))
