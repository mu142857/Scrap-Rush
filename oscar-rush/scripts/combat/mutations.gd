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
	proc_frame = Engine.get_physics_frames()
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
	proc_frame = Engine.get_physics_frames()
	var aim: Vector2 = best.call("aim_point") if best.has_method("aim_point") else best.global_position
	var o: Node2D = (load(ORB_PATH) as GDScript).new()
	# 0.99：不算蓄满（没有顿帧、不穿透），几乎直飞
	o.call("setup", p, from, (aim - from).normalized(), 0.99, null, SLAVE_COLOR)
	var dmg := SLAVE_DAMAGE
	if rivet:
		dmg = SLAVE_RIVET_DAMAGE
	elif _kind(shot) == "blast":
		dmg = SLAVE_HAMMER_DAMAGE
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
