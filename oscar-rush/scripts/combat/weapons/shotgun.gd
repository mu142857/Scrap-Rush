extends WeaponHandler
## 废铁霰弹枪 SCRAP SHOTGUN（10-18 作者："霰弹枪……一下喷出一个特别帅，而且还有一点点后坐力，肯定很爽"）。
## 排气管焊在手摇泵上，打出去的是一把螺母碎铁。按一下喷一扇 7 颗，按住自动连喷。
## 独特特性：后坐力就是位移。在地上往后推一小步；在空中后坐力很大（按住 下 + 攻击 = 朝脚下喷，人往上弹一下），
## 每次离地最多弹 2 次。贴脸打小怪会把它整个轰飞。
## 打击感：扇形枪口火光 3 帧、一团灰烟、红色大弹壳往后抛"叮"；一发里同一只怪中几颗，顿帧就按颗数叠（shotgun_pellet.gd）。
## 第二版（作者："霰弹枪有点弱，且不说打击感不足，这个射程太短了吧"）：射程拉到半屏、远了伤害慢慢衰减；
## 开火一帧定格、震屏更重、人往后推得更明显、火焰大一圈；泵动更脆、开火多一层低音"嘭"。

const PELLET := preload("res://scripts/combat/weapons/shotgun_pellet.gd")
const CASING := preload("res://scripts/combat/casing.gd")
## 两发之间（秒）；"快充"每级 -0.05，最快 0.4
const INTERVAL := 0.55
const INTERVAL_UPGRADE := 0.05
const PELLETS := 7
## 扇面半角（度）
const SPREAD := 7.0
const PELLET_DAMAGE := 11.0
## 弹丸速度（每颗在这两个数之间随机；图鉴 codex_weapons.gd 读这两个常量）
const SPEED_MIN := 400.0
const SPEED_MAX := 460.0
## 地上的后坐力（像素/秒，往后）
const GROUND_KICK := 120.0
## 空中的后坐力：往反方向弹的速度；每次离地最多弹几次
const AIR_KICK := 200.0
const AIR_KICKS := 2

var _cd := 0.0
var _air_left := AIR_KICKS
var _muzzle := 0.0
var _muzzle_dir := Vector2.RIGHT
var _pump_t := 0.0
var _shot_n := 0


func attack(delta: float) -> void:
	_cd -= delta
	_muzzle = maxf(_muzzle - delta / 0.05, 0.0)
	if p.is_on_floor():
		_air_left = AIR_KICKS
	if _pump_t > 0.0:
		_pump_t -= delta
		if _pump_t <= 0.0:
			Game.sfx("shotgun_pump", -12.0, 1.0, 0.05)
	var held: bool = p.attack_held()
	if held:
		p.find_target()
	else:
		p.clear_target()
	if held and _cd <= 0.0:
		_cd = maxf(INTERVAL - INTERVAL_UPGRADE * p.quick_level(), 0.4)
		_fire(1.0, Color.WHITE, false)


## 喷一发。mult / col：变异回声再喷一次时的伤害倍率和颜色；copy = 回声打出来的（不后坐、不抛弹壳）
func _fire(mult: float, col: Color, copy: bool) -> void:
	if not is_instance_valid(p) or not p.is_inside_tree():
		return
	var from: Vector2 = p.muzzle(7.0, -10.0)
	var dir: Vector2 = p.aim_dir(from)
	var air: bool = not p.is_on_floor()
	# 空中按住"下"：朝脚下喷（往上弹）
	if air and p.action_held("down"):
		dir = Vector2.DOWN
		from = p.global_position + Vector2(0, -4)
	var shots: Array = []
	var volley := {}
	for i in PELLETS:
		var a := lerpf(-SPREAD, SPREAD, float(i) / (PELLETS - 1)) + randf_range(-2.0, 2.0)
		var b: Node2D = PELLET.new()
		b.call("setup", from, dir.rotated(deg_to_rad(a)) * randf_range(SPEED_MIN, SPEED_MAX), PELLET_DAMAGE * mult, col, volley, p)
		if copy:
			b.set_meta("mutation_copy", true)
		p.get_parent().add_child(b)
		shots.append(b)
	if copy:
		Game.sfx("shotgun_blast", -14.0, 1.2, 0.05)
		return
	_shot_n += 1
	_muzzle = 1.0
	_muzzle_dir = dir
	_pump_t = 0.22
	Game.sfx("shotgun_blast", -5.0, 1.0, 0.06)
	Game.sfx("shotgun_thump", -3.0, 1.0, 0.05)
	Game.add_shake(3.6)
	p.pop(0.45, 0.9)
	# 开火那一下定格一帧（多颗打中时的顿帧会接在后面）
	if Engine.time_scale > 0.0:
		Game.hitstop(0.025)
	# 后坐力：地上往后推一小步；空中往反方向弹（每次离地最多 2 次）
	if air and _air_left > 0:
		_air_left -= 1
		var v: Vector2 = p.velocity
		if dir.y > 0.5:
			v.y = minf(v.y, 0.0) - AIR_KICK
		else:
			v += -dir * AIR_KICK
			v.y = minf(v.y, -40.0)
		p.velocity = v
	else:
		p.recoil(Vector2(-dir.x * GROUND_KICK, 0.0))
	# 一团灰烟往前喷，一颗红色大弹壳往后上方抛
	Game.sparks(p.get_parent(), from + dir * 4.0, Color(0.62, 0.6, 0.62), 8, 70.0, dir)
	Game.sparks(p.get_parent(), from + dir * 6.0, Color(1.0, 0.75, 0.3), 6, 160.0, dir)
	var c: Node2D = CASING.new()
	c.position = p.global_position + Vector2(-int(p.facing) * 2, -10)
	c.set("velocity", Vector2(-int(p.facing) * randf_range(40.0, 70.0), -randf_range(90.0, 130.0)))
	c.set("ground_y", p.global_position.y - 1.0)
	c.set("brass", Color8(190, 52, 40))
	c.set("dark", Color8(214, 160, 70))
	c.set("big", true)
	c.set("ding_always", true)
	p.get_parent().add_child(c)
	Mutations.on_weapon_fire(p, id, shots, func(m: float, ecol: Color) -> void: _fire(m, ecol, true))


func cancel() -> void:
	super()
	_pump_t = 0.0


## 枪口火光：一整扇火（沿射击方向 ±18°）：第 1 帧最长（14 像素）、第 2 帧收短、第 3 帧只剩白芯和几颗火星。
## 一格一格的像素，近处白、中间暖黄、外沿橙
func draw(c: CanvasItem) -> void:
	if _muzzle <= 0.0:
		return
	var m := Vector2(int(p.facing) * 7, -10)
	if _muzzle_dir.y > 0.5:
		m = Vector2(0, -4)
	var hot := Color(1.0, 0.97, 0.85)
	var warm := Color(1.0, 0.78, 0.35)
	var edge := Color(1.0, 0.5, 0.2)
	var stage := 0 if _muzzle > 0.66 else (1 if _muzzle > 0.33 else 2)
	var reach: int = [20, 13, 6][stage]
	c.draw_rect(Rect2((m - Vector2(3, 3)).round(), Vector2(7, 7)) if stage == 0 else Rect2((m - Vector2(2, 2)).round(), Vector2(5, 5)), Color.WHITE)
	for i in range(2, reach):
		var half := int(i * 0.36) + 1
		for j in range(-half, half + 1):
			var q := (m + _muzzle_dir * i + _muzzle_dir.orthogonal() * j).round()
			var outer := absi(j) >= half - 0 and half > 1
			var col := hot if i < reach * 0.35 else (edge if outer or i > reach * 0.8 else warm)
			# 外沿稀疏一点，像一团喷出去的火，不是实心三角
			if outer and (i + j) % 2 == 0:
				continue
			c.draw_rect(Rect2(q, Vector2.ONE), col)
