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
##   提着灯时不触发。铆钉枪每 4 颗补一发、两发至少隔 0.6 秒、每发 25；蒸汽锤每发 55。间隔按游戏时间算。
##   武器第四版后实测 10 秒单体伤害：闪光灯 1000→1400、铆钉枪 1313→1638、蒸汽锤 1120→约 1480（见夜间报告第 31 节）。
## 发电机 dynamo：每杀 10 只怪，马灯 +5（走 Run.heal_crystal，有回血特效），灯上冒一圈电火花。
##   左上角马灯血条下面有 10 格进度（EmotionFx 画）。
## 注意：这个文件不直接写 Player / Orb / Rivet / SteamBlast / Crystal 这些类名（player.gd 会调这里，
## 直接引用会形成循环依赖，Godot 解析时卡死）。子弹在运行时 load()，种类按脚本路径判断。

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
## 铆钉枪射得快：从闪补的光球伤害低一些、间隔长一些（不然 +100% 以上）
const SLAVE_RIVET_DAMAGE := 25.0
const SLAVE_RIVET_GAP := 0.6
## 蒸汽锤每下补的光球伤害。10-18 武器第三版时锤子 5 秒 3 下，定 55；之后锤子出招变快（10 秒 8 下），
## 55 偏高（+39%），调回 45（约 +32%），和另外两把差不多
const SLAVE_HAMMER_DAMAGE := 45.0
const SLAVE_COLOR := Color8(255, 211, 138)

const DYNAMO_KILLS := 10
const DYNAMO_HEAL := 5.0
const DYNAMO_COLOR := Color8(170, 230, 255)

static var dynamo_kills := 0

# ---- 10-18 新变异（作者定的 4 个，设计见 夜间打磨/商店换武器和变异_方案.md）----
## 保险丝熔断：每第 FUSE_EVERY 次出招伤害 ×FUSE_MULT（子弹变橙），紧接着第一次打中怪的地方炸一小圈
const FUSE_EVERY := 5
const FUSE_MULT := 3.0
const FUSE_WINDOW := 0.8
const FUSE_RADIUS := 22.0
const FUSE_BLAST := 40.0
const FUSE_COLOR := Color8(255, 150, 60)
static var _fuse_n := 0
static var _fuse_until := -1.0
## 真空管预热：连续打中同一个目标，每次 +VALVE_STEP，最多 VALVE_MAX 档；打别的目标（隔 VALVE_GRACE 秒以上）清零。
## 同一下的多颗弹丸（霰弹枪）只算一次；电钳跳到别的怪不会马上清零（有 VALVE_GRACE 的宽限）
const VALVE_STEP := 0.05
const VALVE_MAX := 10
const VALVE_GRACE := 0.25
const VALVE_ONCE := 0.1
const VALVE_COLOR := Color8(255, 170, 90)
static var _valve_target := 0
static var _valve_streak := 0
static var _valve_last := -10.0
## 显像管残影：怪死的地方留一个冷蓝的残影，BURNIN_DELAY 秒后炸开，伤害是它最后挨那一下的 BURNIN_RATIO（至少 BURNIN_MIN）。
## 残影炸死的怪不再留残影，免得一路连锁
const BURNIN_DELAY := 1.0
const BURNIN_RADIUS := 26.0
const BURNIN_RATIO := 0.5
const BURNIN_MIN := 20.0
const BURNIN_COLOR := Color8(120, 150, 190)
static var _burnin_busy := false
## 倒带磁带：马灯碎的时候不重来，人、马灯倒回 REWIND_SECONDS 秒前的位置，马灯血量回到那时候（至少 REWIND_MIN_HP）。
## 每关一次（进关 reset_level 重置），用过 HUD 图标变灰
const REWIND_SECONDS := 5.0
const REWIND_STEP := 0.25
const REWIND_MIN_HP := 0.35
const REWIND_INVULN := 1.5
const REWIND_COLOR := Color8(200, 160, 255)
static var rewind_used := false
## 刚倒带：EmotionFx 看到大于 0 就放一下"倒带"的画面（读完自己清零）
static var rewind_fx := 0.0
static var _snaps: Array = []
static var _snap_t := 0.0

## 商店信息卡"★ 和你的 XX 很配"：每个变异特别配哪几把枪（倒带磁带对谁都一样，不标）
const COMBOS := {
	"rage": ["hammer", "shotgun", "laser"],
	"slave": ["flash", "laser", "tongs"],
	"echo": ["laser", "hammer", "record"],
	"dynamo": ["tongs", "shotgun", "rivet"],
	"fuse": ["hammer", "laser", "shotgun"],
	"valve": ["rivet", "tongs", "record"],
	"burnin": ["laser", "shotgun", "hammer"],
}
## 变异最近一次真的起作用（怒火加成、回声出招、从闪补射、发电机回血）是哪个物理帧：
## HUD 上的变异图标看到它变了就跳一下（EmotionFx 读）
static var proc_frame := -1
const ORB_PATH := "res://scripts/combat/orb.gd"
const RIVET_PATH := "res://scripts/combat/rivet.gd"
const BLAST_PATH := "res://scripts/combat/steam_blast.gd"
static var _rivet_echo_n := 0
static var _rivet_slave_n := 0
static var _slave_last := -10.0


static func rage_mult() -> float:
	return 1.0 + clampf(Run.emotion / 100.0, 0.0, 1.0) * (RAGE_MAX - 1.0)


## Player 出招以后调：shot 是刚 add_child 的 Orb / Rivet / SteamBlast
static func on_attack(p: Node2D, shot: Node2D) -> void:
	if p == null or shot == null or shot.get_meta("mutation_copy", false):
		return
	_pre_fire([shot])
	match Upgrades.mutation:
		"rage":
			_rage(shot)
		"echo":
			_echo(p, shot)
		"slave":
			_slave(p, shot)


## 新武器（WeaponRegistry 里有 handler 的）每打出一发调这个，变异就都生效（说明见 weapon_handler.gd）。
## shots：这一发打出来的子弹节点（怒火给它们乘伤害）；refire：Callable(damage_mult, color)，回声 0.3 秒后调它再打一发。
## 回声、从闪每几发触发一次，读登记表的 echo_every / slave_every；从闪的伤害读 slave_damage
static func on_weapon_fire(p: Node2D, weapon_id: String, shots: Array, refire: Callable) -> void:
	if p == null:
		return
	for s in shots:
		if s is Node and (s as Node).get_meta("mutation_copy", false):
			return
	_pre_fire(shots)
	match Upgrades.mutation:
		"rage":
			var first := true
			for s in shots:
				if s is Node2D:
					if first:
						_rage(s)
						first = false
					else:
						_damage_mul(s, rage_mult())
		"echo":
			_fire_n[weapon_id + ":echo"] = int(_fire_n.get(weapon_id + ":echo", 0)) + 1
			if int(_fire_n[weapon_id + ":echo"]) % maxi(int(WeaponRegistry.value(weapon_id, "echo_every", 1)), 1) != 0:
				return
			if not refire.is_valid():
				return
			p.get_tree().create_timer(ECHO_DELAY, false).timeout.connect(func():
				if not is_instance_valid(p):
					return
				proc_frame = Engine.get_physics_frames()
				refire.call(ECHO_DAMAGE, ECHO_COLOR)
				Game.sparks(p.get_parent(), p.global_position + Vector2(0, -10), ECHO_COLOR, 4, 50.0)
				Game.sfx("shoot", -14.0, 0.75, 0.05))
		"slave":
			_fire_n[weapon_id + ":slave"] = int(_fire_n.get(weapon_id + ":slave", 0)) + 1
			if int(_fire_n[weapon_id + ":slave"]) % maxi(int(WeaponRegistry.value(weapon_id, "slave_every", 1)), 1) != 0:
				return
			_slave_shot(p, float(WeaponRegistry.value(weapon_id, "slave_damage", SLAVE_DAMAGE)),
					SLAVE_RIVET_GAP if int(WeaponRegistry.value(weapon_id, "slave_every", 1)) > 1 else SLAVE_MIN_GAP)


static var _fire_n := {}


## 怪死的时候调（EnemyBase、Crawler）
static func on_kill(_enemy: Node) -> void:
	if Upgrades.mutation == "burnin":
		_burnin(_enemy)
		return
	if Upgrades.mutation != "dynamo":
		return
	dynamo_kills += 1
	if dynamo_kills < DYNAMO_KILLS:
		return
	dynamo_kills = 0
	Run.heal_crystal(DYNAMO_HEAL)
	proc_frame = Engine.get_physics_frames()
	var tree := (_enemy as Node).get_tree() if _enemy else null
	if tree == null:
		return
	for c in tree.get_nodes_in_group("crystal"):
		var n := c as Node2D
		Game.sparks(n.get_parent(), n.global_position + Vector2(0, -5), DYNAMO_COLOR, 12, 90.0)
	Game.sfx("buzz", -8.0, 1.4)


static func _now() -> float:
	return Engine.get_physics_frames() / float(Engine.physics_ticks_per_second)


## 出招前（还没打中）：保险丝熔断数次数、真空管预热按连击乘伤害
static func _pre_fire(shots: Array) -> void:
	match Upgrades.mutation:
		"fuse":
			_fuse_n += 1
			if _fuse_n % FUSE_EVERY != 0:
				return
			_fuse_until = _now() + FUSE_WINDOW
			proc_frame = Engine.get_physics_frames()
			for s in shots:
				if s is Node:
					_damage_mul(s, FUSE_MULT)
					if "color" in s:
						s.set("color", FUSE_COLOR)
			Game.sfx("clang", -8.0, 1.7, 0.05)
		"valve":
			if _valve_streak <= 0:
				return
			var k := 1.0 + VALVE_STEP * _valve_streak
			for s in shots:
				if s is Node:
					_damage_mul(s, k)


## 打中怪的时候调（HitFx.after_hit，7 把武器都走那里）
static func on_hit(body: Node, pos: Vector2) -> void:
	if body == null or not body.is_in_group("enemy"):
		return
	match Upgrades.mutation:
		"valve":
			var now := _now()
			var id := body.get_instance_id()
			if id == _valve_target:
				if now - _valve_last >= VALVE_ONCE and _valve_streak < VALVE_MAX:
					_valve_streak += 1
					proc_frame = Engine.get_physics_frames()
					if _valve_streak % 3 == 0 or _valve_streak == VALVE_MAX:
						Game.sparks(body.get_parent(), pos, VALVE_COLOR, 2 + _valve_streak / 3, 40.0)
				if now - _valve_last >= VALVE_ONCE:
					_valve_last = now
			elif now - _valve_last > VALVE_GRACE:
				_valve_target = id
				_valve_streak = 0
				_valve_last = now
		"fuse":
			if _now() > _fuse_until:
				return
			_fuse_until = -1.0
			_blast(body.get_parent(), pos, FUSE_RADIUS, FUSE_BLAST, FUSE_COLOR, body)
			Game.sfx("boom", -10.0, 1.4, 0.05)
			Game.add_shake(2.0)


## 一小圈爆炸：半径里没死的怪各挨 dmg（except 那只不算，它刚挨过）
static func _blast(parent: Node, at: Vector2, radius: float, dmg: float, col: Color, except: Node = null) -> void:
	if parent == null:
		return
	var tree := parent.get_tree()
	for e in tree.get_nodes_in_group("enemy"):
		var n := e as Node2D
		if n == null or n == except or n.get("dead") or not n.has_method("hurt"):
			continue
		var aim: Vector2 = n.call("aim_point") if n.has_method("aim_point") else n.global_position
		if aim.distance_to(at) <= radius:
			n.call("hurt", dmg, (aim - at).normalized(), false)
	Game.sparks(parent, at, col, 12, 90.0)
	var ring := BlastRing.new()
	ring.position = at.round()
	ring.radius = radius
	ring.color = col
	parent.add_child(ring)


static func _burnin(enemy: Node) -> void:
	if _burnin_busy or not (enemy is Node2D) or not enemy.is_inside_tree():
		return
	var e := enemy as Node2D
	var parent := e.get_parent()
	if parent == null:
		return
	var g := BurnIn.new()
	g.position = e.global_position
	g.dmg = maxf(float(e.get_meta("last_hit_dmg", 40.0)) * BURNIN_RATIO, BURNIN_MIN)
	g.aim = e.call("aim_point") if e.has_method("aim_point") else e.global_position
	var src = e.get("_sprite")
	if src is Sprite2D:
		var sp := Sprite2D.new()
		var ss := src as Sprite2D
		sp.texture = ss.texture
		sp.hframes = ss.hframes
		sp.vframes = ss.vframes
		sp.frame = ss.frame
		sp.flip_h = ss.flip_h
		sp.centered = ss.centered
		sp.offset = ss.offset
		sp.position = ss.position
		sp.region_enabled = ss.region_enabled
		sp.region_rect = ss.region_rect
		g.ghost = sp
	parent.add_child.call_deferred(g)


## EmotionFx 每帧调：带着倒带磁带时，每 REWIND_STEP 秒记一次人、马灯的位置和马灯血量，只留最近 REWIND_SECONDS 秒
static func tick(tree: SceneTree, delta: float) -> void:
	if Upgrades.mutation != "rewind" or rewind_used or tree == null:
		return
	_snap_t -= delta
	if _snap_t > 0.0:
		return
	_snap_t = REWIND_STEP
	if Run.crystal_hp <= 0.0:
		return
	var players: Array = []
	for n in tree.get_nodes_in_group("player"):
		players.append((n as Node2D).global_position)
	var snap := {"players": players, "hp": Run.crystal_hp}
	for c in tree.get_nodes_in_group("crystal"):
		snap["crystal"] = (c as Node2D).global_position
	_snaps.append(snap)
	while _snaps.size() > int(REWIND_SECONDS / REWIND_STEP) + 1:
		_snaps.pop_front()


## 马灯碎的时候 Run.damage_crystal 先问这里：带着倒带磁带、这一关还没用过，就倒回 5 秒前，返回 true（不碎、不重来）
static func try_rewind() -> bool:
	if Upgrades.mutation != "rewind" or rewind_used or _snaps.is_empty():
		return false
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	rewind_used = true
	var snap: Dictionary = _snaps[0]
	_snaps.clear()
	var pp: Array = snap["players"]
	var ps := tree.get_nodes_in_group("player")
	for i in ps.size():
		var p := ps[i] as Node2D
		if i < pp.size():
			p.global_position = pp[i]
		if "velocity" in p:
			p.set("velocity", Vector2.ZERO)
		if p.has_method("reset_physics_interpolation"):
			p.call("reset_physics_interpolation")
		if "_invuln" in p:
			p.set("_invuln", REWIND_INVULN)
	if snap.has("crystal"):
		for c in tree.get_nodes_in_group("crystal"):
			var cn := c as Node2D
			if cn.get("carrier") == null:
				cn.global_position = snap["crystal"]
				if cn.has_method("reset_physics_interpolation"):
					cn.call("reset_physics_interpolation")
	# 5 秒前人可能还在闸门外面、灯可能还放在上一个场子里：正在打的遭遇战把人拉回来、灯飞回手上
	tree.call_group("encounter", "keep_inside")
	Run.crystal_hp = maxf(float(snap["hp"]), Run.crystal_max * REWIND_MIN_HP)
	Run.crystal_changed.emit(Run.crystal_hp, Run.crystal_max)
	proc_frame = Engine.get_physics_frames()
	rewind_fx = 1.0
	Game.sfx("tvclick", -4.0, 0.7)
	Game.sfx("static", -10.0, 0.8)
	return true


## 进一关（EmotionFx 建起来时）和新开一局时调：倒带重新可用，连击、计数清零
static func reset_level() -> void:
	rewind_used = false
	rewind_fx = 0.0
	_snaps.clear()
	_snap_t = 0.0
	_valve_target = 0
	_valve_streak = 0
	_fuse_n = 0
	_fuse_until = -1.0


## 这个变异和这把枪是不是特别配（商店信息卡的"★ 很配"）
static func combos_with(mutation: String, weapon: String) -> bool:
	return weapon in COMBOS.get(mutation, [])


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
		proc_frame = Engine.get_physics_frames()
		var at := shot.global_position
		var par: Node = shot.get_parent() if shot.get_parent() else (Engine.get_main_loop() as SceneTree).current_scene
		Game.sparks(par, at, RAGE_COLOR, 2 + int((m - 1.0) * 6.0), 70.0)


static func _echo(p: Node2D, shot: Node2D) -> void:
	var kind := _kind(shot)
	if kind == "rivet":
		_rivet_echo_n += 1
		if _rivet_echo_n % ECHO_RIVET_EVERY != 0:
			return
	var facing: int = p.get("facing")
	var dir := Vector2(facing, 0)
	if "velocity" in shot and (shot.get("velocity") as Vector2).length() > 1.0:
		dir = (shot.get("velocity") as Vector2).normalized()
	var full: bool = shot.get("full") if "full" in shot else true
	var dmg: float = float(shot.get("damage")) if "damage" in shot else 0.0
	var parent := p.get_parent()
	var tree := p.get_tree()
	tree.create_timer(ECHO_DELAY, false).timeout.connect(func():
		if not is_instance_valid(p) or not is_instance_valid(parent):
			return
		var copy: Node2D = null
		match kind:
			"orb":
				var o: Node2D = (load(ORB_PATH) as GDScript).new()
				o.call("setup", p, p.global_position + Vector2(int(p.get("facing")) * 5, -11), dir, 1.0 if full else 0.6, null, ECHO_COLOR)
				o.set("damage", dmg * ECHO_DAMAGE)
				copy = o
			"rivet":
				var r: Node2D = (load(RIVET_PATH) as GDScript).new()
				r.call("setup", p.global_position + Vector2(int(p.get("facing")) * 6, -10), dir, ECHO_COLOR)
				r.set("damage", dmg * ECHO_DAMAGE)
				copy = r
			"blast":
				var b: Node2D = (load(BLAST_PATH) as GDScript).new()
				b.set("color", ECHO_COLOR)
				b.position = p.global_position + Vector2(0, -10)
				b.set("damage_mult", ECHO_DAMAGE)
				copy = b
		if copy == null:
			return
		copy.set_meta("mutation_copy", true)
		proc_frame = Engine.get_physics_frames()
		if kind != "blast":
			_badge(copy, ECHO_COLOR, true)
		parent.add_child(copy)
		# 磁带回声：出招处闪两颗青紫色的点，声音低一点、轻一点
		Game.sparks(parent, copy.global_position, ECHO_COLOR, 4, 50.0)
		Game.sfx("shoot", -14.0, 0.75, 0.05))


static func _slave(p: Node2D, shot: Node2D) -> void:
	var lamp: Node2D = null
	for c in p.get_tree().get_nodes_in_group("crystal"):
		var cr := c as Node2D
		if cr and cr.get("carrier") == null:
			lamp = cr
	if lamp == null:
		return
	if _kind(shot) == "rivet":
		_rivet_slave_n += 1
		if _rivet_slave_n % SLAVE_RIVET_EVERY != 0:
			return
	var rivet := _kind(shot) == "rivet"
	# 按物理帧数算间隔，不用现实时间：卡顿掉帧时不会少补
	var now := Engine.get_physics_frames() / float(Engine.physics_ticks_per_second)
	if now - _slave_last < (SLAVE_RIVET_GAP if rivet else SLAVE_MIN_GAP):
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
	var dmg := SLAVE_DAMAGE
	if rivet:
		dmg = SLAVE_RIVET_DAMAGE
	elif _kind(shot) == "blast":
		dmg = SLAVE_HAMMER_DAMAGE
	_slave_fire(p, lamp, best, dmg)


## 新武器用：从闪补一发（间隔、伤害由调用的人给）
static func _slave_shot(p: Node2D, dmg: float, gap: float) -> void:
	var lamp: Node2D = null
	for c in p.get_tree().get_nodes_in_group("crystal"):
		var cr := c as Node2D
		if cr and cr.get("carrier") == null:
			lamp = cr
	if lamp == null:
		return
	var now := Engine.get_physics_frames() / float(Engine.physics_ticks_per_second)
	if now - _slave_last < gap:
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
	_slave_fire(p, lamp, best, dmg)


## 从闪：马灯朝 best 打一发光球（老武器、新武器共用）
static func _slave_fire(p: Node2D, lamp: Node2D, best: Node2D, dmg: float) -> void:
	proc_frame = Engine.get_physics_frames()
	var from := lamp.global_position + Vector2(0, -6)
	var aim: Vector2 = best.call("aim_point") if best.has_method("aim_point") else best.global_position
	var o: Node2D = (load(ORB_PATH) as GDScript).new()
	# 0.99：不算蓄满（没有顿帧、不穿透），几乎直飞
	o.call("setup", p, from, (aim - from).normalized(), 0.99, null, SLAVE_COLOR)
	o.set("damage", dmg)
	o.set_meta("mutation_copy", true)
	_badge(o, SLAVE_COLOR, false)
	lamp.get_parent().add_child(o)
	# 马灯跟着闪一下：灯亮一下、冒一圈暖色火花
	var fl := PointLight2D.new()
	fl.texture = Game.light_texture()
	fl.color = SLAVE_COLOR
	fl.energy = 2.0
	fl.texture_scale = 1.4
	fl.position = Vector2(0, -6)
	lamp.add_child(fl)
	var tw := fl.create_tween()
	tw.tween_property(fl, "energy", 0.0, 0.25)
	tw.tween_callback(fl.queue_free)
	Game.sparks(lamp.get_parent(), from, SLAVE_COLOR, 6, 60.0)
	Game.sfx("shoot", -12.0, 1.6, 0.05)


## 给变异打出来的子弹套一个像素小标记，一眼看得出不是自己打的那一发：
## 从闪 = 5×5 的暖黄实心块；回声 = 5×5 的青蓝空心框。不吃场景压暗
static func _badge(shot: Node2D, col: Color, hollow: bool) -> void:
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var rects: Array = [Rect2(-2, -2, 5, 1), Rect2(-2, 2, 5, 1), Rect2(-2, -1, 1, 3), Rect2(2, -1, 1, 3)] if hollow \
			else [Rect2(-2, -1, 5, 3), Rect2(-1, -2, 3, 5)]
	for r: Rect2 in rects:
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		poly.color = col
		poly.material = unshaded
		poly.z_index = 1
		shot.add_child(poly)


static func _kind(shot: Node) -> String:
	var sc := shot.get_script() as Script
	var path := sc.resource_path if sc else ""
	match path:
		ORB_PATH:
			return "orb"
		RIVET_PATH:
			return "rivet"
		BLAST_PATH:
			return "blast"
	return ""


## 熔断、残影炸开时的一圈像素圆环（往外扩，0.25 秒）
class BlastRing:
	extends Node2D
	var radius := 20.0
	var color := Color.WHITE
	var _t := 0.0

	func _ready() -> void:
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded
		z_index = 6

	func _process(delta: float) -> void:
		_t += delta
		if _t >= 0.25:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := _t / 0.25
		UiStyle.pixel_ring(self, Vector2.ZERO, int(4.0 + k * (radius - 4.0)), Color(color, 1.0 if k < 0.6 else 0.5))


## 显像管残影：怪死的地方留一个冷蓝的影子（复制它最后一帧），一闪一闪，到时间炸开
class BurnIn:
	extends Node2D
	var dmg := 20.0
	var aim := Vector2.ZERO
	var ghost: Sprite2D
	var _t := 0.0
	var _boomed := false

	func _ready() -> void:
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded
		z_index = 5
		if ghost:
			ghost.modulate = Color(Mutations.BURNIN_COLOR, 0.75)
			ghost.use_parent_material = true
			add_child(ghost)

	func _process(delta: float) -> void:
		_t += delta
		if ghost:
			# 越接近炸开闪得越快
			var rate := 6.0 + 18.0 * clampf(_t / Mutations.BURNIN_DELAY, 0.0, 1.0)
			ghost.visible = not _boomed and int(_t * rate) % 2 == 0
		if not _boomed and _t >= Mutations.BURNIN_DELAY:
			_boomed = true
			Mutations._burnin_busy = true
			Mutations._blast(get_parent(), aim, Mutations.BURNIN_RADIUS, dmg, Mutations.BURNIN_COLOR)
			Mutations._burnin_busy = false
			Mutations.proc_frame = Engine.get_physics_frames()
			Game.sfx("tvoff", -12.0, 1.3, 0.05)
		if _t >= Mutations.BURNIN_DELAY + 0.1:
			queue_free()
