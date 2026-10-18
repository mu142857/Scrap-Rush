class_name TVBoss
extends StaticBody2D
## 第三关最终 Boss「老电视 THE SET」：废品星最深处最后一台能放录像的老电视，也是这趟旅程的终点。
## 它吸了这颗星球上太多情绪，疯了一样换台。打败它，它安静下来，屏幕一缩关掉；
## 然后自己重新亮起，开始放马灯里那段录像（结局，见 boss3_room.gd）。这一关的主题是"画面"。
##
## 靠"换台"出招（抽签不放回）。换台时屏幕真的换画面，左上角出绿色的 CH 几：
##   雪花台 CH2：一帘帘雪花从天花板直直落下，留两条缝；平台挡得住
##   彩条台 CH4：七根测试彩条先挑几根闪着预告，然后变成整根光柱，站在里面就挨打
##   测试卡 CH7：从屏幕中心射出一圈圈扫描线（穿过平台），三阶段变螺旋
##   重播台 CH9（二阶段起）：录下你的动作，1.2 秒后一个雪花做的"你"沿着你走过的路追你
##   雷雨 CH0（三阶段）：兔耳天线往你脚下劈闪电，落点先标红叉
## 会动（和锅炉的站桩、总机的天车都不一样，它是地上乱跑的那种）：
##   四条细木腿（代码画），每招之间换个位置；
##   冲撞（一阶段起）：屏幕变红、蹲下抖 0.9 秒，然后沿地面冲到墙，撞墙晕一下（这时挨打伤害 ×1.5）。
##     冲撞挡不住也跳不过，要先跳上搁板、再上吊着的电视躲；三阶段撞完掉头再冲一次
##   跳砸（二阶段起）：地上先标落点，跳到你头上砸下来，落地往两边炸出声波，要跳
## 三阶段：一个移动招 + 一个频道招同时出。
## 原点在脚底中间，屏幕朝左。图层坐标见 tools/draw_boss3.py。

signal hp_changed(hp: float, max_hp: float)
signal phase_changed(phase: int)
signal defeated

const BASE_HP := 7800.0  # 10-18 作者："最终 boss 太弱、太脆"：3600 → 7400；武器打击感加强后闪光灯变快，再到 7800。站桩三把武器 60~80 秒
const CONTACT_DAMAGE := 10.0
const CANVAS_ORIGIN := Vector2(44, 78)
const SCREEN := Rect2(Vector2(12, 30) - CANVAS_ORIGIN, Vector2(47, 31))
const KNOBS := [Vector2(72, 36) - CANVAS_ORIGIN, Vector2(72, 46) - CANVAS_ORIGIN]
const LED := Vector2(71, 62) - CANVAS_ORIGIN
const TIPS := [Vector2(24, 3) - CANVAS_ORIGIN, Vector2(66, 1) - CANVAS_ORIGIN]
## 四条腿的胯（相对原点），腿长；腿由 _draw_legs 画
const LEGS_X := [-30.0, -14.0, 14.0, 30.0]
const HIP_Y := -10.0
const SLAM_DAMAGE := 14.0
const DASH_SPEED := [200.0, 240.0, 280.0]
const MOVES := ["charge", "hop"]
const LED_COLOR := Color(1.0, 0.28, 0.18)
const BAR_COLORS := [Color(0.92, 0.92, 0.92), Color(0.95, 0.92, 0.2), Color(0.2, 0.92, 0.95),
	Color(0.2, 0.9, 0.25), Color(0.9, 0.25, 0.9), Color(0.95, 0.22, 0.2), Color(0.2, 0.3, 0.95)]
const CHANNEL_NUM := {"snow": 2, "bars": 4, "test": 7, "rerun": 9, "storm": 0}
const SCREEN_LIGHT := {"snow": Color(0.8, 0.82, 0.9), "bars": Color(0.9, 0.9, 1.0), "test": Color(0.6, 0.95, 1.0),
	"rerun": Color(0.9, 0.6, 0.6), "storm": Color(0.7, 0.75, 1.0), "rage": Color(1.0, 0.35, 0.3), "home": Color(1.0, 0.85, 0.6), "warm": Color(1.0, 0.92, 0.8)}
const HOME_TEX := preload("res://art/boss/hometown.png")

var arena := Rect2(0, 0, 320, 180)
var floor_y := 164.0
var ceil_y := 12.0
var platforms: Array = []
var bullet_parent: Node

var max_hp := BASE_HP
var hp := BASE_HP
var phase := 1
var active := false
var dead := false
## 屏幕现在放什么："off" "snow" "bars" "test" "rerun" "storm" "home" "warm"
var screen_mode := "off"
## 关机动画 0~1（1 = 完全关掉）
var off_t := 0.0
## 开机亮度 0~1
var on_t := 0.0

var _time := 0.0
var _flash := 0.0
## 受击顿一格、换阶段先停一下（夜间打磨：三个 Boss 统一，照总机）
var _recoil := 0.0
var _recoil_dir := 1.0
var _pause_t := 0.0
## 测试卡第一圈扫描线的缺口方向：射出前画一小段淡弧（和总机铃声招一样）
var _gap_hint_t := 0.0
## 冲撞教学：前两次冲撞预警 1.3 秒（先教一遍），之后 0.9 秒；预警期间能躲的吊电视顶上闪暖黄边（第三关新玩家报告第 4 条）
var _charges_done := 0
var _safe_flash_t := 0.0
const CHARGE_WARN_FIRST := 1.3
const CHARGE_WARN := 0.9
var _gap_hint_a := 0.0
var _hot := 0.0
var _knob := [0.0, 0.0]
var _osd_t := 0.0
var _last_pattern := ""
var _bag: Array[String] = []
var _bag_phase := 0
var _warn_t := 0.0
var _warn_pos := Vector2.ZERO
var _storm_spark := 0.0
## 腿的状态："stand" "walk" "crouch" "dash" "air" "stun"
var _mode := "stand"
var _crouch := 0.0
var _gait := 0.0
var _rumble := 0.0
var _contact_damage := CONTACT_DAMAGE
var _shadow_t := 0.0
var _shadow_x := 0.0

var _parts: Node2D
var _legs: Node2D
var _body: Sprite2D
var _deco: Node2D
var _screen_light: PointLight2D
var _led_light: PointLight2D
var _contact: Area2D
var _flash_mat: ShaderMaterial
var _warn: Node2D
var _static: AudioStreamPlayer


func _ready() -> void:
	add_to_group("enemy")
	Bestiary.watch(self, "boss_set", Rect2(-48, -96, 96, 96))   # 怪物图鉴：第一次出现在画面里就记一笔
	collision_layer = 4
	collision_mask = 0
	max_hp = BASE_HP * (1.0 + 0.5 * (Run.players.size() - 1))
	hp = max_hp
	if bullet_parent == null:
		bullet_parent = get_parent()

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(78, 44)
	shape.shape = rect
	shape.position = Vector2(0, -34)
	add_child(shape)
	_contact = Area2D.new()
	_contact.collision_layer = 0
	_contact.collision_mask = 2 | 8
	var cs := CollisionShape2D.new()
	var crect := RectangleShape2D.new()
	crect.size = Vector2(72, 50)
	cs.shape = crect
	cs.position = Vector2(0, -31)
	_contact.add_child(cs)
	add_child(_contact)

	_flash_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = EnemyBase.FLASH_SHADER
	_flash_mat.shader = sh

	_legs = Node2D.new()
	_legs.light_mask = 2
	_legs.draw.connect(_draw_legs)
	add_child(_legs)
	# 会蹲、会抖的那部分：机壳 + 屏幕 + 旋钮
	_parts = Node2D.new()
	add_child(_parts)
	_body = Sprite2D.new()
	_body.texture = load("res://art/boss/tv_body.png")
	_body.centered = false
	_body.offset = -CANVAS_ORIGIN
	_body.material = _flash_mat
	_body.light_mask = 2
	_parts.add_child(_body)

	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_deco = Node2D.new()
	_deco.material = unshaded
	_deco.draw.connect(_draw_deco)
	_parts.add_child(_deco)

	# 屏幕的光：照亮房间，颜色跟着频道变（不照电视自己）
	_screen_light = PointLight2D.new()
	_screen_light.texture = Game.light_texture()
	_screen_light.color = Color.WHITE
	_screen_light.energy = 0.0
	# 屏幕的光照亮周围一圈家具（夜间打磨：4.5 → 6）
	_screen_light.texture_scale = 6.0
	_screen_light.position = SCREEN.get_center() + Vector2(-30, 10)
	_screen_light.range_item_cull_mask = 1
	add_child(_screen_light)

	_led_light = PointLight2D.new()
	_led_light.texture = Game.light_texture()
	_led_light.color = LED_COLOR
	_led_light.energy = 0.0
	_led_light.texture_scale = 0.5
	_led_light.position = LED
	_led_light.range_item_cull_mask = 1
	add_child(_led_light)

	var key := PointLight2D.new()
	key.texture = Game.light_texture()
	key.color = Color(1.0, 0.85, 0.7)
	key.energy = 1.8
	key.texture_scale = 4.2
	key.position = Vector2(-60, -60)
	key.range_item_cull_mask = 2
	add_child(key)

	_warn = Node2D.new()
	_warn.material = unshaded
	_warn.z_index = 20
	_warn.draw.connect(_draw_warn)
	add_child(_warn)

	_static = AudioStreamPlayer.new()
	var st := Game.load_sound("static").duplicate() as AudioStreamWAV
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_end = st.data.size() / 2
	_static.stream = st
	_static.volume_db = -60.0
	add_child(_static)


# —— 对外 ——

func aim_point() -> Vector2:
	return global_position + _parts.position + SCREEN.get_center()


func is_targetable() -> bool:
	return active and not dead


func wake() -> void:
	_led_light.energy = 1.0
	Game.sfx("tvon", -2.0)
	screen_mode = "warm"
	var tw := create_tween()
	tw.tween_property(self, "on_t", 1.0, 0.8)
	if is_inside_tree(): await get_tree().create_timer(0.9, false).timeout
	_switch("snow")
	Game.add_shake(4.0)


func start_fight() -> void:
	active = true
	_static.play()
	_fight_loop()


## 结局：自己重新开机（亮度 0 → 1），屏幕放录像
func turn_on(mode := "home") -> void:
	off_t = 0.0
	on_t = 0.0
	screen_mode = mode
	_led_light.energy = 1.0
	Game.sfx("tvon", -2.0)
	var tw := create_tween()
	tw.tween_property(self, "on_t", 1.0, 1.4)


func hurt(damage: float, from_dir: Vector2, full: bool) -> void:
	if dead:
		return
	_flash = 1.0
	if not active:
		return
	_recoil = 0.06
	_recoil_dir = signf(from_dir.x) if from_dir.x != 0.0 else 1.0
	if full:
		Game.sfx("clang", -12.0, 1.8, 0.1)
	if _mode == "stun":
		damage *= 1.5
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



## 离开场景树（重来、切场景、整关重载）：标成"已结束"，所有出招循环都会看 dead 自己停下；
## 每个 await get_tree() 前面也先看还在不在树里。不然 get_tree() 变成空值，协程空转、无限刷错（夜间质检，网页版会卡死）
func _exit_tree() -> void:
	dead = true
	active = false

# —— 每帧 ——

func _physics_process(delta: float) -> void:
	_time += delta
	_flash = maxf(_flash - delta * 7.0, 0.0)
	_flash_mat.set_shader_parameter("flash", _flash)
	_warn_t -= delta
	_osd_t -= delta
	_storm_spark = maxf(_storm_spark - delta, 0.0)
	_warn.queue_redraw()
	_hot = move_toward(_hot, 1.0 if (phase == 3 and not dead) else 0.0, delta)
	_shadow_t -= delta
	_rumble = maxf(_rumble - delta, 0.0)
	# 三阶段整台电视跟着画面抖；冲撞蓄力时抖得更厉害
	_recoil -= delta
	_pause_t -= delta
	_gap_hint_t -= delta
	_safe_flash_t -= delta
	_parts.position = Vector2(roundf(sin(_time * 40.0) * (_hot * 0.8 + (1.5 if _rumble > 0.0 else 0.0))) + (_recoil_dir if _recoil > 0.0 else 0.0), roundf(_crouch))
	_legs.queue_redraw()
	var target_light: Color = SCREEN_LIGHT.get(screen_mode, Color.WHITE)
	_screen_light.color = _screen_light.color.lerp(target_light, delta * 6.0)
	var lit := (1.0 - off_t) * on_t
	if screen_mode == "off":
		lit = 0.0
	_screen_light.energy = lit * (1.3 + 0.2 * sin(_time * 17.0))
	_static.volume_db = lerpf(-60.0, -16.0, lit) if screen_mode in ["snow", "storm", "rage"] else -60.0
	_deco.queue_redraw()
	if active and not dead:
		for body in _contact.get_overlapping_bodies():
			if body is Player:
				(body as Player).hurt(global_position + Vector2(0, -34), _contact_damage)
			elif body is Crystal:
				(body as Crystal).take_hit(global_position + Vector2(0, -34), _contact_damage)


# —— 出招 ——

func _wait(t: float) -> void:
	if is_inside_tree(): await get_tree().create_timer(t, false).timeout


func _gap() -> float:
	# 10-18 加难：1.1 / 0.85 / 0.6 → 0.9 / 0.6 / 0.4（预警时长不变）
	return [0.9, 0.6, 0.4][phase - 1]


func _pool() -> Array[String]:
	var pool: Array[String] = ["snow", "bars", "test", "charge"]
	if phase >= 2:
		pool.append("rerun")
		pool.append("hop")
	if phase >= 3:
		pool.append("storm")
	return pool


## 抽签不放回；换阶段时新招先出
func _next_pattern() -> String:
	if _bag_phase != phase:
		var old := _bag_phase
		_bag_phase = phase
		_bag.assign(_pool())
		_bag.shuffle()
		for fresh in ["rerun", "hop", "storm"]:
			if _bag.has(fresh) and old > 0 and not (old >= 2 and fresh != "storm"):
				_bag.erase(fresh)
				_bag.append(fresh)
	if _bag.is_empty():
		_bag.assign(_pool())
		_bag.shuffle()
		if _bag.size() > 1 and _bag.back() == _last_pattern:
			_bag.reverse()
	var pick: String = _bag.pop_back()
	_last_pattern = pick
	return pick


func _fight_loop() -> void:
	await _wait(0.5)
	while active and not dead:
		while _pause_t > 0.0 and not dead:
			if is_inside_tree(): await get_tree().physics_frame
		var pick := _next_pattern()
		# 10-18 加难：二阶段起就叠招（原来三阶段才叠）
		if phase >= 2 and pick != "rerun":
			# 三阶段：一个移动招 + 一个频道招同时出（两个都是移动招就先后来）
			var second := _next_pattern()
			if pick in MOVES and second in MOVES:
				await _show(pick)
				await _run(pick)
				pick = second
			elif second in MOVES:
				var tmp := pick
				pick = second
				second = tmp
			if not (second in MOVES):
				_show(second)
				await _wait(0.45)
				_run(second)
		await _show(pick)
		await _run(pick)
		if dead:
			return
		await _wait(_gap())
		if not dead and not (pick in MOVES):
			await _stroll()


## 出招前：频道招换台，移动招屏幕变红
func _show(pick: String) -> void:
	if pick in MOVES:
		screen_mode = "rage"
		Game.sfx("tvclick", -2.0, 0.7)
		return
	_switch(pick)
	await _wait(0.45)


func _run(pick: String) -> void:
	match pick:
		"snow":
			await _snow()
		"bars":
			await _bars()
		"test":
			await _test()
		"rerun":
			await _rerun()
		"storm":
			await _storm()
		"charge":
			await _charge()
		"hop":
			await _hop()


# —— 走位 ——

func _x_min() -> float:
	return arena.position.x + 8.0 + 40.0


func _x_max() -> float:
	return arena.end.x - 8.0 - 40.0


## 招与招之间换个位置：走到离人远一点的地方（最多走 1.3 秒）
func _stroll() -> void:
	var p := _lead()
	var px := p.global_position.x if p else arena.get_center().x
	# 10-18 加难：二阶段起不再走远，朝玩家逼过去、停在约 50 像素外，压迫感
	if phase >= 2:
		var side := signf(position.x - px)
		if side == 0.0:
			side = 1.0
		await _walk_to(px + side * 50.0, [55.0, 80.0, 100.0][phase - 1], 1.1)
		return
	var options: Array[float] = []
	for x in [_x_min() + 10.0, arena.get_center().x, _x_max() - 10.0]:
		if absf(x - px) > 70.0 and absf(x - position.x) > 30.0:
			options.append(x)
	if options.is_empty():
		return
	await _walk_to(options.pick_random(), [55.0, 65.0, 80.0][phase - 1], 1.3)


func _walk_to(x: float, speed: float, max_time := 9.0) -> void:
	x = clampf(x, _x_min(), _x_max())
	_mode = "walk"
	var t := 0.0
	while absf(position.x - x) > 0.5 and t < max_time and not dead:
		if is_inside_tree(): await get_tree().physics_frame
		var d := get_physics_process_delta_time()
		t += d
		var step := speed * d
		position.x = move_toward(position.x, x, step)
		_gait += step * 0.35
	if not dead:
		_mode = "stand"


## 冲撞：屏幕变红、蹲下抖着蓄力，然后沿地面冲到墙；撞墙晕一下。三阶段撞完掉头再冲一次
func _charge() -> void:
	var times := 2 if phase == 3 else 1
	for n in times:
		if dead:
			return
		var p := _lead()
		var dir := signf((p.global_position.x if p else arena.get_center().x) - position.x)
		if n == 1:
			dir = -signf(position.x - arena.get_center().x)
		if dir == 0.0:
			dir = -1.0
		var warn := CHARGE_WARN_FIRST if _charges_done < 2 else CHARGE_WARN
		_charges_done += 1
		_mode = "crouch"
		_rumble = warn
		_safe_flash_t = warn
		_warn_at(Vector2(0, -66), warn)
		Game.sfx("static", -6.0, 0.6)
		var tw := create_tween()
		tw.tween_property(self, "_crouch", 5.0, 0.3)
		await _wait(warn)
		if dead:
			return
		_mode = "dash"
		_contact_damage = SLAM_DAMAGE
		Game.sfx("scrape", -4.0, 1.3)
		var end_x := _x_max() if dir > 0.0 else _x_min()
		var dust_t := 0.0
		while absf(position.x - end_x) > 0.5 and not dead:
			if is_inside_tree(): await get_tree().physics_frame
			var d := get_physics_process_delta_time()
			position.x = move_toward(position.x, end_x, DASH_SPEED[phase - 1] * d)
			_gait += DASH_SPEED[phase - 1] * d * 0.5
			_crouch = move_toward(_crouch, 2.0, d * 20.0)
			dust_t -= d
			if dust_t <= 0.0:
				dust_t = 0.07
				Game.dust(get_parent(), Vector2(position.x - dir * 30.0, floor_y), 1, -dir)
		_contact_damage = CONTACT_DAMAGE
		if dead:
			return
		# 撞墙：一声闷响，屏幕跳成雪花，旋钮乱转，晕一下
		_mode = "stun"
		_crouch = 0.0
		screen_mode = "snow"
		_knob[0] += 3.0
		_knob[1] += 2.0
		Game.sfx("boom", -2.0, 0.9)
		Game.sfx("clang", -6.0, 0.7)
		Game.add_shake(8.0)
		Game.hitstop(0.06)
		Game.sparks(get_parent(), Vector2(position.x + dir * 40.0, floor_y - 30.0), Color(1.0, 0.85, 0.6), 12, 100.0, Vector2(-dir, -0.5))
		await _wait([1.3, 1.1, 0.8][phase - 1])
		if not dead:
			_mode = "stand"
			screen_mode = "rage"


## 跳砸：地上先标落点，蹲一下，跳到人头上砸下来；落地往两边沿地面炸出声波
func _hop() -> void:
	var hops: int = 2 if phase == 2 else 3
	for n in hops:
		if dead:
			return
		var p := _lead()
		var to_x := clampf(p.global_position.x if p else arena.get_center().x, _x_min(), _x_max())
		_shadow_x = to_x
		_shadow_t = 0.75
		_mode = "crouch"
		var tw := create_tween()
		tw.tween_property(self, "_crouch", 6.0, 0.3)
		await _wait(0.4)
		if dead:
			return
		_mode = "air"
		_crouch = -2.0
		_contact_damage = SLAM_DAMAGE
		Game.sfx("jump", -2.0, 0.6)
		var from_x := position.x
		var dur := 0.7
		var t := 0.0
		while t < dur and not dead:
			if is_inside_tree(): await get_tree().physics_frame
			t = minf(t + get_physics_process_delta_time(), dur)
			var k := t / dur
			position.x = lerpf(from_x, to_x, k)
			position.y = floor_y - sin(k * PI) * 70.0
		if dead:
			position.y = floor_y
			return
		position.y = floor_y
		_mode = "stand"
		_crouch = 7.0
		create_tween().tween_property(self, "_crouch", 0.0, 0.3)
		Game.sfx("boom", -2.0, 1.1)
		Game.add_shake(6.0)
		Game.dust(get_parent(), Vector2(position.x, floor_y), 8)
		for dir in [-1.0, 1.0]:
			var b := BossBullet.spawn(bullet_parent, BossBullet.Kind.WAVE,
				Vector2(position.x + dir * 36.0, floor_y - 5.0), Vector2(dir * 100.0, 0))
			b.arena = arena
		await _wait(0.2)
		_contact_damage = CONTACT_DAMAGE
		await _wait(0.35)


## 换台：旋钮转一下、"咔"、一小截雪花、左上角出 CH 几
func _switch(mode: String) -> void:
	_knob[0] += 0.9
	Game.sfx("tvclick", -2.0, randf_range(0.9, 1.1))
	screen_mode = "snow"
	_osd_t = 1.2
	await _wait(0.12)
	if not dead:
		screen_mode = mode


func _warn_at(pos: Vector2, t := 0.6) -> void:
	_warn_pos = pos
	_warn_t = t
	Game.sfx("charge", -16.0, 2.0)


## 雪花台：一帘帘雪花从天花板直直落下，留两条缝（三阶段缝会挪）
func _snow() -> void:
	var waves: int = [1, 2, 3][phase - 1]
	for w in waves:
		if dead:
			return
		# 满屋落雪，留两条缝（电视会跑，所以缝开在哪都可能）
		var zone := _play_zone()
		var gaps := [randf_range(zone.x + 16, zone.y - 110), 0.0]
		gaps[1] = minf(gaps[0] + randf_range(60, 110), zone.y - 14)
		var cols: Array[float] = []
		for x in range(int(zone.x) + 4, int(zone.y) + 4, 12):
			if absf(x - gaps[0]) < 16 or absf(x - gaps[1]) < 16:
				continue
			cols.append(float(x))
		var hint := ColumnHint.new()
		hint.xs = cols
		hint.y = ceil_y + 2.0
		hint.life = 0.7
		bullet_parent.add_child(hint)
		await _wait(0.7)
		for row in 8:
			if dead:
				return
			for x in cols:
				var b := BossBullet.spawn(bullet_parent, BossBullet.Kind.SNOW,
					Vector2(x + randf_range(-2, 2), ceil_y + 4.0), Vector2(0, 72.0))
				b.arena = arena
			await _wait(0.2)
		await _wait(0.4)


## 雪花和彩条铺满的那一段 (左, 右)：墙到墙
func _play_zone() -> Vector2:
	return Vector2(arena.position.x + 8.0, arena.end.x - 8.0)


## 彩条台：七根彩条对应场地里七根柱子，先挑几根闪着预告，再变成光柱
func _bars() -> void:
	var rounds: int = 1 if phase == 1 else 2
	var zone := _play_zone()
	var w := (zone.y - zone.x) / 7.0
	var last: Array = []
	for r in rounds:
		if dead:
			return
		var idx := [0, 1, 2, 3, 4, 5, 6]
		idx.shuffle()
		var pick: Array = idx.slice(0, 3 if phase == 1 else 4)
		if r == 1:
			# 第二轮：打上一轮没打的那些（留一根安全的）
			pick = idx.filter(func(i): return not last.has(i)).slice(0, 3)
		last = pick
		for i in pick:
			var bar := BarPillar.new()
			bar.rect = Rect2(zone.x + w * i, ceil_y, w, floor_y - ceil_y)
			bar.color = BAR_COLORS[i]
			bullet_parent.add_child(bar)
		await _wait(BarPillar.WARN + BarPillar.LIVE + 0.2)


## 测试卡：从屏幕中心射出一圈圈扫描线；三阶段变成两条转着射的螺旋
func _test() -> void:
	var center := global_position + _parts.position + SCREEN.get_center()
	if phase == 3:
		var a := randf() * TAU
		for i in 40:
			if dead:
				return
			for k in 2:
				var b := BossBullet.spawn(bullet_parent, BossBullet.Kind.SCAN, center, Vector2.from_angle(a + PI * k) * 68.0)
				b.arena = arena
			a += deg_to_rad(13.0)
			if i % 5 == 0:
				Game.sfx("tvclick", -14.0, 1.6)
			await _wait(0.07)
		return
	var rings: int = [2, 3, 3][phase - 1]
	var count := 22
	# 第一圈的缺口先定好，在缺口方向画一小段淡弧，停 0.45 秒再射（第一圈不全靠反应）
	var first_gap := randi() % count
	_gap_hint_a = TAU * first_gap / count
	_gap_hint_t = 0.45
	await _wait(0.45)
	for r in rings:
		if dead:
			return
		var gap_at := first_gap if r == 0 else randi() % count
		Game.sfx("rivets", -8.0, 1.6)
		Game.add_shake(1.5)
		for i in count:
			if absi(i - gap_at) <= 1 or absi(i - gap_at) >= count - 1:
				continue
			var a := TAU * i / count + (PI / count) * r
			var b := BossBullet.spawn(bullet_parent, BossBullet.Kind.SCAN, center, Vector2.from_angle(a) * 62.0)
			b.arena = arena
		await _wait(0.6)


## 重播台：一个雪花做的"你"沿着你 1.2 秒前走过的路追你，持续 6 秒
func _rerun() -> void:
	var p := _lead()
	if p == null:
		return
	var echo := Echo.new()
	echo.target = p
	bullet_parent.add_child(echo)
	await _wait(Echo.DELAY + Echo.LIFE * 0.6)


## 雷雨：天线往人脚下劈 4 道闪电，落点先标红叉
func _storm() -> void:
	for i in 4:
		if dead:
			return
		var p := _lead()
		var target := p.global_position if p else Vector2(arena.get_center().x, floor_y)
		target.x += randf_range(-14, 14)
		var tip: Vector2 = global_position + _parts.position + TIPS[i % 2]
		var bolt := Bolt.new()
		bolt.from = tip
		bolt.to = target
		bullet_parent.add_child(bolt)
		_storm_spark = 0.8
		await _wait(0.5)
	await _wait(0.6)


func _lead() -> Player:
	var best := INF
	var out: Player = null
	for n in get_tree().get_nodes_in_group("player"):
		var p := n as Player
		var d := p.global_position.distance_to(global_position)
		if d < best:
			best = d
			out = p
	return out


func _phase_roar() -> void:
	Game.sfx("tvclick", 0.0, 0.7)
	Game.sfx("static", -6.0)
	Game.add_shake(6.0)
	Game.flash(Color(0.9, 0.95, 1.0), 0.35, 0.5)
	screen_mode = "snow"
	_osd_t = 1.5
	# 换阶段：清掉场上的子弹，下一招推迟 0.8 秒
	for bl in get_tree().get_nodes_in_group("boss_bullet"):
		if bl.has_method("fizzle"):
			bl.call("fizzle")
		else:
			# 光柱、雪花分身、闪电没有 fizzle：原地迸一下再没，不凭空消失（10-18）
			if bl is Node2D:
				Game.sparks(get_parent(), (bl as Node2D).global_position, Color(0.85, 0.85, 0.95), 3, 40.0)
			bl.queue_free()
	_pause_t = 0.8


func _die() -> void:
	dead = true
	Bestiary.count_kill("boss_set")   # 怪物图鉴：击杀数
	active = false
	_warn_t = 0.0
	_shadow_t = 0.0
	_rumble = 0.0
	_contact_damage = CONTACT_DAMAGE
	remove_from_group("enemy")
	# 腿一软，整台跪在地上（空中死的先掉下来）
	_mode = "dead"
	var fall := create_tween().set_parallel(true)
	fall.tween_property(self, "position:y", floor_y, 0.2)
	fall.tween_property(self, "_crouch", 8.0, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	# 场上的子弹：有 fizzle 的消散，其他（光柱、闪电、雪花分身）原地迸一下再没，不凭空消失
	for b in get_tree().get_nodes_in_group("boss_bullet"):
		if b.has_method("fizzle"):
			b.call("fizzle")
		else:
			if b is Node2D:
				Game.sparks(get_parent(), (b as Node2D).global_position, Color(0.85, 0.85, 0.95), 3, 40.0)
			b.queue_free()
	defeated.emit()
	Game.hitstop(0.3)
	# 死的那一下有分量：机壳、塑料、玻璃碎片迸出来，屏幕炸一圈火花
	EliteFx.scrap_burst(get_parent(), Rect2(global_position + Vector2(-36.0, -56.0), Vector2(72.0, 44.0)), 12,
		[Color8(134, 77, 31), Color8(80, 86, 104), Color8(170, 176, 196)])
	Game.sparks(get_parent(), aim_point(), Color(0.85, 0.9, 1.0), 14, 120.0)
	Game.sfx("boom", -4.0, 1.2)
	if is_inside_tree(): await get_tree().create_timer(0.35, true, false, true).timeout
	# 疯狂乱换台一阵
	for i in 12:
		if not is_inside_tree():
			return
		screen_mode = ["snow", "bars", "test", "rerun", "storm"][i % 5]
		_osd_t = 0.2
		_flash = 0.6
		Game.sfx("tvclick", -4.0, randf_range(0.7, 1.4))
		Game.add_shake(3.0)
		if is_inside_tree(): await get_tree().create_timer(0.09, true, false, true).timeout
	# 显像管关机：画面缩成一条横线，再缩成一个点，灭
	screen_mode = "warm"
	_static.stop()
	Game.sfx("tvoff", 0.0)
	var tw := create_tween()
	tw.tween_property(self, "off_t", 1.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	screen_mode = "off"
	_led_light.energy = 0.0


# —— 画 ——

## 四条细木腿：胯在机壳底下，走路时对角两条一起迈；蹲下时膝盖往外撇；空中往下耷拉
func _draw_legs() -> void:
	var moving := _mode in ["walk", "dash"]
	for i in 4:
		var hx: float = LEGS_X[i]
		var out := signf(hx)
		var hip := Vector2(hx, HIP_Y + roundf(_crouch))
		var foot := Vector2(hx + out * 2.0, 0.0)
		match _mode:
			"air":
				foot = Vector2(hx + out * 4.0, hip.y + 9.0)
			"dead":
				foot = Vector2(hx + out * 7.0, 0.0)
			_:
				var ph := _gait + (0.0 if i % 3 == 0 else PI)
				if moving:
					foot.x += roundf(sin(ph) * 3.0)
					foot.y -= roundf(maxf(cos(ph), 0.0) * 2.0)
				foot.x += roundf(out * maxf(_crouch, 0.0) * 0.5)
		var knee := (hip + foot) / 2.0 + Vector2(out * maxf(_crouch, 0.0) * 0.7, 0.0)
		for seg in [[hip, knee], [knee, foot]]:
			var a: Vector2 = seg[0]
			var b: Vector2 = seg[1]
			var n := maxi(int(a.distance_to(b)), 1)
			for k in n + 1:
				var q := a.lerp(b, float(k) / n).round()
				_legs.draw_rect(Rect2(q + Vector2(-1, 0), Vector2(2, 1)), Color8(134, 77, 31))
				_legs.draw_rect(Rect2(q + Vector2(-1, 0), Vector2(1, 1)), Color8(187, 117, 49))
		_legs.draw_rect(Rect2(foot.round() + Vector2(-2, -1), Vector2(4, 1)), Color8(79, 42, 20))


func _draw_deco() -> void:
	var r := SCREEN
	var lit := on_t * (1.0 - off_t) if screen_mode != "off" else 0.0
	if lit > 0.0:
		_draw_screen(r, lit)
	elif screen_mode == "off":
		_deco.draw_rect(r, Color(0.04, 0.05, 0.06))
	# 弧形玻璃的反光：左上一道斜亮线
	for i in 6:
		_deco.draw_rect(Rect2(r.position + Vector2(3 + i, 8 - i), Vector2.ONE), Color(1, 1, 1, 0.12))
	# 旋钮：灰色圆钮，一道刻线跟着转
	for k in 2:
		var c: Vector2 = KNOBS[k]
		for y in range(-4, 5):
			for x in range(-4, 5):
				if Vector2(x, y).length() <= 4.3:
					var shade := 0.45 if (x + y) > 1 else 0.6
					_deco.draw_rect(Rect2(c + Vector2(x, y), Vector2.ONE), Color(shade, shade, shade + 0.06) * 0.6)
		var a: float = _knob[k] + (_time * 3.0 if (k == 1 and phase == 3 and not dead) else 0.0)
		for i in range(1, 4):
			_deco.draw_rect(Rect2((c + Vector2.from_angle(a) * i).round(), Vector2.ONE), Color(0.85, 0.85, 0.9) * 0.7)
	# 电源红灯
	var on := _led_light.energy > 0.0
	var led := LED_COLOR.lerp(Color.WHITE, _flash * 0.5) if on else Color(0.25, 0.07, 0.05)
	_deco.draw_rect(Rect2(LED - Vector2(1, 0), Vector2(3, 2)), led)
	# 天线尖上的电火花
	if _storm_spark > 0.0 or (phase == 3 and not dead and randf() < 0.1):
		for tip in TIPS:
			for i in 4:
				var p: Vector2 = tip + Vector2(randi_range(-3, 3), randi_range(-3, 3))
				_deco.draw_rect(Rect2(p, Vector2.ONE), Color(0.75, 0.85, 1.0))


func _draw_screen(r: Rect2, lit: float) -> void:
	# 关机动画：高度先缩成一条线，最后宽度也缩成一个点
	var h := r.size.y * clampf(1.0 - off_t * 1.4, 0.04, 1.0)
	var w := r.size.x * clampf(1.0 - maxf(off_t - 0.7, 0.0) * 3.3, 0.04, 1.0)
	var sr := Rect2(r.get_center() - Vector2(w, h) / 2.0, Vector2(w, h)).abs()
	if off_t > 0.05:
		_deco.draw_rect(r, Color(0.04, 0.05, 0.06))
		_deco.draw_rect(sr, Color(0.95, 0.97, 1.0) * lit)
		return
	match screen_mode:
		"rage":
			# 红色雪花：要冲撞 / 跳砸了
			_deco.draw_rect(r, Color(0.25, 0.04, 0.03) * lit)
			for i in 200:
				var p := r.position + Vector2(randi() % int(r.size.x), randi() % int(r.size.y))
				var v := randf_range(0.4, 1.0) * lit
				_deco.draw_rect(Rect2(p, Vector2(1 + randi() % 2, 1)), Color(v, v * 0.25, v * 0.2))
		"snow", "storm":
			_deco.draw_rect(r, Color(0.12, 0.12, 0.14))
			for i in 260:
				var p := r.position + Vector2(randi() % int(r.size.x), randi() % int(r.size.y))
				var v := randf_range(0.4, 1.0) * lit
				_deco.draw_rect(Rect2(p, Vector2(1 + randi() % 2, 1)), Color(v, v, v * 1.05))
		"bars":
			var bw := r.size.x / 7.0
			for i in 7:
				_deco.draw_rect(Rect2(r.position + Vector2(roundf(bw * i), 0), Vector2(ceilf(bw), r.size.y * 0.75)), BAR_COLORS[i] * lit)
			_deco.draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.75), Vector2(r.size.x, r.size.y * 0.25)), Color(0.08, 0.08, 0.12))
		"test":
			_deco.draw_rect(r, Color(0.3, 0.32, 0.36) * lit)
			var c := r.get_center()
			for k in 120:
				var a := TAU * k / 120.0
				for rad in [8.0, 15.0, 21.0]:
					_deco.draw_rect(Rect2((c + Vector2.from_angle(a) * rad).round(), Vector2.ONE), Color(0.95, 0.95, 0.95) * lit)
			_deco.draw_rect(Rect2(c.x - 30, c.y, 60, 1), Color(0.95, 0.95, 0.95) * lit)
			_deco.draw_rect(Rect2(c.x, c.y - 22, 1, 44), Color(0.95, 0.95, 0.95) * lit)
		"rerun":
			# 屏幕里一个红衣人的剪影在雪花里晃
			_deco.draw_rect(r, Color(0.18, 0.12, 0.12) * lit)
			for i in 90:
				var p := r.position + Vector2(randi() % int(r.size.x), randi() % int(r.size.y))
				_deco.draw_rect(Rect2(p, Vector2.ONE), Color(0.5, 0.45, 0.45) * lit)
			var c := r.get_center() + Vector2(sin(_time * 3.0) * 8.0, 4)
			_deco.draw_rect(Rect2(c + Vector2(-3, -14), Vector2(6, 18)), Color(0.7, 0.18, 0.16) * lit)
			_deco.draw_rect(Rect2(c + Vector2(-3, -12), Vector2(1, 6)), Color(1.0, 0.75, 0.75) * lit)
		"home":
			_deco.draw_texture_rect(HOME_TEX, r, false, Color(lit, lit, lit))
		"warm":
			_deco.draw_rect(r, Color(0.95, 0.9, 0.82) * lit)
	# 扫描线：隔一行暗一点
	for y in range(0, int(r.size.y), 2):
		_deco.draw_rect(Rect2(r.position + Vector2(0, y), Vector2(r.size.x, 1)), Color(0, 0, 0, 0.22))
	# 左上角的频道号（绿色 OSD）
	if _osd_t > 0.0 and CHANNEL_NUM.has(screen_mode):
		_draw_osd(r.position + Vector2(4, 4), "CH%d" % CHANNEL_NUM[screen_mode])


## 3×5 的小像素字，只认 C、H 和数字
const GLYPHS := {
	"C": ["111", "100", "100", "100", "111"], "H": ["101", "101", "111", "101", "101"],
	"0": ["111", "101", "101", "101", "111"], "2": ["111", "001", "111", "100", "111"],
	"4": ["101", "101", "111", "001", "001"], "7": ["111", "001", "010", "010", "010"],
	"9": ["111", "101", "111", "001", "111"],
}


func _draw_osd(at: Vector2, text: String) -> void:
	var x := 0
	for ch in text:
		var g: Array = GLYPHS.get(ch, [])
		for row in g.size():
			for col in 3:
				if g[row][col] == "1":
					_deco.draw_rect(Rect2(at + Vector2(x + col, row), Vector2.ONE), Color(0.3, 1.0, 0.4))
		x += 4


func _draw_warn() -> void:
	if _safe_flash_t > 0.0 and int(_safe_flash_t * 8.0) % 2 == 0:
		# 冲撞躲得开的地方：台面比机壳顶（脚底往上约 56 像素）还高的平台，顶上闪一道暖黄边，两头各一个小角
		var case_top := floor_y - 56.0
		for pl in platforms:
			var plat: Vector3 = pl
			if plat.z >= case_top - 6.0:
				continue
			var x0 := plat.x - global_position.x
			var w := plat.y - plat.x
			var y := plat.z - global_position.y
			var col := Color(1.0, 0.85, 0.45, 0.9)
			_warn.draw_rect(Rect2(x0, y - 1, w, 1), col)
			_warn.draw_rect(Rect2(x0, y - 3, 1, 3), col)
			_warn.draw_rect(Rect2(x0 + w - 1, y - 3, 1, 3), col)
	if _gap_hint_t > 0.0:
		# 测试卡第一圈扫描线的缺口：从屏幕中心往外一小段淡青色弧
		var c := SCREEN.get_center() + _parts.position
		for k in range(-2, 3):
			var a := _gap_hint_a + k * 0.06
			for rr in [14.0, 18.0, 22.0]:
				_warn.draw_rect(Rect2((c + Vector2.from_angle(a) * rr).round(), Vector2.ONE), Color(0.6, 0.95, 1.0, 0.55))
	if _shadow_t > 0.0 and int(_shadow_t * 16.0) % 2 == 0:
		# 跳砸落点：地上一道闪烁的红影，宽度就是机壳的宽度
		var x0 := _shadow_x - global_position.x - 38.0
		var y := floor_y - global_position.y
		_warn.draw_rect(Rect2(x0, y - 2, 76, 2), Color(1.0, 0.25, 0.2, 0.85))
		for k in range(0, 76, 6):
			_warn.draw_rect(Rect2(x0 + k + 2, y - 5, 2, 2), Color(1.0, 0.3, 0.25, 0.6))
	if _warn_t <= 0.0 or int(_warn_t * 14.0) % 2 == 0:
		return
	var p := _warn_pos.round()
	var col := Color(1.0, 0.25, 0.2)
	_warn.draw_rect(Rect2(p + Vector2(-1, -9), Vector2(3, 6)), col)
	_warn.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(3, 2)), col)


## 雪花帘的预告：天花板上一排淡淡的点，标出这一帘会从哪些列落下
class ColumnHint:
	extends Node2D

	var xs: Array[float] = []
	var y := 14.0
	var life := 0.7
	var _t := 0.0

	func _ready() -> void:
		z_index = 9
		add_to_group("boss_bullet")
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		if int(_t * 12.0) % 2 == 1:
			return
		for x in xs:
			for k in 3:
				draw_rect(Rect2(roundf(x), y + k * 3, 1, 2), Color(0.85, 0.85, 0.9, 0.7))


## 一根彩条光柱：先 WARN 秒描边闪烁，再 LIVE 秒整根亮起，站在里面挨打
class BarPillar:
	extends Node2D

	const WARN := 0.9
	const LIVE := 0.6
	const DAMAGE := 10.0
	var rect := Rect2()
	var color := Color.WHITE
	var _t := 0.0
	var _hit := false

	func _ready() -> void:
		z_index = 8
		add_to_group("boss_bullet")
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded
		var l := PointLight2D.new()
		l.texture = Game.light_texture()
		l.color = color
		l.energy = 0.0
		l.texture_scale = 1.6
		l.position = rect.get_center()
		l.name = "L"
		add_child(l)

	func _physics_process(delta: float) -> void:
		var was := _t
		_t += delta
		if was < WARN and _t >= WARN:
			Game.sfx("buzz", -10.0, 1.8)
			Game.add_shake(1.5)
		var live := _t >= WARN and _t < WARN + LIVE
		(get_node("L") as PointLight2D).energy = 1.2 if live else 0.0
		if live:
			for n in get_tree().get_nodes_in_group("player"):
				var p := n as Player
				if rect.grow(-2).has_point(p.global_position + Vector2(0, -8)):
					p.hurt(Vector2(rect.get_center().x, p.global_position.y), DAMAGE * EnemyBase.damage_mult())
		if _t >= WARN + LIVE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		if _t < WARN:
			if int(_t / (0.06 if _t > WARN * 0.5 else 0.11)) % 2 == 0:
				draw_rect(rect, Color(color, 0.12))
				draw_rect(Rect2(rect.position, Vector2(1, rect.size.y)), Color(color, 0.8))
				draw_rect(Rect2(rect.position + Vector2(rect.size.x - 1, 0), Vector2(1, rect.size.y)), Color(color, 0.8))
			return
		draw_rect(rect, Color(color, 0.55))
		draw_rect(rect.grow_individual(-4, 0, -4, 0), Color(color.lerp(Color.WHITE, 0.5), 0.6))


## 重播：录下目标的位置，DELAY 秒后一个雪花剪影沿着同一条路走，碰到就挨打
class Echo:
	extends Node2D

	const DELAY := 1.2
	const LIFE := 6.0
	const DAMAGE := 10.0
	var target: Player
	var _trail: Array[Vector2] = []
	var _t := 0.0
	var _sprite: Sprite2D

	func _ready() -> void:
		z_index = 9
		add_to_group("boss_bullet")
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded
		_sprite = Sprite2D.new()
		_sprite.texture = load("res://art/chars/%s_body.png" % target.skin)
		_sprite.hframes = 7
		_sprite.centered = false
		_sprite.offset = Vector2(-8, -Player.FRAME_SIZE.y)
		_sprite.use_parent_material = true
		_sprite.visible = false
		add_child(_sprite)
		Game.sfx("tvclick", -4.0, 0.6)

	func _physics_process(delta: float) -> void:
		# 顿帧时 time_scale = 0、delta = 0：影子跟着整个停住，也不往轨迹里记（不然解冻后影子会跳一截）
		if delta <= 0.0:
			return
		_t += delta
		if is_instance_valid(target):
			_trail.append(target.global_position)
		# 延迟按物理帧数算，和这一帧的 delta 无关
		# （以前是 int(DELAY / delta)：delta = 0 时是无穷大，x86 电脑上转成整数变成极大的负数，下面取下标越界崩溃）
		var lag := maxi(1, roundi(DELAY * Engine.physics_ticks_per_second))
		if _trail.size() > lag:
			var pos: Vector2 = _trail[_trail.size() - 1 - lag]
			global_position = pos
			_sprite.visible = true
			_sprite.frame = 4 + int(_t * 10.0) % 3
			_sprite.flip_h = _trail.size() > lag + 2 and _trail[_trail.size() - lag - 2].x > pos.x
			_sprite.modulate = Color(1.6, 1.6, 1.8, 0.55 + 0.3 * randf())
			for n in get_tree().get_nodes_in_group("player"):
				var p := n as Player
				if p.global_position.distance_to(global_position) < 8.0:
					p.hurt(global_position, DAMAGE * EnemyBase.damage_mult())
		if _t > DELAY + LIFE:
			Game.sparks(get_parent(), global_position + Vector2(0, -10), Color(0.9, 0.9, 1.0), 10, 60.0)
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		if not _sprite.visible:
			return
		# 身上一层雪花噪点
		for i in 14:
			draw_rect(Rect2(Vector2(randi_range(-4, 3), randi_range(-19, -1)), Vector2.ONE), Color(1, 1, 1, randf_range(0.3, 0.9)))


## 一道闪电：落点先标 0.6 秒红叉，然后从天线尖劈下来，落点一圈挨打
class Bolt:
	extends Node2D

	const WARN := 0.6
	const RADIUS := 11.0
	const DAMAGE := 12.0
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var _t := 0.0
	var _struck := false
	var _path: Array[Vector2] = []

	func _ready() -> void:
		z_index = 10
		add_to_group("boss_bullet")
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded
		Game.sfx("charge", -14.0, 2.4)

	func _physics_process(delta: float) -> void:
		_t += delta
		if _t >= WARN and not _struck:
			_struck = true
			_path.clear()
			var n := 9
			for i in n + 1:
				var p := from.lerp(to, float(i) / n)
				if i > 0 and i < n:
					p += Vector2(randf_range(-6, 6), randf_range(-3, 3))
				_path.append(p)
			Game.sfx("buzz", -2.0, 1.4)
			Game.flash(Color(0.8, 0.85, 1.0), 0.18, 0.2)
			Game.add_shake(3.0)
			Game.sparks(get_parent(), to, Color(0.75, 0.85, 1.0), 12, 90.0)
			for nd in get_tree().get_nodes_in_group("player"):
				var pl := nd as Player
				if pl.global_position.distance_to(to) < RADIUS + 4.0:
					pl.hurt(to, DAMAGE * EnemyBase.damage_mult())
		if _t >= WARN + 0.18:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		if _t < WARN:
			if int(_t * 14.0) % 2 == 0:
				var c := (to - global_position).round()
				for k in range(-3, 4):
					draw_rect(Rect2(c + Vector2(k, k - 2), Vector2.ONE), Color(1, 0.25, 0.2))
					draw_rect(Rect2(c + Vector2(k, -k - 2), Vector2.ONE), Color(1, 0.25, 0.2))
			return
		for i in range(1, _path.size()):
			var a := _path[i - 1] - global_position
			var b := _path[i] - global_position
			var steps := int(a.distance_to(b))
			for s in steps:
				draw_rect(Rect2(a.lerp(b, float(s) / steps).round(), Vector2(2, 1)), Color(0.85, 0.92, 1.0))
