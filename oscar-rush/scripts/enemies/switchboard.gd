class_name Switchboard
extends EliteBase
## 总机台（第二关精英怪，从策划案第九节原设计 B2 接线员来）：一整面插孔板长了腿，前面垂着带插头的线。
## 慢慢朝主角挪，两招轮着放，都先冒红色"!"：
## - 插线通电：一根线甩出去插进主角脚下的地面。那一段约 60 像素先冒火花 0.6 秒，再通电 2 秒，站在上面伤 10。
##   插头本身能打（"enemy" 组，血 100，一发蓄满就断），打掉提前断电。
## - 拔线召唤：从板上拔下两根跳线，线头落地变成两只保险丝甲虫（fuse_beetle.gd 还没有时用爬虫）。
##   自己召出来的还活着两只就不召，改插线；总机台死了，召出来的跟着断电。
## 贴图 switchboard.png（草图/精英怪/l2_switch_gramophone.py 导出），6 帧：
## 0、1 走；2 插线预警（线甩到头顶抡）；3 插线（线甩出去了，灯全亮）；4 拔线预警（两根跳线拽紧）；
## 5 拔线（孔空了冒火花）。

enum State { MOVE, PLUG_WARN, PLUG, PULL_WARN, PULL, RECOVER }

const MOVE_SPEED := 14.0
const WALK_FRAME_TIME := 0.22
## 离主角这么近就站住（插线是远招，不用贴脸）
const STOP_DIST := 60.0
const MOVE_TIME := Vector2(2.2, 2.8)
## 主角在这么远以内才出招
const ATTACK_RANGE := 220.0
const PLUG_WARN := 0.7
## 线甩出去以后站着不动多久（线一直连着，总机台走开了线跟着拖）
const PLUG_HOLD := 0.9
## 线最远甩多远
const PLUG_REACH := 200.0
const PULL_WARN := 0.7
const PULL_TIME := 0.6
const RECOVER_TIME := 0.8
const MAX_SUMMONS := 2
const BEETLE_PATH := "res://scripts/enemies/fuse_beetle.gd"
const CRAWLER_PATH := "res://scripts/enemies/crawler.gd"
## 甩出去那根线的根（帧内像素，朝左）
const CORD_ROOT := Vector2i(8, 33)
## 甲虫从键架前面掉下来：离脚底中间往前多远
const DROP_X := [20.0, 30.0]

var state := State.MOVE
var _state_t := 0.0
var _move_time := 1.4
## 下一招：0 插线，1 拔线
var _next := 0
var _attack_dir := -1
var _cord: CordPlug = null
var _summons: Array[Node2D] = []


func _setup() -> void:
	elite_name = "OPERATOR SWITCHBOARD"
	intro_title = "PLEASE HOLD"
	intro_frame = 2
	texture_path = "res://art/enemies/switchboard.png"
	hframes = 6
	frame_size = Vector2i(54, 47)
	body_rect = Rect2(-15, -46, 30, 46)
	contact_rect = Rect2(-15, -44, 30, 44)
	led_pixel = Vector2i(16, 7)
	max_hp = 1250.0
	contact_damage = 10.0


func _tick(delta: float) -> void:
	_state_t += delta
	match state:
		State.MOVE:
			_move(delta)
			set_frame(int(_time / WALK_FRAME_TIME) % 2)
			var p := nearest_player(ATTACK_RANGE)
			if _state_t >= _move_time and is_on_floor() and p \
					and absf(p.global_position.y - global_position.y) < 80.0:
				_start_attack(p)
		State.PLUG_WARN:
			_brake(delta)
			set_frame(2)
			if _state_t >= PLUG_WARN:
				_throw()
				_enter(State.PLUG)
		State.PLUG:
			_brake(delta)
			set_frame(3)
			if _state_t >= PLUG_HOLD:
				_enter(State.RECOVER)
		State.PULL_WARN:
			_brake(delta)
			set_frame(4)
			if _state_t >= PULL_WARN:
				_summon()
				_enter(State.PULL)
		State.PULL:
			_brake(delta)
			set_frame(5)
			if _state_t >= PULL_TIME:
				_enter(State.RECOVER)
		State.RECOVER:
			_brake(delta)
			set_frame(0)
			if _state_t >= RECOVER_TIME:
				_enter(State.MOVE)
	move_and_slide()


func _enter(s: State) -> void:
	state = s
	_state_t = 0.0
	if s == State.MOVE:
		_move_time = randf_range(MOVE_TIME.x, MOVE_TIME.y)


func _start_attack(p: Player) -> void:
	_face(p)
	_attack_dir = dir
	var can_pull := _alive_summons() < MAX_SUMMONS
	var can_plug := not is_instance_valid(_cord)
	var pull := (_next == 1 and can_pull) or (not can_plug and can_pull)
	if not pull and not can_plug:
		_enter(State.MOVE)                  # 线还插着、甲虫也满了：再挪一会儿
		return
	if pull:
		warn(PULL_WARN)
		_enter(State.PULL_WARN)
		Game.sfx("dial", -8.0, 0.8)
		_next = 0
	else:
		warn(PLUG_WARN)
		_enter(State.PLUG_WARN)
		Game.sfx("ready", -12.0, 0.7)
		_next = 1


func _move(delta: float) -> void:
	var p := nearest_player()
	if p == null:
		_brake(delta)
		return
	_face(p)
	if absf(p.global_position.x - global_position.x) > STOP_DIST and ground_ahead(18.0) and not is_on_wall():
		velocity.x = dir * MOVE_SPEED * speed_mult()
	else:
		_brake(delta)


func _brake(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)


func _face(p: Player) -> void:
	if absf(p.global_position.x - global_position.x) > 2.0:
		dir = 1 if p.global_position.x > global_position.x else -1


## 帧里的像素（原图朝左）→ 相对脚底中间的位置，朝右时镜像
func _frame_pos(px: Vector2i) -> Vector2:
	var col := px.x if dir < 0 else frame_size.x - 1 - px.x
	return Vector2(col - frame_size.x / 2, px.y - frame_size.y)


## 甩出去那根线的根（世界坐标）
func cord_root() -> Vector2:
	return global_position.round() + _frame_pos(CORD_ROOT)


## 插线：落点是主角脚下的地面（最远 PLUG_REACH）
func _throw() -> void:
	var p := nearest_player()
	var tx := global_position.x + _attack_dir * 90.0
	var from_y := global_position.y - 20.0
	if p:
		tx = clampf(p.global_position.x, global_position.x - PLUG_REACH, global_position.x + PLUG_REACH)
		from_y = p.global_position.y - 20.0
	var q := PhysicsRayQueryParameters2D.create(Vector2(tx, from_y), Vector2(tx, from_y + 140.0), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or (hit.normal as Vector2).y > -0.5:
		return
	var c := CordPlug.new()
	c.elite = self
	c.target = (hit.position as Vector2).round()
	c.from = cord_root()
	get_parent().add_child(c)
	c.global_position = c.from
	_cord = c
	Game.sfx("jump", -6.0, 0.6)
	Game.sfx("scrape", -10.0, 1.6)


## 拔线：两根线头落地变成甲虫
func _summon() -> void:
	var path := BEETLE_PATH if ResourceLoader.exists(BEETLE_PATH) else CRAWLER_PATH
	var script := load(path) as GDScript
	Game.sfx("crack", -6.0, 1.4)
	Game.sfx("buzz", -10.0, 1.6)
	Game.add_shake(2.0)
	for i in DROP_X.size():
		var pos := global_position + Vector2(_attack_dir * DROP_X[i], -6.0)
		if _in_wall(pos):
			pos = global_position + Vector2(0, -6.0)
		var e := script.new() as Node2D
		if e == null:
			continue
		if "respawn_time" in e:
			e.set("respawn_time", 0.0)
		e.position = pos
		get_parent().add_child(e)
		if "dir" in e:
			e.set("dir", _attack_dir)
		if e is CharacterBody2D:
			(e as CharacterBody2D).velocity = Vector2(_attack_dir * (40.0 + 30.0 * i), -130.0)
		_summons.append(e)
		Game.sparks(get_parent(), pos + Vector2(0, -4), Color(0.6, 0.85, 1.0), 6, 60.0)
		Game.sparks(get_parent(), global_position + _frame_pos(Vector2i(26, 14)), Color(1.0, 0.85, 0.6), 4, 50.0)


func _alive_summons() -> int:
	var n := 0
	for e in _summons.duplicate():
		if not is_instance_valid(e) or e.get("dead") == true:
			_summons.erase(e)
		else:
			n += 1
	return n


func _in_wall(pos: Vector2) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = pos
	q.collision_mask = 1
	return not get_world_2d().direct_space_state.intersect_point(q, 1).is_empty()


## 死了：线断电、召出来的甲虫跟着灭
func _on_die() -> void:
	if is_instance_valid(_cord):
		_cord.cut()
	for e in _summons:
		if is_instance_valid(e) and e.get("dead") != true and e.has_method("hurt"):
			e.call("hurt", 9999.0, Vector2.UP, true)
	_summons.clear()


func _on_respawn() -> void:
	_enter(State.MOVE)


## 预警时板子抖、一闪一闪发红，越接近放招越快（照钢琴）
func _update_visual() -> void:
	super._update_visual()
	var warn_t := -1.0
	match state:
		State.PLUG_WARN:
			warn_t = _state_t / PLUG_WARN
		State.PULL_WARN:
			warn_t = _state_t / PULL_WARN
	if warn_t >= 0.0:
		var amp := 1.0 if warn_t < 0.6 else 2.0
		_sprite.position.x += amp if int(_state_t * 30.0) % 2 == 0 else -amp
		var pulse := 0.5 + 0.5 * sin(_state_t * (14.0 + 20.0 * warn_t))
		_sprite.modulate = Color.WHITE.lerp(Color(1.8, 0.75, 0.6), pulse * (0.4 + 0.6 * warn_t))
	else:
		_sprite.modulate = Color.WHITE


## 甩出去的插头 + 连回总机台的线。插进地面以后：火花 SPARK 秒 → 通电 LIVE 秒 → 收回去。
## 插头在 "enemy" 组里，血 100，打掉提前断电。放在关卡节点下，总机台死了也会自己收回。
class CordPlug:
	extends StaticBody2D

	const FLY := 0.35
	const SPARK := 0.6
	const LIVE := 2.0
	const RETRACT := 0.3
	## 通电那段地面的一半长度
	const HALF := 30.0
	const DAMAGE := 10.0
	const MAX_HP := 100.0
	const ELEC := Color(0.6, 0.85, 1.0)
	const CORD := Color8(0x4b, 0x47, 0x42)
	const PLUG := Color8(0x8a, 0x84, 0x7c)
	const PLUG_DARK := Color8(0x5c, 0x57, 0x52)
	const BRASS := Color8(0x6e, 0x58, 0x46)

	var elite: Switchboard
	## 线根（世界坐标），总机台活着时每帧更新
	var from := Vector2.ZERO
	## 落点（地面）
	var target := Vector2.ZERO
	var hp := MAX_HP
	## 通电那段地面（世界 x）
	var x0 := 0.0
	var x1 := 0.0

	var _t := 0.0
	var _landed := false
	var _live := false
	var _retract := -1.0
	var _retract_from := Vector2.ZERO
	var _flash := 0.0
	var _shape: CollisionShape2D

	func _ready() -> void:
		add_to_group("enemy")
		collision_layer = 4
		collision_mask = 0
		z_index = 4
		_shape = CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(6, 8)
		_shape.shape = r
		_shape.position = Vector2(0, -4)
		_shape.disabled = true
		add_child(_shape)
		# 线、火花、电弧黑暗里也要看得见
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded

	func aim_point() -> Vector2:
		return global_position + Vector2(0, -4)

	func is_targetable() -> bool:
		return _landed and _retract < 0.0

	func hurt(damage: float, _from_dir: Vector2, _full: bool) -> void:
		if not is_targetable():
			return
		hp -= damage
		_flash = 1.0
		Game.sparks(get_parent(), aim_point(), Color(1.0, 0.85, 0.6), 4, 50.0)
		Game.sfx("hit", -8.0, 1.6, 0.1)
		if hp <= 0.0:
			Game.sfx("crack", -6.0, 1.3)
			Game.sparks(get_parent(), aim_point(), ELEC, 10, 80.0)
			cut()

	## 断电，线收回去
	func cut() -> void:
		if _retract >= 0.0:
			return
		_retract = 0.0
		_retract_from = global_position
		_live = false
		_shape.set_deferred("disabled", true)
		remove_from_group("enemy")

	func _physics_process(delta: float) -> void:
		_t += delta
		_flash = maxf(_flash - delta * 8.0, 0.0)
		if is_instance_valid(elite) and not elite.dead:
			from = elite.cord_root()
		elif _retract < 0.0:
			cut()
		if _retract >= 0.0:
			_retract += delta
			var k := clampf(_retract / RETRACT, 0.0, 1.0)
			global_position = _retract_from.lerp(from, k * k)
			if _retract >= RETRACT:
				queue_free()
				return
		elif _t < FLY:
			var k := _t / FLY
			global_position = from.lerp(target, k) + Vector2(0, -36.0 * 4.0 * k * (1.0 - k))
		else:
			if not _landed:
				_land()
			var lt := _t - FLY - SPARK
			if lt >= 0.0 and not _live and lt < LIVE:
				_live = true
				Game.sfx("buzz", -4.0, 0.9)
				Game.add_shake(2.0)
			if _live:
				_zap()
			if lt >= LIVE:
				cut()
		queue_redraw()

	func _land() -> void:
		_landed = true
		global_position = target
		_shape.disabled = false
		Game.sfx("clang", -8.0, 1.5)
		Game.sfx("static", -10.0, 1.2)
		Game.dust(get_parent(), target, 3)
		Game.sparks(get_parent(), target + Vector2(0, -2), ELEC, 6, 60.0, Vector2.UP)
		# 通电那段跟着地面往两边铺，碰到墙或者坑就停
		x0 = target.x
		x1 = target.x
		var space := get_world_2d().direct_space_state
		for side in [-1.0, 1.0]:
			var x := target.x
			for i in int(HALF / 3.0):
				var nx: float = x + side * 3.0
				var wall := PhysicsRayQueryParameters2D.create(Vector2(x, target.y - 4.0), Vector2(nx, target.y - 4.0), 1)
				if not space.intersect_ray(wall).is_empty():
					break
				var down := PhysicsRayQueryParameters2D.create(Vector2(nx, target.y - 3.0), Vector2(nx, target.y + 3.0), 1)
				if space.intersect_ray(down).is_empty():
					break
				x = nx
			if side < 0.0:
				x0 = x
			else:
				x1 = x

	## 通电：站在这段地面上的主角挨电
	func _zap() -> void:
		for n in get_tree().get_nodes_in_group("player"):
			var p := n as Player
			if p and p.is_on_floor() and absf(p.global_position.y - target.y) < 3.0 \
					and p.global_position.x >= x0 - 3.0 and p.global_position.x <= x1 + 3.0:
				p.hurt(Vector2(p.global_position.x, target.y + 6.0), DAMAGE * EnemyBase.damage_mult())

	func _draw() -> void:
		draw_set_transform(global_position.round() - global_position)
		var me := global_position.round()
		# 线：从线根垂下来连到插头顶上；通电时一串蓝光顺着线往插头流
		var a := from - me
		var b := Vector2(0, -7)
		var mid := (a + b) / 2.0 + Vector2(0, 14.0 if _landed else -6.0)
		var n := int(maxf(a.distance_to(b) * 1.3, 8.0))
		var last := Vector2.INF
		var i := 0
		for s in n + 1:
			var t := float(s) / n
			var pt := ((1.0 - t) * (1.0 - t) * a + 2.0 * (1.0 - t) * t * mid + t * t * b).round()
			if pt == last:
				continue
			last = pt
			var col := CORD
			if _live and (i + int(_t * 40.0)) % 9 == 0:
				col = ELEC
			draw_rect(Rect2(pt, Vector2.ONE), col)
			i += 1
		# 插头：铜套 + 壳 + 尖插进地里
		var body := PLUG.lerp(Color.WHITE, _flash)
		draw_rect(Rect2(-1, -7, 3, 1), BRASS.lerp(Color.WHITE, _flash))
		draw_rect(Rect2(-1, -6, 3, 4), body)
		draw_rect(Rect2(1, -6, 1, 4), PLUG_DARK.lerp(Color.WHITE, _flash))
		draw_rect(Rect2(0, -2, 1, 2), Color8(0xa8, 0xa2, 0x98))
		if not _landed or _retract >= 0.0:
			return
		var l := x0 - me.x
		var w := x1 - x0
		var st := _t - FLY
		if st < SPARK:
			# 火花：整段地面上蓝点一闪一闪，越到后面越快，插头边上冒火星
			if int(st / (0.05 if st > SPARK * 0.5 else 0.1)) % 2 == 0:
				for x in range(int(l) + 1, int(l + w), 4):
					draw_rect(Rect2(x, -1, 2, 1), Color(ELEC, 0.9))
			for k in 3:
				var sp := Vector2(randf_range(-4, 4), -randf_range(1, 6)).round()
				draw_rect(Rect2(sp, Vector2.ONE), Color(1.0, 0.95, 0.8))
			return
		if not _live:
			return
		# 通电：整段地面发白，上面一串串电弧跳
		draw_rect(Rect2(l, -2, w + 1, 2), Color(0.8, 0.92, 1.0, 0.9))
		for k in 8:
			var x := randf_range(l, l + w)
			var h := randi_range(3, 9)
			var px := x
			for y in h:
				px += randf_range(-1.2, 1.2)
				draw_rect(Rect2(roundf(px), -3 - y, 1, 1), Color(0.7, 0.88, 1.0))
