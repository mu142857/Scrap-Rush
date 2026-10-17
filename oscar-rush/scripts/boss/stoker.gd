class_name Stoker
extends StaticBody2D
## 第一关 Boss「司炉 THE STOKER」：成了精的老锅炉，专往炉膛里铲"回忆"烧。
## 它闻到马灯里那段录像——最好的燃料——所以要抢灯。打败它，炉门炸开，飘出别人被烧掉的照片和胶片。
##
## 三个阶段（按血量）：
##   1（100%~66%）余烬雨、铆钉环、铲煤
##   2（66%~33%） 加蒸汽喷口，铆钉变双圈
##   3（33% 以下）超压：通体烧红、出招更快，铆钉转成螺旋，加"添柴"——开炉门往里吸人和马灯
## 炉门开着的时候是弱点，打中伤害翻倍。所有大招前都有预警（红"!"、格栅发红、举铲）。
## 原点在脚底中间，朝左。各图层的坐标对应 tools/draw_boss.py。

signal hp_changed(hp: float, max_hp: float)
signal phase_changed(phase: int)
signal defeated

const BASE_HP := 3000.0
const CONTACT_DAMAGE := 10.0
## 画布 84×96，原点在画布底边中间 (42, 95)
const CANVAS_ORIGIN := Vector2(42, 95)
const GAUGE := Vector2(28, 49) - CANVAS_ORIGIN
const LED := Vector2(19, 41) - CANVAS_ORIGIN
const CHIMNEY := Vector2(54, 7) - CANVAS_ORIGIN
const DOOR_RECT := Rect2(Vector2(23, 63) - CANVAS_ORIGIN, Vector2(18, 15))
const ARM_OFFSET := Vector2(16 - 44, 56 - 24) - CANVAS_ORIGIN
const SHOVEL_TIP := Vector2(-58, -6)

const LED_COLOR := Color(1.0, 0.28, 0.18)
const FIRE_COLOR := Color(1.0, 0.55, 0.2)
const HOT_TINT := Color(1.5, 0.75, 0.6)

## 竞技场（房间里设）：子弹出界就消失，煤块贴着 floor_y 滚
var arena := Rect2(0, 0, 320, 180)
var floor_y := 164.0
## 房间里的蒸汽格栅
var vents: Array[SteamVent] = []
## 子弹放到哪个节点下面
var bullet_parent: Node

var max_hp := BASE_HP
var hp := BASE_HP
var phase := 1
var active := false
var dead := false

var _time := 0.0
var _flash := 0.0
var _hot := 0.0
var _door_open := false
var _stoke_damage := 0.0
var _pressure := 0.0
var _needle := 0.0
var _last_pattern := ""
var _breathe := 0

var _parts: Node2D          # 会呼吸的那部分（身体、门、臂、表、灯、火光）
var _legs: Sprite2D
var _body: Sprite2D
var _door: Sprite2D
var _arm: Sprite2D
var _glow: Node2D
var _needle_node: Node2D
var _led: Node2D
var _fire_light: PointLight2D
var _led_light: PointLight2D
var _smoke: CPUParticles2D
var _contact: Area2D
var _flash_mat: ShaderMaterial
var _warn: Node2D
var _warn_t := 0.0
var _warn_pos := Vector2.ZERO
var _suction: AudioStreamPlayer


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
	rect.size = Vector2(58, 58)
	shape.shape = rect
	shape.position = Vector2(2, -40)
	add_child(shape)

	_contact = Area2D.new()
	_contact.collision_layer = 0
	_contact.collision_mask = 2 | 8
	var cs := CollisionShape2D.new()
	var crect := RectangleShape2D.new()
	crect.size = Vector2(54, 74)
	cs.shape = crect
	cs.position = Vector2(2, -37)
	_contact.add_child(cs)
	add_child(_contact)

	_flash_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = EnemyBase.FLASH_SHADER
	_flash_mat.shader = sh

	_legs = _sprite("res://art/boss/stoker_legs.png", self, 1)
	_parts = Node2D.new()
	add_child(_parts)
	_body = _sprite("res://art/boss/stoker_body.png", _parts, 1)

	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_glow = Node2D.new()
	_glow.material = unshaded
	_glow.draw.connect(_draw_glow)
	_parts.add_child(_glow)

	_door = _sprite("res://art/boss/stoker_door.png", _parts, 2)
	_arm = _sprite("res://art/boss/stoker_arm.png", _parts, 3)
	_arm.offset = ARM_OFFSET

	_needle_node = Node2D.new()
	_needle_node.position = GAUGE
	_needle_node.material = unshaded
	_needle_node.draw.connect(_draw_needle)
	_parts.add_child(_needle_node)

	_led = Node2D.new()
	_led.position = LED
	_led.material = unshaded
	_led.draw.connect(_draw_led)
	_parts.add_child(_led)
	_led_light = PointLight2D.new()
	_led_light.texture = Game.light_texture()
	_led_light.color = LED_COLOR
	_led_light.energy = 0.0
	_led_light.texture_scale = 0.6
	_led_light.range_item_cull_mask = 1
	_led.add_child(_led_light)

	_fire_light = PointLight2D.new()
	_fire_light.texture = Game.light_texture()
	_fire_light.color = FIRE_COLOR
	_fire_light.energy = 0.6
	_fire_light.texture_scale = 2.4
	# 炉火只照地面和墙，不照锅炉自己（2D 的光是相加的，叠多了铁壳会被照成白的）
	_fire_light.range_item_cull_mask = 1
	_fire_light.position = DOOR_RECT.get_center() + Vector2(-6, 6)
	_parts.add_child(_fire_light)
	# 只照 Boss 自己的一盏正面暖光（舞台追光），铁壳看得清又不会过曝
	var key := PointLight2D.new()
	key.texture = Game.light_texture()
	key.color = Color(1.0, 0.78, 0.62)
	key.energy = 2.0
	key.texture_scale = 3.6
	key.position = Vector2(-40, -56)
	key.range_item_cull_mask = 2
	add_child(key)

	_smoke = CPUParticles2D.new()
	_smoke.amount = 18
	_smoke.lifetime = 2.2
	_smoke.local_coords = false
	_smoke.direction = Vector2(0.3, -1)
	_smoke.spread = 12.0
	_smoke.initial_velocity_min = 12.0
	_smoke.initial_velocity_max = 22.0
	_smoke.gravity = Vector2(4, -6)
	_smoke.scale_amount_min = 2.0
	_smoke.scale_amount_max = 5.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.3, 0.28, 0.27, 0.8))
	ramp.set_color(1, Color(0.15, 0.14, 0.14, 0.0))
	_smoke.color_ramp = ramp
	_smoke.position = CHIMNEY
	_parts.add_child(_smoke)

	_warn = Node2D.new()
	_warn.material = unshaded
	_warn.z_index = 20
	_warn.draw.connect(_draw_warn)
	add_child(_warn)

	_suction = AudioStreamPlayer.new()
	var st := Game.load_sound("suction").duplicate() as AudioStreamWAV
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_end = st.data.size() / 2
	_suction.stream = st
	_suction.volume_db = -6.0
	add_child(_suction)


func _sprite(path: String, parent: Node, frames: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.hframes = frames
	s.centered = false
	s.offset = -CANVAS_ORIGIN
	s.material = _flash_mat
	s.light_mask = 2
	parent.add_child(s)
	return s


# —— 对外 ——

func aim_point() -> Vector2:
	return global_position + (DOOR_RECT.get_center() if _door_open else GAUGE)


func is_targetable() -> bool:
	return active and not dead


## 开场：红灯亮起、指针甩到顶再落回来、烟囱喷一口、汽笛
func wake() -> void:
	Game.sfx("whistle", -4.0)
	for i in 3:
		_led_light.energy = 1.0
		_led.queue_redraw()
		await get_tree().create_timer(0.08, false).timeout
		_led_light.energy = 0.0
		await get_tree().create_timer(0.06, false).timeout
	_led_light.energy = 1.0
	_pressure = 1.0
	_smoke.amount = 40
	_blast_smoke()
	Game.add_shake(4.0)
	await get_tree().create_timer(0.6, false).timeout
	_pressure = 0.3


func start_fight() -> void:
	active = true
	_fight_loop()


func hurt(damage: float, from_dir: Vector2, full: bool) -> void:
	if dead:
		return
	_flash = 1.0
	if not active:
		return
	var dmg := damage * (2.0 if _door_open else 1.0)
	if _door_open:
		_stoke_damage += dmg
		Game.sparks(get_parent(), aim_point(), FIRE_COLOR, 10, 90.0)
	hp = maxf(hp - dmg, 0.0)
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
	_warn.queue_redraw()

	# 呼吸：身体每 0.5 秒上下 1 像素，腿不动；超压时抖得更快
	var period := 0.5 if phase < 3 else 0.18
	var b := int(_time / period) % 2
	if b != _breathe:
		_breathe = b
		_parts.position.y = -b
	# 超压：通体发红，一跳一跳的
	_hot = move_toward(_hot, 1.0 if (phase == 3 and not dead) else 0.0, delta)
	var pulse := 0.5 + 0.5 * sin(_time * 9.0)
	var tint := Color.WHITE.lerp(HOT_TINT, _hot * (0.6 + 0.4 * pulse))
	if dead:
		tint = Color(0.55, 0.55, 0.6)
	for s in [_legs, _body, _door, _arm]:
		s.modulate = tint

	# 压力表：情绪越高、阶段越后，指针越往红区走，还一直抖
	if active and not dead:
		_pressure = clampf(0.25 + 0.2 * (phase - 1) + Run.emotion / 100.0 * 0.35, 0.0, 1.0)
	var jitter := sin(_time * 23.0) * 0.03 + sin(_time * 41.0) * 0.02 * phase
	_needle = move_toward(_needle, clampf(_pressure + jitter, 0.0, 1.05), delta * 2.5)
	_needle_node.queue_redraw()
	_glow.queue_redraw()
	_led.queue_redraw()
	var fire := 0.55 + 0.15 * sin(_time * 13.0) + 0.1 * sin(_time * 31.0)
	_fire_light.energy = 0.0 if dead else fire * (2.2 if _door_open else 1.0) * (1.0 + _hot * 0.6)

	if active and not dead:
		for body in _contact.get_overlapping_bodies():
			if body is Player:
				(body as Player).hurt(global_position + Vector2(0, -30), CONTACT_DAMAGE)
			elif body is Crystal:
				(body as Crystal).take_hit(global_position + Vector2(0, -30), CONTACT_DAMAGE)


# —— 出招 ——

func _wait(t: float) -> void:
	await get_tree().create_timer(t, false).timeout


## 歇口气的时间：越往后越短，情绪越高越短
func _gap() -> float:
	return [1.3, 1.0, 0.7][phase - 1] * EnemyBase.interval_mult()


func _fight_loop() -> void:
	await _wait(0.6)
	while active and not dead:
		var pool: Array[String] = ["ember", "ring", "shovel"]
		if phase >= 2:
			pool.append("vents")
		if phase >= 3:
			pool.append("stoke")
			pool.append("spiral")
		pool.erase(_last_pattern)
		var pick: String = pool.pick_random()
		_last_pattern = pick
		match pick:
			"ember":
				await _ember_volley()
			"ring":
				await _rivet_ring()
			"shovel":
				await _shovel_sweep()
			"vents":
				await _vents()
			"stoke":
				await _stoke()
			"spiral":
				await _spiral()
		if dead:
			return
		# 三阶段：歇口气的同时还会补一股余烬
		if phase == 3 and pick != "ember":
			_ember_burst(5)
		await _wait(_gap())


func _warn_at(pos: Vector2, t := 0.6) -> void:
	_warn_pos = pos
	_warn_t = t
	Game.sfx("charge", -16.0, 2.0)


## 余烬雨：烟囱"噗"地喷几股火星上天，落下来满屏都是，躲到平台下面就挡住了
func _ember_volley() -> void:
	_pressure = 0.9
	Game.sfx("alarm", -18.0, 1.4)
	_smoke.amount = 40
	await _wait(0.5)
	var bursts: int = [3, 4, 5][phase - 1]
	for i in bursts:
		if dead:
			return
		_ember_burst([7, 9, 11][phase - 1])
		await _wait(0.45)


func _ember_burst(n: int) -> void:
	Game.sfx("embers", -4.0, 1.0, 0.15)
	Game.add_shake(1.5)
	_blast_smoke()
	var top := global_position + CHIMNEY + _parts.position
	for i in n:
		# 大部分往左（玩家那边），少数往右落回 Boss 身后
		var vx := randf_range(-190.0, -20.0) if randf() < 0.85 else randf_range(0.0, 50.0)
		var v := Vector2(vx, randf_range(-260.0, -170.0))
		var b := BossBullet.spawn(bullet_parent, BossBullet.Kind.EMBER, top + Vector2(randf_range(-3, 3), 0), v, i % 3 == 0)
		b.arena = arena


## 铆钉环：压力表"咔"一声，炸出一圈铆钉，留一个缺口
func _rivet_ring() -> void:
	var center := global_position + GAUGE + _parts.position
	_warn_at(GAUGE + Vector2(0, -14))
	_pressure = 1.0
	await _wait(0.6)
	var rings: int = 1 if phase == 1 else 2
	for r in rings:
		if dead:
			return
		var count := 18 if phase == 1 else 22
		var gap_at := randi() % count
		var spin := (TAU / count) * 0.5 * r
		Game.sfx("rivets", -3.0, 1.0 + 0.1 * r)
		Game.add_shake(2.0)
		Game.sparks(get_parent(), center, Color(1, 0.7, 0.4), 8, 80.0)
		for i in count:
			if absi(i - gap_at) <= 1 or absi(i - gap_at) >= count - 1:
				continue  # 缺口：三颗不发
			var a := TAU * i / count + spin
			var b := BossBullet.spawn(bullet_parent, BossBullet.Kind.RIVET, center, Vector2.from_angle(a) * 70.0)
			b.arena = arena
		await _wait(0.4)


## 三阶段的螺旋：两条铆钉流一边转一边射，转一圈半
func _spiral() -> void:
	var center := global_position + GAUGE
	_warn_at(GAUGE + Vector2(0, -14), 0.7)
	await _wait(0.7)
	var a := randf() * TAU
	for i in 36:
		if dead:
			return
		for arm_i in 2:
			var ang := a + PI * arm_i
			var b := BossBullet.spawn(bullet_parent, BossBullet.Kind.RIVET, center + _parts.position, Vector2.from_angle(ang) * 80.0)
			b.arena = arena
		a += deg_to_rad(15.0)
		if i % 4 == 0:
			Game.sfx("rivets", -10.0, 1.3, 0.1)
		await _wait(0.06)


## 铲煤：举铲（"!"）→ 砸下去贴地铲出一排烧红的煤块往左滚，要跳过去
func _shovel_sweep() -> void:
	_arm.frame = 1
	_warn_at(Vector2(-60, -60), 0.7)
	Game.sfx("scrape", -10.0, 0.7)
	await _wait(0.75)
	if dead:
		return
	_arm.frame = 2
	Game.sfx("scrape", -2.0)
	Game.sfx("boom", -10.0, 1.6)
	Game.add_shake(4.0)
	var tip := global_position + SHOVEL_TIP
	Game.sparks(get_parent(), tip, FIRE_COLOR, 12, 110.0)
	var n: int = [4, 5, 6][phase - 1]
	for i in n:
		var b := BossBullet.spawn(bullet_parent, BossBullet.Kind.COAL, tip + Vector2(-i * 3, -4),
			Vector2(-randf_range(75.0, 135.0), -randf_range(80.0, 170.0)))
		b.floor_y = floor_y
		b.arena = arena
	await _wait(0.7)
	_arm.frame = 0


## 蒸汽喷口：二阶段挑 1~2 个，三阶段三个依次喷
func _vents() -> void:
	if vents.is_empty():
		return
	Game.sfx("whistle", -14.0, 1.3)
	var order := vents.duplicate()
	order.shuffle()
	var n := 2 if phase == 2 else order.size()
	for i in n:
		(order[i] as SteamVent).trigger(i * (0.35 if phase == 3 else 0.6))
	await _wait(1.9 + n * 0.3)


## 添柴：打开炉门往里吸。人和地上的马灯都被往炉门拽；炉门开着时打中伤害翻倍，
## 吸的时候挨够 300 伤害就被打断。马灯真被吸到炉门口，水晶掉一大截，灯被吐出来。
func _stoke() -> void:
	_warn_at(DOOR_RECT.get_center() + Vector2(0, -22), 0.6)
	Game.sfx("whistle", -6.0, 0.8)
	await _wait(0.6)
	if dead:
		return
	_door_open = true
	_door.frame = 1
	_stoke_damage = 0.0
	_suction.play()
	Game.add_shake(3.0)
	var mouth := global_position + DOOR_RECT.get_center()
	var t := 0.0
	while t < 2.6 and not dead and _stoke_damage < 300.0:
		var dt := get_physics_process_delta_time()
		t += dt
		Game.add_shake(1.0)
		for n in get_tree().get_nodes_in_group("player"):
			var p := n as Player
			var dx := mouth.x - p.global_position.x
			p.push(Vector2(signf(dx) * 85.0, 0))
		for n in get_tree().get_nodes_in_group("crystal"):
			var c := n as Crystal
			if c.carrier != null:
				continue
			c.velocity.x += signf(mouth.x - c.global_position.x) * 420.0 * dt
			if c.global_position.distance_to(mouth + Vector2(0, 8)) < 12.0:
				_eat_lantern(c)
		# 往炉门里飘的火星
		if randf() < 0.4:
			Game.sparks(get_parent(), mouth + Vector2(randf_range(-60, -20), randf_range(-20, 10)), FIRE_COLOR, 1, 20.0,
				Vector2(1, 0))
		await get_tree().physics_frame
	_suction.stop()
	_door_open = false
	_door.frame = 0
	Game.sfx("clang", -8.0, 1.4)
	if _stoke_damage >= 300.0:
		# 被打断：踉跄一下，喷一口烟
		Game.sfx("boom", -8.0, 1.2)
		_blast_smoke()
		await _wait(0.8)


func _eat_lantern(c: Crystal) -> void:
	Game.sfx("crack", 0.0, 0.8)
	Game.flash(Color(1.0, 0.5, 0.2), 0.35, 0.5)
	Game.add_shake(6.0)
	Run.damage_crystal(25.0)
	c.velocity = Vector2(-220.0, -200.0)
	c.global_position.x -= 14.0


# —— 阶段转换和死亡 ——

func _phase_roar() -> void:
	Game.sfx("whistle", 0.0, 0.9)
	Game.sfx("alarm", -8.0)
	Game.add_shake(6.0)
	Game.flash(Color(1.0, 0.45, 0.2), 0.3, 0.6)
	_blast_smoke()
	for v in vents:
		v.trigger(randf() * 0.3)


func _blast_smoke() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = 24
	p.lifetime = 1.4
	p.explosiveness = 0.9
	p.direction = Vector2.UP
	p.spread = 30.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 90.0
	p.damping_min = 40.0
	p.damping_max = 70.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.42, 0.38, 0.36, 0.9))
	ramp.set_color(1, Color(0.2, 0.19, 0.19, 0.0))
	p.color_ramp = ramp
	p.global_position = global_position + CHIMNEY + _parts.position
	get_parent().add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func _die() -> void:
	dead = true
	active = false
	_door_open = false
	_suction.stop()
	_warn_t = 0.0
	remove_from_group("enemy")
	for b in get_tree().get_nodes_in_group("boss_bullet"):
		b.queue_free()
	defeated.emit()
	# 慢动作里一连串爆炸
	Game.hitstop(0.25)
	await get_tree().create_timer(0.3, true, false, true).timeout
	Engine.time_scale = 0.35
	for i in 9:
		var p := global_position + Vector2(randf_range(-26, 30), randf_range(-70, -14))
		Game.sparks(get_parent(), p, [FIRE_COLOR, Color(1, 0.85, 0.5), Color(0.8, 0.78, 0.75)][i % 3], 16, 140.0)
		Game.sfx("boom", -4.0, randf_range(0.8, 1.2))
		Game.add_shake(5.0)
		Game.flash(Color(1.0, 0.7, 0.4), 0.25, 0.25)
		_flash = 1.0
		await get_tree().create_timer(0.18, true, false, true).timeout
	Engine.time_scale = 1.0
	# 炉门炸飞，指针落回零，"叮"
	_door.visible = false
	_spawn_flying_door()
	_pressure = 0.0
	_led_light.energy = 0.0
	Game.sfx("ding", -2.0)
	Game.sfx("vent", 0.0, 0.7)
	for v in vents:
		v.trigger(randf() * 0.4)
	_smoke.emitting = false
	await _wait(0.4)
	_release_memories()


func _spawn_flying_door() -> void:
	var d := Sprite2D.new()
	d.texture = _door.texture
	d.hframes = 2
	d.frame = 0
	d.centered = false
	d.offset = -CANVAS_ORIGIN
	d.global_position = global_position
	get_parent().add_child(d)
	var tw := d.create_tween().set_parallel(true)
	tw.tween_property(d, "position", d.position + Vector2(-70, 6), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(d, "rotation", -1.4, 0.8)
	tw.chain().tween_property(d, "modulate:a", 0.0, 1.5)
	tw.chain().tween_callback(d.queue_free)


## 别人被烧掉的回忆：一张张小照片、胶片从炉口飘出来，慢慢往上飘、发着微光
func _release_memories() -> void:
	var mouth := global_position + DOOR_RECT.get_center()
	for i in 16:
		var m := Memory.new()
		m.global_position = mouth + Vector2(randf_range(-6, 6), randf_range(-4, 4))
		m.velocity = Vector2(randf_range(-60, 10), randf_range(-70, -30))
		get_parent().add_child(m)
		await _wait(0.12)


func _draw_glow() -> void:
	if dead:
		_glow.draw_rect(DOOR_RECT, Color(0.05, 0.04, 0.04))
		return
	# 炉膛：底下最亮，往上暗，格子一闪一闪
	var r := DOOR_RECT
	for y in int(r.size.y):
		var k := float(y) / r.size.y
		var base := Color(0.35, 0.08, 0.03).lerp(Color(1.0, 0.5, 0.15), k)
		if _door_open:
			base = base.lerp(Color(1.0, 0.85, 0.5), 0.35)
		for x in int(r.size.x):
			var f := 0.75 + 0.25 * sin(_time * 11.0 + x * 1.7 + y * 0.9)
			_glow.draw_rect(Rect2(r.position + Vector2(x, y), Vector2.ONE), base * f + Color(0, 0, 0, 1.0 - f))


func _draw_needle() -> void:
	# 表盘自己发一点光（不吃场景压暗），黑暗里也读得出指针
	var r := 7
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var d := Vector2(x, y).length()
			if d <= r + 0.3:
				var col := Color(0.78, 0.74, 0.66) if d < r - 0.7 else Color(0.45, 0.42, 0.38)
				_needle_node.draw_rect(Rect2(x, y, 1, 1), col)
	for ang in range(-135, 136, 45):
		var t := Vector2.from_angle(deg_to_rad(ang - 90.0)) * (r - 1)
		_needle_node.draw_rect(Rect2(t.round(), Vector2.ONE), Color(0.3, 0.28, 0.26))
	for ang in [95, 110, 125]:
		var t := Vector2.from_angle(deg_to_rad(ang - 90.0)) * (r - 1)
		_needle_node.draw_rect(Rect2(t.round(), Vector2.ONE), Color(0.85, 0.25, 0.12))
	# 指针：0 在左下，1 在右下（270 度的表），一根 6 格的线
	var a := deg_to_rad(lerpf(-135.0, 135.0, _needle) - 90.0)
	var col := Color(0.15, 0.1, 0.1) if _needle < 0.8 else Color(0.75, 0.12, 0.08)
	for i in range(1, 7):
		var p := (Vector2.from_angle(a) * i).round()
		_needle_node.draw_rect(Rect2(p, Vector2.ONE), col)


func _draw_led() -> void:
	if _led_light.energy <= 0.0:
		_led.draw_rect(Rect2(0, 0, 2, 1), Color(0.3, 0.08, 0.06))
		return
	var blink := 1.0 if phase < 3 else (0.5 + 0.5 * sin(_time * 30.0))
	_led.draw_rect(Rect2(0, 0, 2, 1), LED_COLOR.lerp(Color.WHITE, _flash * 0.6) * blink + Color(0, 0, 0, 1.0 - blink))


func _draw_warn() -> void:
	if _warn_t <= 0.0 or int(_warn_t * 14.0) % 2 == 0:
		return
	var p := _warn_pos.round()
	var col := Color(1.0, 0.25, 0.2)
	_warn.draw_rect(Rect2(p + Vector2(-1, -9), Vector2(3, 6)), col)
	_warn.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(3, 2)), col)
	_warn.draw_rect(Rect2(p + Vector2(0, -9), Vector2(1, 6)), Color(1, 0.75, 0.6))


## 飘出来的回忆（一张小照片或一段胶片）
class Memory:
	extends Node2D

	var velocity := Vector2.ZERO
	var _t := 0.0
	var _film := randf() < 0.4
	var _sway := randf() * TAU

	func _ready() -> void:
		z_index = 15
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded
		var l := PointLight2D.new()
		l.texture = Game.light_texture()
		l.color = Color(1.0, 0.9, 0.7)
		l.energy = 0.5
		l.texture_scale = 0.4
		add_child(l)

	func _process(delta: float) -> void:
		_t += delta
		velocity = velocity.move_toward(Vector2(0, -14), delta * 40.0)
		position += (velocity + Vector2(sin(_t * 2.0 + _sway) * 10.0, 0)) * delta
		modulate.a = clampf(1.0 - (_t - 4.0) / 2.0, 0.0, 1.0)
		if _t > 6.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		# 烧焦的边：外圈暗橙，里面米色，中间一点深色（照片里的人）
		if _film:
			draw_rect(Rect2(-2, -1, 5, 3), Color(0.25, 0.18, 0.14))
			draw_rect(Rect2(-1, 0, 1, 1), Color(0.9, 0.82, 0.65))
			draw_rect(Rect2(1, 0, 1, 1), Color(0.9, 0.82, 0.65))
		else:
			draw_rect(Rect2(-2, -2, 4, 4), Color(0.6, 0.3, 0.12))
			draw_rect(Rect2(-1, -1, 3, 3), Color(0.92, 0.86, 0.72))
			draw_rect(Rect2(0, 0, 1, 1), Color(0.3, 0.24, 0.2))
