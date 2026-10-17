class_name Operator
extends StaticBody2D
## 第二关 Boss「总机 THE OPERATOR」：一台成了精的巨型电话交换台。
## 它接通了这颗星球上所有人的声音，一句都没还回去；它想要录像带里那家人的声音。
## 打败它，冒出一句句别人没打完的最后一通电话。这一关的主题是"声音"。
##
## 招式（抽签不放回，和锅炉一样）：
##   铃声：两只铃铛轮流响，放出一圈圈带缺口的声波（穿过平台，挡不住，要钻缺口）
##   接线：先画红色虚线预警，然后插线从插孔板甩到墙上，整根带电（站在线上就挨电）
##   拨号：转盘转几格，就放出几颗慢慢追人的"声音"小球，打一下就碎（自动瞄准会帮你锁它们）
##   占线（二阶段起）：玩家那边三块铜地板轮流通电，先发蓝光预警，要跳上平台或换一块站
##   砸线（招牌招）：滑车飞快追到你头顶，地上闪红影，整台机器顺着缆绳砸下来；
##     砸在第一块挡住它的面上（长凳、桌子或地面）。砸地面会顺着地板炸出两道声波，要跳；躲长凳底下砸不到
## 会动：开打时上半截（插孔板）离开桌子，吊在天花板的天车轨道上，慢慢滑到你头顶追着你，
##   边追边出招；二阶段起砸两下、三阶段砸三下。桌子留在原地当平台。
## 三阶段：通体发亮、转盘疯转，出招更快，招式两两叠着出。
## 原点在桌腿脚底中间（停在桌上时），朝左。图层坐标见 tools/draw_boss2.py。

signal hp_changed(hp: float, max_hp: float)
signal phase_changed(phase: int)
signal defeated

const BASE_HP := 3200.0
const CONTACT_DAMAGE := 10.0
const CANVAS_ORIGIN := Vector2(48, 111)
const DIAL := Vector2(48, 40) - CANVAS_ORIGIN
const DIAL_R := 12.0
const BELLS := [Vector2(23, 9) - CANVAS_ORIGIN, Vector2(73, 9) - CANVAS_ORIGIN]
const HORN := Vector2(6, 52) - CANVAS_ORIGIN
const JACKS := Rect2(Vector2(20, 24) - CANVAS_ORIGIN, Vector2(56, 36))
const LED_COLOR := Color(1.0, 0.28, 0.18)
const SPARK := Color(0.65, 0.85, 1.0)
const BRASS := Color8(181, 142, 96)
const HOT_TINT := Color(1.35, 1.0, 0.75)
## 两个吊环（缆绳挂这里）
const HOOKS := [Vector2(30, 7) - CANVAS_ORIGIN, Vector2(66, 7) - CANVAS_ORIGIN]
## 插孔板的底边（相对原点）：砸下来时就是这条边落地
const HEAD_BOTTOM := 63.0 - 111.0
## 吊着时原点的高度（插孔板底边离地约 80）
const HOVER_Y := 130.0
const TRACK_SPEED := [38.0, 50.0, 64.0]
const SLAM_DAMAGE := 14.0

var arena := Rect2(0, 0, 320, 180)
var floor_y := 164.0
var bullet_parent: Node
## 房间里会通电的铜地板
var plates: Array = []
## 单向平台 Vector3(x0, x1, 顶面 y)：砸下来时落在第一块挡住它的面上
var platforms: Array = []
var rail_y := 16.0

var max_hp := BASE_HP
var hp := BASE_HP
var phase := 1
var active := false
var dead := false

var _time := 0.0
var _flash := 0.0
var _hot := 0.0
var _dial_angle := 0.0
var _dial_spin := 0.0
var _bell_shake := [0.0, 0.0]
var _lights_on := 1.0
var _breathe := 0
var _last_pattern := ""
var _bag: Array[String] = []
var _bag_phase := 0
var _warn_t := 0.0
var _warn_pos := Vector2.ZERO
## "dock" 停在桌上，"hover" 吊着追人，"hold" 吊着不动，"move" 正在被补间拉着走
var _mode := "dock"
var _track_mult := 1.0
var _shadow_t := 0.0
var _shadow_x := 0.0
var _shadow_y := 164.0
var _cable_shake := 0.0
var _cables_cut := false
var _contact_damage := CONTACT_DAMAGE

var _parts: Node2D
var _body: Sprite2D
var _deco: Node2D
var _led_light: PointLight2D
var _contact: Area2D
var _flash_mat: ShaderMaterial
var _warn: Node2D


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 0
	max_hp = BASE_HP * (1.0 + 0.5 * (Run.players.size() - 1))
	hp = max_hp
	if bullet_parent == null:
		bullet_parent = get_parent()

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(64, 50)
	shape.shape = rect
	shape.position = Vector2(0, -75)
	add_child(shape)
	_contact = Area2D.new()
	_contact.collision_layer = 0
	_contact.collision_mask = 2 | 8
	var cs := CollisionShape2D.new()
	var crect := RectangleShape2D.new()
	crect.size = Vector2(60, 50)
	cs.shape = crect
	cs.position = Vector2(0, -75)
	_contact.add_child(cs)
	add_child(_contact)

	_flash_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = EnemyBase.FLASH_SHADER
	_flash_mat.shader = sh

	_parts = Node2D.new()
	add_child(_parts)
	_body = Sprite2D.new()
	_body.texture = load("res://art/boss/operator_head.png")
	_body.centered = false
	_body.offset = -CANVAS_ORIGIN
	_body.material = _flash_mat
	_body.light_mask = 2
	_parts.add_child(_body)

	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	# 转盘、铃铛、信号小灯：都由代码画，不吃压暗（黑暗里也认得出这台机器的"脸"）
	_deco = Node2D.new()
	_deco.material = unshaded
	_deco.draw.connect(_draw_deco)
	_parts.add_child(_deco)

	_led_light = PointLight2D.new()
	_led_light.texture = Game.light_texture()
	_led_light.color = LED_COLOR
	_led_light.energy = 0.0
	_led_light.texture_scale = 0.8
	_led_light.position = DIAL
	_led_light.range_item_cull_mask = 1
	_parts.add_child(_led_light)

	var key := PointLight2D.new()
	key.texture = Game.light_texture()
	key.color = Color(1.0, 0.85, 0.65)
	key.energy = 2.0
	key.texture_scale = 3.8
	key.position = Vector2(-44, -64)
	key.range_item_cull_mask = 2
	add_child(key)

	_warn = Node2D.new()
	_warn.material = unshaded
	_warn.z_index = 20
	_warn.draw.connect(_draw_warn)
	add_child(_warn)


# —— 对外 ——

func aim_point() -> Vector2:
	return global_position + DIAL + _parts.position


func is_targetable() -> bool:
	return active and not dead


func wake() -> void:
	for i in 3:
		_led_light.energy = 1.0
		await get_tree().create_timer(0.08, false).timeout
		_led_light.energy = 0.0
		await get_tree().create_timer(0.06, false).timeout
	_led_light.energy = 1.0
	_ring_bell(0)
	_ring_bell(1)
	Game.sfx("bell", -2.0)
	_dial_spin = 14.0
	Game.add_shake(4.0)
	await get_tree().create_timer(0.5, false).timeout
	# 上半截离开桌子，顺着缆绳被拉上天车
	Game.sfx("scrape", -4.0, 0.7)
	Game.sfx("clang", -8.0, 1.3)
	Game.sparks(get_parent(), global_position + Vector2(0, HEAD_BOTTOM), BRASS, 10, 70.0)
	_mode = "move"
	var tw := create_tween()
	tw.tween_property(self, "position:y", HOVER_Y, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	# 快速开场时 start_fight 可能已经先到了（_mode 已是 hover），别把它改回去
	if _mode == "move":
		_mode = "hold"


func start_fight() -> void:
	active = true
	_mode = "hover"
	_fight_loop()


func hurt(damage: float, _from_dir: Vector2, _full: bool) -> void:
	if dead:
		return
	_flash = 1.0
	if not active:
		return
	hp = maxf(hp - damage, 0.0)
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_die()
		return
	var new_phase := 1 if hp > max_hp * 0.66 else (2 if hp > max_hp * 0.33 else 3)
	if new_phase != phase:
		phase = new_phase
		phase_changed.emit(phase)
		_phase_roar()


# —— 每帧 ——

func _physics_process(delta: float) -> void:
	_time += delta
	_flash = maxf(_flash - delta * 7.0, 0.0)
	_flash_mat.set_shader_parameter("flash", _flash)
	_warn_t -= delta
	_shadow_t -= delta
	_cable_shake = maxf(_cable_shake - delta, 0.0)
	_warn.queue_redraw()
	if active and not dead and _mode == "hover":
		var tx := clampf(_target().x, arena.position.x + 56.0, arena.end.x - 56.0)
		position.x = move_toward(position.x, tx, TRACK_SPEED[phase - 1] * _track_mult * delta)
		position.y = move_toward(position.y, HOVER_Y, 60.0 * delta)
	for i in 2:
		_bell_shake[i] = maxf(_bell_shake[i] - delta * 2.5, 0.0)
	_dial_spin = move_toward(_dial_spin, 0.0, delta * 6.0)
	_dial_angle += _dial_spin * delta
	var period := 0.55 if phase < 3 else 0.2
	var b := int(_time / period) % 2
	if b != _breathe:
		_breathe = b
		_parts.position.y = -b
	_hot = move_toward(_hot, 1.0 if (phase == 3 and not dead) else 0.0, delta)
	var tint := Color.WHITE.lerp(HOT_TINT, _hot * (0.6 + 0.4 * sin(_time * 8.0)))
	_body.modulate = Color(0.55, 0.55, 0.6) if dead else tint
	_deco.queue_redraw()
	if active and not dead:
		for body in _contact.get_overlapping_bodies():
			if body is Player:
				(body as Player).hurt(global_position + Vector2(0, -75), _contact_damage)
			elif body is Crystal:
				(body as Crystal).take_hit(global_position + Vector2(0, -75), _contact_damage)


# —— 出招 ——

func _wait(t: float) -> void:
	await get_tree().create_timer(t, false).timeout


func _gap() -> float:
	return [1.0, 0.8, 0.55][phase - 1]


func _pool() -> Array[String]:
	var pool: Array[String] = ["ring", "patch", "dial", "drop"]
	if phase >= 2:
		pool.append("busy")
	return pool


## 抽签不放回；换阶段时新招先出（和锅炉一样）
func _next_pattern() -> String:
	if _bag_phase != phase:
		_bag_phase = phase
		_bag.assign(_pool())
		_bag.shuffle()
		if phase >= 2 and _bag.has("busy"):
			_bag.erase("busy")
			_bag.append("busy")
	if _bag.is_empty():
		_bag.assign(_pool())
		_bag.shuffle()
		if _bag.size() > 1 and _bag.back() == _last_pattern:
			_bag.reverse()
	var pick: String = _bag.pop_back()
	_last_pattern = pick
	return pick


func _fight_loop() -> void:
	await _wait(0.6)
	while active and not dead:
		var pick := _next_pattern()
		if phase == 3:
			# 三阶段：两招叠着出（第二招不等第一招放完）
			var second := _next_pattern()
			if second == "drop" or pick == "drop":
				# 砸线不和别的招叠：另一招先放，砸线接着来
				await _run(second if pick == "drop" else pick)
				pick = "drop"
			else:
				_run(second)
			await _run(pick)
		else:
			await _run(pick)
		if dead:
			return
		await _wait(_gap())


func _run(pick: String) -> void:
	match pick:
		"ring":
			await _ring()
		"patch":
			await _patch()
		"dial":
			await _dial()
		"busy":
			await _busy()
		"drop":
			await _drop()


func _warn_at(pos: Vector2, t := 0.6) -> void:
	_warn_pos = pos
	_warn_t = t
	Game.sfx("charge", -16.0, 2.0)


func _ring_bell(i: int) -> void:
	_bell_shake[i] = 1.0


## 铃声：铃铛轮流响，每响一下放一圈声波，留 3 个缺口位置
func _ring() -> void:
	var rings: int = [2, 3, 4][phase - 1]
	_warn_at(BELLS[0] + Vector2(0, -12), 0.5)
	await _wait(0.5)
	for r in rings:
		if dead:
			return
		var side := r % 2
		_ring_bell(side)
		Game.sfx("bell", -4.0, 1.0 + 0.05 * r)
		Game.add_shake(1.5)
		var center: Vector2 = global_position + BELLS[side] + _parts.position
		var count := 24
		var gap_at := randi() % count
		for i in count:
			if absi(i - gap_at) <= 1 or absi(i - gap_at) >= count - 1:
				continue
			var a := TAU * i / count + (PI / count) * r
			var b := BossBullet.spawn(bullet_parent, BossBullet.Kind.WAVE, center, Vector2.from_angle(a) * 62.0)
			b.arena = arena
		await _wait(0.55)


## 接线：几根插线从插孔板甩到左墙，先画虚线预警，然后整根带电
func _patch() -> void:
	var n: int = [2, 3, 4][phase - 1]
	var lines: Array[CordLine] = []
	var tp := _target()
	for i in n:
		var left := global_position.x > arena.get_center().x
		var from := global_position + _parts.position + JACKS.position \
			+ Vector2(randf_range(0, 10) if left else randf_range(JACKS.size.x - 10, JACKS.size.x), randf_range(4, JACKS.size.y - 4))
		var to_y: float
		if i == 0:
			to_y = tp.y - 8.0                     # 第一根瞄着人的高度
		else:
			to_y = randf_range(arena.position.y + 30.0, floor_y - 6.0)
		var to := Vector2(arena.position.x + 8.0 if left else arena.end.x - 8.0, to_y)
		var line := CordLine.new()
		line.from = from
		line.to = to
		line.warn_time = 0.85
		line.live_time = 0.7
		line.delay = i * 0.18
		bullet_parent.add_child(line)
		lines.append(line)
	Game.sfx("dial", -6.0, 0.6)
	await _wait(0.85 + n * 0.18 + 0.7)


## 拨号：转盘一格一格回转，每一格放一颗慢慢追人的"声音"
func _dial() -> void:
	var n: int = [3, 4, 5][phase - 1]
	_warn_at(DIAL + Vector2(0, -18), 0.4)
	await _wait(0.4)
	for i in n:
		if dead:
			return
		_dial_spin = 9.0
		Game.sfx("dial", -2.0, 1.0 + 0.1 * i)
		var v := Voice.new()
		v.position = global_position + HORN + _parts.position
		v.arena = arena
		bullet_parent.add_child(v)
		await _wait(0.32)
	await _wait(0.6)


## 占线：玩家那边的铜地板轮流通电。二阶段一块，三阶段两块；先蓝光预警再通电
func _busy() -> void:
	if plates.is_empty():
		return
	Game.sfx("busy", -6.0)
	var order := plates.duplicate()
	order.shuffle()
	var n := 1 if phase == 2 else 2
	for i in n:
		order[i].call("charge", 1.0 + i * 0.25)
	await _wait(2.4 + n * 0.25)


## 砸线：滑车加速追到头顶 → 停住，地上闪红影 0.6 秒、缆绳抖 → 砸下来 → 停一下 → 收回去
func _drop() -> void:
	var slams: int = [1, 2, 3][phase - 1]
	for i in slams:
		if dead:
			return
		_mode = "hover"
		_track_mult = 3.2
		await _wait(0.75 if i == 0 else 0.45)
		if dead:
			return
		_mode = "hold"
		_track_mult = 1.0
		_shadow_x = position.x
		_shadow_y = _landing_y(position.x)
		_shadow_t = 0.6
		_cable_shake = 0.6
		Game.sfx("scrape", -6.0, 1.4)
		await _wait(0.6)
		if dead:
			return
		_mode = "move"
		_contact_damage = SLAM_DAMAGE
		var tw := create_tween()
		tw.tween_property(self, "position:y", _shadow_y - HEAD_BOTTOM, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
		_slam_impact(_shadow_y)
		await _wait([0.9, 0.7, 0.5][phase - 1])
		_contact_damage = CONTACT_DAMAGE
		if dead:
			return
		Game.sfx("scrape", -8.0, 0.8)
		var up := create_tween()
		up.tween_property(self, "position:y", HOVER_Y, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await up.finished
	_mode = "hover"


## 砸在哪个面上：插孔板底边下面第一块挡住它的平台，没有就是地面
func _landing_y(x: float) -> float:
	var top := global_position.y + _parts.position.y + HEAD_BOTTOM
	var best := floor_y
	for p in platforms:
		if p.x < x + 26.0 and p.y > x - 26.0 and p.z > top and p.z < best:
			best = p.z
	return best


func _slam_impact(y: float) -> void:
	Game.sfx("clang", 0.0, 0.8)
	Game.sfx("boom", -6.0, 1.2)
	Game.add_shake(7.0)
	Game.hitstop(0.05)
	Game.sparks(get_parent(), Vector2(position.x - 26, y), BRASS, 8, 90.0, Vector2.LEFT)
	Game.sparks(get_parent(), Vector2(position.x + 26, y), BRASS, 8, 90.0, Vector2.RIGHT)
	_ring_bell(0)
	_ring_bell(1)
	if absf(y - floor_y) < 1.0:
		# 砸在地上：顺着地板往两边炸出声波，要跳过去
		Game.dust(get_parent(), Vector2(position.x, floor_y), 8)
		for dir in [-1.0, 1.0]:
			for k in (2 if phase == 3 else 1):
				var b := BossBullet.spawn(bullet_parent, BossBullet.Kind.WAVE,
					Vector2(position.x + dir * 30.0, floor_y - 5.0 - k * 7.0), Vector2(dir * 95.0, 0))
				b.arena = arena


## 离 Boss 最近的那个玩家的位置
func _target() -> Vector2:
	var best := INF
	var out := Vector2(arena.position.x + 60.0, floor_y)
	for n in get_tree().get_nodes_in_group("player"):
		var p := n as Player
		var d := p.global_position.distance_to(global_position)
		if d < best:
			best = d
			out = p.global_position
	return out


func _phase_roar() -> void:
	_ring_bell(0)
	_ring_bell(1)
	Game.sfx("bell", 0.0, 0.8)
	Game.sfx("busy", -8.0, 1.2)
	Game.add_shake(6.0)
	Game.flash(Color(1.0, 0.85, 0.5), 0.25, 0.5)
	_dial_spin = 20.0


func _die() -> void:
	dead = true
	active = false
	_warn_t = 0.0
	_shadow_t = 0.0
	_contact_damage = CONTACT_DAMAGE
	remove_from_group("enemy")
	for b in get_tree().get_nodes_in_group("boss_bullet"):
		b.queue_free()
	defeated.emit()
	Game.hitstop(0.25)
	await get_tree().create_timer(0.3, true, false, true).timeout
	Engine.time_scale = 0.35
	for i in 9:
		var p := global_position + Vector2(randf_range(-30, 30), randf_range(-100, -50))
		Game.sparks(get_parent(), p, [SPARK, BRASS, Color(1, 0.9, 0.7)][i % 3], 16, 140.0)
		Game.sfx("buzz", -4.0, randf_range(0.8, 1.3))
		Game.sfx("boom", -8.0, randf_range(0.9, 1.3))
		Game.add_shake(5.0)
		Game.flash(Color(0.8, 0.9, 1.0), 0.22, 0.25)
		_flash = 1.0
		_dial_spin = 18.0
		_ring_bell(i % 2)
		await get_tree().create_timer(0.18, true, false, true).timeout
	Engine.time_scale = 1.0
	# 缆绳崩断，整台砸到地上
	_cables_cut = true
	_mode = "move"
	Game.sfx("clang", -2.0, 1.6)
	var land := _landing_y(position.x)
	var fall := create_tween()
	fall.tween_property(self, "position:y", land - HEAD_BOTTOM, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fall.finished
	Game.sfx("boom", -2.0, 0.8)
	Game.add_shake(8.0)
	Game.dust(get_parent(), Vector2(position.x, land), 10)
	# 信号小灯一盏盏灭掉，红灯熄，最后一声铃
	_led_light.energy = 0.0
	var tw := create_tween()
	tw.tween_property(self, "_lights_on", 0.0, 1.5)
	Game.sfx("bell", -6.0, 0.6)


# —— 画 ——

func _draw_deco() -> void:
	# 天车缆绳：从两个吊环直直拉到天花板轨道，轨道上一个小滑车；砸之前缆绳抖
	if not _cables_cut:
		var rail := rail_y - global_position.y - _parts.position.y
		for h in HOOKS:
			var hp: Vector2 = h
			var wob := roundf(sin(_time * 60.0) * _cable_shake * 2.0)
			for y in range(int(rail) + 3, int(hp.y)):
				var t := float(y - rail) / maxf(hp.y - rail, 1.0)
				var x := hp.x + roundf(wob * sin(t * PI))
				_deco.draw_rect(Rect2(x, y, 1, 1), Color8(70, 62, 52))
			_deco.draw_rect(Rect2(hp.x - 3, rail - 1, 7, 3), Color8(56, 56, 56))
			_deco.draw_rect(Rect2(hp.x - 2, rail - 2, 2, 2), Color8(99, 99, 99))
			_deco.draw_rect(Rect2(hp.x + 1, rail - 2, 2, 2), Color8(99, 99, 99))
	# 转盘：黄铜外圈 + 黑底 + 十个指孔，一直跟着 _dial_angle 转
	var c := DIAL.round()
	var r := int(DIAL_R)
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var d := Vector2(x, y).length()
			if d <= r + 0.3:
				var col := Color8(181, 142, 96) if d > r - 1.7 else Color8(30, 22, 18)
				if d <= 3.3:
					col = Color8(140, 118, 80)
				_deco.draw_rect(Rect2(c + Vector2(x, y), Vector2.ONE), col)
	for k in 10:
		var a := _dial_angle + TAU * k / 12.0 - PI * 0.75
		var p := (c + Vector2.from_angle(a) * (r - 4.5)).round()
		_deco.draw_rect(Rect2(p - Vector2.ONE, Vector2(2, 2)), Color8(96, 66, 42))
		_deco.draw_rect(Rect2(p - Vector2.ONE, Vector2.ONE), Color8(147, 111, 68))
	# 指挡（停住指头的那根小铜钩）
	_deco.draw_rect(Rect2(c + Vector2(r - 3, 3), Vector2(3, 1)), Color8(200, 170, 110))
	# 中心红灯
	var on := _led_light.energy > 0.0
	var blink := 1.0 if phase < 3 else (0.5 + 0.5 * sin(_time * 30.0))
	var led := LED_COLOR.lerp(Color.WHITE, _flash * 0.6) * blink if on else Color(0.3, 0.08, 0.06)
	_deco.draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), Color(led.r, led.g, led.b, 1.0))
	# 两只铃铛：黄铜半球，响的时候左右抖
	for i in 2:
		var bc: Vector2 = BELLS[i]
		var shake := roundf(sin(_time * 70.0) * 1.5 * _bell_shake[i])
		for y in range(-5, 3):
			var half := int(sqrt(maxf(25.0 - (y + 1) * (y + 1), 0.0)))
			for x in range(-half, half + 1):
				var col := Color8(181, 142, 96)
				if x < -half + 2 and y < 0:
					col = Color8(214, 186, 132)
				elif x > half - 2 or y > 0:
					col = Color8(117, 88, 53)
				_deco.draw_rect(Rect2(bc + Vector2(x + shake, y), Vector2.ONE), col)
		_deco.draw_rect(Rect2(bc + Vector2(-1 + shake, 3), Vector2(2, 1)), Color8(96, 66, 42))
	# 插孔上方的信号小灯：一闪一闪，像有电话打进来
	if _lights_on > 0.0:
		for row in 4:
			for col_i in 7:
				var seed := row * 7 + col_i
				var lit := sin(_time * (2.0 + seed % 5) + seed * 1.7) > 0.55
				if not lit:
					continue
				var p := JACKS.position + Vector2(3 + col_i * 8, 2 + row * 9)
				var amber := Color(1.0, 0.75, 0.3, _lights_on)
				_deco.draw_rect(Rect2(p, Vector2.ONE), amber)


func _draw_warn() -> void:
	if _shadow_t > 0.0 and int(_shadow_t * 16.0) % 2 == 0:
		# 砸线落点：落地那一面上一道闪烁的红影，宽度就是插孔板的宽度
		var y := _shadow_y - global_position.y
		var x0 := _shadow_x - global_position.x - 30.0
		_warn.draw_rect(Rect2(x0, y - 2, 60, 2), Color(1.0, 0.25, 0.2, 0.85))
		for k in range(0, 60, 6):
			_warn.draw_rect(Rect2(x0 + k + 2, y - 5, 2, 2), Color(1.0, 0.3, 0.25, 0.6))
	if _warn_t <= 0.0 or int(_warn_t * 14.0) % 2 == 0:
		return
	var p := _warn_pos.round()
	var col := Color(1.0, 0.25, 0.2)
	_warn.draw_rect(Rect2(p + Vector2(-1, -9), Vector2(3, 6)), col)
	_warn.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(3, 2)), col)
	_warn.draw_rect(Rect2(p + Vector2(0, -9), Vector2(1, 6)), Color(1, 0.75, 0.6))


## 一根甩出去的插线：先 warn_time 画红色虚线，然后 live_time 整根带电（挨着线就挨电）
class CordLine:
	extends Node2D

	const HIT_DIST := 3.5
	const DAMAGE := 10.0
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var warn_time := 0.8
	var live_time := 0.7
	var delay := 0.0
	var _t := 0.0
	var _buzzed := false

	func _ready() -> void:
		z_index = 9
		add_to_group("boss_bullet")
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded

	func _physics_process(delta: float) -> void:
		_t += delta
		var t := _t - delay
		if t >= warn_time and not _buzzed:
			_buzzed = true
			Game.sfx("buzz", -6.0, randf_range(0.9, 1.1))
			Game.add_shake(1.5)
		if t >= warn_time and t < warn_time + live_time:
			for n in get_tree().get_nodes_in_group("player"):
				var p := n as Player
				var mid := p.global_position + Vector2(0, -8)
				if Geometry2D.get_closest_point_to_segment(mid, from, to).distance_to(mid) < HIT_DIST + 4.0:
					p.hurt(Geometry2D.get_closest_point_to_segment(mid, from, to), DAMAGE * EnemyBase.damage_mult())
		if t >= warn_time + live_time:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t := _t - delay
		if t < 0.0:
			return
		var len := from.distance_to(to)
		var dir := (to - from) / maxf(len, 1.0)
		if t < warn_time:
			# 预警：红色虚线，越来越快地闪
			var blink := int(t / (0.06 if t > warn_time * 0.5 else 0.1)) % 2 == 0
			if not blink:
				return
			for i in range(0, int(len), 6):
				var p := (from + dir * i).round()
				draw_rect(Rect2(p, Vector2(3, 1)), Color(1.0, 0.3, 0.2, 0.85))
			return
		# 带电：一根黄铜插线，外面一圈蓝白色的电弧在抖
		for i in range(0, int(len), 2):
			var p := (from + dir * i).round()
			draw_rect(Rect2(p, Vector2(2, 1)), Color8(181, 142, 96))
			if randf() < 0.35:
				var off := Vector2(-dir.y, dir.x) * randf_range(-3, 3)
				draw_rect(Rect2((p + off).round(), Vector2.ONE), Color(0.75, 0.9, 1.0))


## 一颗"声音"：慢慢追人的发光小球，4 秒后散掉；打一下就碎（在 enemy 组里，自动瞄准会锁它）
class Voice:
	extends StaticBody2D

	const SPEED := 46.0
	const LIFE := 4.5
	const DAMAGE := 8.0
	var arena := Rect2(0, 0, 320, 180)
	var velocity := Vector2.ZERO
	var _t := 0.0
	var _done := false

	func _ready() -> void:
		add_to_group("enemy")
		add_to_group("boss_bullet")
		collision_layer = 4
		collision_mask = 0
		z_index = 9
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 4.0
		cs.shape = c
		add_child(cs)
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded
		var l := PointLight2D.new()
		l.texture = Game.light_texture()
		l.color = Color(1.0, 0.85, 0.55)
		l.energy = 0.7
		l.texture_scale = 0.6
		add_child(l)
		velocity = Vector2(-40, randf_range(-30, 30))
		Game.sfx("voice", -10.0, randf_range(0.9, 1.2))

	func aim_point() -> Vector2:
		return global_position

	func is_targetable() -> bool:
		return not _done

	func hurt(_damage: float, _dir: Vector2, _full: bool) -> void:
		_pop()

	func _pop() -> void:
		if _done:
			return
		_done = true
		Game.sparks(get_parent(), global_position, Color(1.0, 0.85, 0.55), 8, 60.0)
		Game.sfx("voice", -12.0, 1.8)
		queue_free()

	func _physics_process(delta: float) -> void:
		if _done:
			return
		_t += delta
		var target := global_position + Vector2(-60, 0)
		var best := INF
		for n in get_tree().get_nodes_in_group("player"):
			var p := (n as Node2D).global_position + Vector2(0, -9)
			var d := p.distance_to(global_position)
			if d < best:
				best = d
				target = p
			if d < 7.0:
				(n as Player).hurt(global_position, DAMAGE * EnemyBase.damage_mult())
				_pop()
				return
		var want := (target - global_position).normalized() * SPEED
		velocity = velocity.move_toward(want, 60.0 * delta)
		global_position += velocity * delta
		if _t > LIFE or not arena.grow(20).has_point(global_position):
			_pop()
			return
		queue_redraw()

	func _draw() -> void:
		# 一颗发光小球，外面一圈一圈的声纹
		var pulse := 0.5 + 0.5 * sin(_t * 12.0)
		draw_rect(Rect2(-2, -3, 5, 7), Color(0.1, 0.06, 0.04, 0.85))
		draw_rect(Rect2(-3, -2, 7, 5), Color(0.1, 0.06, 0.04, 0.85))
		draw_rect(Rect2(-1, -2, 3, 5), Color(1.0, 0.8, 0.45))
		draw_rect(Rect2(-2, -1, 5, 3), Color(1.0, 0.8, 0.45))
		draw_rect(Rect2(0, 0, 1, 1), Color.WHITE)
		var r := 5.0 + pulse * 2.0
		for k in 8:
			var p := (Vector2.from_angle(TAU * k / 8.0 + _t) * r).round()
			draw_rect(Rect2(p, Vector2.ONE), Color(1.0, 0.85, 0.55, 0.5 * (1.0 - pulse)))


## 会通电的铜地板（占线）：charge(delay) 以后先蓝光预警 0.9 秒，再通电 1.2 秒，站在上面就挨电
class ElectricPlate:
	extends Node2D

	const WARN := 0.9
	const LIVE := 1.2
	const DAMAGE := 10.0
	var x0 := 0.0
	var x1 := 80.0
	var floor_y := 164.0
	var _t := -1.0

	func _ready() -> void:
		z_index = 7
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded

	func charge(delay := 0.0) -> void:
		_t = -delay

	func _physics_process(delta: float) -> void:
		if _t < -50.0:
			return
		var was := _t
		_t += delta
		if was < WARN and _t >= WARN:
			Game.sfx("buzz", -4.0, 0.8)
			Game.add_shake(2.0)
		if _t >= WARN and _t < WARN + LIVE:
			for n in get_tree().get_nodes_in_group("player"):
				var p := n as Player
				if p.is_on_floor() and absf(p.global_position.y - floor_y) < 3.0 \
						and p.global_position.x >= x0 and p.global_position.x <= x1:
					p.hurt(Vector2(p.global_position.x, floor_y + 6), DAMAGE * EnemyBase.damage_mult())
		if _t >= WARN + LIVE:
			_t = -100.0
		queue_redraw()

	func _draw() -> void:
		if _t < 0.0:
			return
		if _t < WARN:
			# 预警：铜板上一排蓝点闪，越来越快
			if int(_t / (0.06 if _t > WARN * 0.5 else 0.12)) % 2 == 0:
				for x in range(int(x0) + 2, int(x1) - 1, 4):
					draw_rect(Rect2(x, floor_y - 1, 2, 1), Color(0.55, 0.8, 1.0, 0.9))
			return
		# 通电：整块铜板发白，上面一串串电弧跳
		draw_rect(Rect2(x0 + 1, floor_y - 1, x1 - x0 - 2, 2), Color(0.8, 0.92, 1.0, 0.9))
		for i in 10:
			var x := randf_range(x0 + 2, x1 - 2)
			var h := randi_range(3, 9)
			var px := x
			for y in h:
				px += randf_range(-1.2, 1.2)
				draw_rect(Rect2(roundf(px), floor_y - 2 - y, 1, 1), Color(0.7, 0.88, 1.0))
