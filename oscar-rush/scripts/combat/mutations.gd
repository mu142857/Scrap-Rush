class_name Mutations
extends RefCounted
## 商店的 4 个变异（策划案第十节，10-17 作者定"做出来"）。身上同时只有一个（Upgrades.mutation）。
## Player 每出一招（闪光灯放出光球、铆钉枪打出一颗、蒸汽锤炸一圈）调 on_attack；怪死的时候调 on_kill。
## 三把武器都能配，射得快的铆钉枪单独降了频率，免得刷屏、过强（系数写在策划案第十节）。
##
## 怒火 rage：伤害 ×(1 + 情绪/100)，平静 ×1、失控 ×2。子弹往红色偏，越生气越红；出招时冒红火星。
## 磁带回声 echo：出招 0.3 秒后，在人现在的位置按原来的方向再出一次，伤害 50%，颜色是磁带的青紫色。
##   铆钉枪每 3 颗才回一次。回声自己不再触发回声和从闪。
## 从闪 slave：马灯放在地上时，你每出一招，灯朝它 150 像素内最近的怪补一发小光球（伤害 40，暖黄色）。
##   提着灯时不触发。铆钉枪每 4 颗补一发，且两发至少隔 0.3 秒。
## 发电机 dynamo：每杀 10 只怪，马灯 +5（走 Run.heal_crystal，有回血特效），灯上冒一圈电火花。
##   左上角马灯血条下面有 10 格进度（EmotionFx 画）。

const RAGE_MAX := 2.0
const RAGE_COLOR := Color8(255, 64, 44)

const ECHO_DELAY := 0.3
const ECHO_DAMAGE := 0.5
const ECHO_RIVET_EVERY := 3
const ECHO_COLOR := Color8(150, 210, 255)

const SLAVE_RANGE := 150.0
const SLAVE_DAMAGE := 40.0
const SLAVE_RIVET_EVERY := 4
const SLAVE_MIN_GAP := 0.3
const SLAVE_COLOR := Color8(255, 211, 138)

const DYNAMO_KILLS := 10
const DYNAMO_HEAL := 5.0
const DYNAMO_COLOR := Color8(170, 230, 255)

static var dynamo_kills := 0
static var _rivet_echo_n := 0
static var _rivet_slave_n := 0
static var _slave_last := -10.0


static func rage_mult() -> float:
	return 1.0 + clampf(Run.emotion / 100.0, 0.0, 1.0) * (RAGE_MAX - 1.0)


## Player 出招以后调：shot 是刚 add_child 的 Orb / Rivet / SteamBlast
static func on_attack(p: Player, shot: Node2D) -> void:
	if p == null or shot == null or shot.get_meta("mutation_copy", false):
		return
	match Upgrades.mutation:
		"rage":
			_rage(shot)
		"echo":
			_echo(p, shot)
		"slave":
			_slave(p, shot)


## 怪死的时候调（EnemyBase、Crawler）
static func on_kill(_enemy: Node) -> void:
	if Upgrades.mutation != "dynamo":
		return
	dynamo_kills += 1
	if dynamo_kills < DYNAMO_KILLS:
		return
	dynamo_kills = 0
	Run.heal_crystal(DYNAMO_HEAL)
	var tree := (_enemy as Node).get_tree() if _enemy else null
	if tree == null:
		return
	for c in tree.get_nodes_in_group("crystal"):
		var n := c as Node2D
		Game.sparks(n.get_parent(), n.global_position + Vector2(0, -5), DYNAMO_COLOR, 12, 90.0)
	Game.sfx("buzz", -8.0, 1.4)


static func _damage_mul(shot: Node, k: float) -> void:
	if "damage_mult" in shot:
		shot.set("damage_mult", float(shot.get("damage_mult")) * k)
	elif "damage" in shot:
		shot.set("damage", float(shot.get("damage")) * k)


static func _rage(shot: Node2D) -> void:
	var m := rage_mult()
	_damage_mul(shot, m)
	if "color" in shot:
		shot.set("color", (shot.get("color") as Color).lerp(RAGE_COLOR, clampf((m - 1.0) * 1.2, 0.0, 1.0)))
	if m >= 1.2:
		Game.sparks(shot.get_parent(), shot.global_position, RAGE_COLOR, 2 + int((m - 1.0) * 6.0), 70.0)


static func _echo(p: Player, shot: Node2D) -> void:
	var kind := _kind(shot)
	if kind == "rivet":
		_rivet_echo_n += 1
		if _rivet_echo_n % ECHO_RIVET_EVERY != 0:
			return
	var dir := Vector2(p.facing, 0)
	if "velocity" in shot and (shot.get("velocity") as Vector2).length() > 1.0:
		dir = (shot.get("velocity") as Vector2).normalized()
	var full: bool = shot.get("full") if "full" in shot else true
	var dmg: float = float(shot.get("damage")) if "damage" in shot else 0.0
	var parent := shot.get_parent()
	var tree := p.get_tree()
	tree.create_timer(ECHO_DELAY, false).timeout.connect(func():
		if not is_instance_valid(p) or not is_instance_valid(parent):
			return
		var copy: Node2D = null
		match kind:
			"orb":
				var o := Orb.new()
				o.setup(p, p.global_position + Vector2(p.facing * 5, -11), dir, 1.0 if full else 0.6, null, ECHO_COLOR)
				o.damage = dmg * ECHO_DAMAGE
				copy = o
			"rivet":
				var r := Rivet.new()
				r.setup(p.global_position + Vector2(p.facing * 6, -10), dir, ECHO_COLOR)
				r.damage = dmg * ECHO_DAMAGE
				copy = r
			"blast":
				var b := SteamBlast.new()
				b.color = ECHO_COLOR
				b.position = p.global_position + Vector2(0, -10)
				if "damage_mult" in b:
					b.set("damage_mult", ECHO_DAMAGE)
				copy = b
		if copy == null:
			return
		copy.set_meta("mutation_copy", true)
		parent.add_child(copy)
		# 磁带回声：出招处闪两颗青紫色的点，声音低一点、轻一点
		Game.sparks(parent, copy.global_position, ECHO_COLOR, 4, 50.0)
		Game.sfx("shoot", -14.0, 0.75, 0.05))


static func _slave(p: Player, shot: Node2D) -> void:
	var lamp: Crystal = null
	for c in p.get_tree().get_nodes_in_group("crystal"):
		var cr := c as Crystal
		if cr and cr.carrier == null:
			lamp = cr
	if lamp == null:
		return
	if _kind(shot) == "rivet":
		_rivet_slave_n += 1
		if _rivet_slave_n % SLAVE_RIVET_EVERY != 0:
			return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _slave_last < SLAVE_MIN_GAP:
		return
	var from := lamp.global_position + Vector2(0, -6)
	var best: Node2D = null
	var bd := SLAVE_RANGE
	for e in p.get_tree().get_nodes_in_group("enemy"):
		var n := e as Node2D
		if n == null or (n.has_method("is_targetable") and not n.call("is_targetable")):
			continue
		var at: Vector2 = n.call("aim_point") if n.has_method("aim_point") else n.global_position
		var d := from.distance_to(at)
		if d < bd:
			bd = d
			best = n
	if best == null:
		return
	_slave_last = now
	var aim: Vector2 = best.call("aim_point") if best.has_method("aim_point") else best.global_position
	var o := Orb.new()
	# 0.99：不算蓄满（没有顿帧、不穿透），几乎直飞
	o.setup(p, from, (aim - from).normalized(), 0.99, null, SLAVE_COLOR)
	o.damage = SLAVE_DAMAGE
	o.set_meta("mutation_copy", true)
	lamp.get_parent().add_child(o)
	# 马灯跟着闪一下：灯上冒一圈暖色火花
	Game.sparks(lamp.get_parent(), from, SLAVE_COLOR, 6, 60.0)
	Game.sfx("shoot", -12.0, 1.6, 0.05)


static func _kind(shot: Node) -> String:
	if shot is Orb:
		return "orb"
	if shot is Rivet:
		return "rivet"
	if shot is SteamBlast:
		return "blast"
	return ""
