class_name Gramophone
extends EliteBase
## 留声机（第二关精英怪，从策划案第九节原设计 B3 留声机来）：大喇叭朝前，转盘上放着唱片，唱臂会动。
## 红灯在喇叭的喉咙深处。和主角保持一段距离（远了靠近、近了后退；26 以内的台阶走得下去、蹦得上去），
## 横扫和声波轮着放，都先冒红色"!"：
## - 唱针横扫：唱臂伸长，唱针贴着地面从脚下一直划到场子那头（撞墙、到坑边或划满 320 停），要跳过去。
##   唱针头宽 6、高 8，碰到伤 12；伸出去的唱臂不伤人。上下 26 以内的台阶都跟着走。两种轮着来：
##   - 单程：划到头抬起来收回去。
##   - 来回：划到头停 0.45 秒（唱头一闪一闪发红），再贴地划回来，要再跳一次。
## - 声波：喇叭放出一串往外扩的声波（空心圆弧，只往前半边放，越扩越淡），碰到伤 8、情绪 +5。
##   躲到留声机背后都安全；从里往外穿过一圈不算碰到（只有圈扩过来撞到你才算），所以可以跟在一圈后面走。
##   四种弹幕型，第一次一定是"慢转"，之后抽签不放回：
##   - 慢转（33 转）：3 圈，慢、间隔长。每圈在同一处有缺口，地上淡绿点标出来（离主角 50 像素），走过去站着。
##   - 加速：6 圈，唱片越转越快，圈一圈比一圈快、间隔越来越短。缺口在同一处。
##   - 高低：4 圈，低圈和高圈交替。低圈只贴着地面一截（亮橙色，要跳过去），高圈地面往上 20 像素是空的
##     （站在地上别跳）。跳低圈、蹲高圈，像跟着节拍跳。
##   - 跟拍：3 圈，缺口一圈比一圈远 40 像素，先站近处，再跟着往外走两步。
##   声波预警时唱片转速不一样：慢转慢慢转、加速和跟拍转得飞快、高低一亮一暗地闪。
## 贴图 gramophone.png（草图/精英怪/l2_switch_gramophone.py 导出），6 帧：
## 0、1 走（唱片转）；2 横扫预警（唱臂抬起）；3 横扫（唱臂甩到前面朝下）；4 声波预警（喇叭口亮、唱片转出拖影）；
## 5 声波（喇叭口张大）。

enum State { MOVE, SWEEP_WARN, SWEEP, WAVE_WARN, WAVE, RECOVER }

const MOVE_SPEED := 13.0
const WALK_FRAME_TIME := 0.25
## 主角比这个近就后退，比 FAR 远就靠近
const NEAR := 50.0
const FAR := 110.0
const MOVE_TIME := Vector2(2.4, 3.0)
const ATTACK_RANGE := 240.0
## 走路时往前看多远、最多蹦上多高的台阶（座位一排 22）、最多往下走多深（落在座位边角上时，
## 前面可能一下子低两排、44 像素；再深就当是坑）、蹦上台阶的起跳速度（重力 900，蹦 30 像素高）
const AHEAD := 24.0
const STEP := 26.0
const DROP := 60.0
const HOP_SPEED := 235.0
## 搭在台阶边角上时往下滑的速度
const LEDGE_SLIDE := 40.0
const SWEEP_WARN := 0.8
## 横扫最长等多久（来回那种 5 秒内也收回来了）
const SWEEP_MAX := 6.0
const WAVE_WARN := 0.9
const RECOVER_TIME := 0.9
## 帧内像素（朝左）：横扫时的臂尖、喇叭口中心
const ARM_TIP := Vector2i(10, 30)
const MOUTH := Vector2i(6, 11)
## 声波缺口离主角站的地方多远、地面上那一段的一半宽
const ZONE_STEP := 50.0
const ZONE_HALF := 20.0
## 跟拍：缺口一圈比一圈远多少
const MARCH_STEP := 40.0
## 声波的弹幕型：每圈什么时候放（从放第一圈算）、多快、哪种圈（SoundRing.GAP / LOW / HIGH）、缺口怎么摆
const WAVES := {
	"slow": {"times": [0.0, 1.0, 2.0], "speeds": [50.0, 50.0, 50.0], "kinds": [0, 0, 0], "zones": "fixed"},
	"speedup": {"times": [0.0, 0.9, 1.6, 2.15, 2.6, 3.0], "speeds": [50.0, 58.0, 66.0, 74.0, 82.0, 90.0],
			"kinds": [0, 0, 0, 0, 0, 0], "zones": "fixed"},
	"hilo": {"times": [0.0, 0.95, 1.9, 2.85], "speeds": [60.0, 60.0, 60.0, 60.0], "kinds": [1, 2, 1, 2], "zones": "none"},
	"groove": {"times": [0.0, 0.9, 1.8], "speeds": [60.0, 60.0, 60.0], "kinds": [0, 0, 0], "zones": "march"},
}
## 不吃光照的那层叠图多不透明（暗处也看得出身子的样子）
const FILL_ALPHA := 0.4

var state := State.MOVE
var _fill: Sprite2D
var _state_t := 0.0
var _move_time := 1.4
var _next := 0
var _attack_dir := -1
var _needle: Needle = null
var _sweeps := 0
## 这次声波的弹幕型、已经放了几圈
var _wave := "slow"
var _wave_bag: Array[String] = []
var _waves_played := 0
var _rings_done := 0
## 每圈的缺口落在地面上的位置（离喇叭口的前向距离）
var _zones: Array[float] = []
## 声波缺口、高低圈按哪层地面算（主角当时站的地面）
var _zone_floor := 0.0


func _setup() -> void:
	elite_name = "GRAMOPHONE"
	intro_title = "NOW PLAYING"
	intro_frame = 5
	texture_path = "res://art/enemies/gramophone.png"
	hframes = 6
	frame_size = Vector2i(54, 46)
	# 身子连喇叭一起算（光球打喇叭也算），碰到伤人只算柜子和腿
	body_rect = Rect2(-21, -45, 42, 45)
	contact_rect = Rect2(-13, -35, 28, 35)
	led_pixel = Vector2i(7, 11)
	max_hp = 1150.0
	contact_damage = 10.0


## 遭遇战把怪的脚底放在天花板下 14 像素（encounter.gd），第二关的机房有实心天花板，
## 这只 45 高，一出生身子就卡在天花板里，被物理挤到天花板上面去了（看得见血条、看不见怪）。
## 出生时先往上探一下：头顶有天花板就把自己往下挪到天花板下面。
func _after_ready() -> void:
	var feet := global_position
	var top := feet.y + body_rect.position.y - 2.0
	var q := PhysicsRayQueryParameters2D.create(Vector2(feet.x, feet.y - 1.0), Vector2(feet.x, top), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		global_position.y = (hit.position as Vector2).y - body_rect.position.y + 1.0
	# 第二关机房很暗，背后又是一整面插孔板，深灰的身子融进墙里只剩红灯（作者 10-17 找不到它）。
	# 叠一层不吃光照的同一张图，半透明，暗处也看得出形状；亮处基本看不出差别
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
	_state_t += delta
	match state:
		State.MOVE:
			_move(delta)
			set_frame(int(_time / WALK_FRAME_TIME) % 2)
			var p := nearest_player(ATTACK_RANGE)
			if _state_t >= _move_time and is_on_floor() and p \
					and absf(p.global_position.y - global_position.y) < 80.0:
				_start_attack(p)
		State.SWEEP_WARN:
			_brake(delta)
			set_frame(2)
			if _state_t >= SWEEP_WARN:
				_sweep()
				_enter(State.SWEEP)
		State.SWEEP:
			_brake(delta)
			set_frame(3)
			if not is_instance_valid(_needle) or _state_t >= SWEEP_MAX:
				_enter(State.RECOVER)
		State.WAVE_WARN:
			_brake(delta)
			set_frame(_warn_frame())
			if _state_t >= WAVE_WARN:
				_rings_done = 0
				_enter(State.WAVE)
		State.WAVE:
			_brake(delta)
			var w: Dictionary = WAVES[_wave]
			var times: Array = w["times"]
			while _rings_done < times.size() and _state_t >= times[_rings_done]:
				_ring(_rings_done)
				_rings_done += 1
			var last: float = times[_rings_done - 1] if _rings_done > 0 else 0.0
			set_frame(5 if _state_t - last < 0.3 else 4)
			if _rings_done >= times.size() and _state_t >= times[-1] + 0.5:
				_enter(State.RECOVER)
		State.RECOVER:
			_brake(delta)
			set_frame(int(_time / WALK_FRAME_TIME) % 2)
			if _state_t >= RECOVER_TIME:
				_enter(State.MOVE)
	_slide_off_ledge()
	move_and_slide()


func _enter(s: State) -> void:
	state = s
	_state_t = 0.0
	if s == State.MOVE:
		_move_time = randf_range(MOVE_TIME.x, MOVE_TIME.y)


func _start_attack(p: Player) -> void:
	_face(p)
	_attack_dir = dir
	if _next == 0:
		warn(SWEEP_WARN)
		_enter(State.SWEEP_WARN)
		Game.sfx("tvclick", -6.0, 0.7)
	else:
		_wave = _pick_wave()
		warn(WAVE_WARN)
		_enter(State.WAVE_WARN)
		_plan_zones(p)
		# 唱片转起来的声音：慢转低沉，加速、跟拍尖，高低一高一低
		match _wave:
			"slow":
				Game.sfx("charge", -10.0, 0.6)
			"hilo":
				Game.sfx("charge", -10.0, 0.8)
				Game.sfx("dial", -12.0, 1.3)
			_:
				Game.sfx("charge", -10.0, 1.3)
	_next = 1 - _next


## 第一次一定是慢转（教你看缺口），之后四种抽签不放回
func _pick_wave() -> String:
	if _wave_bag.is_empty():
		_wave_bag = ["slow", "speedup", "hilo", "groove"]
		_wave_bag.shuffle()
		if _waves_played == 0:
			_wave_bag.erase("slow")
			_wave_bag.append("slow")
	_waves_played += 1
	return _wave_bag.pop_back()


## 声波预警时唱片的样子：慢转 0/1 慢慢换，加速和跟拍是转出拖影的 4，高低在 4 和 0 之间闪
func _warn_frame() -> int:
	match _wave:
		"slow":
			return int(_state_t / 0.3) % 2
		"hilo":
			return 4 if int(_state_t / 0.15) % 2 == 0 else 0
		_:
			return 4


func _move(delta: float) -> void:
	var p := nearest_player()
	if p == null:
		_brake(delta)
		return
	_face(p)
	var dx := absf(p.global_position.x - global_position.x)
	var want := 0
	if dx > FAR:
		want = dir
	elif dx < NEAR:
		want = -dir                         # 面朝主角往后退
	var path := _path_ahead(want) if want != 0 else -1
	if path >= 0:
		velocity.x = want * MOVE_SPEED * speed_mult()
		# 前面是一级往上的台阶（电影院的座位一排比一排高 22）：蹦上去
		if path == 1 and is_on_floor():
			velocity.y = -HOP_SPEED
			Game.sfx("land", -12.0, 0.7)
			Game.dust(get_parent(), global_position, 3)
	else:
		_brake(delta)


func _brake(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)


func _face(p: Player) -> void:
	if absf(p.global_position.x - global_position.x) > 2.0:
		dir = 1 if p.global_position.x > global_position.x else -1


## 身子 42 宽，座位一排只有 40 宽：会搭在一排座位的边角上、大半个身子悬在下一排上面，看着像卡在椅子上
## （作者 10-17 在乐池里看到的）。脚底正中间下面没地、只有一边踩着时，往没踩着的那边滑下去；
## 正在往踩着的那边走（刚蹦上一级）就不管。
func _slide_off_ledge() -> void:
	if not is_on_floor():
		return
	var space := get_world_2d().direct_space_state
	var y := global_position.y
	var mid := space.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(global_position.x, y - 2.0), Vector2(global_position.x, y + 3.0), 1))
	if not mid.is_empty():
		return
	for side in [-1, 1]:
		var x: float = global_position.x + side * (body_rect.size.x / 2.0 - 0.5)
		var under := space.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(x, y - 2.0), Vector2(x, y + 3.0), 1))
		if not under.is_empty():
			# 正往踩着的那边走（刚蹦上台阶）就让它走上去，不然一推一拉卡在边上
			if velocity.x * side <= 0.0:
				velocity.x = -side * LEDGE_SLIDE
			return


## 往 side 那边走一步行不行：0 平地或往下 DROP 以内，1 往上 STEP 以内的台阶（要蹦一下），-1 墙或坑。
## 第二关乐池（E4）整片都是 20~22 高的台阶（两排座位、乐池、舞台），只能走平地的话落在哪排座位上就卡在哪。
func _path_ahead(side: int) -> int:
	var space := get_world_2d().direct_space_state
	var x0 := global_position.x
	var x1 := x0 + side * AHEAD
	var y := global_position.y
	var low := space.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(x0, y - 4.0), Vector2(x1, y - 4.0), 1))
	if low.is_empty():
		var down := space.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(x1, y - 2.0), Vector2(x1, y + DROP), 1))
		return 0 if not down.is_empty() else -1
	var high := space.intersect_ray(PhysicsRayQueryParameters2D.create(
			Vector2(x0, y - STEP - 2.0), Vector2(x1, y - STEP - 2.0), 1))
	return 1 if high.is_empty() else -1


## 帧里的像素（原图朝左）→ 相对脚底中间的位置，朝右时镜像
func _frame_pos(px: Vector2i) -> Vector2:
	var col := px.x if dir < 0 else frame_size.x - 1 - px.x
	return Vector2(col - frame_size.x / 2, px.y - frame_size.y)


func arm_tip() -> Vector2:
	return global_position.round() + _frame_pos(ARM_TIP)


func mouth() -> Vector2:
	return global_position.round() + _frame_pos(MOUTH)


## 唱针横扫：从前脚外面贴着地面划出去；单程、来回轮着来
func _sweep() -> void:
	var n := Needle.new()
	n.elite = self
	n.dir = _attack_dir
	n.returns = _sweeps % 2 == 1
	_sweeps += 1
	get_parent().add_child(n)
	n.global_position = Vector2(roundf(global_position.x + _attack_dir * 18.0), global_position.y)
	_needle = n
	Game.sfx("scrape", -4.0, 0.8)
	Game.add_shake(1.5)


## 声波缺口摆在哪：
## - fixed：离主角现在站的地方 ZONE_STEP（优先往远处，远处没地就往近处），每圈同一处
## - march：第一圈在近处（离喇叭口 34~60），之后每圈往外 MARCH_STEP；外面没地就退回 fixed
## - none：高低圈不用缺口
func _plan_zones(p: Player) -> void:
	var m := mouth()
	var a := clampf((p.global_position.x - m.x) * _attack_dir, 30.0, 140.0)
	var floor_y := p.global_position.y if p.is_on_floor() else global_position.y
	_zone_floor = floor_y
	var w: Dictionary = WAVES[_wave]
	var n: int = (w["times"] as Array).size()
	_zones.clear()
	if w["zones"] == "march":
		var z0 := clampf(a, 34.0, 60.0)
		var ok := true
		for i in n:
			if not _floor_near(m.x + _attack_dir * (z0 + i * MARCH_STEP), floor_y):
				ok = false
		if ok:
			for i in n:
				_zones.append(z0 + i * MARCH_STEP)
			return
	var b := a + ZONE_STEP if a + ZONE_STEP <= 150.0 else a - ZONE_STEP
	if not _floor_near(m.x + _attack_dir * b, floor_y):
		b = a - ZONE_STEP if b > a else a + ZONE_STEP
		if b < 24.0 or not _floor_near(m.x + _attack_dir * b, floor_y):
			b = a
	for i in n:
		_zones.append(b)


func _floor_near(x: float, y: float) -> bool:
	var q := PhysicsRayQueryParameters2D.create(Vector2(x, y - 4.0), Vector2(x, y + 4.0), 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _ring(i: int) -> void:
	var w: Dictionary = WAVES[_wave]
	var r := SoundRing.new()
	r.dir = _attack_dir
	r.center = mouth()
	r.floor_y = _zone_floor
	r.speed = w["speeds"][i]
	r.kind = w["kinds"][i]
	var z: float = _zones[i] if i < _zones.size() else 80.0
	r.zone = Vector2(z - ZONE_HALF, z + ZONE_HALF)
	get_parent().add_child(r)
	# 圈越快音越高；低圈闷、高圈尖
	var pitch := 0.45 + r.speed / 100.0
	if r.kind == SoundRing.LOW:
		pitch = 0.6
	elif r.kind == SoundRing.HIGH:
		pitch = 1.2
	Game.sfx("bell", -8.0, pitch)
	Game.sfx("voice", -12.0, pitch * 0.8)
	Game.add_shake(1.5)


func _on_die() -> void:
	if is_instance_valid(_needle):
		_needle.lift()


func _on_respawn() -> void:
	_enter(State.MOVE)



## 叠图跟着贴图走（放在 _process 里：出场动画会在 _update_visual 之后再改帧和位置）
func _process(_delta: float) -> void:
	if _fill == null:
		return
	_fill.frame = _sprite.frame
	_fill.flip_h = _sprite.flip_h
	_fill.offset = _sprite.offset
	_fill.position = _sprite.position
	_fill.modulate = Color(_sprite.modulate.lerp(Color(3, 3, 3), _flash), FILL_ALPHA)

## 预警时琴身抖、一闪一闪发红（照钢琴）
func _update_visual() -> void:
	super._update_visual()
	var warn_t := -1.0
	match state:
		State.SWEEP_WARN:
			warn_t = _state_t / SWEEP_WARN
		State.WAVE_WARN:
			warn_t = _state_t / WAVE_WARN
	if warn_t >= 0.0:
		var amp := 1.0 if warn_t < 0.6 else 2.0
		_sprite.position.x += amp if int(_state_t * 30.0) % 2 == 0 else -amp
		var pulse := 0.5 + 0.5 * sin(_state_t * (14.0 + 20.0 * warn_t))
		_sprite.modulate = Color.WHITE.lerp(Color(1.8, 0.75, 0.6), pulse * (0.4 + 0.6 * warn_t))
	else:
		_sprite.modulate = Color.WHITE


## 伸长的唱臂 + 贴地划过去的唱针。原点 = 唱针尖（地面上）。
## 往前划：跟着地面走（往上、往下 STEP 以内的台阶跟过去），撞墙、到坑边、划满 REACH 就停。
## returns 为假：停下就抬起来收回去。为真：停 PAUSE 秒（唱头闪红），再贴地划回来，划回到起点再收。
## 只有唱针头伤人；抬起来收回去的时候不伤人。
class Needle:
	extends Node2D

	const SPEED := 150.0
	const BACK_SPEED := 130.0
	const STEP := 26.0
	const RETRACT_SPEED := 420.0
	const REACH := 320.0
	const PAUSE := 0.45
	const DAMAGE := 12.0
	## 唱针头的判定：宽 6、贴地往上 8（跳得过去）
	const HEAD := Rect2(-3, -8, 6, 8)
	const ARM := Color8(0x8a, 0x84, 0x7c)
	const ARM_DARK := Color8(0x5c, 0x57, 0x52)
	const GROOVE := Color(1.0, 0.75, 0.5)
	const WARN := Color(1.0, 0.25, 0.2)

	var elite: Gramophone
	## 划出去的方向（划回来时也不变，用来画唱臂）
	var dir := -1
	var returns := false
	var _move_dir := 0
	var _travel := 0.0
	var _back := false
	var _pause := -1.0
	var _returning := false
	var _start_x := 0.0
	var _far_x := 0.0
	var _t := 0.0
	var _spark_t := 0.0

	func _ready() -> void:
		z_index = 4
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded
		_move_dir = dir

	func lift() -> void:
		if not _back:
			_back = true
			Game.sfx("tvclick", -8.0, 1.2)

	func _physics_process(delta: float) -> void:
		# 起点在第一帧取：_ready 时留声机还没把位置摆好
		if _t == 0.0:
			_start_x = global_position.x
		_t += delta
		if not is_instance_valid(elite) or elite.dead:
			queue_free()
			return
		if _back:
			var home := elite.arm_tip()
			global_position.x = move_toward(global_position.x, home.x, RETRACT_SPEED * delta)
			global_position.y = move_toward(global_position.y, home.y, RETRACT_SPEED * 0.5 * delta)
			if absf(global_position.x - home.x) < 2.0:
				queue_free()
				return
			queue_redraw()
			return
		if _pause >= 0.0:
			# 划到头停一下，唱头闪红，然后掉头
			_pause -= delta
			if _pause < 0.0:
				_returning = true
				_move_dir = -dir
				_travel = 0.0
				Game.sfx("scrape", -4.0, 1.0)
			_hit()
			queue_redraw()
			return
		var step := (BACK_SPEED if _returning else SPEED) * delta
		var x := global_position.x
		var y := global_position.y
		var nx := x + _move_dir * step
		var space := elite.get_world_2d().direct_space_state
		# 往上、往下 STEP 以内的台阶都跟过去（来回划时，去程走下去的台阶回程要走得上来；
		# 乐池的座位一排 22 高，原来只跟 12 的话唱针一出去就停了）
		var wall := PhysicsRayQueryParameters2D.create(Vector2(x, y - STEP - 1.0), Vector2(nx + _move_dir * 3.0, y - STEP - 1.0), 1)
		var fy := _floor_y(nx, y - STEP - 1.0, STEP * 2.0 + 1.0)
		var home_reached := _returning and (nx - _start_x) * dir <= 0.0
		if not space.intersect_ray(wall).is_empty() or is_nan(fy) or _travel >= REACH or home_reached:
			Game.sparks(get_parent(), global_position + Vector2(0, -2), GROOVE, 6, 60.0, Vector2.UP)
			if returns and not _returning:
				_pause = PAUSE
				_far_x = global_position.x
				Game.sfx("tvclick", -6.0, 0.6)
			else:
				lift()
			queue_redraw()
			return
		global_position = Vector2(nx, fy)
		_travel += step
		_spark_t -= delta
		if _spark_t <= 0.0:
			_spark_t = 0.07
			Game.sparks(get_parent(), global_position + Vector2(-_move_dir * 2.0, -1), GROOVE, 1, 40.0,
					Vector2(-_move_dir, -1).normalized())
		_hit()
		queue_redraw()

	func _floor_y(x: float, from_y: float, depth: float) -> float:
		var q := PhysicsRayQueryParameters2D.create(Vector2(x, from_y), Vector2(x, from_y + depth), 1)
		var hit := get_world_2d().direct_space_state.intersect_ray(q)
		# 射线从上往下打，朝上的面都算地（台阶边上的陡坡也跟过去）
		if hit.is_empty() or (hit.normal as Vector2).y > -0.05:
			return NAN
		return (hit.position as Vector2).y

	func _hit() -> void:
		var r := Rect2(global_position + HEAD.position, HEAD.size)
		for n in get_tree().get_nodes_in_group("player"):
			var p := n as Player
			if p and r.intersects(Rect2(p.global_position + Vector2(-3, -16), Vector2(6, 16))):
				p.hurt(global_position + Vector2(-_move_dir * 6.0, 0), DAMAGE * EnemyBase.damage_mult())
		for n in get_tree().get_nodes_in_group("crystal"):
			var c := n as Crystal
			if c and c.carrier == null and r.intersects(Rect2(c.global_position + Vector2(-2.5, -8), Vector2(5, 8))):
				c.take_hit(global_position + Vector2(-_move_dir * 6.0, 0), DAMAGE * EnemyBase.damage_mult())

	func _draw() -> void:
		draw_set_transform(global_position.round() - global_position)
		var me := global_position.round()
		var tip := elite.arm_tip() - me
		var lift_y := -10.0 if _back else 0.0
		# 划过的地方留一道发烫的唱片纹
		if not _back:
			var far := _far_x if _returning or _pause >= 0.0 else me.x
			var x0 := minf(_start_x, far) - me.x
			var x1 := maxf(_start_x, far) - me.x
			draw_rect(Rect2(x0, -1, x1 - x0, 1), Color(GROOVE, 0.35))
		# 唱臂：从臂尖斜着落到离地 5 像素，再贴着地面伸到唱针头
		var knee := Vector2(tip.x + dir * 6.0, -5.0 + lift_y)
		var head := Vector2(0, -6.0 + lift_y)
		_line(tip, knee, ARM)
		_line(knee, head, ARM)
		_line(knee + Vector2(0, 1), head + Vector2(0, 1), ARM_DARK)
		# 唱头：一小块，底下一根针尖着地；停在头上要划回来时一闪一闪发红
		var col := ARM
		if _pause >= 0.0 and int(_pause / 0.06) % 2 == 0:
			col = WARN
		draw_rect(Rect2(-2, -8 + lift_y, 5, 3), col)
		draw_rect(Rect2(-2, -8 + lift_y, 5, 1), Color8(0xa8, 0xa2, 0x98) if col == ARM else Color(1, 0.7, 0.6))
		draw_rect(Rect2(0, -5 + lift_y, 1, 5), Color(1.0, 0.92, 0.8))
		if _pause >= 0.0:
			# 掉头前：唱头上方一个往回指的小箭头
			var ax := -_move_dir * 1.0
			for k in 3:
				draw_rect(Rect2(ax * (k + 2), -13 - k, 1, 1 + 2 * k), Color(WARN, 0.9))
		elif not _back and int(_t * 20.0) % 2 == 0:
			draw_rect(Rect2(-1, -1, 3, 1), Color(GROOVE, 0.9))

	func _line(a: Vector2, b: Vector2, col: Color) -> void:
		var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
		for i in n + 1:
			var t := float(i) / maxf(n, 1)
			draw_rect(Rect2(a.lerp(b, t).round(), Vector2.ONE), col)


## 一圈往外扩的声波（空心圆弧，只往前半边），越扩越淡。碰到伤 8、情绪 +5，每圈每人最多打一下。
## 只在圈从里往外扩、撞到你的那一下算碰到；你从圈里面往外穿过去不算。
## 三种圈：
## - GAP：缺口对着地面上的一段（zone，离喇叭口的前向距离），那段地面标淡绿点，圈快到时变亮、闪。
## - LOW：只有贴着地面那一截（离地 LOW_H 以内），亮橙色、粗一点，要跳过去。
## - HIGH：地面往上 HIGH_GAP 以内是空的，站在地上就钻过去了，跳起来反而会撞到。
class SoundRing:
	extends Node2D

	const GAP := 0
	const LOW := 1
	const HIGH := 2
	const MAX_R := 160.0
	## 扩到这么大以后不再伤人（已经很淡了）
	const HARM_R := 140.0
	## 往前张开的半角（弧度）：从正上方稍过一点到正下方稍过一点
	const ARC := 1.83
	const LOW_H := 12.0
	const HIGH_GAP := 20.0
	const DAMAGE := 8.0
	const EMOTION := 5.0
	const COLOR := Color(1.0, 0.86, 0.62)
	const LOW_COLOR := Color(1.0, 0.6, 0.3)
	const SAFE := Color(0.6, 1.0, 0.6)
	## 主角身上取三个点（离脚底的高度）
	const SAMPLES := [2.0, 8.0, 14.0]

	var dir := -1
	var center := Vector2.ZERO
	var floor_y := 0.0
	var speed := 60.0
	var kind := GAP
	## 缺口落在地面上的那一段：离喇叭口的前向距离（近, 远）
	var zone := Vector2(60, 100)
	var _r := 3.0
	var _gap := Vector2.ZERO
	var _hit := {}
	## 每个采样点上一帧离圈多远（正 = 在圈外）
	var _prev := {}

	func _ready() -> void:
		z_index = 8
		top_level = true
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded
		global_position = Vector2.ZERO
		# 缺口的角度范围：主角站在 zone 里时，从头顶（远端）到脚底（近端）都要在缺口里
		var dy_feet := floor_y - center.y
		var dy_head := floor_y - 16.0 - center.y
		_gap = Vector2(atan2(dy_head, maxf(zone.y, 4.0)), atan2(dy_feet, maxf(zone.x, 4.0)))
		if _gap.x > _gap.y:
			_gap = Vector2(_gap.y, _gap.x)

	## 世界坐标 → 前向角（正前方 0，往下为正）
	func _angle(pt: Vector2) -> float:
		var v := pt - center
		return atan2(v.y, v.x * dir)

	## 圈上这一点有没有东西（画和判定用同一个规则）
	func _covers(pt: Vector2) -> bool:
		var a := _angle(pt)
		if absf(a) > ARC:
			return false
		match kind:
			LOW:
				return pt.y >= floor_y - LOW_H and pt.y <= floor_y + 1.0
			HIGH:
				return pt.y <= floor_y - HIGH_GAP
		return not (a >= _gap.x and a <= _gap.y)

	func _physics_process(delta: float) -> void:
		_r += speed * delta
		if _r >= MAX_R:
			queue_free()
			return
		for n in get_tree().get_nodes_in_group("player"):
			var p := n as Player
			if p == null:
				continue
			var id := p.get_instance_id()
			for i in SAMPLES.size():
				var pt := p.global_position + Vector2(0, -SAMPLES[i])
				var s := pt.distance_to(center) - _r
				var key := id * 4 + i
				var was: float = _prev.get(key, s)
				_prev[key] = s
				if _hit.has(id) or _r >= HARM_R:
					continue
				# 圈从里面扩过来撞到这一点（上一帧在圈外，这一帧到了圈上或圈里）
				if was > 0.0 and s <= 0.0 and _covers(pt):
					_hit[id] = true
					if p.hurt(center, DAMAGE * EnemyBase.damage_mult()):
						Run.add_emotion(EMOTION)
		queue_redraw()

	func _draw() -> void:
		var alpha := clampf(1.0 - _r / MAX_R, 0.0, 1.0)
		# 缺口落在地面上的那一段：圈一放出来就淡淡标着（跟拍能看到后面几圈的位置），
		# 圈离它 70 像素以内变亮，快到时闪；圈过去了就不标
		if kind == GAP:
			var reach := zone.x - (_r - 10.0)
			if reach > -20.0:
				var blink := reach < 30.0 and int(_r / 4.0) % 2 == 0
				var col := Color(SAFE, 0.85 if blink else (0.5 if reach < 70.0 else 0.22))
				for d in range(int(zone.x), int(zone.y) + 1, 4):
					draw_rect(Rect2(roundf(center.x + dir * d), floor_y - 1, 2, 1), col)
		# 圈：一格一个点，同一个像素只画一次；低圈粗一点、亮一点
		var main := COLOR if kind != LOW else LOW_COLOR
		var layers := [[0.0, 0.85], [2.0, 0.3]] if kind != LOW else [[0.0, 1.0], [1.0, 0.8], [2.0, 0.4]]
		var drawn := {}
		var steps := int(ceilf(2.0 * ARC * _r * 1.4)) + 8
		for layer in layers:
			var rr: float = _r - layer[0]
			if rr < 2.0:
				continue
			var c := Color(main, layer[1] * alpha)
			for i in steps + 1:
				var a := -ARC + 2.0 * ARC * i / steps
				var p := (center + Vector2(cos(a) * dir, sin(a)) * rr).round()
				if drawn.has(p) or not _covers(p):
					continue
				drawn[p] = true
				draw_rect(Rect2(p, Vector2.ONE), c)
