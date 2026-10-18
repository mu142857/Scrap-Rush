extends WeaponHandler
## 显像管激光 CRT LASER（10-18 作者："激光枪，伤害高，可无限穿透，只是攻击速度慢"；第二版作者："激光跟第一个武器闪光灯太像了"）。
## 老电视的显像管电子枪改的。和闪光灯（松手打出一颗会追的暖白光球）完全反过来：
## - 充能是显像管开机：管口先一个亮点，再拉成一道横线，红绿蓝三色错开（0.7 秒，快充每级 -0.08，最快 0.45）。
## - 充满不用松手，自动开火；按着就一直扫，光束最多持续 0.5 秒（松手提前收），之后冷却 0.4 秒。
## - 光束瞬间到墙、无限穿透，每 0.075 秒结算一次（线上每只怪各吃一下）；会慢慢转向目标（扫过去），按住"下"往下压。
## - 光束经过的 Boss 子弹一路烧掉。收束时像关电视：缩成一条线、再缩成一个点。
## 方向：画面里有 Boss 先瞄 Boss，没有就瞄最近的怪；上下最多偏 80°；挑方向时试几个候选，选第一个真打得到的（见 _aim）。

const BEAM := preload("res://scripts/combat/weapons/laser_beam.gd")
const CHARGE_TIME := 0.7
const CHARGE_UPGRADE := 0.08
const COOLDOWN := 0.4
## 每一下（每 0.075 秒）的伤害：一道光束扫满 0.5 秒约 6~7 下 ≈ 170
const TICK_DAMAGE := 26.0
const RANGE := 260.0
## 上下最多偏多少度（Boss2 总机吊在半空，要能打到斜上方）
const MAX_TILT := 80.0
## 目标和枪口高度差在这么多像素以内就打水平（光束横穿一排）
const FLAT_DY := 8.0
## 开火时按住"下"：光束往下压多少度
const PRESS_DOWN := 30.0

var _charge := 0.0
var _full := false
var _cd := 0.0
var _hum: AudioStreamPlayer
var _dir := Vector2.RIGHT
var _len := RANGE
var _t := 0.0
## 正在扫的光束（null = 没在开火）
var _beam: Node2D = null


func charge_time() -> float:
	return maxf(CHARGE_TIME - CHARGE_UPGRADE * p.quick_level(), 0.45)


func attack(delta: float) -> void:
	_t += delta
	_cd -= delta
	var held: bool = p.attack_held()
	# 开火中：每帧重新瞄（光束自己按转速追过去），松手或时间到就收。
	# 光束开始收束就算打完（光束节点还要留 2 秒画墙上的焦痕，不能等它删掉才进冷却：那样一轮要 3.2 秒）
	if is_instance_valid(_beam) and not _beam.call("is_ending"):
		_pick_target()
		_aim()
		var want := _dir
		if p.action_held("down"):
			want = want.rotated(deg_to_rad(PRESS_DOWN) * float(int(p.facing)))
		_beam.set("want_dir", want)
		if not held:
			_beam.call("stop")
		p.set("charging", true)
		p.set("charge", 1.0)
		return
	if _beam != null:
		# 刚收完：进冷却
		_beam = null
		_cd = COOLDOWN
		p.set("charging", false)
		p.set("charge", 0.0)
	if held and _cd <= 0.0:
		if _charge <= 0.0:
			_start()
		_charge = minf(_charge + delta / charge_time(), 1.0)
		_pick_target()
		_aim()
		p.set("charging", true)
		p.set("charge", _charge)
		if _charge >= 1.0:
			_full = true
			_stop_charge()
			_fire(1.0, Color.WHITE, false)
		return
	if _charge > 0.0:
		# 没充满就松手：显像管"啪"地灭掉，不开火
		Game.sfx("tvoff", -16.0, 1.6)
		_stop_charge()
	p.clear_target()


func _start() -> void:
	_full = false
	_hum = Game.sfx("tvon", -12.0, 0.7 / charge_time())


func _stop_charge() -> void:
	_charge = 0.0
	_full = false
	if is_instance_valid(_hum):
		_hum.stop()
	_hum = null
	p.set("charging", false)
	p.set("charge", 0.0)


## 瞄谁：画面里有 Boss 就先瞄 Boss（光束无限穿透，路上的小怪顺带打到；只瞄最近的会老打 Boss2 召出来的插头、甲虫，
## 光束射进墙角，站桩 150 秒打不死 Boss2）。没有 Boss 就和别的武器一样瞄最近的怪
func _pick_target() -> void:
	var from: Vector2 = p.muzzle(7.0, -11.0)
	for e in p.get_tree().get_nodes_in_group("enemy"):
		var n := e as Node2D
		if n == null or not n.has_method("start_fight") or n.get("dead") == true:
			continue
		if n.has_method("is_targetable") and not n.call("is_targetable"):
			continue
		if from.distance_to(p.target_point(n)) <= RANGE:
			p.set("_target", n)
			return
	p.find_target()


## 定方向：几个候选方向挨个试，用和真正出手同一套判断（laser_beam.gd 的 would_hit）挑第一个打得到的：
## ① 目标和枪口差不多一样高（FLAT_DY 以内）先试水平——光束横穿一排；
## ② 朝瞄准点（浮在半空的精英、吊着的 Boss2 拨号盘）；③ 水平（路灯这种又高又细的：灯头够不着就打灯杆）；④ 朝身体中心
func _aim() -> void:
	var from: Vector2 = p.muzzle(7.0, -11.0)
	var t = p.get("_target")
	_dir = Vector2(int(p.facing), 0)
	_len = BEAM.wall_distance(p, from, _dir, RANGE)
	if not (t is Node2D and is_instance_valid(t)):
		return
	var target := t as Node2D
	var ap: Vector2 = p.target_point(target)
	if signf(ap.x - from.x) != 0.0:
		p.set("facing", int(signf(ap.x - from.x)))
	var side := float(int(p.facing))
	var cands: Array[Vector2] = []
	if absf(ap.y - from.y) < FLAT_DY:
		cands.append(Vector2(side, 0))
	cands.append(_tilted(ap - from, side))
	cands.append(Vector2(side, 0))
	cands.append(_tilted(target.global_position + Vector2(0, -6) - from, side))
	for d in cands:
		var length: float = BEAM.wall_distance(p, from, d, RANGE)
		if BEAM.would_hit(p, from, d, length, target):
			_dir = d
			_len = length
			return
	# 都打不到（被墙挡着）：照瞄准点方向，至少看得出在瞄谁
	_dir = cands[0]
	_len = BEAM.wall_distance(p, from, _dir, RANGE)


## 把方向限制在上下 MAX_TILT 度以内，朝 side 那边
func _tilted(v: Vector2, side: float) -> Vector2:
	var ang := clampf(rad_to_deg(atan2(v.y, absf(v.x))), -MAX_TILT, MAX_TILT)
	return Vector2(cos(deg_to_rad(ang)) * side, sin(deg_to_rad(ang)))


## 开火。mult / col：变异回声再射时的伤害倍率和颜色；copy = 回声射出来的（不跟手、不震屏）
func _fire(mult: float, col: Color, copy: bool) -> void:
	if not is_instance_valid(p) or not p.is_inside_tree():
		return
	_pick_target()
	_aim()
	var b: Node2D = BEAM.new()
	b.call("setup", p, _dir, TICK_DAMAGE * mult, col, not copy)
	if copy:
		b.set_meta("mutation_copy", true)
	# 怒火在进场景之前乘（光束节点放在原点画全局坐标，走通用入口的话怒火的红火星会冒在地图左上角）
	if not copy and Upgrades.mutation == "rage":
		b.set("damage", float(b.get("damage")) * Mutations.rage_mult())
	p.get_parent().add_child(b)
	if copy:
		Game.sfx("laser_fire", -14.0, 1.3, 0.05)
		return
	_beam = b
	Game.sfx("laser_ready", -10.0, 0.8)
	Game.sfx("laser_fire", -4.0, 1.0, 0.04)
	Game.add_shake(2.5)
	p.recoil(Vector2(-_dir.x * 50.0, 0.0))
	p.pop(0.3, 0.4)
	if Upgrades.mutation != "rage":
		Mutations.on_weapon_fire(p, id, [], func(m: float, ecol: Color) -> void: _fire(m, ecol, true))


func cancel() -> void:
	_charge = 0.0
	_full = false
	if is_instance_valid(_hum):
		_hum.stop()
	_hum = null
	if is_instance_valid(_beam):
		_beam.call("stop")
	super()


func glow() -> float:
	return _charge * 0.4


func move_mult() -> float:
	return 0.45 if is_instance_valid(_beam) else 0.7


## 充能 = 显像管开机：先是管口一个亮点一闪一闪（前 35%），再横着拉成一道线、红绿蓝三色上下错开一格（35%~100%），
## 线上隔一格暗一格（扫描线）。快满时前面一条很淡的绿色扫描虚线指出光束会去哪儿
func draw(c: CanvasItem) -> void:
	if _charge <= 0.0:
		return
	var m := Vector2(int(p.facing) * 7, -11)
	var red := Color(1.0, 0.25, 0.35)
	var green := Color(0.35, 1.0, 0.5)
	var blue := Color(0.3, 0.55, 1.0)
	if _charge < 0.35:
		if int(_t * 20.0) % 2 == 0:
			c.draw_rect(Rect2(m.round(), Vector2.ONE), Color.WHITE)
		return
	var k := (_charge - 0.35) / 0.65
	var half := int(round(lerpf(1.0, 6.0, k)))
	var normal := Vector2(-_dir.y, _dir.x)
	for i in range(-half, half + 1):
		var q := (m + _dir * i).round()
		var dim := 0.55 if (i + int(_t * 30.0)) % 2 == 0 else 1.0
		c.draw_rect(Rect2(q, Vector2.ONE), Color(1, 1, 1, dim))
		if k > 0.3:
			c.draw_rect(Rect2((q + normal).round(), Vector2.ONE), Color(red, 0.8 * dim))
			c.draw_rect(Rect2((q - normal).round(), Vector2.ONE), Color(blue, 0.8 * dim))
	if k > 0.6:
		var i := 10
		while i < int(_len):
			if (i + int(_t * 40.0)) % 6 == 0:
				c.draw_rect(Rect2((m + _dir * i).round(), Vector2.ONE), Color(green, 0.35))
			i += 1
