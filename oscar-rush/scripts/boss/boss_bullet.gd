class_name BossBullet
extends Area2D
## Boss 的弹幕子弹，三种：
##   EMBER 余烬：从烟囱喷到天上，受重力落下来；往下落时碰到平台、地面才碎（平台下面能躲），
##               往上飞时穿过平台，不会一出烟囱就撞天花板
##   RIVET 铆钉：直线飞，烧红的芯、灰白的壳，后面拖一条短尾巴
##   SNOW  雪花：老电视"雪花台"一帘帘直着往下落的噪点，碰到平台、地面就散（平台能挡）
##   SCAN  扫描线：老电视"测试卡台"从屏幕中心射出去的一小段亮横线，直线飞、穿过平台
##   WAVE  声波：总机的铃声放出来的一圈圈波纹，直线飞、穿过平台（声音挡不住），一小段弧线
##   NOTE  音符：自动钢琴"琶音"弹出来的发光音符，和余烬一样抛物线落下，往下落时被平台、地面挡住
##   COAL  煤块：被高高抛出，落到人脚下那一列的地面上，接着一跳一跳往前滚。
##               只有贴近地面（离地 COAL_HURT_HEIGHT 以内）才伤人：专治站在地上的人，
##               站平台上的人由往上喷的余烬来管（2026-10-17 作者定的分工）
## 打中玩家走 Player.hurt（有无敌时间），打中放在地上的马灯走 Crystal.take_hit。
## crt = true：第三关小怪和精英怪的子弹，飞法不变，画成"电视信号"的样子，和第一关的铆钉、余烬、音符区分开
## （2026-10-17 作者嫌第三关子弹和第一关一样）。最终 Boss 的雪花、扫描线不走这个：
##   RIVET → 色散像素：红、绿、蓝三层错开的小菱形，后面拖三色的点
##   EMBER → 彩条块：竖着的黄、青、绿、品红四色条，外圈一闪一闪
##   NOTE  → 品红和青错开的音符
## gravel = true：压路机"碎石炮"的 COAL，飞法、滚法、伤害都和煤块一样，只是画成路面碎石
## （暖灰、有棱角的石块，后面拖一缕白汽），和锅炉工铲出来的煤块区分开（2026-10-17 作者嫌两个一样）

enum Kind { EMBER, RIVET, COAL, NOTE, WAVE, SNOW, SCAN }

const DAMAGE := 8.0
## 当前 Boss 的子弹伤害倍率：Boss3 开打时设 1.3、离场时设回 1.0（10-18 美术哥「锅炉比电视机难」，Boss3 加压）
static var damage_scale := 1.0
## 2026-10-17 试玩嫌子弹太快：余烬重力从 230 降到 170（落得更慢更飘），煤块落地后滚动限速
const EMBER_GRAVITY := 170.0
const COAL_GRAVITY := 450.0
## 余烬、音符往下飘的最快速度（像火星一样慢慢落，看得清落点）
const EMBER_MAX_FALL := 130.0
const COAL_HURT_HEIGHT := 20.0
## 煤块落地以后最多滚这么快（主角跑 115，大约一半）
const COAL_ROLL_SPEED := 60.0

var kind := Kind.EMBER
var velocity := Vector2.ZERO
## 煤块滚的那条地面高度
var floor_y := 164.0
## 出了这个范围就消失（竞技场）
var arena := Rect2(0, 0, 320, 180)
## 第三关"电视信号"画法（见开头）
var crt := false
## 压路机碎石的画法（见开头）
var gravel := false

var _life := 0.0
var _trail: Array[Vector2] = []
var _done := false
var _seed := 0.0
var _rolling := false


static func spawn(parent: Node, k: Kind, pos: Vector2, vel: Vector2, lit := false) -> BossBullet:
	var b := BossBullet.new()
	b.kind = k
	b.velocity = vel
	b.position = pos
	b.set_meta("lit", lit)
	parent.add_child(b)
	return b


func _ready() -> void:
	add_to_group("boss_bullet")
	collision_layer = 0
	# 铆钉碰到世界（地面、平台、墙）就碎；余烬和煤块往下落时才看世界（见 _physics_process）
	collision_mask = (1 | 2 | 8) if kind == Kind.RIVET else (2 | 8)
	if kind == Kind.WAVE or kind == Kind.SCAN:
		collision_mask = 2 | 8
	elif kind == Kind.SNOW:
		collision_mask = 1 | 2 | 8
	z_index = 8
	_seed = randf() * 10.0
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = {Kind.EMBER: 2.5, Kind.RIVET: 2.0, Kind.COAL: 3.0, Kind.NOTE: 2.5, Kind.WAVE: 2.0,
		Kind.SNOW: 2.0, Kind.SCAN: 2.0}[kind]
	shape.shape = c
	add_child(shape)
	# 所有子弹共用一个材质：每颗各 new 一个就没法合批，Boss3 雪花帘 85 颗同屏时
	# 绘制次数 124、网页版 CPU 降速 4 倍掉到 6~15 帧；共用以后绘制次数 54、52 帧（10-18 网页性能复查）
	if _unshaded == null:
		_unshaded = CanvasItemMaterial.new()
		_unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = _unshaded
	if get_meta("lit", false):
		var l := PointLight2D.new()
		l.texture = Game.light_texture()
		l.color = Color(1.0, 0.55, 0.2)
		l.energy = 0.9
		l.texture_scale = 0.7
		add_child(l)
	body_entered.connect(_on_body)


static var _unshaded: CanvasItemMaterial


func _physics_process(delta: float) -> void:
	if _done:
		return
	_life += delta
	match kind:
		Kind.EMBER:
			velocity.y = minf(velocity.y + EMBER_GRAVITY * delta, EMBER_MAX_FALL)
			velocity.x *= 1.0 - 0.15 * delta
		Kind.NOTE:
			velocity.y = minf(velocity.y + EMBER_GRAVITY * 0.85 * delta, EMBER_MAX_FALL)
		Kind.COAL:
			velocity.y += COAL_GRAVITY * delta
			if position.y >= floor_y - 3.0 and velocity.y > 0.0:
				position.y = floor_y - 3.0
				if not _rolling:
					# 第一次落地：扔出来时的水平速度太快，压到滚动速度
					velocity.x = signf(velocity.x) * minf(absf(velocity.x), COAL_ROLL_SPEED)
				_rolling = true
				# 落地以后一跳一跳往前滚，每跳一次低一点
				velocity.y = -absf(velocity.y) * 0.35 if absf(velocity.y) > 120.0 else -90.0
	# 煤块飞在空中时不伤人，落到贴近地面才开始算
	if kind == Kind.COAL:
		var low := position.y >= floor_y - COAL_HURT_HEIGHT
		set_collision_mask_value(2, low)
		set_collision_mask_value(4, low)
	# 余烬往下落的时候才会被平台、地面挡住（往上飞穿过去）
	if kind == Kind.EMBER or kind == Kind.NOTE:
		var falling := velocity.y > 0.0 and not _rolling
		set_collision_mask_value(1, falling)
	_trail.push_front(position)
	if _trail.size() > (5 if kind == Kind.RIVET else 3):
		_trail.pop_back()
	position += velocity * delta
	# 出了画面才直接删（看不见）；画面里飞够 8 秒的碎散掉，不凭空没（作者 10-18："子弹消失"）
	if not arena.grow(24.0).has_point(position):
		queue_free()
		return
	if _life > 8.0:
		fizzle()
		return
	queue_redraw()


func _on_body(body: Node) -> void:
	if _done:
		return
	var dmg := DAMAGE * EnemyBase.damage_mult() * damage_scale
	if body is Player:
		if not (body as Player).hurt(global_position, dmg):
			return  # 无敌中，子弹穿过去
	elif body is Crystal:
		(body as Crystal).take_hit(global_position, dmg)
	_pop()


## 被清场（Boss 换阶段、蒸汽锤吹散）时调这个，不要直接 queue_free：
## 直接删掉的子弹看起来像"飞到一半凭空没了"（作者 10-18 试玩 Boss2 的反馈），这里迸两颗淡火花再没
## push：被吹散的方向（蒸汽锤），火花顺着这个方向飞，看得出是被吹走的
func fizzle(push := Vector2.ZERO) -> void:
	if _done:
		return
	_done = true
	# 10-18：碎成几片自己颜色的像素往外散（被吹散的顺着吹的方向飞），比两颗淡火花看得清
	_shatter(push, 4)
	if push != Vector2.ZERO:
		Game.sparks(get_parent(), global_position, Color(0.95, 0.95, 1.0), 3, 90.0, push)
	queue_free()


func _pop() -> void:
	_done = true
	var col := Color(1.0, 0.6, 0.25) if kind != Kind.RIVET else Color(0.9, 0.85, 0.8)
	if crt:
		col = [Color(1.0, 0.3, 0.6), Color(0.3, 0.95, 1.0), Color(0.6, 1.0, 0.4)][randi() % 3]
	elif gravel:
		col = Color(0.66, 0.6, 0.52)
	Game.sparks(get_parent(), global_position, col, 3, 50.0)
	_shatter(-velocity.normalized() * 0.5, 5)
	queue_free()


## 子弹自己的颜色（碎片用）
func _colors() -> Array[Color]:
	if crt:
		return [Color(1.0, 0.25, 0.35), Color(0.35, 1.0, 0.45), Color(0.3, 0.55, 1.0)]
	if gravel:
		return [Color(0.66, 0.6, 0.52), Color(0.45, 0.4, 0.36)]
	match kind:
		Kind.SNOW:
			return [Color(0.95, 0.95, 1.0), Color(0.7, 0.72, 0.8)]
		Kind.SCAN:
			return [Color.WHITE, Color(0.55, 0.95, 1.0)]
		Kind.WAVE:
			return [Color(1.0, 0.88, 0.6), Color(0.85, 0.6, 0.35)]
		Kind.NOTE:
			return [Color(0.98, 0.92, 0.72), Color(1.0, 0.85, 0.5)]
		Kind.RIVET:
			return [Color(0.95, 0.92, 0.86), Color(1.0, 0.45, 0.2)]
		Kind.COAL:
			return [Color(0.4, 0.24, 0.16), Color(1.0, 0.45, 0.12)]
	return [Color(1.0, 0.72, 0.3), Color(1.0, 0.42, 0.1)]


## 碎成 n 片：一个节点画全部碎片（不是每片一个节点），0.3 秒散开、最后一闪一闪没掉。用子弹共用的那个材质
func _shatter(push: Vector2, n: int) -> void:
	if get_parent() == null:
		return
	var sh := Shards.new()
	sh.position = position
	sh.cols = _colors()
	for i in n:
		var a := TAU * (i + randf() * 0.6) / n
		sh.vels.append(Vector2(cos(a), sin(a)) * randf_range(25.0, 55.0) + push * 70.0)
		sh.pts.append(Vector2.ZERO)
	sh.material = _unshaded
	get_parent().add_child(sh)


class Shards extends Node2D:
	const LIFE := 0.3
	var pts: Array[Vector2] = []
	var vels: Array[Vector2] = []
	var cols: Array[Color] = []
	var _t := 0.0

	func _ready() -> void:
		z_index = 8

	func _process(delta: float) -> void:
		_t += delta
		if _t > LIFE:
			queue_free()
			return
		for i in pts.size():
			vels[i] *= 1.0 - 4.0 * delta
			vels[i].y += 120.0 * delta
			pts[i] += vels[i] * delta
		queue_redraw()

	func _draw() -> void:
		if _t > LIFE - 0.1 and int(_t * 30.0) % 2 == 0:
			return
		for i in pts.size():
			draw_rect(Rect2(pts[i].round(), Vector2(2, 2) if i == 0 and _t < 0.12 else Vector2.ONE), cols[i % cols.size()])


## 子弹都画大一圈、带一圈深色描边：弹幕游戏里子弹必须一眼看清
func _draw() -> void:
	const OUTLINE := Color(0.08, 0.04, 0.03, 0.85)
	if crt and kind in [Kind.RIVET, Kind.EMBER, Kind.NOTE]:
		_draw_crt()
		return
	if gravel and kind == Kind.COAL:
		_draw_gravel()
		return
	match kind:
		Kind.EMBER:
			var flick := 0.5 + 0.5 * sin(_life * 30.0 + _seed)
			for i in _trail.size():
				var p := (_trail[i] - position).round()
				draw_rect(Rect2(p - Vector2.ONE, Vector2(2, 2)), Color(1.0, 0.45, 0.15, 0.45 - i * 0.13))
			# 5×5 的圆角方块：外圈深色，里面橙，芯是亮黄白
			draw_rect(Rect2(-2, -3, 5, 7), OUTLINE)
			draw_rect(Rect2(-3, -2, 7, 5), OUTLINE)
			draw_rect(Rect2(-1, -2, 3, 5), Color(1.0, 0.42, 0.1))
			draw_rect(Rect2(-2, -1, 5, 3), Color(1.0, 0.42, 0.1))
			draw_rect(Rect2(-1, -1, 3, 3), Color(1.0, 0.72, 0.3))
			draw_rect(Rect2(0, 0, 1, 1), Color(1.0, 0.95, 0.75).lerp(Color.WHITE, flick))
		Kind.RIVET:
			for i in _trail.size():
				var p := (_trail[i] - position).round()
				draw_rect(Rect2(p, Vector2(2, 2)), Color(1.0, 0.5, 0.25, 0.6 - i * 0.11))
			draw_rect(Rect2(-2, -2, 5, 5), OUTLINE)
			draw_rect(Rect2(-1, -1, 3, 3), Color(0.95, 0.92, 0.86))
			draw_rect(Rect2(0, 0, 1, 1), Color(1.0, 0.45, 0.2))
		Kind.SNOW:
			# 一团黑白噪点：每帧随机换几个亮点，像雪花屏
			draw_rect(Rect2(-2, -2, 5, 5), OUTLINE)
			for k in 6:
				var p := Vector2(randi_range(-2, 2), randi_range(-2, 2))
				var v := randf_range(0.55, 1.0)
				draw_rect(Rect2(p, Vector2.ONE), Color(v, v, v))
		Kind.SCAN:
			# 一小段亮横线（扫描线），中间白、两头偏青
			var n := velocity.normalized()
			var side := Vector2(-n.y, n.x)
			for k in range(-3, 4):
				var p := (side * k).round()
				draw_rect(Rect2(p - Vector2.ONE, Vector2(3, 3)), OUTLINE)
			for k in range(-3, 4):
				var p := (side * k).round()
				draw_rect(Rect2(p, Vector2.ONE), Color.WHITE if absf(k) < 2 else Color(0.55, 0.95, 1.0))
		Kind.WAVE:
			# 一小段垂直于飞行方向的弧线，外圈暗、里面亮
			var n := velocity.normalized()
			var side := Vector2(-n.y, n.x)
			for k in range(-2, 3):
				var p := (side * k - n * (absf(k) * 0.6)).round()
				draw_rect(Rect2(p - Vector2.ONE, Vector2(3, 3)), OUTLINE)
			for k in range(-2, 3):
				var p := (side * k - n * (absf(k) * 0.6)).round()
				draw_rect(Rect2(p, Vector2.ONE), Color(1.0, 0.88, 0.6) if absf(k) < 2 else Color(0.85, 0.6, 0.35))
		Kind.NOTE:
			# 一个八分音符：符头 3×2 在左下，符杆 1×6，顶上一面小旗
			var c := Color(0.98, 0.92, 0.72)
			for i in _trail.size():
				var p := (_trail[i] - position).round()
				draw_rect(Rect2(p, Vector2.ONE), Color(1.0, 0.85, 0.5, 0.45 - i * 0.14))
			draw_rect(Rect2(-3, 0, 5, 4), OUTLINE)
			draw_rect(Rect2(0, -6, 3, 7), OUTLINE)
			draw_rect(Rect2(-2, 1, 3, 2), c)
			draw_rect(Rect2(1, -5, 1, 6), c)
			draw_rect(Rect2(2, -5, 1, 2), c)
		Kind.COAL:
			draw_rect(Rect2(-3, -3, 7, 6), OUTLINE)
			draw_rect(Rect2(-2, -2, 5, 4), Color(0.2, 0.15, 0.13))
			draw_rect(Rect2(-1, -2, 3, 1), Color(0.4, 0.24, 0.16))
			var hot := 0.6 + 0.4 * sin(_life * 18.0 + _seed)
			draw_rect(Rect2(-1, -1, 2, 2), Color(1.0, 0.45, 0.12) * hot + Color(0, 0, 0, 1.0 - hot))
			draw_rect(Rect2(1, 0, 1, 1), Color(1.0, 0.8, 0.4))


func _draw_crt() -> void:
	const OUTLINE := Color(0.03, 0.03, 0.06, 0.85)
	const R := Color(1.0, 0.25, 0.35)
	const G := Color(0.35, 1.0, 0.45)
	const B := Color(0.3, 0.55, 1.0)
	match kind:
		Kind.RIVET:
			var trail_cols := [R, G, B]
			for i in _trail.size():
				var p := (_trail[i] - position).round()
				var c: Color = trail_cols[i % 3]
				c.a = 0.7 - i * 0.12
				draw_rect(Rect2(p, Vector2.ONE), c)
			# 菱形：外圈深色，红往左错一格、蓝往右错一格，中间白
			for d in [Vector2(0, -2), Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(-2, 0), Vector2(-1, 0),
					Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1), Vector2(0, 2)]:
				draw_rect(Rect2(d - Vector2.ONE, Vector2(3, 3)), OUTLINE)
			for d in [Vector2(0, -1), Vector2(-1, 0), Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)]:
				draw_rect(Rect2(d + Vector2(-1, 0), Vector2.ONE), R)
				draw_rect(Rect2(d + Vector2(1, 0), Vector2.ONE), B)
			draw_rect(Rect2(0, -1, 1, 3), G)
			draw_rect(Rect2(0, 0, 1, 1), Color.WHITE)
		Kind.EMBER:
			for i in _trail.size():
				var p := (_trail[i] - position).round()
				draw_rect(Rect2(p, Vector2.ONE), Color(1.0, 0.3, 0.8, 0.5 - i * 0.15))
			var blink := int(_life * 12.0 + _seed) % 2 == 0
			draw_rect(Rect2(-3, -3, 6, 6), Color(0.9, 0.9, 0.95) if blink else OUTLINE)
			var bars := [Color(1.0, 0.9, 0.2), Color(0.2, 0.95, 1.0), Color(0.3, 1.0, 0.35), Color(1.0, 0.25, 0.85)]
			for i in 4:
				draw_rect(Rect2(-2 + i, -2, 1, 4), bars[i])
		Kind.NOTE:
			for i in _trail.size():
				var p := (_trail[i] - position).round()
				draw_rect(Rect2(p, Vector2.ONE), Color(0.3, 0.95, 1.0, 0.45 - i * 0.14))
			draw_rect(Rect2(-3, 0, 5, 4), OUTLINE)
			draw_rect(Rect2(0, -6, 3, 7), OUTLINE)
			for o in [[Vector2(-1, 0), Color(1.0, 0.3, 0.8)], [Vector2(1, 0), Color(0.3, 0.95, 1.0)], [Vector2.ZERO, Color.WHITE]]:
				var off: Vector2 = o[0]
				var c: Color = o[1]
				draw_rect(Rect2(Vector2(-2, 1) + off, Vector2(3, 2)), c)
				draw_rect(Rect2(Vector2(1, -5) + off, Vector2(1, 6)), c)
				draw_rect(Rect2(Vector2(2, -5) + off, Vector2(1, 2)), c)


## 路面碎石：7×6 的不规则石块，左上一块亮面、一道深色裂缝；后面拖淡白的汽（不是火星）
func _draw_gravel() -> void:
	const OUTLINE := Color(0.08, 0.07, 0.07, 0.85)
	const STONE := Color8(124, 114, 102)
	const LIGHT := Color8(176, 166, 150)
	const DARK := Color8(78, 71, 64)
	for i in _trail.size():
		var p := (_trail[i] - position).round()
		draw_rect(Rect2(p - Vector2.ONE, Vector2(2, 2)), Color(0.9, 0.9, 0.92, 0.35 - i * 0.1))
	# 滚的时候一翻一翻：每 0.12 秒左右翻一次面
	var flip := int(_life / 0.12 + _seed) % 2 == 1 if _rolling else false
	var sx := -1.0 if flip else 1.0
	draw_rect(Rect2(-3, -2, 7, 5), OUTLINE)
	draw_rect(Rect2(-2, -3, 5, 7), OUTLINE)
	draw_rect(Rect2(-2, -2, 5, 5), STONE)
	draw_rect(Rect2(-3, -1, 1, 3), STONE)
	draw_rect(Rect2(3, -1, 1, 2), STONE)
	draw_rect(Rect2(Vector2(-2, -2) if sx > 0 else Vector2(1, -2), Vector2(2, 1)), LIGHT)
	draw_rect(Rect2(Vector2(-2, -1) if sx > 0 else Vector2(2, -1), Vector2.ONE), LIGHT)
	draw_rect(Rect2(Vector2(1, 0) if sx > 0 else Vector2(-1, 0), Vector2(1, 2)), DARK)
	draw_rect(Rect2(-1, 2, 4, 1), DARK)
