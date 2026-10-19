class_name Switchboard
extends EliteBase
## 总机台（第二关精英怪，从策划案第九节原设计 B2 接线员来）：一整面插孔板长了腿，前面垂着带插头的线。
## 慢慢朝主角挪，两招轮着放，都先冒红色"!"：
## - 插线通电：预警时主角脚下那一段先标出蓝色方括号；一根线甩出去插进主角脚下的地面。那一段约 60 像素先冒火花 0.6 秒，再通电 2 秒，站在上面伤 10。
##   插头本身能打（"enemy" 组，血 100，一发蓄满就断），打掉提前断电。
## - 拔线召唤：从板上拔下两根跳线，线头落地变成两只保险丝甲虫（fuse_beetle.gd 还没有时用爬虫）。
##   自己召出来的还活着两只就不召，改插线；总机台死了，召出来的跟着断电碎掉（不炸、不放电）。
## 贴图 switchboard.png（草图/精英怪/l2_switch_gramophone.py 导出），6 帧：
## 0、1 走；2 插线预警（线甩到头顶抡）；3 插线（线甩出去了，灯全亮）；4 拔线预警（两根跳线拽紧）；
## 5 拔线（孔空了冒火花）。

enum State { MOVE, PLUG_WARN, PLUG, PULL_WARN, PULL, RECOVER }

const MOVE_SPEED := 14.0
const WALK_FRAME_TIME := 0.22
## 离主角这么近就站住（插线是远招，不用贴脸）
const STOP_DIST := 60.0
## 两招之间走几步就出下一招（10-18 作者嫌停顿太长、一辈子只放几次招：2.2~2.8 → 0.6~1.0，连收招一共空 1.1~1.5 秒）
const MOVE_TIME := Vector2(0.6, 1.0)
## 主角在这么远以内才出招
const ATTACK_RANGE := 220.0
const PLUG_WARN := 0.7
## 线甩出去以后站着不动多久（线一直连着，总机台走开了线跟着拖）
const PLUG_HOLD := 0.9
## 线最远甩多远
const PLUG_REACH := 200.0
## 双插：第二根落在主角身后多远（两段通电地面中间留 DOUBLE_GAP - 2*HALF 的空，站中间也躲得掉）、比第一根晚多久扔
const DOUBLE_GAP := 74.0
const DOUBLE_DELAY := 0.2
const PULL_WARN := 0.7
const PULL_TIME := 0.6
const RECOVER_TIME := 0.5
## 场上最多几只甲虫；拉闸一次最多掉两只，补到这个数为止（10-18：2 → 3，不然甲虫没打掉就一直拉不了闸）
const MAX_SUMMONS := 3
const BEETLE_PATH := "res://scripts/enemies/fuse_beetle.gd"
const CRAWLER_PATH := "res://scripts/enemies/crawler.gd"
## 甩出去那根线的根（帧内像素，朝左）
const CORD_ROOT := Vector2i(8, 33)
## 甲虫从键架前面掉下来：离脚底中间往前多远
const DROP_X := [20.0, 30.0]
## 不吃光照的那层叠图多不透明（暗处也看得出身子的样子）
const FILL_ALPHA := 0.4
## 血打空以后先"断电"这么久：板上的灯乱闪、越闪越慢，红灯一跳一跳地灭掉，然后炸成一地废铁
const DIE_TIME := 1.0
## 挨打时贴图往后顿 1 格多久（精英怪不吃击退，没有这一下打上去像打在墙上）
const JOLT_TIME := 0.07

var state := State.MOVE
var _fill: Sprite2D
## 断电演出进行了多久，-1 = 没在死
var _dying := -1.0
var _jolt := 0.0
## 插线预警时标在主角脚下的那一段（线会甩到那里）
var _aim: Node2D
## 插线锁定的那个主角：预警开始时选最近的，方括号跟着他走，线也甩到他脚下（双人时不会中途换人）
var _aim_target: Player = null
var _state_t := 0.0
var _move_time := 1.4
## 下一招：0 插线，1 拔线
var _next := 0
var _attack_dir := -1
var _cord: CordPlug = null
## 双插的第二根（落在主角身后，堵退路）
var _cord2: CordPlug = null
## 放过几次插线：第 2、4、6……次是双插（10-18：出招变密以后同一招要放五六次，加个变化）
var _plugs := 0
## 这一次是不是双插、第二根扔出去没有
var _double := false
var _thrown2 := false
## 第二根的落点 x、找地面的起点 y（扔第一根时就定下来，和预警最后那一刻标的一样）
var _x2 := NAN
var _y2 := 0.0
var _summons: Array[Node2D] = []


func _setup() -> void:
	reveal_moves = ["PLUG_WARN", "PULL_WARN"]   # 露底（EliteBase，布谷鸟钟会话加的一行）：这几招都亮过就加伤
	elite_name = "OPERATOR SWITCHBOARD"
	intro_title = "PLEASE HOLD"
	intro_frame = 2
	texture_path = "res://art/enemies/switchboard.png"
	hframes = 6
	frame_size = Vector2i(54, 47)
	body_rect = Rect2(-15, -46, 30, 46)
	contact_rect = Rect2(-15, -44, 30, 44)
	led_pixel = Vector2i(16, 7)
	max_hp = 1950.0   # 10-18：1250 → 1950，出招变密以后每招都能放 3 轮以上
	contact_damage = 10.0


## 第二关机房很暗，背后又是一整面插孔板，深灰的身子融进墙里只剩红灯（作者 10-17 找不到它）。
## 叠一层不吃光照的同一张图，半透明，暗处也看得出形状；亮处基本看不出差别。
## （出生卡进天花板的问题已经在 encounter.gd 的 _drop_below_ceiling 统一修了，这里原来的补丁删了）
func _after_ready() -> void:
	_aim = Node2D.new()
	_aim.top_level = true
	_aim.z_index = 6
	var aim_mat := CanvasItemMaterial.new()
	aim_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_aim.material = aim_mat
	_aim.draw.connect(_draw_aim)
	add_child(_aim)
	_fill = Sprite2D.new()
	_fill.texture = _sprite.texture
	_fill.hframes = hframes
	_fill.centered = false
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_fill.material = unshaded
	add_child(_fill)
	move_child(_fill, _sprite.get_index() + 1)


func _tick(delta: float) -> void:
	if _dying >= 0.0:
		_tick_dying(delta)
		move_and_slide()
		return
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
			if _double and not _thrown2 and _state_t >= DOUBLE_DELAY:
				_thrown2 = true
				if not is_nan(_x2):
					_cord2 = _throw_at(_x2, _y2)
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
	var can_plug := not is_instance_valid(_cord) and not is_instance_valid(_cord2)
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
		_aim_target = p
		_plugs += 1
		_double = _plugs % 2 == 0
		_thrown2 = false
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
	var p := _aim_target if is_instance_valid(_aim_target) else nearest_player()
	var tx := global_position.x + _attack_dir * 90.0
	var from_y := global_position.y - 20.0
	if p:
		tx = clampf(p.global_position.x, global_position.x - PLUG_REACH, global_position.x + PLUG_REACH)
		from_y = p.global_position.y - 20.0
	_cord = _throw_at(tx, from_y)
	_x2 = _second_x(p) if _double else NAN
	_y2 = from_y


## 往 x 那一列往下找地面，甩一根线过去；找不到地面就不甩，返回 null
func _throw_at(tx: float, from_y: float) -> CordPlug:
	var q := PhysicsRayQueryParameters2D.create(Vector2(tx, from_y), Vector2(tx, from_y + 140.0), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or (hit.normal as Vector2).y > -0.5:
		return null
	var c := CordPlug.new()
	c.elite = self
	c.target = (hit.position as Vector2).round()
	c.from = cord_root()
	get_parent().add_child(c)
	c.global_position = c.from
	Game.sfx("jump", -6.0, 0.6)
	Game.sfx("scrape", -10.0, 1.6)
	return c


## 双插第二根落在哪（世界 x）：主角背后 DOUBLE_GAP；那边是墙、坑、闸门或者够不着，就不扔（返回 NAN）
func _second_x(p: Player) -> float:
	if p == null:
		return NAN
	var px := clampf(p.global_position.x, global_position.x - PLUG_REACH, global_position.x + PLUG_REACH)
	var away := 1.0 if px >= global_position.x else -1.0
	var x := px + away * DOUBLE_GAP
	if absf(x - global_position.x) > PLUG_REACH + DOUBLE_GAP:
		return NAN
	var space := get_world_2d().direct_space_state
	var y := p.global_position.y
	# 主角和落点之间不能隔墙（闸门也在第 1 层）
	var wall := PhysicsRayQueryParameters2D.create(Vector2(px, y - 8.0), Vector2(x + away * CordPlug.HALF, y - 8.0), 1)
	if not space.intersect_ray(wall).is_empty():
		return NAN
	# 落点那段地面要和主角脚下差不多高
	var down := PhysicsRayQueryParameters2D.create(Vector2(x, y - 20.0), Vector2(x, y + 12.0), 1)
	var hit := space.intersect_ray(down)
	if hit.is_empty() or absf((hit.position as Vector2).y - y) > 6.0:
		return NAN
	return roundf(x)


## 拔线：两根线头落地变成甲虫
func _summon() -> void:
	var path := BEETLE_PATH if ResourceLoader.exists(BEETLE_PATH) else CRAWLER_PATH
	var script := load(path) as GDScript
	Game.sfx("crack", -6.0, 1.4)
	Game.sfx("buzz", -10.0, 1.6)
	Game.add_shake(2.0)
	for i in mini(DROP_X.size(), MAX_SUMMONS - _alive_summons()):
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
	# 已经被释放的甲虫不能用 erase（类型数组会报错），整个重建
	var alive: Array[Node2D] = []
	for e in _summons:
		if is_instance_valid(e) and e.get("dead") != true:
			alive.append(e)
	_summons = alive
	return alive.size()


func _in_wall(pos: Vector2) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = pos
	q.collision_mask = 1
	return not get_world_2d().direct_space_state.intersect_point(q, 1).is_empty()


func is_targetable() -> bool:
	return super.is_targetable() and _dying < 0.0


func _on_hurt(_damage: float, full: bool) -> void:
	_jolt = JOLT_TIME
	if full:
		Game.sfx("clang", -14.0, 1.7, 0.1)


## 血打空了：先演一段断电（DIE_TIME），然后才真的死（EliteBase 的大爆炸、顿帧、扣情绪都在那一刻）。
## 断电期间不动、不伤人、不再挨打，插着的线马上断电收回。
func _die() -> void:
	if _dying >= 0.0:
		return
	_dying = 0.0
	velocity.x = 0.0
	_contact.set_deferred("monitoring", false)
	if is_instance_valid(_cord):
		_cord.cut()
	if is_instance_valid(_cord2):
		_cord2.cut()
	Game.sfx("buzz", -6.0, 0.6)
	Game.sfx("tvoff", -8.0, 0.8)
	Game.hitstop(0.08)
	Game.add_shake(2.0)


func _tick_dying(delta: float) -> void:
	_dying += delta
	velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	# 灯全亮（帧 3）和全灭（帧 0）来回闪，越闪越慢，最后一段灭着
	var k := _dying / DIE_TIME
	var period := lerpf(0.04, 0.14, k)
	set_frame(3 if k < 0.75 and int(_dying / period) % 2 == 0 else 0)
	# 插孔板上一直往外冒蓝火花
	if randf() < 0.3:
		Game.sparks(get_parent(), global_position + Vector2(randf_range(-12.0, 12.0), randf_range(-40.0, -14.0)),
				Color(0.6, 0.85, 1.0), 2, 40.0)
	if _dying >= DIE_TIME:
		EliteFx.scrap_burst(get_parent(), Rect2(global_position + body_rect.position, body_rect.size), 20)
		Game.sparks(get_parent(), cord_root(), Color(0.6, 0.85, 1.0), 12, 90.0)
		super._die()


## 死了：线断电、召出来的甲虫跟着灭
func _on_die() -> void:
	if is_instance_valid(_cord):
		_cord.cut()
	if is_instance_valid(_cord2):
		_cord2.cut()
	# 召出来的甲虫跟着断电：冒一下火花、碎掉就没了。不走甲虫自己的死法（烧熔丝再炸、地面带电），
	# 不然打赢的那一刻主角脚边还会被电一下（夜间打磨）。遭遇战不数它们，直接拿掉不影响清场
	for e in _summons:
		if is_instance_valid(e) and e.get("dead") != true:
			Game.sparks(get_parent(), e.global_position + Vector2(0, -4), Color(0.6, 0.85, 1.0), 6, 50.0)
			EliteFx.scrap_burst(get_parent(), Rect2(e.global_position + Vector2(-6, -8), Vector2(12, 8)), 4)
			e.queue_free()
	_summons.clear()


func _on_respawn() -> void:
	_dying = -1.0
	_enter(State.MOVE)



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

## 插线预警：主角脚下那一段地面（和通电那段一样宽）两头各一个蓝色的方括号，跟着主角走，一闪一闪越来越快。
## 线到点就甩到这里，提前 0.7 秒知道"会插到我脚下"
func _draw_aim() -> void:
	if state != State.PLUG_WARN or _dying >= 0.0:
		return
	var p := _aim_target if is_instance_valid(_aim_target) else nearest_player()
	if p == null or not p.is_on_floor():
		return
	var k := _state_t / PLUG_WARN
	if int(_state_t / lerpf(0.12, 0.05, k)) % 2 == 1:
		return
	var c := Color(0.6, 0.85, 1.0, 0.5 + 0.4 * k)
	var x := roundf(clampf(p.global_position.x, global_position.x - PLUG_REACH, global_position.x + PLUG_REACH))
	var y := roundf(p.global_position.y)
	_draw_bracket(x, y, c)
	# 双插：主角背后那一段也先标出来
	if _double:
		var x2 := _second_x(p)
		if not is_nan(x2):
			_draw_bracket(x2, y, c)


func _draw_bracket(x: float, y: float, c: Color) -> void:
	var half := CordPlug.HALF
	for side in [-1.0, 1.0]:
		var ex: float = x + side * half
		_aim.draw_rect(Rect2(ex, y - 4.0, 1, 4), c)
		_aim.draw_rect(Rect2(ex if side < 0.0 else ex - 2.0, y - 4.0, 3, 1), c)
	_aim.draw_rect(Rect2(x - half, y - 1.0, half * 2.0 + 1.0, 1), Color(c, c.a * 0.35))


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
	# 挨打：往背离主角的方向顿 1 格
	_jolt = maxf(_jolt - get_physics_process_delta_time(), 0.0)
	if _jolt > 0.0:
		_sprite.position.x -= dir
	if _aim:
		_aim.queue_redraw()
	if _dying >= 0.0:
		# 断电：越抖越厉害，开头闪白；红灯一跳一跳地灭
		var k := _dying / DIE_TIME
		var amp := 1.0 + 2.0 * k
		_sprite.position.x += amp if int(_dying * 34.0) % 2 == 0 else -amp
		_sprite.modulate = Color.WHITE.lerp(Color(2.0, 2.0, 2.0), clampf(1.0 - k * 4.0, 0.0, 1.0))
		_led.visible = _led.visible and k < 0.6 and int(_dying * (8.0 + 16.0 * k)) % 2 == 0


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
